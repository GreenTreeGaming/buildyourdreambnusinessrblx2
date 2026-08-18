local Players =
	game:GetService("Players")

local ReplicatedStorage =
	game:GetService("ReplicatedStorage")

local Workspace =
	game:GetService("Workspace")


local BusinessConfig =
	require(
		ReplicatedStorage
			:WaitForChild("Shared")
			:WaitForChild("BusinessConfig")
	)

local DataService =
	require(
		script.Parent
			:WaitForChild("Services")
			:WaitForChild("DataService")
	)


local remotes =
	ReplicatedStorage:WaitForChild("Remotes")


local getReputationStateRemote =
	remotes:FindFirstChild("GetReputationState")

if not getReputationStateRemote then
	getReputationStateRemote =
		Instance.new("RemoteFunction")

	getReputationStateRemote.Name =
		"GetReputationState"

	getReputationStateRemote.Parent =
		remotes
end


local plotsFolder =
	Workspace:WaitForChild("Plots")


local MAX_REPUTATION_LEVEL = 50

local SALES_PER_LEVEL = 25

local MINIMUM_RATING = 3

local MAXIMUM_RATING = 5

local MAX_CUSTOMER_RATE_BONUS = 0.15


type ReputationState = {
	Success: boolean,
	Message: string?,

	Rating: number,
	ReputationLevel: number,

	CurrentProgress: number,
	RequiredProgress: number,

	CustomerRateBonus: number,

	RecentReview: string,

	NextUnlockTitle: string,
	NextUnlockSubtitle: string,

	ServiceScore: number,
	QualityScore: number,
	QueueScore: number,
	AppearanceScore: number,
}


local POSITIVE_REVIEWS = {
	"Great service! I'll definitely come back!",
	"This place is awesome!",
	"I love this business!",
	"Really good service!",
	"That was worth the wait!",
	"The lemonade was amazing!",
	"I had a great experience!",
	"This place keeps getting better!",
}


local AVERAGE_REVIEWS = {
	"Pretty good, but it could be better.",
	"The service was okay.",
	"Not bad at all.",
	"I'd probably come back.",
	"The lemonade was pretty good.",
	"Good experience overall.",
}


local NEGATIVE_REVIEWS = {
	"The line took way too long.",
	"The service could be faster.",
	"I expected a little more.",
	"This place needs some upgrades.",
	"The wait wasn't worth it.",
}


local randomGenerator =
	Random.new()


local function clampLevel(
	value: any
): number

	if typeof(value) ~= "number" then
		return 0
	end


	return math.max(
		0,
		math.floor(value)
	)
end


local function getMaximumUpgradeLevel(
	businessConfig: {[any]: any},
	upgradeName: string
): number

	local upgrades =
		businessConfig.Upgrades

	if type(upgrades) ~= "table" then
		return 0
	end


	local upgrade =
		upgrades[upgradeName]

	if type(upgrade) ~= "table"
		or type(upgrade.Levels) ~= "table" then

		return 0
	end


	local maximumLevel = 0


	for _, definition in upgrade.Levels do
		if typeof(definition.Level) == "number" then
			maximumLevel =
				math.max(
					maximumLevel,
					math.floor(definition.Level)
				)
		end
	end


	return maximumLevel
end


local function normalizeLevel(
	currentLevel: number,
	maximumLevel: number
): number

	if maximumLevel <= 0 then
		return 0
	end


	return math.clamp(
		currentLevel / maximumLevel,
		0,
		1
	)
end


local function getAppearanceScore(
	stand: Model,
	businessConfig: {[any]: any}
): number

	local standLevels =
		businessConfig.StandLevels

	if type(standLevels) ~= "table" then
		return 0
	end


	local maximumLevel = 1


	for level in standLevels do
		if typeof(level) == "number" then
			maximumLevel =
				math.max(
					maximumLevel,
					math.floor(level)
				)
		end
	end


	local currentLevel =
		stand:GetAttribute("Level")


	if typeof(currentLevel) ~= "number" then
		currentLevel = 1
	end


	if maximumLevel <= 1 then
		return 1
	end


	return math.clamp(
		(currentLevel - 1)
			/ (maximumLevel - 1),

		0,
		1
	)
end


local function getBusinessType(
	stand: Model
): string

	local businessType =
		stand:GetAttribute(
			"BusinessType"
		)


	if typeof(businessType) == "string"
		and businessType ~= "" then

		return businessType
	end


	if string.match(
		stand.Name,
		"^LemonadeStand"
	) then

		return "LemonadeStand"
	end


	return stand.Name
