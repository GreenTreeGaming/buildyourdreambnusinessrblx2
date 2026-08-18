local Players =
	game:GetService("Players")

local MarketplaceService =
	game:GetService("MarketplaceService")

local ReplicatedStorage =
	game:GetService("ReplicatedStorage")

local ShopConfig =
	require(
		ReplicatedStorage
			:WaitForChild("Shared")
			:WaitForChild("ShopConfig")
	)

local DataService =
	require(
		script.Parent
			:WaitForChild("Services")
			:WaitForChild("DataService")
	)

local BENEFIT_REFRESH_INTERVAL = 1

local function isValidId(
	value: any
): boolean
	return typeof(value) == "number"
		and value > 0
		and value % 1 == 0
end

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

	if cash
		and cash:IsA("IntValue") then

		return cash
	end

	return nil
end

local function ownsGamePass(
	player: Player,
	gamePassId: number
): boolean
	if not isValidId(gamePassId) then
		return false
	end

	local success, owns =
		pcall(function()
			return MarketplaceService:
				UserOwnsGamePassAsync(
					player.UserId,
					gamePassId
				)
		end)

	if not success then
		warn(
			`Could not check gamepass {gamePassId} for {player.Name}: {owns}`
		)

		return false
	end

	return owns == true
end

local function refreshGamePassOwnership(
	player: Player
)
	local cashPass =
		ShopConfig.GamePasses.x2Cash

	local vipPass =
		ShopConfig.GamePasses.VIP

	local has2xCash =
		ownsGamePass(
			player,
			cashPass.Id
		)

	local hasVIP =
		ownsGamePass(
			player,
			vipPass.Id
		)

	player:SetAttribute(
		"Has2xCash",
		has2xCash
	)

	player:SetAttribute(
		"HasVIP",
		hasVIP
	)
end

local function isBoostActive(
	player: Player,
	boostName: string,
	now: number
): boolean
	local expiresAt =
		DataService.GetBoostUntil(
			player,
			boostName
		)

	return expiresAt > now
end

local function refreshBenefits(
	player: Player
)
	if not player.Parent then
		return
	end

	if not DataService.GetProfile(player) then
		return
	end

	local now =
		os.time()

	local cashBoostActive =
		isBoostActive(
			player,
			"CashBoost",
			now
		)

	local customerRushActive =
		isBoostActive(
			player,
			"CustomerRush",
			now
		)

	local reputationBoostActive =
		isBoostActive(
			player,
			"ReputationBoost",
			now
		)

	local cashMultiplier = 1

	if player:GetAttribute(
		"Has2xCash"
	) == true then

		cashMultiplier *=
			ShopConfig.CashGamePassMultiplier
	end

	if cashBoostActive then
		cashMultiplier *=
			ShopConfig.CashBoostMultiplier
	end

	local customerMultiplier = 1

	if player:GetAttribute(
		"HasVIP"
	) == true then

		customerMultiplier *=
			ShopConfig.VIPCustomerMultiplier
	end

	if customerRushActive then
		customerMultiplier *=
			ShopConfig.CustomerRushMultiplier
	end

	local reputationMultiplier = 1

	if reputationBoostActive then
		reputationMultiplier *=
			ShopConfig.ReputationBoostMultiplier
	end

	player:SetAttribute(
		"CashMultiplier",
		cashMultiplier
	)

	player:SetAttribute(
		"CustomerMonetizationMultiplier",
		customerMultiplier
	)

	player:SetAttribute(
		"ReputationSaleMultiplier",
		reputationMultiplier
	)

	player:SetAttribute(
		"CashBoostUntil",
		DataService.GetBoostUntil(
			player,
			"CashBoost"
		)
	)

	player:SetAttribute(
		"CustomerRushUntil",
		DataService.GetBoostUntil(
			player,
			"CustomerRush"
		)
	)

	player:SetAttribute(
		"ReputationBoostUntil",
		DataService.GetBoostUntil(
			player,
			"ReputationBoost"
		)
	)
end

local function extendBoost(
	player: Player,
	boostName: string,
	duration: number
): (boolean, number)
	local now =
		os.time()

	local oldExpiry =
		DataService.GetBoostUntil(
			player,
			boostName
		)

	local startingPoint =
		math.max(
			now,
			oldExpiry
		)

	local newExpiry =
		startingPoint
			+ math.max(
				1,
				math.floor(duration)
			)

	local success =
		DataService.SetBoostUntil(
			player,
			boostName,
			newExpiry
		)

	if success then
		refreshBenefits(player)
	end

	return success, oldExpiry
end

local productById = {}

for _, product in
	ShopConfig.DeveloperProducts do

	if isValidId(product.Id) then
		if productById[product.Id] then
			error(
				`Duplicate developer product ID {product.Id} in ShopConfig.`
			)
		end

		productById[product.Id] =
			product
	end
end

type RollbackFunction =
	() -> ()

