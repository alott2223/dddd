-- Phantom Forces Wapus Features
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local PathfindingService = game:GetService("PathfindingService")
local Camera = Workspace.CurrentCamera

local LocalPlayer = Players.LocalPlayer

-- Settings Table
local Settings = {
    RageBot = {
        Enabled = true,
        Aimbot = true,
        AutoFire = true,
        FOV = 500,
        HitChance = 100,
        HeadshotChance = 100,
        VisibleCheck = false,
        TargetPart = "Head", -- "Head", "Torso", or "Closest"
        Smoothness = 1, -- Lower = smoother aim (1 = instant)
        AutoWall = false
    },
    SilentAim = {
        Enabled = true,
        FOV = 500,
        HitChance = 100,
        HeadshotChance = 100,
        VisibleCheck = false
    },
    GunMods = {
        NoRecoil = true,
        NoSway = true,
        NoSpread = true,
        SmallCrosshair = true,
        NoCameraBob = true
    },
    Movement = {
        NoFallDamage = true
    },
    Pathfinding = {
        Enabled = true,
        AutoMoveToTarget = true,
        TargetDistance = 50, -- Stop moving when within this distance
        PathRefreshRate = 0.5, -- How often to recalculate path (seconds)
        AgentRadius = 2,
        AgentHeight = 5,
        AgentCanJump = true
    }
}

-- Get modules (matching pattern from cloned repo)
local moduleCache
for i, v in getgc(true) do
    if type(v) == "table" and rawget(v, "ScreenCull") and rawget(v, "NetworkClient") then
        moduleCache = v
        break
    end
end

local Modules = {}
if moduleCache then
    for name, data in moduleCache do
        if type(data) == "table" then
            Modules[name] = data.module
        end
    end
    print("[RageBot] Modules loaded successfully")
else
    warn("[RageBot] Module cache not found on first attempt, retrying...")
end

-- Wait for modules to load if not found immediately
if not Modules.NetworkClient then
    local maxAttempts = 50
    for i = 1, maxAttempts do
        task.wait(0.1)
        moduleCache = nil
        for i, v in getgc(true) do
            if type(v) == "table" and rawget(v, "ScreenCull") and rawget(v, "NetworkClient") then
                moduleCache = v
                break
            end
        end
        if moduleCache then
            Modules = {}
            for name, data in moduleCache do
                if type(data) == "table" then
                    Modules[name] = data.module
                end
            end
            if Modules.NetworkClient then
                print("[RageBot] Modules loaded successfully after retry")
                break
            end
        end
    end
end

if not Modules.NetworkClient then
    warn("[RageBot] Failed to load required modules. Some features may not work. Please rejoin the game.")
    warn("[RageBot] Debug: moduleCache = " .. tostring(moduleCache))
    -- Create empty modules table to prevent nil errors
    Modules = {
        NetworkClient = nil,
        ReplicationInterface = nil,
        WeaponControllerInterface = nil,
        PublicSettings = nil,
        BulletObject = nil,
        RecoilSprings = nil,
        FirearmObject = nil,
        CFrameLib = nil,
        MainCameraObject = nil,
        ModifyData = nil
    }
end

local Network = Modules.NetworkClient
local ReplicationInterface = Modules.ReplicationInterface
local WeaponInterface = Modules.WeaponControllerInterface
local PublicSettings = Modules.PublicSettings
local BulletObject = Modules.BulletObject
local Recoil = Modules.RecoilSprings
local FirearmObject = Modules.FirearmObject
local CFrameLib = Modules.CFrameLib
local CameraObject = Modules.MainCameraObject
local ModifyData = Modules.ModifyData

-- Store originals (with nil checks)
local Originals = {}
if Network then
    Originals.Send = Network.send
end
if BulletObject then
    Originals.NewBullet = BulletObject.new
end
if Recoil then
    Originals.ApplyImpulse = Recoil.applyImpulse
end
if FirearmObject then
    Originals.ComputeGunSway = FirearmObject.computeGunSway
    Originals.ComputeWalkSway = FirearmObject.computeWalkSway
