local Players =
	game:GetService("Players")

local ReplicatedStorage =
	game:GetService("ReplicatedStorage")

local Workspace =
	game:GetService("Workspace")


local DataService =
	require(
		script.Parent
			:WaitForChild("Services")
			:WaitForChild("DataService")
	)


local StockService =
	require(
		script.Parent
			:WaitForChild("Services")
			:WaitForChild("StockService")
	)


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


local plotsFolder =
	Workspace:WaitForChild(
		"Plots"
	)


local map =
	Workspace:WaitForChild(
		"Map"
	)


local touchForStock =
	map:WaitForChild(
		"TouchForStock"
	)


--==================================================
-- CONFIGURATION
--==================================================

local REQUEST_COOLDOWN =
	0.12


--
-- The touch parts may be thin floor pads.
--
-- HumanoidRootPart is normally several studs
-- above the player's feet, so give Y a little
-- extra tolerance while still requiring the
-- player to physically be at the shop.
--
local HORIZONTAL_TOUCH_TOLERANCE =
	3

local VERTICAL_TOUCH_TOLERANCE =
	6


--==================================================
-- REMOTES
--==================================================

local remotes =
	ReplicatedStorage:FindFirstChild(
		"Remotes"
	)


if not remotes then

	remotes =
		Instance.new(
			"Folder"
		)

	remotes.Name =
		"Remotes"

	remotes.Parent =
		ReplicatedStorage
end


local function getOrCreateRemoteFunction(
	name: string
): RemoteFunction

	local existing =
		remotes:FindFirstChild(
			name
	)


	if existing then

		if not existing:IsA(
			"RemoteFunction"
		) then

			error(
				`ReplicatedStorage.Remotes.{name} must be a RemoteFunction.`
			)
		end


		return existing
	end


	local remote =
		Instance.new(
			"RemoteFunction"
		)


	remote.Name =
		name

	remote.Parent =
		remotes


	return remote
end


local purchaseStockRemote =
	getOrCreateRemoteFunction(
		"PurchaseStock"
	)


local restockAllRemote =
	getOrCreateRemoteFunction(
		"RestockAllStock"
	)


--==================================================
-- TYPES
--==================================================

type StockResult = {
	Success: boolean,
	Message: string,

	Purchased: number?,
	Cost: number?,
}


--==================================================
-- STATE
--==================================================

local purchaseLocks: {
	[Player]: boolean
} = {}


local lastRequests: {
	[Player]: number
} = {}


--==================================================
-- RESULT HELPERS
--==================================================

local function createResult(
	success: boolean,
	message: string,
	purchased: number?,
	cost: number?
): StockResult

	return {
		Success =
			success,

		Message =
			message,

		Purchased =
			purchased,

		Cost =
			cost,
	}
end


--==================================================
-- CASH
--==================================================

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
		and cash:IsA(
			"IntValue"
		) then

		return cash
	end


	return nil
end


--==================================================
-- PLOT
--==================================================

local function getPlayerPlot(
	player: Player
): Model?

	local plotName =
		player:GetAttribute(
			"PlotName"
		)


	if typeof(plotName)
		== "string" then

		local plot =
			plotsFolder:FindFirstChild(
				plotName
			)


		if plot
			and plot:IsA(
				"Model"
			)
			and plot:GetAttribute(
				"OwnerUserId"
			) == player.UserId then

			return plot
		end
	end


	for _, plot in
		plotsFolder:GetChildren() do

		if plot:IsA(
			"Model"
		)
			and plot:GetAttribute(
				"OwnerUserId"
			) == player.UserId then

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
		stand:GetAttribute(
			"BusinessType"
		)


	if typeof(businessType)
		== "string"
		and type(
			BusinessConfig[
				businessType
			]
		) == "table" then

		return businessType
	end


	for businessName, config in
		BusinessConfig do

		if type(config)
			~= "table" then

			continue
		end


		if stand.Name
				== businessName
			or string.match(
				stand.Name,
				`^{businessName}_`
			) then

			return businessName
		end
	end


	return nil
end


--==================================================
-- STOCK SHOP LOCATION VALIDATION
--==================================================

