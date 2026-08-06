local Players =
	game:GetService("Players")

local ReplicatedStorage =
	game:GetService("ReplicatedStorage")

local TweenService =
	game:GetService("TweenService")

local UserInputService =
	game:GetService("UserInputService")

local player =
	Players.LocalPlayer

local playerGui =
	player:WaitForChild("PlayerGui")

local remotes =
	ReplicatedStorage:WaitForChild(
		"Remotes"
	)

local getMarketingStateRemote =
	remotes:WaitForChild(
		"GetMarketingState"
	)

local purchaseMarketingRemote =
	remotes:WaitForChild(
		"PurchaseMarketing"
	)

local marketingResultRemote =
	remotes:WaitForChild(
		"MarketingResult"
	)

local UITheme = require(
	ReplicatedStorage
		:WaitForChild("Shared")
		:WaitForChild("UITheme")
)

local Colors = UITheme.Colors
local Fonts = UITheme.Fonts

type MarketingState = {
	Success: boolean,
	Message: string,

	CurrentLevel: number?,
	MaximumLevel: number?,
	NextCost: number?,

	DisplayName: string?,
	Description: string?,
	TemplateName: string?,

	CustomerLimit: number?,
	MinimumSpawnInterval: number?,
	MaximumSpawnInterval: number?,
}

type Interface = {
	ScreenGui: ScreenGui,
	OpenButton: TextButton,

	Overlay: Frame,
	Window: Frame,
	WindowScale: UIScale,

	CloseButton: TextButton,

	LevelLabel: TextLabel,
	NameLabel: TextLabel,
	DescriptionLabel: TextLabel,

	CustomerLimitValue: TextLabel,
	SpawnSpeedValue: TextLabel,

	ProgressFill: Frame,
	ProgressLabel: TextLabel,

	StatusLabel: TextLabel,
	PurchaseButton: TextButton,
}

local interface: Interface

local menuOpen = false
local requestPending = false
local currentState: MarketingState? = nil

local function createTextLabel(
	parent: Instance,
	name: string,
	text: string,
	position: UDim2,
	size: UDim2,
	minimumTextSize: number,
	maximumTextSize: number,
	font: Enum.Font?,
	color: Color3?,
	alignment: Enum.TextXAlignment?
): TextLabel
	local label =
		Instance.new("TextLabel")

	label.Name = name
	label.Position = position
	label.Size = size

	label.BackgroundTransparency = 1
	label.BorderSizePixel = 0

	label.Text = text

	label.TextXAlignment =
		alignment
		or Enum.TextXAlignment.Left

	label.TextYAlignment =
		Enum.TextYAlignment.Center

	label.Parent = parent

	UITheme.StyleText(
		label,
		minimumTextSize,
		maximumTextSize,
		color or Colors.Text,
		font or Fonts.Semibold
	)

	return label
end

local function createResponsiveWindow(
	parent: Instance
): (Frame, UIScale)
	local window =
		Instance.new("Frame")

	window.Name = "MarketingWindow"
	window.AnchorPoint =
		Vector2.new(0.5, 0.5)

	window.Position =
		UDim2.fromScale(0.5, 0.5)

	window.Size =
		UDim2.fromScale(
			0.88,
			0.84
		)

	window.BackgroundColor3 =
		Colors.Surface

	window.BorderSizePixel = 0
	window.ClipsDescendants = true
	window.Parent = parent

	UITheme.AddCorner(
		window,
		0.035
	)

	UITheme.AddStroke(
		window,
		Colors.Stroke,
		2,
		0.05
	)

	local sizeConstraint =
		Instance.new("UISizeConstraint")

	sizeConstraint.MinSize =
		Vector2.new(290, 430)

	sizeConstraint.MaxSize =
		Vector2.new(720, 680)

	sizeConstraint.Parent = window

	local scale =
		Instance.new("UIScale")

	scale.Scale = 1
	scale.Parent = window

	return window, scale
end

