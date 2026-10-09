--==================================================
-- EXCLUSIVE UI MANAGER
-- Client-side ModuleScript
--==================================================

local ExclusiveUI = {}

local closeHandlers: {
	[string]: () -> ()
} = {}

local activeMenu: string? = nil

function ExclusiveUI.Register(
	menuName: string,
	closeHandler: () -> ()
)

	assert(type(menuName) == "string")
	assert(type(closeHandler) == "function")

	closeHandlers[menuName] = closeHandler

	return function()
		if closeHandlers[menuName] == closeHandler then
			closeHandlers[menuName] = nil
		end
	end
end


function ExclusiveUI.GetActive(): string?
	return activeMenu
end


function ExclusiveUI.IsBusy(): boolean
	return activeMenu ~= nil
end


function ExclusiveUI.Open(
	menuName: string
)

	if activeMenu == menuName then
		return
	end

	activeMenu = menuName

	for otherName, closeHandler in closeHandlers do
		if otherName == menuName then
			continue
		end

		local success, err = pcall(closeHandler)

		if not success then
			warn(
				"[ExclusiveUI] Failed to close",
				otherName,
				err
			)
		end
	end
end


function ExclusiveUI.Closed(
	menuName: string
)

	if activeMenu == menuName then
		activeMenu = nil
	end
end


return ExclusiveUI