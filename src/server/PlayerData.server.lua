local Players = game:GetService("Players")

local DataService = require(
	script.Parent
		:WaitForChild("Services")
		:WaitForChild("DataService")
)

local AUTOSAVE_INTERVAL_SECONDS = 60

local shuttingDown = false

local function loadPlayer(player: Player)
	local loaded =
		DataService.LoadPlayer(player)

	if not loaded then
		return
	end

	print(`Loaded data for {player.Name}.`)
end

Players.PlayerAdded:Connect(function(player)
	task.spawn(loadPlayer, player)
end)

for _, player in Players:GetPlayers() do
	task.spawn(loadPlayer, player)
end

task.spawn(function()
	while not shuttingDown do
		task.wait(AUTOSAVE_INTERVAL_SECONDS)

		if shuttingDown then
			break
		end

		for _, player in Players:GetPlayers() do
			task.spawn(function()
				DataService.SavePlayer(player)
			end)
		end
	end
end)

game:BindToClose(function()
	shuttingDown = true

	DataService.SaveAllPlayers()
end)