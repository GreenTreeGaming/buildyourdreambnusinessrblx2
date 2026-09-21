local RebirthConfig = {}


--==================================================
-- REQUIREMENTS
--==================================================

-- First rebirth:
-- Rep 50
-- $50M
-- Coffee Stand unlocked

RebirthConfig.BaseRequiredReputation =
	50

RebirthConfig.ReputationIncreasePerRebirth =
	15


RebirthConfig.BaseRequiredCash =
	50_000_000

RebirthConfig.CashGrowthPerRebirth =
	3


RebirthConfig.RequiredBusiness =
	"CoffeeStand"

RebirthConfig.RequiredBusinessDisplayName =
	"Coffee Stand"


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
	1.00


-- +5% rare-customer odds every rebirth.
RebirthConfig.RareCustomerBonusPerRebirth =
	0.05

-- Cap at +50%.
RebirthConfig.MaximumRareCustomerBonus =
	0.50


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


	local requiredReputation =
		RebirthConfig.BaseRequiredReputation
		+ (
			currentRebirths
			* RebirthConfig
				.ReputationIncreasePerRebirth
		)


	local requiredCash =
		RebirthConfig.BaseRequiredCash
		* (
			RebirthConfig.CashGrowthPerRebirth
			^ currentRebirths
		)


	requiredCash =
		math.floor(
			requiredCash
			+ 0.5
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