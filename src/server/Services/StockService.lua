local ReplicatedStorage =
	game:GetService("ReplicatedStorage")


local BusinessConfig =
	require(
		ReplicatedStorage
			:WaitForChild("Shared")
			:WaitForChild("BusinessConfig")
	)


local billboardsFolder =
	ReplicatedStorage:WaitForChild(
		"Billboards"
	)


local stockBillboardTemplate =
	billboardsFolder:WaitForChild(
		"Stock"
	)


local StockService = {}


--==================================================
-- EVENTS
--==================================================

--
-- Server-only event.
--
-- CustomerManager uses this to immediately wake a
-- queue back up when an empty stand is restocked.
--
StockService.StockChanged =
	Instance.new(
		"BindableEvent"
	)


--==================================================
-- STATE
--==================================================

local initializedStands: {
	[Model]: boolean
} =
	setmetatable(
		{},
		{
			__mode = "k",
		}
	)


--==================================================
-- BUSINESS INFORMATION
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
		and businessType ~= ""
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


local function getStandLevel(
	stand: Model
): number

	local level =
		stand:GetAttribute(
			"Level"
		)


	if typeof(level)
			~= "number"
		or level ~= level
		or level == math.huge
		or level == -math.huge then

		level =
			1
	end


	return math.max(
		1,
		math.floor(
			level
		)
	)
end


--==================================================
-- MAX STOCK
--==================================================

function StockService.GetMaxStock(
	stand: Model
): number

	if not stand
		or not stand:IsA(
			"Model"
		) then

		return 0
	end


	local businessType =
		getBusinessType(
			stand
		)


	if not businessType then
		return 0
	end


	local config =
		BusinessConfig[
			businessType
		]


	if type(config)
		~= "table" then

		return 0
	end


	local capacityByLevel =
		config.StockCapacityByLevel


	if type(capacityByLevel)
		~= "table" then

		warn(
			`[StockService] {businessType} has no StockCapacityByLevel configuration.`
		)

		return 0
	end


	local level =
		getStandLevel(
			stand
		)


	local configuredCapacity =
		capacityByLevel[
			level
		]


	if typeof(configuredCapacity)
			~= "number"
		or configuredCapacity < 0 then

		return 0
	end


	--==================================================
	-- FASTER SERVICE STOCK BONUS
	--==================================================
	--
	-- Faster Service consumes stock more quickly.
	--
	-- Instead of letting highly upgraded stands run
	-- dry constantly, capacity grows as service speed
	-- improves.
	--
	-- sqrt() keeps the bonus meaningful without making
	-- stock effectively infinite.
	--
	-- Example:
	--
	-- 5.0s -> 1.5s service
	-- ratio = 3.33
	-- sqrt = ~1.83x stock capacity
	--
	--==================================================

	local baseCooldown =
		config.BaseServingCooldown


	if typeof(baseCooldown)
			~= "number"
		or baseCooldown <= 0 then

		baseCooldown =
			5
	end


	local currentCooldown =
		stand:GetAttribute(
			"PurchaseCooldown"
		)


	if typeof(currentCooldown)
			~= "number"
		or currentCooldown <= 0 then

		currentCooldown =
			baseCooldown
	end


	local speedRatio =
		math.max(
			1,
			baseCooldown
				/ currentCooldown
		)


	local serviceStockMultiplier =
		math.sqrt(
			speedRatio
		)


	--
	-- Safety ceiling in case a future upgrade ever
	-- produces an extremely tiny cooldown.
	--
	serviceStockMultiplier =
		math.clamp(
			serviceStockMultiplier,
			1,
			2.25
		)


	local finalCapacity =
		configuredCapacity
			* serviceStockMultiplier


	return math.max(
		1,
		math.floor(
			finalCapacity
				+ 0.5
		)
	)
end


--==================================================
-- BILLBOARD
--==================================================

local function getBillboardAdornee(
	stand: Model
): BasePart?

	local managementPosition =
		stand:FindFirstChild(
			"ManagementUIPosition",
			true
		)


	if managementPosition
		and managementPosition:IsA(
			"BasePart"
		) then

		return managementPosition
	end


	if stand.PrimaryPart then
		return stand.PrimaryPart
	end


	for _, descendant in
		stand:GetDescendants() do

		if descendant:IsA(
			"BasePart"
		) then

			return descendant
		end
	end


	return nil
end


local function getStockBillboard(
	stand: Model
): BillboardGui?

	local existing =
		stand:FindFirstChild(
			"StockDisplay",
			true
		)


	if existing
		and existing:IsA(
			"BillboardGui"
		) then

		return existing
	end


	return nil
