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


local FirearmShared = game.ReplicatedStorage:WaitForChild("FirearmShared")
local Remote = FirearmShared.Remotes.Main
--local Remote = BridgeNet.CreateBridge("Main")
local ClientRemote = FirearmShared.Remotes.Client
--local ClientRemote = BridgeNet.CreateBridge("Client")
local Dic = require(FirearmShared.Dictionary)
local Tagged = require(FirearmShared.Tagged)
local ReloadRemote =FirearmShared.Remotes.Reload
local HitEffects = FirearmShared.Stuff.Effects
local FlashRemote = FirearmShared.Remotes.Flashlight

local FirearmClient = {}
local Player = game.Players.LocalPlayer
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


@native function BindToTag(Tag: string, Function: (Instance) -> ()): RBXScriptConnection
	for _, Value in CollectionService:GetTagged(Tag) do
		task.spawn(Function, Value)
	end;

	return CollectionService:GetInstanceAddedSignal(Tag):Connect(Function)
end;


if UserInputService.TouchEnabled == true then
	IsMobile = true
end;

@native function RPM(TimeToWait: number)
	-- helps fixes firedelay
	if TimeToWait ~= nil then
		local TotalTime = 0
		TotalTime = TotalTime + game:GetService("RunService").Heartbeat:wait()
		while TotalTime < TimeToWait do
			TotalTime = TotalTime + game:GetService("RunService").Heartbeat:wait()
		end
	else
		game:GetService("RunService").Heartbeat:wait()
	end
end

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



@native function Reload()
	if IsEquipped == false then return end;
	
	if not self or not Player.Character or not Player.Character:FindFirstChild("Humanoid") or Player.Character.Humanoid.Health <= 0 or IsReloading then
		return
	end;
	
	if IsLowered == true then return end;
	if CurrentModule.Ammo == CurrentModule.MaxAmmo then return end;
	
	ReloadRemote:FireServer(self)
	CurrentAnimations.Reload:Play(0.2)
    IsReloading = true
    
    if CurrentModule and self then
        CurrentModule.Ammo = 0
        CurrentModule.Ammo = CurrentModule.MaxAmmo
    end
    
	CurrentAnimations.Reload.Ended:Wait()
	--task.wait(CurrentGun.Handle.Muzzle.Reload.TimeLength - 0.4)
	IsReloading = false
	
end;

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




--[[@native function CheckBlacklist()
	RayIgnore = {}
	for _, v in game.Workspace:GetDescendants() do
		if v:IsA("Accessory") or v:HasTag("RayIgnore") then
			v:AddTag("RayIgnore")
			table.insert(RayIgnore, v)
		end
		--RayParams.FilterDescendantsInstances = {Player.Character, RayIgnore}
	end
end]]

--[[task.defer(@native function()
	task.wait(3)
	CheckBlacklist()
end)]]


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

local WallShootRayParams = RaycastParams.new()
WallShootRayParams.RespectCanCollide = true
WallShootRayParams.FilterDescendantsInstances = getIgnorelist({Player.Character, workspace.CurrentCamera})
WallShootRayParams.IgnoreWater = true

@native function islaoded()
	return Player.Character and Player.Character:FindFirstChild("Humanoid") and Player.Character.Humanoid.Health > 0
end;

@native function canfire()
	return self and islaoded() and not IsReloading and not IsLowered
end;

@native function RealFire(gun: Tool)
	if not IsEquipped or not canfire() or CurrentModule.Ammo <= 0 then return end;
	CurrentModule.Ammo -= 1

	local cameraRay = workspace.CurrentCamera:ScreenPointToRay(Mouse.X, Mouse.Y)
	local spreadDirection = (CFrame.new(Vector3.new(), cameraRay.Direction) *
		CFrame.fromOrientation(0, 0, RNG:NextNumber(0, TAU)) *
		CFrame.fromOrientation(math.rad(RNG:NextNumber(MIN_BULLET_SPREAD_ANGLE, MAX_BULLET_SPREAD_ANGLE)), 0, 0)
	).LookVector

	local WallShootDirection = char.HumanoidRootPart.CFrame.LookVector * 3.5
	local WallShootRaycast = workspace:Raycast(char.HumanoidRootPart.Position, WallShootDirection, WallShootRayParams)

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

	if WallShootRaycast then
		finalRaycastResult = WallShootRaycast
		finalHitPos = WallShootRaycast.Position
		bulletDirection = Vector3.new(0,0,0)
		aimPoint = Vector3.new(0,0,0)
	end;

	Remote:FireServer(gun, "Discharge", muzzlePos, bulletDirection, CurrentModule.Damage, finalHitPos, {
		Instance = finalRaycastResult and finalRaycastResult.Instance or nil,
		Normal = finalRaycastResult and finalRaycastResult.Normal or nil
	})
