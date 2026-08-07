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
	remotes:WaitForChild(
		"PurchaseUpgrade"
	)

local upgradeResultRemote =
	remotes:WaitForChild(
		"UpgradeResult"
	)

local getUpgradeStateRemote =
	remotes:WaitForChild(
		"GetUpgradeState"
	)

local requestAppearanceUpgradeRemote =
	remotes:WaitForChild(
		"RequestBusinessUpgrade"
	)

local appearanceUpgradeResultRemote =
	remotes:WaitForChild(
		"BusinessUpgradeResult"
	)


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


local BUSINESS_NAME =
	"LemonadeStand"

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

	Header: Frame,
	Content: Frame,

	TitleLabel: TextLabel,
	SubtitleLabel: TextLabel,

	CashContainer: Frame,
	CashLabel: TextLabel,

	CloseButton: TextButton,

	StatisticsPanel: ScrollingFrame,
	UpgradeList: ScrollingFrame,

	StatusLabel: TextLabel,
}


local interface: Interface

local menuOpen = false

local selectedBusinessId: string? = nil
local selectedStand: Model? = nil

local requestPending: string? = nil

local statusVersion = 0


local cards:
	{[string]: UpgradeCard} = {}

local statisticLabels:
	{[string]: TextLabel} = {}

local appearanceCard:
	UpgradeCard? = nil


local function getOpenUpgradeMenuEvent(): BindableEvent
	local existing =
		playerGui:FindFirstChild(
			"OpenUpgradeMenu"
		)

	if existing then
		if existing:IsA(
			"BindableEvent"
		) then
			return existing
		end

		existing:Destroy()
	end

	local event =
		Instance.new(
			"BindableEvent"
		)

	event.Name =
		"OpenUpgradeMenu"

	event.Parent =
		playerGui

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
	local label =
		Instance.new("TextLabel")

	label.Name = name
	label.Position = position
	label.Size = size

	label.BackgroundTransparency =
		1

	label.BorderSizePixel =
		0

	label.Text =
		text

	label.TextXAlignment =
		Enum.TextXAlignment.Left

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


local function getOwnedPlot(): Model?
	local plotName =
		player:GetAttribute(
			"PlotName"
		)

	if typeof(plotName)
			== "string" then

		local namedPlot =
			plotsFolder:FindFirstChild(
				plotName
			)

		if namedPlot
			and namedPlot:IsA("Model")
			and namedPlot:GetAttribute(
				"OwnerUserId"
			) == player.UserId then

			return namedPlot
		end
	end

	for _, plot in
		plotsFolder:GetChildren()
	do
		if not plot:IsA("Model") then
			continue
		end

		if plot:GetAttribute(
			"OwnerUserId"
		) == player.UserId then

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

	if instance:GetAttribute(
		"BusinessType"
	) == BUSINESS_NAME then

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
		stand:GetAttribute(
			"BusinessId"
		)

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

	for _, child in
		placedBusinesses:GetChildren()
	do
		if not child:IsA("Model")
			or not isLemonadeStand(
				child
			) then

			continue
		end

		if child:GetAttribute(
			"OwnerUserId"
		) ~= player.UserId then

			continue
		end

		local childBusinessId =
			getStandBusinessId(
				child
			)

		if childBusinessId
				== businessId
			or child.Name
				== businessId then

			return child
		end
	end

	return nil
end


local function selectStandByBusinessId(
	businessId: string
): boolean
	local stand =
		findOwnedStandByBusinessId(
			businessId
		)

	if not stand then
		selectedStand = nil
		selectedBusinessId = nil

		return false
	end

	selectedStand =
		stand

	selectedBusinessId =
		getStandBusinessId(
			stand
		)

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
		instance:GetAttribute(
			attributeName
		)

	if typeof(value) ~= "number" then
		return defaultValue or 0
	end

	return math.max(
		0,
		value
	)
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

	if typeof(lemonadeConfig)
			~= "table" then

		return nil
	end

	local standLevels =
		lemonadeConfig.StandLevels

	if typeof(standLevels)
			~= "table" then

		return nil
	end

	local config =
		standLevels[level]

	if typeof(config)
			~= "table" then

		return nil
	end

	return config