end


local function getReview(
	rating: number
): string

	local reviews


	if rating >= 4.25 then
		reviews =
			POSITIVE_REVIEWS

	elseif rating >= 3.5 then
		reviews =
			AVERAGE_REVIEWS

	else
		reviews =
			NEGATIVE_REVIEWS
	end


	return reviews[
		randomGenerator:NextInteger(
			1,
			#reviews
		)
	]
end


local function getNextUnlock(
	rating: number
): (string, string)

	if rating < 3.5 then
		return
			"3.5 Star Reputation",
			"+4% Customer Rate"
	end


	if rating < 4 then
		return
			"4 Star Reputation",
			"+8% Customer Rate"
	end


	if rating < 4.5 then
		return
			"4.5 Star Reputation",
			"+12% Customer Rate"
	end


	if rating < 5 then
		return
			"5 Star Reputation",
			"+15% Customer Rate"
	end


	return
		"Maximum Reputation",
		"Best Customer Attraction"
end


local function calculateCustomerBonus(
	rating: number
): number

	local progress =
		math.clamp(
			(rating - MINIMUM_RATING)
				/ (
					MAXIMUM_RATING
					- MINIMUM_RATING
				),

			0,
			1
		)


	return progress
		* MAX_CUSTOMER_RATE_BONUS
end


local function calculatePlotReputation(
	plot: Model
): ReputationState

	local placedBusinesses =
		plot:FindFirstChild(
			"PlacedBusinesses"
		)


	if not placedBusinesses then
		return {
			Success = true,

			Rating = MINIMUM_RATING,
			ReputationLevel = 1,

			CurrentProgress = 0,
			RequiredProgress = SALES_PER_LEVEL,

			CustomerRateBonus = 0,

			RecentReview =
				"Open a business to start earning reviews!",

			NextUnlockTitle =
				"3.5 Star Reputation",

			NextUnlockSubtitle =
				"+4% Customer Rate",

			ServiceScore = 0,
			QualityScore = 0,
			QueueScore = 0,
			AppearanceScore = 0,
		}
	end


	local businessCount = 0

	local totalServiceScore = 0
	local totalQualityScore = 0
	local totalQueueScore = 0
	local totalAppearanceScore = 0

	local totalSales = 0


	for _, stand in
		placedBusinesses:GetChildren() do

		if not stand:IsA("Model") then
			continue
		end


		local businessType =
			getBusinessType(
				stand
			)


		local config =
			BusinessConfig[
				businessType
			]


		if type(config) ~= "table" then
			continue
		end


		businessCount += 1


		local servingLevel =
			clampLevel(
				stand:GetAttribute(
					"ServingSpeedLevel"
				)
			)


		local saleValueLevel =
			clampLevel(
				stand:GetAttribute(
					"SaleValueLevel"
				)
			)


		local queueLevel =
			clampLevel(
				stand:GetAttribute(
					"QueueCapacityLevel"
				)
			)


		local maximumServingLevel =
			getMaximumUpgradeLevel(
				config,
				"ServingSpeed"
			)


		local maximumSaleValueLevel =
			getMaximumUpgradeLevel(
				config,
				"SaleValue"
			)


		local maximumQueueLevel =
			getMaximumUpgradeLevel(
				config,
				"QueueCapacity"
			)


		totalServiceScore +=
			normalizeLevel(
				servingLevel,
				maximumServingLevel
			)


		totalQualityScore +=
			normalizeLevel(
				saleValueLevel,
				maximumSaleValueLevel
			)


		totalQueueScore +=
			normalizeLevel(
				queueLevel,
				maximumQueueLevel
			)


		totalAppearanceScore +=
			getAppearanceScore(
				stand,
				config
			)


		local standSales =
			stand:GetAttribute(
				"TotalSales"
			)


		if typeof(standSales) == "number" then
			totalSales +=
				math.max(
					0,
					math.floor(standSales)
				)
		end
	end


	if businessCount <= 0 then
		return {
			Success = true,

			Rating = MINIMUM_RATING,
			ReputationLevel = 1,

			CurrentProgress = 0,
			RequiredProgress = SALES_PER_LEVEL,

			CustomerRateBonus = 0,

			RecentReview =
				"Open a business to start earning reviews!",

			NextUnlockTitle =
				"3.5 Star Reputation",

			NextUnlockSubtitle =
				"+4% Customer Rate",

			ServiceScore = 0,
			QualityScore = 0,
			QueueScore = 0,
			AppearanceScore = 0,
		}
	end

		local ownerUserId =
		plot:GetAttribute(
			"OwnerUserId"
		)

	if typeof(ownerUserId)
		== "number" then

		local player =
			Players:GetPlayerByUserId(
				ownerUserId
			)

		if player then
			totalSales +=
				DataService.GetReputationBonusSales(
					player
				)
		end
	end


	local serviceScore =
		totalServiceScore
		/ businessCount


	local qualityScore =
		totalQualityScore
		/ businessCount


	local queueScore =
		totalQueueScore
		/ businessCount


	local appearanceScore =
		totalAppearanceScore
		/ businessCount


	-- The weighting intentionally makes product quality
	-- and service speed the most important factors.
	local combinedScore =
		serviceScore * 0.30
		+ qualityScore * 0.30
		+ queueScore * 0.15
		+ appearanceScore * 0.25


	-- A brand-new functioning business starts around
	-- 3 stars rather than feeling "bad" immediately.
	local rating =
		MINIMUM_RATING
		+ combinedScore
			* (
				MAXIMUM_RATING
				- MINIMUM_RATING
			)


	rating =
		math.clamp(
			rating,
			MINIMUM_RATING,
			MAXIMUM_RATING
		)


	-- Display ratings in 0.1 increments.
	rating =
		math.round(
			rating * 10
		) / 10


	local reputationLevel =
		math.clamp(
			math.floor(
				totalSales
					/ SALES_PER_LEVEL
			) + 1,

			1,
			MAX_REPUTATION_LEVEL
		)


	local currentProgress

	if reputationLevel
		>= MAX_REPUTATION_LEVEL then

		currentProgress =
			SALES_PER_LEVEL
	else
		currentProgress =
			totalSales
				% SALES_PER_LEVEL
	end


	local customerBonus =
		calculateCustomerBonus(
			rating
		)


	local nextUnlockTitle,
		nextUnlockSubtitle =
		getNextUnlock(
			rating
		)


	return {
		Success = true,

		Rating = rating,

		ReputationLevel =
			reputationLevel,

		CurrentProgress =
			currentProgress,

		RequiredProgress =
			SALES_PER_LEVEL,

		CustomerRateBonus =
			customerBonus,

		RecentReview =
			getReview(
				rating
			),

		NextUnlockTitle =
			nextUnlockTitle,

		NextUnlockSubtitle =
			nextUnlockSubtitle,

		ServiceScore =
			serviceScore,

		QualityScore =
			qualityScore,

		QueueScore =
			queueScore,

		AppearanceScore =
			appearanceScore,
	}
