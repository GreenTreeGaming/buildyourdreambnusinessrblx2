local Players =
	game:GetService("Players")

local ReplicatedStorage =
	game:GetService("ReplicatedStorage")

local TweenService =
	game:GetService("TweenService")


local player =
	Players.LocalPlayer

local playerGui =
	player:WaitForChild(
		"PlayerGui"
	)


--==================================================
-- SHARED
--==================================================

local shared =
	ReplicatedStorage:WaitForChild(
		"Shared"
	)

local DailyRewardConfig =
	require(
		shared:WaitForChild(
			"DailyRewardConfig"
		)
	)


--==================================================
-- REMOTES
--==================================================

local remotes =
	ReplicatedStorage:WaitForChild(
		"Remotes"
	)

local getStateRemote =
	remotes:WaitForChild(
		"GetDailyRewardState"
	) :: RemoteFunction

local claimRemote =
	remotes:WaitForChild(
		"ClaimDailyReward"
	) :: RemoteFunction


--==================================================
-- UI
--==================================================

local screenGui =
	playerGui:WaitForChild(
		"DailyRewards"
	) :: ScreenGui

local mainFrame =
	screenGui:WaitForChild(
		"Frame"
	) :: Frame

local rewardsFrame =
	mainFrame:WaitForChild(
		"RewardsFrame"
	) :: Frame

local template =
	rewardsFrame:WaitForChild(
		"Template"
	) :: GuiObject

local closeButton =
	mainFrame:WaitForChild(
		"Close"
	) :: GuiButton


template.Visible =
	false


--==================================================
-- CONSTANTS
--==================================================

local OPEN_TWEEN =
	TweenInfo.new(
		0.3,
		Enum.EasingStyle.Back,
		Enum.EasingDirection.Out
	)

local CLOSE_TWEEN =
	TweenInfo.new(
		0.2,
		Enum.EasingStyle.Quad,
		Enum.EasingDirection.In
	)


--==================================================
-- STATE
--==================================================

local currentState = nil

local cards: {
	[number]: GuiObject
} = {}

local claiming =
	false

local isOpen =
	false

local countdownToken =
	0

local originalFrameSize =
	mainFrame.Size


--==================================================
-- FORMATTING
--==================================================

local function setClaimButtonText(
	button: TextButton,
	text: string
)
	button.Text = ""

	local title =
		button:FindFirstChild(
			"Title"
		)

	if title
		and title:IsA(
			"TextLabel"
		) then

		title.Text =
			text
	end
end


local function formatNumber(
	value: number
): string
	value =
		math.floor(
			math.max(
				0,
				value
			)
		)

	if value >= 1_000_000_000 then
		local amount =
			value / 1_000_000_000

		if amount >= 10 then
			return string.format(
				"%.0fB",
				amount
			)
		end

		return string.format(
			"%.1fB",
			amount
		):gsub(
			"%.0B",
			"B"
		)
	end

	if value >= 1_000_000 then
		local amount =
			value / 1_000_000

		if amount >= 10 then
			return string.format(
				"%.0fM",
				amount
			)
		end

		return string.format(
			"%.1fM",
			amount
		):gsub(
			"%.0M",
			"M"
		)
	end

	if value >= 1_000 then
		local amount =
			value / 1_000

		if amount >= 10 then
			return string.format(
				"%.0fK",
				amount
			)
		end

		return string.format(
			"%.1fK",
			amount
		):gsub(
			"%.0K",
			"K"
		)
	end

	return tostring(value)
end


local function formatDuration(
	seconds: number
): string
	local minutes =
		math.floor(
			seconds / 60
		)

	if minutes >= 60 then
		local hours =
			math.floor(
				minutes / 60
			)

		local leftoverMinutes =
			minutes % 60

		if leftoverMinutes > 0 then
			return `{hours}h {leftoverMinutes}m`
		end

		return `{hours}h`
	end

	return `{minutes}m`
end


local function formatCountdown(
	seconds: number
): string
	seconds =
		math.max(
			0,
			math.floor(seconds)
		)

	local hours =
		math.floor(
			seconds / 3600
		)

	local minutes =
		math.floor(
			(seconds % 3600) / 60
		)

	local remainingSeconds =
		seconds % 60

	return string.format(
		"%02d:%02d:%02d",
		hours,
		minutes,
		remainingSeconds
	)
end


