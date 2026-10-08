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


local remotes =
	ReplicatedStorage:WaitForChild(
		"Remotes"
	)


--==================================================
-- REMOTES
--==================================================

local getTutorialStateRemote =
	remotes:WaitForChild(
		"GetTutorialState"
	) :: RemoteFunction


local getContextualTutorialStateRemote =
	remotes:WaitForChild(
		"GetContextualTutorialState"
	) :: RemoteFunction


local completeContextualTutorialRemote =
	remotes:WaitForChild(
		"CompleteContextualTutorial"
	) :: RemoteFunction


local getMarketingStateRemote =
	remotes:WaitForChild(
		"GetMarketingState"
	) :: RemoteFunction


local getPlotExpansionStateRemote =
	remotes:WaitForChild(
		"GetPlotExpansionState"
	) :: RemoteFunction


local getRebirthStateRemote =
	remotes:WaitForChild(
		"GetRebirthState"
	) :: RemoteFunction


--==================================================
-- WORLD
--==================================================

local plotsFolder =
	Workspace:WaitForChild(
		"Plots"
	)


local map =
	Workspace:WaitForChild(
		"Map"
	)


local touchForStock =
	map:FindFirstChild(
		"TouchForStock"
	)


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


local tutorialTitle =
	tutorialFrame:WaitForChild(
		"Title"
	) :: TextLabel


local tutorialText =
	tutorialFrame:WaitForChild(
		"TutorialText"
	) :: TextLabel


local skipButton =
	tutorialFrame:WaitForChild(
		"SkipBtn"
	) :: GuiButton


--==================================================
-- MANAGE / MARKETING / PLOT
--==================================================

local manageGui =
	playerGui:WaitForChild(
		"ManageUI"
	) :: ScreenGui


local manageOpenButton =
	manageGui:WaitForChild(
		"OpenButton"
	) :: GuiButton


local manageMain =
	manageGui:WaitForChild(
		"Main"
	) :: Frame


local marketingButton =
	manageMain:WaitForChild(
		"MarketingButton"
	) :: GuiButton


local plotButton =
	manageMain:WaitForChild(
		"PlotButton"
	) :: GuiButton


local marketingFrame =
	manageMain:WaitForChild(
		"Frame"
	) :: Frame


local plotFrame =
	manageMain:WaitForChild(
		"PlotFrame"
	) :: Frame


local marketingBuyButton =
	marketingFrame:WaitForChild(
		"Buy"
	) :: GuiButton


local plotBuyButton =
	plotFrame:WaitForChild(
		"Buy"
	) :: GuiButton


--==================================================
-- LICENSES
--==================================================

local licensesGui =
	playerGui:WaitForChild(
		"LicensesUI"
	) :: ScreenGui


local licensesOpenButton =
	licensesGui:WaitForChild(
		"OpenButton"
	) :: GuiButton


local licensesMain =
	licensesGui:WaitForChild(
		"Main"
	) :: Frame


local licensesContent =
	licensesMain:WaitForChild(
		"Frame"
	) :: Frame


local licenseButtons =
	licensesContent:WaitForChild(
		"Buttons"
	) :: Frame


local licenseUpgradesObject =
	licenseButtons:WaitForChild(
		"Upgrades"
	) :: GuiObject


local licenseUpgradesFrame =
	licensesContent:WaitForChild(
		"UpgradesFrame"
	) :: Frame


--==================================================
-- REBIRTH
--==================================================

local rebirthGui =
	playerGui:WaitForChild(
		"Rebirth"
	) :: ScreenGui


local rebirthOpenButton =
	rebirthGui:WaitForChild(
		"OpenButton"
	) :: GuiButton


local rebirthMain =
	rebirthGui:WaitForChild(
		"Main"
	) :: GuiObject


local rebirthFrame =
	rebirthMain:WaitForChild(
		"Frame"
	)


local rebirthButton =
	rebirthFrame:WaitForChild(
		"Rebirth"
	) :: GuiButton


--==================================================
-- STOCK UI
--==================================================

local stockGui =
	playerGui:WaitForChild(
		"StockUI"
	) :: ScreenGui


local stockMain =
	stockGui:WaitForChild(
		"Main"
	) :: Frame


local restockAllButton =
	stockMain:FindFirstChild(
		"RestockAll",
		true
	)


