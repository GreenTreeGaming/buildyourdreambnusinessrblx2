local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local plotsFolder =
	Workspace:WaitForChild("Plots")

local remotes =
	ReplicatedStorage:WaitForChild("Remotes")

local requestUpgradeRemote =
	remotes:WaitForChild("RequestBusinessUpgrade")

local upgradeResultRemote =
	remotes:WaitForChild("BusinessUpgradeResult")

local BUSINESS_NAME = "LemonadeStand"
local MANAGEMENT_DISTANCE = 14
local UPDATE_INTERVAL = 0.1

-- Keep these synchronized with BusinessConfig.
-- These are display-only. The server remains authoritative.
local DISPLAY_LEVELS = {
	[1] = {
		UpgradeCost = 50,
		Description = "Upgrade the stand's appearance.",
	},

	[2] = {
		Description = "Level 2 appearance unlocked.",
	},
}

local currentStand: Model? = nil
local upgradeGui: BillboardGui? = nil
local upgradePending = false

local function getOwnedPlot(): Model?
	local plotName = player:GetAttribute("PlotName")

	if typeof(plotName) == "string" then
		local plot =
			plotsFolder:FindFirstChild(plotName)

		if plot
			and plot:IsA("Model")
			and plot:GetAttribute("OwnerUserId")
				== player.UserId then

			return plot
		end
	end

	for _, instance in plotsFolder:GetChildren() do
		if instance:IsA("Model")
			and instance:GetAttribute("OwnerUserId")
				== player.UserId then

			return instance
		end
	end

	return nil
end

local function getOwnedStand(): Model?
	local plot = getOwnedPlot()

	if not plot then
		return nil
	end

	local placedBusinesses =
		plot:FindFirstChild("PlacedBusinesses")

	if not placedBusinesses then
		return nil
	end

	local stand =
		placedBusinesses:FindFirstChild(BUSINESS_NAME)

	if not stand or not stand:IsA("Model") then
		return nil
	end

	if stand:GetAttribute("OwnerUserId")
		~= player.UserId then

		return nil
	end

	return stand
end

local function getCharacterRoot(): BasePart?
	local character = player.Character

	if not character then
		return nil
	end

	local root =
		character:FindFirstChild("HumanoidRootPart")

	if root and root:IsA("BasePart") then
		return root
	end

	return nil
end

local function getAdornee(
	stand: Model
): BasePart?
	local position =
		stand:FindFirstChild(
			"ManagementUIPosition",
			true
		)

	if position and position:IsA("BasePart") then
		return position
	end

	if stand.PrimaryPart then
		return stand.PrimaryPart
	end

	return stand:FindFirstChildWhichIsA(
		"BasePart",
		true
	)
end

local function addCorner(
	parent: Instance,
	radius: number
)
	local corner = Instance.new("UICorner")
	corner.CornerRadius =
		UDim.new(0, radius)

	corner.Parent = parent
end

local function addStroke(
	parent: Instance,
	thickness: number
)
	local stroke = Instance.new("UIStroke")
	stroke.Color =
		Color3.fromRGB(25, 28, 32)

	stroke.Thickness = thickness
	stroke.Transparency = 0.15
	stroke.Parent = parent
end

local function destroyUpgradeGui()
	if upgradeGui then
		upgradeGui:Destroy()
		upgradeGui = nil
	end

	currentStand = nil
	upgradePending = false
end

local function getLevel(
	stand: Model
): number
	local value = stand:GetAttribute("Level")

	if typeof(value) ~= "number" then
		return 1
	end

	return math.max(
		1,
		math.floor(value)
	)
end

