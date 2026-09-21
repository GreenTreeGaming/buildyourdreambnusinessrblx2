local Players =
	game:GetService(
		"Players"
	)

local ReplicatedStorage =
	game:GetService(
		"ReplicatedStorage"
	)

local TweenService =
	game:GetService(
		"TweenService"
	)


local player =
	Players.LocalPlayer


local playerGui =
	player:WaitForChild(
		"PlayerGui"
	)


--==================================================
-- MODULES
--==================================================

local FormatNumber =
	require(
		ReplicatedStorage
			:WaitForChild(
				"Shared"
			)
			:WaitForChild(
				"FormatNumber"
			)
	)


--==================================================
-- REMOTES
--==================================================

local remotes =
	ReplicatedStorage:WaitForChild(
		"Remotes"
	)


local getRebirthStateRemote =
	remotes:WaitForChild(
		"GetRebirthState"
	) :: RemoteFunction


local requestRebirthRemote =
	remotes:WaitForChild(
		"RequestRebirth"
	) :: RemoteFunction


local rebirthCompletedRemote =
	remotes:WaitForChild(
		"RebirthCompleted"
	) :: RemoteEvent


--==================================================
-- GUI
--==================================================

local screenGui =
	playerGui:WaitForChild(
		"Rebirth"
	)


local openButton =
	screenGui:WaitForChild(
		"OpenButton"
	) :: GuiButton


local main =
	screenGui:WaitForChild(
		"Main"
	) :: GuiObject


local closeButton =
	main:WaitForChild(
		"Close"
	) :: GuiButton


local frame =
	main:WaitForChild(
		"Frame"
	)


--==================================================
-- AMOUNT
--==================================================

local amountFrame =
	frame:WaitForChild(
		"Amount"
	)


local amountSubtitle =
	amountFrame:WaitForChild(
		"Subtitle"
	) :: TextLabel


--==================================================
-- CURRENT
--==================================================

local currentFrame =
	frame:WaitForChild(
		"Current"
	)


local currentCash =
	currentFrame:WaitForChild(
		"Cash"
	) :: TextLabel


local currentSpeed =
	currentFrame:WaitForChild(
		"Speed"
	) :: TextLabel


local currentOdds =
	currentFrame:WaitForChild(
		"Odds"
	) :: TextLabel


--==================================================
-- REQUIREMENTS
--==================================================

local requirementsFrame =
	frame:WaitForChild(
		"Requirements"
	)


local repRequirement =
	requirementsFrame:WaitForChild(
		"RepLvl"
	) :: TextLabel


local cashRequirement =
	requirementsFrame:WaitForChild(
		"CashAmnt"
	) :: TextLabel


local standRequirement =
	requirementsFrame:WaitForChild(
		"Stand"
	) :: TextLabel


local repImage =
	requirementsFrame:WaitForChild(
		"RepImage"
	) :: ImageLabel


local cashImage =
	requirementsFrame:WaitForChild(
		"CashImage"
	) :: ImageLabel


local standImage =
	requirementsFrame:WaitForChild(
		"StandImage"
	) :: ImageLabel


--==================================================
-- REWARDS
--==================================================

local gainFrame =
	frame:WaitForChild(
		"YouWillGain"
	)


local gainCash =
	gainFrame:WaitForChild(
		"Cash"
	) :: TextLabel


local gainSpeed =
	gainFrame:WaitForChild(
		"Speed"
	) :: TextLabel


local gainOdds =
	gainFrame:WaitForChild(
		"Odds"
	) :: TextLabel


--==================================================
-- REBIRTH BUTTON
--==================================================

local rebirthButton =
	frame:WaitForChild(
		"Rebirth"
	) :: TextButton


local rebirthText =
	rebirthButton:WaitForChild(
		"InText"
	) :: TextLabel


local rebirthStroke =
	rebirthButton:
		FindFirstChildOfClass(
			"UIStroke"
		)


--==================================================
-- CONSTANTS
--==================================================

local CHECK_IMAGE =
	"rbxassetid://15900022302"

local X_IMAGE =
	"rbxassetid://72291248971478"


