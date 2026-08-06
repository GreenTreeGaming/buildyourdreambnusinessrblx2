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

local purchaseUpgradeRemote =
	remotes:WaitForChild("PurchaseUpgrade")

local upgradeResultRemote =
	remotes:WaitForChild("UpgradeResult")

local getUpgradeStateRemote =
	remotes:WaitForChild("GetUpgradeState")

local requestAppearanceUpgradeRemote =
	remotes:WaitForChild("RequestBusinessUpgrade")

local appearanceUpgradeResultRemote =
	remotes:WaitForChild("BusinessUpgradeResult")

local FormatNumber = require(
	ReplicatedStorage
		:WaitForChild("Shared")
		:WaitForChild("FormatNumber")
)

local BusinessConfig = require(
	ReplicatedStorage
		:WaitForChild("Shared")
		:WaitForChild("BusinessConfig")
)

local UITheme = require(
	ReplicatedStorage
		:WaitForChild("Shared")
		:WaitForChild("UITheme")
)

local Colors = UITheme.Colors
local Fonts = UITheme.Fonts

local BUSINESS_NAME = "LemonadeStand"

local GAMEPLAY_UPGRADE_ORDER = {
	"SaleValue",
	"ServingSpeed",
	"QueueCapacity",
}

type GameplayUpgradeState = {
	Success: boolean,
	Message: string,

	BusinessId: string?,
	BusinessName: string?,
	UpgradeName: string?,
	DisplayName: string?,

	CurrentLevel: number?,
	MaximumLevel: number?,
	NextCost: number?,

		CurrentCooldown: number?,
	CurrentSaleValue: number?,
	CurrentQueueCapacity: number?,
}

type UpgradeCard = {
	Root: Frame,
	LevelLabel: TextLabel,
	ValueCaption: TextLabel,
	ValueLabel: TextLabel,
	ProgressFill: Frame,
	PurchaseButton: TextButton,
}

type Interface = {
	ScreenGui: ScreenGui,

	Overlay: Frame,
	Panel: Frame,
	PanelScale: UIScale,

	CloseButton: TextButton,
	CashLabel: TextLabel,
	StatusLabel: TextLabel,
	TitleLabel: TextLabel,
	SubtitleLabel: TextLabel,
}

local menuOpen = false

local selectedBusinessId: string? = nil
local selectedStand: Model? = nil

local requestPending: string? = nil
local statusVersion = 0

local cards: {[string]: UpgradeCard} = {}
local statisticLabels: {[string]: TextLabel} = {}

local appearanceCard: UpgradeCard? = nil

local function getOpenUpgradeMenuEvent(): BindableEvent
	local existing =
		playerGui:FindFirstChild("OpenUpgradeMenu")

	if existing then
		if existing:IsA("BindableEvent") then
			return existing
		end

		existing:Destroy()
	end

	local event = Instance.new("BindableEvent")
	event.Name = "OpenUpgradeMenu"
	event.Parent = playerGui

	return event
end

local openUpgradeMenuEvent =
	getOpenUpgradeMenuEvent()

local function createTextLabel(
	parent: Instance,
	name: string,
	text: string,
	position: UDim2,
	size: UDim2,
	minimumTextSize: number,
	maximumTextSize: number,
	font: Enum.Font?,
	color: Color3?
): TextLabel
	local label = Instance.new("TextLabel")

	label.Name = name
	label.Position = position
	label.Size = size
	label.BackgroundTransparency = 1
	label.Text = text

	label.TextXAlignment =
		Enum.TextXAlignment.Left

	label.TextYAlignment =
		Enum.TextYAlignment.Center

	label.Parent = parent

	UITheme.StyleText(
		label,
		minimumTextSize,
		maximumTextSize,
		color,
		font
	)

	return label
end

local function getOwnedPlot(): Model?
	local plotName =
		player:GetAttribute("PlotName")

	if typeof(plotName) == "string" then
		local namedPlot =
			plotsFolder:FindFirstChild(plotName)

		if namedPlot
			and namedPlot:IsA("Model")
			and namedPlot:GetAttribute("OwnerUserId")
				== player.UserId then

			return namedPlot
		end
	end

	for _, plot in plotsFolder:GetChildren() do
		if not plot:IsA("Model") then
			continue
		end

		if plot:GetAttribute("OwnerUserId")
			== player.UserId then

			return plot
		end
	end

	return nil
end

local function isLemonadeStand(
	instance: Instance
): boolean
	if not instance:IsA("Model") then
		return false
	end

	if instance:GetAttribute("BusinessType")
		== BUSINESS_NAME then

		return true
	end

	return instance.Name == BUSINESS_NAME
		or string.match(
			instance.Name,
			"^LemonadeStand_"
		) ~= nil
end

local function getStandBusinessId(
	stand: Model
): string
	local businessId =
		stand:GetAttribute("BusinessId")

	if typeof(businessId) == "string"
		and businessId ~= "" then

		return businessId
	end

	return stand.Name
end

