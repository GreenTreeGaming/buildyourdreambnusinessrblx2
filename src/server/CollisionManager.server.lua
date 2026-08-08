local PhysicsService =
	game:GetService("PhysicsService")

local Players =
	game:GetService("Players")

local Workspace =
	game:GetService("Workspace")

local CUSTOMER_GROUP = "Customers"
local PLAYER_GROUP = "Players"
local BUSINESS_GROUP = "Businesses"

local plotsFolder =
	Workspace:WaitForChild("Plots")

local watchedCharacters: {
	[Model]: boolean
} = {}

local watchedBusinesses: {
	[Model]: boolean
} = {}

local watchedBusinessFolders: {
	[Instance]: boolean
} = {}

local watchedCustomers: {
	[Model]: boolean
} = {}

local watchedCustomerFolders: {
	[Instance]: boolean
} = {}

local function registerCollisionGroup(
	groupName: string
)
	local success, errorMessage =
		pcall(function()
			PhysicsService:RegisterCollisionGroup(
				groupName
			)
		end)

	if not success
		and not string.find(
			tostring(errorMessage),
			"already exists",
			1,
			true
		) then

		warn(
			`Could not register collision group "{groupName}": {errorMessage}`
		)
	end
end

registerCollisionGroup(
	CUSTOMER_GROUP
)

registerCollisionGroup(
	PLAYER_GROUP
)

registerCollisionGroup(
	BUSINESS_GROUP
)

-- Customers do not collide with players.
PhysicsService:CollisionGroupSetCollidable(
	CUSTOMER_GROUP,
	PLAYER_GROUP,
	false
)

-- Customers do not collide with each other.
PhysicsService:CollisionGroupSetCollidable(
	CUSTOMER_GROUP,
	CUSTOMER_GROUP,
	false
)

-- Customers pass through placed businesses.
PhysicsService:CollisionGroupSetCollidable(
	CUSTOMER_GROUP,
	BUSINESS_GROUP,
	false
)

-- Players physically collide with placed businesses.
PhysicsService:CollisionGroupSetCollidable(
	BUSINESS_GROUP,
	PLAYER_GROUP,
	true
)

-- Customers must still collide with the ground
-- and normal map geometry.
PhysicsService:CollisionGroupSetCollidable(
	CUSTOMER_GROUP,
	"Default",
	true
)

-- Businesses still collide with normal map geometry.
PhysicsService:CollisionGroupSetCollidable(
	BUSINESS_GROUP,
	"Default",
	true
)

-- Players still collide with normal map geometry.
PhysicsService:CollisionGroupSetCollidable(
	PLAYER_GROUP,
	"Default",
	true
)

local function setBasePartCollisionGroup(
	instance: Instance,
	groupName: string
)
	if instance:IsA("BasePart") then
		instance.CollisionGroup =
			groupName
	end
end

local function setCharacterCollisionGroup(
	character: Model
)
	if watchedCharacters[character] then
		return
	end

	watchedCharacters[character] = true

	for _, descendant in
		character:GetDescendants() do

		setBasePartCollisionGroup(
			descendant,
			PLAYER_GROUP
		)
	end

	character.DescendantAdded:Connect(
		function(descendant: Instance)
			setBasePartCollisionGroup(
				descendant,
				PLAYER_GROUP
			)
		end
	)

	character.Destroying:Connect(function()
		watchedCharacters[character] = nil
	end)
end

local function isInsideHumanoidModel(
	part: BasePart,
	business: Model
): boolean
	local ancestor =
		part.Parent

	while ancestor
		and ancestor ~= business do

		if ancestor:IsA("Model")
			and ancestor:FindFirstChildOfClass(
				"Humanoid"
			) then

			return true
		end

		ancestor = ancestor.Parent
	end

	return false
end

local function setBusinessPartState(
	business: Model,
	instance: Instance
)
	if not instance:IsA("BasePart") then
		return
	end

	instance.CollisionGroup =
		BUSINESS_GROUP

	-- Characters built into the stand, such as
	-- cashiers, should never block movement.
	if isInsideHumanoidModel(
		instance,
		business
	) then

		instance.CanCollide = false
	end
end

local function setBusinessCollisionGroup(
	business: Model
)
	if watchedBusinesses[business] then
		return
	end

	watchedBusinesses[business] = true

	for _, descendant in
		business:GetDescendants() do

		setBusinessPartState(
			business,
			descendant
		)
	end

	business.DescendantAdded:Connect(
		function(descendant: Instance)
			setBusinessPartState(
				business,
				descendant
			)
		end
	)

	business.Destroying:Connect(function()
		watchedBusinesses[business] = nil
	end)
end