local function isInsideStockPart(
	root: BasePart,
	part: BasePart
): boolean

	local localPosition =
		part.CFrame:PointToObjectSpace(
			root.Position
		)


	local halfSize =
		part.Size / 2


	return math.abs(
		localPosition.X
	) <= halfSize.X
		+ HORIZONTAL_TOUCH_TOLERANCE

		and math.abs(
			localPosition.Z
		) <= halfSize.Z
		+ HORIZONTAL_TOUCH_TOLERANCE

		and math.abs(
			localPosition.Y
		) <= halfSize.Y
		+ VERTICAL_TOUCH_TOLERANCE
end


local function isPlayerAtStockShop(
	player: Player
): boolean

	local character =
		player.Character


	if not character then
		return false
	end


	local root =
		character:FindFirstChild(
			"HumanoidRootPart"
		)


	if not root
		or not root:IsA(
			"BasePart"
		) then

		return false
	end


	for _, descendant in
		touchForStock:GetDescendants() do

		if not descendant:IsA(
			"BasePart"
		) then

			continue
		end


		if isInsideStockPart(
			root,
			descendant
		) then

			return true
		end
	end


	return false
end


--==================================================
-- BUSINESS STOCK
--==================================================

local function getBusinessesOfType(
	player: Player,
	businessType: string
): {Model}

	local plot =
		getPlayerPlot(
			player
		)


	if not plot then
		return {}
	end


	local placedBusinesses =
		plot:FindFirstChild(
			"PlacedBusinesses"
		)


	if not placedBusinesses then
		return {}
	end


	local businesses = {}


	for _, child in
		placedBusinesses:GetChildren() do

		if not child:IsA(
			"Model"
		) then

			continue
		end


		if child:GetAttribute(
			"OwnerUserId"
		) ~= player.UserId then

			continue
		end


		if getBusinessType(
			child
		) ~= businessType then

			continue
		end


		--
		-- Make sure stock attributes exist before
		-- reading from the stand.
		--
		StockService.InitializeStand(
			child
		)


		table.insert(
			businesses,
			child
		)
	end


	return businesses
end


local function getStockNumbers(
	stands: {Model}
): (
	number,
	number
)

	local currentStock =
		0


	local maximumStock =
		0


	for _, stand in stands do

		local current =
			stand:GetAttribute(
				"Stock"
			)


		local maximum =
			stand:GetAttribute(
				"MaxStock"
			)


		if typeof(current)
			~= "number" then

			current =
				0
		end


		if typeof(maximum)
			~= "number" then

			maximum =
				StockService.GetMaxStock(
					stand
				)
		end


		currentStock +=
			math.max(
				0,
				math.floor(
					current
				)
			)


		maximumStock +=
			math.max(
				0,
				math.floor(
					maximum
				)
			)
	end


	return currentStock,
		maximumStock
end


--==================================================
-- STOCK DISTRIBUTION
--==================================================

local function getStockPercentage(
	stand: Model
): number

	local current =
		stand:GetAttribute(
			"Stock"
		)


	local maximum =
		stand:GetAttribute(
			"MaxStock"
		)


	if typeof(current)
		~= "number" then

		current =
			0
	end


	if typeof(maximum)
			~= "number"
		or maximum <= 0 then

		return 1
	end


	return math.clamp(
		current / maximum,
		0,
		1
	)
end


local function addStockToBusinesses(
	stands: {Model},
	amount: number
): number

	amount =
		math.max(
			0,
			math.floor(
				amount
			)
		)


	if amount <= 0 then
		return 0
	end


	--
	-- Prioritize the stands that are closest to
	-- empty so an out-of-stock stand starts working
	-- again as quickly as possible.
	--
	table.sort(
		stands,
		function(
			first: Model,
			second: Model
		)

			return getStockPercentage(
				first
			) < getStockPercentage(
				second
			)
		end
	)


	local remaining =
		amount


	local totalAdded =
		0


	for _, stand in stands do

		if remaining <= 0 then
			break
		end


		local current =
			stand:GetAttribute(
				"Stock"
			)


		local maximum =
			stand:GetAttribute(
				"MaxStock"
			)


		if typeof(current)
			~= "number" then

			current =
				0
		end


		if typeof(maximum)
			~= "number" then

			maximum =
				StockService.GetMaxStock(
					stand
				)
		end


		current =
			math.max(
				0,
				math.floor(
					current
				)
			)


		maximum =
			math.max(
				0,
				math.floor(
					maximum
				)
			)


		local missing =
			math.max(
				0,
				maximum - current
			)


		if missing <= 0 then
			continue
		end


		local toAdd =
			math.min(
				remaining,
				missing
			)


		local previous =
			current


		local newAmount =
			StockService.AddStock(
				stand,
				toAdd
			)


		local actuallyAdded =
			math.max(
				0,
				newAmount - previous
			)


		totalAdded +=
			actuallyAdded


		remaining -=
			actuallyAdded
	end


	return totalAdded
