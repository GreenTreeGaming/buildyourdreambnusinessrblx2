local Players =
	game:GetService("Players")

local ReplicatedStorage =
	game:GetService("ReplicatedStorage")


local DataService =
	require(
		script.Parent
			:WaitForChild("Services")
			:WaitForChild("DataService")
	)


local AnalyticsTracker =
	require(
		script.Parent
			:WaitForChild("Services")
			:WaitForChild("AnalyticsService")
	)


local remotes =
	ReplicatedStorage:WaitForChild(
		"Remotes"
	)


--==================================================
-- VALID CONTEXTUAL TUTORIALS
--==================================================

local VALID_CONTEXTUAL_TUTORIALS = {
	Stock = true,
	Marketing = true,
	PlotExpansion = true,
	Licenses = true,
	Rebirth = true,
}


--==================================================
-- REMOTE HELPERS
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
			existing:IsA(
				"RemoteFunction"
			),
			`Remotes.{name} must be a RemoteFunction.`
		)


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


local function getOrCreateRemoteEvent(
	name: string
): RemoteEvent

	local existing =
		remotes:FindFirstChild(
			name
		)


	if existing then

		assert(
			existing:IsA(
				"RemoteEvent"
			),
			`Remotes.{name} must be a RemoteEvent.`
		)


		return existing
	end


	local remote =
		Instance.new(
			"RemoteEvent"
		)


	remote.Name =
		name

	remote.Parent =
		remotes


	return remote
end


--==================================================
-- MAIN TUTORIAL REMOTES
--==================================================

local getTutorialStateRemote =
	getOrCreateRemoteFunction(
		"GetTutorialState"
	)


local completeTutorialRemote =
	getOrCreateRemoteEvent(
		"CompleteTutorial"
	)


--==================================================
-- CONTEXTUAL TUTORIAL REMOTES
--==================================================

local getContextualTutorialStateRemote =
	getOrCreateRemoteFunction(
		"GetContextualTutorialState"
	)


local completeContextualTutorialRemote =
	getOrCreateRemoteFunction(
		"CompleteContextualTutorial"
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
-- MAIN TUTORIAL STATE
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
-- MAIN TUTORIAL COMPLETION
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


		--==================================================
		-- ALREADY COMPLETED
		--==================================================

		if DataService.GetTutorialCompleted(
			player
		) then

			--
			-- Still make sure the replicated attribute
			-- correctly reflects the saved state.
			--
			player:SetAttribute(
				"TutorialCompleted",
				true
			)


			completionLocks[
				player
			] = nil

			return
		end


		--==================================================
		-- SAVE COMPLETION
		--==================================================

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


		--
		-- IMPORTANT:
		--
		-- Contextual tutorials listen to this.
		-- Set it immediately instead of waiting until
		-- the player rejoins.
		--
		player:SetAttribute(
			"TutorialCompleted",
			true
		)


		AnalyticsTracker.LogOnboarding(
			player,
			AnalyticsTracker.Onboarding
				.TutorialCompleted,
			"Tutorial Completed"
		)


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


--==================================================
-- GET CONTEXTUAL TUTORIAL STATE
--==================================================

getContextualTutorialStateRemote.OnServerInvoke =
	function(
		player: Player
	)

		local profile =
			waitForProfile(
				player
			)


		if not profile then

			return {
				Success = false,
				Completed = {},
			}
		end


		return {
			Success = true,

			Completed =
				DataService.GetContextualTutorials(
					player
				),
		}
	end


--==================================================
-- COMPLETE CONTEXTUAL TUTORIAL
--==================================================

local contextualCompletionLocks: {
	[Player]: boolean
} = {}


completeContextualTutorialRemote.OnServerInvoke =
	function(
		player: Player,
		tutorialId: string
	)

		if type(tutorialId)
			~= "string"
			or VALID_CONTEXTUAL_TUTORIALS[
				tutorialId
			] ~= true then

			return false
		end


		if contextualCompletionLocks[
			player
		] then

			return false
		end


		contextualCompletionLocks[
			player
		] = true


		local profile =
			waitForProfile(
				player
			)


		if not profile then

			contextualCompletionLocks[
				player
			] = nil

			return false
		end


		local success =
			DataService.MarkContextualTutorialCompleted(
				player,
				tutorialId
			)


		if success then

			task.spawn(
				function()

					if player.Parent then

						DataService.SavePlayer(
							player
						)
					end
				end
			)
		end


		contextualCompletionLocks[
			player
		] = nil


		return success
	end


--==================================================
-- CLEANUP
--==================================================

Players.PlayerRemoving:Connect(
	function(
		player: Player
	)

		completionLocks[
			player
		] = nil


		contextualCompletionLocks[
			player
		] = nil
	end
)