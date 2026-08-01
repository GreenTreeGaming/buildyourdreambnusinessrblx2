local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local ServerStorage = game:GetService("ServerStorage")

local plotsFolder = Workspace:WaitForChild("Plots")
local remotes = ReplicatedStorage:WaitForChild("Remotes")

local requestEditRemote =
	remotes:WaitForChild("RequestEditBusiness")

local requestRemoveRemote =
	remotes:WaitForChild("RequestRemoveBusiness")

local interactionResultRemote =
	remotes:WaitForChild("BusinessInteractionResult")

local cancelEditRemote =
	remotes:WaitForChild("CancelBusinessEdit")

local businessAvailabilityEvent =
	ServerStorage:FindFirstChild("BusinessAvailabilityChanged")

local BUSINESS_NAME = "LemonadeStand"
local REMOVE_CONFIRMIRMATION_TIMEOUT = 15

type EditState = {
	stand: Model,
	plot: Model,
	originalCFrame: CFrame,
}

type RemoveRequest = {
	stand: Model,
	plot: Model,
	expiresAt: number,
}

local activeEdits: {[Player]: EditState} = {}
local pendingRemovals: {[Player]: RemoveRequest} = {}

local function getPlayerPlot(player: Player): Model?
	local plotName = player:GetAttribute("PlotName")

	if typeof(plotName) == "string" then
		local namedPlot = plotsFolder:FindFirstChild(plotName)

		if namedPlot
			and namedPlot:IsA("Model")
			and namedPlot:GetAttribute("OwnerUserId") == player.UserId then

			return namedPlot
		end
	end

	for _, plot in plotsFolder:GetChildren() do
		if not plot:IsA("Model") then
			continue
		end

		if plot:GetAttribute("OwnerUserId") == player.UserId then
			return plot
		end
	end

	return nil
end

local function getPlacedBusinesses(plot: Model): Instance?
	local placedBusinesses =
		plot:FindFirstChild("PlacedBusinesses")

	if placedBusinesses then
		return placedBusinesses
	end

	return nil
end

local function getPlayerStand(
	player: Player
): (Model?, Model?)
	local plot = getPlayerPlot(player)

	if not plot then
		return nil, nil
	end

	local placedBusinesses = getPlacedBusinesses(plot)

	if not placedBusinesses then
		return nil, plot
	end

	local stand =
		placedBusinesses:FindFirstChild(BUSINESS_NAME)

	if stand and stand:IsA("Model") then
		return stand, plot
	end

	return nil, plot
end

local function playerOwnsStand(
	player: Player,
	stand: Model,
	plot: Model
): boolean
	if plot:GetAttribute("OwnerUserId") ~= player.UserId then
		return false
	end

	if stand:GetAttribute("OwnerUserId") ~= player.UserId then
		return false
	end

	local placedBusinesses = getPlacedBusinesses(plot)

	if not placedBusinesses then
		return false
	end

	return stand.Parent == placedBusinesses
end

local function setPurchasePromptsEnabled(
	stand: Model,
	enabled: boolean
)
	for _, descendant in stand:GetDescendants() do
		if descendant:IsA("ProximityPrompt") then
			descendant.Enabled = enabled
		end
	end
end

local function closeStand(
	stand: Model,
	plot: Model
)
	stand:SetAttribute("StandUnavailable", true)
	stand:SetAttribute("IsBeingEdited", true)

	setPurchasePromptsEnabled(stand, false)

	-- Tells CustomerManager to cancel all queue movement and send every
	-- customer assigned to this plot toward CustomerExit.
	businessAvailabilityEvent:Fire(plot)
end

local function reopenStand(stand: Model)
	stand:SetAttribute("StandUnavailable", false)
	stand:SetAttribute("IsBeingEdited", false)

	setPurchasePromptsEnabled(stand, true)
end

local function clearPlayerInteractionState(player: Player)
	activeEdits[player] = nil
	pendingRemovals[player] = nil

	player:SetAttribute("EditingBusiness", nil)
end

local function sendFailure(
	player: Player,
	action: string,
	message: string
)
	interactionResultRemote:FireClient(
		player,
		action,
		message
	)
end

