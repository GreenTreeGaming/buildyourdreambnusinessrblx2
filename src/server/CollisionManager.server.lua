local PhysicsService = game:GetService("PhysicsService")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local CUSTOMER_GROUP = "Customers"
local PLAYER_GROUP = "Players"
local BUSINESS_GROUP = "Businesses"

local plotsFolder =
	Workspace:WaitForChild("Plots")

local watchedCharacters: {[Model]: boolean} = {}
local watchedBusinesses: {[Model]: boolean} = {}
local watchedBusinessFolders: {[Instance]: boolean} = {}

local function registerCollisionGroup(
	groupName: string
)
	local success, errorMessage = pcall(function()
		PhysicsService:RegisterCollisionGroup(
			groupName
		)
	end)

	if not success
		and not string.find(
			tostring(errorMessage),
			"already exists"
		) then

		warn(
			`Could not register collision group "{groupName}": {errorMessage}`
		)
	end
end

registerCollisionGroup(CUSTOMER_GROUP)
registerCollisionGroup(PLAYER_GROUP)
registerCollisionGroup(BUSINESS_GROUP)

-- Customers do not push players.
PhysicsService:CollisionGroupSetCollidable(
	CUSTOMER_GROUP,
	PLAYER_GROUP,
	false
)

-- Customers do not push each other.
PhysicsService:CollisionGroupSetCollidable(
	CUSTOMER_GROUP,
	CUSTOMER_GROUP,
	false
)

-- Players can walk through placed businesses.
PhysicsService:CollisionGroupSetCollidable(
	BUSINESS_GROUP,
	PLAYER_GROUP,
	false
)

local function setBasePartCollisionGroup(
	instance: Instance,
	groupName: string
)
	if instance:IsA("BasePart") then
		instance.CollisionGroup = groupName
	end
end

local function setCharacterCollisionGroup(
	character: Model
)
	if watchedCharacters[character] then
		return
	end

	watchedCharacters[character] = true

	for _, descendant in character:GetDescendants() do
		setBasePartCollisionGroup(
			descendant,
			PLAYER_GROUP
		)
	end

	character.DescendantAdded:Connect(
		function(descendant)
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
	local ancestor = part.Parent

	while ancestor and ancestor ~= business do
		if ancestor:IsA("Model")
			and ancestor:FindFirstChildOfClass("Humanoid") then

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

	instance.CollisionGroup = BUSINESS_GROUP

	-- Humanoid characters built into a business, such as the cashier,
	-- should never physically block or push players.
	if isInsideHumanoidModel(instance, business) then
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

	for _, descendant in business:GetDescendants() do
		setBusinessPartState(
			business,
			descendant
		)
	end

	business.DescendantAdded:Connect(
		function(descendant)
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

local function watchPlacedBusinessesFolder(
	placedBusinesses: Instance
)
	if watchedBusinessFolders[placedBusinesses] then
		return
	end

	watchedBusinessFolders[placedBusinesses] = true

	for _, child in placedBusinesses:GetChildren() do
		if child:IsA("Model") then
			setBusinessCollisionGroup(child)
		end
	end

	placedBusinesses.ChildAdded:Connect(function(child)
		if child:IsA("Model") then
			setBusinessCollisionGroup(child)
		end
	end)

	placedBusinesses.Destroying:Connect(function()
		watchedBusinessFolders[placedBusinesses] = nil
	end)
end

local function watchPlot(plot: Model)
	local placedBusinesses =
		plot:FindFirstChild("PlacedBusinesses")

	if placedBusinesses then
		watchPlacedBusinessesFolder(
			placedBusinesses
		)

		return
	end

	task.spawn(function()
		local folder =
			plot:WaitForChild(
				"PlacedBusinesses",
				15
			)

		if folder then
			watchPlacedBusinessesFolder(folder)
		else
			warn(
				`{plot.Name} is missing PlacedBusinesses.`
			)
		end
	end)
end

local function connectPlayer(player: Player)
	player.CharacterAdded:Connect(function(character)
		setCharacterCollisionGroup(character)
	end)

	if player.Character then
		setCharacterCollisionGroup(
			player.Character
		)
	end
end

Players.PlayerAdded:Connect(connectPlayer)

for _, player in Players:GetPlayers() do
	connectPlayer(player)
end

for _, plot in plotsFolder:GetChildren() do
	if plot:IsA("Model") then
		watchPlot(plot)
	end
end

plotsFolder.ChildAdded:Connect(function(child)
	if child:IsA("Model") then
		watchPlot(child)
	end
end)

print("CollisionManager started.")