local function findOwnedStandByBusinessId(
	businessId: string
): Model?
	if businessId == "" then
		return nil
	end

	local plot = getOwnedPlot()

	if not plot then
		return nil
	end

	local placedBusinesses =
		plot:FindFirstChild("PlacedBusinesses")

	if not placedBusinesses then
		return nil
	end

	for _, child in placedBusinesses:GetChildren() do
		if not child:IsA("Model")
			or not isLemonadeStand(child) then

			continue
		end

		if child:GetAttribute("OwnerUserId")
			~= player.UserId then

			continue
		end

		local childBusinessId =
			getStandBusinessId(child)

		if childBusinessId == businessId
			or child.Name == businessId then

			return child
		end
	end

	return nil
end

local function selectStandByBusinessId(
	businessId: string
): boolean
	local stand =
		findOwnedStandByBusinessId(businessId)

	if not stand then
		selectedStand = nil
		selectedBusinessId = nil

		return false
	end

	selectedStand = stand
	selectedBusinessId =
		getStandBusinessId(stand)

	return true
end

local function getStandNumber(
	businessId: string
): string
	return string.match(
		businessId,
		"_(%d+)$"
	) or businessId
end

local function getNumericAttribute(
	instance: Instance,
	attributeName: string,
	defaultValue: number?
): number
	local value =
		instance:GetAttribute(attributeName)

	if typeof(value) ~= "number" then
		return defaultValue or 0
	end

	return math.max(0, value)
end

local function getStandAppearanceLevel(
	stand: Model
): number
	local level =
		getNumericAttribute(
			stand,
			"Level",
			1
		)

	return math.max(
		1,
		math.floor(level)
	)
end

local function getAppearanceConfig(
	level: number
): {[string]: any}?
	local lemonadeConfig =
		BusinessConfig.LemonadeStand

	if typeof(lemonadeConfig) ~= "table" then
		return nil
	end

	local standLevels =
		lemonadeConfig.StandLevels

	if typeof(standLevels) ~= "table" then
		return nil
	end

	local config =
		standLevels[level]

	if typeof(config) ~= "table" then
		return nil
	end

	return config
end

local function getMaximumAppearanceLevel(): number
	local lemonadeConfig =
		BusinessConfig.LemonadeStand

	if typeof(lemonadeConfig) ~= "table"
		or typeof(lemonadeConfig.StandLevels)
			~= "table" then

		return 1
	end

	local maximumLevel = 1

	for level, config in
		lemonadeConfig.StandLevels do

		if typeof(level) == "number"
			and typeof(config) == "table"
			and level > maximumLevel then

			maximumLevel = level
		end
	end

	return maximumLevel
end

local function createStatisticBox(
	parent: Instance,
	name: string,
	captionText: string
): TextLabel
	local box =
		Instance.new("Frame")

	box.Name = name .. "Box"

	box.Size =
		UDim2.fromOffset(
			154,
			72
		)

	box.BackgroundColor3 =
		Colors.SurfaceRaised

	box.BorderSizePixel = 0
	box.Parent = parent

	UITheme.AddCorner(
		box,
		0.12
	)

	UITheme.AddStroke(
		box,
		Colors.Stroke,
		1,
		0.5
	)

	local caption =
		createTextLabel(
			box,
			"Caption",
			captionText,
			UDim2.fromScale(
				0.08,
				0.1
			),
			UDim2.fromScale(
				0.84,
				0.28
			),
			8,
			11,
			Fonts.Bold,
			Colors.TextMuted
		)

	caption.TextXAlignment =
		Enum.TextXAlignment.Center

	local value =
		createTextLabel(
			box,
			"Value",
			"--",
			UDim2.fromScale(
				0.08,
				0.4
			),
			UDim2.fromScale(
				0.84,
				0.42
			),
			12,
			19,
			Fonts.Black,
			Colors.Text
		)

	value.TextXAlignment =
		Enum.TextXAlignment.Center

	return value
end

