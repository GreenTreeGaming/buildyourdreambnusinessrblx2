local Players =
	game:GetService("Players")

local ReplicatedStorage =
	game:GetService("ReplicatedStorage")


local player =
	Players.LocalPlayer

local playerGui =
	player:WaitForChild("PlayerGui")


local remotes =
	ReplicatedStorage:WaitForChild(
		"Remotes"
	)


local Notification =
	require(
		ReplicatedStorage
			:WaitForChild("Shared")
			:WaitForChild("Notification")
	)


local getMarketingStateRemote =
	remotes:WaitForChild(
		"GetMarketingState"
	) :: RemoteFunction


local getPlotStateRemote =
	remotes:WaitForChild(
		"GetPlotExpansionState"
	) :: RemoteFunction

local MARKETING_NOTIFICATION_DURATION =
	5

local PLOT_NOTIFICATION_DURATION =
	5.5

--==================================================
-- UI
--==================================================

local manageGui =
	playerGui:WaitForChild(
		"ManageUI"
	) :: ScreenGui


local openButton =
	manageGui:WaitForChild(
		"OpenButton"
	) :: TextButton


local openUpdate =
	openButton:WaitForChild(
		"Update"
	) :: Frame


local main =
	manageGui:WaitForChild(
		"Main"
	) :: Frame


local marketingButton =
	main:WaitForChild(
		"MarketingButton"
	) :: TextButton


local marketingUpdate =
	marketingButton:WaitForChild(
		"Update"
	) :: Frame


local plotButton =
	main:WaitForChild(
		"PlotButton"
	) :: TextButton


local plotUpdate =
	plotButton:WaitForChild(
		"Update"
	) :: Frame


--==================================================
-- CASH
--==================================================

local leaderstats =
	player:WaitForChild(
		"leaderstats"
	)


local cash =
	leaderstats:WaitForChild(
		"Cash"
	) :: IntValue


--==================================================
-- TYPES
--==================================================

type UpgradeState = {
	Success: boolean?,
	CurrentLevel: number?,
	MaximumLevel: number?,
	NextCost: number?,
}


type IndicatorState = {
	Affordable: boolean,

	-- The level that was affordable when this
	-- indicator became active.
	LevelKey: number?,

	-- The player already opened this particular
	-- upgrade level and saw it.
	SeenLevelKey: number?,
}


--==================================================
-- STATE
--==================================================

local marketingIndicator: IndicatorState = {
	Affordable = false,
	LevelKey = nil,
	SeenLevelKey = nil,
}


local plotIndicator: IndicatorState = {
	Affordable = false,
	LevelKey = nil,
	SeenLevelKey = nil,
}


local refreshQueued =
	false


local refreshing =
	false


local initialized =
	false


--==================================================
-- HELPERS
--==================================================

local function safeInvoke(
	remote: RemoteFunction
): UpgradeState?

	local success, result =
		pcall(function()
			return remote:InvokeServer()
		end)


	if not success then

		warn(
			"Could not get upgrade notification state:",
			result
		)

		return nil
	end


	if typeof(result)
		~= "table" then

		return nil
	end


	return result :: UpgradeState
end


local function isMaxLevel(
	state: UpgradeState
): boolean

	local currentLevel =
		state.CurrentLevel

	local maximumLevel =
		state.MaximumLevel


	if typeof(currentLevel)
			~= "number"
		or typeof(maximumLevel)
			~= "number" then

		return false
	end


	return currentLevel
		>= maximumLevel
end


local function getAffordableState(
	state: UpgradeState?
): (boolean, number?)

	if not state
		or state.Success
			~= true then

		return false, nil
	end


	if isMaxLevel(state) then
		return false, nil
	end


	local nextCost =
		state.NextCost


	if typeof(nextCost)
			~= "number"
		or nextCost <= 0 then

		return false, nil
	end


	local currentLevel =
		state.CurrentLevel


	if typeof(currentLevel)
		~= "number" then

		currentLevel = 0
	end


	local affordable =
		cash.Value
			>= nextCost


	return affordable,
		math.floor(currentLevel)
end


local function isUnseenAffordable(
	indicator: IndicatorState
): boolean

	return indicator.Affordable
		and indicator.LevelKey ~= nil
		and indicator.SeenLevelKey
			~= indicator.LevelKey
end


local function updateBadges()

	local marketingUnseen =
		isUnseenAffordable(
			marketingIndicator
		)


	local plotUnseen =
		isUnseenAffordable(
			plotIndicator
		)


	marketingUpdate.Visible =
		marketingUnseen


	plotUpdate.Visible =
		plotUnseen


	-- Main Manage button remains marked while at least
	-- one individual affordable upgrade has not been seen.
	openUpdate.Visible =
		marketingUnseen
		or plotUnseen
