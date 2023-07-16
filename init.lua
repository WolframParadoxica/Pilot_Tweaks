local mod = {
	id = "Pilot Tweaks",
	name = "Pilot Tweaks",
	version = "0.1",
	requirements = {},
	dependencies = { --This requests modApiExt from the mod loader
		modApiExt = "1.18", --We can get this by using the variable `modapiext`
	},
	modApiVersion = "2.9.2",
	--icon = "img/mod_icon.png"
}

local function init(self)
	require(self.scriptPath.."Prospero_Chasm")
	--require(self.scriptPath.."Prospero_Crack")
	require(self.scriptPath.."Gana_Shield")
end

function load(self, options, version)
	--why does this exist?!?!?!
end

return {
    id = "Pilot_Tweaks",
    name = "Paradoxica's Pilot Tweaks",
    version = "0.1",
    init = init
    load = load
}
