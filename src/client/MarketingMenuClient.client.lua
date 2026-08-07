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


local Colors =
	UITheme.Colors

local Fonts =
	UITheme.Fonts


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

	Header: Frame,
	Body: ScrollingFrame,
	Footer: Frame,

	TitleLabel: TextLabel,
	SubtitleLabel: TextLabel,

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

local menuOpen =
	false

local requestPending =
	false

local currentState:
	MarketingState? = nil


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
		Instance.new(
			"TextLabel"
		)

	label.Name =
		name

	label.Position =
		position

	label.Size =
		size

	label.BackgroundTransparency =
		1

	label.BorderSizePixel =
		0

	label.Text =
		text

	label.TextXAlignment =
		alignment
		or Enum.TextXAlignment.Left

	label.TextYAlignment =
		Enum.TextYAlignment.Center

	label.Parent =
		parent

	UITheme.StyleText(
		label,
		minimumTextSize,
		maximumTextSize,
		color or Colors.Text,
		font or Fonts.Semibold
	)

	return label
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

	card.Name =
		name

	card.LayoutOrder =
		layoutOrder

	card.Size =
		UDim2.new(
			0.5,
			-5,
			0,
			72
		)

	card.BackgroundColor3 =
		Colors.SurfaceRaised

	card.BorderSizePixel =
		0

	card.Parent =
		parent

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
			UDim2.new(
				0,
				10,
				0,
				8
			),
			UDim2.fromOffset(
				32,
				26
			),
			13,
			21,
			Fonts.Black,
			Colors.Primary,
			Enum.TextXAlignment.Center
		)

	icon.TextYAlignment =
		Enum.TextYAlignment.Center


	createTextLabel(
		card,
		"Title",
		title,
		UDim2.new(
			0,
			44,
			0,
			8
		),
		UDim2.new(
			1,
			-54,
			0,
			21
		),
		8,
		12,
		Fonts.Bold,
		Colors.TextMuted,
		Enum.TextXAlignment.Left
	)


	local valueLabel =
		createTextLabel(
			card,
			"Value",
			"--",
			UDim2.new(
				0,
				10,
				0,
				32
			),
			UDim2.new(
				1,
				-20,
				0,
				31
			),
			13,
			22,
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

	screenGui.Name =
		"MarketingMenu"

	screenGui.ResetOnSpawn =
		false

	-- Respect Roblox's top bar instead of drawing
	-- underneath the mobile controls.
	screenGui.IgnoreGuiInset =
		false

	screenGui.ScreenInsets =
		Enum.ScreenInsets.DeviceSafeInsets

	screenGui.DisplayOrder =
		25

	screenGui.ZIndexBehavior =
		Enum.ZIndexBehavior.Sibling

	screenGui.Parent =
		playerGui


	-- Permanent HUD button.
	local openButton =
		Instance.new("TextButton")

	openButton.Name =
		"OpenMarketingButton"

	openButton.AnchorPoint =
		Vector2.new(
			0,
			0.5
		)

	openButton.Position =
		UDim2.new(
			0,
			12,
			0.58,
			0
		)

	openButton.Size =
		UDim2.fromOffset(
			146,
			50
		)

	openButton.Text =
		"MARKETING"

	openButton.Parent =
		screenGui

	UITheme.StyleText(
		openButton,
		10,
		17,
		Colors.TextDark,
		Fonts.Black
	)

	UITheme.StyleButton(
		openButton,
		Colors.Primary,
		Colors.PrimaryDark,
		Colors.TextDark
	)


	local overlay =
		Instance.new("Frame")

	overlay.Name =
		"Overlay"

	overlay.Size =
		UDim2.fromScale(
			1,
			1
		)

	overlay.BackgroundColor3 =
		Colors.Shadow

	overlay.BackgroundTransparency =
		1

	overlay.BorderSizePixel =
		0

	overlay.Visible =
		false

	overlay.Active =
		true

	overlay.Parent =
		screenGui


	local window =
		Instance.new("Frame")

	window.Name =
		"MarketingWindow"

	window.AnchorPoint =
		Vector2.new(
			0.5,
			0.5
		)

	window.Position =
		UDim2.fromScale(
			0.5,
			0.5
		)

	window.Size =
		UDim2.fromOffset(
			680,
			580
		)

	window.BackgroundColor3 =
		Colors.Surface

	window.BorderSizePixel =
		0

	window.ClipsDescendants =
		true

	window.Parent =
		overlay

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


	local windowScale =
		Instance.new("UIScale")

	windowScale.Scale =
		0.92

	windowScale.Parent =
		window


	-- Header.
	local header =
		Instance.new("Frame")

	header.Name =
		"Header"

	header.Size =
		UDim2.new(
			1,
			0,
			0,
			88
		)

	header.BackgroundColor3 =
		Colors.SurfaceRaised

	header.BorderSizePixel =
		0

	header.ClipsDescendants =
		true

	header.Parent =
		window


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

	headerGradient.Rotation =
		90

	headerGradient.Parent =
		header


	local titleLabel =
		createTextLabel(
			header,
			"Title",
			"MARKETING",
			UDim2.fromOffset(
				24,
				12
			),
			UDim2.new(
				1,
				-100,
				0,
				31
			),
			16,
			28,
			Fonts.Black,
			Colors.Text,
			Enum.TextXAlignment.Left
		)

	titleLabel.ZIndex =
		2


	local subtitleLabel =
		createTextLabel(
			header,
			"Subtitle",
			"Bring more customers to your businesses",
			UDim2.fromOffset(
				24,
				45
			),
			UDim2.new(
				1,
				-100,
				0,
				22
			),
			8,
			13,
			Fonts.Medium,
			Colors.TextMuted,
			Enum.TextXAlignment.Left
		)

	subtitleLabel.ZIndex =
		2


	local closeButton =
		Instance.new("TextButton")

	closeButton.Name =
		"CloseButton"

	closeButton.AnchorPoint =
		Vector2.new(
			1,
			0.5
		)

	closeButton.Position =
		UDim2.new(
			1,
			-16,
			0.5,
			0
		)

	closeButton.Size =
		UDim2.fromOffset(
			48,
			48
		)

	closeButton.Text =
		"×"

	closeButton.ZIndex =
		3

	closeButton.Parent =
		header

	UITheme.StyleText(
		closeButton,
		16,
		25,
		Colors.Text,
		Fonts.Black
	)

	UITheme.StyleButton(
		closeButton,
		Colors.Danger,
		Colors.DangerDark,
		Colors.Text
	)


	-- Scrolling content.
	local body =
		Instance.new("ScrollingFrame")

	body.Name =
		"Body"

	body.Position =
		UDim2.fromOffset(
			0,
			88
		)

	body.Size =
		UDim2.new(
			1,
			0,
			1,
			-166
		)

	body.BackgroundTransparency =
		1

	body.BorderSizePixel =
		0

	body.CanvasSize =
		UDim2.fromOffset(
			0,
			0
		)

	body.AutomaticCanvasSize =
		Enum.AutomaticSize.Y

	body.ScrollBarThickness =
		3

	body.ScrollBarImageColor3 =
		Colors.Primary

	body.ScrollingDirection =
		Enum.ScrollingDirection.Y

	body.ElasticBehavior =
		Enum.ElasticBehavior.WhenScrollable

	body.Parent =
		window


	local bodyPadding =
		Instance.new("UIPadding")

	bodyPadding.PaddingLeft =
		UDim.new(
			0,
			18
		)

	bodyPadding.PaddingRight =
		UDim.new(
			0,
			24
		)

	bodyPadding.PaddingTop =
		UDim.new(
			0,
			14
		)

	bodyPadding.PaddingBottom =
		UDim.new(
			0,
			16
		)

	bodyPadding.Parent =
		body


	local bodyLayout =
		Instance.new("UIListLayout")

	bodyLayout.FillDirection =
		Enum.FillDirection.Vertical

	bodyLayout.HorizontalAlignment =
		Enum.HorizontalAlignment.Center

	bodyLayout.SortOrder =
		Enum.SortOrder.LayoutOrder

	bodyLayout.Padding =
		UDim.new(
			0,
			10
		)

	bodyLayout.Parent =
		body


	-- Hero card.
	local heroCard =
		Instance.new("Frame")

	heroCard.Name =
		"HeroCard"

	heroCard.LayoutOrder =
		1

	heroCard.Size =
		UDim2.new(
			1,
			0,
			0,
			116
		)

	heroCard.BackgroundColor3 =
		Colors.SurfaceRaised

	heroCard.BorderSizePixel =
		0

	heroCard.Parent =
		body

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

	accent.Name =
		"Accent"

	accent.Size =
		UDim2.new(
			0,
			6,
			1,
			0
		)

	accent.BackgroundColor3 =
		Colors.Primary

	accent.BorderSizePixel =
		0

	accent.Parent =
		heroCard

	UITheme.AddCorner(
		accent,
		0.4
	)


	local levelLabel =
		createTextLabel(
			heroCard,
			"Level",
			"LEVEL 0",
			UDim2.fromOffset(
				24,
				10
			),
			UDim2.new(
				1,
				-46,
				0,
				20
			),
			9,
			14,
			Fonts.Black,
			Colors.Primary,
			Enum.TextXAlignment.Left
		)


	local nameLabel =
		createTextLabel(
			heroCard,
			"MarketingName",
			"WORD OF MOUTH",
			UDim2.fromOffset(
				24,
				31
			),
			UDim2.new(
				1,
				-46,
				0,
				31
			),
			13,
			22,
			Fonts.Black,
			Colors.Text,
			Enum.TextXAlignment.Left
		)


	local descriptionLabel =
		createTextLabel(
			heroCard,
			"Description",
			"Customers discover your businesses naturally.",
			UDim2.fromOffset(
				24,
				65
			),
			UDim2.new(
				1,
				-46,
				0,
				42
			),
			8,
			13,
			Fonts.Medium,
			Colors.TextMuted,
			Enum.TextXAlignment.Left
		)

	descriptionLabel.TextWrapped =
		true

	descriptionLabel.TextYAlignment =
		Enum.TextYAlignment.Top


	-- Statistics row.
	local statRow =
		Instance.new("Frame")

	statRow.Name =
		"StatRow"

	statRow.LayoutOrder =
		2

	statRow.Size =
		UDim2.new(
			1,
			0,
			0,
			72
		)

	statRow.BackgroundTransparency =
		1

	statRow.Parent =
		body


	local statLayout =
		Instance.new("UIListLayout")

	statLayout.FillDirection =
		Enum.FillDirection.Horizontal

	statLayout.HorizontalAlignment =
		Enum.HorizontalAlignment.Center

	statLayout.VerticalAlignment =
		Enum.VerticalAlignment.Center

	statLayout.Padding =
		UDim.new(
			0,
			10
		)

	statLayout.Parent =
		statRow


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


	-- Progress card.
	local progressCard =
		Instance.new("Frame")

	progressCard.Name =
		"ProgressCard"

	progressCard.LayoutOrder =
		3

	progressCard.Size =
		UDim2.new(
			1,
			0,
			0,
			68
		)

	progressCard.BackgroundColor3 =
		Colors.SurfaceRaised

	progressCard.BorderSizePixel =
		0

	progressCard.Parent =
		body

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
			UDim2.fromOffset(
				16,
				7
			),
			UDim2.new(
				1,
				-32,
				0,
				22
			),
			8,
			12,
			Fonts.Bold,
			Colors.TextMuted,
			Enum.TextXAlignment.Left
		)


	local progressTrack =
		Instance.new("Frame")

	progressTrack.Name =
		"ProgressTrack"

	progressTrack.Position =
		UDim2.new(
			0,
			16,
			0,
			40
		)

	progressTrack.Size =
		UDim2.new(
			1,
			-32,
			0,
			10
		)

	progressTrack.BackgroundColor3 =
		Colors.ProgressTrack

	progressTrack.BorderSizePixel =
		0

	progressTrack.ClipsDescendants =
		true

	progressTrack.Parent =
		progressCard

	UITheme.AddCorner(
		progressTrack,
		0.5
	)


	local progressFill =
		Instance.new("Frame")

	progressFill.Name =
		"ProgressFill"

	progressFill.Size =
		UDim2.fromScale(
			0,
			1
		)

	progressFill.BackgroundColor3 =
		Colors.Primary

	progressFill.BorderSizePixel =
		0

	progressFill.Parent =
		progressTrack

	UITheme.AddCorner(
		progressFill,
		0.5
	)


	-- Fixed bottom footer.
	local footer =
		Instance.new("Frame")

	footer.Name =
		"Footer"

	footer.AnchorPoint =
		Vector2.new(
			0,
			1
		)

	footer.Position =
		UDim2.fromScale(
			0,
			1
		)

	footer.Size =
		UDim2.new(
			1,
			0,
			0,
			78
		)

	footer.BackgroundColor3 =
		Colors.Surface

	footer.BorderSizePixel =
		0

	footer.Parent =
		window


	local footerLine =
		Instance.new("Frame")

	footerLine.Name =
		"Divider"

	footerLine.Size =
		UDim2.new(
			1,
			0,
			0,
			1
		)

	footerLine.BackgroundColor3 =
		Colors.Stroke

	footerLine.BackgroundTransparency =
		0.55

	footerLine.BorderSizePixel =
		0

	footerLine.Parent =
		footer


	local statusLabel =
		createTextLabel(
			footer,
			"StatusLabel",
			"",
			UDim2.new(
				0,
				18,
				0,
				4
			),
			UDim2.new(
				1,
				-36,
				0,
				20
			),
			8,
			12,
			Fonts.Semibold,
			Colors.TextMuted,
			Enum.TextXAlignment.Center
		)


	local purchaseButton =
		Instance.new("TextButton")

	purchaseButton.Name =
		"PurchaseButton"

	purchaseButton.Position =
		UDim2.new(
			0,
			18,
			0,
			26
		)

	purchaseButton.Size =
		UDim2.new(
			1,
			-36,
			0,
			46
		)

	purchaseButton.Text =
		"LOADING..."

	purchaseButton.Parent =
		footer

	UITheme.StyleText(
		purchaseButton,
		11,
		18,
		Colors.TextDark,
		Fonts.Black
	)

	UITheme.StyleButton(
		purchaseButton,
		Colors.Primary,
		Colors.PrimaryDark,
		Colors.TextDark
	)


	return {
		ScreenGui = screenGui,

		OpenButton = openButton,

		Overlay = overlay,

		Window = window,
		WindowScale = windowScale,

		Header = header,
		Body = body,
		Footer = footer,

		TitleLabel = titleLabel,
		SubtitleLabel = subtitleLabel,

		CloseButton = closeButton,

		LevelLabel = levelLabel,
		NameLabel = nameLabel,
		DescriptionLabel =
			descriptionLabel,

		CustomerLimitValue =
			customerLimitValue,

		SpawnSpeedValue =
			spawnSpeedValue,

		ProgressFill =
			progressFill,

		ProgressLabel =
			progressLabel,

		StatusLabel =
			statusLabel,

		PurchaseButton =
			purchaseButton,
	}