assert(
	restockAllButton
		and restockAllButton:IsA(
			"GuiButton"
		),
	"StockUI.Main must contain RestockAll."
)


restockAllButton =
	restockAllButton :: GuiButton


--==================================================
-- SETTINGS
--==================================================

local STOCK_TRIGGER_PERCENT =
	0.25


local CHECK_INTERVAL =
	1


local MESSAGE_TIME =
	3


local SHORT_MESSAGE_TIME =
	2.25


local TUTORIAL_HIGHLIGHT_COLOR =
	Color3.fromRGB(
		255,
		223,
		102
	)


--==================================================
-- PRIORITY
--==================================================

local PRIORITY = {
	Stock = 1,
	Marketing = 2,
	PlotExpansion = 3,
	Licenses = 4,
	Rebirth = 5,
}


--==================================================
-- STATE
--==================================================

local completed: {
	[string]: boolean
} = {}


local queued: {
	[string]: boolean
} = {}


local runners: {
	[string]: () -> ()
} = {}


local tutorialRunning =
	false


local activeTutorialId:
	string? =
	nil


local skipRequested =
	false


local activeHighlight:
	Frame? =
	nil


local worldHighlights: {
	Highlight
} = {}

local stockGuideBeam:
	Beam? =
	nil


local stockGuidePlayerAttachment:
	Attachment? =
	nil


local stockGuideTargetAttachment:
	Attachment? =
	nil


local stockGuideTargetPart:
	BasePart? =
	nil


local stockGuideThread:
	thread? =
	nil

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

		if plot:IsA(
			"Model"
		)
			and plot:GetAttribute(
				"OwnerUserId"
			) == player.UserId then

			return plot
		end
	end


	return nil
end


local function getPlacedBusinesses():
	Instance?

	local plot =
		getOwnedPlot()


	if not plot then
		return nil
	end


	return plot:FindFirstChild(
		"PlacedBusinesses"
	)
end


--==================================================
-- UI HELPERS
--==================================================

local function showTutorial(
	titleText: string,
	bodyText: string
)

	tutorialGui.Enabled =
		true


	tutorialFrame.Visible =
		true


	tutorialTitle.Text =
		titleText


	tutorialText.Text =
		bodyText


	tutorialText.TextTransparency =
		0
end


local function setTutorialText(
	titleText: string,
	bodyText: string
)

	tutorialTitle.Text =
		titleText


	tutorialText.Text =
		bodyText
end


local function hideTutorial()

	tutorialFrame.Visible =
		false


	tutorialGui.Enabled =
		false
end


local function showTimedMessage(
	titleText: string,
	bodyText: string,
	duration: number?
): boolean

	setTutorialText(
		titleText,
		bodyText
	)


	local endTime =
		time()
		+ (
			duration
			or MESSAGE_TIME
		)


	while time() < endTime do

		if skipRequested then
			return false
		end


		task.wait(
			0.1
		)
	end


	return true
end


--==================================================
-- GUI HIGHLIGHT
--==================================================

local function clearHighlight()

	if activeHighlight then

		activeHighlight:Destroy()

		activeHighlight =
			nil
	end
end


local function highlightGui(
	object: GuiObject
)

	clearHighlight()


	local frame =
		Instance.new(
			"Frame"
		)


	frame.Name =
		"ContextualTutorialHighlight"


	frame.AnchorPoint =
		Vector2.new(
			0.5,
			0.5
		)


	frame.Position =
		UDim2.fromScale(
			0.5,
			0.5
		)


	frame.Size =
		UDim2.new(
			1,
			18,
			1,
			18
		)


	frame.BackgroundColor3 =
		TUTORIAL_HIGHLIGHT_COLOR


	frame.BackgroundTransparency =
		0.88


	frame.BorderSizePixel =
		0


	frame.ZIndex =
		math.max(
			1,
			object.ZIndex - 1
		)


	frame.Parent =
		object


	local corner =
		Instance.new(
			"UICorner"
		)


	corner.CornerRadius =
		UDim.new(
			0,
			12
		)


	corner.Parent =
		frame


	local stroke =
		Instance.new(
			"UIStroke"
		)


	stroke.Color =
		TUTORIAL_HIGHLIGHT_COLOR


	stroke.Thickness =
		4


	stroke.Parent =
		frame


	local scale =
		Instance.new(
			"UIScale"
		)


	scale.Parent =
		frame


	activeHighlight =
		frame


	task.spawn(
		function()

			while activeHighlight
				== frame
				and frame.Parent do

				local outward =
					TweenService:Create(
						scale,

						TweenInfo.new(
							0.5,
							Enum.EasingStyle.Sine,
							Enum.EasingDirection.Out
						),

						{
							Scale = 1.06,
						}
					)


				outward:Play()

				outward.Completed:Wait()


				if activeHighlight
					~= frame
					or not frame.Parent then

					break
				end


				local inward =
					TweenService:Create(
						scale,

						TweenInfo.new(
							0.5,
							Enum.EasingStyle.Sine,
							Enum.EasingDirection.InOut
						),

						{
							Scale = 1,
						}
					)


				inward:Play()

				inward.Completed:Wait()
			end
		end
	)