end


local function showMarketingNotification()

	Notification.Info(
		"You can now afford your next Marketing upgrade!",

		{
			Title =
				"Marketing Upgrade Available",

			Duration =
				MARKETING_NOTIFICATION_DURATION,
		}
	)
end


local function showPlotNotification()

	Notification.Info(
		"You can now afford to expand your plot!",

		{
			Title =
				"Plot Expansion Available",

			Duration =
				PLOT_NOTIFICATION_DURATION,
		}
	)
end

--==================================================
-- INDICATOR UPDATE
--==================================================

local function applyIndicatorState(
	indicator: IndicatorState,
	affordable: boolean,
	levelKey: number?,
	notificationCallback: (() -> ())?
)

	local wasAffordable =
		indicator.Affordable


	local oldLevelKey =
		indicator.LevelKey


	indicator.Affordable =
		affordable


	indicator.LevelKey =
		levelKey


	-- A new level means this is a completely new
	-- upgrade opportunity.
	local enteredNewLevel =
		affordable
		and levelKey ~= nil
		and oldLevelKey
			~= levelKey


	-- They dropped below the price and later earned
	-- enough again for the SAME level.
	--
	-- Do NOT notify again if they already saw it.
	local crossedAffordabilityThreshold =
		affordable
		and not wasAffordable
		and indicator.SeenLevelKey
			~= levelKey


	local shouldNotify =
		initialized
		and (
			enteredNewLevel
			or crossedAffordabilityThreshold
		)
		and indicator.SeenLevelKey
			~= levelKey


	if shouldNotify
		and notificationCallback then

		notificationCallback()
	end
end


--==================================================
-- REFRESH
--==================================================

local function refresh()

	if refreshing then
		refreshQueued =
			true

		return
	end


	refreshing =
		true


	local marketingState =
		safeInvoke(
			getMarketingStateRemote
		)


	local plotState =
		safeInvoke(
			getPlotStateRemote
		)


	local marketingAffordable,
		marketingLevel =
		getAffordableState(
			marketingState
		)


	local plotAffordable,
		plotLevel =
		getAffordableState(
			plotState
		)


	applyIndicatorState(
		marketingIndicator,
		marketingAffordable,
		marketingLevel,
		showMarketingNotification
	)


	applyIndicatorState(
		plotIndicator,
		plotAffordable,
		plotLevel,
		showPlotNotification
	)


	updateBadges()


	initialized =
		true


	refreshing =
		false


	if refreshQueued then

		refreshQueued =
			false

		task.defer(
			refresh
		)
	end
end


local function queueRefresh()

	if refreshQueued then
		return
	end


	refreshQueued =
		true


	task.delay(
		0.15,

		function()

			if not refreshQueued then
				return
			end


			refreshQueued =
				false


			refresh()
		end
	)
end


--==================================================
-- MARK AS SEEN
--==================================================

local function markMarketingSeen()

	if marketingIndicator.Affordable
		and marketingIndicator.LevelKey
			~= nil then

		marketingIndicator.SeenLevelKey =
			marketingIndicator.LevelKey
	end


	updateBadges()
end


local function markPlotSeen()

	if plotIndicator.Affordable
		and plotIndicator.LevelKey
			~= nil then

		plotIndicator.SeenLevelKey =
			plotIndicator.LevelKey
	end


	updateBadges()
end


--==================================================
-- BUTTONS
--==================================================

marketingButton.MouseButton1Click:
	Connect(function()

		-- They opened the Marketing page and have now
		-- seen that the upgrade is available.
		markMarketingSeen()
	end)


plotButton.MouseButton1Click:
	Connect(function()

		-- Same behavior for Plot Expansion.
		markPlotSeen()
	end)


--==================================================
-- CASH CHANGES
--==================================================

cash:GetPropertyChangedSignal(
	"Value"
):Connect(function()

	queueRefresh()
end)


--==================================================
-- PURCHASE DETECTION
--==================================================
--
-- MarketingMenuClient already performs the actual
-- purchases.
--
-- We periodically refresh so when CurrentLevel changes,
-- this script recognizes that the next level is a new
-- opportunity.
--==================================================

task.spawn(function()

	while player.Parent do

		task.wait(1)

		queueRefresh()
	end
end)


--==================================================
-- INITIAL STATE
--==================================================

openUpdate.Visible =
	false

marketingUpdate.Visible =
	false

plotUpdate.Visible =
	false


refresh()