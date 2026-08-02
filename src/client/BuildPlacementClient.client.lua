local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local UITheme = require(
	ReplicatedStorage
		:WaitForChild("Shared")
		:WaitForChild("UITheme")
)

local BusinessConfig = require(
	ReplicatedStorage
		:WaitForChild("Shared")
		:WaitForChild("BusinessConfig")
)

local lemonadeConfig =
	BusinessConfig.LemonadeStand

local MAXIMUM_STANDS =
	lemonadeConfig.MaximumPlaced or 3

local ADDITIONAL_STAND_COST =
	lemonadeConfig.AdditionalStandCost or 750

local Colors = UITheme.Colors
local Fonts = UITheme.Fonts

local IS_TOUCH_DEVICE =
	UserInputService.TouchEnabled

local businessModels =
	ReplicatedStorage:WaitForChild("BusinessModels")

local remotes =
	ReplicatedStorage:WaitForChild("Remotes")

local placeBusinessRemote =
	remotes:WaitForChild("PlaceBusiness")

local interactionResultRemote =
	remotes:WaitForChild("BusinessInteractionResult")

local cancelEditRemote =
	remotes:WaitForChild("CancelBusinessEdit")

local plotsFolder =
	Workspace:WaitForChild("Plots")

local BUSINESS_NAME = "LemonadeStand"

local ROTATION_INCREMENT = 90
local GRID_SIZE = 1

local previewModel: Model? = nil
local ownedPlot: Model? = nil
local originalStand: Model? = nil

local currentPlacementCFrame: CFrame? = nil
local lastTouchPosition: Vector2? = nil

local rotationY = 0

local isPlacementActive = false
local isEditingExistingStand = false
local placementValid = false
local waitingForServer = false

local function getOwnedPlot(): Model?
	local plotName =
		player:GetAttribute("PlotName")

	if typeof(plotName) == "string" then
		local plot =
			plotsFolder:FindFirstChild(plotName)

		if plot
			and plot:IsA("Model")
			and plot:GetAttribute("OwnerUserId")
			== player.UserId then

			return plot
		end
	end

	for _, plot in plotsFolder:GetChildren() do
		if plot:IsA("Model")
			and plot:GetAttribute("OwnerUserId")
			== player.UserId then

			return plot
		end
	end

	return nil
end

local function getBusinessType(
	business: Model
): string
	local businessType =
		business:GetAttribute("BusinessType")

	if typeof(businessType) == "string"
		and businessType ~= "" then

		return businessType
	end

	if string.match(
		business.Name,
		"^LemonadeStand"
	) then

		return BUSINESS_NAME
	end

	return business.Name
end


local function getLemonadeStands(): {Model}
	if not ownedPlot then
		return {}
	end

	local placedBusinesses =
		ownedPlot:FindFirstChild(
			"PlacedBusinesses"
		)

	if not placedBusinesses then
		return {}
	end

	local stands = {}

	for _, child in
		placedBusinesses:GetChildren() do

		if not child:IsA("Model") then
			continue
		end

		if getBusinessType(child)
			== BUSINESS_NAME then

			table.insert(stands, child)
		end
	end

	return stands
end

local function findStandByBusinessId(
	businessId: string
): Model?
	if not ownedPlot
		or type(businessId) ~= "string"
		or businessId == "" then

		return nil
	end

	local placedBusinesses =
		ownedPlot:FindFirstChild(
			"PlacedBusinesses"
		)

	if not placedBusinesses then
		return nil
	end

	for _, child in
		placedBusinesses:GetChildren() do

		if not child:IsA("Model") then
			continue
		end

		if getBusinessType(child)
			~= BUSINESS_NAME then

			continue
		end

		if child:GetAttribute(
			"OwnerUserId"
		) ~= player.UserId then

			continue
		end

		local childBusinessId =
			child:GetAttribute(
				"BusinessId"
			)

		if childBusinessId == businessId
			or child.Name == businessId then

			return child
		end
	end

	return nil
end

local function getStandCount(): number
	return #getLemonadeStands()
end

