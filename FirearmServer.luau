@native function Fire(player: any, gun: Tool, arg: string, muzzlePosition: Vector3, bulletDirection: Vector3, dmg: number, finalHitPosition: Vector3, raycastResult: any)
    for _,v in gun:GetDescendants() do
        if v:IsA("BasePart") then
            v:SetNetworkOwner(player)
        end
    end
    local self = gun
    if self == nil or self:IsDescendantOf(workspace) == false or player.Character.Humanoid.Health == 0 then return end
    if arg == "Discharge" then
        --	local s = os.clock()


        if typeof(raycastResult.Instance) ~= "Instance" or typeof(raycastResult.Normal) ~= "Vector3" then
            -- legit will not work without this since when its nil it likes to turn into a random number for somereason so yeah
            return
        end;

        if finalHitPosition == nil or typeof(finalHitPosition) ~= "Vector3" then
            return
        end;
     
        if raycastResult and finalHitPosition and raycastResult.Normal then
            
           do
            local hitInstance = raycastResult.Instance or nil
            if hitInstance == nil then
                return
            end
            local hitHumanoid = hitInstance and hitInstance.Parent:FindFirstChild("Humanoid")

            local hitModel = hitInstance:FindFirstAncestor("173")
            if hitModel and hitModel:IsA("Model") then
                local healthValue = hitModel:FindFirstChild("Health")
                if healthValue and healthValue:IsA("NumberValue") then
                    healthValue.Value = healthValue.Value - dmg 
                end;
            end;

            if hitHumanoid then
                local targetPlayer = Players:GetPlayerFromCharacter(hitHumanoid.Parent)

                if targetPlayer == nil or TeamCheck(player, targetPlayer, self) then
                    hitHumanoid:TakeDamage(dmg)
                    end;
                end;
              end;
        end;

        --print((os.clock()-s)*1e+6, "μs")
    end;
end;
