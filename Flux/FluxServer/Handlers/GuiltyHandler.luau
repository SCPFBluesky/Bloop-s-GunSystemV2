--[[
	Name: GuiltyHandler
	Author(s): @WATDAHECKLOL32
	Date: sometime in 2023 no idea
	RunTimeContext: Shared
	Information: Guilty for CDs
]]

--!strict
--!native

local require, network, tagged, asset, tween, thread = shared.import("require", "network", "tagged", "asset", "tween", "thread")


local Players = game:GetService("Players")
local folder = workspace:FindFirstChild("TrespassingZones")

local function OnCharAdded(character: any, player: Player)
	if not (player.Team == game:GetService("Teams")["Class D"]) then
		return
	end

	if character then
		character:SetAttribute("Guilty", false)

		character.ChildAdded:Connect(function(item: Tool)
			if item:IsA("Tool") and (item:HasTag("Hostile") or item:HasTag("Guilty")) then
				local guilty = character:GetAttribute("Guilty")

				if guilty == true then
					return
				end

				character:SetAttribute("Guilty", true)
				network:FireClient(player, "NotifyPlayer", "You are now hostile.")
			end
		end)
	end
end

local function OnTouched(part: BasePart)
	local player = Players:GetPlayerFromCharacter(part.Parent)

	if player then
		if not (player.Team == game:GetService("Teams")["Class D"]) then
			return
		end

		if player.Character then
			local GuiltyAttribute = player.Character:GetAttribute("Guilty")

			if GuiltyAttribute == true then
				return
			end

			player.Character:SetAttribute("Guilty", true)
			network:FireClient(player, "NotifyPlayer", "You are now hostile.")
		end
	end
end

Players.PlayerAdded:Connect(function(player: Player)
	player.CharacterAdded:Connect(function(character: any)
		OnCharAdded(character, player)
	end)
end)

if folder then
	for _, part in folder:GetChildren() do
		if part:IsA("BasePart") then
			part.Touched:Connect(OnTouched)
		end
	end
end
