local Players =
	game:GetService("Players")

local ReplicatedStorage =
	game:GetService("ReplicatedStorage")

local TweenService =
	game:GetService("TweenService")


local player =
	Players.LocalPlayer


local AchievementConfig =
	require(
		ReplicatedStorage
			:WaitForChild("Shared")
			:WaitForChild("AchievementConfig")
	)


local FormatNumber =
	require(
		ReplicatedStorage
			:WaitForChild("Shared")
			:WaitForChild("FormatNumber")
	)


local Notification =
	require(
		ReplicatedStorage
			:WaitForChild("Shared")
			:WaitForChild("Notification")
	)


local remotes =
	ReplicatedStorage:WaitForChild(
		"Remotes"
	)


local getAchievementState =
	remotes:WaitForChild(
		"GetAchievementState"
	) :: RemoteFunction


local claimAchievement =
	remotes:WaitForChild(
		"ClaimAchievement"
	) :: RemoteFunction


local achievementStateUpdated =
	remotes:WaitForChild(
		"AchievementStateUpdated"
	) :: RemoteEvent


--==================================================
-- UI
--==================================================

local playerGui =
	player:WaitForChild(
		"PlayerGui"
	)


local screenGui =
	playerGui:WaitForChild(
		"Achievements"
	)


local main =
	screenGui:WaitForChild(
		"Main"
	) :: Frame


local openButton =
	screenGui:WaitForChild(
		"OpenButton"
	) :: TextButton

local updateFrame =
	openButton:WaitForChild(
		"Update"
	) :: Frame


local closeButton =
	main:WaitForChild(
		"Close"
	) :: TextButton


local categoriesFrame =
	main:WaitForChild(
		"Categories"
	) :: Frame


local categoryTemplate =
	categoriesFrame:WaitForChild(
		"Template"
	) :: TextButton


local achievementFrame =
	main:WaitForChild(
		"Achievements"
	) :: ScrollingFrame


local achievementTemplate =
	achievementFrame:WaitForChild(
		"Template"
	) :: Frame


local overallProgress =
	main:WaitForChild(
		"Background"
	) :: Frame


local overallBar =
	overallProgress:WaitForChild(
		"Bar"
	) :: Frame


local overallPercent =
	overallProgress:WaitForChild(
		"PercentCompleted"
	) :: TextLabel


local overallAmount =
	overallProgress:WaitForChild(
		"AmountCompleted"
	) :: TextLabel


local upcomingTiers =
	main:WaitForChild(
		"UpcomingTiers"
	) :: Frame


local upcomingContainer =
	upcomingTiers:WaitForChild(
		"Frame"
	) :: Frame


local upcomingTemplate =
	upcomingContainer:WaitForChild(
		"Template"
	) :: Frame


--==================================================
-- CONSTANTS
--==================================================

local OPEN_TWEEN =
	TweenInfo.new(
		0.22,
		Enum.EasingStyle.Back,
		Enum.EasingDirection.Out
	)


local CLOSE_TWEEN =
	TweenInfo.new(
		0.14,
		Enum.EasingStyle.Quad,
		Enum.EasingDirection.In
	)


local PROGRESS_TWEEN =
	TweenInfo.new(
		0.3,
		Enum.EasingStyle.Quint,
		Enum.EasingDirection.Out
	)


local CLAIM_COLOR =
	Color3.fromRGB(
		51,
		232,
		0
	)


local CLAIMED_COLOR =
	Color3.fromRGB(
		50,
		168,
		75
	)


local IN_PROGRESS_COLOR =
	Color3.fromRGB(
		45,
		130,
		200
	)


local MAXED_COLOR =
	Color3.fromRGB(
		75,
		170,
		90
	)


--==================================================
-- LOCAL STATE
--==================================================

local renderState

local selectedCategory =
	"All"


local currentState: any =
	nil


local categoryButtons: {
	[string]: TextButton
} = {}


local achievementCards: {
	[string]: Frame
} = {}


local claimDebounces: {
	[string]: boolean
} = {}

--==================================================
-- INPUT / ZINDEX FIXES
--==================================================

openButton.Active = true
openButton.Interactable = true
openButton.ZIndex = 20

closeButton.Active = true
closeButton.Interactable = true
closeButton.ZIndex = 30

local closeX =
	closeButton:FindFirstChild("X")

if closeX and closeX:IsA("GuiObject") then
	closeX.ZIndex = 31
end

