local Players = game:GetService("Players")
local ReplicatedStorage =
	game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local playerGui =
	player:WaitForChild("PlayerGui")

local remotes =
	ReplicatedStorage:WaitForChild("Remotes")

local purchaseUpgradeRemote =
	remotes:WaitForChild("PurchaseUpgrade")

local upgradeResultRemote =
	remotes:WaitForChild("UpgradeResult")

local getUpgradeStateRemote =
	remotes:WaitForChild("GetUpgradeState")

local UITheme = require(
	ReplicatedStorage
		:WaitForChild("Shared")
		:WaitForChild("UITheme")
)

local Colors = UITheme.Colors
local Fonts = UITheme.Fonts

local BUSINESS_NAME = "LemonadeStand"

local UPGRADE_ORDER = {
	"ServingSpeed",
	"SaleValue",
}

type UpgradeState = {
	Success: boolean,
	Message: string,

	BusinessName: string?,
	UpgradeName: string?,
	DisplayName: string?,

	CurrentLevel: number?,
	MaximumLevel: number?,
	NextCost: number?,

	CurrentCooldown: number?,
	CurrentSaleValue: number?,
}

type UpgradeCard = {
	Root: Frame,

	LevelLabel: TextLabel,
	ValueCaption: TextLabel,
	ValueLabel: TextLabel,

	ProgressFill: Frame,
	PurchaseButton: TextButton,
}

local requestPending: string? = nil
local statusVersion = 0

local cards: {
	[string]: UpgradeCard
} = {}

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

local function createUpgradeCard(
	parent: Instance,
	upgradeName: string,
	titleText: string,
	descriptionText: string,
	valueCaptionText: string
): UpgradeCard
	local card = Instance.new("Frame")

	card.Name = upgradeName .. "Card"
	card.Size =
	UDim2.fromScale(0.96, 0.47)

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
		UDim2.fromScale(0.64, 0.1),
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
		UDim2.fromScale(0.68, 0.1),
		9,
		14,
		Fonts.Medium,
		Colors.Text
	)

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
		name: string,
		captionText: string
	): (Frame, TextLabel)
		local box = Instance.new("Frame")

		box.Name = name
		box.Size =
			UDim2.fromScale(0.4825, 1)

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
		Colors.Primary

	progressFill.BorderSizePixel = 0
	progressFill.Parent = progressTrack

	UITheme.AddCorner(
		progressFill,
		0.5
	)

	UITheme.AddGradient(
		progressFill,
		Colors.Primary,
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
		Colors.Success,
		Colors.SuccessDark,
		Colors.Text
	)

	purchaseButton.TextColor3 =
		Color3.fromRGB(255, 255, 255)

	purchaseButton.TextTransparency = 0

	purchaseButton.Activated:Connect(function()
		if requestPending
			or not purchaseButton.Active then

			return
		end

		requestPending = upgradeName

		purchaseButton.Text =
			"PURCHASING..."

		UITheme.SetButtonEnabled(
			purchaseButton,
			false,
			Colors.Success,
			Colors.SuccessDark
		)

		purchaseUpgradeRemote:FireServer(
			BUSINESS_NAME,
			upgradeName
		)
	end)

	return {
		Root = card,

		LevelLabel = levelLabel,
		ValueCaption = valueCaption,
		ValueLabel = valueLabel,

		ProgressFill = progressFill,
		PurchaseButton = purchaseButton,
	}
end

