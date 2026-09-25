-- ServerScriptService/ChatReminders.server.lua

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local REMINDER_INTERVAL = 120 -- 2 minutes

local messages = {
	"👍 Enjoying the game? Drop a Like to support us!",
	"⭐ Favorite the game so you can easily come back later!",
	"💰 Keep building... your business empire isn't going to build itself!",
	"🚀 Upgrade your businesses to grow your empire even faster!",
	"👑 Can you become the richest business owner?",
	"🔥 Invite your friends and build your businesses together!",
}

-- RemoteEvent used to display the message on each player's client.
local chatReminderEvent = ReplicatedStorage:FindFirstChild("ChatReminder")

if not chatReminderEvent then
	chatReminderEvent = Instance.new("RemoteEvent")
	chatReminderEvent.Name = "ChatReminder"
	chatReminderEvent.Parent = ReplicatedStorage
end

local lastMessageIndex = 0

local function getRandomMessage()
	if #messages == 1 then
		return messages[1]
	end

	local index

	repeat
		index = math.random(1, #messages)
	until index ~= lastMessageIndex

	lastMessageIndex = index

	return messages[index]
end

while true do
	task.wait(REMINDER_INTERVAL)

	chatReminderEvent:FireAllClients(getRandomMessage())
end