end


--==================================================
-- STOCK GUIDE BEAM
--==================================================

local STOCK_BEAM_COLOR =
	Color3.fromRGB(
	255,
	220,
	60
)


local STOCK_BEAM_WIDTH =
	0.32


local STOCK_BEAM_HEIGHT_OFFSET =
	1.5


local function getCharacterRoot():
	BasePart?

	local character =
		player.Character


	if not character then
		return nil
	end


	local root =
		character:FindFirstChild(
			"HumanoidRootPart"
		)


	if root
		and root:IsA(
			"BasePart"
		) then

		return root
	end


	return nil
end


local function getStockTouchParts():
	{BasePart}

	local parts = {}


	if not touchForStock then
		return parts
	end


	if touchForStock:IsA(
		"BasePart"
	) then

		table.insert(
			parts,
			touchForStock
		)
	end


	for _, descendant in
		touchForStock:GetDescendants()
	do

		if descendant:IsA(
			"BasePart"
		) then

			table.insert(
				parts,
				descendant
			)
		end
	end


	return parts
end


local function getNearestStockTouchPart():
	BasePart?

	local root =
		getCharacterRoot()


	if not root then
		return nil
	end


	local nearestPart:
		BasePart? =
		nil


	local nearestDistance =
		math.huge


	for _, part in
		getStockTouchParts()
	do

		if not part.Parent then
			continue
		end


		local distance =
			(
				root.Position
				- part.Position
			).Magnitude


		if distance
			< nearestDistance then

			nearestDistance =
				distance


			nearestPart =
				part
		end
	end


	return nearestPart
end


local function clearStockGuideBeam()

	if stockGuideThread then

		task.cancel(
			stockGuideThread
		)


		stockGuideThread =
			nil
	end


	if stockGuideBeam then

		stockGuideBeam:Destroy()


		stockGuideBeam =
			nil
	end


	if stockGuidePlayerAttachment then

		stockGuidePlayerAttachment:
			Destroy()


		stockGuidePlayerAttachment =
			nil
	end


	if stockGuideTargetAttachment then

		stockGuideTargetAttachment:
			Destroy()


		stockGuideTargetAttachment =
			nil
	end


	stockGuideTargetPart =
		nil
end


