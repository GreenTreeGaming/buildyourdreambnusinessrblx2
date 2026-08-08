local Players =
	game:GetService("Players")

local player =
	Players.LocalPlayer

local playerGui =
	player:WaitForChild("PlayerGui")

-- Appearance upgrades are no longer shown through a
-- separate BillboardGui above businesses.
--
-- Clean up any old UI that may already exist while
-- testing in Studio.
for _, instance in playerGui:GetChildren() do
	if instance:IsA("BillboardGui")
		and instance.Name == "BusinessUpgradeUI" then

		instance:Destroy()
	end
end