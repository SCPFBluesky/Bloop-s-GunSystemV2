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

local Import = require

local _Random = Random.new()
local require, network, thread, tagged, asset = shared.import("require", "network", "thread", "tagged", "asset")

local newInstance = require("newInstance")

local Players = game:FindService("Players")
local Teams = game:FindService("Teams")
local Lighting = game:FindService("Lighting")

local CreateSound = require("CreateSound")
local RunService = game:GetService("RunService")
local TextService = game:GetService("TextService")

local ServerStorage = game:FindService("ServerStorage")
local PhysService = game:GetService("PhysicsService")
local TeleportService = game:GetService("TeleportService")
local GuiltyHandler = require("GuiltyHandler")
local TeamPriorityModule = require("TeamPriority")
local Settings = require("GunConfig")

local CollectionService = game:GetService("CollectionService")

---------------------------
--      S E T U P        --
---------------------------

PhysService:RegisterCollisionGroup("Accessory")
PhysService:RegisterCollisionGroup("Bullets")
PhysService:CollisionGroupSetCollidable("Bullets", "Accessory", false)

--------------------------------
-- F L U X  F U N C T I O N S --
--------------------------------

function HandleCharAdded(Player: Player, Team: Team)
	Player.Character:SetAttribute("Flashlight", false)
end;

function GetTeamPriority(teamName: string, PlayerWhoFired: Player)
	for priorityLevel: any, teams: any in TeamPriorityModule do
		for _, team in teams do
			if team == teamName then
				local priority = tonumber(priorityLevel:match("%d+"))
				return priority;
			end;
		end;
	end;

	if not PlayerWhoFired or not PlayerWhoFired:IsA("Player") then
		return nil;
	end;

	network:FireClient("NotifyPlayer", PlayerWhoFired, "This player's team isn't defined in the Team Priority Module. If you see this, report this to the owner of the game.")
	warn("Team is nil, did you specify all teams in the module correctly?")
	return nil;
end;


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

function DropGun(Player: Player, Tool: any)
	-- this is rushed! but it works well enough and thats what i care about

	if not Tool:IsDescendantOf(Player.Character) and not Tool:IsDescendantOf(Player.Backpack) or not Settings.EnableDropWeapons then
		return;
	end;

	local DropConnect


	Tool:SetAttribute("IsStill", false)
	Tool.Handle.CanTouch = false
	Tool.Enabled = false
	Tool.Parent = workspace

	local Prompt = Instance.new("ProximityPrompt")
	Prompt.Parent = Tool.Handle
	Prompt.ActionText = tostring(Tool)
	Prompt.KeyboardKeyCode = Enum.KeyCode.Q
	Prompt.RequiresLineOfSight = false
	Prompt.ObjectText = ""
	Prompt.MaxActivationDistance = 5

	for _, v in Tool:GetDescendants() do
		if v:IsA("BasePart") then
			if not v.CanCollide then
				v:SetNetworkOwner(nil)
				v.CanCollide = true
			end;

		elseif v:IsA("BaseScript") then
			v.Disabled = true
		end;
	end;


	local past = Tool.Handle.Position

	task.delay(1,  function()
		DropConnect = game:GetService("RunService").Heartbeat:Connect( function()
			if not Tool:FindFirstChild("Handle") then
				return;
			end;
			local current = Tool.Handle.Position
			if (current - past).Magnitude < 0.01 then
				Tool:SetAttribute("IsStill", true)
			end;
			past = current
		end);
	end);

	Tool:GetAttributeChangedSignal("IsStill"):Connect( function()
		if Tool:GetAttribute("IsStill") then
			if DropConnect then
				DropConnect:Disconnect()
				DropConnect = nil
			end;

			for _, v in Tool:GetDescendants() do
				if v:IsA("BasePart") then
					v.Anchored = true
				end;
			end;
		end;
	end);

	Prompt.Triggered:Connect( function(playerWhoTriggered: Player)
		local GiveTool

		for _, v in game:GetService("ServerStorage"):GetDescendants() do
			if v.Name == tostring(Tool) and v:IsA("Tool") then
				GiveTool = v
				break;
			end;
		end;

		if GiveTool and not DropConnect then
			local Char: any = playerWhoTriggered.Character or playerWhoTriggered.CharacterAdded:Wait()

			if Char.Humanoid.Health <= 0 then
				return;
			end;

			local Pickup = CreateSound.new(526686369, "Pickup", 0.4, Char.HumanoidRootPart)
			Pickup:Play()
			local New = GiveTool:Clone()
			New.Parent = playerWhoTriggered.Backpack
			Tool:Destroy()

			task.delay(Pickup.TimeLength, function()
				Pickup:Destroy()
			end);
		end;
	end);
end;


function ReplicateFire(player: any, gun: Tool, arg: string, muzzlePosition: Vector3, bulletDirection: Vector3, dmg: number, finalHitPosition: Vector3, raycastResult: any)
	if gun == nil or not gun:IsDescendantOf(workspace) or player.Character.Humanoid.Health == 0 then return; end;

	if arg == "Discharge" then
		--	local s = os.clock()

		local hitInstance = raycastResult.Instance

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
					if targetPlayer == nil or TeamCheck(player, targetPlayer, gun) then
						local HitSFX = CreateSound.new(2615387841, "Hit", 0.5, hitHumanoid.Parent.HumanoidRootPart)
						HitSFX.RollOffMaxDistance = 50
						HitSFX:Play()
						game:GetService("Debris"):AddItem(HitSFX, 2)
						hitHumanoid:TakeDamage(dmg)
					end;
				end;
			end;
		end;
		--print((os.clock()-s)*1e+6, "μs")
	end;
end