local function createStockGuideBeamForTarget(
	targetPart: BasePart
)

	local root =
		getCharacterRoot()


	if not root
		or not targetPart.Parent then

		return
	end


	if stockGuideBeam then

		stockGuideBeam:Destroy()


		stockGuideBeam =
			nil
	end


	if stockGuidePlayerAttachment then

		stockGuidePlayerAttachment:
			Destroy()


		stockGuidePlayerAttachment =
			nil
	end


	if stockGuideTargetAttachment then

		stockGuideTargetAttachment:
			Destroy()


		stockGuideTargetAttachment =
			nil
	end


	--==================================================
	-- PLAYER ATTACHMENT
	--==================================================

	local playerAttachment =
		Instance.new(
			"Attachment"
		)


	playerAttachment.Name =
		"StockTutorialPlayerAttachment"


	playerAttachment.Position =
		Vector3.new(
			0,
			-STOCK_BEAM_HEIGHT_OFFSET,
			0
		)


	playerAttachment.Parent =
		root


	--==================================================
	-- STOCK SHOP ATTACHMENT
	--==================================================

	local targetAttachment =
		Instance.new(
			"Attachment"
		)


	targetAttachment.Name =
		"StockTutorialTargetAttachment"


	targetAttachment.Position =
		Vector3.new(
			0,
			targetPart.Size.Y / 2
				+ 1,
			0
		)


	targetAttachment.Parent =
		targetPart


	--==================================================
	-- BEAM
	--==================================================

	local beam =
		Instance.new(
			"Beam"
		)


	beam.Name =
		"StockTutorialGuideBeam"


	beam.Attachment0 =
		playerAttachment


	beam.Attachment1 =
		targetAttachment


	beam.Color =
		ColorSequence.new(
			STOCK_BEAM_COLOR
		)


	beam.Width0 =
		STOCK_BEAM_WIDTH


	beam.Width1 =
		STOCK_BEAM_WIDTH


	beam.FaceCamera =
		true


	beam.LightEmission =
		1


	beam.LightInfluence =
		0


	beam.Transparency =
		NumberSequence.new({
			NumberSequenceKeypoint.new(
				0,
				0.05
			),

			NumberSequenceKeypoint.new(
				1,
				0.15
			),
		})


	--
	-- A slight curve makes the direction line easier
	-- to see instead of hiding directly against the floor.
	--
	beam.CurveSize0 =
		3


	beam.CurveSize1 =
		3


	beam.Parent =
		root


	stockGuidePlayerAttachment =
		playerAttachment


	stockGuideTargetAttachment =
		targetAttachment


	stockGuideBeam =
		beam


	stockGuideTargetPart =
		targetPart
end


local function startStockGuideBeam()

	clearStockGuideBeam()


	stockGuideThread =
		task.spawn(
			function()

				while player.Parent
					and tutorialRunning
					and activeTutorialId
						== "Stock"
					and not skipRequested do

					local root =
						getCharacterRoot()


					if not root then

						task.wait(
							0.25
						)

						continue
					end


					local nearestPart =
						getNearestStockTouchPart()


					if nearestPart
						and (
							stockGuideTargetPart
								~= nearestPart
							or not stockGuideBeam
							or not stockGuideBeam.Parent
						) then

						createStockGuideBeamForTarget(
							nearestPart
						)
					end


					task.wait(
						0.25
					)
				end
			end
		)
end

--==================================================
-- WORLD HIGHLIGHTS
--==================================================

local function clearWorldHighlights()

	for _, highlight in
		worldHighlights do

		if highlight.Parent then
			highlight:Destroy()
		end
	end


	table.clear(
		worldHighlights
	)
end


local function highlightStockShop()

	clearWorldHighlights()


	if not touchForStock then
		return
	end


	local adorneeCandidates = {}


	if touchForStock:IsA(
		"BasePart"
	)
		or touchForStock:IsA(
			"Model"
		) then

		table.insert(
			adorneeCandidates,
			touchForStock
		)
	end


	for _, descendant in
		touchForStock:GetDescendants()
	do

		if descendant:IsA(
			"Model"
		) then

			table.insert(
				adorneeCandidates,
				descendant
			)
		end
	end


	--
	-- Avoid creating dozens of highlights if the
	-- stock shop contains lots of nested models.
	--
	for index = 1,
		math.min(
			#adorneeCandidates,
			4
		)
	do

		local highlight =
			Instance.new(
				"Highlight"
			)


		highlight.Name =
			"ContextualStockHighlight"


		highlight.FillColor =
			TUTORIAL_HIGHLIGHT_COLOR


		highlight.OutlineColor =
			Color3.new(
				1,
				1,
				1
			)


		highlight.FillTransparency =
			0.65


		highlight.OutlineTransparency =
			0


		highlight.DepthMode =
			Enum.HighlightDepthMode.AlwaysOnTop


		highlight.Adornee =
			adorneeCandidates[
				index
			]


		highlight.Parent =
			Workspace


		table.insert(
			worldHighlights,
			highlight
		)
	end
end


--==================================================
-- GENERIC WAIT HELPERS
--==================================================

local function waitForCondition(
	callback: () -> boolean,
	timeout: number?
): boolean

	local startedAt =
		time()


	while player.Parent do

		if skipRequested then
			return false
		end


		if callback() then
			return true
		end


		if timeout
			and time() - startedAt
				>= timeout then

			return false
		end


		task.wait(
			0.1
		)
	end


	return false
end


