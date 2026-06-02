Players = game:GetService("Players")
Workspace = game:GetService("Workspace")
ReplicatedStorage = game:GetService("ReplicatedStorage")
ServerStorage = game:GetService("ServerStorage")
RunService = game:GetService("RunService")
TweenService = game:GetService("TweenService")
TeleportService = game:GetService("TeleportService")
UserInputService = game:GetService("UserInputService")
VirtualUser = game:GetService("VirtualUser")
ContextActionService = game:GetService("ContextActionService")
GuiService = game:GetService("GuiService")
CoreGui = game:GetService("CoreGui")
HttpService = game:GetService("HttpService")
SoundService = game:GetService("SoundService")
Lighting = game:GetService("Lighting")
PhysicsService = game:GetService("PhysicsService")
PathfindingService = game:GetService("PathfindingService")
LocalizationService = game:GetService("LocalizationService")
Debris = game:GetService("Debris")

killersFolder = Workspace:WaitForChild("Players"):WaitForChild("Killers")
survivorsFolder = Workspace:WaitForChild("Players"):WaitForChild("Survivors")
localPlayer = Players.LocalPlayer
playerCharacter = localPlayer.Character or localPlayer.CharacterAdded:Wait()

localPlayer.CharacterAdded:Connect(function(character)
    playerCharacter = character
end)
-- =========================================================================
-- HUTAOHUB ESP BACKEND CORE SYSTEM
-- =========================================================================
if getgenv().HutaoESPSystem then
    -- Nếu hệ thống đã chạy ngầm trước đó, tiến hành dọn dẹp kết nối cũ để tránh rò rỉ bộ nhớ
    local oldSys = getgenv().HutaoESPSystem
    if oldSys.System.GlobalScanLoop then task.cancel(oldSys.System.GlobalScanLoop) end
    if oldSys.System.LogicScanLoop then task.cancel(oldSys.System.LogicScanLoop) end
    if oldSys.System.UpdateLoop then oldSys.System.UpdateLoop:Disconnect() end
    for _, con in ipairs(oldSys.System.Connections) do pcall(con.Disconnect, con) end
end

getgenv().HutaoESPSystem = {
    System = {
        Enabled = {},
        Objects = {},
        Connections = {},
        GlobalScanLoop = nil,
        LogicScanLoop = nil, 
        UpdateLoop = nil,
        LastUpdate = 0
    },
    ConfigsMap = {},
    Folders = { Survivors = nil, Killers = nil, Gen = nil },
    Cache = { CachedRoot = nil, CleanupTick = 0 },
    
    Config = {
        FONT_SIZE = 12, HEARTBEAT_RATE = 0.15, DISTANCE_RATE = 0.15,
        GENERATOR_DUPLICATE_RADIUS = 10,
        CLONE_IGNORE_POSITION = Vector3.new(-3552.90, 11.88, 267.95), CLONE_IGNORE_RADIUS = 500
    },
    Names = {
        Survivors = { Eliot = true, Shedletsky = true, Chance = true, ["007n7"] = true, Builderman = true, Veeronica = true, JaneDoe = true, Taph = true, Guest1337 = true, TwoTime = true, Noob = true, Dusekkar = true },
        Killers = { Slasher = true, c00lkidd = true, Noli = true, ["1x1x1x1"] = true, ["John Doe"] = true, Sixer = true, Nosferatu = true }
    },
    Constants = {
        EXCLUDED_NPC_KEYWORDS = { "taphtripwire", "subspacetripmine", "buildermandispenser", "buildermansentry", "pray" },
        EXCLUDED_MODELS = { ["rig"] = true, ["bowrig"] = true }
    },
    Utils = {},
    Validators = {},
    Internal = {}
}

local Sys = getgenv().HutaoESPSystem

-- ==========================================
-- UTILS UTILITIES (HÀM BỔ TRỢ PHẲNG)
-- ==========================================
function Sys.Utils.getCharacter() return localPlayer.Character end
function Sys.Utils.getRoot(model)
    if not model then return nil end
    if model:IsA("BasePart") then return model end
    return model.PrimaryPart or model:FindFirstChild("HumanoidRootPart") or model:FindFirstChildWhichIsA("BasePart")
