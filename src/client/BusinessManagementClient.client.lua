local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local plotsFolder = Workspace:WaitForChild("Plots")
local remotes = ReplicatedStorage:WaitForChild("Remotes")

local requestEditRemote =
	remotes:WaitForChild("RequestEditBusiness")

local requestRemoveRemote =
	remotes:WaitForChild("RequestRemoveBusiness")

local interactionResultRemote =
	remotes:WaitForChild("BusinessInteractionResult")

local BUSINESS_NAME = "LemonadeStand"

local MANAGEMENT_DISTANCE = 22
local UPDATE_INTERVAL = 0.1

local managementGui: BillboardGui? = nil
local managementStand: Model? = nil
local confirmationOverlay: Frame? = nil

local removeRequestPending = false

local function getOwnedPlot(): Model?
	local plotName = player:GetAttribute("PlotName")

	if typeof(plotName) == "string" then
		local plot = plotsFolder:FindFirstChild(plotName)

		if plot
			and plot:IsA("Model")
			and plot:GetAttribute("OwnerUserId") == player.UserId then

			return plot
		end
	end

	for _, plot in plotsFolder:GetChildren() do
		if plot:IsA("Model")
			and plot:GetAttribute("OwnerUserId") == player.UserId then

			return plot
		end
	end

	return nil
end

local function getOwnedStand(): Model?
	local plot = getOwnedPlot()

	if not plot then
		return nil
	end

	local placedBusinesses =
		plot:FindFirstChild("PlacedBusinesses")

	if not placedBusinesses then
		return nil
	end

	local stand =
		placedBusinesses:FindFirstChild(BUSINESS_NAME)

	if not stand or not stand:IsA("Model") then
		return nil
	end

	if stand:GetAttribute("OwnerUserId") ~= player.UserId then
		return nil
	end

	return stand
end

local function getCharacterRoot(): BasePart?
	local character = player.Character

	if not character then
		return nil
	end

	local rootPart =
		character:FindFirstChild("HumanoidRootPart")

	if rootPart and rootPart:IsA("BasePart") then
		return rootPart
	end

	return nil
end

local function getUIAdornee(stand: Model): BasePart?
	local managementPosition =
		stand:FindFirstChild("ManagementUIPosition", true)

	if managementPosition
		and managementPosition:IsA("BasePart") then

		return managementPosition
	end

	local cooldownPosition =
		stand:FindFirstChild("CooldownUIPosition", true)

	if cooldownPosition
		and cooldownPosition:IsA("BasePart") then

		return cooldownPosition
	end

	if stand.PrimaryPart then
		return stand.PrimaryPart
	end

	return stand:FindFirstChildWhichIsA("BasePart", true)
end

local function addCorner(
	parent: Instance,
	radius: number
): UICorner
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius)
	corner.Parent = parent

	return corner
end

local function addStroke(
	parent: Instance,
	thickness: number,
	transparency: number
): UIStroke
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(20, 22, 27)
	stroke.Thickness = thickness
	stroke.Transparency = transparency
	stroke.Parent = parent

	return stroke
end

local function createButton(
	parent: Instance,
	name: string,
	text: string,
	icon: string,
	backgroundColor: Color3
): TextButton
	local button = Instance.new("TextButton")
	button.Name = name
	button.Size = UDim2.new(0.5, -5, 1, 0)
	button.BackgroundColor3 = backgroundColor
	button.BorderSizePixel = 0
	button.AutoButtonColor = true

	-- Put the text directly on the button so nothing sits
	-- in front of its clickable area.
	button.Text = icon .. "  " .. text
	button.TextColor3 = Color3.fromRGB(255, 255, 255)
	button.Font = Enum.Font.GothamBold
	button.TextSize = 13

	button.Active = true
	button.Selectable = true
	button.Interactable = true
	button.ZIndex = 10
	button.Parent = parent

	addCorner(button, 9)
	addStroke(button, 1.5, 0.25)

	local scale = Instance.new("UIScale")
	scale.Scale = 1
	scale.Parent = button

	button.MouseEnter:Connect(function()
		scale.Scale = 1.04
	end)

	button.MouseLeave:Connect(function()
		scale.Scale = 1
	end)

	button.MouseButton1Down:Connect(function()
		scale.Scale = 0.96
	end)

	button.MouseButton1Up:Connect(function()
		scale.Scale = 1.04
	end)

	return button