local function createInterface()
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

	local openButton =
		Instance.new("TextButton")

	openButton.Name = "OpenButton"
	openButton.AnchorPoint =
		Vector2.new(0, 0.5)

	openButton.Position =
		UDim2.fromScale(0.025, 0.5)

	openButton.Size =
		UDim2.fromScale(0.12, 0.06)

	openButton.Text = "UPGRADES"
	openButton.Parent = screenGui

	UITheme.StyleText(
		openButton,
		10,
		16,
		Colors.Text,
		Fonts.Black
	)

	UITheme.StyleButton(
		openButton,
		Colors.Primary,
		Colors.PrimaryDark,
		Colors.Text
	)

	openButton.BackgroundColor3 =
		Colors.Primary

	openButton.TextColor3 =
		Color3.fromRGB(255, 255, 255)

	openButton.TextTransparency = 0

	local overlay = Instance.new("Frame")
	overlay.Name = "Overlay"
	overlay.Size =
		UDim2.fromScale(1, 1)

	overlay.BackgroundTransparency = 1
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
		UDim2.fromScale(0.52, 0.78)

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
		UDim2.fromScale(0.52, 0.78)

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
		UDim2.fromScale(0.045, 0.035)

	header.Size =
		UDim2.fromScale(0.91, 0.12)

	header.BackgroundTransparency = 1
	header.Parent = panel

	local title = createTextLabel(
		header,
		"Title",
		"LEMONADE UPGRADES",
		UDim2.fromScale(0, 0),
		UDim2.fromScale(0.78, 0.48),
		14,
		23,
		Fonts.Black,
		Colors.Text
	)

	local subtitle = createTextLabel(
		header,
		"Subtitle",
		"Invest your earnings to grow the stand.",
		UDim2.fromScale(0, 0.5),
		UDim2.fromScale(0.78, 0.34),
		9,
		14,
		Fonts.Medium,
		Colors.Text
	)

	local closeButton =
		Instance.new("TextButton")

	closeButton.Name = "CloseButton"
	closeButton.AnchorPoint =
		Vector2.new(1, 0)

	closeButton.Position =
		UDim2.fromScale(1, 0)

	closeButton.Size =
		UDim2.fromScale(0.1, 0.75)

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

	local cashLabel = createTextLabel(
		header,
		"CashLabel",
		"CASH  $0",
		UDim2.fromScale(0.61, 0.48),
		UDim2.fromScale(0.25, 0.3),
		10,
		15,
		Fonts.Bold,
		Colors.Primary
	)

	cashLabel.TextXAlignment =
		Enum.TextXAlignment.Right

	local scrollingFrame =
		Instance.new("ScrollingFrame")

	scrollingFrame.Name =
		"UpgradeList"

	scrollingFrame.Position =
		UDim2.fromScale(0.045, 0.17)

	scrollingFrame.Size =
		UDim2.fromScale(0.91, 0.72)

	scrollingFrame.BackgroundTransparency = 1
	scrollingFrame.BorderSizePixel = 0

	scrollingFrame.CanvasSize =
		UDim2.fromScale(0, 0)

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
	UDim.new(0.01, 0)

listPadding.PaddingBottom =
	UDim.new(0.02, 0)

listPadding.Parent = scrollingFrame

	local listLayout =
		Instance.new("UIListLayout")

	listLayout.FillDirection =
		Enum.FillDirection.Vertical

	listLayout.HorizontalAlignment =
		Enum.HorizontalAlignment.Center

	listLayout.VerticalAlignment =
		Enum.VerticalAlignment.Top

	listLayout.Padding =
		UDim.new(0.035, 0)

	listLayout.Parent = scrollingFrame

	local servingCard =
		createUpgradeCard(
			scrollingFrame,
			"ServingSpeed",
			"FASTER SERVICE",
			"Reduce how long each customer waits at the counter.",
			"SERVICE TIME"
		)

	local saleValueCard =
		createUpgradeCard(
			scrollingFrame,
			"SaleValue",
			"BETTER LEMONADE",
			"Improve the recipe and earn more from every sale.",
			"CASH PER SALE"
		)

	cards.ServingSpeed =
		servingCard

	cards.SaleValue =
		saleValueCard

	local statusLabel = createTextLabel(
		panel,
		"StatusLabel",
		"",
		UDim2.fromScale(0.06, 0.9),
		UDim2.fromScale(0.88, 0.07),
		9,
		14,
		Fonts.Semibold,
		Colors.Text
	)

	statusLabel.TextXAlignment =
		Enum.TextXAlignment.Center

	local function updateResponsiveLayout()
		local camera = Workspace.CurrentCamera

		if not camera then
			return
		end

		local viewport =
			camera.ViewportSize

		local portrait =
			viewport.Y > viewport.X

		local compact =
			viewport.X < 800
			or viewport.Y < 550

		if portrait then
			panel.Size =
				UDim2.fromScale(0.94, 0.82)

			shadow.Size =
				UDim2.fromScale(0.94, 0.82)

			openButton.Size =
				UDim2.fromScale(0.23, 0.06)
		elseif compact then
			panel.Size =
				UDim2.fromScale(0.72, 0.9)

			shadow.Size =
				UDim2.fromScale(0.72, 0.9)

			openButton.Size =
				UDim2.fromScale(0.16, 0.075)
		else
			panel.Size =
				UDim2.fromScale(0.52, 0.78)

			shadow.Size =
				UDim2.fromScale(0.52, 0.78)

			openButton.Size =
				UDim2.fromScale(0.12, 0.06)
		end
	end

	updateResponsiveLayout()

	local camera = Workspace.CurrentCamera

	if camera then
		camera:GetPropertyChangedSignal(
			"ViewportSize"
		):Connect(updateResponsiveLayout)
	end

	return {
		ScreenGui = screenGui,
		OpenButton = openButton,
		Overlay = overlay,
		CloseButton = closeButton,
		CashLabel = cashLabel,
		StatusLabel = statusLabel,
	}
