local Players =
	game:GetService("Players")

local ReplicatedStorage =
	game:GetService("ReplicatedStorage")

local TweenService =
	game:GetService("TweenService")

local Workspace =
	game:GetService("Workspace")


local player =
	Players.LocalPlayer

local playerGui =
	player:WaitForChild(
		"PlayerGui"
	)

local camera =
	Workspace.CurrentCamera


local plotsFolder =
	Workspace:WaitForChild(
		"Plots"
	)


local shared =
	ReplicatedStorage:WaitForChild(
		"Shared"
	)


local BusinessConfig =
	require(
		shared:WaitForChild(
			"BusinessConfig"
		)
	)


local remotes =
	ReplicatedStorage:WaitForChild(
		"Remotes"
	)


local getTutorialStateRemote =
	remotes:WaitForChild(
		"GetTutorialState"
	) :: RemoteFunction


local completeTutorialRemote =
	remotes:WaitForChild(
		"CompleteTutorial"
	) :: RemoteEvent


--==================================================
-- TUTORIAL UI
--==================================================

local tutorialGui =
	playerGui:WaitForChild(
		"Tutorial"
	) :: ScreenGui


local tutorialFrame =
	tutorialGui:WaitForChild(
		"Frame"
	) :: Frame


local skipButton =
	tutorialFrame:WaitForChild(
		"SkipBtn"
	) :: GuiButton


local title =
	tutorialFrame:WaitForChild(
		"Title"
	) :: TextLabel


local tutorialText =
	tutorialFrame:WaitForChild(
		"TutorialText"
	) :: TextLabel


--==================================================
-- ADD BUSINESS UI
--==================================================

local addBusinessGui =
	playerGui:WaitForChild(
		"AddBusiness"
	) :: ScreenGui


local addButton =
	addBusinessGui:WaitForChild(
		"Add"
	) :: TextButton


local addFrame =
	addBusinessGui:WaitForChild(
		"AddFrame"
	) :: Frame


local businessScrollingFrame =
	addFrame:WaitForChild(
		"ScrollingFrame"
	) :: ScrollingFrame


local addButtons =
	addBusinessGui:WaitForChild(
		"AddButtons"
	) :: Frame


--==================================================
-- QUEST UI
--==================================================

local questsGui =
	playerGui:WaitForChild(
		"Quests"
	) :: ScreenGui


local questsMain =
	questsGui:WaitForChild(
		"Main"
	) :: Frame


local questsOpenButton =
	questsGui:WaitForChild(
		"OpenButton"
	) :: TextButton


--==================================================
-- MANAGE UI
--==================================================

local manageGui =
	playerGui:WaitForChild(
		"ManageStand"
	) :: ScreenGui


local manageMain =
	manageGui:WaitForChild(
		"Main"
	) :: Frame


--==================================================
-- DAILY REWARDS
--==================================================

local dailyRewardsGui =
	playerGui:FindFirstChild(
		"DailyRewards"
	) :: ScreenGui?


--==================================================
-- CASH
--==================================================

local leaderstats =
	player:WaitForChild(
		"leaderstats"
	)


local cash =
	leaderstats:WaitForChild(
		"Cash"
	) :: IntValue


--==================================================
-- POSITIONS
--==================================================

local HIDDEN_POSITION =
	UDim2.new(
		0.5,
		0,
		1.1,
		0
	)


local NORMAL_POSITION =
	UDim2.new(
		0.5,
		0,
		0.731,
		0
	)


local SIDE_POSITION =
	UDim2.new(
		0.882,
		0,
		0.731,
		0
	)


--==================================================
-- TIMING
--==================================================
--
-- Tutorial pacing should feel calm and readable.
--
-- Informational messages remain visible long enough
-- for a new player to actually read them, while
-- action instructions stay visible until the player
-- performs the requested action.
--==================================================

local FRAME_TWEEN_TIME =
	0.30