end

local function destroyManagementUI()
	if managementGui then
		managementGui:Destroy()
		managementGui = nil
	end

	managementStand = nil
end

local function createManagementUI(stand: Model)
	destroyManagementUI()

	local adornee = getUIAdornee(stand)

	if not adornee then
		warn(
			"LemonadeStand does not contain a part for its management UI."
		)

		return
	end

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "BusinessManagementUI"
	billboard.Adornee = adornee
	billboard.Size = UDim2.fromOffset(270, 76)
	billboard.StudsOffsetWorldSpace = Vector3.new(0, 2.7, 0)

	billboard.AlwaysOnTop = true
	billboard.LightInfluence = 0
	billboard.MaxDistance = MANAGEMENT_DISTANCE + 3

	-- Required for buttons inside a BillboardGui to receive input.
	billboard.Active = true
	billboard.Enabled = false

	billboard.ResetOnSpawn = false
	billboard.Parent = playerGui

	local container = Instance.new("Frame")
	container.Name = "Container"
	container.AnchorPoint = Vector2.new(0.5, 0.5)
	container.Position = UDim2.fromScale(0.5, 0.5)
	container.Size = UDim2.new(1, -4, 1, -4)
	container.BackgroundColor3 = Color3.fromRGB(30, 33, 40)
	container.BackgroundTransparency = 0.04
	container.BorderSizePixel = 0
	container.Active = true
	container.ZIndex = 2
	container.Parent = billboard

	addCorner(container, 12)
	addStroke(container, 2, 0.1)

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.Position = UDim2.fromOffset(10, 4)
	title.Size = UDim2.new(1, -20, 0, 21)
	title.BackgroundTransparency = 1
	title.Text = "LEMONADE STAND"
	title.TextColor3 = Color3.fromRGB(245, 247, 250)
	title.Font = Enum.Font.GothamBold
	title.TextSize = 12
	title.TextTransparency = 0.08
	title.ZIndex = 3
	title.Parent = container

	local buttonHolder = Instance.new("Frame")
	buttonHolder.Name = "Buttons"
	buttonHolder.Position = UDim2.fromOffset(8, 27)
	buttonHolder.Size = UDim2.new(1, -16, 0, 40)
	buttonHolder.BackgroundTransparency = 1
	buttonHolder.Active = true
	buttonHolder.ClipsDescendants = false
	buttonHolder.ZIndex = 3
	buttonHolder.Parent = container

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.Padding = UDim.new(0, 10)
	layout.Parent = buttonHolder

	local editButton = createButton(
		buttonHolder,
		"EditButton",
		"Edit Position",
		"✎",
		Color3.fromRGB(65, 130, 230)
	)

	local removeButton = createButton(
		buttonHolder,
		"RemoveButton",
		"Remove",
		"×",
		Color3.fromRGB(215, 67, 67)
	)

	editButton.Activated:Connect(function()
		print("Edit button clicked")

		if stand ~= getOwnedStand() then
			warn("Edit blocked: owned stand did not match")
			return
		end

		if stand:GetAttribute("IsBeingEdited") == true then
			warn("Edit blocked: stand is already being edited")
			return
		end

		billboard.Enabled = false
		requestEditRemote:FireServer()
	end)

	removeButton.Activated:Connect(function()
		print("Remove button clicked")

		if removeRequestPending then
			warn("Remove blocked: request already pending")
			return
		end

		if stand ~= getOwnedStand() then
			warn("Remove blocked: owned stand did not match")
			return
		end

		removeRequestPending = true
		requestRemoveRemote:FireServer(false)

		task.delay(2, function()
			removeRequestPending = false
		end)
	end)

	managementGui = billboard
	managementStand = stand