local function createStatCard(
	parent: Instance,
	name: string,
	title: string,
	iconText: string,
	layoutOrder: number
): TextLabel
	local card =
		Instance.new("Frame")

	card.Name = name
	card.LayoutOrder = layoutOrder
	card.Size =
		UDim2.new(
			0.5,
			-6,
			1,
			0
		)

	card.BackgroundColor3 =
		Colors.SurfaceRaised

	card.BorderSizePixel = 0
	card.Parent = parent

	UITheme.AddCorner(
		card,
		0.1
	)

	UITheme.AddStroke(
		card,
		Colors.Stroke,
		1.5,
		0.3
	)

	local icon =
		createTextLabel(
			card,
			"Icon",
			iconText,
			UDim2.fromScale(0.05, 0.08),
			UDim2.fromScale(0.2, 0.34),
			15,
			26,
			Fonts.Black,
			Colors.Primary,
			Enum.TextXAlignment.Center
		)

	icon.TextYAlignment =
		Enum.TextYAlignment.Center

	local titleLabel =
		createTextLabel(
			card,
			"Title",
			title,
			UDim2.fromScale(0.24, 0.08),
			UDim2.fromScale(0.7, 0.3),
			9,
			14,
			Fonts.Bold,
			Colors.TextMuted,
			Enum.TextXAlignment.Left
		)

	local valueLabel =
		createTextLabel(
			card,
			"Value",
			"--",
			UDim2.fromScale(0.08, 0.4),
			UDim2.fromScale(0.84, 0.45),
			15,
			28,
			Fonts.Black,
			Colors.Text,
			Enum.TextXAlignment.Center
		)

	return valueLabel
end

local function createInterface(): Interface
	local existing =
		playerGui:FindFirstChild(
			"MarketingMenu"
		)

	if existing then
		existing:Destroy()
	end

	local screenGui =
		Instance.new("ScreenGui")

	screenGui.Name = "MarketingMenu"
	screenGui.ResetOnSpawn = false
	screenGui.IgnoreGuiInset = false
	screenGui.DisplayOrder = 25
	screenGui.ZIndexBehavior =
		Enum.ZIndexBehavior.Sibling

	screenGui.Parent = playerGui

	-- Permanent HUD button.
	local openButton =
		Instance.new("TextButton")

	openButton.Name = "OpenMarketingButton"
	openButton.AnchorPoint =
		Vector2.new(0, 0.5)

	openButton.Position =
		UDim2.new(
			0,
			14,
			0.58,
			0
		)

	openButton.Size =
		UDim2.fromOffset(
			158,
			54
		)

	openButton.Text =
		"MARKETING"

	openButton.Parent = screenGui

	UITheme.StyleText(
		openButton,
		11,
		18,
		Colors.TextDark,
		Fonts.Black
	)

	UITheme.StyleButton(
		openButton,
		Colors.Primary,
		Colors.PrimaryDark,
		Colors.TextDark
	)

	local openSizeConstraint =
		Instance.new("UISizeConstraint")

	openSizeConstraint.MinSize =
		Vector2.new(126, 46)

	openSizeConstraint.MaxSize =
		Vector2.new(170, 58)

	openSizeConstraint.Parent =
		openButton

	-- Darkened background behind the menu.
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
	overlay.Parent = screenGui

	local window, windowScale =
		createResponsiveWindow(
			overlay
		)

	windowScale.Scale = 0.92

	-- Header.
	local header =
		Instance.new("Frame")

	header.Name = "Header"
	header.Size =
		UDim2.fromScale(1, 0.145)

	header.BackgroundColor3 =
		Colors.SurfaceRaised

	header.BorderSizePixel = 0
	header.Parent = window

	UITheme.AddCorner(
	header,
	0.035
)

local headerBottomCover =
	Instance.new("Frame")

headerBottomCover.Name =
	"HeaderBottomCover"

headerBottomCover.AnchorPoint =
	Vector2.new(0, 1)

headerBottomCover.Position =
	UDim2.fromScale(0, 1)

headerBottomCover.Size =
	UDim2.fromScale(1, 0.22)

headerBottomCover.BackgroundColor3 =
	Colors.SurfaceRaised

