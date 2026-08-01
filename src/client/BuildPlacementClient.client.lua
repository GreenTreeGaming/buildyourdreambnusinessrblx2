local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local businessModels =
	ReplicatedStorage:WaitForChild("BusinessModels")

local remotes =
	ReplicatedStorage:WaitForChild("Remotes")

local placeBusinessRemote =
	remotes:WaitForChild("PlaceBusiness")

local requestRemoveRemote =
	remotes:WaitForChild("RequestRemoveBusiness")

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

local rotationY = 0

local isPlacementActive = false
local isEditingExistingStand = false
local placementValid = false
local waitingForServer = false

local function getOwnedPlot(): Model?
	local plotName = player:GetAttribute("PlotName")

	if typeof(plotName) == "string" then
		local plot = plotsFolder:FindFirstChild(plotName)

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

local function getExistingStand(): Model?
	if not ownedPlot then
		return nil
	end

	local placedBusinesses =
		ownedPlot:FindFirstChild("PlacedBusinesses")

	if not placedBusinesses then
		return nil
	end

	local stand =
		placedBusinesses:FindFirstChild(BUSINESS_NAME)

	if stand and stand:IsA("Model") then
		return stand
	end

	return nil
end

local function createInterface()
	local existing = playerGui:FindFirstChild("BuildMenu")

	if existing then
		existing:Destroy()
	end

	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "BuildMenu"
	screenGui.ResetOnSpawn = false
	screenGui.IgnoreGuiInset = true
	screenGui.Parent = playerGui

	local menu = Instance.new("Frame")
	menu.Name = "Menu"
	menu.AnchorPoint = Vector2.new(0, 0.5)
	menu.Position = UDim2.new(0, 25, 0.5, 0)
	menu.Size = UDim2.fromOffset(245, 160)
	menu.BackgroundColor3 = Color3.fromRGB(30, 32, 38)
	menu.BorderSizePixel = 0
	menu.Parent = screenGui

	local menuCorner = Instance.new("UICorner")
	menuCorner.CornerRadius = UDim.new(0, 12)
	menuCorner.Parent = menu

	local menuStroke = Instance.new("UIStroke")
	menuStroke.Color = Color3.fromRGB(65, 69, 80)
	menuStroke.Thickness = 1.5
	menuStroke.Parent = menu

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.Position = UDim2.fromOffset(15, 10)
	title.Size = UDim2.new(1, -30, 0, 35)
	title.BackgroundTransparency = 1
	title.Text = "Build Your Business"
	title.TextColor3 = Color3.fromRGB(255, 255, 255)
	title.Font = Enum.Font.GothamBold
	title.TextSize = 20
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Parent = menu

	local buildButton = Instance.new("TextButton")
	buildButton.Name = "LemonadeStandButton"
	buildButton.Position = UDim2.fromOffset(15, 55)
	buildButton.Size = UDim2.new(1, -30, 0, 55)
	buildButton.BackgroundColor3 = Color3.fromRGB(85, 210, 105)
	buildButton.BorderSizePixel = 0
	buildButton.Text = "Build Lemonade Stand"
	buildButton.TextColor3 = Color3.fromRGB(255, 255, 255)
	buildButton.Font = Enum.Font.GothamBold
	buildButton.TextSize = 16
	buildButton.AutoButtonColor = true
	buildButton.Parent = menu

	local buttonCorner = Instance.new("UICorner")
	buttonCorner.CornerRadius = UDim.new(0, 9)
	buttonCorner.Parent = buildButton

	local instructions = Instance.new("TextLabel")
	instructions.Name = "Instructions"
	instructions.Position = UDim2.fromOffset(15, 117)
	instructions.Size = UDim2.new(1, -30, 0, 28)
	instructions.BackgroundTransparency = 1
	instructions.Text = "Click place  •  R rotate  •  Esc cancel"
	instructions.TextColor3 = Color3.fromRGB(190, 195, 205)
	instructions.Font = Enum.Font.Gotham
	instructions.TextSize = 12
	instructions.Parent = menu

	local status = Instance.new("TextLabel")
	status.Name = "Status"
	status.AnchorPoint = Vector2.new(0.5, 1)
	status.Position = UDim2.new(0.5, 0, 1, -25)
	status.Size = UDim2.fromOffset(470, 45)
	status.BackgroundColor3 = Color3.fromRGB(30, 32, 38)
	status.BackgroundTransparency = 0.08
	status.BorderSizePixel = 0
	status.Text = ""
	status.TextColor3 = Color3.fromRGB(255, 255, 255)
	status.Font = Enum.Font.GothamBold
	status.TextSize = 17
	status.Visible = false
	status.ZIndex = 10
	status.Parent = screenGui

	local statusCorner = Instance.new("UICorner")
	statusCorner.CornerRadius = UDim.new(0, 10)
	statusCorner.Parent = status

	return screenGui, menu, buildButton, status
