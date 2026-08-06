local Players =
	game:GetService("Players")

local ReplicatedStorage =
	game:GetService("ReplicatedStorage")

local Workspace =
	game:GetService("Workspace")

local TweenService =
	game:GetService("TweenService")

local UserInputService =
	game:GetService("UserInputService")

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
local confirmationWindowScale: UIScale? = nil

local confirmationOpen = false
local confirmationAnimating = false

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

local function hideRemoveConfirmation(
	clearPendingId: boolean?
)
	if not confirmationOverlay
		or not confirmationWindowScale
		or not confirmationOpen
		or confirmationAnimating then

		if clearPendingId ~= false then
			removeRequestPending = false
			pendingRemoveBusinessId = nil
		end

		return
	end

	confirmationOpen = false
	confirmationAnimating = true

	local overlayTween =
		TweenService:Create(
			confirmationOverlay,
			TweenInfo.new(
				0.16,
				Enum.EasingStyle.Quad,
				Enum.EasingDirection.In
			),
			{
				BackgroundTransparency = 1,
			}
		)

	local windowTween =
		TweenService:Create(
			confirmationWindowScale,
			TweenInfo.new(
				0.15,
				Enum.EasingStyle.Quad,
				Enum.EasingDirection.In
			),
			{
				Scale = 0.94,
			}
		)

	overlayTween:Play()
	windowTween:Play()

	windowTween.Completed:Once(function()
		confirmationAnimating = false

		if confirmationOpen then
			return
		end

		if confirmationOverlay then
			confirmationOverlay.Visible = false
		end

		if clearPendingId ~= false then
			removeRequestPending = false
			pendingRemoveBusinessId = nil
		end
	end)
end

local function showRemoveConfirmation()
	if not confirmationOverlay
		or not confirmationWindowScale
		or confirmationOpen then

		return
	end

	updateConfirmationLayout()

	confirmationOpen = true
	confirmationAnimating = false

	confirmationOverlay.Visible = true
	confirmationOverlay.BackgroundTransparency = 1

	confirmationWindowScale.Scale = 0.9

	TweenService:Create(
		confirmationOverlay,
		TweenInfo.new(
			0.18,
			Enum.EasingStyle.Quad,
			Enum.EasingDirection.Out
		),
		{
			BackgroundTransparency = 0.28,
		}
	):Play()

	TweenService:Create(
		confirmationWindowScale,
		TweenInfo.new(
			0.23,
			Enum.EasingStyle.Back,
			Enum.EasingDirection.Out
		),
		{
			Scale = 1,
		}
	):Play()
end

