local Players =
	game:GetService("Players")

local ReplicatedStorage =
	game:GetService("ReplicatedStorage")

local Workspace =
	game:GetService("Workspace")

local CRATE_IMAGES = {
	LemonadeStand = "rbxassetid://93684417666859",
	HotdogStand = "rbxassetid://131611361390942",
	HaircutStand = "rbxassetid://85112086517048",
	CoffeeStand = "rbxassetid://97673268017110",
}


local player =
	Players.LocalPlayer


local playerGui =
	player:WaitForChild(
		"PlayerGui"
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


local FormatNumber =
	require(
		ReplicatedStorage
			:WaitForChild("Shared")
			:WaitForChild("FormatNumber")
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


local remotes =
	ReplicatedStorage:WaitForChild(
		"Remotes"
	)


local purchaseStockRemote =
	remotes:WaitForChild(
		"PurchaseStock"
	) :: RemoteFunction


local restockAllRemote =
	remotes:WaitForChild(
		"RestockAllStock"
	) :: RemoteFunction


--==================================================
-- CONFIGURATION
--==================================================

local TOUCH_CHECK_INTERVAL =
	0.1


--
-- A player must remain outside the trigger for this
-- long before the menu closes.
--
-- This prevents tiny physics/touch gaps from making
-- the menu flicker.
--
local EXIT_GRACE_PERIOD =
	0.3


local UI_REFRESH_INTERVAL =
	0.2


local HORIZONTAL_TOUCH_TOLERANCE =
	3


local VERTICAL_TOUCH_TOLERANCE =
	6


--==================================================
-- TYPES
--==================================================

type BusinessStockState = {
	BusinessType: string,
	DisplayName: string,
	DisplayOrder: number,

	CurrentStock: number,
	MaximumStock: number,
	Shortage: number,

	UnitPrice: number,
	Buy1: number,
	Buy2: number,
}


type RowRefs = {
	Root: Frame,

	BusinessName: TextLabel,
	StockLeft: TextLabel,
	CrateImg: ImageLabel,

	Buy1: TextButton,
	Buy1Text: TextLabel,

	Buy2: TextButton,
	Buy2Text: TextLabel,

	Fill: TextButton,
	FillText: TextLabel,

	Bar: Frame,
	FullBarSize: UDim2,

	Connections: {
		RBXScriptConnection
	},
}

--==================================================
-- UI
--==================================================

local gui =
	playerGui:WaitForChild(
		"StockUI"
	) :: ScreenGui


local main =
	gui:WaitForChild(
		"Main"
	) :: Frame


local contentFrame =
	main:WaitForChild(
		"Frame"
	) :: Frame


local scrollingFrame =
	contentFrame:WaitForChild(
		"ScrollingFrame"
	) :: ScrollingFrame


local template =
	scrollingFrame:WaitForChild(
		"Template"
	) :: Frame


template.Visible =
	false

--==================================================
-- RESTOCK ALL BUTTON
--==================================================

local restockAllInstance =
	main:FindFirstChild(
		"RestockAll",
		true
	)


assert(
	restockAllInstance
		and restockAllInstance:IsA(
			"TextButton"
		),

	"StockUI.Main must contain a TextButton named RestockAll."
)


local restockAllButton =
	restockAllInstance :: TextButton


--==================================================
-- CLOSE BUTTON
--==================================================

local closeInstance =
	main:FindFirstChild(
		"Close",
		true
	)


local closeButton:
	TextButton? =
	nil


if closeInstance
	and closeInstance:IsA(
		"TextButton"
	) then

	closeButton =
		closeInstance
end


--==================================================
-- STATE
--==================================================

local rows: {
	[string]: RowRefs
} = {}


local currentStates: {
	[string]: BusinessStockState
} = {}


local purchasePending =
	false


local playerInside =
	false


local dismissedUntilExit =
	false


local lastInsideTime =
	-math.huge


local lastUIRefresh =
	0


--==================================================
-- GENERAL UI HELPERS
--==================================================

local function getButtonTextLabel(
	button: TextButton
): TextLabel

	local inText =
		button:WaitForChild(
			"InText"
		)


	assert(
		inText:IsA(
			"TextLabel"
		),

		`{button:GetFullName()}.InText must be a TextLabel.`
	)


	return inText
end


local function setOptionalButtonText(
	button: TextButton,
	text: string
)

	local inText =
		button:FindFirstChild(
			"InText"
		)


	if inText
		and inText:IsA(
			"TextLabel"
		) then

		inText.Text =
			text

		return
	end


	button.Text =
		text
end


local function setButtonEnabled(
	button: TextButton,
	enabled: boolean
)

	button.Active =
		enabled


	button.Selectable =
		enabled


	button.AutoButtonColor =
		enabled
end


local function formatAmount(
	amount: number
): string

	return FormatNumber.Compact(
		amount,
		0
	)
end


local function formatPrice(
	price: number
): string

	return FormatNumber.Currency(
		price,
		1
	)
end


--==================================================
-- PLAYER PLOT
--==================================================

local function getPlayerPlot():
	Model?

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
-- MAXIMUM STOCK FALLBACK
--==================================================

local function getConfiguredMaximumStock(
	stand: Model,
	businessType: string
): number

	local businessConfig =
		BusinessConfig[
			businessType
		]


	if type(businessConfig)
		~= "table" then

		return 0
	end


	local capacities =
		businessConfig.StockCapacityByLevel


	if type(capacities)
		~= "table" then

		return 0
	end


	local level =
		stand:GetAttribute(
			"Level"
		)


	if typeof(level)
		~= "number" then

		level =
			1
	end


	level =
		math.max(
			1,
			math.floor(
				level
			)
		)


	local capacity =
		capacities[
			level
		]


	if typeof(capacity)
		~= "number" then

		return 0
	end


	return math.max(
		0,
		math.floor(
			capacity
		)
	)
end


--==================================================
-- COLLECT BUSINESS STOCK
--==================================================

local function collectBusinessStates():
	{BusinessStockState}

	local plot =
		getPlayerPlot()


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


	local totals: {
		[string]: BusinessStockState
	} = {}

	local highestLevels: {
		[string]: number
	} = {}


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


		local businessType =
			getBusinessType(
				child
			)


		if not businessType then
			continue
		end

		local standLevel =
			child:GetAttribute("Level")
		
		
		if typeof(standLevel) ~= "number"
			or standLevel ~= standLevel
			or standLevel == math.huge
			or standLevel == -math.huge then
		
			standLevel = 1
		end
		
		
		highestLevels[businessType] =
			math.max(
				highestLevels[businessType] or 1,
				math.floor(standLevel)
			)


		local purchaseDefinition =
			StockPurchaseConfig[
				businessType
			]


		local businessDefinition =
			BusinessConfig[
				businessType
			]


		if type(purchaseDefinition)
			~= "table"
			or type(businessDefinition)
				~= "table" then

			continue
		end


		local maximumStock =
			child:GetAttribute(
				"MaxStock"
			)


		if typeof(maximumStock)
			~= "number" then

			maximumStock =
				getConfiguredMaximumStock(
					child,
					businessType
				)
		end


		maximumStock =
			math.max(
				0,
				math.floor(
					maximumStock
				)
			)


		local currentStock =
			child:GetAttribute(
				"Stock"
			)


		--
		-- StockManager initializes a newly placed
		-- stand at full stock. If replication has not
		-- reached this client yet, show it as full
		-- instead of incorrectly showing zero.
		--
		if typeof(currentStock)
			~= "number" then

			currentStock =
				maximumStock
		end


		currentStock =
			math.clamp(
				math.floor(
					currentStock
				),
				0,
				maximumStock
			)


		local state =
			totals[
				businessType
			]


		if not state then

			state = {
				BusinessType =
					businessType,

				DisplayName =
					businessDefinition.DisplayName
					or businessType,

				DisplayOrder =
					tonumber(
						businessDefinition.DisplayOrder
					) or 999,

				CurrentStock =
					0,

				MaximumStock =
					0,

				Shortage =
					0,

				UnitPrice =
					math.max(
						0,
						math.floor(
							tonumber(
								purchaseDefinition.UnitPrice
							) or 0
						)
					),

				Buy1 =
					math.max(
						1,
						math.floor(
							tonumber(
								purchaseDefinition.Buy1
							) or 1
						)
					),

				Buy2 =
					math.max(
						1,
						math.floor(
							tonumber(
								purchaseDefinition.Buy2
							) or 1
						)
					),
			}


			totals[
				businessType
			] = state
		end


		state.CurrentStock +=
			currentStock


		state.MaximumStock +=
			maximumStock
	end


	local states = {}


	for _, state in totals do
	
		state.Shortage =
			math.max(
				0,
				state.MaximumStock
					- state.CurrentStock
			)
	
	
		state.UnitPrice =
			StockPurchaseConfig.GetUnitPrice(
				state.BusinessType,
				highestLevels[state.BusinessType] or 1
			)
	
	
		table.insert(
			states,
			state
		)
	end


	table.sort(
		states,
		function(
			first: BusinessStockState,
			second: BusinessStockState
		)

			if first.DisplayOrder
				== second.DisplayOrder then

				return first.DisplayName
					< second.DisplayName
			end


			return first.DisplayOrder
				< second.DisplayOrder
		end
	)


	return states
end


--==================================================
-- PURCHASE AMOUNT
--==================================================

local function getPurchaseAmount(
	state: BusinessStockState,
	optionName: string
): number

	if state.Shortage <= 0 then
		return 0
	end


	if optionName
		== "Fill" then

		return state.Shortage
	end


	if optionName
		== "Buy1" then

		return math.min(
			state.Shortage,
			state.Buy1
		)
	end


	if optionName
		== "Buy2" then

		return math.min(
			state.Shortage,
			state.Buy2
		)
	end


	return 0
end


--==================================================
-- PURCHASE REQUESTS
--==================================================

local refreshUI


local function performPurchase(
	businessType: string,
	optionName: string
)

	if purchasePending then
		return
	end


	local state =
		currentStates[
			businessType
		]


	if not state
		or state.Shortage <= 0 then

		return
	end


	local purchaseAmount =
		getPurchaseAmount(
			state,
			optionName
		)


	if purchaseAmount <= 0 then
		return
	end


	purchasePending =
		true


	refreshUI()


	local success,
		result =
		pcall(
			function()

				return purchaseStockRemote:
					InvokeServer(
						businessType,
						optionName
					)
			end
		)


	purchasePending =
		false


	if not success then

		warn(
			"[StockUI] Failed to purchase stock:",
			result
		)

	elseif type(result)
		== "table"
		and result.Success
			~= true then

		warn(
			"[StockUI]",
			result.Message
				or "Stock purchase failed."
		)
	end


	--
	-- Give replicated attributes a moment to arrive.
	--
	task.delay(
		0.05,
		function()

			if main.Visible then
				refreshUI()
			end
		end
	)


	refreshUI()
end


local function performRestockAll()

	if purchasePending then
		return
	end


	local hasShortage =
		false


	for _, state in currentStates do

		if state.Shortage > 0 then

			hasShortage =
				true

			break
		end
	end


	if not hasShortage then
		return
	end


	purchasePending =
		true


	refreshUI()


	local success,
		result =
		pcall(
			function()

				return restockAllRemote:
					InvokeServer()
			end
		)


	purchasePending =
		false


	if not success then

		warn(
			"[StockUI] Failed to restock all:",
			result
		)

	elseif type(result)
		== "table"
		and result.Success
			~= true then

		warn(
			"[StockUI]",
			result.Message
				or "Restock all failed."
		)
	end


	task.delay(
		0.05,
		function()

			if main.Visible then
				refreshUI()
			end
		end
	)


	refreshUI()
end


--==================================================
-- CREATE BUSINESS ROW
--==================================================

local function createRow(
	state: BusinessStockState
): RowRefs

	local root =
		template:Clone()


	root.Name =
		`Stock_{state.BusinessType}`


	root.Visible =
		true


	root.LayoutOrder =
		state.DisplayOrder


	local businessName =
		root:WaitForChild(
			"BusinessName"
		) :: TextLabel


	local stockLeft =
		root:WaitForChild(
			"StockLeft"
		) :: TextLabel

	local crateImg =
	root:WaitForChild(
		"CrateImg"
	) :: ImageLabel


	local buy1 =
		root:WaitForChild(
			"Buy1"
		) :: TextButton


	local buy2 =
		root:WaitForChild(
			"Buy2"
		) :: TextButton


	local fill =
		root:WaitForChild(
			"Fill"
		) :: TextButton


	local buy1Text =
		getButtonTextLabel(
			buy1
		)


	local buy2Text =
		getButtonTextLabel(
			buy2
		)


	local fillText =
		getButtonTextLabel(
			fill
		)


	buy1.Text =
		""


	buy2.Text =
		""


	fill.Text =
		""


	buy1Text.Active =
		false


	buy2Text.Active =
		false


	fillText.Active =
		false


	local background =
		root:WaitForChild(
			"Background"
		) :: Frame


	local bar =
		background:WaitForChild(
			"Bar"
		) :: Frame


	local refs: RowRefs = {
		Root =
			root,

		BusinessName =
			businessName,

		StockLeft =
			stockLeft,

		CrateImg =
	crateImg,

		Buy1 =
			buy1,

		Buy1Text =
			buy1Text,

		Buy2 =
			buy2,

		Buy2Text =
			buy2Text,

		Fill =
			fill,

		FillText =
			fillText,

		Bar =
			bar,

		FullBarSize =
			bar.Size,

		Connections =
			{},
	}


	table.insert(
		refs.Connections,

		buy1.Activated:Connect(
			function()

				performPurchase(
					state.BusinessType,
					"Buy1"
				)
			end
		)
	)


	table.insert(
		refs.Connections,

		buy2.Activated:Connect(
			function()

				performPurchase(
					state.BusinessType,
					"Buy2"
				)
			end
		)
	)


	table.insert(
		refs.Connections,

		fill.Activated:Connect(
			function()

				performPurchase(
					state.BusinessType,
					"Fill"
				)
			end
		)
	)


	root.Parent =
		scrollingFrame


	return refs
end


--==================================================
-- DESTROY BUSINESS ROW
--==================================================

local function destroyRow(
	businessType: string
)

	local row =
		rows[
			businessType
		]


	if not row then
		return
	end


	for _, connection in
		row.Connections do

		connection:Disconnect()
	end


	row.Root:Destroy()


	rows[
		businessType
	] = nil
end


--==================================================
-- UPDATE BUSINESS ROW
--==================================================

local function updateRow(
	row: RowRefs,
	state: BusinessStockState
)

	row.Root.LayoutOrder =
		state.DisplayOrder


	row.BusinessName.Text =
		state.DisplayName

	row.CrateImg.Image =
	CRATE_IMAGES[
		state.BusinessType
	]
	or ""


	row.StockLeft.Text =
		`{formatAmount(state.CurrentStock)}/{formatAmount(state.MaximumStock)} stock left`


	local percentage =
		0


	if state.MaximumStock > 0 then

		percentage =
			math.clamp(
				state.CurrentStock
					/ state.MaximumStock,
				0,
				1
			)
	end


	row.Bar.AnchorPoint =
	Vector2.new(
		0,
		row.Bar.AnchorPoint.Y
	)


row.Bar.Position =
	UDim2.new(
		0,
		0,
		row.Bar.Position.Y.Scale,
		row.Bar.Position.Y.Offset
	)


row.Bar.Size =
	UDim2.new(
		percentage,
		0,
		1,
		0
	)


	local full =
		state.Shortage <= 0


	if full then

		row.Buy1Text.Text =
			"FULL"


		row.Buy2Text.Text =
			"FULL"


		row.FillText.Text =
			"FULL"


		setButtonEnabled(
			row.Buy1,
			false
		)


		setButtonEnabled(
			row.Buy2,
			false
		)


		setButtonEnabled(
			row.Fill,
			false
		)


		return
	end


	local buy1Amount =
		getPurchaseAmount(
			state,
			"Buy1"
		)


	local buy2Amount =
		getPurchaseAmount(
			state,
			"Buy2"
		)


	local fillAmount =
		getPurchaseAmount(
			state,
			"Fill"
		)


	local buy1Cost =
		buy1Amount
			* state.UnitPrice


	local buy2Cost =
		buy2Amount
			* state.UnitPrice


	local fillCost =
		fillAmount
			* state.UnitPrice


	row.Buy1Text.Text =
		`Buy {formatAmount(buy1Amount)} - {formatPrice(buy1Cost)}`


	row.Buy2Text.Text =
		`Buy {formatAmount(buy2Amount)} - {formatPrice(buy2Cost)}`


	row.FillText.Text =
		`Fill - {formatPrice(fillCost)}`


	local enabled =
		not purchasePending


	setButtonEnabled(
		row.Buy1,
		enabled
	)


	setButtonEnabled(
		row.Buy2,
		enabled
	)


	setButtonEnabled(
		row.Fill,
		enabled
	)
end


--==================================================
-- REFRESH UI
--==================================================

refreshUI =
	function()

		local states =
			collectBusinessStates()


		local seen: {
			[string]: boolean
		} = {}


		local newStateLookup: {
			[string]: BusinessStockState
		} = {}


		for _, state in states do

			seen[
				state.BusinessType
			] = true


			newStateLookup[
				state.BusinessType
			] = state


			local row =
				rows[
					state.BusinessType
				]


			if not row then

				row =
					createRow(
						state
					)


				rows[
					state.BusinessType
				] = row
			end


			updateRow(
				row,
				state
			)
		end


		local toRemove = {}


		for businessType in rows do

			if not seen[
				businessType
			] then

				table.insert(
					toRemove,
					businessType
				)
			end
		end


		for _, businessType in
			toRemove do

			destroyRow(
				businessType
			)
		end


		currentStates =
			newStateLookup


		--==================================================
		-- RESTOCK ALL
		--==================================================

		local totalCost =
			0


		local totalShortage =
			0


		for _, state in states do

			totalShortage +=
				state.Shortage


			totalCost +=
				state.Shortage
					* state.UnitPrice
		end


		if #states == 0 then

			setOptionalButtonText(
				restockAllButton,
				"Place a Business First"
			)


			setButtonEnabled(
				restockAllButton,
				false
			)


		elseif totalShortage <= 0 then

			setOptionalButtonText(
				restockAllButton,
				"Everything Fully Stocked"
			)


			setButtonEnabled(
				restockAllButton,
				false
			)


		else

			setOptionalButtonText(
				restockAllButton,

				`Restock All - {formatPrice(totalCost)}`
			)


			setButtonEnabled(
				restockAllButton,
				not purchasePending
			)
		end
	end


--==================================================
-- RESTOCK ALL INPUT
--==================================================

restockAllButton.Activated:Connect(
	function()

		performRestockAll()
	end
)


--==================================================
-- STOCK SHOP TOUCH DETECTION
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


local function isPlayerTouchingStockZone():
	boolean

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
-- OPEN / CLOSE
--==================================================

local function openMenu()

	if dismissedUntilExit then
		return
	end


	main.Visible =
		true


	refreshUI()
end


local function hideMenu()

	main.Visible =
		false
end


if closeButton then

	closeButton.Activated:Connect(
		function()

			--
			-- If the player presses X while still
			-- standing on the trigger, do not instantly
			-- reopen the menu.
			--
			-- They must leave the stock area and walk
			-- back in.
			--
			dismissedUntilExit =
				true


			hideMenu()
		end
	)
end


--==================================================
-- INITIAL STATE
--==================================================

--
-- IMPORTANT:
-- We only change Main.Visible.
--
-- StockUI.Enabled is never touched.
--
main.Visible =
	false


--==================================================
-- TOUCH LOOP
--==================================================

task.spawn(
	function()

		while player.Parent do

			local now =
				time()


			local inside =
				isPlayerTouchingStockZone()


			if inside then

				lastInsideTime =
					now


				if not playerInside then

					playerInside =
						true


					dismissedUntilExit =
						false


					openMenu()
				end


				if main.Visible
					and not dismissedUntilExit
					and now - lastUIRefresh
						>= UI_REFRESH_INTERVAL then

					lastUIRefresh =
						now


					refreshUI()
				end


			elseif playerInside
				and now - lastInsideTime
					>= EXIT_GRACE_PERIOD then

				playerInside =
					false


				dismissedUntilExit =
					false


				hideMenu()
			end


			task.wait(
				TOUCH_CHECK_INTERVAL
			)
		end
	end
)