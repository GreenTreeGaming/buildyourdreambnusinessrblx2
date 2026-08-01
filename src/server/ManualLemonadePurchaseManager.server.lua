local Players = game:GetService("Players")
local ReplicatedStorage =
	game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local plotsFolder =
	Workspace:WaitForChild("Plots")

local remotes =
	ReplicatedStorage:WaitForChild("Remotes")

local BUSINESS_NAME = "LemonadeStand"
local DEFAULT_SALE_VALUE = 2
local DEFAULT_PURCHASE_COOLDOWN = 1

local promptConnections: {
	[ProximityPrompt]: RBXScriptConnection
} = {}

local promptCooldowns: {
	[ProximityPrompt]: number
} = {}

local manualSaleResultRemote =
	remotes:FindFirstChild(
		"ManualLemonadeSaleResult"
	)

if manualSaleResultRemote
	and not manualSaleResultRemote:IsA(
		"RemoteEvent"
	) then

	error(
		"ManualLemonadeSaleResult must be a RemoteEvent."
	)
end

if not manualSaleResultRemote then
	manualSaleResultRemote =
		Instance.new("RemoteEvent")

	manualSaleResultRemote.Name =
		"ManualLemonadeSaleResult"

	manualSaleResultRemote.Parent =
		remotes
end

local function getPlotFromStand(
	stand: Model
): Model?
	local current: Instance? = stand

	while current
		and current ~= plotsFolder do

		if current:IsA("Model")
			and current.Parent == plotsFolder then

			return current
		end

		current = current.Parent
	end

	return nil
end

local function getOwnerFromStand(
	stand: Model
): Player?
	local ownerUserId =
		stand:GetAttribute("OwnerUserId")

	if typeof(ownerUserId) ~= "number"
		or ownerUserId <= 0 then

		local plot =
			getPlotFromStand(stand)

		if plot then
			ownerUserId =
				plot:GetAttribute(
					"OwnerUserId"
				)
		end
	end

	if typeof(ownerUserId) ~= "number"
		or ownerUserId <= 0 then

		return nil
	end

	return Players:GetPlayerByUserId(
		ownerUserId
	)
end

local function getCashValue(
	player: Player
): IntValue?
	local leaderstats =
		player:FindFirstChild("leaderstats")

	if not leaderstats then
		return nil
	end

	local cash =
		leaderstats:FindFirstChild("Cash")

	if cash and cash:IsA("IntValue") then
		return cash
	end

	return nil
end

local function getSaleValue(
	stand: Model
): number
	local saleValue =
		stand:GetAttribute("SaleValue")

	if typeof(saleValue) ~= "number"
		or saleValue < 0 then

		return DEFAULT_SALE_VALUE
	end

	return math.max(
		0,
		math.floor(saleValue)
	)
end

local function getPromptCooldown(
	stand: Model
): number
	local cooldown =
		stand:GetAttribute(
			"ManualPurchaseCooldown"
		)

	if typeof(cooldown) ~= "number"
		or cooldown < 0 then

		return DEFAULT_PURCHASE_COOLDOWN
	end

	return cooldown
end

local function isLemonadePurchasePrompt(
	prompt: ProximityPrompt
): boolean
	if prompt:GetAttribute(
		"IsLemonadePurchasePrompt"
	) == true then

		return true
	end

	local actionText =
		string.lower(prompt.ActionText)

	local objectText =
		string.lower(prompt.ObjectText)

	return string.find(
		actionText,
		"lemonade",
		1,
		true
	) ~= nil
		or string.find(
			objectText,
			"lemonade",
			1,
			true
		) ~= nil
end

local function canUseStand(
	stand: Model
): boolean
	if not stand.Parent then
		return false
	end

	if stand:GetAttribute("StandUnavailable")
		== true then

		return false
	end

	if stand:GetAttribute("IsBeingEdited")
		== true then

		return false
	end

	return true
end

local function processPurchase(
	prompt: ProximityPrompt,
	stand: Model,
	buyer: Player
)
	if not canUseStand(stand) then
		return
	end

	local currentTime = time()
	local availableAt =
		promptCooldowns[prompt] or 0

	if currentTime < availableAt then
		return
	end

	local owner =
		getOwnerFromStand(stand)

	if not owner then
		warn(
			`Could not find the owner of {stand:GetFullName()}.`
		)

		return
	end

	local cash = getCashValue(owner)

	if not cash then
		warn(
			`Cash value was not found for {owner.Name}.`
		)

		return
	end

	local saleValue =
		getSaleValue(stand)

	local cooldown =
		getPromptCooldown(stand)

	promptCooldowns[prompt] =
		currentTime + cooldown

	cash.Value += saleValue

	-- Show the new sale UI to the buyer.
	manualSaleResultRemote:FireClient(
		buyer,
		stand,
		saleValue
	)

	-- Also show it to the owner when another player buys.
	if owner ~= buyer then
		manualSaleResultRemote:FireClient(
			owner,
			stand,
			saleValue
		)
	end
end

local function connectPrompt(
	stand: Model,
	prompt: ProximityPrompt
)
	if promptConnections[prompt] then
		return
	end

	if not isLemonadePurchasePrompt(prompt) then
		return
	end

	-- This attribute makes the intended prompt explicit
	-- when inspecting it in Studio.
	prompt:SetAttribute(
		"IsLemonadePurchasePrompt",
		true
	)

	promptConnections[prompt] =
		prompt.Triggered:Connect(function(
			playerWhoTriggered: Player
		)
			processPurchase(
				prompt,
				stand,
				playerWhoTriggered
			)
		end)

	prompt.Destroying:Connect(function()
		local connection =
			promptConnections[prompt]

		if connection then
			connection:Disconnect()
		end

		promptConnections[prompt] = nil
		promptCooldowns[prompt] = nil
	end)
end

local function connectStand(
	stand: Model
)
	if stand.Name ~= BUSINESS_NAME then
		return
	end

	for _, descendant in
		stand:GetDescendants() do

		if descendant:IsA(
			"ProximityPrompt"
		) then

			connectPrompt(
				stand,
				descendant
			)
		end
	end

	stand.DescendantAdded:Connect(function(
		descendant
	)
		if descendant:IsA(
			"ProximityPrompt"
		) then

			connectPrompt(
				stand,
				descendant
			)
		end
	end)
end

local function watchPlacedBusinesses(
	placedBusinesses: Instance
)
	for _, child in
		placedBusinesses:GetChildren() do

		if child:IsA("Model") then
			connectStand(child)
		end
	end

	placedBusinesses.ChildAdded:Connect(
		function(child)
			if child:IsA("Model") then
				task.defer(
					connectStand,
					child
				)
			end
		end
	)
end

local function watchPlot(
	plot: Model
)
	local placedBusinesses =
		plot:FindFirstChild(
			"PlacedBusinesses"
		)

	if placedBusinesses then
		watchPlacedBusinesses(
			placedBusinesses
		)

		return
	end

	task.spawn(function()
		local folder =
			plot:WaitForChild(
				"PlacedBusinesses",
				15
			)

		if folder then
			watchPlacedBusinesses(folder)
		end
	end)
end

for _, plot in plotsFolder:GetChildren() do
	if plot:IsA("Model") then
		watchPlot(plot)
	end
end

plotsFolder.ChildAdded:Connect(function(
	child
)
	if child:IsA("Model") then
		watchPlot(child)
	end
end)

print(
	"ManualLemonadePurchaseManager started."
)