headerBottomCover.BorderSizePixel = 0
headerBottomCover.Parent = header

	local headerGradient =
		Instance.new("UIGradient")

	headerGradient.Color =
		ColorSequence.new({
			ColorSequenceKeypoint.new(
				0,
				Colors.SurfaceRaised
			),
			ColorSequenceKeypoint.new(
				1,
				Colors.Surface
			),
		})

	headerGradient.Rotation = 90
	headerGradient.Parent = header

	local titleLabel =
		createTextLabel(
			header,
			"Title",
			"MARKETING",
			UDim2.fromScale(0.05, 0.1),
			UDim2.fromScale(0.7, 0.44),
			18,
			32,
			Fonts.Black,
			Colors.Text,
			Enum.TextXAlignment.Left
		)

	local subtitleLabel =
		createTextLabel(
			header,
			"Subtitle",
			"Bring more customers to your businesses",
			UDim2.fromScale(0.05, 0.53),
			UDim2.fromScale(0.76, 0.3),
			9,
			15,
			Fonts.Medium,
			Colors.TextMuted,
			Enum.TextXAlignment.Left
		)

	local closeButton =
		Instance.new("TextButton")

	closeButton.Name = "CloseButton"
	closeButton.AnchorPoint =
		Vector2.new(1, 0.5)

	closeButton.Position =
		UDim2.fromScale(0.955, 0.5)

	closeButton.Size =
		UDim2.fromScale(0.09, 0.56)

	closeButton.Text = "×"
	closeButton.Parent = header

	UITheme.StyleText(
		closeButton,
		18,
		30,
		Colors.Text,
		Fonts.Black
	)

	UITheme.StyleButton(
		closeButton,
		Colors.Danger,
		Colors.DangerDark,
		Colors.Text
	)

	local closeAspect =
		Instance.new("UIAspectRatioConstraint")

	closeAspect.AspectRatio = 1
	closeAspect.Parent = closeButton

	-- Main content container.
	local content =
		Instance.new("Frame")

	content.Name = "Content"
	content.Position =
		UDim2.fromScale(0, 0.145)

	content.Size =
		UDim2.fromScale(1, 0.855)

	content.BackgroundTransparency = 1
	content.Parent = window

	local contentPadding =
		Instance.new("UIPadding")

	contentPadding.PaddingLeft =
		UDim.new(0.045, 0)

	contentPadding.PaddingRight =
		UDim.new(0.045, 0)

	contentPadding.PaddingTop =
		UDim.new(0.035, 0)

	contentPadding.PaddingBottom =
		UDim.new(0.035, 0)

	contentPadding.Parent = content

	local layout =
		Instance.new("UIListLayout")

	layout.FillDirection =
		Enum.FillDirection.Vertical

	layout.HorizontalAlignment =
		Enum.HorizontalAlignment.Center

	layout.SortOrder =
		Enum.SortOrder.LayoutOrder

	layout.Padding =
		UDim.new(0.018, 0)

	layout.Parent = content

	-- Level and current marketing name.
	local heroCard =
		Instance.new("Frame")

	heroCard.Name = "HeroCard"
	heroCard.LayoutOrder = 1
	heroCard.Size =
		UDim2.new(1, 0, 0.25, 0)

	heroCard.BackgroundColor3 =
		Colors.SurfaceRaised

	heroCard.BorderSizePixel = 0
	heroCard.Parent = content

	UITheme.AddCorner(
		heroCard,
		0.06
	)

	UITheme.AddStroke(
		heroCard,
		Colors.Primary,
		2,
		0.2
	)

	local accent =
		Instance.new("Frame")

	accent.Name = "Accent"
	accent.Size =
		UDim2.fromScale(0.025, 1)

	accent.BackgroundColor3 =
		Colors.Primary

	accent.BorderSizePixel = 0
	accent.Parent = heroCard

	UITheme.AddCorner(
		accent,
		0.25
	)

	local levelLabel =
		createTextLabel(
			heroCard,
			"Level",
			"LEVEL 0",
			UDim2.fromScale(0.07, 0.08),
			UDim2.fromScale(0.38, 0.22),
			10,
			16,
			Fonts.Black,
			Colors.Primary,
			Enum.TextXAlignment.Left
		)

	local nameLabel =
		createTextLabel(
			heroCard,
			"MarketingName",
			"WORD OF MOUTH",
			UDim2.fromScale(0.07, 0.29),
			UDim2.fromScale(0.86, 0.28),
			15,
			27,
			Fonts.Black,
			Colors.Text,
			Enum.TextXAlignment.Left
		)

	local descriptionLabel =
		createTextLabel(
			heroCard,
			"Description",
			"Customers discover your businesses naturally.",
			UDim2.fromScale(0.07, 0.58),
			UDim2.fromScale(0.86, 0.32),
			9,
			15,
			Fonts.Medium,
			Colors.TextMuted,
			Enum.TextXAlignment.Left
		)

	descriptionLabel.TextYAlignment =
		Enum.TextYAlignment.Top

	-- Statistics.
	local statRow =
		Instance.new("Frame")

	statRow.Name = "StatRow"
	statRow.LayoutOrder = 2
	statRow.Size =
		UDim2.new(1, 0, 0.18, 0)

	statRow.BackgroundTransparency = 1
	statRow.Parent = content

	local statLayout =
		Instance.new("UIListLayout")

	statLayout.FillDirection =
		Enum.FillDirection.Horizontal

	statLayout.HorizontalAlignment =
		Enum.HorizontalAlignment.Center

	statLayout.VerticalAlignment =
		Enum.VerticalAlignment.Center

	statLayout.Padding =
		UDim.new(0, 12)

	statLayout.Parent = statRow

	local customerLimitValue =
		createStatCard(
			statRow,
			"CustomerLimitCard",
			"CUSTOMER LIMIT",
			"👥",
			1
		)

	local spawnSpeedValue =
		createStatCard(
			statRow,
			"SpawnSpeedCard",
			"SPAWN TIME",
			"⏱",
			2
		)

	-- Progress.
	local progressCard =
		Instance.new("Frame")

	progressCard.Name = "ProgressCard"
	progressCard.LayoutOrder = 3
	progressCard.Size =
		UDim2.new(1, 0, 0.15, 0)

	progressCard.BackgroundColor3 =
		Colors.SurfaceRaised

	progressCard.BorderSizePixel = 0
	progressCard.Parent = content

	UITheme.AddCorner(
		progressCard,
		0.08
	)

	UITheme.AddStroke(
		progressCard,
		Colors.Stroke,
		1.5,
		0.3
	)

	local progressLabel =
		createTextLabel(
			progressCard,
			"ProgressLabel",
			"MARKETING PROGRESS",
			UDim2.fromScale(0.05, 0.08),
			UDim2.fromScale(0.9, 0.34),
			9,
			14,
			Fonts.Bold,
			Colors.TextMuted,
			Enum.TextXAlignment.Left
		)

	local progressTrack =
		Instance.new("Frame")

	progressTrack.Name = "ProgressTrack"
	progressTrack.Position =
		UDim2.fromScale(0.05, 0.58)

	progressTrack.Size =
		UDim2.fromScale(0.9, 0.22)

	progressTrack.BackgroundColor3 =
		Colors.ProgressTrack

	progressTrack.BorderSizePixel = 0
	progressTrack.ClipsDescendants = true
	progressTrack.Parent = progressCard

	UITheme.AddCorner(
		progressTrack,
		0.5
	)

	local progressFill =
		Instance.new("Frame")

	progressFill.Name = "ProgressFill"
	progressFill.Size =
		UDim2.fromScale(0, 1)

	progressFill.BackgroundColor3 =
		Colors.Primary

	progressFill.BorderSizePixel = 0
	progressFill.Parent = progressTrack

	UITheme.AddCorner(
		progressFill,
		0.5
	)

	-- Status.
	local statusLabel =
		createTextLabel(
			content,
			"StatusLabel",
			"",
			UDim2.new(),
			UDim2.new(1, 0, 0.08, 0),
			9,
			15,
			Fonts.Semibold,
			Colors.TextMuted,
			Enum.TextXAlignment.Center
		)

	statusLabel.LayoutOrder = 4

	-- Purchase button.
	local purchaseButton =
		Instance.new("TextButton")

	purchaseButton.Name =
		"PurchaseButton"

	purchaseButton.LayoutOrder = 5
	purchaseButton.Size =
		UDim2.new(1, 0, 0.14, 0)

	purchaseButton.Text =
		"LOADING..."

	purchaseButton.Parent = content

	UITheme.StyleText(
		purchaseButton,
		13,
		23,
		Colors.TextDark,
		Fonts.Black
	)

	UITheme.StyleButton(
		purchaseButton,
		Colors.Primary,
		Colors.PrimaryDark,
		Colors.TextDark
	)

	local buttonSizeConstraint =
		Instance.new("UISizeConstraint")

	buttonSizeConstraint.MinSize =
		Vector2.new(0, 52)

	buttonSizeConstraint.MaxSize =
		Vector2.new(1000, 76)

	buttonSizeConstraint.Parent =
		purchaseButton

	return {
		ScreenGui = screenGui,
		OpenButton = openButton,

		Overlay = overlay,
		Window = window,
		WindowScale = windowScale,

		CloseButton = closeButton,

		LevelLabel = levelLabel,
		NameLabel = nameLabel,
		DescriptionLabel =
			descriptionLabel,

		CustomerLimitValue =
			customerLimitValue,

		SpawnSpeedValue =
			spawnSpeedValue,

		ProgressFill = progressFill,
		ProgressLabel = progressLabel,

		StatusLabel = statusLabel,
		PurchaseButton = purchaseButton,
	}
