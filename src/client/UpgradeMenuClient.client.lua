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
local UPGRADE_NAME = "ServingSpeed"

local requestPending = false
local statusVersion = 0

type UpgradeState = {
	Success: boolean,
	Message: string,

	CurrentLevel: number?,
	MaximumLevel: number?,

	NextCost: number?,
	CurrentCooldown: number?,
}

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

local function createInterface()
	local existing =
		playerGui:FindFirstChild("UpgradeMenu")

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

openButton.TextColor3 = Colors.Text
openButton.TextTransparency = 0

local openGradient =
	openButton:FindFirstChildOfClass("UIGradient")

if openGradient then
	openGradient:Destroy()
end

openButton.BackgroundColor3 =
	Colors.Primary

openButton.TextColor3 =
	Color3.fromRGB(255, 255, 255)

openButton.TextTransparency = 0

	local overlay = Instance.new("Frame")
	overlay.Name = "Overlay"
	overlay.Size = UDim2.fromScale(1, 1)
	overlay.BackgroundColor3 =
	Colors.Background

overlay.BackgroundTransparency = 1
	overlay.BorderSizePixel = 0
	overlay.Visible = false
	overlay.Active = true
	overlay.Parent = screenGui

	local panelShadow = Instance.new("Frame")
	panelShadow.Name = "PanelShadow"
	panelShadow.AnchorPoint =
		Vector2.new(0.5, 0.5)

	panelShadow.Position =
		UDim2.fromScale(0.505, 0.515)

	panelShadow.Size =
		UDim2.fromScale(0.47, 0.64)

	panelShadow.BackgroundColor3 =
		Colors.Shadow

	panelShadow.BackgroundTransparency = 0.25
	panelShadow.BorderSizePixel = 0
	panelShadow.Parent = overlay

	UITheme.AddCorner(panelShadow, 0.06)

	local panel = Instance.new("Frame")
	panel.Name = "Panel"
	panel.AnchorPoint =
		Vector2.new(0.5, 0.5)

	panel.Position =
		UDim2.fromScale(0.5, 0.5)

	panel.Size =
		UDim2.fromScale(0.47, 0.64)

	panel.BackgroundColor3 =
		Colors.Surface

	panel.BorderSizePixel = 0
	panel.Parent = overlay

	UITheme.AddCorner(panel, 0.06)

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
		UDim2.fromScale(0.045, 0.04)

	header.Size =
		UDim2.fromScale(0.91, 0.17)

	header.BackgroundTransparency = 1
	header.Parent = panel

	local title = createTextLabel(
	header,
	"Title",
	"LEMONADE UPGRADES",
	UDim2.fromScale(0, 0.05),
	UDim2.fromScale(0.8, 0.42),
	15,
	25,
	Fonts.Black,
	Colors.Text
)

	local subtitle = createTextLabel(
	header,
	"Subtitle",
	"Grow faster and serve more customers.",
	UDim2.fromScale(0, 0.5),
	UDim2.fromScale(0.8, 0.3),
	10,
	15,
	Fonts.Medium,
	Colors.Text
)

	local closeButton =
		Instance.new("TextButton")

	closeButton.Name = "CloseButton"
	closeButton.AnchorPoint =
		Vector2.new(1, 0)

	closeButton.Position =
		UDim2.fromScale(1, 0.08)

	closeButton.Size =
		UDim2.fromScale(0.11, 0.64)

	closeButton.Text = "×"
	closeButton.Parent = header

	closeButton.TextColor3 = Colors.Text
closeButton.TextTransparency = 0

	UITheme.StyleText(
		closeButton,
		18,
		28,
		Colors.Text,
		Fonts.Bold
	)

	UITheme.StyleButton(
		closeButton,
		Colors.SurfaceLight,
		Colors.SurfaceRaised
	)

	closeButton.TextColor3 =
	Color3.fromRGB(255, 255, 255)

closeButton.TextTransparency = 0
closeButton.TextStrokeTransparency = 1

	local card = Instance.new("Frame")
	card.Name = "ServingSpeedCard"
	card.Position =
		UDim2.fromScale(0.045, 0.23)

	card.Size =
		UDim2.fromScale(0.91, 0.59)

	card.BackgroundColor3 =
		Colors.SurfaceRaised

	card.BorderSizePixel = 0
	card.Parent = panel

	UITheme.AddCorner(card, 0.06)

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

	local upgradeTitle = createTextLabel(
	card,
	"UpgradeTitle",
	"FASTER SERVICE",
	UDim2.fromScale(0.05, 0.06),
	UDim2.fromScale(0.6, 0.095),
	14,
	22,
	Fonts.Black,
	Colors.Text
)

	local cashLabel = createTextLabel(
	card,
	"CashLabel",
	"CASH  $0",
	UDim2.fromScale(0.71, 0.07),
	UDim2.fromScale(0.24, 0.08),
	11,
	16,
	Fonts.Bold,
	Colors.Primary
)