local ENABLED_COLOR =
	Color3.fromRGB(
		24,
		238,
		0
	)


local ENABLED_STROKE =
	Color3.fromRGB(
		50,
		176,
		48
	)


local DISABLED_COLOR =
	Color3.fromRGB(
		255,
		74,
		74
	)


local DISABLED_STROKE =
	Color3.fromRGB(
		176,
		51,
		51
	)


--==================================================
-- STATE
--==================================================

local currentState = nil

local refreshing =
	false

local rebirthing =
	false

local confirmationActive =
	false

local confirmationVersion =
	0


--==================================================
-- IMAGE
--==================================================

local function setRequirementImage(
	image: ImageLabel,
	completed: boolean
)

	image.Image =
		completed
			and CHECK_IMAGE
			or X_IMAGE
end


--==================================================
-- BUTTON
--==================================================

local function setButtonState(
	enabled: boolean,
	text: string
)

	rebirthText.Text =
		text


	rebirthButton.BackgroundColor3 =
		enabled
			and ENABLED_COLOR
			or DISABLED_COLOR


	if rebirthStroke then

		rebirthStroke.Color =
			enabled
				and ENABLED_STROKE
				or DISABLED_STROKE
	end


	rebirthButton.Active =
		enabled

	rebirthButton.Selectable =
		enabled

	rebirthButton.AutoButtonColor =
		enabled
end


--==================================================
-- FORMAT GAIN
--==================================================

local function getGainText(
	amount: number,
	name: string
): string

	if amount <= 0 then

		return `{name}: MAXED`
	end


	return `+{amount}% {name}`
end


--==================================================
-- APPLY STATE
--==================================================

local function applyState(
	state
)

	if type(state)
		~= "table"
		or state.Success
			~= true then

		return
	end


	currentState =
		state


	--==================================================
	-- REBIRTH COUNT
	--==================================================

	amountSubtitle.Text =
		`REBIRTHS: {state.Rebirths or 0}`


	--==================================================
	-- CURRENT PERMANENT BONUSES
	--==================================================

	local currentBonuses =
		state.CurrentBonuses
		or {}


	currentCash.Text =
		`CASH: +{currentBonuses.CashPercent or 0}%`


	currentSpeed.Text =
		`CUSTOMER SPEED: +{currentBonuses.SpeedPercent or 0}%`


	currentOdds.Text =
		`RARE CUSTOMER ODDS: +{currentBonuses.OddsPercent or 0}%`


	--==================================================
	-- REQUIREMENTS
	--==================================================

	local requirements =
		state.Requirements
		or {}


	local rep =
		requirements.Reputation
		or {}


	local cash =
		requirements.Cash
		or {}


	local stand =
		requirements.Stand
		or {}


	repRequirement.Text =
		`REPUTATION LEVEL: {rep.Current or 1} / {rep.Required or 50}`


	cashRequirement.Text =
		`CASH: {FormatNumber.Currency(cash.Current or 0)} / {FormatNumber.Currency(cash.Required or 0)}`


	standRequirement.Text =
		`{stand.Name or "Coffee Stand"} UNLOCKED`


	setRequirementImage(
		repImage,
		rep.Met == true
	)


	setRequirementImage(
		cashImage,
		cash.Met == true
	)


	setRequirementImage(
		standImage,
		stand.Met == true
	)


	--==================================================
	-- NEXT REBIRTH REWARD
	--==================================================

	local nextGain =
		state.NextGain
		or {}


	gainCash.Text =
		getGainText(
			nextGain.CashPercent
				or 0,

			"CASH"
		)


	gainSpeed.Text =
		getGainText(
			nextGain.SpeedPercent
				or 0,

			"CUSTOMER SPEED"
		)


	gainOdds.Text =
		getGainText(
			nextGain.OddsPercent
				or 0,

			"RARE CUSTOMER ODDS"
		)


	--==================================================
	-- BUTTON
	--==================================================

	if rebirthing then

		setButtonState(
			false,
			"REBIRTHING..."
		)


	elseif state.CanRebirth
		== true then

		setButtonState(
			true,
			"REBIRTH"
		)


	else

		setButtonState(
			false,
			"REQUIREMENTS NOT MET"
		)
	end
