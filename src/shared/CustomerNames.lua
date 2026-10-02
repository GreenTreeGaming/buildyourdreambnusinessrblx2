local CollectionService =
	game:GetService("CollectionService")


local CustomerNames = {}


local random =
	Random.new()


--==================================================
-- NAMES
--==================================================

local BOY_FIRST_NAMES = {
	"Alex",
	"Andrew",
	"Ben",
	"Blake",
	"Brandon",
	"Cameron",
	"Charlie",
	"Chris",
	"Daniel",
	"David",
	"Dylan",
	"Ethan",
	"Evan",
	"Henry",
	"Jack",
	"Jacob",
	"Jake",
	"James",
	"Jason",
	"Jordan",
	"Josh",
	"Kevin",
	"Leo",
	"Liam",
	"Logan",
	"Lucas",
	"Mason",
	"Matthew",
	"Michael",
	"Nathan",
	"Nick",
	"Noah",
	"Owen",
	"Ryan",
	"Sam",
	"Tyler",
	"William",
}


local GIRL_FIRST_NAMES = {
	"Anna",
	"Avery",
	"Brooke",
	"Chloe",
	"Ella",
	"Emily",
	"Emma",
	"Grace",
	"Hailey",
	"Hannah",
	"Isabella",
	"Julia",
	"Kayla",
	"Lauren",
	"Lily",
	"Madison",
	"Maya",
	"Mia",
	"Natalie",
	"Olivia",
	"Sarah",
	"Sofia",
	"Sophie",
	"Taylor",
	"Zoe",
}


local LAST_NAMES = {
	"Adams",
	"Allen",
	"Anderson",
	"Baker",
	"Bennett",
	"Brooks",
	"Brown",
	"Campbell",
	"Carter",
	"Clark",
	"Collins",
	"Cook",
	"Cooper",
	"Davis",
	"Edwards",
	"Evans",
	"Foster",
	"Garcia",
	"Gray",
	"Green",
	"Hall",
	"Harris",
	"Hill",
	"Howard",
	"Hughes",
	"Jackson",
	"James",
	"Johnson",
	"Jones",
	"Kelly",
	"King",
	"Lee",
	"Lewis",
	"Martin",
	"Miller",
	"Mitchell",
	"Moore",
	"Morgan",
	"Morris",
	"Murphy",
	"Nelson",
	"Ortiz",
	"Parker",
	"Perez",
	"Phillips",
	"Price",
	"Reed",
	"Richardson",
	"Rivera",
	"Roberts",
	"Robinson",
	"Rodriguez",
	"Rogers",
	"Ross",
	"Scott",
	"Smith",
	"Stewart",
	"Taylor",
	"Thomas",
	"Thompson",
	"Turner",
	"Walker",
	"White",
	"Williams",
	"Wilson",
	"Wood",
	"Young",
}


--==================================================
-- INTERNAL
--==================================================

local function getRandomFrom(
	list: {string}
): string

	return list[
		random:NextInteger(
			1,
			#list
		)
	]
end


local function getGender(
	npc: Instance?
): string?

	if not npc then
		return nil
	end


	if CollectionService:HasTag(
		npc,
		"Boy"
	) then

		return "Boy"
	end


	if CollectionService:HasTag(
		npc,
		"Girl"
	) then

		return "Girl"
	end


	return nil
end


--==================================================
-- PUBLIC
--==================================================

function CustomerNames.GetRandomFirstName(
	npc: Instance?
): string

	local gender =
		getGender(
			npc
		)


	if gender == "Boy" then

		return getRandomFrom(
			BOY_FIRST_NAMES
		)
	end


	if gender == "Girl" then

		return getRandomFrom(
			GIRL_FIRST_NAMES
		)
	end


	-- Fallback in case an NPC somehow has
	-- neither tag.
	if random:NextNumber() < 0.5 then

		return getRandomFrom(
			BOY_FIRST_NAMES
		)
	end


	return getRandomFrom(
		GIRL_FIRST_NAMES
	)
end


function CustomerNames.GetRandomLastName(): string

	return getRandomFrom(
		LAST_NAMES
	)
end


function CustomerNames.GetRandomName(
	npc: Instance?
): string

	local firstName =
		CustomerNames.GetRandomFirstName(
			npc
		)


	local lastName =
		CustomerNames.GetRandomLastName()


	return `{firstName} {lastName}`
end


return CustomerNames