end

local function formatSpawnTime(
	minimum: number?,
	maximum: number?
): string
	if typeof(minimum) ~= "number"
		or typeof(maximum) ~= "number" then

		return "--"
	end

	return string.format(
		"%.1f–%.1fs",
		minimum,
		maximum
	)
end

local function setStatus(
	message: string,
	isError: boolean?
)
	interface.StatusLabel.Text =
		message

	interface.StatusLabel.TextColor3 =
		isError
		and Colors.Danger
		or Colors.TextMuted
end

local function setPurchaseButtonEnabled(
	enabled: boolean
)
	interface.PurchaseButton.Active =
		enabled

	interface.PurchaseButton.Selectable =
		enabled

	if enabled then
		interface.PurchaseButton.BackgroundColor3 =
			Colors.Primary

		interface.PurchaseButton.TextColor3 =
			Colors.TextDark

		interface.PurchaseButton.BackgroundTransparency =
			0
	else
		interface.PurchaseButton.BackgroundColor3 =
			Colors.SurfaceLight

		interface.PurchaseButton.TextColor3 =
			Colors.TextMuted

		interface.PurchaseButton.BackgroundTransparency =
			0.1
	end
end

local function updateInterface(
	state: MarketingState
)
	currentState = state

	local currentLevel =
		typeof(state.CurrentLevel) == "number"
		and math.max(
			0,
			math.floor(state.CurrentLevel)
		)
		or 0

	local maximumLevel =
		typeof(state.MaximumLevel) == "number"
		and math.max(
			0,
			math.floor(state.MaximumLevel)
		)
		or 0

	interface.LevelLabel.Text =
		`LEVEL {currentLevel} / {maximumLevel}`

	interface.NameLabel.Text =
		string.upper(
			state.DisplayName
			or "Marketing"
		)

	interface.DescriptionLabel.Text =
		state.Description
		or "Increase customer demand across your plot."

	local customerLimit =
		typeof(state.CustomerLimit) == "number"
		and math.max(
			1,
			math.floor(state.CustomerLimit)
		)
		or 0

	interface.CustomerLimitValue.Text =
		customerLimit > 0
		and tostring(customerLimit)
		or "--"

	interface.SpawnSpeedValue.Text =
		formatSpawnTime(
			state.MinimumSpawnInterval,
			state.MaximumSpawnInterval
		)

	local progress = 0

	if maximumLevel > 0 then
		progress =
			math.clamp(
				currentLevel
					/ maximumLevel,
				0,
				1
			)
	end

	TweenService:Create(
		interface.ProgressFill,
		TweenInfo.new(
			0.25,
			Enum.EasingStyle.Quad,
			Enum.EasingDirection.Out
		),
		{
			Size =
				UDim2.fromScale(
					progress,
					1
				),
		}
	):Play()

	interface.ProgressLabel.Text =
		`MARKETING PROGRESS  •  {currentLevel} / {maximumLevel}`

	if currentLevel >= maximumLevel then
		interface.PurchaseButton.Text =
			"MAXIMUM LEVEL"

		setPurchaseButtonEnabled(false)

		setStatus(
			"Your marketing is fully upgraded."
		)

		return
	end

	local nextCost =
		state.NextCost

	if typeof(nextCost) == "number" then
		interface.PurchaseButton.Text =
			`UPGRADE MARKETING  •  ${math.floor(nextCost)}`
	else
		interface.PurchaseButton.Text =
			"UPGRADE UNAVAILABLE"
	end

	setPurchaseButtonEnabled(
		typeof(nextCost) == "number"
			and not requestPending
	)

	if state.Success == false then
		setStatus(
			state.Message
				or "Marketing could not be loaded.",
			true
		)
	else
		setStatus(
			state.Message
				or "Upgrade available."
		)
	end
