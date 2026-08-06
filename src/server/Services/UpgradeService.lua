local Players =
	game:GetService("Players")

local ReplicatedStorage =
	game:GetService("ReplicatedStorage")

local DataService = require(
	script.Parent:WaitForChild(
		"DataService"
	)
)

local BusinessConfig = require(
	ReplicatedStorage
		:WaitForChild("Shared")
		:WaitForChild("BusinessConfig")
)

local BUSINESS_NAME =
	"LemonadeStand"

type UpgradeResult = {
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

local purchaseLocks: {
	[Player]: boolean
} = {}

local UpgradeService = {}

local function getCashValue(
	player: Player
): IntValue?
	local leaderstats =
		player:FindFirstChild(
			"leaderstats"
		)

	if not leaderstats then
		return nil
	end

	local cash =
		leaderstats:FindFirstChild(
			"Cash"
		)

	if cash
		and cash:IsA("IntValue") then

		return cash
	end

	return nil
end

local function getBusinessType(
	stand: Model
): string
	local businessType =
		stand:GetAttribute(
			"BusinessType"
		)

	if typeof(businessType) == "string"
		and businessType ~= "" then

		return businessType
	end

	if stand.Name == BUSINESS_NAME
		or string.match(
			stand.Name,
			"^LemonadeStand_"
		) then

		return BUSINESS_NAME
	end

	return stand.Name
end

local function getUpgradeConfig(
	businessName: string,
	upgradeName: string
)
	local businessConfig =
		BusinessConfig[businessName]

	if not businessConfig
		or not businessConfig.Upgrades then

		return nil
	end

	return businessConfig.Upgrades[
		upgradeName
	]
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

	if typeof(definition.Capacity)
		== "number" then

		result.CurrentQueueCapacity =
			definition.Capacity
	end
end

local function buildUpgradeResult(
	success: boolean,
	message: string,
	businessId: string,
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

		BusinessId = businessId,
		BusinessName = businessName,

		UpgradeName = upgradeName,
		DisplayName =
			upgradeConfig.DisplayName,

		CurrentLevel = currentLevel,
		MaximumLevel = maximumLevel,

		NextCost =
			nextDefinition
			and nextDefinition.Cost
			or nil,
	}

	addDefinitionValues(
		result,
		currentDefinition
	)

	return result
end

local function getOwnedStand(
	player: Player,
	businessId: string
): Model?
	local stand =
		DataService.FindOwnedBusinessById(
			player,
			businessId
		)

	if not stand then
		return nil
	end

	if getBusinessType(stand)
		~= BUSINESS_NAME then

		return nil
	end

	return stand
end

function UpgradeService.ApplyStandUpgrades(
	player: Player,
	stand: Model
): boolean
	if not stand
		or not stand:IsA("Model") then

		return false
	end

	if stand:GetAttribute(
		"OwnerUserId"
	) ~= player.UserId then

		return false
	end

	if getBusinessType(stand)
		~= BUSINESS_NAME then

		return false
	end

	local businessId =
		stand:GetAttribute(
			"BusinessId"
		)

	if typeof(businessId) ~= "string"
		or businessId == "" then

		businessId = stand.Name
	end

	local businessConfig =
		BusinessConfig.LemonadeStand

	local servingConfig =
		businessConfig.Upgrades.ServingSpeed

		local saleValueConfig =
		businessConfig.Upgrades.SaleValue

	local queueCapacityConfig =
		businessConfig.Upgrades.QueueCapacity

	local servingLevel =
		DataService.GetBusinessUpgradeLevel(
			player,
			businessId,
			"ServingSpeed"
		)

	local saleValueLevel =
		DataService.GetBusinessUpgradeLevel(
			player,
			businessId,
			"SaleValue"
		)

	local queueCapacityLevel =
		DataService.GetBusinessUpgradeLevel(
			player,
			businessId,
			"QueueCapacity"
		)

	servingLevel =
		math.clamp(
			servingLevel,
			0,
			getMaximumLevel(
				servingConfig
			)
		)

		saleValueLevel =
		math.clamp(
			saleValueLevel,
			0,
			getMaximumLevel(
				saleValueConfig
			)
		)

	queueCapacityLevel =
		math.clamp(
			queueCapacityLevel,
			0,
			getMaximumLevel(
				queueCapacityConfig
			)
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

	local queueCapacityDefinition =
		getLevelDefinition(
			queueCapacityConfig,
			queueCapacityLevel
		)

	if not servingDefinition
		or not saleValueDefinition
		or not queueCapacityDefinition then

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

		stand:SetAttribute(
		"QueueCapacityLevel",
		queueCapacityLevel
	)

	stand:SetAttribute(
		"QueueCapacity",
		queueCapacityDefinition.Capacity
	)

	return true
end

function UpgradeService.GetUpgradeState(
	player: Player,
	businessId: string,
	upgradeName: string
): UpgradeResult
	if type(businessId) ~= "string"
		or businessId == ""
		or type(upgradeName) ~= "string"
		or upgradeName == "" then

		return createResult(
			false,
			"Invalid upgrade request."
		)
	end

	if not DataService.GetProfile(player) then
		return createResult(
			false,
			"Your data has not loaded yet."
		)
	end

	local stand =
		getOwnedStand(
			player,
			businessId
		)

	if not stand then
		return createResult(
			false,
			"The selected lemonade stand could not be found."
		)
	end

	local businessName =
		getBusinessType(stand)

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

	local maximumLevel =
		getMaximumLevel(
			upgradeConfig
		)

	local currentLevel =
		DataService.GetBusinessUpgradeLevel(
			player,
			businessId,
			upgradeName
		)

	currentLevel =
		math.clamp(
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
		businessId,
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
	businessId: string,
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

	if type(businessId) ~= "string"
		or businessId == ""
		or type(upgradeName) ~= "string"
		or upgradeName == "" then

		return finish(
			createResult(
				false,
				"Invalid upgrade request."
			)
		)
	end

	if not DataService.GetProfile(player) then
		return finish(
			createResult(
				false,
				"Your data has not loaded yet."
			)
		)
	end

	local stand =
		getOwnedStand(
			player,
			businessId
		)

	if not stand then
		return finish(
			createResult(
				false,
				"The selected lemonade stand could not be found."
			)
		)
	end

	local businessName =
		getBusinessType(stand)

	local upgradeConfig =
		getUpgradeConfig(
			businessName,
			upgradeName
		)

	if not upgradeConfig then
		return finish(
			createResult(
				false,
				"That upgrade is not available."
			)
		)
	end

	local maximumLevel =
		getMaximumLevel(
			upgradeConfig
		)

	local currentLevel =
		DataService.GetBusinessUpgradeLevel(
			player,
			businessId,
			upgradeName
		)

	currentLevel =
		math.clamp(
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
				businessId,
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
		return finish(
			createResult(
				false,
				"The next upgrade level is not configured."
			)
		)
	end

	local cost =
		nextDefinition.Cost

	if typeof(cost) ~= "number"
		or cost < 0 then

		return finish(
			createResult(
				false,
				"The upgrade cost is invalid."
			)
		)
	end

	local cash =
		getCashValue(player)

	if not cash then
		return finish(
			createResult(
				false,
				"Your cash value could not be found."
			)
		)
	end

	if cash.Value < cost then
		return finish(
			buildUpgradeResult(
				false,
				`You need ${cost - cash.Value} more.`,
				businessId,
				businessName,
				upgradeName,
				currentLevel,
				maximumLevel,
				upgradeConfig,
				currentDefinition,
				nextDefinition
			)
		)
	end

	cash.Value -= cost

	local levelUpdated =
		DataService.SetBusinessUpgradeLevel(
			player,
			businessId,
			upgradeName,
			nextLevel
		)

	if not levelUpdated then
		cash.Value += cost

		return finish(
			createResult(
				false,
				"The upgrade could not be saved."
			)
		)
	end

	local applied =
		UpgradeService.ApplyStandUpgrades(
			player,
			stand
		)

	if not applied then
		DataService.SetBusinessUpgradeLevel(
			player,
			businessId,
			upgradeName,
			currentLevel
		)

		cash.Value += cost

		return finish(
			createResult(
				false,
				"The upgrade could not be applied."
			)
		)
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
			businessId,
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
	player: Player
)
	UpgradeService.ReleasePlayer(player)
end)

return UpgradeService