local RobloxAnalyticsService =
	game:GetService("AnalyticsService")

local Players =
	game:GetService("Players")

local HttpService =
	game:GetService("HttpService")


local AnalyticsTracker = {}

local activeFunnelSessions: {
	[Player]: {
		[string]: string,
	},
} = {}


--==================================================
-- ONBOARDING
--==================================================

AnalyticsTracker.Onboarding = {
	JoinedGame = 1,
	TutorialStarted = 2,
	EnteredPlacementMode = 3,
	PlacedFirstLemonadeStand = 4,
	ServedFirstCustomer = 5,
	BoughtFirstUpgrade = 6,
	TutorialCompleted = 7,
}


--==================================================
-- RUNTIME DEDUPLICATION
--==================================================

local loggedSteps: {
	[Player]: {
		[string]: {
			[number]: boolean,
		},
	},
} = {}


local clientEventTimes: {
	[Player]: {
		[string]: number,
	},
} = {}


local CLIENT_EVENT_COOLDOWN =
	0.2


local function getPlayerCache(
	player: Player
)
	local cache =
		loggedSteps[player]

	if cache then
		return cache
	end


	cache = {}

	loggedSteps[player] =
		cache


	return cache
end


local function hasLogged(
	player: Player,
	category: string,
	step: number
): boolean

	local cache =
		getPlayerCache(
			player
		)


	local categoryCache =
		cache[
			category
		]


	if not categoryCache then
		return false
	end


	return categoryCache[
		step
	] == true
end


local function markLogged(
	player: Player,
	category: string,
	step: number
)

	local cache =
		getPlayerCache(
			player
		)


	if not cache[
		category
	] then

		cache[
			category
		] = {}
	end


	cache[
		category
	][step] =
		true
end


--==================================================
-- SAFE ANALYTICS CALL
--==================================================

local function safeCall(
	callback: () -> ()
): boolean

	local success,
		errorMessage =
		pcall(
			callback
		)


	if not success then

		warn(
			"[AnalyticsTracker] Analytics event failed:",
			errorMessage
		)


		return false
	end


	return true
end


--==================================================
-- CUSTOM FIELDS
--==================================================

function AnalyticsTracker.MakeFields(
	first: any?,
	second: any?,
	third: any?
): {[string]: string}

	local fields: {
		[string]: string
	} = {}


	if first ~= nil then

		fields[
			Enum.AnalyticsCustomFieldKeys
				.CustomField01.Name
		] =
			tostring(
				first
			)
	end


	if second ~= nil then

		fields[
			Enum.AnalyticsCustomFieldKeys
				.CustomField02.Name
		] =
			tostring(
				second
			)
	end


	if third ~= nil then

		fields[
			Enum.AnalyticsCustomFieldKeys
				.CustomField03.Name
		] =
			tostring(
				third
			)
	end


	return fields
end


--==================================================
-- FUNNEL SESSIONS
--==================================================

local function getPersistentSessionId(
	player: Player,
	funnelName: string
): string

	return `{player.UserId}:{funnelName}`
end


function AnalyticsTracker.StartFunnelSession(
	player: Player,
	funnelName: string
): string

	local playerSessions =
		activeFunnelSessions[player]

	if not playerSessions then

		playerSessions = {}

		activeFunnelSessions[player] =
			playerSessions
	end


	local sessionId =
		HttpService:GenerateGUID(false)


	playerSessions[funnelName] =
		sessionId


	return sessionId
end


function AnalyticsTracker.GetActiveFunnelSession(
	player: Player,
	funnelName: string
): string?

	local playerSessions =
		activeFunnelSessions[player]

	if not playerSessions then
		return nil
	end


	return playerSessions[funnelName]
end


function AnalyticsTracker.EndFunnelSession(
	player: Player,
	funnelName: string
)

	local playerSessions =
		activeFunnelSessions[player]

	if not playerSessions then
		return
	end


	playerSessions[funnelName] =
		nil
end


--==================================================
-- ONBOARDING
--==================================================

function AnalyticsTracker.LogOnboarding(
	player: Player,
	step: number,
	stepName: string,
	customFields: {[string]: string}?
)

	if not player.Parent then
		return
	end


	if hasLogged(
		player,
		"Onboarding",
		step
	) then

		return
	end


	local success =
		safeCall(
			function()

				RobloxAnalyticsService:
					LogOnboardingFunnelStepEvent(
						player,
						step,
						stepName,
						customFields or {}
					)
			end
		)


	if success then

		markLogged(
			player,
			"Onboarding",
			step
		)
	end
end


--==================================================
-- STANDARD FUNNEL
--==================================================

function AnalyticsTracker.LogFunnel(
	player: Player,
	funnelName: string,
	step: number,
	stepName: string,
	customFields: {[string]: string}?,
	sessionId: string?
)

	if not player.Parent then
		return
	end


	local resolvedSessionId =
		sessionId
		or getPersistentSessionId(
			player,
			funnelName
		)


	--
	-- Deduplicate lifetime funnels, but do NOT
	-- deduplicate recurring session-based funnels.
	--
	local category =
		`Funnel:{funnelName}:{resolvedSessionId}`


	if hasLogged(
		player,
		category,
		step
	) then

		return
	end


	local success =
		safeCall(
			function()

				RobloxAnalyticsService:
					LogFunnelStepEvent(
						player,
						funnelName,
						resolvedSessionId,
						step,
						stepName,
						customFields or {}
					)
			end
		)


	if success then

		markLogged(
			player,
			category,
			step
		)
	end
end


--==================================================
-- PROGRESSION
--==================================================

function AnalyticsTracker.LogProgression(
	player: Player,
	pathName: string,
	level: number,
	levelName: string,
	customFields: {[string]: string}?
)

	if not player.Parent then
		return
	end


	if hasLogged(
		player,
		`Progression:{pathName}`,
		level
	) then

		return
	end


	local success =
		safeCall(
			function()

				RobloxAnalyticsService:
					LogProgressionCompleteEvent(
						player,
						pathName,
						level,
						levelName,
						customFields or {}
					)
			end
		)


	if success then

		markLogged(
			player,
			`Progression:{pathName}`,
			level
		)
	end
end


--==================================================
-- CUSTOM EVENT
--==================================================

function AnalyticsTracker.LogCustom(
	player: Player,
	eventName: string,
	value: number?,
	customFields: {[string]: string}?
)

	if not player.Parent then
		return
	end


	safeCall(
		function()

			RobloxAnalyticsService:
				LogCustomEvent(
					player,
					eventName,
					value or 1,
					customFields or {}
				)
		end
	)
end


--==================================================
-- CLIENT EVENT RATE LIMIT
--==================================================

function AnalyticsTracker.CanAcceptClientEvent(
	player: Player,
	eventName: string
): boolean

	local now =
		time()


	local playerEvents =
		clientEventTimes[
			player
		]


	if not playerEvents then

		playerEvents = {}

		clientEventTimes[
			player
		] =
			playerEvents
	end


	local lastTime =
		playerEvents[
			eventName
		]


	if lastTime
		and now - lastTime
			< CLIENT_EVENT_COOLDOWN then

		return false
	end


	playerEvents[
		eventName
	] =
		now


	return true
end


--==================================================
-- CLEANUP
--==================================================

Players.PlayerRemoving:Connect(
	function(
		player: Player
	)

		loggedSteps[
			player
		] = nil


		clientEventTimes[
			player
		] = nil


		activeFunnelSessions[
			player
		] = nil
	end
)

return AnalyticsTracker