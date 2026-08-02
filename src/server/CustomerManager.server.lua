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

	nextSpawnTime: number,
}

local standStates: {
	[Model]: StandState
} = {}

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

		nextSpawnTime =
			time()
			+ randomGenerator:NextNumber(
				MIN_SPAWN_INTERVAL,
				MAX_SPAWN_INTERVAL
			),
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

		humanoid.AutoRotate = true
		humanoid.WalkSpeed = 11
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
			WaypointSpacing = 6,
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

local function moveCustomerTo(
	customer: Model,
	target: BasePart
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

	local targetPosition =
		target.Position

	local waypoints =
		createPathPoints(
			rootPart.Position,
			targetPosition
		)

	if not waypoints
		or #waypoints == 0 then

		waypoints = {
			{
				Position = targetPosition,
				Action =
					Enum.PathWaypointAction.Walk,
				Label = "",
			},
		}
	end

	local waypointIndex = 1

	if #waypoints >= 2
		and (
			rootPart.Position
				- waypoints[1].Position
		).Magnitude
			<= PATH_WAYPOINT_REACHED_DISTANCE then

		waypointIndex = 2
	end

	local startedAt = time()
	local lastCommandAt = 0
	local lastProgressAt = time()
	local lastDistance = math.huge
	local recalculations = 0

	while customer.Parent
		and humanoid.Health > 0 do

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
			waypoints[waypointIndex]

		if not waypoint then
			waypoint = {
				Position = targetPosition,
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

			waypointIndex += 1
			waypoint =
				waypoints[waypointIndex]

			lastCommandAt = 0
		end

		if waypoint.Action
			== Enum.PathWaypointAction.Jump then

			humanoid.Jump = true
		end

		if time() - lastCommandAt
			>= PATH_REISSUE_INTERVAL then

			humanoid:MoveTo(
				waypoint.Position
			)

			lastCommandAt = time()
		end

		local currentDistance =
			(
				rootPart.Position
					- targetPosition
			).Magnitude

		if currentDistance
			< lastDistance - 0.1 then

			lastDistance =
				currentDistance

			lastProgressAt = time()
		elseif time() - lastProgressAt
				>= PATH_STUCK_TIME
			and recalculations < 2 then

			recalculations += 1
			lastProgressAt = time()

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
					math.min(
						2,
						#waypoints
					)

				lastCommandAt = 0
			else
				humanoid:MoveTo(
					targetPosition
				)
			end
		end

		RunService.Heartbeat:Wait()
	end

	return false
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
		getLemonadeSaleValue(
			stand
		)

	cash.Value += saleValue

	local totalSales =
	stand:GetAttribute(
		"TotalSales"
	)

if typeof(totalSales) ~= "number" then
	totalSales = 0
end

local lifetimeEarnings =
	stand:GetAttribute(
		"LifetimeEarnings"
	)

if typeof(lifetimeEarnings)
	~= "number" then

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

	entry.controllerRunning = true

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
		or not rootPart:IsA("BasePart") then

		entry.controllerRunning = false
		return
	end

	local lastTarget: BasePart? = nil
	local lastCommandAt = 0
	local targetStartedAt = time()

	while customer.Parent
		and not entry.isLeaving do

		local target =
			entry.targetPosition

		if not target
			or not target.Parent then

			entry.reachedPosition = false
			RunService.Heartbeat:Wait()
			continue
		end

		if target ~= lastTarget then
			lastTarget = target
			lastCommandAt = 0
			targetStartedAt = time()
			entry.reachedPosition = false
		end

		local horizontalOffset =
			Vector3.new(
				rootPart.Position.X
					- target.Position.X,
				0,
				rootPart.Position.Z
					- target.Position.Z
			)

		if horizontalOffset.Magnitude
			<= QUEUE_REACHED_DISTANCE then

			if not entry.reachedPosition then
				entry.reachedPosition = true

				humanoid:MoveTo(
					rootPart.Position
				)
			end
		else
			entry.reachedPosition = false

			if time() - lastCommandAt
				>= QUEUE_COMMAND_INTERVAL then

				humanoid:MoveTo(
					target.Position
				)

				lastCommandAt = time()
			end

			if time() - targetStartedAt
				>= QUEUE_MOVE_TIMEOUT then

				entry.isLeaving = true
				break
			end
		end

		RunService.Heartbeat:Wait()
	end

	entry.controllerRunning = false
end

local function moveQueueForward(
	stand: Model,
	state: StandState
)
	local queuePositions =
		getQueuePositions(stand)

	for queueIndex, entry in
		state.queue do

		local targetPosition =
			queuePositions[queueIndex]

		if not targetPosition
			or entry.isLeaving then

			continue
		end

		entry.assignedSlot =
			queueIndex

		entry.targetPosition =
			targetPosition

		entry.reachedPosition = false

		if not entry.controllerRunning then
			task.spawn(
				runQueueMovementController,
				entry
			)
		end
	end
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

			if time() - waitStartedAt
				>= QUEUE_MOVE_TIMEOUT then

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
)
	if not standIsAvailable(stand) then
		return
	end

	local state =
		getStandState(stand)

	local queuePositions =
		getQueuePositions(stand)

	if #queuePositions == 0 then
		return
	end

	if #state.queue
		>= #queuePositions then

		return
	end

	local customerSpawn =
		plot:FindFirstChild(
			"CustomerSpawn"
		)

	if not customerSpawn
		or not customerSpawn:IsA(
			"BasePart"
		) then

		return
	end

	local npcTemplate =
		getNextNpcTemplate(state)

	if not npcTemplate then
		return
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

	moveQueueForward(
		stand,
		state
	)

	task.spawn(
		processQueue,
		plot,
		stand
	)
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

	for _, plot in
		plotsFolder:GetChildren() do

		if not plot:IsA("Model")
			or not plotHasOwner(plot) then

			continue
		end

		local stands =
			getLemonadeStands(plot)

		for _, stand in stands do
			if not standIsAvailable(stand) then
				continue
			end

			local state =
				getStandState(stand)

			if currentTime
				< state.nextSpawnTime then

				continue
			end

			spawnCustomerForStand(
				plot,
				stand
			)

			state.nextSpawnTime =
				currentTime
				+ randomGenerator:NextNumber(
					MIN_SPAWN_INTERVAL,
					MAX_SPAWN_INTERVAL
				)
		end
	end

	task.wait(0.2)
end