end

local screenGui, menu, buildButton, statusLabel =
	createInterface()

local statusVersion = 0

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

local function createRemoveConfirmation(): Frame
	local overlay = Instance.new("Frame")
	overlay.Name = "RemoveConfirmation"
	overlay.Size = UDim2.fromScale(1, 1)
	overlay.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	overlay.BackgroundTransparency = 0.45
	overlay.Visible = false
	overlay.Active = true
	overlay.ZIndex = 20
	overlay.Parent = screenGui

	local window = Instance.new("Frame")
	window.Name = "Window"
	window.AnchorPoint = Vector2.new(0.5, 0.5)
	window.Position = UDim2.fromScale(0.5, 0.5)
	window.Size = UDim2.fromOffset(380, 205)
	window.BackgroundColor3 = Color3.fromRGB(35, 37, 44)
	window.BorderSizePixel = 0
	window.ZIndex = 21
	window.Parent = overlay

	local windowCorner = Instance.new("UICorner")
	windowCorner.CornerRadius = UDim.new(0, 13)
	windowCorner.Parent = window

	local windowStroke = Instance.new("UIStroke")
	windowStroke.Color = Color3.fromRGB(75, 79, 92)
	windowStroke.Thickness = 1.5
	windowStroke.Parent = window

	local title = Instance.new("TextLabel")
	title.Position = UDim2.fromOffset(20, 16)
	title.Size = UDim2.new(1, -40, 0, 38)
	title.BackgroundTransparency = 1
	title.Text = "Remove Lemonade Stand?"
	title.TextColor3 = Color3.fromRGB(255, 255, 255)
	title.Font = Enum.Font.GothamBold
	title.TextSize = 21
	title.ZIndex = 22
	title.Parent = window

	local description = Instance.new("TextLabel")
	description.Position = UDim2.fromOffset(28, 61)
	description.Size = UDim2.new(1, -56, 0, 55)
	description.BackgroundTransparency = 1
	description.Text =
		"Customers will leave and no new customers will arrive until you build it again."

	description.TextWrapped = true
	description.TextColor3 = Color3.fromRGB(202, 206, 216)
	description.Font = Enum.Font.Gotham
	description.TextSize = 14
	description.ZIndex = 22
	description.Parent = window

	local cancelButton = Instance.new("TextButton")
	cancelButton.Name = "CancelButton"
	cancelButton.Position = UDim2.fromOffset(20, 138)
	cancelButton.Size = UDim2.fromOffset(160, 47)
	cancelButton.BackgroundColor3 = Color3.fromRGB(75, 78, 88)
	cancelButton.BorderSizePixel = 0
	cancelButton.Text = "Cancel"
	cancelButton.TextColor3 = Color3.fromRGB(255, 255, 255)
	cancelButton.Font = Enum.Font.GothamBold
	cancelButton.TextSize = 16
	cancelButton.ZIndex = 22
	cancelButton.Parent = window

	local removeButton = Instance.new("TextButton")
	removeButton.Name = "RemoveButton"
	removeButton.Position = UDim2.new(1, -180, 0, 138)
	removeButton.Size = UDim2.fromOffset(160, 47)
	removeButton.BackgroundColor3 = Color3.fromRGB(220, 65, 65)
	removeButton.BorderSizePixel = 0
	removeButton.Text = "Remove"
	removeButton.TextColor3 = Color3.fromRGB(255, 255, 255)
	removeButton.Font = Enum.Font.GothamBold
	removeButton.TextSize = 16
	removeButton.ZIndex = 22
	removeButton.Parent = window

	for _, button in {cancelButton, removeButton} do
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 9)
		corner.Parent = button
	end

	cancelButton.Activated:Connect(function()
		overlay.Visible = false
	end)

	removeButton.Activated:Connect(function()
		overlay.Visible = false
		requestRemoveRemote:FireServer()

		showStatus("Removing lemonade stand...")
	end)

	return overlay
