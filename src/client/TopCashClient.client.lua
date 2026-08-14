local Players =
	game:GetService("Players")

local ReplicatedStorage =
	game:GetService("ReplicatedStorage")

local TweenService =
	game:GetService("TweenService")


local FormatNumber =
	require(
		ReplicatedStorage
			:WaitForChild("Shared")
			:WaitForChild("FormatNumber")
	)


local player =
	Players.LocalPlayer


local playerGui =
	player:WaitForChild(
		"PlayerGui"
	)


local topGui =
	playerGui:WaitForChild(
		"Top"
	) :: ScreenGui


local cashAmount =
	topGui:WaitForChild(
		"CashAmount"
	) :: Frame


local cashLabel =
	cashAmount:WaitForChild(
		"Title"
	) :: TextLabel


local leaderstats =
	player:WaitForChild(
		"leaderstats"
	)


local cashValue =
	leaderstats:WaitForChild(
		"Cash"
	) :: IntValue


--==================================================
-- CONFIG
--==================================================

-- How long the number rolls toward the new value.
local NUMBER_ANIMATION_TIME =
	0.35


-- Small pop when cash increases.
local INCREASE_SCALE =
	1.12


-- Small squash when money is spent.
local DECREASE_SCALE =
	0.92


-- How quickly the text returns to normal size.
local SCALE_RETURN_TIME =
	0.18


--==================================================
-- UI SETUP
--==================================================

local textScale =
	cashLabel:FindFirstChild(
		"CashTextScale"
	)


if not textScale then

	textScale =
		Instance.new(
			"UIScale"
		)


	textScale.Name =
		"CashTextScale"


	textScale.Scale =
		1


	textScale.Parent =
		cashLabel
end


textScale =
	textScale :: UIScale


--==================================================
-- STATE
--==================================================

local displayedCash =
	cashValue.Value


local animationVersion =
	0


local activeScaleTween:
	Tween? =
	nil


--==================================================
-- HELPERS
--==================================================

local function setCashText(
	value: number
)

	cashLabel.Text =
		FormatNumber.Currency(
			math.max(
				0,
				value
			),
			1
		)
end


local function stopScaleTween()

	if activeScaleTween then

		activeScaleTween:Cancel()

		activeScaleTween =
			nil
	end
end


local function animateScale(
	targetScale: number
)

	stopScaleTween()


	textScale.Scale =
		targetScale


	local tween =
		TweenService:Create(
			textScale,

			TweenInfo.new(
				SCALE_RETURN_TIME,
				Enum.EasingStyle.Back,
				Enum.EasingDirection.Out
			),

			{
				Scale = 1,
			}
		)


	activeScaleTween =
		tween


	tween.Completed:Once(
		function()

			if activeScaleTween
				== tween then

				activeScaleTween =
					nil
			end
		end
	)


	tween:Play()
end


local function animateCashChange(
	newCash: number
)

	newCash =
		math.max(
			0,
			math.floor(
				newCash
			)
		)


	local startingCash =
		displayedCash


	if newCash == startingCash then

		setCashText(
			newCash
		)

		return
	end


	animationVersion += 1


	local currentVersion =
		animationVersion


	local difference =
		newCash
			- startingCash


	-- Visual feedback immediately tells the player
	-- whether money was earned or spent.
	if difference > 0 then

		animateScale(
			INCREASE_SCALE
		)

	else

		animateScale(
			DECREASE_SCALE
		)
	end


	local startedAt =
		os.clock()


	while currentVersion
			== animationVersion do

		local elapsed =
			os.clock()
				- startedAt


		local alpha =
			math.clamp(
				elapsed
					/ NUMBER_ANIMATION_TIME,

				0,
				1
			)


		-- Quad-out gives the counter a quick start
		-- and smooth finish.
		local easedAlpha =
			1
				- (
					1 - alpha
				) ^ 2


		local currentValue =
			startingCash
				+ difference
					* easedAlpha


		displayedCash =
			math.floor(
				currentValue
					+ 0.5
			)


		setCashText(
			displayedCash
		)


		if alpha >= 1 then
			break
		end


		task.wait()
	end


	-- Only the newest animation is allowed to
	-- finalize the displayed value.
	if currentVersion
		~= animationVersion then

		return
	end


	displayedCash =
		newCash


	setCashText(
		newCash
	)
end


--==================================================
-- CASH CHANGES
--==================================================

cashValue:GetPropertyChangedSignal(
	"Value"
):Connect(
	function()

		local newCash =
			cashValue.Value


		task.spawn(
			function()

				animateCashChange(
					newCash
				)
			end
		)
	end
)


--==================================================
-- INITIAL DISPLAY
--==================================================

displayedCash =
	cashValue.Value


setCashText(
	displayedCash
)