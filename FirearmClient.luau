--[[
	FirearmClient.Luau
	--------------------
	Author(s): @DrBIoop
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

local CollectionService = game:GetService("CollectionService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local CurrentFlashState = false
local og

local FirearmShared = game:GetService("ReplicatedStorage").FirearmShared
local MuzzleEffects = game:GetService("ReplicatedStorage").FirearmShared.Stuff.Muzzle:GetChildren()

local packet = require(game:GetService("ReplicatedStorage").packet)
local Tagged = require(FirearmShared.Tagged)

local ReloadRemote = FirearmShared.Remotes.Reload
local HitEffects = FirearmShared.Stuff.Effects
local FlashRemote = FirearmShared.Remotes.Flashlight

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
--   S E T T I N G S   --
---------------------------

local Settings = {
    ShowBlood = true, -- Show blood?
    ShowMuzzleEffects = true, -- Show muzzle?
}


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
	 @Author : @DrBIoop
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
	 @Author :        @DrBIoop
	 @Description :   Function to reload the weapon
	 @Params : 	      None
	--------------------------------------------------------------------------------------------------
--]]
@native function Reload()
    if not IsEquipped or not self or not Player.Character or not Player.Character:FindFirstChild("Humanoid") or Player.Character.Humanoid.Health <= 0 or IsReloading then
        return;
    end;

    if IsLowered or CurrentModule.Ammo == CurrentModule.MaxAmmo then return end;
    
    do
        CurrentModule.Ammo = 0
        ReloadRemote:FireServer(self)
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
	 @Author :        @DrBIoop
	 @Description :   Holsters the user's current weapon
	 @Params : 	      None
	--------------------------------------------------------------------------------------------------
--]]
@native function Holster()
    if not self or not Player.Character or not Player.Character:FindFirstChild("Humanoid") or Player.Character.Humanoid.Health <= 0 or IsReloading then
        return
    end;

    if not CurrentModule.CanLower then return end;

    IsLowered = not IsLowered

    if IsLowered then
        StopAnimation("Idle")
        PlayAnimation("Lower")
    else
        StopAnimation("Lower")
        PlayAnimation("Idle")
    end;
end;



@native function getIgnorelist(items: any)
    local ignore = Tagged("RayIgnore")

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
	 @Name : 	 	  RealFire
	 @Author :        @DrBIoop
	 @Description :   Shoots the user's current gun
	 @Params : 	      none
	--------------------------------------------------------------------------------------------------
--]]
@native function RealFire()
    if not IsEquipped or not canfire() or CurrentModule.Ammo <= 0 or not char:FindFirstChild("Head") then
        return;
    end;

    local FirearmCooldown = CurrentModule.RPM

    if os.clock() - DebouncedRate < FirearmCooldown then
        return;
    end;

    local GunData = self:FindFirstChild("Settings")
    
    if not GunData then
        Player:Kick("Gun settings not found in your gun. You have been kicked for security reasons.")
    end;

    RayParams.FilterDescendantsInstances = getIgnorelist({Player.Character, workspace.CurrentCamera})

    DebouncedRate = os.clock()
    CurrentModule.Ammo -= 1

    local cameraRay = workspace.CurrentCamera:ScreenPointToRay(Mouse.X, Mouse.Y)
    local spreadCF = CFrame.new(Vector3.new(), cameraRay.Direction) *
        CFrame.fromOrientation(0, 0, RNG:NextNumber(0, TAU)) *
        CFrame.fromOrientation(math.rad(RNG:NextNumber(MIN_BULLET_SPREAD_ANGLE, MAX_BULLET_SPREAD_ANGLE)), 0, 0)
    local spreadDirection = spreadCF.LookVector

    local raycastResult = workspace:Raycast(cameraRay.Origin, spreadDirection * CONST_RANGE, RayParams)
    local aimPoint = raycastResult and raycastResult.Position or (cameraRay.Origin + spreadDirection * CONST_RANGE)

    local head = Player.Character and Player.Character:FindFirstChild("Head")
    local headPos = head.Position
    local bulletDirection = (aimPoint - headPos).Unit

    local finalRaycastResult = workspace:Raycast(headPos, bulletDirection * CONST_RANGE, RayParams)
    local finalHitPos = finalRaycastResult and finalRaycastResult.Position or aimPoint

    local RayResult = {
        Instance = finalRaycastResult and finalRaycastResult.Instance or nil,
        Normal = finalRaycastResult and finalRaycastResult.Normal or nil
    }

    mkHitEffects("DisplayEffects", self, headPos, finalHitPos, raycastResult)

    packet.discharge.send({
        gun = self,
        action = "Discharge",
        muzzlePos = headPos,
        bulletDirection = bulletDirection,
        damage = CurrentModule.Damage,
        finalHitPos = finalHitPos,
        hitInfo = RayResult
    });
    