local function createUpgradeGui(
	stand: Model
)
	destroyUpgradeGui()

	local adornee = getAdornee(stand)

	if not adornee then
		warn(
			"LemonadeStand is missing ManagementUIPosition."
		)

		return
	end

	currentStand = stand

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "BusinessUpgradeUI"
	billboard.Adornee = adornee
	billboard.Size = UDim2.fromOffset(250, 118)

	-- Places this above your existing Edit/Remove UI.
	billboard.StudsOffsetWorldSpace =
		Vector3.new(0, 6.5, 0)

	billboard.AlwaysOnTop = true
	billboard.LightInfluence = 0
	billboard.MaxDistance =
		MANAGEMENT_DISTANCE + 3

	billboard.Active = true
	billboard.Enabled = false
	billboard.ResetOnSpawn = false
	billboard.Parent = playerGui

	local container = Instance.new("Frame")
	container.Name = "Container"
	container.Size = UDim2.fromScale(1, 1)
	container.BackgroundColor3 =
		Color3.fromRGB(31, 35, 40)

	container.BackgroundTransparency = 0.04
	container.BorderSizePixel = 0
	container.Active = true
	container.Parent = billboard

	addCorner(container, 12)
	addStroke(container, 2)

	local levelLabel = Instance.new("TextLabel")
	levelLabel.Name = "LevelLabel"
	levelLabel.Position =
		UDim2.fromOffset(10, 7)

	levelLabel.Size =
		UDim2.new(1, -20, 0, 24)

	levelLabel.BackgroundTransparency = 1
	levelLabel.TextColor3 =
		Color3.fromRGB(255, 255, 255)

	levelLabel.Font = Enum.Font.GothamBold
	levelLabel.TextSize = 17
	levelLabel.TextXAlignment =
		Enum.TextXAlignment.Left

	levelLabel.Parent = container

	local detailsLabel = Instance.new("TextLabel")
	detailsLabel.Name = "DetailsLabel"
	detailsLabel.Position =
		UDim2.fromOffset(10, 31)

	detailsLabel.Size =
		UDim2.new(1, -20, 0, 27)

	detailsLabel.BackgroundTransparency = 1
	detailsLabel.TextColor3 =
		Color3.fromRGB(205, 210, 220)

	detailsLabel.Font = Enum.Font.Gotham
	detailsLabel.TextSize = 13
	detailsLabel.TextXAlignment =
		Enum.TextXAlignment.Left

	detailsLabel.Parent = container

	local upgradeButton = Instance.new("TextButton")
	upgradeButton.Name = "UpgradeButton"
	upgradeButton.Position =
		UDim2.fromOffset(10, 67)

	upgradeButton.Size =
		UDim2.new(1, -20, 0, 40)

	upgradeButton.BackgroundColor3 =
		Color3.fromRGB(50, 185, 90)

	upgradeButton.BorderSizePixel = 0
	upgradeButton.AutoButtonColor = true
	upgradeButton.TextColor3 =
		Color3.fromRGB(255, 255, 255)

	upgradeButton.Font =
		Enum.Font.GothamBold

	upgradeButton.TextSize = 15
	upgradeButton.Active = true
	upgradeButton.Selectable = true
	upgradeButton.Interactable = true
	upgradeButton.Parent = container

	addCorner(upgradeButton, 9)
	addStroke(upgradeButton, 1.5)

	local function refresh()
		if not stand.Parent then
			return
		end

		local level = getLevel(stand)
		local displayConfig =
			DISPLAY_LEVELS[level]

		levelLabel.Text =
			`Lemonade Stand — Level {level}`

		if not displayConfig
			or not displayConfig.UpgradeCost then

			detailsLabel.Text =
	displayConfig.Description

			upgradeButton.Text =
				"MAX LEVEL"

			upgradeButton.BackgroundColor3 =
				Color3.fromRGB(95, 100, 110)

			upgradeButton.Interactable = false
			return
		end

		detailsLabel.Text =
	displayConfig.Description

		upgradeButton.Text = string.format(
			"UPGRADE TO LEVEL %d — $%d",
			level + 1,
			displayConfig.UpgradeCost
		)

		upgradeButton.BackgroundColor3 =
			Color3.fromRGB(50, 185, 90)

		upgradeButton.Interactable =
			not upgradePending
	end

	upgradeButton.MouseButton1Click:Connect(
		function()
			if upgradePending then
				return
			end

			if not stand.Parent then
				return
			end

			upgradePending = true
			upgradeButton.Interactable = false
			upgradeButton.Text = "UPGRADING..."

			requestUpgradeRemote:FireServer()
		end
	)

	stand:GetAttributeChangedSignal("Level"):Connect(
		refresh
	)

	refresh()

	upgradeGui = billboard
end

upgradeResultRemote.OnClientEvent:Connect(
	function(
		success: boolean,
		message: string,
		_level: number?
	)
		upgradePending = false

		if success then
			print(message)
		else
			warn(message)
		end

		-- The upgraded stand is a new model, so the update
		-- loop below will recreate the UI automatically.
	end
)

task.spawn(function()
	while true do
		local stand = getOwnedStand()

		if stand ~= currentStand then
			if stand then
				createUpgradeGui(stand)
			else
				destroyUpgradeGui()
			end
		end

		local root = getCharacterRoot()

		if upgradeGui
			and currentStand
			and currentStand.Parent
			and root then

			local distance =
				(
					root.Position
					- currentStand:GetPivot().Position
				).Magnitude

			local canShow =
				distance <= MANAGEMENT_DISTANCE
				and player:GetAttribute(
					"EditingBusiness"
				) == nil

			upgradeGui.Enabled = canShow
		elseif upgradeGui then
			upgradeGui.Enabled = false
		end

		task.wait(UPDATE_INTERVAL)
	end
end)