end
function Sys.Utils.getHumanoid(model) return model and model:FindFirstChildWhichIsA("Humanoid") end
function Sys.Utils.isAlive(model) local h = Sys.Utils.getHumanoid(model) return h and h.Health > 0 end
function Sys.Utils.isLocalCharacter(model)
    local char = Sys.Utils.getCharacter()
    if not char or not model then return false end
    return model == char or model:IsDescendantOf(char) or char:IsDescendantOf(model)
end
function Sys.Utils.getDistance(part)
    if not Sys.Cache.CachedRoot or not part then return 0 end
    return math.floor((Sys.Cache.CachedRoot.Position - part.Position).Magnitude)
end
function Sys.Utils.isSurvivor(obj)
    return obj and obj:IsA("Model") and (Sys.Names.Survivors[obj.Name] or (Sys.Folders.Survivors and obj:IsDescendantOf(Sys.Folders.Survivors)) or obj.Parent == Sys.Folders.Survivors)
end
function Sys.Utils.isKiller(obj)
    return obj and obj:IsA("Model") and (Sys.Names.Killers[obj.Name] or (Sys.Folders.Killers and obj:IsDescendantOf(Sys.Folders.Killers)) or obj.Parent == Sys.Folders.Killers)
end
function Sys.Utils.isIgnoredClonePosition(root)
    if not root then return false end
    return (root.Position - Sys.Config.CLONE_IGNORE_POSITION).Magnitude <= Sys.Config.CLONE_IGNORE_RADIUS
end
function Sys.Utils.isExcluded(name)
    local lower = name:lower()
    for _, keyword in ipairs(Sys.Constants.EXCLUDED_NPC_KEYWORDS) do
        if lower:find(keyword) then return true end
    end
    return false
end
function Sys.Utils.getModelVolume(model)
    local minPos, maxPos
    for _, v in ipairs(model:GetDescendants()) do
        if v:IsA("BasePart") then
            local pos = v.Position
            if not minPos then minPos, maxPos = pos, pos else
                minPos = Vector3.new(math.min(minPos.X, pos.X), math.min(minPos.Y, pos.Y), math.min(minPos.Z, pos.Z))
                maxPos = Vector3.new(math.max(maxPos.X, pos.X), math.max(maxPos.Y, pos.Y), math.max(maxPos.Z, pos.Z))
            end
        end
    end
    if not minPos or not maxPos then return 0 end
    local size = maxPos - minPos
    return size.X * size.Y * size.Z
end

-- ==========================================
-- INTERNAL LOGIC MECHANICS (HÀM XỬ LÝ KHUNG NHÌN)
-- ==========================================
function Sys.Internal.RemoveESP(id, object)
    local cache = Sys.System.Objects[id]
    if not cache then return end
    local data = cache[object]
    if not data then return end
    if data.Connections then
        for _, connection in ipairs(data.Connections) do pcall(connection.Disconnect, connection) end
    end
    cache[object] = nil
    if data.Highlight then pcall(data.Highlight.Destroy, data.Highlight) end
    if data.Billboard then pcall(data.Billboard.Destroy, data.Billboard) end
end

function Sys.Internal.CleanupEmptyESP()
    for id, objects in pairs(Sys.System.Objects) do
        for object in pairs(objects) do
            if typeof(object) ~= "Instance" or object.Parent == nil then objects[object] = nil end
        end
    end
end

function Sys.Internal.CreateProtectedHighlight(object, color, transparency)
    local h = Instance.new("Highlight")
    h.Name = "HutaoESPHighlight"
    h.FillColor = color
    h.OutlineColor = Color3.new(1,1,1)
    h.FillTransparency = transparency or 0.5
    h.OutlineTransparency = 0
    h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    h.Adornee = object
    h.Enabled = true
    h.Parent = CoreGui
    return h
end

