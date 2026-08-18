local Players =
	game:GetService("Players")

local ReplicatedStorage =
	game:GetService("ReplicatedStorage")

local Workspace =
	game:GetService("Workspace")

local UpgradeService = require(
	script.Parent
		:WaitForChild("Services")
		:WaitForChild("UpgradeService")
)

local BusinessConfig =
	require(
		ReplicatedStorage
			:WaitForChild("Shared")
			:WaitForChild("BusinessConfig")
	)

local plotsFolder =
	Workspace:WaitForChild("Plots")

local remotes =
	ReplicatedStorage:FindFirstChild(
		"Remotes"
	)

if not remotes then
	remotes = Instance.new("Folder")
	remotes.Name = "Remotes"
	remotes.Parent = ReplicatedStorage
end

local function getOrCreateRemoteEvent(
	name: string
): RemoteEvent
	local existing =
		remotes:FindFirstChild(name)

	if existing then
		if not existing:IsA(
			"RemoteEvent"
		) then

			error(
				`ReplicatedStorage.Remotes.{name} must be a RemoteEvent.`
			)
		end

		return existing
	end

	local remote =
		Instance.new("RemoteEvent")

	remote.Name = name
	remote.Parent = remotes

	return remote
end

local function getOrCreateRemoteFunction(
	name: string
): RemoteFunction
	local existing =
		remotes:FindFirstChild(name)

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
		Instance.new("RemoteFunction")

	remote.Name = name
	remote.Parent = remotes

	return remote
end

local purchaseUpgradeRemote =
	getOrCreateRemoteEvent(
		"PurchaseUpgrade"
	)

local upgradeResultRemote =
	getOrCreateRemoteEvent(
		"UpgradeResult"
	)

local getUpgradeStateRemote =
	getOrCreateRemoteFunction(
		"GetUpgradeState"
	)

local function getBusinessType(
	instance: Model
): string?

	local businessType =
		instance:GetAttribute(
			"BusinessType"
		)


	if typeof(businessType) == "string"
		and BusinessConfig[businessType] then

		return businessType
	end


	for businessName in BusinessConfig do

		if instance.Name == businessName
			or string.match(
				instance.Name,
				`^{businessName}_`
			) then

			return businessName
		end
	end


	return nil
end


local function isSupportedBusiness(
	instance: Instance
): boolean

	if not instance:IsA("Model") then
		return false
	end


	return getBusinessType(
		instance
	) ~= nil
end

local function getPlayerFromPlot(
	plot: Model
): Player?
	local ownerUserId =
		plot:GetAttribute(
			"OwnerUserId"
		)

	if typeof(ownerUserId) ~= "number"
		or ownerUserId <= 0 then

		return nil
	end

	return Players:GetPlayerByUserId(
		ownerUserId
	)
end

local function applyUpgradesToStand(
	plot: Model,
	stand: Instance
)
	if not isSupportedBusiness(stand) then
	return
end

	local standModel: Model =
		stand :: Model

	local player =
		getPlayerFromPlot(plot)

	if not player then
		return
	end

	local function apply()
		if not standModel.Parent then
			return
		end

		UpgradeService.ApplyStandUpgrades(
			player,
			standModel
		)
	end

	if player:GetAttribute(
		"DataLoaded"
	) == true then

		apply()
		return
	end

	local connection

	connection =
		player:GetAttributeChangedSignal(
			"DataLoaded"
		):Connect(function()

			if player:GetAttribute(
				"DataLoaded"
			) ~= true then

				return
			end

			connection:Disconnect()
			apply()
		end)
end

local function watchPlot(
	plot: Model
)
	local placedBusinesses =
		plot:FindFirstChild(
			"PlacedBusinesses"
		)

	if not placedBusinesses then
		task.spawn(function()
			placedBusinesses =
				plot:WaitForChild(
					"PlacedBusinesses",
					15
				)

			if not placedBusinesses then
				return
			end

			watchPlot(plot)
		end)

		return
	end

	placedBusinesses.ChildAdded:Connect(
		function(child)
			task.defer(
				applyUpgradesToStand,
				plot,
				child
			)
		end
	)

	for _, child in
		placedBusinesses:GetChildren() do

		task.defer(
			applyUpgradesToStand,
			plot,
			child
		)
	end
end

for _, plot in
	plotsFolder:GetChildren() do

	if plot:IsA("Model") then
		watchPlot(plot)
	end
end

plotsFolder.ChildAdded:Connect(function(
	child: Instance
)
	if child:IsA("Model") then
		watchPlot(child)
	end
end)

getUpgradeStateRemote.OnServerInvoke =
	function(
		player: Player,
		businessId: string,
		upgradeName: string
	)
		return UpgradeService.GetUpgradeState(
			player,
			businessId,
			upgradeName
		)
	end

purchaseUpgradeRemote.OnServerEvent:Connect(
	function(
		player: Player,
		businessId: string,
		upgradeName: string
	)
		local result =
			UpgradeService.PurchaseUpgrade(
				player,
				businessId,
				upgradeName
			)

		upgradeResultRemote:FireClient(
			player,
			result
		)
	end
)

print("UpgradeManager started.")