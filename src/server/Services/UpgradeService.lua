local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local DataService = require(
	script.Parent:WaitForChild("DataService")
)

local BusinessConfig = require(
	ReplicatedStorage
		:WaitForChild("Shared")
		:WaitForChild("BusinessConfig")
)

local plotsFolder =
	Workspace:WaitForChild("Plots")

local BUSINESS_NAME = "LemonadeStand"
local SERVING_SPEED_UPGRADE = "ServingSpeed"

type UpgradeResult = {
	Success: boolean,
	Message: string,

	BusinessName: string?,
	UpgradeName: string?,

	CurrentLevel: number?,
	MaximumLevel: number?,

	NextCost: number?,
	CurrentCooldown: number?,
}

local purchaseLocks: {[Player]: boolean} = {}

local UpgradeService = {}

local function getCashValue(
	player: Player
): IntValue?
	local leaderstats =
		player:FindFirstChild("leaderstats")

	if not leaderstats then
		return nil
	end

	local cash =
		leaderstats:FindFirstChild("Cash")

	if cash and cash:IsA("IntValue") then
		return cash
	end

	return nil
end

local function getPlayerPlot(
	player: Player
): Model?
	local plotName =
		player:GetAttribute("PlotName")

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

	for _, plot in plotsFolder:GetChildren() do
		if plot:IsA("Model")
			and plot:GetAttribute("OwnerUserId")
			== player.UserId then

			return plot
		end
	end

	return nil
end

local function getPlayerStand(
	player: Player
): Model?
	local plot = getPlayerPlot(player)

	if not plot then
		return nil
	end

	local placedBusinesses =
		plot:FindFirstChild("PlacedBusinesses")

	if not placedBusinesses then
		return nil
	end

	local stand =
		placedBusinesses:FindFirstChild(
			BUSINESS_NAME
		)

	if stand and stand:IsA("Model") then
		return stand
	end

	return nil
end

local function getUpgradeConfig(
	businessName: string,
	upgradeName: string
)
	local business =
		BusinessConfig[businessName]

	if not business then
		return nil
	end

	local upgrades = business.Upgrades

	if not upgrades then
		return nil
	end

	return upgrades[upgradeName]
end

local function getMaximumLevel(
	upgradeConfig
): number
	return math.max(
		0,
		#upgradeConfig.Levels - 1
	)
end

local function getLevelDefinition(
	upgradeConfig,
	level: number
)
	for _, definition in upgradeConfig.Levels do
		if definition.Level == level then
			return definition
		end
	end

	return nil
end

local function createResult(
	success: boolean,
	message: string
): UpgradeResult
	return {
		Success = success,
		Message = message,
	}
end

function UpgradeService.ApplyStandUpgrades(
	player: Player,
	stand: Model
): boolean
	if not stand
		or not stand:IsA("Model") then

		return false
	end

	if stand.Name ~= BUSINESS_NAME then
		return false
	end

	if stand:GetAttribute("OwnerUserId")
		~= player.UserId then

		return false
	end

	local business =
		BusinessConfig.LemonadeStand

	local upgradeConfig =
		business.Upgrades.ServingSpeed

	local currentLevel =
		DataService.GetUpgradeLevel(
			player,
			BUSINESS_NAME,
			SERVING_SPEED_UPGRADE
		)

	local maximumLevel =
		getMaximumLevel(upgradeConfig)

	currentLevel = math.clamp(
		currentLevel,
		0,
		maximumLevel
	)

	local definition =
		getLevelDefinition(
			upgradeConfig,
			currentLevel
		)

	if not definition then
		warn(
			`Missing ServingSpeed level {currentLevel} in BusinessConfig.`
		)

		return false
	end

	stand:SetAttribute(
		"ServingSpeedLevel",
		currentLevel
	)

	stand:SetAttribute(
		"PurchaseCooldown",
		definition.Cooldown
	)

	stand:SetAttribute(
		"SaleValue",
		business.BaseSaleValue
	)

	return true
end

function UpgradeService.GetUpgradeState(
	player: Player,
	businessName: string,
	upgradeName: string
): UpgradeResult
	if type(businessName) ~= "string"
		or type(upgradeName) ~= "string" then

		return createResult(
			false,
			"Invalid upgrade request."
		)
	end

	local upgradeConfig =
		getUpgradeConfig(
			businessName,
			upgradeName
		)

	if not upgradeConfig then
		return createResult(
			false,
			"That upgrade does not exist."
		)
	end

	local profile =
		DataService.GetProfile(player)

	if not profile then
		return createResult(
			false,
			"Your data has not loaded yet."
		)
	end

	local currentLevel =
		DataService.GetUpgradeLevel(
			player,
			businessName,
			upgradeName
		)

	local maximumLevel =
		getMaximumLevel(upgradeConfig)

	currentLevel = math.clamp(
		currentLevel,
		0,
		maximumLevel
	)

	local currentDefinition =
		getLevelDefinition(
			upgradeConfig,
			currentLevel
		)

	local nextDefinition =
		getLevelDefinition(
			upgradeConfig,
			currentLevel + 1
		)

	return {
		Success = true,
		Message = currentLevel >= maximumLevel
			and "Maximum level reached."
			or "Upgrade available.",

		BusinessName = businessName,
		UpgradeName = upgradeName,

		CurrentLevel = currentLevel,
		MaximumLevel = maximumLevel,

		NextCost = nextDefinition
			and nextDefinition.Cost
			or nil,

		CurrentCooldown =
			currentDefinition
			and currentDefinition.Cooldown
			or nil,
	}
