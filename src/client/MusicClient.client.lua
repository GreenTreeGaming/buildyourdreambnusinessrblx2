local SoundService =
	game:GetService("SoundService")

local bgmFolder =
	SoundService:WaitForChild("BGM")

local random =
	Random.new()

local songs = {}

for _, child in bgmFolder:GetChildren() do
	if child:IsA("Sound") then
		table.insert(
			songs,
			child
		)
	end
end

if #songs == 0 then
	warn("No songs found in SoundService.BGM")
	return
end

local function shuffle(
	list: {Sound}
)
	for index = #list, 2, -1 do
		local swapIndex =
			random:NextInteger(
				1,
				index
			)

		list[index],
		list[swapIndex] =
			list[swapIndex],
			list[index]
	end
end

while true do
	shuffle(
		songs
	)

	for _, song in songs do
		song.Looped =
			false

		song.TimePosition =
			0

		song:Play()

		song.Ended:Wait()
	end
end