local mod = modApi:getCurrentMod()
local path = mod_loader.mods[modApi.currentMod].scriptPath
local customAnim = require(path .."/customAnim")

--change the description of the pilot skill hover text
local oldGetSkillInfo = GetSkillInfo
function GetSkillInfo(skill)
	if skill == "Deploy_Anywhere"    then
		return PilotSkill("Preemptive Strike", "Deploy anywhere on the map, damaging adjacent enemies and shielding adjacent friendly non-Mech units.")
	end
	return oldGetSkillInfo(skill)
end

--create custom animation for the static imagemark shield icon
ANIMS.ShieldPreview = Animation:new{
	Image = "combat/icons/icon_shield_glow.png",
	PosX = -13, PosY = 12,
	Time = 0.15,
	Loop = true,
	NumFrames = 1
}

--this section detects the event that triggers instantly when End Turn or Confirm is pressed
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

local function ShieldAnim(mission)
	if not modApi.deployment.isDeploymentPhase(self) then return end
	mission.DeploymentBegun = false or mission.DeploymentBegun
	--create a list to hold the previous set of adjacent tiles when the player is changing deployment spots of the pilot
	mission.PrevGanaDeploySquares = mission.PrevGanaDeploySquares or {Point(-1,-1),Point(-1,-1),Point(-1,-1),Point(-1,-1)}
	local j = -1
	for i = 0,2 do
		local pawn = Game:GetPawn(i)
		if pawn and pawn:IsAbility("Deploy_Anywhere") then
			j = i
		end
	end
	--exit if pilot of interest not found
	if j == -1 then return end
	if modApi.deployment.isDeploymentPhase(self) and Board:IsValid(Game:GetPawn(j):GetSpace()) and not mission.DeploymentBegun then
		local point = Game:GetPawn(j):GetSpace()
		--if the pilot changes location, erase all the prior shield marks
		if mission.PrevGanaDeploySquares[1]+DIR_VECTORS[2]~=point then
			for i = 1,4 do
				customAnim:rem(mission.PrevGanaDeploySquares[i], "ShieldPreview")
			end
		end
		for i = 0, 3 do
			local curr = point + DIR_VECTORS[i]
			--update the list with the new adjacent tiles
			mission.PrevGanaDeploySquares[i+1] = curr
			if Board:IsPawnSpace(curr) and Board:GetPawn(curr):GetTeam() == TEAM_PLAYER and not Board:GetPawn(curr):IsMech() then
				customAnim:add(curr, "ShieldPreview")
			end
		end
	end
	--erase shield marks once the player clicks Confirm
	for i = 1,4 do
		if mission.DeploymentBegun then customAnim:rem(mission.PrevGanaDeploySquares[i], "ShieldPreview") end
	end
end

--this part does the actual shielding
local function GanaShield(pawnId)
	local pawn = Board:GetPawn(pawnId)
	if pawn and pawn:IsAbility("Deploy_Anywhere") then
		local point = pawn:GetSpace()
		for i = 0, 3 do
			local curr = point + DIR_VECTORS[i]
			if Board:IsPawnSpace(curr) and Board:GetPawn(curr):GetTeam() == TEAM_PLAYER and not Board:GetPawn(curr):IsMech() then
				Board:AddShield(curr)
			end
		end
	end
end

local function EVENT_onModsLoaded() --This function will run when the mod is loaded
	modApi:addMissionUpdateHook(ShieldAnim)
end
modApi.events.onPawnLanded:subscribe(GanaShield)
modApi.events.onModsLoaded:subscribe(EVENT_onModsLoaded)
