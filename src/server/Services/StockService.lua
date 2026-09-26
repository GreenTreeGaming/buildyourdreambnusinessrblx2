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


	return math.max(
		0,
		math.floor(
			configuredCapacity
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


	local background =
		billboard:FindFirstChild(
			"Background"
		)


	if background
		and background:IsA(
			"GuiObject"
		) then

		local bar =
			background:FindFirstChild(
				"Bar"
			)


		if bar
			and bar:IsA(
				"GuiObject"
			) then

			--
			-- Remember the FULL bar dimensions.
			-- This lets the stock percentage resize your
			-- existing UI without requiring hard-coded UI sizes.
			--
			bar:SetAttribute(
				"StockFullXScale",
				bar.Size.X.Scale
			)

			bar:SetAttribute(
				"StockFullXOffset",
				bar.Size.X.Offset
			)

			bar:SetAttribute(
				"StockFullYScale",
				bar.Size.Y.Scale
			)

			bar:SetAttribute(
				"StockFullYOffset",
				bar.Size.Y.Offset
			)
		end
	end


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

		amount.Text =
			`{currentStock}/{maxStock}`
	end


	local bar =
		background:FindFirstChild(
			"Bar"
		)


	if bar
		and bar:IsA(
			"GuiObject"
		) then

		local fullXScale =
			bar:GetAttribute(
				"StockFullXScale"
			)


		local fullXOffset =
			bar:GetAttribute(
				"StockFullXOffset"
			)


		local fullYScale =
			bar:GetAttribute(
				"StockFullYScale"
			)


		local fullYOffset =
			bar:GetAttribute(
				"StockFullYOffset"
			)


		if typeof(fullXScale)
			~= "number" then

			fullXScale =
				bar.Size.X.Scale
		end


		if typeof(fullXOffset)
			~= "number" then

			fullXOffset =
				bar.Size.X.Offset
		end


		if typeof(fullYScale)
			~= "number" then

			fullYScale =
				bar.Size.Y.Scale
		end


		if typeof(fullYOffset)
			~= "number" then

			fullYOffset =
				bar.Size.Y.Offset
		end


		bar.Size =
			UDim2.new(
				fullXScale
					* percentage,

				math.floor(
					fullXOffset
						* percentage
				),

				fullYScale,
				fullYOffset
			)
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
-- INITIALIZATION
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


	--
	-- Brand-new stand:
	-- starts completely full.
	--
	if typeof(previousStock)
		~= "number" then

		stand:SetAttribute(
			"Stock",
			maxStock
		)

	else

		--
		-- Existing/upgraded stand:
		-- capacity increases, but upgrading does NOT
		-- magically refill supplies.
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


	return true
end


return StockService