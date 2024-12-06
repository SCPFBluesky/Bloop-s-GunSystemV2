--[[
	FirearmClient.Luau
	--------------------
	Author(s): @DrBIoop
	Date: 11-1-24
	Runtime: Shared 
	Information: Client side of the gun sytem
--]]

--!native
--!nonstrict

---------------------------
--   V A R I A B L E S   --
---------------------------
local CollectionService = game:GetService("CollectionService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")


local FirearmShared = game:GetService("ReplicatedStorage"):WaitForChild("FirearmShared")
local packet = require(game:GetService("ReplicatedStorage").packet)
local packet2 = require(game:GetService("ReplicatedStorage").packet2)
local Dic = require(FirearmShared.Dictionary)
local Tagged = require(FirearmShared.Tagged)
local ReloadRemote =FirearmShared.Remotes.Reload
local HitEffects = FirearmShared.Stuff.Effects
local FlashRemote = FirearmShared.Remotes.Flashlight

local FirearmClient = {}
local Player = game:GetService("Players").LocalPlayer
local char = Player.Character or Player.CharacterAdded:Wait()

local IsReloading, IsLowered, IsMobile, IsEquipped, IsButtonDown, alreadyfiring, FlashEnabled, AlreadyCloned, IsCrawled = false, false, false, false, false, false, false, false, false
local firingTimes, self, CurrentModule = {}, nil, nil

local IsReloading = false
local IsLowered = false

local firingTimes = {}
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

