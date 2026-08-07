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

local managementScale: UIScale? = nil
local managementVisible = false
local managementVisibilityVersion = 0

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
	iconOrTopColor: string | Color3,
	topOrBottomColor: Color3,
	optionalBottomColor: Color3?
): TextButton
	local iconText: string? = nil
	local topColor: Color3
	local bottomColor: Color3

	if typeof(iconOrTopColor) == "string" then
		iconText = iconOrTopColor
		topColor = topOrBottomColor

		if not optionalBottomColor then
			error(
				`{name} is missing its bottom button color.`
			)
		end

		bottomColor = optionalBottomColor
	else
		topColor = iconOrTopColor
		bottomColor = topOrBottomColor
	end

	local button =
		Instance.new("TextButton")

	button.Name = name

	-- 3-button management row needs narrower buttons.
	-- 2-button confirmation modal keeps wider buttons.
	if iconText then
		button.Size =
			UDim2.new(
				1 / 3,
				-6,
				1,
				0
			)
	else
		button.Size =
			UDim2.new(
				0.48,
				0,
				1,
				0
			)
	end

	button.BackgroundColor3 = topColor
	button.BorderSizePixel = 0
	button.Text = ""

	button.AutoButtonColor = false
	button.Active = true
	button.Selectable = true
	button.ZIndex = 10
	button.Parent = parent

	UITheme.AddCorner(
		button,
		0.16
	)

	UITheme.AddStroke(
		button,
		topColor:Lerp(
			Color3.new(1, 1, 1),
			0.28
		),
		1.25,
		0.34
	)

	UITheme.AddGradient(
		button,
		topColor,
		bottomColor
	)

	local buttonScale =
		Instance.new("UIScale")

	buttonScale.Scale = 1
	buttonScale.Parent = button

	if iconText then
		local icon =
			Instance.new("Frame")

		icon.Name = "Icon"
		icon.AnchorPoint = Vector2.new(0, 0.5)
		icon.Position = UDim2.new(0, 8, 0.5, 0)
		icon.Size = UDim2.fromOffset(26, 26)
		icon.BackgroundColor3 = Color3.new(1, 1, 1)
		icon.BackgroundTransparency = 0.82
		icon.BorderSizePixel = 0
		icon.ZIndex = 11
		icon.Parent = button

		UITheme.AddCorner(icon, 0.28)

		local iconLabel =
			Instance.new("TextLabel")

		iconLabel.Name = "IconLabel"
		iconLabel.Size = UDim2.fromScale(1, 1)
		iconLabel.BackgroundTransparency = 1
		iconLabel.Text = iconText
		iconLabel.TextColor3 = Colors.Text
		iconLabel.TextXAlignment = Enum.TextXAlignment.Center
		iconLabel.TextYAlignment = Enum.TextYAlignment.Center
		iconLabel.ZIndex = 12
		iconLabel.Parent = icon

		UITheme.StyleText(
			iconLabel,
			12,
			18,
			Colors.Text,
			Fonts.Black
		)

		local label =
			Instance.new("TextLabel")

		label.Name = "Label"
		label.AnchorPoint = Vector2.new(0, 0.5)
		label.Position = UDim2.new(0, 40, 0.5, 0)
		label.Size = UDim2.new(1, -46, 1, 0)
		label.BackgroundTransparency = 1
		label.Text = text
		label.TextColor3 = Colors.Text
		label.TextWrapped = false
		label.TextXAlignment = Enum.TextXAlignment.Left
		label.TextYAlignment = Enum.TextYAlignment.Center
		label.ZIndex = 11
		label.Parent = button

		UITheme.StyleText(
			label,
			8,
			13,
			Colors.Text,
			Fonts.Black
		)
	else
		local label =
			Instance.new("TextLabel")

		label.Name = "Label"
		label.Size = UDim2.new(1, -24, 1, 0)
		label.Position = UDim2.fromOffset(12, 0)
		label.BackgroundTransparency = 1
		label.Text = text
		label.TextColor3 = Colors.Text
		label.TextWrapped = true
		label.TextXAlignment = Enum.TextXAlignment.Center
		label.TextYAlignment = Enum.TextYAlignment.Center
		label.ZIndex = 11
		label.Parent = button

		UITheme.StyleText(
			label,
			10,
			17,
			Colors.Text,
			Fonts.Black
		)
	end

	local activeTween: Tween? = nil

	local function tweenScale(
		scale: number,
		duration: number
	)
		if activeTween then
			activeTween:Cancel()
		end

		activeTween =
			TweenService:Create(
				buttonScale,
				TweenInfo.new(
					duration,
					Enum.EasingStyle.Quad,
					Enum.EasingDirection.Out
				),
				{
					Scale = scale,
				}
			)

		activeTween:Play()
	end

	button.MouseEnter:Connect(function()
		if button.Active then
			tweenScale(1.025, 0.1)
		end
	end)

	button.MouseLeave:Connect(function()
		tweenScale(1, 0.1)
	end)

	button.InputBegan:Connect(function(input)
		if not button.Active then
			return
		end

		if input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch then

			tweenScale(0.95, 0.06)
		end
	end)

	button.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch then

			tweenScale(1, 0.09)
		end
	end)

	return button