local function waitForButton(
	button: GuiButton
): boolean

	local pressed =
		false


	local connection =
		button.Activated:Connect(
			function()

				pressed =
					true
			end
		)


	highlightGui(
		button
	)


	local success =
		waitForCondition(
			function()

				return pressed

			end
		)


	connection:Disconnect()


	clearHighlight()


	return success
end


local function waitForVisible(
	object: GuiObject
): boolean

	return waitForCondition(
		function()

			return object.Visible

		end
	)
end


local function getClickable(
	object: GuiObject
):
	GuiButton?

	if object:IsA(
		"GuiButton"
	) then

		return object
	end


	local button =
		object:FindFirstChildWhichIsA(
			"GuiButton",
			true
		)


	if button then
		return button
	end


	return nil
end


--==================================================
-- COMPLETION
--==================================================

local function markCompleted(
	tutorialId: string
)

	if completed[
		tutorialId
	] then

		return
	end


	completed[
		tutorialId
	] =
		true


	local success,
		result =
		pcall(
			function()

				return completeContextualTutorialRemote
					:InvokeServer(
						tutorialId
					)

			end
		)


	if not success
		or result ~= true then

		warn(
			`[ContextualTutorial] Failed to save "{tutorialId}".`
		)
	end
end


--==================================================
-- STOCK HELPERS
--==================================================

local function getStockNumbers(
	stand: Model
): (
	number?,
	number?
)

	local stock =
		stand:GetAttribute(
			"Stock"
		)


	local maximum =
		stand:GetAttribute(
			"MaxStock"
		)


	if typeof(stock)
			~= "number"
		or typeof(maximum)
			~= "number"
		or maximum <= 0 then

		return nil,
			nil
	end


	return stock,
		maximum
end


local function findLowStockStand():
	Model?

	local folder =
		getPlacedBusinesses()


	if not folder then
		return nil
	end


	for _, child in
		folder:GetChildren()
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


		local stock,
			maximum =
			getStockNumbers(
				child
			)


		if stock
			and maximum
			and stock / maximum
				<= STOCK_TRIGGER_PERCENT then

			return child
		end
	end


	return nil
end


--==================================================
-- STOCK TUTORIAL
--==================================================

local function runStockTutorial()

	local stand =
		findLowStockStand()


	if not stand then
		return
	end


	local startingStock =
		stand:GetAttribute(
			"Stock"
		)


	if typeof(startingStock)
		~= "number" then

		return
	end


	showTutorial(
		"LOW STOCK!",
		"Your business is running low on stock. When stock reaches 0, it cannot serve customers."
	)


	if not showTimedMessage(
		"LOW STOCK!",
		"Your business is running low on stock. When stock reaches 0, it cannot serve customers.",
		MESSAGE_TIME
	) then

		return
	end


	highlightStockShop()
	
	
	startStockGuideBeam()
	
	
	setTutorialText(
		"RESTOCK YOUR BUSINESS",
		"Follow the yellow guide to the nearest Stock Shop!"
	)
	
	
	local reachedShop =
		waitForVisible(
			stockMain
		)
	
	
	--
	-- They reached a stock shop, so the directional
	-- beam is no longer needed.
	--
	clearStockGuideBeam()
	
	
	clearWorldHighlights()


	if not reachedShop then
		return
	end


	setTutorialText(
		"REFILL YOUR STOCK",
		"Use Restock All to refill your businesses. Keeping stock filled keeps your money flowing!"
	)


	highlightGui(
		restockAllButton
	)


	local restocked =
		waitForCondition(
			function()

				if not stand.Parent then
					return true
				end


				local currentStock =
					stand:GetAttribute(
						"Stock"
					)


				return typeof(currentStock)
						== "number"
					and currentStock
						> startingStock

			end
		)


	clearHighlight()


	if not restocked then
		return
	end


	showTimedMessage(
		"STOCK REFILLED!",
		"Perfect! If a business ever stops serving, check its stock first.",
		SHORT_MESSAGE_TIME
	)
end


--==================================================
-- MARKETING TUTORIAL
--==================================================

