local Players =
	game:GetService("Players")

local ReplicatedStorage =
	game:GetService("ReplicatedStorage")

local Workspace =
	game:GetService("Workspace")


local plotsFolder =
	Workspace:WaitForChild("Plots")

local remotes =
	ReplicatedStorage:WaitForChild("Remotes")


local BusinessConfig =
	require(
		ReplicatedStorage
			:WaitForChild("Shared")
			:WaitForChild("BusinessConfig")
	)


--==================================================
-- STATE
--==================================================

local promptConnections: {
	[ProximityPrompt]: RBXScriptConnection
} = {}

local activePurchases: {
	[ProximityPrompt]: boolean
} = {}

local connectedStands: {
	[Model]: boolean
} = {}


--==================================================
-- REMOTE
--==================================================

-- Keep the old remote name for compatibility with
-- existing client scripts.
local manualSaleResultRemote =
	remotes:FindFirstChild(
		"ManualLemonadeSaleResult"
	)


if manualSaleResultRemote
	and not manualSaleResultRemote:IsA(
		"RemoteEvent"
	) then

	error(
		"ManualLemonadeSaleResult must be a RemoteEvent."
	)
end


if not manualSaleResultRemote then

	manualSaleResultRemote =
		Instance.new(
			"RemoteEvent"
		)

	manualSaleResultRemote.Name =
		"ManualLemonadeSaleResult"

	manualSaleResultRemote.Parent =
		remotes
end


manualSaleResultRemote =
	manualSaleResultRemote :: RemoteEvent


--==================================================
-- BUSINESS HELPERS
--==================================================

local function getBusinessType(
	stand: Model
): string?

	local businessType =
		stand:GetAttribute(
			"BusinessType"
		)


	if typeof(businessType) == "string"
		and BusinessConfig[businessType] then

		return businessType
	end


	for businessName in BusinessConfig do

		if stand.Name == businessName
			or string.match(
				stand.Name,
				`^{businessName}_`
			) then

			return businessName
		end
	end


	return nil
end


local function getBusinessConfig(
	stand: Model
): {[any]: any}?

	local businessType =
		getBusinessType(
			stand
		)


	if not businessType then
		return nil
	end


	local config =
		BusinessConfig[
			businessType
		]


	if type(config) ~= "table" then
		return nil
	end


	return config
end


local function getBusinessDisplayName(
	stand: Model
): string

	local businessType =
		getBusinessType(
			stand
		)


	if not businessType then
		return "Business"
	end


	local config =
		BusinessConfig[
			businessType
		]


	if type(config) == "table"
		and typeof(config.DisplayName)
			== "string"
		and config.DisplayName ~= "" then

		return config.DisplayName
	end


	return businessType
end


local function isSupportedBusiness(
	stand: Model
): boolean

	return getBusinessType(
		stand
	) ~= nil
end


--==================================================
-- PLOT / OWNER HELPERS
--==================================================

local function getPlotFromStand(
	stand: Model
): Model?

	local current: Instance? =
		stand


	while current
		and current ~= plotsFolder do

		if current:IsA(
			"Model"
		)
			and current.Parent
				== plotsFolder then

			return current
		end


		current =
			current.Parent
	end


	return nil
end


local function getOwnerFromStand(
	stand: Model
): Player?

	local ownerUserId =
		stand:GetAttribute(
			"OwnerUserId"
		)


	if typeof(ownerUserId)
			~= "number"
		or ownerUserId <= 0 then

		local plot =
			getPlotFromStand(
				stand
			)


		if plot then

			ownerUserId =
				plot:GetAttribute(
					"OwnerUserId"
				)
		end
	end


	if typeof(ownerUserId)
			~= "number"
		or ownerUserId <= 0 then

		return nil
	end


	return Players:GetPlayerByUserId(
		ownerUserId
	)
end


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
-- SALE VALUES
--==================================================

local function getSaleValue(
	stand: Model
): number

	local saleValue =
		stand:GetAttribute(
			"SaleValue"
		)


	if typeof(saleValue) == "number"
		and saleValue == saleValue
		and saleValue ~= math.huge
		and saleValue ~= -math.huge
		and saleValue >= 0 then

		return math.max(
			0,
			math.floor(
				saleValue
			)
		)
	end


	local config =
		getBusinessConfig(
			stand
		)


	if config
		and typeof(
			config.BaseSaleValue
		) == "number" then

		return math.max(
			0,
			math.floor(
				config.BaseSaleValue
			)
		)
	end


	return 0
end


