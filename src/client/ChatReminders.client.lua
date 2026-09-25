-- StarterPlayer/StarterPlayerScripts/ChatReminders.client.lua

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextChatService = game:GetService("TextChatService")

local chatReminderEvent = ReplicatedStorage:WaitForChild("ChatReminder")

local function showSystemMessage(message)
	local textChannels = TextChatService:FindFirstChild("TextChannels")

	if not textChannels then
		warn("TextChatService.TextChannels was not found.")
		return
	end

	local generalChannel = textChannels:FindFirstChild("RBXGeneral")

	if not generalChannel then
		warn("RBXGeneral chat channel was not found.")
		return
	end

	generalChannel:DisplaySystemMessage(message)
end

chatReminderEvent.OnClientEvent:Connect(showSystemMessage)