local function runMarketingTutorial()

	local plot =
		getOwnedPlot()


	if not plot then
		return
	end


	local startingLevel =
		plot:GetAttribute(
			"MarketingLevel"
		)


	if typeof(startingLevel)
		~= "number" then

		startingLevel =
			0
	end


	showTutorial(
		"GET MORE CUSTOMERS",
		"Your business is growing! Marketing lets more customers visit you at once."
	)


	if not showTimedMessage(
		"GET MORE CUSTOMERS",
		"Your business is growing! Marketing lets more customers visit you at once.",
		MESSAGE_TIME
	) then

		return
	end


	setTutorialText(
		"OPEN MANAGEMENT",
		"Open Management to upgrade your Marketing."
	)


	if not manageMain.Visible then

		if not waitForButton(
			manageOpenButton
		) then

			return
		end


		if not waitForVisible(
			manageMain
		) then

			return
		end
	end


	setTutorialText(
		"MARKETING",
		"Open the Marketing tab. More Marketing = more customers = more sales."
	)


	if not waitForButton(
		marketingButton
	) then

		return
	end


	setTutorialText(
		"UPGRADE MARKETING",
		"Buy your first Marketing upgrade to increase your customer limit."
	)


	highlightGui(
		marketingBuyButton
	)


	local upgraded =
		waitForCondition(
			function()

				local currentLevel =
					plot:GetAttribute(
						"MarketingLevel"
					)


				return typeof(currentLevel)
						== "number"
					and currentLevel
						> startingLevel

			end
		)


	clearHighlight()


	if not upgraded then
		return
	end


	showTimedMessage(
		"MORE CUSTOMERS!",
		"Nice! Upgrade Marketing whenever your businesses are ready for more customer traffic.",
		SHORT_MESSAGE_TIME
	)
end


--==================================================
-- PLOT EXPANSION TUTORIAL
--==================================================

local function runPlotTutorial()

	local plot =
		getOwnedPlot()


	if not plot then
		return
	end


	local startingLevel =
		plot:GetAttribute(
			"PlotLevel"
		)


	if typeof(startingLevel)
		~= "number" then

		startingLevel =
			0
	end


	showTutorial(
		"YOUR EMPIRE NEEDS ROOM",
		"You can expand your plot to create more room for businesses."
	)


	if not showTimedMessage(
		"YOUR EMPIRE NEEDS ROOM",
		"You can expand your plot to create more room for businesses.",
		MESSAGE_TIME
	) then

		return
	end


	setTutorialText(
		"OPEN MANAGEMENT",
		"Open Management to find your Plot upgrades."
	)


	if not manageMain.Visible then

		if not waitForButton(
			manageOpenButton
		) then

			return
		end


		if not waitForVisible(
			manageMain
		) then

			return
		end
	end


	setTutorialText(
		"PLOT EXPANSIONS",
		"Open the Plot tab."
	)


	if not waitForButton(
		plotButton
	) then

		return
	end


	setTutorialText(
		"EXPAND YOUR PLOT",
		"Buy the expansion to make your building area larger."
	)


	highlightGui(
		plotBuyButton
	)


	local expanded =
		waitForCondition(
			function()

				local currentLevel =
					plot:GetAttribute(
						"PlotLevel"
					)


				return typeof(currentLevel)
						== "number"
					and currentLevel
						> startingLevel

			end
		)


	clearHighlight()


	if not expanded then
		return
	end


	showTimedMessage(
		"MORE ROOM!",
		"Your plot is bigger! Expand again later whenever your empire needs more space.",
		SHORT_MESSAGE_TIME
	)
end


--==================================================
-- LICENSE TUTORIAL
--==================================================

