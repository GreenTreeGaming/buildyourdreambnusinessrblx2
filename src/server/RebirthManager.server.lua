local Players =
	game:GetService(
		"Players"
	)

local DataStoreService =
	game:GetService(
		"DataStoreService"
	)

local ReplicatedStorage =
	game:GetService(
		"ReplicatedStorage"
	)

local Workspace =
	game:GetService(
		"Workspace"
	)


--==================================================
-- MODULES
--==================================================

local RebirthConfig =
	require(
		ReplicatedStorage
			:WaitForChild(
				"Shared"
			)
			:WaitForChild(
				"RebirthConfig"
			)
	)


local Services =
	script.Parent:WaitForChild(
		"Services"
	)


local DataService =
	require(
		Services:WaitForChild(
			"DataService"
		)
	)


local PlotService =
	require(
		Services:WaitForChild(
			"PlotService"
		)
	)


local MarketingService =
	require(
		Services:WaitForChild(
			"MarketingService"
		)
	)


--==================================================
-- DATA STORE
--==================================================

local rebirthStore =
	DataStoreService:GetDataStore(
		"RebirthData_v1"
	)


local rebirthCounts: {
	[Player]: number
} = {}


local playerLocks: {
	[Player]: boolean
} = {}


--==================================================
-- REMOTES
--==================================================

local remotes =
	ReplicatedStorage:FindFirstChild(
		"Remotes"
	)


if not remotes then

	remotes =
		Instance.new(
			"Folder"
		)

	remotes.Name =
		"Remotes"

	remotes.Parent =
		ReplicatedStorage
end


local function getOrCreateRemoteFunction(
	name: string
): RemoteFunction

	local existing =
		remotes:FindFirstChild(
			name
		)


	if existing then

		if not existing:IsA(
			"RemoteFunction"
		) then

			error(
				`ReplicatedStorage.Remotes.{name} must be a RemoteFunction.`
			)
		end


		return existing
	end


	local remote =
		Instance.new(
			"RemoteFunction"
		)

	remote.Name =
		name

	remote.Parent =
		remotes


	return remote
end


local function getOrCreateRemoteEvent(
	name: string
): RemoteEvent

	local existing =
		remotes:FindFirstChild(
			name
		)


	if existing then

		if not existing:IsA(
			"RemoteEvent"
		) then

			error(
				`ReplicatedStorage.Remotes.{name} must be a RemoteEvent.`
			)
		end


		return existing
	end


	local remote =
		Instance.new(
			"RemoteEvent"
		)

	remote.Name =
		name

	remote.Parent =
		remotes


	return remote
end


local getRebirthStateRemote =
	getOrCreateRemoteFunction(
		"GetRebirthState"
	)


local requestRebirthRemote =
	getOrCreateRemoteFunction(
		"RequestRebirth"
	)


local rebirthCompletedRemote =
	getOrCreateRemoteEvent(
		"RebirthCompleted"
	)


--==================================================
-- HELPERS
--==================================================

local function sanitizeRebirthCount(
	value: any
): number

	if typeof(value)
		~= "number" then

		return 0
	end


	if value ~= value
		or value == math.huge
		or value == -math.huge then

		return 0
	end


	return math.max(
		0,
		math.floor(
			value
		)
	)
end


local function getDataKey(
	player: Player
): string

	return `Player_{player.UserId}`
end


local function getOwnedPlot(
	player: Player
): Model?

	local plotName =
		player:GetAttribute(
			"PlotName"
		)


	if typeof(plotName)
		== "string" then

		local plot =
			Workspace
				:WaitForChild(
					"Plots"
				)
				:FindFirstChild(
					plotName
				)


		if plot
			and plot:IsA(
				"Model"
			)
			and plot:GetAttribute(
				"OwnerUserId"
			) == player.UserId then

			return plot
		end
	end


	for _, plot in
		Workspace
			:WaitForChild(
				"Plots"
			)
			:GetChildren() do

		if plot:IsA(
			"Model"
		)
			and plot:GetAttribute(
				"OwnerUserId"
			) == player.UserId then

			return plot
		end
	end


	return nil
end


