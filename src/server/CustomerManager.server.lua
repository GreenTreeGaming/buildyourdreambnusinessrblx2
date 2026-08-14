local Players = game:GetService("Players")
local ReplicatedStorage =
	game:GetService("ReplicatedStorage")
local ServerStorage =
	game:GetService("ServerStorage")
local Workspace =
	game:GetService("Workspace")
local PathfindingService =
	game:GetService("PathfindingService")
local TweenService =
	game:GetService("TweenService")
local Debris =
	game:GetService("Debris")
local RunService =
	game:GetService("RunService")

local BusinessConfig = require(
	ReplicatedStorage
		:WaitForChild("Shared")
		:WaitForChild("BusinessConfig")
)

local UITheme = require(
	ReplicatedStorage
		:WaitForChild("Shared")
		:WaitForChild("UITheme")
)

local CUSTOMER_WALK_ANIMATION_ID =
	"rbxassetid://180426354"

local Colors = UITheme.Colors
local Fonts = UITheme.Fonts

local BUSINESS_NAME = "LemonadeStand"

local lemonadeStandConfig =
	BusinessConfig.LemonadeStand

local DEFAULT_LEMONADE_COOLDOWN =
	lemonadeStandConfig.BaseServingCooldown

local DEFAULT_LEMONADE_SALE_VALUE =
	lemonadeStandConfig.BaseSaleValue

local CUSTOMER_COLLISION_GROUP =
	"Customers"

local MIN_SPAWN_INTERVAL = 1.8
local MAX_SPAWN_INTERVAL = 3.4

-- Maximum number of customer NPCs that may belong
-- to one plot at the same time.
--
-- This includes customers:
-- walking to a stand,
-- waiting in a queue,
-- being served,
-- and walking toward the exit.
local BASE_PLOT_CUSTOMER_LIMIT = 6

local MIN_COUNTER_RESET_TIME = 0.1
local MAX_COUNTER_RESET_TIME = 0.25

local QUEUE_REACHED_DISTANCE = 1.75
local QUEUE_COMMAND_INTERVAL = 0.4
local QUEUE_MOVE_TIMEOUT = 10

local PATH_TIMEOUT = 20
local PATH_WAYPOINT_REACHED_DISTANCE = 3
local PATH_FINAL_REACHED_DISTANCE = 2
local PATH_REISSUE_INTERVAL = 0.75
local PATH_STUCK_TIME = 2

-- Customers pathfind to a point outside the business
-- before the normal queue controller takes over.
local STAND_APPROACH_CLEARANCE =
	3.5

local plotsFolder =
	Workspace:WaitForChild("Plots")

local npcFolder =
	ServerStorage:WaitForChild("NPCs")

local customersFolder =
	Workspace:FindFirstChild("Customers")

if not customersFolder then
	customersFolder =
		Instance.new("Folder")

	customersFolder.Name = "Customers"
	customersFolder.Parent = Workspace
end

local businessAvailabilityEvent =
	ServerStorage:FindFirstChild(
		"BusinessAvailabilityChanged"
	)

local randomGenerator = Random.new()

