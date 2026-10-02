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


local licensesAmount =
	topGui:WaitForChild(
		"LicensesAmount"
	) :: Frame


local licensesLabel =
	licensesAmount:WaitForChild(
		"Title"
	) :: TextLabel


--==================================================
-- CONFIG
--==================================================

local NUMBER_ANIMATION_TIME =
	0.35


local INCREASE_SCALE =
	1.12


local DECREASE_SCALE =
	0.92


local SCALE_RETURN_TIME =
	0.18


--==================================================
-- UI SETUP
--==================================================

local textScale =
	licensesLabel:FindFirstChild(
		"LicensesTextScale"
	)


if not textScale then

	textScale =
		Instance.new(
			"UIScale"
		)


	textScale.Name =
		"LicensesTextScale"


	textScale.Scale =
		1


	textScale.Parent =
		licensesLabel
end


textScale =
	textScale :: UIScale


--==================================================
-- STATE
--==================================================

local displayedLicenses =
	0


local animationVersion =
	0


local activeScaleTween:
	Tween? =
	nil


--==================================================
-- HELPERS
--==================================================

local function getLicenses():
	number

	local value =
		player:GetAttribute(
			"Licenses"
		)


	if typeof(value)
		~= "number" then

		return 0
	end


	return math.max(
		0,
		math.floor(
			value
		)
	)
end


local function setLicensesText(
	value: number
)

	licensesLabel.Text =
		FormatNumber.Compact(
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


local function animateLicenseChange(
	newLicenses: number
)

	newLicenses =
		math.max(
			0,
			math.floor(
				newLicenses
			)
		)


	local startingLicenses =
		displayedLicenses


	if newLicenses
		== startingLicenses then

		setLicensesText(
			newLicenses
		)

		return
	end


	animationVersion += 1


	local currentVersion =
		animationVersion


	local difference =
		newLicenses
			- startingLicenses


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


		local easedAlpha =
			1
				- (
					1 - alpha
				) ^ 2


		local currentValue =
			startingLicenses
				+ difference
					* easedAlpha


		displayedLicenses =
			math.floor(
				currentValue
					+ 0.5
			)


		setLicensesText(
			displayedLicenses
		)


		if alpha >= 1 then
			break
		end


		task.wait()
	end


	if currentVersion
		~= animationVersion then

		return
	end


	displayedLicenses =
		newLicenses


	setLicensesText(
		newLicenses
	)
end


--==================================================
-- LICENSE CHANGES
--==================================================

player:GetAttributeChangedSignal(
	"Licenses"
):Connect(
	function()

		local newLicenses =
			getLicenses()


		task.spawn(
			function()

				animateLicenseChange(
					newLicenses
				)
			end
		)
	end
)


--==================================================
-- INITIAL DISPLAY
--==================================================

displayedLicenses =
	getLicenses()


setLicensesText(
	displayedLicenses
)