end

local function hideRemoveConfirmation()
	if confirmationOverlay then
		confirmationOverlay.Visible = false
	end

	removeRequestPending = false
end

local function createRemoveConfirmation()
	local existing =
		playerGui:FindFirstChild("RemoveBusinessConfirmation")

	if existing then
		existing:Destroy()
	end

	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "RemoveBusinessConfirmation"
	screenGui.IgnoreGuiInset = true
	screenGui.ResetOnSpawn = false
	screenGui.DisplayOrder = 100
	screenGui.Parent = playerGui

	local overlay = Instance.new("Frame")
	overlay.Name = "Overlay"
	overlay.Size = UDim2.fromScale(1, 1)
	overlay.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	overlay.BackgroundTransparency = 0.42
	overlay.BorderSizePixel = 0
	overlay.Visible = false
	overlay.Active = true
	overlay.ZIndex = 20
	overlay.Parent = screenGui

	local window = Instance.new("Frame")
	window.Name = "Window"
	window.AnchorPoint = Vector2.new(0.5, 0.5)
	window.Position = UDim2.fromScale(0.5, 0.5)
	window.Size = UDim2.fromOffset(390, 220)
	window.BackgroundColor3 = Color3.fromRGB(31, 34, 41)
	window.BorderSizePixel = 0
	window.Active = true
	window.ZIndex = 21
	window.Parent = overlay

	addCorner(window, 14)
	addStroke(window, 2, 0.08)

	local warningIcon = Instance.new("TextLabel")
	warningIcon.Name = "WarningIcon"
	warningIcon.AnchorPoint = Vector2.new(0.5, 0)
	warningIcon.Position = UDim2.new(0.5, 0, 0, 15)
	warningIcon.Size = UDim2.fromOffset(44, 44)
	warningIcon.BackgroundColor3 = Color3.fromRGB(215, 67, 67)
	warningIcon.BorderSizePixel = 0
	warningIcon.Text = "!"
	warningIcon.TextColor3 = Color3.fromRGB(255, 255, 255)
	warningIcon.Font = Enum.Font.GothamBold
	warningIcon.TextSize = 27
	warningIcon.ZIndex = 22
	warningIcon.Parent = window

	addCorner(warningIcon, 22)

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.Position = UDim2.fromOffset(20, 66)
	title.Size = UDim2.new(1, -40, 0, 32)
	title.BackgroundTransparency = 1
	title.Text = "Remove Lemonade Stand?"
	title.TextColor3 = Color3.fromRGB(255, 255, 255)
	title.Font = Enum.Font.GothamBold
	title.TextSize = 21
	title.ZIndex = 22
	title.Parent = window

	local description = Instance.new("TextLabel")
	description.Name = "Description"
	description.Position = UDim2.fromOffset(30, 101)
	description.Size = UDim2.new(1, -60, 0, 47)
	description.BackgroundTransparency = 1
	description.Text =
		"All waiting customers will leave. You can build the stand again later."

	description.TextWrapped = true
	description.TextColor3 = Color3.fromRGB(196, 201, 211)
	description.Font = Enum.Font.Gotham
	description.TextSize = 14
	description.ZIndex = 22
	description.Parent = window

	local buttons = Instance.new("Frame")
	buttons.Name = "Buttons"
	buttons.Position = UDim2.fromOffset(20, 160)
	buttons.Size = UDim2.new(1, -40, 0, 43)
	buttons.BackgroundTransparency = 1
	buttons.ZIndex = 22
	buttons.Parent = window

	local buttonLayout = Instance.new("UIListLayout")
	buttonLayout.FillDirection = Enum.FillDirection.Horizontal
	buttonLayout.HorizontalAlignment =
		Enum.HorizontalAlignment.Center

	buttonLayout.VerticalAlignment =
		Enum.VerticalAlignment.Center

	buttonLayout.Padding = UDim.new(0, 12)
	buttonLayout.Parent = buttons

	local cancelButton = Instance.new("TextButton")
	cancelButton.Name = "CancelButton"
	cancelButton.Size = UDim2.new(0.5, -6, 1, 0)
	cancelButton.BackgroundColor3 = Color3.fromRGB(72, 76, 88)
	cancelButton.BorderSizePixel = 0
	cancelButton.Text = "Cancel"
	cancelButton.TextColor3 = Color3.fromRGB(255, 255, 255)
	cancelButton.Font = Enum.Font.GothamBold
	cancelButton.TextSize = 15
	cancelButton.AutoButtonColor = true
	cancelButton.ZIndex = 23
	cancelButton.Parent = buttons

	addCorner(cancelButton, 9)
	addStroke(cancelButton, 1.5, 0.3)

	local removeButton = Instance.new("TextButton")
	removeButton.Name = "ConfirmRemoveButton"
	removeButton.Size = UDim2.new(0.5, -6, 1, 0)
	removeButton.BackgroundColor3 = Color3.fromRGB(215, 67, 67)
	removeButton.BorderSizePixel = 0
	removeButton.Text = "Remove Stand"
	removeButton.TextColor3 = Color3.fromRGB(255, 255, 255)
	removeButton.Font = Enum.Font.GothamBold
	removeButton.TextSize = 15
	removeButton.AutoButtonColor = true
	removeButton.ZIndex = 23
	removeButton.Parent = buttons

	addCorner(removeButton, 9)
	addStroke(removeButton, 1.5, 0.25)

	cancelButton.Activated:Connect(function()
		hideRemoveConfirmation()
	end)

	removeButton.Activated:Connect(function()
		if removeRequestPending then
			return
		end

		removeRequestPending = true
		overlay.Visible = false

		requestRemoveRemote:FireServer(true)

		task.delay(2, function()
			removeRequestPending = false
		end)
	end)

	confirmationOverlay = overlay