function Sys.Internal.CreateProtectedBillboard(root, color)
    local billboard = Instance.new("BillboardGui")
    billboard.Name = "HutaoESP"
    billboard.AlwaysOnTop = true
    billboard.LightInfluence = 0
    billboard.ResetOnSpawn = false
    billboard.MaxDistance = math.huge
    billboard.Size = UDim2.new(0, 220, 0, 50)
    billboard.StudsOffset = Vector3.new(0, 3, 0)
    billboard.Adornee = root

    local text = Instance.new("TextLabel")
    text.BackgroundTransparency = 1
    text.Size = UDim2.new(1,0,1,0)
    text.Font = Enum.Font.GothamBold
    text.TextColor3 = color
    text.TextStrokeTransparency = 0
    text.TextStrokeColor3 = Color3.new(0,0,0)
    text.TextSize = Sys.Config.FONT_SIZE
    text.TextScaled = false
    text.RichText = false
    text.Parent = billboard

    billboard.Parent = CoreGui
    return billboard, text
end

function Sys.Internal.CreateESP(id, object, config)
    if not Sys.System.Enabled[id] or not object or not object.Parent or Sys.Utils.isLocalCharacter(object) then return end
    Sys.System.Objects[id] = Sys.System.Objects[id] or {}
    if Sys.System.Objects[id][object] then return end

    local root = Sys.Utils.getRoot(object)
    if not root then return end

    local billboard, text = Sys.Internal.CreateProtectedBillboard(root, config.Color)
    local highlight = Sys.Internal.CreateProtectedHighlight(object, config.Color, config.FillTransparency)

    local data = {
        Object = object, Billboard = billboard, Text = text, Highlight = highlight, Config = config,
        CachedText = "", Volume = Sys.Utils.getModelVolume(object), LastDistanceUpdate = 0, Connections = {}
    }

    table.insert(data.Connections, object.AncestryChanged:Connect(function(_, parent)
        if not parent then Sys.Internal.RemoveESP(id, object) end
    end))
    table.insert(data.Connections, billboard.AncestryChanged:Connect(function(_, parent)
        if not parent and object.Parent and Sys.System.Objects[id][object] then billboard.Parent = CoreGui end
    end))
    table.insert(data.Connections, data.Highlight.AncestryChanged:Connect(function(_, parent)
        if not parent and object.Parent and Sys.System.Objects[id][object] then
            data.Highlight = Sys.Internal.CreateProtectedHighlight(object, config.Color, config.FillTransparency)
            data.Highlight.Enabled = Sys.System.Enabled[id] or false
        end
    end))

    Sys.System.Objects[id][object] = data
end

function Sys.Internal.ValidateAndCreate(id, obj, config)
    if not Sys.System.Enabled[id] or not obj or not obj.Parent or Sys.Utils.isLocalCharacter(obj) then return end
    if obj:IsA("Model") and Sys.Constants.EXCLUDED_MODELS[obj.Name:lower()] then return end
    local success, valid = pcall(config.Validator, obj)
    if success and valid then Sys.Internal.CreateESP(id, obj, config) end
end

-- ==========================================
-- THE MAP DISCOVERY INTEGRATION
-- ==========================================
function Sys.Internal.GetDynamicMapFolder()
    local mapContainer = Workspace:FindFirstChild("Map")
    local ingame = mapContainer and mapContainer:FindFirstChild("Ingame")
    return ingame and ingame:FindFirstChild("Map")
end

function Sys.Internal.ScanEnvironment(id, config)
    local watchFolder = (id == "Generator" or id == "FakeGenerator" or id == "Item") and Sys.Internal.GetDynamicMapFolder() or config.WatchFolder
    if id == "Item" and watchFolder then
        for _, obj in ipairs(watchFolder:GetDescendants()) do
            if obj:IsA("Tool") then Sys.Internal.ValidateAndCreate(id, obj, config) end
        end
    else
        local descendants = Workspace:GetDescendants()
        for i, obj in ipairs(descendants) do
            if obj:IsA("Model") or obj:IsA("Tool") then Sys.Internal.ValidateAndCreate(id, obj, config) end
            if i % 1000 == 0 then task.wait() end
        end
        if watchFolder then
            for _, obj in ipairs(watchFolder:GetChildren()) do Sys.Internal.ValidateAndCreate(id, obj, config) end
        end
    end
