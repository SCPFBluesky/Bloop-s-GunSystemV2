--!nocheck
--[[
	Author(s):		WATDAHECKLOL32
	Name:           FluxServerCore.luau
	Info:           Handles Server.
	Date: 			2/14/24
	Run context:	Server
]]

warn("[FLUX/SERVER/CORE] FluxServerCore has been Loaded!")


---------------------------
--   V A R I A B L E S   --
---------------------------

local Import = require;
local _Random = Random.new();

local wait, delay, spawn, defer, cancel = task.wait, task.delay, task.spawn, task.defer, task.cancel;
local require, network, thread, tagged, asset = shared.import("require", "network", "thread", "tagged", "asset");

local newInstance = require("newInstance");

local Players = game:FindService("Players");
local Teams = game:FindService("Teams");
local Lighting = game:FindService("Lighting");

local CreateSound = require("CreateSound");
local RunService = game:GetService("RunService");
local TextService = game:GetService("TextService");

local ServerStorage = game:FindService("ServerStorage");
local PhysService = game:GetService("PhysicsService");

local TeleportService = game:GetService("TeleportService");

local TeamPriorityModule = require("TeamPriority");
local Settings = require("GunConfig");

local CollectionService = game:GetService("CollectionService");


---------------------------
--      S E T U P        --
---------------------------

--------------------------------
-- F L U X  F U N C T I O N S --
--------------------------------


function TeamCheck(PlayerWhoFired: Player, targetPlr: any, gun: Tool)
	if Settings.AlwaysDamage and PlayerWhoFired ~= targetPlr then
		return true;
	end

	if not PlayerWhoFired.Team then
		return true;
	end;


	local PlrTeam = PlayerWhoFired.Team.Name
	local TargetTeam = targetPlr.Team.Name
	local PlrPriority = GetTeamPriority(PlrTeam, PlayerWhoFired)
	local TargetPirority = GetTeamPriority(TargetTeam, PlayerWhoFired)


	if targetPlr.Character:GetAttribute("Zombie") then
		return true;
	end;

	if PlrTeam == TargetTeam then
		network:FireClient(PlayerWhoFired, "NotifyPlayer", "You cannot damage people on your own team.")
		return false;
	end;

	if PlrPriority == 1 then
		if TargetPirority == 1 then
			if Settings.NotifyPlayer then
				network:FireClient(PlayerWhoFired, "NotifyPlayer", "You cannot damage people on your own team.")
				-- Notify:FireClient(PlayerWhoFired, "You cannot damage people on your own team.")
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
					network:FireClient(PlayerWhoFired, "NotifyPlayer", "You cannot damage Class Ds who did nothing wrong.")
				end;
				return false;
			end;
			return true;
		elseif TargetPirority == 2 or TargetPirority == 3 then
			if Settings.NotifyPlayer then
				network:FireClient(PlayerWhoFired, "NotifyPlayer", "You cannot damage people who also work for the Foundation.")
			end
			return false;
		end;
	end;



	if PlrPriority == 3 then
		return true;
	end;

	return false;
end;

local function PlayBeepSound(Player: (Player) )
	if not Player or not Player.Character then
		return;
	end;
	
	local new: (Sound) = CreateSound.new(1283290053, "Beep", 1, Player.Character.Head)
	new:Play()

	delay(new.TimeLength, function()
		new:Destroy()
	end);
end;


---------------------------------------------
-- N E T W O R K \ C O N N E C T I O N S  --
---------------------------------------------