end

local function updateManagementLayout()
	if not managementGui then
		return
	end

	local camera =
		Workspace.CurrentCamera

	if not camera then
		return
	end

	local viewport =
		camera.ViewportSize

	local mobile =
		viewport.X < 700
		or viewport.Y > viewport.X

	if mobile then
		managementGui.Size =
			UDim2.fromOffset(
				310,
				112
			)
	else
		managementGui.Size =
			UDim2.fromOffset(
				346,
				116
			)
	end
end


local function setManagementVisible(
	visible: boolean
)
	if not managementGui
		or not managementScale then

		return
	end

	if managementVisible == visible then
		return
	end

	managementVisible = visible
	managementVisibilityVersion += 1

	local currentVersion =
		managementVisibilityVersion

	if visible then
		managementGui.Enabled = true
		managementScale.Scale = 0.9

		TweenService:Create(
			managementScale,
			TweenInfo.new(
				0.18,
				Enum.EasingStyle.Back,
				Enum.EasingDirection.Out
			),
			{
				Scale = 1,
			}
		):Play()

		return
	end

	TweenService:Create(
	managementScale,
	TweenInfo.new(
		0.11,
		Enum.EasingStyle.Quad,
		Enum.EasingDirection.In
	),
	{
		Scale = 0.94,
	}
):Play()

task.delay(
	0.11,
	function()
		if currentVersion
				~= managementVisibilityVersion
			or managementVisible then

			return
		end

		if managementGui then
			managementGui.Enabled = false
		end
	end
)
end

local function destroyManagementUI()
	managementVisibilityVersion += 1
	managementVisible = false

	if managementGui then
		managementGui:Destroy()
		managementGui = nil
	end

	managementScale = nil
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

	billboard.Adornee =
		adornee

	-- Pixel sizing is much more consistent across
	-- desktop, tablet, and mobile than stud scaling.
	billboard.Size =
		UDim2.fromOffset(
			346,
			116
		)

	billboard.StudsOffsetWorldSpace =
		Vector3.new(
			0,
			3.25,
			0
		)

	billboard.AlwaysOnTop = true
	billboard.LightInfluence = 0

	billboard.MaxDistance =
		MANAGEMENT_DISTANCE + 5

	billboard.Active = true
	billboard.Enabled = false
	billboard.ResetOnSpawn = false

	billboard.Parent =
		playerGui


	-- Whole widget animation.
	local rootScale =
		Instance.new("UIScale")

	rootScale.Scale = 0.9
	rootScale.Parent = billboard


	-- Subtle shadow rather than the large hard shadow
	-- used by the old widget.
	local shadow =
		Instance.new("Frame")

	shadow.Name =
		"Shadow"

	shadow.AnchorPoint =
		Vector2.new(
			0.5,
			0.5
		)

	shadow.Position =
		UDim2.new(
			0.5,
			0,
			0.5,
			4
		)

	shadow.Size =
		UDim2.new(
			1,
			-4,
			1,
			-4
		)

	shadow.BackgroundColor3 =
		Colors.Shadow

	shadow.BackgroundTransparency =
		0.42

	shadow.BorderSizePixel = 0
	shadow.ZIndex = 1
	shadow.Parent = billboard

	UITheme.AddCorner(
		shadow,
		0.12
	)


	local container =
		Instance.new("Frame")

	container.Name =
		"Container"

	container.AnchorPoint =
		Vector2.new(
			0.5,
			0.5
		)

	container.Position =
		UDim2.fromScale(
			0.5,
			0.5
		)

	container.Size =
		UDim2.new(
			1,
			-4,
			1,
			-4
		)

	container.BackgroundColor3 =
		Colors.Surface

	container.BorderSizePixel = 0
	container.Active = true
	container.ClipsDescendants = true

	container.ZIndex = 2
	container.Parent = billboard

	UITheme.AddCorner(
		container,
		0.12
	)

	UITheme.AddStroke(
		container,
		Colors.Stroke,
		1.5,
		0.18
	)

	UITheme.AddGradient(
		container,
		Colors.SurfaceRaised,
		Colors.Background
	)


	-- Thin premium-colored top accent.
	local topAccent =
		Instance.new("Frame")

	topAccent.Name =
		"TopAccent"

	topAccent.Size =
		UDim2.new(
			1,
			0,
			0,
			4
		)

	topAccent.BackgroundColor3 =
		Colors.Primary

	topAccent.BorderSizePixel = 0
	topAccent.ZIndex = 3
	topAccent.Parent = container


	-- Header.
	local header =
		Instance.new("Frame")

	header.Name =
		"Header"

	header.Position =
		UDim2.fromOffset(
			14,
			10
		)

	header.Size =
		UDim2.new(
			1,
			-28,
			0,
			30
		)

	header.BackgroundTransparency =
		1

	header.ZIndex = 4
	header.Parent = container


	local title =
		Instance.new("TextLabel")

	title.Name =
		"Title"

	title.Position =
		UDim2.fromOffset(
			0,
			0
		)

	title.Size =
	UDim2.new(
		1,
		0,
		0,
		18
	)

	title.BackgroundTransparency =
		1

	title.Text =
		"LEMONADE STAND"

	title.TextWrapped = false

	title.TextXAlignment =
		Enum.TextXAlignment.Left

	title.TextYAlignment =
		Enum.TextYAlignment.Center

	title.ZIndex = 5
	title.Parent = header

	UITheme.StyleText(
		title,
		11,
		16,
		Colors.Text,
		Fonts.Black
	)


	local subtitle =
		Instance.new("TextLabel")

	subtitle.Name =
		"Subtitle"

	subtitle.Position =
		UDim2.fromOffset(
			0,
			17
		)

	subtitle.Size =
	UDim2.new(
		1,
		0,
		0,
		13
	)

	subtitle.BackgroundTransparency =
		1

	subtitle.Text =
		"Manage this location"

	subtitle.TextWrapped = false

	subtitle.TextXAlignment =
		Enum.TextXAlignment.Left

	subtitle.TextYAlignment =
		Enum.TextYAlignment.Center

	subtitle.ZIndex = 5
	subtitle.Parent = header

	UITheme.StyleText(
		subtitle,
		8,
		11,
		Colors.TextMuted,
		Fonts.Medium
	)


	local divider =
		Instance.new("Frame")

	divider.Name =
		"Divider"

	divider.Position =
		UDim2.fromOffset(
			14,
			47
		)

	divider.Size =
		UDim2.new(
			1,
			-28,
			0,
			1
		)

	divider.BackgroundColor3 =
		Colors.Stroke

	divider.BackgroundTransparency =
		0.65

	divider.BorderSizePixel = 0
	divider.ZIndex = 4
	divider.Parent = container


	-- Action area.
	local buttons =
		Instance.new("Frame")

	buttons.Name =
		"Buttons"

	buttons.Position =
	UDim2.fromOffset(
		14,
		56
	)