end

-- ==========================================
-- MAIN THREAD LOOPS & HOOKS (HỆ THỐNG VÒNG LẶP CHÍNH)
-- ==========================================
RunService.Heartbeat:Connect(function()
    local char = Sys.Utils.getCharacter()
    Sys.Cache.CachedRoot = char and Sys.Utils.getRoot(char)
end)

Sys.System.GlobalScanLoop = task.spawn(function()
    while true do
        task.wait(10)
        local descendants = Workspace:GetDescendants()
        for i = 1, #descendants do
            local obj = descendants[i]
            if obj:IsA("Model") or obj:IsA("Tool") then
                for id, config in pairs(Sys.ConfigsMap) do
                    if id ~= "Item" and Sys.System.Enabled[id] then Sys.Internal.ValidateAndCreate(id, obj, config) end
                end
            end
            if i % 500 == 0 then task.wait() end
        end
    end
end)

table.insert(Sys.System.Connections, Workspace.DescendantAdded:Connect(function(obj)
    if obj:IsA("Tool") then
        local itemRoot = obj:FindFirstChild("ItemRoot")
        if itemRoot and itemRoot:FindFirstChild("ProximityPrompt") and Sys.System.Enabled["Item"] then
            local itemConfig = Sys.ConfigsMap["Item"]
            if itemConfig then Sys.Internal.ValidateAndCreate("Item", obj, itemConfig) end
        end
        return
    end
    if not obj:IsA("Model") then return end
    task.defer(function()
        if not obj.Parent then return end
        for id, config in pairs(Sys.ConfigsMap) do
            if id ~= "Item" and Sys.System.Enabled[id] then Sys.Internal.ValidateAndCreate(id, obj, config) end
        end
    end)
end))

table.insert(Sys.System.Connections, Workspace.DescendantRemoving:Connect(function(obj)
    for id in pairs(Sys.System.Objects) do Sys.Internal.RemoveESP(id, obj) end
end))

Sys.System.LogicScanLoop = task.spawn(function()
    while true do
        task.wait(1)
        Sys.Cache.CleanupTick = Sys.Cache.CleanupTick + 1
        if Sys.Cache.CleanupTick >= 20 then
            Sys.Cache.CleanupTick = 0
            Sys.Internal.CleanupEmptyESP()
        end
        
        for id, objects in pairs(Sys.System.Objects) do
            if not Sys.System.Enabled[id] then continue end
            for object, data in pairs(objects) do
                if not object or not object.Parent or Sys.Utils.isLocalCharacter(object) or object.Name == "Rig" then
                    Sys.Internal.RemoveESP(id, object) continue
                end
                if Sys.Utils.isExcluded(object.Name) and not (id == "Trap" or id == "Sentry" or id == "Dispenser" or id == "Subspace" or id == "JohnDoeTrap") then
                    Sys.Internal.RemoveESP(id, object) continue
                end
                local root = Sys.Utils.getRoot(object)
                if not root or not root.Parent then Sys.Internal.RemoveESP(id, object) continue end
                if id == "Clone" and (Sys.Utils.getHumanoid(object) == nil or Sys.Utils.getHumanoid(object).Health <= 0 or Sys.Utils.isSurvivor(object) or Sys.Utils.isKiller(object) or Sys.Utils.isIgnoredClonePosition(root)) then
                    Sys.Internal.RemoveESP(id, object) continue
                end
                if data.Config.Living and not Sys.Utils.isAlive(object) then Sys.Internal.RemoveESP(id, object) continue end
                
                if data.Config.Generator then
                    local p = object:FindFirstChild("Progress", true)
                    if p and p:IsA("NumberValue") and p.Value >= 100 then Sys.Internal.RemoveESP(id, object) continue end
                    for otherObject, otherData in pairs(objects) do
                        if otherObject ~= object and otherData and otherData.Config and otherData.Config.Generator then
                            local otherRoot = Sys.Utils.getRoot(otherObject)
                            if otherRoot and (root.Position - otherRoot.Position).Magnitude <= Sys.Config.GENERATOR_DUPLICATE_RADIUS then
                                if root.Position.Y < otherRoot.Position.Y then Sys.Internal.RemoveESP(id, object) break
                                elseif math.abs(root.Position.Y - otherRoot.Position.Y) <= 2 and data.Volume < (otherData.Volume or 0) then
                                    Sys.Internal.RemoveESP(id, object) break
                                end
                            end
                        end
                    end
                end
                if data.Config.Item then
                    local itemRoot = object:FindFirstChild("ItemRoot")
                    if not itemRoot or not itemRoot:FindFirstChild("ProximityPrompt") then Sys.Internal.RemoveESP(id, object) continue end
                end
            end
        end
    end
end)

