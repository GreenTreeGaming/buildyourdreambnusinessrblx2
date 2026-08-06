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
	CloseButton: TextButton,
	CashLabel: TextLabel,
	StatusLabel: TextLabel,
	TitleLabel: TextLabel,
	SubtitleLabel: TextLabel,
}

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
	local box = Instance.new("Frame")

	box.Name = name .. "Box"

	box.Size =
		UDim2.new(
			0.2,
			-8,
			1,
			0
		)

	box.BackgroundColor3 =
		Colors.Background

	box.BackgroundTransparency = 0.2
	box.BorderSizePixel = 0
	box.Parent = parent

	UITheme.AddCorner(box, 0.12)

	UITheme.AddStroke(
		box,
		Colors.Stroke,
		1,
		0.5
	)

	local caption = createTextLabel(
		box,
		"Caption",
		captionText,
		UDim2.fromScale(0.06, 0.08),
		UDim2.fromScale(0.88, 0.34),
		7,
		11,
		Fonts.Bold,
		Colors.TextMuted
	)

	caption.TextWrapped = true

	caption.TextXAlignment =
		Enum.TextXAlignment.Center

	local value = createTextLabel(
		box,
		"Value",
		"--",
		UDim2.fromScale(0.06, 0.43),
		UDim2.fromScale(0.88, 0.44),
		11,
		18,
		Fonts.Black,
		Colors.Text
	)

	value.TextWrapped = true

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
	local card = Instance.new("Frame")

	card.Name = name .. "Card"

	card.Size =
		UDim2.new(
			0.96,
			0,
			0,
			205
		)

	card.BackgroundColor3 =
		Color3.fromRGB(48, 68, 94)

	card.BorderSizePixel = 0
	card.Parent = parent

	UITheme.AddCorner(card, 0.055)

	UITheme.AddStroke(
		card,
		Colors.Info,
		1.5,
		0.45
	)

	UITheme.AddGradient(
		card,
		Color3.fromRGB(48, 68, 94),
		Color3.fromRGB(31, 48, 71)
	)

	local title = createTextLabel(
		card,
		"Title",
		titleText,
		UDim2.fromScale(0.045, 0.045),
		UDim2.fromScale(0.91, 0.1),
		13,
		21,
		Fonts.Black,
		Colors.Text
	)

	local description = createTextLabel(
		card,
		"Description",
		descriptionText,
		UDim2.fromScale(0.045, 0.145),
		UDim2.fromScale(0.91, 0.11),
		9,
		14,
		Fonts.Medium,
		Colors.Text
	)

	description.TextWrapped = true

	local statRow = Instance.new("Frame")

	statRow.Name = "Stats"

	statRow.Position =
		UDim2.fromScale(0.045, 0.3)

	statRow.Size =
		UDim2.fromScale(0.91, 0.25)

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
		UDim.new(0.035, 0)

	statLayout.Parent = statRow

	local function createStatBox(
		statName: string,
		captionText: string
	): (Frame, TextLabel)
		local box = Instance.new("Frame")

		box.Name = statName

		box.Size =
			UDim2.fromScale(
				0.4825,
				1
			)

		box.BackgroundColor3 =
			Colors.Background

		box.BackgroundTransparency = 0.2
		box.BorderSizePixel = 0
		box.Parent = statRow

		UITheme.AddCorner(box, 0.12)

		UITheme.AddStroke(
			box,
			Colors.Stroke,
			1,
			0.45
		)

		local caption = createTextLabel(
			box,
			"Caption",
			captionText,
			UDim2.fromScale(0.08, 0.08),
			UDim2.fromScale(0.84, 0.3),
			8,
			12,
			Fonts.Bold,
			Colors.Text
		)

		caption.TextXAlignment =
			Enum.TextXAlignment.Center

		local value = createTextLabel(
			box,
			"Value",
			"--",
			UDim2.fromScale(0.08, 0.42),
			UDim2.fromScale(0.84, 0.45),
			13,
			21,
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
		Colors.Success

	local progressTrack =
		Instance.new("Frame")

	progressTrack.Name = "ProgressTrack"

	progressTrack.Position =
		UDim2.fromScale(0.045, 0.62)

	progressTrack.Size =
		UDim2.fromScale(0.91, 0.065)

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

	progressFill.Name = "ProgressFill"

	progressFill.Size =
		UDim2.fromScale(0, 1)

	progressFill.BackgroundColor3 =
		buttonColor

	progressFill.BorderSizePixel = 0
	progressFill.Parent = progressTrack

	UITheme.AddCorner(
		progressFill,
		0.5
	)

	UITheme.AddGradient(
		progressFill,
		buttonColor,
		Colors.Success,
		0
	)

	local purchaseButton =
		Instance.new("TextButton")

	purchaseButton.Name =
		"PurchaseButton"

	purchaseButton.Position =
		UDim2.fromScale(0.045, 0.745)

	purchaseButton.Size =
		UDim2.fromScale(0.91, 0.17)

	purchaseButton.Text = "LOADING..."
	purchaseButton.Parent = card

	UITheme.StyleText(
		purchaseButton,
		11,
		17,
		Colors.Text,
		Fonts.Black
	)

	UITheme.StyleButton(
		purchaseButton,
		buttonColor,
		buttonDarkColor,
		Colors.Text
	)

	purchaseButton.TextColor3 =
		Color3.fromRGB(255, 255, 255)

	purchaseButton.TextTransparency = 0

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
	screenGui.IgnoreGuiInset = false
	screenGui.DisplayOrder = 30
	screenGui.Parent = playerGui

	local overlay = Instance.new("Frame")

	overlay.Name = "Overlay"

	overlay.Size =
		UDim2.fromScale(1, 1)

	overlay.BackgroundColor3 =
		Color3.fromRGB(0, 0, 0)

	overlay.BackgroundTransparency = 0.35
	overlay.BorderSizePixel = 0
	overlay.Visible = false
	overlay.Active = true
	overlay.Parent = screenGui

	local shadow = Instance.new("Frame")

	shadow.Name = "Shadow"

	shadow.AnchorPoint =
		Vector2.new(0.5, 0.5)

	shadow.Position =
		UDim2.fromScale(0.507, 0.512)

	shadow.Size =
		UDim2.fromScale(0.58, 0.86)

	shadow.BackgroundColor3 =
		Colors.Shadow

	shadow.BackgroundTransparency = 0.25
	shadow.BorderSizePixel = 0
	shadow.Parent = overlay

	UITheme.AddCorner(shadow, 0.045)

	local panel = Instance.new("Frame")

	panel.Name = "Panel"

	panel.AnchorPoint =
		Vector2.new(0.5, 0.5)

	panel.Position =
		UDim2.fromScale(0.5, 0.5)

	panel.Size =
		UDim2.fromScale(0.58, 0.86)

	panel.BackgroundColor3 =
		Color3.fromRGB(39, 57, 80)

	panel.BorderSizePixel = 0
	panel.Parent = overlay

	UITheme.AddCorner(panel, 0.045)

	UITheme.AddStroke(
		panel,
		Colors.Stroke,
		2,
		0.08
	)

	UITheme.AddGradient(
		panel,
		Color3.fromRGB(39, 57, 80),
		Color3.fromRGB(23, 37, 57)
	)

	local header = Instance.new("Frame")

	header.Name = "Header"

	header.Position =
		UDim2.fromScale(0.045, 0.025)

	header.Size =
		UDim2.fromScale(0.91, 0.105)

	header.BackgroundTransparency = 1
	header.Parent = panel

	local title = createTextLabel(
		header,
		"Title",
		"LEMONADE STAND",
		UDim2.fromScale(0, 0),
		UDim2.fromScale(0.62, 0.48),
		14,
		23,
		Fonts.Black,
		Colors.Text
	)

	local subtitle = createTextLabel(
		header,
		"Subtitle",
		"Upgrades apply only to this stand.",
		UDim2.fromScale(0, 0.5),
		UDim2.fromScale(0.62, 0.34),
		9,
		14,
		Fonts.Medium,
		Colors.TextMuted
	)

	local cashLabel = createTextLabel(
		header,
		"CashLabel",
		"CASH  $0",
		UDim2.fromScale(0.6, 0.48),
		UDim2.fromScale(0.25, 0.3),
		10,
		15,
		Fonts.Bold,
		Colors.Primary
	)

	cashLabel.TextXAlignment =
		Enum.TextXAlignment.Right

	local closeButton =
		Instance.new("TextButton")

	closeButton.Name = "CloseButton"

	closeButton.AnchorPoint =
		Vector2.new(1, 0)

	closeButton.Position =
		UDim2.fromScale(1, 0)

	closeButton.Size =
		UDim2.fromScale(0.09, 0.75)

	closeButton.Text = "×"
	closeButton.Parent = header

	UITheme.StyleText(
		closeButton,
		17,
		27,
		Colors.Text,
		Fonts.Bold
	)

	UITheme.StyleButton(
		closeButton,
		Colors.SurfaceLight,
		Colors.SurfaceRaised,
		Colors.Text
	)

	closeButton.TextColor3 =
		Color3.fromRGB(255, 255, 255)

	closeButton.TextTransparency = 0

	local statisticsPanel =
		Instance.new("Frame")

	statisticsPanel.Name =
		"StatisticsPanel"

	statisticsPanel.Position =
		UDim2.fromScale(0.045, 0.14)

	statisticsPanel.Size =
		UDim2.fromScale(0.91, 0.125)

	statisticsPanel.BackgroundTransparency = 1
	statisticsPanel.Parent = panel

	local statisticsLayout =
		Instance.new("UIListLayout")

	statisticsLayout.FillDirection =
		Enum.FillDirection.Horizontal

	statisticsLayout.HorizontalAlignment =
		Enum.HorizontalAlignment.Center

	statisticsLayout.VerticalAlignment =
		Enum.VerticalAlignment.Center

	statisticsLayout.Padding =
		UDim.new(0, 8)

	statisticsLayout.Parent =
		statisticsPanel

	statisticLabels.TotalSales =
		createStatisticBox(
			statisticsPanel,
			"TotalSales",
			"TOTAL SALES"
		)

	statisticLabels.LifetimeEarnings =
		createStatisticBox(
			statisticsPanel,
			"LifetimeEarnings",
			"LIFETIME CASH"
		)

	statisticLabels.CustomersWaiting =
		createStatisticBox(
			statisticsPanel,
			"CustomersWaiting",
			"WAITING"
		)

	statisticLabels.ServiceTime =
		createStatisticBox(
			statisticsPanel,
			"ServiceTime",
			"SERVICE TIME"
		)

	statisticLabels.CashPerSale =
		createStatisticBox(
			statisticsPanel,
			"CashPerSale",
			"CASH / SALE"
		)

	local scrollingFrame =
		Instance.new("ScrollingFrame")

	scrollingFrame.Name =
		"UpgradeList"

	scrollingFrame.Position =
		UDim2.fromScale(0.045, 0.285)

	scrollingFrame.Size =
		UDim2.fromScale(0.91, 0.625)

	scrollingFrame.BackgroundTransparency = 1
	scrollingFrame.BorderSizePixel = 0

	scrollingFrame.CanvasSize =
		UDim2.fromOffset(0, 0)

	scrollingFrame.AutomaticCanvasSize =
		Enum.AutomaticSize.Y

	scrollingFrame.ScrollBarThickness = 5

	scrollingFrame.ScrollBarImageColor3 =
		Colors.Primary

	scrollingFrame.ScrollingDirection =
		Enum.ScrollingDirection.Y

	scrollingFrame.Parent = panel

	local listPadding =
		Instance.new("UIPadding")

	listPadding.PaddingLeft =
		UDim.new(0.015, 0)

	listPadding.PaddingRight =
		UDim.new(0.025, 0)

	listPadding.PaddingTop =
		UDim.new(0, 5)

	listPadding.PaddingBottom =
		UDim.new(0, 12)

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

	listLayout.Padding =
		UDim.new(0, 12)

	listLayout.Parent =
		scrollingFrame

	appearanceCard = createUpgradeCard(
		scrollingFrame,
		"StandAppearance",
		"STAND APPEARANCE",
		"Improve the physical stand with a larger and more professional design.",
		"NEXT DESIGN",
		Colors.Primary,
		Colors.PrimaryDark
	)

	cards.SaleValue = createUpgradeCard(
		scrollingFrame,
		"SaleValue",
		"BETTER LEMONADE",
		"Improve the recipe and earn more from every sale.",
		"CASH PER SALE",
		Colors.Success,
		Colors.SuccessDark
	)

		cards.ServingSpeed = createUpgradeCard(
		scrollingFrame,
		"ServingSpeed",
		"FASTER SERVICE",
		"Reduce how long each customer waits at the counter.",
		"SERVICE TIME",
		Colors.Success,
		Colors.SuccessDark
	)

	cards.QueueCapacity = createUpgradeCard(
		scrollingFrame,
		"QueueCapacity",
		"LONGER QUEUE",
		"Allow more customers to wait at this stand.",
		"QUEUE SIZE",
		Colors.Success,
		Colors.SuccessDark
	)

	local statusLabel = createTextLabel(
		panel,
		"StatusLabel",
		"",
		UDim2.fromScale(0.06, 0.925),
		UDim2.fromScale(0.88, 0.05),
		9,
		14,
		Fonts.Semibold,
		Colors.Text
	)

	statusLabel.TextXAlignment =
		Enum.TextXAlignment.Center

	local function updateResponsiveLayout()
		local camera =
			Workspace.CurrentCamera

		if not camera then
			return
		end

		local viewport =
			camera.ViewportSize

		local portrait =
			viewport.Y > viewport.X

		local compact =
			viewport.X < 900
			or viewport.Y < 600

		if portrait then
			panel.Size =
				UDim2.fromScale(0.94, 0.88)

			shadow.Size =
				UDim2.fromScale(0.94, 0.88)
		elseif compact then
			panel.Size =
				UDim2.fromScale(0.78, 0.92)

			shadow.Size =
				UDim2.fromScale(0.78, 0.92)
		else
			panel.Size =
				UDim2.fromScale(0.58, 0.86)

			shadow.Size =
				UDim2.fromScale(0.58, 0.86)
		end
	end

	updateResponsiveLayout()

	local camera =
		Workspace.CurrentCamera

	if camera then
		camera:GetPropertyChangedSignal(
			"ViewportSize"
		):Connect(updateResponsiveLayout)
	end

	return {
		ScreenGui = screenGui,
		Overlay = overlay,
		CloseButton = closeButton,
		CashLabel = cashLabel,
		StatusLabel = statusLabel,
		TitleLabel = title,
		SubtitleLabel = subtitle,
	}
end

local interface =
	createInterface()

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
	if interface.Overlay.Visible then
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

	interface.Overlay.Visible = true

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
	function()
		interface.Overlay.Visible = false

		requestPending = nil
		selectedStand = nil
		selectedBusinessId = nil
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

				interface.Overlay.Visible = false

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
		`CASH  ${cash.Value}`
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
					interface.Overlay.Visible = false

					requestPending = nil
					selectedStand = nil
					selectedBusinessId = nil
				end
			end
		end

		task.wait(0.25)
	end
end)