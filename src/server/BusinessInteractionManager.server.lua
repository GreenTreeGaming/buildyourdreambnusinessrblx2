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

local BusinessConfig =
	require(
		ReplicatedStorage
			:WaitForChild("Shared")
			:WaitForChild("BusinessConfig")
	)

local REMOVE_CONFIRMATION_TIMEOUT = 15

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

local function findOwnedBusinessById(
	player: Player,
	plot: Model,
	businessId: string
): Model?
	if type(businessId) ~= "string"
		or businessId == "" then

		return nil
	end

	local placedBusinesses =
		plot:FindFirstChild(
			"PlacedBusinesses"
		)

	if not placedBusinesses then
		return nil
	end

	for _, child in
		placedBusinesses:GetChildren() do

		if not child:IsA("Model") then
			continue
		end

		local childId =
			child:GetAttribute("BusinessId")

		if childId == businessId
			or child.Name == businessId then

			if child:GetAttribute("OwnerUserId")
				== player.UserId then

				return child
			end
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
	stand:SetAttribute(
		"StandUnavailable",
		true
	)

	stand:SetAttribute(
		"IsBeingEdited",
		true
	)

	setPurchasePromptsEnabled(
		stand,
		false
	)

	if businessAvailabilityEvent
		and businessAvailabilityEvent:IsA(
			"BindableEvent"
		) then

		businessAvailabilityEvent:Fire(
			plot,
			stand
		)
	end
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

local function getBusinessType(
	stand: Model
): string?

	local businessType =
		stand:GetAttribute(
			"BusinessType"
		)

	if typeof(businessType) == "string"
		and BusinessConfig[businessType] then

		return businessType
	end

	for businessName in BusinessConfig do

		if stand.Name == businessName
			or string.match(
				stand.Name,
				`^{businessName}_`
			) then

			return businessName
		end
	end

	return nil
end

local function beginEditing(
	player: Player,
	businessId: string
)
	if activeEdits[player] then
		sendFailure(
			player,
			"EditFailed",
			"You are already editing a business."
		)

		return
	end

	local plot =
		getPlayerPlot(player)

	if not plot then
		sendFailure(
			player,
			"EditFailed",
			"Your plot could not be found."
		)

		return
	end

	local stand =
		findOwnedBusinessById(
			player,
			plot,
			businessId
		)

	if not stand then
		sendFailure(
			player,
			"EditFailed",
			"Your business could not be found."
		)

		return
	end

	if not playerOwnsStand(
		player,
		stand,
		plot
	) then
		sendFailure(
			player,
			"EditFailed",
			"You do not own this business."
		)

		return
	end

	if stand:GetAttribute(
		"IsBeingEdited"
	) == true then
		sendFailure(
			player,
			"EditFailed",
			"This business is already being edited."
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
		businessId
	)

	closeStand(
		stand,
		plot
	)

	interactionResultRemote:FireClient(
		player,
		"BeginEdit",
		stand:GetPivot(),
		businessId
	)
end

local function beginRemoveConfirmation(
	player: Player,
	businessId: string
)
	if activeEdits[player] then
		sendFailure(
			player,
			"RemoveFailed",
			"Finish editing before removing the stand."
		)

		return
	end

	local plot =
		getPlayerPlot(player)

	if not plot then
		sendFailure(
			player,
			"RemoveFailed",
			"Your plot could not be found."
		)

		return
	end

	local stand =
		findOwnedBusinessById(
			player,
			plot,
			businessId
		)

	if not stand then
		sendFailure(
			player,
			"RemoveFailed",
			"Your business could not be found."
		)

		return
	end

	if not playerOwnsStand(
		player,
		stand,
		plot
	) then
		sendFailure(
			player,
			"RemoveFailed",
			"You do not own this business."
		)

		return
	end

	pendingRemovals[player] = {
		stand = stand,
		plot = plot,
		expiresAt =
			time()
			+ REMOVE_CONFIRMATION_TIMEOUT,
	}

	interactionResultRemote:FireClient(
		player,
		"ShowRemoveConfirmation",
		nil,
		businessId
	)
end

local function confirmRemoval(
	player: Player,
	businessId: string
)
	local request =
		pendingRemovals[player]

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

	local storedBusinessId =
		stand:GetAttribute("BusinessId")
		or stand.Name

	if storedBusinessId ~= businessId then
		sendFailure(
			player,
			"RemoveFailed",
			"The selected business changed."
		)

		return
	end

	if not stand.Parent
		or not plot.Parent
		or not playerOwnsStand(
			player,
			stand,
			plot
		) then

		sendFailure(
			player,
			"RemoveFailed",
			"The business could not be found."
		)

		return
	end

	closeStand(
		stand,
		plot
	)

	task.wait()

	local removedBusinessType =
	getBusinessType(
		stand
	)

local removedBusinessConfig =
	removedBusinessType
	and BusinessConfig[
		removedBusinessType
	]

local removedDisplayName =
	removedBusinessConfig
	and removedBusinessConfig.DisplayName
	or "Business"

	if stand.Parent then
		stand:Destroy()
	end

	local placedBusinesses =
		getPlacedBusinesses(plot)

	local hasRemainingStarterBusiness =
	false

if placedBusinesses then

	for _, child in
		placedBusinesses:GetChildren() do

		if not child:IsA(
			"Model"
		) then

			continue
		end

		local businessType =
			getBusinessType(
				child
			)

		if businessType
			== "LemonadeStand" then

			hasRemainingStarterBusiness =
				true

			break
		end
	end
end


plot:SetAttribute(
	"StarterBusinessPlaced",
	hasRemainingStarterBusiness
)

	clearPlayerInteractionState(player)

	interactionResultRemote:FireClient(
	player,
	"Removed",
	`{removedDisplayName} removed.`,
	businessId
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

requestEditRemote.OnServerEvent:Connect(function(
	player: Player,
	businessId: string
)
	if typeof(businessId) ~= "string"
		or businessId == "" then

		interactionResultRemote:FireClient(
			player,
			"EditFailed",
			"The business could not be identified."
		)

		return
	end

	beginEditing(
		player,
		businessId
	)
end)

requestRemoveRemote.OnServerEvent:Connect(function(
	player: Player,
	confirmed: boolean,
	businessId: string
)
	if typeof(confirmed) ~= "boolean"
		or typeof(businessId) ~= "string"
		or businessId == "" then

		sendFailure(
			player,
			"RemoveFailed",
			"The removal request was invalid."
		)

		return
	end

	if confirmed then
		confirmRemoval(
			player,
			businessId
		)
	else
		beginRemoveConfirmation(
			player,
			businessId
		)
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