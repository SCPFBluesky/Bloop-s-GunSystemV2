--[[
	Name: FluxServerCore.Luau
	Author(s): @WATDAHECKLOL32
	Date: 2024-12-27 12:43:12 AM
	RunTimeContext: Shared
	Information: Server side handler for the flux framework.
]]

--!nocheck
--!native

--[[
	network useage:
	network:FireClient(plr, function, functionarg)
	network:FireAllClientsExpect(expect, function, functionarg)
]]

warn("[FLUX/SERVER/CORE] FluxServerCore has been Loaded!")


---------------------------
--   V A R I A B L E S   --
---------------------------


local require, network, thread, tagged, asset = shared.import("require", "network", "thread", "tagged", "asset")

local newInstance = require("newInstance")

local Players = game:FindService("Players")
local Teams = game:FindService("Teams")
local Lighting = game:FindService("Lighting")

local FirearmServer = require("FirearmServer")
local RunService = game:GetService("RunService")
local TextService = game:GetService("TextService")

local ServerStorage = game:FindService("ServerStorage")
local PhysService = game:GetService("PhysicsService")
local TeleportService = game:GetService("TeleportService")
local GuiltyHandler = require("GuiltyHandler")

local CollectionService = game:GetService("CollectionService")

---------------------------
--      S E T U P        --
---------------------------


--------------------------------
-- F L U X  F U N C T I O N S --
--------------------------------

--[[@native function HandleCharAdded(Player: Player, Team: Team)
	local UniformFolder = ServerStorage.TeamUniforms:FindFirstChild(tostring(Team))
	
	for _,v in Player.Character:GetChildren() do
		if v:IsA("Clothing") then
			v:Destroy()
		elseif v:IsA("Accessory") and Team:GetAttribute("RemoveHats") then
			v:Destroy()
		end;
	end;
	
	if UniformFolder then
		for _,v in UniformFolder:GetChildren() do
			local New = v:Clone()
			New.Parent = Player.Character
		end;
	end;
end;]]


---------------------------------------------
-- N E T W O R K \ C O N N E C T I O N S  --
---------------------------------------------

network:OnEvent({
	createKnifeSounds = @native function(Player: (Player), Tool : (any) )
		if not Tool or Tool.Parent ~= Player.Character or not Tool:FindFirstChild("Main") or Tool:GetAttribute("Inited") then
			return;
		end;
		Tool:SetAttribute("Inited", true)
		
		local MainModule = OldRequire(Tool.Main)
		
		for Name: (string), SoundID: (number) in MainModule.Sounds do
			local New = CreateSound.new(SoundID, Name, 1, Tool.Handle)
		end;
		
	end,
	useMelee = @native function(Player: (Player), Tool: (Tool), rayResult: (any) )
		if not Tool or Tool.Parent ~= Player.Character or not rayResult then
			return;
		end;
		
		local Handle = Tool.Handle
		
		Handle.Slash:Play()
		local SlashFleshSounds = {"HitFlesh1", "HitFlesh2", "HitFlesh3"}
		
		if rayResult.Instance and rayResult.Instance.Parent then
			local hitInstance = rayResult.Instance
			local HitHumanoid
			
			if hitInstance and hitInstance.Parent and hitInstance.Parent:FindFirstChildWhichIsA("Humanoid") then
				HitHumanoid = hitInstance.Parent.Humanoid
			end;
			
			if HitHumanoid then
				Handle[SlashFleshSounds[_Random:NextInteger(1, #SlashFleshSounds)]]:Play()
				HitHumanoid:TakeDamage(20)
			else
				Handle.HitOther:Play()
			end;
		end;
	end,
	Reload =  @native function(Player: (Player), gun: any)
		if not gun or gun.Parent ~= Player.Character then
			return;
		end;
		
		FirearmServer.Reload(Player, gun)
	end,
	useMedkit = @native function(Player: (Player), Tool: any)
		if not Tool or Tool.Parent ~= Player.Character then
			return;
		end;
		
		Player.Character.Humanoid.Health = Player.Character.Humanoid.MaxHealth
		
		Tool:Destroy()
		
		network:FireClient(Player, "NotifyPlayer", "You start to feel better.")
	end,
	DropWeapon = @native function(Player: (Player), gun: any)
		FirearmServer.DropGun(Player, gun)
	end,
	
	DischargeGun = @native function(Player: Player, gun: any, Action: string, MuzzlePos: Vector3, BulletDir: Vector3, Dmg: number, finalHitPos: Vector3, hitInfo: any)
		network:FireAllClientsWithException(Player, "mkHitEffects", "DisplayEffects", gun, MuzzlePos, finalHitPos, hitInfo)
		FirearmServer.Fire(Player, gun, Action, MuzzlePos, BulletDir, Dmg, finalHitPos, hitInfo)
	end,
	
	flashlight = @native function(player: (Player), Tool: (Tool), State: (boolean) )
		if Tool == nil or not player.Character:FindFirstChild("Flashlight") or not player.Character:FindFirstChild("Flashlight").Main then
			return;
		end;
		network:FireAllClientsWithException(player, "ReplicateFlashLight", Tool, State)
	end,
	
});
network:OnFunction({})

------------------------------------------------------------------------------

return {};