Sys.System.UpdateLoop = RunService.Heartbeat:Connect(function(delta)
    Sys.System.LastUpdate = Sys.System.LastUpdate + delta
    if Sys.System.LastUpdate < Sys.Config.HEARTBEAT_RATE then return end
    Sys.System.LastUpdate = 0

    local now = tick()
    for id, objects in pairs(Sys.System.Objects) do
        if not Sys.System.Enabled[id] then continue end
        for object, data in pairs(objects) do
            local root = Sys.Utils.getRoot(object)
            if not root then continue end

            local dist = Sys.Utils.getDistance(root)
            local withinRange = (dist <= 500)

            if now - (data.LastProtectionCheck or 0) >= 2 then
                data.LastProtectionCheck = now
                if not data.Highlight or not data.Highlight.Parent then data.Highlight = Sys.Internal.CreateProtectedHighlight(object, data.Config.Color, data.Config.FillTransparency) end
                if not data.Billboard or not data.Billboard.Parent then data.Billboard, data.Text = Sys.Internal.CreateProtectedBillboard(root, data.Config.Color) end
            end

            if data.Highlight.Adornee ~= object then data.Highlight.Adornee = object end
            if data.Highlight.Enabled ~= withinRange then data.Highlight.Enabled = withinRange end
            if data.Billboard.Adornee ~= root then data.Billboard.Adornee = root end
            if data.Billboard.Enabled ~= withinRange then data.Billboard.Enabled = withinRange end

            if withinRange and (now - data.LastDistanceUpdate >= Sys.Config.DISTANCE_RATE) then
                data.LastDistanceUpdate = now
                local text
                if id == "JohnDoeTrap" then text = "Digital Trap [" .. dist .. "m]" else
                    local h = Sys.Utils.getHumanoid(object)
                    text = (data.Config.ShowHealth and h) and string.format("%s [%sm] [HP : %d/%d]", object.Name, dist, math.floor(h.Health), math.floor(h.MaxHealth)) or string.format("%s [%sm]", object.Name, dist)
                end
                if data.CachedText ~= text then
                    data.CachedText = text
                    if data.Text then data.Text.Text = text end
                end
            end
        end
    end
end)

-- ==========================================
-- CONTROLLER ROUTER FOR FRONTEND TOGGLE CALLBACK
-- ==========================================
function Sys.Internal.RegisterRuntimeConfig(id, data)
    Sys.ConfigsMap[id] = data
    Sys.System.Objects[id] = Sys.System.Objects[id] or {}
    if data.WatchFolder then
        table.insert(Sys.System.Connections, data.WatchFolder.ChildAdded:Connect(function(obj)
            task.defer(function() Sys.Internal.ValidateAndCreate(id, obj, data) end)
        end))
    end
end

function Sys.Internal.TriggerToggle(id, state)
    Sys.System.Enabled[id] = state
    local config = Sys.ConfigsMap[id]
    if not config then return end

    if state then
        task.spawn(Sys.Internal.ScanEnvironment, id, config)
    else
        local cache = Sys.System.Objects[id]
        if cache then
            for _, data in pairs(cache) do
                if data.Highlight then data.Highlight.Enabled = false end
                if data.Billboard then data.Billboard.Enabled = false end
            end
        end
    end
end