local function getCash(
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


local function getReputationLevel(
	player: Player
): number

	local plot =
		getOwnedPlot(
			player
		)


	if not plot then
		return 1
	end


	local level =
		plot:GetAttribute(
			"ReputationLevel"
		)


	if typeof(level)
		~= "number" then

		return 1
	end


	return math.max(
		1,
		math.floor(
			level
		)
	)
end


--==================================================
-- PERMANENT BONUS ATTRIBUTES
--==================================================

local function applyRebirthBonuses(
	player: Player
)

	local rebirths =
		rebirthCounts[
			player
		] or 0


	local bonuses =
		RebirthConfig.GetBonuses(
			rebirths
		)


	player:SetAttribute(
		"Rebirths",
		rebirths
	)


	player:SetAttribute(
		"RebirthCashMultiplier",
		bonuses.CashMultiplier
	)


	player:SetAttribute(
		"RebirthCustomerMultiplier",
		bonuses.CustomerRateMultiplier
	)


	player:SetAttribute(
		"RebirthRareCustomerMultiplier",
		bonuses.RareCustomerMultiplier
	)
end


--==================================================
-- STATE
--==================================================

local function buildState(
	player: Player
)

	local rebirths =
		rebirthCounts[
			player
		] or 0


	local requirements =
		RebirthConfig.GetRequirements(
			rebirths
		)


	local bonuses =
		RebirthConfig.GetBonuses(
			rebirths
		)


	local nextGain =
		RebirthConfig.GetNextGain(
			rebirths
		)


	local reputation =
		getReputationLevel(
			player
		)


	local cashValue =
		getCash(
			player
		)


	local cash =
		cashValue
			and cashValue.Value
			or 0


	local standUnlocked =
		DataService.IsBusinessUnlocked(
			player,
			requirements.Business
		)


	local reputationMet =
		reputation
		>= requirements.Reputation


	local cashMet =
		cash
		>= requirements.Cash


	local canRebirth =
		reputationMet
		and cashMet
		and standUnlocked


	return {
		Success =
			true,

		Rebirths =
			rebirths,

		CanRebirth =
			canRebirth,

		CurrentBonuses = {
			CashPercent =
				math.floor(
					bonuses.CashBonus
						* 100
						+ 0.5
				),

			SpeedPercent =
				math.floor(
					bonuses.CustomerRateBonus
						* 100
						+ 0.5
				),

			OddsPercent =
				math.floor(
					bonuses.RareCustomerBonus
						* 100
						+ 0.5
				),
		},

		NextGain = {
			CashPercent =
				math.floor(
					nextGain.CashBonus
						* 100
						+ 0.5
				),

			SpeedPercent =
				math.floor(
					nextGain.CustomerRateBonus
						* 100
						+ 0.5
				),

			OddsPercent =
				math.floor(
					nextGain.RareCustomerBonus
						* 100
						+ 0.5
				),
		},

		Requirements = {
			Reputation = {
				Current =
					reputation,

				Required =
					requirements.Reputation,

				Met =
					reputationMet,
			},

			Cash = {
				Current =
					cash,

				Required =
					requirements.Cash,

				Met =
					cashMet,
			},

			Stand = {
				Name =
					requirements
						.BusinessDisplayName,

				Met =
					standUnlocked,
			},
		},
	}
end


--==================================================
-- SAVE REBIRTH COUNT
--==================================================

local function saveRebirthCount(
	player: Player,
	newCount: number
): boolean

	local success,
		result =
		pcall(
			function()

				return rebirthStore:
					UpdateAsync(
						getDataKey(
							player
						),

						function(
							oldValue
						)

							local oldCount =
								sanitizeRebirthCount(
									oldValue
								)


							return math.max(
								oldCount,
								newCount
							)
						end
					)
			end
		)


	if not success then

		warn(
			`[Rebirth] Failed to save rebirth for {player.Name}: {result}`
		)

		return false
	end


	return true
end


--==================================================
-- CLEAR CUSTOMERS
--==================================================

local function clearPlotCustomers(
	plot: Model
)

	local customers =
		Workspace:FindFirstChild(
			"Customers"
		)


	if not customers then
		return
	end


	for _, customer in
		customers:GetChildren() do

		if not customer:IsA(
			"Model"
		) then

			continue
		end


		if customer:GetAttribute(
			"PlotName"
		) == plot.Name then

			customer:Destroy()
		end
	end
end


--==================================================
-- CLEAR BUSINESSES
--==================================================

local function clearBusinesses(
	plot: Model
)

	local placedBusinesses =
		plot:FindFirstChild(
			"PlacedBusinesses"
		)


	if not placedBusinesses then
		return
	end


	for _, business in
		placedBusinesses:GetChildren() do

		business:Destroy()
	end
end


--==================================================
-- RESET CURRENT RUN
--==================================================

local function resetCurrentRun(
	player: Player
): boolean

	local profile =
		DataService.GetProfile(
			player
		)


	if not profile then

		return false
	end


	local plot =
		getOwnedPlot(
			player
		)


	if not plot then

		return false
	end


	local cash =
		getCash(
			player
		)


	if not cash then

		return false
	end


	--==================================================
	-- CASH
	--==================================================

	cash.Value =
		0

	profile.Cash =
		0


	-- HighestCash intentionally remains untouched.
	-- It represents the player's all-time record.


	--==================================================
	-- BUSINESS PROGRESSION
	--==================================================

	profile.PlacedBusinesses =
		{}

	profile.NextBusinessNumber =
		1


	profile.Upgrades = {
		LemonadeStand = {
			ServingSpeed =
				0,

			SaleValue =
				0,

			QueueCapacity =
				0,
		},
	}


	profile.UnlockedBusinesses = {
		LemonadeStand =
			true,

		HotdogStand =
			false,

		HaircutStand =
			false,

		CoffeeStand =
			false,
	}


	--==================================================
	-- MARKETING / PLOT
	--==================================================

	DataService.SetMarketingLevel(
		player,
		0
	)


	DataService.SetPlotLevel(
		player,
		0
	)


	--==================================================
	-- REPUTATION BOOST PROGRESS
	--==================================================

	-- Keep purchased boost timers, receipts, etc.
	-- Only current-run reputation progress resets.

	if type(
		profile.Monetization
	) == "table" then

		profile.Monetization
			.ReputationBonusSales =
			0
	end


	--==================================================
	-- PHYSICAL WORLD
	--==================================================

	clearPlotCustomers(
		plot
	)


	clearBusinesses(
		plot
	)


	PlotService.ResetPlot(
		plot
	)


	MarketingService.ApplyToPlot(
		player,
		plot
	)


	--==================================================
	-- RUNTIME PLOT ATTRIBUTES
	--==================================================

	plot:SetAttribute(
		"StarterBusinessPlaced",
		false
	)


	plot:SetAttribute(
		"ReputationReady",
		false
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


	player:SetAttribute(
		"EditingBusiness",
		nil
	)


	--==================================================
	-- SAVE RESET STATE
	--==================================================

	local saved =
		DataService.SavePlayer(
			player
		)


	if not saved then

		warn(
			`[Rebirth] Current-run reset save failed for {player.Name}.`
		)
	end


	return true
end


--==================================================
-- GET STATE
--==================================================

getRebirthStateRemote.OnServerInvoke =
	function(
		player: Player
	)

		if rebirthCounts[
			player
		] == nil then

			return {
				Success =
					false,

				Message =
					"Your rebirth data is still loading.",
			}
		end


		return buildState(
			player
		)
	end


--==================================================
-- REBIRTH
--==================================================

requestRebirthRemote.OnServerInvoke =
	function(
		player: Player
	)

		if playerLocks[
			player
		] then

			return {
				Success =
					false,

				Message =
					"Please wait.",
			}
		end


		playerLocks[
			player
		] =
			true


		local function finish(
			result
		)

			playerLocks[
				player
			] =
				nil


			return result
		end


		if rebirthCounts[
			player
		] == nil then

			return finish({
				Success =
					false,

				Message =
					"Your rebirth data is still loading.",
			})
		end


		-- Re-check requirements on the SERVER.
		local state =
			buildState(
				player
			)


		if state.CanRebirth
			~= true then

			return finish({
				Success =
					false,

				Message =
					"You do not meet the rebirth requirements yet.",

				State =
					state,
			})
		end


		local oldCount =
			rebirthCounts[
				player
			]


		local newCount =
			oldCount + 1


		-- Save the permanent reward first.
		local savedRebirth =
			saveRebirthCount(
				player,
				newCount
			)


		if not savedRebirth then

			return finish({
				Success =
					false,

				Message =
					"Your rebirth could not be saved. Please try again.",
			})
		end


		rebirthCounts[
			player
		] =
			newCount


		applyRebirthBonuses(
			player
		)


		local resetSuccess =
			resetCurrentRun(
				player
			)


		if not resetSuccess then

			warn(
				`[Rebirth] {player.Name}'s rebirth saved, but their current run could not fully reset.`
			)


			return finish({
				Success =
					false,

				Message =
					"Your rebirth was saved, but your plot could not fully reset. Please rejoin.",
			})
		end


		local newState =
			buildState(
				player
			)


		rebirthCompletedRemote:
			FireClient(
				player,
				newState
			)


		-- Respawn them at their clean plot.
		task.defer(
			function()

				if player.Parent then

					player:LoadCharacter()
				end
			end
		)


		return finish({
			Success =
				true,

			Message =
				`Rebirth #{newCount} complete!`,

			State =
				newState,
		})
	end


--==================================================
-- LOAD PLAYER
--==================================================

local function loadPlayer(
	player: Player
)

	-- Wait for the normal player profile first.
	local profile =
		DataService.WaitForProfile(
			player,
			20
		)


	if not profile
		or not player.Parent then

		return
	end


	local success,
		result =
		pcall(
			function()

				return rebirthStore:GetAsync(
					getDataKey(
						player
					)
				)
			end
		)


	local count =
		0


	if success then

		count =
			sanitizeRebirthCount(
				result
			)

	else

		warn(
			`[Rebirth] Failed to load rebirth data for {player.Name}: {result}`
		)
	end


	if not player.Parent then
		return
	end


	rebirthCounts[
		player
	] =
		count


	applyRebirthBonuses(
		player
	)
end


--==================================================
-- PLAYERS
--==================================================

Players.PlayerAdded:Connect(
	function(
		player: Player
	)

		task.spawn(
			loadPlayer,
			player
		)
	end
)


Players.PlayerRemoving:Connect(
	function(
		player: Player
	)

		rebirthCounts[
			player
		] =
			nil


		playerLocks[
			player
		] =
			nil
	end
)


for _, player in
	Players:GetPlayers() do

	task.spawn(
		loadPlayer,
		player
	)
end


print(
	"RebirthManager started."
)