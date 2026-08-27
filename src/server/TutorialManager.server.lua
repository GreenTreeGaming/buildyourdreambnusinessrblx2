local ReplicatedStorage =
	game:GetService("ReplicatedStorage")


local DataService =
	require(
		script.Parent
			:WaitForChild("Services")
			:WaitForChild("DataService")
	)


local remotes =
	ReplicatedStorage:WaitForChild(
		"Remotes"
	)


--==================================================
-- REMOTES
--==================================================

local function getOrCreateRemoteFunction(
	name: string
): RemoteFunction

	local existing =
		remotes:FindFirstChild(
			name
		)


	if existing then

		assert(
			existing:IsA("RemoteFunction"),
			`Remotes.{name} must be a RemoteFunction.`
		)


		return existing
	end


	local remote =
		Instance.new("RemoteFunction")


	remote.Name =
		name

	remote.Parent =
		remotes


	return remote
end


local function getOrCreateRemoteEvent(
	name: string
): RemoteEvent

	local existing =
		remotes:FindFirstChild(
			name
		)


	if existing then

		assert(
			existing:IsA("RemoteEvent"),
			`Remotes.{name} must be a RemoteEvent.`
		)


		return existing
	end


	local remote =
		Instance.new("RemoteEvent")


	remote.Name =
		name

	remote.Parent =
		remotes


	return remote
end


local getTutorialStateRemote =
	getOrCreateRemoteFunction(
		"GetTutorialState"
	)


local completeTutorialRemote =
	getOrCreateRemoteEvent(
		"CompleteTutorial"
	)


--==================================================
-- PROFILE WAITING
--==================================================

local PROFILE_WAIT_TIMEOUT =
	20


local function waitForProfile(
	player: Player
)

	local deadline =
		time()
		+ PROFILE_WAIT_TIMEOUT


	while player.Parent
		and not DataService.GetProfile(
			player
		)
		and time() < deadline do

		task.wait(
			0.1
		)
	end


	return DataService.GetProfile(
		player
	)
end


--==================================================
-- GET STATE
--==================================================

getTutorialStateRemote.OnServerInvoke =
	function(
		player: Player
	)

		local profile =
			waitForProfile(
				player
			)


		if not profile then
			return {
				Loaded = false,
				Completed = false,
			}
		end


		local completed =
			DataService.GetTutorialCompleted(
				player
			)


		player:SetAttribute(
			"TutorialCompleted",
			completed
		)


		return {
			Loaded = true,
			Completed = completed,
		}
	end


--==================================================
-- COMPLETE TUTORIAL
--==================================================

local completionLocks: {
	[Player]: boolean
} = {}


completeTutorialRemote.OnServerEvent:Connect(
	function(
		player: Player
	)

		if completionLocks[
			player
		] then

			return
		end


		completionLocks[
			player
		] = true


		local profile =
			waitForProfile(
				player
			)


		if not profile then

			completionLocks[
				player
			] = nil

			return
		end


		-- Already completed.
		if DataService.GetTutorialCompleted(
			player
		) then

			completionLocks[
				player
			] = nil

			return
		end


		local updated =
			DataService.SetTutorialCompleted(
				player,
				true
			)


		if not updated then

			completionLocks[
				player
			] = nil

			return
		end


		-- Save immediately instead of relying solely
		-- on the regular autosave.
		task.spawn(
			function()

				DataService.SavePlayer(
					player
				)

			end
		)


		completionLocks[
			player
		] = nil
	end
)