end


local function createStockBillboard(
	stand: Model
): BillboardGui?

	local adornee =
		getBillboardAdornee(
			stand
		)


	if not adornee then

		warn(
			`[StockService] {stand:GetFullName()} has no part to attach the Stock billboard to.`
		)

		return nil
	end


	if not stockBillboardTemplate:IsA(
		"BillboardGui"
	) then

		warn(
			"[StockService] ReplicatedStorage.Billboards.Stock must be a BillboardGui."
		)

		return nil
	end


	local billboard =
		stockBillboardTemplate:Clone()


	billboard.Name =
		"StockDisplay"


	billboard.Adornee =
		adornee


	billboard.Parent =
		adornee


	return billboard
end


local function updateBillboard(
	stand: Model
)

	local billboard =
		getStockBillboard(
			stand
		)


	if not billboard then

		billboard =
			createStockBillboard(
				stand
			)
	end


	if not billboard then
		return
	end


	local currentStock =
		stand:GetAttribute(
			"Stock"
		)


	local maxStock =
		stand:GetAttribute(
			"MaxStock"
		)


	if typeof(currentStock)
			~= "number" then

		currentStock =
			0
	end


	if typeof(maxStock)
			~= "number"
		or maxStock <= 0 then

		maxStock =
			1
	end


	currentStock =
		math.clamp(
			math.floor(
				currentStock
			),
			0,
			math.floor(
				maxStock
			)
		)


	maxStock =
		math.max(
			1,
			math.floor(
				maxStock
			)
		)


	local percentage =
		math.clamp(
			currentStock
				/ maxStock,
			0,
			1
		)


	local background =
		billboard:FindFirstChild(
			"Background"
		)


	if not background
		or not background:IsA(
			"GuiObject"
		) then

		return
	end


	local amount =
		background:FindFirstChild(
			"Amount"
		)


	if amount
		and amount:IsA(
			"TextLabel"
		) then

		if currentStock <= 0 then

			amount.Text =
				"OUT OF STOCK"

		else

			amount.Text =
				`{currentStock}/{maxStock}`
		end
	end


	local bar =
		background:FindFirstChild(
			"Bar"
		)


	if bar
		and bar:IsA(
			"GuiObject"
		) then

		bar.AnchorPoint =
			Vector2.new(
				0,
				bar.AnchorPoint.Y
			)


		bar.Size =
			UDim2.new(
				percentage,
				0,
				bar.Size.Y.Scale,
				bar.Size.Y.Offset
			)


		local fullColor =
			Color3.fromRGB(
				70,
				220,
				90
			)


		local middleColor =
			Color3.fromRGB(
				255,
				200,
				55
			)


		local emptyColor =
			Color3.fromRGB(
				235,
				65,
				65
			)


		local stockColor


		if percentage >= 0.5 then

			local alpha =
				(
					percentage - 0.5
				) / 0.5


			stockColor =
				middleColor:Lerp(
					fullColor,
					alpha
				)

		else

			local alpha =
				percentage / 0.5


			stockColor =
				emptyColor:Lerp(
					middleColor,
					alpha
				)
		end


		bar.BackgroundColor3 =
			stockColor
	end
end


--==================================================
-- STOCK STATE
--==================================================

local function updateStateAttributes(
	stand: Model
)

	local currentStock =
		stand:GetAttribute(
			"Stock"
		)


	local maxStock =
		stand:GetAttribute(
			"MaxStock"
		)


	if typeof(currentStock)
			~= "number" then

		currentStock =
			0
	end


	if typeof(maxStock)
			~= "number"
		or maxStock < 0 then

		maxStock =
			0
	end


	currentStock =
		math.clamp(
			math.floor(
				currentStock
			),
			0,
			math.floor(
				maxStock
			)
		)


	local outOfStock =
		currentStock <= 0


	local lowThreshold =
		math.max(
			1,
			math.ceil(
				maxStock
					* 0.25
			)
		)


	local lowStock =
		not outOfStock
			and currentStock
				<= lowThreshold


	stand:SetAttribute(
		"OutOfStock",
		outOfStock
	)


	stand:SetAttribute(
		"LowStock",
		lowStock
	)


	updateBillboard(
		stand
	)
end


