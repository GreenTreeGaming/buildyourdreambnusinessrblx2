local ReputationConfig = {}

-- Reputation 1-10 stays fast so early-game unlocks
-- still happen at a good pace.
ReputationConfig.BaseSalesPerLevel = 25

-- Scaling begins after Reputation 10.
ReputationConfig.GrowthStartLevel = 10

-- Every reputation level after 10 requires
-- 5 more sales than the previous one.
ReputationConfig.SalesGrowthPerLevel = 5


function ReputationConfig.GetSalesRequiredForNextLevel(
	reputationLevel: number
): number

	reputationLevel =
		math.max(
			1,
			math.floor(
				tonumber(reputationLevel) or 1
			)
		)


	local levelsPastGrowthStart =
		math.max(
			0,
			reputationLevel
				- ReputationConfig.GrowthStartLevel
		)


	return
		ReputationConfig.BaseSalesPerLevel
		+ levelsPastGrowthStart
			* ReputationConfig.SalesGrowthPerLevel
end


function ReputationConfig.GetStateFromSales(
	totalSales: number
): (
	number,
	number,
	number
)

	totalSales =
		math.max(
			0,
			math.floor(
				tonumber(totalSales) or 0
			)
		)


	local reputationLevel =
		1

	local remainingSales =
		totalSales


	while true do

		local required =
			ReputationConfig
				.GetSalesRequiredForNextLevel(
					reputationLevel
				)


		if remainingSales < required then

			return
				reputationLevel,
				remainingSales,
				required
		end


		remainingSales -=
			required

		reputationLevel +=
			1
	end
end


function ReputationConfig.GetLevelFromSales(
	totalSales: number
): number

	local reputationLevel =
		ReputationConfig
			.GetStateFromSales(
				totalSales
			)


	return reputationLevel
end


return ReputationConfig