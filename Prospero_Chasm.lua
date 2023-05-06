local mod = modApi:getCurrentMod()
local path = mod_loader.mods[modApi.currentMod].scriptPath
local customAnim = require(path .."/customAnim")

--change the description of the pilot skill hover text
local oldGetSkillInfo = GetSkillInfo
function GetSkillInfo(skill)
	if skill == "Flying"    then
		return PilotSkill("Flying", "Mech gains Flying. On deployment, collapse a ground tile in front of self.")-- under and 
	end
	return oldGetSkillInfo(skill)
end

--create custom animation for the shattering icon for unoccupied tiles
ANIMS.ShatteringTileCentred = Animation:new{
	Image = "advanced/combat/icons/icon_shatter_anim.png",
	PosX = -13, PosY = 12,
	Time = 0.15,
	Loop = true,
	NumFrames = 7
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

--this part does the actual tile collapse
local function ProsperoChasm(pawnId)
	local pawn = Board:GetPawn(pawnId)
	local point = pawn:GetSpace()
	if pawn and pawn:IsAbility("Flying") then
		--grab the list of pylons for the final missions so we can avoid collapsing the tile under them
		local pylons = extract_table(Board:GetZone("pylons"))
	
		local dam = SpaceDamage(point,0)
		dam.iTerrain = TERRAIN_HOLE
		point = point + DIR_VECTORS[1]
		--the only defend mission that this can interfere with is the train mission. all the meridia missions with a track of some kind have non-stable units to defend. hence we only bother checking for train mission, which is the one most impacted by this prospero buff.
		--don't bother collapsing mountains (Vek obstacle), water/ice/cracks (insta-kill potential)
		while ((Board:IsPawnSpace(point) and Board:GetPawn(point):GetTeam() == TEAM_PLAYER and not Board:GetPawn(point):IsFlying()) or Board:IsBuilding(point) or Board:IsTerrain(point,TERRAIN_WATER) or Board:IsTerrain(point,TERRAIN_MOUNTAIN) or Board:IsTerrain(point,TERRAIN_ICE) or Board:IsTerrain(point,TERRAIN_HOLE) or Board:IsCracked(point) or (#pylons > 0 and list_contains(pylons, point)) or (Board:IsPawnSpace(Point(4,6)) and (Board:GetPawn(Point(4,6)):GetType() == "Train_Pawn" or Board:GetPawn(Point(4,6)):GetType() == "Train_Armored") and point.x == 4)) do
			point = point + DIR_VECTORS[1]
		end
		dam.loc = point
		Board:DamageSpace(dam)
		Game:TriggerSound("/props/ground_break_tile")
		GetCurrentMission().ProsperoChasmLoc = point
	end
end

-- duplicate function for anim hook that returns the point of collapse
local function ProsperoChasmDupe(pawnId)
	local pawn = Board:GetPawn(pawnId)
	local point = pawn:GetSpace()
	if pawn and pawn:IsAbility("Flying") then
		local pylons = extract_table(Board:GetZone("pylons"))
		point = point + DIR_VECTORS[1]
		while ((Board:IsPawnSpace(point) and Board:GetPawn(point):GetTeam() == TEAM_PLAYER and not Board:GetPawn(point):IsFlying()) or Board:IsBuilding(point) or Board:IsTerrain(point,TERRAIN_WATER) or Board:IsTerrain(point,TERRAIN_MOUNTAIN) or Board:IsTerrain(point,TERRAIN_ICE) or Board:IsTerrain(point,TERRAIN_HOLE) or Board:IsCracked(point) or (#pylons > 0 and list_contains(pylons, point)) or (Board:IsPawnSpace(Point(4,6)) and (Board:GetPawn(Point(4,6)):GetType() == "Train_Pawn" or Board:GetPawn(Point(4,6)):GetType() == "Train_Armored") and point.x == 4)) do
			point = point + DIR_VECTORS[1]
		end
		return point
	end
end

--this function collapses the next eligible tile if the pod crashes onto the chasm,
--because otherwise the player completely loses out on the chasm bonus by unlucky time pod location
--possible for there to be no eligible tile but that's a risk the player can assess for themselves
local function PodChasm(point)
	if GetCurrentMission().ProsperoChasmLoc == point then
		local p = GetCurrentMission().ProsperoChasmLoc + DIR_VECTORS[1]
		while ((Board:IsPawnSpace(p) and Board:GetPawn(p):GetTeam() == TEAM_PLAYER and not Board:GetPawn(p):IsFlying()) or Board:IsBuilding(p) or Board:IsTerrain(p,TERRAIN_WATER) or Board:IsTerrain(p,TERRAIN_MOUNTAIN) or Board:IsTerrain(p,TERRAIN_ICE) or Board:IsCracked(p)) do
			p = p + DIR_VECTORS[1]
		end
		local dam = SpaceDamage(p,0)
		dam.iTerrain = TERRAIN_HOLE
		Board:DamageSpace(dam)
		Game:TriggerSound("/props/ground_break_tile")
	end
end

--this part simulates the same effect for deployment inside the volcano
--could be broken by lag, but unlikely unless the player has like a hundred mods running at the same time
--with mission update hooks that do stuff to the board during the volcano collapse phase,
--of which very few, if any, exist outside of this mod and its derivatives
local function ProsperoVolcano(prevMission, nextMission)
	local j = -1
	local Prospero = nil
	modApi:scheduleHook(3500, function()
		if Game == nil then return end
		for i = 0,2 do
			local pawn = Game:GetPawn(i)
			if pawn and pawn:IsAbility("Flying") then
				j = i
			end
		end
		Prospero = Game:GetPawn(j)
		modApi:conditionalHook(
			function()
				--wait until either prospero has deployed, or the last mech has deployed, then proceed
				return Game == nil or (Prospero ~= nil and Prospero:GetSpace() ~= Point(-1,-1) and not Prospero:IsBusy()) or (Game:GetPawn(2):GetSpace() ~= Point(-1,-1) and not Game:GetPawn(2):IsBusy())
			end,
			function()
				if Prospero ~= nil then
					--because it is impossible to know where mechs get deployed in advance,
					--just make it so that the square in front of the front most row of mechs is the one that gets collapsed;
					--i.e. we don't bother checking for flying allied mech compatibility, unlike the other functions.
					--it is always guaranteed to not be a pylon, so we don't need to check for that.
					local dam = SpaceDamage(Prospero:GetSpace() + DIR_VECTORS[1]*(4 - Prospero:GetSpace().x),0)
					dam.iTerrain = TERRAIN_HOLE
					Board:DamageSpace(dam)
					Game:TriggerSound("/props/ground_break_tile")
				end
			end
		)
	end)
end

local function ChasmAnim(mission)
	if not modApi.deployment.isDeploymentPhase(self) then return end
	mission.DeploymentBegun = false or mission.DeploymentBegun
	local j = -1
	for i = 0,2 do
		local pawn = Game:GetPawn(i)
		if pawn and pawn:IsAbility("Flying") then
			j = i
		end
	end
	--exit if pilot of interest not found
	if j == -1 then return end
	if modApi.deployment.isDeploymentPhase(self) and Board:IsValid(Game:GetPawn(j):GetSpace()) and not mission.DeploymentBegun then
		if Board:IsBlocked(ProsperoChasmDupe(j),PATH_PROJECTILE) then
			customAnim:add(ProsperoChasmDupe(j), "ShatteringTile")
			customAnim:rem(ProsperoChasmDupe(j), "ShatteringTileCentred")
		else
			customAnim:add(ProsperoChasmDupe(j), "ShatteringTileCentred")
			customAnim:rem(ProsperoChasmDupe(j), "ShatteringTile")
		end
		for i, p in ipairs(Board) do
			if p~=ProsperoChasmDupe(j) then customAnim:rem(p, "ShatteringTile") customAnim:rem(p, "ShatteringTileCentred") end
		end
	end
	--erase shattering preview once the player clicks Confirm
	if mission.DeploymentBegun then
		customAnim:rem(ProsperoChasmDupe(j), "ShatteringTile")
		customAnim:rem(ProsperoChasmDupe(j), "ShatteringTileCentred")
	end
end

local function EVENT_onModsLoaded()
	modapiext:addPodLandedHook(PodChasm)
	modApi:addMissionNextPhaseCreatedHook(ProsperoVolcano)
	modApi:addMissionUpdateHook(ChasmAnim)
end

modApi.events.onPawnLanded:subscribe(ProsperoChasm)
modApi.events.onModsLoaded:subscribe(EVENT_onModsLoaded)
