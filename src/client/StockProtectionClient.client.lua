--==================================================
-- STOCK PROTECTION CLIENT
--==================================================

local ReplicatedStorage =
	game:GetService("ReplicatedStorage")


local Notification =
	require(
		ReplicatedStorage
			:WaitForChild("Shared")
			:WaitForChild("Notification")
	)


local remotes =
	ReplicatedStorage:WaitForChild("Remotes")


local notificationRemote =
	remotes:WaitForChild(
		"StockProtectionNotification"
	)


notificationRemote.OnClientEvent:Connect(
	function(message: string)

		if typeof(message) ~= "string"
			or message == "" then

			return
		end

		Notification.Warning(message)
	end
)