local function getRewardAmountText(
	reward
): string
	local cashText =
		`${
			formatNumber(
				reward.Cash or 0
			)
		}`

	if reward.Boost then
		return `{cashText} + {
			formatDuration(
				reward.Boost.Duration
			)
		}`
	end

	return cashText
end


--==================================================
-- OPEN / CLOSE
--==================================================

local function openUI()
	if isOpen then
		return
	end

	isOpen =
		true

	screenGui.Enabled =
		true

	mainFrame.Visible =
		true

	mainFrame.Size =
		UDim2.new(
			originalFrameSize.X.Scale
				* 0.88,

			originalFrameSize.X.Offset,

			originalFrameSize.Y.Scale
				* 0.88,

			originalFrameSize.Y.Offset
		)

	TweenService:Create(
		mainFrame,
		OPEN_TWEEN,
		{
			Size =
				originalFrameSize,
		}
	):Play()
end


local function closeUI()
	if not isOpen then
		screenGui.Enabled =
			false

		return
	end

	isOpen =
		false

	local tween =
		TweenService:Create(
			mainFrame,
			CLOSE_TWEEN,
			{
				Size =
					UDim2.new(
						originalFrameSize.X.Scale
							* 0.9,

						originalFrameSize.X.Offset,

						originalFrameSize.Y.Scale
							* 0.9,

						originalFrameSize.Y.Offset
					),
			}
		)

	tween:Play()

	tween.Completed:Once(
		function()
			if isOpen then
				return
			end

			screenGui.Enabled =
				false

			mainFrame.Size =
				originalFrameSize
		end
	)
end


--==================================================
-- CARD HELPERS
--==================================================

local function clearCards()
	for _, child in
		rewardsFrame:GetChildren() do

		if child == template then
			continue
		end

		-- Keep things such as UIGridLayout,
		-- UIPadding, etc.
		if child:IsA(
			"GuiObject"
		) then

			child:Destroy()
		end
	end

	table.clear(cards)
end


--==================================================
-- CARD STATE
--==================================================

local function refreshCards()
	if not currentState then
		return
	end

	local nextDay =
		currentState.NextDay
		or 1

	local canClaim =
		currentState.CanClaim
		== true

	local lastRewardDay =
		currentState.LastClaimRewardDay
		or 0

	local completedCycleToday =
		currentState.CompletedCycleToday
		== true

	local remaining =
		currentState.SecondsUntilNextClaim
		or 0


	for day, card in cards do
		local claimButton =
			card:FindFirstChild(
				"ClaimReward"
			)

		if not claimButton
			or not claimButton:IsA(
				"TextButton"
			) then

			continue
		end


		-- Day 7 was claimed today.
		if completedCycleToday then
			setClaimButtonText(
				claimButton,
				"CLAIMED"
			)

			claimButton.Active =
				false

			claimButton.AutoButtonColor =
				false

			continue
		end


		-- Previous rewards in the current cycle.
		if day < nextDay then
			setClaimButtonText(
				claimButton,
				"CLAIMED"
			)

			claimButton.Active =
				false

			claimButton.AutoButtonColor =
				false

			continue
		end


		-- The player's current reward.
		if day == nextDay then
			if canClaim then
				setClaimButtonText(
					claimButton,
					"CLAIM"
				)

				claimButton.Active =
					not claiming

				claimButton.AutoButtonColor =
					not claiming
			else
				-- If this was the reward they just
				-- claimed, keep it saying CLAIMED.
				if lastRewardDay == day then
					setClaimButtonText(
						claimButton,
						"CLAIMED"
					)
				else
					setClaimButtonText(
						claimButton,
						formatCountdown(
							remaining
						)
					)
				end

				claimButton.Active =
					false

				claimButton.AutoButtonColor =
					false
			end

			continue
		end


		-- Future rewards.
		setClaimButtonText(
			claimButton,
			"LOCKED"
		)

		claimButton.Active =
			false

		claimButton.AutoButtonColor =
			false
	end
end


--==================================================
-- SERVER STATE
--==================================================

local function loadState(): boolean
	local success, state =
		pcall(
			function()
				return getStateRemote:
					InvokeServer()
			end
		)

	if not success then
		warn(
			"Failed to load daily reward state:",
			state
		)

		return false
	end

	if type(state) ~= "table"
		or state.Loaded ~= true then

		return false
	end

	currentState =
		state

	refreshCards()

	return true
