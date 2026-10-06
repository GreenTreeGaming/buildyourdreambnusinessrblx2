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

local FRAME_TWEEN_TIME =
	0.30


local TEXT_FADE_TIME =
	0.14


local TEXT_CLEAR_DELAY =
	0.10


local CAMERA_TWEEN_TIME =
	0.65


local CAMERA_HOLD_TIME =
	0.55


local SHORT_MESSAGE_TIME =
	2.25


local NORMAL_MESSAGE_TIME =
	3.25


local LONG_MESSAGE_TIME =
	4


local ACTION_RESULT_PAUSE =
	0.55


local MAJOR_RESULT_PAUSE =
	0.8


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


--==================================================
-- HIGHLIGHT SETTINGS
--==================================================

local TUTORIAL_HIGHLIGHT_COLOR =
	Color3.fromRGB(
		255,
		223,
		102
	)


local TUTORIAL_HIGHLIGHT_FILL_TRANSPARENCY =
	0.86


local TUTORIAL_HIGHLIGHT_IDLE_TRANSPARENCY =
	0.12


local TUTORIAL_HIGHLIGHT_PULSE_TRANSPARENCY =
	0.42


local TUTORIAL_HIGHLIGHT_THICKNESS =
	3


local TUTORIAL_HIGHLIGHT_PULSE_THICKNESS =
	6


local TUTORIAL_HIGHLIGHT_SIZE_OFFSET =
	18


local TUTORIAL_HIGHLIGHT_PULSE_SCALE =
	1.06


local TUTORIAL_HIGHLIGHT_PULSE_TIME =
	0.5


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


local function setTutorialStep(
	stepTitle: string,
	text: string
)

	title.Text =
		stepTitle


	clearText()


	tutorialText.Text =
		text


	tweenTextTransparency(
		0
	)
end


