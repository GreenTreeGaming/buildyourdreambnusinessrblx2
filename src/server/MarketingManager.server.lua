local Players =
	game:GetService("Players")

local ReplicatedStorage =
	game:GetService("ReplicatedStorage")

local Workspace =
	game:GetService("Workspace")


local MarketingService =
	require(
		script.Parent
			:WaitForChild("Services")
			:WaitForChild("MarketingService")
	)


local plotsFolder =
	Workspace:WaitForChild(
		"Plots"
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


local getMarketingStateRemote =
	getOrCreateRemoteFunction(
		"GetMarketingState"
	)


local purchaseMarketingRequestRemote =
	getOrCreateRemoteFunction(
		"PurchaseMarketingRequest"
	)


local function findOwnedPlot(
	player: Player
): Model?

	for _, plot in
		plotsFolder:GetChildren() do

		if plot:IsA(
			"Model"
		)
			and plot:GetAttribute(
				"OwnerUserId"
			) == player.UserId then

			return plot
		end
	end


	return nil
end


local function applyPlayerMarketing(
	player: Player
)
	task.spawn(
		function()

			local startedAt =
				time()


			while player.Parent
				and time()
					- startedAt < 20 do

				if player:GetAttribute(
					"DataLoaded"
				) == true then

					local plot =
						findOwnedPlot(
							player
						)


					if plot then

						MarketingService.ApplyToPlot(
							player,
							plot
						)


						return
					end
				end


				task.wait(
					0.25
				)
			end
		end
	)
end


getMarketingStateRemote.OnServerInvoke =
	function(
		player: Player
	)

		return MarketingService.GetState(
			player
		)
	end


purchaseMarketingRequestRemote.OnServerInvoke =
	function(
		player: Player
	)

		local success,
			result =
			pcall(
				function()

					return MarketingService.Purchase(
						player
					)
				end
			)


		if not success then

			warn(
				`[MarketingManager] Purchase failed for {player.Name}: {result}`
			)


			return {
				Success = false,

				Message =
					"Something went wrong while purchasing marketing.",
			}
		end


		if type(result)
			~= "table" then

			return {
				Success = false,

				Message =
					"The marketing purchase returned an invalid result.",
			}
		end


		return result
	end


for _, player in
	Players:GetPlayers() do

	applyPlayerMarketing(
		player
	)
end


Players.PlayerAdded:Connect(
	applyPlayerMarketing
)


print(
	"MarketingManager started."
)