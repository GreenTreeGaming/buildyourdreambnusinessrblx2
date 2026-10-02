local Players =
	game:GetService("Players")

local ReplicatedStorage =
	game:GetService("ReplicatedStorage")


local Shared =
	ReplicatedStorage:WaitForChild(
		"Shared"
	)

local DailyRewardConfig =
	require(
		Shared:WaitForChild(
			"DailyRewardConfig"
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


--==================================================
-- REMOTES
--==================================================

local remotes =
	ReplicatedStorage:FindFirstChild(
		"Remotes"
	)

if not remotes then
	remotes =
		Instance.new("Folder")

	remotes.Name =
		"Remotes"

	remotes.Parent =
		ReplicatedStorage
end


local function getOrCreateRemoteFunction(
	name: string
): RemoteFunction
	local existing =
		remotes:FindFirstChild(name)

	if existing then
		assert(
			existing:IsA(
				"RemoteFunction"
			),
			`ReplicatedStorage.Remotes.{name} must be a RemoteFunction.`
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


local getStateRemote =
	getOrCreateRemoteFunction(
		"GetDailyRewardState"
	)

local claimRemote =
	getOrCreateRemoteFunction(
		"ClaimDailyReward"
	)


--==================================================
-- CONSTANTS
--==================================================

local CLAIM_COOLDOWN =
	24 * 60 * 60

-- Prevent two simultaneous RemoteFunction calls
-- from claiming the same reward.
local claimingPlayers: {
	[Player]: boolean
} = {}


--==================================================
-- HELPERS
--==================================================


local function getReward(
	day: number
)
	return DailyRewardConfig.Rewards[
		day
	]
end

local function createClientReward(
	day: number
)
	local reward =
		getReward(day)

	if not reward then
		return nil
	end

	local clientReward = {
		Day = day,
		Name = reward.Name,
		Cash = reward.Cash or 0,
	}

	if reward.Boost then
		clientReward.Boost = {
			Name =
				reward.Boost.Name,

			DisplayName =
				reward.Boost.DisplayName,

			Duration =
				reward.Boost.Duration,
		}
	end

	return clientReward
end


local function getState(
	player: Player
)
	local dailyData =
		DataService.GetDailyRewardData(
			player
		)

	if not dailyData then
		return {
			Loaded = false,
			CanClaim = false,
		}
	end

	local now =
		os.time()

	local claimable =
		now >= dailyData.NextClaimAt

	local secondsRemaining =
		math.max(
			0,
			dailyData.NextClaimAt - now
		)

	local completedCycleToday =
		not claimable
			and dailyData.LastClaimRewardDay
				== 7

	local rewards = {}

	for day = 1, 7 do
		rewards[day] =
			createClientReward(day)
	end

	return {
		Loaded = true,

		CanClaim =
			claimable,

		NextDay =
			dailyData.NextDay,

		LastClaimRewardDay =
			dailyData.LastClaimRewardDay,

		CompletedCycleToday =
			completedCycleToday,

		SecondsUntilNextClaim =
			secondsRemaining,

		Rewards =
			rewards,
	}
end

local function addBoost(
	player: Player,
	boostName: string,
	duration: number
): boolean
	if type(boostName) ~= "string"
		or boostName == "" then

		return false
	end

	if typeof(duration) ~= "number"
		or duration <= 0 then

		return false
	end

	duration =
		math.floor(duration)

	local now =
		os.time()

	local currentExpiresAt =
		DataService.GetBoostUntil(
			player,
			boostName
		)

	-- Stack onto any remaining boost instead
	-- of overwriting it.
	local startingTimestamp =
		math.max(
			now,
			currentExpiresAt
		)

	local newExpiresAt =
		startingTimestamp
			+ duration

	local success =
		DataService.SetBoostUntil(
			player,
			boostName,
			newExpiresAt
		)

	if not success then
		return false
	end

	-- Your existing boost UI/gameplay reads these
	-- attributes.
	player:SetAttribute(
		`{boostName}Until`,
		newExpiresAt
	)

	return true
end


local function grantReward(
	player: Player,
	reward
): boolean
	local cash =
		reward.Cash or 0

	if cash > 0 then
		local addedCash =
			DataService.AddCash(
				player,
				cash
			)

		if not addedCash then
			return false
		end
	end

	if reward.Boost then
		local boostSuccess =
			addBoost(
				player,
				reward.Boost.Name,
				reward.Boost.Duration
			)

		if not boostSuccess then
			return false
		end
	end

	return true
end


--==================================================
-- STATE REQUEST
--==================================================

getStateRemote.OnServerInvoke =
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
				CanClaim = false,
			}
		end

		return getState(player)
	end


--==================================================
-- CLAIM
--==================================================

claimRemote.OnServerInvoke =
	function(
		player: Player
	)
		if claimingPlayers[player] then
			return {
				Success = false,
				Message =
					"Your reward is already being claimed.",

				State =
					getState(player),
			}
		end

		claimingPlayers[player] =
			true

		local function finish(
			result
		)
			claimingPlayers[player] =
				nil

			return result
		end


		local profile =
			DataService.WaitForProfile(
				player,
				15
			)

		if not profile then
			return finish({
				Success = false,

				Message =
					"Your data has not finished loading.",

				State =
					getState(player),
			})
		end


		local dailyData =
			DataService.GetDailyRewardData(
				player
			)

		if not dailyData then
			return finish({
				Success = false,

				Message =
					"Daily reward data is unavailable.",

				State =
					getState(player),
			})
		end


		local now =
			os.time()
		
		if now
			< dailyData.NextClaimAt then
		
			return finish({
				Success = false,
		
				Message =
					"Your next daily reward is not ready yet.",
		
				State =
					getState(player),
			})
		end


		local rewardDay =
			dailyData.NextDay

		local reward =
			getReward(
				rewardDay
			)

		if not reward then
			return finish({
				Success = false,

				Message =
					"That daily reward does not exist.",

				State =
					getState(player),
			})
		end


		-- Grant the actual reward first.
		local granted =
			grantReward(
				player,
				reward
			)

		if not granted then
			return finish({
				Success = false,

				Message =
					"Your reward could not be granted.",

				State =
					getState(player),
			})
		end


		local nextRewardDay =
			rewardDay + 1

		if nextRewardDay > 7 then
			nextRewardDay = 1
		end

		local nextClaimAt =
			os.time()
				+ CLAIM_COOLDOWN


		local updated =
			DataService.SetDailyRewardData(
				player,
				nextRewardDay,
				nextClaimAt,
				rewardDay
			)

		if not updated then
			warn(
				`Failed to update daily reward data for {player.Name}.`
			)

			return finish({
				Success = false,

				Message =
					"Your daily reward data could not be updated.",

				State =
					getState(player),
			})
		end


		-- Daily rewards are valuable enough that
		-- we immediately save after a successful claim.
		task.spawn(
			function()
				if player.Parent then
					local saved =
						DataService.SavePlayer(
							player
						)

					if not saved then
						warn(
							`Failed to immediately save daily reward claim for {player.Name}.`
						)
					end
				end
			end
		)


		return finish({
			Success = true,

			ClaimedDay =
				rewardDay,

			Reward =
				createClientReward(
					rewardDay
				),

			State =
				getState(player),
		})
	end


Players.PlayerRemoving:Connect(
	function(player: Player)
		claimingPlayers[player] =
			nil
	end
)