local function createInterface()
	local existing =
		playerGui:FindFirstChild("BuildMenu")

	if existing then
		existing:Destroy()
	end

	local screenGui =
		Instance.new("ScreenGui")

	screenGui.Name = "BuildMenu"
	screenGui.ResetOnSpawn = false
	screenGui.IgnoreGuiInset = false
	screenGui.DisplayOrder = 20
	screenGui.Parent = playerGui

	local menuShadow = Instance.new("Frame")
	menuShadow.Name = "MenuShadow"
	menuShadow.AnchorPoint =
	Vector2.new(0.5, 1)

menuShadow.Position =
	UDim2.fromScale(0.508, 0.975)

menuShadow.Size =
	UDim2.fromScale(0.32, 0.22)

	menuShadow.BackgroundColor3 =
		Colors.Shadow

	menuShadow.BackgroundTransparency = 0.28
	menuShadow.BorderSizePixel = 0
	menuShadow.Parent = screenGui

	UITheme.AddCorner(menuShadow, 0.07)

	local menu = Instance.new("Frame")
	menu.Name = "Menu"
	menu.AnchorPoint =
	Vector2.new(0.5, 1)

menu.Position =
	UDim2.fromScale(0.5, 0.965)

menu.Size =
	UDim2.fromScale(0.32, 0.22)

	menu.BackgroundColor3 =
		Colors.Surface

	menu.BorderSizePixel = 0
	menu.Parent = screenGui

	UITheme.AddCorner(menu, 0.07)

	UITheme.AddStroke(
		menu,
		Colors.Primary,
		2,
		0.2
	)

	UITheme.AddGradient(
		menu,
		Colors.SurfaceRaised,
		Colors.Background
	)

	local accent = Instance.new("Frame")
	accent.Name = "Accent"
	accent.Position =
		UDim2.fromScale(0.035, 0.08)

	accent.Size =
		UDim2.fromScale(0.025, 0.84)

	accent.BackgroundColor3 =
		Colors.Primary

	accent.BorderSizePixel = 0
	accent.Parent = menu

	UITheme.AddCorner(accent, 0.5)

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.Position =
	UDim2.fromScale(0.09, 0.07)

title.Size =
	UDim2.fromScale(0.84, 0.13)
	
	title.BackgroundTransparency = 1
	title.Text = "BUILD YOUR BUSINESS"
	title.TextXAlignment =
		Enum.TextXAlignment.Left

	title.Parent = menu

	UITheme.StyleText(
		title,
		12,
		20,
		Colors.Text,
		Fonts.Black
	)

	local subtitle = Instance.new("TextLabel")
	subtitle.Name = "Subtitle"
	subtitle.Position =
	UDim2.fromScale(0.09, 0.21)