end


--==================================================
-- REFRESH
--==================================================

local function refreshState()

	if refreshing then
		return
	end


	refreshing =
		true


	local success,
		result =
		pcall(
			function()

				return getRebirthStateRemote:
					InvokeServer()
			end
		)


	refreshing =
		false


	if not success then

		warn(
			"[Rebirth] Failed to retrieve rebirth state:",
			result
		)

		return
	end


	if type(result)
		~= "table"
		or result.Success
			~= true then

		return
	end


	applyState(
		result
	)
end


--==================================================
-- OPEN / CLOSE
--==================================================

local originalSize =
	main.Size


local uiScale =
	main:FindFirstChild(
		"RebirthOpenScale"
	)


if not uiScale then

	uiScale =
		Instance.new(
			"UIScale"
		)

	uiScale.Name =
		"RebirthOpenScale"

	uiScale.Scale =
		1

	uiScale.Parent =
		main
end


local function openMenu()

	confirmationActive =
		false

	confirmationVersion +=
		1


	main.Visible =
		true


	uiScale.Scale =
		0.92


	TweenService:Create(
		uiScale,

		TweenInfo.new(
			0.2,
			Enum.EasingStyle.Back,
			Enum.EasingDirection.Out
		),

		{
			Scale =
				1,
		}
	):Play()


	refreshState()
end


local function closeMenu()

	confirmationActive =
		false

	confirmationVersion +=
		1


	main.Visible =
		false
end


--==================================================
-- REBIRTH
--==================================================

local function performRebirth()

	if rebirthing then
		return
	end


	if not currentState
		or currentState.CanRebirth
			~= true then

		refreshState()

		return
	end


	--==================================================
	-- FIRST CLICK = CONFIRMATION
	--==================================================

	if not confirmationActive then

		confirmationActive =
			true

		confirmationVersion +=
			1


		local thisVersion =
			confirmationVersion


		setButtonState(
			true,
			"CLICK AGAIN TO CONFIRM"
		)


		task.delay(
			3,
			function()

				if confirmationVersion
						~= thisVersion
					or not confirmationActive then

					return
				end


				confirmationActive =
					false


				if currentState then

					applyState(
						currentState
					)
				end
			end
		)


		return
	end


	--==================================================
	-- SECOND CLICK = REBIRTH
	--==================================================

	confirmationActive =
		false

	confirmationVersion +=
		1


	rebirthing =
		true


	setButtonState(
		false,
		"REBIRTHING..."
	)


	local success,
		result =
		pcall(
			function()

				return requestRebirthRemote:
					InvokeServer()
			end
		)


	rebirthing =
		false


	if not success then

		warn(
			"[Rebirth] Request failed:",
			result
		)


		refreshState()

		return
	end


	if type(result)
			~= "table"
		or result.Success
			~= true then

		warn(
			"[Rebirth]",
			type(result) == "table"
				and result.Message
				or "Rebirth failed."
		)


		if type(result)
				== "table"
			and type(result.State)
				== "table" then

			applyState(
				result.State
			)

		else

			refreshState()
		end


		return
	end


	if type(result.State)
		== "table" then

		applyState(
			result.State
		)
	end


	closeMenu()
end


--==================================================
-- BUTTON CONNECTIONS
--==================================================

openButton.Activated:Connect(
	openMenu
)


closeButton.Activated:Connect(
	closeMenu
)


rebirthButton.Activated:Connect(
	performRebirth
)


--==================================================
-- SERVER COMPLETION
--==================================================

rebirthCompletedRemote.OnClientEvent:Connect(
	function(
		state
	)

		rebirthing =
			false


		if type(state)
			== "table" then

			applyState(
				state
			)
		end


		closeMenu()
	end
)


--==================================================
-- LIVE UI UPDATE
--==================================================

task.spawn(
	function()

		while screenGui.Parent do

			if main.Visible
				and not rebirthing then

				refreshState()
			end


			task.wait(
				0.75
			)
		end
	end
)


--==================================================
-- INITIAL
--==================================================

main.Visible =
	false