local TEXT_FADE_TIME =
	0.16


local TEXT_CLEAR_DELAY =
	0.18


local CAMERA_TWEEN_TIME =
	0.65


local CAMERA_HOLD_TIME =
	0.85


-- Short confirmation / encouragement.
local SHORT_MESSAGE_TIME =
	3.0


-- Normal one-sentence explanation.
local NORMAL_MESSAGE_TIME =
	4.0


-- Longer explanation with multiple ideas.
local LONG_MESSAGE_TIME =
	5.25


-- Small pause after the player completes an action.
-- Gives them time to see the result before the
-- tutorial immediately asks for something else.
local ACTION_RESULT_PAUSE =
	0.75


-- Used for especially important moments such as
-- the first sale and first upgrade.
local MAJOR_RESULT_PAUSE =
	1.0

--==================================================
-- TWEEN INFO
--==================================================

local frameTweenInfo =
	TweenInfo.new(
		FRAME_TWEEN_TIME,
		Enum.EasingStyle.Quint,
		Enum.EasingDirection.Out
	)


local cameraTweenInfo =
	TweenInfo.new(
		CAMERA_TWEEN_TIME,
		Enum.EasingStyle.Quint,
		Enum.EasingDirection.InOut
	)


local textTweenInfo =
	TweenInfo.new(
		TEXT_FADE_TIME,
		Enum.EasingStyle.Quad,
		Enum.EasingDirection.Out
	)


--==================================================
-- STATE
--==================================================

local running =
	false


local tutorialThread:
	thread? =
	nil


local activeFrameTween:
	Tween? =
	nil


local activeTextTween:
	Tween? =
	nil


local activeHighlight:
	Frame? =
	nil


local activeHighlightPulseThread:
	thread? =
	nil


local dailyRewardsConnection:
	RBXScriptConnection? =
	nil


local TUTORIAL_HIGHLIGHT_COLOR =
	Color3.fromRGB(
		255,
		223,
		102
	)


local TUTORIAL_HIGHLIGHT_FILL_TRANSPARENCY =
	0.86


local TUTORIAL_HIGHLIGHT_IDLE_TRANSPARENCY =
	0.18


local TUTORIAL_HIGHLIGHT_PULSE_TRANSPARENCY =
	0.45


local TUTORIAL_HIGHLIGHT_THICKNESS =
	3


local TUTORIAL_HIGHLIGHT_PULSE_THICKNESS =
	5


local TUTORIAL_HIGHLIGHT_SIZE_OFFSET =
	18


local TUTORIAL_HIGHLIGHT_PULSE_SCALE =
	1.06


local TUTORIAL_HIGHLIGHT_PULSE_TIME =
	0.55


--==================================================
-- FRAME HELPERS
--==================================================

local function cancelFrameTween()

	if activeFrameTween then

		activeFrameTween:Cancel()

		activeFrameTween =
			nil
	end
end


local function tweenFrameTo(
	position: UDim2
)

	cancelFrameTween()


	activeFrameTween =
		TweenService:Create(
			tutorialFrame,
			frameTweenInfo,
			{
				Position =
					position,
			}
		)


	activeFrameTween:Play()

	activeFrameTween.Completed:Wait()


	activeFrameTween =
		nil
end


--==================================================
-- TEXT HELPERS
--==================================================

local function tweenTextTransparency(
	transparency: number
)

	if activeTextTween then

		activeTextTween:Cancel()

		activeTextTween =
			nil
	end


	activeTextTween =
		TweenService:Create(
			tutorialText,
			textTweenInfo,
			{
				TextTransparency =
					transparency,
			}
		)


	activeTextTween:Play()

	activeTextTween.Completed:Wait()


	activeTextTween =
		nil
end


local function clearText()

	tweenTextTransparency(
		1
	)


	tutorialText.Text =
		""


	task.wait(
		TEXT_CLEAR_DELAY
	)
end


