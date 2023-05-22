local mod = modApi:getCurrentMod()
local path = mod_loader.mods[modApi.currentMod].scriptPath
local customAnim = require(path .."/customAnim")

ANIMS.FirePreview = Animation:new{
	Image = "combat/icons/icon_fire_glow.png",
	PosX = -13, PosY = 12,
	Time = 0.15,
	Loop = true,
	NumFrames = 1
}

Passive_FireBoost = Passive_FireBoost:new{
	Upgrades = 1,
	UpgradeCost = {2},
}

Passive_FireBoost_A = Passive_FireBoost:new{
	TipImage = {
		Unit = Point(2,3),
		Target = Point(2,3),
		Friendly1 = Point(1,1),
		Friendly2 = Point(2,1),
	}
}

function Passive_FireBoost_A:GetSkillEffect(p1, p2)
	local ret = SkillEffect()
	local dam = SpaceDamage(Point(1,0),0)
	dam.iFire = 1
	if p1 == Point(2,3) then
		ret:AddDamage(dam)
		dam.loc = Point(2,0)
		ret:AddDamage(dam)
		dam.loc = Point(0,1)
		ret:AddDamage(dam)
		dam.loc = Point(3,1)
		ret:AddDamage(dam)
		dam.loc = Point(1,2)
		ret:AddDamage(dam)
		dam.loc = Point(2,2)
		ret:AddDamage(dam)
		dam.loc = Point(2,4)
		ret:AddDamage(dam)
		dam.loc = Point(1,3)
		ret:AddDamage(dam)
		dam.loc = Point(3,3)
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

local function FireAnim(mission)
	if not modApi.deployment.isDeploymentPhase(self) then return end
	mission.DeploymentBegun = false or mission.DeploymentBegun
	
	local deployburnflag = false
	for i = 0,2 do
		if Board:GetPawn(i):IsWeaponPowered("Passive_FireBoost_A") then
			deployburnflag = true
		end
	end
	if not deployburnflag then return end
	
	mission.PrevMechDeploySquares = mission.PrevMechDeploySquares or {{Point(-1,-1),Point(-1,-1),Point(-1,-1),Point(-1,-1)},{Point(-1,-1),Point(-1,-1),Point(-1,-1),Point(-1,-1)},{Point(-1,-1),Point(-1,-1),Point(-1,-1),Point(-1,-1)}}

	if modApi.deployment.isDeploymentPhase(self) and not mission.DeploymentBegun then
		for i = 0,2 do
			local pawn = Game:GetPawn(i)
			local point = pawn:GetSpace()
			if Board:IsValid(point) then
				if mission.PrevMechDeploySquares[i+1][1]+DIR_VECTORS[2]~=point then
					for j = 1,4 do
						customAnim:rem(mission.PrevMechDeploySquares[i+1][j], "FirePreview")
					end
				end
				for k = 0,3 do
					local curr = point + DIR_VECTORS[k]
					mission.PrevMechDeploySquares[i+1][k+1] = curr
					if Board:IsPawnSpace(curr) and Board:GetPawn(curr):GetTeam() == TEAM_PLAYER then
						--do nothing
					else
						customAnim:add(curr, "FirePreview")
					end
				end
			end
		end
	end
	if mission.DeploymentBegun then 
		for i = 0,2 do
			for k = 0,3 do
				customAnim:rem(mission.PrevMechDeploySquares[i+1][k+1], "FirePreview")
			end
		end
		mission.PrevMechDeploySquares = nil
	end
end
local function DeployBurn(pawnId)
	local pawn = Board:GetPawn(pawnId)
	local deployburnflag = false
	for i = 0,2 do
		if Board:GetPawn(i):IsWeaponPowered("Passive_FireBoost_A") then
			deployburnflag = true
		end
	end
	if not deployburnflag then return end
	
	local dam = SpaceDamage(Point(-1,-1),0)
	dam.iFire = 1
	if pawn and pawn:IsMech() then
		local point = pawn:GetSpace()
		for i = 0, 3 do
			local curr = point + DIR_VECTORS[i]
			if Board:IsPawnSpace(curr) and Board:GetPawn(curr):GetTeam() == TEAM_PLAYER then
				--do nothing
			else
				dam.loc = curr
				Board:DamageSpace(dam)
			end
		end
	end
end

local function DeployBurnVolcano(prevMission, nextMission)
	modApi:scheduleHook(3500, function()
		if Game == nil then return end
		local deployburnflag = false
		for i = 0,2 do
			if Board:GetPawn(i):IsWeaponPowered("Passive_FireBoost_A") then
				deployburnflag = true
			end
		end
		if not deployburnflag then return end
		for k = 0,2 do
			local Mech = Game:GetPawn(k)
			modApi:conditionalHook(
				function()
					return Game == nil or (Mech ~= nil and Mech:GetSpace() ~= Point(-1,-1) and not Mech:IsBusy())
				end,
				function()
					if Mech ~= nil then
						local dam = SpaceDamage(0)
						dam.iFire = 1
						for i = 0, 3 do
							local curr = Mech:GetSpace() + DIR_VECTORS[i]
							dam.loc = curr
							if curr ~= Point(2,3) and curr ~= Point(3,3) and curr ~= Point(2,4) and curr ~= Point(3,4) then
								Board:DamageSpace(dam)
							end
						end
					end
				end
			)
		end
	end)
end

local function EVENT_onModsLoaded() --This function will run when the mod is loaded
	modApi:setText("Passive_FireBoost_Upgrade1", "Preignition")
	modApi:setText("Passive_FireBoost_A_UpgradeDescription", "On deployment, ignite all adjacent tiles to Mechs, ignoring allied units.")
	modApi:addMissionUpdateHook(FireAnim)
	modApi:addMissionNextPhaseCreatedHook(DeployBurnVolcano)
end
modApi.events.onPawnLanded:subscribe(DeployBurn)
modApi.events.onModsLoaded:subscribe(EVENT_onModsLoaded)