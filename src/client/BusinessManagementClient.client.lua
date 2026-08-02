local Players =
	game:GetService("Players")

local ReplicatedStorage =
	game:GetService("ReplicatedStorage")

local Workspace =
	game:GetService("Workspace")

local player =
	Players.LocalPlayer

local playerGui =
	player:WaitForChild("PlayerGui")

local plotsFolder =
	Workspace:WaitForChild("Plots")

local remotes =
	ReplicatedStorage:WaitForChild("Remotes")

local requestEditRemote =
	remotes:WaitForChild(
		"RequestEditBusiness"
	)

local requestRemoveRemote =
	remotes:WaitForChild(
		"RequestRemoveBusiness"
	)

local interactionResultRemote =
	remotes:WaitForChild(
		"BusinessInteractionResult"
	)

local function getOpenUpgradeMenuEvent(): BindableEvent
	local existing =
		playerGui:FindFirstChild(
			"OpenUpgradeMenu"
		)

	if existing then
		if not existing:IsA(
			"BindableEvent"
		) then

			existing:Destroy()
		else
			return existing
		end
	end

	local event =
		Instance.new("BindableEvent")

	event.Name = "OpenUpgradeMenu"
	event.Parent = playerGui

	return event
end

local openUpgradeMenuEvent =
	getOpenUpgradeMenuEvent()

local UITheme = require(
	ReplicatedStorage
		:WaitForChild("Shared")
		:WaitForChild("UITheme")
)

local Colors = UITheme.Colors
local Fonts = UITheme.Fonts

local BUSINESS_NAME =
	"LemonadeStand"

local MANAGEMENT_DISTANCE = 22
local UPDATE_INTERVAL = 0.1

local managementGui: BillboardGui? = nil
local managementStand: Model? = nil

local confirmationOverlay: Frame? = nil
local confirmationWindow: Frame? = nil
local confirmationShadow: Frame? = nil

local confirmationTitle: TextLabel? = nil
local confirmationSubtitle: TextLabel? = nil
local confirmationDescription: TextLabel? = nil

local confirmationButtons: Frame? = nil
local confirmationButtonsLayout:
	UIListLayout? = nil

local keepStandButton: TextButton? = nil
local confirmRemoveButton: TextButton? = nil

local toastLabel: TextLabel? = nil

local managementCreationPending = false
local removeRequestPending = false

local pendingRemoveBusinessId:
	string? = nil

local toastVersion = 0

local function getOwnedPlot(): Model?
	local plotName =
		player:GetAttribute("PlotName")

	if typeof(plotName) == "string" then
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
		plotsFolder:GetChildren() do

		if plot:IsA("Model")
			and plot:GetAttribute(
				"OwnerUserId"
			) == player.UserId then

			return plot
		end
	end

	return nil
end

local function getCharacterRoot(): BasePart?
	local character =
		player.Character

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

local function isLemonadeStand(
	instance: Instance
): boolean
	if not instance:IsA("Model") then
		return false
	end

	local businessType =
		instance:GetAttribute(
			"BusinessType"
		)

	if businessType == BUSINESS_NAME then
		return true
	end

	return instance.Name == BUSINESS_NAME
		or string.match(
			instance.Name,
			"^LemonadeStand_"
		) ~= nil
end

