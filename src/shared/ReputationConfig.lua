local ReputationConfig = {}

-- Early reputation still moves quickly so the
-- first few minutes stay rewarding.
ReputationConfig.BaseSalesPerLevel = 25

-- Scaling begins at Reputation 4.
ReputationConfig.GrowthStartLevel = 4

-- Every reputation level after the growth point
-- requires 5 additional sales over the previous one.
--
-- This is intentionally slightly softer than the
-- previous +6 curve so later rebirths do not become
-- almost entirely a customer-count grind.
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