local CurrentAnimations = {
    Idle = nil,
    Lower = nil,
    Reload = nil,
    Crawl = nil
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






if UserInputService.TouchEnabled == true then
    IsMobile = true
end;

--[[
	--------------------------------------------------------------------------------------------------
	 @Name : 	 	  ResetWeaponState
	 @Author : @DrBIoop
	 @Description : Resets all state control to default values
	 @Params : 	 boolean: IsReset - Resets ammo
	--------------------------------------------------------------------------------------------------
--]]
@native function ResetWeaponState(isReset: boolean)
    if isReset then
        --warn("is true")
        if CurrentModule then
            --warn("found module")
            --warn(CurrentModule)
            --warn(CurrentModule.Ammo)
            --warn(CurrentModule.MaxAmmo)
            CurrentModule.Ammo = CurrentModule.MaxAmmo
            --warn("after:" ..CurrentModule.Ammo)
        end;
    end;

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
        return
    end

    if IsLowered or CurrentModule.Ammo == CurrentModule.MaxAmmo then return end
    do
        CurrentModule.Ammo = 0
        ReloadRemote:FireServer(self)
        CurrentAnimations.Reload:Play(0.2)
        IsReloading = true
    end

    task.spawn(@native function()
        CurrentAnimations.Reload.Ended:Wait()
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

    if CurrentModule.CanLower == false then return end;

    IsLowered = not IsLowered

    if IsLowered == true then
        CurrentAnimations.Idle:Stop()
        CurrentAnimations.Lower:Play(0.2)
    else
        CurrentAnimations.Lower:Stop()
        CurrentAnimations.Idle:Play(0.2)
    end;
end;




local function getIgnorelist(items: any)
    local ignore = Tagged("RayIgnore")

    for _, object in items do
        table.insert(ignore, 1, object)
    end;

    return ignore
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
    if not IsEquipped or not canfire() or CurrentModule.Ammo <= 0 then return end;
    local FirearmCooldown = CurrentModule.RPM
    if tick() - DebouncedRate < FirearmCooldown then
        return  
    end
    RayParams.FilterDescendantsInstances = getIgnorelist({Player.Character, workspace.CurrentCamera})

    DebouncedRate = tick() 
    CurrentModule.Ammo -= 1

    local cameraRay = workspace.CurrentCamera:ScreenPointToRay(Mouse.X, Mouse.Y)
    local spreadDirection = (CFrame.new(Vector3.new(), cameraRay.Direction) *
        CFrame.fromOrientation(0, 0, RNG:NextNumber(0, TAU)) *
        CFrame.fromOrientation(math.rad(RNG:NextNumber(MIN_BULLET_SPREAD_ANGLE, MAX_BULLET_SPREAD_ANGLE)), 0, 0)
    ).LookVector


    local raycastResult = workspace:Raycast(cameraRay.Origin, spreadDirection * CONST_RANGE, RayParams)
    local aimPoint = raycastResult and raycastResult.Position or (cameraRay.Origin + spreadDirection * CONST_RANGE)

    local muzzle = self:FindFirstChild("Handle") and self.Handle:FindFirstChild("Muzzle")
    if not muzzle then return end;

    local muzzlePos = muzzle.WorldPosition
    local bulletDirection = (aimPoint - muzzlePos).Unit
    local finalRaycastResult = workspace:Raycast(muzzlePos, bulletDirection * CONST_RANGE, RayParams)

    local finalHitPos
    if finalRaycastResult then
        finalHitPos = finalRaycastResult.Position
    else
        finalHitPos = aimPoint
    end;
    local RayResult = {
        Instance = finalRaycastResult and finalRaycastResult.Instance or nil,
        Normal = finalRaycastResult and finalRaycastResult.Normal or nil
    }
    mkHitEffects("DisplayEffects", self, muzzlePos, finalHitPos, raycastResult)
    packet.discharge.send({
        -- if anyone could understand the pain no one will.
        -- I hope this was worth it, Seriously.
        gun = self,                             
        action = "Discharge",                    
        muzzlePos = muzzlePos,                   
        bulletDirection = bulletDirection,        
        damage = CurrentModule.Damage,           
        finalHitPos = finalHitPos,              
        hitInfo = RayResult or nil                        
    })
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
    --warn(rayresult)
    if action ~= "DisplayEffects" then return end;
    local FireSound = self.Handle.Muzzle:FindFirstChild("FireSound") or self.Handle.Muzzle.Fire:Clone()
    FireSound.Parent = self.Handle
    FireSound.TimePosition = 0
    FireSound.PlaybackSpeed = 1
    FireSound:Play()
    game:GetService("Debris"):AddItem(FireSound, FireSound.TimeLength)
    local muzzle = gun:FindFirstChild("Handle") and gun.Handle:FindFirstChild("Muzzle")
    if muzzle then
        if Settings.ShowMuzzleEffects == true then
            for _, effect in pairs(game:GetService("ReplicatedStorage").FirearmShared.Stuff.Muzzle:GetChildren()) do
                local clonedEffect = effect:Clone()
                clonedEffect.Parent = muzzle
                if clonedEffect:IsA("ParticleEmitter") then clonedEffect:Emit(15) end
                game:GetService("Debris"):AddItem(clonedEffect, clonedEffect.Name == "Light" and 0.1 or 3)
            end
        end
    end


    if not rayresult or not rayresult.Instance or not rayresult.Normal then
        return  
    end
    if hitPos == nil then
        return
    end

    if typeof(rayresult.Instance) ~= "Instance" or typeof(rayresult.Normal) ~= "Vector3" then
        -- warn("this really got me thinking if this is worth it or not")
        return
    end

    if hitPos == nil or typeof(hitPos) ~= "Vector3" then
        --warn("KJFWEFWEFEWKLWEFQ LINE 350")
        return
    end

    local attach = HitEffects.Effects:Clone()
    attach.Parent = workspace.Terrain
    attach.CFrame = CFrame.new(hitPos, hitPos + rayresult.Normal)

    local hithuam = rayresult.Instance and rayresult.Instance.Parent:FindFirstChild("Humanoid")
    if hithuam then
        if Settings.ShowBlood == true then
            attach.Blood:Emit(20)
        end
    else
        attach.Flash:Emit(20)
        attach.Smoke:Emit(20)
        game:GetService("Debris"):AddItem(attach, attach.Smoke.Lifetime.Max + 0.1)
    end
end

--[[
	--------------------------------------------------------------------------------------------------
	 @Event : 	 	  Listen (https://ffrostfall.github.io/ByteNet/api/functions/definePacket/)
	 @Author :        @DrBIoop
	 @Description :   Inits the remote event
	 @Params : 	      any: data the data that got sent to the fake remote
	--------------------------------------------------------------------------------------------------
--]]
packet2.MKHitEffects.listen(@native function(data: any)
    local action = data.action
    local gun = data.gun
    local muzzlePos = data.muzzlePos
    local hitPos = data.hitPos
    local rayresult = data.rayresult

    mkHitEffects(action, gun, muzzlePos, hitPos, rayresult)
end)


--[[function StartFiring()
	if not IsEquipped or alreadyfiring or not canfire() then return end

	alreadyfiring = true
	IsButtonDown = true

	if CurrentModule.Automatic then
		local function AutoFire()
			while IsButtonDown and IsEquipped and CurrentModule.Ammo > 0 do
				RealFire(self)
				CurrentModule.Ammo = CurrentModule.Ammo - 1
				waitthing(CurrentModule.RPM) 
			end
			alreadyfiring = false
		end

		AutoFire()
	else
		RealFire(self)
	end
end]]







--[[Player.CharacterAdded:Connect(function()
	ResetWeaponState()
end)]]

--[[char:WaitForChild("Humanoid").Died:Connect(@native function()
	ResetWeaponState()
end)]]



--BindToTag("Firearm", InitWeapon)
--[[BindToTag("Firearm", function(gun: any)
	if gun:IsDescendantOf(Player.Character) then 
		InitWeapon(gun)
	end
end)]]


---------------------------
--  C O N N E C T I O N S  --
---------------------------

--[[
	--------------------------------------------------------------------------------------------------
	 @Name : 	 	  CheckAndInitWeapon
	 @Author :        @DrBIoop
	 @Description :   Looks up the gun and inits it if found in the "Dictionary" Module
	 @Params : 	      Tool: Tool - The equipped tool to init \ check
	--------------------------------------------------------------------------------------------------
--]]
@native function CheckAndInitWeapon(tool: Tool)
    if Dic[tool.Name] then
        -- warn("passed checks")
        InitWeapon(tool)
    end;
end;


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
            -- warn("Ran return")
            return
        end

        if IsButtonDown == false then
            break
        end

        --warn("Shooting")
        alreadyfiring = true
        task.spawn(RealFire)
        task.wait(CurrentModule.RPM)
        if self and CurrentModule then
        if not CurrentModule.Automatic then
            break
        end
        end
    end
    alreadyfiring = false
    IsButtonDown = false
end


--[[
	--------------------------------------------------------------------------------------------------
	 @Name : 	 	  InitWeapon
	 @Author :        @DrBIoop
	 @Description :   Initializes the weapon
	 @Params : 	      Tool: Tool - The equipped weapon to init
	--------------------------------------------------------------------------------------------------
--]]
@native function InitWeapon(gun: Tool)
    if not Player.Character or Player.Character:WaitForChild("Humanoid").Health <= 0 then return end

    local equip, unequip
    -- local og
    if equip then equip:Disconnect() end
    if unequip then unequip:Disconnect() end

    @native local function CleanUpConnections()
        if equip then equip:Disconnect() equip = nil end
        if unequip then unequip:Disconnect() unequip = nil end
    end

    local AnimationCache = {}

    equip = gun.Equipped:Connect(@native function()
        CleanUpConnections()
        ResetWeaponState(false)

        IsEquipped = true
	local char = Player.Character or Player.CharacterAdded:Wait()
        og = char.Humanoid.WalkSpeed
        local hum = char.Humanoid
        local Animator: Animator = hum.Animator

        self = gun
        CurrentModule = Dic[tostring(gun)]

        for name, anim in pairs(CurrentAnimations) do
            if anim then
                anim:Stop()
                CurrentAnimations[name] = nil
            end
        end

        task.spawn(@native function()
            for name, Id in pairs(CurrentModule.Animations) do
                if not AnimationCache[name] then
                    local NewAnimation = Instance.new("Animation")
                    NewAnimation.AnimationId = "rbxassetid://" .. Id
                    AnimationCache[name] = Animator:LoadAnimation(NewAnimation)
                end
                CurrentAnimations[name] = AnimationCache[name]
            end
        end)

        if CurrentAnimations.Idle then
            CurrentAnimations.Idle:Play(0.2)
        end

        if IsMobile then
            Player.PlayerGui.MobileUI.Enabled = true
        end


        self.Activated:Connect(@native function()
            --warn("activ")
            Activated()
        end)
        self.Deactivated:Connect(@native function()
            -- warn("deactive")
            IsButtonDown, alreadyfiring = false, false
        end)


        unequip = gun.Unequipped:Connect(@native function()
            CleanUpConnections()
        if self and CurrentModule then if CurrentModule.CanCrawl then
                UserInputService.MouseBehavior = Enum.MouseBehavior.Default
                Player.CameraMaxZoomDistance = game:GetService("StarterPlayer").CameraMaxZoomDistance
                Player.CameraMinZoomDistance = game:GetService("StarterPlayer").CameraMinZoomDistance
                Player.Character:WaitForChild("Humanoid").WalkSpeed = og
            end
        end
            for _, anim in pairs(CurrentAnimations) do
                anim:Stop()
            end


            self = nil
            IsEquipped = false
            CurrentModule = nil

            if IsMobile then
                Player.PlayerGui.MobileUI.Enabled = false
            end

            ResetWeaponState(false)

        end)
    end)
end


--[[
	--------------------------------------------------------------------------------------------------
	 @Event : 	 	  InputBegan (https://create.roblox.com/docs/reference/engine/classes/UserInputService#InputBegan)
	 @Author :        @DrBIoop
	 @Description :   M249 Crawling
	 @Params : 	      InputObject: InputObject - players input, boolean: gameProcessedEvent - GPE
	--------------------------------------------------------------------------------------------------
--]]
UserInputService.InputBegan:Connect(@native function(input: InputObject, gameProcessedEvent: boolean) 
    if gameProcessedEvent == true then 
        return 
    end;
    if input.UserInputType == Enum.UserInputType.Keyboard and input.KeyCode == Enum.KeyCode.X then
        if IsEquipped ==  false then return end
        if IsReloading == true then return end
        if IsLowered  ==  true then return end
        if CurrentModule.CanCrawl then
            IsCrawled = not IsCrawled
            if IsCrawled == true then
                Player.CameraMaxZoomDistance = 7
                Player.CameraMinZoomDistance = 7
                UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
                Player.Character:WaitForChild("Humanoid").WalkSpeed = 0
                CurrentAnimations.Idle:Stop(0.2)
                CurrentAnimations.Crawl:Play(0.2)
            else
                Player.CameraMaxZoomDistance = game:GetService("StarterPlayer").CameraMaxZoomDistance
                Player.CameraMinZoomDistance = game:GetService("StarterPlayer").CameraMinZoomDistance
                Player.CameraMode = Enum.CameraMode.Classic
                UserInputService.MouseBehavior = Enum.MouseBehavior.Default
                Player.Character:WaitForChild("Humanoid").WalkSpeed = og
                CurrentAnimations.Crawl:Stop(0.2)
                CurrentAnimations.Idle:Play(0.2)
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
    if IsCrawled == true then
        Player.Character:WaitForChild("Humanoid").WalkSpeed = 0
    else
        return
    end;
end);


@native function thesus(item: Tool)
    if Dic[item.Name] then
        local CurrentModule = Dic[item.Name]
        CurrentModule.Ammo = CurrentModule.MaxAmmo
        ResetWeaponState(true)
    end;
end;

--[[
	--------------------------------------------------------------------------------------------------
	 @Event : 	 	  MouseButton1Click (https://create.roblox.com/docs/reference/engine/classes/GuiButton#MouseButton1Click)
	 @Author :        @DrBIoop
	 @Description :   (Mobile) Reload
	 @Params : 	      boolean: gameProcessedEvent - GPE
	--------------------------------------------------------------------------------------------------
--]]
ReloadButton.MouseButton1Click:Connect(@native function(gpe: boolean) 
    if IsEquipped == false then return end;  -- just double checking
    if IsCrawled == true then return end
    if gpe then return end; -- also just double checking
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
    if IsEquipped == false then return end;  -- just double checking
    if IsCrawled == true then return end
    if gpe then return end;  -- alos just double checking
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
    if gameProcessedEvent == true then
        return
    end;
    if IsCrawled == true then return end
    if input.UserInputType == Enum.UserInputType.Keyboard and input.KeyCode == Enum.KeyCode.R then
        if IsEquipped == false then return end
        Reload()
    end;
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
    if IsEquipped == false then return end
    if IsCrawled == true then return end
    if gameProcessedEvent == true then return end;
    if input.UserInputType == Enum.UserInputType.Keyboard and input.KeyCode == Enum.KeyCode.E then
        Holster()
    end;
end);


@native function HandleAdded()
    task.spawn(function()
        for _, v in Player.Backpack:GetChildren() do
            if Dic[v.Name] then
                thesus(v)
            end
        end
    end)

    Player.Backpack.ChildAdded:Connect(@native function(child: Tool)
        if child:IsA("Tool") and Dic[child.Name] then
            InitWeapon(child)
        end
    end)

    Player.Character.ChildAdded:Connect(@native function(child: Tool)
        if child:IsA("Tool") and Dic[child.Name] then
            InitWeapon(child)
        end
    end)
end

Player.Character.Humanoid.Died:Connect(@native function()
    task.spawn(@native function()
        for _, v in Player.Character:GetChildren() do
            if v:IsA("Tool") and Dic[v.Name] then
                thesus(v)
            end
        end
    end)
end)

Player.Backpack.ChildAdded:Connect(@native function(child: Tool)
    if child:IsA("Tool") and Dic[child.Name] then
        thesus(child)
    end
end)

Player.CharacterAdded:Connect(@native function(character: any)
    character:WaitForChild("Humanoid") 
    HandleAdded()
end)

if Player.Character then
    for _, v in Player.Backpack:GetChildren() do
        if v:IsA("Tool") and Dic[v.Name] then
            thesus(v)
        end
    end
    HandleAdded()
end

return FirearmClient