end


--==================================================
-- PURCHASE CONFIGURATION
--==================================================

local function getPurchaseAmount(
	businessType: string,
	optionName: string,
	shortage: number
): number

	local definition =
		StockPurchaseConfig[
			businessType
		]


	if type(definition)
		~= "table" then

		return 0
	end


	shortage =
		math.max(
			0,
			math.floor(
				shortage
			)
		)


	if shortage <= 0 then
		return 0
	end


	if optionName
		== "Fill" then

		return shortage
	end


	local configuredAmount =
		definition[
			optionName
		]


	if typeof(configuredAmount)
		~= "number"
		or configuredAmount <= 0 then

		return 0
	end


	return math.min(
		shortage,
		math.floor(
			configuredAmount
		)
	)
end


--==================================================
-- SINGLE BUSINESS-TYPE PURCHASE
--==================================================

local function purchaseStock(
	player: Player,
	businessType: string,
	optionName: string
): StockResult

	if not DataService.GetProfile(
		player
	) then

		return createResult(
			false,
			"Your data has not loaded yet."
		)
	end


	if not isPlayerAtStockShop(
		player
	) then

		return createResult(
			false,
			"You must be at the stock shop to buy supplies."
		)
	end


	if type(businessType)
		~= "string"
		or type(optionName)
			~= "string" then

		return createResult(
			false,
			"Invalid stock purchase."
		)
	end


	local definition =
		StockPurchaseConfig[
			businessType
		]


	if type(definition)
		~= "table" then

		return createResult(
			false,
			"This business does not have stock purchasing configured."
		)
	end


	if optionName ~= "Buy1"
		and optionName ~= "Buy2"
		and optionName ~= "Fill" then

		return createResult(
			false,
			"Invalid stock purchase option."
		)
	end


	local stands =
		getBusinessesOfType(
			player,
			businessType
		)

	local highestLevel =
		StockPurchaseConfig.GetHighestStandLevel(
			stands
		)
	
	
	local unitPrice =
		StockPurchaseConfig.GetUnitPrice(
			businessType,
			highestLevel
		)
	
	
	if unitPrice <= 0 then
	
		return createResult(
			false,
			"The stock price is not configured correctly."
		)
	end


	--
	-- This is what prevents Coffee, etc. from being
	-- purchasable before the player has actually
	-- placed one.
	--
	if #stands == 0 then

		return createResult(
			false,
			"You have not placed this business yet."
		)
	end


	local currentStock,
		maximumStock =
		getStockNumbers(
			stands
		)


	local shortage =
		math.max(
			0,
			maximumStock
				- currentStock
		)


	if shortage <= 0 then

		return createResult(
			false,
			"That business is already fully stocked."
		)
	end


	local requestedAmount =
		getPurchaseAmount(
			businessType,
			optionName,
			shortage
		)


	if requestedAmount <= 0 then

		return createResult(
			false,
			"Nothing needs to be purchased."
		)
	end


	local requestedCost =
		requestedAmount
			* unitPrice


	local cash =
		getCashValue(
			player
		)


	if not cash then

		return createResult(
			false,
			"Your cash could not be found."
		)
	end


	if cash.Value
		< requestedCost then

		return createResult(
			false,
			`You need ${requestedCost - cash.Value} more.`
		)
	end


	cash.Value -=
		requestedCost


	local actuallyAdded =
		addStockToBusinesses(
			stands,
			requestedAmount
		)


	local actualCost =
		actuallyAdded
			* unitPrice


	--
	-- Safety refund in case a stand changed between
	-- the validation and the purchase application.
	--
	if actualCost
		< requestedCost then

		cash.Value +=
			requestedCost
				- actualCost
	end


	if actuallyAdded <= 0 then

		return createResult(
			false,
			"Your businesses could not be restocked."
		)
	end


	return createResult(
		true,
		`Purchased {actuallyAdded} stock.`,
		actuallyAdded,
		actualCost
	)
end


--==================================================
-- RESTOCK ALL
--==================================================

