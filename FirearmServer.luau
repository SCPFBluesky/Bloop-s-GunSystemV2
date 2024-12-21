--[[
	FirearmServer.Luau
	--------------------
	Author(s): @DrBIoop
	Date: 11-1-24
	Runtime: Shared
	Information: Serverside of the gun sytem
--]]

--!strict
--!native
--!divine-intellect

---------------------------
--   V A R I A B L E S   --
---------------------------

local FirearmServer = {}
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")

local IsCloned, IsEnabled = false,false

local packet = require(game:GetService("ReplicatedStorage").packet)
local CreateSound = require(game:GetService("ReplicatedStorage").CreateSound)
local ClientRemote = game:GetService("ReplicatedStorage").FirearmShared.Remotes.Client

local HitEffects = game:GetService("ReplicatedStorage").FirearmShared.Stuff.Effects
local MuzzleEffects = game:GetService("ReplicatedStorage").FirearmShared.Stuff.Muzzle
local FlashlightRemote = game:GetService("ReplicatedStorage").FirearmShared.Remotes.Flashlight

local Notify = game:GetService("ReplicatedStorage").NotifyPlayer
local ReloadRemote = game:GetService("ReplicatedStorage").FirearmShared.Remotes.Reload
local TeamPriorityModule = require(game:GetService("ReplicatedStorage").FirearmShared.TeamPriorityModule)

local PhysService = game:GetService("PhysicsService")

---------------------------
--   S E T T I N G S   --
---------------------------

local Settings = {
    AlwaysDamage = false; -- Enabling this disables ALL team kill restrictions
    NotifyPlayer = true; -- Enable notifcations
    EnableGuiltySystem = true; -- Enable CD Guilty system
    EnableS19ReloadSounds = true -- Enables S19 Reload (Magin \ Magout Sounds) + Mag Transparency else, Will revert to the normal single reload sound if there is one

}


------------------------------
-- I N I T  C O L L I S I O N --
------------------------------

PhysService:RegisterCollisionGroup("Accessory")
PhysService:RegisterCollisionGroup("Bullets")
PhysService:CollisionGroupSetCollidable("Bullets", "Accessory", false)


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
    for priorityLevel: any, teams: any in TeamPriorityModule do
        for _, team in teams do
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
    if Settings.AlwaysDamage == true and PlayerWhoFired ~= targetPlr then
        return true
    end

    if not PlayerWhoFired.Team then
        return true;
    end;

    local PlrTeam = PlayerWhoFired.Team.Name
    local TargetTeam = targetPlr.Team.Name
    local PlrPriority = GetTeamPriority(PlrTeam, PlayerWhoFired)
    local TargetPirority = GetTeamPriority(TargetTeam, PlayerWhoFired)

    --[[warn(PlayerWhoFired)
    warn(targetPlr)
    warn(PlrPriority)
    warn(TargetPirority)]]
    

    if targetPlr.Character:GetAttribute("Zombie") == true then
        return true;
    end;

    if PlrPriority == 1 then
        if TargetPirority == 1 then
            if Settings.NotifyPlayer then
                Notify:FireClient(PlayerWhoFired, "You cannot damage people on your own team.")
            end;
            return false;
            
        elseif TargetPirority == 2 or TargetPirority == 3 then
           -- print("YES I AM R")
            return true;
        end;
    end;

    if PlrPriority == 2 then
        if TargetTeam == "Chaos Insurgency" then
            return true;
        elseif TargetTeam == "Class D" then
            if Settings.EnableGuiltySystem then
                if targetPlr.Character:GetAttribute("Guilty") then
                   -- warn("impending doom")
                    return true;
                elseif Settings.NotifyPlayer then
                    Notify:FireClient(PlayerWhoFired, "You cannot damage Class Ds who did nothing wrong.")
                end;
                return false;
            end;
            return true;
        elseif TargetPirority == 2 or TargetPirority == 3 then
            if Settings.NotifyPlayer then
                Notify:FireClient(PlayerWhoFired, "You cannot damage people who also work for the Foundation.")
            end;
            return false;
        end;
    end;

    if PlrPriority == 3 then
        return true;
    end;
 
    return false;
