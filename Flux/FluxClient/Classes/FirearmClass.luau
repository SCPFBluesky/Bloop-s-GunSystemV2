--[[
	Name: FirearmClass.luau
	Author(s): @WATDAHECKLOL32
	Date: 2025-01-09 23:46:22
	RunTimeContext: Shared
	Information: Handles client side of the weapon system
]]
--!nonstrict
--!native

local FirearmClass = {};
FirearmClass.__index = FirearmClass

local Import = require
local require, network, tagged, asset, tween, thread = shared.import("require", "network", "tagged", "asset", "tween", "thread")

local MuzzleEffects = game:FindService("ReplicatedStorage").FirearmShared.Stuff.Muzzle
local HitEffects = game:FindService("ReplicatedStorage").FirearmShared.Stuff.Effects
local CreateAnimation = require("CreateAnimation")
local Settings = require("GunConfig")
local Icon = require("Icon")
local Player = game:FindService("Players").LocalPlayer

local DebounceRate = 0
local IsMobile = game:GetService("UserInputService").TouchEnabled
local og

local Camera = workspace.CurrentCamera
local UserGameSettings = UserSettings():GetService("UserGameSettings")

local RNG = Random.new()
local Mouse = Player:GetMouse()
local char = Player.Character or Player.CharacterAdded:Wait()



---------------------------
--   R A Y C A S T   --
---------------------------

local RayParams = RaycastParams.new()
RayParams.RespectCanCollide = false
RayParams.CollisionGroup = "Bullets"
RayParams.FilterType = Enum.RaycastFilterType.Exclude
RayParams.IgnoreWater = true

@native function getIgnorelist(items: any)
	local ignore = tagged("RayIgnore")

	for _, object in items do
		table.insert(ignore, 1, object)
	end;

	return ignore;
end;


do
	if IsMobile then

		local ShiftLock = Icon.new()
			:setLabel("Enable Shift Lock")


		ShiftLock.toggled:Connect(@native function(State: (boolean), Source: (string) )
			if State then
				--Player.PlayerGui.MobileUI.MobileButtons.Crosshair.Position = UDim2.new(-3.194, 0,-0.115, 0)
				ShiftLock:setLabel("Disable Shift Lock")
				UserGameSettings.RotationType = Enum.RotationType.CameraRelative
				char.Humanoid.CameraOffset = Vector3.new(1.75, 0, 0)
			else
				--Player.PlayerGui.MobileUI.MobileButtons.Crosshair.Position = UDim2.new(-3.174, 0,-0.262, 0)
				ShiftLock:setLabel("Enable Shift Lock")
				UserGameSettings.RotationType = Enum.RotationType.MovementRelative
				char.Humanoid.CameraOffset = Vector3.new(0, 0, 0)
			end;
		end);
	end;
end;

--[[
	--------------------------------------------------------------------------------------------------
	 @Name :  FirearmClass.new
	 @Author : @WATDAHECKLOL32
	 @Description : Initlizes a new weapon
	 @Params : Tool - Firearm - The tool to init
	--------------------------------------------------------------------------------------------------
--]]
@native function FirearmClass.new(Firearm: (Tool) )
	assert(Firearm, "Attempt to call FirearmClass.new, but no tool was provided.")
	
	if (not Player or not Player.Character or not Player.Character:FindFirstChild("HumanoidRootPart") or not Player.Character:FindFirstChild("Humanoid"):FindFirstChild("Animator") or not Firearm:FindFirstChild("Settings")) then
		return;
	end;

	RayParams.FilterDescendantsInstances = getIgnorelist({Player.Character, workspace.CurrentCamera})

	local Settings = Import(Firearm:FindFirstChild("Settings"))
	
	local Weapon = setmetatable({
		Tool = Firearm;
		Settings = Settings;
		RPM = Settings.RPM;
		Damage = Settings.Damage;
		CanLower = Settings.CanLower;
		CanDrop = Settings.CanDrop;
		MaxAmmo = Settings.MaxAmmo;
		Cooldown = Settings.Cooldown;
		Spread = Settings.Spread;
		Automatic = Settings.Automatic;
		Animations = {
			Idle = nil;
			Fire = nil;
			Lower = nil;
			Reload = nil;
			Crawl = nil
		};
		CanCrawl = Settings.CanCrawl or false;
		IsEquipped = false;
		IsHolstered = false;
		IsCrawling = false;
		IsReloading = false;
		ButtonDown = false;
		
		MIN_BULLET_SPREAD_ANGLE = 0.4;
		MAX_BULLET_SPREAD_ANGLE = 0.4;
		SPREAD_INCREMENT = 1;
		MAX_SPREAD_ANGLE = 10;
		SpreadTime = {};
	}, FirearmClass);
		
	network:FireServer("createGun", Firearm)
	return Weapon;