end


local function getPlayerPlot(
	player: Player
): Model?

	for _, plot in
		plotsFolder:GetChildren() do

		if plot:IsA("Model")
			and plot:GetAttribute(
				"OwnerUserId"
			) == player.UserId then

			return plot
		end
	end


	return nil
end


local function updatePlotReputation(
	plot: Model
)

	local state =
		calculatePlotReputation(
			plot
		)


	local multiplier =
		1
		+ state.CustomerRateBonus


	plot:SetAttribute(
		"ReputationRating",
		state.Rating
	)


	plot:SetAttribute(
		"ReputationLevel",
		state.ReputationLevel
	)


	plot:SetAttribute(
		"ReputationCustomerRateMultiplier",
		multiplier
	)
end


getReputationStateRemote.OnServerInvoke =
	function(
		player: Player
	)

		local plot =
			getPlayerPlot(
				player
			)


		if not plot then
			return {
				Success = false,
				Message =
					"Your plot could not be found.",
			}
		end


		updatePlotReputation(
			plot
		)


		return calculatePlotReputation(
			plot
		)
	end


-- Reputation is derived from actual stand state,
-- so refresh it periodically. This also means upgrades
-- immediately affect customer attraction even if the
-- player never opens the Reputation menu.
task.spawn(
	function()

		while true do

			for _, plot in
				plotsFolder:GetChildren() do

				if plot:IsA("Model")
					and typeof(
						plot:GetAttribute(
							"OwnerUserId"
						)
					) == "number" then

					updatePlotReputation(
						plot
					)
				end
			end


			task.wait(2)
		end
	end
)


Players.PlayerRemoving:Connect(
	function(_player)
		-- Nothing is stored separately here.
		-- Reputation is calculated from saved
		-- business upgrades and sales.
	end
)