local Players = game:GetService("Players")
local ReplicatedStorage =
	game:GetService("ReplicatedStorage")
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

type UpgradeResult = {
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

local purchaseLocks: {
	[Player]: boolean
} = {}

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

local function getBusinessConfig(
	businessName: string
)
	return BusinessConfig[businessName]
end

local function getUpgradeConfig(
	businessName: string,
	upgradeName: string
)
	local business =
		getBusinessConfig(businessName)

	if not business
		or not business.Upgrades then

		return nil
	end

	return business.Upgrades[upgradeName]
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
	for _, definition in
		upgradeConfig.Levels do

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

local function addDefinitionValues(
	result: UpgradeResult,
	definition
)
	if not definition then
		return
	end

	if typeof(definition.Cooldown)
		== "number" then

		result.CurrentCooldown =
			definition.Cooldown
	end

	if typeof(definition.SaleValue)
		== "number" then

		result.CurrentSaleValue =
			definition.SaleValue
	end
end

local function buildUpgradeResult(
	success: boolean,
	message: string,
	businessName: string,
	upgradeName: string,
	currentLevel: number,
	maximumLevel: number,
	upgradeConfig,
	currentDefinition,
	nextDefinition
): UpgradeResult
	local result: UpgradeResult = {
		Success = success,
		Message = message,

		BusinessName = businessName,
		UpgradeName = upgradeName,
		DisplayName =
			upgradeConfig.DisplayName,

		CurrentLevel = currentLevel,
		MaximumLevel = maximumLevel,

		NextCost = nextDefinition
			and nextDefinition.Cost
			or nil,
	}

	addDefinitionValues(
		result,
		currentDefinition
	)

	return result
end

function UpgradeService.ApplyStandUpgrades(
	player: Player,
	stand: Model
): boolean
	if not stand
		or not stand:IsA("Model")
		or stand.Name ~= BUSINESS_NAME then

		return false
	end

	if stand:GetAttribute("OwnerUserId")
		~= player.UserId then

		return false
	end

	local business =
		BusinessConfig.LemonadeStand

	local servingConfig =
		business.Upgrades.ServingSpeed

	local saleValueConfig =
		business.Upgrades.SaleValue

	local servingLevel =
		DataService.GetUpgradeLevel(
			player,
			BUSINESS_NAME,
			"ServingSpeed"
		)

	local saleValueLevel =
		DataService.GetUpgradeLevel(
			player,
			BUSINESS_NAME,
			"SaleValue"
		)

	servingLevel = math.clamp(
		servingLevel,
		0,
		getMaximumLevel(servingConfig)
	)

	saleValueLevel = math.clamp(
		saleValueLevel,
		0,
		getMaximumLevel(saleValueConfig)
	)

	local servingDefinition =
		getLevelDefinition(
			servingConfig,
			servingLevel
		)

	local saleValueDefinition =
		getLevelDefinition(
			saleValueConfig,
			saleValueLevel
		)

	if not servingDefinition then
		warn(
			`Missing ServingSpeed level {servingLevel}.`
		)

		return false
	end

	if not saleValueDefinition then
		warn(
			`Missing SaleValue level {saleValueLevel}.`
		)

		return false
	end

	stand:SetAttribute(
		"ServingSpeedLevel",
		servingLevel
	)

	stand:SetAttribute(
		"PurchaseCooldown",
		servingDefinition.Cooldown
	)

	stand:SetAttribute(
		"SaleValueLevel",
		saleValueLevel
	)

	stand:SetAttribute(
		"SaleValue",
		saleValueDefinition.SaleValue
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

	local businessConfig =
		getBusinessConfig(businessName)

	local upgradeConfig =
		getUpgradeConfig(
			businessName,
			upgradeName
		)

	if not businessConfig
		or not upgradeConfig then

		return createResult(
			false,
			"That upgrade does not exist."
		)
	end

	if not DataService.GetProfile(player) then
		return createResult(
			false,
			"Your data has not loaded yet."
		)
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

	return buildUpgradeResult(
		true,
		currentLevel >= maximumLevel
			and "Maximum level reached."
			or "Upgrade available.",
		businessName,
		upgradeName,
		currentLevel,
		maximumLevel,
		upgradeConfig,
		currentDefinition,
		nextDefinition
	)
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

	if businessName ~= BUSINESS_NAME then
		return finish(createResult(
			false,
			"That business is not available."
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
			"That upgrade is not available."
		))
	end

	if not DataService.GetProfile(player) then
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

	local currentDefinition =
		getLevelDefinition(
			upgradeConfig,
			currentLevel
		)

	if currentLevel >= maximumLevel then
		return finish(
			buildUpgradeResult(
				false,
				"This upgrade is already at maximum level.",
				businessName,
				upgradeName,
				currentLevel,
				maximumLevel,
				upgradeConfig,
				currentDefinition,
				nil
			)
		)
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

	if typeof(cost) ~= "number"
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
		local result =
			buildUpgradeResult(
				false,
				`You need ${cost - cash.Value} more.`,
				businessName,
				upgradeName,
				currentLevel,
				maximumLevel,
				upgradeConfig,
				currentDefinition,
				nextDefinition
			)

		return finish(result)
	end

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

	local followingDefinition =
		getLevelDefinition(
			upgradeConfig,
			nextLevel + 1
		)

	return finish(
		buildUpgradeResult(
			true,
			`{upgradeConfig.DisplayName} upgraded to level {nextLevel}!`,
			businessName,
			upgradeName,
			nextLevel,
			maximumLevel,
			upgradeConfig,
			nextDefinition,
			followingDefinition
		)
	)
end

function UpgradeService.ReleasePlayer(
	player: Player
)
	purchaseLocks[player] = nil
end

Players.PlayerRemoving:Connect(function(
	player
)
	UpgradeService.ReleasePlayer(player)
end)

return UpgradeService