end
if CFrameLib then
    Originals.FromAxisAngle = CFrameLib.fromAxisAngle
end
if CameraObject then
    Originals.Step = CameraObject.step
end
if ModifyData then
    Originals.GetModifiedData = ModifyData.getModifiedData
end

-- Silent Aim Functions
local function ComplexTrajectory(o, a, t, s, e)
    local ld = t - o
    a = -a
    e = e or Vector3.zero

    local function Solve(v44, v45, v46, v47, v48)
        if not v44 then return end
        if v44 > -1.0E-10 and v44 < 1.0E-10 then return Solve(v45, v46, v47, v48) end
        
        if v48 then
            local v49 = -v45 / (4 * v44)
            local v50 = (v46 + v49 * (3 * v45 + 6 * v44 * v49)) / v44
            local v51 = (v47 + v49 * (2 * v46 + v49 * (3 * v45 + 4 * v44 * v49))) / v44
            local v52 = (v48 + v49 * (v47 + v49 * (v46 + v49 * (v45 + v44 * v49)))) / v44
            
            if v51 > -1.0E-10 and v51 < 1.0E-10 then
                local v53, v54 = Solve(1, v50, v52)
                if not v54 or v54 < 0 then return end
                local v55, v56 = math.sqrt(v53), math.sqrt(v54)
                return v49 - v56, v49 - v55, v49 + v55, v49 + v56
            else
                local v57, _, v59 = Solve(1, 2 * v50, v50 * v50 - 4 * v52, -v51 * v51)
                local v60 = v59 or v57
                local v61 = math.sqrt(v60)
                local v62, v63 = Solve(1, v61, (v60 + v50 - v51 / v61) / 2)
                local v64, v65 = Solve(1, -v61, (v60 + v50 + v51 / v61) / 2)
                if v62 and v64 then return v49 + v62, v49 + v63, v49 + v64, v49 + v65
                elseif v62 then return v49 + v62, v49 + v63
                elseif v64 then return v49 + v64, v49 + v65 end
            end
        elseif v47 then
            local v66 = -v45 / (3 * v44)
            local v67 = -(v46 + v66 * (2 * v45 + 3 * v44 * v66)) / (3 * v44)
            local v68 = -(v47 + v66 * (v46 + v66 * (v45 + v44 * v66))) / (2 * v44)
            local v69 = v68 * v68 - v67 * v67 * v67
            local v70 = math.sqrt(math.abs(v69))
            
            if v69 > 0 then
                local v71 = v68 + v70
                local v72 = v68 - v70
                v71 = v71 < 0 and -(-v71)^0.3333333333333333 or v71^0.3333333333333333
                local v73 = v72 < 0 and -(-v72)^0.3333333333333333 or v72^0.3333333333333333
                return v66 + v71 + v73
            else
                local v74 = math.atan2(v70, v68) / 3
                local v75 = 2 * math.sqrt(v67)
                return v66 - v75 * math.sin(v74 + 0.5235987755982988), v66 + v75 * math.sin(v74 - 0.5235987755982988), v66 + v75 * math.cos(v74)
            end
        elseif v46 then
            local v76 = -v45 / (2 * v44)
            local v77 = v76 * v76 - v46 / v44
            if v77 < 0 then return end
            local v78 = math.sqrt(v77)
            return v76 - v78, v76 + v78
        elseif v45 then
            return -v45 / v44
        end
    end

    local r1, r2, r3, r4 = Solve(a:Dot(a) * 0.25, a:Dot(e), a:Dot(ld) + e:Dot(e) - s^2, ld:Dot(e) * 2, ld:Dot(ld))
    local x = (r1>0 and r1) or (r2>0 and r2) or (r3>0 and r3) or r4
    local v = (ld + e*x + 0.5*a*x^2) / x
    return v, x
end