end

local function requestState()
	if requestPending then
		return
	end

	requestPending = true

	interface.PurchaseButton.Text =
		"LOADING..."

	setPurchaseButtonEnabled(false)

	local success, result =
		pcall(function()
			return getMarketingStateRemote
				:InvokeServer()
		end)

	requestPending = false

	if not success
		or type(result) ~= "table" then

		setStatus(
			"Marketing data could not be loaded.",
			true
		)

		interface.PurchaseButton.Text =
			"TRY AGAIN"

		setPurchaseButtonEnabled(true)

		return
	end

	updateInterface(
		result :: MarketingState
	)
end

local function openMenu()
	if menuOpen then
		return
	end

	menuOpen = true
	interface.Overlay.Visible = true

	interface.Overlay.BackgroundTransparency =
		1

	interface.WindowScale.Scale =
		0.92

	TweenService:Create(
		interface.Overlay,
		TweenInfo.new(
			0.18,
			Enum.EasingStyle.Quad,
			Enum.EasingDirection.Out
		),
		{
			BackgroundTransparency =
				0.28,
		}
	):Play()

	TweenService:Create(
		interface.WindowScale,
		TweenInfo.new(
			0.22,
			Enum.EasingStyle.Back,
			Enum.EasingDirection.Out
		),
		{
			Scale = 1,
		}
	):Play()

	requestState()
