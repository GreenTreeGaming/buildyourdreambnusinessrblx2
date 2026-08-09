local Players =
	game:GetService("Players")

local ReplicatedStorage =
	game:GetService("ReplicatedStorage")

local Workspace =
	game:GetService("Workspace")


local DataService =
	require(
		script.Parent:WaitForChild(
			"DataService"
		)
	)

local QuestConfig =
	require(
		ReplicatedStorage
			:WaitForChild("Shared")
			:WaitForChild("QuestConfig")
	)


local plotsFolder =
	Workspace:WaitForChild(
		"Plots"
	)


type QuestSaveData = {
	Stats: {
		TotalSales: number,
		LifetimeEarnings: number,
	},

	Completed: {
		[string]: boolean,
	},

	Claimed: {
		[string]: boolean,
	},
}


type QuestState = {
	Id: string,

	DisplayName: string,
	Description: string,

	Progress: number,
	Required: number,

	RewardCash: number,

	Completed: boolean,
	Claimed: boolean,
}


local QuestService = {}


--==================================================
-- SANITIZATION
--==================================================

local function sanitizeNumber(
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


local function sanitizeBooleanMap(
	value: any
): {[string]: boolean}

	local result: {
		[string]: boolean
	} = {}


	if typeof(value)
		~= "table" then

		return result
	end


	for key, enabled in value do
		if typeof(key)
				== "string"
			and enabled == true then

			result[key] =
				true
		end
	end


	return result
end


--==================================================
-- PROFILE QUEST DATA
--==================================================

local function getQuestData(
	player: Player
): QuestSaveData?

	local profile =
		DataService.GetProfile(
			player
		)

	if not profile then
		return nil
	end


	local questData =
		profile.Quests


	if typeof(questData)
		~= "table" then

		questData = {
			Stats = {
				TotalSales = 0,
				LifetimeEarnings = 0,
			},

			Completed = {},
			Claimed = {},
		}

		profile.Quests =
			questData
	end


	if typeof(questData.Stats)
		~= "table" then

		questData.Stats = {}
	end


	questData.Stats.TotalSales =
		sanitizeNumber(
			questData.Stats.TotalSales
		)

	questData.Stats.LifetimeEarnings =
		sanitizeNumber(
			questData.Stats.LifetimeEarnings
		)


	questData.Completed =
		sanitizeBooleanMap(
			questData.Completed
		)

	questData.Claimed =
		sanitizeBooleanMap(
			questData.Claimed
		)


	return questData
end


--==================================================
-- EXISTING SAVE MIGRATION
--==================================================

local function getSavedBusinessTotals(
	player: Player
): (number, number)

	local profile =
		DataService.GetProfile(
			player
		)

	if not profile then
		return 0, 0
	end


	local totalSales =
		0

	local lifetimeEarnings =
		0


	local placedBusinesses =
		profile.PlacedBusinesses


	if typeof(placedBusinesses)
		~= "table" then

		return 0, 0
	end


	for _, business in
		placedBusinesses
	do
		if typeof(business)
			~= "table" then

			continue
		end


		totalSales +=
			sanitizeNumber(
				business.TotalSales
			)

		lifetimeEarnings +=
			sanitizeNumber(
				business.LifetimeEarnings
			)
	end


	return totalSales,
		lifetimeEarnings
end


function QuestService.InitializePlayer(
	player: Player
): boolean

	local questData =
		getQuestData(
			player
		)

	if not questData then
		return false
	end


	--
	-- Players who already had businesses before
	-- quests were added should not start at 0.
	--
	local existingSales,
		existingEarnings =
		getSavedBusinessTotals(
			player
		)


	questData.Stats.TotalSales =
		math.max(
			questData.Stats.TotalSales,
			existingSales
		)

	questData.Stats.LifetimeEarnings =
		math.max(
			questData.Stats.LifetimeEarnings,
			existingEarnings
		)


	return true
end


--==================================================
-- PLOT / BUSINESS HELPERS
--==================================================

local function getPlayerPlot(
	player: Player
): Model?

	local plotName =
		player:GetAttribute(
			"PlotName"
		)


	if typeof(plotName)
		== "string" then

		local plot =
			plotsFolder:FindFirstChild(
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
		plotsFolder:GetChildren()
	do
		if not plot:IsA("Model") then
			continue
		end


		if plot:GetAttribute(
			"OwnerUserId"
		) == player.UserId then

			return plot
		end
	end


	return nil
end


local function getPlacedBusinesses(
	player: Player
): {Model}

	local plot =
		getPlayerPlot(
			player
		)

	if not plot then
		return {}
	end


	local folder =
		plot:FindFirstChild(
			"PlacedBusinesses"
		)


	if not folder then
		return {}
	end


	local businesses: {Model} =
		{}


	for _, child in
		folder:GetChildren()
	do
		if child:IsA("Model") then
			table.insert(
				businesses,
				child
			)
		end
	end


	return businesses
end


local function getBusinessType(
	business: Model
): string

	local businessType =
		business:GetAttribute(
			"BusinessType"
		)


	if typeof(businessType)
			== "string"
		and businessType ~= "" then

		return businessType
	end


	if business.Name
			== "LemonadeStand"
		or string.match(
			business.Name,
			"^LemonadeStand_"
		) then

		return "LemonadeStand"
	end


	return business.Name
end


local function getBusinessCount(
	player: Player,
	businessType: string?
): number

	local amount =
		0


	for _, business in
		getPlacedBusinesses(
			player
		)
	do
		if businessType
			and getBusinessType(
				business
			) ~= businessType then

			continue
		end


		amount += 1
	end


	return amount
end


local function getMaximumUpgradeLevel(
	player: Player,
	businessType: string?,
	upgradeName: string
): number

	local maximum =
		0


	local attributeName =
		upgradeName .. "Level"


	for _, business in
		getPlacedBusinesses(
			player
		)
	do
		if businessType
			and getBusinessType(
				business
			) ~= businessType then

			continue
		end


		local level =
			business:GetAttribute(
				attributeName
			)


		if typeof(level)
			== "number" then

			maximum =
				math.max(
					maximum,
					math.floor(level)
				)
		end
	end


	return maximum
end


local function getMaximumAppearanceLevel(
	player: Player,
	businessType: string?
): number

	local maximum =
		0


	for _, business in
		getPlacedBusinesses(
			player
		)
	do
		if businessType
			and getBusinessType(
				business
			) ~= businessType then

			continue
		end


		local level =
			business:GetAttribute(
				"Level"
			)


		if typeof(level)
			== "number" then

			maximum =
				math.max(
					maximum,
					math.floor(level)
				)
		end
	end


	return maximum
end


--==================================================
-- STAT TRACKING
--==================================================

function QuestService.AddStat(
	player: Player,
	statName: string,
	amount: number
): boolean

	if typeof(statName)
			~= "string"
		or typeof(amount)
			~= "number"
		or amount <= 0 then

		return false
	end


	local questData =
		getQuestData(
			player
		)

	if not questData then
		return false
	end


	if statName
			~= "TotalSales"
		and statName
			~= "LifetimeEarnings" then

		return false
	end


	questData.Stats[
		statName
	] =
		sanitizeNumber(
			questData.Stats[
				statName
			]
		) + math.floor(amount)


	return true
end


--==================================================
-- QUEST PROGRESS
--==================================================

local function getQuestProgress(
	player: Player,
	questId: string,
	definition
): number

	local questData =
		getQuestData(
			player
		)

	if not questData then
		return 0
	end


	local questType =
		definition.Type


	if questType
		== "TotalSales" then

		return questData
			.Stats
			.TotalSales
	end


	if questType
		== "LifetimeEarnings" then

		return questData
			.Stats
			.LifetimeEarnings
	end


	if questType
		== "BusinessCount" then

		return getBusinessCount(
			player,
			definition.BusinessType
		)
	end


	if questType
		== "UpgradeLevel" then

		if typeof(
			definition.UpgradeName
		) ~= "string" then

			return 0
		end


		return getMaximumUpgradeLevel(
			player,
			definition.BusinessType,
			definition.UpgradeName
		)
	end


	if questType
		== "AppearanceLevel" then

		return getMaximumAppearanceLevel(
			player,
			definition.BusinessType
		)
	end


	warn(
		`Unknown quest type "{tostring(questType)}" for quest "{questId}".`
	)


	return 0
end


function QuestService.EvaluateCompletions(
	player: Player
): boolean

	local questData =
		getQuestData(
			player
		)

	if not questData then
		return false
	end


	local changed =
		false


	for _, questId in
		QuestConfig.Order
	do
		local definition =
			QuestConfig.Quests[
				questId
			]


		if not definition then
			continue
		end


		if questData.Completed[
			questId
		] == true then

			continue
		end


		local required =
			sanitizeNumber(
				definition.Required
			)


		local progress =
			getQuestProgress(
				player,
				questId,
				definition
			)


		if required > 0
			and progress >= required then

			questData.Completed[
				questId
			] = true

			changed =
				true
		end
	end


	return changed
end


--==================================================
-- STATE FOR CLIENT
--==================================================

function QuestService.GetState(
	player: Player
): {QuestState}

	QuestService.EvaluateCompletions(
		player
	)


	local questData =
		getQuestData(
			player
		)

	if not questData then
		return {}
	end


	local state: {QuestState} =
		{}


	for _, questId in
		QuestConfig.Order
	do
		local definition =
			QuestConfig.Quests[
				questId
			]


		if not definition then
			continue
		end


		local required =
			sanitizeNumber(
				definition.Required
			)

		local progress =
			getQuestProgress(
				player,
				questId,
				definition
			)


		local completed =
			questData.Completed[
				questId
			] == true

		local claimed =
			questData.Claimed[
				questId
			] == true


		table.insert(
			state,
			{
				Id =
					questId,

				DisplayName =
					tostring(
						definition.DisplayName
							or questId
					),

				Description =
					tostring(
						definition.Description
							or ""
					),

				Progress =
					math.max(
						0,
						progress
					),

				Required =
					required,

				RewardCash =
					sanitizeNumber(
						definition.RewardCash
					),

				Completed =
					completed,

				Claimed =
					claimed,
			}
		)
	end


	return state
end


--==================================================
-- CLAIMING
--==================================================

function QuestService.Claim(
	player: Player,
	questId: string
): (boolean, string)

	if typeof(questId)
			~= "string"
		or questId == "" then

		return false,
			"Invalid quest."
	end


	local definition =
		QuestConfig.Quests[
			questId
		]


	if not definition then
		return false,
			"That quest does not exist."
	end


	QuestService.EvaluateCompletions(
		player
	)


	local questData =
		getQuestData(
			player
		)

	if not questData then
		return false,
			"Your data has not loaded yet."
	end


	if questData.Claimed[
		questId
	] == true then

		return false,
			"You already claimed this quest."
	end


	if questData.Completed[
		questId
	] ~= true then

		return false,
			"That quest is not complete yet."
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

		return false,
			"Your cash could not be found."
	end


	local reward =
		sanitizeNumber(
			definition.RewardCash
		)


	--
	-- Mark claimed on the server before rewarding,
	-- preventing duplicate claims from spam.
	--
	questData.Claimed[
		questId
	] = true


	cash.Value +=
		reward


	return true,
		`Quest complete! +${reward}`
end


return QuestService