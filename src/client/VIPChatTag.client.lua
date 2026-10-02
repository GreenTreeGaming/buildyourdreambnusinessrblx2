local Players =
	game:GetService(
		"Players"
	)

local TextChatService =
	game:GetService(
		"TextChatService"
	)


--==================================================
-- TAGS
--==================================================

local VIP_TAG =
	'<font color="#FFD84A">[VIP]</font>'


local REBIRTH_TIERS = {
	{
		Minimum = 20,

		Tag =
			'<font color="#FF56E1">[MYTHIC]</font>',
	},

	{
		Minimum = 10,

		Tag =
			'<font color="#63E7FF">[DIAMOND]</font>',
	},

	{
		Minimum = 5,

		Tag =
			'<font color="#FFCD31">[GOLD]</font>',
	},

	{
		Minimum = 3,

		Tag =
			'<font color="#D2DEEB">[SILVER]</font>',
	},

	{
		Minimum = 1,

		Tag =
			'<font color="#D8894B">[BRONZE]</font>',
	},
}


local function getRebirthTag(
	rebirths: number
): string?

	for _, tier in
		REBIRTH_TIERS do

		if rebirths
			>= tier.Minimum then

			return tier.Tag
		end
	end


	return nil
end


--==================================================
-- CHAT
--==================================================

TextChatService.OnIncomingMessage =
	function(
		message: TextChatMessage
	)

		local properties =
			Instance.new(
				"TextChatMessageProperties"
			)


		local textSource =
			message.TextSource


		if not textSource then

			return properties
		end


		local player =
			Players:GetPlayerByUserId(
				textSource.UserId
			)


		if not player then

			return properties
		end


		local tags = {}


		--==================================================
		-- VIP
		--==================================================

		if player:GetAttribute(
			"HasVIP"
		) == true then

			table.insert(
				tags,
				VIP_TAG
			)
		end


		--==================================================
		-- REBIRTH TIER
		--==================================================

		local rebirths =
			player:GetAttribute(
				"Rebirths"
			)


		if typeof(rebirths)
			~= "number" then

			rebirths =
				0
		end


		rebirths =
			math.max(
				0,
				math.floor(
					rebirths
				)
			)


		local rebirthTag =
			getRebirthTag(
				rebirths
			)


		if rebirthTag then

			table.insert(
				tags,
				rebirthTag
			)
		end


		--==================================================
		-- APPLY
		--==================================================

		if #tags == 0 then

			return properties
		end


		properties.PrefixText =
			`{table.concat(tags, " ")} {message.PrefixText}`


		return properties
	end