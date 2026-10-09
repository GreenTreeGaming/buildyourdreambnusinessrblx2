--==================================================
-- STOCK PROTECTION SERVICE
--==================================================
--
-- Prevent players from spending the money they
-- need for their next stock purchase.
--
-- Stock purchases themselves are never blocked.
--
-- Server-side protection for:
-- Business upgrades
-- Appearance upgrades
-- Business placement
-- Marketing
-- Plot expansion
--
--==================================================

local ReplicatedStorage =
	game:GetService("ReplicatedStorage")

local Workspace =
	game:GetService("Workspace")


local BusinessConfig =
	require(
		ReplicatedStorage
			:WaitForChild("Shared")
			:WaitForChild("BusinessConfig")
	)


local StockPurchaseConfig =
	require(
		ReplicatedStorage
			:WaitForChild("Shared")
			:WaitForChild("StockPurchaseConfig")
	)


local StockProtectionService = {}


--==================================================
-- NOTIFICATION REMOTE
--==================================================

local remotes =
	ReplicatedStorage:WaitForChild("Remotes")

local protectionNotification =
	remotes:FindFirstChild(
		"StockProtectionNotification"
	)

if not protectionNotification then

	protectionNotification =
		Instance.new("RemoteEvent")

	protectionNotification.Name =
		"StockProtectionNotification"

	protectionNotification.Parent =
		remotes
end


local lastNotification = {}

local NOTIFICATION_COOLDOWN = 3


local function notifyPlayer(
	player: Player
)

	local currentTime =
		os.clock()

	local previous =
		lastNotification[player] or 0

	if currentTime - previous
		< NOTIFICATION_COOLDOWN then

		return
	end

	lastNotification[player] =
		currentTime

	protectionNotification:FireClient(
		player,
		StockProtectionService.BlockedMessage
	)
end

--==================================================
-- SETTINGS
--==================================================

StockProtectionService.BlockedMessage =
	"Save money for stock! Restock your business before upgrading."


--==================================================
-- PLOT LOOKUP
--==================================================

local function getPlayerPlot(
	player: Player
): Model?

	local plotsFolder =
		Workspace:FindFirstChild("Plots")

	if not plotsFolder then
		return nil
	end

	for _, plot in plotsFolder:GetChildren() do

		if not plot:IsA("Model") then
			continue
		end

		if plot:GetAttribute("OwnerUserId")
			== player.UserId then

			return plot
		end
	end

	return nil
end


--==================================================
-- BUSINESS TYPE
--==================================================

local function getBusinessType(
	stand: Model
): string?

	local businessType =
		stand:GetAttribute("BusinessType")

	if typeof(businessType) == "string"
		and type(BusinessConfig[businessType]) == "table" then

		return businessType
	end

	for name, config in BusinessConfig do

		if type(config) ~= "table" then
			continue
		end

		if stand.Name == name
			or string.match(
				stand.Name,
				"^" .. name .. "_"
			) then

			return name
		end
	end

	return nil
end


--==================================================
-- READ STOCK
--==================================================

local function getStock(
	stand: Model
): (number, number)

	local stock =
		stand:GetAttribute("Stock")

	local maximum =
		stand:GetAttribute("MaxStock")

	if typeof(stock) ~= "number"
		or stock ~= stock then

		stock = 0
	end

	if typeof(maximum) ~= "number"
		or maximum ~= maximum then

		maximum = 0
	end

	stock =
		math.max(
			0,
			math.floor(stock)
		)

	maximum =
		math.max(
			0,
			math.floor(maximum)
		)

	return stock, maximum
end


--==================================================
-- CALCULATE REQUIRED STOCK RESERVE
--==================================================
--
-- We reserve enough money for the smallest normal
-- Buy1 stock purchase the player can make.
--
-- When a business is nearly full, its actual
-- shortage may be smaller than Buy1.
--
-- When every business is full, we still reserve
-- enough for one future Buy1 purchase.
--
--==================================================