cashLabel.TextXAlignment =
	Enum.TextXAlignment.Right

	local description = createTextLabel(
	card,
	"Description",
	"Reduce the time each customer spends at the counter.",
	UDim2.fromScale(0.05, 0.16),
	UDim2.fromScale(0.68, 0.1),
	10,
	15,
	Fonts.Medium,
	Colors.Text
)

	local statRow = Instance.new("Frame")
	statRow.Name = "Stats"
	statRow.Position =
		UDim2.fromScale(0.05, 0.31)

	statRow.Size =
		UDim2.fromScale(0.9, 0.22)

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

	statLayout.Padding = UDim.new(0.04, 0)
	statLayout.Parent = statRow

	local levelCard = Instance.new("Frame")
	levelCard.Name = "LevelCard"
	levelCard.Size =
		UDim2.fromScale(0.48, 1)

	levelCard.BackgroundColor3 =
		Colors.Background

	levelCard.BackgroundTransparency = 0.2
	levelCard.BorderSizePixel = 0
	levelCard.Parent = statRow

	UITheme.AddCorner(levelCard, 0.12)
	UITheme.AddStroke(levelCard, Colors.Stroke, 1, 0.45)

	local levelCaption = createTextLabel(
		levelCard,
		"Caption",
		"CURRENT LEVEL",
		UDim2.fromScale(0.08, 0.1),
		UDim2.fromScale(0.84, 0.3),
		9,
		13,
		Fonts.Bold,
		Colors.TextMuted
	)

	levelCaption.TextXAlignment =
		Enum.TextXAlignment.Center

	local levelLabel = createTextLabel(
		levelCard,
		"LevelLabel",
		"-- / --",
		UDim2.fromScale(0.08, 0.45),
		UDim2.fromScale(0.84, 0.4),
		14,
		23,
		Fonts.Black,
		Colors.Text
	)

	levelLabel.TextXAlignment =
		Enum.TextXAlignment.Center

	local speedCard = Instance.new("Frame")
	speedCard.Name = "SpeedCard"
	speedCard.Size =
		UDim2.fromScale(0.48, 1)

	speedCard.BackgroundColor3 =
		Colors.Background

	speedCard.BackgroundTransparency = 0.2
	speedCard.BorderSizePixel = 0
	speedCard.Parent = statRow

	UITheme.AddCorner(speedCard, 0.12)
	UITheme.AddStroke(speedCard, Colors.Stroke, 1, 0.45)

	local speedCaption = createTextLabel(
		speedCard,
		"Caption",
		"SERVICE TIME",
		UDim2.fromScale(0.08, 0.1),
		UDim2.fromScale(0.84, 0.3),
		9,
		13,
		Fonts.Bold,
		Colors.TextMuted
	)

	speedCaption.TextXAlignment =
		Enum.TextXAlignment.Center

	local cooldownLabel = createTextLabel(
		speedCard,
		"CooldownLabel",
		"--",
		UDim2.fromScale(0.08, 0.45),
		UDim2.fromScale(0.84, 0.4),
		14,
		23,
		Fonts.Black,
		Colors.Success
	)

	cooldownLabel.TextXAlignment =
		Enum.TextXAlignment.Center

	local progressCaption = createTextLabel(
		card,
		"ProgressCaption",
		"UPGRADE PROGRESS",
		UDim2.fromScale(0.05, 0.57),
		UDim2.fromScale(0.9, 0.07),
		9,
		13,
		Fonts.Bold,
		Colors.TextMuted
	)

	local progressTrack = Instance.new("Frame")
	progressTrack.Name = "ProgressTrack"
	progressTrack.Position =
		UDim2.fromScale(0.05, 0.66)

	progressTrack.Size =
		UDim2.fromScale(0.9, 0.07)

	progressTrack.BackgroundColor3 =
		Colors.ProgressTrack

	progressTrack.BorderSizePixel = 0
	progressTrack.ClipsDescendants = true
	progressTrack.Parent = card

	UITheme.AddCorner(progressTrack, 0.5)

	local progressFill = Instance.new("Frame")
	progressFill.Name = "ProgressFill"
	progressFill.Size =
		UDim2.fromScale(0, 1)

	progressFill.BackgroundColor3 =
		Colors.Primary

	progressFill.BorderSizePixel = 0
	progressFill.Parent = progressTrack

	UITheme.AddCorner(progressFill, 0.5)

	UITheme.AddGradient(
		progressFill,
		Colors.Primary,
		Colors.Success,
		0
	)

	local purchaseButton =
		Instance.new("TextButton")

	purchaseButton.Name = "PurchaseButton"
	purchaseButton.Position =
		UDim2.fromScale(0.05, 0.78)

	purchaseButton.Size =
		UDim2.fromScale(0.9, 0.16)

	purchaseButton.Text = "LOADING..."
	purchaseButton.Parent = card

	UITheme.StyleText(
		purchaseButton,
		12,
		19,
		Colors.Text,
		Fonts.Black
	)

	UITheme.StyleButton(
		purchaseButton,
		Colors.Success,
		Colors.SuccessDark
	)

	local statusLabel = createTextLabel(
		panel,
		"StatusLabel",
		"",
		UDim2.fromScale(0.06, 0.85),
		UDim2.fromScale(0.88, 0.1),
		10,
		15,
		Fonts.Semibold,
		Colors.TextMuted
	)

	statusLabel.TextXAlignment =
		Enum.TextXAlignment.Center

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
	panel.Size =
		UDim2.fromScale(0.92, 0.68)

	panelShadow.Size =
		UDim2.fromScale(0.92, 0.68)

	openButton.Size =
		UDim2.fromScale(0.2, 0.06)

	openButton.Position =
		UDim2.fromScale(0.025, 0.5)
