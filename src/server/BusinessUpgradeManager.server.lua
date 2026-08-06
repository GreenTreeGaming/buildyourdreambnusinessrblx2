local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local BusinessConfig = require(
	ReplicatedStorage
		:WaitForChild("Shared")
		:WaitForChild("BusinessConfig")
)

local businessModels =
	ReplicatedStorage:WaitForChild("BusinessModels")

local remotes =
	ReplicatedStorage:WaitForChild("Remotes")

local plotsFolder =
	Workspace:WaitForChild("Plots")

local BUSINESS_NAME = "LemonadeStand"
local REQUEST_COOLDOWN = 0.5
local MANAGEMENT_DISTANCE = 22

local requestUpgradeRemote =
	remotes:FindFirstChild("RequestBusinessUpgrade")

if not requestUpgradeRemote then
	requestUpgradeRemote = Instance.new("RemoteEvent")
	requestUpgradeRemote.Name = "RequestBusinessUpgrade"
	requestUpgradeRemote.Parent = remotes
end

local upgradeResultRemote =
	remotes:FindFirstChild("BusinessUpgradeResult")

if not upgradeResultRemote then
	upgradeResultRemote = Instance.new("RemoteEvent")
	upgradeResultRemote.Name = "BusinessUpgradeResult"
	upgradeResultRemote.Parent = remotes
end

local lastRequests: {[Player]: number} = {}
local activeUpgrades: {[Player]: boolean} = {}

local function sendResult(
	player: Player,
	success: boolean,
	message: string,
	level: number?
)
	upgradeResultRemote:FireClient(
		player,
		success,
		message,
		level
	)
end

local function getPlayerPlot(player: Player): Model?
	local plotName = player:GetAttribute("PlotName")

	if typeof(plotName) == "string" then
		local namedPlot = plotsFolder:FindFirstChild(plotName)

		if namedPlot
			and namedPlot:IsA("Model")
			and namedPlot:GetAttribute("OwnerUserId")
				== player.UserId then

			return namedPlot
		end
	end

	for _, instance in plotsFolder:GetChildren() do
		if not instance:IsA("Model") then
			continue
		end

		if instance:GetAttribute("OwnerUserId")
			== player.UserId then

			return instance
		end
	end

	return nil
end

local function getPlacedBusinesses(
	plot: Model
): Instance?
	return plot:FindFirstChild("PlacedBusinesses")
end

local function getCashValue(
	player: Player
): IntValue?
	local leaderstats =
		player:FindFirstChild("leaderstats")

	if not leaderstats then
		return nil
	end

	local cash = leaderstats:FindFirstChild("Cash")

	if cash and cash:IsA("IntValue") then
		return cash
	end

	return nil
end

local function getCurrentLevel(
	stand: Model
): number
	local value = stand:GetAttribute("Level")

	if typeof(value) ~= "number" then
		return 1
	end

	if value % 1 ~= 0 or value < 1 then
		return 1
	end

	return value
end

