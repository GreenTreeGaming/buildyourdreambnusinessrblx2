local Players = game:GetService("Players")
local ReplicatedStorage =
	game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local playerGui =
	player:WaitForChild("PlayerGui")

local plotsFolder =
	Workspace:WaitForChild("Plots")

local remotes =
	ReplicatedStorage:WaitForChild("Remotes")

local requestEditRemote =
	remotes:WaitForChild("RequestEditBusiness")

local requestRemoveRemote =
	remotes:WaitForChild("RequestRemoveBusiness")

local interactionResultRemote =
	remotes:WaitForChild("BusinessInteractionResult")

local UITheme = require(
	ReplicatedStorage
		:WaitForChild("Shared")
		:WaitForChild("UITheme")
)

local Colors = UITheme.Colors
local Fonts = UITheme.Fonts

local BUSINESS_NAME = "LemonadeStand"

local MANAGEMENT_DISTANCE = 22
local UPDATE_INTERVAL = 0.1

local managementGui: BillboardGui? = nil
local managementStand: Model? = nil
local confirmationOverlay: Frame? = nil
local confirmationWindow: Frame? = nil
local toastLabel: TextLabel? = nil
local managementCreationPending = false

local removeRequestPending = false
local toastVersion = 0

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
		placedBusinesses:FindFirstChild(
			BUSINESS_NAME
		)

	if not stand or not stand:IsA("Model") then
		return nil
	end

	if stand:GetAttribute("OwnerUserId")
		~= player.UserId then

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
		character:FindFirstChild(
			"HumanoidRootPart"
		)

	if rootPart
		and rootPart:IsA("BasePart") then

		return rootPart
	end

	return nil
end

local function getUIAdornee(
	stand: Model,
	waitForReplication: boolean?
): BasePart?
	local function findAdornee(): BasePart?
		local managementPosition =
			stand:FindFirstChild(
				"ManagementUIPosition",
				true
			)

		if managementPosition
			and managementPosition:IsA("BasePart") then

			return managementPosition
		end

		local cooldownPosition =
			stand:FindFirstChild(
				"CooldownUIPosition",
				true
			)

		if cooldownPosition
			and cooldownPosition:IsA("BasePart") then

			return cooldownPosition
		end

		local salePosition =
			stand:FindFirstChild(
				"SaleEffectPosition",
				true
			)

		if salePosition
			and salePosition:IsA("BasePart") then

			return salePosition
		end

		if stand.PrimaryPart then
			return stand.PrimaryPart
		end

		return nil
	end

	local existing = findAdornee()

	if existing or waitForReplication ~= true then
		return existing
	end

	local startedAt = time()

	while stand.Parent
		and time() - startedAt < 10 do

		local adornee = findAdornee()

		if adornee then
			return adornee
		end

		task.wait(0.1)
	end

	return stand:FindFirstChildWhichIsA(
		"BasePart",
		true
	)
end

local function showToast(
	message: string,
	isError: boolean?
)
	if not toastLabel then
		return
	end

	toastVersion += 1
	local currentVersion = toastVersion

	toastLabel.Text = message
	toastLabel.TextColor3 =
		isError
		and Colors.Danger
		or Colors.Success

	toastLabel.Visible = true

	task.delay(4, function()
		if toastVersion == currentVersion
			and toastLabel then

			toastLabel.Visible = false
		end
	end)
end

local function createActionButton(
	parent: Instance,
	name: string,
	text: string,
	topColor: Color3,
	bottomColor: Color3
): TextButton
	local button = Instance.new("TextButton")

	button.Name = name
	button.Size =
		UDim2.fromScale(0.48, 1)

	button.Text = text
	button.TextColor3 = Colors.Text
	button.TextTransparency = 0
	button.ZIndex = 10
	button.Parent = parent

	UITheme.StyleText(
		button,
		11,
		17,
		Colors.Text,
		Fonts.Black
	)

	UITheme.StyleButton(
		button,
		topColor,
		bottomColor,
		Colors.Text
	)

	button.TextColor3 = Colors.Text
	button.TextTransparency = 0

	return button
end

local function destroyManagementUI()
	if managementGui then
		managementGui:Destroy()
		managementGui = nil
	end

	managementStand = nil
end

