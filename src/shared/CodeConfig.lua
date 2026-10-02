local CodeConfig = {}

--[[
	TIMES:
	Use Unix timestamps.

	You can get one from:
	DateTime.fromUniversalTime(...).UnixTimestamp

	StartTime = nil means active immediately.
	EndTime = nil means never expires.

	All codes are case-insensitive when redeemed.
]]

CodeConfig.Codes = {
	RELEASE = {
		StartTime = nil,
		EndTime = nil,

		Reward = {
			Type = "Cash",
			Amount = 500,
		},
	},

	DREAMBUSINESS = {
		StartTime = nil,
		EndTime = nil,

		Reward = {
			Type = "Cash",
			Amount = 1000,
		},
	},

	-- Example limited-time code.
	LAUNCH2026 = {
		StartTime =
			DateTime.fromUniversalTime(
				2026,
				8,
				20,
				0,
				0,
				0
			).UnixTimestamp,

		EndTime =
			DateTime.fromUniversalTime(
				2026,
				9,
				20,
				23,
				59,
				59
			).UnixTimestamp,

		Reward = {
			Type = "Cash",
			Amount = 2500,
		},
	},
}

return CodeConfig