local function GetClosestTarget(origin, partName)
    if not ReplicationInterface then return nil, nil, nil end
    
    local distance = Settings.SilentAim.FOV
    local position, closestPlayer, part

    ReplicationInterface.operateOnAllEntries(function(player, entry)
        local character = entry._thirdPersonObject and entry._thirdPersonObject._characterModelHash
        if character and player.Team ~= LocalPlayer.Team then
            local target = character[partName].Position
            local screenPosition = Camera:WorldToViewportPoint(target)
            local screenDistance = (Vector2.new(screenPosition.X, screenPosition.Y) - origin).Magnitude

            if screenPosition.Z > 0 and screenDistance < distance then
                part = character[partName]
                position = target
                distance = screenDistance
                closestPlayer = entry
            end
        end
    end)

    return position, closestPlayer, part
end

-- RageBot Functions
local function GetBestTarget()
    if not ReplicationInterface then return nil, nil, nil end
    
    local bestTarget = nil
    local bestDistance = Settings.RageBot.FOV
    local bestPart = nil
    local bestPlayer = nil

    ReplicationInterface.operateOnAllEntries(function(player, entry)
        local character = entry._thirdPersonObject and entry._thirdPersonObject._characterModelHash
        if character and player.Team ~= LocalPlayer.Team then
            local targetPart = Settings.RageBot.TargetPart
            
            local part = nil
            local targetPos = nil
            
            if targetPart == "Closest" then
                -- Find closest part
                local head = character.Head
                local torso = character.Torso
                if head and torso then
                    local headScreen = Camera:WorldToViewportPoint(head.Position)
                    local torsoScreen = Camera:WorldToViewportPoint(torso.Position)
                    local headDist = (Camera.CFrame.Position - head.Position).Magnitude
                    local torsoDist = (Camera.CFrame.Position - torso.Position).Magnitude
                    
                    if headDist < torsoDist and headScreen.Z > 0 then
                        part = head
                        targetPos = head.Position
                    elseif torsoScreen.Z > 0 then
                        part = torso
                        targetPos = torso.Position
                    end
                end
            else
                part = character[targetPart]
                if part then
                    targetPos = part.Position
                end
            end
            
            if targetPos and part then
                local screenPosition = Camera:WorldToViewportPoint(targetPos)
                local screenDistance = (Vector2.new(screenPosition.X, screenPosition.Y) - Camera.ViewportSize * 0.5).Magnitude
                
                if screenPosition.Z > 0 and screenDistance < bestDistance then
                    bestTarget = targetPos
                    bestDistance = screenDistance
                    bestPart = part
                    bestPlayer = entry
                end
            end
        end
    end)

    return bestTarget, bestPlayer, bestPart
end

local function AimAtTarget(target)
    if not target then return end
    
    local cameraCFrame = Camera.CFrame
    local targetCFrame = CFrame.lookAt(cameraCFrame.Position, target)
    local currentLook = cameraCFrame.LookVector
    local targetLook = targetCFrame.LookVector
    
    local smoothness = Settings.RageBot.Smoothness
    local newLook = currentLook:Lerp(targetLook, 1 / smoothness)
    
    Camera.CFrame = CFrame.lookAt(cameraCFrame.Position, cameraCFrame.Position + newLook * 100)
end

-- Pathfinding Functions
local PathfindingAgent = nil
local CurrentPath = nil
local PathWaypoints = {}
local LastPathUpdate = 0
local CurrentTargetPosition = nil

local function CreatePathfindingAgent()
    if not LocalPlayer.Character or not LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
        return nil
    end
    
    local agentParams = {
        AgentRadius = Settings.Pathfinding.AgentRadius,
        AgentHeight = Settings.Pathfinding.AgentHeight,
        AgentCanJump = Settings.Pathfinding.AgentCanJump,
        WaypointSpacing = 4,
        Costs = {
            Water = math.huge,
            Danger = math.huge
        }
    }
    
    return PathfindingService:CreatePath(agentParams)
end