subtitle.Size =
	UDim2.fromScale(0.84, 0.1)

	subtitle.BackgroundTransparency = 1
	subtitle.Text =
		"Start earning with your first stand."

	subtitle.TextXAlignment =
		Enum.TextXAlignment.Left

	subtitle.Parent = menu

	UITheme.StyleText(
		subtitle,
		9,
		13,
		Colors.TextMuted,
		Fonts.Medium
	)

	local buildButton =
		Instance.new("TextButton")

	buildButton.Name =
		"LemonadeStandButton"

	buildButton.Position =
		UDim2.fromScale(0.09, 0.42)

	buildButton.Size =
		UDim2.fromScale(0.84, 0.3)

	buildButton.Text =
		"BUILD LEMONADE STAND"

	buildButton.Parent = menu

	UITheme.StyleText(
		buildButton,
		11,
		18,
		Colors.TextDark,
		Fonts.Black
	)

	UITheme.StyleButton(
		buildButton,
		Colors.Primary,
		Colors.PrimaryDark,
		Colors.TextDark
	)

	local instructions =
		Instance.new("TextLabel")

	instructions.Name = "Instructions"
	instructions.Position =
		UDim2.fromScale(0.09, 0.78)

	instructions.Size =
		UDim2.fromScale(0.84, 0.12)

	instructions.BackgroundTransparency = 1

	instructions.Text =
		IS_TOUCH_DEVICE
		and "Tap the plot, then use the controls."
		or "Click to place  •  R rotate"

	instructions.TextXAlignment =
		Enum.TextXAlignment.Center

	instructions.Parent = menu

	UITheme.StyleText(
		instructions,
		8,
		12,
		Colors.TextMuted,
		Fonts.Medium
	)

	local status = Instance.new("TextLabel")
	status.Name = "Status"
	status.AnchorPoint =
		Vector2.new(0.5, 0)

	status.Position =
		UDim2.fromScale(0.5, 0.055)

	status.Size =
		UDim2.fromScale(0.52, 0.075)

	status.BackgroundColor3 =
		Colors.Surface

	status.BackgroundTransparency = 0.03
	status.BorderSizePixel = 0
	status.Text = ""
	status.Visible = false
	status.ZIndex = 15
	status.Parent = screenGui

	UITheme.AddCorner(status, 0.25)

	UITheme.AddStroke(
		status,
		Colors.Stroke,
		1.5,
		0.2
	)

	UITheme.StyleText(
		status,
		11,
		17,
		Colors.Text,
		Fonts.Bold
	)

	local controls = Instance.new("Frame")
	controls.Name = "PlacementControls"
	controls.AnchorPoint =
		Vector2.new(0.5, 1)

	controls.Position =
		UDim2.fromScale(0.5, 0.96)

	controls.Size =
		UDim2.fromScale(0.5, 0.095)

	controls.BackgroundColor3 =
		Colors.Surface

	controls.BackgroundTransparency = 0.02
	controls.BorderSizePixel = 0
	controls.Visible = false
	controls.ZIndex = 20
	controls.Parent = screenGui

	UITheme.AddCorner(controls, 0.18)

	UITheme.AddStroke(
		controls,
		Colors.Primary,
		1.5,
		0.25
	)

	UITheme.AddPadding(
		controls,
		0.035,
		0.035,
		0.14,
		0.14
	)

	local controlLayout =
		Instance.new("UIListLayout")

	controlLayout.FillDirection =
		Enum.FillDirection.Horizontal

	controlLayout.HorizontalAlignment =
		Enum.HorizontalAlignment.Center

	controlLayout.VerticalAlignment =
		Enum.VerticalAlignment.Center

	controlLayout.Padding =
		UDim.new(0.035, 0)

	controlLayout.Parent = controls

	local function createControlButton(
		name: string,
		text: string,
		topColor: Color3,
		bottomColor: Color3
	): TextButton
		local button =
			Instance.new("TextButton")

		button.Name = name
		button.Size =
			UDim2.fromScale(0.31, 1)

		button.Text = text
		button.ZIndex = 21
		button.Parent = controls

		button.TextColor3 = Colors.Text
		button.TextTransparency = 0

		UITheme.StyleText(
			button,
			10,
			16,
			Colors.Text,
			Fonts.Black
		)

		UITheme.StyleButton(
			button,
			topColor,
			bottomColor
		)

		button.TextColor3 = Colors.Text
button.TextTransparency = 0

		return button
	end

	local rotateButton = createControlButton(
	"RotateButton",
	"ROTATE",
	Colors.Info,
	Colors.InfoDark
)

local placeButton = createControlButton(
	"PlaceButton",
	"PLACE",
	Colors.Success,
	Colors.SuccessDark
)