type QueueEntry = {
	customer: Model,

	reachedPosition: boolean,
	isLeaving: boolean,

	-- False while the customer is pathfinding around
	-- the stand toward the queue entrance.
	approachComplete: boolean,

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

		minimum = MIN_SPAWN_INTERVAL
	end

	if typeof(maximum) ~= "number"
		or maximum < minimum then

		maximum =
			math.max(
				minimum,
				MAX_SPAWN_INTERVAL
			)
	end

	return randomGenerator:NextNumber(
		minimum,
		maximum
	)
end

local function isLemonadeStand(
	instance: Instance
): boolean
	if not instance:IsA("Model") then
		return false
	end

	local businessType =
		instance:GetAttribute("BusinessType")

	if businessType == BUSINESS_NAME then
		return true
	end

	if instance.Name == BUSINESS_NAME then
		return true
	end

	return string.match(
		instance.Name,
		"^LemonadeStand_"
	) ~= nil
end

local function getPlacedBusinesses(
	plot: Model
): Folder?
	local folder =
		plot:FindFirstChild(
			"PlacedBusinesses"
		)

	if folder and folder:IsA("Folder") then
		return folder
	end

	return nil
end

local function getLemonadeStands(
	plot: Model
): {Model}
	local placedBusinesses =
		getPlacedBusinesses(plot)

	if not placedBusinesses then
		return {}
	end

	local stands = {}

	for _, child in
		placedBusinesses:GetChildren() do

		if isLemonadeStand(child) then
			table.insert(
				stands,
				child :: Model
			)
		end
	end

	return stands
end

local function getPlotCustomerCount(
	plot: Model
): number
	local customerCount = 0

	for _, customer in
		customersFolder:GetChildren() do

		if not customer:IsA("Model") then
			continue
		end

		if customer:GetAttribute("PlotName")
			== plot.Name then

			customerCount += 1
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

	if plot and plot:IsA("Model") then
		return plot
	end

	return nil
end

local function getStandState(
	stand: Model
): StandState
	local existingState =
		standStates[stand]

	if existingState then
		return existingState
	end

		local newState: StandState = {
		queue = {},
		isServing = false,

		templateBag = {},
		lastTemplate = nil,
	}

	standStates[stand] =
		newState

	return newState
end

local function updateStandWaitingCount(
	stand: Model,
	state: StandState
)
	if not stand.Parent then
		return
	end

	local waitingCount = 0

	for _, entry in state.queue do
		if entry.customer.Parent
			and not entry.isLeaving then

			waitingCount += 1
		end
	end

	stand:SetAttribute(
		"CustomersWaiting",
		waitingCount
	)
end

local function getPlayerFromPlot(
	plot: Model
): Player?
	local ownerUserId =
		plot:GetAttribute("OwnerUserId")

	if typeof(ownerUserId) ~= "number"
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
		leaderstats:FindFirstChild("Cash")

	if cash and cash:IsA("IntValue") then
		return cash
	end

	return nil
end

local function standIsAvailable(
	stand: Model
): boolean
	if not stand.Parent then
		return false
	end

	if not isLemonadeStand(stand) then
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

local function getLemonadeCooldown(
	stand: Model
): number
	local standCooldown =
		stand:GetAttribute(
			"PurchaseCooldown"
		)

	if typeof(standCooldown) == "number"
		and standCooldown > 0 then

		return standCooldown
	end

	return DEFAULT_LEMONADE_COOLDOWN
end

local function getCashPerSale(
	stand: Model
): number
	local levelValue =
		stand:GetAttribute("Level")

	local level = 1

	if typeof(levelValue) == "number"
		and levelValue >= 1
		and levelValue % 1 == 0 then

		level = levelValue
	end

	local standConfig =
		BusinessConfig.LemonadeStand

	if typeof(standConfig) ~= "table" then
		return 2
	end

	local levels = standConfig.Levels

	if typeof(levels) ~= "table" then
		return 2
	end

	local levelConfig = levels[level]

	if typeof(levelConfig) ~= "table" then
		return 2
	end

	local cashPerSale =
		levelConfig.CashPerSale

	if typeof(cashPerSale) ~= "number"
		or cashPerSale < 0 then

		return 2
	end

	return math.floor(cashPerSale)
end

local function getLemonadeSaleValue(
	stand: Model
): number
	local saleValue =
		stand:GetAttribute("SaleValue")

	if typeof(saleValue) == "number"
		and saleValue >= 0 then

		return math.floor(saleValue)
	end

	return DEFAULT_LEMONADE_SALE_VALUE
end

local getQueuePositions: (
	stand: Model
) -> {BasePart}

local function getQueueCapacity(
	stand: Model,
	availablePositions: number
): number
	local capacity =
		stand:GetAttribute(
			"QueueCapacity"
		)

	if typeof(capacity) ~= "number"
		or capacity ~= capacity
		or capacity == math.huge
		or capacity == -math.huge then

		capacity = 1
	end

	capacity =
		math.max(
			1,
			math.floor(capacity)
		)

	-- Never allow more customers than the model has
	-- physical queue positions for.
	return math.min(
		capacity,
		availablePositions
	)
end

local function getStandQueueSpace(
	stand: Model
): (boolean, number, number)
	if not standIsAvailable(stand) then
		return false, 0, 0
	end

	local queuePositions =
		getQueuePositions(stand)

	if #queuePositions == 0 then
		return false, 0, 0
	end

	local queueCapacity =
		getQueueCapacity(
			stand,
			#queuePositions
		)

	local state =
		getStandState(stand)

	local queueCount = 0

	for _, entry in state.queue do
		if entry.customer.Parent
			and not entry.isLeaving then

			queueCount += 1
		end
	end

	return queueCount < queueCapacity,
		queueCount,
		queueCapacity
end

local function prepareStandPathfinding(
	stand: Model
)
	local placementBounds =
		stand:FindFirstChild(
			"PlacementBounds",
			true
		)

	if not placementBounds
		or not placementBounds:IsA(
			"BasePart"
		) then

		return
	end

	local existing =
		stand:FindFirstChild(
			"CustomerPathBlocker"
		)

	if existing
		and existing:IsA(
			"BasePart"
		) then

		return
	end

	local blocker =
		Instance.new("Part")

	blocker.Name =
		"CustomerPathBlocker"

	blocker.Anchored =
		true

	blocker.CanCollide =
		false

	blocker.CanTouch =
		false

	blocker.CanQuery =
		false

	blocker.Transparency =
		1

	blocker.CastShadow =
		false

	-- Reserve the physical center of the business while
	-- leaving some room around the edge where its queue,
	-- door and customer positions may exist.
	blocker.Size =
		Vector3.new(
			math.max(
				1,
				placementBounds.Size.X - 1.25
			),

			math.max(
				4,
				placementBounds.Size.Y
			),

			math.max(
				1,
				placementBounds.Size.Z - 1.25
			)
		)

	blocker.CFrame =
		placementBounds.CFrame
			* CFrame.new(
				0,
				blocker.Size.Y / 2,
				0
			)

	blocker.Parent =
		stand

	local modifier =
		Instance.new(
			"PathfindingModifier"
		)

	modifier.Name =
		"BusinessPathfindingModifier"

	modifier.Label =
		"BusinessObstacle"

	modifier.PassThrough =
		false

	modifier.Parent =
		blocker
end

local function chooseStandForCustomer(
	plot: Model
): Model?
	local availableStands: {Model} = {}

	local lowestQueueCount =
		math.huge

	for _, stand in
		getLemonadeStands(plot) do

			prepareStandPathfinding(
		stand
	)

		local hasSpace, queueCount =
			getStandQueueSpace(stand)

		if not hasSpace then
			continue
		end

		if queueCount < lowestQueueCount then
			lowestQueueCount =
				queueCount

			table.clear(
				availableStands
			)

			table.insert(
				availableStands,
				stand
			)
		elseif queueCount
			== lowestQueueCount then

			table.insert(
				availableStands,
				stand
			)
		end
	end

	if #availableStands == 0 then
		return nil
	end

	return availableStands[
		randomGenerator:NextInteger(
			1,
			#availableStands
		)
	]
end

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
		and typeof(duration) == "number"
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

getQueuePositions = function(
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

	local queuePositions = {}

	for _, instance in
		queueFolder:GetChildren() do

		if not instance:IsA("BasePart") then
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
		function(first, second)
			local firstNumber =
				tonumber(
					string.match(
						first.Name,
						"%d+"
					)
				) or math.huge

			local secondNumber =
				tonumber(
					string.match(
						second.Name,
						"%d+"
					)
				) or math.huge

			return firstNumber
				< secondNumber
		end
	)

	return queuePositions
end

local function getValidNpcTemplates(): {Model}
	local templates = {}

	for _, instance in
		npcFolder:GetChildren() do

		if not instance:IsA("Model") then
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
			instance:FindFirstChild("Torso")

		if not humanoid
			or humanoid.RigType
				~= Enum.HumanoidRigType.R6
			or not rootPart
			or not rootPart:IsA("BasePart")
			or not torso
			or not torso:IsA("BasePart") then

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
	for index = #templates, 2, -1 do
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

	shuffleTemplates(templates)

	if #templates > 1
		and state.lastTemplate
		and templates[#templates]
			== state.lastTemplate then

		templates[#templates],
		templates[1] =
			templates[1],
			templates[#templates]
	end

	state.templateBag = templates

	return true
end

local function getNextNpcTemplate(
	state: StandState
): Model?
	while true do
		if #state.templateBag == 0 then
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

local function setupCustomerMovementAnimation(
	customer: Model,
	humanoid: Humanoid
)
	-- We control customer walking ourselves.
	-- Disable any copied Animate scripts so they cannot
	-- fight with this movement animation controller.
	for _, descendant in customer:GetDescendants() do
		if descendant.Name == "Animate"
			and (
				descendant:IsA("LocalScript")
				or descendant:IsA("Script")
			) then

			descendant.Enabled = false
		end
	end

	local animator =
		humanoid:FindFirstChildOfClass(
			"Animator"
		)

	if not animator then
		animator =
			Instance.new("Animator")

		animator.Parent =
			humanoid
	end

	local animation =
		Instance.new("Animation")

	animation.Name =
		"CustomerWalkAnimation"

	animation.AnimationId =
		CUSTOMER_WALK_ANIMATION_ID

	local success, walkTrack =
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

	local function updateWalkAnimation(
		speed: number
	)
		if humanoid.Health <= 0 then
			if walkTrack.IsPlaying then
				walkTrack:Stop(0.1)
			end

			return
		end

		if speed > 0.15 then
			if not walkTrack.IsPlaying then
				walkTrack:Play(
					0.12,
					1,
					1
				)
			end

			-- Keep animation speed reasonably matched
			-- to actual humanoid movement.
			walkTrack:AdjustSpeed(
				math.clamp(
					speed / 11,
					0.75,
					1.4
				)
			)
		elseif walkTrack.IsPlaying then
			walkTrack:Stop(
				0.12
			)
		end
	end

	humanoid.Running:Connect(
		updateWalkAnimation
	)

	humanoid.Died:Connect(function()
		if walkTrack.IsPlaying then
			walkTrack:Stop(0)
		end
	end)

	-- Safety check.
	--
	-- Running can occasionally miss the exact moment an
	-- NPC begins moving after spawning/path recalculation,
	-- so periodically make sure physical movement and the
	-- animation track agree.
	task.spawn(function()
		while customer.Parent
			and humanoid.Parent
			and humanoid.Health > 0 do

			local rootPart =
				customer:FindFirstChild(
					"HumanoidRootPart"
				)

			if rootPart
				and rootPart:IsA("BasePart") then

				local horizontalVelocity =
					Vector3.new(
						rootPart.AssemblyLinearVelocity.X,
						0,
						rootPart.AssemblyLinearVelocity.Z
					).Magnitude

				if horizontalVelocity > 0.5 then
					if not walkTrack.IsPlaying then
						walkTrack:Play(
							0.08,
							1,
							1
						)
					end
				elseif walkTrack.IsPlaying
					and humanoid.MoveDirection.Magnitude
						<= 0.01 then

					walkTrack:Stop(
						0.1
					)
				end
			end

			task.wait(
				0.2
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
	humanoid.DisplayName =
		"Customer"

	humanoid.AutoRotate =
		true

	humanoid.WalkSpeed =
		11

	setupCustomerMovementAnimation(
		customer,
		humanoid
	)
end

	for _, descendant in
		customer:GetDescendants() do

		if descendant:IsA("BasePart") then
			descendant.Anchored = false

			descendant.CollisionGroup =
				CUSTOMER_COLLISION_GROUP
		end
	end

	customer.DescendantAdded:Connect(
		function(descendant)
			if descendant:IsA(
				"BasePart"
			) then
				descendant.CollisionGroup =
					CUSTOMER_COLLISION_GROUP
			end
		end
	)

	if rootPart
		and rootPart:IsA("BasePart") then

		local canSetOwnership =
			rootPart:CanSetNetworkOwnership()

		if canSetOwnership then
			rootPart:SetNetworkOwner(nil)
		end
	end
end

local function createPathPoints(
	startPosition: Vector3,
	targetPosition: Vector3
): {PathWaypoint}?
	local path =
		PathfindingService:CreatePath({
			AgentRadius = 2,
			AgentHeight = 5,

			AgentCanJump = true,
			AgentCanClimb = false,

			WaypointSpacing = 4,

			Costs = {
				BusinessObstacle =
					math.huge,
			},
		})

	local success, calculationError =
		pcall(function()
			path:ComputeAsync(
				startPosition,
				targetPosition
			)
		end)

	if not success then
		warn(
			`Path calculation failed: {calculationError}`
		)

		return nil
	end

	if path.Status
		~= Enum.PathStatus.Success then

		return nil
	end

	return path:GetWaypoints()
end

local function moveCustomerToPosition(
	customer: Model,
	targetPosition: Vector3,
	allowDirectFallback: boolean?,
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
		or not rootPart:IsA("BasePart") then

		return false
	end


	humanoid.AutoRotate =
		true


	local waypoints =
		createPathPoints(
			rootPart.Position,
			targetPosition
		)


	if not waypoints
		or #waypoints == 0 then

		-- For queue approaches we specifically DON'T
		-- want to fall back to a straight MoveTo because
		-- that is what lets NPCs walk through buildings.
		if allowDirectFallback == false then
			return false
		end


		waypoints = {
			{
				Position =
					targetPosition,

				Action =
					Enum.PathWaypointAction.Walk,

				Label = "",
			},
		}
	end


	local waypointIndex =
		1


	if #waypoints >= 2
		and (
			rootPart.Position
				- waypoints[1].Position
		).Magnitude
			<= PATH_WAYPOINT_REACHED_DISTANCE then

		waypointIndex =
			2
	end


	local startedAt =
		time()

	local lastCommandAt =
		0

	local lastProgressAt =
		time()

	local lastDistance =
		math.huge

	local recalculations =
		0


	while customer.Parent
		and humanoid.Health > 0 do

		if shouldContinue
			and not shouldContinue() then

			humanoid:MoveTo(
				rootPart.Position
			)

			return false
		end


		if time() - startedAt
			>= PATH_TIMEOUT then

			return false
		end


		local finalOffset =
			Vector3.new(
				rootPart.Position.X
					- targetPosition.X,

				0,

				rootPart.Position.Z
					- targetPosition.Z
			)


		if finalOffset.Magnitude
			<= PATH_FINAL_REACHED_DISTANCE then

			humanoid:MoveTo(
				rootPart.Position
			)

			return true
		end


		local waypoint =
			waypoints[
				waypointIndex
			]


		if not waypoint then
			waypoint = {
				Position =
					targetPosition,

				Action =
					Enum.PathWaypointAction.Walk,

				Label = "",
			}
		end


		local waypointOffset =
			Vector3.new(
				rootPart.Position.X
					- waypoint.Position.X,

				0,

				rootPart.Position.Z
					- waypoint.Position.Z
			)


		if waypointOffset.Magnitude
			<= PATH_WAYPOINT_REACHED_DISTANCE
			and waypointIndex
				< #waypoints then

			waypointIndex +=
				1


			waypoint =
				waypoints[
					waypointIndex
				]


			lastCommandAt =
				0
		end


		if waypoint.Action
			== Enum.PathWaypointAction.Jump then

			humanoid.Jump =
				true
		end


		if time() - lastCommandAt
			>= PATH_REISSUE_INTERVAL then

			humanoid:MoveTo(
				waypoint.Position
			)


			lastCommandAt =
				time()
		end


		local currentDistance =
			Vector3.new(
				rootPart.Position.X
					- targetPosition.X,

				0,

				rootPart.Position.Z
					- targetPosition.Z
			).Magnitude


		if currentDistance
			< lastDistance - 0.1 then

			lastDistance =
				currentDistance

			lastProgressAt =
				time()

		elseif time() - lastProgressAt
				>= PATH_STUCK_TIME
			and recalculations < 3 then

			recalculations +=
				1


			lastProgressAt =
				time()


			local newWaypoints =
				createPathPoints(
					rootPart.Position,
					targetPosition
				)


			if newWaypoints
				and #newWaypoints > 0 then

				waypoints =
					newWaypoints


				waypointIndex =
					1


				if #waypoints >= 2
					and (
						rootPart.Position
							- waypoints[1].Position
					).Magnitude
						<= PATH_WAYPOINT_REACHED_DISTANCE then

					waypointIndex =
						2
				end


				lastCommandAt =
					0

				lastDistance =
					math.huge
			elseif allowDirectFallback
				~= false then

				humanoid:MoveTo(
					targetPosition
				)
			else
				return false
			end
		end


		RunService.Heartbeat:Wait()
	end


	return false
end


local function moveCustomerTo(
	customer: Model,
	target: BasePart
): boolean
	return moveCustomerToPosition(
		customer,
		target.Position,
		true,
		nil
	)
end

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
		or not rootPart:IsA("BasePart") then

		return
	end

	local facingPosition =
		stand:FindFirstChild(
			"CustomerFacingPosition",
			true
		)

	local targetPosition

	if facingPosition
		and facingPosition:IsA("BasePart") then

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

	humanoid.AutoRotate = false

	rootPart.CFrame =
		CFrame.lookAt(
			rootPart.Position,
			horizontalTarget
		)
end

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
		Instance.new("BillboardGui")

	billboard.Name = "CashPopup"
	billboard.Adornee =
		effectPosition

	billboard.Size =
		UDim2.fromScale(4.2, 1.2)

	billboard.StudsOffsetWorldSpace =
		Vector3.new(0, 1.8, 0)

	billboard.AlwaysOnTop = true
	billboard.LightInfluence = 0
	billboard.MaxDistance = 80
	billboard.Parent =
		effectPosition

	local container =
		Instance.new("Frame")

	container.Name = "Container"
	container.AnchorPoint =
		Vector2.new(0.5, 0.5)

	container.Position =
		UDim2.fromScale(0.5, 0.5)

	container.Size =
		UDim2.fromScale(0.94, 0.86)

	container.BackgroundColor3 =
		Colors.Success

	container.BorderSizePixel = 0
	container.Parent = billboard

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
		Instance.new("TextLabel")

	amountLabel.Name = "Amount"
	amountLabel.Size =
		UDim2.fromScale(1, 1)

	amountLabel.BackgroundTransparency = 1

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
				TextTransparency = 1,
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
				BackgroundTransparency = 1,
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
				Transparency = 1,
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
		and saleSound:IsA("Sound") then

		saleSound:Play()
	end
end

local function rewardPlotOwner(
	plot: Model,
	stand: Model
): boolean
	local player =
		getPlayerFromPlot(plot)

	if not player then
		return false
	end

	local cash =
		getCashValue(player)

	if not cash then
		return false
	end

	local saleValue =
		getLemonadeSaleValue(stand)

	cash.Value += saleValue

	local totalSales =
		stand:GetAttribute("TotalSales")

	if typeof(totalSales) ~= "number" then
		totalSales = 0
	end

	local lifetimeEarnings =
		stand:GetAttribute("LifetimeEarnings")

	if typeof(lifetimeEarnings) ~= "number" then
		lifetimeEarnings = 0
	end

	stand:SetAttribute(
		"TotalSales",
		math.max(
			0,
			math.floor(totalSales)
		) + 1
	)

	stand:SetAttribute(
		"LifetimeEarnings",
		math.max(
			0,
			math.floor(lifetimeEarnings)
		) + saleValue
	)

	showCashPopup(
		stand,
		saleValue
	)

	playSaleSound(stand)

	return true
end

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

	task.spawn(function()
		moveCustomerTo(
			customer,
			customerExit
		)

		if customer.Parent then
			customer:Destroy()
		end
	end)
end

local function runQueueMovementController(
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

		local targetAtStart =
			target


		local reached =
			moveCustomerToPosition(
				customer,
				target.Position,

				-- This is crucial.
				--
				-- Never use direct MoveTo fallback for
				-- movement around businesses.
				false,

				function()
					return customer.Parent
							~= nil

						and not entry.isLeaving

						and entry.targetPosition
							== targetAtStart

						and entry.movementVersion
							== movementVersion
				end
			)


		if entry.isLeaving
			or not customer.Parent then

			break
		end


		-- Queue moved while we were pathfinding.
		-- Recalculate for the new target.
		if entry.targetPosition
			~= targetAtStart
			or entry.movementVersion
				~= movementVersion then

			continue
		end


		if reached then
			entry.reachedPosition =
				true


			humanoid:MoveTo(
				rootPart.Position
			)


			-- Wait here until this customer advances
			-- to another queue position.
			while customer.Parent
				and not entry.isLeaving
				and entry.targetPosition
					== targetAtStart
				and entry.movementVersion
					== movementVersion do

				RunService.Heartbeat:Wait()
			end
		else
			-- Don't walk straight through the stand just
			-- because pathfinding failed.
			entry.isLeaving =
				true

			entry.reachedPosition =
				false

			break
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
				entry
			)
		end
	end
end

local function getStandApproachPosition(
	stand: Model,
	queuePosition: Vector3
): Vector3

	local placementBounds =
		stand:FindFirstChild(
			"PlacementBounds",
			true
		)


	if not placementBounds
		or not placementBounds:IsA(
			"BasePart"
		) then

		return queuePosition
	end


	local localQueuePosition =
		placementBounds.CFrame
			:PointToObjectSpace(
				queuePosition
			)


	local halfX =
		placementBounds.Size.X
			/ 2

	local halfZ =
		placementBounds.Size.Z
			/ 2


	local normalizedX =
		math.abs(
			localQueuePosition.X
		) / math.max(
			halfX,
			0.01
		)


	local normalizedZ =
		math.abs(
			localQueuePosition.Z
		) / math.max(
			halfZ,
			0.01
		)


	local approachLocal


	if normalizedX > normalizedZ then

		local direction =
			localQueuePosition.X >= 0
				and 1
				or -1


		approachLocal =
			Vector3.new(
				direction
					* (
						halfX
						+ STAND_APPROACH_CLEARANCE
					),

				0,

				math.clamp(
					localQueuePosition.Z,
					-halfZ,
					halfZ
				)
			)
	else

		local direction =
			localQueuePosition.Z >= 0
				and 1
				or -1


		approachLocal =
			Vector3.new(
				math.clamp(
					localQueuePosition.X,
					-halfX,
					halfX
				),

				0,

				direction
					* (
						halfZ
						+ STAND_APPROACH_CLEARANCE
					)
			)
	end


	local worldApproach =
		placementBounds.CFrame
			:PointToWorldSpace(
				approachLocal
			)


	return Vector3.new(
		worldApproach.X,
		queuePosition.Y,
		worldApproach.Z
	)
end


local function approachStandBeforeQueue(
	plot: Model,
	stand: Model,
	state: StandState,
	entry: QueueEntry
)
	local customer =
		entry.customer


	if not customer.Parent
		or entry.isLeaving then

		return
	end


	local initialMovementVersion =
		entry.movementVersion


	local queueTarget =
		entry.targetPosition


	if not queueTarget
		or not queueTarget.Parent then

		entry.isLeaving =
			true

		return
	end


	local approachPosition =
		getStandApproachPosition(
			stand,
			queueTarget.Position
		)


	local reachedApproach =
		moveCustomerToPosition(
			customer,
			approachPosition,

			-- Never straight-line fallback through
			-- the business.
			false,

			function()
				return customer.Parent
						~= nil

					and stand.Parent
						~= nil

					and standIsAvailable(
						stand
					)

					and not entry.isLeaving

					and entry.movementVersion
						== initialMovementVersion
			end
		)


	if not customer.Parent
		or entry.isLeaving
		or entry.movementVersion
			~= initialMovementVersion then

		return
	end


	if not reachedApproach then
		entry.isLeaving =
			true

		entry.targetPosition =
			nil

		entry.reachedPosition =
			false

		return
	end


	-- The NPC has now approached the OUTSIDE of the
	-- stand using real pathfinding.
	entry.approachComplete =
		true


	-- Their queue position may have changed while
	-- walking toward the stand, so refresh assignments.
	moveQueueForward(
		stand,
		state
	)
end

local function evacuateStandCustomers(
	plot: Model,
	stand: Model,
	state: StandState
)
	-- Stop the current service timer immediately.
	setStandServingState(
		stand,
		false
	)

	-- Copy the entries before clearing the queue.
	local customersToRemove: {
		QueueEntry
	} = {}

	for _, entry in state.queue do
		table.insert(
			customersToRemove,
			entry
		)
	end

	table.clear(state.queue)

updateStandWaitingCount(
	stand,
	state
)

	for _, entry in customersToRemove do
		entry.isLeaving = true
		entry.targetPosition = nil
		entry.reachedPosition = false
		entry.movementVersion += 1

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
				humanoid.AutoRotate = true

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
				or not plot:IsA("Model")
				or not stand
				or not stand:IsA("Model") then

				return
			end

			if getPlotFromStand(stand)
				~= plot then

				return
			end

			local state =
				standStates[stand]

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

local function processQueue(
	plot: Model,
	stand: Model
)
	local state =
		getStandState(stand)

	if state.isServing then
		return
	end

	state.isServing = true

	while standIsAvailable(stand)
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

		local waitStartedAt = time()

		while firstEntry.customer.Parent
			and not firstEntry.isLeaving
			and standIsAvailable(stand) do

			local readyForService =
				firstEntry.assignedSlot == 1
				and firstEntry.targetPosition
					~= nil
				and firstEntry.reachedPosition

			if readyForService then
				break
			end

			local allowedMoveTime

if firstEntry.approachComplete then
	allowedMoveTime =
		QUEUE_MOVE_TIMEOUT
else
	allowedMoveTime =
		PATH_TIMEOUT + 2
end


if time() - waitStartedAt
	>= allowedMoveTime then

	firstEntry.isLeaving =
		true

	break
end

			task.wait(0.05)
		end

		if not standIsAvailable(stand) then
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
			getLemonadeCooldown(
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
			time() + transactionTime

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

			task.wait(0.05)
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
			stand
		)

		firstEntry.isLeaving = true
		firstEntry.targetPosition = nil
		firstEntry.reachedPosition = false
		firstEntry.movementVersion += 1

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
			humanoid.AutoRotate = true

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

	state.isServing = false
end

local function spawnCustomerForStand(
	plot: Model,
	stand: Model
): boolean
	if not standIsAvailable(stand) then
		return false
	end

	if getPlotCustomerCount(plot)
	>= getPlotCustomerLimit(plot) then

		return false
	end

	local state =
		getStandState(stand)

	local queuePositions =
		getQueuePositions(stand)

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
		getNextNpcTemplate(state)

	if not npcTemplate then
		return false
	end

	local customer =
		npcTemplate:Clone()

	customer.Name = "Customer"

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
		) or stand.Name
	)

	prepareCustomer(customer)

	customer.Parent =
		customersFolder

	customer:PivotTo(
		customerSpawn.CFrame
			* CFrame.new(0, 3, 0)
	)

	local entry: QueueEntry = {
	customer = customer,

	reachedPosition = false,
	isLeaving = false,

	approachComplete = false,

	assignedSlot = 0,
	targetPosition = nil,

	controllerRunning = false,
	movementVersion = 0,
}

	table.insert(
		state.queue,
		entry
	)

	updateStandWaitingCount(
		stand,
		state
	)

	-- Reserve and assign the customer's queue position,
-- but moveQueueForward will NOT start the direct queue
-- controller until approachComplete becomes true.
moveQueueForward(
	stand,
	state
)


task.spawn(
	approachStandBeforeQueue,
	plot,
	stand,
	state,
	entry
)


task.spawn(
	processQueue,
	plot,
	stand
)

	return true
end

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
		standStates[stand]

	if not state then
		return
	end

	for _, entry in state.queue do
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

	standStates[stand] = nil
end

local function cleanPlotCustomers(
	plot: Model
)
	for stand in standStates do
		if getPlotFromStand(stand)
			== plot then

			cleanStandState(stand)
		end
	end
end

Players.PlayerRemoving:Connect(
	function(player)
		for _, plot in
			plotsFolder:GetChildren() do

			if not plot:IsA("Model") then
				continue
			end

			if plot:GetAttribute(
				"OwnerUserId"
			) == player.UserId then

				cleanPlotCustomers(plot)
			end
		end
	end
)

while true do
	local currentTime = time()

	for stand in standStates do
		if not stand.Parent then
			cleanStandState(stand)
		end
	end

	for plot in plotNextSpawnTimes do
		if not plot.Parent
			or not plot:IsDescendantOf(
				plotsFolder
			) then

			plotNextSpawnTimes[plot] =
				nil
		end
	end

	for _, plot in
		plotsFolder:GetChildren() do

		if not plot:IsA("Model")
			or not plotHasOwner(plot) then

			plotNextSpawnTimes[plot] =
				nil

			continue
		end

		local nextSpawnTime =
			plotNextSpawnTimes[plot]

		if typeof(nextSpawnTime)
			~= "number" then

			plotNextSpawnTimes[plot] =
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

		if getPlotCustomerCount(plot)
			>= getPlotCustomerLimit(plot) then

			plotNextSpawnTimes[plot] =
				currentTime + 0.5

			continue
		end

		local selectedStand =
			chooseStandForCustomer(
				plot
			)

		if selectedStand then
			spawnCustomerForStand(
				plot,
				selectedStand
			)
		end

		plotNextSpawnTimes[plot] =
			currentTime
				+ getPlotSpawnInterval(
					plot
				)
	end

	task.wait(0.2)
end