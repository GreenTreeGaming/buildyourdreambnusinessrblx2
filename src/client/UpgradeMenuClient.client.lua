local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

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

local function addCorner(
	instance: GuiObject,
	radius: number
)
	local corner = Instance.new("UICorner")
	corner.CornerRadius =
		UDim.new(0, radius)
	corner.Parent = instance
end

local function addStroke(
	instance: GuiObject,
	thickness: number
)
	local stroke = Instance.new("UIStroke")
	stroke.Color =
		Color3.fromRGB(72, 77, 90)
	stroke.Thickness = thickness
	stroke.Parent = instance
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
	screenGui.Parent = playerGui

	local openButton =
		Instance.new("TextButton")

	openButton.Name = "OpenButton"
	openButton.AnchorPoint =
		Vector2.new(1, 0.5)

	openButton.Position =
		UDim2.new(1, -25, 0.5, 0)

	openButton.Size =
		UDim2.fromOffset(155, 52)

	openButton.BackgroundColor3 =
		Color3.fromRGB(255, 183, 55)

	openButton.BorderSizePixel = 0
	openButton.Text = "Upgrades"
	openButton.TextColor3 =
		Color3.fromRGB(35, 30, 20)

	openButton.Font =
		Enum.Font.GothamBold

	openButton.TextSize = 17
	openButton.Parent = screenGui

	addCorner(openButton, 10)

	local panel = Instance.new("Frame")
	panel.Name = "Panel"
	panel.AnchorPoint =
		Vector2.new(0.5, 0.5)

	panel.Position =
		UDim2.fromScale(0.5, 0.5)

	panel.Size =
		UDim2.fromOffset(430, 330)

	panel.BackgroundColor3 =
		Color3.fromRGB(30, 32, 38)

	panel.BorderSizePixel = 0
	panel.Visible = false
	panel.Parent = screenGui

	addCorner(panel, 14)
	addStroke(panel, 1.5)

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.Position =
		UDim2.fromOffset(20, 15)

	title.Size =
		UDim2.new(1, -75, 0, 38)

	title.BackgroundTransparency = 1
	title.Text = "Lemonade Stand Upgrades"
	title.TextColor3 =
		Color3.fromRGB(255, 255, 255)

	title.Font =
		Enum.Font.GothamBold

	title.TextSize = 21
	title.TextXAlignment =
		Enum.TextXAlignment.Left

	title.Parent = panel

	local closeButton =
		Instance.new("TextButton")

	closeButton.Name = "CloseButton"
	closeButton.AnchorPoint =
		Vector2.new(1, 0)

	closeButton.Position =
		UDim2.new(1, -15, 0, 15)

	closeButton.Size =
		UDim2.fromOffset(38, 38)

	closeButton.BackgroundColor3 =
		Color3.fromRGB(64, 67, 76)

	closeButton.BorderSizePixel = 0
	closeButton.Text = "×"
	closeButton.TextColor3 =
		Color3.fromRGB(255, 255, 255)

	closeButton.Font =
		Enum.Font.GothamBold

	closeButton.TextSize = 25
	closeButton.Parent = panel

	addCorner(closeButton, 8)

	local upgradeCard =
		Instance.new("Frame")

	upgradeCard.Name = "ServingSpeedCard"
	upgradeCard.Position =
		UDim2.fromOffset(20, 70)

	upgradeCard.Size =
		UDim2.new(1, -40, 0, 185)

	upgradeCard.BackgroundColor3 =
		Color3.fromRGB(42, 45, 53)

	upgradeCard.BorderSizePixel = 0
	upgradeCard.Parent = panel

	addCorner(upgradeCard, 11)

	local upgradeTitle =
		Instance.new("TextLabel")

	upgradeTitle.Name = "UpgradeTitle"
	upgradeTitle.Position =
		UDim2.fromOffset(16, 13)

	upgradeTitle.Size =
		UDim2.new(1, -32, 0, 30)

	upgradeTitle.BackgroundTransparency = 1
	upgradeTitle.Text = "Faster Service"
	upgradeTitle.TextColor3 =
		Color3.fromRGB(255, 255, 255)

	upgradeTitle.Font =
		Enum.Font.GothamBold

	upgradeTitle.TextSize = 19
	upgradeTitle.TextXAlignment =
		Enum.TextXAlignment.Left

	upgradeTitle.Parent = upgradeCard

	local description =
		Instance.new("TextLabel")

	description.Name = "Description"
	description.Position =
		UDim2.fromOffset(16, 45)

	description.Size =
		UDim2.new(1, -32, 0, 35)

	description.BackgroundTransparency = 1
	description.Text =
		"Reduces how long each customer takes to purchase lemonade."

	description.TextWrapped = true
	description.TextColor3 =
		Color3.fromRGB(195, 200, 212)

	description.Font =
		Enum.Font.Gotham

	description.TextSize = 14
	description.TextXAlignment =
		Enum.TextXAlignment.Left

	description.Parent = upgradeCard

	local levelLabel =
		Instance.new("TextLabel")

	levelLabel.Name = "LevelLabel"
	levelLabel.Position =
		UDim2.fromOffset(16, 86)

	levelLabel.Size =
		UDim2.new(0.5, -20, 0, 26)

	levelLabel.BackgroundTransparency = 1
	levelLabel.Text = "Level: --"
	levelLabel.TextColor3 =
		Color3.fromRGB(225, 228, 235)

	levelLabel.Font =
		Enum.Font.GothamSemibold

	levelLabel.TextSize = 15
	levelLabel.TextXAlignment =
		Enum.TextXAlignment.Left

	levelLabel.Parent = upgradeCard

	local cooldownLabel =
		Instance.new("TextLabel")

	cooldownLabel.Name = "CooldownLabel"
	cooldownLabel.Position =
		UDim2.new(0.5, 5, 0, 86)

	cooldownLabel.Size =
		UDim2.new(0.5, -21, 0, 26)

	cooldownLabel.BackgroundTransparency = 1
	cooldownLabel.Text = "Service time: --"
	cooldownLabel.TextColor3 =
		Color3.fromRGB(225, 228, 235)

	cooldownLabel.Font =
		Enum.Font.GothamSemibold

	cooldownLabel.TextSize = 15
	cooldownLabel.TextXAlignment =
		Enum.TextXAlignment.Right

	cooldownLabel.Parent = upgradeCard

	local purchaseButton =
		Instance.new("TextButton")

	purchaseButton.Name = "PurchaseButton"
	purchaseButton.Position =
		UDim2.fromOffset(16, 126)

	purchaseButton.Size =
		UDim2.new(1, -32, 0, 44)

	purchaseButton.BackgroundColor3 =
		Color3.fromRGB(85, 210, 105)

	purchaseButton.BorderSizePixel = 0
	purchaseButton.Text = "Loading..."
	purchaseButton.TextColor3 =
		Color3.fromRGB(255, 255, 255)

	purchaseButton.Font =
		Enum.Font.GothamBold

	purchaseButton.TextSize = 16
	purchaseButton.AutoButtonColor = true
	purchaseButton.Parent = upgradeCard

	addCorner(purchaseButton, 9)

	local statusLabel =
		Instance.new("TextLabel")

	statusLabel.Name = "StatusLabel"
	statusLabel.Position =
		UDim2.fromOffset(20, 268)

	statusLabel.Size =
		UDim2.new(1, -40, 0, 42)

	statusLabel.BackgroundTransparency = 1
	statusLabel.Text = ""
	statusLabel.TextWrapped = true
	statusLabel.TextColor3 =
		Color3.fromRGB(220, 223, 232)

	statusLabel.Font =
		Enum.Font.GothamSemibold

	statusLabel.TextSize = 14
	statusLabel.Parent = panel

	return {
		ScreenGui = screenGui,
		OpenButton = openButton,
		Panel = panel,
		CloseButton = closeButton,

		LevelLabel = levelLabel,
		CooldownLabel = cooldownLabel,
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

	local currentVersion =
		statusVersion

	interface.StatusLabel.Text = message

	interface.StatusLabel.TextColor3 =
		isError
		and Color3.fromRGB(255, 115, 115)
		or Color3.fromRGB(130, 235, 145)

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
		interface.LevelLabel.Text =
			"Level: --"

		interface.CooldownLabel.Text =
			"Service time: --"

		interface.PurchaseButton.Text =
			"Unavailable"

		interface.PurchaseButton.Active = false
		interface.PurchaseButton.AutoButtonColor = false

		interface.PurchaseButton.BackgroundColor3 =
			Color3.fromRGB(90, 92, 100)

		showStatus(
			state.Message,
			true
		)

		return
	end

	local currentLevel =
		state.CurrentLevel or 0

	local maximumLevel =
		state.MaximumLevel or 0

	interface.LevelLabel.Text =
		`Level: {currentLevel}/{maximumLevel}`

	if state.CurrentCooldown then
		interface.CooldownLabel.Text =
			string.format(
				"Service time: %.2fs",
				state.CurrentCooldown
			)
	else
		interface.CooldownLabel.Text =
			"Service time: --"
	end

	if currentLevel >= maximumLevel then
		interface.PurchaseButton.Text =
			"Maximum Level"

		interface.PurchaseButton.Active = false
		interface.PurchaseButton.AutoButtonColor = false

		interface.PurchaseButton.BackgroundColor3 =
			Color3.fromRGB(90, 92, 100)

		return
	end

	interface.PurchaseButton.Text =
		`Upgrade for ${state.NextCost or 0}`

	interface.PurchaseButton.Active =
		not requestPending

	interface.PurchaseButton.AutoButtonColor =
		not requestPending

	interface.PurchaseButton.BackgroundColor3 =
		requestPending
		and Color3.fromRGB(90, 92, 100)
		or Color3.fromRGB(85, 210, 105)
end

local function requestUpgradeState()
	local success, result =
		pcall(function()
			return getUpgradeStateRemote:InvokeServer(
				BUSINESS_NAME,
				UPGRADE_NAME
			)
		end)

	if not success then
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
	interface.Panel.Visible = true
	requestUpgradeState()
end)

interface.CloseButton.Activated:Connect(function()
	interface.Panel.Visible = false
end)

interface.PurchaseButton.Activated:Connect(function()
	if requestPending
		or not interface.PurchaseButton.Active then

		return
	end

	requestPending = true

	interface.PurchaseButton.Text =
		"Purchasing..."

	interface.PurchaseButton.Active = false
	interface.PurchaseButton.AutoButtonColor = false
	interface.PurchaseButton.BackgroundColor3 =
		Color3.fromRGB(90, 92, 100)

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

cash:GetPropertyChangedSignal("Value"):Connect(function()
	if interface.Panel.Visible then
		requestUpgradeState()
	end
end)