end;



--[[
	--------------------------------------------------------------------------------------------------
	 @Name : 	 	  mkHitEffects
	 @Author :        @DrBIoop
	 @Description :   Handles muzzle, blood, ground effects for the gun system
	 @Params : 	      Action: string - exists for no reason Tool: Gun - The players gun MuzzlePosition: Vector3 - The players muzzle position, HitPos: Vector3 - RaycastHit, RayReult: any - Raycast Result
	--------------------------------------------------------------------------------------------------
--]]
@native function mkHitEffects(action: string, gun: any, muzzlePos: Vector3, hitPos: Vector3, rayresult: any)
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
                        Clone:Emit(15)
                    end;

                    local lifetime = (Clone.Name == "Light") and 0.1 or 3
                    game:GetService("Debris"):AddItem(Clone, lifetime)
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
            attach.Blood:Emit(20)
        end;
    else
        attach.Flash:Emit(20)
        attach.Smoke:Emit(20)
        game:GetService("Debris"):AddItem(attach, attach.Smoke.Lifetime.Max + 0.1)
    end;
end;

---------------------------
--  C O N N E C T I O N S  --
---------------------------

--[[
	--------------------------------------------------------------------------------------------------
	 @Name : 	 	  Activated
	 @Author :        @DrBIoop
	 @Description :   Handles when the player starts to shoot
	 @Params : 	      None
	--------------------------------------------------------------------------------------------------
--]]
@native function Activated()
    -- warn("function")
    IsButtonDown = true
    
    while CurrentModule and self and Player.Character and Player.Character.Humanoid.Health > 0 and CurrentModule.Ammo > 0 and not IsReloading and not IsLowered and IsButtonDown do
        
        if not self or not CurrentModule then
            return;
        end;
        
        if CurrentAnimations.Fire then
            CurrentAnimations.Fire:Play()
        end
        
        if not IsButtonDown then
            break;
        end;

        --warn("Shooting")
        alreadyfiring = true
        task.spawn(RealFire)
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
	 @Author :        @DrBIoop
	 @Description :   Initializes the weapon
	 @Params : 	      Tool: Tool - The equipped weapon to init
	--------------------------------------------------------------------------------------------------