local cancelButton = createControlButton(
	"CancelButton",
	"CANCEL",
	Colors.Danger,
	Colors.DangerDark
)

	local function updateResponsiveLayout()
	local camera = Workspace.CurrentCamera

	if not camera then
		return
	end

	local viewport =
		camera.ViewportSize

	local portrait =
		viewport.Y > viewport.X

	local compact =
		viewport.X < 800
		or viewport.Y < 550

	menu.AnchorPoint =
		Vector2.new(0.5, 1)

	menuShadow.AnchorPoint =
		Vector2.new(0.5, 1)

	if portrait then
		menu.Position =
			UDim2.fromScale(0.5, 0.965)

		menu.Size =
			UDim2.fromScale(0.92, 0.21)

		menuShadow.Position =
			UDim2.fromScale(0.508, 0.975)

		menuShadow.Size =
			UDim2.fromScale(0.92, 0.21)

		controls.Size =
			UDim2.fromScale(0.94, 0.1)

		status.Size =
			UDim2.fromScale(0.9, 0.07)
	elseif compact then
		menu.Position =
			UDim2.fromScale(0.5, 0.965)

		menu.Size =
			UDim2.fromScale(0.48, 0.32)

		menuShadow.Position =
			UDim2.fromScale(0.508, 0.975)

		menuShadow.Size =
			UDim2.fromScale(0.48, 0.32)

		controls.Size =
			UDim2.fromScale(0.68, 0.13)

		status.Size =
			UDim2.fromScale(0.65, 0.1)
	else
		menu.Position =
			UDim2.fromScale(0.5, 0.965)

		menu.Size =
			UDim2.fromScale(0.32, 0.22)

		menuShadow.Position =
			UDim2.fromScale(0.508, 0.975)

		menuShadow.Size =
			UDim2.fromScale(0.32, 0.22)

		controls.Size =
			UDim2.fromScale(0.5, 0.095)

		status.Size =
			UDim2.fromScale(0.52, 0.075)
	end
end

	updateResponsiveLayout()

	local camera = Workspace.CurrentCamera

	if camera then
		camera:GetPropertyChangedSignal(
			"ViewportSize"
		):Connect(updateResponsiveLayout)
	end

	return {
	ScreenGui = screenGui,
	Menu = menu,
	MenuShadow = menuShadow,

	BuildButton = buildButton,
	Subtitle = subtitle,
	StatusLabel = status,

	PlacementControls = controls,
	RotateButton = rotateButton,
	PlaceButton = placeButton,
	CancelButton = cancelButton,
}
end

local interface = createInterface()

local screenGui = interface.ScreenGui
local menu = interface.Menu
local menuShadow = interface.MenuShadow

local buildButton = interface.BuildButton
local buildSubtitle =
	interface.Subtitle
local statusLabel = interface.StatusLabel

local placementControls =
	interface.PlacementControls

local rotateButton =
	interface.RotateButton

local placeButton =
	interface.PlaceButton

local cancelPlacementButton =
	interface.CancelButton

local statusVersion = 0

local function setBuildMenuVisible(
	visible: boolean
)
	menu.Visible = visible
	menuShadow.Visible = visible
end

local function updateBuildMenu()
	local standCount =
		getStandCount()

	local remaining =
		math.max(
			0,
			MAXIMUM_STANDS - standCount
		)

	if standCount == 0 then
		buildButton.Text =
			"BUILD FIRST STAND — FREE"

		buildSubtitle.Text =
			`0 / {MAXIMUM_STANDS} stands placed`
	elseif standCount
		< MAXIMUM_STANDS then

		buildButton.Text =
			`BUILD ANOTHER — ${ADDITIONAL_STAND_COST}`

		buildSubtitle.Text =
			`{standCount} / {MAXIMUM_STANDS} stands placed`
	else
		buildButton.Text =
			"MAXIMUM STANDS PLACED"

		buildSubtitle.Text =
			`{MAXIMUM_STANDS} / {MAXIMUM_STANDS} stands placed`
	end

	UITheme.SetButtonEnabled(
		buildButton,
		remaining > 0,
		Colors.Primary,
		Colors.PrimaryDark
	)

	buildButton.TextColor3 =
		Color3.fromRGB(255, 255, 255)

	buildButton.TextTransparency = 0
end

local function showStatus(
	message: string,
	duration: number?
)
	statusVersion += 1

	local version = statusVersion

	statusLabel.Text = message
	statusLabel.Visible = true

	if duration then
		task.delay(duration, function()
			if statusVersion == version then
				statusLabel.Visible = false
			end
		end)
	end
end