local function getPurchaseTime(
	stand: Model
): number

	local purchaseTime =
		stand:GetAttribute(
			"PurchaseCooldown"
		)


	if typeof(purchaseTime) == "number"
		and purchaseTime == purchaseTime
		and purchaseTime ~= math.huge
		and purchaseTime ~= -math.huge
		and purchaseTime > 0 then

		return purchaseTime
	end


	local config =
		getBusinessConfig(
			stand
		)


	if config
		and typeof(
			config.BaseServingCooldown
		) == "number"
		and config.BaseServingCooldown > 0 then

		return config.BaseServingCooldown
	end


	return 5
end


--==================================================
-- AVAILABILITY
--==================================================

local function isStandAvailable(
	stand: Model
): boolean

	if not stand.Parent then
		return false
	end


	if not isSupportedBusiness(
		stand
	) then

		return false
	end


	if stand:GetAttribute(
		"StandUnavailable"
	) == true then

		return false
	end


	if stand:GetAttribute(
		"IsBeingEdited"
	) == true then

		return false
	end


	return true
end


--==================================================
-- PURCHASE PROMPT
--==================================================

local function isPurchasePrompt(
	prompt: ProximityPrompt
): boolean

	-- New generic attribute.
	if prompt:GetAttribute(
		"IsBusinessPurchasePrompt"
	) == true then

		return true
	end


	-- Backwards compatibility with existing
	-- Lemonade Stand templates.
	if prompt:GetAttribute(
		"IsLemonadePurchasePrompt"
	) == true then

		return true
	end


	-- Existing stand templates use this default
	-- ProximityPrompt name.
	if prompt.Name
		== "ProximityPrompt" then

		return true
	end


	return false
end


--==================================================
-- STATISTICS
--==================================================

local function addSaleStatistics(
	stand: Model,
	saleValue: number
)

	local totalSales =
		stand:GetAttribute(
			"TotalSales"
		)


	if typeof(totalSales)
		~= "number" then

		totalSales =
			0
	end


	local lifetimeEarnings =
		stand:GetAttribute(
			"LifetimeEarnings"
		)


	if typeof(lifetimeEarnings)
		~= "number" then

		lifetimeEarnings =
			0
	end


	stand:SetAttribute(
		"TotalSales",
		math.max(
			0,
			math.floor(
				totalSales
			)
		) + 1
	)


	stand:SetAttribute(
		"LifetimeEarnings",
		math.max(
			0,
			math.floor(
				lifetimeEarnings
			)
		) + saleValue
	)
end


--==================================================
-- PURCHASE STATE
--==================================================

local function clearPurchaseState(
	stand: Model,
	prompt: ProximityPrompt
)

	activePurchases[prompt] =
		nil


	if stand.Parent then

		stand:SetAttribute(
			"ManualPurchaseActive",
			false
		)

		stand:SetAttribute(
			"ManualPurchaseStartedAt",
			nil
		)

		stand:SetAttribute(
			"ManualPurchaseDuration",
			nil
		)
	end


	if prompt.Parent
		and isStandAvailable(
			stand
		) then

		prompt.Enabled =
			true
	end
end


--==================================================
-- PROCESS PURCHASE
--==================================================

local function processPurchase(
	prompt: ProximityPrompt,
	stand: Model,
	buyer: Player
)

	if activePurchases[
		prompt
	] then

		return
	end


	if not isStandAvailable(
		stand
	) then

		return
	end


	local businessType =
		getBusinessType(
			stand
		)


	if not businessType then
		return
	end


	local owner =
		getOwnerFromStand(
			stand
		)


	if not owner then

		warn(
			`Could not find the owner of {stand:GetFullName()}.`
		)

		return
	end


	local ownerCash =
		getCashValue(
			owner
		)


	if not ownerCash then

		warn(
			`Cash value was not found for {owner.Name}.`
		)

		return
	end


	local purchaseTime =
		getPurchaseTime(
			stand
		)


	local saleValue =
		getSaleValue(
			stand
		)


	local displayName =
		getBusinessDisplayName(
			stand
		)


	activePurchases[prompt] =
		true


	prompt.Enabled =
		false


	stand:SetAttribute(
		"ManualPurchaseActive",
		true
	)

	stand:SetAttribute(
		"ManualPurchaseStartedAt",
		Workspace:GetServerTimeNow()
	)

	stand:SetAttribute(
		"ManualPurchaseDuration",
		purchaseTime
	)


	print(
		`{buyer.Name} started buying from {owner.Name}'s {displayName}.`
	)


	task.delay(
		purchaseTime,

		function()

			if not activePurchases[
				prompt
			] then

				return
			end


			if not prompt.Parent
				or not stand.Parent
				or not buyer.Parent
				or not owner.Parent
				or not isStandAvailable(
					stand
				) then

				clearPurchaseState(
					stand,
					prompt
				)

				return
			end


			-- Make sure the business did not somehow
			-- change while the purchase was active.
			if getBusinessType(
				stand
			) ~= businessType then

				clearPurchaseState(
					stand,
					prompt
				)

				return
			end


			local currentOwnerCash =
				getCashValue(
					owner
				)


			if not currentOwnerCash then

				clearPurchaseState(
					stand,
					prompt
				)

				return
			end


			currentOwnerCash.Value +=
				saleValue


			addSaleStatistics(
				stand,
				saleValue
			)


			manualSaleResultRemote:FireClient(
				buyer,
				stand,
				saleValue
			)


			if owner ~= buyer then

				manualSaleResultRemote:FireClient(
					owner,
					stand,
					saleValue
				)
			end


			clearPurchaseState(
				stand,
				prompt
			)


			print(
				`${displayName} sale completed for $${saleValue}.`
			)
		end
	)