buttons.Size =
	UDim2.new(
		1,
		-28,
		0,
		44
	)

	buttons.BackgroundTransparency =
		1

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

	layout.SortOrder =
		Enum.SortOrder.LayoutOrder

	layout.Padding =
	UDim.new(
		0,
		6
	)

	layout.Parent = buttons


	local editButton =
		createActionButton(
			buttons,
			"EditButton",
			"MOVE",
			"↔",
			Colors.Info,
			Colors.InfoDark
		)

	editButton.LayoutOrder = 1


	local upgradeButton =
		createActionButton(
			buttons,
			"UpgradeButton",
			"UPGRADE",
			"↑",
			Colors.Primary,
			Colors.PrimaryDark
		)

	upgradeButton.LayoutOrder = 2


	local removeButton =
		createActionButton(
			buttons,
			"RemoveButton",
			"REMOVE",
			"×",
			Colors.Danger,
			Colors.DangerDark
		)

	removeButton.LayoutOrder = 3


	editButton.Activated:Connect(
		function()
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

			setManagementVisible(
				false
			)

			requestEditRemote:FireServer(
				businessId
			)
		end
	)


	upgradeButton.Activated:Connect(
		function()
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

			if typeof(businessId)
					~= "string"
				or businessId == "" then

				businessId =
					stand.Name
			end

			setManagementVisible(
				false
			)

			openUpgradeMenuEvent:Fire(
				businessId
			)
		end
	)


	removeButton.Activated:Connect(
		function()
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

			task.delay(
				2,
				function()
					removeRequestPending =
						false
				end
			)
		end
	)


	managementGui = billboard
	managementStand = stand
	managementScale = rootScale
	managementVisible = false

	updateManagementLayout()
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

local function connectManagementCamera(
	camera: Camera
)
	camera:GetPropertyChangedSignal(
		"ViewportSize"
	):Connect(function()
		updateManagementLayout()
	end)
end


if Workspace.CurrentCamera then
	connectManagementCamera(
		Workspace.CurrentCamera
	)
end


Workspace:GetPropertyChangedSignal(
	"CurrentCamera"
):Connect(function()
	local camera =
		Workspace.CurrentCamera

	if not camera then
		return
	end

	updateManagementLayout()

	connectManagementCamera(
		camera
	)
end)

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

			setManagementVisible(
	false
)

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
			setManagementVisible(
	false
)

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
	setManagementVisible(
	false
)

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

				managementCreationPending =
					true

				task.spawn(function()
					createManagementUI(
						stand
					)

					managementCreationPending =
						false
				end)

			elseif not stand then
				destroyManagementUI()

				managementCreationPending =
					false
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
				getUIAdornee(
					stand
				)

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


		setManagementVisible(
			shouldShow
		)

		task.wait(
			UPDATE_INTERVAL
		)
	end
end)