local Players =
	game:GetService(
		"Players"
	)

local MarketplaceService =
	game:GetService(
		"MarketplaceService"
	)

local ReplicatedStorage =
	game:GetService(
		"ReplicatedStorage"
	)

local ServerStorage =
	game:GetService(
		"ServerStorage"
	)


--==================================================
-- MODULES
--==================================================

local ShopConfig =
	require(
		ReplicatedStorage
			:WaitForChild("Shared")
			:WaitForChild("ShopConfig")
	)


local DataService =
	require(
		script.Parent
			:WaitForChild("Services")
			:WaitForChild("DataService")
	)


local config =
	ShopConfig.StarterPack


assert(
	type(config) == "table",
	"[StarterPack] ShopConfig.StarterPack is missing."
)


--==================================================
-- REMOTES
--==================================================

local remotes =
	ReplicatedStorage:WaitForChild(
		"Remotes"
	)


local function getOrCreateRemoteFunction(
	name: string
): RemoteFunction

	local existing =
		remotes:FindFirstChild(
			name
		)


	if existing then

		assert(
			existing:IsA(
				"RemoteFunction"
			),

			`Remotes.{name} must be a RemoteFunction.`
		)


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

		assert(
			existing:IsA(
				"RemoteEvent"
			),

			`Remotes.{name} must be a RemoteEvent.`
		)


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


local getStarterPackState =
	getOrCreateRemoteFunction(
		"GetStarterPackState"
	)


local starterPackUpdated =
	getOrCreateRemoteEvent(
		"StarterPackUpdated"
	)


--==================================================
-- STATE
--==================================================

local grantLocks: {
	[Player]: boolean
} = {}


local goldenWorkers: {
	[Player]: boolean
} = {}


--==================================================
-- OWNERSHIP
--==================================================

local function ownsStarterPack(
	player: Player
): boolean

	local success,
		result =
		pcall(
			function()

				return MarketplaceService:
					UserOwnsGamePassAsync(
						player.UserId,
						config.Id
					)
			end
		)


	if not success then

		warn(
			`[StarterPack] Could not check ownership for {player.Name}: {result}`
		)

		return false
	end


	return result == true
end


--==================================================
-- START TIMER
--==================================================

local function ensureTimerStarted(
	player: Player
): number

	if not DataService.GetTutorialCompleted(
		player
	) then

		return -1
	end


	local startedAt =
		DataService.GetStarterPackStartedAt(
			player
		)


	if startedAt >= 0 then
		return startedAt
	end


	startedAt =
		DataService.GetTimePlayed(
			player
		)


	if not DataService.SetStarterPackStartedAt(
		player,
		startedAt
	) then

		return -1
	end


	-- Save the starting point promptly so a reconnect
	-- cannot reset the new-player offer timer.
	task.spawn(
		function()

			DataService.SavePlayer(
				player
			)
		end
	)


	return startedAt
end


--==================================================
-- TIME REMAINING
--==================================================

local function getSecondsRemaining(
	player: Player
): number

	if not DataService.GetTutorialCompleted(
		player
	) then

		return config.OfferDuration
	end


	local startedAt =
		ensureTimerStarted(
			player
		)


	if startedAt < 0 then
		return config.OfferDuration
	end


	local playedSinceStart =
		math.max(
			0,

			DataService.GetTimePlayed(
				player
			)
				- startedAt
		)


	return math.max(
		0,

		config.OfferDuration
			- playedSinceStart
	)
end


--==================================================
-- GOLDEN CUSTOMER DELIVERY
--==================================================