local function createUpgradeCard(
	parent: Instance,
	name: string,
	titleText: string,
	descriptionText: string,
	valueCaptionText: string,
	buttonColor: Color3,
	buttonDarkColor: Color3
): UpgradeCard
	local card =
		Instance.new("Frame")

	card.Name = name .. "Card"

	card.Size =
		UDim2.new(
			1,
			-8,
			0,
			188
		)

	card.BackgroundColor3 =
		Colors.SurfaceRaised

	card.BorderSizePixel = 0
	card.Parent = parent

	UITheme.AddCorner(
		card,
		0.045
	)

	UITheme.AddStroke(
		card,
		Colors.Stroke,
		1.5,
		0.35
	)

	local accent =
		Instance.new("Frame")

	accent.Name = "Accent"

	accent.Size =
		UDim2.new(
			0,
			5,
			1,
			0
		)

	accent.BackgroundColor3 =
		buttonColor

	accent.BorderSizePixel = 0
	accent.Parent = card

	UITheme.AddCorner(
		accent,
		0.5
	)

	local title =
		createTextLabel(
			card,
			"Title",
			titleText,
			UDim2.fromScale(
				0.045,
				0.055
			),
			UDim2.fromScale(
				0.9,
				0.12
			),
			12,
			20,
			Fonts.Black,
			Colors.Text
		)

	local description =
		createTextLabel(
			card,
			"Description",
			descriptionText,
			UDim2.fromScale(
				0.045,
				0.17
			),
			UDim2.fromScale(
				0.9,
				0.12
			),
			8,
			13,
			Fonts.Medium,
			Colors.TextMuted
		)

	description.TextWrapped = true

	local statRow =
		Instance.new("Frame")

	statRow.Name = "Stats"

	statRow.Position =
		UDim2.fromScale(
			0.045,
			0.33
		)

	statRow.Size =
		UDim2.fromScale(
			0.91,
			0.25
		)

	statRow.BackgroundTransparency = 1
	statRow.Parent = card

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

	statLayout.Parent = statRow

	local function createStatBox(
		statName: string,
		captionText: string
	): (Frame, TextLabel)
		local box =
			Instance.new("Frame")

		box.Name = statName

		box.Size =
			UDim2.new(
				0.5,
				-5,
				1,
				0
			)

		box.BackgroundColor3 =
			Colors.Background

		box.BackgroundTransparency =
			0.3

		box.BorderSizePixel = 0
		box.Parent = statRow

		UITheme.AddCorner(
			box,
			0.12
		)

		UITheme.AddStroke(
			box,
			Colors.Stroke,
			1,
			0.55
		)

		local caption =
			createTextLabel(
				box,
				"Caption",
				captionText,
				UDim2.fromScale(
					0.06,
					0.08
				),
				UDim2.fromScale(
					0.88,
					0.3
				),
				8,
				11,
				Fonts.Bold,
				Colors.TextMuted
			)

		caption.TextXAlignment =
			Enum.TextXAlignment.Center

		local value =
			createTextLabel(
				box,
				"Value",
				"--",
				UDim2.fromScale(
					0.06,
					0.4
				),
				UDim2.fromScale(
					0.88,
					0.45
				),
				12,
				19,
				Fonts.Black,
				Colors.Text
			)

		value.TextXAlignment =
			Enum.TextXAlignment.Center

		return box, value
	end

	local _, levelLabel =
		createStatBox(
			"LevelStat",
			"CURRENT LEVEL"
		)

	local valueBox, valueLabel =
		createStatBox(
			"ValueStat",
			valueCaptionText
		)

	local valueCaption =
		valueBox:FindFirstChild(
			"Caption"
		) :: TextLabel

	valueLabel.TextColor3 =
		buttonColor

	local progressTrack =
		Instance.new("Frame")

	progressTrack.Name =
		"ProgressTrack"

	progressTrack.Position =
		UDim2.fromScale(
			0.045,
			0.635
		)

	progressTrack.Size =
		UDim2.fromScale(
			0.91,
			0.045
		)

	progressTrack.BackgroundColor3 =
		Colors.ProgressTrack

	progressTrack.BorderSizePixel = 0
	progressTrack.ClipsDescendants = true
	progressTrack.Parent = card

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
		buttonColor

	progressFill.BorderSizePixel = 0
	progressFill.Parent = progressTrack

	UITheme.AddCorner(
		progressFill,
		0.5
	)

	local purchaseButton =
		Instance.new("TextButton")

	purchaseButton.Name =
		"PurchaseButton"

	purchaseButton.Position =
		UDim2.fromScale(
			0.045,
			0.745
		)

	purchaseButton.Size =
		UDim2.fromScale(
			0.91,
			0.16
		)

	purchaseButton.Text =
		"LOADING..."

	purchaseButton.Parent = card

	UITheme.StyleText(
		purchaseButton,
		10,
		16,
		Colors.Text,
		Fonts.Black
	)

	UITheme.StyleButton(
		purchaseButton,
		buttonColor,
		buttonDarkColor,
		Colors.Text
	)

	return {
		Root = card,
		LevelLabel = levelLabel,
		ValueCaption = valueCaption,
		ValueLabel = valueLabel,
		ProgressFill = progressFill,
		PurchaseButton = purchaseButton,
	}
end

