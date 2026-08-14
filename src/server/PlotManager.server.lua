local Players =
	game:GetService("Players")

local Workspace =
	game:GetService("Workspace")


local DataService =
	require(
		script.Parent
			:WaitForChild("Services")
			:WaitForChild("DataService")
	)


local PlotService =
	require(
		script.Parent
			:WaitForChild("Services")
			:WaitForChild("PlotService")
	)


local plotsFolder =
	Workspace:WaitForChild(
		"Plots"
	)


local assignedPlots: {
	[Player]: Model
} = {}


local releasingPlayers: {
	[Player]: boolean
} = {}


local function getSortedPlots(): {
	Model
}
	local plots = {}


	for _, instance in
		plotsFolder:GetChildren() do

		if instance:IsA(
			"Model"
		) then

			table.insert(
				plots,
				instance
			)
		end
	end


	table.sort(
		plots,

		function(
			firstPlot,
			secondPlot
		)

			return firstPlot.Name
				< secondPlot.Name
		end
	)


	return plots
end


local function getAvailablePlot(): Model?

	for _, plot in
		getSortedPlots() do

		local ownerUserId =
			plot:GetAttribute(
				"OwnerUserId"
			)


		if ownerUserId == nil
			or ownerUserId == 0 then

			return plot
		end
	end


	return nil
end


local function teleportCharacterToPlot(
	character: Model,
	plot: Model
)
	local spawnPart =
		plot:FindFirstChild(
			"PlayerSpawn"
		)


	if not spawnPart
		or not spawnPart:IsA(
			"BasePart"
		) then

		warn(
			`Plot "{plot.Name}" does not contain a valid PlayerSpawn part.`
		)


		return
	end


	local humanoidRootPart =
		character:WaitForChild(
			"HumanoidRootPart",
			10
		)


	if not humanoidRootPart then

		warn(
			"HumanoidRootPart did not load for character."
		)


		return
	end


	character:PivotTo(
		spawnPart.CFrame
			* CFrame.new(
				0,
				3,
				0
			)
	)
end


local function getPlacedBusinesses(
	plot: Model
): Folder?

	local placedBusinesses =
		plot:FindFirstChild(
			"PlacedBusinesses"
		)


	if placedBusinesses
		and placedBusinesses:IsA(
			"Folder"
		) then

		return placedBusinesses
	end


	warn(
		`Plot "{plot.Name}" does not contain a valid PlacedBusinesses folder.`
	)


	return nil
end


local function clearPlot(
	plot: Model
)
	local placedBusinesses =
		getPlacedBusinesses(
			plot
		)


	if placedBusinesses then

		for _, business in
			placedBusinesses:GetChildren() do

			business:Destroy()
		end
	end


	PlotService.ResetPlot(
		plot
	)


	plot:SetAttribute(
		"StarterBusinessPlaced",
		false
	)
end


local function releasePlot(
	player: Player
)
	if releasingPlayers[
		player
	] then

		return
	end


	releasingPlayers[
		player
	] = true


	local plot =
		assignedPlots[
			player
		]


	if not plot then

		DataService.ReleasePlayer(
			player
		)


		releasingPlayers[
			player
		] = nil


		return
	end


	-- Save BEFORE resetting the plot.
	local saved =
		DataService.SavePlayer(
			player
		)


	if not saved then

		warn(
			`Final save failed for {player.Name}.`
		)
	end


	clearPlot(
		plot
	)


	plot:SetAttribute(
		"OwnerUserId",
		0
	)


	plot:SetAttribute(
		"OwnerName",
		""
	)


	player:SetAttribute(
		"PlotName",
		nil
	)


	assignedPlots[
		player
	] = nil


	DataService.ReleasePlayer(
		player
	)


	releasingPlayers[
		player
	] = nil
end


local function assignPlot(
	player: Player
)
	if assignedPlots[
		player
	] then

		return
	end


	local profile =
		DataService.WaitForProfile(
			player,
			20
		)


	if not profile then

		if player.Parent then

			player:Kick(
				"Your saved data did not finish loading. Please rejoin."
			)
		end


		return
	end


	if not player.Parent then
		return
	end


	local plot =
		getAvailablePlot()


	if not plot then

		player:Kick(
			"All business plots are currently occupied."
		)


		return
	end


	plot:SetAttribute(
		"OwnerUserId",
		player.UserId
	)


	plot:SetAttribute(
		"OwnerName",
		player.Name
	)


	assignedPlots[
		player
	] = plot


	player:SetAttribute(
		"PlotName",
		plot.Name
	)


	clearPlot(
		plot
	)


	-- Restore saved plot size FIRST.
	local plotApplied =
		PlotService.ApplyToPlot(
			player,
			plot,
			false
		)


	if not plotApplied then

		warn(
			`Could not restore {player.Name}'s plot size.`
		)
	end


	-- Restore businesses after Ground has reached
	-- its saved size.
	local restored =
		DataService.RestorePlot(
			player,
			plot
		)


	if not restored then

		warn(
			`Could not fully restore {player.Name}'s plot.`
		)
	end


	player.CharacterAdded:Connect(
		function(
			character
		)

			teleportCharacterToPlot(
				character,
				plot
			)
		end
	)


	if player.Character then

		teleportCharacterToPlot(
			player.Character,
			plot
		)
	end


	print(
		`Assigned {plot.Name} to {player.Name}`
	)
end


Players.PlayerAdded:Connect(
	function(
		player
	)

		task.spawn(
			assignPlot,
			player
		)
	end
)


Players.PlayerRemoving:Connect(
	releasePlot
)


for _, player in
	Players:GetPlayers() do

	task.spawn(
		assignPlot,
		player
	)
end