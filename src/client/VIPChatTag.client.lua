local Players =
	game:GetService("Players")

local TextChatService =
	game:GetService("TextChatService")

local VIP_TAG =
	'<font color="#FFD84A">[VIP]</font>'

TextChatService.OnIncomingMessage =
	function(message: TextChatMessage)
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

		if player:GetAttribute(
			"HasVIP"
		) ~= true then

			return properties
		end

		properties.PrefixText =
			`{VIP_TAG} {message.PrefixText}`

		return properties
	end