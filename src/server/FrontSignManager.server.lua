local Players =
	game:GetService("Players")

local ReplicatedStorage =
	game:GetService("ReplicatedStorage")

local Workspace =
	game:GetService("Workspace")


local FormatNumber =
	require(
		ReplicatedStorage
			:WaitForChild("Shared")
			:WaitForChild("FormatNumber")
	)


local plotsFolder =
	Workspace:WaitForChild("Plots")

local DataService =
	require(
		script.Parent
			:WaitForChild("Services")
			:WaitForChild("DataService")
	)


local UPDATE_INTERVAL =
	0.5


local DEFAULT_RATING =
	3

local DEFAULT_REPUTATION_LEVEL =
	1


type SignReferences = {
	SurfaceGui: SurfaceGui,
	Frame: Frame,

	PlayerImg: ImageLabel,
	PlayerName: TextLabel,

	ReputationLevel: TextLabel,
	CustomersServed: TextLabel,

	Rating: TextLabel,

	Stars: {
		ImageLabel
	},
}


local signCache: {
	[Model]: SignReferences
} = {}


local thumbnailCache: {
	[number]: string
} = {}


--==================================================
-- SIGN REFERENCES
--==================================================

local function getSignReferences(
	plot: Model
): SignReferences?

	local cached =
		signCache[plot]

	if cached then
		return cached
	end


	local frontSign =
		plot:FindFirstChild(
			"FrontSign"
		)

	if not frontSign
		or not frontSign:IsA("Folder") then

		warn(
			`{plot:GetFullName()} is missing FrontSign.`
		)

		return nil
	end


	local board =
		frontSign:FindFirstChild(
			"Board"
		)

	if not board
		or not board:IsA("BasePart") then

		warn(
			`{frontSign:GetFullName()} is missing Board.`
		)

		return nil
	end


	local surfaceGui =
		board:FindFirstChildOfClass(
			"SurfaceGui"
		)

	if not surfaceGui then
		warn(
			`{board:GetFullName()} is missing a SurfaceGui.`
		)

		return nil
	end


	local frame =
		surfaceGui:FindFirstChild(
			"Frame"
		)

	if not frame
		or not frame:IsA("Frame") then

		warn(
			`{surfaceGui:GetFullName()} is missing Frame.`
		)

		return nil
	end


	local playerImg =
		frame:FindFirstChild(
			"PlayerImg"
		)

	local playerName =
		frame:FindFirstChild(
			"PlayerName"
		)

	local reputationLevel =
		frame:FindFirstChild(
			"ReputationLevel"
		)

	local customersServed =
		frame:FindFirstChild(
			"CustomersServed"
		)

	local starsPanel =
		frame:FindFirstChild(
			"Stars"
		)


	if not playerImg
		or not playerImg:IsA("ImageLabel")
		or not playerName
		or not playerName:IsA("TextLabel")
		or not reputationLevel
		or not reputationLevel:IsA("TextLabel")
		or not customersServed
		or not customersServed:IsA("TextLabel")
		or not starsPanel
		or not starsPanel:IsA("Frame") then

		warn(
			`{frame:GetFullName()} has an invalid front sign hierarchy.`
		)

		return nil
	end


	local rating =
		starsPanel:FindFirstChild(
			"Rating"
		)

	local starsFrame =
		starsPanel:FindFirstChild(
			"Frame"
		)


	if not rating
		or not rating:IsA("TextLabel")
		or not starsFrame
		or not starsFrame:IsA("Frame") then

		warn(
			`{starsPanel:GetFullName()} has an invalid Stars hierarchy.`
		)

		return nil
	end


	local stars: {
		ImageLabel
	} = {}


	for index = 1, 5 do
		local star =
			starsFrame:FindFirstChild(
				`Star{index}`
			)

		if not star
			or not star:IsA("ImageLabel") then

			warn(
				`{starsFrame:GetFullName()} is missing Star{index}.`
			)

			return nil
		end


		stars[index] =
			star
	end


	local references: SignReferences = {
		SurfaceGui = surfaceGui,
		Frame = frame,

		PlayerImg = playerImg,
		PlayerName = playerName,

		ReputationLevel = reputationLevel,
		CustomersServed = customersServed,

		Rating = rating,

		Stars = stars,
	}


	signCache[plot] =
		references


	return references
end


--==================================================
-- PLAYER
--==================================================