local function setTutorialText(
	text: string
)

	clearText()


	tutorialText.Text =
		text


	tweenTextTransparency(
		0
	)
end


local function showTimedMessage(
	text: string,
	duration: number?
)

	setTutorialText(
		text
	)


	task.wait(
		duration
			or NORMAL_MESSAGE_TIME
	)
end


--==================================================
-- DAILY REWARD SUPPRESSION
--==================================================
--
-- Daily Rewards normally auto-opens shortly after
-- joining. Prevent it from covering the first-time
-- tutorial, then show it after the tutorial finishes.
--==================================================

local function beginSuppressingDailyRewards()

	dailyRewardsGui =
		playerGui:FindFirstChild(
			"DailyRewards"
		) :: ScreenGui?


	if not dailyRewardsGui then
		return
	end


	dailyRewardsGui.Enabled =
		false


	if dailyRewardsConnection then

		dailyRewardsConnection:Disconnect()

		dailyRewardsConnection =
			nil
	end


	dailyRewardsConnection =
		dailyRewardsGui
			:GetPropertyChangedSignal(
				"Enabled"
			)
			:Connect(
				function()

					if running
						and dailyRewardsGui
						.Enabled then

						dailyRewardsGui.Enabled =
							false
					end
				end
			)
end


local function stopSuppressingDailyRewards(
	showRewards: boolean
)

	if dailyRewardsConnection then

		dailyRewardsConnection:Disconnect()

		dailyRewardsConnection =
			nil
	end


	if showRewards
		and dailyRewardsGui
		and dailyRewardsGui.Parent then

		dailyRewardsGui.Enabled =
			true
	end
end


--==================================================
-- PLOT HELPERS
--==================================================

local function getOwnedPlot():
	Model?

	local plotName =
		player:GetAttribute(
			"PlotName"
		)


	if typeof(plotName)
		== "string" then

		local plot =
			plotsFolder:FindFirstChild(
				plotName
			)


		if plot
			and plot:IsA(
				"Model"
			)
			and plot:GetAttribute(
				"OwnerUserId"
			) == player.UserId then

			return plot
		end
	end


	for _, plot in
		plotsFolder:GetChildren()
	do

		if not plot:IsA(
			"Model"
		) then

			continue
		end


		if plot:GetAttribute(
			"OwnerUserId"
		) == player.UserId then

			return plot
		end
	end


	return nil
end


local function waitForOwnedPlot():
	Model

	while player.Parent do

		local plot =
			getOwnedPlot()


		if plot then
			return plot
		end


		task.wait(
			0.1
		)
	end


	error(
		"Player left before tutorial plot was found."
	)
end


local function getPlacedBusinesses(
	plot: Model
): Instance

	local existing =
		plot:FindFirstChild(
			"PlacedBusinesses"
		)


	if existing then
		return existing
	end


	return plot:WaitForChild(
		"PlacedBusinesses"
	)
end


local function getBusinessType(
	stand: Model
): string

	local businessType =
		stand:GetAttribute(
			"BusinessType"
		)


	if typeof(businessType)
			== "string"
		and businessType ~= "" then

		return businessType
	end


	return stand.Name
end


local function findLemonadeStand(
	plot: Model
): Model?

	local placedBusinesses =
		getPlacedBusinesses(
			plot
		)


	for _, child in
		placedBusinesses:GetChildren()
	do

		if not child:IsA(
			"Model"
		) then

			continue
		end


		if child:GetAttribute(
			"OwnerUserId"
		) ~= player.UserId then

			continue
		end


		if getBusinessType(
			child
		) == "LemonadeStand" then

			return child
		end
	end


	return nil
end


