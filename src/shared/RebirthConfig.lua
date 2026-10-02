local RebirthConfig = {}


--==================================================
-- REQUIREMENTS
--==================================================

-- First rebirth:
-- Rep 15
-- K
-- Haircut Stand unlocked


RebirthConfig.RequiredBusiness =
	"HaircutStand"

RebirthConfig.RequiredBusinessDisplayName =
	"Haircut Stand"


--==================================================
-- PERMANENT BONUSES
--==================================================

-- +25% cash every rebirth.
RebirthConfig.CashBonusPerRebirth =
	0.25


-- +10% customer rate every rebirth.
RebirthConfig.CustomerRateBonusPerRebirth =
	0.10

-- Cap at +100%.
RebirthConfig.MaximumCustomerRateBonus =
	1.50


-- +5% rare-customer odds every rebirth.
RebirthConfig.RareCustomerBonusPerRebirth =
	0.05

-- Cap at +50%.
RebirthConfig.MaximumRareCustomerBonus =
	0.75


--==================================================
-- CASH REQUIREMENTS
--==================================================

-- Explicitly balanced early / mid rebirth costs.
--
-- Index = rebirth being purchased.
--
-- Rebirth 1 intentionally remains K.
-- Early rebirths remain approachable.
-- From Rebirth 5 onward, cash once again becomes
-- an important part of the prestige requirement.

RebirthConfig.CashRequirements = {
	[1] = 500_000,
	[2] = 900_000,
	[3] = 1_500_000,
	[4] = 2_400_000,
	[5] = 4_000_000,
	[6] = 6_500_000,
	[7] = 10_000_000,
	[8] = 15_000_000,
	[9] = 22_000_000,
	[10] = 32_000_000,
	[11] = 45_000_000,
}


-- After the hand-balanced portion of the game,
-- rebirth cash requirements continue growing
-- automatically.
RebirthConfig.LateCashGrowth =
	1.40


local function roundCash(
	value: number
): number

	if value >= 100_000_000 then

		return
			math.floor(
				value / 1_000_000
					+ 0.5
			)
			* 1_000_000

	elseif value >= 10_000_000 then

		return
			math.floor(
				value / 500_000
					+ 0.5
			)
			* 500_000

	elseif value >= 1_000_000 then

		return
			math.floor(
				value / 50_000
					+ 0.5
			)
			* 50_000

	else

		return
			math.floor(
				value / 10_000
					+ 0.5
			)
			* 10_000
	end
end


local function getRequiredCash(
	rebirthBeingPurchased: number
): number

	local configured =
		RebirthConfig.CashRequirements[
			rebirthBeingPurchased
		]


	if configured ~= nil then
		return configured
	end


	local lastConfiguredRebirth =
		#RebirthConfig.CashRequirements

	local lastConfiguredCash =
		RebirthConfig.CashRequirements[
			lastConfiguredRebirth
		]


	local levelsPastConfigured =
		rebirthBeingPurchased
		- lastConfiguredRebirth


	local requiredCash =
		lastConfiguredCash
		* (
			RebirthConfig.LateCashGrowth
			^ levelsPastConfigured
		)


	return roundCash(
		requiredCash
	)
end


--==================================================
-- REQUIREMENTS
--==================================================

function RebirthConfig.GetRequirements(
	currentRebirths: number
)

	currentRebirths =
		math.max(
			0,
			math.floor(
				tonumber(
					currentRebirths
				) or 0
			)
		)


	local rebirthBeingPurchased =
		currentRebirths + 1


	local requiredReputation =
		math.floor(
			15
				+ 7 * currentRebirths
				+ 2.5 * (
					currentRebirths
					^ 1.35
				)
				+ 0.5
		)


	local requiredCash =
		getRequiredCash(
			rebirthBeingPurchased
		)


	return {
		Reputation =
			requiredReputation,

		Cash =
			requiredCash,

		Business =
			RebirthConfig.RequiredBusiness,

		BusinessDisplayName =
			RebirthConfig
				.RequiredBusinessDisplayName,
	}
end


--==================================================
-- CURRENT BONUSES
--==================================================

function RebirthConfig.GetBonuses(
	rebirths: number
)

	rebirths =
		math.max(
			0,
			math.floor(
				tonumber(
					rebirths
				) or 0
			)
		)


	local cashBonus =
		rebirths
		* RebirthConfig
			.CashBonusPerRebirth


	local customerRateBonus =
		math.min(
			rebirths
				* RebirthConfig
					.CustomerRateBonusPerRebirth,

			RebirthConfig
				.MaximumCustomerRateBonus
		)


	local rareCustomerBonus =
		math.min(
			rebirths
				* RebirthConfig
					.RareCustomerBonusPerRebirth,

			RebirthConfig
				.MaximumRareCustomerBonus
		)


	return {
		CashBonus =
			cashBonus,

		CustomerRateBonus =
			customerRateBonus,

		RareCustomerBonus =
			rareCustomerBonus,

		CashMultiplier =
			1 + cashBonus,

		CustomerRateMultiplier =
			1 + customerRateBonus,

		RareCustomerMultiplier =
			1 + rareCustomerBonus,
	}
end


--==================================================
-- NEXT REBIRTH GAIN
--==================================================

function RebirthConfig.GetNextGain(
	currentRebirths: number
)

	local current =
		RebirthConfig.GetBonuses(
			currentRebirths
		)


	local after =
		RebirthConfig.GetBonuses(
			currentRebirths + 1
		)


	return {
		CashBonus =
			math.max(
				0,
				after.CashBonus
					- current.CashBonus
			),

		CustomerRateBonus =
			math.max(
				0,
				after.CustomerRateBonus
					- current.CustomerRateBonus
			),

		RareCustomerBonus =
			math.max(
				0,
				after.RareCustomerBonus
					- current.RareCustomerBonus
			),
	}
end


return RebirthConfig