--[[
	FirearmServer.Luau
	--------------------
	Author(s): @DrBIoop
	Date: 11-1-24
	Runtime: Shared
	Information: Serverside of the gun sytem
--]]

--!native
--!nonstrict

---------------------------
--   V A R I A B L E S   --
---------------------------

local FirearmServer = {}
local Players = game:GetService("Players")

local IsCloned, IsEnabled = false,false

local packet = require(game:GetService("ReplicatedStorage").packet)
local packet2 = require(game:GetService('ReplicatedStorage').packet2)
local CreateSound = require(game:GetService("ReplicatedStorage").CreateSound)
local ClientRemote = game:GetService("ReplicatedStorage").FirearmShared.Remotes.Client

local HitEffects = game:GetService("ReplicatedStorage").FirearmShared.Stuff.Effects
local MuzzleEffects = game:GetService("ReplicatedStorage").FirearmShared.Stuff.Muzzle
local FlashlightRemote = game:GetService("ReplicatedStorage").FirearmShared.Remotes.Flashlight

local Notify = game:GetService("ReplicatedStorage").NotifyPlayer
local ReloadRemote = game:GetService("ReplicatedStorage").FirearmShared.Remotes.Reload
local TeamPriorityModule = require(game:GetService("ReplicatedStorage").FirearmShared.TeamPriorityModule)

local PhysService = game:GetService("PhysicsService")
PhysService:RegisterCollisionGroup("Accessory")
PhysService:RegisterCollisionGroup("Bullets")
PhysService:CollisionGroupSetCollidable("Bullets", "Accessory", false)

---------------------------
--   S E T T I N G S   --
---------------------------

local Settings = {
    AlwaysDamage = false,
    NotifyPlayer = true,
    EnableGuiltySystem = true,
    EnableS19ReloadSounds = true

}

---------------------------
-- M A I N   S C R I P T --
---------------------------

--[[
	--------------------------------------------------------------------------------------------------
	 @Name : 	 	  GetTeamPriority
	 @Author :        @DrBIoop
	 @Description :   Gets the player and the player's PriorityLevel in the module
	 @Params : 	      string: teamName - The team name, player: PlayerWhoFired - Any player who shot the gun
	--------------------------------------------------------------------------------------------------
--]]
@native function GetTeamPriority(teamName: string, PlayerWhoFired: Player)
    for priorityLevel, teams in pairs(TeamPriorityModule) do
        for _, team in ipairs(teams) do
            if team == teamName then
                local priority = tonumber(priorityLevel:match("%d+"))
                return priority
            end;
        end;
    end;

    if not PlayerWhoFired or not PlayerWhoFired:IsA("Player") then
        return nil
    end;

    Notify:FireClient(PlayerWhoFired, "This player's team isn't defined in the Team Priority Module. If you see this, report this to the owner of the game.")
    warn("Team is nil, did you specify all teams in the module correctly?")
    return nil
end;