local function waitForLemonadeStand(
	plot: Model
): Model

	local existing =
		findLemonadeStand(
			plot
		)


	if existing then
		return existing
	end


	local placedBusinesses =
		getPlacedBusinesses(
			plot
		)


	while player.Parent do

		local child =
			placedBusinesses
				.ChildAdded
				:Wait()


		if not child:IsA(
			"Model"
		) then

			continue
		end


		-- Give placement code one frame to finish
		-- setting the model's attributes.
		task.wait()


		if child:GetAttribute(
			"OwnerUserId"
		) ~= player.UserId then

			continue
		end


		if getBusinessType(
			child
		) == "LemonadeStand" then

			return child
		end
	end


	error(
		"Player left while waiting for Lemonade Stand."
	)
end


--==================================================
-- FIRST SALE
--==================================================

local function getTotalSales(
	stand: Model
): number

	local sales =
		stand:GetAttribute(
			"TotalSales"
		)


	if typeof(sales)
		~= "number" then

		return 0
	end


	return math.max(
		0,
		math.floor(
			sales
		)
	)
end


local function waitForFirstSale(
	stand: Model
)

	if getTotalSales(
		stand
	) >= 1 then

		return
	end


	while player.Parent
		and stand.Parent do

		stand:GetAttributeChangedSignal(
			"TotalSales"
		):Wait()


		if getTotalSales(
			stand
		) >= 1 then

			return
		end
	end
end


--==================================================
-- CAMERA
--==================================================

local function showPlotCamera(
	plot: Model
)

	local tutorialFolder =
		plot:FindFirstChild(
			"Tutorial"
		)


	if not tutorialFolder then

		warn(
			`{plot.Name} is missing its Tutorial folder.`
		)

		return
	end


	local cameraPart =
		tutorialFolder:FindFirstChild(
			"1"
		)


	if not cameraPart
		or not cameraPart:IsA(
			"BasePart"
		) then

		warn(
			`{plot.Name}.Tutorial is missing BasePart "1".`
		)

		return
	end


	local previousCameraType =
		camera.CameraType


	local previousCameraSubject =
		camera.CameraSubject


	local previousCFrame =
		camera.CFrame


	camera.CameraType =
		Enum.CameraType.Scriptable


	local moveTween =
		TweenService:Create(
			camera,
			cameraTweenInfo,
			{
				CFrame =
					cameraPart.CFrame,
			}
		)


	moveTween:Play()

	moveTween.Completed:Wait()


	showTimedMessage(
		"This is your plot. Turn it into a business empire.",
		SHORT_MESSAGE_TIME
	)


	task.wait(
		CAMERA_HOLD_TIME
	)


	local returnTween =
		TweenService:Create(
			camera,
			cameraTweenInfo,
			{
				CFrame =
					previousCFrame,
			}
		)


	returnTween:Play()

	returnTween.Completed:Wait()


	camera.CameraType =
		previousCameraType


	if previousCameraSubject
		and previousCameraSubject.Parent then

		camera.CameraSubject =
			previousCameraSubject
	end
end


--==================================================
-- UI WAIT HELPERS
--==================================================

local function waitUntilVisible(
	object: GuiObject
)

	if object.Visible then
		return
	end


	while player.Parent
		and not object.Visible do

		object:GetPropertyChangedSignal(
			"Visible"
		):Wait()
	end
end


local function waitUntilHidden(
	object: GuiObject
)

	if not object.Visible then
		return
	end


	while player.Parent
		and object.Visible do

		object:GetPropertyChangedSignal(
			"Visible"
		):Wait()
	end
end


local function waitForManageMenu()

	waitUntilVisible(
		manageMain
	)
end


--==================================================
-- LEMONADE BUTTON
--==================================================

local function getLemonadeButton():
	TextButton

	local existing =
		businessScrollingFrame:FindFirstChild(
			"LemonadeStand"
		)


	if existing
		and existing:IsA(
			"TextButton"
		) then

		return existing
	end


	return businessScrollingFrame:WaitForChild(
		"LemonadeStand"
	) :: TextButton
end


--==================================================
-- QUEST CLAIM HELPERS
--==================================================

