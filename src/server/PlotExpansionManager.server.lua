local ReplicatedStorage =
	game:GetService("ReplicatedStorage")


local PlotService =
	require(
		script.Parent
			:WaitForChild("Services")
			:WaitForChild("PlotService")
	)


local remotes =
	ReplicatedStorage:FindFirstChild(
		"Remotes"
	)


if not remotes then

	remotes =
		Instance.new(
			"Folder"
		)

	remotes.Name =
		"Remotes"

	remotes.Parent =
		ReplicatedStorage
end


local function getOrCreateRemoteFunction(
	name: string
): RemoteFunction

	local existing =
		remotes:FindFirstChild(
			name
		)


	if existing then

		if not existing:IsA(
			"RemoteFunction"
		) then

			error(
				`ReplicatedStorage.Remotes.{name} must be a RemoteFunction.`
			)
		end


		return existing
	end


	local remote =
		Instance.new(
			"RemoteFunction"
		)

	remote.Name =
		name

	remote.Parent =
		remotes


	return remote
end


local getPlotExpansionStateRemote =
	getOrCreateRemoteFunction(
		"GetPlotExpansionState"
	)


local purchasePlotExpansionRemote =
	getOrCreateRemoteFunction(
		"PurchasePlotExpansion"
	)


getPlotExpansionStateRemote.OnServerInvoke =
	function(
		player: Player
	)

		return PlotService.GetState(
			player
		)
	end


purchasePlotExpansionRemote.OnServerInvoke =
	function(
		player: Player
	)

		local success,
			result =
			pcall(
				function()

					return PlotService.Purchase(
						player
					)
				end
			)


		if not success then

			warn(
				`[PlotExpansionManager] Purchase failed for {player.Name}: {result}`
			)


			return {
				Success = false,

				Message =
					"Something went wrong while expanding your plot.",
			}
		end


		return result
	end


print(
	"PlotExpansionManager started."
)