local function setCustomerPartState(
	customer: Model,
	instance: Instance
)
	if not instance:IsA("BasePart") then
		return
	end

	instance.CollisionGroup =
		CUSTOMER_GROUP

	-- Accessory handles should never snag on
	-- stands, players, or other customers.
	if instance.Parent
		and instance.Parent:IsA(
			"Accessory"
		) then

		instance.CanCollide = false
	end

	-- HumanoidRootPart should not physically
	-- collide with scenery.
	if instance.Name == "HumanoidRootPart" then
		instance.CanCollide = false
	end
end

local function setCustomerCollisionGroup(
	customer: Model
)
	if watchedCustomers[customer] then
		return
	end

	local humanoid =
		customer:FindFirstChildOfClass(
			"Humanoid"
		)

	if not humanoid then
		return
	end

	watchedCustomers[customer] = true

	for _, descendant in
		customer:GetDescendants() do

		setCustomerPartState(
			customer,
			descendant
		)
	end

	customer.DescendantAdded:Connect(
		function(descendant: Instance)
			setCustomerPartState(
				customer,
				descendant
			)
		end
	)

	customer.Destroying:Connect(function()
		watchedCustomers[customer] = nil
	end)
end

local function watchPlacedBusinessesFolder(
	placedBusinesses: Instance
)
	if watchedBusinessFolders[
		placedBusinesses
	] then

		return
	end

	watchedBusinessFolders[
		placedBusinesses
	] = true

	for _, child in
		placedBusinesses:GetChildren() do

		if child:IsA("Model") then
			setBusinessCollisionGroup(
				child
			)
		end
	end

	placedBusinesses.ChildAdded:Connect(
		function(child: Instance)
			if child:IsA("Model") then
				task.defer(
					setBusinessCollisionGroup,
					child
				)
			end
		end
	)

	placedBusinesses.Destroying:Connect(function()
		watchedBusinessFolders[
			placedBusinesses
		] = nil
	end)
end

local function watchCustomerFolder(
	customerFolder: Instance
)
	if watchedCustomerFolders[
		customerFolder
	] then

		return
	end

	watchedCustomerFolders[
		customerFolder
	] = true

	for _, child in
		customerFolder:GetChildren() do

		if child:IsA("Model") then
			setCustomerCollisionGroup(
				child
			)
		end
	end

	customerFolder.ChildAdded:Connect(
		function(child: Instance)
			if child:IsA("Model") then
				task.defer(
					setCustomerCollisionGroup,
					child
				)
			end
		end
	)

	customerFolder.Destroying:Connect(function()
		watchedCustomerFolders[
			customerFolder
		] = nil
	end)
end

local function watchPlot(
	plot: Model
)
	local placedBusinesses =
		plot:FindFirstChild(
			"PlacedBusinesses"
		)

	if placedBusinesses then
		watchPlacedBusinessesFolder(
			placedBusinesses
		)
	else
		task.spawn(function()
			local folder =
				plot:WaitForChild(
					"PlacedBusinesses",
					15
				)

			if folder then
				watchPlacedBusinessesFolder(
					folder
				)
			else
				warn(
					`{plot.Name} is missing PlacedBusinesses.`
				)
			end
		end)
	end

	-- Supports either a plot-local Customers folder
	-- or a globally parented customer folder later.
	local customerFolder =
		plot:FindFirstChild(
			"Customers"
		)

	if customerFolder then
		watchCustomerFolder(
			customerFolder
		)
	end

	plot.ChildAdded:Connect(function(
		child: Instance
	)
		if child.Name == "Customers" then
			watchCustomerFolder(child)
		end
	end)
end

local function watchWorkspaceCustomers()
	local customerFolder =
		Workspace:FindFirstChild(
			"Customers"
		)

	if customerFolder then
		watchCustomerFolder(
			customerFolder
		)
	end

	Workspace.ChildAdded:Connect(function(
		child: Instance
	)
		if child.Name == "Customers" then
			watchCustomerFolder(child)
		end
	end)
end

local function connectPlayer(
	player: Player
)
	player.CharacterAdded:Connect(function(
		character: Model
	)
		setCharacterCollisionGroup(
			character
		)
	end)

	if player.Character then
		setCharacterCollisionGroup(
			player.Character
		)
	end
end

Players.PlayerAdded:Connect(
	connectPlayer
)

for _, player in
	Players:GetPlayers() do

	connectPlayer(player)
end

for _, plot in
	plotsFolder:GetChildren() do

	if plot:IsA("Model") then
		watchPlot(plot)
	end
end

plotsFolder.ChildAdded:Connect(function(
	child: Instance
)
	if child:IsA("Model") then
		watchPlot(child)
	end
end)

watchWorkspaceCustomers()

print("CollisionManager started.")