local function startGoldenWorker(
	player: Player
)

	if goldenWorkers[
		player
	] then

		return
	end


	goldenWorkers[
		player
	] =
		true


	task.spawn(
		function()

			local spawnPurchasedCustomer =
				ServerStorage:WaitForChild(
					"SpawnPurchasedCustomer"
				)


			if not spawnPurchasedCustomer:IsA(
				"BindableFunction"
			) then

				warn(
					"[StarterPack] SpawnPurchasedCustomer is not a BindableFunction."
				)

				goldenWorkers[
					player
				] = nil

				return
			end


			while player.Parent do

				local pending =
					DataService
						.GetStarterPackGoldenPending(
							player
						)


				if pending <= 0 then
					break
				end


				local success,
					spawned =
					pcall(
						function()

							return spawnPurchasedCustomer:
								Invoke(
									player,
									"Golden"
								)
						end
					)


				if success
					and spawned == true then

					DataService
						.SetStarterPackGoldenPending(
							player,
							pending - 1
						)


					-- Persist delivered customers so
					-- reconnecting does not re-deliver them.
					task.spawn(
						function()

							DataService.SavePlayer(
								player
							)
						end
					)


					task.wait(
						0.25
					)

				else

					-- Plot/queues may currently be full.
					-- Retry until the purchased customer
					-- can actually enter.
					task.wait(
						1
					)
				end
			end


			goldenWorkers[
				player
			] = nil
		end
	)
end


--==================================================
-- GRANT STARTER PACK
--==================================================

local function grantStarterPack(
	player: Player
): boolean

	if grantLocks[
		player
	] then

		return false
	end


	if DataService
		.GetStarterPackRewardGranted(
			player
		) then

		startGoldenWorker(
			player
		)

		return true
	end


	grantLocks[
		player
	] =
		true


	local profile =
		DataService.WaitForProfile(
			player,
			15
		)


	if not profile then

		grantLocks[
			player
		] = nil

		return false
	end


	local leaderstats =
		player:FindFirstChild(
			"leaderstats"
		)


	local cash =
		leaderstats
		and leaderstats:FindFirstChild(
			"Cash"
		)


	if not cash
		or not cash:IsA(
			"IntValue"
		) then

		grantLocks[
			player
		] = nil

		return false
	end


	--==================================================
	-- SAVE OLD VALUES FOR ROLLBACK
	--==================================================

	local oldCash =
		cash.Value


	local oldBoostUntil =
		DataService.GetBoostUntil(
			player,
			"CashBoost"
		)


	local oldPending =
		DataService
			.GetStarterPackGoldenPending(
				player
			)


	--==================================================
	-- CASH
	--==================================================

	cash.Value +=
		config.Cash


	--==================================================
	-- X2 CASH BOOST
	--==================================================

	local now =
		os.time()


	local boostStartsAt =
		math.max(
			now,
			oldBoostUntil
		)


	local newBoostUntil =
		boostStartsAt
			+ config.CashBoostDuration


	local boostUpdated =
		DataService.SetBoostUntil(
			player,
			"CashBoost",
			newBoostUntil
		)


	if not boostUpdated then

		cash.Value =
			oldCash


		grantLocks[
			player
		] = nil


		return false
	end


	-- MonetizationManager refreshes the actual
	-- CashMultiplier once per second.
	player:SetAttribute(
		"CashBoostUntil",
		newBoostUntil
	)


	--==================================================
	-- GOLDEN CUSTOMER
	--==================================================

	DataService
		.SetStarterPackGoldenPending(
			player,
			oldPending
				+ config.GoldenCustomers
		)


	--==================================================
	-- CLAIMED
	--==================================================

	DataService
		.SetStarterPackRewardGranted(
			player,
			true
		)


	--==================================================
	-- SAVE BEFORE DELIVERY
	--==================================================

	local saved =
		DataService.SavePlayer(
			player
		)


	if not saved then

		-- Roll everything back. Because a gamepass
		-- remains owned, the system can safely try
		-- granting again on the next join.

		cash.Value =
			oldCash


		DataService.SetBoostUntil(
			player,
			"CashBoost",
			oldBoostUntil
		)


		DataService
			.SetStarterPackGoldenPending(
				player,
				oldPending
			)


		DataService
			.SetStarterPackRewardGranted(
				player,
				false
			)


		grantLocks[
			player
		] = nil


		warn(
			`[StarterPack] Could not save Starter Pack grant for {player.Name}.`
		)


		return false
	end


	grantLocks[
		player
	] = nil


	--==================================================
	-- UPDATE CLIENT
	--==================================================

	starterPackUpdated:
		FireClient(
			player
		)


	startGoldenWorker(
		player
	)


	print(
		`[StarterPack] Granted Starter Pack to {player.Name}.`
	)


	return true