end

local interface = createInterface()

local function showStatus(
	message: string,
	isError: boolean?
)
	statusVersion += 1

	local currentVersion =
		statusVersion

	interface.StatusLabel.Text = message

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

local function updateCard(
	state: UpgradeState
)
	local upgradeName =
		state.UpgradeName

	if not upgradeName then
		return
	end

	local card = cards[upgradeName]

	if not card then
		return
	end

	if not state.Success
		and state.CurrentLevel == nil then

		card.LevelLabel.Text = "-- / --"
		card.ValueLabel.Text = "--"
		card.ProgressFill.Size =
			UDim2.fromScale(0, 1)

		card.PurchaseButton.Text =
			"UNAVAILABLE"

		UITheme.SetButtonEnabled(
			card.PurchaseButton,
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
	end

	local progress = 0

	if maximumLevel > 0 then
		progress = math.clamp(
			currentLevel / maximumLevel,
			0,
			1
		)
	end

	card.ProgressFill.Size =
		UDim2.fromScale(progress, 1)

	if currentLevel >= maximumLevel then
		card.PurchaseButton.Text =
			"MAXIMUM LEVEL"

		UITheme.SetButtonEnabled(
			card.PurchaseButton,
			false,
			Colors.Success,
			Colors.SuccessDark
		)

		return
	end

	card.PurchaseButton.Text =
		`UPGRADE  •  ${state.NextCost or 0}`

	UITheme.SetButtonEnabled(
		card.PurchaseButton,
		requestPending == nil,
		Colors.Success,
		Colors.SuccessDark
	)

	card.PurchaseButton.TextColor3 =
		Color3.fromRGB(255, 255, 255)

	card.PurchaseButton.TextTransparency = 0
end

local function requestUpgradeState(
	upgradeName: string
)
	local success, result =
		pcall(function()
			return getUpgradeStateRemote:InvokeServer(
				BUSINESS_NAME,
				upgradeName
			)
		end)

	if not success
		or type(result) ~= "table" then

		updateCard({
			Success = false,
			Message =
				"The upgrade server could not be reached.",
			UpgradeName = upgradeName,
		})

		return
	end

	updateCard(result)
end

local function refreshAllCards()
	for _, upgradeName in UPGRADE_ORDER do
		requestUpgradeState(upgradeName)
	end
end

interface.OpenButton.Activated:Connect(function()
	interface.Overlay.Visible = true
	interface.OpenButton.Visible = false

	refreshAllCards()
end)

interface.CloseButton.Activated:Connect(function()
	interface.Overlay.Visible = false
	interface.OpenButton.Visible = true
end)

upgradeResultRemote.OnClientEvent:Connect(function(
	result: UpgradeState
)
	requestPending = nil

	showStatus(
		result.Message,
		not result.Success
	)

	refreshAllCards()
end)

local leaderstats =
	player:WaitForChild("leaderstats")

local cash =
	leaderstats:WaitForChild("Cash")

local function updateCashLabel()
	interface.CashLabel.Text =
		`CASH  ${cash.Value}`
end

updateCashLabel()

cash:GetPropertyChangedSignal("Value"):Connect(function()
	updateCashLabel()

	if interface.Overlay.Visible
		and not requestPending then

		refreshAllCards()
	end
end)