categoriesFrame.ZIndex = 10

achievementFrame.ZIndex = 5


--==================================================
-- SCALE / OPEN ANIMATION
--==================================================

local uiScale =
	main:FindFirstChildOfClass(
		"UIScale"
	)


if not uiScale then

	uiScale =
		Instance.new(
			"UIScale"
		)

	uiScale.Scale = 1
	uiScale.Parent = main
end


main.Visible = false

updateFrame.Visible = false

categoryTemplate.Visible = false
achievementTemplate.Visible = false
upcomingTemplate.Visible = false


--==================================================
-- FORMAT HELPERS
--==================================================

local function formatNumber(
	value: number
): string

	return FormatNumber.Compact(
		value
	)
end


local function formatMoney(
	value: number
): string

	return "$"
		.. formatNumber(
			value
		)
end


local ROMAN_NUMERALS = {
	[1] = "I",
	[2] = "II",
	[3] = "III",
	[4] = "IV",
	[5] = "V",
	[6] = "VI",
	[7] = "VII",
	[8] = "VIII",
	[9] = "IX",
	[10] = "X",
}


local function romanNumeral(
	value: number
): string

	return ROMAN_NUMERALS[value]
		or tostring(value)
end


local function formatProgress(
	progress: number,
	goal: number
): string

	local displayedProgress =
		math.min(
			progress,
			goal
		)

	return formatNumber(
		displayedProgress
	)
		.. "/"
		.. formatNumber(goal)
end

local function getRatio(
	progress: number,
	goal: number
): number

	if goal <= 0 then
		return 0
	end


	return math.clamp(
		progress / goal,
		0,
		1
	)
end

local function renderUpdateIndicator(
	state: any
)
	local claimableCount =
		state.ClaimableCount
		or 0

	updateFrame.Visible =
		claimableCount > 0
end


local function setProgressBar(
	background: Frame,
	progress: number,
	goal: number,
	animated: boolean?
)

	local bar =
		background:FindFirstChild(
			"Bar"
		)


	if not bar
		or not bar:IsA("Frame") then

		return
	end


	local ratio =
		getRatio(
			progress,
			goal
		)


	local target =
		UDim2.new(
			ratio,
			0,
			bar.Size.Y.Scale,
			bar.Size.Y.Offset
		)


	if animated then

		TweenService:Create(
			bar,
			PROGRESS_TWEEN,

			{
				Size = target,
			}
		):Play()

	else

		bar.Size =
			target
	end
end


--==================================================
-- WINDOW
--==================================================

local function openWindow()
	if main.Visible then
		return
	end

	main.Visible = true

	-- Keep the achievements side button visible.
	openButton.Visible = true

	uiScale.Scale = 0.92

	TweenService:Create(
		uiScale,
		OPEN_TWEEN,
		{
			Scale = 1,
		}
	):Play()
end


local function closeWindow()
	if not main.Visible then
		return
	end

	local tween =
		TweenService:Create(
			uiScale,
			CLOSE_TWEEN,
			{
				Scale = 0.92,
			}
		)

	tween:Play()

	tween.Completed:Once(function()
		main.Visible = false
		uiScale.Scale = 1

		-- Never hide the open button.
		openButton.Visible = true
	end)
end


openButton.Active = true
openButton.Interactable = true

closeButton.Active = true
closeButton.Interactable = true

openButton.Activated:Connect(openWindow)
closeButton.Activated:Connect(closeWindow)

--==================================================
-- CATEGORY BUTTONS
--==================================================

local function updateCategoryVisuals()
	for categoryId, button in categoryButtons do
		local selected =
			categoryId == selectedCategory

		local stroke =
			button:FindFirstChildOfClass(
				"UIStroke"
			)

		if stroke then
			stroke.Thickness =
				selected and 4 or 2
		end

		button.BackgroundTransparency =
			selected and 0 or 0.12
	end
end


local function selectCategory(
	categoryId: string
)
	if selectedCategory == categoryId then
		return
	end

	selectedCategory = categoryId

	updateCategoryVisuals()

	if currentState then
		renderState(currentState)
	end
end