end


local function updateResponsiveLayout()
	local camera =
		Workspace.CurrentCamera

	if not camera then
		return
	end


	local viewport =
		camera.ViewportSize

	local touchDevice =
		UserInputService.TouchEnabled

	local narrow =
		viewport.X < 520

	local shortLandscape =
		touchDevice
		and viewport.X > viewport.Y
		and viewport.Y < 560


	local widthMargin =
		shortLandscape
		and 32
		or narrow
			and 26
			or 70

	local verticalReserve =
		shortLandscape
		and 82
		or touchDevice
			and 64
			or 70


	local windowWidth =
		math.min(
			shortLandscape
				and 700
				or 720,
			math.max(
				290,
				viewport.X
					- widthMargin
			)
		)

	local windowHeight =
		math.min(
			touchDevice
				and 650
				or 680,
			math.max(
				260,
				viewport.Y
					- verticalReserve
			)
		)


	interface.Window.Size =
		UDim2.fromOffset(
			windowWidth,
			windowHeight
		)


	local headerHeight: number
	local footerHeight: number


	if shortLandscape then
		headerHeight = 54
		footerHeight = 66
	elseif narrow then
		headerHeight = 86
		footerHeight = 82
	else
		headerHeight = 88
		footerHeight = 78
	end


	interface.Header.Size =
		UDim2.new(
			1,
			0,
			0,
			headerHeight
		)

	interface.Footer.Size =
		UDim2.new(
			1,
			0,
			0,
			footerHeight
		)

	interface.Body.Position =
		UDim2.fromOffset(
			0,
			headerHeight
		)

	interface.Body.Size =
		UDim2.new(
			1,
			0,
			1,
			-(
				headerHeight
				+ footerHeight
			)
		)


	if shortLandscape then
		interface.TitleLabel.Position =
			UDim2.fromOffset(
				18,
				12
			)

		interface.TitleLabel.Size =
			UDim2.new(
				1,
				-84,
				0,
				28
			)

		interface.SubtitleLabel.Visible =
			false

		interface.CloseButton.Position =
			UDim2.new(
				1,
				-10,
				0.5,
				0
			)

		interface.CloseButton.Size =
			UDim2.fromOffset(
				40,
				40
			)

	elseif narrow then
		interface.TitleLabel.Position =
			UDim2.fromOffset(
				18,
				10
			)

		interface.TitleLabel.Size =
			UDim2.new(
				1,
				-78,
				0,
				27
			)

		interface.SubtitleLabel.Visible =
			true

		interface.SubtitleLabel.Position =
			UDim2.fromOffset(
				18,
				39
			)

		interface.SubtitleLabel.Size =
			UDim2.new(
				1,
				-78,
				0,
				26
			)

		interface.CloseButton.Position =
			UDim2.new(
				1,
				-12,
				0,
				12
			)

		interface.CloseButton.Size =
			UDim2.fromOffset(
				42,
				42
			)

	else
		interface.TitleLabel.Position =
			UDim2.fromOffset(
				24,
				12
			)

		interface.TitleLabel.Size =
			UDim2.new(
				1,
				-100,
				0,
				31
			)

		interface.SubtitleLabel.Visible =
			true

		interface.SubtitleLabel.Position =
			UDim2.fromOffset(
				24,
				45
			)

		interface.SubtitleLabel.Size =
			UDim2.new(
				1,
				-100,
				0,
				22
			)

		interface.CloseButton.Position =
			UDim2.new(
				1,
				-16,
				0.5,
				0
			)

		interface.CloseButton.Size =
			UDim2.fromOffset(
				48,
				48
			)
	end


	if shortLandscape then
		interface.StatusLabel.Position =
			UDim2.new(
				0,
				14,
				0,
				2
			)

		interface.StatusLabel.Size =
			UDim2.new(
				1,
				-28,
				0,
				17
			)

		interface.PurchaseButton.Position =
			UDim2.new(
				0,
				14,
				0,
				20
			)

		interface.PurchaseButton.Size =
			UDim2.new(
				1,
				-28,
				0,
				40
			)
	else
		interface.StatusLabel.Position =
			UDim2.new(
				0,
				18,
				0,
				4
			)

		interface.StatusLabel.Size =
			UDim2.new(
				1,
				-36,
				0,
				20
			)

		interface.PurchaseButton.Position =
			UDim2.new(
				0,
				18,
				0,
				26
			)

		interface.PurchaseButton.Size =
			UDim2.new(
				1,
				-36,
				0,
				46
			)
	end


	if touchDevice then
		interface.OpenButton.Size =
			UDim2.fromOffset(
				126,
				46
			)
	else
		interface.OpenButton.Size =
			UDim2.fromOffset(
				146,
				50
			)
	end