local function setOriginalStandVisible(
	visible: boolean
)
	if not originalStand then
		return
	end

	for _, descendant in
		originalStand:GetDescendants() do

		if descendant:IsA("BasePart") then
			descendant.LocalTransparencyModifier =
				visible and 0 or 1
		elseif descendant:IsA("BillboardGui") then
			descendant.Enabled = visible
		end
	end
end

local function createPlacementBox(
	model: Model
)
	local placementBounds =
		model:FindFirstChild(
			"PlacementBounds",
			true
		)

	if not placementBounds
		or not placementBounds:IsA("BasePart") then

		warn(
			"LemonadeStand preview is missing PlacementBounds."
		)

		return
	end

	local selectionBox =
		Instance.new("SelectionBox")

	selectionBox.Name = "PlacementBox"
	selectionBox.Adornee = placementBounds
	selectionBox.LineThickness = 0.08
	selectionBox.SurfaceTransparency = 0.82

	selectionBox.Color3 =
		Colors.Success

	selectionBox.SurfaceColor3 =
		Colors.Success

	selectionBox.Parent = model
end

local function preparePreview(
	model: Model
)
	for _, descendant in
		model:GetDescendants() do

		if descendant:IsA("BasePart") then
			descendant.Anchored = true
			descendant.CanCollide = false
			descendant.CanTouch = false
			descendant.CanQuery = false

			descendant.Transparency =
				math.max(
					descendant.Transparency,
					0.45
				)
		elseif descendant:IsA("Script")
			or descendant:IsA("LocalScript") then

			descendant.Enabled = false
		elseif descendant:IsA("ProximityPrompt") then
			descendant.Enabled = false
		elseif descendant:IsA("BillboardGui") then
			descendant.Enabled = false
		end
	end

	local highlight =
		Instance.new("Highlight")

	highlight.Name = "PlacementHighlight"
	highlight.FillTransparency = 0.7
	highlight.OutlineTransparency = 0

	highlight.DepthMode =
		Enum.HighlightDepthMode.AlwaysOnTop

	highlight.Parent = model

	createPlacementBox(model)
end

local function setPreviewColor(
	valid: boolean
)
	if not previewModel then
		return
	end

	local highlight =
		previewModel:FindFirstChild(
			"PlacementHighlight"
		)

	local placementBox =
		previewModel:FindFirstChild(
			"PlacementBox"
		)

	local fillColor
	local outlineColor

	if valid then
		fillColor = Colors.Success
		outlineColor =
			Colors.SuccessDark
	else
		fillColor = Colors.Danger
		outlineColor =
			Colors.DangerDark
	end

	if highlight
		and highlight:IsA("Highlight") then

		highlight.FillColor = fillColor
		highlight.OutlineColor =
			outlineColor
	end

	if placementBox
		and placementBox:IsA("SelectionBox") then

		placementBox.Color3 = fillColor
		placementBox.SurfaceColor3 =
			fillColor
	end
end

local function snapToGrid(
	value: number
): number
	return math.round(value / GRID_SIZE)
		* GRID_SIZE
end

local function getPlacementCFrame(
	hitPosition: Vector3,
	ground: BasePart
): CFrame
	local groundPosition =
		ground.CFrame:PointToObjectSpace(
			hitPosition
		)

	local localX =
		snapToGrid(groundPosition.X)

	local localZ =
		snapToGrid(groundPosition.Z)

	return ground.CFrame
		* CFrame.new(
			localX,
			ground.Size.Y / 2,
			localZ
		)
		* CFrame.Angles(
			0,
			math.rad(rotationY),
			0
		)
end

local function isPreviewInsideGround(
	model: Model,
	ground: BasePart
): boolean
	local placementBounds =
		model:FindFirstChild(
			"PlacementBounds",
			true
		)

	if not placementBounds
		or not placementBounds:IsA("BasePart") then

		return false
	end

	local halfX =
		placementBounds.Size.X / 2

	local halfZ =
		placementBounds.Size.Z / 2

	local corners = {
		Vector3.new(-halfX, 0, -halfZ),
		Vector3.new(-halfX, 0, halfZ),
		Vector3.new(halfX, 0, -halfZ),
		Vector3.new(halfX, 0, halfZ),
	}

	for _, cornerOffset in corners do
		local worldCorner =
			placementBounds.CFrame
				:PointToWorldSpace(
					cornerOffset
				)

		local groundSpace =
			ground.CFrame
				:PointToObjectSpace(
					worldCorner
				)

		if math.abs(groundSpace.X)
			> ground.Size.X / 2
			or math.abs(groundSpace.Z)
			> ground.Size.Z / 2 then

			return false
		end
	end

	return true