-- ==========================================
-- CORE BASE VALIDATORS
-- ==========================================
function Sys.Validators.Clone(obj)
    if not obj or not obj:IsA("Model") or Sys.Utils.isLocalCharacter(obj) or obj.Name == "Rig" or Sys.Utils.isExcluded(obj.Name) or Sys.Utils.isSurvivor(obj) or Sys.Utils.isKiller(obj) then return false end
    local h, root = Sys.Utils.getHumanoid(obj), Sys.Utils.getRoot(obj)
    return h and h.Health > 0 and root and not Sys.Utils.isIgnoredClonePosition(root)
end
function Sys.Validators.Model(obj) return obj and obj:IsA("Model") and not Players:GetPlayerFromCharacter(obj) and not Sys.Utils.isLocalCharacter(obj) and Sys.Utils.getRoot(obj) end
function Sys.Validators.Survivor(obj) local h = Sys.Utils.getHumanoid(obj) return obj and obj:IsA("Model") and not Sys.Utils.isLocalCharacter(obj) and Sys.Utils.getRoot(obj) and h and h.Health > 0 and Sys.Utils.isSurvivor(obj) end
function Sys.Validators.Killer(obj) local h = Sys.Utils.getHumanoid(obj) return obj and obj:IsA("Model") and not Sys.Utils.isLocalCharacter(obj) and Sys.Utils.getRoot(obj) and h and h.Health > 0 and Sys.Utils.isKiller(obj) end
function Sys.Validators.Generator(obj)
    if not obj or not obj:IsA("Model") or obj.Name ~= "Generator" then return false end
    local map = Sys.Internal.GetDynamicMapFolder()
    if not map or not obj:IsDescendantOf(map) or not Sys.Utils.getRoot(obj) then return false end
    if obj.Parent and obj.Parent:IsA("Model") and obj.Parent.Name:lower():find("generator") then return false end
    local p = obj:FindFirstChild("Progress", true)
    if p and p:IsA("NumberValue") and p.Value >= 100 then return false end
    local myVol = Sys.Utils.getModelVolume(obj)
    for _, other in ipairs(map:GetChildren()) do
        if other ~= obj and other:IsA("Model") and other.Name:lower():find("generator") then
            local otherRoot = Sys.Utils.getRoot(other)
            if otherRoot and (Sys.Utils.getRoot(obj).Position - otherRoot.Position).Magnitude <= Sys.Config.GENERATOR_DUPLICATE_RADIUS and Sys.Utils.getModelVolume(other) > myVol then return false end
        end
    end
    return true
end
function Sys.Validators.Item(obj) if not obj or not obj:IsA("Tool") then return false end local r = obj:FindFirstChild("ItemRoot") return r and r:FindFirstChild("ProximityPrompt") ~= nil end
function Sys.Validators.Dispenser(obj) return obj and obj:IsA("Model") and obj.Name:lower():find("dispenser") and not Sys.Utils.isLocalCharacter(obj) and Sys.Utils.getRoot(obj) end
function Sys.Validators.Sentry(obj) return obj and obj:IsA("Model") and obj.Name:lower():find("sentry") and not Sys.Utils.isLocalCharacter(obj) and Sys.Utils.getRoot(obj) end
function Sys.Validators.Trap(obj) return obj and obj:IsA("Model") and obj.Name:find("TaphTripwire") and not Sys.Utils.isLocalCharacter(obj) and Sys.Utils.getRoot(obj) end
function Sys.Validators.Subspace(obj) return obj and obj:IsA("Model") and obj.Name == "SubspaceTripmine" and not Sys.Utils.isLocalCharacter(obj) and Sys.Utils.getRoot(obj) end
function Sys.Validators.JohnDoeTrap(obj) local n = obj.Name:lower() return obj and (n == "shadow" or n:find("shadow")) and not Sys.Utils.isLocalCharacter(obj) and Sys.Utils.getRoot(obj) end
function Sys.Validators.FakeGenerator(obj) if not obj or not obj:IsA("Model") or obj.Name ~= "FakeGenerator" then return false end local m = Sys.Internal.GetDynamicMapFolder() return m and obj:IsDescendantOf(m) and Sys.Utils.getRoot(obj) ~= nil end

print("HutaoESP Backend Loaded Successfully via getgenv()!")
