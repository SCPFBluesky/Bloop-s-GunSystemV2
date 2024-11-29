

--[[
	FirearmClient.Luau
	--------------------
	Author(s): @SCPF_RedSky
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
--local Remote = BridgeNet.CreateBridge("Main")
local ClientRemote = FirearmShared.Remotes.Client
--local ClientRemote = BridgeNet.CreateBridge("Client")
local Dic = require(FirearmShared.Dictionary)
local Tagged = require(FirearmShared.Tagged)
local ReloadRemote =FirearmShared.Remotes.Reload
local HitEffects = FirearmShared.Stuff.Effects
local FlashRemote = FirearmShared.Remotes.Flashlight

local FirearmClient = {}
local Player = game:GetService("Players").LocalPlayer
local char = Player.Character or Player.CharacterAdded:Wait()

local IsReloading, IsLowered, IsMobile, IsEquipped, IsButtonDown, alreadyfiring, FlashEnabled, AlreadyCloned, IsCrawled = false, false, false, false, false, false, false, false, false
local firingTimes, CurrentAnimations, self, CurrentModule = {}, {}, nil, nil

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
	 @Author : @SCPF_RedSky
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

    if CurrentAnimations then
        for _, anim in pairs(CurrentAnimations) do
            anim:Stop()
        end;
    end;

    CurrentAnimations, self, CurrentModule = {}, nil, nil
end;


--[[
	--------------------------------------------------------------------------------------------------
	 @Name : 	 	  Reload
	 @Author :        @SCPF_RedSky
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
	 @Author :        @SCPF_RedSky
	 @Description :   Holsters the user's current weapon
	 @Params : 	      None
	--------------------------------------------------------------------------------------------------
--]]
@native function Holster()
    --if IsEquipped == false then return end
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

    for _, object in pairs(items) do
        table.insert(ignore, 1, object)
    end;

    return ignore
end;


local IgnoreWallShooting = {char}

for _,v in ipairs(workspace:GetDescendants()) do
    if v:FindFirstChild("HumanoidRootPart") then
        table.insert(IgnoreWallShooting, v)
    end
end



@native function islaoded()
    return Player.Character and Player.Character:FindFirstChild("Humanoid") and Player.Character.Humanoid.Health > 0
end;


@native function canfire()
    return self and islaoded() and not IsReloading and not IsLowered
end;

--[[
	--------------------------------------------------------------------------------------------------
	 @Name : 	 	  RealFire
	 @Author :        @SCPF_RedSky
	 @Description :   Shoots the user's current gun
	 @Params : 	      Tool: Gun - The gun to shoot
	--------------------------------------------------------------------------------------------------
--]]
@native function RealFire(gun: any)
    if not IsEquipped or not canfire() or CurrentModule.Ammo <= 0 then return end;
    local FirearmCooldown = CurrentModule.RPM
    if tick() - DebouncedRate < FirearmCooldown then
        return  
    end
    DebouncedRate = tick() 
    CurrentModule.Ammo -= 1

    local cameraRay = workspace.CurrentCamera:ScreenPointToRay(Mouse.X, Mouse.Y)
    local spreadDirection = (CFrame.new(Vector3.new(), cameraRay.Direction) *
        CFrame.fromOrientation(0, 0, RNG:NextNumber(0, TAU)) *
        CFrame.fromOrientation(math.rad(RNG:NextNumber(MIN_BULLET_SPREAD_ANGLE, MAX_BULLET_SPREAD_ANGLE)), 0, 0)
    ).LookVector


    local raycastResult = workspace:Raycast(cameraRay.Origin, spreadDirection * CONST_RANGE, RayParams)
    local aimPoint = raycastResult and raycastResult.Position or (cameraRay.Origin + spreadDirection * CONST_RANGE)

    local muzzle = gun:FindFirstChild("Handle") and gun.Handle:FindFirstChild("Muzzle")
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

    packet.discharge.send({
        -- if anyone could understand the pain no one will.
        -- I hope this was worth it, Seriously.
        gun = gun,                             
        action = "Discharge",                    
        muzzlePos = muzzlePos,                   
        bulletDirection = bulletDirection,        
        damage = CurrentModule.Damage,           
        finalHitPos = finalHitPos,              
        hitInfo = RayResult or nil                        
    })



    --[[Remote:FireServer(gun, "Discharge", muzzlePos, bulletDirection, CurrentModule.Damage, finalHitPos, {
        Instance = finalRaycastResult and finalRaycastResult.Instance or nil,
        Normal = finalRaycastResult and finalRaycastResult.Normal or nil
    })]]
end;


--[[
	--------------------------------------------------------------------------------------------------
	 @Name : 	 	  mkHitEffects
	 @Author :        @SCPF_RedSky
	 @Description :   Handles muzzle, blood, ground effects for the gun system
	 @Params : 	      Action: string - exists for no reason Tool: Gun - The players gun MuzzlePosition: Vector3 - The players muzzle position, HitPos: Vector3 - RaycastHit, RayReult: any - Raycast Result
	--------------------------------------------------------------------------------------------------
--]]
@native function mkHitEffects(action: string, gun: any, muzzlePos: Vector3, hitPos: Vector3, rayresult: any)
    --warn(rayresult)
    if action ~= "DisplayEffects" then return end;

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
	 @Author :        @SCPF_RedSky
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
	 @Author :        @SCPF_RedSky
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
	 @Name : 	 	  InitWeapon
	 @Author :        @SCPF_RedSky
	 @Description :   Initializes the weapon
	 @Params : 	      Tool: Tool - The equipped weapon to init
	--------------------------------------------------------------------------------------------------
--]]
@native function InitWeapon(gun: Tool)
    -- warn("init called")
    if not Player.Character or Player.Character:WaitForChild("Humanoid").Health <= 0 then return end
    ResetWeaponState(false)

    local equip, unequip
    local debounce = false
    local LastWeapon = nil
    local ActiveConnection, Deactivated


    equip = gun.Equipped:Connect(@native function()
        if debounce or gun == LastWeapon then return end
        debounce = true
        LastWeapon = gun
        ResetWeaponState(false)

        og = Player.Character:WaitForChild("Humanoid").WalkSpeed
        IsEquipped = true

        local char = Player.Character or Player.CharacterAdded:Wait()
        local hum = char:WaitForChild("Humanoid")

        self = gun
        CurrentModule = Dic[tostring(gun)]

        for _,v in CurrentAnimations do
            v:Stop()
        end
        table.clear(CurrentAnimations)

        for name, Id in pairs(CurrentModule.Animations) do
            local newAnimation = Instance.new("Animation")
            newAnimation.AnimationId = "rbxassetid://" .. Id
            local loadedAnim = hum:LoadAnimation(newAnimation)
            CurrentAnimations[name] = loadedAnim
        end;

        if CurrentAnimations.Idle then
            CurrentAnimations.Idle:Play(0.2)
        end;

        if IsMobile then
            Player.PlayerGui.MobileUI.Enabled = true
        end;

        RayParams.FilterDescendantsInstances = getIgnorelist({Player.Character, workspace.CurrentCamera})

        if not ActiveConnection then
            ActiveConnection = self.Activated:Connect(function(gpe: boolean)
                if not self or not CurrentModule or not IsEquipped or gpe then return end;

                IsButtonDown = true
                while IsButtonDown and IsEquipped and CurrentModule and CurrentModule.Ammo > 0 and self do
                    if alreadyfiring or not canfire() then return end;

                    if not self or not CurrentModule then return end;

                    alreadyfiring = true
                    RealFire(self)

                    if CurrentModule and CurrentModule.RPM then
                        task.wait(CurrentModule.RPM)
                       -- RPM(CurrentModule.RPM)
                    end;

                    alreadyfiring = false
                    if not CurrentModule or not CurrentModule.Automatic then break end;
                end;
            end);
        end;


        UserInputService.TouchStarted:Connect(@native function(touch: InputObject, gameProcessedEvent: boolean) 
            if not gameProcessedEvent then IsButtonDown = true end;
        end);

        UserInputService.TouchEnded:Connect(@native function(touch: InputObject, gameProcessedEvent: boolean) 
            if not gameProcessedEvent then IsButtonDown, alreadyfiring = false, false end;
        end);

        if not Deactivated then
            Deactivated = self.Deactivated:Connect(@native function(gpe: boolean)
                if IsEquipped == false or gpe then return end
                IsButtonDown, alreadyfiring = false, false 
            end);
        end;

        debounce = false
    end);

    unequip = gun.Unequipped:Connect(@native function()
        if debounce then return end
        debounce = true
        self = nil
        IsEquipped = false
        CurrentModule = nil
        UserInputService.MouseBehavior = Enum.MouseBehavior.Default
        Player.CameraMaxZoomDistance = game:GetService("StarterPlayer").CameraMaxZoomDistance
        Player.CameraMinZoomDistance = game:GetService("StarterPlayer").CameraMinZoomDistance
        Player.Character:WaitForChild("Humanoid").WalkSpeed = og


        if IsMobile then
            Player.PlayerGui.MobileUI.Enabled = false
        end;

        if ActiveConnection then
            ActiveConnection:Disconnect()
            ActiveConnection = nil
        end;

        if Deactivated then
            Deactivated:Disconnect()
            Deactivated = nil
        end;
        for _,v in CurrentAnimations do
            v:Stop()
        end
        table.clear(CurrentAnimations)
        ResetWeaponState(false)
        debounce = false
    end);