end


--==================================================
-- GET STATE
--==================================================

getStarterPackState.OnServerInvoke =
	function(
		player: Player
	)

		local profile =
			DataService.WaitForProfile(
				player,
				15
			)


		if not profile then

			return {
				Loaded = false,
			}
		end


		local tutorialCompleted =
			DataService
				.GetTutorialCompleted(
					player
				)


		local secondsRemaining =
			getSecondsRemaining(
				player
			)


		local rewardGranted =
			DataService
				.GetStarterPackRewardGranted(
					player
				)


		local owned =
			ownsStarterPack(
				player
			)


		-- If Roblox says the player owns the pass,
		-- make sure the rewards are delivered even
		-- if they disconnected during the purchase.
		if owned
			and not rewardGranted then

			task.spawn(
				grantStarterPack,
				player
			)
		end


		return {
			Loaded = true,

			TutorialCompleted =
				tutorialCompleted,

			SecondsRemaining =
				secondsRemaining,

			RewardGranted =
				rewardGranted,

			Owned =
				owned,

			Visible =
				tutorialCompleted
				and secondsRemaining > 0
				and not rewardGranted
				and not owned,
		}
	end


--==================================================
-- PURCHASE COMPLETED
--==================================================

MarketplaceService
	.PromptGamePassPurchaseFinished:
	Connect(
		function(
			player: Player,
			gamePassId: number,
			wasPurchased: boolean
		)

			if gamePassId
				~= config.Id then

				return
			end


			if not wasPurchased then
				return
			end


			-- Never deny the reward after Roblox has
			-- accepted payment, even if the timer happens
			-- to reach zero while the purchase prompt is open.
			task.spawn(
				grantStarterPack,
				player
			)
		end
	)


--==================================================
-- PLAYER SETUP
--==================================================

local function setupPlayer(
	player: Player
)

	local profile =
		DataService.WaitForProfile(
			player,
			15
		)


	if not profile then
		return
	end


	-- Start the timer immediately for anyone whose
	-- tutorial was already completed before joining.
	if DataService.GetTutorialCompleted(
		player
	) then

		ensureTimerStarted(
			player
		)
	end


	-- Existing ownership is also checked on join.
	if ownsStarterPack(
		player
	)
		and not DataService
			.GetStarterPackRewardGranted(
				player
			) then

		grantStarterPack(
			player
		)
	end


	if DataService
		.GetStarterPackGoldenPending(
			player
		) > 0 then

		startGoldenWorker(
			player
		)
	end


	-- TutorialManager sets this attribute when the
	-- tutorial is loaded/completed.
	player:GetAttributeChangedSignal(
		"TutorialCompleted"
	):Connect(
		function()

			if player:GetAttribute(
				"TutorialCompleted"
			) ~= true then

				return
			end


			ensureTimerStarted(
				player
			)


			starterPackUpdated:
				FireClient(
					player
				)
		end
	)
end


Players.PlayerAdded:Connect(
	function(
		player: Player
	)

		task.spawn(
			setupPlayer,
			player
		)
	end
)


for _, player in
	Players:GetPlayers()
do

	task.spawn(
		setupPlayer,
		player
	)
end


--==================================================
-- CLEANUP
--==================================================

Players.PlayerRemoving:Connect(
	function(
		player: Player
	)

		grantLocks[
			player
		] = nil


		goldenWorkers[
			player
		] = nil
	end
)