local function createInterface(): Interface
	local existing =
		playerGui:FindFirstChild(
			"UpgradeMenu"
		)

	if existing then
		existing:Destroy()
	end

	local screenGui =
		Instance.new("ScreenGui")

	screenGui.Name = "UpgradeMenu"
	screenGui.ResetOnSpawn = false
	screenGui.IgnoreGuiInset = true

	screenGui.ScreenInsets =
		Enum.ScreenInsets.DeviceSafeInsets

	screenGui.DisplayOrder = 30

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
	overlay.Parent = screenGui

	-- No separate fake shadow frame.
	local panel =
		Instance.new("Frame")

	panel.Name = "Panel"

	panel.AnchorPoint =
		Vector2.new(0.5, 0.5)

	panel.Position =
		UDim2.fromScale(0.5, 0.5)

	panel.Size =
		UDim2.fromScale(
			0.88,
			0.88
		)

	panel.BackgroundColor3 =
		Colors.Surface

	panel.BorderSizePixel = 0
	panel.ClipsDescendants = true
	panel.Parent = overlay

	UITheme.AddCorner(
		panel,
		0.025
	)

	UITheme.AddStroke(
		panel,
		Colors.Stroke,
		2,
		0.1
	)

	local panelConstraint =
		Instance.new("UISizeConstraint")

	panelConstraint.MinSize =
		Vector2.new(
			300,
			430
		)

	panelConstraint.MaxSize =
		Vector2.new(
			1060,
			720
		)

	panelConstraint.Parent = panel

	local panelScale =
		Instance.new("UIScale")

	panelScale.Scale = 0.92
	panelScale.Parent = panel

	-- Premium header.
	local header =
		Instance.new("Frame")

	header.Name = "Header"

	header.Size =
		UDim2.fromScale(
			1,
			0.145
		)

	header.BackgroundColor3 =
		Colors.Background

	header.BorderSizePixel = 0
	header.ClipsDescendants = true
	header.Parent = panel

	local headerCorner =
		Instance.new("UICorner")

	headerCorner.CornerRadius =
		UDim.new(
			0,
			18
		)

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
	headerBottomCover.ZIndex = 1
	headerBottomCover.Parent = header

	local title =
		createTextLabel(
			header,
			"Title",
			"LEMONADE STAND",
			UDim2.fromScale(
				0.045,
				0.12
			),
			UDim2.fromScale(
				0.58,
				0.32
			),
			15,
			25,
			Fonts.Black,
			Colors.Text
		)

	title.ZIndex = 2

	local subtitle =
		createTextLabel(
			header,
			"Subtitle",
			"Appearance and upgrades apply only to this stand.",
			UDim2.fromScale(
				0.045,
				0.49
			),
			UDim2.fromScale(
				0.62,
				0.24
			),
			8,
			14,
			Fonts.Medium,
			Colors.TextMuted
		)

	subtitle.ZIndex = 2

	local cashContainer =
	Instance.new("Frame")

cashContainer.Name =
	"CashContainer"

cashContainer.AnchorPoint =
	Vector2.new(1, 0.5)

cashContainer.Position =
	UDim2.new(
		1,
		-92,
		0.5,
		0
	)

cashContainer.Size =
	UDim2.fromOffset(
		190,
		48
	)

cashContainer.BackgroundColor3 =
	Colors.SurfaceRaised

cashContainer.BorderSizePixel = 0
cashContainer.ZIndex = 2
cashContainer.Parent = header

UITheme.AddCorner(
	cashContainer,
	0.22
)

UITheme.AddStroke(
	cashContainer,
	Colors.Primary,
	1.5,
	0.28
)

local cashIcon =
	Instance.new("Frame")

cashIcon.Name =
	"CashIcon"

cashIcon.AnchorPoint =
	Vector2.new(0, 0.5)

cashIcon.Position =
	UDim2.new(
		0,
		10,
		0.5,
		0
	)

cashIcon.Size =
	UDim2.fromOffset(
		30,
		30
	)

cashIcon.BackgroundColor3 =
	Colors.Primary

cashIcon.BorderSizePixel = 0
cashIcon.ZIndex = 3
cashIcon.Parent = cashContainer

UITheme.AddCorner(
	cashIcon,
	0.5
)

local dollarLabel =
	createTextLabel(
	cashIcon,
	"Dollar",
	"$",
	UDim2.fromScale(0, 0),
	UDim2.fromScale(1, 1),
	13,
	20,
	Fonts.Black,
	Colors.TextDark
)

dollarLabel.TextXAlignment =
	Enum.TextXAlignment.Center

dollarLabel.ZIndex = 4

local cashCaption =
	createTextLabel(
	cashContainer,
	"Caption",
	"CASH",
	UDim2.fromScale(
		0.25,
		0.12
	),
	UDim2.fromScale(
		0.68,
		0.25
	),
	8,
	11,
	Fonts.Bold,
	Colors.TextMuted
)

cashCaption.ZIndex = 3

local cashLabel =
	createTextLabel(
	cashContainer,
	"CashLabel",
	"$0",
	UDim2.fromScale(
		0.25,
		0.36
	),
	UDim2.fromScale(
		0.68,
		0.45
	),
	12,
	20,
	Fonts.Black,
	Colors.Primary
)