end


--==================================================
-- CONNECT PROMPT
--==================================================

local function connectPrompt(
	stand: Model,
	prompt: ProximityPrompt
)

	if promptConnections[
		prompt
	] then

		return
	end


	if not isPurchasePrompt(
		prompt
	) then

		return
	end


	prompt:SetAttribute(
		"IsBusinessPurchasePrompt",
		true
	)


	-- Remove the obsolete Lemonade-only marker.
	if prompt:GetAttribute(
		"IsLemonadePurchasePrompt"
	) ~= nil then

		prompt:SetAttribute(
			"IsLemonadePurchasePrompt",
			nil
		)
	end


	promptConnections[prompt] =
		prompt.Triggered:Connect(
			function(
				triggeringPlayer: Player
			)

				processPurchase(
					prompt,
					stand,
					triggeringPlayer
				)
			end
		)


	prompt.Destroying:Connect(
		function()

			local connection =
				promptConnections[
					prompt
				]


			if connection then

				connection:Disconnect()
			end


			promptConnections[prompt] =
				nil

			activePurchases[prompt] =
				nil
		end
	)


	print(
		`Connected purchase prompt for {getBusinessDisplayName(stand)}: {prompt:GetFullName()}`
	)
end


--==================================================
-- CONNECT BUSINESS
--==================================================

local function connectStand(
	stand: Model
)

	if connectedStands[
		stand
	] then

		return
	end


	if not isSupportedBusiness(
		stand
	) then

		return
	end


	connectedStands[stand] =
		true


	for _, descendant in
		stand:GetDescendants() do

		if descendant:IsA(
			"ProximityPrompt"
		) then

			connectPrompt(
				stand,
				descendant
			)
		end
	end


	stand.DescendantAdded:Connect(
		function(
			descendant: Instance
		)

			if descendant:IsA(
				"ProximityPrompt"
			) then

				connectPrompt(
					stand,
					descendant
				)
			end
		end
	)


	stand.Destroying:Connect(
		function()

			connectedStands[
				stand
			] = nil
		end
	)
end


--==================================================
-- WATCH PLACED BUSINESSES
--==================================================

local function watchPlacedBusinesses(
	placedBusinesses: Instance
)

	for _, child in
		placedBusinesses:GetChildren() do

		if child:IsA(
			"Model"
		) then

			connectStand(
				child
			)
		end
	end


	placedBusinesses.ChildAdded:Connect(
		function(
			child: Instance
		)

			if child:IsA(
				"Model"
			) then

				task.defer(
					connectStand,
					child
				)
			end
		end
	)
end


--==================================================
-- WATCH PLOT
--==================================================

local function watchPlot(
	plot: Model
)

	local placedBusinesses =
		plot:FindFirstChild(
			"PlacedBusinesses"
		)


	if placedBusinesses then

		watchPlacedBusinesses(
			placedBusinesses
		)

		return
	end


	task.spawn(
		function()

			local folder =
				plot:WaitForChild(
					"PlacedBusinesses",
					15
				)


			if folder then

				watchPlacedBusinesses(
					folder
				)
			end
		end
	)
end


--==================================================
-- START
--==================================================

for _, plot in
	plotsFolder:GetChildren() do

	if plot:IsA(
		"Model"
	) then

		watchPlot(
			plot
		)
	end
end


plotsFolder.ChildAdded:Connect(
	function(
		child: Instance
	)

		if child:IsA(
			"Model"
		) then

			watchPlot(
				child
			)
		end
	end
)


print(
	"ManualBusinessPurchaseManager started."
)