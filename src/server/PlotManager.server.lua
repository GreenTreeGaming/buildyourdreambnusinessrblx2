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


local customersFolder =
	Workspace:WaitForChild(
		"Customers"
	)


local plotsFolder =
	Workspace:WaitForChild(
		"Plots"
	)


--==================================================
-- SETTINGS
--==================================================

local EXPECTED_PLOT_COUNT =
	6


local REQUIRED_PLOT_CHILDREN = {
	"PlotOrigin",
	"Ground",
	"PlayerSpawn",
	"CustomerSpawn",
	"PlacedBusinesses",
}


--==================================================
-- STATE
--==================================================

local assignedPlots: {
	[Player]: Model
} = {}


local releasingPlayers: {
	[Player]: boolean
} = {}


--==================================================
-- PLOT NUMBER
--==================================================

local function getPlotNumber(
	plot: Model
): number

	local number =
		tonumber(
			string.match(
				plot.Name,
				"^Plot(%d+)$"
			)
		)


	return number
		or math.huge
end


--==================================================
-- PLOT VALIDATION
--==================================================

local function validatePlot(
	plot: Model
): boolean

	for _, childName in
		REQUIRED_PLOT_CHILDREN do

		local child =
			plot:FindFirstChild(
				childName
			)


		if not child then

			warn(
				`[PlotManager] {plot:GetFullName()} is missing {childName}.`
			)


			return false
		end
	end


	local plotOrigin =
		plot:FindFirstChild(
			"PlotOrigin"
		)


	if not plotOrigin
		or not plotOrigin:IsA(
			"BasePart"
		) then

		warn(
			`[PlotManager] {plot:GetFullName()}.PlotOrigin must be a BasePart.`
		)


		return false
	end


	local ground =
		plot:FindFirstChild(
			"Ground"
		)


	if not ground
		or not ground:IsA(
			"BasePart"
		) then

		warn(
			`[PlotManager] {plot:GetFullName()}.Ground must be a BasePart.`
		)


		return false
	end


	local playerSpawn =
		plot:FindFirstChild(
			"PlayerSpawn"
		)


	if not playerSpawn
		or not playerSpawn:IsA(
			"BasePart"
		) then

		warn(
			`[PlotManager] {plot:GetFullName()}.PlayerSpawn must be a BasePart.`
		)


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

		warn(
			`[PlotManager] {plot:GetFullName()}.CustomerSpawn must be a BasePart.`
		)


		return false
	end


	local placedBusinesses =
		plot:FindFirstChild(
			"PlacedBusinesses"
		)


	if not placedBusinesses
		or not placedBusinesses:IsA(
			"Folder"
		) then

		warn(
			`[PlotManager] {plot:GetFullName()}.PlacedBusinesses must be a Folder.`
		)


		return false
	end


	return true
end


--==================================================
-- SORTED PLOTS
--==================================================

local function getSortedPlots(): {
	Model
}

	local plots = {}


	for _, instance in
		plotsFolder:GetChildren() do

		if not instance:IsA(
			"Model"
		) then

			continue
		end


		if not validatePlot(
			instance
		) then

			continue
		end


		table.insert(
			plots,
			instance
		)
	end


	table.sort(
		plots,

		function(
			firstPlot: Model,
			secondPlot: Model
		): boolean

			return getPlotNumber(
				firstPlot
			) < getPlotNumber(
				secondPlot
			)
		end
	)


	return plots
end


--==================================================
-- INITIALIZE PLOTS
--==================================================

local function initializePlots()

	local plots =
		getSortedPlots()


	if #plots ~= EXPECTED_PLOT_COUNT then

		warn(
			`[PlotManager] Expected {EXPECTED_PLOT_COUNT} plots, but found {#plots} valid plots.`
		)

	end


	for _, plot in plots do

		-- Studio may contain old test attributes.
		-- Always begin a fresh server with every physical
		-- plot unclaimed.
		plot:SetAttribute(
			"OwnerUserId",
			0
		)


		plot:SetAttribute(
			"OwnerName",
			""
		)


		plot:SetAttribute(
			"StarterBusinessPlaced",
			false
		)


		local origin =
			plot:FindFirstChild(
				"PlotOrigin"
			)


		if origin
			and origin:IsA(
				"BasePart"
			) then

			origin.Anchored =
				true

			origin.CanCollide =
				false

			origin.CanTouch =
				false

			origin.CanQuery =
				false

			origin.Transparency =
				1
		end
	end


	print(
		`[PlotManager] Initialized {#plots} plot(s).`
	)
