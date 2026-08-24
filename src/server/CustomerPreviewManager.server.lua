local ReplicatedStorage =
	game:GetService("ReplicatedStorage")

local ServerStorage =
	game:GetService("ServerStorage")


local NPC_FOLDER_NAME =
	"NPCs"

local PREVIEW_MODEL_NAME =
	"CustomerPreviewModel"


local npcFolder =
	ServerStorage:WaitForChild(
		NPC_FOLDER_NAME
	)


local function getPreviewSource(): Model?

	for _, child in
		npcFolder:GetChildren() do

		if child:IsA("Model") then
			return child
		end
	end


	return nil
end


local function stripServerOnlyObjects(
	model: Model
)

	for _, descendant in
		model:GetDescendants() do

		if descendant:IsA("Script")
			or descendant:IsA("LocalScript") then

			descendant:Destroy()

			continue
		end


		if descendant:IsA(
			"ParticleEmitter"
		)
			or descendant:IsA(
				"Trail"
			)
			or descendant:IsA(
				"Beam"
			) then

			descendant.Enabled =
				false
		end


		if descendant:IsA("BasePart") then

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


local function createCustomerPreview()

	local oldPreview =
		ReplicatedStorage:FindFirstChild(
			PREVIEW_MODEL_NAME
		)


	if oldPreview then
		oldPreview:Destroy()
	end


	local source =
		getPreviewSource()


	if not source then

		warn(
			"[CustomerPreviewManager] No customer Model found in ServerStorage.NPCs."
		)

		return
	end


	local preview =
		source:Clone()


	preview.Name =
		PREVIEW_MODEL_NAME


	stripServerOnlyObjects(
		preview
	)


	preview.Parent =
		ReplicatedStorage
end


createCustomerPreview()