local function runLicenseTutorial()

	local startingLicenses =
		player:GetAttribute(
			"Licenses"
		)


	if typeof(startingLicenses)
			~= "number"
		or startingLicenses < 1 then

		return
	end


	showTutorial(
		"YOU EARNED A LICENSE!",
		"Licenses buy powerful long-term upgrades for your entire business empire."
	)


	if not showTimedMessage(
		"YOU EARNED A LICENSE!",
		"Licenses buy powerful long-term upgrades for your entire business empire.",
		MESSAGE_TIME
	) then

		return
	end


	setTutorialText(
		"OPEN LICENSES",
		"Open the Licenses menu."
	)


	if not waitForButton(
		licensesOpenButton
	) then

		return
	end


	if not waitForVisible(
		licensesMain
	) then

		return
	end


	setTutorialText(
		"LICENSE UPGRADES",
		"Open Upgrades to spend your License."
	)


	local upgradesClickable =
		getClickable(
			licenseUpgradesObject
		)


	if upgradesClickable then

		if not waitForButton(
			upgradesClickable
		) then

			return
		end

	else

		if not waitForCondition(
			function()

				return licenseUpgradesFrame.Visible

			end
		) then

			return
		end
	end


	local operationCard =
		licenseUpgradesFrame:
			FindFirstChild(
				"Operations"
			)


	if operationCard then

		local buyButton =
			operationCard:
				FindFirstChild(
					"Buy",
					true
				)


		if buyButton
			and buyButton:IsA(
				"GuiButton"
			) then

			setTutorialText(
				"BUY A PERMANENT UPGRADE",
				"Try the Operations License. License upgrades strengthen your entire empire."
			)


			highlightGui(
				buyButton
			)
		end
	end


	local purchased =
		waitForCondition(
			function()

				local current =
					player:GetAttribute(
						"Licenses"
					)


				return typeof(current)
						== "number"
					and current
						< startingLicenses

			end
		)


	clearHighlight()


	if not purchased then
		return
	end


	showTimedMessage(
		"PERMANENT PROGRESS!",
		"Great! Keep earning Licenses from milestones and use them for permanent bonuses.",
		SHORT_MESSAGE_TIME
	)
end


--==================================================
-- REBIRTH TUTORIAL
--==================================================

local function runRebirthTutorial()

	showTutorial(
		"REBIRTH READY!",
		"You've grown far enough to Rebirth. Rebirth resets your current run in exchange for permanent bonuses."
	)


	if not showTimedMessage(
		"REBIRTH READY!",
		"You've grown far enough to Rebirth. Rebirth resets your current run in exchange for permanent bonuses.",
		MESSAGE_TIME
	) then

		return
	end


	setTutorialText(
		"OPEN REBIRTH",
		"Open the Rebirth menu to see what you'll gain."
	)


	if not waitForButton(
		rebirthOpenButton
	) then

		return
	end


	if not waitForVisible(
		rebirthMain
	) then

		return
	end


	if not showTimedMessage(
		"PERMANENT BONUSES",
		"Rebirth gives permanent Cash, Customer Speed, and Rare Customer bonuses that make future runs faster.",
		MESSAGE_TIME
	) then

		return
	end


	highlightGui(
		rebirthButton
	)


	showTimedMessage(
		"REBIRTH WHEN YOU'RE READY",
		"You do NOT have to Rebirth right now. When you're ready, this button starts your next stronger run.",
		MESSAGE_TIME
	)


	clearHighlight()
end


--==================================================
-- RUNNER MAP
--==================================================

runners.Stock =
	runStockTutorial

runners.Marketing =
	runMarketingTutorial

runners.PlotExpansion =
	runPlotTutorial

runners.Licenses =
	runLicenseTutorial

runners.Rebirth =
	runRebirthTutorial


--==================================================
-- QUEUE
--==================================================

local function getNextQueuedTutorial():
	string?

	local bestId =
		nil


	local bestPriority =
		math.huge


	for tutorialId in
		queued
	do

		if not completed[
			tutorialId
		] then

			local priority =
				PRIORITY[
					tutorialId
				]
				or 999


			if priority
				< bestPriority then

				bestPriority =
					priority


				bestId =
					tutorialId
			end
		end
	end


	return bestId
end


local function enqueue(
	tutorialId: string
)

	if completed[
		tutorialId
		]
		or queued[
			tutorialId
		]
		or activeTutorialId
			== tutorialId then

		return
	end


	queued[
		tutorialId
	] =
		true
end


--==================================================
-- SKIP
--==================================================

skipButton.Activated:Connect(
	function()

		if not tutorialRunning
			or not activeTutorialId then

			return
		end


		skipRequested =
			true


		clearHighlight()

		clearWorldHighlights()

		clearStockGuideBeam()
	end
)


--==================================================
-- QUEUE PROCESSOR
--==================================================

