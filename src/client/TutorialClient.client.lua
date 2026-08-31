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
	0.42


local TEXT_FADE_TIME =
	0.22


-- Small empty pause between sentences.
local TEXT_CLEAR_DELAY =
	0.30


local CAMERA_TWEEN_TIME =
	0.9


local CAMERA_HOLD_TIME =
	1.25


-- Increased from the previous version.
local SHORT_MESSAGE_TIME =
	3.2


local NORMAL_MESSAGE_TIME =
	4.2


local LONG_MESSAGE_TIME =
	5


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


local activeFrameTween:
	Tween? =
	nil


local activeTextTween:
	Tween? =
	nil


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
			and plot:IsA("Model")
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
			placedBusinesses.ChildAdded:Wait()


		if not child:IsA(
			"Model"
		) then

			continue

		end


		-- Give placement code one frame to finish setting
		-- attributes on the new model.
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
		"This is your plot. Everything you build will grow from here.",
		NORMAL_MESSAGE_TIME
	)


	showTimedMessage(
		"You can place businesses around your plot, upgrade them, and eventually expand into much bigger businesses.",
		LONG_MESSAGE_TIME
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

local function waitForButtonPress(
	button: GuiButton
)

	button.Activated:Wait()
end


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

		currentLevel = 0

	end


	-- Better Lemonade Level 1 currently costs $100.
	-- Keeping this helper here means the tutorial can
	-- easily be changed later if the first upgrade changes.
	if currentLevel < 1 then

		return 100

	end


	return 0
end


local function waitForCash(
	requiredCash: number
)

	if cash.Value >= requiredCash then

		return

	end


	while player.Parent
		and cash.Value < requiredCash do

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


	while player.Parent do

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


local function finishTutorial()

	showTimedMessage(
		"That's everything you need to get started!",
		NORMAL_MESSAGE_TIME
	)


	showTimedMessage(
		"Keep serving customers, completing quests, upgrading your businesses, and building your dream business!",
		LONG_MESSAGE_TIME
	)


	clearText()


	completeTutorialRemote:FireServer()


	tweenFrameTo(
		HIDDEN_POSITION
	)


	tutorialFrame.Visible =
		false


	running =
		false
end


--==================================================
-- MAIN TUTORIAL
--==================================================

local function runTutorial()

	if running then

		return

	end


	running =
		true


	local plot =
		waitForOwnedPlot()


	showTutorial()


	--==================================================
	-- INTRO
	--==================================================

	showTimedMessage(
		"Welcome to From Broke To Boss!",
		NORMAL_MESSAGE_TIME
	)


	showTimedMessage(
		"Start with a small business, serve customers, earn cash, and turn your plot into a growing business empire.",
		LONG_MESSAGE_TIME
	)


	showTimedMessage(
		"This quick tutorial will walk you through the basics.",
		NORMAL_MESSAGE_TIME
	)


	--==================================================
	-- SHOW PLOT
	--==================================================

	setTutorialText(
		"First, let's take a look at your plot."
	)


	task.wait(
		1.5
	)


	showPlotCamera(
		plot
	)


	--==================================================
	-- ADD BUTTON
	--==================================================

	setTutorialText(
		"Let's open your first business. Click the Add button on the left side of your screen."
	)


	waitForButtonPress(
		addButton
	)


	local lemonadeStand =
		findLemonadeStand(
			plot
		)


	if not lemonadeStand then

		--==============================================
		-- SELECT LEMONADE
		--==============================================

		setTutorialText(
			"Great! Select the Lemonade Stand. Your very first one is completely free."
		)


		local lemonadeButton =
			getLemonadeButton()


		waitForButtonPress(
			lemonadeButton
		)


		-- Wait for the real placement controls.
		waitUntilVisible(
			addButtons
		)


		-- Move tutorial away from Rotate / Place / Cancel.
		tweenFrameTo(
			SIDE_POSITION
		)


		setTutorialText(
			"Now choose where you want your Lemonade Stand. You can rotate it, then press Place when you're happy with it."
		)


		-- Only advances when placement actually succeeds.
		lemonadeStand =
			waitForLemonadeStand(
				plot
			)


		tweenFrameTo(
			NORMAL_POSITION
		)


	else

		showTimedMessage(
			"You already have a Lemonade Stand, so we'll use that one.",
			NORMAL_MESSAGE_TIME
		)

	end


	--==================================================
	-- FIRST BUSINESS
	--==================================================

	showTimedMessage(
		"Nice! Your first business is officially open.",
		NORMAL_MESSAGE_TIME
	)


	showTimedMessage(
		"Customers will automatically visit your businesses. Once they're served, you'll earn cash.",
		LONG_MESSAGE_TIME
	)


	--==================================================
	-- QUESTS
	--==================================================

	showTimedMessage(
		"Placing your first business also unlocks your first quests.",
		NORMAL_MESSAGE_TIME
	)


	showTimedMessage(
		"Quests give you goals to work toward and reward you with extra cash as you play.",
		LONG_MESSAGE_TIME
	)


	setTutorialText(
		"Click the Quests button to take a look."
	)


	waitForButtonPress(
		questsOpenButton
	)


	waitUntilVisible(
		questsMain
	)


	showTimedMessage(
		"These will progress naturally while you build, serve customers, upgrade businesses, and expand.",
		LONG_MESSAGE_TIME
	)


	showTimedMessage(
		"When a quest is finished, come back here and claim its reward. These rewards are especially useful early on.",
		LONG_MESSAGE_TIME
	)


	setTutorialText(
		"Close the Quests menu when you're ready to continue."
	)


	waitUntilHidden(
		questsMain
	)


	--==================================================
	-- MANAGE INTRO
	--==================================================

	showTimedMessage(
		"Next, let's look at how you improve a business.",
		NORMAL_MESSAGE_TIME
	)


	setTutorialText(
		"Walk over to your Lemonade Stand and press Manage."
	)


	waitForManageMenu()


	-- Manage menu is in the center, so get out of its way.
	tweenFrameTo(
		SIDE_POSITION
	)


	--==================================================
	-- EXPLAIN MANAGEMENT
	--==================================================

	showTimedMessage(
		"This is the Manage menu. Every stand has upgrades that make it more powerful.",
		LONG_MESSAGE_TIME
	)


	showTimedMessage(
		"Better Lemonade increases how much cash you earn from every customer you serve.",
		NORMAL_MESSAGE_TIME
	)


	showTimedMessage(
		"Faster Service reduces the time it takes to serve each customer.",
		NORMAL_MESSAGE_TIME
	)


	showTimedMessage(
		"Longer Queue lets more customers wait at the stand instead of leaving when it's busy.",
		LONG_MESSAGE_TIME
	)


	showTimedMessage(
		"Upgrading the stand's appearance is also important. Better-looking stands earn more and attract customers more effectively.",
		LONG_MESSAGE_TIME
	)


	--==================================================
	-- WAIT FOR ENOUGH CASH
	--==================================================

	local firstUpgradeCost =
		getBetterLemonadeNextCost(
			lemonadeStand
		)


	if firstUpgradeCost > 0
		and cash.Value < firstUpgradeCost then

		setTutorialText(
			`Better Lemonade costs ${firstUpgradeCost}. You don't have to buy it yet — let your stand serve customers until you have enough cash.`
		)


		waitForCash(
			firstUpgradeCost
		)


		showTimedMessage(
			`You now have enough cash! Let's spend ${firstUpgradeCost} on your first Better Lemonade upgrade.`,
			NORMAL_MESSAGE_TIME
		)

	end


	--==================================================
	-- REQUIRE UPGRADE
	--==================================================

	setTutorialText(
		"Upgrade Better Lemonade once."
	)


	waitForSaleValueUpgrade(
		lemonadeStand
	)


	showTimedMessage(
		"Perfect! That stand now earns more cash from every sale.",
		NORMAL_MESSAGE_TIME
	)


	showTimedMessage(
		"Later upgrades become much more powerful, so keep reinvesting some of the money your businesses make.",
		LONG_MESSAGE_TIME
	)


	--==================================================
	-- LEAVE MANAGE MENU
	--==================================================

	setTutorialText(
		"Close the Manage menu when you're ready."
	)


	waitUntilHidden(
		manageMain
	)


	tweenFrameTo(
		NORMAL_POSITION
	)


	--==================================================
	-- FINAL PROGRESSION
	--==================================================

	showTimedMessage(
		"As you earn more cash and reputation, you'll unlock completely new types of businesses.",
		LONG_MESSAGE_TIME
	)


	showTimedMessage(
		"New businesses earn more, while your older businesses can continue generating money alongside them.",
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


task.spawn(
	runTutorial
)