local function getStandLevelConfig(
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

	local levelConfig =
		standLevels[level]

	if typeof(levelConfig) ~= "table" then
		return nil
	end

	return levelConfig
end

local function playerOwnsStand(
	player: Player,
	stand: Model,
	plot: Model
): boolean
	if plot:GetAttribute("OwnerUserId")
		~= player.UserId then

		return false
	end

	if stand:GetAttribute("OwnerUserId")
		~= player.UserId then

		return false
	end

	local placedBusinesses =
		getPlacedBusinesses(plot)

	if not placedBusinesses then
		return false
	end

	return stand.Parent == placedBusinesses
end

local function setModelPlacedState(model: Model)
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.Anchored = true
		end
	end
end

local function setPromptsEnabled(
	model: Model,
	enabled: boolean
)
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("ProximityPrompt") then
			descendant.MaxActivationDistance =
				MANAGEMENT_DISTANCE

			descendant.Enabled = enabled
		end
	end
end

local function copyAttributes(
	source: Model,
	target: Model
)
	for attributeName, value in source:GetAttributes() do
		target:SetAttribute(attributeName, value)
	end
end

local function validateUpgradeTemplate(
	template: Model
): (boolean, string)
	if not template.PrimaryPart then
		return false,
			`${template.Name} does not have a PrimaryPart.`
	end

	local requiredInstances = {
		"PlacementOrigin",
		"PlacementBounds",
		"ManagementUIPosition",
		"CooldownUIPosition",
		"SaleEffectPosition",
		"CustomerFacingPosition",
		"QueuePositions",
	}

	for _, instanceName in requiredInstances do
		if not template:FindFirstChild(
			instanceName,
			true
		) then
			return false,
				`${template.Name} is missing {instanceName}.`
		end
	end

	return true, ""
end

local function isLemonadeStand(
	stand: Model
): boolean
	local businessType =
		stand:GetAttribute("BusinessType")

	if businessType == BUSINESS_NAME then
		return true
	end

	return stand.Name == BUSINESS_NAME
		or string.match(
			stand.Name,
			"^LemonadeStand_"
		) ~= nil
end

local function performUpgrade(player: Player, stand: Model)
	if activeUpgrades[player] then
		return
	end

	activeUpgrades[player] = true

	local function finish()
		activeUpgrades[player] = nil
	end

	if typeof(stand) ~= "Instance"
	or not stand:IsA("Model") then

	finish()

	sendResult(
		player,
		false,
		"The selected lemonade stand is invalid."
	)

	return
end

local plot =
	getPlayerPlot(player)

if not plot then
	finish()

	sendResult(
		player,
		false,
		"You do not own a plot."
	)

	return
end

if not isLemonadeStand(stand) then
	finish()

	sendResult(
		player,
		false,
		"The selected business is not a lemonade stand."
	)

	return
end

	if not playerOwnsStand(
		player,
		stand,
		plot
	) then
		finish()

		sendResult(
			player,
			false,
			"You do not own this lemonade stand."
		)

		return
	end

	if player:GetAttribute("EditingBusiness") then
		finish()

		sendResult(
			player,
			false,
			"Finish editing the stand before upgrading it."
		)

		return
	end

	if stand:GetAttribute("IsBeingEdited") == true then
		finish()

		sendResult(
			player,
			false,
			"This stand is currently being edited."
		)

		return
	end

	if stand:GetAttribute("StandUnavailable") == true then
		finish()

		sendResult(
			player,
			false,
			"This stand is currently unavailable."
		)

		return
	end

	local currentLevel =
		getCurrentLevel(stand)

	local currentConfig =
	getStandLevelConfig(currentLevel)

	if not currentConfig then
		finish()

		sendResult(
			player,
			false,
			"The current stand level is not configured."
		)

		return
	end

	local nextLevel = currentLevel + 1

	local nextConfig =
	getStandLevelConfig(nextLevel)

	if not nextConfig then
		finish()

		sendResult(
			player,
			false,
			"Your lemonade stand is already at the maximum level.",
			currentLevel
		)

		return
	end

	local upgradeCost =
		currentConfig.UpgradeCost

	if typeof(upgradeCost) ~= "number"
		or upgradeCost < 0
		or upgradeCost % 1 ~= 0 then

		finish()

		sendResult(
			player,
			false,
			"The upgrade cost is not configured correctly."
		)

		return
	end

	local templateName =
		nextConfig.TemplateName

	if typeof(templateName) ~= "string" then
		finish()

		sendResult(
			player,
			false,
			"The next stand model is not configured."
		)

		return
	end

	local template =
		businessModels:FindFirstChild(templateName)

	if not template or not template:IsA("Model") then
		finish()

		sendResult(
			player,
			false,
			`${templateName} could not be found in BusinessModels.`
		)

		return
	end

	local templateValid, templateReason =
		validateUpgradeTemplate(template)

	if not templateValid then
		finish()

		sendResult(
			player,
			false,
			templateReason
		)

		return
	end

	local cash = getCashValue(player)

	if not cash then
		finish()

		sendResult(
			player,
			false,
			"Your cash value could not be found."
		)

		return
	end

	if cash.Value < upgradeCost then
		finish()

		sendResult(
			player,
			false,
			`You need ${upgradeCost} to upgrade this stand.`,
			currentLevel
		)

		return
	end

	local placedBusinesses =
		getPlacedBusinesses(plot)

	if not placedBusinesses then
		finish()

		sendResult(
			player,
			false,
			"The plot is missing PlacedBusinesses."
		)

		return
	end

	local oldPivot = stand:GetPivot()

	-- Stop new customers from using the old stand during replacement.
	stand:SetAttribute("StandUnavailable", true)
	setPromptsEnabled(stand, false)

	local upgradedStand = template:Clone()

	local success, upgradeError =
		pcall(function()
			upgradedStand.Name = stand.Name

			copyAttributes(
				stand,
				upgradedStand
			)

			upgradedStand:SetAttribute(
				"BusinessType",
				BUSINESS_NAME
			)

			upgradedStand:SetAttribute(
				"Level",
				nextLevel
			)

			upgradedStand:SetAttribute(
				"OwnerUserId",
				player.UserId
			)

			upgradedStand:SetAttribute(
				"PlotName",
				plot.Name
			)

			upgradedStand:SetAttribute(
				"StandUnavailable",
				false
			)

			upgradedStand:SetAttribute(
				"IsBeingEdited",
				false
			)

			setModelPlacedState(upgradedStand)

			upgradedStand.Name =
	stand.Name .. "_UpgradePending"

upgradedStand.Parent =
	placedBusinesses

upgradedStand:PivotTo(oldPivot)

local finalName = stand.Name

stand:SetAttribute(
	"StandUnavailable",
	true
)

task.wait(0.1)

stand:Destroy()

upgradedStand.Name = finalName

			setPromptsEnabled(
				upgradedStand,
				true
			)
		end)

	if not success then
		if upgradedStand.Parent then
			upgradedStand:Destroy()
		end

		stand:SetAttribute(
			"StandUnavailable",
			false
		)

		setPromptsEnabled(stand, true)

		finish()

		warn(
			`Failed to upgrade {player.Name}'s stand: {upgradeError}`
		)

		sendResult(
			player,
			false,
			"The lemonade stand upgrade failed."
		)

		return
	end

	-- Charge only after the replacement model was created successfully.
	cash.Value -= upgradeCost

	if stand.Parent then
		stand:Destroy()
	end

	finish()

	sendResult(
		player,
		true,
		`Lemonade stand upgraded to Level {nextLevel}!`,
		nextLevel
	)
end

requestUpgradeRemote.OnServerEvent:Connect(
	function(
		player: Player,
		stand: Model
	)
		local currentTime = time()

		local previousRequest =
			lastRequests[player] or 0

		if currentTime - previousRequest
			< REQUEST_COOLDOWN then

			return
		end

		lastRequests[player] = currentTime

		performUpgrade(
			player,
			stand
		)
	end
)

Players.PlayerRemoving:Connect(function(player)
	lastRequests[player] = nil
	activeUpgrades[player] = nil
end)

print("BusinessUpgradeManager started.")