local function restockAll(
	player: Player
): StockResult

	if not DataService.GetProfile(
		player
	) then

		return createResult(
			false,
			"Your data has not loaded yet."
		)
	end


	if not isPlayerAtStockShop(
		player
	) then

		return createResult(
			false,
			"You must be at the stock shop to buy supplies."
		)
	end


	type RestockOperation = {
		BusinessType: string,
		Stands: {Model},
		Shortage: number,
		UnitPrice: number,
	}


	local operations: {
		RestockOperation
	} = {}


	local totalCost =
		0


	for businessType, definition in
		StockPurchaseConfig do

		if type(definition)
			~= "table" then

			continue
		end

		local stands =
			getBusinessesOfType(
				player,
				businessType
			)

		local highestLevel =
			StockPurchaseConfig.GetHighestStandLevel(
				stands
			)
		
		
		local unitPrice =
			StockPurchaseConfig.GetUnitPrice(
				businessType,
				highestLevel
			)
		
		
		if unitPrice <= 0 then
			continue
		end


		if #stands == 0 then
			continue
		end


		local currentStock,
			maximumStock =
			getStockNumbers(
				stands
			)


		local shortage =
			math.max(
				0,
				maximumStock
					- currentStock
			)


		if shortage <= 0 then
			continue
		end


		table.insert(
			operations,
			{
				BusinessType =
					businessType,

				Stands =
					stands,

				Shortage =
					shortage,

				UnitPrice =
					unitPrice,
			}
		)


		totalCost +=
			shortage
				* unitPrice
	end


	if #operations == 0 then

		return createResult(
			false,
			"All of your businesses are already fully stocked."
		)
	end


	local cash =
		getCashValue(
			player
		)


	if not cash then

		return createResult(
			false,
			"Your cash could not be found."
		)
	end


	if cash.Value
		< totalCost then

		return createResult(
			false,
			`You need ${totalCost - cash.Value} more.`
		)
	end


	cash.Value -=
		totalCost


	local totalPurchased =
		0


	local actualCost =
		0


	for _, operation in operations do

		local added =
			addStockToBusinesses(
				operation.Stands,
				operation.Shortage
			)


		totalPurchased +=
			added


		actualCost +=
			added
				* operation.UnitPrice
	end


	--
	-- Refund anything that could not be applied.
	--
	if actualCost
		< totalCost then

		cash.Value +=
			totalCost - actualCost
	end


	if totalPurchased <= 0 then

		return createResult(
			false,
			"Your businesses could not be restocked."
		)
	end


	return createResult(
		true,
		`Restocked all businesses with {totalPurchased} stock.`,
		totalPurchased,
		actualCost
	)
end


--==================================================
-- REQUEST LOCK
--==================================================

local function runPurchaseRequest(
	player: Player,
	callback: () -> StockResult
): StockResult

	local now =
		time()


	local previousRequest =
		lastRequests[
			player
		] or 0


	if now - previousRequest
		< REQUEST_COOLDOWN then

		return createResult(
			false,
			"Please wait before purchasing again."
		)
	end


	lastRequests[
		player
	] = now


	if purchaseLocks[
		player
	] then

		return createResult(
			false,
			"A stock purchase is already processing."
		)
	end


	purchaseLocks[
		player
	] = true


	local success,
		result =
		xpcall(
			callback,
			debug.traceback
		)


	purchaseLocks[
		player
	] = nil


	if not success then

		warn(
			`[StockPurchaseManager] Purchase failed for {player.Name}: {result}`
		)


		return createResult(
			false,
			"Something went wrong while purchasing stock."
		)
	end


	return result
end


--==================================================
-- REMOTE HANDLERS
--==================================================

purchaseStockRemote.OnServerInvoke =
	function(
		player: Player,
		businessType: string,
		optionName: string
	)

		return runPurchaseRequest(
			player,
			function()

				return purchaseStock(
					player,
					businessType,
					optionName
				)
			end
		)
	end


restockAllRemote.OnServerInvoke =
	function(
		player: Player
	)

		return runPurchaseRequest(
			player,
			function()

				return restockAll(
					player
				)
			end
		)
	end


--==================================================
-- CLEANUP
--==================================================

Players.PlayerRemoving:Connect(
	function(
		player: Player
	)

		purchaseLocks[
			player
		] = nil


		lastRequests[
			player
		] = nil
	end
)


print(
	"StockPurchaseManager started."
)