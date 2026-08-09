local Players =
	game:GetService("Players")

local ReplicatedStorage =
	game:GetService("ReplicatedStorage")

local Workspace =
	game:GetService("Workspace")


local QuestService =
	require(
		script.Parent
			:WaitForChild("Services")
			:WaitForChild("QuestService")
	)


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


--==================================================
-- REMOTES
--==================================================

local function getOrCreateRemoteEvent(
	name: string
): RemoteEvent

	local existing =
		remotes:FindFirstChild(
			name
		)


	if existing then
		if existing:IsA(
			"RemoteEvent"
		) then

			return existing
		end


		existing:Destroy()
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


local function getOrCreateRemoteFunction(
	name: string
): RemoteFunction

	local existing =
		remotes:FindFirstChild(
			name
		)


	if existing then
		if existing:IsA(
			"RemoteFunction"
		) then

			return existing
		end


		existing:Destroy()
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


local getQuestStateRemote =
	getOrCreateRemoteFunction(
		"GetQuestState"
	)

local claimQuestRemote =
	getOrCreateRemoteEvent(
		"ClaimQuest"
	)

local questStateChangedRemote =
	getOrCreateRemoteEvent(
		"QuestStateChanged"
	)

local questClaimResultRemote =
	getOrCreateRemoteEvent(
		"QuestClaimResult"
	)


--==================================================
-- TRACKING
--==================================================

type StandTracker = {
	TotalSales: number,
	LifetimeEarnings: number,

	Connections: {
		RBXScriptConnection
	},
}


local trackedStands: {
	[Player]: {
		[Model]: StandTracker
	}
} = {}


local playerStateSignatures: {
	[Player]: string
} = {}


local claimLocks: {
	[Player]: boolean
} = {}


--==================================================
-- HELPERS
--==================================================

local function sanitizeCounter(
	value: any
): number

	if typeof(value)
			~= "number"
		or value ~= value
		or value == math.huge
		or value == -math.huge then

		return 0
	end


	return math.max(
		0,
		math.floor(value)
	)
end


local function getPlayerPlot(
	player: Player
): Model?

	local plots =
		Workspace:FindFirstChild(
			"Plots"
		)

	if not plots then
		return nil
	end


	local plotName =
		player:GetAttribute(
			"PlotName"
		)


	if typeof(plotName)
		== "string" then

		local plot =
			plots:FindFirstChild(
				plotName
			)


		if plot
			and plot:IsA("Model")
			and plot:GetAttribute(
				"OwnerUserId"
			) == player.UserId then

			return plot
		end
	end


	for _, plot in
		plots:GetChildren()
	do
		if plot:IsA("Model")
			and plot:GetAttribute(
				"OwnerUserId"
			) == player.UserId then

			return plot
		end
	end


	return nil
end


local function getPlacedBusinessesFolder(
	player: Player
): Folder?

	local plot =
		getPlayerPlot(
			player
		)

	if not plot then
		return nil
	end


	local folder =
		plot:FindFirstChild(
			"PlacedBusinesses"
		)


	if folder
		and folder:IsA(
			"Folder"
		) then

		return folder
	end


	return nil
end


local function disconnectTracker(
	tracker: StandTracker
)
	for _, connection in
		tracker.Connections
	do
		connection:Disconnect()
	end


	table.clear(
		tracker.Connections
	)
end


local function createStateSignature(
	state
): string

	local pieces =
		{}


	for _, quest in state do
		table.insert(
			pieces,

			table.concat(
				{
					tostring(
						quest.Id
					),

					tostring(
						quest.Progress
					),

					tostring(
						quest.Completed
					),

					tostring(
						quest.Claimed
					),
				},

				":"
			)
		)
	end


	return table.concat(
		pieces,
		"|"
	)
end


local function pushStateIfChanged(
	player: Player,
	force: boolean?
)
	if not player.Parent then
		return
	end


	local state =
		QuestService.GetState(
			player
		)

	local signature =
		createStateSignature(
			state
		)


	if not force
		and playerStateSignatures[
			player
		] == signature then

		return
	end


	playerStateSignatures[
		player
	] = signature


	questStateChangedRemote:FireClient(
		player,
		state
	)
end


--==================================================
-- STAND ATTRIBUTE TRACKING
--==================================================