task.defer(function()
	task.delay(1.5, function()
		for _,v in workspace:GetDescendants() do
			task.wait()
			if v:IsA("Accessory") then
				for _,v in v:GetDescendants() do
					if v:IsA("BasePart") then
						CollectionService:AddTag(v, "RayIgnore")
						PhysService:SetPartCollisionGroup(v, "Accessory")
					end;
				end;
			end;
		end;
	end);

	do
		Players.PlayerAdded:Connect( function(player: Player) 
			player.CharacterAdded:Connect( function(character: Model)  
				task.wait(1)
				for _,v in character:GetChildren() do
					if v:IsA("Accessory") then
						for _,v in v:GetDescendants() do
							if v:IsA("BasePart") then
								CollectionService:AddTag(v, "RayIgnore")
								PhysService:SetPartCollisionGroup(v, "Accessory")
							end;
						end;
					end;
				end;
			end);
		end);
	end;
end)

---------------------------------------------
-- N E T W O R K \ C O N N E C T I O N S  --
---------------------------------------------

for _,v in Players:GetPlayers() do
	HandleCharAdded(v)
end;

Players.PlayerAdded:Connect(function(player: Player) 
	player.CharacterAdded:Connect(function(character: Model) 
		HandleCharAdded(player)	
	end);
end);

network:OnEvent({
	createKnifeSounds = function(Player: (Player), Tool : (any) )
		if not Tool or Tool.Parent ~= Player.Character or not Tool:FindFirstChild("Main") or Tool:GetAttribute("Inited") then
			return;
		end;
		Tool:SetAttribute("Inited", true)
		
		local MainModule = Import(Tool.Main)
		
		for Name: (string), SoundID: (number) in MainModule.Sounds do
			local New = CreateSound.new(SoundID, Name, 1, Tool.Handle)
		end;
		
	end,
		
	DischargeWeapon = function(Player: Player, gun: any, Action: string, MuzzlePos: Vector3, BulletDir: Vector3, Dmg: number, finalHitPos: Vector3, hitInfo: any)
		network:FireAllClientsWithException(Player, "mkHitEffects", "DisplayEffects", gun, MuzzlePos, finalHitPos, hitInfo)
		ReplicateFire(Player, gun, Action, MuzzlePos, BulletDir, Dmg, finalHitPos, hitInfo)
	end,
	
	Reload = function(Player: (Player), GunMeta: (any) )
		if not Player or not GunMeta or GunMeta.Tool.Parent ~= Player.Character then
			return;
		end;
		local gun = GunMeta.Tool
		if Settings.EnableS19ReloadSounds then

            if not gun.Handle:FindFirstChild("magIn") then

                local MagInSound = CreateSound.new(330005593, "magIn", 1, gun.Handle)
                local magOut = CreateSound.new(295387403, "magOut", 1, gun.Handle)

            end;

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

			if not gun:IsDescendantOf(Player.Character) then
				return;
			end;

			if not MagPart or not MagPart:IsA("BasePart") then
				if gun.Handle:FindFirstChild("Reload") then
					gun.Handle.Reload:Play()
				end
				return;
			end;


			local MagInTime = Settings.MaginTime or 1
			local MagIn = gun.Handle.magIn
			local magOut = gun.Handle.magOut

			MagPart.Transparency = 1
			magOut:Play()

			task.delay(MagInTime, function()
				if not gun:IsDescendantOf(Player.Character) then
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
   end,
	
	createGun = function(Player: (Player), Tool: (any) )
		if not Player or not Player.Character or Tool.Parent ~= Player.Character then
			local Settings = Import(Tool.Settings)
			for Name, ID in Settings.Sounds do
				if not Tool.Handle:FindFirstChild(Name) then
					CreateSound.new(ID, Name, 1, Tool.Handle)
				end;
			end;
		end;
	end,
	
	useMelee = function(Player: (Player), Tool: (Tool), rayResult: (any) )
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
	
	useMedkit = function(Player: (Player), Tool: any)
		if not Tool or Tool.Parent ~= Player.Character then
			return;
		end;
		
		Player.Character.Humanoid.Health = Player.Character.Humanoid.MaxHealth
		
		Tool:Destroy()
		
		network:FireClient(Player, "NotifyPlayer", "You start to feel better.")
	end,
	
	dropFirearm = function(Player: (Player), gun: any)
		DropGun(Player, gun)
	end,
	
	
	toggleFlashLight = function(Player: (Player))
		if not Player.Character then
			return;
		end;
		local FlashAttribute = Player.Character:GetAttribute("Flashlight")
		
		Player.Character:SetAttribute("Flashlight", not FlashAttribute)

		local Goal = FlashAttribute
		

		if Player.Team == Teams["RAISA"] then
			local new: (Sound) = CreateSound.new(1283290053, "Beep", 1, Player.Character.Head) :: (Sound)
			new:Play()

			task.delay(new.TimeLength, function()
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

			task.delay(new.TimeLength, function()
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
			local ToolOfInterset = Player.Character:FindFirstChildWhichIsA("Tool")
			if ToolOfInterset and ToolOfInterset:FindFirstChild("Muzzle") and ToolOfInterset.Muzzle:FindFirstChild("SpotLight") then
				
				do
					local new: (Sound) = CreateSound.new(1283290053, "Beep", 1, Player.Character.Head) :: (Sound)
					new:Play()

					task.delay(new.TimeLength,  function()
						new:Destroy()
					end);
				end;
			
				local SpotLight = ToolOfInterset.Muzzle.SpotLight
				SpotLight.Enabled = Goal
			end;
		end;
	end,
	
})
network:OnFunction({})

------------------------------------------------------------------------------



return {};