end


--==================================================
-- CUSTOMERS
--==================================================

local function clearPlotCustomers(
	plot: Model
)

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


		customer:Destroy()
	end
end


--==================================================
-- AVAILABLE PLOT
--==================================================

local function getAvailablePlot():
	Model?

	for _, plot in
		getSortedPlots() do

		local ownerUserId =
			plot:GetAttribute(
				"OwnerUserId"
			)


		if typeof(ownerUserId)
				~= "number"
			or ownerUserId <= 0 then

			return plot
		end
	end


	return nil
end


--==================================================
-- PLACED BUSINESSES
--==================================================

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
		`[PlotManager] {plot.Name} does not contain a valid PlacedBusinesses folder.`
	)


	return nil
end


--==================================================
-- CHARACTER TELEPORT
--==================================================

local function teleportCharacterToPlot(
	character: Model,
	plot: Model
)

	if not character.Parent then
		return
	end


	local spawnPart =
		plot:FindFirstChild(
			"PlayerSpawn"
		)


	if not spawnPart
		or not spawnPart:IsA(
			"BasePart"
		) then

		warn(
			`[PlotManager] {plot.Name} does not contain a valid PlayerSpawn.`
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
			"[PlotManager] HumanoidRootPart did not load."
		)


		return
	end


	-- IMPORTANT:
	-- This uses PlayerSpawn.CFrame rather than only
	-- PlayerSpawn.Position.
	--
	-- Therefore Plot4–Plot6 may face the opposite
	-- direction and the character will correctly spawn
	-- facing toward their road.
	character:PivotTo(
		spawnPart.CFrame
			* CFrame.new(
				0,
				3,
				0
			)
	)
end


--==================================================
-- CLEAR PLOT
--==================================================

local function clearPlot(
	plot: Model
)

	-- Remove every customer belonging to this plot.
	clearPlotCustomers(
		plot
	)


	-- Remove every business belonging to the old owner.
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


	-- Return the physical plot to its starting size.
	PlotService.ResetPlot(
		plot
	)


	--==================================================
	-- RESET RUNTIME PLOT STATE
	--==================================================

	plot:SetAttribute(
		"StarterBusinessPlaced",
		false
	)


	plot:SetAttribute(
		"MarketingLevel",
		0
	)


	plot:SetAttribute(
		"ReputationLevel",
		1
	)


	plot:SetAttribute(
		"ReputationRating",
		3
	)


	plot:SetAttribute(
		"ReputationCustomerRateMultiplier",
		1
	)


	plot:SetAttribute(
		"PlotCustomerRateMultiplier",
		1
	)


	plot:SetAttribute(
		"ActiveCustomerTrafficMultiplier",
		nil
	)
end

--==================================================
-- RELEASE
--==================================================

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
	] =
		true


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


	-- Save before destroying physical businesses.
	local saved =
		DataService.SavePlayer(
			player
		)


	if not saved then

		warn(
			`[PlotManager] Final save failed for {player.Name}.`
		)

	end


	-- Release ownership immediately after the save so
-- no gameplay systems continue treating this plot
-- as active while it is being cleaned.
plot:SetAttribute(
	"OwnerUserId",
	0
)


plot:SetAttribute(
	"OwnerName",
	""
)


clearPlot(
	plot
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


	print(
		`[PlotManager] Released {plot.Name} from {player.Name}.`
	)
end


--==================================================
-- ASSIGN
--==================================================

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


	-- Claim immediately. There are no yields between
	-- finding the available plot and claiming it.
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
	] =
		plot


	player:SetAttribute(
		"PlotName",
		plot.Name
	)


	clearPlot(
		plot
	)


	-- Restore plot expansion before businesses.
	local plotApplied =
		PlotService.ApplyToPlot(
			player,
			plot,
			false
		)


	if not plotApplied then

		warn(
			`[PlotManager] Could not restore {player.Name}'s plot size.`
		)

	end


	-- Businesses use plot-relative coordinates,
	-- therefore the same saved layout can load on
	-- Plot1, Plot4, Plot6, etc.
	local restored =
		DataService.RestorePlot(
			player,
			plot
		)


	if not restored then

		warn(
			`[PlotManager] Could not fully restore {player.Name}'s plot.`
		)

	end


	player.CharacterAdded:Connect(
		function(
			character: Model
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
		`[PlotManager] Assigned {plot.Name} to {player.Name}.`
	)
end


--==================================================
-- STARTUP
--==================================================

initializePlots()


Players.PlayerAdded:Connect(
	function(
		player: Player
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