local function trackStand(
	player: Player,
	stand: Model
)
	local playerTrackers =
		trackedStands[
			player
		]

	if not playerTrackers then
		return
	end


	if playerTrackers[
		stand
	] then

		return
	end


	local tracker: StandTracker = {
		TotalSales =
			sanitizeCounter(
				stand:GetAttribute(
					"TotalSales"
				)
			),

		LifetimeEarnings =
			sanitizeCounter(
				stand:GetAttribute(
					"LifetimeEarnings"
				)
			),

		Connections = {},
	}


	playerTrackers[
		stand
	] = tracker


	local salesConnection =
		stand:GetAttributeChangedSignal(
			"TotalSales"
		):Connect(
			function()
				local current =
					sanitizeCounter(
						stand:GetAttribute(
							"TotalSales"
						)
					)


				local delta =
					current
					- tracker.TotalSales


				tracker.TotalSales =
					current


				if delta > 0 then
					QuestService.AddStat(
						player,
						"TotalSales",
						delta
					)

					pushStateIfChanged(
						player
					)
				end
			end
		)


	local earningsConnection =
		stand:GetAttributeChangedSignal(
			"LifetimeEarnings"
		):Connect(
			function()
				local current =
					sanitizeCounter(
						stand:GetAttribute(
							"LifetimeEarnings"
						)
					)


				local delta =
					current
					- tracker.LifetimeEarnings


				tracker.LifetimeEarnings =
					current


				if delta > 0 then
					QuestService.AddStat(
						player,
						"LifetimeEarnings",
						delta
					)

					pushStateIfChanged(
						player
					)
				end
			end
		)


	local ancestryConnection =
		stand.AncestryChanged:Connect(
			function()
				if stand:IsDescendantOf(
					Workspace
				) then

					return
				end


				local currentTracker =
					playerTrackers[
						stand
					]


				if currentTracker then
					disconnectTracker(
						currentTracker
					)

					playerTrackers[
						stand
					] = nil
				end
			end
		)


	table.insert(
		tracker.Connections,
		salesConnection
	)

	table.insert(
		tracker.Connections,
		earningsConnection
	)

	table.insert(
		tracker.Connections,
		ancestryConnection
	)
end


local function discoverStands(
	player: Player
)
	local playerTrackers =
		trackedStands[
			player
		]

	if not playerTrackers then
		return
	end


	local folder =
		getPlacedBusinessesFolder(
			player
		)

	if not folder then
		return
	end


	for _, child in
		folder:GetChildren()
	do
		if child:IsA("Model") then
			trackStand(
				player,
				child
			)
		end
	end


	--
	-- Clean up trackers for models that no longer
	-- exist. Appearance upgrades can replace models.
	--
	for stand, tracker in
		playerTrackers
	do
		if not stand.Parent
			or stand.Parent
				~= folder then

			disconnectTracker(
				tracker
			)

			playerTrackers[
				stand
			] = nil
		end
	end
end


--==================================================
-- PLAYER INITIALIZATION
--==================================================

local function initializePlayer(
	player: Player
)
	while player.Parent
		and player:GetAttribute(
			"DataLoaded"
		) ~= true do

		task.wait(
			0.1
		)
	end


	if not player.Parent then
		return
	end


	QuestService.InitializePlayer(
		player
	)


	trackedStands[
		player
	] = {}


	discoverStands(
		player
	)


	pushStateIfChanged(
		player,
		true
	)
end


Players.PlayerAdded:Connect(
	function(
		player: Player
	)
		task.spawn(
			initializePlayer,
			player
		)
	end
)


for _, player in
	Players:GetPlayers()
do
	task.spawn(
		initializePlayer,
		player
	)
end


--==================================================
-- REMOTE REQUESTS
--==================================================

getQuestStateRemote.OnServerInvoke =
	function(
		player: Player
	)
		if player:GetAttribute(
			"DataLoaded"
		) ~= true then

			return {}
		end


		return QuestService.GetState(
			player
		)
	end


claimQuestRemote.OnServerEvent:Connect(
	function(
		player: Player,
		questId: any
	)
		if claimLocks[
			player
		] then

			return
		end


		if typeof(questId)
			~= "string" then

			return
		end


		claimLocks[
			player
		] = true


		local success,
			message =
			QuestService.Claim(
				player,
				questId
			)


		questClaimResultRemote:FireClient(
			player,
			success,
			message
		)


		pushStateIfChanged(
			player,
			true
		)


		task.delay(
			0.2,
			function()
				claimLocks[
					player
				] = nil
			end
		)
	end
)


--==================================================
-- PERIODIC DYNAMIC QUEST REFRESH
--==================================================

--
-- Sales/earnings are event-driven above.
--
-- This lightweight loop handles things like:
--   business count
--   stand appearance level
--   gameplay upgrade level
--
task.spawn(
	function()
		while true do
			for _, player in
				Players:GetPlayers()
			do
				if player:GetAttribute(
					"DataLoaded"
				) == true then

					discoverStands(
						player
					)

					pushStateIfChanged(
						player
					)
				end
			end


			task.wait(
				0.5
			)
		end
	end
)


--==================================================
-- CLEANUP
--==================================================

Players.PlayerRemoving:Connect(
	function(
		player: Player
	)
		local playerTrackers =
			trackedStands[
				player
			]


		if playerTrackers then
			for _, tracker in
				playerTrackers
			do
				disconnectTracker(
					tracker
				)
			end
		end


		trackedStands[
			player
		] = nil

		playerStateSignatures[
			player
		] = nil

		claimLocks[
			player
		] = nil
	end
)