function StockService.SetStock(
	stand: Model,
	amount: number
): number

	if not stand
		or not stand:IsA(
			"Model"
		) then

		return 0
	end


	if typeof(amount)
			~= "number"
		or amount ~= amount
		or amount == math.huge
		or amount == -math.huge then

		return 0
	end


	local previousStock =
		stand:GetAttribute(
			"Stock"
		)


	if typeof(previousStock)
		~= "number" then

		previousStock =
			0
	end


	local maxStock =
		stand:GetAttribute(
			"MaxStock"
		)


	if typeof(maxStock)
			~= "number" then

		maxStock =
			StockService.GetMaxStock(
				stand
			)
	end


	maxStock =
		math.max(
			0,
			math.floor(
				maxStock
			)
		)


	local newStock =
		math.clamp(
			math.floor(
				amount
			),
			0,
			maxStock
		)


	stand:SetAttribute(
		"Stock",
		newStock
	)


	updateStateAttributes(
		stand
	)


	if previousStock
		~= newStock then

		StockService.StockChanged:
			Fire(
				stand,
				previousStock,
				newStock
			)
	end


	return newStock
end


function StockService.AddStock(
	stand: Model,
	amount: number
): number

	if typeof(amount)
			~= "number"
		or amount <= 0 then

		local current =
			stand:GetAttribute(
				"Stock"
			)


		return typeof(current)
				== "number"
				and current
				or 0
	end


	local current =
		stand:GetAttribute(
			"Stock"
		)


	if typeof(current)
			~= "number" then

		current =
			0
	end


	return StockService.SetStock(
		stand,
		current + amount
	)
end


function StockService.CanServe(
	stand: Model
): boolean

	if not stand
		or not stand:IsA(
			"Model"
		) then

		return false
	end


	if stand:GetAttribute(
		"MaxStock"
	) == nil then

		StockService.InitializeStand(
			stand
		)
	end


	local stock =
		stand:GetAttribute(
			"Stock"
		)


	return typeof(stock)
			== "number"
		and stock >= 1
end


function StockService.TryConsume(
	stand: Model,
	amount: number?
): boolean

	local consumeAmount =
		amount or 1


	if typeof(consumeAmount)
			~= "number"
		or consumeAmount <= 0 then

		return false
	end


	consumeAmount =
		math.max(
			1,
			math.floor(
				consumeAmount
			)
		)


	if stand:GetAttribute(
		"MaxStock"
	) == nil then

		StockService.InitializeStand(
			stand
		)
	end


	local current =
		stand:GetAttribute(
			"Stock"
		)


	if typeof(current)
			~= "number" then

		return false
	end


	if current
		< consumeAmount then

		StockService.SetStock(
			stand,
			0
		)

		return false
	end


	StockService.SetStock(
		stand,
		current - consumeAmount
	)


	return true
end


--==================================================
-- MAXIMUM STOCK UPDATE
--==================================================

local function updateMaximumStock(
	stand: Model
)

	local maxStock =
		StockService.GetMaxStock(
			stand
		)


	if maxStock <= 0 then
		return
	end


	local previousStock =
		stand:GetAttribute(
			"Stock"
		)


	stand:SetAttribute(
		"MaxStock",
		maxStock
	)


	if typeof(previousStock)
		~= "number" then

		--
		-- Brand-new business.
		--
		stand:SetAttribute(
			"Stock",
			maxStock
		)

	else

		--
		-- Increasing capacity should not magically
		-- refill the business.
		--
		stand:SetAttribute(
			"Stock",

			math.clamp(
				math.floor(
					previousStock
				),
				0,
				maxStock
			)
		)
	end


	updateStateAttributes(
		stand
	)
end


--==================================================
-- INITIALIZATION
--==================================================

function StockService.InitializeStand(
	stand: Model
): boolean

	if not stand
		or not stand:IsA(
			"Model"
		) then

		return false
	end


	local businessType =
		getBusinessType(
			stand
		)


	if not businessType then
		return false
	end


	updateMaximumStock(
		stand
	)


	if initializedStands[
		stand
	] then

		return true
	end


	initializedStands[
		stand
	] =
		true


	stand:GetAttributeChangedSignal(
		"Stock"
	):Connect(
		function()

			if not stand.Parent then
				return
			end


			updateStateAttributes(
				stand
			)
		end
	)


	stand:GetAttributeChangedSignal(
		"Level"
	):Connect(
		function()

			if not stand.Parent then
				return
			end


			updateMaximumStock(
				stand
			)
		end
	)


	--
	-- Faster Service modifies PurchaseCooldown,
	-- therefore it also modifies useful stock
	-- capacity.
	--
	stand:GetAttributeChangedSignal(
		"PurchaseCooldown"
	):Connect(
		function()

			if not stand.Parent then
				return
			end


			updateMaximumStock(
				stand
			)
		end
	)


	return true
end


return StockService