end

local function rectanglesOverlapXZ(
	firstCFrame: CFrame,
	firstSize: Vector3,
	secondCFrame: CFrame,
	secondSize: Vector3
): boolean
	local firstRight =
		Vector3.new(
			firstCFrame.RightVector.X,
			0,
			firstCFrame.RightVector.Z
		).Unit

	local firstForward =
		Vector3.new(
			firstCFrame.LookVector.X,
			0,
			firstCFrame.LookVector.Z
		).Unit

	local secondRight =
		Vector3.new(
			secondCFrame.RightVector.X,
			0,
			secondCFrame.RightVector.Z
		).Unit

	local secondForward =
		Vector3.new(
			secondCFrame.LookVector.X,
			0,
			secondCFrame.LookVector.Z
		).Unit

	local offset =
		Vector3.new(
			secondCFrame.Position.X
				- firstCFrame.Position.X,
			0,
			secondCFrame.Position.Z
				- firstCFrame.Position.Z
		)

	local axes = {
		firstRight,
		firstForward,
		secondRight,
		secondForward,
	}

	local firstHalfX =
		firstSize.X / 2

	local firstHalfZ =
		firstSize.Z / 2

	local secondHalfX =
		secondSize.X / 2

	local secondHalfZ =
		secondSize.Z / 2

	for _, axis in axes do
		local distance =
			math.abs(
				offset:Dot(axis)
			)

		local firstRadius =
			math.abs(
				firstRight:Dot(axis)
			) * firstHalfX
			+ math.abs(
				firstForward:Dot(axis)
			) * firstHalfZ

		local secondRadius =
			math.abs(
				secondRight:Dot(axis)
			) * secondHalfX
			+ math.abs(
				secondForward:Dot(axis)
			) * secondHalfZ

		if distance >=
			firstRadius + secondRadius then

			return false
		end
	end

	return true
end

local function isPreviewOverlappingBusiness(
	model: Model
): boolean
	if not ownedPlot then
		return false
	end

	local placedBusinesses =
		ownedPlot:FindFirstChild(
			"PlacedBusinesses"
		)

	if not placedBusinesses then
		return false
	end

	local previewBounds =
		model:FindFirstChild(
			"PlacementBounds",
			true
		)

	if not previewBounds
		or not previewBounds:IsA("BasePart") then

		return true
	end

	for _, business in
		placedBusinesses:GetChildren() do

		if not business:IsA("Model")
			or business == originalStand then

			continue
		end

		local existingBounds =
			business:FindFirstChild(
				"PlacementBounds",
				true
			)

		if not existingBounds
			or not existingBounds:IsA(
				"BasePart"
			) then

			continue
		end

		if rectanglesOverlapXZ(
			previewBounds.CFrame,
			previewBounds.Size,
			existingBounds.CFrame,
			existingBounds.Size
		) then

			return true
		end
	end

	return false
end

local function destroyPreview()
	if previewModel then
		previewModel:Destroy()
		previewModel = nil
	end

	currentPlacementCFrame = nil
	placementValid = false
	waitingForServer = false
	isPlacementActive = false
end

local function finishPlacementMode()
	destroyPreview()

	setOriginalStandVisible(true)

	originalStand = nil
	isEditingExistingStand = false

	placementControls.Visible = false
end

local function startPlacement(
	editingExisting: boolean,
	businessId: string?
)
	if isPlacementActive then
		return
	end

	ownedPlot = getOwnedPlot()

	if not ownedPlot then
		showStatus(
			"Waiting for your plot...",
			2
		)

		return
	end

	local existingStand: Model? = nil

