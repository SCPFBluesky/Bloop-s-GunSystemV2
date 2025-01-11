--[[
	Name: InputHandler.Luau
	Author(s): @Unknown
	Date: Unknown
	RunTimeContext: Shared
	Information: Input handler able to bind functions to input.
]]

--!nocheck
--!native

local require = shared.import("require")

local UserSetting = UserSettings():GetService("UserGameSettings")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local GuiService = game:GetService("GuiService")

local InputBinds = require("InputBinds")

local MobileUI = game:FindService("Players").LocalPlayer.PlayerGui:WaitForChild("MobileUI")
local isMobileDevice = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled and not UserInputService.MouseEnabled and not UserInputService.GamepadEnabled and not GuiService:IsTenFootInterface()
local inputMovement = Vector2.new()
local thumbMovement = Vector2.new()
local mouseMovement = Vector3.new()

local self = {
	Functions = {}
}

local function inputHandle(down, input, gameProcessed)
	for name, binds in pairs(InputBinds) do
		for _, bind in pairs(binds) do
			if input.UserInputType == bind[1] and input.KeyCode == bind[2] then
				if self.Functions[name] then
					self.Functions[name](down, gameProcessed)
				else
					warn("FLUX INPUT: No function is bound to '" .. name .. "'")
				end
			end
		end
	end
	if not gameProcessed then
		if input.KeyCode == Enum.KeyCode.W then
			inputMovement = Vector2.new(inputMovement.X, down and -1 or inputMovement.Y < 0 and 0 or inputMovement.Y)
		elseif input.KeyCode == Enum.KeyCode.S then
			inputMovement = Vector2.new(inputMovement.X, down and 1 or inputMovement.Y > 0 and 0 or inputMovement.Y)
		elseif input.KeyCode == Enum.KeyCode.A then
			inputMovement = Vector2.new(down and -1 or inputMovement.X < 0 and 0 or inputMovement.X, inputMovement.Y)
		elseif input.KeyCode == Enum.KeyCode.D then
			inputMovement = Vector2.new(down and 1 or inputMovement.X > 0 and 0 or inputMovement.X, inputMovement.Y)
		end
	end
end

local function inputBegan(...)
	inputHandle(true, ...)
end

local function inputEnded(...)
	inputHandle(false, ...)
end

local function inputChanged(input, gameProcessed)
	if input.UserInputType == Enum.UserInputType.MouseMovement then
		mouseMovement = Vector3.new(input.Delta.X, input.Delta.Y, mouseMovement.Z)
	elseif input.UserInputType == Enum.UserInputType.MouseWheel then
		mouseMovement = Vector3.new(mouseMovement.X, mouseMovement.Y, input.Position.Z)
	elseif input.UserInputType == Enum.UserInputType.Gamepad1 then
		if input.KeyCode == Enum.KeyCode.Thumbstick1 then
			inputMovement = Vector2.new(input.Position.X, -input.Position.Y)
		elseif input.KeyCode == Enum.KeyCode.Thumbstick2 then
			thumbMovement = Vector2.new(input.Delta.X, input.Delta.Y)
		end
	end
end

function self:BindAction(guiObject, action, toggle)
	if not isMobileDevice then
		guiObject.Visible = false
		return
	end
	if toggle then
		do
			local active = false
			guiObject.MouseButton1Click:Connect(function()
				active = not active
				self.Functions[action](active, false)
			end)
		end
	else
		guiObject.MouseButton1Down:Connect(function()
			self.Functions[action](true, false)
		end)
		guiObject.MouseButton1Up:Connect(function()
			self.Functions[action](false, false)
		end)
	end
end

function self:GetInputMovement()
	return inputMovement
end

function self:GetMouseMovement()
	local currentMouse = mouseMovement
	mouseMovement = Vector3.new(mouseMovement.X, mouseMovement.Y, 0)
	return currentMouse
end

function self:GetThumbMovement()
	return thumbMovement
end

function self:GetCameraMovement()
	local cameraMovement = Vector2.new(mouseMovement.X, mouseMovement.Y) / 100 * UserSetting.MouseSensitivity + thumbMovement / 100 * UserSetting.GamepadCameraSensitivity
	mouseMovement = Vector3.new()
	thumbMovement = Vector2.new()
	return cameraMovement
end

self:BindAction(MobileUI.MobileButtons.FireButton, "Activate", false)
self:BindAction(MobileUI.MobileButtons.ReloadButton, "Reload", false)
self:BindAction(MobileUI.MobileButtons.LowerButton, "Holster", false)
self:BindAction(MobileUI.MobileButtons.Flashlight, "Flashlight", false)

UserInputService.InputBegan:Connect(inputBegan)
UserInputService.InputEnded:Connect(inputEnded)
UserInputService.InputChanged:Connect(inputChanged)

return self