elseif compact then
	panel.Size =
		UDim2.fromScale(0.7, 0.82)

	panelShadow.Size =
		UDim2.fromScale(0.7, 0.82)

	openButton.Size =
		UDim2.fromScale(0.14, 0.07)

	openButton.Position =
		UDim2.fromScale(0.025, 0.5)
else
	panel.Size =
		UDim2.fromScale(0.47, 0.64)

	panelShadow.Size =
		UDim2.fromScale(0.47, 0.64)

	openButton.Size =
		UDim2.fromScale(0.12, 0.06)

	openButton.Position =
		UDim2.fromScale(0.025, 0.5)
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
		Panel = panel,
		CloseButton = closeButton,

		CashLabel = cashLabel,
		LevelLabel = levelLabel,
		CooldownLabel = cooldownLabel,
		ProgressFill = progressFill,

		PurchaseButton = purchaseButton,
		StatusLabel = statusLabel,
	}
end

local interface = createInterface()

local function showStatus(
	message: string,
	isError: boolean?
)
	statusVersion += 1

	local currentVersion = statusVersion

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

local function updateInterface(
	state: UpgradeState
)
	if not state.Success then
		interface.LevelLabel.Text = "-- / --"
		interface.CooldownLabel.Text = "--"
		interface.ProgressFill.Size =
			UDim2.fromScale(0, 1)

		interface.PurchaseButton.Text =
			"UNAVAILABLE"

		UITheme.SetButtonEnabled(
			interface.PurchaseButton,
			false,
			Colors.Success,
			Colors.SuccessDark
		)

		showStatus(state.Message, true)

		return
	end

	local currentLevel =
		state.CurrentLevel or 0

	local maximumLevel =
		state.MaximumLevel or 0

	interface.LevelLabel.Text =
		`{currentLevel} / {maximumLevel}`

	if state.CurrentCooldown then
		interface.CooldownLabel.Text =
			string.format(
				"%.2fs",
				state.CurrentCooldown
			)
	else
		interface.CooldownLabel.Text = "--"
	end

	local progress = 0

	if maximumLevel > 0 then
		progress = math.clamp(
			currentLevel / maximumLevel,
			0,
			1
		)
	end

	interface.ProgressFill.Size =
		UDim2.fromScale(progress, 1)

	if currentLevel >= maximumLevel then
		interface.PurchaseButton.Text =
			"MAXIMUM LEVEL"

		UITheme.SetButtonEnabled(
			interface.PurchaseButton,
			false,
			Colors.Success,
			Colors.SuccessDark
		)

		return
	end

	interface.PurchaseButton.Text =
		`UPGRADE  •  ${state.NextCost or 0}`

	UITheme.SetButtonEnabled(
		interface.PurchaseButton,
		not requestPending,
		Colors.Success,
		Colors.SuccessDark
	)
end

local function requestUpgradeState()
	local success, result =
		pcall(function()
			return getUpgradeStateRemote:InvokeServer(
				BUSINESS_NAME,
				UPGRADE_NAME
			)
		end)

	if not success
		or type(result) ~= "table" then

		updateInterface({
			Success = false,
			Message =
				"The upgrade server could not be reached.",
		})

		return
	end

	updateInterface(result)
end

interface.OpenButton.Activated:Connect(function()
	interface.Overlay.Visible = true
	interface.OpenButton.Visible = false

	requestUpgradeState()
end)

interface.CloseButton.Activated:Connect(function()
	interface.Overlay.Visible = false
	interface.OpenButton.Visible = true
end)

interface.PurchaseButton.Activated:Connect(function()
	if requestPending
		or not interface.PurchaseButton.Active then

		return
	end

	requestPending = true

	interface.PurchaseButton.Text =
		"PURCHASING..."

	UITheme.SetButtonEnabled(
		interface.PurchaseButton,
		false,
		Colors.Success,
		Colors.SuccessDark
	)

	purchaseUpgradeRemote:FireServer(
		BUSINESS_NAME,
		UPGRADE_NAME
	)
end)

upgradeResultRemote.OnClientEvent:Connect(
	function(result: UpgradeState)
		requestPending = false

		showStatus(
			result.Message,
			not result.Success
		)

		if result.Success then
			updateInterface(result)
		else
			requestUpgradeState()
		end
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

cash:GetPropertyChangedSignal("Value"):Connect(function()
	updateCashLabel()

	if interface.Overlay.Visible then
		requestUpgradeState()
	end
end)