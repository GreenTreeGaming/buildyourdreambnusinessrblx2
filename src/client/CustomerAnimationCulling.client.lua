-- Customer walk animations are intentionally never culled.
--
-- CustomerManager.server.lua owns the walking animation and
-- already starts/stops it based on actual NPC movement.
--
-- Previously this client script stopped Movement-priority
-- AnimationTracks for distant/off-screen NPCs. That could race
-- against the server animation controller and occasionally leave
-- a physically moving customer with no walk animation.
--
-- Keeping this file as a no-op prevents old references to the
-- script from breaking while ensuring all customers can animate.

print(
	"Customer animation culling disabled; customer animations always enabled."
)