end

function UpgradeService.PurchaseUpgrade(
	player: Player,
	businessName: string,
	upgradeName: string
): UpgradeResult
	if purchaseLocks[player] then
		return createResult(
			false,
			"Please wait before purchasing again."
		)
	end

	purchaseLocks[player] = true

	local function finish(
		result: UpgradeResult
	): UpgradeResult
		purchaseLocks[player] = nil
		return result
	end

	if type(businessName) ~= "string"
		or type(upgradeName) ~= "string" then

		return finish(createResult(
			false,
			"Invalid upgrade request."
		))
	end

	if businessName ~= BUSINESS_NAME
		or upgradeName ~= SERVING_SPEED_UPGRADE then

		return finish(createResult(
			false,
			"That upgrade is not available."
		))
	end

	local profile =
		DataService.GetProfile(player)

	if not profile then
		return finish(createResult(
			false,
			"Your data has not loaded yet."
		))
	end

	local stand = getPlayerStand(player)

	if not stand then
		return finish(createResult(
			false,
			"Build your lemonade stand first."
		))
	end

	if stand:GetAttribute("OwnerUserId")
		~= player.UserId then

		return finish(createResult(
			false,
			"You do not own this lemonade stand."
		))
	end

	local upgradeConfig =
		getUpgradeConfig(
			businessName,
			upgradeName
		)

	if not upgradeConfig then
		return finish(createResult(
			false,
			"Upgrade configuration was not found."
		))
	end

	local maximumLevel =
		getMaximumLevel(upgradeConfig)

	local currentLevel =
		DataService.GetUpgradeLevel(
			player,
			businessName,
			upgradeName
		)

	currentLevel = math.clamp(
		currentLevel,
		0,
		maximumLevel
	)

	if currentLevel >= maximumLevel then
		return finish({
			Success = false,
			Message = "This upgrade is already at maximum level.",

			BusinessName = businessName,
			UpgradeName = upgradeName,

			CurrentLevel = currentLevel,
			MaximumLevel = maximumLevel,
		})
	end

	local nextLevel =
		currentLevel + 1

	local nextDefinition =
		getLevelDefinition(
			upgradeConfig,
			nextLevel
		)

	if not nextDefinition then
		return finish(createResult(
			false,
			"The next upgrade level is not configured."
		))
	end

	local cost = nextDefinition.Cost

	if type(cost) ~= "number"
		or cost < 0 then

		return finish(createResult(
			false,
			"The upgrade cost is invalid."
		))
	end

	local cash = getCashValue(player)

	if not cash then
		return finish(createResult(
			false,
			"Your cash value could not be found."
		))
	end

	if cash.Value < cost then
		return finish({
			Success = false,
			Message = `You need ${cost - cash.Value} more.`,

			BusinessName = businessName,
			UpgradeName = upgradeName,

			CurrentLevel = currentLevel,
			MaximumLevel = maximumLevel,

			NextCost = cost,
		})
	end

	-- The cash deduction and level update happen together inside
	-- this purchase lock so duplicate requests cannot purchase twice.
	cash.Value -= cost

	local levelUpdated =
		DataService.SetUpgradeLevel(
			player,
			businessName,
			upgradeName,
			nextLevel
		)

	if not levelUpdated then
		cash.Value += cost

		return finish(createResult(
			false,
			"The upgrade could not be saved."
		))
	end

	local applied =
		UpgradeService.ApplyStandUpgrades(
			player,
			stand
		)

	if not applied then
		-- Roll the transaction back if the stand could not be updated.
		DataService.SetUpgradeLevel(
			player,
			businessName,
			upgradeName,
			currentLevel
		)

		cash.Value += cost

		return finish(createResult(
			false,
			"The upgrade could not be applied."
		))
	end

	local nextUpgradeDefinition =
		getLevelDefinition(
			upgradeConfig,
			nextLevel + 1
		)

	return finish({
		Success = true,
		Message = `Faster Service upgraded to level {nextLevel}!`,

		BusinessName = businessName,
		UpgradeName = upgradeName,

		CurrentLevel = nextLevel,
		MaximumLevel = maximumLevel,

		NextCost = nextUpgradeDefinition
			and nextUpgradeDefinition.Cost
			or nil,

		CurrentCooldown =
			nextDefinition.Cooldown,
	})
end

function UpgradeService.ReleasePlayer(
	player: Player
)
	purchaseLocks[player] = nil
end

Players.PlayerRemoving:Connect(function(player)
	UpgradeService.ReleasePlayer(player)
end)

return UpgradeService