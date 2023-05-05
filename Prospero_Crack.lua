local mod = modApi:getCurrentMod()
local path = mod_loader.mods[modApi.currentMod].scriptPath
local customAnim = require(path .."/customAnim")

local oldGetSkillInfo = GetSkillInfo
function GetSkillInfo(skill)
	if skill == "Flying"    then
		return PilotSkill("Flying", "Mech gains Flying. On deployment, crack adjacent tiles.")
	end
	return oldGetSkillInfo(skill)
end

ANIMS.CrackingTileCentred = Animation:new{
	Image = "advanced/combat/icons/icon_crack_anim.png",
	PosX = -13, PosY = 12,
	Time = 0.15,
	Loop = true,
	NumFrames = 6
}
ANIMS.NotCrackingTileCentred = Animation:new{
	Image = "advanced/combat/icons/icon_crack_glow_off.png",
	PosX = -13, PosY = 12,
	Time = 0.15,
	Loop = true,
	NumFrames = 1
}
ANIMS.NotCrackingTile = Animation:new{
	Image = "advanced/combat/icons/icon_crack_glow_off.png",
	PosX = -13, PosY = 22,
	Time = 0.15,
	Loop = true,
	NumFrames = 1
}

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

local function ProsperoCrack(pawnId)
	local pawn = Board:GetPawn(pawnId)
	local point = pawn:GetSpace()
	local pylons = extract_table(Board:GetZone("pylons"))
	if pawn and pawn:IsAbility("Flying") then
		local dam = SpaceDamage(0)
		dam.iCrack = 1
		for i = 0, 3 do
			local curr = point + DIR_VECTORS[i]
			dam.loc = curr
			if #pylons > 0 and list_contains(pylons, curr) then
				--do nothing
			else
				Board:DamageSpace(dam)
			end
		end
		Game:TriggerSound("/weapons/crack_ko")
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
		local pylons = extract_table(Board:GetZone("pylons"))
		modApi:conditionalHook(
			function()
				return Game == nil or (Prospero ~= nil and Prospero:GetSpace() ~= Point(-1,-1) and not Prospero:IsBusy()) or (Game:GetPawn(2):GetSpace() ~= Point(-1,-1) and not Game:GetPawn(2):IsBusy())
			end,
			function()
				if Prospero ~= nil then
					local dam = SpaceDamage(0)
					dam.iCrack = 1
					for i = 0, 3 do
						local curr = Prospero:GetSpace() + DIR_VECTORS[i]
						dam.loc = curr
						if #pylons > 0 and list_contains(pylons, curr) then
							--do nothing
						else
							Board:DamageSpace(dam)
						end
					end
					Game:TriggerSound("/weapons/crack_ko")
				end
			end
		)
	end)
end

local function CrackAnim(mission)
	if not modApi.deployment.isDeploymentPhase(self) then return end
	mission.DeploymentBegun = false or mission.DeploymentBegun
	mission.PrevProsperoDeploySquares = mission.PrevProsperoDeploySquares or {Point(-1,-1),Point(-1,-1),Point(-1,-1),Point(-1,-1)}
	local j = -1
	for i = 0,2 do
		local pawn = Game:GetPawn(i)
		if pawn and pawn:IsAbility("Flying") then
			j = i
		end
	end
	if j == -1 then return end
	local pylons = extract_table(Board:GetZone("pylons"))
	if modApi.deployment.isDeploymentPhase(self) and Board:IsValid(Game:GetPawn(j):GetSpace()) and not mission.DeploymentBegun then
		local point = Game:GetPawn(j):GetSpace()
		if mission.PrevProsperoDeploySquares[1]+DIR_VECTORS[2]~=point then
			for i = 1,4 do
				customAnim:rem(mission.PrevProsperoDeploySquares[i], "CrackingTile")
				customAnim:rem(mission.PrevProsperoDeploySquares[i], "CrackingTileCentred")
				customAnim:rem(mission.PrevProsperoDeploySquares[i], "NotCrackingTile")
				customAnim:rem(mission.PrevProsperoDeploySquares[i], "NotCrackingTileCentred")
			end
		end
		for i = 0, 3 do
			local curr = point + DIR_VECTORS[i]
			mission.PrevProsperoDeploySquares[i+1] = curr
			if #pylons > 0 and list_contains(pylons, curr) then
				customAnim:add(curr, "NotCrackingTileCentred")
			elseif not Board:IsCrackable(curr) or Board:IsCracked(curr) then
				if Board:IsBlocked(curr,PATH_PROJECTILE) and not Board:IsBuilding(curr) then
					customAnim:add(curr, "NotCrackingTile")
					customAnim:rem(curr, "NotCrackingTileCentred")
				else
					customAnim:add(curr, "NotCrackingTileCentred")
					customAnim:rem(curr, "NotCrackingTile")
				end
			elseif Board:IsBlocked(curr,PATH_PROJECTILE) and not Board:IsTerrain(curr,TERRAIN_MOUNTAIN) then
				customAnim:add(curr, "CrackingTile")
				customAnim:rem(curr, "CrackingTileCentred")
			else
				customAnim:add(curr, "CrackingTileCentred")
				customAnim:rem(curr, "CrackingTile")
			end
		end
	end
	for i = 1,4 do
		if mission.DeploymentBegun then
			customAnim:rem(mission.PrevProsperoDeploySquares[i], "CrackingTile")
			customAnim:rem(mission.PrevProsperoDeploySquares[i], "CrackingTileCentred")
			customAnim:rem(mission.PrevProsperoDeploySquares[i], "NotCrackingTile")
			customAnim:rem(mission.PrevProsperoDeploySquares[i], "NotCrackingTileCentred")
		end
	end
end

local function EVENT_onModsLoaded()
	modApi:addMissionNextPhaseCreatedHook(ProsperoVolcano)
	modApi:addMissionUpdateHook(CrackAnim)
end

modApi.events.onModsLoaded:subscribe(EVENT_onModsLoaded)
modApi.events.onPawnLanded:subscribe(ProsperoCrack)