network:OnEvent({
	useMedkit = function(Player: (Player) )
		if not Player or not Player.Character or not Player.Character:FindFirstChild("Medkit") or not Player.Character:FindFirstChildWhichIsA("Humanoid") or Player.Character.Humanoid.Health >= 100 then
			return;
		end;
		
		Player.Character.Humanoid.Health = Player.Character.Humanoid.MaxHealth;
		
		Player.Character.Medkit:Destroy()
	end,
	
	replicateReload = function(Player: (Player), Weapon: (Tool) )
		if not Player or not Weapon or Weapon.Parent ~= Player.Character or not Weapon:FindFirstChild("Main") then
			return;
		end;
		
		local Main = Import(Weapon.Main);
		local ReloadTime = Main.Variables.MaginTime or 1;
		
		local MagInSound = CreateSound.new(330005593, "magIn", 1, Weapon.Handle);
		local magOut = CreateSound.new(295387403, "magOut", 1, Weapon.Handle);

		magOut:Play()
		wait(ReloadTime);
		MagInSound:Play()
		wait(MagInSound.TimeLength)
		magOut:Destroy()
		MagInSound:Destroy()
	end,
	
	useFlashlight = function(Player: (Player), Toggle: (boolean) )
		if not Player or not Player.Team or not Player.Character:FindFirstChild("Humanoid") or Player.Character:FindFirstChild("Humanoid").Health <= 0 then
			return;
		end;

		if Player.Character:FindFirstChild("NVGHelmet") then
			PlayBeepSound(Player)
			local NVG = Player.Character.NVGHelmet;
			local NVGParts = NVG.NVGPart;
			
			network:FireClient(Player, "useNVG")
			
			for _,Node: (Attachment) in next, NVGParts:GetChildren() do
				if Node:IsA("Attachment") and tostring(Node) == "node" then
					Node.Light.Enabled = Toggle
				end;
			end;
		elseif Player.Character:FindFirstChild("FlashlightHelmet") then
			PlayBeepSound(Player)
			local FlashlightHel = Player.Character.FlashlightHelmet;
			local node = FlashlightHel.FlashPart.node;
			
			node.SpotLight.Enabled = Toggle
			node.Light.Enabled = Toggle
			
			if Toggle then
				node.Parent.Material = Enum.Material.Neon
			else
				node.Parent.Material = Enum.Material.Glass
			end;
		elseif Player.Character:FindFirstChildWhichIsA("Tool") and Player.Character:FindFirstChildWhichIsA("Tool"):FindFirstChild("Muzzle") then
			PlayBeepSound(Player)
			local Tool = Player.Character:FindFirstChildWhichIsA("Tool");
			local Muzzle = Tool.Muzzle;
			
			if not Tool or not Muzzle or not Muzzle:FindFirstChild("SpotLight") then
				return;
			end;
			
			Muzzle.SpotLight.Enabled = Toggle
		end;
	end,
	
	useCard = function(Player: (Player) )
		if not Player or not Player.Character or not Player.Character:FindFirstChild("Card") then
			return;
		end;

		local Card = Player.Character:FindFirstChild("Card");

		if not Card or not Card:IsA("Tool") then
			return;
		end;
		
		local Main = Card.Handle.Id;
		
		Main.User.Text = tostring(Player)
		Main.Rank.Text = Player:GetRoleInGroup(35558033)
	end,
	
	createGun = function(Player: (Player), Tool: (Tool) )
		if not Player or not Tool or Tool.Parent ~= Player.Backpack or Tool.Handle:FindFirstChild("Fire") or not Tool:FindFirstChild("Main") then
			return;
		end;
		
		local Main = Import(Tool.Main);
		
		if Main and Main.Variables.Sounds then
			for Index, Value in next, Main.Variables.Sounds do
				local New = Instance.new("Sound");
				New.SoundId = "rbxassetid://"..Value
				New.Name = tostring(Index)
				New.Parent = Tool.Handle
			end;
		end;
	end,
	
	dischargeFirearm = function(Player: (Player), Tool: (Tool), FireSound: (number), RayResult1: (Instance), RayResult2: (number) )
		if not Player or not Tool or not FireSound or Tool.Parent ~= Player.Character then
			return;
		end;

		local Main = Import(Tool:FindFirstChild("Main"));
		if not Main then
			return;
		end;

		local Vars = Main.Variables;
		if FireSound ~= Vars.Sounds.Fire then
			Player:Kick("nice hook lol")
		end;

		if RayResult1 and RayResult1.Parent and RayResult1.Parent:FindFirstChildWhichIsA("Humanoid") then
			local Humanoid: (Humanoid) = RayResult1.Parent:FindFirstChildWhichIsA("Humanoid");
			local targetPlayer = Players:GetPlayerFromCharacter(Humanoid.Parent);

			if not targetPlayer or TeamCheck(Player, targetPlayer, Tool) then
				Humanoid:TakeDamage(Vars.Damage) 
			end;
		end;

		network:FireAllClientsWithException(Player, "ReplicateGunEffects", Tool, Vars.Sounds.Fire, RayResult1, RayResult2)
	end,
})
network:OnFunction({})

------------------------------------------------------------------------------



return {};