if editingExisting then
	if type(businessId) ~= "string"
		or businessId == "" then

		showStatus(
			"The selected lemonade stand could not be identified.",
			2
		)

		cancelEditRemote:FireServer()
		return
	end

	existingStand =
		findStandByBusinessId(
			businessId
		)
end

	if not editingExisting
	and getStandCount()
		>= MAXIMUM_STANDS then

	showStatus(
		`You can only place {MAXIMUM_STANDS} Lemonade Stands.`,
		2
	)

	return
end

	if editingExisting
		and not existingStand then

		showStatus(
			"Your lemonade stand could not be found.",
			2
		)

		cancelEditRemote:FireServer()
		return
	end

	local template =
		businessModels:FindFirstChild(
			BUSINESS_NAME
		)

	if not template
		or not template:IsA("Model") then

		warn(
			"LemonadeStand was not found in ReplicatedStorage.BusinessModels."
		)

		return
	end

	if not template.PrimaryPart then
		warn(
			"LemonadeStand needs PlacementOrigin set as its PrimaryPart."
		)

		return
	end

	previewModel = template:Clone()
	previewModel.Name =
		"LemonadeStandPreview"

	preparePreview(previewModel)

	previewModel.Parent = Workspace

	isEditingExistingStand =
		editingExisting

	if editingExisting then
		originalStand = existingStand

		setOriginalStandVisible(false)

		rotationY = math.deg(
			select(
				2,
				existingStand
					:GetPivot()
					:ToOrientation()
			)
		)

		previewModel:PivotTo(
			existingStand:GetPivot()
		)
	else
		originalStand = nil
		rotationY = 0
	end

	isPlacementActive = true
	waitingForServer = false
	placementValid = false

	setBuildMenuVisible(false)
	placementControls.Visible = true

	showStatus(
		IS_TOUCH_DEVICE
			and "Move the preview, then tap Place."
			or "Click to place  •  R rotate  •  Esc cancel"
	)
end

local function rotatePlacement()
	if not isPlacementActive then
		return
	end

	rotationY =
		(rotationY + ROTATION_INCREMENT)
		% 360
end

local function cancelPlacement()
	if not isPlacementActive then
		return
	end

	local wasEditing =
		isEditingExistingStand

	finishPlacementMode()
	statusLabel.Visible = false

	if wasEditing then
		cancelEditRemote:FireServer()
	else
		setBuildMenuVisible(true)
	end
end

local function requestCurrentPlacement()
	if not isPlacementActive
		or waitingForServer then

		return
	end

	if not placementValid
		or not currentPlacementCFrame then

		showStatus(
	"The stand must be inside your plot and cannot overlap another business.",
	1.75
)

		return
	end

	waitingForServer = true

	placeBusinessRemote:FireServer(
		BUSINESS_NAME,
		currentPlacementCFrame
	)

	showStatus(
		isEditingExistingStand
			and "Moving lemonade stand..."
			or "Building lemonade stand..."
	)
end

buildButton.Activated:Connect(function()
	startPlacement(false)
end)

rotateButton.Activated:Connect(
	rotatePlacement
)

placeButton.Activated:Connect(
	requestCurrentPlacement
)

cancelPlacementButton.Activated:Connect(
	cancelPlacement
)

UserInputService.InputChanged:Connect(function(
	input: InputObject
)
	if input.UserInputType
		== Enum.UserInputType.Touch then

		lastTouchPosition = Vector2.new(
			input.Position.X,
			input.Position.Y
		)
	end
end)