local function findFirstSaleClaimButton():
	GuiButton?

	local card =
		questsMain:FindFirstChild(
			"FirstSale",
			true
		)


	if not card then
		return nil
	end


	local complete =
		card:FindFirstChild(
			"Complete",
			true
		)


	if complete
		and complete:IsA(
			"GuiButton"
		) then

		return complete
	end


	return nil
end


local function waitForFirstSaleClaimButton(
	timeout: number
):
	GuiButton?

	local startedAt =
		time()


	while player.Parent
		and time() - startedAt
			< timeout do

		local button =
			findFirstSaleClaimButton()


		if button
			and button.Visible
			and button.Active then

			return button
		end


		task.wait(
			0.1
		)
	end


	return nil
end


--==================================================
-- CASH / UPGRADE HELPERS
--==================================================

local function getBetterLemonadeNextCost(
	stand: Model
): number

	local currentLevel =
		stand:GetAttribute(
			"SaleValueLevel"
		)


	if typeof(currentLevel)
		~= "number" then

		currentLevel =
			0
	end


	local lemonadeConfig =
		BusinessConfig.LemonadeStand


	if not lemonadeConfig
		or type(
			lemonadeConfig.Upgrades
		) ~= "table"
		or type(
			lemonadeConfig.Upgrades.SaleValue
		) ~= "table"
		or type(
			lemonadeConfig
				.Upgrades
				.SaleValue
				.Levels
		) ~= "table" then

		return 100
	end


	local nextDefinition =
		lemonadeConfig
			.Upgrades
			.SaleValue
			.Levels[
				currentLevel + 2
			]


	if type(nextDefinition)
			== "table"
		and typeof(
			nextDefinition.Cost
		) == "number" then

		return math.max(
			0,
			math.floor(
				nextDefinition.Cost
			)
		)
	end


	return 0
end


local function waitForCash(
	requiredCash: number
)

	if cash.Value
		>= requiredCash then

		return
	end


	while player.Parent
		and cash.Value
			< requiredCash do

		cash.Changed:Wait()
	end
end


local function waitForSaleValueUpgrade(
	stand: Model
)

	local function hasUpgrade():
		boolean

		local level =
			stand:GetAttribute(
				"SaleValueLevel"
			)


		return typeof(level)
				== "number"
			and level >= 1
	end


	if hasUpgrade() then
		return
	end


	while player.Parent
		and stand.Parent do

		stand:GetAttributeChangedSignal(
			"SaleValueLevel"
		):Wait()


		if hasUpgrade() then
			return
		end
	end
end


--==================================================
-- TUTORIAL VISIBILITY
--==================================================

local function showTutorial()

	tutorialGui.Enabled =
		true


	tutorialFrame.Position =
		HIDDEN_POSITION


	title.Text =
		"TUTORIAL"


	tutorialText.Text =
		""


	tutorialText.TextTransparency =
		1


	tutorialFrame.Visible =
		true


	tweenFrameTo(
		NORMAL_POSITION
	)
end


--==================================================
-- BUTTON HIGHLIGHT
--==================================================

local function clearButtonHighlight()

	if activeHighlightPulseThread then

		task.cancel(
			activeHighlightPulseThread
		)

		activeHighlightPulseThread =
			nil
	end


	if activeHighlight then

		activeHighlight:Destroy()

		activeHighlight =
			nil
	end
end


local function getButtonCornerRadius(
	button: GuiButton
): UDim

	local uiCorner =
		button:FindFirstChildWhichIsA(
			"UICorner"
		)


	if uiCorner then

		return uiCorner
			.CornerRadius
	end


	return UDim.new(
		0,
		12
	)
end


