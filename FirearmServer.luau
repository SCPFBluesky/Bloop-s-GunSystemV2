
--[[
	FirearmServer.Luau
	--------------------
	Author(s): @SCPF_RedSky
	Date: 11-1-24
	Runtime: Shared
	Information: Serverside of the gun sytem
--]]

--!native
--!strict

---------------------------
--   V A R I A B L E S   --
---------------------------

local FirearmServer = {}
local Players = game:GetService("Players")

local IsCloned, IsEnabled = false,false

local Remote = game:GetService("ReplicatedStorage").FirearmShared.Remotes.Main
--local Remote = BridgeNet.CreateBridge("Main")
local ClientRemote = game:GetService("ReplicatedStorage").FirearmShared.Remotes.Client
--local ClientRemote = BridgeNet.CreateBridge("Client")

local HitEffects = game:GetService("ReplicatedStorage").FirearmShared.Stuff.Effects
local MuzzleEffects = game:GetService("ReplicatedStorage").FirearmShared.Stuff.Muzzle
local FlashlightRemote = game:GetService("ReplicatedStorage").FirearmShared.Remotes.Flashlight

local Notify = game:GetService("ReplicatedStorage").NotifyPlayer
local ReloadRemote = game:GetService("ReplicatedStorage").FirearmShared.Remotes.Reload
local TeamPriorityModule = require(game:GetService("ReplicatedStorage").FirearmShared.TeamPriorityModule)
local Dictionary = require(game:GetService("ReplicatedStorage").FirearmShared.Dictionary)

---------------------------
--   S E T T I N G S   --
---------------------------

local Settings = {
    AlwaysDamage = false,
    NotifyPlayer = true,
    EnableGuiltySystem = true,

}

---------------------------
-- M A I N   S C R I P T --
---------------------------

--[[
	--------------------------------------------------------------------------------------------------
	 @Name : 	 	  GetTeamPriority
	 @Author :        @SCPF_RedSky
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
	 @Author :        @SCPF_RedSky
	 @Description :   Teamchecks the players
	 @Params : 	      Player: PlayerWhoFired - The player who fired the gun, any: targetPlr - The player who got shot, Tool: the player's gun
	--------------------------------------------------------------------------------------------------
--]]
@native function TeamCheck(PlayerWhoFired: Player, targetPlr: any, gun: Tool)
    -- this is old and i dont care lol
    local playerTeam = PlayerWhoFired.Team.Name
    local targetTeam = targetPlr.Team.Name

    local playerPriority = GetTeamPriority(playerTeam, PlayerWhoFired)
    local targetPriority = GetTeamPriority(targetTeam, PlayerWhoFired)

    local ClearToDamage = false

    if Settings.AlwaysDamage == true and not (PlayerWhoFired == targetPlr) then
        return true
    end;

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
	 @Author :        @SCPF_RedSky
	 @Description :   Server sides the reload sounds
	 @Params : 	      any: self - the players gun
	--------------------------------------------------------------------------------------------------
--]]
@native function Reload(plr: any, gun: any)
    local sound = gun.Handle.Muzzle.Reload
    sound:Play()
end;

--[[
	--------------------------------------------------------------------------------------------------
	 @Name : 	 	  Fire
	 @Author :        @SCPF_RedSky
	 @Description :   Handles hit detection
	 @Params : 	      no
	--------------------------------------------------------------------------------------------------
--]]
@native function Fire(player: any, gun: Tool, arg: string, muzzlePosition: Vector3, bulletDirection: Vector3, dmg: number, finalHitPosition: Vector3, raycastResult: any)
    local self = gun
    if self == nil or self:IsDescendantOf(workspace) == false or player.Character.Humanoid.Health == 0 then return end
    if arg == "Discharge" then
        --	local s = os.clock()
        local FireSound = self.Handle.Muzzle:FindFirstChild("FireSound") or self.Handle.Muzzle.Fire:Clone()
        FireSound.Parent = self.Handle
        FireSound.TimePosition = 0
        FireSound.PlaybackSpeed = 1
        FireSound:Play()
        game:GetService("Debris"):AddItem(FireSound, FireSound.TimeLength)




        if raycastResult and finalHitPosition and raycastResult.Normal then
            local hitInstance = raycastResult.Instance
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

        --print((os.clock()-s)*1e+6, "μs")
    end;
end;



ReloadRemote.OnServerEvent:Connect(Reload)

--[[
	--------------------------------------------------------------------------------------------------
	 @Event : 	 	  OnServerEvent (https://create.roblox.com/docs/reference/engine/classes/RemoteEvent#OnServerEvent)
	 @Author :        @SCPF_RedSky
	 @Description :   Inits the remote event
	 @Params : 	      alot.
	--------------------------------------------------------------------------------------------------
--]]
Remote.OnServerEvent:Connect(@native function(player: Player, gun: Tool, arg: string, muzzlePosition: Vector3, bulletDirection: Vector3, dmg: number, finalHitPosition: Vector3, raycastResult: Vector3) 
    local Module = Dictionary[tostring(gun)]

    local DebouncedRate = tick() 
    local WeaponRPM = Module.RPM
    local FireCooldown = WeaponRPM
    if os.time() - DebouncedRate < FireCooldown then
        return  
    end
    ClientRemote:FireAllClients("DisplayEffects", gun, muzzlePosition, finalHitPosition, raycastResult)

    Fire(player, gun, arg, muzzlePosition, bulletDirection, dmg, finalHitPosition, raycastResult)
end);


return FirearmServer