local function showTimedStep(
	stepTitle: string,
	text: string,
	duration: number?
)

	setTutorialStep(
		stepTitle,
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
						and dailyRewardsGui.Enabled then

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
-- SALES
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


local function waitForSaleAfter(
	stand: Model,
	previousSales: number
): number

	while player.Parent
		and stand.Parent do

		local currentSales =
			getTotalSales(
				stand
			)


		if currentSales > previousSales then
			return currentSales
		end


		stand:GetAttributeChangedSignal(
			"TotalSales"
		):Wait()
	end


	return getTotalSales(
		stand
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


	waitForSaleAfter(
		stand,
		0
	)
end


--==================================================
-- SALE VALUE
--==================================================

local function getSaleValueLevel(
	stand: Model
): number

	local level =
		stand:GetAttribute(
			"SaleValueLevel"
		)


	if typeof(level)
		~= "number" then

		return 0
	end


	return math.max(
		0,
		math.floor(
			level
		)
	)
end


local function getSaleValueForLevel(
	level: number
): number

	local lemonadeConfig =
		BusinessConfig.LemonadeStand


	if type(lemonadeConfig)
			~= "table"
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

		return 0
	end


	local definition =
		lemonadeConfig
			.Upgrades
			.SaleValue
			.Levels[
				level + 1
			]


	if type(definition)
			== "table"
		and typeof(
			definition.SaleValue
		) == "number" then

		return math.max(
			0,
			math.floor(
				definition.SaleValue
			)
		)
	end


	return 0
end


local function getBetterLemonadeNextCost(
	stand: Model
): number

	local currentLevel =
		getSaleValueLevel(
			stand
		)


	local lemonadeConfig =
		BusinessConfig.LemonadeStand


	if type(lemonadeConfig)
			~= "table"
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


local function waitForSaleValueUpgrade(
	stand: Model,
	startingLevel: number
)

	if getSaleValueLevel(
		stand
	) > startingLevel then

		return
	end


	while player.Parent
		and stand.Parent do

		stand:GetAttributeChangedSignal(
			"SaleValueLevel"
		):Wait()


		if getSaleValueLevel(
			stand
		) > startingLevel then

			return
		end
	end
end


--==================================================
-- CASH
--==================================================

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


	showTimedStep(
		"YOUR BUSINESS",
		"This empty plot is yours. We're going to turn it into an empire.",
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
-- VISIBILITY HELPERS
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
-- MANAGE / UPGRADE BUTTON
--==================================================

local function getUpgradeScrollingFrame():
	ScrollingFrame?

	local contentFrame =
		manageMain:FindFirstChild(
			"Frame"
		)


	if not contentFrame
		or not contentFrame:IsA(
			"Frame"
		) then

		return nil
	end


	local scrollingFrame =
		contentFrame:FindFirstChild(
			"ScrollingFrame"
		)


	if scrollingFrame
		and scrollingFrame:IsA(
			"ScrollingFrame"
		) then

		return scrollingFrame
	end


	return nil
end


local function findBetterLemonadeBuyButton():
	GuiButton?

	local scrollingFrame =
		getUpgradeScrollingFrame()


	if not scrollingFrame then
		return nil
	end


	local saleValueCard =
		scrollingFrame:FindFirstChild(
			"SaleValue"
		)


	if not saleValueCard then
		return nil
	end


	local buy =
		saleValueCard:FindFirstChild(
			"Buy"
		)


	if buy
		and buy:IsA(
			"GuiButton"
		) then

		return buy
	end


	return nil
end


local function waitForBetterLemonadeBuyButton(
	timeout: number
):
	GuiButton?

	local startedAt =
		time()


	while player.Parent
		and time() - startedAt
			< timeout do

		local button =
			findBetterLemonadeBuyButton()


		if button
			and button.Visible then

			return button
		end


		task.wait(
			0.1
		)
	end


	return nil
end


--==================================================
-- QUEST HELPERS
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
-- TUTORIAL VISIBILITY
--==================================================

local function showTutorial()

	tutorialGui.Enabled =
		true


	tutorialFrame.Position =
		HIDDEN_POSITION


	title.Text =
		"WELCOME!"


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
-- REPUTATION / NEXT GOAL
--==================================================

local function getReputationLevel(
	plot: Model
): number

	local reputation =
		plot:GetAttribute(
			"ReputationLevel"
		)


	if typeof(reputation)
		~= "number" then

		return 1
	end


	return math.max(
		1,
		math.floor(
			reputation
		)
	)
end


local function getHotdogRequirements()

	local hotdogConfig =
		BusinessConfig.HotdogStand


	if type(hotdogConfig)
		~= "table" then

		return 4, 2500, 2
	end


	local requirements =
		hotdogConfig.UnlockRequirements


	if type(requirements)
		~= "table" then

		return 4, 2500, 2
	end


	local reputation =
		tonumber(
			requirements.ReputationLevel
		) or 4


	local lifetimeEarnings =
		tonumber(
			requirements.LifetimeEarnings
		) or 2500


	local lemonadeLevel =
		2


	if type(
		requirements.BusinessLevel
	) == "table" then

		lemonadeLevel =
			tonumber(
				requirements
					.BusinessLevel
					.Level
			) or 2
	end


	return reputation,
		lifetimeEarnings,
		lemonadeLevel
end


--==================================================
-- FINISH
--==================================================

local function finishTutorial(
	plot: Model
)

	clearButtonHighlight()


	local reputationRequired,
		lifetimeRequired,
		lemonadeLevelRequired =
		getHotdogRequirements()


	local currentReputation =
		getReputationLevel(
			plot
		)


	showTimedStep(
		"HOW YOU PROGRESS",
		`Customers build Reputation. You're Reputation {currentReputation} right now — higher Reputation unlocks bigger businesses.`,
		LONG_MESSAGE_TIME
	)


	showTimedStep(
		"YOUR NEXT GOAL",
		`Unlock the Hotdog Stand! Reach Reputation {reputationRequired}, earn  total, and upgrade your Lemonade Stand to Level {lemonadeLevelRequired}.`,
		LONG_MESSAGE_TIME
	)


	showTimedStep(
		"BUILD YOUR EMPIRE!",
		"Build → Earn → Upgrade → Unlock. Keep repeating that loop and turn your tiny stand into a business empire!",
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

	showTimedStep(
		"WELCOME!",
		"Start with nothing. Build businesses, serve customers, reinvest your money, and become a billionaire!",
		NORMAL_MESSAGE_TIME
	)


	--==================================================
	-- 2. SHOW PLAYER THEIR PLOT
	--==================================================

	showPlotCamera(
		plot
	)


	--==================================================
	-- 3. BUILD FIRST BUSINESS
	--==================================================

	setTutorialStep(
		"BUILD YOUR FIRST BUSINESS",
		"Click ADD to choose your first business."
	)


	waitForHighlightedButtonPress(
		addButton
	)


	task.wait(
		ACTION_RESULT_PAUSE
	)


	local lemonadeStand =
		findLemonadeStand(
			plot
		)


	if not lemonadeStand then

		setTutorialStep(
			"CHOOSE A BUSINESS",
			"Pick the Lemonade Stand. Your first one is FREE!"
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


		setTutorialStep(
			"PLACE YOUR STAND",
			"Choose a spot on your plot, then press Place."
		)


		lemonadeStand =
			waitForLemonadeStand(
				plot
			)


		tweenFrameTo(
			NORMAL_POSITION
		)

	else

		showTimedStep(
			"YOUR FIRST BUSINESS",
			"You already have a Lemonade Stand, so we'll use it!",
			SHORT_MESSAGE_TIME
		)
	end


	task.wait(
		MAJOR_RESULT_PAUSE
	)


	showTimedStep(
		"NICE!",
		"That's your first business. Customers will automatically visit it and pay you.",
		NORMAL_MESSAGE_TIME
	)


	--==================================================
	-- 4. FIRST CUSTOMER
	--==================================================

	local startingCash =
		cash.Value


	setTutorialStep(
		"YOUR FIRST CUSTOMER",
		"Watch your Lemonade Stand. A customer is coming!"
	)


	waitForFirstSale(
		lemonadeStand
	)


	task.wait(
		MAJOR_RESULT_PAUSE
	)


	local earnedCash =
		math.max(
			0,
			cash.Value - startingCash
		)


	if earnedCash > 0 then

		showTimedStep(
			"YOU MADE MONEY!",
			`Customer served! You earned +. Every customer your businesses serve earns you cash.`,
			NORMAL_MESSAGE_TIME
		)

	else

		showTimedStep(
			"YOU MADE A SALE!",
			"Customer served! Businesses automatically make money whenever they serve customers.",
			NORMAL_MESSAGE_TIME
		)
	end


	--==================================================
	-- 5. TEACH CORE LOOP
	--==================================================

	showTimedStep(
		"THE CORE LOOP",
		"More customers = more money. Now let's reinvest that money to make each customer worth MORE.",
		NORMAL_MESSAGE_TIME
	)


	--==================================================
	-- 6. OPEN MANAGE MENU
	--==================================================

	setTutorialStep(
		"UPGRADE YOUR BUSINESS",
		"Walk to your Lemonade Stand and press Manage."
	)


	waitForManageMenu()


	tweenFrameTo(
		SIDE_POSITION
	)


	showTimedStep(
		"UPGRADE YOUR BUSINESS",
		"This menu makes your stand stronger. Let's increase how much money every sale earns.",
		NORMAL_MESSAGE_TIME
	)


	--==================================================
	-- 7. BUY BETTER LEMONADE
	--==================================================

	local startingSaleValueLevel =
		getSaleValueLevel(
			lemonadeStand
		)


	local beforeUpgradeSaleValue =
		getSaleValueForLevel(
			startingSaleValueLevel
		)


	local firstUpgradeCost =
		getBetterLemonadeNextCost(
			lemonadeStand
		)


	if firstUpgradeCost > 0
		and cash.Value
			< firstUpgradeCost then

		setTutorialStep(
			"EARN FOR YOUR UPGRADE",
			`Better Lemonade costs $. Keep serving customers — you need $${firstUpgradeCost - cash.Value} more!`
		)


		waitForCash(
			firstUpgradeCost
		)


		task.wait(
			ACTION_RESULT_PAUSE
		)
	end


	local betterLemonadeButton =
		waitForBetterLemonadeBuyButton(
			5
		)


	if firstUpgradeCost > 0 then

		setTutorialStep(
			"BUY BETTER LEMONADE",
			`Buy Better Lemonade for $. This permanently increases how much this stand earns per sale.`
		)


		if betterLemonadeButton then

			highlightButton(
				betterLemonadeButton
			)
		end


		waitForSaleValueUpgrade(
			lemonadeStand,
			startingSaleValueLevel
		)


		clearButtonHighlight()

	else

		showTimedStep(
			"ALREADY UPGRADED!",
			"Your Better Lemonade upgrade is already purchased.",
			SHORT_MESSAGE_TIME
		)
	end


	task.wait(
		MAJOR_RESULT_PAUSE
	)


	local upgradedSaleValueLevel =
		getSaleValueLevel(
			lemonadeStand
		)


	local afterUpgradeSaleValue =
		getSaleValueForLevel(
			upgradedSaleValueLevel
		)


	if afterUpgradeSaleValue
			> beforeUpgradeSaleValue then

		showTimedStep(
			"UPGRADE COMPLETE!",
			`Your Lemonade Stand went from $ → $ per normal sale!`,
			NORMAL_MESSAGE_TIME
		)

	else

		showTimedStep(
			"UPGRADE COMPLETE!",
			"Great! Reinvesting your money makes your businesses earn more.",
			NORMAL_MESSAGE_TIME
		)
	end


	--==================================================
	-- 8. CLOSE MANAGE
	--==================================================

	setTutorialStep(
		"SEE THE DIFFERENCE",
		"Close the Manage menu. Let's watch your upgraded stand make another sale."
	)


	waitUntilHidden(
		manageMain
	)


	tweenFrameTo(
		NORMAL_POSITION
	)


	--==================================================
	-- 9. SECOND CUSTOMER AFTER UPGRADE
	--==================================================

	local salesBeforeDemonstration =
		getTotalSales(
			lemonadeStand
		)


	local cashBeforeDemonstration =
		cash.Value


	setTutorialStep(
		"SEE THE DIFFERENCE",
		"Watch the next customer. Your upgraded Lemonade Stand now earns more per sale!"
	)


	waitForSaleAfter(
		lemonadeStand,
		salesBeforeDemonstration
	)


	task.wait(
		MAJOR_RESULT_PAUSE
	)


	local demonstrationCash =
		math.max(
			0,
			cash.Value - cashBeforeDemonstration
		)


	if demonstrationCash > 0 then

		showTimedStep(
			"THAT'S THE LOOP!",
			`Another customer served: +$! Spend money on upgrades → earn faster → buy even better businesses.`,
			NORMAL_MESSAGE_TIME
		)

	else

		showTimedStep(
			"THAT'S THE LOOP!",
			"Build → earn money → upgrade → earn even more. That's the main loop of the game!",
			NORMAL_MESSAGE_TIME
		)
	end


	--==================================================
	-- 10. QUESTS
	--==================================================

	setTutorialStep(
		"WHAT SHOULD I DO NEXT?",
		"If you're ever unsure what to do, Quests give you goals AND rewards. Open Quests."
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

		setTutorialStep(
			"CLAIM YOUR REWARD",
			"You already completed your first quest! Claim the reward."
		)


		waitForHighlightedButtonPress(
			firstSaleClaimButton
		)


		task.wait(
			ACTION_RESULT_PAUSE
		)


		showTimedStep(
			"QUEST COMPLETE!",
			"Nice! Keep following Quests whenever you want a clear goal and extra rewards.",
			NORMAL_MESSAGE_TIME
		)

	else

		showTimedStep(
			"FOLLOW YOUR QUESTS",
			"Quests track your progress and always give you something useful to work toward.",
			NORMAL_MESSAGE_TIME
		)
	end


	setTutorialStep(
		"BACK TO YOUR BUSINESS",
		"Close Quests when you're ready."
	)


	waitUntilHidden(
		questsMain
	)


	--==================================================
	-- 11. REPUTATION + NEXT BUSINESS
	--==================================================

	local reputationRequired,
		lifetimeRequired,
		lemonadeLevelRequired =
		getHotdogRequirements()


	local currentReputation =
		getReputationLevel(
			plot
		)


	showTimedStep(
		"UNLOCK BIGGER BUSINESSES",
		`Serving customers grows your Reputation. You're Reputation {currentReputation}; the Hotdog Stand needs Reputation {reputationRequired}.`,
		LONG_MESSAGE_TIME
	)


	showTimedStep(
		"YOUR FIRST BIG GOAL",
		`Keep serving customers, earn $ total, and upgrade your Lemonade Stand to Level {lemonadeLevelRequired} to unlock Hotdogs.`,
		LONG_MESSAGE_TIME
	)


	--==================================================
	-- 12. FINISH
	--==================================================

	finishTutorial(
		plot
	)
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