updateConfirmationLayout = function()
	local camera =
		Workspace.CurrentCamera

	if not camera
		or not confirmationWindow
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

	local mobile =
		viewport.X < 700
		or viewport.Y > viewport.X

	local veryNarrow =
		viewport.X < 430

	local availableWidth =
		math.max(
			280,
			viewport.X - 32
		)

	local windowWidth =
		math.min(
			mobile and 520 or 660,
			availableWidth
		)

	-- Fit the window closely around its actual content.
	local windowHeight =
		mobile and 410 or 348

	confirmationWindow.Size =
		UDim2.fromOffset(
			windowWidth,
			windowHeight
		)

	local horizontalPadding =
		mobile and 22 or 34

	local titleLeft =
		mobile and 82 or 92

	local rightReservedSpace =
		mobile and 76 or 92

	-- Keep the title to the right of the warning icon.
	confirmationTitle.Position =
		UDim2.fromOffset(
			titleLeft,
			20
		)

	confirmationTitle.Size =
		UDim2.new(
			1,
			-(titleLeft + rightReservedSpace),
			0,
			38
		)

	-- Leave clear space between the subtitle and
	-- the bottom edge of the header.
	confirmationSubtitle.Position =
		UDim2.fromOffset(
			titleLeft,
			60
		)

	confirmationSubtitle.Size =
		UDim2.new(
			1,
			-(titleLeft + rightReservedSpace),
			0,
			26
		)

	local descriptionY = 132

	local descriptionHeight =
		mobile and 96 or 86

	confirmationDescription.Position =
		UDim2.fromOffset(
			horizontalPadding,
			descriptionY
		)

	confirmationDescription.Size =
		UDim2.new(
			1,
			-horizontalPadding * 2,
			0,
			descriptionHeight
		)

	if mobile then
		confirmationButtonsLayout.FillDirection =
			Enum.FillDirection.Vertical

		confirmationButtonsLayout.Padding =
			UDim.new(0, 10)

		confirmationButtons.Position =
			UDim2.fromOffset(
				horizontalPadding,
				descriptionY
					+ descriptionHeight
					+ 16
			)

		confirmationButtons.Size =
			UDim2.new(
				1,
				-horizontalPadding * 2,
				0,
				118
			)

		keepStandButton.Size =
			UDim2.new(
				1,
				0,
				0,
				54
			)

		confirmRemoveButton.Size =
			UDim2.new(
				1,
				0,
				0,
				54
			)

		confirmRemoveButton.LayoutOrder = 1
		keepStandButton.LayoutOrder = 2
	else
		confirmationButtonsLayout.FillDirection =
			Enum.FillDirection.Horizontal

		confirmationButtonsLayout.Padding =
			UDim.new(0, 14)

		confirmationButtons.Position =
			UDim2.fromOffset(
				horizontalPadding,
				descriptionY
					+ descriptionHeight
					+ 18
			)

		confirmationButtons.Size =
			UDim2.new(
				1,
				-horizontalPadding * 2,
				0,
				58
			)

		keepStandButton.Size =
			UDim2.new(
				0.5,
				-7,
				1,
				0
			)

		confirmRemoveButton.Size =
			UDim2.new(
				0.5,
				-7,
				1,
				0
			)

		keepStandButton.LayoutOrder = 1
		confirmRemoveButton.LayoutOrder = 2
	end

	local toastWidth =
		math.min(
			560,
			viewport.X - 28
		)

	toastLabel.Size =
		UDim2.fromOffset(
			toastWidth,
			veryNarrow and 58 or 50
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

	screenGui.IgnoreGuiInset = true

	screenGui.ScreenInsets =
		Enum.ScreenInsets.DeviceSafeInsets

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

	overlay.BackgroundTransparency = 1
	overlay.BorderSizePixel = 0

	overlay.Visible = false
	overlay.Active = true
	overlay.ZIndex = 1
	overlay.Parent = screenGui

	-- No fake offset shadow frame.
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
			660,
			430
		)

	window.BackgroundColor3 =
		Colors.Surface

	window.BorderSizePixel = 0
	window.Active = true
	window.ClipsDescendants = true
	window.ZIndex = 3
	window.Parent = overlay

	local windowCorner =
		Instance.new("UICorner")

	windowCorner.CornerRadius =
		UDim.new(0, 18)

	windowCorner.Parent = window

	UITheme.AddStroke(
		window,
		Colors.Stroke,
		2,
		0.1
	)

	local windowScale =
		Instance.new("UIScale")

	windowScale.Scale = 0.9
	windowScale.Parent = window

	-- Clean premium header.
	local header =
		Instance.new("Frame")

	header.Name = "Header"

	header.Size =
	UDim2.new(
		1,
		0,
		0,
		112
	)

	header.BackgroundColor3 =
		Colors.Background

	header.BorderSizePixel = 0
	header.ClipsDescendants = true
	header.ZIndex = 4
	header.Parent = window

	local headerCorner =
		Instance.new("UICorner")

	headerCorner.CornerRadius =
		UDim.new(0, 18)

	headerCorner.Parent = header

	local headerBottomCover =
		Instance.new("Frame")

	headerBottomCover.Name =
		"BottomCover"

	headerBottomCover.AnchorPoint =
		Vector2.new(0, 1)

	headerBottomCover.Position =
		UDim2.fromScale(0, 1)

	headerBottomCover.Size =
		UDim2.new(
			1,
			0,
			0,
			20
		)

	headerBottomCover.BackgroundColor3 =
		Colors.Background

	headerBottomCover.BorderSizePixel = 0
	headerBottomCover.ZIndex = 4
	headerBottomCover.Parent = header

	local dangerIcon =
		Instance.new("Frame")

	dangerIcon.Name =
		"DangerIcon"

	dangerIcon.AnchorPoint =
		Vector2.new(0, 0.5)

	dangerIcon.Position =
	UDim2.new(
		0,
		28,
		0.5,
		0
	)

	dangerIcon.Size =
		UDim2.fromOffset(
			48,
			48
		)

	dangerIcon.BackgroundColor3 =
		Colors.Danger

	dangerIcon.BorderSizePixel = 0
	dangerIcon.ZIndex = 5
	dangerIcon.Parent = header

	UITheme.AddCorner(
		dangerIcon,
		0.5
	)

	local dangerIconConstraint =
	Instance.new("UISizeConstraint")