local function getClosestOwnedStand(): Model?
	local plot =
		getOwnedPlot()

	if not plot then
		return nil
	end

	local placedBusinesses =
		plot:FindFirstChild(
			"PlacedBusinesses"
		)

	if not placedBusinesses then
		return nil
	end

	local rootPart =
		getCharacterRoot()

	if not rootPart then
		return nil
	end

	local closestStand: Model? = nil
	local closestDistance = math.huge

	for _, child in
		placedBusinesses:GetChildren() do

		if not child:IsA("Model") then
			continue
		end

		if not isLemonadeStand(child) then
			continue
		end

		if child:GetAttribute(
			"OwnerUserId"
		) ~= player.UserId then

			continue
		end

		local positionInstance =
			child:FindFirstChild(
				"ManagementUIPosition",
				true
			)

		local positionPart:
			BasePart? = nil

		if positionInstance
			and positionInstance:IsA(
				"BasePart"
			) then

			positionPart =
				positionInstance
		elseif child.PrimaryPart then
			positionPart =
				child.PrimaryPart
		end

		if not positionPart then
			continue
		end

		local distance =
			(
				rootPart.Position
					- positionPart.Position
			).Magnitude

		if distance < closestDistance then
			closestDistance = distance
			closestStand = child
		end
	end

	return closestStand
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
			and managementPosition:IsA(
				"BasePart"
			) then

			return managementPosition
		end

		local cooldownPosition =
			stand:FindFirstChild(
				"CooldownUIPosition",
				true
			)

		if cooldownPosition
			and cooldownPosition:IsA(
				"BasePart"
			) then

			return cooldownPosition
		end

		local salePosition =
			stand:FindFirstChild(
				"SaleEffectPosition",
				true
			)

		if salePosition
			and salePosition:IsA(
				"BasePart"
			) then

			return salePosition
		end

		if stand.PrimaryPart then
			return stand.PrimaryPart
		end

		return nil
	end

	local existing =
		findAdornee()

	if existing
		or waitForReplication ~= true then

		return existing
	end

	local startedAt = time()

	while stand.Parent
		and time() - startedAt < 10 do

		local adornee =
			findAdornee()

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

	local currentVersion =
		toastVersion

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
	local button =
		Instance.new("TextButton")

	button.Name = name

	button.Size =
		UDim2.fromScale(
			0.48,
			1
		)

	button.BackgroundColor3 =
		topColor

	button.BorderSizePixel = 0

	button.Text = text
	button.TextWrapped = true
	button.TextColor3 = Colors.Text
	button.TextTransparency = 0

	button.AutoButtonColor = true
	button.Active = true

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

	button.TextColor3 =
		Colors.Text

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

	billboard.Size =
	UDim2.fromScale(
		9.4,
		2.25
	)

	billboard.StudsOffsetWorldSpace =
		Vector3.new(
			0,
			3.1,
			0
		)

	billboard.AlwaysOnTop = true
	billboard.LightInfluence = 0

	billboard.MaxDistance =
		MANAGEMENT_DISTANCE + 5

	billboard.Active = true
	billboard.Enabled = false
	billboard.ResetOnSpawn = false
	billboard.Parent = playerGui

	local shadow =
		Instance.new("Frame")

	shadow.Name = "Shadow"

	shadow.AnchorPoint =
		Vector2.new(0.5, 0.5)

	shadow.Position =
		UDim2.fromScale(
			0.51,
			0.54
		)

	shadow.Size =
		UDim2.fromScale(
			0.98,
			0.96
		)

	shadow.BackgroundColor3 =
		Colors.Shadow

	shadow.BackgroundTransparency = 0.28
	shadow.BorderSizePixel = 0
	shadow.Parent = billboard

	UITheme.AddCorner(
		shadow,
		0.12
	)

	local container =
		Instance.new("Frame")

	container.Name = "Container"

	container.AnchorPoint =
		Vector2.new(0.5, 0.5)

	container.Position =
		UDim2.fromScale(
			0.5,
			0.5
		)

	container.Size =
		UDim2.fromScale(
			0.98,
			0.96
		)

	container.BackgroundColor3 =
		Colors.Surface

	container.BorderSizePixel = 0
	container.Active = true
	container.ZIndex = 2
	container.Parent = billboard

	UITheme.AddCorner(
		container,
		0.12
	)

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

	local accent =
		Instance.new("Frame")

	accent.Name = "Accent"

	accent.Position =
		UDim2.fromScale(
			0.03,
			0.08
		)

	accent.Size =
		UDim2.fromScale(
			0.025,
			0.84
		)

	accent.BackgroundColor3 =
		Colors.Primary

	accent.BorderSizePixel = 0
	accent.ZIndex = 3
	accent.Parent = container

	UITheme.AddCorner(
		accent,
		0.5
	)

	local title =
		Instance.new("TextLabel")

	title.Name = "Title"

	title.Position =
		UDim2.fromScale(
			0.09,
			0.08
		)

	title.Size =
		UDim2.fromScale(
			0.82,
			0.23
		)

	title.BackgroundTransparency = 1
	title.Text = "LEMONADE STAND"
	title.TextWrapped = true

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

	local buttons =
		Instance.new("Frame")

	buttons.Name = "Buttons"

	buttons.Position =
		UDim2.fromScale(
			0.09,
			0.5
		)

	buttons.Size =
		UDim2.fromScale(
			0.82,
			0.36
		)

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

	layout.Padding =
	UDim.new(0.025, 0)

	layout.Parent = buttons

	local editButton =
	createActionButton(
		buttons,
		"EditButton",
		"MOVE",
		Colors.Info,
		Colors.InfoDark
	)

