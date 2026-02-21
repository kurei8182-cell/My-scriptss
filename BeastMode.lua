local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local VIM = game:GetService("VirtualInputManager")
local StarterGui = game:GetService("StarterGui")
local localPlayer = Players.LocalPlayer
local camera = workspace.CurrentCamera

local function sendNotification(title, text)
    pcall(function()
        StarterGui:SetCore("SendNotification", {
            Title = title,
            Text = text,
            Duration = 3
        })
    end)
end

local function startScript(character)
    local rootPart = character:WaitForChild("HumanoidRootPart", 5)
    local humanoid = character:WaitForChild("Humanoid", 5)
    
    if not rootPart or not humanoid then
        sendNotification("Beast Mode", "Failed to find Humanoid/RootPart.")
        return
    end

    local bv = nil
    local bg = nil

    local function createMovers()
        if rootPart:FindFirstChild("FollowVel") then rootPart.FollowVel:Destroy() end
        if rootPart:FindFirstChild("FollowGyro") then rootPart.FollowGyro:Destroy() end
        
        -- Supercharged BodyVelocity
        bv = Instance.new("BodyVelocity")
        bv.Name = "FollowVel"
        bv.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
        bv.Velocity = Vector3.zero
        bv.Parent = rootPart
        
        -- Instant-snap BodyGyro
        bg = Instance.new("BodyGyro")
        bg.Name = "FollowGyro"
        bg.MaxTorque = Vector3.new(0, math.huge, 0)
        bg.P = 5000000 -- Extremely high power for instant snapping
        bg.D = 500     -- Lower dampening for faster response
        bg.Parent = rootPart
    end

    local function cleanup()
        if _G.FollowConnection then
            _G.FollowConnection:Disconnect()
            _G.FollowConnection = nil
        end
        if _G.UnstuckConnection then
            _G.UnstuckConnection:Disconnect()
            _G.UnstuckConnection = nil
        end
        if rootPart:FindFirstChild("FollowVel") then rootPart.FollowVel:Destroy() end
        if rootPart:FindFirstChild("FollowGyro") then rootPart.FollowGyro:Destroy() end
        camera.CameraType = Enum.CameraType.Custom
        local hum = localPlayer.Character and localPlayer.Character:FindFirstChild("Humanoid")
        if hum then camera.CameraSubject = hum end
    end

    cleanup()
    createMovers()

    -- [ BEAST MODE SETTINGS ]
    local backDistance = 3.8       -- Adjusted to keep just out of their hitbox range (was 2.5)
    local maxSpeed = 350           -- Ridiculous speed cap to never lose them
    local predictionFactor = 0.08  -- Predicts where they are moving to cut them off
    local cameraDistance = 10      -- Closer camera view
    
    local lockedTarget = nil

    local function isTargetValid()
        return lockedTarget
            and lockedTarget.Character
            and lockedTarget.Character:FindFirstChild("HumanoidRootPart") ~= nil
            and lockedTarget.Character:FindFirstChild("Humanoid")
            and lockedTarget.Character.Humanoid.Health > 0
    end

    local function findClosestPlayer()
        local myRoot = localPlayer.Character and localPlayer.Character:FindFirstChild("HumanoidRootPart")
        if not myRoot then return nil end
        local closest, closestDist = nil, math.huge
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= localPlayer and p.Character then
                local root = p.Character:FindFirstChild("HumanoidRootPart")
                local hum = p.Character:FindFirstChild("Humanoid")
                if root and hum and hum.Health > 0 then
                    local dist = (root.Position - myRoot.Position).Magnitude
                    if dist < closestDist then
                        closestDist = dist
                        closest = p
                    end
                end
            end
        end
        return closest
    end

    lockedTarget = findClosestPlayer()
    if not lockedTarget then
        sendNotification("Beast Mode", "Hunting for prey...")
    else
        sendNotification("Beast Mode", "Locked onto: " .. lockedTarget.Name)
    end

    local attackKeys = {
        Enum.KeyCode.One,
        Enum.KeyCode.Two,
        Enum.KeyCode.Three,
        Enum.KeyCode.Four,
    }
    
    local currentAttack = 1
    local lastAttack = 0
    local lastUlt = 0
    local lastM1 = 0
    
    -- [ HYPER-AGGRESSIVE COMBAT INTERVALS ]
    local attackInterval = 0.2 -- Spams skills 5x faster
    local ultInterval = 1      -- Tries to ult twice as often
    local m1Interval = 0.05    -- Absolute machine-gun clicks

    local function pressKey(keyCode)
        pcall(function()
            VIM:SendKeyEvent(true, keyCode, false, game)
            task.delay(0.02, function() -- Lightning fast release
                VIM:SendKeyEvent(false, keyCode, false, game)
            end)
        end)
    end

    local function clickM1()
        pcall(function()
            VIM:SendMouseButtonEvent(0, 0, 0, true, game, 1)
            task.delay(0.02, function() -- Lightning fast release
                VIM:SendMouseButtonEvent(0, 0, 0, false, game, 1)
            end)
        end)
    end

    local function killAndRespawn()
        sendNotification("Beast Mode", "Stuck! Respawning...")
        local hum = localPlayer.Character and localPlayer.Character:FindFirstChild("Humanoid")
        if hum then hum.Health = 0 end
    end

    local lastReset = tick()
    local resetInterval = 180 -- 3 minutes

    local lastPos = rootPart.Position
    local lastPosCheck = tick()
    local stuckInterval = 5 -- Checks if stuck more frequently
    local stuckThreshold = 2
    local stuckDistFromTarget = 10

    _G.UnstuckConnection = RunService.Heartbeat:Connect(function()
        local myRoot = localPlayer.Character and localPlayer.Character:FindFirstChild("HumanoidRootPart")
        if not myRoot then return end

        local now = tick()

        -- Anti-Stuck Logic
        if now - lastPosCheck >= stuckInterval then
            local moved = (myRoot.Position - lastPos).Magnitude
            if moved < stuckThreshold and isTargetValid() then
                local targetRoot = lockedTarget.Character.HumanoidRootPart
                local distToTarget = (myRoot.Position - targetRoot.Position).Magnitude
                if distToTarget > stuckDistFromTarget then
                    killAndRespawn()
                end
            end
            lastPos = myRoot.Position
            lastPosCheck = now
        end

        -- Auto respawn
        if now - lastReset >= resetInterval then
            killAndRespawn()
            lastReset = now
        end
    end)

    character.AncestryChanged:Connect(function()
        if not character:IsDescendantOf(workspace) then
            cleanup()
        end
    end)

    _G.FollowConnection = RunService.RenderStepped:Connect(function()
        local myRoot = localPlayer.Character and localPlayer.Character:FindFirstChild("HumanoidRootPart")
        if not myRoot then
            cleanup()
            return
        end

        if not isTargetValid() then
            lockedTarget = findClosestPlayer()
            if not lockedTarget then
                if bv then bv.Velocity = Vector3.zero end
                return -- Keep hunting but don't crash
            end
            sendNotification("Beast Mode", "Target acquired: " .. lockedTarget.Name)
        end

        local targetRoot = lockedTarget.Character.HumanoidRootPart
        
        -- [ ADVANCED VELOCITY PREDICTION & STICKING ]
        -- Calculate their velocity to stick to them even if they dash or sprint
        local targetVel = targetRoot.AssemblyLinearVelocity or targetRoot.Velocity or Vector3.zero
        
        -- Predict where their back will be in the next few frames
        local predictedBackCFrame = targetRoot.CFrame * CFrame.new(0, 0, backDistance)
        local predictedPos = predictedBackCFrame.Position + (targetVel * predictionFactor)
        
        local diff = predictedPos - myRoot.Position
        local dist = diff.Magnitude

        if bv then
            if dist > 0.5 then
                -- Closes the gap incredibly aggressively by adding our pursuit speed TO their escape speed
                local pursuitVelocity = (diff * 25) + targetVel
                if pursuitVelocity.Magnitude > maxSpeed then
                    pursuitVelocity = pursuitVelocity.Unit * maxSpeed
                end
                bv.Velocity = pursuitVelocity
            else
                -- If we are perfectly on their back, perfectly match their movement speed to stay glued
                bv.Velocity = targetVel
            end
        end

        if bg then
            -- Snaps head and body instantly to face them
            local lookAt = Vector3.new(targetRoot.Position.X, myRoot.Position.Y, targetRoot.Position.Z)
            bg.CFrame = CFrame.new(myRoot.Position, lookAt)
        end

        local now = tick()

        -- Combat loops
        if now - lastM1 >= m1Interval then
            clickM1()
            lastM1 = now
        end

        if now - lastAttack >= attackInterval then
            pressKey(attackKeys[currentAttack])
            currentAttack = (currentAttack % #attackKeys) + 1
            lastAttack = now
        end

        if now - lastUlt >= ultInterval then
            pressKey(Enum.KeyCode.G)
            lastUlt = now
        end

        -- Camera lock
        camera.CameraType = Enum.CameraType.Scriptable
        local camOffset = (myRoot.Position - targetRoot.Position).Unit * cameraDistance
        local camPos = myRoot.Position + camOffset + Vector3.new(0, 4, 0)
        camera.CFrame = CFrame.new(camPos, targetRoot.Position)
    end)
    
    sendNotification("Beast Mode", "Script successfully started!")
end

-- Safely wait for character to load before injecting
local char = localPlayer.Character or localPlayer.CharacterAdded:Wait()
task.wait(0.5) -- Give it a brief moment to finish assembling in the game world
startScript(char)

-- Auto re-inject every time we respawn
localPlayer.CharacterAdded:Connect(function(newCharacter)
    task.wait(1) -- Slightly longer wait on respawn to prevent physics glitches
    camera.CameraType = Enum.CameraType.Custom
    local hum = newCharacter:WaitForChild("Humanoid", 5)
    if hum then camera.CameraSubject = hum end
    startScript(newCharacter)
end)
