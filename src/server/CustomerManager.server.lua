local Players =
	game:GetService("Players")

local ReplicatedStorage =
	game:GetService("ReplicatedStorage")

local ServerStorage =
	game:GetService("ServerStorage")

local DataService =
	require(
		script.Parent
			:WaitForChild("Services")
			:WaitForChild("DataService")
	)

local Workspace =
	game:GetService("Workspace")

local TweenService =
	game:GetService("TweenService")

local Debris =
	game:GetService("Debris")

local RunService =
	game:GetService("RunService")

local standIsAvailable: (
	stand: Model
) -> boolean

local getPlotCustomerRateMultiplier: (
	plot: Model
) -> number

local CustomerNames =
	require(
		ReplicatedStorage
			:WaitForChild("Shared")
			:WaitForChild("CustomerNames")
	)

local CustomerTypes =
	require(
		ReplicatedStorage
			:WaitForChild("Shared")
			:WaitForChild("CustomerTypes")
	)

local remotes =
	ReplicatedStorage:WaitForChild(
		"Remotes"
	)

local customerVisitUpdated =
	remotes:WaitForChild(
		"CustomerVisitUpdated"
	) :: RemoteEvent


local rareCustomerNotification =
	remotes:WaitForChild(
		"RareCustomerNotification"
	)

local npcInfoTemplate =
	ReplicatedStorage:WaitForChild(
		"NPCInfo"
	)

local BusinessConfig =
	require(
		ReplicatedStorage
			:WaitForChild("Shared")
			:WaitForChild("BusinessConfig")
	)


local UITheme =
	require(
		ReplicatedStorage
			:WaitForChild("Shared")
			:WaitForChild("UITheme")
	)


local CUSTOMER_WALK_ANIMATION_ID =
	"rbxassetid://180426354"


local Colors =
	UITheme.Colors

local Fonts =
	UITheme.Fonts


local CUSTOMER_COLLISION_GROUP =
	"Customers"


local MIN_SPAWN_INTERVAL =
	1.8

local MAX_SPAWN_INTERVAL =
	3.4


local BASE_PLOT_CUSTOMER_LIMIT =
	6


local MIN_COUNTER_RESET_TIME =
	0.1

local MAX_COUNTER_RESET_TIME =
	0.25


--==================================================
-- CUSTOMER MOVEMENT
--==================================================

local WALK_SPEED =
	11


-- How close the customer needs to get before a movement
-- target counts as reached.
local MOVE_REACHED_DISTANCE =
	1.35


-- Reissue Humanoid:MoveTo occasionally in case Roblox
-- drops/stalls a movement command.
local MOVE_COMMAND_INTERVAL =
	0.3


-- Maximum time to reach one movement point.
local MOVE_POINT_TIMEOUT =
	15


-- How long the front customer may take to reach Queue1.
local QUEUE_MOVE_TIMEOUT =
	30


-- Every newly spawned customer visits Queue4 first.
local QUEUE_ENTRANCE_NUMBER =
	4


local plotsFolder =
	Workspace:WaitForChild("Plots")


local npcFolder =
	ServerStorage:WaitForChild("NPCs")


local customersFolder =
	Workspace:FindFirstChild("Customers")


if not customersFolder then
	customersFolder =
		Instance.new("Folder")

	customersFolder.Name =
		"Customers"

	customersFolder.Parent =
		Workspace
end


local businessAvailabilityEvent =
	ServerStorage:FindFirstChild(
		"BusinessAvailabilityChanged"
	)


local randomGenerator =
	Random.new()


type QueueEntry = {
	customer: Model,

	reachedPosition: boolean,
	isLeaving: boolean,

	-- Customer must visit the plot's entrance waypoint
	-- before approaching any stand.
	hasReachedPlotWaypoint: boolean,

	-- Becomes true after this customer has physically
	-- walked to Queue4 once.
	hasEnteredQueue: boolean,

	assignedSlot: number,
	targetPosition: BasePart?,

	controllerRunning: boolean,
	movementVersion: number,
}


type StandState = {
	queue: {QueueEntry},

	isServing: boolean,

	templateBag: {Model},
	lastTemplate: Model?,
}


local standStates: {
	[Model]: StandState
} = {}


local plotNextSpawnTimes: {
	[Model]: number
} = {}

--==================================================
-- CUSTOMER VISUAL EFFECTS
--==================================================

local function createParticleEmitter(
	parent: BasePart,
	name: string,
	texture: string,
	color: ColorSequence,
	rate: number,
	lifetime: NumberRange,
	speed: NumberRange,
	size: NumberSequence
): ParticleEmitter

	local emitter =
		Instance.new("ParticleEmitter")

	emitter.Name =
		name

	emitter.Texture =
		texture

	emitter.Color =
		color

	emitter.Rate =
		rate

	emitter.Lifetime =
		lifetime

	emitter.Speed =
		speed

	emitter.Size =
		size

	emitter.LightEmission =
		0.35

	emitter.SpreadAngle =
		Vector2.new(
			180,
			180
		)

	emitter.Rotation =
		NumberRange.new(
			0,
			360
		)

	emitter.RotSpeed =
		NumberRange.new(
			-35,
			35
		)

	emitter.Parent =
		parent


	return emitter
end


local function addCustomerVisualEffects(
	customer: Model,
	customerType: string
)
	local rootPart =
		customer:FindFirstChild(
			"HumanoidRootPart"
		)

	local head =
		customer:FindFirstChild(
			"Head"
		)


	if not rootPart
		or not rootPart:IsA("BasePart")
		or not head
		or not head:IsA("BasePart") then

		return
	end


	-- Prevent duplicate effects.
	if customer:GetAttribute(
		"CustomerEffectsInitialized"
	) == true then

		return
	end


	local typeConfig =
		CustomerTypes.Get(
			customerType
		)


	--==================================================
-- CUSTOMER TYPE OUTLINE
--==================================================

if customerType ~= "Regular" then

	local highlight =
		Instance.new("Highlight")

	highlight.Name =
		"CustomerTypeOutline"

	highlight.Adornee =
		customer

	highlight.FillTransparency =
		1

	highlight.OutlineColor =
		typeConfig.TextColor

	-- Slightly stronger than before.
	highlight.OutlineTransparency =
		0

	highlight.DepthMode =
		Enum.HighlightDepthMode.Occluded

	highlight.Parent =
		customer
end


	--==================================================
	-- VIP
	--==================================================

	if customerType == "VIP" then

		createParticleEmitter(
			head,
			"VIPSparkles",

			"rbxasset://textures/particles/sparkles_main.dds",

			ColorSequence.new(
				Color3.fromRGB(
					255,
					222,
					73
				)
			),

			4,

			NumberRange.new(
				0.45,
				0.8
			),

			NumberRange.new(
				0.2,
				0.7
			),

			NumberSequence.new({
				NumberSequenceKeypoint.new(
					0,
					0.16
				),

				NumberSequenceKeypoint.new(
					0.5,
					0.22
				),

				NumberSequenceKeypoint.new(
					1,
					0
				),
			})
		)


	--==================================================
	-- CELEBRITY
	--==================================================

	elseif customerType == "Celebrity" then

		createParticleEmitter(
			head,
			"CelebrityStars",

			"rbxasset://textures/particles/sparkles_main.dds",

			ColorSequence.new(
				Color3.fromRGB(
					255,
					102,
					213
				)
			),

			7,

			NumberRange.new(
				0.55,
				0.95
			),

			NumberRange.new(
				0.3,
				0.9
			),

			NumberSequence.new({
				NumberSequenceKeypoint.new(
					0,
					0.2
				),

				NumberSequenceKeypoint.new(
					0.5,
					0.28
				),

				NumberSequenceKeypoint.new(
					1,
					0
				),
			})
		)


	--==================================================
	-- BILLIONAIRE
	--==================================================

	elseif customerType == "Billionaire" then

		local emitter =
			createParticleEmitter(
				rootPart,
				"BillionaireCash",

				"rbxasset://textures/particles/sparkles_main.dds",

				ColorSequence.new(
					Color3.fromRGB(
						77,
						255,
						126
					)
				),

				6,

				NumberRange.new(
					0.7,
					1.1
				),

				NumberRange.new(
					0.6,
					1.2
				),

				NumberSequence.new({
					NumberSequenceKeypoint.new(
						0,
						0.22
					),

					NumberSequenceKeypoint.new(
						0.7,
						0.3
					),

					NumberSequenceKeypoint.new(
						1,
						0
					),
				})
			)


		emitter.Acceleration =
			Vector3.new(
				0,
				2.2,
				0
			)


	--==================================================
	-- GOLDEN
	--==================================================

	elseif customerType == "Golden" then

		local sparkles =
			createParticleEmitter(
				head,
				"GoldenSparkles",

				"rbxasset://textures/particles/sparkles_main.dds",

				ColorSequence.new(
					Color3.fromRGB(
						255,
						214,
						65
					)
				),

				9,

				NumberRange.new(
					0.55,
					0.9
				),

				NumberRange.new(
					0.25,
					0.75
				),

				NumberSequence.new({
					NumberSequenceKeypoint.new(
						0,
						0.18
					),

					NumberSequenceKeypoint.new(
						0.5,
						0.3
					),

					NumberSequenceKeypoint.new(
						1,
						0
					),
				})
			)


		sparkles.LightEmission =
			0.65
	end


	customer:SetAttribute(
		"CustomerEffectsInitialized",
		true
	)