local upgradeButton =
	createActionButton(
		buttons,
		"UpgradeButton",
		"UPGRADE",
		Colors.Primary,
		Colors.PrimaryDark
	)

local removeButton =
	createActionButton(
		buttons,
		"RemoveButton",
		"REMOVE",
		Colors.Danger,
		Colors.DangerDark
	)

editButton.Size =
	UDim2.fromScale(
		0.31,
		1
	)

upgradeButton.Size =
	UDim2.fromScale(
		0.31,
		1
	)

removeButton.Size =
	UDim2.fromScale(
		0.31,
		1
	)

	editButton.Activated:Connect(function()
		if stand
			~= getClosestOwnedStand() then

			showToast(
				"Your lemonade stand could not be found.",
				true
			)

			return
		end

		if stand:GetAttribute(
			"IsBeingEdited"
		) == true then

			return
		end

		local businessId =
			stand:GetAttribute(
				"BusinessId"
			) or stand.Name

		billboard.Enabled = false

		requestEditRemote:FireServer(
			businessId
		)
	end)

	upgradeButton.Activated:Connect(function()
	if stand
		~= getClosestOwnedStand() then

		showToast(
			"Your lemonade stand could not be found.",
			true
		)

		return
	end

	if stand:GetAttribute(
		"IsBeingEdited"
	) == true then

		showToast(
			"Finish moving this stand first.",
			true
		)

		return
	end

	if stand:GetAttribute(
		"StandUnavailable"
	) == true then

		showToast(
			"This stand is currently unavailable.",
			true
		)

		return
	end

	local businessId =
		stand:GetAttribute(
			"BusinessId"
		)

	if typeof(businessId) ~= "string"
		or businessId == "" then

		businessId = stand.Name
	end

	billboard.Enabled = false

	openUpgradeMenuEvent:Fire(
		businessId
	)
end)

	removeButton.Activated:Connect(function()
		if removeRequestPending then
			return
		end

		if stand
			~= getClosestOwnedStand() then

			showToast(
				"Your lemonade stand could not be found.",
				true
			)

			return
		end

		pendingRemoveBusinessId =
			stand:GetAttribute(
				"BusinessId"
			) or stand.Name

		removeRequestPending = true

		requestRemoveRemote:FireServer(
			false,
			pendingRemoveBusinessId
		)

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
	pendingRemoveBusinessId = nil
end

local function updateConfirmationLayout()
	local camera =
		Workspace.CurrentCamera

	if not camera
		or not confirmationWindow
		or not confirmationShadow
		or not confirmationButtons
		or not confirmationButtonsLayout
		or not keepStandButton
		or not confirmRemoveButton
		or not confirmationTitle
		or not confirmationSubtitle
		or not confirmationDescription
		or not toastLabel then

		return
	end

	local viewport =
		camera.ViewportSize

	local portrait =
		viewport.Y > viewport.X

	local narrow =
		viewport.X < 700

	local shortScreen =
		viewport.Y < 600

	local mobile =
		portrait or narrow

	local horizontalMargin = 24
	local verticalMargin = 36

	local maximumWidth =
		mobile and 520 or 680

	local maximumHeight =
		mobile and 520 or 410

	local windowWidth =
		math.min(
			maximumWidth,
			viewport.X - horizontalMargin * 2
		)

	local windowHeight =
		math.min(
			maximumHeight,
			viewport.Y - verticalMargin * 2
		)

	windowWidth =
		math.max(
			300,
			windowWidth
		)

	windowHeight =
		math.max(
			330,
			windowHeight
		)

	if shortScreen then
		windowHeight =
			math.min(
				windowHeight,
				viewport.Y - 24
			)
	end

	confirmationWindow.Size =
		UDim2.fromOffset(
			windowWidth,
			windowHeight
		)

	confirmationShadow.Size =
		UDim2.fromOffset(
			windowWidth,
			windowHeight
		)

	confirmationShadow.Position =
		UDim2.new(
			0.5,
			8,
			0.5,
			10
		)

	local contentPadding =
		mobile and 22 or 34

	confirmationTitle.Position =
		UDim2.fromOffset(
			contentPadding,
			mobile and 24 or 30
		)

	confirmationTitle.Size =
		UDim2.new(
			1,
			-contentPadding * 2,
			0,
			mobile and 52 or 48
		)

	confirmationSubtitle.Position =
		UDim2.fromOffset(
			contentPadding,
			mobile and 80 or 82
		)

	confirmationSubtitle.Size =
		UDim2.new(
			1,
			-contentPadding * 2,
			0,
			mobile and 42 or 36
		)

	local descriptionY =
		mobile and 132 or 128

	local descriptionHeight =
		mobile and 84 or 76

	confirmationDescription.Position =
		UDim2.fromOffset(
			contentPadding,
			descriptionY
		)

	confirmationDescription.Size =
		UDim2.new(
			1,
			-contentPadding * 2,
			0,
			descriptionHeight
		)

	if mobile then
		confirmationButtonsLayout.FillDirection =
			Enum.FillDirection.Vertical

		confirmationButtonsLayout.Padding =
			UDim.new(0, 12)

		confirmationButtons.Position =
			UDim2.fromOffset(
				contentPadding,
				descriptionY
					+ descriptionHeight
					+ 18
			)

		confirmationButtons.Size =
			UDim2.new(
				1,
				-contentPadding * 2,
				0,
				124
			)

		keepStandButton.Size =
			UDim2.new(
				1,
				0,
				0,
				56
			)

		confirmRemoveButton.Size =
			UDim2.new(
				1,
				0,
				0,
				56
			)
	else
		confirmationButtonsLayout.FillDirection =
			Enum.FillDirection.Horizontal

		confirmationButtonsLayout.Padding =
			UDim.new(0, 16)

		confirmationButtons.Position =
			UDim2.fromOffset(
				contentPadding,
				descriptionY
					+ descriptionHeight
					+ 24
			)

		confirmationButtons.Size =
			UDim2.new(
				1,
				-contentPadding * 2,
				0,
				66
			)

		keepStandButton.Size =
			UDim2.new(
				0.5,
				-8,
				1,
				0
			)

		confirmRemoveButton.Size =
			UDim2.new(
				0.5,
				-8,
				1,
				0
			)
	end

	local toastWidth =
		math.min(
			560,
			viewport.X - 32
		)

	toastLabel.Size =
		UDim2.fromOffset(
			toastWidth,
			mobile and 56 or 48
		)
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
	screenGui.ZIndexBehavior =
		Enum.ZIndexBehavior.Sibling

	screenGui.Parent = playerGui

	local overlay =
		Instance.new("Frame")

	overlay.Name = "Overlay"

	overlay.Size =
		UDim2.fromScale(1, 1)

	overlay.BackgroundColor3 =
		Colors.Shadow

	overlay.BackgroundTransparency = 0.18
	overlay.BorderSizePixel = 0

	overlay.Visible = false
	overlay.Active = true
	overlay.ZIndex = 1
	overlay.Parent = screenGui

	local shadow =
		Instance.new("Frame")

	shadow.Name = "Shadow"

	shadow.AnchorPoint =
		Vector2.new(0.5, 0.5)

	shadow.Position =
		UDim2.new(
			0.5,
			8,
			0.5,
			10
		)

	shadow.Size =
		UDim2.fromOffset(
			680,
			410
		)

	shadow.BackgroundColor3 =
		Colors.Shadow

	shadow.BackgroundTransparency = 0.2
	shadow.BorderSizePixel = 0
	shadow.ZIndex = 2
	shadow.Parent = overlay

	UITheme.AddCorner(
		shadow,
		0.05
	)

	local window =
		Instance.new("Frame")

	window.Name = "Window"

	window.AnchorPoint =
		Vector2.new(0.5, 0.5)

	window.Position =
		UDim2.fromScale(
			0.5,
			0.5
		)

	window.Size =
		UDim2.fromOffset(
			680,
			410
		)

	window.BackgroundColor3 =
		Colors.Surface

	window.BorderSizePixel = 0
	window.Active = true
	window.ClipsDescendants = true
	window.ZIndex = 3
	window.Parent = overlay

	UITheme.AddCorner(
		window,
		0.05
	)

	UITheme.AddStroke(
		window,
		Colors.Danger,
		2,
		0.08
	)

	UITheme.AddGradient(
		window,
		Colors.SurfaceRaised,
		Colors.Background
	)

	local topAccent =
		Instance.new("Frame")

	topAccent.Name = "TopAccent"

	topAccent.Position =
		UDim2.fromOffset(0, 0)

	topAccent.Size =
		UDim2.new(
			1,
			0,
			0,
			6
		)

	topAccent.BackgroundColor3 =
		Colors.Danger

	topAccent.BorderSizePixel = 0
	topAccent.ZIndex = 4
	topAccent.Parent = window

	local title =
		Instance.new("TextLabel")

	title.Name = "Title"

	title.Position =
		UDim2.fromOffset(
			34,
			30
		)

	title.Size =
		UDim2.new(
			1,
			-68,
			0,
			48
		)

	title.BackgroundTransparency = 1

	title.Text =
		"REMOVE LEMONADE STAND?"

	title.TextWrapped = true

	title.TextXAlignment =
		Enum.TextXAlignment.Left

	title.TextYAlignment =
		Enum.TextYAlignment.Center

	title.ZIndex = 4
	title.Parent = window

	UITheme.StyleText(
		title,
		17,
		25,
		Colors.Text,
		Fonts.Black
	)

	local subtitle =
		Instance.new("TextLabel")

	subtitle.Name = "Subtitle"

	subtitle.Position =
		UDim2.fromOffset(
			34,
			82
		)

	subtitle.Size =
		UDim2.new(
			1,
			-68,
			0,
			36
		)

	subtitle.BackgroundTransparency = 1

	subtitle.Text =
		"You can build another stand later."

	subtitle.TextWrapped = true

	subtitle.TextXAlignment =
		Enum.TextXAlignment.Left

	subtitle.TextYAlignment =
		Enum.TextYAlignment.Center

	subtitle.ZIndex = 4
	subtitle.Parent = window

	UITheme.StyleText(
		subtitle,
		10,
		15,
		Colors.TextMuted,
		Fonts.Medium
	)

	local description =
		Instance.new("TextLabel")

	description.Name = "Description"

	description.Position =
		UDim2.fromOffset(
			34,
			128
		)

	description.Size =
		UDim2.new(
			1,
			-68,
			0,
			76
		)

	description.BackgroundColor3 =
		Colors.Background

	description.BackgroundTransparency = 0.22
	description.BorderSizePixel = 0

	description.Text =
		"Customers waiting at this stand will leave. Your other stands and their customers will continue operating normally."

	description.TextWrapped = true

	description.TextXAlignment =
		Enum.TextXAlignment.Center

	description.TextYAlignment =
		Enum.TextYAlignment.Center

	description.ZIndex = 4
	description.Parent = window

	UITheme.AddCorner(
		description,
		0.09
	)

	UITheme.AddStroke(
		description,
		Colors.Stroke,
		1,
		0.45
	)

	UITheme.StyleText(
		description,
		10,
		16,
		Colors.TextMuted,
		Fonts.Medium
	)

	local buttons =
		Instance.new("Frame")

	buttons.Name = "Buttons"

	buttons.Position =
		UDim2.fromOffset(
			34,
			228
		)

	buttons.Size =
		UDim2.new(
			1,
			-68,
			0,
			66
		)

	buttons.BackgroundTransparency = 1
	buttons.ZIndex = 4
	buttons.Parent = window

	local layout =
		Instance.new("UIListLayout")

	layout.FillDirection =
		Enum.FillDirection.Horizontal

	layout.HorizontalAlignment =
		Enum.HorizontalAlignment.Center

	layout.VerticalAlignment =
		Enum.VerticalAlignment.Center

	layout.SortOrder =
		Enum.SortOrder.LayoutOrder

	layout.Padding =
		UDim.new(0, 16)

	layout.Parent = buttons

	local cancelButton =
		createActionButton(
			buttons,
			"CancelButton",
			"KEEP STAND",
			Colors.SurfaceLight,
			Colors.SurfaceRaised
		)

	cancelButton.LayoutOrder = 1

	local removeButton =
		createActionButton(
			buttons,
			"ConfirmRemoveButton",
			"REMOVE STAND",
			Colors.Danger,
			Colors.DangerDark
		)

	removeButton.LayoutOrder = 2

	cancelButton.Activated:Connect(function()
		hideRemoveConfirmation()
	end)

	removeButton.Activated:Connect(function()
		if removeRequestPending then
			return
		end

		if not pendingRemoveBusinessId then
			hideRemoveConfirmation()
			return
		end

		removeRequestPending = true
		overlay.Visible = false

		requestRemoveRemote:FireServer(
			true,
			pendingRemoveBusinessId
		)

		task.delay(2, function()
			removeRequestPending = false
		end)
	end)

	local toast =
		Instance.new("TextLabel")

	toast.Name = "Toast"

	toast.AnchorPoint =
		Vector2.new(0.5, 0)

	toast.Position =
		UDim2.new(
			0.5,
			0,
			0,
			18
		)

	toast.Size =
		UDim2.fromOffset(
			560,
			48
		)

	toast.BackgroundColor3 =
		Colors.Surface

	toast.BackgroundTransparency = 0.04
	toast.BorderSizePixel = 0

	toast.Text = ""
	toast.TextWrapped = true

	toast.Visible = false
	toast.ZIndex = 20
	toast.Parent = screenGui

	UITheme.AddCorner(
		toast,
		0.2
	)

	UITheme.AddStroke(
		toast,
		Colors.Stroke,
		1.5,
		0.2
	)

	UITheme.StyleText(
		toast,
		11,
		17,
		Colors.Text,
		Fonts.Bold
	)

	confirmationOverlay = overlay
	confirmationWindow = window
	confirmationShadow = shadow

	confirmationTitle = title
	confirmationSubtitle = subtitle
	confirmationDescription = description

	confirmationButtons = buttons
	confirmationButtonsLayout = layout

	keepStandButton = cancelButton
	confirmRemoveButton = removeButton

	toastLabel = toast

	updateConfirmationLayout()

	local camera =
		Workspace.CurrentCamera

	if camera then
		camera:GetPropertyChangedSignal(
			"ViewportSize"
		):Connect(
			updateConfirmationLayout
		)
	end

	Workspace:GetPropertyChangedSignal(
		"CurrentCamera"
	):Connect(function()
		local newCamera =
			Workspace.CurrentCamera

		if newCamera then
			updateConfirmationLayout()

			newCamera:GetPropertyChangedSignal(
				"ViewportSize"
			):Connect(
				updateConfirmationLayout
			)
		end
	end)
end

createRemoveConfirmation()

interactionResultRemote.OnClientEvent:Connect(
	function(
		action: string,
		message: any
	)
		if action
			== "ShowRemoveConfirmation" then

			removeRequestPending = false

			if confirmationOverlay then
				updateConfirmationLayout()

				confirmationOverlay.Visible =
					true
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
	end
)

player.CharacterRemoving:Connect(function()
	if managementGui then
		managementGui.Enabled = false
	end

	hideRemoveConfirmation()
end)

task.spawn(function()
	while true do
		local stand =
			getClosestOwnedStand()

		local rootPart =
			getCharacterRoot()

		if stand ~= managementStand then
			if stand
				and not managementCreationPending then

				managementCreationPending = true

				task.spawn(function()
					createManagementUI(
						stand
					)

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
			and managementStand == stand
			and stand:GetAttribute(
				"IsBeingEdited"
			) ~= true
			and stand:GetAttribute(
				"StandUnavailable"
			) ~= true then

			local adornee =
				getUIAdornee(stand)

			if adornee then
				local distance =
					(
						rootPart.Position
							- adornee.Position
					).Magnitude

				shouldShow =
					distance
					<= MANAGEMENT_DISTANCE
			end
		end

		if managementGui then
			managementGui.Enabled =
				shouldShow
		end

		task.wait(
			UPDATE_INTERVAL
		)
	end
end)