end


local function getMaximumAppearanceLevel(): number
	local lemonadeConfig =
		BusinessConfig.LemonadeStand

	if typeof(lemonadeConfig)
			~= "table"
		or typeof(
			lemonadeConfig.StandLevels
		) ~= "table" then

		return 1
	end

	local maximumLevel = 1

	for level, config in
		lemonadeConfig.StandLevels
	do
		if typeof(level) == "number"
			and typeof(config) == "table"
			and level > maximumLevel then

			maximumLevel =
				level
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

	box.Name =
		name .. "Box"

	box.Size =
		UDim2.fromOffset(
			142,
			60
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
		0.48
	)


	local caption =
		createTextLabel(
			box,
			"Caption",
			captionText,
			UDim2.new(
				0,
				8,
				0,
				5
			),
			UDim2.new(
				1,
				-16,
				0,
				18
			),
			8,
			10,
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
			UDim2.new(
				0,
				8,
				0,
				23
			),
			UDim2.new(
				1,
				-16,
				0,
				29
			),
			11,
			17,
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

	card.Name =
		name .. "Card"

	card.Size =
		UDim2.new(
			1,
			-4,
			0,
			174
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


	createTextLabel(
		card,
		"Title",
		titleText,
		UDim2.new(
			0,
			18,
			0,
			9
		),
		UDim2.new(
			1,
			-34,
			0,
			22
		),
		11,
		18,
		Fonts.Black,
		Colors.Text
	)


	local description =
		createTextLabel(
			card,
			"Description",
			descriptionText,
			UDim2.new(
				0,
				18,
				0,
				31
			),
			UDim2.new(
				1,
				-34,
				0,
				27
			),
			8,
			12,
			Fonts.Medium,
			Colors.TextMuted
		)

	description.TextWrapped = true
	description.TextYAlignment =
		Enum.TextYAlignment.Top


	local statRow =
		Instance.new("Frame")

	statRow.Name = "Stats"

	statRow.Position =
		UDim2.new(
			0,
			18,
			0,
			62
		)

	statRow.Size =
		UDim2.new(
			1,
			-36,
			0,
			43
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
			8
		)

	statLayout.Parent =
		statRow


	local function createStatBox(
		statName: string,
		captionText: string
	): (Frame, TextLabel)
		local box =
			Instance.new("Frame")

		box.Name =
			statName

		box.Size =
			UDim2.new(
				0.5,
				-4,
				1,
				0
			)

		box.BackgroundColor3 =
			Colors.Background

		box.BackgroundTransparency =
			0.26

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
				UDim2.new(
					0,
					6,
					0,
					3
				),
				UDim2.new(
					1,
					-12,
					0,
					15
				),
				7,
				10,
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
				UDim2.new(
					0,
					6,
					0,
					18
				),
				UDim2.new(
					1,
					-12,
					0,
					21
				),
				10,
				16,
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
		UDim2.new(
			0,
			18,
			0,
			113
		)

	progressTrack.Size =
		UDim2.new(
			1,
			-36,
			0,
			8
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
		UDim2.new(
			0,
			18,
			0,
			130
		)

	purchaseButton.Size =
		UDim2.new(
			1,
			-36,
			0,
			35
		)

	purchaseButton.Text =
		"LOADING..."

	purchaseButton.Parent =
		card

	UITheme.StyleText(
		purchaseButton,
		9,
		14,
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

	screenGui.Name =
		"UpgradeMenu"

	screenGui.ResetOnSpawn =
		false

	-- Important:
	-- Do NOT draw underneath Roblox's top bar.
	screenGui.IgnoreGuiInset =
		false

	screenGui.ScreenInsets =
		Enum.ScreenInsets.DeviceSafeInsets

	screenGui.DisplayOrder =
		30

	screenGui.ZIndexBehavior =
		Enum.ZIndexBehavior.Sibling

	screenGui.Parent =
		playerGui


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


	local panel =
		Instance.new("Frame")

	panel.Name =
		"Panel"

	panel.AnchorPoint =
		Vector2.new(
			0.5,
			0.5
		)

	panel.Position =
		UDim2.fromScale(
			0.5,
			0.5
		)

	panel.Size =
		UDim2.fromOffset(
			900,
			620
		)

	panel.BackgroundColor3 =
		Colors.Surface

	panel.BorderSizePixel =
		0

	panel.ClipsDescendants =
		true

	panel.Parent =
		overlay

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


	local panelScale =
		Instance.new("UIScale")

	panelScale.Scale =
		0.92

	panelScale.Parent =
		panel


	local header =
		Instance.new("Frame")

	header.Name =
		"Header"

	header.Size =
		UDim2.new(
			1,
			0,
			0,
			86
		)

	header.BackgroundColor3 =
		Colors.Background

	header.BorderSizePixel =
		0

	header.ClipsDescendants =
		true

	header.Parent =
		panel


	local headerBottomCover =
		Instance.new("Frame")

	headerBottomCover.Name =
		"BottomCover"

	headerBottomCover.AnchorPoint =
		Vector2.new(
			0,
			1
		)

	headerBottomCover.Position =
		UDim2.fromScale(
			0,
			1
		)

	headerBottomCover.Size =
		UDim2.new(
			1,
			0,
			0,
			18
		)

	headerBottomCover.BackgroundColor3 =
		Colors.Background

	headerBottomCover.BorderSizePixel =
		0

	headerBottomCover.Parent =
		header


	local title =
		createTextLabel(
			header,
			"Title",
			"LEMONADE STAND",
			UDim2.fromOffset(
				26,
				14
			),
			UDim2.new(
				1,
				-310,
				0,
				30
			),
			14,
			24,
			Fonts.Black,
			Colors.Text
		)

	title.ZIndex = 2


	local subtitle =
		createTextLabel(
			header,
			"Subtitle",
			"Appearance and upgrades apply only to this stand.",
			UDim2.fromOffset(
				26,
				44
			),
			UDim2.new(
				1,
				-310,
				0,
				22
			),
			8,
			13,
			Fonts.Medium,
			Colors.TextMuted
		)

	subtitle.ZIndex = 2


	local cashContainer =
		Instance.new("Frame")

	cashContainer.Name =
		"CashContainer"

	cashContainer.AnchorPoint =
		Vector2.new(
			1,
			0.5
		)

	cashContainer.Position =
		UDim2.new(
			1,
			-82,
			0.5,
			0
		)

	cashContainer.Size =
		UDim2.fromOffset(
			170,
			44
		)

	cashContainer.BackgroundColor3 =
		Colors.SurfaceRaised

	cashContainer.BorderSizePixel =
		0

	cashContainer.ZIndex = 2
	cashContainer.Parent = header

	UITheme.AddCorner(
		cashContainer,
		0.2
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
		Vector2.new(
			0,
			0.5
		)

	cashIcon.Position =
		UDim2.new(
			0,
			8,
			0.5,
			0
		)

	cashIcon.Size =
		UDim2.fromOffset(
			28,
			28
		)

	cashIcon.BackgroundColor3 =
		Colors.Primary

	cashIcon.BorderSizePixel =
		0

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
			UDim2.fromScale(
				0,
				0
			),
			UDim2.fromScale(
				1,
				1
			),
			12,
			18,
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
			UDim2.new(
				0,
				43,
				0,
				5
			),
			UDim2.new(
				1,
				-50,
				0,
				14
			),
			7,
			10,
			Fonts.Bold,
			Colors.TextMuted
		)

	cashCaption.ZIndex = 3


	local cashLabel =
		createTextLabel(
			cashContainer,
			"CashLabel",
			"$0",
			UDim2.new(
				0,
				43,
				0,
				18
			),
			UDim2.new(
				1,
				-50,
				0,
				21
			),
			10,
			17,
			Fonts.Black,
			Colors.Primary
		)

	cashLabel.ZIndex = 3


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

	closeButton.ZIndex = 4
	closeButton.Parent = header

	UITheme.StyleText(
		closeButton,
		16,
		24,
		Colors.Text,
		Fonts.Black
	)

	UITheme.StyleButton(
		closeButton,
		Colors.Danger,
		Colors.DangerDark,
		Colors.Text
	)


	local content =
		Instance.new("Frame")

	content.Name =
		"Content"

	content.Position =
		UDim2.fromOffset(
			0,
			86
		)

	content.Size =
		UDim2.new(
			1,
			0,
			1,
			-86
		)

	content.BackgroundTransparency =
		1

	content.Parent =
		panel


	local contentPadding =
		Instance.new("UIPadding")

	contentPadding.PaddingLeft =
		UDim.new(
			0,
			18
		)

	contentPadding.PaddingRight =
		UDim.new(
			0,
			18
		)

	contentPadding.PaddingTop =
		UDim.new(
			0,
			12
		)

	contentPadding.PaddingBottom =
		UDim.new(
			0,
			10
		)

	contentPadding.Parent =
		content


	local statisticsPanel =
		Instance.new("ScrollingFrame")

	statisticsPanel.Name =
		"StatisticsPanel"

	statisticsPanel.Position =
		UDim2.fromOffset(
			0,
			0
		)

	statisticsPanel.Size =
		UDim2.new(
			1,
			0,
			0,
			64
		)

	statisticsPanel.BackgroundTransparency =
		1

	statisticsPanel.BorderSizePixel =
		0

	statisticsPanel.CanvasSize =
		UDim2.fromOffset(
			0,
			0
		)

	statisticsPanel.AutomaticCanvasSize =
		Enum.AutomaticSize.X

	statisticsPanel.ScrollingDirection =
		Enum.ScrollingDirection.X

	statisticsPanel.ScrollBarThickness =
		2

	statisticsPanel.ScrollBarImageColor3 =
		Colors.Primary

	statisticsPanel.ElasticBehavior =
		Enum.ElasticBehavior.WhenScrollable

	statisticsPanel.Parent =
		content


	local statisticsLayout =
		Instance.new("UIListLayout")

	statisticsLayout.FillDirection =
		Enum.FillDirection.Horizontal

	statisticsLayout.VerticalAlignment =
		Enum.VerticalAlignment.Top

	statisticsLayout.SortOrder =
		Enum.SortOrder.LayoutOrder

	statisticsLayout.Padding =
		UDim.new(
			0,
			8
		)

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


	local upgradeList =
		Instance.new("ScrollingFrame")

	upgradeList.Name =
		"UpgradeList"

	upgradeList.Position =
		UDim2.fromOffset(
			0,
			72
		)

	upgradeList.Size =
		UDim2.new(
			1,
			0,
			1,
			-102
		)

	upgradeList.BackgroundTransparency =
		1

	upgradeList.BorderSizePixel =
		0

	upgradeList.CanvasSize =
		UDim2.fromOffset(
			0,
			0
		)

	upgradeList.AutomaticCanvasSize =
		Enum.AutomaticSize.Y

	upgradeList.ScrollBarThickness =
		3

	upgradeList.ScrollBarImageColor3 =
		Colors.Primary

	upgradeList.ScrollingDirection =
		Enum.ScrollingDirection.Y

	upgradeList.ElasticBehavior =
		Enum.ElasticBehavior.WhenScrollable

	upgradeList.Parent =
		content


	local listPadding =
		Instance.new("UIPadding")

	listPadding.PaddingLeft =
		UDim.new(
			0,
			2
		)

	listPadding.PaddingRight =
		UDim.new(
			0,
			8
		)

	listPadding.PaddingTop =
		UDim.new(
			0,
			2
		)

	listPadding.PaddingBottom =
		UDim.new(
			0,
			12
		)

	listPadding.Parent =
		upgradeList


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
		UDim.new(
			0,
			10
		)

	listLayout.Parent =
		upgradeList


	appearanceCard =
		createUpgradeCard(
			upgradeList,
			"StandAppearance",
			"STAND APPEARANCE",
			"Improve the physical stand with a larger and more professional design.",
			"NEXT DESIGN",
			Colors.Primary,
			Colors.PrimaryDark
		)


	cards.QueueCapacity =
		createUpgradeCard(
			upgradeList,
			"QueueCapacity",
			"LONGER QUEUE",
			"Allow more customers to wait at this stand.",
			"QUEUE SIZE",
			Colors.Info,
			Colors.InfoDark
		)


	cards.SaleValue =
		createUpgradeCard(
			upgradeList,
			"SaleValue",
			"BETTER LEMONADE",
			"Improve the recipe and earn more from every sale.",
			"CASH PER SALE",
			Colors.Success,
			Colors.SuccessDark
		)


	cards.ServingSpeed =
		createUpgradeCard(
			upgradeList,
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
			UDim2.new(
				0,
				0,
				1,
				-25
			),
			UDim2.new(
				1,
				0,
				0,
				22
			),
			8,
			12,
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

		Header = header,
		Content = content,

		TitleLabel = title,
		SubtitleLabel = subtitle,

		CashContainer = cashContainer,
		CashLabel = cashLabel,

		CloseButton = closeButton,

		StatisticsPanel = statisticsPanel,
		UpgradeList = upgradeList,

		StatusLabel = statusLabel,
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


	local horizontalMargin =
		shortLandscape
		and 30
		or narrow
			and 24
			or 70

	local verticalReserve =
		shortLandscape
		and 82
		or touchDevice
			and 64
			or 70


	local panelWidth =
		math.min(
			shortLandscape
				and 720
				or 960,
			math.max(
				300,
				viewport.X
					- horizontalMargin
			)
		)

	local panelHeight =
		math.min(
			touchDevice
				and 650
				or 700,
			math.max(
				260,
				viewport.Y
					- verticalReserve
			)
		)

	interface.Panel.Size =
		UDim2.fromOffset(
			panelWidth,
			panelHeight
		)


	local headerHeight: number

	if shortLandscape then
		headerHeight = 56
	elseif narrow then
		headerHeight = 108
	else
		headerHeight = 86
	end


	interface.Header.Size =
		UDim2.new(
			1,
			0,
			0,
			headerHeight
		)

	interface.Content.Position =
		UDim2.fromOffset(
			0,
			headerHeight
		)

	interface.Content.Size =
		UDim2.new(
			1,
			0,
			1,
			-headerHeight
		)


	if shortLandscape then
		interface.TitleLabel.Position =
			UDim2.fromOffset(
				18,
				13
			)

		interface.TitleLabel.Size =
			UDim2.new(
				1,
				-250,
				0,
				28
			)

		interface.SubtitleLabel.Visible =
			false

		interface.CashContainer.Position =
			UDim2.new(
				1,
				-69,
				0.5,
				0
			)

		interface.CashContainer.Size =
			UDim2.fromOffset(
				142,
				38
			)

		interface.CloseButton.Position =
			UDim2.new(
				1,
				-12,
				0.5,
				0
			)

		interface.CloseButton.Size =
			UDim2.fromOffset(
				42,
				42
			)

	elseif narrow then
		interface.TitleLabel.Position =
			UDim2.fromOffset(
				16,
				10
			)

		interface.TitleLabel.Size =
			UDim2.new(
				1,
				-78,
				0,
				25
			)

		interface.SubtitleLabel.Visible =
			true

		interface.SubtitleLabel.Position =
			UDim2.fromOffset(
				16,
				35
			)

		interface.SubtitleLabel.Size =
			UDim2.new(
				1,
				-32,
				0,
				22
			)

		interface.CashContainer.AnchorPoint =
			Vector2.new(
				0,
				0
			)

		interface.CashContainer.Position =
			UDim2.fromOffset(
				16,
				64
			)

		interface.CashContainer.Size =
			UDim2.fromOffset(
				144,
				36
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
				26,
				14
			)

		interface.TitleLabel.Size =
			UDim2.new(
				1,
				-310,
				0,
				30
			)

		interface.SubtitleLabel.Visible =
			true

		interface.SubtitleLabel.Position =
			UDim2.fromOffset(
				26,
				44
			)

		interface.SubtitleLabel.Size =
			UDim2.new(
				1,
				-310,
				0,
				22
			)

		interface.CashContainer.AnchorPoint =
			Vector2.new(
				1,
				0.5
			)

		interface.CashContainer.Position =
			UDim2.new(
				1,
				-82,
				0.5,
				0
			)

		interface.CashContainer.Size =
			UDim2.fromOffset(
				170,
				44
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


	local statsHeight =
		shortLandscape
		and 62
		or 64

	local statusHeight =
		shortLandscape
		and 20
		or 24

	interface.StatisticsPanel.Size =
		UDim2.new(
			1,
			0,
			0,
			statsHeight
		)

	interface.UpgradeList.Position =
		UDim2.fromOffset(
			0,
			statsHeight + 7
		)

	interface.UpgradeList.Size =
		UDim2.new(
			1,
			0,
			1,
			-(
				statsHeight
				+ statusHeight
				+ 16
			)
		)

	interface.StatusLabel.Position =
		UDim2.new(
			0,
			0,
			1,
			-statusHeight
		)

	interface.StatusLabel.Size =
		UDim2.new(
			1,
			0,
			0,
			statusHeight
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


	panelTween.Completed:Once(
		function()
			if menuOpen then
				return
			end

			interface.Overlay.Visible =
				false

			selectedStand = nil
			selectedBusinessId = nil
		end
	)
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

	task.delay(
		4,
		function()
			if statusVersion
					== currentVersion then

				interface.StatusLabel.Text =
					""
			end
		end
	)
end


local function updateStatistics()
	if not selectedStand
		or not selectedStand.Parent then

		for _, label in
			statisticLabels
		do
			label.Text =
				"--"
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
			math.floor(
				lifetimeEarnings
			)
		)

	statisticLabels.CustomersWaiting.Text =
		string.format(
			"%d",
			math.floor(
				customersWaiting
			)
		)

	statisticLabels.ServiceTime.Text =
		string.format(
			"%.2fs",
			serviceTime
		)

	statisticLabels.CashPerSale.Text =
		string.format(
			"$%d",
			math.floor(
				cashPerSale
			)
		)
end


local function setCardButtonState(
	card: UpgradeCard,
	text: string,
	enabled: boolean,
	topColor: Color3,
	bottomColor: Color3
)
	card.PurchaseButton.Text =
		text

	UITheme.SetButtonEnabled(
		card.PurchaseButton,
		enabled,
		topColor,
		bottomColor
	)

	card.PurchaseButton.TextColor3 =
		Color3.fromRGB(
			255,
			255,
			255
		)

	card.PurchaseButton.TextTransparency =
		0
end


local function updateAppearanceCard()
	local card =
		appearanceCard

	if not card then
		return
	end

	if not selectedStand
		or not selectedStand.Parent then

		card.LevelLabel.Text =
			"-- / --"

		card.ValueLabel.Text =
			"--"

		card.ProgressFill.Size =
			UDim2.fromScale(
				0,
				1
			)

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
		getAppearanceConfig(
			currentLevel
		)

	local nextConfig =
		getAppearanceConfig(
			currentLevel + 1
		)


	card.LevelLabel.Text =
		`{currentLevel} / {maximumLevel}`

	card.ValueCaption.Text =
		"NEXT DESIGN"


	if nextConfig
		and typeof(
			nextConfig.TemplateName
		) == "string" then

		card.ValueLabel.Text =
			`LEVEL {currentLevel + 1}`
	else
		card.ValueLabel.Text =
			"COMPLETE"
	end


	local progress =
		math.clamp(
			currentLevel
				/ math.max(
					maximumLevel,
					1
				),
			0,
			1
		)

	card.ProgressFill.Size =
		UDim2.fromScale(
			progress,
			1
		)


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

		card.LevelLabel.Text =
			"-- / --"

		card.ValueLabel.Text =
			"--"

		card.ProgressFill.Size =
			UDim2.fromScale(
				0,
				1
			)

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


	if upgradeName
			== "ServingSpeed" then

		card.ValueCaption.Text =
			"SERVICE TIME"

		card.ValueLabel.Text =
			state.CurrentCooldown
			and string.format(
				"%.2fs",
				state.CurrentCooldown
			)
			or "--"

	elseif upgradeName
			== "SaleValue" then

		card.ValueCaption.Text =
			"CASH PER SALE"

		card.ValueLabel.Text =
			state.CurrentSaleValue
			and string.format(
				"$%d",
				state.CurrentSaleValue
			)
			or "--"

	elseif upgradeName
			== "QueueCapacity" then

		card.ValueCaption.Text =
			"QUEUE SIZE"

		local capacity =
			state.CurrentQueueCapacity

		if typeof(capacity)
				== "number" then

			local roundedCapacity =
				math.max(
					1,
					math.floor(
						capacity
					)
				)

			if roundedCapacity == 1 then
				card.ValueLabel.Text =
					"1 CUSTOMER"
			else
				card.ValueLabel.Text =
					`{roundedCapacity} CUSTOMERS`
			end
		else
			card.ValueLabel.Text =
				"--"
		end
	end


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


	card.ProgressFill.Size =
		UDim2.fromScale(
			progress,
			1
		)


	if currentLevel
			>= maximumLevel then

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

			UpgradeName =
				upgradeName,
		})

		return
	end


	local requestedBusinessId =
		selectedBusinessId


	local success, result =
		pcall(function()
			return getUpgradeStateRemote
				:InvokeServer(
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

			UpgradeName =
				upgradeName,
		})

		return
	end


	if result.BusinessId
		and result.BusinessId
			~= selectedBusinessId then

		return
	end


	updateGameplayCard(
		result
	)
end


local function refreshGameplayCards()
	for _, upgradeName in
		GAMEPLAY_UPGRADE_ORDER
	do
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

	selectedStand =
		replacement

	return true
end


if appearanceCard then
	appearanceCard
		.PurchaseButton
		.Activated:Connect(
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

				requestAppearanceUpgradeRemote
					:FireServer(
						selectedStand
					)
			end
		)
end


for upgradeName, card in
	cards
do
	card.PurchaseButton
		.Activated:Connect(
			function()
				if requestPending
					or not card
						.PurchaseButton.Active
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

				purchaseUpgradeRemote
					:FireServer(
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

	if not selectStandByBusinessId(
		businessId
	) or not selectedBusinessId then

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


	requestPending =
		nil

	menuOpen =
		true

	updateResponsiveLayout()

	interface.Overlay.Visible =
		true

	interface.Overlay.BackgroundTransparency =
		1

	interface.PanelScale.Scale =
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
		if typeof(businessId)
				~= "string" then

			return
		end

		openUpgradeMenuForStand(
			businessId
		)
	end
)


interface.CloseButton
	.Activated:Connect(
		closeUpgradeMenu
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

			closeUpgradeMenu()
		end
	end
)


upgradeResultRemote.OnClientEvent:Connect(
	function(
		result: GameplayUpgradeState
	)
		if result.BusinessId
			and selectedBusinessId
			and result.BusinessId
				~= selectedBusinessId then

			return
		end


		requestPending =
			nil

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
		if requestPending
				~= "StandAppearance" then

			return
		end


		requestPending =
			nil


		if success then
			task.defer(function()
				local startedAt =
					time()

				while time()
						- startedAt < 3 do

					if reconnectSelectedStand() then
						updateStatistics()
						refreshAllCards()
						return
					end

					task.wait(
						0.05
					)
				end


				closeUpgradeMenu()

				selectedStand =
					nil

				selectedBusinessId =
					nil

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
	player:WaitForChild(
		"leaderstats"
	)

local cash =
	leaderstats:WaitForChild(
		"Cash"
	)


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

					requestPending =
						nil

					selectedStand =
						nil

					selectedBusinessId =
						nil
				end
			end
		end

		task.wait(
			0.25
		)
	end
end)