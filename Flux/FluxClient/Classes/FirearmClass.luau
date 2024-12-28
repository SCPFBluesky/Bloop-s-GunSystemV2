--[[
	FirearmClient.Luau
	--------------------
	Author(s): @WATDAHECKLOL32
	Date: 11-1-24
	Runtime: Shared 
	Information: Client side of the gun sytem
--]]

--!native
--!strict
--!divine-intellect

---------------------------
--   V A R I A B L E S   --
---------------------------

local NormalRequire = require
local require, network, tagged, asset, tween, thread = shared.import("require", "network", "tagged", "asset", "tween", "thread")

local CollectionService = game:GetService("CollectionService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local og

local FirearmShared = game:GetService("ReplicatedStorage").FirearmShared
local MuzzleEffects = game:GetService("ReplicatedStorage").FirearmShared.Stuff.Muzzle:GetChildren()
local Settings = require("GunConfig")


local HitEffects = FirearmShared.Stuff.Effects

local FirearmClient = {}
local Player = game:GetService("Players").LocalPlayer
local char = Player.Character or Player.CharacterAdded:Wait()

local IsReloading, IsLowered, IsMobile, IsEquipped, IsButtonDown, alreadyfiring, FlashEnabled, AlreadyCloned, IsCrawled = false, false, false, false, false, false, false, false, false
local self, CurrentModule: any = nil, nil

local IsReloading = false
local IsLowered = false

local DebouncedRate = 0 
local RNG = Random.new()
local TAU = math.pi * 2
local Mouse = Player:GetMouse()

local SpreadTime = {}
local FiringConnection
local LastFire = 0

local MobileHUD = Player.PlayerGui:WaitForChild("MobileUI").MobileButtons
local LowerButton = MobileHUD.LowerButton
local ReloadButton = MobileHUD.ReloadButton
local FlashButton = MobileHUD.Flashlight

type AnimationTable = {
    Idle: AnimationTrack?,
    Walk: AnimationTrack?,
    Run: AnimationTrack?,
    Lower: AnimationTrack?,
    Reload: AnimationTrack?,
    Crawl: AnimationTrack?,
    Fire: AnimationTrack?
}

local CurrentAnimations: AnimationTable = {
    Idle = nil,
    Walk = nil,
    Run = nil,
    Lower = nil,
    Reload = nil,
    Crawl = nil,
    Fire = nil
}


---------------------------
--   R A Y C A S T   --
---------------------------

local CONST_RANGE = 1000
local RayParams = RaycastParams.new()
RayParams.RespectCanCollide = false
RayParams.CollisionGroup = "Bullets"
RayParams.FilterType = Enum.RaycastFilterType.Exclude
RayParams.IgnoreWater = true
local MIN_BULLET_SPREAD_ANGLE, MAX_BULLET_SPREAD_ANGLE = 0.8, 0.8
local SPREAD_INCREMENT = 0.6
local MAX_SPREAD_ANGLE = 13



---------------------------
--  M A I N S C R I P T  --
---------------------------

if UserInputService.TouchEnabled then
    IsMobile = true
end;


@native function PlayAnimation(AnimationName: string, Time: number?)
    local _Time = Time or 0.2
    assert(AnimationName, "Attempt to call PlayAnimation with missing name!")

    local Animation = CurrentAnimations[AnimationName]
    assert(Animation, "Animation not found!")

    if Animation then
        Animation:Play(_Time)
    end
end


@native function StopAnimation(AnimationName: string)
    assert(AnimationName, "Attempt to call StopAnimation with missing name!")

    local Animation = CurrentAnimations[AnimationName]
    assert(Animation, "Animation not found!")

    if Animation then
        Animation:Stop()
    end
end

--[[
	--------------------------------------------------------------------------------------------------
	 @Name : 	 	  ResetWeaponState
	 @Author : @WATDAHECKLOL32
	 @Description : Resets all state control to default values
	 @Params : 	 None
	--------------------------------------------------------------------------------------------------
--]]
@native function ResetWeaponState()
    IsLowered, IsReloading, IsButtonDown, IsEquipped, IsCrawled = false, false, false, false, false
end;


--[[
	--------------------------------------------------------------------------------------------------
	 @Name : 	 	  Reload
	 @Author :        @WATDAHECKLOL32
	 @Description :   Function to reload the weapon
	 @Params : 	      None
	--------------------------------------------------------------------------------------------------
--]]
@native function FirearmClient.Reload()
    if not IsEquipped or not self or not Player.Character or not Player.Character:FindFirstChild("Humanoid") or Player.Character.Humanoid.Health <= 0 or IsReloading or IsCrawled then
        return;
    end;

    if IsLowered or CurrentModule.Ammo == CurrentModule.MaxAmmo then return end;
    
    do
		CurrentModule.Ammo = 0
		network:FireServer("Reload", self)
      --  ReloadRemote:FireServer(self)
        PlayAnimation("Reload", 0)
        --CurrentAnimations.Reload:Play(0.2)
        IsReloading = true
    end

    if CurrentAnimations.Reload then
        
    task.delay(CurrentAnimations.Reload.Length, @native function()
        if IsEquipped then
            if CurrentModule then
                CurrentModule.Ammo = CurrentModule.MaxAmmo
            end
            IsReloading = false
        else
            CurrentAnimations.Reload:Stop()
            IsReloading = false
             end;
        end);
    end
end;


--[[
	--------------------------------------------------------------------------------------------------
	 @Name : 	 	  Holster
	 @Author :        @WATDAHECKLOL32
	 @Description :   Holsters the user's current weapon
	 @Params : 	      None
	--------------------------------------------------------------------------------------------------
--]]
@native function FirearmClient.Holster()
    if not self or not Player.Character or not Player.Character:FindFirstChild("Humanoid") or Player.Character.Humanoid.Health <= 0 or IsReloading then
        return
    end;

    if not CurrentModule.CanLower then return end;

    IsLowered = not IsLowered

    if IsLowered then
        StopAnimation("Idle")
		PlayAnimation("Lower", 0.100000001)
    else
        StopAnimation("Lower")
		PlayAnimation("Idle", 0.100000001)
    end;
end;



@native function getIgnorelist(items: any)
    local ignore = tagged("RayIgnore")

    for _, object in items do
        table.insert(ignore, 1, object)
    end;

    return ignore;
end;



@native function islaoded()
    return Player.Character and Player.Character:FindFirstChild("Humanoid") and Player.Character.Humanoid.Health > 0
end;


@native function canfire()
    return self and islaoded() and not IsReloading and not IsLowered
end;



--[[
	--------------------------------------------------------------------------------------------------
	 @Name : 	 	  mkHitEffects
	 @Author :        @WATDAHECKLOL32
	 @Description :   Handles muzzle, blood, ground effects for the gun system
	 @Params : 	      Action: string - exists for no reason Tool: Gun - The players gun MuzzlePosition: Vector3 - The players muzzle position, HitPos: Vector3 - RaycastHit, RayReult: any - Raycast Result
	--------------------------------------------------------------------------------------------------
--]]
@native function FirearmClient.mkHitEffects(action: string, gun: any, muzzlePos: Vector3, hitPos: Vector3, rayresult: any)
    local FireSound = gun.Handle.Muzzle:FindFirstChild("FireSound") or gun.Handle.Muzzle.Fire:Clone()
    FireSound.Parent = gun.Handle
    FireSound.TimePosition = 0
    FireSound.PlaybackSpeed = 1
    FireSound:Play()
    
    game:GetService("Debris"):AddItem(FireSound, FireSound.TimeLength)
    
    if action ~= "DisplayEffects" then return; end;
    
    local muzzle = gun:FindFirstChild("Handle") and gun.Handle:FindFirstChild("Muzzle")
    
    if muzzle then
        do
            if Settings.ShowMuzzleEffects then
                for _, effect in MuzzleEffects do

                    local Clone = effect:Clone()
                    Clone.Parent = muzzle

                    if Clone:IsA("ParticleEmitter") then
                        Clone:Emit(20)
                    end;

					game:GetService("Debris"):AddItem(Clone, Clone.Name == "Light" and 0.1 or 5)
                end;
            end;
        end;
    end;
    
    if not rayresult or not rayresult.Instance or not rayresult.Normal or not hitPos or 
        typeof(rayresult.Instance) ~= "Instance" or typeof(rayresult.Normal) ~= "Vector3" or 
        typeof(hitPos) ~= "Vector3" then
        return;
    end;



    local attach = HitEffects.Effects:Clone()
    attach.Parent = workspace.Terrain
    attach.CFrame = CFrame.new(hitPos, hitPos + rayresult.Normal)
    
    local hithuam 
    local RayInstance: any = rayresult.Instance or nil
    
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

---------------------------
--  C O N N E C T I O N S  --
---------------------------



--[[
	--------------------------------------------------------------------------------------------------
	 @Name : 	 	  Activated
	 @Author :        @WATDAHECKLOL32
	 @Description :   Handles when the player starts to shoot
	 @Params : 	      None
	--------------------------------------------------------------------------------------------------
--]]
@native function Activated()
	IsButtonDown = true

	while CurrentModule and self and Player.Character and Player.Character.Humanoid.Health > 0 and CurrentModule.Ammo > 0 and not IsReloading and not IsLowered and IsButtonDown do

		if not self or not CurrentModule then
			return;
		end;

		if CurrentAnimations.Fire then
			PlayAnimation("Fire")
		end;

		if not IsButtonDown then
			break;
		end;

		if not IsEquipped or not canfire() or CurrentModule.Ammo <= 0 or not char:FindFirstChild("Head") then
			return;
		end;

		local FirearmCooldown = CurrentModule.RPM

		if CurrentModule.Cooldown then
			if os.clock() - CurrentModule.Cooldown < DebouncedRate then
				return;
			end;
		end;

		if Settings.EnableAltSpread then
			SpreadTime[Player] = (SpreadTime[Player] or 0) + 0.02
			local NewSpread = math.min(SpreadTime[Player] * SPREAD_INCREMENT, MAX_SPREAD_ANGLE)
			MIN_BULLET_SPREAD_ANGLE += NewSpread
			MAX_BULLET_SPREAD_ANGLE += NewSpread
		end;

		if os.clock() - DebouncedRate < FirearmCooldown then
			return;
		end;

		local GunData = self:FindFirstChild("Settings")

		if not GunData then
			Player:Kick("Gun settings not found in your gun. You have been kicked for security reasons.")
		end;


		DebouncedRate = os.clock()
		CurrentModule.Ammo -= 1

		local cameraRay = workspace.CurrentCamera:ScreenPointToRay(Mouse.X, Mouse.Y)

		local spreadCF = CFrame.new(Vector3.new(), cameraRay.Direction) *
			CFrame.fromOrientation(0, 0, RNG:NextNumber(0, math.pi * 2)) *
			CFrame.fromOrientation(math.rad(RNG:NextNumber(MIN_BULLET_SPREAD_ANGLE, MAX_BULLET_SPREAD_ANGLE)), 0, 0)
		local spreadDirection = spreadCF.LookVector

		local StartRay = workspace:Raycast(cameraRay.Origin, spreadDirection * CONST_RANGE, RayParams)
		local Aimpoint = StartRay and StartRay.Position or (cameraRay.Origin + spreadDirection * CONST_RANGE)

		local head = Player.Character and Player.Character:FindFirstChild("Head")
		local headPos = head and head.Position or Vector3.zero

		local bulletDirection = (Aimpoint - headPos).Unit

		local raycastResult = workspace:Raycast(headPos, bulletDirection * CONST_RANGE, RayParams)

		local finalHitPos = raycastResult and raycastResult.Position or Aimpoint
		
		local RayResult = {
			Instance = raycastResult and raycastResult.Instance or nil,
			Normal = raycastResult and raycastResult.Normal or nil,
			Position = raycastResult and raycastResult.Position or Aimpoint
		}


		FirearmClient.mkHitEffects("DisplayEffects", self, headPos, finalHitPos, raycastResult)

		network:FireServer("DischargeGun", self, "Discharge", headPos, bulletDirection, CurrentModule.Damage, finalHitPos, RayResult)
		--[[packet.discharge.send({
			gun = self,
			action = "Discharge",
			muzzlePos = headPos,
			bulletDirection = bulletDirection,
			damage = CurrentModule.Damage,
			finalHitPos = finalHitPos,
			hitInfo = RayResult
		});]]

		task.wait(CurrentModule.RPM)

		if self and CurrentModule then
			if not CurrentModule.Automatic then
				break;
			end;
		end;
	end;

	alreadyfiring = false
	IsButtonDown = false
end;


--[[
	--------------------------------------------------------------------------------------------------
	 @Name : 	 	  InitWeapon
	 @Author :        @WATDAHECKLOL32
	 @Description :   Initializes the weapon
	 @Params : 	      Tool: Tool - The equipped weapon to init
	--------------------------------------------------------------------------------------------------
--]]
@native function InitWeapon(gun: Tool)
    if not Player.Character or Player.Character.Humanoid.Health <= 0 then return; end;

	RayParams.FilterDescendantsInstances = getIgnorelist({Player.Character, workspace.CurrentCamera})

    local equip, unequip
    
    if equip then equip:Disconnect() end;
    if unequip then unequip:Disconnect() end;
    
    local AnimationCache = {}

    equip = gun.Equipped:Connect(@native function()
        
        ResetWeaponState()
        
        IsEquipped = true
        
        local char = Player.Character or Player.CharacterAdded:Wait()
        og = char.Humanoid.WalkSpeed
        local hum = char.Humanoid
        local Animator: Animator = hum.Animator

        self = gun
     
		CurrentModule = NormalRequire(gun:FindFirstChild("Settings")) :: ModuleScript
		
        assert(CurrentModule, "Gun does NOT have Current Module!")
        
        self.ChildRemoved:Connect(@native function(Added: any)
            if Added.Name == "Settings" and Added:IsA("ModuleScript") then
                Player:Kick("Settings module Altered. You have been kicked for security reasons.")
            end;
        end);
        
        for name, anim: any in CurrentAnimations do
            if anim then
                anim:Stop()
                CurrentAnimations[name] = nil
            end;
        end;

        do
            for name, Id in CurrentModule.Animations do
                if not AnimationCache[name] then
                    local NewAnimation = Instance.new("Animation")
                    NewAnimation.AnimationId = "rbxassetid://" .. Id
                    AnimationCache[name] = Animator:LoadAnimation(NewAnimation)
                end;
                CurrentAnimations[name] = AnimationCache[name]
            end;
        end;

        if CurrentAnimations.Idle then
            PlayAnimation("Idle", 0.2)
        end;

        if IsMobile then
            Player.PlayerGui.MobileUI.Enabled = true
        end;


		self.Activated:Connect(@native function()
			if IsMobile then
				return;
			end;
			
			task.spawn(Activated)
        end);
		
		
		UserInputService.TouchStarted:Connect(@native function(input: InputObject, GPE: (boolean) )
			if UserInputService:GetFocusedTextBox() or GPE then
				return;
			end;
			
			
			if input.UserInputType == Enum.UserInputType.Touch then
				task.spawn(Activated)
			end;
		end);

		UserInputService.TouchEnded:Connect(@native function(input: InputObject, GPE : (boolean) )
			if UserInputService:GetFocusedTextBox() or GPE then
				return;
			end;
	
			
			if input.UserInputType == Enum.UserInputType.Touch then
				IsButtonDown, alreadyfiring, SpreadTime = false, false, {}
				MIN_BULLET_SPREAD_ANGLE, MAX_BULLET_SPREAD_ANGLE, MAX_SPREAD_ANGLE = 0.8, 0.8, 13
			end;
		end);
		
        self.Deactivated:Connect(@native function()
			if IsMobile then
				return;
			end;
			
			IsButtonDown, alreadyfiring, SpreadTime = false, false, {}
			MIN_BULLET_SPREAD_ANGLE, MAX_BULLET_SPREAD_ANGLE, MAX_SPREAD_ANGLE = 0.8, 0.8, 13
        end);


        unequip = gun.Unequipped:Connect(@native function()
            
            if self and CurrentModule then if CurrentModule.CanCrawl then
                    UserInputService.MouseBehavior = Enum.MouseBehavior.Default
                    Player.CameraMaxZoomDistance = game:GetService("StarterPlayer").CameraMaxZoomDistance
                    Player.CameraMinZoomDistance = game:GetService("StarterPlayer").CameraMinZoomDistance
                    Player.Character.Humanoid.WalkSpeed = og
                end;
            end;
            
            for _, anim: any in CurrentAnimations do
                anim:Stop()
            end;


            self = nil
            IsEquipped = false
            CurrentModule = nil

            if IsMobile then
                Player.PlayerGui.MobileUI.Enabled = false
            end;

            ResetWeaponState()

        end);
    end);
end;

------------------------------
-- END OF FILE --
------------------------------

@native function FirearmClient.Drop()
	if self then
		network:FireServer("DropWeapon", self)
	end;
end;

@native function FirearmClient.Crawl()
		if not IsEquipped or IsReloading or IsLowered then return end;
	
		if CurrentModule.CanCrawl then
			IsCrawled = not IsCrawled
			if IsCrawled then
				Player.CameraMaxZoomDistance = 7
				Player.CameraMinZoomDistance = 7
				UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter

				Player.Character.Humanoid.WalkSpeed = 0
				PlayAnimation("Crawl", 0.2)
				StopAnimation("Idle")
				--CurrentAnimations.Crawl:Play(0.2)
			else
				Player.CameraMaxZoomDistance = game:GetService("StarterPlayer").CameraMaxZoomDistance
				Player.CameraMinZoomDistance = game:GetService("StarterPlayer").CameraMinZoomDistance

				Player.CameraMode = Enum.CameraMode.Classic
				UserInputService.MouseBehavior = Enum.MouseBehavior.Default
				Player.Character.Humanoid.WalkSpeed = og
				StopAnimation("Crawl")
				PlayAnimation("Idle", 0.2)
				--CurrentAnimations.Idle:Play(0.2)
			end;
		end;
end;



--[[
	--------------------------------------------------------------------------------------------------
	 @Event : 	 	  GetPropertyChangedSignal (https://create.roblox.com/docs/reference/engine/classes/Instance#GetPropertyChangedSignal)
	 @Author :        @WATDAHECKLOL32
	 @Description :   Prevents users from walking during crawl
	 @Params : 	      None
	--------------------------------------------------------------------------------------------------
--]]
Player.Character:WaitForChild("Humanoid"):GetPropertyChangedSignal("WalkSpeed"):Connect(@native function()
    if IsCrawled then
        Player.Character.Humanoid.WalkSpeed = 0
    else
        return;
    end;
end);


--[[
	--------------------------------------------------------------------------------------------------
	 @Event : 	 	  MouseButton1Click (https://create.roblox.com/docs/reference/engine/classes/GuiButton#MouseButton1Click)
	 @Author :        @WATDAHECKLOL32
	 @Description :   (Mobile) Reload
	 @Params : 	      boolean: gameProcessedEvent - GPE
	--------------------------------------------------------------------------------------------------
--]]
ReloadButton.MouseButton1Click:Connect(@native function(gpe: boolean) 
    if not IsEquipped or IsCrawled or gpe then return; end;
    FirearmClient.Reload()
end);

--[[
	--------------------------------------------------------------------------------------------------
	 @Event : 	 	  MouseButton1Click (https://create.roblox.com/docs/reference/engine/classes/GuiButton#MouseButton1Click)
	 @Author :        @WATDAHECKLOL32
	 @Description :   (Mobile) Holster
	 @Params : 	      boolean: gameProcessedEvent - GPE
	--------------------------------------------------------------------------------------------------
--]]
LowerButton.MouseButton1Click:Connect(@native function(gpe: boolean) 
    if not IsEquipped or IsCrawled or gpe then return; end;
	FirearmClient.Holster()
end);


if Player.Character then
    Player.Character.ChildAdded:Connect(@native function(child: Instance) 
        if child:IsA("Tool") and child:FindFirstChild("Settings") and child:FindFirstChild("Handle"):FindFirstChild("Muzzle") then
            InitWeapon(child)
        end;
    end);
end;

Player.CharacterAdded:Connect(@native function(character: Model) 
    Player.Character.ChildAdded:Connect(@native function(child: Instance) 
        if child:IsA("Tool") and child:FindFirstChild("Settings") and child:FindFirstChild("Handle"):FindFirstChild("Muzzle") then
            InitWeapon(child)
        end;
    end);
end);

return FirearmClient

