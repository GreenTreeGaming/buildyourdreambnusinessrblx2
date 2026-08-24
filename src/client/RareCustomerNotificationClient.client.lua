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
					4.5,
			}
		)
	end
)