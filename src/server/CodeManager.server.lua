local Players =
	game:GetService("Players")

local ReplicatedStorage =
	game:GetService("ReplicatedStorage")


local CodeService =
	require(
		script.Parent
			:WaitForChild("Services")
			:WaitForChild("CodeService")
	)


local remotes =
	ReplicatedStorage:FindFirstChild(
		"Remotes"
	)

if not remotes then
	remotes =
		Instance.new("Folder")

	remotes.Name =
		"Remotes"

	remotes.Parent =
		ReplicatedStorage
end


local redeemCodeRemote =
	remotes:FindFirstChild(
		"RedeemCode"
	)

if redeemCodeRemote
	and not redeemCodeRemote:IsA(
		"RemoteFunction"
	) then

	redeemCodeRemote:Destroy()

	redeemCodeRemote =
		nil
end


if not redeemCodeRemote then
	redeemCodeRemote =
		Instance.new(
			"RemoteFunction"
		)

	redeemCodeRemote.Name =
		"RedeemCode"

	redeemCodeRemote.Parent =
		remotes
end


local lastRequestTimes: {
	[Player]: number
} = {}


local RATE_LIMIT_SECONDS =
	0.75


redeemCodeRemote.OnServerInvoke =
	function(
		player: Player,
		code: any
	)
		local now =
			os.clock()

		local previous =
			lastRequestTimes[player]

		if previous
			and now - previous
				< RATE_LIMIT_SECONDS then

			return {
				Success = false,
				Status = "RateLimited",
				Message =
					"You're entering codes too quickly.",
			}
		end

		lastRequestTimes[player] =
			now

		local success,
			result =
			pcall(function()

				return CodeService.Redeem(
					player,
					code
				)
			end)

		if not success then
			warn(
				`[Codes] Redeem failed for {player.Name}: {result}`
			)

			return {
				Success = false,
				Status = "ServerError",
				Message =
					"Something went wrong. Try again.",
			}
		end

		return result
	end


Players.PlayerRemoving:Connect(
	function(player)
		lastRequestTimes[player] =
			nil
	end
)


print(
	"[Codes] CodeManager initialized."
)