cashLabel.ZIndex = 3

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
			54,
			54
		)

	closeButton.Text = "×"
	closeButton.ZIndex = 3
	closeButton.Parent = header

	UITheme.StyleText(
		closeButton,
		17,
		27,
		Colors.Text,
		Fonts.Black
	)

	UITheme.StyleButton(
		closeButton,
		Colors.Danger,
		Colors.DangerDark,
		Colors.Text
	)

	local closeConstraint =
		Instance.new("UISizeConstraint")

	closeConstraint.MinSize =
		Vector2.new(46, 46)

	closeConstraint.MaxSize =
		Vector2.new(56, 56)

	closeConstraint.Parent =
		closeButton

	local closeAspect =
		Instance.new(
			"UIAspectRatioConstraint"
		)

	closeAspect.AspectRatio = 1
	closeAspect.Parent = closeButton

	-- Body.
	local content =
		Instance.new("Frame")

	content.Name = "Content"

	content.Position =
		UDim2.fromScale(
			0,
			0.145
		)

	content.Size =
		UDim2.fromScale(
			1,
			0.855
		)

	content.BackgroundTransparency = 1
	content.Parent = panel

	local contentPadding =
		Instance.new("UIPadding")

	contentPadding.PaddingLeft =
		UDim.new(0.035, 0)

	contentPadding.PaddingRight =
		UDim.new(0.035, 0)

	contentPadding.PaddingTop =
	UDim.new(0.035, 0)

	contentPadding.PaddingBottom =
		UDim.new(0.025, 0)

	contentPadding.Parent = content

	-- Horizontally scrollable stats on narrow displays.
	local statisticsPanel =
		Instance.new("ScrollingFrame")

	statisticsPanel.Name =
		"StatisticsPanel"

	statisticsPanel.Position =
		UDim2.fromScale(0, 0)

	statisticsPanel.Size =
	UDim2.fromScale(
		1,
		0.15
	)

	statisticsPanel.BackgroundTransparency = 1
	statisticsPanel.BorderSizePixel = 0

	statisticsPanel.CanvasSize =
		UDim2.fromOffset(0, 0)

	statisticsPanel.AutomaticCanvasSize =
		Enum.AutomaticSize.X

	statisticsPanel.ScrollingDirection =
		Enum.ScrollingDirection.X

	statisticsPanel.ScrollBarThickness = 3

	statisticsPanel.ScrollBarImageColor3 =
		Colors.Primary

	statisticsPanel.ElasticBehavior =
		Enum.ElasticBehavior.WhenScrollable

	statisticsPanel.Parent = content

	local statisticsPadding =
		Instance.new("UIPadding")

	statisticsPadding.PaddingLeft =
		UDim.new(0, 2)

	statisticsPadding.PaddingRight =
		UDim.new(0, 8)

	statisticsPadding.PaddingBottom =
		UDim.new(0, 5)

	statisticsPadding.Parent =
		statisticsPanel

	local statisticsLayout =
		Instance.new("UIListLayout")

	statisticsLayout.FillDirection =
		Enum.FillDirection.Horizontal

	statisticsLayout.VerticalAlignment =
		Enum.VerticalAlignment.Top

	statisticsLayout.SortOrder =
		Enum.SortOrder.LayoutOrder

	statisticsLayout.Padding =
		UDim.new(0, 10)

	statisticsLayout.Parent =
		statisticsPanel

	statisticLabels.CashPerSale =
		createStatisticBox(
			statisticsPanel,
			"CashPerSale",
			"CASH / SALE"
		)

	statisticLabels.CustomersWaiting =
		createStatisticBox(
			statisticsPanel,
			"CustomersWaiting",
			"WAITING"
		)

	statisticLabels.LifetimeEarnings =
		createStatisticBox(
			statisticsPanel,
			"LifetimeEarnings",
			"LIFETIME CASH"
		)

	statisticLabels.ServiceTime =
		createStatisticBox(
			statisticsPanel,
			"ServiceTime",
			"SERVICE TIME"
		)

	statisticLabels.TotalSales =
		createStatisticBox(
			statisticsPanel,
			"TotalSales",
			"TOTAL SALES"
		)

	local scrollingFrame =
		Instance.new("ScrollingFrame")

	scrollingFrame.Name =
		"UpgradeList"

	scrollingFrame.Position =
	UDim2.fromScale(
		0,
		0.17
	)