--[[
	--------------------------------------------------------------------------------------------------
	 @Name : 	 	  TeamCheck
	 @Author :        @DrBIoop
	 @Description :   Teamchecks the players
	 @Params : 	      Player: PlayerWhoFired - The player who fired the gun, any: targetPlr - The player who got shot, Tool: the player's gun
	--------------------------------------------------------------------------------------------------
--]]
@native function TeamCheck(PlayerWhoFired: Player, targetPlr: any, gun: Tool)
    -- this is old and i dont care lol
    if Settings.AlwaysDamage == true and not (PlayerWhoFired == targetPlr) then
        return true
    end;
    if PlayerWhoFired.Team == nil then
        return
    end
    local playerTeam = PlayerWhoFired.Team.Name
    local targetTeam = targetPlr.Team.Name

    local playerPriority = GetTeamPriority(playerTeam, PlayerWhoFired)
    local targetPriority = GetTeamPriority(targetTeam, PlayerWhoFired)

    local ClearToDamage = false

    if PlayerWhoFired == targetPlr then
        return false
    end;


    if playerPriority == 1 and targetPriority == 1 then
        ClearToDamage = false
        if Settings.NotifyPlayer == true and not (targetPlr.Character:GetAttribute("Zombie") == true) then
            Notify:FireClient(PlayerWhoFired, "You cannot damage people on your own team.")
        end;

    elseif playerPriority == 2 then
        if targetPriority == 2 or targetPriority == 3 then
            ClearToDamage = false
            if Settings.NotifyPlayer == true and not (targetPlr.Character:GetAttribute("Zombie") == true) then
                Notify:FireClient(PlayerWhoFired, "You cannot damage people who also work for the Foundation.")
            end;
        elseif targetTeam == "Chaos Insurgency" then
            ClearToDamage = true
        end;

        if targetTeam == "Class D" then
            if Settings.EnableGuiltySystem == true then
                if targetPlr.Character:GetAttribute("Guilty") == true then
                    ClearToDamage = true
                else
                    if Settings.NotifyPlayer == true  and not (targetPlr.Character:GetAttribute("Zombie") == true) then
                        Notify:FireClient(PlayerWhoFired, "You cannot damage Class Ds who did nothing wrong.")
                    end
                    ClearToDamage = false
                end;
            else
                ClearToDamage = true
            end;
        end;

    elseif playerPriority == 3 then
        ClearToDamage = true
    end;

    if playerPriority == 1 and targetPriority == 2 then
        ClearToDamage = true
    end;
    if playerPriority == 1 and targetPriority == 3 then 
        ClearToDamage = true
    end;
    if playerPriority == 2 and targetTeam == "Chaos Insurgency" then
        ClearToDamage = true
    end;

    if playerTeam == "Chaos Insurgency" and (targetPriority == 2 or targetPriority == 3) then
        ClearToDamage = true
    end;

    if (playerTeam == "Chaos Insurgency" and targetTeam == "Class D") or
        (playerTeam == "Class D" and targetTeam == "Chaos Insurgency") then
        ClearToDamage = false
        if Settings.NotifyPlayer == true and not (targetPlr.Character:GetAttribute("Zombie") == true) then
            Notify:FireClient(PlayerWhoFired, "You cannot damage people on your own team.")
        end;
    end;

    if targetPlr and targetPlr.Character:GetAttribute("Zombie") == true then
        ClearToDamage = true
    end;
    return ClearToDamage
end;



--[[
	--------------------------------------------------------------------------------------------------
	 @Name : 	 	  Reload
	 @Author :        @DrBIoop
	 @Description :   Server sides the reload sounds
	 @Params : 	      any: self - the players gun
	--------------------------------------------------------------------------------------------------
--]]
@native function Reload(plr: Player, gun: any)
    local Char = plr.Character or nil
    
    if not Char then
        return
    end
    
    if Settings.EnableS19ReloadSounds then
    do
        if not gun.Handle:FindFirstChild("magIn") then
            
        local MagInSound = CreateSound.new("magIn", 330005593, 1, gun.Handle.Muzzle)
        local magOut = CreateSound.new("magOut", 295387403, 1, gun.Handle.Muzzle)
        end
    end
 
    local Settings = require(gun.Settings)
    local MagPart = nil
    
    if gun and gun.Handle then
       -- MagPart = gun:FindFirstChild("Mag") or gun.Handle:FindFirstChild("Mag")
       
       for _,v in gun:GetDescendants() do
            if v.Name == "Mag" and v:IsA("BasePart") then
                MagPart = v
                break
            end
       end
       
    end
    
   -- warn(typeof(MagPart))
   -- warn(MagPart)
    
    if not MagPart or not MagPart:IsA("BasePart") then
        return
    end
    
    if not gun:IsDescendantOf(Char) then
        return
    end
        
    local MagInTime = Settings.MaginTime or 1
    local MagIn = gun.Handle.Muzzle.magIn
    local magOut = gun.Handle.Muzzle.magOut
    
    MagPart.Transparency = 1
    magOut:Play()
    
    task.delay(MagInTime, @native function()
        if not gun:IsDescendantOf(Char) then
            return
        end
        
        MagIn:Play()
        MagPart.Transparency = 0
    end)
    
    else
       
        gun.Handle:FindFirstChild("Reload"):Play()
    end
