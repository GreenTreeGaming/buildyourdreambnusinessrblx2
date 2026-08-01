local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")
local PathfindingService = game:GetService("PathfindingService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local PhysicsService = game:GetService("PhysicsService")
local RunService = game:GetService("RunService")

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

local lemonadeStandConfig =
	BusinessConfig.LemonadeStand

local DEFAULT_LEMONADE_COOLDOWN =
	lemonadeStandConfig.BaseServingCooldown

local DEFAULT_LEMONADE_SALE_VALUE =
	lemonadeStandConfig.BaseSaleValue

local CUSTOMER_COLLISION_GROUP = "Customers"

local plotsFolder = Workspace:WaitForChild("Plots")
local npcFolder = ServerStorage:WaitForChild("NPCs")

local customersFolder = Workspace:FindFirstChild("Customers")

if not customersFolder then
	customersFolder = Instance.new("Folder")
	customersFolder.Name = "Customers"
	customersFolder.Parent = Workspace
end

local businessAvailabilityEvent =
	ServerStorage:FindFirstChild("BusinessAvailabilityChanged")

-- Arrival timing. Customers arrive faster than some transactions complete,
-- allowing a visible queue to form naturally.
local MIN_SPAWN_INTERVAL = 1.8
local MAX_SPAWN_INTERVAL = 3.4

local MIN_TRANSACTION_TIME = 1.25
local MAX_TRANSACTION_TIME = 3.25

local MIN_COUNTER_RESET_TIME = 0.1
local MAX_COUNTER_RESET_TIME = 0.25

local QUEUE_REACHED_DISTANCE = 1.5
local QUEUE_COMMAND_INTERVAL = 0.4

local randomGenerator = Random.new()

local WALK_TIMEOUT = 20
local WAYPOINT_SPACING = 7
local TARGET_REACHED_DISTANCE = 2.5

local PATH_TIMEOUT = 20
local PATH_WAYPOINT_REACHED_DISTANCE = 3
local PATH_FINAL_REACHED_DISTANCE = 2
local PATH_REISSUE_INTERVAL = 0.75
local PATH_STUCK_TIME = 2

type QueueEntry = {
	customer: Model,

	reachedPosition: boolean,
	isLeaving: boolean,

	assignedSlot: number,
	targetPosition: BasePart?,

	controllerRunning: boolean,
	movementVersion: number,
}

type PlotState = {
	queue: {QueueEntry},
	isServing: boolean,

	templateBag: {Model},
	lastTemplate: Model?,

	nextSpawnTime: number,
}

local plotStates: {[Model]: PlotState} = {}

local function getPlotState(plot: Model): PlotState
	local existingState = plotStates[plot]

	if existingState then
		return existingState
	end

	local newState: PlotState = {
		queue = {},
		isServing = false,

		templateBag = {},
		lastTemplate = nil,

		nextSpawnTime = time()
			+ randomGenerator:NextNumber(
				MIN_SPAWN_INTERVAL,
				MAX_SPAWN_INTERVAL
			),
	}

	plotStates[plot] = newState

	return newState
end

local function getPlayerFromPlot(plot: Model): Player?
	local ownerUserId = plot:GetAttribute("OwnerUserId")

	if typeof(ownerUserId) ~= "number" or ownerUserId == 0 then
		return nil
	end

	return Players:GetPlayerByUserId(ownerUserId)
end

local function getCashValue(player: Player): IntValue?
	local leaderstats = player:FindFirstChild("leaderstats")

	if not leaderstats then
		return nil
	end

	local cash = leaderstats:FindFirstChild("Cash")

	if cash and cash:IsA("IntValue") then
		return cash
	end

	return nil
end

local function getLemonadeStand(plot: Model): Model?
	local placedBusinesses = plot:FindFirstChild("PlacedBusinesses")

	if not placedBusinesses then
		return nil
	end

	local stand = placedBusinesses:FindFirstChild("LemonadeStand")

	if stand and stand:IsA("Model") then
		return stand
	end

	return nil
end

local function standIsAvailable(plot: Model): boolean
	local stand = getLemonadeStand(plot)

	if not stand then
		return false
	end

	if stand:GetAttribute("StandUnavailable") == true then
		return false
	end

	if stand:GetAttribute("IsBeingEdited") == true then
		return false
	end

	return true
end

local function getLemonadeCooldown(stand: Model): number
	local standCooldown = stand:GetAttribute("PurchaseCooldown")

	if typeof(standCooldown) == "number" and standCooldown >= 0 then
		return standCooldown
	end

	return DEFAULT_LEMONADE_COOLDOWN
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

	if active and duration then
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

local function getLemonadeSaleValue(
	stand: Model
): number
	local standSaleValue =
		stand:GetAttribute("SaleValue")

	if typeof(standSaleValue) == "number"
		and standSaleValue >= 0 then

		return math.floor(standSaleValue)
	end

	return DEFAULT_LEMONADE_SALE_VALUE
end

local function getQueuePositions(plot: Model): {BasePart}
	local stand = getLemonadeStand(plot)

	if not stand then
		return {}
	end

	local queueFolder =
		stand:FindFirstChild("QueuePositions")

	if not queueFolder then
		warn(`{stand.Name} is missing QueuePositions.`)
		return {}
	end

	local queuePositions = {}

	for _, instance in queueFolder:GetChildren() do
		if not instance:IsA("BasePart") then
			continue
		end

		local queueNumber = tonumber(
			string.match(
				instance.Name,
				"^Queue(%d+)$"
			)
		)

		if queueNumber then
			table.insert(queuePositions, instance)
		end
	end

	table.sort(queuePositions, function(first, second)
		local firstNumber =
			tonumber(string.match(first.Name, "%d+"))
			or math.huge

		local secondNumber =
			tonumber(string.match(second.Name, "%d+"))
			or math.huge

		return firstNumber < secondNumber
	end)

	return queuePositions
end

local function getValidNpcTemplates(): {Model}
	local templates = {}

	for _, instance in npcFolder:GetChildren() do
		if not instance:IsA("Model") then
			continue
		end

		local humanoid = instance:FindFirstChildOfClass("Humanoid")
		local rootPart = instance:FindFirstChild("HumanoidRootPart")
		local torso = instance:FindFirstChild("Torso")

		if not humanoid
			or humanoid.RigType ~= Enum.HumanoidRigType.R6
			or not rootPart
			or not rootPart:IsA("BasePart")
			or not torso
			or not torso:IsA("BasePart") then

			continue
		end

		table.insert(templates, instance)
	end

	return templates
end

local function shuffleTemplates(templates: {Model})
	for index = #templates, 2, -1 do
		local swapIndex = randomGenerator:NextInteger(1, index)

		templates[index], templates[swapIndex] =
			templates[swapIndex], templates[index]
	end
end

local function refillTemplateBag(state: PlotState): boolean
	local templates = getValidNpcTemplates()

	if #templates == 0 then
		warn("No valid R6 NPC templates were found in ServerStorage.NPCs.")
		return false
	end

	shuffleTemplates(templates)

	-- Templates are removed from the end of the bag. Prevent the next
	-- selection from matching the final selection of the previous bag.
	if #templates > 1
		and state.lastTemplate
		and templates[#templates] == state.lastTemplate then

		templates[#templates], templates[1] =
			templates[1], templates[#templates]
	end

	state.templateBag = templates

	return true
end

local function getNextNpcTemplate(state: PlotState): Model?
	while true do
		if #state.templateBag == 0 then
			if not refillTemplateBag(state) then
				return nil
			end
		end

		local template = table.remove(state.templateBag)

		-- Protect against templates being removed from ServerStorage after
		-- the current bag was created.
		if template and template.Parent == npcFolder then
			state.lastTemplate = template
			return template
		end
	end
end

local function prepareCustomer(customer: Model)
	local humanoid = customer:FindFirstChildOfClass("Humanoid")
	local rootPart = customer:FindFirstChild("HumanoidRootPart")

	if humanoid then
		humanoid.DisplayName = "Customer"
		humanoid.AutoRotate = true
		humanoid.WalkSpeed = 11
	end

	for _, descendant in customer:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.Anchored = false
			descendant.CollisionGroup = CUSTOMER_COLLISION_GROUP
		end
	end

	-- Handles parts added after the NPC is cloned, such as accessories.
	customer.DescendantAdded:Connect(function(descendant)
		if descendant:IsA("BasePart") then
			descendant.CollisionGroup = CUSTOMER_COLLISION_GROUP
		end
	end)

	if rootPart and rootPart:IsA("BasePart") then
		local canSetOwnership = rootPart:CanSetNetworkOwnership()

		if canSetOwnership then
			rootPart:SetNetworkOwner(nil)
		end
	end
end

local function createPathPoints(
	startPosition: Vector3,
	targetPosition: Vector3
): {PathWaypoint}?
	local path = PathfindingService:CreatePath({
		AgentRadius = 2,
		AgentHeight = 5,
		AgentCanJump = true,
		AgentCanClimb = false,
		WaypointSpacing = 6,
	})

	local success, calculationError = pcall(function()
		path:ComputeAsync(startPosition, targetPosition)
	end)

	if not success then
		warn(`Path calculation failed: {calculationError}`)
		return nil
	end

	if path.Status ~= Enum.PathStatus.Success then
		return nil
	end

	return path:GetWaypoints()
end

local function moveCustomerTo(
	customer: Model,
	target: BasePart
): boolean
	local humanoid = customer:FindFirstChildOfClass("Humanoid")
	local rootPart = customer:FindFirstChild("HumanoidRootPart")

	if not humanoid
		or not rootPart
		or not rootPart:IsA("BasePart") then

		warn(`{customer.Name} is missing its Humanoid or HumanoidRootPart.`)
		return false
	end

	local targetPosition = target.Position
	local waypoints = createPathPoints(
		rootPart.Position,
		targetPosition
	)

	-- Direct movement fallback.
	if not waypoints or #waypoints == 0 then
		waypoints = {
			{
				Position = targetPosition,
				Action = Enum.PathWaypointAction.Walk,
				Label = "",
			},
		}
	end

	local waypointIndex = 1

	-- Skip the waypoint located at the NPC's current position.
	if #waypoints >= 2
		and (rootPart.Position - waypoints[1].Position).Magnitude
		<= PATH_WAYPOINT_REACHED_DISTANCE then

		waypointIndex = 2
	end

	local startedAt = time()
	local lastCommandAt = 0
	local lastProgressAt = time()
	local lastDistance = math.huge
	local recalculations = 0

	while customer.Parent and humanoid.Health > 0 do
		if time() - startedAt >= PATH_TIMEOUT then
			warn(`{customer.Name} timed out while walking.`)
			return false
		end

		local finalOffset = Vector3.new(
			rootPart.Position.X - targetPosition.X,
			0,
			rootPart.Position.Z - targetPosition.Z
		)

		if finalOffset.Magnitude <= PATH_FINAL_REACHED_DISTANCE then
			humanoid:MoveTo(rootPart.Position)
			return true
		end

		local waypoint = waypoints[waypointIndex]

		if not waypoint then
			waypoint = {
				Position = targetPosition,
				Action = Enum.PathWaypointAction.Walk,
				Label = "",
			}
		end

		local waypointOffset = Vector3.new(
			rootPart.Position.X - waypoint.Position.X,
			0,
			rootPart.Position.Z - waypoint.Position.Z
		)

		-- Advance slightly before reaching the waypoint so the NPC does not
		-- stop between path segments.
		if waypointOffset.Magnitude
			<= PATH_WAYPOINT_REACHED_DISTANCE
			and waypointIndex < #waypoints then

			waypointIndex += 1
			waypoint = waypoints[waypointIndex]
			lastCommandAt = 0
		end

		if waypoint.Action == Enum.PathWaypointAction.Jump then
			humanoid.Jump = true
		end

		if time() - lastCommandAt >= PATH_REISSUE_INTERVAL then
			humanoid:MoveTo(waypoint.Position)
			lastCommandAt = time()
		end

		local currentDistance =
			(rootPart.Position - targetPosition).Magnitude

		if currentDistance < lastDistance - 0.1 then
			lastDistance = currentDistance
			lastProgressAt = time()
		elseif time() - lastProgressAt >= PATH_STUCK_TIME
			and recalculations < 2 then

			recalculations += 1
			lastProgressAt = time()

			local newWaypoints = createPathPoints(
				rootPart.Position,
				targetPosition
			)

			if newWaypoints and #newWaypoints > 0 then
				waypoints = newWaypoints
				waypointIndex = math.min(2, #waypoints)
				lastCommandAt = 0
			else
				humanoid:MoveTo(targetPosition)
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
		customer:FindFirstChildOfClass("Humanoid")

	local rootPart =
		customer:FindFirstChild("HumanoidRootPart")

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

		targetPosition = facingPosition.Position
	else
		targetPosition = stand:GetPivot().Position
	end

	local horizontalTarget = Vector3.new(
		targetPosition.X,
		rootPart.Position.Y,
		targetPosition.Z
	)

	if (horizontalTarget - rootPart.Position).Magnitude < 0.05 then
		return
	end

	-- Prevent the Humanoid from overriding the serving rotation.
	humanoid.AutoRotate = false

	rootPart.CFrame = CFrame.lookAt(
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
		or not effectPosition:IsA("BasePart") then

		warn(
			`Could not find a sale effect position in {stand.Name}.`
		)

		return
	end

	local billboard =
		Instance.new("BillboardGui")

	billboard.Name = "CashPopup"
	billboard.Adornee = effectPosition

	-- World-space scaling instead of pixel offsets.
	billboard.Size =
		UDim2.fromScale(4.2, 1.2)

	billboard.StudsOffsetWorldSpace =
		Vector3.new(0, 1.8, 0)

	billboard.AlwaysOnTop = true
	billboard.LightInfluence = 0
	billboard.MaxDistance = 80
	billboard.Parent = effectPosition

	local container = Instance.new("Frame")
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

	UITheme.AddCorner(container, 0.25)

	local stroke = UITheme.AddStroke(
		container,
		Colors.Success,
		2,
		0.12
	)

	UITheme.AddGradient(
		container,
		Colors.Success,
		Colors.SuccessDark
	)

	local amountLabel =
		Instance.new("TextLabel")

	amountLabel.Name = "Amount"
	amountLabel.Position =
		UDim2.fromScale(0.08, 0.08)

	amountLabel.Size =
		UDim2.fromScale(0.84, 0.55)

	amountLabel.BackgroundTransparency = 1
	amountLabel.Text =
		string.format("+$%d", amount)

	amountLabel.TextXAlignment =
		Enum.TextXAlignment.Center

	amountLabel.Parent = container

	UITheme.StyleText(
		amountLabel,
		15,
		27,
		Colors.Text,
		Fonts.Black
	)

	local saleLabel =
		Instance.new("TextLabel")

	saleLabel.Name = "SaleLabel"
	saleLabel.Position =
		UDim2.fromScale(0.08, 0.61)

	saleLabel.Size =
		UDim2.fromScale(0.84, 0.24)

	saleLabel.BackgroundTransparency = 1
	saleLabel.Text = "SALE COMPLETE"
	saleLabel.TextXAlignment =
		Enum.TextXAlignment.Center

	saleLabel.Parent = container

	UITheme.StyleText(
		saleLabel,
		8,
		13,
		Colors.Text,
		Fonts.Bold
	)

	local moveTween = TweenService:Create(
		billboard,
		TweenInfo.new(
			1,
			Enum.EasingStyle.Back,
			Enum.EasingDirection.Out
		),
		{
			StudsOffsetWorldSpace =
				Vector3.new(0, 4.3, 0),
		}
	)

	local amountFadeTween =
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

	local saleFadeTween =
		TweenService:Create(
			saleLabel,
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

	local containerFadeTween =
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

	local strokeFadeTween =
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
	amountFadeTween:Play()
	saleFadeTween:Play()
	containerFadeTween:Play()
	strokeFadeTween:Play()

	Debris:AddItem(billboard, 1.15)
end

local function playSaleSound(stand: Model)
	local saleSound = stand:FindFirstChild("SaleSound", true)

	if not saleSound or not saleSound:IsA("Sound") then
		warn(`{stand.Name} is missing SaleSound.`)
		return
	end

	saleSound:Play()
end

local function rewardPlotOwner(
	plot: Model,
	stand: Model
): boolean
	local player = getPlayerFromPlot(plot)

	if not player then
		return false
	end

	local cash = getCashValue(player)

	if not cash then
		warn(
			`Cash value was not found for {player.Name}.`
		)

		return false
	end

	local saleValue =
		getLemonadeSaleValue(stand)

	cash.Value += saleValue

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
	local customerExit = plot:FindFirstChild("CustomerExit")

	if not customerExit or not customerExit:IsA("BasePart") then
		warn(`{plot.Name} is missing CustomerExit.`)
		customer:Destroy()
		return
	end

	task.spawn(function()
		moveCustomerTo(customer, customerExit)

		if customer.Parent then
			customer:Destroy()
		end
	end)
end

local function evacuatePlotCustomers(plot: Model)
	local state = plotStates[plot]

	if not state or #state.queue == 0 then
		return
	end

	-- Remove the entries from the active queue first so processQueue
	-- and the spawning system no longer treat them as customers waiting
	-- for this stand.
	local customersToEvacuate = state.queue
	state.queue = {}

	for _, entry in customersToEvacuate do
		entry.isLeaving = true
		entry.reachedPosition = false
		entry.targetPosition = nil

		-- Cancels movement functions that use movementVersion.
		entry.movementVersion += 1

		local customer = entry.customer

		if not customer.Parent then
			continue
		end

		local humanoid =
			customer:FindFirstChildOfClass("Humanoid")

		local rootPart =
			customer:FindFirstChild("HumanoidRootPart")

		if humanoid then
			humanoid.AutoRotate = true

			if rootPart and rootPart:IsA("BasePart") then
				-- Cancels the command that was taking the customer
				-- toward a queue position.
				humanoid:MoveTo(rootPart.Position)
			end
		end

		sendCustomerToExit(plot, customer)
	end
end

businessAvailabilityEvent.Event:Connect(function(plot: Model)
	if not plot or not plot:IsA("Model") then
		return
	end

	evacuatePlotCustomers(plot)
end)

local QUEUE_MOVE_TIMEOUT = 8
local QUEUE_REACHED_DISTANCE = 1.75

local function moveQueueEntryTo(
	entry: QueueEntry,
	target: BasePart
): boolean
	local customer = entry.customer
	local humanoid = customer:FindFirstChildOfClass("Humanoid")
	local rootPart = customer:FindFirstChild("HumanoidRootPart")

	if not humanoid or not rootPart or not rootPart:IsA("BasePart") then
		return false
	end

	-- Invalidates any previous queue movement for this customer.
	entry.movementVersion += 1
	local currentVersion = entry.movementVersion

	entry.reachedPosition = false
	humanoid:MoveTo(target.Position)

	local startedAt = time()

	while customer.Parent and humanoid.Health > 0 do
		if entry.movementVersion ~= currentVersion then
			return false
		end

		local horizontalOffset = Vector3.new(
			rootPart.Position.X - target.Position.X,
			0,
			rootPart.Position.Z - target.Position.Z
		)

		if horizontalOffset.Magnitude <= QUEUE_REACHED_DISTANCE then
			-- Stop the Humanoid cleanly at its current location.
			humanoid:MoveTo(rootPart.Position)
			entry.reachedPosition = true
			return true
		end

		if time() - startedAt >= QUEUE_MOVE_TIMEOUT then
			return false
		end

		task.wait(0.05)
	end

	return false
end

local function runQueueMovementController(entry: QueueEntry)
	if entry.controllerRunning then
		return
	end

	entry.controllerRunning = true

	local customer = entry.customer
	local humanoid = customer:FindFirstChildOfClass("Humanoid")
	local rootPart = customer:FindFirstChild("HumanoidRootPart")

	if not humanoid
		or not rootPart
		or not rootPart:IsA("BasePart") then

		entry.controllerRunning = false
		return
	end

	local lastTarget: BasePart? = nil
	local lastCommandAt = 0

	while customer.Parent and not entry.isLeaving do
		local target = entry.targetPosition

		if not target or not target.Parent then
			entry.reachedPosition = false
			RunService.Heartbeat:Wait()
			continue
		end

		local targetChanged = target ~= lastTarget

		if targetChanged then
			lastTarget = target
			lastCommandAt = 0
			entry.reachedPosition = false
		end

		local horizontalOffset = Vector3.new(
			rootPart.Position.X - target.Position.X,
			0,
			rootPart.Position.Z - target.Position.Z
		)

		if horizontalOffset.Magnitude <= QUEUE_REACHED_DISTANCE then
			if not entry.reachedPosition then
				entry.reachedPosition = true
				humanoid:MoveTo(rootPart.Position)
			end
		else
			entry.reachedPosition = false

			if time() - lastCommandAt >= QUEUE_COMMAND_INTERVAL then
				humanoid:MoveTo(target.Position)
				lastCommandAt = time()
			end
		end

		RunService.Heartbeat:Wait()
	end

	entry.controllerRunning = false
end

local function moveQueueForward(
	plot: Model,
	state: PlotState
)
	local queuePositions = getQueuePositions(plot)

	for queueIndex, entry in state.queue do
		local targetPosition = queuePositions[queueIndex]

		if not targetPosition or entry.isLeaving then
			continue
		end

		entry.assignedSlot = queueIndex
		entry.targetPosition = targetPosition
		entry.reachedPosition = false

		if not entry.controllerRunning then
			task.spawn(runQueueMovementController, entry)
		end
	end
end

local function processQueue(plot: Model)
	local state = getPlotState(plot)

	if state.isServing then
		return
	end

	state.isServing = true

	while #state.queue > 0 and standIsAvailable(plot) do
		local firstEntry = state.queue[1]

		if not firstEntry or not firstEntry.customer.Parent then
			table.remove(state.queue, 1)
			moveQueueForward(plot, state)
			continue
		end

		local waitStartedAt = time()

		while firstEntry.customer.Parent
			and not firstEntry.isLeaving
			and standIsAvailable(plot) do
			local readyForService =
				firstEntry.assignedSlot == 1
				and firstEntry.targetPosition ~= nil
				and firstEntry.reachedPosition

			if readyForService then
				break
			end

			if time() - waitStartedAt >= WALK_TIMEOUT then
				break
			end

			task.wait(0.05)
		end
		
		if firstEntry.isLeaving or not standIsAvailable(plot) then
			break
		end

		if not firstEntry.customer.Parent then
			table.remove(state.queue, 1)
			moveQueueForward(plot, state)
			continue
		end

		if firstEntry.assignedSlot ~= 1
			or not firstEntry.reachedPosition then

			firstEntry.isLeaving = true
			firstEntry.targetPosition = nil
			firstEntry.reachedPosition = false

			firstEntry.customer:Destroy()

			table.remove(state.queue, 1)
			moveQueueForward(plot, state)
			continue
		end

		local stand = getLemonadeStand(plot)

		if not stand then
			firstEntry.isLeaving = true
			firstEntry.targetPosition = nil
			firstEntry.reachedPosition = false

			firstEntry.customer:Destroy()

			table.remove(state.queue, 1)
			moveQueueForward(plot, state)
			continue
		end

		faceCustomerTowardStand(
			firstEntry.customer,
			stand
		)

		local transactionTime =
	getLemonadeCooldown(stand)

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

		while time() < transactionEndsAt do
			local transactionCompleted =
	not firstEntry.isLeaving
	and firstEntry.customer.Parent ~= nil
	and standIsAvailable(plot)

setStandServingState(
	stand,
	false
)

if not transactionCompleted then
	break
end

			task.wait(0.05)
		end

		if firstEntry.isLeaving
			or not firstEntry.customer.Parent
			or not standIsAvailable(plot) then

			break
		end

		if not firstEntry.customer.Parent then
			table.remove(state.queue, 1)
			moveQueueForward(plot, state)
			continue
		end

		rewardPlotOwner(plot, stand)

		-- Stop the queue controller before exit movement takes control.
		firstEntry.isLeaving = true
		firstEntry.targetPosition = nil
		firstEntry.reachedPosition = false

		local humanoid =
			firstEntry.customer:FindFirstChildOfClass("Humanoid")

		local rootPart =
			firstEntry.customer:FindFirstChild("HumanoidRootPart")

		if humanoid
			and rootPart
			and rootPart:IsA("BasePart") then

			humanoid:MoveTo(rootPart.Position)
		end

		table.remove(state.queue, 1)
		
		local humanoid =
			firstEntry.customer:FindFirstChildOfClass("Humanoid")

		if humanoid then
			humanoid.AutoRotate = true
		end

		-- Exit movement now has sole control of this customer.
		sendCustomerToExit(
			plot,
			firstEntry.customer
		)

		-- Reassign everyone still waiting to Queue1, Queue2, Queue3, etc.
		moveQueueForward(plot, state)

		local counterResetTime = randomGenerator:NextNumber(
			MIN_COUNTER_RESET_TIME,
			MAX_COUNTER_RESET_TIME
		)

		task.wait(counterResetTime)
	end

	state.isServing = false
end

local function spawnCustomerForPlot(plot: Model)
	local state = getPlotState(plot)
	local queuePositions = getQueuePositions(plot)

	if #queuePositions == 0 then
		return
	end

	-- Do not spawn customers when all queue spaces are occupied.
	if #state.queue >= #queuePositions then
		return
	end

	local customerSpawn = plot:FindFirstChild("CustomerSpawn")

	if not customerSpawn or not customerSpawn:IsA("BasePart") then
		warn(`{plot.Name} is missing CustomerSpawn.`)
		return
	end

	local npcTemplate = getNextNpcTemplate(state)

	if not npcTemplate then
		return
	end

	local customer = npcTemplate:Clone()
	customer.Name = "Customer"

	customer:SetAttribute("CharacterTemplate", npcTemplate.Name)
	customer:SetAttribute("PlotName", plot.Name)

	prepareCustomer(customer)

	customer.Parent = customersFolder
	customer:PivotTo(
		customerSpawn.CFrame * CFrame.new(0, 3, 0)
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

	table.insert(state.queue, entry)

	-- Assigns every customer to exactly one deterministic queue slot.
	moveQueueForward(plot, state)

	task.spawn(processQueue, plot)
end

local function plotCanReceiveCustomers(plot: Model): boolean
	local ownerUserId = plot:GetAttribute("OwnerUserId")

	if typeof(ownerUserId) ~= "number" or ownerUserId == 0 then
		return false
	end

	return standIsAvailable(plot)
end

local function cleanPlotCustomers(plot: Model)
	local state = plotStates[plot]

	if not state then
		return
	end

	for _, entry in state.queue do
		if entry.customer.Parent then
			entry.customer:Destroy()
		end
	end

	state.queue = {}
	state.isServing = false
end

Players.PlayerRemoving:Connect(function(player)
	for _, plot in plotsFolder:GetChildren() do
		if not plot:IsA("Model") then
			continue
		end

		local ownerUserId = plot:GetAttribute("OwnerUserId")

		if ownerUserId == player.UserId then
			cleanPlotCustomers(plot)
		end
	end
end)

while true do
	local currentTime = time()

	for _, plot in plotsFolder:GetChildren() do
		if not plot:IsA("Model") then
			continue
		end

		if not plotCanReceiveCustomers(plot) then
			continue
		end

		local state = getPlotState(plot)

		if currentTime < state.nextSpawnTime then
			continue
		end

		spawnCustomerForPlot(plot)

		state.nextSpawnTime = currentTime
			+ randomGenerator:NextNumber(
				MIN_SPAWN_INTERVAL,
				MAX_SPAWN_INTERVAL
			)
	end

	-- Lightweight scheduler so each plot has independent customer timing.
	task.wait(0.2)
end