end

local removeConfirmation =
	createRemoveConfirmation()

local function setOriginalStandVisible(visible: boolean)
	if not originalStand then
		return
	end

	for _, descendant in originalStand:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.LocalTransparencyModifier =
				visible and 0 or 1
		elseif descendant:IsA("BillboardGui") then
			descendant.Enabled = visible
		end
	end
end

local function createPlacementBox(model: Model)
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

	local selectionBox = Instance.new("SelectionBox")
	selectionBox.Name = "PlacementBox"
	selectionBox.Adornee = placementBounds
	selectionBox.LineThickness = 0.08
	selectionBox.SurfaceTransparency = 0.82
	selectionBox.Color3 = Color3.fromRGB(80, 230, 110)
	selectionBox.SurfaceColor3 = Color3.fromRGB(80, 230, 110)
	selectionBox.Parent = model
end

local function preparePreview(model: Model)
	for _, descendant in model:GetDescendants() do
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

	local highlight = Instance.new("Highlight")
	highlight.Name = "PlacementHighlight"
	highlight.FillTransparency = 0.7
	highlight.OutlineTransparency = 0
	highlight.DepthMode =
		Enum.HighlightDepthMode.AlwaysOnTop

	highlight.Parent = model

	createPlacementBox(model)
end

local function setPreviewColor(valid: boolean)
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
		fillColor = Color3.fromRGB(70, 235, 105)
		outlineColor = Color3.fromRGB(25, 155, 55)
	else
		fillColor = Color3.fromRGB(240, 70, 70)
		outlineColor = Color3.fromRGB(170, 25, 25)
	end

	if highlight and highlight:IsA("Highlight") then
		highlight.FillColor = fillColor
		highlight.OutlineColor = outlineColor
	end

	if placementBox
		and placementBox:IsA("SelectionBox") then

		placementBox.Color3 = fillColor
		placementBox.SurfaceColor3 = fillColor
	end
end

local function snapToGrid(value: number): number
	return math.round(value / GRID_SIZE) * GRID_SIZE
end