local function CalculatePathToTarget(targetPosition)
    if not Settings.Pathfinding.Enabled or not Settings.Pathfinding.AutoMoveToTarget then
        return nil
    end
    
    local character = LocalPlayer.Character
    if not character then return nil end
    
    local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
    if not humanoidRootPart then return nil end
    
    local startPosition = humanoidRootPart.Position
    local distance = (startPosition - targetPosition).Magnitude
    
    if distance <= Settings.Pathfinding.TargetDistance then
        CurrentPath = nil
        PathWaypoints = {}
        return nil
    end
    
    if not PathfindingAgent then
        PathfindingAgent = CreatePathfindingAgent()
    end
    
    if not PathfindingAgent then return nil end
    
    local success, errorMessage = pcall(function()
        PathfindingAgent:ComputeAsync(startPosition, targetPosition)
    end)
    
    if success and PathfindingAgent.Status == Enum.PathStatus.Success then
        CurrentPath = PathfindingAgent
        PathWaypoints = PathfindingAgent:GetWaypoints()
        return PathWaypoints
    else
        CurrentPath = nil
        PathWaypoints = {}
        return nil
    end
end

local function MoveAlongPath()
    if not Settings.Pathfinding.Enabled or not Settings.Pathfinding.AutoMoveToTarget then
        return
    end
    
    local character = LocalPlayer.Character
    if not character then return end
    
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
    
    if not humanoid or not humanoidRootPart then return end
    
    if #PathWaypoints == 0 then
        humanoid:MoveTo(humanoidRootPart.Position)
        return
    end
    
    local currentWaypoint = PathWaypoints[1]
    if not currentWaypoint then return end
    
    local distanceToWaypoint = (humanoidRootPart.Position - currentWaypoint.Position).Magnitude
    
    if distanceToWaypoint < 3 then
        table.remove(PathWaypoints, 1)
        if #PathWaypoints > 0 then
            currentWaypoint = PathWaypoints[1]
        end
    end
    
    if currentWaypoint then
        if currentWaypoint.Action == Enum.PathWaypointAction.Jump then
            humanoid.Jump = true
        end
        humanoid:MoveTo(currentWaypoint.Position)
    end
end

-- Character cleanup
LocalPlayer.CharacterAdded:Connect(function()
    PathfindingAgent = nil
    CurrentPath = nil
    PathWaypoints = {}
    LastPathUpdate = 0
    CurrentTargetPosition = nil
end)

-- RageBot Main Loop
local RageBotConnection
if Settings.RageBot.Enabled then
    RageBotConnection = RunService.Heartbeat:Connect(function()
        if Settings.RageBot.Enabled and Settings.RageBot.Aimbot then
            local target, player, part = GetBestTarget()
            if target then
                AimAtTarget(target)
                
                -- Pathfinding to target
                if Settings.Pathfinding.Enabled and Settings.Pathfinding.AutoMoveToTarget then
                    local currentTime = tick()
                    if currentTime - LastPathUpdate >= Settings.Pathfinding.PathRefreshRate or CurrentTargetPosition ~= target then
                        CalculatePathToTarget(target)
                        CurrentTargetPosition = target
                        LastPathUpdate = currentTime
                    end
                    MoveAlongPath()
                end
                
                -- Auto Fire
                if Settings.RageBot.AutoFire then
                    local controller = WeaponInterface and WeaponInterface.getActiveWeaponController()
                    if controller then
                        local weapon = controller:getActiveWeapon()
                        if weapon and weapon._weaponData then
                            -- Fire through network client (matching pattern from cloned repo)
                            if Network and Network.send then
                                Network:send("shoot", tick())
                            end
                        end
                    end
                end
            else
                -- No target, stop pathfinding
                if Settings.Pathfinding.Enabled then
                    PathWaypoints = {}
                    CurrentTargetPosition = nil
                end
            end
        end
    end)
end