scrollingFrame.Size =
	UDim2.fromScale(
		1,
		0.74
	)

	scrollingFrame.BackgroundTransparency = 1
	scrollingFrame.BorderSizePixel = 0

	scrollingFrame.CanvasSize =
		UDim2.fromOffset(0, 0)

	scrollingFrame.AutomaticCanvasSize =
		Enum.AutomaticSize.Y

	scrollingFrame.ScrollBarThickness = 4

	scrollingFrame.ScrollBarImageColor3 =
		Colors.Primary

	scrollingFrame.ScrollingDirection =
		Enum.ScrollingDirection.Y

	scrollingFrame.ElasticBehavior =
		Enum.ElasticBehavior.WhenScrollable

	scrollingFrame.Parent = content

	local listPadding =
		Instance.new("UIPadding")

	listPadding.PaddingLeft =
		UDim.new(0, 2)

	listPadding.PaddingRight =
		UDim.new(0, 10)

	listPadding.PaddingTop =
		UDim.new(0, 2)

	listPadding.PaddingBottom =
		UDim.new(0, 14)

	listPadding.Parent =
		scrollingFrame

	local listLayout =
		Instance.new("UIListLayout")

	listLayout.FillDirection =
		Enum.FillDirection.Vertical

	listLayout.HorizontalAlignment =
		Enum.HorizontalAlignment.Center

	listLayout.VerticalAlignment =
		Enum.VerticalAlignment.Top

	listLayout.SortOrder =
		Enum.SortOrder.LayoutOrder

	listLayout.Padding =
		UDim.new(0, 12)

	listLayout.Parent =
		scrollingFrame

	appearanceCard =
		createUpgradeCard(
			scrollingFrame,
			"StandAppearance",
			"STAND APPEARANCE",
			"Improve the physical stand with a larger and more professional design.",
			"NEXT DESIGN",
			Colors.Primary,
			Colors.PrimaryDark
		)

	cards.QueueCapacity =
		createUpgradeCard(
			scrollingFrame,
			"QueueCapacity",
			"LONGER QUEUE",
			"Allow more customers to wait at this stand.",
			"QUEUE SIZE",
			Colors.Info,
			Colors.InfoDark
		)

	cards.SaleValue =
		createUpgradeCard(
			scrollingFrame,
			"SaleValue",
			"BETTER LEMONADE",
			"Improve the recipe and earn more from every sale.",
			"CASH PER SALE",
			Colors.Success,
			Colors.SuccessDark
		)

	cards.ServingSpeed =
		createUpgradeCard(
			scrollingFrame,
			"ServingSpeed",
			"FASTER SERVICE",
			"Reduce how long each customer waits at the counter.",
			"SERVICE TIME",
			Colors.Success,
			Colors.SuccessDark
		)

	local statusLabel =
		createTextLabel(
			content,
			"StatusLabel",
			"",
			UDim2.fromScale(
				0,
				0.92
			),
			UDim2.fromScale(
				1,
				0.055
			),
			8,
			14,
			Fonts.Semibold,
			Colors.TextMuted
		)

	statusLabel.TextXAlignment =
		Enum.TextXAlignment.Center

	return {
		ScreenGui = screenGui,

		Overlay = overlay,
		Panel = panel,
		PanelScale = panelScale,

		CloseButton = closeButton,
		CashLabel = cashLabel,
		StatusLabel = statusLabel,
		TitleLabel = title,
		SubtitleLabel = subtitle,
	}
end

local interface =
	createInterface()