end

--==================================================
-- RARE CUSTOMER NOTIFICATIONS
--==================================================

local NOTIFIED_CUSTOMER_TYPES = {
	VIP = true,
	Celebrity = true,
	Influencer = true,
	Billionaire = true,
	Golden = true,
}


local function notifyRareCustomer(
	plot: Model,
	customerType: string,
	customerName: string
)
	if NOTIFIED_CUSTOMER_TYPES[
		customerType
	] ~= true then

		return
	end


	local ownerUserId =
		plot:GetAttribute(
			"OwnerUserId"
		)


	if typeof(ownerUserId)
			~= "number"
		or ownerUserId <= 0 then

		return
	end


	local player =
		Players:GetPlayerByUserId(
			ownerUserId
		)


	if not player then
		return
	end


	rareCustomerNotification:FireClient(
		player,
		customerType,
		customerName
	)
end

--==================================================
-- CUSTOMER INFO
--==================================================

local function setupCustomerInfo(
	plot: Model,
	customer: Model
)
	if customer:GetAttribute(
		"CustomerInfoInitialized"
	) == true then

		return
	end


	local head =
		customer:FindFirstChild(
			"Head"
		)


	if not head
		or not head:IsA(
			"BasePart"
		) then

		warn(
			`Customer "{customer.Name}" has no Head part.`
		)

		return
	end


	--==================================================
	-- GENERATE CUSTOMER
	--==================================================

	local customerName =
	CustomerNames.GetRandomName(
		customer
	)


	local customerType,
		typeConfig =
		CustomerTypes.GetRandomType()


	--==================================================
	-- CUSTOMER ATTRIBUTES
	--==================================================

	customer:SetAttribute(
		"CustomerName",
		customerName
	)


	customer:SetAttribute(
		"CustomerType",
		customerType
	)


	customer:SetAttribute(
		"PaymentMultiplier",
		typeConfig.PaymentMultiplier
	)


	customer:SetAttribute(
		"TrafficMultiplier",
		typeConfig.TrafficMultiplier
	)

addCustomerVisualEffects(
	customer,
	customerType
)

notifyRareCustomer(
	plot,
	customerType,
	customerName
)

	--==================================================
	-- BILLBOARD
	--==================================================

	local existingInfo =
		head:FindFirstChild(
			"NPCInfo"
		)


	if existingInfo then
		existingInfo:Destroy()
	end


	local billboard =
		npcInfoTemplate:Clone()


	if not billboard:IsA(
		"BillboardGui"
	) then

		warn(
			"ReplicatedStorage.NPCInfo must be a BillboardGui."
		)

		billboard:Destroy()

		return
	end


	billboard.Name =
		"NPCInfo"

	billboard.Adornee =
		head

	billboard.Parent =
		head


	--==================================================
	-- REFERENCES
	--==================================================

	local frame =
		billboard:FindFirstChild(
			"Frame"
		)


	if not frame
		or not frame:IsA(
			"Frame"
		) then

		warn(
			"NPCInfo is missing Frame."
		)

		billboard:Destroy()

		return
	end


	local customerNameLabel =
		frame:FindFirstChild(
			"CustomerName"
		)


	local customerTypeLabel =
		frame:FindFirstChild(
			"CustomerType"
		)


	if not customerNameLabel
		or not customerNameLabel:IsA(
			"TextLabel"
		) then

		warn(
			"NPCInfo.Frame is missing CustomerName TextLabel."
		)

		billboard:Destroy()

		return
	end


	if not customerTypeLabel
		or not customerTypeLabel:IsA(
			"TextLabel"
		) then

		warn(
			"NPCInfo.Frame is missing CustomerType TextLabel."
		)

		billboard:Destroy()

		return
	end


	--==================================================
	-- NAME
	--==================================================

	customerNameLabel.Text =
		customerName


	--==================================================
	-- CUSTOMER TYPE
	--==================================================

	customerTypeLabel.Text =
		typeConfig.DisplayName


	customerTypeLabel.TextColor3 =
		typeConfig.TextColor


	local typeStroke =
		customerTypeLabel:FindFirstChildOfClass(
			"UIStroke"
		)


	if typeStroke then

		typeStroke.Color =
			typeConfig.StrokeColor

	else

		warn(
			"NPCInfo.Frame.CustomerType is missing its UIStroke."
		)
	end

	customer:SetAttribute(
	"CustomerInfoInitialized",
	true
)
end

--==================================================
-- PLOT HELPERS
--==================================================

local function getCustomerWaypoint(
	plot: Model
): BasePart?

	local waypoint =
		plot:FindFirstChild(
			"CustomerWaypoint1"
		)


	if waypoint
		and waypoint:IsA(
			"BasePart"
		) then

		return waypoint
	end


	return nil
end

local function getPlotCustomerLimit(
	plot: Model
): number

	local value =
		plot:GetAttribute(
			"CustomerLimit"
		)


	if typeof(value) ~= "number"
		or value < 1 then

		return BASE_PLOT_CUSTOMER_LIMIT
	end


	return math.max(
		1,
		math.floor(value)
	)
end

local function getActiveCustomerTrafficMultiplier(
	plot: Model
): number

	local bestMultiplier =
		1


	for _, customer in
		customersFolder:GetChildren() do

		if not customer:IsA(
			"Model"
		) then

			continue
		end


		if customer:GetAttribute(
			"PlotName"
		) ~= plot.Name then

			continue
		end


		local multiplier =
			customer:GetAttribute(
				"TrafficMultiplier"
			)


		if typeof(multiplier)
				~= "number"
			or multiplier < 1 then

			continue
		end


		bestMultiplier =
			math.max(
				bestMultiplier,
				multiplier
			)
	end


	return bestMultiplier
end

local function getPlotSpawnInterval(
	plot: Model
): number

	local minimum =
		plot:GetAttribute(
			"MinimumCustomerSpawnInterval"
		)


	local maximum =
		plot:GetAttribute(
			"MaximumCustomerSpawnInterval"
		)


	if typeof(minimum) ~= "number"
		or minimum <= 0 then

		minimum =
			MIN_SPAWN_INTERVAL
	end


	if typeof(maximum) ~= "number"
		or maximum < minimum then

		maximum =
			math.max(
				minimum,
				MAX_SPAWN_INTERVAL
			)
	end


	local baseInterval =
		randomGenerator:NextNumber(
			minimum,
			maximum
		)


	local plotRateMultiplier =
	getPlotCustomerRateMultiplier(
		plot
	)


local customerTrafficMultiplier =
	getActiveCustomerTrafficMultiplier(
		plot
	)


local finalRateMultiplier =
	plotRateMultiplier
		* customerTrafficMultiplier


return baseInterval
	/ finalRateMultiplier
end


local function getBusinessType(
	instance: Model
): string?

	local businessType =
		instance:GetAttribute(
			"BusinessType"
		)


	if typeof(businessType) == "string"
		and BusinessConfig[businessType] then

		return businessType
	end


	for businessName in BusinessConfig do

		if instance.Name == businessName
			or string.match(
				instance.Name,
				`^{businessName}_`
			) then

			return businessName
		end
	end


	return nil
