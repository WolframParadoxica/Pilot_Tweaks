local mod = modApi:getCurrentMod()
local path = mod_loader.mods[modApi.currentMod].scriptPath
local customAnim = require(path .."/customAnim")

local oldGetSkillInfo = GetSkillInfo
function GetSkillInfo(skill)
	if skill == "Flying"    then
		return PilotSkill("Flying", "Mech gains Flying. On deployment, collapse a ground tile in front of self.")-- under and 
	end
	return oldGetSkillInfo(skill)
end
ANIMS.ShatteringTileCentred = Animation:new{
	Image = "advanced/combat/icons/icon_shatter_anim.png",
	PosX = -13, PosY = 12,
	Time = 0.15,
	Loop = true,
	NumFrames = 7
}
--		LOG(GetCurrentMission().GetSaveData().podReward.cores)
--		LOG(GetCurrentMission().GetSaveData().map_data.pod)
--		LOG(GetCurrentRegion().player.map_data.pod)
--		LOG(GetCurrentRegion().player.podReward)
--[[local function Para_RegionFinder()
	for i=0,7 do
	  for k,v in pairs(RegionData) do
		if tostring(k)=="region"..i and v.player and v.player.map_data and v.player.map_data.pawn1 then
		  return v
		end
	  end
	end
end]]
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

local function ProsperoChasm(pawnId)
	local pawn = Board:GetPawn(pawnId)
	local point = pawn:GetSpace()
	if pawn and pawn:IsAbility("Flying") then
	
		local pylons = extract_table(Board:GetZone("pylons"))
	
		local dam = SpaceDamage(point,0)
		dam.iTerrain = TERRAIN_HOLE
		--Board:DamageSpace(dam)
		-- or (not Para_RegionFinder().player.secret and point == Para_RegionFinder().player.map_data.pod)
		point = point + DIR_VECTORS[1]
		while ((Board:IsPawnSpace(point) and Board:GetPawn(point):GetTeam() == TEAM_PLAYER and not Board:GetPawn(point):IsFlying()) or Board:IsBuilding(point) or Board:IsTerrain(point,TERRAIN_WATER) or Board:IsTerrain(point,TERRAIN_MOUNTAIN) or Board:IsTerrain(point,TERRAIN_ICE) or Board:IsCracked(point) or (#pylons > 0 and list_contains(pylons, point)) or (Board:IsPawnSpace(Point(4,6)) and (Board:GetPawn(Point(4,6)):GetType() == "Train_Pawn" or Board:GetPawn(Point(4,6)):GetType() == "Train_Armored") and point.x == 4)) do
			point = point + DIR_VECTORS[1]
		end
		dam.loc = point
		--if Board:IsTerrain(point,TERRAIN_MOUNTAIN) then dam.iDamage = DAMAGE_DEATH end
		Board:DamageSpace(dam)
		Game:TriggerSound("/props/ground_break_tile")
		GetCurrentMission().ProsperoChasmLoc = point
	end
end

-- duplicate for anim hook
local function ProsperoChasmDupe(pawnId)
	local pawn = Board:GetPawn(pawnId)
	local point = pawn:GetSpace()
	if pawn and pawn:IsAbility("Flying") then
	
		local pylons = extract_table(Board:GetZone("pylons"))
	
		local dam = SpaceDamage(point,0)
		dam.iTerrain = TERRAIN_HOLE
		--Board:DamageSpace(dam)
		-- or (not Para_RegionFinder().player.secret and point == Para_RegionFinder().player.map_data.pod)
		point = point + DIR_VECTORS[1]
		while ((Board:IsPawnSpace(point) and Board:GetPawn(point):GetTeam() == TEAM_PLAYER and not Board:GetPawn(point):IsFlying()) or Board:IsBuilding(point) or Board:IsTerrain(point,TERRAIN_WATER) or Board:IsTerrain(point,TERRAIN_MOUNTAIN) or Board:IsTerrain(point,TERRAIN_ICE) or Board:IsCracked(point) or (#pylons > 0 and list_contains(pylons, point)) or (Board:IsPawnSpace(Point(4,6)) and (Board:GetPawn(Point(4,6)):GetType() == "Train_Pawn" or Board:GetPawn(Point(4,6)):GetType() == "Train_Armored") and point.x == 4)) do
			point = point + DIR_VECTORS[1]
		end
		dam.loc = point
		--if Board:IsTerrain(point,TERRAIN_MOUNTAIN) then dam.iDamage = DAMAGE_DEATH end
		--Board:DamageSpace(dam)
		--Game:TriggerSound("/props/ground_break_tile")
		return point
	end
end

local function PodChasm(point)
	LOG("Pod Landed!")
	if GetCurrentMission().ProsperoChasmLoc == point then
		local p = GetCurrentMission().ProsperoChasmLoc + DIR_VECTORS[1]
		while ((Board:IsPawnSpace(p) and Board:GetPawn(p):GetTeam() == TEAM_PLAYER and not Board:GetPawn(p):IsFlying()) or Board:IsBuilding(p) or Board:IsTerrain(p,TERRAIN_WATER) or Board:IsTerrain(p,TERRAIN_MOUNTAIN) or Board:IsTerrain(p,TERRAIN_ICE) or Board:IsCracked(p)) do
			p = p + DIR_VECTORS[1]
		end
		local dam = SpaceDamage(p,0)
		dam.iTerrain = TERRAIN_HOLE
		--if Board:IsTerrain(p,TERRAIN_MOUNTAIN) then dam.iDamage = DAMAGE_DEATH end
		Board:DamageSpace(dam)
		Game:TriggerSound("/props/ground_break_tile")
	end
end

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
				return Game == nil or (Prospero ~= nil and Prospero:GetSpace() ~= Point(-1,-1) and not Prospero:IsBusy()) or (Game:GetPawn(2):GetSpace() ~= Point(-1,-1) and not Game:GetPawn(2):IsBusy())
			end,
			function()
				if Prospero ~= nil then
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