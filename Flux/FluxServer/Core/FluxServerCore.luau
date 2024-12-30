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

local OldRequire = require

local _Random = Random.new()
local require, network, thread, tagged, asset = shared.import("require", "network", "thread", "tagged", "asset")

local newInstance = require("newInstance")

local Players = game:FindService("Players")
local Teams = game:FindService("Teams")
local Lighting = game:FindService("Lighting")

local CreateSound = require("CreateSound")
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

@native function HandleCharAdded(Player: Player, Team: Team)
	Player.Character:SetAttribute("Flashlight", false)
end;


---------------------------------------------
-- N E T W O R K \ C O N N E C T I O N S  --
---------------------------------------------

for _,v in Players:GetPlayers() do
	HandleCharAdded(v)
end;

Players.PlayerAdded:Connect(@native function(player: Player) 
	player.CharacterAdded:Connect(@native function(character: Model) 
		HandleCharAdded(player)	
	end);
end);

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
	
	toggleFlashLight = @native function(Player: (Player))
		if not Player.Character then
			return;
		end;
		local FlashAttribute = Player.Character:GetAttribute("Flashlight")
		
		Player.Character:SetAttribute("Flashlight", not FlashAttribute)

		local Goal = FlashAttribute
		

		if Player.Team == Teams["RAISA"] then
			local new: (Sound) = CreateSound.new(1283290053, "Beep", 1, Player.Character.Head) :: (Sound)
			new:Play()

			task.delay(new.TimeLength, @native function()
				new:Destroy()
			end);
			
			local Hel = Player.Character:FindFirstChild("FlashlightHelmet")	
		
			if Hel and Hel.FlashPart then
				local FlashPart: (any) = Hel.FlashPart :: (any)
				local Node = FlashPart.node
				
				if Goal then
					FlashPart.Material = Enum.Material.Neon
				else
					FlashPart.Material = Enum.Material.Glass
				end;
				
				Node.Light.Enabled = Goal
				repeat task.wait() Node.SpotLight.Enabled = Goal until Node.SpotLight.Enabled == Goal
			end;
		elseif Player.Team == Teams["MTF Alpha-1"] then
			local new: (Sound) = CreateSound.new(1283290053, "Beep", 1, Player.Character.Head) :: (Sound)
			new:Play()

			task.delay(new.TimeLength, @native function()
				new:Destroy()
			end);
			
			local NVG = Player.Character:FindFirstChild("NVGHelmet")
			
			if NVG and NVG.NVGPart then
				network:FireClient(Player, "useNVG", Goal)
				local NVGPart = NVG.NVGPart
				for _,v: (any) in NVGPart:GetChildren() do
					if v.Name == "node" and v:IsA("Attachment") then
						v.Light.Enabled = Goal
					end;
				end
			end;
		else
			local new: (Sound) = CreateSound.new(1283290053, "Beep", 1, Player.Character.Head) :: (Sound)
			new:Play()

			task.delay(new.TimeLength, @native function()
				new:Destroy()
			end);
			
			local ToolOfInterset = Player.Character:FindFirstChildWhichIsA("Tool")
			if ToolOfInterset and ToolOfInterset:FindFirstChild("Muzzle") and ToolOfInterset.Muzzle:FindFirstChild("SpotLight") then
				local SpotLight = ToolOfInterset.Muzzle.SpotLight
				SpotLight.Enabled = Goal
			end;
		end;
	end,
	
})
network:OnFunction({})

------------------------------------------------------------------------------

return {};