local function grantDeveloperProduct(
	player: Player,
	product: {[any]: any}
): (boolean, RollbackFunction?)
	if product.RewardType == "Cash" then
		local cash =
			getCashValue(player)

		if not cash then
			return false, nil
		end

		local amount =
			product.Amount

		if typeof(amount) ~= "number"
			or amount <= 0 then

			return false, nil
		end

		amount =
			math.floor(amount)

		local oldCash =
			cash.Value

		cash.Value += amount

		return true, function()
			if cash.Parent then
				cash.Value =
					oldCash
			end
		end
	end

	if product.RewardType == "Boost" then
		local boostName =
			product.BoostName

		local duration =
			product.Duration

		if type(boostName) ~= "string"
			or boostName == ""
			or typeof(duration) ~= "number"
			or duration <= 0 then

			return false, nil
		end

		local success, oldExpiry =
			extendBoost(
				player,
				boostName,
				duration
			)

		if not success then
			return false, nil
		end

		return true, function()
			DataService.SetBoostUntil(
				player,
				boostName,
				oldExpiry
			)

			refreshBenefits(player)
		end
	end

	warn(
		`Unknown shop reward type: {tostring(product.RewardType)}`
	)

	return false, nil
end

local function processReceipt(
	receiptInfo: {[any]: any}
): Enum.ProductPurchaseDecision
	local player =
		Players:GetPlayerByUserId(
			receiptInfo.PlayerId
		)

	if not player then
		return Enum.ProductPurchaseDecision
			.NotProcessedYet
	end

	local profile =
		DataService.WaitForProfile(
			player,
			15
		)

	if not profile then
		return Enum.ProductPurchaseDecision
			.NotProcessedYet
	end

	local purchaseId =
		tostring(
			receiptInfo.PurchaseId
		)

	if purchaseId == "" then
		warn(
			"Developer product receipt had no PurchaseId."
		)

		return Enum.ProductPurchaseDecision
			.NotProcessedYet
	end

	if DataService.HasProcessedReceipt(
		player,
		purchaseId
	) then

		return Enum.ProductPurchaseDecision
			.PurchaseGranted
	end

	local product =
		productById[
			receiptInfo.ProductId
		]

	if not product then
		warn(
			`No developer product handler exists for product ID {receiptInfo.ProductId}.`
		)

		return Enum.ProductPurchaseDecision
			.NotProcessedYet
	end

	local success,
		granted,
		rollback = pcall(
			grantDeveloperProduct,
			player,
			product
		)

	if not success then
		warn(
			`Developer product grant crashed for {player.Name}: {granted}`
		)

		return Enum.ProductPurchaseDecision
			.NotProcessedYet
	end

	if granted ~= true then
		warn(
			`Could not grant developer product {receiptInfo.ProductId} to {player.Name}.`
		)

		return Enum.ProductPurchaseDecision
			.NotProcessedYet
	end

	DataService.SetReceiptProcessed(
		player,
		purchaseId,
		true
	)

	-- Important: save before acknowledging the receipt.
	local saved =
		DataService.SavePlayer(
			player
		)

	if not saved then
		DataService.SetReceiptProcessed(
			player,
			purchaseId,
			false
		)

		if rollback then
			rollback()
		end

		warn(
			`Could not save developer product receipt {purchaseId}; purchase will be retried.`
		)

		return Enum.ProductPurchaseDecision
			.NotProcessedYet
	end

	print(
		`Granted developer product {receiptInfo.ProductId} to {player.Name}.`
	)

	return Enum.ProductPurchaseDecision
		.PurchaseGranted
end

MarketplaceService.ProcessReceipt =
	processReceipt

MarketplaceService.PromptGamePassPurchaseFinished:
	Connect(function(
		player: Player,
		gamePassId: number,
		wasPurchased: boolean
	)
		if not wasPurchased then
			return
		end

		local relevant =
			gamePassId
				== ShopConfig.GamePasses.x2Cash.Id
			or gamePassId
				== ShopConfig.GamePasses.VIP.Id

		if not relevant then
			return
		end

		task.delay(
			0.5,
			function()
				if not player.Parent then
					return
				end

				refreshGamePassOwnership(
					player
				)

				refreshBenefits(
					player
				)
			end
		)
	end)

local function setupPlayer(
	player: Player
)
	local profile =
		DataService.WaitForProfile(
			player,
			15
		)

	if not profile then
		return
	end

	refreshGamePassOwnership(
		player
	)

	refreshBenefits(
		player
	)
end

Players.PlayerAdded:
	Connect(function(player)
		task.spawn(
			setupPlayer,
			player
		)
	end)

for _, player in
	Players:GetPlayers() do

	task.spawn(
		setupPlayer,
		player
	)
end

task.spawn(function()
	while true do
		task.wait(
			BENEFIT_REFRESH_INTERVAL
		)

		for _, player in
			Players:GetPlayers() do

			refreshBenefits(
				player
			)
		end
	end
end)