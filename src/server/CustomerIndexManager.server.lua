local Players =
	game:GetService("Players")

local ReplicatedStorage =
	game:GetService("ReplicatedStorage")

local ServerStorage =
	game:GetService("ServerStorage")


local DataService =
	require(
		script.Parent
			:WaitForChild("Services")
			:WaitForChild("DataService")
	)


local CustomerTypes =
	require(
		ReplicatedStorage
			:WaitForChild("Shared")
			:WaitForChild("CustomerTypes")
	)


local remotes =
	ReplicatedStorage:WaitForChild(
		"Remotes"
	)


--==================================================
-- PREVIEW MODEL
--==================================================

local npcFolder =
	ServerStorage:WaitForChild(
		"NPCs"
	)


local PREVIEW_MODEL_NAME =
	"CustomerPreviewModel"


local function getPreviewSource(): Model?

	for _, child in
		npcFolder:GetChildren() do

		if not child:IsA("Model") then
			continue
		end


		if not child:FindFirstChildOfClass(
			"Humanoid"
		) then

			continue
		end


		return child
	end


	return nil
end


local function preparePreviewModel(
	model: Model
)

	for _, descendant in
		model:GetDescendants() do

		if descendant:IsA("Script")
			or descendant:IsA(
				"LocalScript"
			) then

			descendant:Destroy()

			continue
		end


		if descendant:IsA(
			"BillboardGui"
		)
			or descendant:IsA(
				"SurfaceGui"
			) then

			descendant:Destroy()

			continue
		end


		if descendant:IsA(
			"BasePart"
		) then

			descendant.Anchored =
				true

			descendant.CanCollide =
				false

			descendant.CanTouch =
				false

			descendant.CanQuery =
				false
		end
	end
end


local function createPreviewModel()

	local existing =
		ReplicatedStorage:FindFirstChild(
			PREVIEW_MODEL_NAME
		)


	if existing then

		existing:Destroy()
	end


	local source =
		getPreviewSource()


	if not source then

		warn(
			"[CustomerIndex] No valid NPC model found in ServerStorage.NPCs."
		)

		return
	end


	local preview =
		source:Clone()


	preview.Name =
		PREVIEW_MODEL_NAME


	preparePreviewModel(
		preview
	)


	preview.Parent =
		ReplicatedStorage
end


createPreviewModel()


--==================================================
-- REMOTES
--==================================================

local getCustomerIndexState =
	remotes:FindFirstChild(
		"GetCustomerIndexState"
	)


if not getCustomerIndexState then

	getCustomerIndexState =
		Instance.new(
			"RemoteFunction"
		)

	getCustomerIndexState.Name =
		"GetCustomerIndexState"

	getCustomerIndexState.Parent =
		remotes
end


local customerVisitUpdated =
	remotes:FindFirstChild(
		"CustomerVisitUpdated"
	)


if not customerVisitUpdated then

	customerVisitUpdated =
		Instance.new(
			"RemoteEvent"
		)

	customerVisitUpdated.Name =
		"CustomerVisitUpdated"

	customerVisitUpdated.Parent =
		remotes
end


--==================================================
-- STATE
--==================================================

local CUSTOMER_ORDER = {
	"Regular",
	"Generous",
	"Rich",
	"VIP",
	"Celebrity",
	"Influencer",
	"Billionaire",
	"Golden",
}


local function buildState(
	player: Player
)

	local visits =
		DataService.GetCustomerVisits(
			player
		)


	local state = {}


	for order, customerType in
		CUSTOMER_ORDER do

		local config =
			CustomerTypes.Types[
				customerType
			]


		if not config then
			continue
		end


		local amount =
			visits[
				customerType
			]
			or 0


		table.insert(
			state,
			{
				TypeName =
					customerType,

				DisplayName =
					config.DisplayName
						or customerType,

				Order =
					order,

				Visits =
					amount,

				Discovered =
					amount > 0,
			}
		)
	end


	return state
end


(
	getCustomerIndexState
		:: RemoteFunction
).OnServerInvoke =
	function(
		player: Player
	)

		if not Players:FindFirstChild(
			player.Name
		) then

			return {}
		end


		local profile =
			DataService.WaitForProfile(
				player,
				10
			)


		if not profile then
			return {}
		end


		return buildState(
			player
		)
	end