-- Silent Aim Hooks
if Network and Network.send then
    local OriginalNetworkSend = Network.send
    function Network.send(self, name, ...)
        if name == "falldamage" and Settings.Movement.NoFallDamage then
            return -- Block fall damage packets
        end
        
        if name == "newbullets" and Settings.SilentAim.Enabled then
            local uniqueId, bulletData, time = ...
            
            if Settings.SilentAim.HitChance >= math.random(1, 100) then
                local partName = Settings.SilentAim.HeadshotChance >= math.random(1, 100) and "Head" or "Torso"
                local target = GetClosestTarget(Camera.ViewportSize * 0.5, partName)

                if target then
                    local controller = WeaponInterface and WeaponInterface.getActiveWeaponController()
                    if controller then
                        local weapon = controller:getActiveWeapon()
                        if weapon and weapon._weaponData then
                            local velocity = ComplexTrajectory(bulletData.firepos, PublicSettings.bulletAcceleration, target, weapon._weaponData.bulletspeed, Vector3.zero).Unit
                            
                            for _, bullet in bulletData.bullets do
                                bullet[1] = velocity
                            end
                        end
                    end
                end
            end
        end
        
        return OriginalNetworkSend(self, name, ...)
    end
end

if BulletObject and BulletObject.new then
    local OriginalBulletNew = BulletObject.new
    function BulletObject.new(bulletData)
    if bulletData.onplayerhit and Settings.SilentAim.Enabled then
        if Settings.SilentAim.HitChance >= math.random(1, 100) then
            local partName = Settings.SilentAim.HeadshotChance >= math.random(1, 100) and "Head" or "Torso"
            local target = GetClosestTarget(Camera.ViewportSize * 0.5, partName)

            if target then
                local velocity = ComplexTrajectory(bulletData.position, bulletData.acceleration, target, bulletData.velocity.Magnitude, Vector3.zero)
                bulletData.velocity = velocity
            end
        end
    end
    
        return OriginalBulletNew(bulletData)
    end
end

-- Gun Mods Hooks
if Recoil and Recoil.applyImpulse then
    local OriginalApplyImpulse = Recoil.applyImpulse
    function Recoil.applyImpulse(...)
        if Settings.GunMods.NoRecoil then return end
        return OriginalApplyImpulse(...)
    end
end

if FirearmObject and FirearmObject.computeGunSway then
    local OriginalComputeGunSway = FirearmObject.computeGunSway
    function FirearmObject.computeGunSway(...)
        if Settings.GunMods.NoSway then return CFrame.identity end
        return OriginalComputeGunSway(...)
    end
end

if FirearmObject and FirearmObject.computeWalkSway then
    local OriginalComputeWalkSway = FirearmObject.computeWalkSway
    function FirearmObject.computeWalkSway(self, dy, dx)
        if Settings.GunMods.NoSway then 
            return OriginalComputeWalkSway(self, 0, 0)
        end
        return OriginalComputeWalkSway(self, dy, dx)
    end
end

if CFrameLib and CFrameLib.fromAxisAngle then
    local OriginalFromAxisAngle = CFrameLib.fromAxisAngle
    function CFrameLib.fromAxisAngle(x, y, z)
        if Settings.GunMods.NoSway then
            local controller = WeaponInterface and WeaponInterface.getActiveWeaponController()
            local weapon = controller and controller:getActiveWeapon()
            if weapon and not weapon._aiming then return CFrame.identity end
        end
        return OriginalFromAxisAngle(x, y, z)
    end
end

if CameraObject and CameraObject.step then
    local OriginalStep = CameraObject.step
    function CameraObject.step(self, dt)
        if Settings.GunMods.NoCameraBob then
            OriginalStep(self, 0)
            self._lookDt = dt
            return
        end
        return OriginalStep(self, dt)
    end
end

if ModifyData and ModifyData.getModifiedData then
    local OriginalGetModifiedData = ModifyData.getModifiedData
    function ModifyData.getModifiedData(data, ...)
        setreadonly(data, false)
        
        if Settings.GunMods.NoSpread then
            data.hipfirespread = 0
            data.hipfirestability = 99999
            data.hipfirespreadrecover = 99999
            data.aimspread = 0
            data.aimstability = 99999
        end
        
        if Settings.GunMods.SmallCrosshair then
            data.crosssize = 10
            data.crossexpansion = 0
            data.crossspeed = 100
            data.crossdamper = 1
        end
        
        setreadonly(data, true)
        return OriginalGetModifiedData(data, ...)
    end
end