end;

--[[
	--------------------------------------------------------------------------------------------------
	 @Name : 	 	  Fire
	 @Author :        @DrBIoop
	 @Description :   Handles hit detection
	 @Params : 	      no
	--------------------------------------------------------------------------------------------------
--]]
@native function Fire(player: any, gun: Tool, arg: string, muzzlePosition: Vector3, bulletDirection: Vector3, dmg: number, finalHitPosition: Vector3, raycastResult: any)
    local self = gun
    if self == nil or self:IsDescendantOf(workspace) == false or player.Character.Humanoid.Health == 0 then return end
    if arg == "Discharge" then
        --	local s = os.clock()


        if typeof(raycastResult.Instance) ~= "Instance" or typeof(raycastResult.Normal) ~= "Vector3" then
            -- legit will not work without this since when its nil it likes to turn into a random number for somereason so yeah
            return
        end;

        if finalHitPosition == nil or typeof(finalHitPosition) ~= "Vector3" then
            return
        end;

        if raycastResult and finalHitPosition and raycastResult.Normal then

            do
                local hitInstance = raycastResult.Instance or nil
                if hitInstance == nil then
                    return
                end
                local hitHumanoid = hitInstance and hitInstance.Parent:FindFirstChild("Humanoid")

                local hitModel = hitInstance:FindFirstAncestor("173")
                if hitModel and hitModel:IsA("Model") then
                    local healthValue = hitModel:FindFirstChild("Health")
                    if healthValue and healthValue:IsA("NumberValue") then
                        healthValue.Value = healthValue.Value - dmg 
                    end;
                end;

                if hitHumanoid then
                    local targetPlayer = Players:GetPlayerFromCharacter(hitHumanoid.Parent)

                    if targetPlayer == nil or TeamCheck(player, targetPlayer, self) then
                        hitHumanoid:TakeDamage(dmg)
                    end;
                end;
            end;
        end;

        --print((os.clock()-s)*1e+6, "μs")
    end;
end;



ReloadRemote.OnServerEvent:Connect(Reload)

--[[
	--------------------------------------------------------------------------------------------------
	 @Event : 	 	  Listen (https://ffrostfall.github.io/ByteNet/api/functions/definePacket/)
	 @Author :        @DrBIoop
	 @Description :   Inits the remote event
	 @Params : 	      any: data the data that got sent to the fake remote, player: player - the playedr!!!!
	--------------------------------------------------------------------------------------------------
--]]
packet.discharge.listen(@native function(data: any, player: Player?)  -- please work im begging you
    local gun = data.gun
    local MuzzlePos = data.muzzlePos
    local HitPos = data.finalHitPos
    local RayCastResult = data.hitInfo


    packet2.MKHitEffects.sendToAllExcept({
        action = "DisplayEffects",
        gun = gun,
        muzzlePos = MuzzlePos,
        hitPos = HitPos,
        rayresult = {
            Instance = RayCastResult.Instance,
            Normal = RayCastResult.Normal    
        }
    }, player)


    Fire(
        player,
        data.gun,
        data.action,
        data.muzzlePos,
        data.bulletDirection,
        data.damage,
        data.finalHitPos,
        data.hitInfo
    )
end)

do
    Players.PlayerAdded:Connect(@native function(player: Player) 
        player.CharacterAdded:Connect(@native function(character: Model)  
            task.wait(1)
            for _,v in character:GetChildren() do
                if v:IsA("Accessory") then
                    for _,v in v:GetChildren() do
                        if v:IsA("BasePart") then
                            PhysService:SetPartCollisionGroup(v, "Accessory")
                        end
                    end
                end
            end
        end)
    end)
end

return FirearmServer