RunService.RenderStepped:Connect(function()
	if not isPlacementActive
		or not previewModel
		or not ownedPlot then

		return
	end

	local ground =
		ownedPlot:FindFirstChild("Ground")

	if not ground
		or not ground:IsA("BasePart") then

		placementValid = false
		setPreviewColor(false)
		return
	end

	local camera = Workspace.CurrentCamera

	if not camera then
		return
	end

	local pointerPosition =
		lastTouchPosition
		or UserInputService:GetMouseLocation()

	local ray =
		camera:ViewportPointToRay(
			pointerPosition.X,
			pointerPosition.Y
		)

	local raycastParams =
		RaycastParams.new()

	raycastParams.FilterType =
		Enum.RaycastFilterType.Include

	raycastParams.FilterDescendantsInstances = {
		ground,
	}

	local result = Workspace:Raycast(
		ray.Origin,
		ray.Direction * 1000,
		raycastParams
	)

	if not result then
		placementValid = false
		setPreviewColor(false)
		return
	end

	currentPlacementCFrame =
		getPlacementCFrame(
			result.Position,
			ground
		)

	previewModel:PivotTo(
		currentPlacementCFrame
	)

	local insideGround =
	isPreviewInsideGround(
		previewModel,
		ground
	)

local overlapping =
	isPreviewOverlappingBusiness(
		previewModel
	)

placementValid =
	insideGround
	and not overlapping

setPreviewColor(placementValid)
end)

UserInputService.InputBegan:Connect(function(
	input: InputObject,
	gameProcessed: boolean
)
	if gameProcessed
		or not isPlacementActive then

		return
	end

	if input.UserInputType
		== Enum.UserInputType.Touch then

		lastTouchPosition = Vector2.new(
			input.Position.X,
			input.Position.Y
		)

		return
	end

	if input.KeyCode == Enum.KeyCode.R then
		rotatePlacement()
		return
	end

	if input.KeyCode
		== Enum.KeyCode.Escape then

		cancelPlacement()
		return
	end

	if input.UserInputType
		== Enum.UserInputType.MouseButton1 then

		requestCurrentPlacement()
	end
end)

placeBusinessRemote.OnClientEvent:Connect(function(
	success: boolean,
	message: string
)
	waitingForServer = false

	if success then
		finishPlacementMode()

		ownedPlot = getOwnedPlot()

		task.defer(function()
			updateBuildMenu()

			setBuildMenuVisible(
				getStandCount()
					< MAXIMUM_STANDS
			)
		end)

		showStatus(
			message ~= ""
				and message
				or "Lemonade stand placed!",
			2
		)

		return
	end

	showStatus(
		message ~= ""
			and message
			or "The stand could not be placed.",
		2
	)
end)

interactionResultRemote.OnClientEvent:Connect(function(
	action: string,
	message: any,
	businessId: any
)
	if action == "ShowRemoveConfirmation" then
		-- BusinessManagementClient owns this interface.
		return
	end

	if action == "BeginEdit" then
	if typeof(businessId) ~= "string"
		or businessId == "" then

		showStatus(
			"The selected lemonade stand could not be identified.",
			2
		)

		cancelEditRemote:FireServer()
		return
	end

	startPlacement(
		true,
		businessId
	)

	return
end

	if action == "Removed" then
	finishPlacementMode()

	ownedPlot = getOwnedPlot()

	task.defer(function()
		updateBuildMenu()

		setBuildMenuVisible(
			getStandCount()
				< MAXIMUM_STANDS
		)
	end)

	showStatus(
		typeof(message) == "string"
			and message
			or "Lemonade stand removed.",
		2
	)

	return
end

	if action == "RemoveFailed" then
		showStatus(
			typeof(message) == "string"
				and message
				or "The stand could not be removed.",
			2
		)

		return
	end

	if action == "EditCancelled" then
		finishPlacementMode()

		ownedPlot = getOwnedPlot()
		updateBuildMenu()

		setBuildMenuVisible(
			getStandCount()
				< MAXIMUM_STANDS
		)

		showStatus(
			typeof(message) == "string"
				and message
				or "Editing cancelled.",
			2
		)
	end
end)

task.spawn(function()
	while screenGui.Parent do
		ownedPlot = getOwnedPlot()

		if ownedPlot
			and not isPlacementActive
			and not isEditingExistingStand then

			updateBuildMenu()

			setBuildMenuVisible(
				getStandCount()
					< MAXIMUM_STANDS
			)
		else
			setBuildMenuVisible(false)
		end

		task.wait(0.5)
	end
end)