local function createManagementUI(
	stand: Model
)
	destroyManagementUI()

	local adornee =
	getUIAdornee(
		stand,
		true
	)

	if not adornee then
		warn(
	`{stand:GetFullName()} did not finish loading a management UI position.`
)

		return
	end

	local billboard =
		Instance.new("BillboardGui")

	billboard.Name =
		"BusinessManagementUI"

	billboard.Adornee = adornee

	-- Scale values on BillboardGui are world-space studs.
	billboard.Size =
		UDim2.fromScale(7.4, 2.25)

	billboard.StudsOffsetWorldSpace =
		Vector3.new(0, 3.1, 0)

	billboard.AlwaysOnTop = true
	billboard.LightInfluence = 0
	billboard.MaxDistance =
		MANAGEMENT_DISTANCE + 5

	billboard.Active = true
	billboard.Enabled = false
	billboard.ResetOnSpawn = false
	billboard.Parent = playerGui

	local shadow = Instance.new("Frame")
	shadow.Name = "Shadow"
	shadow.AnchorPoint =
		Vector2.new(0.5, 0.5)

	shadow.Position =
		UDim2.fromScale(0.51, 0.54)

	shadow.Size =
		UDim2.fromScale(0.98, 0.96)

	shadow.BackgroundColor3 =
		Colors.Shadow

	shadow.BackgroundTransparency = 0.28
	shadow.BorderSizePixel = 0
	shadow.Parent = billboard

	UITheme.AddCorner(shadow, 0.12)

	local container = Instance.new("Frame")
	container.Name = "Container"
	container.AnchorPoint =
		Vector2.new(0.5, 0.5)

	container.Position =
		UDim2.fromScale(0.5, 0.5)

	container.Size =
		UDim2.fromScale(0.98, 0.96)

	container.BackgroundColor3 =
		Colors.Surface

	container.BorderSizePixel = 0
	container.Active = true
	container.ZIndex = 2
	container.Parent = billboard

	UITheme.AddCorner(container, 0.12)

	UITheme.AddStroke(
		container,
		Colors.Primary,
		2,
		0.18
	)

	UITheme.AddGradient(
		container,
		Colors.SurfaceRaised,
		Colors.Background
	)

	local accent = Instance.new("Frame")
	accent.Name = "Accent"
	accent.Position =
		UDim2.fromScale(0.03, 0.08)

	accent.Size =
		UDim2.fromScale(0.025, 0.84)

	accent.BackgroundColor3 =
		Colors.Primary

	accent.BorderSizePixel = 0
	accent.ZIndex = 3
	accent.Parent = container

	UITheme.AddCorner(accent, 0.5)

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.Position =
		UDim2.fromScale(0.09, 0.08)

	title.Size =
		UDim2.fromScale(0.82, 0.23)

	title.BackgroundTransparency = 1
	title.Text = "LEMONADE STAND"
	title.TextXAlignment =
		Enum.TextXAlignment.Left

	title.ZIndex = 3
	title.Parent = container

	UITheme.StyleText(
		title,
		11,
		17,
		Colors.Text,
		Fonts.Black
	)

	local buttons = Instance.new("Frame")
	buttons.Name = "Buttons"
	buttons.Position =
		UDim2.fromScale(0.09, 0.5)

	buttons.Size =
		UDim2.fromScale(0.82, 0.36)

	buttons.BackgroundTransparency = 1
	buttons.Active = true
	buttons.ZIndex = 4
	buttons.Parent = container

	local layout =
		Instance.new("UIListLayout")

	layout.FillDirection =
		Enum.FillDirection.Horizontal

	layout.HorizontalAlignment =
		Enum.HorizontalAlignment.Center

	layout.VerticalAlignment =
		Enum.VerticalAlignment.Center

	layout.Padding = UDim.new(0.04, 0)
	layout.Parent = buttons

	local editButton = createActionButton(
	buttons,
	"EditButton",
	"MOVE",
	Colors.Info,
	Colors.InfoDark
)