--]]
@native function InitWeapon(gun: Tool)
    if not Player.Character or Player.Character.Humanoid.Health <= 0 then return; end;

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
     
        CurrentModule = require(gun:FindFirstChild("Settings"))
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
            CurrentAnimations.Idle:Play(0.2)
        end;

        if IsMobile then
            Player.PlayerGui.MobileUI.Enabled = true
        end;


        self.Activated:Connect(@native function()
            Activated()
        end);
        
        self.Deactivated:Connect(@native function()
            IsButtonDown, alreadyfiring = false, false
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


--[[
	--------------------------------------------------------------------------------------------------
	 @Event : 	 	  InputBegan (https://create.roblox.com/docs/reference/engine/classes/UserInputService#InputBegan)
	 @Author :        @DrBIoop
	 @Description :   M249 Crawling
	 @Params : 	      InputObject: InputObject - players input, boolean: gameProcessedEvent - GPE
	--------------------------------------------------------------------------------------------------
--]]
UserInputService.InputBegan:Connect(@native function(input: InputObject, gameProcessedEvent: boolean) 
    if gameProcessedEvent then 
        return;
    end;
    
    if input.UserInputType == Enum.UserInputType.Keyboard and input.KeyCode == Enum.KeyCode.X then
        
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
end);


--[[
	--------------------------------------------------------------------------------------------------
	 @Event : 	 	  GetPropertyChangedSignal (https://create.roblox.com/docs/reference/engine/classes/Instance#GetPropertyChangedSignal)
	 @Author :        @DrBIoop
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
	 @Author :        @DrBIoop
	 @Description :   (Mobile) Reload
	 @Params : 	      boolean: gameProcessedEvent - GPE
	--------------------------------------------------------------------------------------------------
--]]
ReloadButton.MouseButton1Click:Connect(@native function(gpe: boolean) 
    if not IsEquipped or IsCrawled or gpe then return; end;
    Reload()
end);

--[[
	--------------------------------------------------------------------------------------------------
	 @Event : 	 	  MouseButton1Click (https://create.roblox.com/docs/reference/engine/classes/GuiButton#MouseButton1Click)
	 @Author :        @DrBIoop
	 @Description :   (Mobile) Holster
	 @Params : 	      boolean: gameProcessedEvent - GPE
	--------------------------------------------------------------------------------------------------
--]]
LowerButton.MouseButton1Click:Connect(@native function(gpe: boolean) 
    if not IsEquipped or IsCrawled or gpe then return; end;
    Holster()
end);

--[[
	--------------------------------------------------------------------------------------------------
	 @Event : 	 	  InputBegan (https://create.roblox.com/docs/reference/engine/classes/UserInputService#InputBegan)
	 @Author :        @DrBIoop
	 @Description :   (PC) Reload
	 @Params : 	      InputObject: InputObject - players input, boolean: gameProcessedEvent - GPE
	--------------------------------------------------------------------------------------------------
--]]
UserInputService.InputBegan:Connect(@native function(input: InputObject, gameProcessedEvent: boolean) 
    if gameProcessedEvent then
        return;
    end;
    
    if IsCrawled then return; end;
    
    if input.UserInputType == Enum.UserInputType.Keyboard and input.KeyCode == Enum.KeyCode.R then
        if not IsEquipped then return; end;
        Reload()
    end;
end);

--[[
	--------------------------------------------------------------------------------------------------
	 @Event : 	 	  Listen (https://ffrostfall.github.io/ByteNet/api/functions/definePacket/)
	 @Author :        @DrBIoop
	 @Description :   Inits the remote event
	 @Params : 	      any: data the data that got sent to the fake remote
	--------------------------------------------------------------------------------------------------
--]]
packet.MKHitEffects.listen(@native function(data: any)
    local action = data.action
    local gun = data.gun
    local muzzlePos = data.muzzlePos
    local hitPos = data.hitPos
    local rayresult = data.rayresult

    mkHitEffects(action, gun, muzzlePos, hitPos, rayresult)
end);

--[[
	--------------------------------------------------------------------------------------------------
	 @Event : 	 	  InputBegan (https://create.roblox.com/docs/reference/engine/classes/UserInputService#InputBegan)
	 @Author :        @DrBIoop
	 @Description :   (PC) Holster
	 @Params : 	      InputObject: InputObject - players input, boolean: gameProcessedEvent - GPE
	--------------------------------------------------------------------------------------------------
--]]

UserInputService.InputBegan:Connect(@native function(input: InputObject, gameProcessedEvent: boolean) 
    if not IsEquipped or IsCrawled or gameProcessedEvent then return; end;

    if input.UserInputType == Enum.UserInputType.Keyboard and input.KeyCode == Enum.KeyCode.E then
        Holster()
    end;
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