local function highlightButton(
	button: GuiButton,
	color: Color3?
)

	clearButtonHighlight()


	if not button.Parent then
		return
	end


	local highlightColor =
		color
		or TUTORIAL_HIGHLIGHT_COLOR


	local aura =
		Instance.new(
			"Frame"
		)


	aura.Name =
		"TutorialHighlight"


	aura.AnchorPoint =
		Vector2.new(
			0.5,
			0.5
		)


	aura.Position =
		UDim2.new(
			0.5,
			0,
			0.5,
			0
		)


	aura.Size =
		UDim2.new(
			1,
			TUTORIAL_HIGHLIGHT_SIZE_OFFSET,
			1,
			TUTORIAL_HIGHLIGHT_SIZE_OFFSET
		)


	aura.BackgroundColor3 =
		highlightColor


	aura.BackgroundTransparency =
		TUTORIAL_HIGHLIGHT_FILL_TRANSPARENCY


	aura.BorderSizePixel =
		0


	aura.ZIndex =
		math.max(
			1,
			button.ZIndex - 1
		)


	aura.Parent =
		button


	local auraCorner =
		Instance.new(
			"UICorner"
		)


	auraCorner.CornerRadius =
		getButtonCornerRadius(
			button
		)


	auraCorner.Parent =
		aura


	local auraStroke =
		Instance.new(
			"UIStroke"
		)


	auraStroke.Color =
		highlightColor


	auraStroke.Thickness =
		TUTORIAL_HIGHLIGHT_THICKNESS


	auraStroke.Transparency =
		TUTORIAL_HIGHLIGHT_IDLE_TRANSPARENCY


	auraStroke.Parent =
		aura


	local auraScale =
		Instance.new(
			"UIScale"
		)


	auraScale.Scale =
		1


	auraScale.Parent =
		aura


	activeHighlight =
		aura


	activeHighlightPulseThread =
		task.spawn(
			function()

				while running
					and aura.Parent
					and button.Parent do

					local growTween =
						TweenService:Create(
							auraScale,

							TweenInfo.new(
								TUTORIAL_HIGHLIGHT_PULSE_TIME,
								Enum.EasingStyle.Sine,
								Enum.EasingDirection.Out
							),

							{
								Scale =
									TUTORIAL_HIGHLIGHT_PULSE_SCALE,
							}
						)


					local strokeGrowTween =
						TweenService:Create(
							auraStroke,

							TweenInfo.new(
								TUTORIAL_HIGHLIGHT_PULSE_TIME,
								Enum.EasingStyle.Sine,
								Enum.EasingDirection.Out
							),

							{
								Transparency =
									TUTORIAL_HIGHLIGHT_PULSE_TRANSPARENCY,

								Thickness =
									TUTORIAL_HIGHLIGHT_PULSE_THICKNESS,
							}
						)


					growTween:Play()
					strokeGrowTween:Play()


					growTween.Completed:Wait()


					if not running
						or not aura.Parent
						or not button.Parent then

						break
					end


					local shrinkTween =
						TweenService:Create(
							auraScale,

							TweenInfo.new(
								TUTORIAL_HIGHLIGHT_PULSE_TIME,
								Enum.EasingStyle.Sine,
								Enum.EasingDirection.InOut
							),

							{
								Scale =
									1,
							}
						)


					local strokeShrinkTween =
						TweenService:Create(
							auraStroke,

							TweenInfo.new(
								TUTORIAL_HIGHLIGHT_PULSE_TIME,
								Enum.EasingStyle.Sine,
								Enum.EasingDirection.InOut
							),

							{
								Transparency =
									TUTORIAL_HIGHLIGHT_IDLE_TRANSPARENCY,

								Thickness =
									TUTORIAL_HIGHLIGHT_THICKNESS,
							}
						)


					shrinkTween:Play()
					strokeShrinkTween:Play()


					shrinkTween.Completed:Wait()
				end
			end
		)
end


local function waitForHighlightedButtonPress(
	button: GuiButton,
	color: Color3?
)

	highlightButton(
		button,
		color
	)


	button.Activated:Wait()


	clearButtonHighlight()
end


--==================================================
-- RESTORE CAMERA
--==================================================