local function createCategoryButtons()
	for _, category in
		AchievementConfig.Categories do
		local button =
			categoryTemplate:Clone()

		button.Name = category.Id
		button.LayoutOrder = category.Order
		button.Visible = true

		button.Active = true
		button.Interactable = true
		button.AutoButtonColor = true

		button.ZIndex = 15

		local text =
			button:FindFirstChild(
				"InText"
			)

		if text
			and text:IsA(
				"TextLabel"
			) then

			text.Text =
				category.DisplayName

			text.ZIndex = 16
		end

		button.Parent =
			categoriesFrame

		categoryButtons[
			category.Id
		] = button

		button.Activated:Connect(
			function()
				selectCategory(
					category.Id
				)
			end
		)
	end

	updateCategoryVisuals()
end

--==================================================
-- CLEAR GENERATED UI
--==================================================

local function clearAchievementCards()

	for _, card in
		achievementCards do

		if card.Parent then
			card:Destroy()
		end
	end


	table.clear(
		achievementCards
	)
end


local function clearUpcomingCards()

	for _, child in
		upcomingContainer:GetChildren() do

		if child == upcomingTemplate
			or child:IsA(
				"UIGridLayout"
			)
			or child:IsA(
				"UIListLayout"
			)
			or child:IsA(
				"UIPadding"
			) then

			continue
		end


		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
end


--==================================================
-- CLAIM BUTTON
--==================================================


local function requestClaim(
	entry: any
)

	if claimDebounces[
		entry.Id
	] then

		return
	end


	claimDebounces[
		entry.Id
	] = true


	local success, result =
		pcall(
			function()

				return claimAchievement
					:InvokeServer(
						entry.Id
					)
			end
		)


	claimDebounces[
		entry.Id
	] = nil


	if not success then

		Notification.Info(
			"Could not claim this achievement.",

			{
				Title =
					"Achievements",

				Duration =
					3,
			}
		)

		return
	end


	if type(result) ~= "table"
		or result.Success ~= true then

		local message =
			type(result) == "table"
			and result.Message
			or "Could not claim this achievement."


		Notification.Info(
			message,

			{
				Title =
					"Achievements",

				Duration =
					3,
			}
		)

		return
	end


	Notification.Success(
		`You earned ${formatNumber(result.Reward or 0)}!`,

		{
			Title =
				`{result.AchievementName} {romanNumeral(result.Tier or 1)}`,

			Duration =
				4,
		}
	)


	if result.State then

		renderState(
			result.State
		)
	end
end


--==================================================
-- ACHIEVEMENT CARD
--==================================================

local function configureClaimButton(
	card: Frame,
	entry: any
)

	local buy =
		card:WaitForChild(
			"Buy"
		) :: TextButton

	local buttonText =
		buy:WaitForChild(
			"InText"
		) :: TextLabel

	buy.Text = ""

	--==================================================
	-- MAXED
	--==================================================

	if entry.Maxed then
		buy.Visible = true

		buttonText.Text =
			"MAXED"

		buy.BackgroundColor3 =
			MAXED_COLOR

		buy.Active = false
		buy.Interactable = false
		buy.AutoButtonColor = false

		return
	end


	--==================================================
	-- CLAIMABLE
	--==================================================

	if entry.Claimable then
		buy.Visible = true

		buttonText.Text =
			"CLAIM"

		buy.BackgroundColor3 =
			CLAIM_COLOR

		buy.Active = true
		buy.Interactable = true
		buy.AutoButtonColor = true

		buy.Activated:Connect(
			function()
				requestClaim(entry)
			end
		)

		return
	end


	--==================================================
	-- STILL IN PROGRESS
	--==================================================

	-- The progress bar already communicates
	-- that the achievement isn't finished.
	-- Don't show a fake unusable button.

	buy.Visible = false
end

local function createAchievementCard(
	entry: any,
	layoutOrder: number
)

	local card =
		achievementTemplate:Clone()


	card.Name =
		entry.Id


	card.LayoutOrder =
	layoutOrder


	card.Visible = true


	local achievementName =
		card:WaitForChild(
			"AchievementName"
		) :: TextLabel


	local description =
		card:WaitForChild(
			"AchievementDesc"
		) :: TextLabel


	local reward =
		card:WaitForChild(
			"Reward"
		) :: TextLabel


	local progressBackground =
		card:WaitForChild(
			"Background"
		) :: Frame


	local progressText =
		progressBackground
			:WaitForChild(
				"PercentCompleted"
			) :: TextLabel


	achievementName.Text =
		`{entry.DisplayName} {romanNumeral(entry.Tier)}`


	description.Text =
		entry.Description


	reward.Text =
		formatMoney(
			entry.Reward
		)


	progressText.Text =
		formatProgress(
			entry.Progress,
			entry.Goal
		)


	setProgressBar(
		progressBackground,
		entry.Progress,
		entry.Goal,
		true
	)


	configureClaimButton(
		card,
		entry
	)


	card.Parent =
		achievementFrame


	achievementCards[
		entry.Id
	] = card