local function getPlotOwner(
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


local function getPlayerThumbnail(
	player: Player
): string

	local cached =
		thumbnailCache[
			player.UserId
		]

	if cached then
		return cached
	end


	local success,
		content =
		pcall(
			function()
				local image =
					Players:GetUserThumbnailAsync(
						player.UserId,

						Enum.ThumbnailType
							.HeadShot,

						Enum.ThumbnailSize
							.Size420x420
					)


				return image
			end
		)


	if not success
		or typeof(content)
			~= "string" then

		return ""
	end


	thumbnailCache[
		player.UserId
	] = content


	return content
end


--==================================================
-- CUSTOMERS SERVED
--==================================================

local function getCustomersServed(
	player: Player
): number

	local profile =
		DataService.GetProfile(
			player
		)


	if not profile then
		return 0
	end


	local quests =
		profile.Quests


	if typeof(quests)
		~= "table" then

		return 0
	end


	local stats =
		quests.Stats


	if typeof(stats)
		~= "table" then

		return 0
	end


	local totalSales =
		stats.TotalSales


	if typeof(totalSales)
			~= "number"
		or totalSales ~= totalSales
		or totalSales == math.huge
		or totalSales == -math.huge then

		return 0
	end


	return math.max(
		0,
		math.floor(
			totalSales
		)
	)
end

--==================================================
-- STARS
--==================================================

local function updateStars(
	references: SignReferences,
	rating: number
)

	rating =
		math.clamp(
			rating,
			0,
			5
		)


	local roundedStars =
		math.clamp(
			math.floor(
				rating + 0.5
			),

			0,
			5
		)


	for index, star in
		references.Stars do

		local filled =
			index <= roundedStars


		star.ImageTransparency =
			filled
				and 0
				or 0.65
	end
end


--==================================================
-- EMPTY SIGN
--==================================================

local function clearSign(
	plot: Model
)

	local references =
		getSignReferences(
			plot
		)

	if not references then
		return
	end


	references.PlayerImg.Image =
		""


	references.PlayerName.Text =
		"Unclaimed Plot"


	references.ReputationLevel.Text =
		"Reputation Level: --"


	references.CustomersServed.Text =
		"Customers Served: 0"


	references.Rating.Text =
		"-- / 5"


	updateStars(
		references,
		0
	)
end


--==================================================
-- UPDATE SIGN
--==================================================

local function updateSign(
	plot: Model
)

	local references =
		getSignReferences(
			plot
		)

	if not references then
		return
	end


	local owner =
		getPlotOwner(
			plot
		)


	if not owner then
		clearSign(
			plot
		)

		return
	end


	-- Player information.
	references.PlayerName.Text =
	owner.Name


	local thumbnail =
		getPlayerThumbnail(
			owner
		)


	if thumbnail ~= "" then
		references.PlayerImg.Image =
			thumbnail
	end


	-- Customers served.
	local customersServed =
	getCustomersServed(
		owner
	)


	references.CustomersServed.Text =
		`Customers Served: {FormatNumber.Compact(customersServed)}`


	-- Reputation.
	local reputationLevel =
		plot:GetAttribute(
			"ReputationLevel"
		)


	if typeof(reputationLevel)
		~= "number" then

		reputationLevel =
			DEFAULT_REPUTATION_LEVEL
	end


	reputationLevel =
		math.max(
			1,
			math.floor(
				reputationLevel
			)
		)


	references.ReputationLevel.Text =
		`Reputation Level: {reputationLevel}`


	local rating =
		plot:GetAttribute(
			"ReputationRating"
		)


	if typeof(rating)
		~= "number" then

		rating =
			DEFAULT_RATING
	end


	rating =
		math.clamp(
			rating,
			0,
			5
		)


	references.Rating.Text =
		string.format(
			"%.1f / 5",
			rating
		)


	updateStars(
		references,
		rating
	)
end


--==================================================
-- PLOT SETUP
--==================================================

local function setupPlot(
	plot: Model
)

	-- Validate/cache its sign now.
	getSignReferences(
		plot
	)


	plot:GetAttributeChangedSignal(
		"OwnerUserId"
	):Connect(function()

		updateSign(
			plot
		)
	end)


	plot:GetAttributeChangedSignal(
		"ReputationRating"
	):Connect(function()

		updateSign(
			plot
		)
	end)


	plot:GetAttributeChangedSignal(
		"ReputationLevel"
	):Connect(function()

		updateSign(
			plot
		)
	end)


	updateSign(
		plot
	)
end


for _, plot in
	plotsFolder:GetChildren() do

	if plot:IsA("Model") then
		setupPlot(
			plot
		)
	end
end


plotsFolder.ChildAdded:Connect(
	function(
		child: Instance
	)

		if not child:IsA("Model") then
			return
		end


		setupPlot(
			child
		)
	end
)


--==================================================
-- LIVE CUSTOMER COUNT
--==================================================

task.spawn(function()

	while true do

		for _, plot in
			plotsFolder:GetChildren() do

			if not plot:IsA("Model") then
				continue
			end


			if getPlotOwner(
				plot
			) then

				updateSign(
					plot
				)
			end
		end


		task.wait(
			UPDATE_INTERVAL
		)
	end
end)