local function getPlacementCFrame(
	hitPosition: Vector3,
	ground: BasePart
): CFrame
	local groundPosition =
		ground.CFrame:PointToObjectSpace(hitPosition)

	local localX = snapToGrid(groundPosition.X)
	local localZ = snapToGrid(groundPosition.Z)

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

	local halfX = placementBounds.Size.X / 2
	local halfZ = placementBounds.Size.Z / 2

	local corners = {
		Vector3.new(-halfX, 0, -halfZ),
		Vector3.new(-halfX, 0, halfZ),
		Vector3.new(halfX, 0, -halfZ),
		Vector3.new(halfX, 0, halfZ),
	}

	for _, cornerOffset in corners do
		local worldCorner =
			placementBounds.CFrame:PointToWorldSpace(
				cornerOffset
			)

		local groundSpace =
			ground.CFrame:PointToObjectSpace(
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
end

local function startPlacement(editingExisting: boolean)
	if isPlacementActive then
		return
	end

	ownedPlot = getOwnedPlot()

	if not ownedPlot then
		showStatus("Waiting for your plot...", 2)
		return
	end

	local existingStand = getExistingStand()

	if not editingExisting and existingStand then
		showStatus(
			"You already built the lemonade stand.",
			2
		)

		menu.Visible = false
		return
	end

	if editingExisting and not existingStand then
		showStatus(
			"Your lemonade stand could not be found.",
			2
		)

		cancelEditRemote:FireServer()
		return
	end

	local template =
		businessModels:FindFirstChild(BUSINESS_NAME)

	if not template or not template:IsA("Model") then
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
	previewModel.Name = "LemonadeStandPreview"

	preparePreview(previewModel)

	previewModel.Parent = Workspace

	isEditingExistingStand = editingExisting

	if editingExisting then
		originalStand = existingStand

		setOriginalStandVisible(false)

		rotationY = math.deg(
			select(
				2,
				existingStand:GetPivot():ToOrientation()
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

	menu.Visible = false

	showStatus(
		"Click to place  •  R to rotate  •  Esc to cancel"
	)
end

buildButton.Activated:Connect(function()
	startPlacement(false)
end)

RunService.RenderStepped:Connect(function()
	if not isPlacementActive
		or not previewModel
		or not ownedPlot then

		return
	end

	local ground = ownedPlot:FindFirstChild("Ground")

	if not ground or not ground:IsA("BasePart") then
		placementValid = false
		setPreviewColor(false)
		return
	end

	local camera = Workspace.CurrentCamera

	if not camera then
		return
	end

	local mousePosition =
		UserInputService:GetMouseLocation()

	local ray = camera:ViewportPointToRay(
		mousePosition.X,
		mousePosition.Y
	)

	local raycastParams = RaycastParams.new()
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

	placementValid =
		isPreviewInsideGround(
			previewModel,
			ground
		)

	setPreviewColor(placementValid)
end)

UserInputService.InputBegan:Connect(function(
	input: InputObject,
	gameProcessed: boolean
)
	if gameProcessed or not isPlacementActive then
		return
	end

	if input.KeyCode == Enum.KeyCode.R then
		rotationY =
			(rotationY + ROTATION_INCREMENT) % 360

		return
	end

	if input.KeyCode == Enum.KeyCode.Escape then
		local wasEditing = isEditingExistingStand

		finishPlacementMode()
		statusLabel.Visible = false

		if wasEditing then
			cancelEditRemote:FireServer()
		else
			menu.Visible = true
		end

		return
	end

	if input.UserInputType
		~= Enum.UserInputType.MouseButton1 then

		return
	end

	if waitingForServer
		or not placementValid
		or not currentPlacementCFrame then

		if not placementValid then
			showStatus(
				"The full placement box must be inside your plot.",
				1.5
			)
		end

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
end)

placeBusinessRemote.OnClientEvent:Connect(function(
	success: boolean,
	message: string
)
	waitingForServer = false

	if success then
		finishPlacementMode()
		menu.Visible = false

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
	message: any
)
	if action == "ShowRemoveConfirmation" then
		removeConfirmation.Visible = true
		return
	end

	if action == "BeginEdit" then
		startPlacement(true)
		return
	end

	if action == "Removed" then
		removeConfirmation.Visible = false
		finishPlacementMode()

		menu.Visible = true

		showStatus(
			typeof(message) == "string"
				and message
				or "Lemonade stand removed.",
			2
		)

		return
	end

	if action == "RemoveFailed" then
		removeConfirmation.Visible = false

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

		menu.Visible =
			getExistingStand() == nil

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

			local standExists =
				getExistingStand() ~= nil

			menu.Visible = not standExists
		else
			menu.Visible = false
		end

		task.wait(0.5)
	end
end)