local PhysicsService = game:GetService("PhysicsService")
local Players = game:GetService("Players")

local CUSTOMER_GROUP = "Customers"
local PLAYER_GROUP = "Players"

local function registerCollisionGroup(groupName: string)
	pcall(function()
		PhysicsService:RegisterCollisionGroup(groupName)
	end)
end

registerCollisionGroup(CUSTOMER_GROUP)
registerCollisionGroup(PLAYER_GROUP)

PhysicsService:CollisionGroupSetCollidable(
	CUSTOMER_GROUP,
	PLAYER_GROUP,
	false
)

PhysicsService:CollisionGroupSetCollidable(
	CUSTOMER_GROUP,
	CUSTOMER_GROUP,
	false
)

local function setCharacterCollisionGroup(
	character: Model,
	groupName: string
)
	for _, descendant in character:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.CollisionGroup = groupName
		end
	end

	character.DescendantAdded:Connect(function(descendant)
		if descendant:IsA("BasePart") then
			descendant.CollisionGroup = groupName
		end
	end)
end

Players.PlayerAdded:Connect(function(player)
	player.CharacterAdded:Connect(function(character)
		setCharacterCollisionGroup(character, PLAYER_GROUP)
	end)
end)

for _, player in Players:GetPlayers() do
	if player.Character then
		setCharacterCollisionGroup(player.Character, PLAYER_GROUP)
	end

	player.CharacterAdded:Connect(function(character)
		setCharacterCollisionGroup(character, PLAYER_GROUP)
	end)
end