dangerIconConstraint.MinSize =
	Vector2.new(42, 42)

dangerIconConstraint.MaxSize =
	Vector2.new(48, 48)

dangerIconConstraint.Parent =
	dangerIcon

	local warningLabel =
		Instance.new("TextLabel")

	warningLabel.Name =
		"Warning"

	warningLabel.Size =
		UDim2.fromScale(1, 1)

	warningLabel.BackgroundTransparency = 1
	warningLabel.Text = "!"
	warningLabel.ZIndex = 6
	warningLabel.Parent = dangerIcon

	UITheme.StyleText(
		warningLabel,
		20,
		30,
		Colors.Text,
		Fonts.Black
	)

	local title =
		Instance.new("TextLabel")

	title.Name = "Title"

	title.Position =
		UDim2.fromOffset(
			92,
			24
		)

	title.Size =
		UDim2.new(
			1,
			-158,
			0,
			42
		)

	title.BackgroundTransparency = 1

	title.Text =
		"REMOVE LEMONADE STAND?"

	title.TextWrapped = true

	title.TextXAlignment =
		Enum.TextXAlignment.Left

	title.TextYAlignment =
		Enum.TextYAlignment.Center

	title.ZIndex = 5
	title.Parent = header

	UITheme.StyleText(
		title,
		16,
		24,
		Colors.Text,
		Fonts.Black
	)

	local subtitle =
		Instance.new("TextLabel")

	subtitle.Name = "Subtitle"

	subtitle.Position =
		UDim2.fromOffset(
			92,
			62
		)

	subtitle.Size =
		UDim2.new(
			1,
			-158,
			0,
			28
		)

	subtitle.BackgroundTransparency = 1

	subtitle.Text =
	"Only this stand will be removed."

	subtitle.TextWrapped = true

	subtitle.TextXAlignment =
		Enum.TextXAlignment.Left

	subtitle.TextYAlignment =
		Enum.TextYAlignment.Center

	subtitle.ZIndex = 5
	subtitle.Parent = header

	UITheme.StyleText(
		subtitle,
		9,
		14,
		Colors.TextMuted,
		Fonts.Medium
	)

	local closeButton =
		Instance.new("TextButton")

	closeButton.Name =
		"CloseButton"

	closeButton.AnchorPoint =
		Vector2.new(1, 0.5)

	closeButton.Position =
		UDim2.new(
			1,
			-22,
			0.5,
			0
		)

	closeButton.Size =
		UDim2.fromOffset(
			48,
			48
		)

	closeButton.Text = "×"
	closeButton.ZIndex = 6
	closeButton.Parent = header

	UITheme.StyleText(
		closeButton,
		17,
		25,
		Colors.Text,
		Fonts.Black
	)

	UITheme.StyleButton(
		closeButton,
		Colors.SurfaceLight,
		Colors.SurfaceRaised,
		Colors.Text
	)

	local closeAspect =
		Instance.new(
			"UIAspectRatioConstraint"
		)

	closeAspect.AspectRatio = 1
	closeAspect.Parent = closeButton

	local description =
		Instance.new("TextLabel")

	description.Name =
		"Description"

	description.Position =
		UDim2.fromOffset(
			34,
			132
		)

	description.Size =
		UDim2.new(
			1,
			-68,
			0,
			92
		)

	description.BackgroundColor3 =
		Colors.SurfaceRaised

	description.BorderSizePixel = 0

	description.Text =
		"Customers waiting at this stand will leave. Your other stands and their customers will continue operating normally."

	description.TextWrapped = true

	description.TextXAlignment =
		Enum.TextXAlignment.Left

	description.TextYAlignment =
		Enum.TextYAlignment.Center

	description.ZIndex = 4
	description.Parent = window

	UITheme.AddCorner(
		description,
		0.08
	)

	UITheme.AddStroke(
		description,
		Colors.Stroke,
		1,
		0.4
	)

	local descriptionPadding =
		Instance.new("UIPadding")

	descriptionPadding.PaddingLeft =
		UDim.new(0, 20)

	descriptionPadding.PaddingRight =
		UDim.new(0, 20)

	descriptionPadding.PaddingTop =
		UDim.new(0, 12)

	descriptionPadding.PaddingBottom =
		UDim.new(0, 12)

	descriptionPadding.Parent =
		description

	UITheme.StyleText(
		description,
		9,
		15,
		Colors.TextMuted,
		Fonts.Medium
	)

	local buttons =
		Instance.new("Frame")

	buttons.Name = "Buttons"

	buttons.Position =
		UDim2.fromOffset(
			34,
			248
		)

	buttons.Size =
		UDim2.new(
			1,
			-68,
			0,
			62
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
		UDim.new(0, 14)

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

	closeButton.Activated:Connect(function()
		hideRemoveConfirmation()
	end)

	removeButton.Activated:Connect(function()
		if removeRequestPending then
			return
		end

		local businessId =
			pendingRemoveBusinessId

		if not businessId then
			hideRemoveConfirmation()
			return
		end

		removeRequestPending = true

		removeButton.Text =
			"REMOVING..."

		removeButton.Active = false
		removeButton.Selectable = false

		-- Preserve the ID while the close animation plays.
		hideRemoveConfirmation(false)

		requestRemoveRemote:FireServer(
			true,
			businessId
		)

		task.delay(2, function()
			removeRequestPending = false

			if removeButton then
				removeButton.Text =
					"REMOVE STAND"

				removeButton.Active = true
				removeButton.Selectable = true
			end
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
			50
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
		10,
		16,
		Colors.Text,
		Fonts.Bold
	)

	confirmationOverlay = overlay
	confirmationWindow = window
	confirmationWindowScale = windowScale

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

		if not newCamera then
			return
		end

		updateConfirmationLayout()

		newCamera:GetPropertyChangedSignal(
			"ViewportSize"
		):Connect(
			updateConfirmationLayout
		)
	end)
end

createRemoveConfirmation()

UserInputService.InputBegan:Connect(
	function(input, gameProcessed)
		if gameProcessed
			or not confirmationOpen then

			return
		end

		if input.KeyCode
			== Enum.KeyCode.Escape
			or input.KeyCode
				== Enum.KeyCode.ButtonB then

			hideRemoveConfirmation()
		end
	end
)

interactionResultRemote.OnClientEvent:Connect(
	function(
		action: string,
		message: any
	)
		if action
			== "ShowRemoveConfirmation" then

			removeRequestPending = false

			showRemoveConfirmation()

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