end;



@native function mkHitEffects(action: string, gun: Tool, muzzlePos: Vector3, hitPos: Vector3, rayresult: any)
	if action ~= "DisplayEffects" then return end;

	local muzzle = gun:FindFirstChild("Handle") and gun.Handle:FindFirstChild("Muzzle")
	if muzzle then
		if Settings.ShowMuzzleEffects == true then
		for _, effect in pairs(game.ReplicatedStorage.FirearmShared.Stuff.Muzzle:GetChildren()) do
			local clonedEffect = effect:Clone()
			clonedEffect.Parent = muzzle
			if clonedEffect:IsA("ParticleEmitter") then clonedEffect:Emit(15) end
			game.Debris:AddItem(clonedEffect, clonedEffect.Name == "Light" and 0.1 or 3)
			end;
		end;
	end;

	if not (rayresult and hitPos and rayresult.Normal) then return end;

	local attach = HitEffects.Effects:Clone()
	attach.Parent = workspace.Terrain
	attach.CFrame = CFrame.new(hitPos, hitPos + rayresult.Normal)

	local hithuam = rayresult.Instance and rayresult.Instance.Parent:FindFirstChild("Humanoid")
	if hithuam then
		if Settings.ShowBlood == true then
		attach.Blood:Emit(20)
		end;
	else
		attach.Flash:Emit(20)
		attach.Smoke:Emit(20)
		game.Debris:AddItem(attach, attach.Smoke.Lifetime.Max + 0.1)
	end;
end;


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

@native function CheckAndInitWeapon(tool: Tool)
    if Dic[tool.Name] then
       -- warn("passed checks")
		InitWeapon(tool)
	end;
end;

@native function InitWeapon(gun: Tool)
   -- warn("init called")
    if not Player.Character or Player.Character:WaitForChild("Humanoid").Health <= 0 then return end
    ResetWeaponState(false)

    local equip, unequip
    local debounce = false
    local LastWeapon = nil
    local ActiveConnection, Deactivated

    @native local function CleanAnimations()
        for _, anim in pairs(CurrentAnimations) do
            if anim then
                anim:Stop()
                anim:Destroy() 
            end;
        end;
    end;

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

        CleanAnimations()
        CurrentAnimations = {}
        
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
                        RPM(CurrentModule.RPM)
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
        CleanAnimations()
        CurrentAnimations = {}
        ResetWeaponState(false)
        debounce = false
    end);
end;




UserInputService.InputBegan:Connect(@native function(input: InputObject, gameProcessedEvent: boolean) 
	if gameProcessedEvent == true then 
		return 
	end;
	if input.UserInputType == Enum.UserInputType.Keyboard and input.KeyCode == Enum.KeyCode.X then
	if IsEquipped ==  false then return end
	if IsReloading == true then return end
	if IsLowered  ==  true then return end
	--if not alreadyfiring then return end 
	if self.Name == "M249" then
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


ReloadButton.MouseButton1Click:Connect(@native function(gpe: boolean) 
	if IsEquipped == false then return end;  -- just double checking
	if IsCrawled == true then return end
	if gpe then return end; -- also just double checking
	Reload()
end);

LowerButton.MouseButton1Click:Connect(@native function(gpe: boolean) 
	if IsEquipped == false then return end;  -- just double checking
	if IsCrawled == true then return end
	if gpe then return end;  -- alos just double checking
	Holster()
end);

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

UserInputService.InputBegan:Connect(@native function(input: InputObject, gameProcessedEvent: boolean) 
	if IsEquipped == false then return end
	if IsCrawled == true then return end
	if gameProcessedEvent == true then return end;
	if input.UserInputType == Enum.UserInputType.Keyboard and input.KeyCode == Enum.KeyCode.E then
		Holster()
	end;
end);


local function added()
    local char = Player.Character or Player.CharacterAdded:Wait()
    char.ChildAdded:Connect(function(child)
        if child:IsA("Tool") and Dic[child.Name] then
            warn("checking and initing")
            char:WaitForChild("Humanoid").Died:Connect(@native function()
                for _,v in Player.Character:GetChildren() do
                    if v:IsA("Tool") and Dic[child.Name] then
                        thesus(child)
                    end
                end
                for _,v in Player.Backpack:GetChildren() do
                   if v:IsA("Tool") and Dic[child.Name] then
                        thesus(child)
                   end
                end
            end)
            child.Equipped:Connect(function()
                warn("initing")
                CheckAndInitWeapon(child)
            end)
        end
    end)
end

Player.CharacterAdded:Connect(added)
ClientRemote.OnClientEvent:Connect(mkHitEffects)
return FirearmClient