end

local function closeMenu()
	if not menuOpen then
		return
	end

	menuOpen = false

	local overlayTween =
		TweenService:Create(
			interface.Overlay,
			TweenInfo.new(
				0.15,
				Enum.EasingStyle.Quad,
				Enum.EasingDirection.In
			),
			{
				BackgroundTransparency =
					1,
			}
		)

	local windowTween =
		TweenService:Create(
			interface.WindowScale,
			TweenInfo.new(
				0.14,
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
		if not menuOpen then
			interface.Overlay.Visible =
				false
		end
	end)
end

interface = createInterface()

interface.OpenButton.Activated:Connect(
	openMenu
)

interface.CloseButton.Activated:Connect(
	closeMenu
)

interface.Overlay.InputBegan:Connect(
	function(input)
		if input.UserInputType
			== Enum.UserInputType.MouseButton1 then

			local position =
				input.Position

			local windowPosition =
				interface.Window.AbsolutePosition

			local windowSize =
				interface.Window.AbsoluteSize

			local outsideWindow =
				position.X < windowPosition.X
				or position.X
					> windowPosition.X
						+ windowSize.X
				or position.Y < windowPosition.Y
				or position.Y
					> windowPosition.Y
						+ windowSize.Y

			if outsideWindow then
				closeMenu()
			end
		end
	end
)

interface.PurchaseButton.Activated:Connect(
	function()
		if requestPending then
			return
		end

		local state =
			currentState

		if not state then
			requestState()
			return
		end

		local currentLevel =
			state.CurrentLevel or 0

		local maximumLevel =
			state.MaximumLevel or 0

		if currentLevel >= maximumLevel then
			return
		end

		if typeof(state.NextCost)
			~= "number" then

			return
		end

		requestPending = true

		interface.PurchaseButton.Text =
			"PURCHASING..."

		setPurchaseButtonEnabled(false)

		purchaseMarketingRemote:FireServer()
	end
)

marketingResultRemote.OnClientEvent:Connect(
	function(result)
		requestPending = false

		if type(result) ~= "table" then
			setStatus(
				"An invalid response was received.",
				true
			)

			requestState()
			return
		end

		updateInterface(
			result :: MarketingState
		)
	end
)

UserInputService.InputBegan:Connect(
	function(input, gameProcessed)
		if gameProcessed
			or not menuOpen then

			return
		end

		if input.KeyCode
			== Enum.KeyCode.Escape
			or input.KeyCode
				== Enum.KeyCode.ButtonB then

			closeMenu()
		end
	end
)

player:GetAttributeChangedSignal(
	"DataLoaded"
):Connect(function()
	if player:GetAttribute(
		"DataLoaded"
	) == true
		and menuOpen then

		requestState()
	end
end)