end;


--[[
	--------------------------------------------------------------------------------------------------
	 @Name :  FirearmClass:Equip()
	 @Author : @WATDAHECKLOL32
	 @Description : Fires when the gun is equipped.
	 @Params : None
	--------------------------------------------------------------------------------------------------
--]]
@native function FirearmClass:Equip()
	if self.IsEquipped then
		return;
	end;
	
	self.IsEquipped = true;
	
	if IsMobile then
		Player.PlayerGui.MobileUI.Enabled = true
	end;
	
	for AnimationName, ID in self.Settings.Animations do
		if not self.Animations[AnimationName] then
			local NewInstance = Instance.new("Animation")
			NewInstance.AnimationId = "rbxassetid://" .. ID
			self.Animations[AnimationName] = Player.Character:WaitForChild("Humanoid").Animator:LoadAnimation(NewInstance)
		end
	end
	
	if self and self.Tool and self.Tool.Parent == Player.Character and self.Animations.Idle then
		self.Animations.Idle:Play(0.2)
	end
	
end;

@native function FirearmClass:Unequip()
	if not self.IsEquipped then
		return;
	end;
	
	self.IsEquipped = false
	
	if IsMobile then
		Player.PlayerGui.MobileUI.Enabled = false
	end;
	
	for _, Animation in self.Animations do
		if Animation.IsPlaying then
			Animation:Stop()
		end;
	end;
end;

@native function FirearmClass:Reload()
	if not self.IsEquipped or self.IsHolstered or self.IsReloading or self.Settings.Ammo == self.MaxAmmo or self.IsCrawling then
		return;
	end;
	
	if self.Animations.Reload then
		network:FireServer("Reload", self)
		self.IsReloading = true
		self.Animations.Reload:Play(0.2)
		task.delay(self.Animations.Reload.Length, @native function()
			self.IsReloading = false
			self.Settings.Ammo = self.MaxAmmo
		end);
	end;
end;

@native function FirearmClass:Crawl()
	if not self.IsEquipped or not Player.Character then
		return;
	end;
	
	if not self.CanCrawl then
		return;
	end;
	
	self.IsCrawling = not self.IsCrawling

	
	if self.IsCrawling and Player.Character and Player.Character:FindFirstChildWhichIsA("Humanoid") then
		og = Player.Character.Humanoid.WalkSpeed

		Player.Character.Humanoid.WalkSpeed = 0
		self.Animations.Idle:Stop(0.2)
		self.Animations.Crawl:Play(0.2)
	else
		Player.Character.Humanoid.WalkSpeed = og

		og = nil
		self.Animations.Crawl:Stop(0.2)
		self.Animations.Idle:Play(0.2)
	end;
	
end;