end


local function isSupportedBusiness(
	instance: Instance
): boolean

	if not instance:IsA("Model") then
		return false
	end


	return getBusinessType(
		instance
	) ~= nil
end

local function getPlacedBusinesses(
	plot: Model
): Folder?

	local folder =
		plot:FindFirstChild(
			"PlacedBusinesses"
		)


	if folder
		and folder:IsA("Folder") then

		return folder
	end


	return nil
end


local function getSupportedBusinesses(
	plot: Model
): {Model}

	local placedBusinesses =
		getPlacedBusinesses(
			plot
		)


	if not placedBusinesses then
		return {}
	end


	local businesses: {Model} =
		{}


	for _, child in
		placedBusinesses:GetChildren() do

		if isSupportedBusiness(
			child
		) then

			table.insert(
				businesses,
				child :: Model
			)
		end
	end


	return businesses
end

local function getStandAppearanceLevel(
	stand: Model
): number

	local level =
		stand:GetAttribute(
			"Level"
		)


	if typeof(level) ~= "number"
		or level < 1
		or level % 1 ~= 0 then

		return 1
	end


	return math.floor(
		level
	)
end


local function getStandLevelConfig(
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


	local standLevels =
		config.StandLevels


	if type(standLevels)
		~= "table" then

		return nil
	end


	local level =
		getStandAppearanceLevel(
			stand
		)


	local levelConfig =
		standLevels[
			level
		]


	if type(levelConfig)
		~= "table" then

		return nil
	end


	return levelConfig
end

local function getStandCustomerAttraction(
	stand: Model,
	customer: Model?
): number

	local levelConfig =
		getStandLevelConfig(
			stand
		)

	if not levelConfig then
		return 1
	end


	--==================================================
	-- BASE ATTRACTION
	--==================================================

	local attraction =
		levelConfig.CustomerAttraction

	if typeof(attraction)
			~= "number"
		or attraction <= 0 then

		attraction = 1
	end


	if not customer then
		return attraction
	end


	--==================================================
	-- PREMIUM CUSTOMER ATTRACTION
	--==================================================

	local premiumAttraction =
		levelConfig.PremiumCustomerAttraction

	if typeof(premiumAttraction)
			~= "number"
		or premiumAttraction < 1 then

		premiumAttraction = 1
	end


	local paymentMultiplier =
		customer:GetAttribute(
			"PaymentMultiplier"
		)

	if typeof(paymentMultiplier)
		~= "number" then

		paymentMultiplier = 1
	end


	-- Regular customers get none of this bonus.
	--
	-- Higher-value customers increasingly care about
	-- premium-looking businesses.
	local premiumStrength =
		math.clamp(
			(paymentMultiplier - 1) / 6,
			0,
			1
		)


	local premiumMultiplier =
		1
		+ (
			(premiumAttraction - 1)
			* premiumStrength
		)


	--==================================================
	-- CUSTOMER BUSINESS PREFERENCE
	--==================================================

	local businessPreference =
		1


	local customerType =
		customer:GetAttribute(
			"CustomerType"
		)


	if typeof(customerType)
		== "string" then

		local customerConfig =
			CustomerTypes.Get(
				customerType
			)


		if customerConfig then

			local preferences =
				customerConfig.BusinessPreferences


			if type(preferences)
				== "table" then

				local businessType =
					stand:GetAttribute(
						"BusinessType"
					)


				if typeof(businessType)
					~= "string"
					or businessType == "" then

					for configuredBusinessType in
						BusinessConfig do

						if stand.Name
								== configuredBusinessType
							or string.match(
								stand.Name,
								`^{configuredBusinessType}_`
							) then

							businessType =
								configuredBusinessType

							break
						end
					end
				end


				if typeof(businessType)
					== "string" then

					local configuredPreference =
						preferences[
							businessType
						]


					if typeof(configuredPreference)
							== "number"
						and configuredPreference > 0 then

						businessPreference =
							configuredPreference
					end
				end
			end
		end
	end


	--==================================================
	-- FINAL ATTRACTION
	--==================================================

	return attraction
		* premiumMultiplier
		* businessPreference
end

local function getStandCustomerRateMultiplier(
	stand: Model
): number

	local levelConfig =
		getStandLevelConfig(
			stand
		)


	if not levelConfig then
		return 1
	end


	local multiplier =
		levelConfig.CustomerRateMultiplier


	if typeof(multiplier)
		~= "number"
		or multiplier <= 0 then

		return 1
	end


	return multiplier
end


getPlotCustomerRateMultiplier = function(
	plot: Model
): number
	local bestStandMultiplier =
		1

	for _, stand in
	getSupportedBusinesses(
		plot
	) do

		if not standIsAvailable(
			stand
		) then

			continue
		end

		bestStandMultiplier =
			math.max(
				bestStandMultiplier,

				getStandCustomerRateMultiplier(
					stand
				)
			)
	end

	local reputationMultiplier =
		plot:GetAttribute(
			"ReputationCustomerRateMultiplier"
		)

	if typeof(reputationMultiplier)
			~= "number"
		or reputationMultiplier < 1 then

		reputationMultiplier =
			1
	end

	local monetizationMultiplier =
		1

	local ownerUserId =
		plot:GetAttribute(
			"OwnerUserId"
		)

	if typeof(ownerUserId)
		== "number" then

		local owner =
			Players:GetPlayerByUserId(
				ownerUserId
			)

		if owner then
			local multiplier =
				owner:GetAttribute(
					"CustomerMonetizationMultiplier"
				)

			if typeof(multiplier)
					== "number"
				and multiplier >= 1 then

				monetizationMultiplier =
					multiplier
			end
		end
	end

	return bestStandMultiplier
		* reputationMultiplier
		* monetizationMultiplier
end

local function getPlotCustomerCount(
	plot: Model
): number

	local customerCount =
		0


	for _, customer in
		customersFolder:GetChildren() do

		if not customer:IsA(
			"Model"
		) then

			continue
		end


		if customer:GetAttribute(
			"PlotName"
		) == plot.Name then

			customerCount +=
				1
		end
	end


	return customerCount
end


local function getPlotFromStand(
	stand: Model
): Model?

	local placedBusinesses =
		stand.Parent


	if not placedBusinesses
		or placedBusinesses.Name
			~= "PlacedBusinesses" then

		return nil
	end


	local plot =
		placedBusinesses.Parent


	if plot
		and plot:IsA(
			"Model"
		) then

		return plot
	end


	return nil
end


--==================================================
-- STAND STATE
--==================================================

local function getStandState(
	stand: Model
): StandState

	local existingState =
		standStates[
			stand
		]


	if existingState then
		return existingState
	end


	local newState: StandState = {
		queue = {},

		isServing = false,

		templateBag = {},
		lastTemplate = nil,
	}


	standStates[
		stand
	] = newState


	return newState
end


local function updateStandWaitingCount(
	stand: Model,
	state: StandState
)
	if not stand.Parent then
		return
	end


	local waitingCount =
		0


	for _, entry in
		state.queue do

		if entry.customer.Parent
			and not entry.isLeaving then

			waitingCount +=
				1
		end
	end


	stand:SetAttribute(
		"CustomersWaiting",
		waitingCount
	)
end


--==================================================
-- MONEY
--==================================================

local function getPlayerFromPlot(
	plot: Model
): Player?

	local ownerUserId =
		plot:GetAttribute(
			"OwnerUserId"
		)


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
-- BUSINESS CONFIG
--==================================================

standIsAvailable = function(
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


local function getBusinessCooldown(
	stand: Model
): number

	local standCooldown =
		stand:GetAttribute(
			"PurchaseCooldown"
		)


	if typeof(standCooldown)
			== "number"
		and standCooldown > 0 then

		return standCooldown
	end


	local businessType =
		getBusinessType(
			stand
		)


	local config =
		businessType
		and BusinessConfig[
			businessType
		]


	if config
		and typeof(
			config.BaseServingCooldown
		) == "number"
		and config.BaseServingCooldown > 0 then

		return config.BaseServingCooldown
	end


	return 5
end

local function getBusinessSaleValue(
	stand: Model
): number

	local upgradeSaleValue =
		stand:GetAttribute(
			"SaleValue"
		)

	if typeof(upgradeSaleValue)
			~= "number"
		or upgradeSaleValue < 0 then

		upgradeSaleValue = nil
	end


	local businessType =
		getBusinessType(
			stand
		)


	if not businessType then
		return 0
	end


	local businessConfig =
		BusinessConfig[
			businessType
		]


	if not businessConfig then
		return 0
	end


	if not upgradeSaleValue then
		upgradeSaleValue =
			businessConfig.BaseSaleValue
	end


	if typeof(upgradeSaleValue)
			~= "number"
		or upgradeSaleValue < 0 then

		upgradeSaleValue = 0
	end


	--==================================================
	-- APPEARANCE LEVEL VALUE BONUS
	--==================================================

	local level =
		stand:GetAttribute(
			"Level"
		)


	if typeof(level) ~= "number" then
		level = 1
	end


	level =
		math.max(
			1,
			math.floor(level)
		)


	local standLevels =
		businessConfig.StandLevels


	local levelConfig =
		typeof(standLevels) == "table"
		and standLevels[level]
		or nil


	local saleValueMultiplier =
		1


	if levelConfig
		and typeof(
			levelConfig.SaleValueMultiplier
		) == "number"
		and levelConfig.SaleValueMultiplier > 0 then

		saleValueMultiplier =
			levelConfig.SaleValueMultiplier
	end


	return math.max(
		0,

		math.floor(
			upgradeSaleValue
				* saleValueMultiplier
				+ 0.5
		)
	)
end

--==================================================
-- QUEUE POSITIONS
--==================================================

local function getQueuePositions(
	stand: Model
): {BasePart}

	local queueFolder =
		stand:FindFirstChild(
			"QueuePositions",
			true
		)


	if not queueFolder then

		warn(
			`{stand:GetFullName()} is missing QueuePositions.`
		)

		return {}
	end


	local queuePositions: {
		BasePart
	} = {}


	for _, instance in
		queueFolder:GetChildren() do

		if not instance:IsA(
			"BasePart"
		) then

			continue
		end


		local queueNumber =
			tonumber(
				string.match(
					instance.Name,
					"^Queue(%d+)$"
				)
			)


		if queueNumber then

			table.insert(
				queuePositions,
				instance
			)
		end
	end


	table.sort(
		queuePositions,

		function(
			first: BasePart,
			second: BasePart
		): boolean

			local firstNumber =
				tonumber(
					string.match(
						first.Name,
						"%d+"
					)
				)
				or math.huge


			local secondNumber =
				tonumber(
					string.match(
						second.Name,
						"%d+"
					)
				)
				or math.huge


			return firstNumber
				< secondNumber
		end
	)


	return queuePositions
end


local function getQueuePosition(
	stand: Model,
	queueNumber: number
): BasePart?

	local queueFolder =
		stand:FindFirstChild(
			"QueuePositions",
			true
		)


	if not queueFolder then
		return nil
	end


	local queuePosition =
		queueFolder:FindFirstChild(
			`Queue{queueNumber}`
		)


	if queuePosition
		and queuePosition:IsA(
			"BasePart"
		) then

		return queuePosition
	end


	return nil
end


local function getQueueCapacity(
	stand: Model,
	availablePositions: number
): number

	local capacity =
		stand:GetAttribute(
			"QueueCapacity"
		)


	if typeof(capacity)
			~= "number"
		or capacity ~= capacity
		or capacity == math.huge
		or capacity == -math.huge then

		capacity =
			1
	end


	capacity =
		math.max(
			1,
			math.floor(
				capacity
			)
		)


	return math.min(
		capacity,
		availablePositions
	)
end


local function getStandQueueSpace(
	stand: Model
): (boolean, number, number)

	if not standIsAvailable(
		stand
	) then

		return false, 0, 0
	end


	local queuePositions =
		getQueuePositions(
			stand
		)


	if #queuePositions == 0 then
		return false, 0, 0
	end


	local queueCapacity =
		getQueueCapacity(
			stand,
			#queuePositions
		)


	local state =
		getStandState(
			stand
		)


	local queueCount =
		0


	for _, entry in
		state.queue do

		if entry.customer.Parent
			and not entry.isLeaving then

			queueCount +=
				1
		end
	end


	return queueCount
			< queueCapacity,
		queueCount,
		queueCapacity
end


--==================================================
-- HELPER PART SAFETY
--==================================================

local HELPER_PART_NAMES = {
	PlacementOrigin = true,
	PlacementBounds = true,

	CustomerFacingPosition = true,
	CooldownUIPosition = true,
	ManagementUIPosition = true,
	SaleEffectPosition = true,
}


local function sanitizeStandMarkers(
	stand: Model
)
	for _, descendant in
		stand:GetDescendants() do

		if not descendant:IsA(
			"BasePart"
		) then

			continue
		end


		local isQueuePosition =
			descendant.Parent
			and descendant.Parent.Name
				== "QueuePositions"


		if HELPER_PART_NAMES[
			descendant.Name
		]
			or isQueuePosition then

			descendant.CanCollide =
				false

			descendant.CanTouch =
				false

			descendant.CanQuery =
				false

			descendant.Transparency =
				1
		end
	end
end


--==================================================
-- STAND SELECTION
--==================================================

local function chooseStandForCustomer(
	plot: Model,
	customer: Model
): Model?
	type WeightedStand = {
		Stand: Model,
		Weight: number,
	}


	local choices: {
		WeightedStand
	} = {}


	local totalWeight =
		0


	for _, stand in
	getSupportedBusinesses(
		plot
	) do

		sanitizeStandMarkers(
			stand
		)


		local entrance =
			getQueuePosition(
				stand,
				QUEUE_ENTRANCE_NUMBER
			)


		if not entrance then

			warn(
				`{stand:GetFullName()} needs Queue{QUEUE_ENTRANCE_NUMBER} as its customer entrance.`
			)

			continue
		end


		local hasSpace,
			queueCount,
			queueCapacity =
			getStandQueueSpace(
				stand
			)


		if not hasSpace then
			continue
		end


		local attraction =
	getStandCustomerAttraction(
		stand,
		customer
	)


		-- ==================================================
		-- QUEUE PENALTY
		-- ==================================================
		--
		-- Better-looking stands attract more customers,
		-- but customers still dislike long queues.
		--
		-- Empty queue:
		-- 1.00x
		--
		-- Half full:
		-- ~0.67x
		--
		-- Nearly full:
		-- ~0.5x
		local queueFillRatio =
			queueCount
			/ math.max(
				queueCapacity,
				1
			)


		local queuePenalty =
			1
			/ (
				1
				+ queueFillRatio
			)


		local finalWeight =
			attraction
			* queuePenalty


		if finalWeight <= 0 then
			continue
		end


		totalWeight +=
			finalWeight


		table.insert(
			choices,

			{
				Stand = stand,
				Weight = finalWeight,
			}
		)
	end


	if #choices == 0
		or totalWeight <= 0 then

		return nil
	end


	-- Weighted random selection.
	--
	-- This avoids making upgraded stands ALWAYS win.
	-- They are simply more desirable.
	local roll =
		randomGenerator:NextNumber(
			0,
			totalWeight
		)


	local accumulatedWeight =
		0


	for _, choice in
		choices do

		accumulatedWeight +=
			choice.Weight


		if roll
			<= accumulatedWeight then

			return choice.Stand
		end
	end


	-- Floating point safety fallback.
	return choices[
		#choices
	].Stand
end

--==================================================
-- STAND SERVING STATE
--==================================================

local function setStandServingState(
	stand: Model,
	active: boolean,
	duration: number?
)
	if not stand.Parent then
		return
	end


	stand:SetAttribute(
		"IsServingCustomer",
		active
	)


	if active
		and typeof(duration)
			== "number"
		and duration > 0 then

		stand:SetAttribute(
			"ServiceStartedAt",
			Workspace:GetServerTimeNow()
		)


		stand:SetAttribute(
			"ServiceDuration",
			duration
		)
	else
		stand:SetAttribute(
			"ServiceStartedAt",
			nil
		)


		stand:SetAttribute(
			"ServiceDuration",
			nil
		)
	end
end


--==================================================
-- NPC TEMPLATE SELECTION
--==================================================

local function getValidNpcTemplates(): {
	Model
}

	local templates: {
		Model
	} = {}


	for _, instance in
		npcFolder:GetChildren() do

		if not instance:IsA(
			"Model"
		) then

			continue
		end


		local humanoid =
			instance:FindFirstChildOfClass(
				"Humanoid"
			)


		local rootPart =
			instance:FindFirstChild(
				"HumanoidRootPart"
			)


		local torso =
			instance:FindFirstChild(
				"Torso"
			)


		if not humanoid
			or humanoid.RigType
				~= Enum.HumanoidRigType.R6
			or not rootPart
			or not rootPart:IsA(
				"BasePart"
			)
			or not torso
			or not torso:IsA(
				"BasePart"
			) then

			continue
		end


		table.insert(
			templates,
			instance
		)
	end


	return templates
end


local function shuffleTemplates(
	templates: {Model}
)
	for index =
		#templates,
		2,
		-1 do

		local swapIndex =
			randomGenerator:NextInteger(
				1,
				index
			)


		templates[index],
			templates[swapIndex] =

			templates[swapIndex],
			templates[index]
	end
end


local function refillTemplateBag(
	state: StandState
): boolean

	local templates =
		getValidNpcTemplates()


	if #templates == 0 then

		warn(
			"No valid R6 NPC templates were found in ServerStorage.NPCs."
		)

		return false
	end


	shuffleTemplates(
		templates
	)


	if #templates > 1
		and state.lastTemplate
		and templates[#templates]
			== state.lastTemplate then

		templates[#templates],
			templates[1] =

			templates[1],
			templates[#templates]
	end


	state.templateBag =
		templates


	return true
end


local function getNextNpcTemplate(
	state: StandState
): Model?

	while true do

		if #state.templateBag
			== 0 then

			if not refillTemplateBag(
				state
			) then

				return nil
			end
		end


		local template =
			table.remove(
				state.templateBag
			)


		if template
			and template.Parent
				== npcFolder then

			state.lastTemplate =
				template


			return template
		end
	end
end


--==================================================
-- WALK ANIMATION
--==================================================

local function setupCustomerMovementAnimation(
	customer: Model,
	humanoid: Humanoid
)
	-- Prevent another Animate controller from fighting
	-- with the customer movement animation.
	for _, descendant in
		customer:GetDescendants() do

		if descendant.Name
			== "Animate"
			and (
				descendant:IsA(
					"LocalScript"
				)
				or descendant:IsA(
					"Script"
				)
			) then

			descendant.Enabled =
				false
		end
	end


	local animator =
		humanoid:FindFirstChildOfClass(
			"Animator"
		)


	if not animator then

		animator =
			Instance.new(
				"Animator"
			)

		animator.Parent =
			humanoid
	end


	local animation =
		Instance.new(
			"Animation"
		)


	animation.Name =
		"CustomerWalkAnimation"

	animation.AnimationId =
		CUSTOMER_WALK_ANIMATION_ID


	local success,
		walkTrack =
		pcall(function()

			return animator:LoadAnimation(
				animation
			)
		end)


	animation:Destroy()


	if not success
		or not walkTrack then

		warn(
			`Could not load walk animation for {customer:GetFullName()}.`
		)

		return
	end


	walkTrack.Name =
		"CustomerWalk"

	walkTrack.Priority =
		Enum.AnimationPriority.Movement

	walkTrack.Looped =
		true


	local function startWalking(
		speed: number
	)
		if humanoid.Health <= 0 then
			return
		end


		if speed > 0.15 then

			if not walkTrack.IsPlaying then

				walkTrack:Play(
					0.08,
					1,
					1
				)
			end


			walkTrack:AdjustSpeed(
				math.clamp(
					speed
						/ WALK_SPEED,

					0.75,
					1.5
				)
			)

		elseif walkTrack.IsPlaying then

			walkTrack:Stop(
				0.1
			)
		end
	end


	humanoid.Running:Connect(
		startWalking
	)


	humanoid.Died:Connect(
		function()

			if walkTrack.IsPlaying then

				walkTrack:Stop(
					0
				)
			end
		end
	)


	-- Extra safety:
	-- if Roblox physically moves the NPC but Running
	-- doesn't restart the animation, detect velocity.
	task.spawn(function()

		while customer.Parent
			and humanoid.Parent
			and humanoid.Health > 0 do

			local rootPart =
				customer:FindFirstChild(
					"HumanoidRootPart"
				)


			if rootPart
				and rootPart:IsA(
					"BasePart"
				) then

				local velocity =
					Vector3.new(
						rootPart.AssemblyLinearVelocity.X,
						0,
						rootPart.AssemblyLinearVelocity.Z
					).Magnitude


				if velocity > 0.5 then

					if not walkTrack.IsPlaying then

						walkTrack:Play(
							0.08,
							1,
							1
						)
					end


					walkTrack:AdjustSpeed(
						math.clamp(
							velocity
								/ WALK_SPEED,

							0.75,
							1.5
						)
					)

				elseif walkTrack.IsPlaying
					and humanoid.MoveDirection.Magnitude
						<= 0.01 then

					walkTrack:Stop(
						0.1
					)
				end
			end


			task.wait(
				0.15
			)
		end
	end)
end


local function prepareCustomer(
	customer: Model
)
	local humanoid =
		customer:FindFirstChildOfClass(
			"Humanoid"
		)


	local rootPart =
		customer:FindFirstChild(
			"HumanoidRootPart"
		)


	if humanoid then

	humanoid.DisplayDistanceType =
		Enum.HumanoidDisplayDistanceType.None

	humanoid.HealthDisplayType =
		Enum.HumanoidHealthDisplayType.AlwaysOff

	humanoid.AutoRotate =
		true

	humanoid.WalkSpeed =
		WALK_SPEED


		setupCustomerMovementAnimation(
			customer,
			humanoid
		)
	end


	for _, descendant in
		customer:GetDescendants() do

		if descendant:IsA(
			"BasePart"
		) then

			descendant.Anchored =
				false

			descendant.CollisionGroup =
				CUSTOMER_COLLISION_GROUP
		end
	end


	customer.DescendantAdded:Connect(
		function(
			descendant: Instance
		)
			if descendant:IsA(
				"BasePart"
			) then

				descendant.CollisionGroup =
					CUSTOMER_COLLISION_GROUP
			end
		end
	)


	if rootPart
		and rootPart:IsA(
			"BasePart"
		) then

		local canSetOwnership =
			rootPart:CanSetNetworkOwnership()


		if canSetOwnership then

			rootPart:SetNetworkOwner(
				nil
			)
		end
	end
end


--==================================================
-- BASIC MOVEMENT
--==================================================

local function moveCustomerToPosition(
	customer: Model,
	targetPosition: Vector3,
	shouldContinue: (() -> boolean)?
): boolean

	local humanoid =
		customer:FindFirstChildOfClass(
			"Humanoid"
		)


	local rootPart =
		customer:FindFirstChild(
			"HumanoidRootPart"
		)


	if not humanoid
		or not rootPart
		or not rootPart:IsA(
			"BasePart"
		) then

		return false
	end


	humanoid.AutoRotate =
		true


	local startedAt =
		time()

	local lastCommandAt =
		0

	local lastProgressAt =
		time()

	local lastDistance =
		math.huge


	while customer.Parent
		and humanoid.Health > 0 do

		if shouldContinue
			and not shouldContinue() then

			humanoid:MoveTo(
				rootPart.Position
			)

			return false
		end


		local offset =
			Vector3.new(
				rootPart.Position.X
					- targetPosition.X,

				0,

				rootPart.Position.Z
					- targetPosition.Z
			)


		local distance =
			offset.Magnitude


		if distance
			<= MOVE_REACHED_DISTANCE then

			humanoid:MoveTo(
				rootPart.Position
			)

			return true
		end


		if time() - startedAt
			>= MOVE_POINT_TIMEOUT then

			return false
		end


		if distance
			< lastDistance - 0.05 then

			lastDistance =
				distance

			lastProgressAt =
				time()

		elseif time() - lastProgressAt
			>= 3 then

			-- Customer hasn't made meaningful progress.
			return false
		end


		if time() - lastCommandAt
			>= MOVE_COMMAND_INTERVAL then

			humanoid:MoveTo(
				targetPosition
			)

			lastCommandAt =
				time()
		end


		RunService.Heartbeat:Wait()
	end


	return false
end


local function moveCustomerToPart(
	customer: Model,
	target: BasePart
): boolean

	return moveCustomerToPosition(
		customer,
		target.Position,
		nil
	)
end


--==================================================
-- CUSTOMER FACING
--==================================================

local function faceCustomerTowardStand(
	customer: Model,
	stand: Model
)
	local humanoid =
		customer:FindFirstChildOfClass(
			"Humanoid"
		)


	local rootPart =
		customer:FindFirstChild(
			"HumanoidRootPart"
		)


	if not humanoid
		or not rootPart
		or not rootPart:IsA(
			"BasePart"
		) then

		return
	end


	local facingPosition =
		stand:FindFirstChild(
			"CustomerFacingPosition",
			true
		)


	local targetPosition


	if facingPosition
		and facingPosition:IsA(
			"BasePart"
		) then

		targetPosition =
			facingPosition.Position
	else
		targetPosition =
			stand:GetPivot().Position
	end


	local horizontalTarget =
		Vector3.new(
			targetPosition.X,
			rootPart.Position.Y,
			targetPosition.Z
		)


	if (
		horizontalTarget
			- rootPart.Position
	).Magnitude < 0.05 then

		return
	end


	humanoid.AutoRotate =
		false


	rootPart.CFrame =
		CFrame.lookAt(
			rootPart.Position,
			horizontalTarget
		)
end


--==================================================
-- SALE EFFECT
--==================================================

local function showCashPopup(
	stand: Model,
	amount: number
)
	local effectPosition =
		stand:FindFirstChild(
			"SaleEffectPosition",
			true
		)
		or stand:FindFirstChild(
			"CooldownUIPosition",
			true
		)


	if not effectPosition
		or not effectPosition:IsA(
			"BasePart"
		) then

		return
	end


	local billboard =
		Instance.new(
			"BillboardGui"
		)


	billboard.Name =
		"CashPopup"

	billboard.Adornee =
		effectPosition

	billboard.Size =
		UDim2.fromScale(
			4.2,
			1.2
		)

	billboard.StudsOffsetWorldSpace =
		Vector3.new(
			0,
			1.8,
			0
		)

	billboard.AlwaysOnTop =
		true

	billboard.LightInfluence =
		0

	billboard.MaxDistance =
		80

	billboard.Parent =
		effectPosition


	local container =
		Instance.new(
			"Frame"
		)


	container.Name =
		"Container"

	container.AnchorPoint =
		Vector2.new(
			0.5,
			0.5
		)

	container.Position =
		UDim2.fromScale(
			0.5,
			0.5
		)

	container.Size =
		UDim2.fromScale(
			0.94,
			0.86
		)

	container.BackgroundColor3 =
		Colors.Success

	container.BorderSizePixel =
		0

	container.Parent =
		billboard


	UITheme.AddCorner(
		container,
		0.25
	)


	local stroke =
		UITheme.AddStroke(
			container,
			Colors.Success,
			2,
			0.12
		)


	local amountLabel =
		Instance.new(
			"TextLabel"
		)


	amountLabel.Name =
		"Amount"

	amountLabel.Size =
		UDim2.fromScale(
			1,
			1
		)

	amountLabel.BackgroundTransparency =
		1

	amountLabel.Text =
		string.format(
			"+$%d",
			amount
		)

	amountLabel.Parent =
		container


	UITheme.StyleText(
		amountLabel,
		15,
		27,
		Colors.Text,
		Fonts.Black
	)


	local moveTween =
		TweenService:Create(
			billboard,

			TweenInfo.new(
				1,
				Enum.EasingStyle.Back,
				Enum.EasingDirection.Out
			),

			{
				StudsOffsetWorldSpace =
					Vector3.new(
						0,
						4.3,
						0
					),
			}
		)


	local labelFade =
		TweenService:Create(
			amountLabel,

			TweenInfo.new(
				0.3,
				Enum.EasingStyle.Linear,
				Enum.EasingDirection.Out,
				0,
				false,
				0.68
			),

			{
				TextTransparency =
					1,
			}
		)


	local backgroundFade =
		TweenService:Create(
			container,

			TweenInfo.new(
				0.3,
				Enum.EasingStyle.Linear,
				Enum.EasingDirection.Out,
				0,
				false,
				0.68
			),

			{
				BackgroundTransparency =
					1,
			}
		)


	local strokeFade =
		TweenService:Create(
			stroke,

			TweenInfo.new(
				0.3,
				Enum.EasingStyle.Linear,
				Enum.EasingDirection.Out,
				0,
				false,
				0.68
			),

			{
				Transparency =
					1,
			}
		)


	moveTween:Play()
	labelFade:Play()
	backgroundFade:Play()
	strokeFade:Play()


	Debris:AddItem(
		billboard,
		1.15
	)
end


local function playSaleSound(
	stand: Model
)
	local saleSound =
		stand:FindFirstChild(
			"SaleSound",
			true
		)


	if saleSound
		and saleSound:IsA(
			"Sound"
		) then

		saleSound:Play()
	end
end


local function rewardPlotOwner(
	plot: Model,
	stand: Model,
	customer: Model
): boolean
	local player =
		getPlayerFromPlot(
			plot
		)

	if not player then
		return false
	end

	local cash =
		getCashValue(
			player
		)

	if not cash then
		return false
	end

	local baseSaleValue =
	getBusinessSaleValue(
		stand
	)

	local cashMultiplier =
		player:GetAttribute(
			"CashMultiplier"
		)

	if typeof(cashMultiplier)
			~= "number"
		or cashMultiplier < 1 then

		cashMultiplier =
			1
	end

	local customerPaymentMultiplier =
	customer:GetAttribute(
		"PaymentMultiplier"
	)


if typeof(customerPaymentMultiplier)
		~= "number"
	or customerPaymentMultiplier < 1 then

	customerPaymentMultiplier =
		1
end

	local finalSaleValue =
	math.max(
		0,

		math.floor(
			baseSaleValue
				* cashMultiplier
				* customerPaymentMultiplier
				+ 0.5
		)
	)

	cash.Value +=
		finalSaleValue

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
		) + finalSaleValue
	)

	-- Keep literal TotalSales accurate.
	-- Reputation Boost adds separate bonus progress.
	local reputationMultiplier =
		player:GetAttribute(
			"ReputationSaleMultiplier"
		)

	if typeof(reputationMultiplier)
			== "number"
		and reputationMultiplier > 1 then

		local bonusSales =
			math.max(
				0,
				math.floor(
					reputationMultiplier - 1
				)
			)

		if bonusSales > 0 then
			DataService.AddReputationBonusSales(
				player,
				bonusSales
			)
		end
	end

	--==================================================
-- CUSTOMER INDEX VISIT
--==================================================

local customerType =
	customer:GetAttribute(
		"CustomerType"
	)


if typeof(customerType)
	== "string" then

	local newVisitAmount =
		DataService.AddCustomerVisit(
			player,
			customerType,
			1
		)


	customerVisitUpdated:FireClient(
		player,
		customerType,
		newVisitAmount
	)
end

	showCashPopup(
		stand,
		finalSaleValue
	)

	playSaleSound(
		stand
	)

	return true
end

--==================================================
-- EXIT MOVEMENT
--==================================================

local function sendCustomerToExit(
	plot: Model,
	customer: Model
)
	local customerExit =
		plot:FindFirstChild(
			"CustomerExit"
		)


	if not customerExit
		or not customerExit:IsA(
			"BasePart"
		) then

		customer:Destroy()

		return
	end


	local waypoint =
		getCustomerWaypoint(
			plot
		)


	task.spawn(function()

		--==================================================
		-- FIRST: RETURN TO CUSTOMER WAYPOINT
		--==================================================

		if waypoint
			and waypoint.Parent
			and customer.Parent then

			moveCustomerToPosition(
				customer,
				waypoint.Position,
				nil
			)
		end


		if not customer.Parent then
			return
		end


		--==================================================
		-- THEN: WALK TO EXIT
		--==================================================

		moveCustomerToPosition(
			customer,
			customerExit.Position,
			nil
		)


		if customer.Parent then
			customer:Destroy()
		end
	end)
end

--==================================================
-- QUEUE MOVEMENT
--==================================================

local function runQueueMovementController(
	stand: Model,
	entry: QueueEntry
)
	if entry.controllerRunning then
		return
	end


	entry.controllerRunning =
		true


	local customer =
		entry.customer


	local humanoid =
		customer:FindFirstChildOfClass(
			"Humanoid"
		)


	local rootPart =
		customer:FindFirstChild(
			"HumanoidRootPart"
		)


	if not humanoid
		or not rootPart
		or not rootPart:IsA(
			"BasePart"
		) then

		entry.controllerRunning =
			false

		return
	end


	while customer.Parent
		and stand.Parent
		and not entry.isLeaving do

		local target =
			entry.targetPosition


		if not target
			or not target.Parent then

			entry.reachedPosition =
				false

			RunService.Heartbeat:Wait()

			continue
		end


		local movementVersion =
			entry.movementVersion


		entry.reachedPosition =
			false


		--==================================================
		-- STEP 1: ALWAYS VISIT CUSTOMERWAYPOINT1 FIRST
		--==================================================

		if not entry.hasReachedPlotWaypoint then

			local plot =
				getPlotFromStand(
					stand
				)


			if not plot then

				entry.isLeaving =
					true

				break
			end


			local waypoint =
				getCustomerWaypoint(
					plot
				)


			if not waypoint then

				warn(
					`{plot:GetFullName()} is missing CustomerWaypoint1.`
				)

				entry.isLeaving =
					true

				break
			end


			local waypointVersion =
				entry.movementVersion


			local reachedWaypoint =
				moveCustomerToPosition(
					customer,
					waypoint.Position,

					function()

						return customer.Parent
								~= nil

							and stand.Parent
								~= nil

							and not entry.isLeaving

							and entry.movementVersion
								== waypointVersion
					end
				)


			if not customer.Parent
				or entry.isLeaving then

				break
			end


			-- Queue assignment changed while walking.
			if entry.movementVersion
				~= waypointVersion then

				continue
			end


			if not reachedWaypoint then

				entry.isLeaving =
					true

				break
			end


			entry.hasReachedPlotWaypoint =
				true
		end


		--==================================================
		-- STEP 2: FIRST STAND ENTRY ALWAYS GOES TO QUEUE4
		--==================================================

		if not entry.hasEnteredQueue then

			local entrance =
				getQueuePosition(
					stand,
					QUEUE_ENTRANCE_NUMBER
				)


			if not entrance then

				warn(
					`{stand:GetFullName()} is missing Queue{QUEUE_ENTRANCE_NUMBER}.`
				)


				entry.isLeaving =
					true

				break
			end


			local entranceVersion =
				entry.movementVersion


			local reachedEntrance =
				moveCustomerToPosition(
					customer,
					entrance.Position,

					function()

						return customer.Parent
								~= nil

							and stand.Parent
								~= nil

							and not entry.isLeaving

							and entry.movementVersion
								== entranceVersion
					end
				)


			if not customer.Parent
				or entry.isLeaving then

				break
			end


			if entry.movementVersion
				~= entranceVersion then

				continue
			end


			if not reachedEntrance then

				entry.isLeaving =
					true

				break
			end


			entry.hasEnteredQueue =
				true
		end


		--==================================================
		-- STEP 3: WALK TO THE CURRENT ASSIGNED QUEUE SLOT
		--==================================================

		local currentTarget =
			entry.targetPosition


		if not currentTarget
			or not currentTarget.Parent then

			continue
		end


		movementVersion =
			entry.movementVersion


		local targetAtStart =
			currentTarget


		-- If Queue4 itself is their assigned slot,
		-- they are already at the correct position.
		local entrance =
			getQueuePosition(
				stand,
				QUEUE_ENTRANCE_NUMBER
			)


		if entrance
			and targetAtStart
				== entrance then

			entry.reachedPosition =
				true


			humanoid:MoveTo(
				rootPart.Position
			)


			while customer.Parent
				and stand.Parent
				and not entry.isLeaving
				and entry.targetPosition
					== targetAtStart
				and entry.movementVersion
					== movementVersion do

				RunService.Heartbeat:Wait()
			end


			continue
		end


		local reachedTarget =
			moveCustomerToPosition(
				customer,
				targetAtStart.Position,

				function()

					return customer.Parent
							~= nil

						and stand.Parent
							~= nil

						and not entry.isLeaving

						and entry.targetPosition
							== targetAtStart

						and entry.movementVersion
							== movementVersion
				end
			)


		if not customer.Parent
			or entry.isLeaving then

			break
		end


		-- Their queue slot changed while walking.
		if entry.targetPosition
				~= targetAtStart
			or entry.movementVersion
				~= movementVersion then

			continue
		end


		if not reachedTarget then

			entry.isLeaving =
				true

			entry.reachedPosition =
				false

			break
		end


		entry.reachedPosition =
			true


		humanoid:MoveTo(
			rootPart.Position
		)


		-- Remain here until the queue moves forward.
		while customer.Parent
			and stand.Parent
			and not entry.isLeaving
			and entry.targetPosition
				== targetAtStart
			and entry.movementVersion
				== movementVersion do

			RunService.Heartbeat:Wait()
		end
	end


	entry.controllerRunning =
		false
end

local function moveQueueForward(
	stand: Model,
	state: StandState
)
	local queuePositions =
		getQueuePositions(
			stand
		)


	for queueIndex, entry in
		state.queue do

		local targetPosition =
			queuePositions[
				queueIndex
			]


		if not targetPosition
			or entry.isLeaving then

			continue
		end


		if entry.targetPosition
			~= targetPosition then

			entry.movementVersion +=
				1
		end


		entry.assignedSlot =
			queueIndex


		entry.targetPosition =
			targetPosition


		entry.reachedPosition =
			false


		if not entry.controllerRunning then

			task.spawn(
				runQueueMovementController,
				stand,
				entry
			)
		end
	end
end


--==================================================
-- EVACUATING A STAND
--==================================================

local function evacuateStandCustomers(
	plot: Model,
	stand: Model,
	state: StandState
)
	setStandServingState(
		stand,
		false
	)


	local customersToRemove: {
		QueueEntry
	} = {}


	for _, entry in
		state.queue do

		table.insert(
			customersToRemove,
			entry
		)
	end


	table.clear(
		state.queue
	)


	updateStandWaitingCount(
		stand,
		state
	)


	for _, entry in
		customersToRemove do

		entry.isLeaving =
			true

		entry.targetPosition =
			nil

		entry.reachedPosition =
			false

		entry.movementVersion +=
			1


		local customer =
			entry.customer


		if customer
			and customer.Parent then

			local humanoid =
				customer:FindFirstChildOfClass(
					"Humanoid"
				)


			local rootPart =
				customer:FindFirstChild(
					"HumanoidRootPart"
				)


			if humanoid then

				humanoid.AutoRotate =
					true


				if rootPart
					and rootPart:IsA(
						"BasePart"
					) then

					humanoid:MoveTo(
						rootPart.Position
					)
				end
			end


			sendCustomerToExit(
				plot,
				customer
			)
		end
	end
end


if businessAvailabilityEvent
	and businessAvailabilityEvent:IsA(
		"BindableEvent"
	) then

	businessAvailabilityEvent.Event:Connect(
		function(
			plot: Model,
			stand: Model
		)
			if not plot
				or not plot:IsA(
					"Model"
				)
				or not stand
				or not stand:IsA(
					"Model"
				) then

				return
			end


			if getPlotFromStand(
				stand
			) ~= plot then

				return
			end


			local state =
				standStates[
					stand
				]


			if not state then
				return
			end


			evacuateStandCustomers(
				plot,
				stand,
				state
			)
		end
	)
end


--==================================================
-- PROCESS SALES
--==================================================

local function processQueue(
	plot: Model,
	stand: Model
)
	local state =
		getStandState(
			stand
		)


	if state.isServing then
		return
	end


	state.isServing =
		true


	while standIsAvailable(
		stand
	)
		and #state.queue > 0 do

		local firstEntry =
			state.queue[1]


		if not firstEntry
			or not firstEntry.customer.Parent then

			table.remove(
				state.queue,
				1
			)


			updateStandWaitingCount(
				stand,
				state
			)


			moveQueueForward(
				stand,
				state
			)


			continue
		end


		local waitStartedAt =
			time()


		while firstEntry.customer.Parent
			and not firstEntry.isLeaving
			and standIsAvailable(
				stand
			) do

			local readyForService =
				firstEntry.assignedSlot
					== 1

				and firstEntry.targetPosition
					~= nil

				and firstEntry.reachedPosition


			if readyForService then
				break
			end


			if time() - waitStartedAt
				>= QUEUE_MOVE_TIMEOUT then

				firstEntry.isLeaving =
					true

				break
			end


			task.wait(
				0.05
			)
		end


		if not standIsAvailable(
			stand
		) then

			break
		end


		if firstEntry.isLeaving
			or not firstEntry.customer.Parent then

			local customer =
				firstEntry.customer


			table.remove(
				state.queue,
				1
			)


			updateStandWaitingCount(
				stand,
				state
			)


			if customer.Parent then

				sendCustomerToExit(
					plot,
					customer
				)
			end


			moveQueueForward(
				stand,
				state
			)


			continue
		end


		faceCustomerTowardStand(
			firstEntry.customer,
			stand
		)


		local transactionTime =
	getBusinessCooldown(
		stand
	)


		firstEntry.customer:SetAttribute(
			"TransactionTime",
			transactionTime
		)


		setStandServingState(
			stand,
			true,
			transactionTime
		)


		local transactionEndsAt =
			time()
				+ transactionTime


		local transactionCompleted =
			true


		while time()
			< transactionEndsAt do

			transactionCompleted =
				not firstEntry.isLeaving

				and firstEntry.customer.Parent
					~= nil

				and standIsAvailable(
					stand
				)


			if not transactionCompleted then
				break
			end


			task.wait(
				0.05
			)
		end


		setStandServingState(
			stand,
			false
		)


		if not transactionCompleted then
			break
		end


		rewardPlotOwner(
	plot,
	stand,
	firstEntry.customer
)


		firstEntry.isLeaving =
			true

		firstEntry.targetPosition =
			nil

		firstEntry.reachedPosition =
			false

		firstEntry.movementVersion +=
			1


		local customer =
			firstEntry.customer


		local humanoid =
			customer:FindFirstChildOfClass(
				"Humanoid"
			)


		local rootPart =
			customer:FindFirstChild(
				"HumanoidRootPart"
			)


		if humanoid then

			humanoid.AutoRotate =
				true


			if rootPart
				and rootPart:IsA(
					"BasePart"
				) then

				humanoid:MoveTo(
					rootPart.Position
				)
			end
		end


		table.remove(
			state.queue,
			1
		)


		updateStandWaitingCount(
			stand,
			state
		)


		sendCustomerToExit(
			plot,
			customer
		)


		moveQueueForward(
			stand,
			state
		)


		task.wait(
			randomGenerator:NextNumber(
				MIN_COUNTER_RESET_TIME,
				MAX_COUNTER_RESET_TIME
			)
		)
	end


	setStandServingState(
		stand,
		false
	)


	state.isServing =
		false
end


--==================================================
-- SPAWNING
--==================================================

local function spawnCustomerForStand(
	plot: Model,
	stand: Model
): boolean

	if not standIsAvailable(
		stand
	) then

		return false
	end


	if getPlotCustomerCount(
		plot
	) >= getPlotCustomerLimit(
		plot
	) then

		return false
	end


	local entrance =
		getQueuePosition(
			stand,
			QUEUE_ENTRANCE_NUMBER
		)


	if not entrance then

		warn(
			`{stand:GetFullName()} cannot spawn customers because Queue{QUEUE_ENTRANCE_NUMBER} is missing.`
		)

		return false
	end


	local state =
		getStandState(
			stand
		)


	local queuePositions =
		getQueuePositions(
			stand
		)


	if #queuePositions == 0 then
		return false
	end


	local queueCapacity =
		getQueueCapacity(
			stand,
			#queuePositions
		)


	if #state.queue
		>= queueCapacity then

		return false
	end


	local customerSpawn =
		plot:FindFirstChild(
			"CustomerSpawn"
		)


	if not customerSpawn
		or not customerSpawn:IsA(
			"BasePart"
		) then

		return false
	end


	local npcTemplate =
		getNextNpcTemplate(
			state
		)


	if not npcTemplate then
		return false
	end


	local customer =
		npcTemplate:Clone()


	customer.Name =
		"Customer"


	customer:SetAttribute(
		"CharacterTemplate",
		npcTemplate.Name
	)


	customer:SetAttribute(
		"PlotName",
		plot.Name
	)


	customer:SetAttribute(
		"BusinessId",

		stand:GetAttribute(
			"BusinessId"
		)
			or stand.Name
	)


	prepareCustomer(
	customer
)


customer.Parent =
	customersFolder


customer:PivotTo(
	customerSpawn.CFrame
		* CFrame.new(
			0,
			3,
			0
		)
)


setupCustomerInfo(
	plot,
	customer
)


	local entry: QueueEntry = {
	customer =
		customer,

	reachedPosition =
		false,

	isLeaving =
		false,

	hasReachedPlotWaypoint =
		false,

	hasEnteredQueue =
		false,

	assignedSlot =
		0,

	targetPosition =
		nil,

	controllerRunning =
		false,

	movementVersion =
		0,
}


	table.insert(
		state.queue,
		entry
	)


	updateStandWaitingCount(
		stand,
		state
	)


	moveQueueForward(
		stand,
		state
	)


	task.spawn(
		processQueue,
		plot,
		stand
	)


	return true
end


--==================================================
-- CLEANUP
--==================================================

local function plotHasOwner(
	plot: Model
): boolean

	local ownerUserId =
		plot:GetAttribute(
			"OwnerUserId"
		)


	return typeof(ownerUserId)
			== "number"
		and ownerUserId > 0
end


local function cleanStandState(
	stand: Model
)
	local state =
		standStates[
			stand
		]


	if not state then
		return
	end


	for _, entry in
		state.queue do

		if entry.customer.Parent then

			entry.customer:Destroy()
		end
	end


	if stand.Parent then

		stand:SetAttribute(
			"CustomersWaiting",
			0
		)
	end


	setStandServingState(
		stand,
		false
	)


	standStates[
		stand
	] = nil
end


local function cleanPlotCustomers(
	plot: Model
)
	for stand in
		standStates do

		if getPlotFromStand(
			stand
		) == plot then

			cleanStandState(
				stand
			)
		end
	end
end


Players.PlayerRemoving:Connect(
	function(
		player: Player
	)
		for _, plot in
			plotsFolder:GetChildren() do

			if not plot:IsA(
				"Model"
			) then

				continue
			end


			if plot:GetAttribute(
				"OwnerUserId"
			) == player.UserId then

				cleanPlotCustomers(
					plot
				)
			end
		end
	end
)


--==================================================
-- SPAWN LOOP
--==================================================

while true do

	local currentTime =
		time()


	for stand in
		standStates do

		if not stand.Parent then

			cleanStandState(
				stand
			)
		end
	end


	for plot in
		plotNextSpawnTimes do

		if not plot.Parent
			or not plot:IsDescendantOf(
				plotsFolder
			) then

			plotNextSpawnTimes[
				plot
			] = nil
		end
	end


	for _, plot in
		plotsFolder:GetChildren() do

		if not plot:IsA(
			"Model"
		)
			or not plotHasOwner(
				plot
			) then

			plotNextSpawnTimes[
				plot
			] = nil

			continue
		end


		local nextSpawnTime =
			plotNextSpawnTimes[
				plot
			]


		if typeof(nextSpawnTime)
			~= "number" then

			plotNextSpawnTimes[
				plot
			] =
				currentTime
				+ getPlotSpawnInterval(
					plot
				)

			continue
		end


		if currentTime
			< nextSpawnTime then

			continue
		end


		if getPlotCustomerCount(
			plot
		) >= getPlotCustomerLimit(
			plot
		) then

			plotNextSpawnTimes[
				plot
			] =
				currentTime + 0.5

			continue
		end


		local selectedStand =
			chooseStandForCustomer(
				plot,
				customer
			)


		if selectedStand then

			spawnCustomerForStand(
				plot,
				selectedStand
			)
		end


		plotNextSpawnTimes[
			plot
		] =
			currentTime
			+ getPlotSpawnInterval(
				plot
			)
	end


	task.wait(
		0.2
	)
end