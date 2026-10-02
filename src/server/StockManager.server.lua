local ReplicatedStorage =
	game:GetService("ReplicatedStorage")

local Workspace =
	game:GetService("Workspace")


local StockService =
	require(
		script.Parent
			:WaitForChild("Services")
			:WaitForChild("StockService")
	)


local plotsFolder =
	Workspace:WaitForChild(
		"Plots"
	)


local watchedFolders: {
	[Instance]: boolean
} =
	setmetatable(
		{},
		{
			__mode = "k",
		}
	)


local watchedPlots: {
	[Model]: boolean
} =
	setmetatable(
		{},
		{
			__mode = "k",
		}
	)


--==================================================
-- STANDS
--==================================================

local function initializeStand(
	instance: Instance
)

	if not instance:IsA(
		"Model"
	) then

		return
	end


	task.defer(
		function()

			if not instance.Parent then
				return
			end


			StockService.InitializeStand(
				instance
			)
		end
	)
end


--==================================================
-- PLACED BUSINESSES
--==================================================

local function watchPlacedBusinesses(
	folder: Instance
)

	if watchedFolders[
		folder
	] then

		return
	end


	watchedFolders[
		folder
	] =
		true


	for _, child in
		folder:GetChildren() do

		initializeStand(
			child
		)
	end


	folder.ChildAdded:Connect(
		initializeStand
	)
end


--==================================================
-- PLOTS
--==================================================

local function watchPlot(
	plot: Model
)

	if watchedPlots[
		plot
	] then

		return
	end


	watchedPlots[
		plot
	] =
		true


	local placedBusinesses =
		plot:FindFirstChild(
			"PlacedBusinesses"
		)


	if placedBusinesses then

		watchPlacedBusinesses(
			placedBusinesses
		)
	end


	plot.ChildAdded:Connect(
		function(
			child: Instance
		)

			if child.Name
				== "PlacedBusinesses" then

				watchPlacedBusinesses(
					child
				)
			end
		end
	)
end


for _, child in
	plotsFolder:GetChildren() do

	if child:IsA(
		"Model"
	) then

		watchPlot(
			child
		)
	end
end


plotsFolder.ChildAdded:Connect(
	function(
		child: Instance
	)

		if child:IsA(
			"Model"
		) then

			watchPlot(
				child
			)
		end
	end
)


print(
	"StockManager started."
)