--[[
	--------------------------------------------------------------------------------------------------
	 @Name :  FirearmClass:MKHitEffects()
	 @Author : @WATDAHECKLOL32
	 @Description : Handles sounds, and visuals for the weapon system, gets called immediately on the client to mask Latency.
	 @Params : string - Action - Useless as shit and exists for no reason, Vector3(s) = muzzlePos, hitPos - Self explaintory, any: rayresult - gun raycast result, tool: the weapon that got fired.
	--------------------------------------------------------------------------------------------------
--]]
@native function FirearmClass:MKHitEffects(action: string, muzzlePos: Vector3, hitPos: Vector3, rayresult: any, Tool: (any) )
	local FireSound = Tool.Handle:FindFirstChild("FireSound") or Tool.Handle.Fire:Clone()
	FireSound.SoundGroup = game:FindService("SoundService").Gun
	FireSound.Parent = Tool.Handle
	FireSound:Play()

	game:GetService("Debris"):AddItem(FireSound, FireSound.TimeLength)

	if action ~= "DisplayEffects" then return; end;

	local muzzle = Tool:FindFirstChild("Handle") and Tool.Handle:FindFirstChild("Muzzle")
	
	if Settings.ShowMuzzleEffects then
		for _, effect in MuzzleEffects:GetChildren() do

			local Clone = effect:Clone()
			Clone.Parent = muzzle

			if Clone:IsA("ParticleEmitter") then
				Clone:Emit(20)
			end;

			game:GetService("Debris"):AddItem(Clone, Clone.Name == "Light" and 0.1 or 5)
		end;
	end;

	if not rayresult or not rayresult.Instance or not rayresult.Normal or not hitPos or 
		typeof(rayresult.Instance) ~= "Instance" or typeof(rayresult.Normal) ~= "Vector3" or 
		typeof(hitPos) ~= "Vector3" then
		return;
	end;



	local attach = HitEffects.Effects:Clone()
	attach.Parent = workspace.Terrain
	--attach.CFrame = CFrame.new(hitPos, hitPos + rayresult.Normal)
	attach.CFrame = attach.CFrame:ToObjectSpace(CFrame.new(hitPos, hitPos + rayresult.Normal))
	local hithuam 
	local RayInstance: any = rayresult.Instance

	if RayInstance and RayInstance.Parent and RayInstance.Parent:FindFirstChildWhichIsA("Humanoid") then
		hithuam = RayInstance.Parent.Humanoid
	end 

	if hithuam then
		if Settings.ShowBlood == true then
			attach.Blood:Emit(10)
		end;
	else
		attach.Flash:Emit(10)
		attach.Smoke:Emit(10)
		game:GetService("Debris"):AddItem(attach, 2)
	end;
end;