end


--==================================================
-- UPCOMING TIERS
--==================================================

local function getUpcomingEntries(
	state: any
): {any}

	local results = {}


	for _, entry in
		state.Achievements do

		if selectedCategory
				~= "All"
			and entry.Category
				~= selectedCategory then

			continue
		end


		if not entry.NextTier then
			continue
		end


		table.insert(
			results,

			{
				DisplayName =
					entry.DisplayName,

				Tier =
					entry.NextTier.Tier,

				Reward =
					entry.NextTier.Reward,

				Order =
					entry.Order
					or 0,
			}
		)
	end


	table.sort(
		results,

		function(
			first,
			second
		)

			return first.Order
				< second.Order
		end
	)


	return results
end


local function renderUpcomingTiers(
	state: any
)

	clearUpcomingCards()


	local entries =
		getUpcomingEntries(
			state
		)


	local maximum =
		math.min(
			3,
			#entries
		)


	for index = 1,
		maximum do

		local entry =
			entries[index]


		local card =
			upcomingTemplate:Clone()


		card.Name =
			`Upcoming_{index}`


		card.LayoutOrder =
			index


		card.Visible =
			true


		local name =
			card:WaitForChild(
				"AchievementName"
			) :: TextLabel


		local reward =
			card:WaitForChild(
				"Reward"
			) :: TextLabel


		name.Text =
			`{entry.DisplayName} {romanNumeral(entry.Tier)}`


		reward.Text =
			formatMoney(
				entry.Reward
			)


		card.Parent =
			upcomingContainer
	end
end


--==================================================
-- OVERALL PROGRESS
--==================================================

local function renderOverallProgress(
	state: any
)

	local completed =
		state.Completed
		or 0


	local total =
		state.Total
		or 0


	local percent =
		math.clamp(
			state.Percent
				or 0,
			0,
			1
		)


	overallAmount.Text =
		`{completed}/{total} Completed`


	overallPercent.Text =
		`{math.floor(percent * 100 + 0.5)}% Complete`


	TweenService:Create(
		overallBar,
		PROGRESS_TWEEN,

		{
			Size =
				UDim2.new(
					percent,
					0,
					overallBar
						.Size
						.Y
						.Scale,

					overallBar
						.Size
						.Y
						.Offset
				),
		}
	):Play()
end


--==================================================
-- RENDER EVERYTHING
--==================================================

renderState =
	function(
		state: any
	)

		if type(state) ~= "table"
			or type(state.Achievements)
				~= "table" then

			return
		end


		currentState =
			state


		clearAchievementCards()

local visibleAchievements = {}

for _, entry in state.Achievements do
	if selectedCategory ~= "All"
		and entry.Category ~= selectedCategory then

		continue
	end

	table.insert(
		visibleAchievements,
		entry
	)
end


table.sort(
	visibleAchievements,

	function(first, second)

		-- Claimable achievements always come first.
		if first.Claimable ~= second.Claimable then
			return first.Claimable
		end


		-- Non-maxed achievements come before maxed ones.
		if first.Maxed ~= second.Maxed then
			return not first.Maxed
		end


		-- Otherwise preserve normal achievement order.
		if first.Order ~= second.Order then
			return first.Order < second.Order
		end


		return first.Id < second.Id
	end
)


for index, entry in visibleAchievements do
	createAchievementCard(
		entry,
		index
	)
end

		renderUpcomingTiers(
	state
)


renderOverallProgress(
	state
)


renderUpdateIndicator(
	state
)
	end


--==================================================
-- CATEGORY RE-RENDER
--==================================================


createCategoryButtons()

--==================================================
-- SERVER UPDATES
--==================================================

achievementStateUpdated
	.OnClientEvent
	:Connect(
		function(
			state: any
		)

			renderState(
				state
			)
		end
	)


--==================================================
-- INITIAL LOAD
--==================================================

task.spawn(
	function()

		local success, state =
			pcall(
				function()

					return getAchievementState
						:InvokeServer()
				end
			)


		if not success then

			warn(
				"[Achievements] Failed to load achievement state."
			)

			return
		end


		if state then

			renderState(
				state
			)
		end
	end
)