local function beginEditing(player: Player)
	if activeEdits[player] then
		return
	end

	local stand, plot = getPlayerStand(player)

	if not stand or not plot then
		sendFailure(
			player,
			"EditFailed",
			"Your lemonade stand could not be found."
		)

		return
	end

	if not playerOwnsStand(player, stand, plot) then
		sendFailure(
			player,
			"EditFailed",
			"You do not own this lemonade stand."
		)

		return
	end

	if stand:GetAttribute("IsBeingEdited") == true then
		sendFailure(
			player,
			"EditFailed",
			"This lemonade stand is already being edited."
		)

		return
	end

	pendingRemovals[player] = nil

	activeEdits[player] = {
		stand = stand,
		plot = plot,
		originalCFrame = stand:GetPivot(),
	}

	player:SetAttribute(
		"EditingBusiness",
		BUSINESS_NAME
	)

	closeStand(stand, plot)

	interactionResultRemote:FireClient(
		player,
		"BeginEdit",
		stand:GetPivot()
	)
end

local function beginRemoveConfirmation(player: Player)
	if activeEdits[player] then
		sendFailure(
			player,
			"RemoveFailed",
			"Finish editing before removing the stand."
		)

		return
	end

	local stand, plot = getPlayerStand(player)

	if not stand or not plot then
		sendFailure(
			player,
			"RemoveFailed",
			"Your lemonade stand could not be found."
		)

		return
	end

	if not playerOwnsStand(player, stand, plot) then
		sendFailure(
			player,
			"RemoveFailed",
			"You do not own this lemonade stand."
		)

		return
	end

	pendingRemovals[player] = {
		stand = stand,
		plot = plot,
		expiresAt = time() + REMOVE_CONFIRMIRMATION_TIMEOUT,
	}

	interactionResultRemote:FireClient(
		player,
		"ShowRemoveConfirmation"
	)
end

local function confirmRemoval(player: Player)
	local request = pendingRemovals[player]

	if not request then
		sendFailure(
			player,
			"RemoveFailed",
			"There is no active removal confirmation."
		)

		return
	end

	pendingRemovals[player] = nil

	if time() > request.expiresAt then
		sendFailure(
			player,
			"RemoveFailed",
			"The removal confirmation expired."
		)

		return
	end

	local stand = request.stand
	local plot = request.plot

	if not stand.Parent
		or not plot.Parent
		or not playerOwnsStand(player, stand, plot) then

		sendFailure(
			player,
			"RemoveFailed",
			"The lemonade stand could not be found."
		)

		return
	end

	closeStand(stand, plot)

	-- Gives CustomerManager time to detect StandUnavailable
	-- and send existing customers away.
	task.wait()

	if stand.Parent then
		stand:Destroy()
	end

	plot:SetAttribute(
		"StarterBusinessPlaced",
		false
	)

	clearPlayerInteractionState(player)

	interactionResultRemote:FireClient(
		player,
		"Removed",
		"Lemonade stand removed."
	)
end

local function cancelEditing(player: Player)
	local editState = activeEdits[player]

	if not editState then
		return
	end

	local stand = editState.stand

	if stand.Parent then
		stand:PivotTo(editState.originalCFrame)
		reopenStand(stand)
	end

	clearPlayerInteractionState(player)

	interactionResultRemote:FireClient(
		player,
		"EditCancelled",
		"Editing cancelled."
	)
end

requestEditRemote.OnServerEvent:Connect(function(player: Player)
	beginEditing(player)
end)

requestRemoveRemote.OnServerEvent:Connect(function(
	player: Player,
	confirmed: boolean?
)
	if confirmed == true then
		confirmRemoval(player)
	else
		beginRemoveConfirmation(player)
	end
end)

cancelEditRemote.OnServerEvent:Connect(function(player: Player)
	cancelEditing(player)
end)

Players.PlayerRemoving:Connect(function(player: Player)
	local editState = activeEdits[player]

	if editState then
		local stand = editState.stand

		if stand.Parent then
			stand:PivotTo(editState.originalCFrame)
			reopenStand(stand)
		end
	end

	clearPlayerInteractionState(player)
end)

-- BusinessPlacementManager reads this table when deciding whether
-- to move an existing stand instead of cloning a new one.
_G.BusinessEditStates = activeEdits

print("BusinessInteractionManager started.")