end


--==================================================
-- COUNTDOWN
--==================================================

local function startCountdown()
	countdownToken += 1

	local myToken =
		countdownToken

	task.spawn(
		function()
			while myToken
				== countdownToken do

				if not currentState then
					return
				end

				if currentState.CanClaim then
					return
				end

				local remaining =
					currentState.SecondsUntilNextClaim
					or 0

				if remaining <= 0 then
					local loaded =
						loadState()

					if not loaded then
						task.wait(1)
						continue
					end

					if currentState.CanClaim then
						refreshCards()

						return
					end

					task.wait(1)

					continue
				end

				currentState.SecondsUntilNextClaim =
					remaining - 1

				refreshCards()

				task.wait(1)
			end
		end
	)
end


--==================================================
-- CLAIM
--==================================================

local function claimReward(
	day: number,
	claimButton: TextButton
)
	if claiming then
		return
	end

	if not currentState
		or not currentState.CanClaim
		or currentState.NextDay
			~= day then

		return
	end


	claiming =
		true

	claimButton.Active =
		false

	claimButton.AutoButtonColor =
		false

	setClaimButtonText(
		claimButton,
		"CLAIMING..."
	)


	local success, result =
		pcall(
			function()
				return claimRemote:
					InvokeServer()
			end
		)


	claiming =
		false


	if not success then
		warn(
			"Failed to claim daily reward:",
			result
		)

		refreshCards()

		return
	end


	if type(result) ~= "table" then
		warn(
			"Daily reward server returned an invalid result."
		)

		refreshCards()

		return
	end


	if result.State then
		currentState =
			result.State

		refreshCards()
	end


	if not result.Success then
		if result.Message then
			warn(
				"Daily reward claim failed:",
				result.Message
			)
		end

		return
	end


	-- Stop any old countdown that may still
	-- be running.
	countdownToken += 1


	-- Start the next reward's countdown.
	if currentState
		and not currentState.CanClaim then

		startCountdown()
	end
end


--==================================================
-- CARD CREATION
--==================================================

local function createCards()
	clearCards()

	for day = 1, 7 do
		local reward =
			DailyRewardConfig.Rewards[
				day
			]

		if not reward then
			warn(
				`Daily reward config is missing Day {day}.`
			)

			continue
		end


		local card =
			template:Clone()

		card.Name =
			`Day{day}`

		card.LayoutOrder =
			day

		card.Visible =
			true

		card.Parent =
			rewardsFrame


		local rewardName =
			card:WaitForChild(
				"RewardName"
			) :: TextLabel

		local rewardAmount =
			card:WaitForChild(
				"RewardAmount"
			) :: TextLabel

		local rewardImg =
			card:WaitForChild(
				"RewardImg"
			) :: ImageLabel

		local rewardImg2 =
			card:WaitForChild(
				"RewardImg2"
			) :: ImageLabel

		local claimButton =
			card:WaitForChild(
				"ClaimReward"
			) :: TextButton


		-- The TextButton itself should have no
		-- text. ClaimReward.Title displays it.
		claimButton.Text =
			""


		rewardName.Text =
			`DAY {day}`

		rewardAmount.Text =
			getRewardAmountText(
				reward
			)


		rewardImg.Image =
			DailyRewardConfig.Images.Cash

		rewardImg.Visible =
			true


		if reward.Boost then
			local image =
				DailyRewardConfig.Images[
					reward.Boost.Name
				]

			rewardImg2.Image =
				image or ""

			rewardImg2.Visible =
				image ~= nil
		else
			rewardImg2.Image =
				""

			rewardImg2.Visible =
				false
		end


		claimButton.Activated:Connect(
			function()
				claimReward(
					day,
					claimButton
				)
			end
		)


		cards[day] =
			card
	end
end


--==================================================
-- CONNECTIONS
--==================================================

closeButton.Activated:Connect(
	closeUI
)


--==================================================
-- INITIALIZE
--==================================================

screenGui.Enabled =
	false

mainFrame.Visible =
	true

template.Visible =
	false


createCards()


task.spawn(
	function()
		-- Give the rest of the player's UI
		-- a moment to initialize.
		task.wait(1)

		local loaded =
			loadState()

		if not loaded then
			warn(
				"Daily rewards could not be initialized."
			)

			return
		end


		openUI()
		
		if not currentState.CanClaim then
			startCountdown()
		end
	end
)