local removeButton = createActionButton(
	buttons,
	"RemoveButton",
	"REMOVE",
	Colors.Danger,
	Colors.DangerDark
)

	editButton.Activated:Connect(function()
		if stand ~= getOwnedStand() then
			showToast(
				"Your lemonade stand could not be found.",
				true
			)

			return
		end

		if stand:GetAttribute("IsBeingEdited")
			== true then

			return
		end

		billboard.Enabled = false
		requestEditRemote:FireServer()
	end)

	removeButton.Activated:Connect(function()
		if removeRequestPending then
			return
		end

		if stand ~= getOwnedStand() then
			showToast(
				"Your lemonade stand could not be found.",
				true
			)

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
		playerGui:FindFirstChild(
			"RemoveBusinessConfirmation"
		)

	if existing then
		existing:Destroy()
	end

	local screenGui =
		Instance.new("ScreenGui")

	screenGui.Name =
		"RemoveBusinessConfirmation"

	screenGui.IgnoreGuiInset = false
	screenGui.ResetOnSpawn = false
	screenGui.DisplayOrder = 100
	screenGui.Parent = playerGui

	local overlay = Instance.new("Frame")
	overlay.Name = "Overlay"
	overlay.Size =
		UDim2.fromScale(1, 1)

	overlay.BackgroundColor3 =
		Colors.Shadow

	overlay.BackgroundTransparency = 0.2
	overlay.BorderSizePixel = 0
	overlay.Visible = false
	overlay.Active = true
	overlay.Parent = screenGui

	local shadow = Instance.new("Frame")
	shadow.Name = "Shadow"
	shadow.AnchorPoint =
		Vector2.new(0.5, 0.5)

	shadow.Position =
		UDim2.fromScale(0.51, 0.52)

	shadow.Size =
		UDim2.fromScale(0.45, 0.48)

	shadow.BackgroundColor3 =
		Colors.Shadow

	shadow.BackgroundTransparency = 0.25
	shadow.BorderSizePixel = 0
	shadow.Parent = overlay

	UITheme.AddCorner(shadow, 0.07)

	local window = Instance.new("Frame")
	window.Name = "Window"
	window.AnchorPoint =
		Vector2.new(0.5, 0.5)

	window.Position =
		UDim2.fromScale(0.5, 0.5)

	window.Size =
		UDim2.fromScale(0.45, 0.48)

	window.BackgroundColor3 =
		Colors.Surface

	window.BorderSizePixel = 0
	window.Active = true
	window.Parent = overlay

	UITheme.AddCorner(window, 0.07)

	UITheme.AddStroke(
		window,
		Colors.Danger,
		2,
		0.18
	)

	UITheme.AddGradient(
		window,
		Colors.SurfaceRaised,
		Colors.Background
	)

	local warningIcon =
		Instance.new("TextLabel")

	warningIcon.Name = "WarningIcon"
	warningIcon.Position =
		UDim2.fromScale(0.08, 0.08)

	warningIcon.Size =
		UDim2.fromScale(0.14, 0.22)

	warningIcon.BackgroundColor3 =
		Colors.Danger

	warningIcon.BorderSizePixel = 0
	warningIcon.Text = "!"
	warningIcon.Parent = window

	UITheme.AddCorner(warningIcon, 0.5)

	UITheme.AddGradient(
		warningIcon,
		Colors.Danger,
		Colors.DangerDark
	)

	UITheme.StyleText(
		warningIcon,
		18,
		30,
		Colors.Text,
		Fonts.Black
	)

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.Position =
	UDim2.fromScale(0.09, 0.12)

title.Size =
	UDim2.fromScale(0.82, 0.28)

	title.BackgroundTransparency = 1
	title.Text =
		"REMOVE LEMONADE STAND?"

	title.TextXAlignment =
		Enum.TextXAlignment.Left

	title.Parent = window

	UITheme.StyleText(
		title,
		14,
		23,
		Colors.Text,
		Fonts.Black
	)

	local subtitle =
		Instance.new("TextLabel")

	subtitle.Name = "Subtitle"
	subtitle.Position =
		UDim2.fromScale(0.27, 0.2)

	subtitle.Size =
		UDim2.fromScale(0.65, 0.08)

	subtitle.BackgroundTransparency = 1
	subtitle.Text =
		"This action can be reversed by building it again."

	subtitle.TextXAlignment =
		Enum.TextXAlignment.Left

	subtitle.Parent = window

	UITheme.StyleText(
		subtitle,
		9,
		14,
		Colors.TextMuted,
		Fonts.Medium
	)

	local description =
		Instance.new("TextLabel")

	description.Name = "Description"
	description.Position =
		UDim2.fromScale(0.08, 0.37)

	description.Size =
		UDim2.fromScale(0.84, 0.2)

	description.BackgroundColor3 =
		Colors.Background

	description.BackgroundTransparency = 0.3
	description.BorderSizePixel = 0

	description.Text =
		"All waiting customers will leave and sales will stop until another stand is built."

	description.TextXAlignment =
		Enum.TextXAlignment.Center

	description.Parent = window

	UITheme.AddCorner(description, 0.12)

	UITheme.AddStroke(
		description,
		Colors.Stroke,
		1,
		0.5
	)

	UITheme.StyleText(
		description,
		10,
		15,
		Colors.TextMuted,
		Fonts.Medium
	)

	local buttons = Instance.new("Frame")
	buttons.Name = "Buttons"
	buttons.Position =
	UDim2.fromScale(0.09, 0.48)

buttons.Size =
	UDim2.fromScale(0.82, 0.4)

	buttons.BackgroundTransparency = 1
	buttons.Parent = window

	local layout =
		Instance.new("UIListLayout")

	layout.FillDirection =
		Enum.FillDirection.Horizontal

	layout.HorizontalAlignment =
		Enum.HorizontalAlignment.Center

	layout.VerticalAlignment =
		Enum.VerticalAlignment.Center

	layout.Padding = UDim.new(0.04, 0)
	layout.Parent = buttons

	local cancelButton = createActionButton(
		buttons,
		"CancelButton",
		"KEEP STAND",
		Colors.SurfaceLight,
		Colors.SurfaceRaised
	)

	local removeButton = createActionButton(
		buttons,
		"ConfirmRemoveButton",
		"REMOVE STAND",
		Colors.Danger,
		Colors.DangerDark
	)

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

	local toast = Instance.new("TextLabel")
	toast.Name = "Toast"
	toast.AnchorPoint =
		Vector2.new(0.5, 0)

	toast.Position =
		UDim2.fromScale(0.5, 0.05)

	toast.Size =
		UDim2.fromScale(0.52, 0.075)

	toast.BackgroundColor3 =
		Colors.Surface

	toast.BackgroundTransparency = 0.05
	toast.BorderSizePixel = 0
	toast.Text = ""
	toast.Visible = false
	toast.Parent = screenGui

	UITheme.AddCorner(toast, 0.25)
	UITheme.AddStroke(toast, Colors.Stroke, 1.5, 0.2)

	UITheme.StyleText(
		toast,
		11,
		17,
		Colors.Text,
		Fonts.Bold
	)

	local function updateResponsiveLayout()
		local camera = Workspace.CurrentCamera

		if not camera then
			return
		end

		local viewport = camera.ViewportSize
		local portrait =
			viewport.Y > viewport.X

		local compact =
			viewport.X < 800
			or viewport.Y < 550

		if portrait then
			window.Size =
				UDim2.fromScale(0.9, 0.46)

			shadow.Size =
				UDim2.fromScale(0.9, 0.46)

			toast.Size =
				UDim2.fromScale(0.88, 0.075)
		elseif compact then
			window.Size =
				UDim2.fromScale(0.62, 0.7)

			shadow.Size =
				UDim2.fromScale(0.62, 0.7)

			toast.Size =
				UDim2.fromScale(0.62, 0.1)
		else
			window.Size =
				UDim2.fromScale(0.45, 0.48)

			shadow.Size =
				UDim2.fromScale(0.45, 0.48)

			toast.Size =
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

	confirmationOverlay = overlay
	confirmationWindow = window
	toastLabel = toast
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

		showToast(
			typeof(message) == "string"
				and message
				or "Lemonade stand removed."
		)

		return
	end

	if action == "RemoveFailed" then
		hideRemoveConfirmation()

		showToast(
			typeof(message) == "string"
				and message
				or "The stand could not be removed.",
			true
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

		showToast(
			typeof(message) == "string"
				and message
				or "The stand could not be edited.",
			true
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
	if stand and not managementCreationPending then
		managementCreationPending = true

		task.spawn(function()
			createManagementUI(stand)
			managementCreationPending = false
		end)
	elseif not stand then
		destroyManagementUI()
		managementCreationPending = false
	end
end

		local shouldShow = false

		if stand
			and rootPart
			and managementGui
			and stand:GetAttribute("IsBeingEdited")
			~= true
			and stand:GetAttribute("StandUnavailable")
			~= true then

			local adornee = getUIAdornee(stand)

			if adornee then
				local distance =
					(
						rootPart.Position
						- adornee.Position
					).Magnitude

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