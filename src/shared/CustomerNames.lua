local CustomerNames = {}


local random =
	Random.new()


--==================================================
-- NAMES
--==================================================

local FIRST_NAMES = {
	"Alex",
	"Andrew",
	"Anna",
	"Avery",
	"Ben",
	"Blake",
	"Brandon",
	"Brooke",
	"Cameron",
	"Charlie",
	"Chloe",
	"Chris",
	"Daniel",
	"David",
	"Dylan",
	"Ella",
	"Emily",
	"Emma",
	"Ethan",
	"Evan",
	"Grace",
	"Hailey",
	"Hannah",
	"Henry",
	"Isabella",
	"Jack",
	"Jacob",
	"Jake",
	"James",
	"Jason",
	"Jordan",
	"Josh",
	"Julia",
	"Kayla",
	"Kevin",
	"Lauren",
	"Leo",
	"Liam",
	"Lily",
	"Logan",
	"Lucas",
	"Madison",
	"Mason",
	"Matthew",
	"Maya",
	"Mia",
	"Michael",
	"Natalie",
	"Nathan",
	"Nick",
	"Noah",
	"Olivia",
	"Owen",
	"Ryan",
	"Sam",
	"Sarah",
	"Sofia",
	"Sophie",
	"Taylor",
	"Tyler",
	"William",
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
-- PUBLIC
--==================================================

function CustomerNames.GetRandomFirstName(): string
	return FIRST_NAMES[
		random:NextInteger(
			1,
			#FIRST_NAMES
		)
	]
end


function CustomerNames.GetRandomLastName(): string
	return LAST_NAMES[
		random:NextInteger(
			1,
			#LAST_NAMES
		)
	]
end


function CustomerNames.GetRandomName(): string
	local firstName =
		CustomerNames.GetRandomFirstName()

	local lastName =
		CustomerNames.GetRandomLastName()


	return `{firstName} {lastName}`
end


return CustomerNames