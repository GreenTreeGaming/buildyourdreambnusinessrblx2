local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local plotsFolder = Workspace:WaitForChild("Plots")

local assignedPlots: {[Player]: Model} = {}

local function getSortedPlots(): {Model}
	local plots = {}

	for _, instance in plotsFolder:GetChildren() do
		if instance:IsA("Model") then
			table.insert(plots, instance)
		end
	end

	table.sort(plots, function(firstPlot, secondPlot)
		return firstPlot.Name < secondPlot.Name
	end)

	return plots
end

local function getAvailablePlot(): Model?
	for _, plot in getSortedPlots() do
		local ownerUserId = plot:GetAttribute("OwnerUserId")

		if ownerUserId == nil or ownerUserId == 0 then
			return plot
		end
	end

	return nil
end

local function teleportCharacterToPlot(
	character: Model,
	plot: Model
)
	local spawnPart = plot:FindFirstChild("PlayerSpawn")

	if not spawnPart or not spawnPart:IsA("BasePart") then
		warn(
			`Plot "{plot.Name}" does not contain a valid PlayerSpawn part.`
		)

		return
	end

	local humanoidRootPart = character:WaitForChild(
		"HumanoidRootPart",
		10
	)

	if not humanoidRootPart then
		warn("HumanoidRootPart did not load for character.")
		return
	end

	character:PivotTo(
		spawnPart.CFrame * CFrame.new(0, 3, 0)
	)
end

local function getPlacedBusinesses(plot: Model): Folder?
	local placedBusinesses =
		plot:FindFirstChild("PlacedBusinesses")

	if placedBusinesses
		and placedBusinesses:IsA("Folder") then

		return placedBusinesses
	end

	warn(
		`Plot "{plot.Name}" does not contain a valid PlacedBusinesses folder.`
	)

	return nil
end

local function clearPlot(plot: Model)
	local placedBusinesses = getPlacedBusinesses(plot)

	if placedBusinesses then
		for _, business in placedBusinesses:GetChildren() do
			business:Destroy()
		end
	end

	plot:SetAttribute("StarterBusinessPlaced", false)
end

local function releasePlot(player: Player)
	local plot = assignedPlots[player]

	if not plot then
		return
	end

	clearPlot(plot)

	plot:SetAttribute("OwnerUserId", 0)
	plot:SetAttribute("OwnerName", "")

	player:SetAttribute("PlotName", nil)

	assignedPlots[player] = nil
end

local function assignPlot(player: Player)
	if assignedPlots[player] then
		return
	end

	local plot = getAvailablePlot()

	if not plot then
		player:Kick(
			"All business plots are currently occupied."
		)

		return
	end

	-- Claim the plot before any yielding occurs.
	plot:SetAttribute("OwnerUserId", player.UserId)
	plot:SetAttribute("OwnerName", player.Name)
	plot:SetAttribute("StarterBusinessPlaced", false)

	assignedPlots[player] = plot

	player:SetAttribute("PlotName", plot.Name)

	-- Ensure the plot starts empty.
	clearPlot(plot)

	player.CharacterAdded:Connect(function(character)
		teleportCharacterToPlot(character, plot)
	end)

	if player.Character then
		teleportCharacterToPlot(
			player.Character,
			plot
		)
	end

	print(
		`Assigned empty {plot.Name} to {player.Name}`
	)
end

Players.PlayerAdded:Connect(assignPlot)
Players.PlayerRemoving:Connect(releasePlot)

-- Handles players who joined before this script loaded.
for _, player in Players:GetPlayers() do
	task.spawn(assignPlot, player)
end