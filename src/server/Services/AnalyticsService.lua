local RobloxAnalyticsService =
	game:GetService("AnalyticsService")

local Players =
	game:GetService("Players")


local AnalyticsTracker = {}


--==================================================
-- ONBOARDING
--==================================================

AnalyticsTracker.Onboarding = {
	JoinedGame = 1,
	TutorialStarted = 2,
	EnteredPlacementMode = 3,
	PlacedFirstLemonadeStand = 4,
	ServedFirstCustomer = 5,
	EarnedFirstCash = 6,
	BoughtFirstUpgrade = 7,
	TutorialCompleted = 8,
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
-- FUNNEL SESSION
--==================================================

local function getPersistentSessionId(
	player: Player,
	funnelName: string
): string

	--
	-- These funnels represent first-time / lifetime
	-- progression, so the same user keeps the same
	-- session ID between joins.
	--
	return `{player.UserId}:{funnelName}`
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
	customFields: {[string]: string}?
)

	if not player.Parent then
		return
	end


	if hasLogged(
		player,
		`Funnel:{funnelName}`,
		step
	) then

		return
	end


	local sessionId =
		getPersistentSessionId(
			player,
			funnelName
		)


	local success =
		safeCall(
			function()

				RobloxAnalyticsService:
					LogFunnelStepEvent(
						player,
						funnelName,
						sessionId,
						step,
						stepName,
						customFields or {}
					)
			end
		)


	if success then

		markLogged(
			player,
			`Funnel:{funnelName}`,
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
	end
)


return AnalyticsTracker