end;




--[[
	--------------------------------------------------------------------------------------------------
	 @Name : 	 	  Reload
	 @Author :        @DrBIoop
	 @Description :   Server sides the reload sounds
	 @Params : 	      Player: Player - The player Any: gun - The gun
	--------------------------------------------------------------------------------------------------
--]]
@native function Reload(plr: Player, gun: any)
    local Char = plr.Character or nil
    
    if not Char then
        return;
    end;
    
    if Settings.EnableS19ReloadSounds then
        
    do
        if not gun.Handle:FindFirstChild("magIn") then
            
        local MagInSound = CreateSound.new(330005593, "magIn", 1, gun.Handle.Muzzle)
        local magOut = CreateSound.new(295387403, "magOut", 1, gun.Handle.Muzzle)
        
        end;
    end;
    
    local Module: ModuleScript = gun:FindFirstChild("Settings") :: ModuleScript
    local Settings = require(Module) -- how do i make this shut up??
    
    local MagPart = nil
    
    if gun and gun.Handle then
       -- MagPart = gun:FindFirstChild("Mag") or gun.Handle:FindFirstChild("Mag")
       
       for _,v in gun:GetDescendants() do
            if v.Name == "Mag" and v:IsA("BasePart") then
                MagPart = v
                break;
            end;
       end;
    end;
    
   -- warn(typeof(MagPart))
   -- warn(MagPart)

     if not MagPart or not MagPart:IsA("BasePart") or not gun:IsDescendantOf(Char) then
        return;
     end;


    local MagInTime = Settings.MaginTime or 1
    local MagIn = gun.Handle.Muzzle.magIn
    local magOut = gun.Handle.Muzzle.magOut
    
    MagPart.Transparency = 1
    magOut:Play()
    
    task.delay(MagInTime, @native function()
        if not gun:IsDescendantOf(Char) then
            return;
        end;
        
        MagIn:Play()
        MagPart.Transparency = 0
    end);
    
    else
        local ReloadSound = gun.Handle:FindFirstChild("Reload") or gun:FindFirstChild("Reload") or gun.Handle.Muzzle:FindFirstChild("Reload")
        
        if ReloadSound and ReloadSound:IsA("Sound") then
            ReloadSound:Play()
        end;
    end;
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
    
    if self == nil or not self:IsDescendantOf(workspace) or player.Character.Humanoid.Health == 0 then return; end;
    
    if arg == "Discharge" then
        --	local s = os.clock()

        local hitInstance = raycastResult.Instance or nil

        if typeof(raycastResult.Instance) ~= "Instance" or typeof(raycastResult.Normal) ~= "Vector3" or not finalHitPosition or typeof(finalHitPosition) ~= "Vector3" or not hitInstance then
            return;
        end;


        if raycastResult and finalHitPosition and raycastResult.Normal then

            do
                local hitHumanoid

                if hitInstance and hitInstance.Parent and hitInstance.Parent:FindFirstChildWhichIsA("Humanoid") then
                    hitHumanoid = hitInstance.Parent.Humanoid
                end;
                
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


    packet.MKHitEffects.sendToAllExcept({
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




task.delay(1.5, @native function()
    for _,v in workspace:GetDescendants() do
        task.wait()
        if v:IsA("Accessory") then
            for _,v in v:GetDescendants() do
                if v:IsA("BasePart") then
                    CollectionService:AddTag(v, "RayIgnore")
                    PhysService:SetPartCollisionGroup(v, "Accessory")
                end
            end
        end
    end
end)

do
    Players.PlayerAdded:Connect(@native function(player: Player) 
        player.CharacterAdded:Connect(@native function(character: Model)  
            task.wait(1)
            for _,v in character:GetChildren() do
                if v:IsA("Accessory") then
                    for _,v in v:GetDescendants() do
                        if v:IsA("BasePart") then
                            CollectionService:AddTag(v, "RayIgnore")
                            PhysService:SetPartCollisionGroup(v, "Accessory")
                        end
                    end
                end
            end
        end)
    end)
end

return FirearmServer