end

createRemoveConfirmation()

interactionResultRemote.OnClientEvent:Connect(function(
	action: string,
	message: any
)
	if action == "ShowRemoveConfirmation" then
		removeRequestPending = false

		if confirmationOverlay then
			confirmationOverlay.Visible = true
		end

		return
	end

	if action == "BeginEdit" then
		hideRemoveConfirmation()

		if managementGui then
			managementGui.Enabled = false
		end

		return
	end

	if action == "Removed" then
		hideRemoveConfirmation()
		destroyManagementUI()
		return
	end

	if action == "RemoveFailed" then
		hideRemoveConfirmation()

		warn(
			typeof(message) == "string"
				and message
				or "The lemonade stand could not be removed."
		)

		return
	end

	if action == "EditCancelled" then
		hideRemoveConfirmation()
		return
	end

	if action == "EditFailed" then
		if managementGui then
			managementGui.Enabled = false
		end

		warn(
			typeof(message) == "string"
				and message
				or "The lemonade stand could not be edited."
		)
	end
end)

player.CharacterRemoving:Connect(function()
	if managementGui then
		managementGui.Enabled = false
	end

	hideRemoveConfirmation()
end)

task.spawn(function()
	while true do
		local stand = getOwnedStand()
		local rootPart = getCharacterRoot()

		if stand ~= managementStand then
			if stand then
				createManagementUI(stand)
			else
				destroyManagementUI()
			end
		end

		local shouldShow = false

		if stand
			and rootPart
			and managementGui
			and stand:GetAttribute("IsBeingEdited") ~= true
			and stand:GetAttribute("StandUnavailable") ~= true then

			local adornee = getUIAdornee(stand)

			if adornee then
				local distance =
					(rootPart.Position - adornee.Position).Magnitude

				shouldShow =
					distance <= MANAGEMENT_DISTANCE
			end
		end

		if managementGui then
			managementGui.Enabled = shouldShow
		end

		task.wait(UPDATE_INTERVAL)
	end
end)