end;



--[[
	--------------------------------------------------------------------------------------------------
	 @Event : 	 	  InputBegan (https://create.roblox.com/docs/reference/engine/classes/UserInputService#InputBegan)
	 @Author :        @SCPF_RedSky
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
        --if not alreadyfiring then return end 
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
	 @Author :        @SCPF_RedSky
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
	 @Author :        @SCPF_RedSky
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
	 @Author :        @SCPF_RedSky
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
	 @Author :        @SCPF_RedSky
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
	 @Author :        @SCPF_RedSky
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


local function handleTool(child)
    if child:IsA("Tool") and Dic[child.Name] then
        --warn("checking and initing")

        Player.Character:WaitForChild("Humanoid").Died:Connect(function()
            for _, v in ipairs(Player.Character:GetChildren()) do
                if v:IsA("Tool") and Dic[v.Name] then
                    thesus(v)
                end
            end
            for _, v in ipairs(Player.Backpack:GetChildren()) do
                if v:IsA("Tool") and Dic[v.Name] then
                    thesus(v)
                end
            end
        end)

        child.Equipped:Connect(function()
            --warn("initing")
            CheckAndInitWeapon(child)
        end)
    end
end

local function added()
    --  warn("called")
    local char = Player.Character
    char.ChildAdded:Connect(handleTool)
end

if Player.Character then
    added() 
end
Player.CharacterAdded:Connect(added)

ClientRemote.OnClientEvent:Connect(mkHitEffects)
return FirearmClient