local function closeUpgradeMenu()
	if not menuOpen then
		return
	end

	menuOpen = false
	requestPending = nil

	local overlayTween =
		TweenService:Create(
			interface.Overlay,
			TweenInfo.new(
				0.15,
				Enum.EasingStyle.Quad,
				Enum.EasingDirection.In
			),
			{
				BackgroundTransparency = 1,
			}
		)

	local panelTween =
		TweenService:Create(
			interface.PanelScale,
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
	panelTween:Play()

	panelTween.Completed:Once(function()
		if menuOpen then
			return
		end

		interface.Overlay.Visible =
			false

		selectedStand = nil
		selectedBusinessId = nil
	end)
end

local function showStatus(
	message: string,
	isError: boolean?
)
	statusVersion += 1

	local currentVersion =
		statusVersion

	interface.StatusLabel.Text =
		message

	interface.StatusLabel.TextColor3 =
		isError
		and Colors.Danger
		or Colors.Success

	task.delay(4, function()
		if statusVersion == currentVersion then
			interface.StatusLabel.Text = ""
		end
	end)
end

local function updateStatistics()
	if not selectedStand
		or not selectedStand.Parent then

		for _, label in statisticLabels do
			label.Text = "--"
		end

		return
	end

	local totalSales =
		getNumericAttribute(
			selectedStand,
			"TotalSales"
		)

	local lifetimeEarnings =
		getNumericAttribute(
			selectedStand,
			"LifetimeEarnings"
		)

	local customersWaiting =
		getNumericAttribute(
			selectedStand,
			"CustomersWaiting"
		)

	local serviceTime =
		getNumericAttribute(
			selectedStand,
			"PurchaseCooldown"
		)

	local cashPerSale =
		getNumericAttribute(
			selectedStand,
			"SaleValue"
		)

	statisticLabels.TotalSales.Text =
		string.format(
			"%d",
			math.floor(totalSales)
		)

	statisticLabels.LifetimeEarnings.Text =
		string.format(
			"$%d",
			math.floor(lifetimeEarnings)
		)

	statisticLabels.CustomersWaiting.Text =
		string.format(
			"%d",
			math.floor(customersWaiting)
		)

	statisticLabels.ServiceTime.Text =
		string.format(
			"%.2fs",
			serviceTime
		)

	statisticLabels.CashPerSale.Text =
		string.format(
			"$%d",
			math.floor(cashPerSale)
		)
end

local function setCardButtonState(
	card: UpgradeCard,
	text: string,
	enabled: boolean,
	topColor: Color3,
	bottomColor: Color3
)
	card.PurchaseButton.Text = text

	UITheme.SetButtonEnabled(
		card.PurchaseButton,
		enabled,
		topColor,
		bottomColor
	)

	card.PurchaseButton.TextColor3 =
		Color3.fromRGB(255, 255, 255)

	card.PurchaseButton.TextTransparency = 0
end

local function updateAppearanceCard()
	local card = appearanceCard

	if not card then
		return
	end

	if not selectedStand
		or not selectedStand.Parent then

		card.LevelLabel.Text = "-- / --"
		card.ValueLabel.Text = "--"

		card.ProgressFill.Size =
			UDim2.fromScale(0, 1)

		setCardButtonState(
			card,
			"UNAVAILABLE",
			false,
			Colors.Primary,
			Colors.PrimaryDark
		)

		return
	end

	local currentLevel =
		getStandAppearanceLevel(
			selectedStand
		)

	local maximumLevel =
		getMaximumAppearanceLevel()

	local currentConfig =
		getAppearanceConfig(currentLevel)

	local nextConfig =
		getAppearanceConfig(currentLevel + 1)

	card.LevelLabel.Text =
		`{currentLevel} / {maximumLevel}`

	card.ValueCaption.Text =
		"NEXT DESIGN"

	if nextConfig
		and typeof(nextConfig.TemplateName)
			== "string" then

		card.ValueLabel.Text =
			`LEVEL {currentLevel + 1}`
	else
		card.ValueLabel.Text =
			"COMPLETE"
	end

	local progress =
		math.clamp(
			currentLevel
				/ math.max(maximumLevel, 1),
			0,
			1
		)

	card.ProgressFill.Size =
		UDim2.fromScale(progress, 1)

	if currentLevel >= maximumLevel
		or not nextConfig then

		setCardButtonState(
			card,
			"MAXIMUM LEVEL",
			false,
			Colors.Primary,
			Colors.PrimaryDark
		)

		return
	end

	local upgradeCost =
		currentConfig
		and currentConfig.UpgradeCost

	if typeof(upgradeCost) ~= "number"
		or upgradeCost < 0 then

		setCardButtonState(
			card,
			"UNAVAILABLE",
			false,
			Colors.Primary,
			Colors.PrimaryDark
		)

		return
	end

	setCardButtonState(
		card,
		`UPGRADE STAND  •  ${math.floor(upgradeCost)}`,
		requestPending == nil,
		Colors.Primary,
		Colors.PrimaryDark
	)
end

local function updateGameplayCard(
	state: GameplayUpgradeState
)
	local upgradeName =
		state.UpgradeName

	if not upgradeName then
		return
	end

	local card =
		cards[upgradeName]

	if not card then
		return
	end

	if not state.Success
		and state.CurrentLevel == nil then

		card.LevelLabel.Text = "-- / --"
		card.ValueLabel.Text = "--"

		card.ProgressFill.Size =
			UDim2.fromScale(0, 1)

		setCardButtonState(
			card,
			"UNAVAILABLE",
			false,
			Colors.Success,
			Colors.SuccessDark
		)

		return
	end

	local currentLevel =
		state.CurrentLevel or 0

	local maximumLevel =
		state.MaximumLevel or 0

	card.LevelLabel.Text =
		`{currentLevel} / {maximumLevel}`

		if upgradeName == "ServingSpeed" then
		card.ValueCaption.Text =
			"SERVICE TIME"

		card.ValueLabel.Text =
			state.CurrentCooldown
			and string.format(
				"%.2fs",
				state.CurrentCooldown
			)
			or "--"

	elseif upgradeName == "SaleValue" then
		card.ValueCaption.Text =
			"CASH PER SALE"

		card.ValueLabel.Text =
			state.CurrentSaleValue
			and string.format(
				"$%d",
				state.CurrentSaleValue
			)
			or "--"

	elseif upgradeName == "QueueCapacity" then
		card.ValueCaption.Text =
			"QUEUE SIZE"

		local capacity =
			state.CurrentQueueCapacity

		if typeof(capacity) == "number" then
			local roundedCapacity =
				math.max(
					1,
					math.floor(capacity)
				)

			if roundedCapacity == 1 then
				card.ValueLabel.Text =
					"1 CUSTOMER"
			else
				card.ValueLabel.Text =
					`{roundedCapacity} CUSTOMERS`
			end
		else
			card.ValueLabel.Text = "--"
		end
	end

	local progress = 0

	if maximumLevel > 0 then
		progress =
			math.clamp(
				currentLevel / maximumLevel,
				0,
				1
			)
	end

	card.ProgressFill.Size =
		UDim2.fromScale(progress, 1)

	if currentLevel >= maximumLevel then
		setCardButtonState(
			card,
			"MAXIMUM LEVEL",
			false,
			Colors.Success,
			Colors.SuccessDark
		)

		return
	end

	setCardButtonState(
		card,
		`UPGRADE  •  ${state.NextCost or 0}`,
		requestPending == nil,
		Colors.Success,
		Colors.SuccessDark
	)
end

local function requestGameplayUpgradeState(
	upgradeName: string
)
	if not selectedBusinessId then
		updateGameplayCard({
			Success = false,
			Message =
				"No lemonade stand is selected.",
			UpgradeName = upgradeName,
		})

		return
	end

	local requestedBusinessId =
		selectedBusinessId

	local success, result =
		pcall(function()
			return getUpgradeStateRemote:InvokeServer(
				requestedBusinessId,
				upgradeName
			)
		end)

	if not success
		or type(result) ~= "table" then

		updateGameplayCard({
			Success = false,
			Message =
				"The upgrade server could not be reached.",
			UpgradeName = upgradeName,
		})

		return
	end

	if result.BusinessId
		and result.BusinessId
			~= selectedBusinessId then

		return
	end

	updateGameplayCard(result)
end

local function refreshGameplayCards()
	for _, upgradeName in
		GAMEPLAY_UPGRADE_ORDER do

		requestGameplayUpgradeState(
			upgradeName
		)
	end
end

local function refreshAllCards()
	updateAppearanceCard()
	refreshGameplayCards()
end

local function reconnectSelectedStand(): boolean
	if not selectedBusinessId then
		return false
	end

	local replacement =
		findOwnedStandByBusinessId(
			selectedBusinessId
		)

	if not replacement then
		return false
	end

	selectedStand = replacement

	return true
end

if appearanceCard then
	appearanceCard.PurchaseButton.Activated:Connect(
		function()
			if requestPending
				or not selectedStand
				or not selectedStand.Parent
				or not appearanceCard
					.PurchaseButton.Active then

				return
			end

			requestPending =
				"StandAppearance"

			setCardButtonState(
				appearanceCard,
				"UPGRADING STAND...",
				false,
				Colors.Primary,
				Colors.PrimaryDark
			)

			requestAppearanceUpgradeRemote:FireServer(
				selectedStand
			)
		end
	)
end

for upgradeName, card in cards do
	card.PurchaseButton.Activated:Connect(
		function()
			if requestPending
				or not card.PurchaseButton.Active
				or not selectedBusinessId then

				return
			end

			requestPending =
				upgradeName

			setCardButtonState(
				card,
				"PURCHASING...",
				false,
				Colors.Success,
				Colors.SuccessDark
			)

			purchaseUpgradeRemote:FireServer(
				selectedBusinessId,
				upgradeName
			)
		end
	)
end

local function openUpgradeMenuForStand(
	businessId: string
)
	if menuOpen then
	return
end

	if not selectStandByBusinessId(businessId)
		or not selectedBusinessId then

		showStatus(
			"The selected lemonade stand could not be found.",
			true
		)

		return
	end

	local standNumber =
		getStandNumber(
			selectedBusinessId
		)

	interface.TitleLabel.Text =
		`LEMONADE STAND #{standNumber}`

	interface.SubtitleLabel.Text =
		"Appearance and upgrades apply only to this stand."

	requestPending = nil

	menuOpen = true

interface.Overlay.Visible = true
interface.Overlay.BackgroundTransparency = 1
interface.PanelScale.Scale = 0.92

TweenService:Create(
	interface.Overlay,
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
	interface.PanelScale,
	TweenInfo.new(
		0.22,
		Enum.EasingStyle.Back,
		Enum.EasingDirection.Out
	),
	{
		Scale = 1,
	}
):Play()

updateStatistics()
refreshAllCards()
end

openUpgradeMenuEvent.Event:Connect(
	function(businessId: string)
		if typeof(businessId) ~= "string" then
			return
		end

		openUpgradeMenuForStand(
			businessId
		)
	end
)

interface.CloseButton.Activated:Connect(
	closeUpgradeMenu
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

			closeUpgradeMenu()
		end
	end
)

upgradeResultRemote.OnClientEvent:Connect(
	function(result: GameplayUpgradeState)
		if result.BusinessId
			and selectedBusinessId
			and result.BusinessId
				~= selectedBusinessId then

			return
		end

		requestPending = nil

		showStatus(
			result.Message,
			not result.Success
		)

		updateStatistics()
		refreshAllCards()
	end
)

appearanceUpgradeResultRemote.OnClientEvent:Connect(
	function(
		success: boolean,
		message: string,
		_level: number?
	)
		if requestPending ~= "StandAppearance" then
			return
		end

		requestPending = nil

		if success then
			-- The server replaces the old model. Its BusinessId
			-- and final name are preserved, so reconnect to it.
			task.defer(function()
				local startedAt = time()

				while time() - startedAt < 3 do
					if reconnectSelectedStand() then
						updateStatistics()
						refreshAllCards()
						return
					end

					task.wait(0.05)
				end

				closeUpgradeMenu()

				selectedStand = nil
				selectedBusinessId = nil

				showStatus(
					"The upgraded stand could not be found.",
					true
				)
			end)
		else
			refreshAllCards()
		end

		showStatus(
			message,
			not success
		)
	end
)

local leaderstats =
	player:WaitForChild("leaderstats")

local cash =
	leaderstats:WaitForChild("Cash")

local function updateCashLabel()
	interface.CashLabel.Text =
		FormatNumber.Currency(
			cash.Value
		)
end

updateCashLabel()

cash:GetPropertyChangedSignal(
	"Value"
):Connect(function()
	updateCashLabel()

	if interface.Overlay.Visible
		and not requestPending then

		refreshAllCards()
	end
end)

task.spawn(function()
	while true do
		if interface.Overlay.Visible then
			if selectedStand
				and selectedStand.Parent then

				updateStatistics()
			elseif requestPending
				~= "StandAppearance" then

				if not reconnectSelectedStand() then
					closeUpgradeMenu()

					requestPending = nil
					selectedStand = nil
					selectedBusinessId = nil
				end
			end
		end

		task.wait(0.25)
	end
end)