local function restorePlayerCamera()

	local character =
		player.Character


	local humanoid =
		character
			and character:FindFirstChildOfClass(
				"Humanoid"
			)


	camera.CameraType =
		Enum.CameraType.Custom


	if humanoid then

		camera.CameraSubject =
			humanoid
	end
end


--==================================================
-- FINISH
--==================================================

local function finishTutorial()

	clearButtonHighlight()


	showTimedMessage(
	"Keep growing your reputation to unlock bigger businesses.",
	NORMAL_MESSAGE_TIME
)


showTimedMessage(
	"Quests, achievements, marketing, plot expansions, daily rewards, and licenses will help your empire grow.",
	LONG_MESSAGE_TIME
)


showTimedMessage(
	"You're ready. Go from broke to billionare!",
	NORMAL_MESSAGE_TIME
)


	clearText()


	completeTutorialRemote:FireServer()


	tweenFrameTo(
		HIDDEN_POSITION
	)


	tutorialFrame.Visible =
		false


	tutorialGui.Enabled =
		false


	running =
		false


	stopSuppressingDailyRewards(
		true
	)
end


--==================================================
-- SKIP
--==================================================

local function skipTutorial()

	if not running then
		return
	end


	running =
		false


	clearButtonHighlight()


	completeTutorialRemote:FireServer()


	if activeFrameTween then

		activeFrameTween:Cancel()

		activeFrameTween =
			nil
	end


	if activeTextTween then

		activeTextTween:Cancel()

		activeTextTween =
			nil
	end


	tutorialFrame.Visible =
		false


	tutorialGui.Enabled =
		false


	restorePlayerCamera()


	stopSuppressingDailyRewards(
		true
	)


	if tutorialThread then

		task.cancel(
			tutorialThread
		)

		tutorialThread =
			nil
	end
end


skipButton.Activated:Connect(
	skipTutorial
)


--==================================================
-- MAIN TUTORIAL
--==================================================

