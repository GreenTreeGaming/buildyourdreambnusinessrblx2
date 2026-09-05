local ReplicatedStorage =
	game:GetService("ReplicatedStorage")


local Notification =
	require(
		ReplicatedStorage
			:WaitForChild("Shared")
			:WaitForChild("Notification")
	)


local remotes =
	ReplicatedStorage:WaitForChild(
		"Remotes"
	)


local rareCustomerNotification =
	remotes:WaitForChild(
		"RareCustomerNotification"
	)


-- Important gameplay events should stay visible
-- noticeably longer than ordinary success messages.
local RARE_CUSTOMER_NOTIFICATION_DURATION =
	5.5


rareCustomerNotification.OnClientEvent:Connect(
	function(
		customerType: string,
		customerName: string
	)

		if typeof(customerType)
				~= "string"
			or typeof(customerName)
				~= "string" then

			return
		end


		Notification.Info(
			`A {customerType} Customer has arrived!`,

			{
				Title =
					customerName,

				Duration =
					RARE_CUSTOMER_NOTIFICATION_DURATION,
			}
		)
	end
)