task.spawn(
	function()

		while player.Parent do

			if tutorialRunning then

				task.wait(
					0.25
				)

				continue
			end


			local tutorialId =
				getNextQueuedTutorial()


			if not tutorialId then

				task.wait(
					0.25
				)

				continue
			end


			queued[
				tutorialId
			] =
				nil


			local runner =
				runners[
					tutorialId
				]


			if not runner then

				completed[
					tutorialId
				] =
					true

				continue
			end


			tutorialRunning =
				true


			activeTutorialId =
				tutorialId


			skipRequested =
				false


			local success,
				err =
				pcall(
					runner
				)


			clearHighlight()
			
			clearWorldHighlights()
			
			clearStockGuideBeam()
			
			hideTutorial()


			if not success then

				warn(
					`[ContextualTutorial] {tutorialId} failed: {err}`
				)
			end


			--
			-- Completing OR skipping counts as seen.
			-- We don't want to nag players repeatedly.
			--
			markCompleted(
				tutorialId
			)


			activeTutorialId =
				nil


			tutorialRunning =
				false


			skipRequested =
				false


			task.wait(
				0.5
			)
		end
	end
)


--==================================================
-- WAIT FOR MAIN TUTORIAL
--==================================================

local function waitForMainTutorial()

	local success,
		state =
		pcall(
			function()

				return getTutorialStateRemote
					:InvokeServer()

			end
		)


	if success
		and type(state)
			== "table"
		and state.Completed
			== true then

		return
	end


	while player.Parent
		and player:GetAttribute(
			"TutorialCompleted"
		) ~= true do

		player:GetAttributeChangedSignal(
			"TutorialCompleted"
		):Wait()
	end
end


waitForMainTutorial()


--==================================================
-- LOAD COMPLETED CONTEXTUAL TUTORIALS
--==================================================

do

	local success,
		state =
		pcall(
			function()

				return getContextualTutorialStateRemote
					:InvokeServer()

			end
		)


	if success
		and type(state)
			== "table"
		and state.Success
			== true
		and type(state.Completed)
			== "table" then

		for tutorialId,
			wasCompleted in
			state.Completed
		do

			if wasCompleted
				== true then

				completed[
					tutorialId
				] =
					true
			end
		end
	end
end


--==================================================
-- STOCK WATCH
--==================================================

task.spawn(
	function()

		while player.Parent
			and not completed.Stock do

			if findLowStockStand() then

				enqueue(
					"Stock"
				)

				return
			end


			task.wait(
				CHECK_INTERVAL
			)
		end
	end
)


--==================================================
-- MARKETING WATCH
--==================================================

task.spawn(
	function()

		while player.Parent
			and not completed.Marketing do

			local success,
				state =
				pcall(
					function()

						return getMarketingStateRemote
							:InvokeServer()

					end
				)


			if success
				and type(state)
					== "table"
				and state.Success
					== true
				and state.CurrentLevel
					== 0
				and typeof(state.NextCost)
					== "number"
				and cash.Value
					>= state.NextCost then

				enqueue(
					"Marketing"
				)

				return
			end


			task.wait(
				2
			)
		end
	end
)


--==================================================
-- PLOT EXPANSION WATCH
--==================================================

task.spawn(
	function()

		while player.Parent
			and not completed.PlotExpansion do

			local success,
				state =
				pcall(
					function()

						return getPlotExpansionStateRemote
							:InvokeServer()

					end
				)


			if success
				and type(state)
					== "table"
				and state.Success
					== true
				and state.CurrentLevel
					== 0
				and typeof(state.NextCost)
					== "number"
				and cash.Value
					>= state.NextCost then

				enqueue(
					"PlotExpansion"
				)

				return
			end


			task.wait(
				3
			)
		end
	end
)


--==================================================
-- LICENSE WATCH
--==================================================

task.spawn(
	function()

		while player.Parent
			and not completed.Licenses do

			local licenses =
				player:GetAttribute(
					"Licenses"
				)


			if typeof(licenses)
					== "number"
				and licenses >= 1 then

				enqueue(
					"Licenses"
				)

				return
			end


			task.wait(
				1
			)
		end
	end
)


--==================================================
-- REBIRTH WATCH
--==================================================

task.spawn(
	function()

		while player.Parent
			and not completed.Rebirth do

			local success,
				state =
				pcall(
					function()

						return getRebirthStateRemote
							:InvokeServer()

					end
				)


			if success
				and type(state)
					== "table"
				and state.Success
					== true
				and state.CanRebirth
					== true then

				enqueue(
					"Rebirth"
				)

				return
			end


			task.wait(
				5
			)
		end
	end
)