local function runTutorial()

	if running then
		return
	end


	running =
		true


	beginSuppressingDailyRewards()


	local plot =
		waitForOwnedPlot()


	showTutorial()


	--==================================================
	-- 1. VERY SHORT INTRO
	--==================================================

	showTimedMessage(
	"Welcome to Broke To Billionare! Start small, build businesses, and grow your empire.",
	LONG_MESSAGE_TIME
)


	--==================================================
	-- 2. SHOW PLOT
	--==================================================

	showPlotCamera(
		plot
	)


	--==================================================
	-- 3. PLACE FIRST BUSINESS
	--==================================================

	setTutorialText(
		"Let's start earning. Click Add."
	)


	waitForHighlightedButtonPress(
		addButton
	)


	local lemonadeStand =
		findLemonadeStand(
			plot
		)

	task.wait(
	ACTION_RESULT_PAUSE
)


	if not lemonadeStand then

		setTutorialText(
			"Choose the Lemonade Stand. Your first one is FREE."
		)


		local lemonadeButton =
			getLemonadeButton()


		waitForHighlightedButtonPress(
			lemonadeButton
		)


		waitUntilVisible(
			addButtons
		)


		tweenFrameTo(
			SIDE_POSITION
		)


		setTutorialText(
			"Pick a spot, rotate it if you want, then press Place."
		)


		lemonadeStand =
			waitForLemonadeStand(
				plot
			)


		tweenFrameTo(
			NORMAL_POSITION
		)

	else

		showTimedMessage(
			"We'll use the Lemonade Stand you already placed.",
			SHORT_MESSAGE_TIME
		)
	end


	--==================================================
	-- 4. FIRST CUSTOMER
	--==================================================

	showTimedMessage(
	"Nice! Customers visit automatically and pay you when they're served.",
	LONG_MESSAGE_TIME
)


	setTutorialText(
		"Watch your first customer get served."
	)


	waitForFirstSale(
		lemonadeStand
	)

	task.wait(
	MAJOR_RESULT_PAUSE
)


	showTimedMessage(
	"First sale! Your businesses keep earning while you build and upgrade.",
	NORMAL_MESSAGE_TIME
)


	--==================================================
	-- 5. QUESTS + FIRST CLAIM
	--==================================================

	setTutorialText(
		"Quests give you extra cash for progressing. Open Quests."
	)


	waitForHighlightedButtonPress(
		questsOpenButton
	)


	waitUntilVisible(
		questsMain
	)


	local firstSaleClaimButton =
		waitForFirstSaleClaimButton(
			5
		)


	if firstSaleClaimButton then

		setTutorialText(
			"Your first quest is complete. Claim the reward!"
		)


		waitForHighlightedButtonPress(
			firstSaleClaimButton
		)

		task.wait(
	ACTION_RESULT_PAUSE
)


		showTimedMessage(
	"Perfect. New quests replace completed ones, so you'll always have goals.",
	NORMAL_MESSAGE_TIME
)

	else

		showTimedMessage(
			"Quests track your sales, earnings, upgrades, and business growth.",
			NORMAL_MESSAGE_TIME
		)
	end


	setTutorialText(
		"Close Quests when you're ready."
	)


	waitUntilHidden(
		questsMain
	)


	--==================================================
	-- 6. MANAGE BUSINESS
	--==================================================

	setTutorialText(
		"Now walk to your Lemonade Stand and press Manage."
	)


	waitForManageMenu()


	tweenFrameTo(
		SIDE_POSITION
	)


	showTimedMessage(
	"Here you can improve earnings, service speed, queue size, and the stand itself.",
	LONG_MESSAGE_TIME
)


	--==================================================
	-- 7. FIRST UPGRADE
	--==================================================

	local firstUpgradeCost =
		getBetterLemonadeNextCost(
			lemonadeStand
		)


	if firstUpgradeCost > 0
		and cash.Value
			< firstUpgradeCost then

		setTutorialText(
			`Better Lemonade costs $. Let customers earn the cash you need.`
		)


		waitForCash(
			firstUpgradeCost
		)
	end


	if firstUpgradeCost > 0 then

		setTutorialText(
			`Buy Better Lemonade for $. It increases every sale.`
		)

	else

		setTutorialText(
			"You've already upgraded Better Lemonade!"
		)
	end


	waitForSaleValueUpgrade(
		lemonadeStand
	)

	task.wait(
	MAJOR_RESULT_PAUSE
)


	showTimedMessage(
	"Great! Reinvesting your cash makes every business stronger.",
	NORMAL_MESSAGE_TIME
)


	setTutorialText(
		"Close the Manage menu."
	)


	waitUntilHidden(
		manageMain
	)


	tweenFrameTo(
		NORMAL_POSITION
	)


	--==================================================
	-- 8. SHORT GAME OVERVIEW
	--==================================================

	showTimedMessage(
	"Serve customers to raise Reputation and unlock Hotdogs, Haircuts, Coffee, and future businesses.",
	LONG_MESSAGE_TIME
)


	showTimedMessage(
	"Marketing brings more customers, and Plot Expansions give you more room to build.",
	LONG_MESSAGE_TIME
)


	finishTutorial()
end


--==================================================
-- LOAD TUTORIAL STATE
--==================================================

tutorialFrame.Visible =
	false


tutorialFrame.Position =
	HIDDEN_POSITION


local success,
	state =
	pcall(
		function()

			return getTutorialStateRemote
				:InvokeServer()
		end
	)


if not success then

	warn(
		"Tutorial state could not be loaded."
	)

	return
end


if type(state)
		~= "table"
	or state.Loaded
		~= true then

	warn(
		"Tutorial could not start because player data was not ready."
	)

	return
end


if state.Completed
	== true then

	return
end


tutorialThread =
	task.spawn(
		runTutorial
	)