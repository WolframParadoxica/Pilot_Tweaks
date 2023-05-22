local mod = modApi:getCurrentMod()
local path = mod_loader.mods[modApi.currentMod].scriptPath
local customAnim = require(path .."/customAnim")

ANIMS.SmokePreview = Animation:new{
	Image = "combat/icons/icon_smoke_glow.png",
	PosX = -13, PosY = 12,
	Time = 0.15,
	Loop = true,
	NumFrames = 1
}

Passive_HealingSmoke = Passive_HealingSmoke:new{
	Upgrades = 1,
	UpgradeCost = {2},
}

Passive_HealingSmoke_A = Passive_HealingSmoke:new{
	TipImage = {
		Unit = Point(2,3),
		Target = Point(2,3),
		Enemy1 = Point(2,1),
		Enemy2 = Point(1,3),
	}
}

function Passive_HealingSmoke_A:GetSkillEffect(p1, p2)
	local ret = SkillEffect()
	local dam = SpaceDamage(Point(2,1),0)
	dam.iSmoke = 1
	if p1 == Point(2,3) then
		ret:AddDamage(dam)
		dam.loc = Point(1,3)
		ret:AddDamage(dam)
	end
	return ret
end

EXCL = {
    "GetAmbience", 
    "GetBonusStatus", 
    "BaseUpdate", 
    "UpdateMission", 
    "GetCustomTile", 
    "GetDamage", 
    "GetTurnLimit", 
    "BaseObjectives",
    "UpdateObjectives",
} 

for i,v in pairs(Mission) do 
    if type(v) == 'function' then 
        local oldfn = v 
        Mission[i] = function(...) 
            if not list_contains(_G["EXCL"], i) then 
                if i == "IsEnvironmentEffect" then
					GetCurrentMission().DeploymentBegun = true
				end
            end 
            return oldfn(...) 
        end 
    end 
end

local function SmokeAnim(mission)
	if not modApi.deployment.isDeploymentPhase(self) then return end
	mission.DeploymentBegun = false or mission.DeploymentBegun
	
	local deploysmokeflag = false
	for i = 0,2 do
		if Board:GetPawn(i):IsWeaponPowered("Passive_HealingSmoke_A") then
			deploysmokeflag = true
		end
	end
	if not deploysmokeflag then return end

	if modApi.deployment.isDeploymentPhase(self) and not mission.DeploymentBegun then
		for k,v in ipairs(Board) do
			local unit = Board:GetPawn(v)
			if unit and unit:GetTeam() ~= TEAM_PLAYER and unit:GetDefaultFaction() ~= FACTION_BOTS then
				customAnim:add(v, "SmokePreview")
			end
		end
	end
	if mission.DeploymentBegun then 
		for k,v in ipairs(Board) do
			local unit = Board:GetPawn(v)
			if unit and unit:GetTeam() ~= TEAM_PLAYER and unit:GetDefaultFaction() ~= FACTION_BOTS then
				customAnim:rem(v, "SmokePreview")
			end
		end
	end
end
local function DeploySmoke(pawnId)
	local pawn = Board:GetPawn(pawnId)
	local deploysmokeflag = false
	for i = 0,2 do
		if Board:GetPawn(i):IsWeaponPowered("Passive_HealingSmoke_A") then
			deploysmokeflag = true
		end
	end
	if not deploysmokeflag then return end
	
	local dam = SpaceDamage(Point(-1,-1),0)
	dam.iSmoke = 1
	if GetCurrentMission().deployment[(pawnId+1)%3].state ~= 4 and GetCurrentMission().deployment[(pawnId+2)%3].state ~= 4 then
		for k,v in ipairs(Board) do
			local unit = Board:GetPawn(v)
			if unit and unit:GetTeam() ~= TEAM_PLAYER and unit:GetDefaultFaction() ~= FACTION_BOTS then
				dam.loc = v
				Board:DamageSpace(dam)
			end
		end
	end
end

local function DeploySmokeVolcano(prevMission, nextMission)
	modApi:scheduleHook(3500, function()
		if Game == nil then return end
		local deploysmokeflag = false
		for i = 0,2 do
			if Board:GetPawn(i):IsWeaponPowered("Passive_HealingSmoke_A") then
				deploysmokeflag = true
			end
		end
		if not deploysmokeflag then return end
			local Mech = Game:GetPawn(0)
			modApi:conditionalHook(
				function()
					return Game == nil or (Mech ~= nil and Mech:GetSpace() ~= Point(-1,-1) and not Mech:IsBusy())
				end,
				function()
					if Mech ~= nil then
						local dam = SpaceDamage(0)
						dam.iSmoke = 1
						for k,v in ipairs(Board) do
							local unit = Board:GetPawn(v)
							if unit and unit:GetTeam() ~= TEAM_PLAYER and unit:GetDefaultFaction() ~= FACTION_BOTS then
								dam.loc = v
								Board:DamageSpace(dam)
							end
						end
					end
				end
			)
	end)
end

local function EVENT_onModsLoaded() --This function will run when the mod is loaded
	modApi:setText("Passive_HealingSmoke_Upgrade1", "Morning Haze")
	modApi:setText("Passive_HealingSmoke_A_UpgradeDescription", "On deployment, add Smoke to all Vek")
	modApi:addMissionUpdateHook(SmokeAnim)
	modApi:addMissionNextPhaseCreatedHook(DeploySmokeVolcano)
end
modApi.events.onPawnLanded:subscribe(DeploySmoke)
modApi.events.onModsLoaded:subscribe(EVENT_onModsLoaded)