end


local function formatSpawnTime(
	minimum: number?,
	maximum: number?
): string
	if typeof(minimum)
			~= "number"
		or typeof(maximum)
			~= "number" then

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
		interface.PurchaseButton
			.BackgroundColor3 =
			Colors.Primary

		interface.PurchaseButton
			.TextColor3 =
			Colors.TextDark

		interface.PurchaseButton
			.BackgroundTransparency =
			0
	else
		interface.PurchaseButton
			.BackgroundColor3 =
			Colors.SurfaceLight

		interface.PurchaseButton
			.TextColor3 =
			Colors.TextMuted

		interface.PurchaseButton
			.BackgroundTransparency =
			0.1
	end
end


local function updateInterface(
	state: MarketingState
)
	currentState =
		state


	local currentLevel =
		typeof(state.CurrentLevel)
				== "number"
			and math.max(
				0,
				math.floor(
					state.CurrentLevel
				)
			)
			or 0


	local maximumLevel =
		typeof(state.MaximumLevel)
				== "number"
			and math.max(
				0,
				math.floor(
					state.MaximumLevel
				)
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
		typeof(state.CustomerLimit)
				== "number"
			and math.max(
				1,
				math.floor(
					state.CustomerLimit
				)
			)
			or 0


	interface.CustomerLimitValue.Text =
		customerLimit > 0
		and tostring(
			customerLimit
		)
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


	if currentLevel
			>= maximumLevel then

		interface.PurchaseButton.Text =
			"MAXIMUM LEVEL"

		setPurchaseButtonEnabled(
			false
		)

		setStatus(
			"Your marketing is fully upgraded."
		)

		return
	end


	local nextCost =
		state.NextCost


	if typeof(nextCost)
			== "number" then

		interface.PurchaseButton.Text =
			`UPGRADE MARKETING  •  $${math.floor(nextCost)}`

	else
		interface.PurchaseButton.Text =
			"UPGRADE UNAVAILABLE"
	end


	setPurchaseButtonEnabled(
		typeof(nextCost)
				== "number"
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


	requestPending =
		true

	interface.PurchaseButton.Text =
		"LOADING..."

	setPurchaseButtonEnabled(
		false
	)


	local success, result =
		pcall(function()
			return getMarketingStateRemote
				:InvokeServer()
		end)


	requestPending =
		false


	if not success
		or type(result)
			~= "table" then

		setStatus(
			"Marketing data could not be loaded.",
			true
		)

		interface.PurchaseButton.Text =
			"TRY AGAIN"

		setPurchaseButtonEnabled(
			true
		)

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


	menuOpen =
		true

	updateResponsiveLayout()

	interface.Overlay.Visible =
		true

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


	menuOpen =
		false


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


	windowTween.Completed:Once(
		function()
			if not menuOpen then
				interface.Overlay.Visible =
					false
			end
		end
	)
end


interface =
	createInterface()

updateResponsiveLayout()


local function connectCamera(
	camera: Camera
)
	camera:GetPropertyChangedSignal(
		"ViewportSize"
	):Connect(
		updateResponsiveLayout
	)
end


if Workspace.CurrentCamera then
	connectCamera(
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

	updateResponsiveLayout()
	connectCamera(camera)
end)


interface.OpenButton.Activated:Connect(
	openMenu
)


interface.CloseButton.Activated:Connect(
	closeMenu
)


interface.Overlay.InputBegan:Connect(
	function(input)
		if input.UserInputType
				~= Enum.UserInputType.MouseButton1
			and input.UserInputType
				~= Enum.UserInputType.Touch then

			return
		end


		local position =
			input.Position

		local windowPosition =
			interface.Window.AbsolutePosition

		local windowSize =
			interface.Window.AbsoluteSize


		local outsideWindow =
			position.X
				< windowPosition.X
			or position.X
				> windowPosition.X
					+ windowSize.X
			or position.Y
				< windowPosition.Y
			or position.Y
				> windowPosition.Y
					+ windowSize.Y


		if outsideWindow then
			closeMenu()
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


		if currentLevel
				>= maximumLevel then

			return
		end


		if typeof(state.NextCost)
				~= "number" then

			return
		end


		requestPending =
			true

		interface.PurchaseButton.Text =
			"PURCHASING..."

		setPurchaseButtonEnabled(
			false
		)

		purchaseMarketingRemote
			:FireServer()
	end
)


marketingResultRemote.OnClientEvent:Connect(
	function(result)
		requestPending =
			false


		if type(result)
				~= "table" then

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
	function(
		input,
		gameProcessed
	)
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