--[[
	--------------------------------------------------------------------------------------------------
	 @Name :  FirearmClass:Fire()
	 @Author : @WATDAHECKLOL32
	 @Description : Handles sounds, and visuals for the weapon system, gets called immediately on the client to mask Latency.
	 @Params : None
	--------------------------------------------------------------------------------------------------
--]]
@native function FirearmClass:Fire()
	while self and Player and Player.Character and Player.Character.Humanoid and Player.Character.Humanoid.Health > 0 and self.Settings.Ammo > 0 and not self.IsHolstered and not self.IsReloading and self.ButtonDown and self.IsEquipped do
		if not self.IsEquipped then
			return;
		end;
		
		
		local Cooldown = self.Cooldown
		local RPM = self.RPM
		
		if Cooldown then
			if os.clock() - Cooldown < DebounceRate then
				return;
			end;
		end;
		

		if Settings.EnableAltSpread then
			self.SpreadTime[Player] = (self.SpreadTime[Player] or 0) + 0.01
			local NewSpread = math.min(self.SpreadTime[Player] * self.SPREAD_INCREMENT, self.MAX_SPREAD_ANGLE)
			self.MIN_BULLET_SPREAD_ANGLE += NewSpread
			self.MAX_BULLET_SPREAD_ANGLE += NewSpread
		end;

		if os.clock() - DebounceRate < RPM then
			return;
		end;

		local GunData = self.Tool:FindFirstChild("Settings")

		if not GunData then
			Player:Kick("Gun settings not found in your gun. You have been kicked for security reasons.")
		end;

		
		if self.Animations.Fire then
			self.Animations.Fire:Play(0.2)	
		end;
		
		DebounceRate = os.clock()
		
		
		self.Settings.Ammo -= 1
	

		local cameraRay
		local spreadCF
		local spreadDirection
		local StartRay
		local Aimpoint
		local head
		local headPos
		local bulletDirection
		local finalHitPos
		local raycastResult
		local RayResult

		if IsMobile then
			local CameraPos = workspace.CurrentCamera.CFrame.Position

			local CameralookVector = Camera.CFrame.LookVector

			spreadCF = CFrame.new(Vector3.new(), CameralookVector) *
				CFrame.fromOrientation(0, 0, RNG:NextNumber(0, math.pi * 2)) *
				CFrame.fromOrientation(math.rad(RNG:NextNumber(self.MIN_BULLET_SPREAD_ANGLE, self.MAX_BULLET_SPREAD_ANGLE)), 0, 0)
			spreadDirection = spreadCF.LookVector

			StartRay = workspace:Raycast(CameraPos, spreadDirection * 1000, RayParams)
			Aimpoint = StartRay and StartRay.Position or (CameraPos + spreadDirection * 1000)

			head = Player.Character:FindFirstChild("Head")
			headPos = head and head.Position or Vector3.zero
			bulletDirection = (Aimpoint - headPos).Unit
			raycastResult = workspace:Raycast(headPos, bulletDirection * 1000, RayParams)
			finalHitPos = raycastResult and raycastResult.Position or Aimpoint

			RayResult = {
				Instance = raycastResult and raycastResult.Instance,
				Normal = raycastResult and raycastResult.Normal,
				Position = raycastResult and raycastResult.Position or Aimpoint
			}
		else
			cameraRay = workspace.CurrentCamera:ScreenPointToRay(Mouse.X, Mouse.Y)
			spreadCF = CFrame.new(Vector3.new(), cameraRay.Direction) *
				CFrame.fromOrientation(0, 0, RNG:NextNumber(0, math.pi * 2)) *
				CFrame.fromOrientation(math.rad(RNG:NextNumber(self.MIN_BULLET_SPREAD_ANGLE, self.MAX_BULLET_SPREAD_ANGLE)), 0, 0)
			spreadDirection = spreadCF.LookVector

			StartRay = workspace:Raycast(cameraRay.Origin, spreadDirection * 1000, RayParams)
			Aimpoint = StartRay and StartRay.Position or (cameraRay.Origin + spreadDirection * 1000)
			head = Player.Character and Player.Character:FindFirstChild("Head")
			headPos = head and head.Position or Vector3.zero

			bulletDirection = (Aimpoint - headPos).Unit
			raycastResult = workspace:Raycast(headPos, bulletDirection * 1000, RayParams)
			finalHitPos = raycastResult and raycastResult.Position or Aimpoint

			RayResult = {
				Instance = raycastResult and raycastResult.Instance,
				Normal = raycastResult and raycastResult.Normal,
				Position = raycastResult and raycastResult.Position or Aimpoint
			}
		end;

		FirearmClass:MKHitEffects("DisplayEffects", headPos, finalHitPos, raycastResult, self.Tool)

		network:FireServer("DischargeWeapon", self.Tool, "Discharge", headPos, bulletDirection, self.Damage, finalHitPos, RayResult)
		task.wait(self.RPM)

		if not self.Automatic then
			break;
		end;
	end;

	self.IsButtonDown = false
end;

--[[
	--------------------------------------------------------------------------------------------------
	 @Name :  FirearmClass:Holster()
	 @Author : @WATDAHECKLOL32
	 @Description : Holsters (Lowers) the player's weapon.
	 @Params : None
	--------------------------------------------------------------------------------------------------
--]]
@native function FirearmClass:Holster()
	if not self or not Player.Character or not self.IsEquipped or self.IsReloading or not self.CanLower or self.IsCrawling then
		return;
	end;
	
	if self.IsEquipped then
		self.IsHolstered = not self.IsHolstered
		if self.IsHolstered then
			self.Animations.Idle:Stop()
			self.Animations.Lower:Play()
		else
			self.Animations.Lower:Stop()
			self.Animations.Idle:Play()
		end;
	end;
end;



return FirearmClass;