function StockProtectionService.GetRequiredReserve(
	player: Player
): number

	local plot =
		getPlayerPlot(player)

	if not plot then
		return 0
	end

	local businessesFolder =
		plot:FindFirstChild("PlacedBusinesses")

	if not businessesFolder then
		return 0
	end

	local businessesByType = {}

	for _, stand in businessesFolder:GetChildren() do

		if not stand:IsA("Model") then
			continue
		end

		local businessType =
			getBusinessType(stand)

		if not businessType then
			continue
		end

		local definition =
			StockPurchaseConfig[businessType]

		if type(definition) ~= "table" then
			continue
		end

		local group =
			businessesByType[businessType]

		if not group then

			group = {
				Stands = {},
				Stock = 0,
				MaxStock = 0,
			}

			businessesByType[businessType] =
				group
		end

		table.insert(
			group.Stands,
			stand
		)

		local stock, maximum =
			getStock(stand)

		group.Stock += stock
		group.MaxStock += maximum
	end


	local minimumCurrentCost = math.huge
	local minimumFutureCost = math.huge

	for businessType, group in businessesByType do

		if #group.Stands == 0 then
			continue
		end

		local definition =
			StockPurchaseConfig[businessType]

		local highestLevel =
			StockPurchaseConfig.GetHighestStandLevel(
				group.Stands
			)

		local unitPrice =
			StockPurchaseConfig.GetUnitPrice(
				businessType,
				highestLevel
			)

		local buyAmount =
			tonumber(definition.Buy1) or 0

		buyAmount =
			math.floor(buyAmount)

		if unitPrice <= 0
			or buyAmount <= 0 then

			continue
		end

		-- Enough for a normal Buy1 purchase
		-- when inventory eventually needs it.

		local futureAmount =
			math.min(
				buyAmount,
				group.MaxStock
			)

		if futureAmount > 0 then

			minimumFutureCost =
				math.min(
					minimumFutureCost,
					futureAmount * unitPrice
				)
		end


		-- Use the actual current shortage
		-- if stock needs replenishing now.

		local shortage =
			math.max(
				0,
				group.MaxStock - group.Stock
			)

		if shortage > 0 then

			local currentAmount =
				math.min(
					buyAmount,
					shortage
				)

			minimumCurrentCost =
				math.min(
					minimumCurrentCost,
					currentAmount * unitPrice
				)
		end
	end


	-- Always protect one normal Buy1 purchase.
	-- Do not reduce the reserve just because a
	-- business currently needs only a few units.
	
	if minimumFutureCost ~= math.huge then
	
		return math.ceil(
			minimumFutureCost
		)
	end
	
	return 0
end


--==================================================
-- PURCHASE VALIDATION
--==================================================

function StockProtectionService.CanSpend(
	player: Player,
	purchaseCost: number
): (boolean, string?)

	if typeof(purchaseCost) ~= "number"
		or purchaseCost ~= purchaseCost
		or purchaseCost == math.huge
		or purchaseCost == -math.huge
		or purchaseCost < 0 then

		return false, "Invalid purchase cost."
	end

	local leaderstats =
		player:FindFirstChild("leaderstats")

	local cash =
		leaderstats
		and leaderstats:FindFirstChild("Cash")

	if not cash
		or not cash:IsA("IntValue") then

		return false, "Your cash could not be found."
	end

	if cash.Value < purchaseCost then

		return false, "Not enough cash."
	end

	-- Free purchases should never be blocked.

	if purchaseCost == 0 then
		return true, nil
	end


	local reserve =
		StockProtectionService.GetRequiredReserve(
			player
		)

	if reserve <= 0 then
		return true, nil
	end


	local remainingCash =
		cash.Value - purchaseCost

	if remainingCash < reserve then
	
		notifyPlayer(player)
	
		return false,
			StockProtectionService.BlockedMessage
	end

	return true, nil
end

game:GetService("Players").PlayerRemoving:Connect(
	function(player)
		lastNotification[player] = nil
	end
)


return StockProtectionService