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
ServerScriptService = game:GetService("ServerScriptService")

MapFolder = Workspace:WaitForChild("Map")
IngameFolder = MapFolder:WaitForChild("Ingame")
killersFolder = Workspace:WaitForChild("Players"):WaitForChild("Killers")
survivorsFolder = Workspace:WaitForChild("Players"):WaitForChild("Survivors")
localPlayer = Players.LocalPlayer
PlayerGui = localPlayer:WaitForChild("PlayerGui", 10)
playerCharacter = localPlayer.Character or localPlayer.CharacterAdded:Wait()

localPlayer.CharacterAdded:Connect(function(character)
    playerCharacter = character
end)

Camera = Workspace.CurrentCamera

if getgenv().HutaoESPSystem then
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
        FONT_SIZE = 12, HEARTBEAT_RATE = 0.1, DISTANCE_RATE = 0.1,
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

-- ====================================================
-- [QUẢN LÝ TRẠNG THÁI HỆ THỐNG - WEAK TABLE]
-- ====================================================
getgenv().FlowAutoSolve = getgenv().FlowAutoSolve or false
getgenv().FlowSolveDelay = getgenv().FlowSolveDelay or 0.08
getgenv().FlowDebug = getgenv().FlowDebug or false

if not getgenv().FlowKnownPuzzles then
    getgenv().FlowKnownPuzzles = {}
    setmetatable(getgenv().FlowKnownPuzzles, { __mode = "k" })
end

local FlowPathCache = {}
local FlowUsedCache = {}
local lastGuiState = false
local HookedModules = {}
local PlayerGui = localPlayer:WaitForChild("PlayerGui")

-- ====================================================
-- [HÀM TIỆN ÍCH LÕI]
-- ====================================================
local function debugPrint(...)
    if getgenv().FlowDebug then print("[FLOW DEBUG]:", ...) end
end

local function safeCall(fn, ...)
    local ok, res = pcall(fn, ...)
    if ok then return res end
    debugPrint("Lỗi thực thi hàm:", res)
end

getgenv().isFlowGuiVisible = function()
    local puzzleUI = PlayerGui:FindFirstChild("PuzzleUI")
    if not (puzzleUI and puzzleUI.Enabled) then return nil end
    
    local container = puzzleUI:FindFirstChild("Container")
    local gridHolder = container and container:FindFirstChild("GridHolder")
    local grid = gridHolder and gridHolder:FindFirstChild("Grid")
    
    if grid and grid.Visible then 
        return grid 
    end
    return nil
end

local function IsPuzzle(tbl)
    if typeof(tbl) ~= "table" then return false end
    if rawget(tbl, "Solution") then return true end
    if rawget(tbl, "paths") and rawget(tbl, "updateGui") then return true end
    return false
end

local function getDirection(r1, c1, r2, c2)
    if r2 < r1 then return "up" end
    if r2 > r1 then return "down" end
    if c2 < c1 then return "left" end
    if c2 > c1 then return "right" end
end

local function getConnections(prev, curr, nextNode)
    local connections = {}
    if prev and curr then
        local dir = getDirection(curr.row, curr.col, prev.row, prev.col)
        if dir == "up" then dir = "down"
        elseif dir == "down" then dir = "up"
        elseif dir == "left" then dir = "right"
        elseif dir == "right" then dir = "left" end
        if dir then connections[dir] = true end
    end
    if nextNode and curr then
        local dir = getDirection(curr.row, curr.col, nextNode.row, nextNode.col)
        if dir then connections[dir] = true end
    end
    return connections
end

local function isNeighbour(a, b)
    return math.abs(a.row - b.row) + math.abs(a.col - b.col) == 1
end

local function findMethod(obj, names)
    for i = 1, #names do
        if typeof(obj[names[i]]) == "function" then return obj[names[i]] end
    end
end

-- ====================================================
-- [THUẬT TOÁN HƯỚNG DẪN VIÊN - SẮP XẾP ĐƯỜNG ĐI]
-- ====================================================
local function findStartNode()
    for i = 1, #FlowPathCache do
        local neighbors = 0
        for j = 1, #FlowPathCache do
            if i ~= j and isNeighbour(FlowPathCache[i], FlowPathCache[j]) then
                neighbors = neighbors + 1
            end
        end
        if neighbors == 1 then return i end
    end
    return 1
end

local function sortPathByRealEnds(unorderedPath)
    if not unorderedPath or #unorderedPath <= 1 then return unorderedPath end
    table.clear(FlowPathCache)
    table.clear(FlowUsedCache)
    
    for i = 1, #unorderedPath do
        FlowPathCache[i] = {row = unorderedPath[i].row, col = unorderedPath[i].col}
    end

    local startNodeIndex = findStartNode()
    local ordered = { FlowPathCache[startNodeIndex] }
    FlowUsedCache[startNodeIndex] = true

    for _ = 2, #FlowPathCache do
        local last = ordered[#ordered]
        local foundNext = false
        for i = 1, #FlowPathCache do
            if not FlowUsedCache[i] and isNeighbour(last, FlowPathCache[i]) then
                table.insert(ordered, FlowPathCache[i])
                FlowUsedCache[i] = true
                foundNext = true
                break
            end
        end
        if not foundNext then
            for i = 1, #FlowPathCache do
                if not FlowUsedCache[i] then
                    table.insert(ordered, FlowPathCache[i])
                    FlowUsedCache[i] = true
                    break
                end
            end
        end
    end
    return ordered
end

-- ====================================================
-- [KIỂM TRA HOÀN THÀNH BẢNG ĐỐ]
-- ====================================================
local function isPuzzleComplete(puzzle)
    if not puzzle.Solution or not puzzle.paths then return false end
    for colorIndex, solutionPath in pairs(puzzle.Solution) do
        local currentPath = puzzle.paths[colorIndex]
        if not currentPath or #currentPath ~= #solutionPath then
            return false
        end
    end
    return true
end

-- ====================================================
-- [MÔ PHỎNG VẼ DẦN DẦN (GUIDE MODE)]
-- ====================================================
local function drawSingleColor(puzzle, colorIndex, solutionPath, updateGui)
    local ordered = sortPathByRealEnds(solutionPath)
    if not ordered or #ordered == 0 then return true end

    puzzle.paths[colorIndex] = {}
    for i = 1, #ordered do 
        puzzle.gridConnections[ordered[i].row.."-"..ordered[i].col] = nil 
    end
    if updateGui then safeCall(updateGui, puzzle) end

    for i = 1, #ordered do
        if not getgenv().FlowAutoSolve or not getgenv().isFlowGuiVisible() then return false end 
        
        local node = ordered[i]
        table.insert(puzzle.paths[colorIndex], {row = node.row, col = node.col})
        puzzle.gridConnections[node.row.."-"..node.col] = getConnections(ordered[i-1], node, ordered[i+1])

        if updateGui then safeCall(updateGui, puzzle) end
        task.wait(getgenv().FlowSolveDelay)
    end
    return true
end

getgenv().SolveFlowPuzzle = function(puzzle)
    if not getgenv().FlowAutoSolve or not IsPuzzle(puzzle) or not puzzle.Solution then return end
    
    if puzzle.GuideActive then return end 
    puzzle.GuideActive = true 

    puzzle.paths = puzzle.paths or {}
    puzzle.gridConnections = puzzle.gridConnections or {}

    local updateGui = findMethod(puzzle, {"updateGui", "UpdateGui", "Render", "render"})
    local checkWin = findMethod(puzzle, {"checkForWin", "CheckForWin", "WinCheck"})
    
    if not getgenv().isFlowGuiVisible() then 
        puzzle.GuideActive = false 
        return 
    end

    for colorIndex = 1, #puzzle.Solution do
        local currentPath = puzzle.paths[colorIndex]
        if not currentPath or #currentPath ~= #puzzle.Solution[colorIndex] then
            local success = drawSingleColor(puzzle, colorIndex, puzzle.Solution[colorIndex], updateGui)
            if not success then break end
        end
    end

    if checkWin and getgenv().isFlowGuiVisible() then safeCall(checkWin, puzzle) end
    puzzle.GuideActive = false
end

getgenv().triggerFlowSolvers = function()
    for puzzle, _ in pairs(getgenv().FlowKnownPuzzles) do
        task.spawn(function() getgenv().SolveFlowPuzzle(puzzle) end)
    end
end

-- ====================================================
-- [VÒNG LẶP KIỂM TRA SIÊU NHẸ]
-- ====================================================
local function ProcessAutoFlowLoop()
    if not getgenv().FlowAutoSolve then return end

    local currentGuiState = (getgenv().isFlowGuiVisible() ~= nil)
    
    if currentGuiState and not lastGuiState then
        task.wait(0.3) 
        getgenv().triggerFlowSolvers()
    end
    
    lastGuiState = currentGuiState
    
    if currentGuiState then
        for puzzle, _ in pairs(getgenv().FlowKnownPuzzles) do
            if puzzle.Solution and not puzzle.GuideActive and not isPuzzleComplete(puzzle) then
                task.spawn(function() getgenv().SolveFlowPuzzle(puzzle) end)
                break
            end
        end
    end
end

-- ====================================================
-- [HỆ THỐNG HOOK MODULE SCRIPT]
-- ====================================================
local function ProcessHookResult(result)
    if IsPuzzle(result) then
        getgenv().FlowKnownPuzzles[result] = true
        getgenv().SolveFlowPuzzle(result)
        return
    end
    if typeof(result) == "table" then
        for _, v in pairs(result) do
            if IsPuzzle(v) then 
                getgenv().FlowKnownPuzzles[v] = true
                getgenv().SolveFlowPuzzle(v) 
            end
        end
    end
end

local function HookModule(moduleScript)
    if HookedModules[moduleScript] then return end
    HookedModules[moduleScript] = true

    local success, module = pcall(require, moduleScript)
    if not success or typeof(module) ~= "table" or typeof(module.new) ~= "function" then return end

    debugPrint("Đã kết nối thành công hệ thống:", moduleScript:GetFullName())

    local oldNew = module.new
    module.new = function(...)
        local result = oldNew(...)
        task.spawn(function()
            task.wait(0.05)
            safeCall(ProcessHookResult, result)
        end)
        return result
    end
end

local function ScanModules()
    -- Đã tái sử dụng ReplicatedStorage từ main file
    local safeContainers = {ReplicatedStorage, game:GetService("StarterGui")}
    for c = 1, #safeContainers do
        task.spawn(function()
            local descendants = safeContainers[c]:GetDescendants()
            for i = 1, #descendants do
                local obj = descendants[i]
                if obj:IsA("ModuleScript") then
                    local lower = string.lower(obj.Name)
                    if lower:find("flow") or lower:find("puzzle") or lower:find("pipe") or lower:find("connect") or lower:find("grid") then
                        HookModule(obj)
                    end
                end
                if i % 40 == 0 then RunService.Heartbeat:Wait() end
            end
        end)
    end
end

ScanModules()

ReplicatedStorage.DescendantAdded:Connect(function(obj)
    if obj:IsA("ModuleScript") then
        local lower = string.lower(obj.Name)
        if lower:find("flow") or lower:find("puzzle") or lower:find("pipe") or lower:find("connect") or lower:find("grid") then
            task.wait(0.05)
            HookModule(obj)
        end
    end
end)

task.spawn(function()
    while true do
        RunService.Heartbeat:Wait()
        local LastTick = getgenv().FlowLoopTick or 0
        if tick() - LastTick >= 0.15 then
            getgenv().FlowLoopTick = tick()
            ProcessAutoFlowLoop()
        end
    end
end)

-- auto block

-- ==================== KHỞI TẠO CẤU HÌNH QUA getgenv() ====================
-- Cho phép tách UI (nút) và logic (script này) thành 2 phần độc lập
-- Nếu biến chưa có trong getgenv(), gán giá trị mặc định

local defaults = {
    soundIds = {
        -- Block M1
        ["112809109188560"] = true, -- slasher 
        ["108907358619313"] = true, -- subject_0
        ["84307400688050"] = true, -- c00lkkid mafia
        ["80516583309685"] = true, -- c00lkidd
        ["140242176732868"] = true, -- john doe
        ["89004992452376"] = true, -- noli artful
        ["109348678063422"] = true, -- noli
        ["117173212095661"] = true, -- 1x
        ["79980897195554"] = true, -- guest666
        ["119583605486352"] = true, -- guest666 
        ["104910828105172"] = true -- nosforatu
    },

    -- Chế độ & tính năng
    BlockMode = "Default",  -- "Default" hoặc "Pro"
    AutoBlock = false,
    ShowCircle = false,
    UseHitCircle = false,
    WallCheck = false,
    StubCheckEnabled = false,

    -- Thông số
    RangeCheck = 25,
    StubCheck = 6,
    HitRange = 10,
    ProBlockCooldown = 0.3,
    ProSoundThreshold = 0.9  -- bỏ qua sound đã chạy quá 90%
}

-- Đồng bộ với getgenv(), chỉ gán nếu chưa tồn tại
for k, v in pairs(defaults) do
    if getgenv()[k] == nil then
        getgenv()[k] = v
    end
end

-- ==================== HÀM KIỂM TRA ĐIỀU KIỆN GUEST1337 ====================
local function isGuest1337()
    -- Chỉ cho phép hoạt động nếu nhân vật (Character) có tên là "Guest1337"
    return playerCharacter and playerCharacter.Name == "Guest1337"
end

local function GetRootPart()
    return playerCharacter and playerCharacter:FindFirstChild("HumanoidRootPart")
end

local function isKiller(player)
    if not killersFolder or not player then return false end
    if killersFolder:FindFirstChild(player.Name) then return true end
    local char = player.Character
    if char and killersFolder:FindFirstChild(char.Name) then return true end
    return false
end

local function FireButton(btn)
    if not btn or not btn.Visible then return end
    pcall(function() btn:Activate() end)
    pcall(function()
        local conns = getconnections(btn.MouseButton1Click)
        for _, conn in ipairs(conns) do
            pcall(function() conn:Fire() end)
        end
    end)
    pcall(function()
        local conns = getconnections(btn.Activated)
        for _, conn in ipairs(conns) do
            pcall(function() conn:Fire() end)
        end
    end)
end

local function fastBlock()
    local mainUI = PlayerGui:FindFirstChild("MainUI")
    local container = mainUI and mainUI:FindFirstChild("AbilityContainer")
    if not container then return end
    local btn = container:FindFirstChild("Block")
    if btn and (btn:IsA("TextButton") or btn:IsA("ImageButton")) then
        FireButton(btn)
    end
end

local function CreateCircle(partRef, size)
    if partRef and partRef.Parent then return partRef end
    local p = Instance.new("Part")
    p.Anchored = true
    p.CanCollide = false
    p.Transparency = 0.2
    p.Material = Enum.Material.Neon
    p.Shape = Enum.PartType.Cylinder
    p.Size = Vector3.new(0.2, size, size)
    p.Color = Color3.fromRGB(255, 0, 0)
    p.Parent = Workspace
    return p
end

local function GetMainKiller()
    if not killersFolder then return nil end
    for _, k in ipairs(killersFolder:GetChildren()) do
        local hrp = k:FindFirstChild("HumanoidRootPart")
        if hrp then
            return k, hrp.CFrame
        end
    end
end

local function isCharacterModel(model)
    return model and model:IsA("Model") and model:FindFirstChildOfClass("Humanoid") ~= nil
end

local function CheckWall(fromPos, toPos)
    if not getgenv().WallCheck then return false end
    local rayParams = RaycastParams.new()
    rayParams.FilterType = Enum.RaycastFilterType.Blacklist
    local blacklist = {playerCharacter}
    local playersFolder = Workspace:FindFirstChild("Players")
    if playersFolder then table.insert(blacklist, playersFolder) end
    for _, obj in ipairs(Workspace:GetChildren()) do
        if isCharacterModel(obj) then table.insert(blacklist, obj) end
    end
    rayParams.FilterDescendantsInstances = blacklist
    local dir = (toPos - fromPos)
    local result = Workspace:Raycast(fromPos, dir, rayParams)
    return result ~= nil
end

local CirclePart, HitCirclePart

local function UpdateCircle()
    -- Nếu không phải Guest1337, dọn dẹp các vòng tròn đang hiển thị và dừng lại
    if not isGuest1337() then
        if CirclePart then CirclePart:Destroy(); CirclePart = nil end
        if HitCirclePart then HitCirclePart:Destroy(); HitCirclePart = nil end
        return
    end

    local hrp = GetRootPart()
    if not hrp then return end
    local killer, kcf = GetMainKiller()
    if not killer or not kcf then return end
    local baseOffset = Vector3.new(0, -3, 0)

    if getgenv().ShowCircle then
        CirclePart = CreateCircle(CirclePart, getgenv().RangeCheck * 2)
        CirclePart.CFrame = (kcf + baseOffset) * CFrame.Angles(0, 0, math.rad(90))
        CirclePart.Size = Vector3.new(0.2, getgenv().RangeCheck * 2, getgenv().RangeCheck * 2)
        if getgenv().UseHitCircle then
            CirclePart.Color = Color3.fromRGB(255, 0, 0)
        else
            local inside = (hrp.Position - kcf.Position).Magnitude <= getgenv().RangeCheck
            CirclePart.Color = inside and Color3.fromRGB(0, 255, 0) or Color3.fromRGB(255, 0, 0)
        end
    elseif CirclePart then
        CirclePart:Destroy()
        CirclePart = nil
    end

    if getgenv().UseHitCircle then
        HitCirclePart = CreateCircle(HitCirclePart, getgenv().HitRange * 2)
        local forward = kcf.LookVector
        local pos = kcf.Position + forward * (getgenv().HitRange * 0.8) + baseOffset
        HitCirclePart.CFrame = CFrame.new(pos) * CFrame.Angles(0, 0, math.rad(90))
        HitCirclePart.Size = Vector3.new(0.2, getgenv().HitRange * 2, getgenv().HitRange * 2)
        local inside = (hrp.Position - pos).Magnitude <= getgenv().HitRange
        HitCirclePart.Color = inside and Color3.fromRGB(0, 255, 0) or Color3.fromRGB(255, 0, 0)
    elseif HitCirclePart then
        HitCirclePart:Destroy()
        HitCirclePart = nil
    end
end

-- ==================== XỬ LÝ SOUND ====================
local function getSoundId(sound)
    if not sound or not sound.SoundId then return nil end
    return tostring(sound.SoundId):match("%d+")
end

local activeAttackers = {}
local function removeActiveSound(player, sound)
    if not activeAttackers[player] then return end
    local data = activeAttackers[player]
    data.sounds[sound] = nil
    if data.endedConns[sound] then
        data.endedConns[sound]:Disconnect()
        data.endedConns[sound] = nil
    end
    if next(data.sounds) == nil then
        for _, conn in pairs(data.endedConns) do
            conn:Disconnect()
        end
        activeAttackers[player] = nil
    end
end

local function onSoundStarted(player, sound, char, soundId)
    -- Chốt chặn: Không phải Guest1337 thì làm ngơ luôn
    if not isGuest1337() then return end
    if not getgenv().AutoBlock then return end
    if not soundId or not getgenv().soundIds[soundId] then return end
    if not isKiller(player) then return end

    if getgenv().BlockMode == "Default" then
        local myRoot = GetRootPart()
        local root = char:FindFirstChild("HumanoidRootPart")
        if not myRoot or not root then return end

        if getgenv().StubCheckEnabled and math.abs(root.Position.Y - myRoot.Position.Y) > getgenv().StubCheck then return end

        local inRange = false
        if getgenv().UseHitCircle then
            local killer, kcf = GetMainKiller()
            if not killer or not kcf then return end
            local baseOffset = Vector3.new(0, -3, 0)
            local forward = kcf.LookVector
            local pos = kcf.Position + forward * (getgenv().HitRange * 0.8) + baseOffset
            inRange = (myRoot.Position - pos).Magnitude <= getgenv().HitRange
        else
            inRange = (myRoot.Position - root.Position).Magnitude <= getgenv().RangeCheck
        end

        if not inRange then return end
        if CheckWall(myRoot.Position, root.Position) then return end

        fastBlock()
    else
        -- Pro mode: lưu trạng thái đang tấn công
        if not activeAttackers[player] then
            local root = char:FindFirstChild("HumanoidRootPart")
            if not root then return end
            activeAttackers[player] = {
                root = root,
                sounds = {},
                endedConns = {}
            }
        else
            local root = char:FindFirstChild("HumanoidRootPart")
            if root then activeAttackers[player].root = root end
        end

        activeAttackers[player].sounds[sound] = true

        local conn = sound.Ended:Connect(function()
            removeActiveSound(player, sound)
        end)
        activeAttackers[player].endedConns[sound] = conn

        local destroyConn
        destroyConn = sound.Destroying:Connect(function()
            removeActiveSound(player, sound)
            destroyConn:Disconnect()
        end)
    end
end

-- ==================== KIỂM TRA PRO MODE ====================
local lastProBlockTime = 0
local proHeartbeatConn = nil

local function checkProBlock()
    -- Chốt chặn: Không phải Guest1337 thì hủy kiểm tra
    if not isGuest1337() then return end
    if not getgenv().AutoBlock then return end
    if getgenv().BlockMode ~= "Pro" then return end

    local now = tick()
    if now - lastProBlockTime < getgenv().ProBlockCooldown then return end

    local myRoot = GetRootPart()
    if not myRoot then return end

    for player, data in pairs(activeAttackers) do
        local root = data.root
        if not root or not root.Parent then
            for _, conn in pairs(data.endedConns) do conn:Disconnect() end
            activeAttackers[player] = nil
            continue
        end

        local anyValidSound = false
        for sound, _ in pairs(data.sounds) do
            if sound and sound.Parent then
                local isPlaying = pcall(function() return sound.IsPlaying end)
                if isPlaying then
                    if sound.TimeLength > 0 then
                        local progress = sound.TimePosition / sound.TimeLength
                        if progress < getgenv().ProSoundThreshold then
                            anyValidSound = true
                            break
                        end
                    else
                        anyValidSound = true
                        break
                    end
                end
            end
        end

        if not anyValidSound then
            for _, conn in pairs(data.endedConns) do conn:Disconnect() end
            activeAttackers[player] = nil
            continue
        end

        if getgenv().StubCheckEnabled and math.abs(root.Position.Y - myRoot.Position.Y) > getgenv().StubCheck then continue end

        local inRange = false
        if getgenv().UseHitCircle then
            local killer, kcf = GetMainKiller()
            if not killer or not kcf then continue end
            local baseOffset = Vector3.new(0, -3, 0)
            local forward = kcf.LookVector
            local pos = kcf.Position + forward * (getgenv().HitRange * 0.8) + baseOffset
            inRange = (myRoot.Position - pos).Magnitude <= getgenv().HitRange
        else
            inRange = (myRoot.Position - root.Position).Magnitude <= getgenv().RangeCheck
        end

        if not inRange then continue end
        if CheckWall(myRoot.Position, root.Position) then continue end

        lastProBlockTime = now
        fastBlock()
        break
    end
end

local function startProLoop()
    if proHeartbeatConn then return end
    proHeartbeatConn = RunService.Heartbeat:Connect(checkProBlock)
end

local function stopProLoop()
    if proHeartbeatConn then
        proHeartbeatConn:Disconnect()
        proHeartbeatConn = nil
    end
end

-- ==================== QUẢN LÝ PLAYER ====================
local function setupSoundListener(char, player)
    if not isKiller(player) then return end

    if activeAttackers[player] then
        for _, conn in pairs(activeAttackers[player].endedConns) do
            conn:Disconnect()
        end
        activeAttackers[player] = nil
    end

    for _, sound in ipairs(char:GetDescendants()) do
        if sound:IsA("Sound") then
            local soundId = getSoundId(sound)
            if soundId and getgenv().soundIds[soundId] then
                local playedEvent = sound:GetPropertyChangedSignal("IsPlaying")
                if playedEvent then
                    playedEvent:Connect(function()
                        if sound.IsPlaying then
                            onSoundStarted(player, sound, char, soundId)
                        end
                    end)
                end
                if sound.IsPlaying then
                    onSoundStarted(player, sound, char, soundId)
                end
            end
        end
    end

    char.DescendantAdded:Connect(function(descendant)
        if descendant:IsA("Sound") then
            local soundId = getSoundId(descendant)
            if soundId and getgenv().soundIds[soundId] then
                local playedEvent = descendant:GetPropertyChangedSignal("IsPlaying")
                if playedEvent then
                    playedEvent:Connect(function()
                        if descendant.IsPlaying then
                            onSoundStarted(player, descendant, char, soundId)
                        end
                    end)
                end
                if descendant.IsPlaying then
                    onSoundStarted(player, descendant, char, soundId)
                end
            end
        end
    end)
end

local playerConns = {}

local function monitorCharacter(player, char)
    if not char then return end
    if isKiller(player) then
        setupSoundListener(char, player)
    end
    playerConns[player] = playerConns[player] or {}
end

local function onPlayerAdded(player)
    if player == localPlayer then return end
    if player.Character then
        monitorCharacter(player, player.Character)
    end
    player.CharacterAdded:Connect(function(char)
        task.wait(0)
        monitorCharacter(player, char)
    end)
end

for _, p in ipairs(Players:GetPlayers()) do
    onPlayerAdded(p)
end
Players.PlayerAdded:Connect(onPlayerAdded)

localPlayer.CharacterAdded:Connect(function(char)
    playerCharacter = char
end)

spawn(function()
    while true do
        -- Nếu là Guest1337 thì cho phép vòng lặp hoạt động
        if isGuest1337() then
            UpdateCircle()
            if getgenv().AutoBlock and getgenv().BlockMode == "Pro" then
                startProLoop()
            else
                stopProLoop()
            end
        else
            -- Nếu đổi tên hoặc mất quyền Guest1337, dọn dẹp hiển thị và dừng ProLoop
            UpdateCircle() 
            stopProLoop()
        end
        task.wait(0.02)
    end
end)


-- Auto Punch Logic

-- Khởi tạo getgenv nếu chưa có
if not getgenv().AutoPunchSettings then
    getgenv().AutoPunchSettings = {
        AimMode = "Character",
        AutoPunchEnabled = false,
        AimbotPunchEnabled = true,
        UseDistanceCheck = false,
        PunchDistance = 10,
        DelayTime = 0.5,
        AimDuration = 1,
        CameraAimSpeed = 8,
        -- Dash
        DashPunchEnabled = false,
        DashRange = 30,
        DashSpeed = 50,
        DashDelay = 0.1,
    }
end

local S = getgenv().AutoPunchSettings

-- ================= REMOTE =================
local remote = ReplicatedStorage:FindFirstChild("Modules") and ReplicatedStorage.Modules:FindFirstChild("Network") and ReplicatedStorage.Modules.Network:FindFirstChild("RemoteEvent")

-- ================= CONFIG =================
local SoundIDs = {
    ["132298811847315"] = true,
    ["18568553101"] = true,
}
local AnimationIDs = {
    ["87259391926321"] = true,
    ["140703210927645"] = true,
    ["136007065400978"] = true,
    ["129843313690921"] = true,
    ["86709774283672"] = true,
    ["108807732150251"] = true,
    ["138040001965654"] = true,
    ["86096387000557"] = true,
}

-- ================= BIẾN NỘI BỘ =================
local isPunchProcessing = false
local soundListener = nil
local animationListener = nil
local aimCoroutine = nil
local dashCoroutine = nil
local lastPunchTarget = nil

-- ================= HÀM HỖ TRỢ =================
local function clickPunchButton(btn)
    if not btn then return end
    local success = pcall(function()
        local connections = getconnections(btn.MouseButton1Click)
        if connections then
            for _, conn in ipairs(connections) do
                pcall(function() conn:Fire() end)
            end
            return true
        end
    end)
    if success then return end
    pcall(function() firesignal(btn.MouseButton1Click) end)
    pcall(function() firesignal(btn.MouseButton1Down) end)
    pcall(function() firesignal(btn.MouseButton1Up) end)
    pcall(function() firesignal(btn.Activated) end)
    pcall(function() btn:Activate() end)
end

local function tryActivatePunchViaUI()
    local mainUI = PlayerGui:FindFirstChild("MainUI")
    local container = mainUI and mainUI:FindFirstChild("AbilityContainer")
    if not container then return false end
    local punchBtn = container:FindFirstChild("Punch")
    if not punchBtn then return false end
    local charges = punchBtn:FindFirstChild("Charges")
    if charges and charges.Text == "0" then return false end
    clickPunchButton(punchBtn)
    return true
end

local function tryActivatePunchViaRemote()
    if not remote then return false end
    local charges = PlayerGui:FindFirstChild("MainUI") 
        and PlayerGui.MainUI:FindFirstChild("AbilityContainer")
        and PlayerGui.MainUI.AbilityContainer:FindFirstChild("Punch")
        and PlayerGui.MainUI.AbilityContainer.Punch:FindFirstChild("Charges")
    if charges and charges.Text == "0" then return false end
    pcall(function()
        remote:FireServer("UseActorAbility", {"Punch"})
    end)
    return true
end

local function getNearestKiller()
    local nearestRoot = nil
    local minDist = math.huge
    local myRoot = playerCharacter and playerCharacter:FindFirstChild("HumanoidRootPart")
    if not myRoot then return nil, nil end
    for _, killer in ipairs(killersFolder:GetChildren()) do
        if killer:IsA("Model") then
            local humanoid = killer:FindFirstChild("Humanoid")
            local root = killer:FindFirstChild("HumanoidRootPart")
            if humanoid and root and humanoid.Health > 0 then
                local dist = (myRoot.Position - root.Position).Magnitude
                if dist < minDist then
                    minDist = dist
                    nearestRoot = root
                end
            end
        end
    end
    return nearestRoot, minDist
end

local function findTargetForAim()
    local target = getNearestKiller()
    if target then return target end
    for _ = 1, 3 do
        wait(0.1)
        target = getNearestKiller()
        if target then return target end
    end
    if lastPunchTarget and lastPunchTarget.Parent and lastPunchTarget.Parent:FindFirstChild("HumanoidRootPart") == lastPunchTarget then
        local hum = lastPunchTarget.Parent:FindFirstChild("Humanoid")
        if hum and hum.Health > 0 then
            return lastPunchTarget
        end
    end
    return nil
end

-- ================= DASH PUNCH (DÙNG LỰC ĐẨY) =================
local function stopDash()
    if dashCoroutine then
        coroutine.close(dashCoroutine)
        dashCoroutine = nil
    end
end

local function dashToKiller(targetRoot, speed, range)
    if not targetRoot or not playerCharacter then return end
    local myRoot = playerCharacter:FindFirstChild("HumanoidRootPart")
    if not myRoot then return end
    
    local dist = (myRoot.Position - targetRoot.Position).Magnitude
    if dist > range then return end
    
    local direction = (targetRoot.Position - myRoot.Position).Unit
    local dashTime = dist / speed
    local startTime = tick()
    
    local connection
    connection = RunService.Heartbeat:Connect(function(deltaTime)
        if tick() - startTime >= dashTime then
            connection:Disconnect()
            myRoot.Velocity = Vector3.zero
            return
        end
        
        local currentTarget = targetRoot.Parent and targetRoot.Parent:FindFirstChild("HumanoidRootPart")
        if not currentTarget then
            connection:Disconnect()
            return
        end
        
        direction = (currentTarget.Position - myRoot.Position).Unit
        myRoot.Velocity = direction * speed
        myRoot.CFrame = myRoot.CFrame:Lerp(
            CFrame.new(myRoot.Position, currentTarget.Position),
            math.min(1, deltaTime * 10)
        )
    end)
end

local function startDash(targetRoot)
    if not targetRoot or not playerCharacter then return end
    stopDash()
    
    local speed = S.DashSpeed
    local range = S.DashRange
    local delay = S.DashDelay
    
    dashCoroutine = coroutine.create(function()
        wait(delay)
        pcall(function()
            dashToKiller(targetRoot, speed, range)
        end)
        dashCoroutine = nil
    end)
    coroutine.resume(dashCoroutine)
end

-- ================= AIM =================
local function startContinuousAim(targetRoot, duration)
    if not targetRoot or not playerCharacter then return end
    local myRoot = playerCharacter:FindFirstChild("HumanoidRootPart")
    if not myRoot then return end

    if aimCoroutine then
        coroutine.close(aimCoroutine)
        aimCoroutine = nil
    end

    aimCoroutine = coroutine.create(function()
        local startTime = tick()
        local hum = playerCharacter:FindFirstChild("Humanoid")
        local cam = workspace.CurrentCamera

        if hum then hum.AutoRotate = false end

        local heartbeat
        heartbeat = RunService.Heartbeat:Connect(function(deltaTime)
            if tick() - startTime >= duration then
                heartbeat:Disconnect()
                if hum then hum.AutoRotate = true end
                aimCoroutine = nil
                return
            end

            local currentRoot = targetRoot.Parent and targetRoot.Parent:FindFirstChild("HumanoidRootPart")
            if not currentRoot then
                local newRoot = findTargetForAim()
                if newRoot then currentRoot = newRoot else return end
            end
            if not currentRoot then return end

            local myCurrentRoot = playerCharacter:FindFirstChild("HumanoidRootPart")
            if not myCurrentRoot then return end

            if S.AimMode == "Character" then
                myCurrentRoot.CFrame = CFrame.lookAt(myCurrentRoot.Position, currentRoot.Position)
            elseif S.AimMode == "Camera" then
                myCurrentRoot.CFrame = CFrame.lookAt(myCurrentRoot.Position, currentRoot.Position)
                if cam then
                    local desiredCF = CFrame.lookAt(cam.CFrame.Position, currentRoot.Position)
                    cam.CFrame = cam.CFrame:Lerp(desiredCF, math.min(1, deltaTime * S.CameraAimSpeed))
                end
            end
        end)
    end)
    coroutine.resume(aimCoroutine)
end

-- ================= TRIGGERS =================
local function triggerPunch()
    if not S.AutoPunchEnabled or isPunchProcessing then return end
    local nearestRoot, dist = getNearestKiller()
    if not nearestRoot then return end
    if S.UseDistanceCheck and dist > S.PunchDistance then return end

    lastPunchTarget = nearestRoot
    isPunchProcessing = true
    
    local success = tryActivatePunchViaUI()
    if not success then tryActivatePunchViaRemote() end
    
    wait(0.6)
    isPunchProcessing = false
end

local function triggerAim()
    if not S.AutoPunchEnabled then return end

    local target = findTargetForAim()
    if not target then return end

    if S.UseDistanceCheck then
        local myRoot = playerCharacter and playerCharacter:FindFirstChild("HumanoidRootPart")
        if myRoot and (myRoot.Position - target.Position).Magnitude > S.PunchDistance then
            return
        end
    end

    if S.DashPunchEnabled then
        startDash(target)
    end

    if S.AimbotPunchEnabled then
        if S.AimMode == "CharacterDelay" then
            coroutine.wrap(function()
                wait(S.DelayTime)
                startContinuousAim(target, S.AimDuration)
            end)()
        else
            startContinuousAim(target, S.AimDuration)
        end
    end
end

local function setupListeners()
    if soundListener then soundListener:Disconnect(); soundListener = nil end
    if animationListener then animationListener:Disconnect(); animationListener = nil end
    if not playerCharacter then return end

    soundListener = playerCharacter.DescendantAdded:Connect(function(desc)
        if desc:IsA("Sound") then
            local id = string.match(desc.SoundId, "rbxassetid://(%d+)")
            if id and SoundIDs[id] then triggerPunch() end
        end
    end)

    local humanoid = playerCharacter:FindFirstChild("Humanoid")
    if humanoid then
        local animator = humanoid:FindFirstChild("Animator")
        if animator then
            animationListener = animator.AnimationPlayed:Connect(function(track)
                if track and track.Animation then
                    local id = string.match(track.Animation.AnimationId, "rbxassetid://(%d+)")
                    if id and AnimationIDs[id] then triggerAim() end
                end
            end)
        end
    end
end

-- ================= CẬP NHẬT KHI CHARACTER SPAWN =================
localPlayer.CharacterAdded:Connect(function(character)
    playerCharacter = character
    if S.AutoPunchEnabled then setupListeners() end
end)

if S.AutoPunchEnabled and playerCharacter then
    setupListeners()
end

-- ================= API CHO UI =================
getgenv().AutoPunchAPI = {
    SetAutoPunch = function(val)
        S.AutoPunchEnabled = val
        if val then setupListeners()
        else
            if soundListener then soundListener:Disconnect(); soundListener = nil end
            if animationListener then animationListener:Disconnect(); animationListener = nil end
            stopDash()
        end
    end,
    SetAimbot = function(val) S.AimbotPunchEnabled = val end,
    SetAimMode = function(val) S.AimMode = val end,
    SetUseDistanceCheck = function(val) S.UseDistanceCheck = val end,
    SetPunchDistance = function(val) S.PunchDistance = tonumber(val) or 10 end,
    SetDelayTime = function(val) S.DelayTime = tonumber(val) or 0.5 end,
    SetAimDuration = function(val) S.AimDuration = tonumber(val) or 1 end,
    SetCameraAimSpeed = function(val) S.CameraAimSpeed = tonumber(val) or 8 end,
    SetDashPunch = function(val) 
        S.DashPunchEnabled = val 
        if not val then stopDash() end 
    end,
    SetDashRange = function(val) S.DashRange = tonumber(val) or 30 end,
    SetDashSpeed = function(val) S.DashSpeed = tonumber(val) or 50 end,
    SetDashDelay = function(val) S.DashDelay = tonumber(val) or 0.1 end,
}

-- Veeronica auto trick

-- Khởi tạo getgenv nếu chưa có
if not getgenv().VeeronicaSettings then
    getgenv().VeeronicaSettings = {
        Sk8ControlEnabled = false,
        AutoTrickEnabled = false,
    }
end

local S = getgenv().VeeronicaSettings

-- ================= CONSTANTS =================
local VEER_SK8_DASH_SPEED = 60
local VEER_SK8_ANIMATION_IDS = { "117058860640843" }

-- ================= BIẾN NỘI BỘ =================
local veerIsSk8Active = false
local veerSk8Loop = nil
local veerSavedHumanoid = {}
local veerCamera = Workspace.CurrentCamera
local veerActiveSk8Track = nil

local autoTrickConnections = {}
local autoTrickLoop = nil
local autoTrickHighlights = {}

-- ================= HÀM HỖ TRỢ =================
local function veerGetHumanoid()
    local char = Players.LocalPlayer.Character
    if not char then return nil end
    return char:FindFirstChildOfClass("Humanoid")
end

local function veerGetRootPart()
    local char = Players.LocalPlayer.Character
    if not char then return nil end
    return char:FindFirstChild("HumanoidRootPart")
end

-- ================= SK8 CONTROL =================
local function veerSaveHumanoidState(humanoid)
    if not humanoid or veerSavedHumanoid[humanoid] then return end
    local state = {
        walkSpeed = humanoid.WalkSpeed,
        jumpPower = humanoid.JumpPower or humanoid.JumpHeight,
        platformStand = humanoid.PlatformStand
    }
    veerSavedHumanoid[humanoid] = state
end

local function veerRestoreHumanoidState(humanoid)
    if not humanoid then return end
    local state = veerSavedHumanoid[humanoid]
    if not state then return end
    humanoid.WalkSpeed = state.walkSpeed
    if humanoid:FindFirstChild("JumpPower") then
        humanoid.JumpPower = state.jumpPower
    elseif humanoid:FindFirstChild("JumpHeight") then
        humanoid.JumpHeight = state.jumpPower
    end
    humanoid.PlatformStand = state.platformStand
    veerSavedHumanoid[humanoid] = nil
end

local function veerIsSk8AnimationActive()
    local humanoid = veerGetHumanoid()
    if not humanoid then return false end
    for _, track in ipairs(humanoid:GetPlayingAnimationTracks()) do
        local anim = track.Animation
        if anim then
            local id = tostring(anim.AnimationId):match("%d+")
            if id and table.find(VEER_SK8_ANIMATION_IDS, id) then
                return track
            end
        end
    end
    return false
end

local function veerStartSk8Override()
    if veerIsSk8Active then return end
    local humanoid = veerGetHumanoid()
    local root = veerGetRootPart()
    if not humanoid or not root then return end

    veerIsSk8Active = true
    veerSaveHumanoidState(humanoid)
    humanoid.WalkSpeed = VEER_SK8_DASH_SPEED

    if veerSk8Loop then veerSk8Loop:Disconnect() end

    veerSk8Loop = RunService.RenderStepped:Connect(function()
        local hum = veerGetHumanoid()
        local rootPart = veerGetRootPart()
        if not hum or not rootPart then
            veerStopSk8Override()
            return
        end

        hum.WalkSpeed = VEER_SK8_DASH_SPEED

        local camLook = veerCamera.CFrame.LookVector
        local moveDir = Vector3.new(camLook.X, 0, camLook.Z)
        if moveDir.Magnitude > 0 then
            moveDir = moveDir.Unit
            hum:Move(moveDir, false)
        end

        local targetCFrame = CFrame.new(rootPart.Position, rootPart.Position + moveDir)
        rootPart.CFrame = rootPart.CFrame:Lerp(targetCFrame, 0.3)
    end)
end

local function veerStopSk8Override()
    if not veerIsSk8Active then return end
    veerIsSk8Active = false

    if veerSk8Loop then
        veerSk8Loop:Disconnect()
        veerSk8Loop = nil
    end

    if veerActiveSk8Track then
        pcall(function() veerActiveSk8Track.Stopped:Disconnect() end)
        veerActiveSk8Track = nil
    end

    local humanoid = veerGetHumanoid()
    if humanoid then
        veerRestoreHumanoidState(humanoid)
        humanoid:Move(Vector3.new(0, 0, 0), false)
    end
end

-- ================= AUTO TRICK V3 =================
local function getBehaviorFolder()
    local ok, folder = pcall(function()
        return ReplicatedStorage.Assets.Survivors.Veeronica.Behavior
    end)
    return ok and folder
end

local function getSprintingButton()
    local gui = PlayerGui
    if not gui then return nil end
    local main = gui:FindFirstChild("MainUI")
    if not main then return nil end
    return main:FindFirstChild("SprintingButton")
end

local function adorneeIsPlayerCharacter(h)
    if not h then return false end
    local adornee = h.Adornee
    local char = playerCharacter
    if not adornee or not char then return false end
    return adornee == char or adornee:IsDescendantOf(char)
end

local function triggerSprint()
    local btn = getSprintingButton()
    if not btn then return end

    local conns = getconnections(btn.MouseButton1Down)
    for _, v in pairs(conns) do
        pcall(function()
            v:Fire()
            if v.Function then v:Function() end
        end)
    end
end

local function autoTrickCleanup()
    for _, conn in ipairs(autoTrickConnections) do
        if conn and conn.Connected then
            conn:Disconnect()
        end
    end
    autoTrickConnections = {}
    autoTrickHighlights = {}

    if autoTrickLoop then
        autoTrickLoop:Disconnect()
        autoTrickLoop = nil
    end
end

local function startAutoTrick()
    autoTrickCleanup()

    local behaviorFolder = getBehaviorFolder()
    if not behaviorFolder then
        warn("[AutoTrick] Behavior folder not found.")
        return
    end

    for _, child in ipairs(behaviorFolder:GetDescendants()) do
        if child:IsA("Highlight") then
            autoTrickHighlights[child] = true
        end
    end

    local addConn = behaviorFolder.DescendantAdded:Connect(function(child)
        if child:IsA("Highlight") then
            autoTrickHighlights[child] = true
        end
    end)
    local removeConn = behaviorFolder.DescendantRemoving:Connect(function(child)
        if child:IsA("Highlight") then
            autoTrickHighlights[child] = nil
        end
    end)

    table.insert(autoTrickConnections, addConn)
    table.insert(autoTrickConnections, removeConn)

    autoTrickLoop = RunService.Heartbeat:Connect(function()
        if not S.AutoTrickEnabled then return end
        for h in pairs(autoTrickHighlights) do
            if adorneeIsPlayerCharacter(h) then
                triggerSprint()
                break
            end
        end
    end)
end

local function stopAutoTrick()
    autoTrickCleanup()
end

-- ================= MAIN SK8 CONTROL LOOP =================
RunService.RenderStepped:Connect(function()
    if not S.Sk8ControlEnabled then
        if veerIsSk8Active then veerStopSk8Override() end
        return
    end

    local humanoid = veerGetHumanoid()
    if not humanoid then
        if veerIsSk8Active then veerStopSk8Override() end
        return
    end

    local currentTrack = veerIsSk8AnimationActive()

    if currentTrack and not veerIsSk8Active then
        veerActiveSk8Track = currentTrack
        currentTrack.Stopped:Connect(function()
            if veerIsSk8Active then veerStopSk8Override() end
        end)
        veerStartSk8Override()
    elseif not currentTrack and veerIsSk8Active then
        veerStopSk8Override()
    end
end)

-- ================= CHARACTER RESPAWN =================
Players.LocalPlayer.CharacterAdded:Connect(function()
    veerStopSk8Override()
    veerSavedHumanoid = {}

    if S.AutoTrickEnabled then
        stopAutoTrick()
        startAutoTrick()
    end
end)

-- ================= API CHO UI =================
getgenv().VeeronicaAPI = {
    SetSk8Control = function(val)
        S.Sk8ControlEnabled = val
        if not val and veerIsSk8Active then
            veerStopSk8Override()
        end
    end,
    SetAutoTrick = function(val)
        S.AutoTrickEnabled = val
        if val then
            startAutoTrick()
        else
            stopAutoTrick()
        end
    end,
}

-- Auto Dagger Aim

-- Khởi tạo getgenv nếu chưa có
if not getgenv().TwoTimeDaggerSettings then
    getgenv().TwoTimeDaggerSettings = {
        AutoDaggerEnabled = false,
        AimDaggerEnabled = false,
        AimDaggerMode = "LookVector",
        DaggerRadius = 4,
        DashEnabled = false,
        DashSpeed = 50
    }
end

local D = getgenv().TwoTimeDaggerSettings

-- ================= BIẾN NỘI BỘ =================
local twoTimeDaggerBtn = nil
local twoTimeCooldownLabel = nil
local twoTimeBehindDistance = 2.5
local twoTimeAimRefCount = 0
local isAiming = false 

local lastSkillTriggerTime = 0 
local lastTargetKiller = nil
local aimDashConnection = nil

-- ================= REMOTE =================
local twoTimeRemoteEvent = ReplicatedStorage:FindFirstChild("Modules")
    and ReplicatedStorage.Modules:FindFirstChild("Network")
    and ReplicatedStorage.Modules.Network:FindFirstChild("RemoteEvent")

-- ================= HÀM KIỂM TRA NHÂN VẬT =================
local function isTwoTimeCharacter()
    return playerCharacter and playerCharacter.Name == "TwoTime"
end

-- ================= HÀM REFRESH UI =================
local function twoTimeRefreshUI()
    if not isTwoTimeCharacter() then 
        twoTimeDaggerBtn, twoTimeCooldownLabel = nil, nil
        return false 
    end
    
    local mainUi = PlayerGui:FindFirstChild("MainUI")
    if not mainUi then return false end
    local container = mainUi:FindFirstChild("AbilityContainer")
    if not container then return false end

    twoTimeDaggerBtn = container:FindFirstChild("Dagger")
    if not twoTimeDaggerBtn then
        for _, child in ipairs(container:GetChildren()) do
            if child:IsA("ImageButton") or child:IsA("TextButton") then
                twoTimeDaggerBtn = child
                break
            end
        end
    end

    if twoTimeDaggerBtn then
        twoTimeCooldownLabel = twoTimeDaggerBtn:FindFirstChild("CooldownTime")
        return true
    end
    twoTimeDaggerBtn, twoTimeCooldownLabel = nil, nil
    return false
end

-- ================= HÀM CHECK SKILL SẴN SÀNG =================
local function isSkillReady()
    if not twoTimeDaggerBtn or not twoTimeCooldownLabel then
        if not twoTimeRefreshUI() then return false end
    end
    if not twoTimeDaggerBtn or not twoTimeCooldownLabel then return false end
    
    if tick() - lastSkillTriggerTime <= 0.3 then 
        return true 
    end

    if twoTimeCooldownLabel.Text ~= "" then 
        return false 
    end
    
    local charges = twoTimeDaggerBtn:FindFirstChild("Charges")
    if charges and charges.Text == "0" then 
        return false 
    end

    return true
end

-- ================= HÀM CLICK GUI =================
local function clickButton(btn)
    if not btn then return end
    local success = pcall(function()
        local connections = getconnections(btn.MouseButton1Click)
        if connections then
            for _, conn in ipairs(connections) do
                pcall(function() conn:Fire() end)
            end
            return true
        end
    end)
    if success then return end
    pcall(function() firesignal(btn.MouseButton1Click) end)
    pcall(function() firesignal(btn.MouseButton1Down) end)
    pcall(function() firesignal(btn.MouseButton1Up) end)
    pcall(function() firesignal(btn.Activated) end)
    pcall(function() btn:Activate() end)
end

-- ================= HÀM DASH THÔNG THƯỜNG =================
local function twoTimeDash()
    if not isTwoTimeCharacter() or not D.DashEnabled then return end
    local hrp = playerCharacter and playerCharacter:FindFirstChild("HumanoidRootPart")
    if not hrp then return end

    local dashDirection = hrp.CFrame.LookVector
    local dashTime = 0.3
    local startTime = tick()

    local conn
    conn = RunService.Heartbeat:Connect(function()
        if not isTwoTimeCharacter() or tick() - startTime >= dashTime then
            conn:Disconnect()
            if hrp and hrp.Parent then hrp.Velocity = Vector3.zero end
            return
        end
        hrp.Velocity = dashDirection * D.DashSpeed
    end)
end

-- ================= KIỂM TRA SAU LƯNG =================
local function isBehindKiller(killerHRP, playerHRP)
    if not killerHRP or not playerHRP then return false end
    local killerLook = killerHRP.CFrame.LookVector
    local toPlayer = (playerHRP.Position - killerHRP.Position).Unit
    local dot = killerLook:Dot(toPlayer)
    return dot < -0.5
end

-- ================= HÀM DASH RA SAU LƯNG KILLER =================
local function startAimDash(killerHRP, playerHRP)
    if aimDashConnection then
        aimDashConnection:Disconnect()
        aimDashConnection = nil
    end

    if not D.DashEnabled then 
        print("[TwoTime] Dash đang TẮT, không dash khi aim.")
        return 
    end
    if not killerHRP or not playerHRP then return end

    local behindPos = killerHRP.Position - killerHRP.CFrame.LookVector * twoTimeBehindDistance
    behindPos = Vector3.new(behindPos.X, killerHRP.Position.Y, behindPos.Z)
    local direction = (behindPos - playerHRP.Position).Unit
    if direction.Magnitude == 0 then return end

    local dashSpeed = D.DashSpeed
    local startTime = tick()
    local dashDuration = 0.4 

    aimDashConnection = RunService.Heartbeat:Connect(function()
        if not isTwoTimeCharacter() then
            aimDashConnection:Disconnect()
            aimDashConnection = nil
            return
        end

        local hrp = playerCharacter and playerCharacter:FindFirstChild("HumanoidRootPart")
        if not hrp or not hrp.Parent then
            aimDashConnection:Disconnect()
            aimDashConnection = nil
            return
        end

        local currentDistance = (behindPos - hrp.Position).Magnitude
        if currentDistance < 0.5 or tick() - startTime > dashDuration then
            hrp.Velocity = Vector3.zero
            aimDashConnection:Disconnect()
            aimDashConnection = nil
            return
        end

        local newBehind = killerHRP.Position - killerHRP.CFrame.LookVector * twoTimeBehindDistance
        newBehind = Vector3.new(newBehind.X, killerHRP.Position.Y, newBehind.Z)
        local newDir = (newBehind - hrp.Position).Unit
        if newDir.Magnitude > 0 then
            hrp.Velocity = newDir * dashSpeed
        end
    end)
end

-- ================= HÀM KÍCH HOẠT SKILL =================
local function twoTimeFireDagger()
    if not isTwoTimeCharacter() then return end
    
    lastSkillTriggerTime = tick() 
    local activated = false

    if twoTimeDaggerBtn then
        clickButton(twoTimeDaggerBtn)
        activated = true
    end

    if not activated and twoTimeRemoteEvent then
        twoTimeRemoteEvent:FireServer("UseActorAbility", { buffer.fromstring("\"Dagger\"") })
        activated = true
    end

    if activated then
        twoTimeDash()
    end
end

-- Aim: LookVector mode
local function twoTimeAimLookVector(khrp, hrp)
    if not isTwoTimeCharacter() then return end
    local humanoid = playerCharacter and playerCharacter:FindFirstChildOfClass("Humanoid")
    if not humanoid then return end

    startAimDash(khrp, hrp)

    isAiming = true
    twoTimeAimRefCount += 1
    if twoTimeAimRefCount == 1 then humanoid.AutoRotate = false end

    hrp.CFrame = CFrame.lookAt(hrp.Position, hrp.Position + khrp.CFrame.LookVector)

    local start = tick()
    local conn
    conn = RunService.RenderStepped:Connect(function()
        if not isTwoTimeCharacter() or tick() - start >= 0.6 or (tick() - lastSkillTriggerTime > 0.3 and twoTimeCooldownLabel and twoTimeCooldownLabel.Text ~= "") then
            conn:Disconnect()
            twoTimeAimRefCount = math.max(0, twoTimeAimRefCount - 1)
            if twoTimeAimRefCount == 0 and humanoid and humanoid.Parent then 
                humanoid.AutoRotate = true 
            end
            isAiming = false
            if aimDashConnection then
                aimDashConnection:Disconnect()
                aimDashConnection = nil
            end
            return
        end
        local look = khrp.CFrame.LookVector
        hrp.CFrame = CFrame.lookAt(hrp.Position, hrp.Position + look)
    end)
end

-- Aim: TPBack mode
local function twoTimeAimTPBack(killer, khrp, hrp)
    if not isTwoTimeCharacter() then return end
    local humanoid = playerCharacter and playerCharacter:FindFirstChildOfClass("Humanoid")
    if not humanoid then return end

    startAimDash(khrp, hrp)

    isAiming = true
    twoTimeAimRefCount += 1
    if twoTimeAimRefCount == 1 then humanoid.AutoRotate = false end

    local behindPos = khrp.Position - khrp.CFrame.LookVector * twoTimeBehindDistance
    behindPos = Vector3.new(behindPos.X, khrp.Position.Y, behindPos.Z)
    hrp.CFrame = CFrame.lookAt(behindPos, khrp.Position)

    local start = tick()
    local conn
    conn = RunService.RenderStepped:Connect(function()
        if not isTwoTimeCharacter() or tick() - start >= 0.6 or (tick() - lastSkillTriggerTime > 0.3 and twoTimeCooldownLabel and twoTimeCooldownLabel.Text ~= "") then
            conn:Disconnect()
            twoTimeAimRefCount = math.max(0, twoTimeAimRefCount - 1)
            if twoTimeAimRefCount == 0 and humanoid and humanoid.Parent then 
                humanoid.AutoRotate = true 
            end
            isAiming = false
            if aimDashConnection then
                aimDashConnection:Disconnect()
                aimDashConnection = nil
            end
            return
        end
        local look = khrp.CFrame.LookVector
        hrp.CFrame = CFrame.lookAt(hrp.Position, hrp.Position + look)
    end)
end

local function twoTimeApplyAim(killer, khrp, hrp)
    if D.AimDaggerMode == "LookVector" then
        twoTimeAimLookVector(khrp, hrp)
    elseif D.AimDaggerMode == "TPBack" then
        twoTimeAimTPBack(killer, khrp, hrp)
    end
end

-- ================= MAIN LOGIC (CÓ DEBUG) =================
local function twoTimeAttemptDagger()
    if not isTwoTimeCharacter() or not D.AutoDaggerEnabled then 
        -- không in debug ở đây để tránh spam
        return 
    end
    
    if not isSkillReady() then 
        -- print("[TwoTime] Skill chưa sẵn sàng (cooldown/charges)")
        return 
    end

    local char = playerCharacter
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end

    for _, killer in ipairs(killersFolder:GetChildren()) do
        if not killer:IsA("Model") then continue end
        local humanoid = killer:FindFirstChild("Humanoid")
        local khrp = killer:FindFirstChild("HumanoidRootPart")
        
        if humanoid and khrp and humanoid.Health > 0 then
            local distance = (hrp.Position - khrp.Position).Magnitude
            
            if distance <= D.DaggerRadius and isBehindKiller(khrp, hrp) then
                
                -- Trường hợp bay vào range trong 0.3s
                if tick() - lastSkillTriggerTime <= 0.3 and D.AimDaggerEnabled then
                    if not isAiming or lastTargetKiller ~= killer then
                        print("[TwoTime] Bay vào range, khóa Aim vào killer: " .. killer.Name)
                        lastTargetKiller = killer
                        twoTimeApplyAim(killer, khrp, hrp)
                    end
                    break 
                end
                
                -- Trường hợp thường
                if not isAiming and tick() - lastSkillTriggerTime > 0.3 then
                    if D.AimDaggerEnabled then
                        print("[TwoTime] Phát hiện killer sau lưng, bắt đầu Aim + Dash: " .. killer.Name)
                        lastTargetKiller = killer
                        twoTimeApplyAim(killer, khrp, hrp)
                    else
                        print("[TwoTime] Aim đang TẮT, chỉ bắn chiêu.")
                    end
                    twoTimeFireDagger()
                    break
                end
            end
        end
    end
end

-- ================= THEO DÕI CLICK THỦ CÔNG =================
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if not isTwoTimeCharacter() then return end
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        local mainUi = PlayerGui:FindFirstChild("MainUI")
        local container = mainUi and mainUi:FindFirstChild("AbilityContainer")
        local daggerBtn = container and container:FindFirstChild("Dagger")
        if daggerBtn and twoTimeCooldownLabel and twoTimeCooldownLabel.Text == "" then
            lastSkillTriggerTime = tick()
        end
    end
end)

-- ================= UI MONITOR =================
twoTimeRefreshUI()
PlayerGui.ChildAdded:Connect(function(child)
    if child.Name == "MainUI" then
        task.delay(0.02, twoTimeRefreshUI)
    end
end)

localPlayer.CharacterAdded:Connect(function()
    twoTimeAimRefCount = 0
    isAiming = false
    lastSkillTriggerTime = 0
    lastTargetKiller = nil
    if aimDashConnection then
        aimDashConnection:Disconnect()
        aimDashConnection = nil
    end
    task.delay(0.5, twoTimeRefreshUI)
end)

RunService.Heartbeat:Connect(twoTimeAttemptDagger)

-- ================= API CHO UI =================
getgenv().TwoTimeDaggerAPI = {
    SetAutoDagger = function(val) D.AutoDaggerEnabled = val end,
    SetAimDagger = function(val) D.AimDaggerEnabled = val end,
    SetAimMode = function(val) D.AimDaggerMode = val end,
    SetRadius = function(val) D.DaggerRadius = tonumber(val) or 4 end,
    SetDash = function(val) D.DashEnabled = val end,
    SetDashSpeed = function(val) D.DashSpeed = tonumber(val) or 50 end,
}

-- Auto Slash Shedletsky

-- Khởi tạo getgenv nếu chưa có
if not getgenv().ShedletskySettings then
    getgenv().ShedletskySettings = {
        AutoSlashEnabled = false,
        SlashRadius = 10,
        SetSlashTime = 1,
        AutoChickenEnabled = false,
        ChickenHPThreshold = 40,
        ChickenDistance = 100,
    }
end

local S = getgenv().ShedletskySettings

-- ================= BIẾN NỘI BỘ =================
local shedKillerDetectionTimes = {}
local shedLastSlashTime = 0
local shedSlashCooldown = 0.7

-- ================= REMOTE =================
local shedRemoteEvent = ReplicatedStorage:FindFirstChild("Modules")
    and ReplicatedStorage.Modules:FindFirstChild("Network")
    and ReplicatedStorage.Modules.Network:FindFirstChild("RemoteEvent")

-- ================= HÀM CLICK GUI =================
local function clickButton(btn)
    if not btn then return end
    local success = pcall(function()
        local connections = getconnections(btn.MouseButton1Click)
        if connections then
            for _, conn in ipairs(connections) do
                pcall(function() conn:Fire() end)
            end
            return true
        end
    end)
    if success then return end
    pcall(function() firesignal(btn.MouseButton1Click) end)
    pcall(function() firesignal(btn.MouseButton1Down) end)
    pcall(function() firesignal(btn.MouseButton1Up) end)
    pcall(function() firesignal(btn.Activated) end)
    pcall(function() btn:Activate() end)
end

-- ================= HÀM KÍCH HOẠT SKILL =================
local function shedActivateSkill(skillName)
    -- Đã fix: Trỏ rõ ràng đến PlayerGui của localPlayer
    local PlayerGui = localPlayer:FindFirstChild("PlayerGui")
    local mainUI = PlayerGui and PlayerGui:FindFirstChild("MainUI")
    local container = mainUI and mainUI:FindFirstChild("AbilityContainer")
    
    if container then
        local btn = container:FindFirstChild(skillName)
        if btn then
            local charges = btn:FindFirstChild("Charges")
            if charges and charges.Text == "0" then return false end
            clickButton(btn)
            return true
        end
    end

    if shedRemoteEvent then
        shedRemoteEvent:FireServer("UseActorAbility", { buffer.fromstring("\"" .. skillName .. "\"") })
        return true
    end
    return false
end

local function shedFireSlash()
    shedActivateSkill("Slash")
end

local function shedFireChicken()
    shedActivateSkill("FriedChicken")
end

-- ================= HÀM KIỂM TRA =================
local function shedIsInRange(hrp, targetHrp, range)
    if not hrp or not targetHrp then return false end
    return (hrp.Position - targetHrp.Position).Magnitude <= range
end

local function shedGetCurrentHP(char)
    if not char then return nil end
    local humanoid = char:FindFirstChildOfClass("Humanoid")
    if not humanoid then return nil end
    return humanoid.Health
end

-- ================= MAIN LOGIC =================
RunService.Heartbeat:Connect(function()
    local char = playerCharacter
    
    -- CHỐT CHẶN 100%: Chỉ hoạt động nếu nhân vật tồn tại VÀ đang nằm trong mục Survivors
    if not (char and char:IsDescendantOf(survivorsFolder)) then
        shedKillerDetectionTimes = {} -- Xóa lịch sử tracking để tránh lỗi kẹt thời gian
        return
    end

    -- AUTO CHICKEN
    if S.AutoChickenEnabled then
        local hp = shedGetCurrentHP(char)
        if hp and hp <= S.ChickenHPThreshold then
            local hrp = char:FindFirstChild("HumanoidRootPart")
            if hrp then
                local allSafe = true
                for _, killer in ipairs(killersFolder:GetChildren()) do
                    if killer:IsA("Model") then
                        local hum = killer:FindFirstChild("Humanoid")
                        local khrp = killer:FindFirstChild("HumanoidRootPart")
                        if hum and khrp and hum.Health > 0 then
                            local dist = (hrp.Position - khrp.Position).Magnitude
                            if dist < S.ChickenDistance then
                                allSafe = false
                                break
                            end
                        end
                    end
                end
                if allSafe then
                    shedFireChicken()
                end
            end
        end
    end

    -- AUTO SLASH
    if not S.AutoSlashEnabled then
        shedKillerDetectionTimes = {}
        return
    end

    local now = tick()
    if now < shedLastSlashTime + shedSlashCooldown then return end

    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end

    for _, killer in ipairs(killersFolder:GetChildren()) do
        if not killer:IsA("Model") then continue end
        local humanoid = killer:FindFirstChild("Humanoid")
        local khrp = killer:FindFirstChild("HumanoidRootPart")
        if humanoid and khrp and humanoid.Health > 0 and shedIsInRange(hrp, khrp, S.SlashRadius) then
            local killerName = killer.Name
            local firstSeen = shedKillerDetectionTimes[killerName] or now
            if now >= firstSeen + S.SetSlashTime then
                shedFireSlash()
                shedLastSlashTime = now
                shedKillerDetectionTimes[killerName] = now
                break
            else
                shedKillerDetectionTimes[killerName] = firstSeen
            end
        else
            shedKillerDetectionTimes[killer.Name] = nil
        end
    end
end)

-- ================= CHARACTER RESPAWN =================
localPlayer.CharacterAdded:Connect(function()
    shedKillerDetectionTimes = {}
end)

-- ================= API CHO UI =================
getgenv().ShedletskyAPI = {
    SetAutoSlash = function(val) S.AutoSlashEnabled = val end,
    SetSlashRadius = function(val) S.SlashRadius = tonumber(val) or 10 end,
    SetSlashTime = function(val) S.SetSlashTime = tonumber(val) or 1 end,
    SetAutoChicken = function(val) S.AutoChickenEnabled = val end,
    SetChickenHP = function(val) S.ChickenHPThreshold = tonumber(val) or 40 end,
    SetChickenDistance = function(val) S.ChickenDistance = tonumber(val) or 100 end,
}

-- Chance Aimbot 

if not getgenv().ChanceSettings then
    getgenv().ChanceSettings = {
        AimbotActive = false,
        AimUseOffset = false,
        PredictionMode = "Speed",
        AimMode = "Normal",
        AimDuration = 1.7,
        AimFasterDuration = 1.5,
        AimSpinDuration = 0.5,
        AutoCoinflip = false,
        CoinflipTargetCharge = 3,
        CoinflipBlockWhenClose = true,
        CoinflipBlockDist = 50,
    }
end

local S = getgenv().ChanceSettings

-- Biến nội bộ
local isAiming = false
local aimStartTime = 0
local prevFlintVisible = false
local lastCoinflipTime = 0
local coinflipCooldown = 0.15

-- Remote
local remoteEvent = ReplicatedStorage:FindFirstChild("Modules")
    and ReplicatedStorage.Modules:FindFirstChild("Network")
    and ReplicatedStorage.Modules.Network:FindFirstChild("RemoteEvent")

-- Hàm click button (dùng connections)
local function clickButton(btn)
    if not btn then return end
    local success = pcall(function()
        local connections = getconnections(btn.MouseButton1Click)
        if connections then
            for _, conn in ipairs(connections) do
                pcall(function() conn:Fire() end)
            end
            return true
        end
    end)
    if success then return end
    pcall(function() firesignal(btn.MouseButton1Click) end)
    pcall(function() firesignal(btn.MouseButton1Down) end)
    pcall(function() firesignal(btn.MouseButton1Up) end)
    pcall(function() firesignal(btn.Activated) end)
    pcall(function() btn:Activate() end)
end

-- Lấy ping (fallback 0.1 nếu không có Stats)
local function getPingSeconds()
    local success, stat = pcall(function() return Stats.Network.ServerStatsItem["Data Ping"] end)
    if not success or not stat then return 0.1 end
    local success2, value = pcall(function() return stat:GetValue() end)
    if success2 and type(value) == "number" then return value / 1000 end
    return 0.1
end

-- Kiểm tra Flintlock đang hiện
local function isFlintlockVisible()
    local char = playerCharacter
    if not char then return false end
    local success, flint = pcall(function() return char:FindFirstChild("Flintlock", true) end)
    if not success or not flint then return false end
    if not flint:IsA("BasePart") then return false end
    return flint.Transparency < 1
end

-- Lấy HRP killer gần nhất
local function getNearestKillerHRP()
    local nearest, minDist = nil, math.huge
    local myRoot = playerCharacter and playerCharacter:FindFirstChild("HumanoidRootPart")
    if not myRoot then return nil end
    for _, killer in ipairs(killersFolder:GetChildren()) do
        if killer:IsA("Model") then
            local hum = killer:FindFirstChild("Humanoid")
            local hrp = killer:FindFirstChild("HumanoidRootPart")
            if hum and hrp and hum.Health > 0 then
                local dist = (myRoot.Position - hrp.Position).Magnitude
                if dist < minDist then
                    minDist = dist
                    nearest = hrp
                end
            end
        end
    end
    return nearest
end

-- Dự đoán vị trí
local function getPredictedPos(targetHRP)
    if not targetHRP then return nil end
    local ping = getPingSeconds()
    local mode = S.PredictionMode
    if mode == "Ping" then
        return targetHRP.Position + (targetHRP.Velocity or Vector3.zero) * ping
    elseif mode == "front" then
        return targetHRP.Position + (targetHRP.CFrame and targetHRP.CFrame.LookVector or Vector3.new()) * 4
    elseif mode == "No Lag" then
        return targetHRP.Position + (targetHRP.CFrame and targetHRP.CFrame.LookVector or Vector3.new()) * (ping * 60)
    else -- Speed (mặc định)
        if S.AimUseOffset then
            return targetHRP.Position + (targetHRP.Velocity or Vector3.zero) * (4 / 60)
        else
            return targetHRP.Position
        end
    end
end

-- Tìm nút Coinflip
local function findCoinflipButton()
    local mainUI = PlayerGui:FindFirstChild("MainUI")
    local container = mainUI and mainUI:FindFirstChild("AbilityContainer")
    if not container then return nil end
    for _, obj in ipairs(container:GetDescendants()) do
        if obj:IsA("TextButton") or obj:IsA("ImageButton") then
            local n = string.lower(obj.Name)
            local t = pcall(function() return string.lower(obj.Text) end) and string.lower(obj.Text) or ""
            if n:find("coin") or n:find("flip") or t:find("coin") or t:find("flip") then
                return obj
            end
        end
    end
    return nil
end

-- Lấy điểm cao nhất
local function getNearbyMaxNumber()
    local mainUI = PlayerGui:FindFirstChild("MainUI")
    local container = mainUI and mainUI:FindFirstChild("AbilityContainer")
    if not container then return nil end
    local maxNum = nil
    for _, obj in ipairs(container:GetDescendants()) do
        if (obj:IsA("TextLabel") or obj:IsA("TextButton") or obj:IsA("TextBox")) and pcall(function() return obj.Text end) then
            local text = tostring(obj.Text)
            local n = tonumber(text)
            if n and n >= 1 and n <= 3 then
                if not maxNum or n > maxNum then
                    maxNum = n
                end
            end
        end
    end
    return maxNum
end

-- Main loop
RunService.Heartbeat:Connect(function()
    -- ========== AIMBOT ==========
    if S.AimbotActive then
        local visible = isFlintlockVisible()

        -- Cạnh lên: flintlock vừa xuất hiện -> bắt đầu aim
        if visible and not prevFlintVisible and not isAiming then
            isAiming = true
            aimStartTime = tick()
        end

        prevFlintVisible = visible

        if isAiming then
            local elapsed = tick() - aimStartTime
            local duration = (S.AimMode == "Faster") and S.AimFasterDuration or S.AimDuration

            -- Reflex: quay tròn trong SpinDuration
            if S.AimMode == "Reflex" and elapsed <= S.AimSpinDuration then
                local hrp = playerCharacter and playerCharacter:FindFirstChild("HumanoidRootPart")
                local hum = playerCharacter and playerCharacter:FindFirstChildOfClass("Humanoid")
                if hrp then
                    if hum then hum.AutoRotate = false end
                    local angle = math.rad(360 * (elapsed / S.AimSpinDuration))
                    hrp.CFrame = CFrame.new(hrp.Position) * CFrame.Angles(0, angle, 0)
                end
            -- Aim bình thường (sau Spin hoặc chế độ khác)
            elseif elapsed <= duration then
                local targetHRP = getNearestKillerHRP()
                if targetHRP then
                    local predicted = getPredictedPos(targetHRP)
                    if predicted then
                        local hrp = playerCharacter and playerCharacter:FindFirstChild("HumanoidRootPart")
                        local hum = playerCharacter and playerCharacter:FindFirstChildOfClass("Humanoid")
                        if hrp then
                            if hum then hum.AutoRotate = false end
                            hrp.CFrame = CFrame.lookAt(hrp.Position, predicted)
                        end
                    end
                end
            else
                -- Hết thời gian aim
                isAiming = false
                local hum = playerCharacter and playerCharacter:FindFirstChildOfClass("Humanoid")
                if hum then hum.AutoRotate = true end
            end
        end
    else
        -- Tắt aimbot -> reset trạng thái
        if isAiming then
            isAiming = false
            local hum = playerCharacter and playerCharacter:FindFirstChildOfClass("Humanoid")
            if hum then hum.AutoRotate = true end
        end
        prevFlintVisible = isFlintlockVisible()
    end

    -- ========== AUTO COINFLIP ==========
    if S.AutoCoinflip then
        local block = false
        if S.CoinflipBlockWhenClose then
            local targetHRP = getNearestKillerHRP()
            local myRoot = playerCharacter and playerCharacter:FindFirstChild("HumanoidRootPart")
            if targetHRP and myRoot then
                local dist = (targetHRP.Position - myRoot.Position).Magnitude
                if dist <= S.CoinflipBlockDist then
                    block = true
                end
            end
        end

        if not block and tick() - lastCoinflipTime >= coinflipCooldown then
            local maxNum = getNearbyMaxNumber()
            if not maxNum or maxNum < S.CoinflipTargetCharge then
                lastCoinflipTime = tick()
                local btn = findCoinflipButton()
                if btn then
                    clickButton(btn)
                end
            end
        end
    end
end)

-- Khi chết/reset
Players.LocalPlayer.CharacterAdded:Connect(function()
    isAiming = false
    prevFlintVisible = false
end)

-- API cho UI
getgenv().ChanceAPI = {
    SetAimbot = function(v) S.AimbotActive = v end,
    SetOffset = function(v) S.AimUseOffset = v end,
    SetPrediction = function(v) S.PredictionMode = v end,
    SetAimMode = function(v) S.AimMode = v end,
    SetCoinflip = function(v) S.AutoCoinflip = v end,
    SetTargetCharge = function(v) S.CoinflipTargetCharge = tonumber(v) or 3 end,
    SetBlockWhenClose = function(v) S.CoinflipBlockWhenClose = v end,
    SetBlockDist = function(v) S.CoinflipBlockDist = tonumber(v) or 50 end,
}

-- Eliot Aimbot

if not getgenv().EliotSettings then
    getgenv().EliotSettings = {
        PizzaAimbotEnabled = false,
        AimDistance = 100,
        AimOffset = 2,
        AutoEatPizzaEnabled = false,
        EatPizzaHPThreshold = 30,
        AimDuration = 0.8,
    }
end

local S = getgenv().EliotSettings

-- Biến nội bộ
local currentTarget = nil
local isLockedOn = false
local aimCompleted = false  -- Đánh dấu đã aim xong trong lần cooldown này
local aimStartTime = 0
local autoRotateDisabledByScript = false
local eliotModels = { ["Elliot"] = true }

-- ================= HÀM HỖ TRỢ =================
local function isEliot()
    local char = playerCharacter
    return char and eliotModels[char.Name] or false
end

local function getHumanoid()
    return playerCharacter and playerCharacter:FindFirstChildOfClass("Humanoid")
end

local function getHRP()
    return playerCharacter and playerCharacter:FindFirstChild("HumanoidRootPart")
end

local function restoreAutoRotate()
    local hum = getHumanoid()
    if hum and autoRotateDisabledByScript then
        hum.AutoRotate = true
        autoRotateDisabledByScript = false
    end
end

-- ================= KIỂM TRA COOLDOWN =================
local function isPizzaOnCooldown()
    local mainUI = PlayerGui:FindFirstChild("MainUI")
    local container = mainUI and mainUI:FindFirstChild("AbilityContainer")
    if not container then return false end

    local pizzaBtn = container:FindFirstChild("Pizza")
    if not pizzaBtn then
        for _, child in ipairs(container:GetChildren()) do
            if (child:IsA("TextButton") or child:IsA("ImageButton")) and string.lower(child.Name):find("pizza") then
                pizzaBtn = child
                break
            end
        end
    end
    if not pizzaBtn then return false end

    -- CHỈ kiểm tra CooldownTime hoặc Cooldown (label hiện số đếm ngược)
    local cooldownLabel = pizzaBtn:FindFirstChild("CooldownTime") or pizzaBtn:FindFirstChild("Cooldown")
    if cooldownLabel and cooldownLabel:IsA("TextLabel") then
        local text = cooldownLabel.Text:gsub("%s+", "")
        if text ~= "" then
            return true
        end
    end

    return false
end

-- ================= PIZZA AIMBOT =================
local function getWeakestSurvivor()
    if not survivorsFolder then return nil end
    local myChar = playerCharacter
    local myHum = getHumanoid()
    local myRoot = getHRP()
    if not myHum or not myRoot or not myHum.MaxHealth or myHum.MaxHealth <= 0 then return nil end

    local myHpPercent = myHum.Health / myHum.MaxHealth
    local list = {}

    for _, mdl in ipairs(survivorsFolder:GetChildren()) do
        if mdl:IsA("Model") and mdl ~= myChar then
            local hum = mdl:FindFirstChildOfClass("Humanoid")
            local hrp = mdl:FindFirstChild("HumanoidRootPart")
            if hum and hrp and hum.Health > 0 and hum.MaxHealth > 0 then
                local dist = (hrp.Position - myRoot.Position).Magnitude
                if dist <= S.AimDistance then
                    table.insert(list, { model = mdl, hp = hum.Health / hum.MaxHealth })
                end
            end
        end
    end

    if #list == 0 then return nil end
    table.sort(list, function(a, b) return a.hp < b.hp end)

    if myHpPercent <= list[1].hp and #list > 1 then
        return list[2].model
    else
        return list[1].model
    end
end

-- ================= AUTO EAT PIZZA =================
local function findMap()
    local mapContainer = Workspace:FindFirstChild("Map")
    if mapContainer then
        local ingame = mapContainer:FindFirstChild("Ingame")
        if ingame then
            local map = ingame:FindFirstChild("Map")
            if map then return map end
        end
    end
    return Workspace:FindFirstChild("Map")
end

-- ================= FIX FULL: NHẶT PIZZA TRỰC TIẾP =================

local function getPizzaCF()
    -- Dùng trực tiếp IngameFolder đã khai báo ở đầu script
    -- IngameFolder = Workspace.Map.Ingame
    local pizza = IngameFolder:FindFirstChild("Pizza", true)
    
    if not pizza then return nil end

    -- Xử lý lấy CFrame chuẩn xác cho mọi trường hợp (Part, Model, hoặc CFrameValue)
    if pizza:IsA("BasePart") or pizza:IsA("MeshPart") or pizza:IsA("UnionOperation") then
        return pizza.CFrame
    elseif pizza:IsA("Model") then
        -- Ưu tiên PrimaryPart, nếu chưa set thì lấy Part đầu tiên bên trong
        local pp = pizza.PrimaryPart or pizza:FindFirstChildWhichIsA("BasePart", true)
        return pp and pp.CFrame or nil
    elseif pizza:IsA("CFrameValue") then
        return pizza.Value
    end
    
    return nil
end

local function tryEatPizza()
    local hrp = getHRP()
    local hum = getHumanoid()
    
    -- Kiểm tra điều kiện HP
    if not hrp or not hum then return end
    if hum.Health > S.EatPizzaHPThreshold then return end

    local pizzaCF = getPizzaCF()
    if not pizzaCF then return end -- Nếu không thấy Pizza thì dừng

    -- Lưu vị trí cũ để sau khi ăn xong quay về
    local oldCF = hrp.CFrame
    
    -- Teleport tới Pizza (nâng cao 1 đơn vị để tránh kẹt sàn)
    hrp.CFrame = pizzaCF * CFrame.new(0, 1, 0)

    -- Quay trở lại vị trí cũ sau 0.2 giây
    task.delay(0.2, function()
        pcall(function()
            if hrp then 
                hrp.CFrame = oldCF 
            end
        end)
    end)
end

-- ================= MAIN LOOPS =================
RunService.RenderStepped:Connect(function()
    if not S.PizzaAimbotEnabled then
        restoreAutoRotate()
        currentTarget, isLockedOn, aimCompleted = nil, false, false
        return
    end

    if not isEliot() then
        restoreAutoRotate()
        currentTarget, isLockedOn, aimCompleted = nil, false, false
        return
    end

    local hum = getHumanoid()
    local root = getHRP()
    if not hum or not root then return end

    local cooldownActive = isPizzaOnCooldown()

    -- Khi cooldown kết thúc, reset mọi thứ
    if not cooldownActive then
        if isLockedOn or aimCompleted then
            currentTarget, isLockedOn, aimCompleted = nil, false, false
            restoreAutoRotate()
        end
        return
    end

    -- Bắt đầu lock khi cooldown vừa xuất hiện và chưa aim xong
    if cooldownActive and not isLockedOn and not aimCompleted then
        currentTarget = getWeakestSurvivor()
        if currentTarget then
            isLockedOn = true
            aimStartTime = tick()
        end
    end

    -- Thực hiện aim nếu đang lock
    if isLockedOn and currentTarget then
        local elapsed = tick() - aimStartTime
        if elapsed > S.AimDuration then
            -- Hết thời gian aim, đánh dấu đã aim xong
            isLockedOn = false
            aimCompleted = true
            restoreAutoRotate()
            return
        end

        local tRoot = currentTarget:FindFirstChild("HumanoidRootPart")
        if not tRoot then
            currentTarget, isLockedOn = nil, false
            restoreAutoRotate()
            return
        end

        local tHum = currentTarget:FindFirstChildOfClass("Humanoid")
        if not tHum or tHum.Health <= 0 then
            currentTarget, isLockedOn = nil, false
            restoreAutoRotate()
            return
        end

        if not autoRotateDisabledByScript then
            hum.AutoRotate = false
            autoRotateDisabledByScript = true
        end

        local offsetPos = tRoot.Position + root.CFrame.RightVector * S.AimOffset
        local targetPos = Vector3.new(offsetPos.X, root.Position.Y, offsetPos.Z)
        root.CFrame = CFrame.lookAt(root.Position, targetPos)
    end
end)

-- Auto Eat Pizza loop
task.spawn(function()
    while task.wait(0.9) do
        if S.AutoEatPizzaEnabled and isEliot() then
            tryEatPizza()
        end
    end
end)

-- Khi chết/reset
Players.LocalPlayer.CharacterAdded:Connect(function()
    autoRotateDisabledByScript = false
    currentTarget, isLockedOn, aimCompleted = nil, false, false
end)

-- ================= API CHO UI =================
getgenv().EliotAPI = {
    SetPizzaAimbot = function(v) S.PizzaAimbotEnabled = v end,
    SetAimDistance = function(v) S.AimDistance = tonumber(v) or 100 end,
    SetAimOffset = function(v) S.AimOffset = tonumber(v) or 2 end,
    SetAutoEatPizza = function(v) S.AutoEatPizzaEnabled = v end,
    SetHPThreshold = function(v) S.EatPizzaHPThreshold = tonumber(v) or 30 end,
    SetAimDuration = function(v) S.AimDuration = tonumber(v) or 0.8 end,
}

-- Camlock Bypass Pro

if not getgenv().KillerCamlockSettings then
    getgenv().KillerCamlockSettings = {
        Enabled = false,
        Target = nil,
        ZoomDistance = 10,
        HeightOffset = 1.5,
        AimPart = "Head",               
        QuickGuiVisible = false,
        OriginalCameraSubject = nil,   
        CustomCameraCFrame = nil,      
        Connections = {},
        PinchTouches = {},
        LastPinchDistance = nil
    }
end

local S = getgenv().KillerCamlockSettings
local CAMLOCK_RENDER_KEY = "KillerCamlock_SyncRender_MaxPriority"

-- Giao diện nút bấm nhanh
local QuickFrame, QuickButton

-- ================= HÀM TWEEN (ANIMATION) =================
local function tweenObj(obj, properties, duration)
    if not obj then return end
    local tweenInfo = TweenInfo.new(duration or 0.2, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)
    local tween = TweenService:Create(obj, tweenInfo, properties)
    tween:Play()
    return tween
end

-- ================= HÀM LẤY BỘ PHẬN AIM =================
local function getAimPartPosition(model, aimPartName)
    if not model then return nil end
    local partMap = {
        ["Head"] = "Head",
        ["Torso"] = "UpperTorso",
        ["Left Arm"] = "LeftHand",
        ["Right Arm"] = "RightHand",
        ["Left Leg"] = "LeftFoot",
        ["Right Leg"] = "RightFoot"
    }
    local partName = partMap[aimPartName] or "Head"
    local part = model:FindFirstChild(partName)
    if part and part:IsA("BasePart") then return part.Position end
    
    part = model:FindFirstChild(aimPartName)
    if part and part:IsA("BasePart") then return part.Position end
    
    local hrp = model:FindFirstChild("HumanoidRootPart")
    return hrp and hrp.Position
end

-- ================= HÀM HỖ TRỢ =================
local function isKiller()
    if not playerCharacter or not killersFolder then return false end
    return playerCharacter:IsDescendantOf(killersFolder)
end

local function getNearestSurvivor()
    if not survivorsFolder then return nil end
    local myRoot = playerCharacter and playerCharacter:FindFirstChild("HumanoidRootPart")
    if not myRoot then return nil end

    local nearest, minDist = nil, math.huge
    for _, s in ipairs(survivorsFolder:GetChildren()) do
        if s:IsA("Model") then
            local h = s:FindFirstChild("Humanoid")
            local r = s:FindFirstChild("HumanoidRootPart")
            if h and r and h.Health > 0 then
                local d = (r.Position - myRoot.Position).Magnitude
                if d < minDist then minDist = d; nearest = r end
            end
        end
    end
    return nearest
end

-- ================= CẬP NHẬT GIAO DIỆN NÚT NHANH =================
local function updateQuickGuiAppearance()
    if not QuickButton or not QuickFrame then return end
    local stroke = QuickFrame:FindFirstChild("UIStroke")
    
    if S.Enabled then
        QuickButton.Text = "CAMLOCK: ON"
        tweenObj(QuickButton, {TextColor3 = Color3.fromRGB(255, 75, 75)}, 0.3)
        if stroke then tweenObj(stroke, {Color = Color3.fromRGB(255, 75, 75)}, 0.3) end
    else
        QuickButton.Text = "CAMLOCK: OFF"
        tweenObj(QuickButton, {TextColor3 = Color3.fromRGB(200, 200, 200)}, 0.3)
        if stroke then tweenObj(stroke, {Color = Color3.fromRGB(60, 60, 60)}, 0.3) end
    end
end

-- ================= TẠO GUI BẤM NHANH =================
local function createQuickGui()
    if CoreGui:FindFirstChild("HutaoQuickCamlock") then 
        CoreGui.HutaoQuickCamlock:Destroy() 
    end

    local sgui = Instance.new("ScreenGui")
    sgui.Name = "HutaoQuickCamlock"
    sgui.ResetOnSpawn = false
    sgui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    sgui.Enabled = S.QuickGuiVisible
    sgui.Parent = CoreGui

    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(0, 130, 0, 45)
    frame.Position = UDim2.new(0.85, 0, 0.5, 0) 
    frame.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
    frame.BorderSizePixel = 0
    frame.Active = true
    frame.AnchorPoint = Vector2.new(0.5, 0.5) -- Thêm AnchorPoint để bóp méo từ tâm
    frame.Parent = sgui
    QuickFrame = frame

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 12) -- ĐÃ FIX: Bo góc mượt mà
    corner.Parent = frame

    local stroke = Instance.new("UIStroke")
    stroke.Thickness = 2
    stroke.Color = Color3.fromRGB(60, 60, 60)
    stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    stroke.Parent = frame

    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, 0, 1, 0)
    btn.BackgroundTransparency = 1
    btn.Text = "CAMLOCK: OFF"
    btn.Font = Enum.Font.GothamBold
    btn.TextSize = 14
    btn.TextColor3 = Color3.fromRGB(200, 200, 200)
    btn.Parent = frame
    QuickButton = btn

    -- ĐÃ FIX: Logic kéo thả an toàn, chống giật teleport khi chạm nhiều ngón
    local dragInput = nil 
    local dragStart = nil
    local startPos = nil
    local totalDragDist = 0

    btn.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            -- Animation bóp méo khi đè nút
            tweenObj(frame, {Size = UDim2.new(0, 120, 0, 40)}, 0.1)
            
            dragInput = input -- Khóa chặt vào ngón tay này
            dragStart = input.Position
            startPos = frame.Position
            totalDragDist = 0
        end
    end)

    UserInputService.InputChanged:Connect(function(input)
        -- Chỉ di chuyển khi đúng ngón tay đã chạm ban đầu
        if dragInput and input == dragInput then
            local delta = input.Position - dragStart
            totalDragDist = totalDragDist + delta.Magnitude
            frame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end)

    btn.InputEnded:Connect(function(input)
        if input == dragInput then
            -- Trả lại kích thước ban đầu
            tweenObj(frame, {Size = UDim2.new(0, 130, 0, 45)}, 0.15)
            dragInput = nil 
            
            if totalDragDist < 8 then 
                local targetState = not S.Enabled
                getgenv().KillerCamlockAPI.Toggle(targetState)
            end
        end
    end)

    updateQuickGuiAppearance()
end

-- ================= TẮT CAMLOCK =================
local function disable()
    RunService:UnbindFromRenderStep(CAMLOCK_RENDER_KEY)

    for _, conn in ipairs(S.Connections) do
        if conn and conn.Connected then conn:Disconnect() end
    end
    S.Connections = {}
    S.PinchTouches = {}
    S.LastPinchDistance = nil

    if Camera then
        Camera.CameraType = Enum.CameraType.Custom
        if S.OriginalCameraSubject then
            Camera.CameraSubject = S.OriginalCameraSubject
            S.OriginalCameraSubject = nil
        end
    end

    S.Target = nil
    S.CustomCameraCFrame = nil 
    updateQuickGuiAppearance()
end

-- ================= BẬT CAMLOCK =================
local function enable()
    if S.OriginalCameraSubject then return end 
    if not Camera then return end

    S.OriginalCameraSubject = Camera.CameraSubject
    S.CustomCameraCFrame = Camera.CFrame 

    RunService:BindToRenderStep(CAMLOCK_RENDER_KEY, Enum.RenderPriority.Camera.Value + 50, function()
        if not S.Enabled then
            disable()
            return
        end

        if not isKiller() then
            if Camera.CameraType == Enum.CameraType.Scriptable then
                Camera.CameraType = Enum.CameraType.Custom
            end
            return
        end

        if not (S.Target and S.Target.Parent and S.Target.Parent:FindFirstChild("Humanoid") and S.Target.Parent.Humanoid.Health > 0) then
            local newHRP = getNearestSurvivor()
            if newHRP then
                S.Target = newHRP
            else
                if Camera.CameraType == Enum.CameraType.Scriptable then
                    Camera.CameraType = Enum.CameraType.Custom
                end
                return
            end
        end

        local myRoot = playerCharacter and playerCharacter:FindFirstChild("HumanoidRootPart")
        if not myRoot then return end

        local aimPos = getAimPartPosition(S.Target.Parent, S.AimPart) or S.Target.Position
        local anchorPos = myRoot.Position + Vector3.new(0, S.HeightOffset or 1.5, 0)
        
        local targetDir = (aimPos - anchorPos).Unit
        local currentDir = S.CustomCameraCFrame and S.CustomCameraCFrame.LookVector or Camera.CFrame.LookVector
        local smoothDir = currentDir:Lerp(targetDir, 0.2).Unit 
        
        local camPos = anchorPos - smoothDir * S.ZoomDistance
        S.CustomCameraCFrame = CFrame.lookAt(camPos, camPos + smoothDir)

        Camera.CameraType = Enum.CameraType.Scriptable
        Camera.CFrame = S.CustomCameraCFrame
        Camera.Focus = CFrame.new(aimPos) 
    end)

    local mouseConn = UserInputService.InputChanged:Connect(function(input)
        if not S.Enabled then return end
        if input.UserInputType == Enum.UserInputType.MouseWheel then
            S.ZoomDistance = math.clamp(S.ZoomDistance - input.Position.Z * 2.0, 2, 30)
        end
    end)
    table.insert(S.Connections, mouseConn)

    S.PinchTouches = {}
    S.LastPinchDistance = nil

    local touchStartConn = UserInputService.TouchStarted:Connect(function(touch, gameProcessed)
        if not S.Enabled or gameProcessed then return end
        table.insert(S.PinchTouches, touch)
        if #S.PinchTouches == 2 then
            local pos1 = Vector2.new(S.PinchTouches[1].Position.X, S.PinchTouches[1].Position.Y)
            local pos2 = Vector2.new(S.PinchTouches[2].Position.X, S.PinchTouches[2].Position.Y)
            S.LastPinchDistance = (pos1 - pos2).Magnitude
        end
    end)
    table.insert(S.Connections, touchStartConn)

    local touchMoveConn = UserInputService.TouchMoved:Connect(function(touch, gameProcessed)
        if not S.Enabled or gameProcessed then return end
        for i, t in ipairs(S.PinchTouches) do
            if t == touch then S.PinchTouches[i] = touch break end
        end
        if #S.PinchTouches == 2 and S.LastPinchDistance then
            local pos1 = Vector2.new(S.PinchTouches[1].Position.X, S.PinchTouches[1].Position.Y)
            local pos2 = Vector2.new(S.PinchTouches[2].Position.X, S.PinchTouches[2].Position.Y)
            local newDist = (pos1 - pos2).Magnitude
            local delta = newDist - S.LastPinchDistance
            S.ZoomDistance = math.clamp(S.ZoomDistance - delta / 20, 2, 30)
            S.LastPinchDistance = newDist
        end
    end)
    table.insert(S.Connections, touchMoveConn)

    local touchEndConn = UserInputService.TouchEnded:Connect(function(touch)
        if not S.Enabled then return end
        for i, t in ipairs(S.PinchTouches) do
            if t == touch then table.remove(S.PinchTouches, i) break end
        end
        if #S.PinchTouches < 2 then S.LastPinchDistance = nil end
    end)
    table.insert(S.Connections, touchEndConn)
    
    updateQuickGuiAppearance()
end

createQuickGui()

-- ================= GLOBAL API ENGINE =================
getgenv().KillerCamlockAPI = {
    Toggle = function(state)
        S.Enabled = state
        updateQuickGuiAppearance()
        if state then enable() else disable() end
    end,
    SetQuickGuiVisible = function(state)
        S.QuickGuiVisible = state
        local sgui = CoreGui:FindFirstChild("HutaoQuickCamlock")
        if sgui and QuickFrame then
            if state then
                sgui.Enabled = true
                -- Animation trượt từ ngoài vào trong
                QuickFrame.Position = UDim2.new(0.95, 50, QuickFrame.Position.Y.Scale, QuickFrame.Position.Y.Offset)
                QuickFrame.BackgroundTransparency = 1
                QuickButton.TextTransparency = 1
                if QuickFrame:FindFirstChild("UIStroke") then QuickFrame.UIStroke.Transparency = 1 end
                
                tweenObj(QuickFrame, {Position = UDim2.new(0.85, 0, QuickFrame.Position.Y.Scale, QuickFrame.Position.Y.Offset), BackgroundTransparency = 0}, 0.4)
                tweenObj(QuickButton, {TextTransparency = 0}, 0.4)
                if QuickFrame:FindFirstChild("UIStroke") then tweenObj(QuickFrame.UIStroke, {Transparency = 0}, 0.4) end
            else
                -- Animation trượt ngược ra ngoài rồi mới tắt
                tweenObj(QuickFrame, {Position = UDim2.new(0.95, 50, QuickFrame.Position.Y.Scale, QuickFrame.Position.Y.Offset), BackgroundTransparency = 1}, 0.3)
                tweenObj(QuickButton, {TextTransparency = 1}, 0.3)
                if QuickFrame:FindFirstChild("UIStroke") then tweenObj(QuickFrame.UIStroke, {Transparency = 1}, 0.3) end
                
                task.delay(0.3, function() sgui.Enabled = false end)
            end
        end
    end,
    SetHeightOffset = function(val)
        S.HeightOffset = tonumber(val) or 1.5
    end,
    SwitchTarget = function()
        if not S.Enabled then return end
        local new = getNearestSurvivor()
        if new then S.Target = new end
    end,
    SetAimPart = function(part)
        S.AimPart = part
    end
}

Players.LocalPlayer.CharacterAdded:Connect(function()
    if S.Enabled then
        disable()
        S.Enabled = false
        updateQuickGuiAppearance()
    end
end)

-- 007n7

local INVIS_ANIM_ID = "rbxassetid://115509603980568"
local CLONE_DURATION = 5

if not getgenv().InvisSettings then
    getgenv().InvisSettings = {
        InstantEnabled = false,
        CloneEnabled = false,
        AnimTrack = nil,
        IsPlaying = false,
        CloneActive = false,
        WasOnCooldown = false,
        IsValidRole = false
    }
end

local Settings = getgenv().InvisSettings

local function getAnimator()
    if not playerCharacter then return nil end
    local hum = playerCharacter:FindFirstChildOfClass("Humanoid")
    if not hum then return nil end
    return hum:FindFirstChildOfClass("Animator")
end

local function getCloneButton()
    local playerGui = localPlayer:FindFirstChild("PlayerGui")
    if not playerGui then return nil end
    local mainUI = playerGui:FindFirstChild("MainUI")
    if not mainUI then return nil end
    local abilityContainer = mainUI:FindFirstChild("AbilityContainer")
    if not abilityContainer then return nil end
    return abilityContainer:FindFirstChild("Clone")
end

local function getCooldownText()
    local button = getCloneButton()
    if not button then return nil end
    if button:IsA("TextButton") then return button.Text end
    local label = button:FindFirstChildWhichIsA("TextLabel", true)
    if label then return label.Text end
    return nil
end

local function isCooldownActive()
    local text = getCooldownText()
    return text and text ~= "" and tonumber(text) ~= nil
end

local function stopAnimation()
    if not Settings.AnimTrack then return end
    Settings.AnimTrack:Stop(0.1)
    Settings.AnimTrack = nil
    Settings.IsPlaying = false
end

local function playAnimation()
    if Settings.IsPlaying then return end
    local animator = getAnimator()
    if not animator then return end
    local anim = Instance.new("Animation")
    anim.AnimationId = INVIS_ANIM_ID
    local track = animator:LoadAnimation(anim)
    track.Priority = Enum.AnimationPriority.Action4
    track:Play(0.1)
    track:AdjustSpeed(0)
    Settings.AnimTrack = track
    Settings.IsPlaying = true
end

local function updateAnimation()
    local shouldPlay = (Settings.InstantEnabled or Settings.CloneActive) and Settings.IsValidRole
    if shouldPlay then
        playAnimation()
    else
        stopAnimation()
    end
end

local function deactivateClone()
    Settings.CloneActive = false
    updateAnimation()
end

local function activateClone()
    if Settings.CloneActive then return end
    Settings.CloneActive = true
    updateAnimation()
    task.delay(CLONE_DURATION, deactivateClone)
end

local function updateCloneDetection()
    local onCooldown = isCooldownActive()
    if onCooldown and not Settings.WasOnCooldown then
        activateClone()
    end
    Settings.WasOnCooldown = onCooldown
end

local function checkValidRole()
    if not playerCharacter or not playerCharacter.Parent then return false end
    return playerCharacter:IsDescendantOf(survivorsFolder) or playerCharacter:IsDescendantOf(killersFolder)
end

local function handleRoleTransition(currentlyValid)
    if currentlyValid and not Settings.IsValidRole then
        Settings.IsValidRole = true
        updateAnimation()
    elseif not currentlyValid and Settings.IsValidRole then
        Settings.IsValidRole = false
        Settings.CloneActive = false
        Settings.WasOnCooldown = false
        stopAnimation()
    end
end

local function ProcessInvisLoop()
    local currentlyValid = checkValidRole()
    handleRoleTransition(currentlyValid)
    if currentlyValid and Settings.CloneEnabled then
        updateCloneDetection()
    end
end

local InvisLastTick = tick()
RunService.Heartbeat:Connect(function()
    if tick() - InvisLastTick >= 0.2 then
        InvisLastTick = tick()
        ProcessInvisLoop()
    end
end)

-- API cho UI
getgenv().InvisAPI = {
    SetInstant = function(val)
        Settings.InstantEnabled = val
        updateAnimation()
    end,
    SetClone = function(val)
        Settings.CloneEnabled = val
        if not val then
            Settings.CloneActive = false
            Settings.WasOnCooldown = false
        end
        updateAnimation()
    end
}

-- Hitbox Angel

repeat task.wait() until game:IsLoaded()

-- Khởi tạo getgenv nếu chưa có
if not getgenv().HitboxDevilSettings then
    getgenv().HitboxDevilSettings = {
        Enabled = false,
        Distance = 120,
        AttackAnimations = {
            "rbxassetid://131430497821198",
            "rbxassetid://83829782357897",
            "rbxassetid://126830014841198",
            "rbxassetid://126355327951215",
            "rbxassetid://121086746534252",
            "rbxassetid://105458270463374",
            "rbxassetid://18885919947",
            "rbxassetid://18885909645",
            "rbxassetid://87259391926321",
            "rbxassetid://106014898528300",
            "rbxassetid://87259391926321",
            "rbxassetid://86545133269813",
            "rbxassetid://89448354637442",
            "rbxassetid://90499469533503",
            "rbxassetid://116618003477002",
            "rbxassetid://106086955212611",
            "rbxassetid://107640065977686",
            "rbxassetid://77124578197357",
            "rbxassetid://101771617803133",
            "rbxassetid://134958187822107",
            "rbxassetid://111313169447787",
            "rbxassetid://71685573690338",
            "rbxassetid://129843313690921",
            "rbxassetid://97623143664485",
            "rbxassetid://129843313690921",
            "rbxassetid://136007065400978",
            "rbxassetid://136007065400978",
            "rbxassetid://86096387000557",
            "rbxassetid://108807732150251",
            "rbxassetid://138040001965654",
            "rbxassetid://73502073176819",
            "rbxassetid://129843313690921",
            "rbxassetid://97623143664485",
            "rbxassetid://129843313690921",
            "rbxassetid://97623143664485",
            "rbxassetid://86709774283672",
            "rbxassetid://106014898528300",
            "rbxassetid://87259391926321",
            "rbxassetid://140703210927645",
            "rbxassetid://96173857867228",
            "rbxassetid://121255898612475",
            "rbxassetid://98031287364865",
            "rbxassetid://119462383658044",
            "rbxassetid://77448521277146",
            "rbxassetid://77448521277146",
            "rbxassetid://103741352379819",
            "rbxassetid://119462383658044",
            "rbxassetid://131696603025265",
            "rbxassetid://122503338277352",
            "rbxassetid://97648548303678",
            "rbxassetid://94162446513587",
            "rbxassetid://93069721274110",
            "rbxassetid://97433060861952",
            "rbxassetid://100592913030351",
            "rbxassetid://121293883585738",
            "rbxassetid://100592913030351",
            "rbxassetid://121293883585738",
            "rbxassetid://100592913030351",
            "rbxassetid://121293883585738",
            "rbxassetid://70447634862911",
            "rbxassetid://92173139187970",
            "rbxassetid://106847695270773",
            "rbxassetid://125403313786645",
            "rbxassetid://81639435858902",
            "rbxassetid://137314737492715",
            "rbxassetid://120112897026015",
            "rbxassetid://82113744478546",
            "rbxassetid://118298475669935",
            "rbxassetid://82113744478546",
            "rbxassetid://118298475669935",
            "rbxassetid://126681776859538",
            "rbxassetid://129976080405072",
            "rbxassetid://109667959938617",
            "rbxassetid://74707328554358",
            "rbxassetid://133336594357903",
            "rbxassetid://86204001129974",
            "rbxassetid://82113744478546",
            "rbxassetid://118298475669935",
            "rbxassetid://124243639579224",
            "rbxassetid://70371667919898",
            "rbxassetid://131543461321709",
            "rbxassetid://136323728355613",
            "rbxassetid://109230267448394",
            "rbxassetid://139835501033932",
            "rbxassetid://106538427162796",
            "rbxassetid://109667959938617",
            "rbxassetid://126681776859538",
            "rbxassetid://129976080405072",
            "rbxassetid://110400453990786",
            "rbxassetid://83685305553364",
            "rbxassetid://126171487400618",
            "rbxassetid://122709416391891",
            "rbxassetid://87989533095285",
            "rbxassetid://119326397274934",
            "rbxassetid://140365014326125",
            "rbxassetid://139309647473555",
            "rbxassetid://133363345661032",
            "rbxassetid://128414736976503",
            "rbxassetid://121808371053483",
            "rbxassetid://77375846492436",
            "rbxassetid://100358581940485",
            "rbxassetid://91758760621955",
            "rbxassetid://94634594529334",
            "rbxassetid://101101433684051",
            "rbxassetid://90620531468240",
            "rbxassetid://94958041603347",
            "rbxassetid://131642454238375",
            "rbxassetid://110702884830060",
            "rbxassetid://76312020299624",
            "rbxassetid://126654961540956",
            "rbxassetid://139613699193400",
            "rbxassetid://91509234639766",
            "rbxassetid://105458270463374",
            "rbxassetid://109777684604906",
            "rbxassetid://84069821282466",
            "rbxassetid://135283134632311",
            "rbxassetid://127846074966393",
        }
    }
end

local S = getgenv().HitboxDevilSettings
local RNG = Random.new()

-- ================= HÀM HỖ TRỢ =================
local function getSafePing()
    local ok, ping = pcall(Players.LocalPlayer.GetNetworkPing, Players.LocalPlayer)
    if ok and typeof(ping) == "number" and ping > 0 then
        return math.clamp(ping, 0.03, 0.12)
    end
    return 0.05
end

local function scanFolder(folder, bestDist)
    if not folder or not playerCharacter then return nil, bestDist end
    local myRoot = playerCharacter:FindFirstChild("HumanoidRootPart")
    if not myRoot then return nil, bestDist end

    local target
    for _, model in ipairs(folder:GetChildren()) do
        if model:IsA("Model") and model ~= playerCharacter then
            local hrp2 = model:FindFirstChild("HumanoidRootPart")
            local hum2 = model:FindFirstChild("Humanoid")
            if hrp2 and hum2 and hum2.Health > 0 then
                local dist = (hrp2.Position - myRoot.Position).Magnitude
                if dist < bestDist then
                    bestDist = dist
                    target = model
                end
            end
        end
    end
    return target, bestDist
end

-- ================= LOGIC CHÍNH =================
local lastBlink = 0
local BLINK_COOLDOWN = 0.05

local function ForsakenReachLogic()
    if not S.Enabled then return end
    
    local char = playerCharacter
    if not char then return end
    local hum = char:FindFirstChildOfClass("Humanoid")
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hum or not hrp then return end
    
    if tick() - lastBlink < BLINK_COOLDOWN then return end

    -- Kiểm tra animation tấn công
    local attacking = false
    for _, track in ipairs(hum:GetPlayingAnimationTracks()) do
        local anim = track.Animation
        if anim and table.find(S.AttackAnimations, anim.AnimationId) and track.Length > 0 and (track.TimePosition / track.Length < 0.75) then
            attacking = true
            break
        end
    end
    if not attacking then return end

    -- Xác định folder đối thủ
    local oppositeFolder
    if char:IsDescendantOf(killersFolder) then
        oppositeFolder = survivorsFolder
    elseif char:IsDescendantOf(survivorsFolder) then
        oppositeFolder = killersFolder
    end

    local target, bestDist = nil, S.Distance
    if oppositeFolder then
        target, bestDist = scanFolder(oppositeFolder, bestDist)
    end
    if not target then
        local playersFolder = workspace:FindFirstChild("Players")
        if playersFolder then
            target, bestDist = scanFolder(playersFolder, bestDist)
        end
    end
    if not target then return end

    local targetHRP = target:FindFirstChild("HumanoidRootPart")
    if not targetHRP then return end

    lastBlink = tick()

    local oldCF = hrp.CFrame
    local oldVel = hrp.Velocity
    local cam = workspace.CurrentCamera
    local camCF = cam and cam.CFrame
    local oldCamType = cam and cam.CameraType

    local ping = getSafePing()
    local targetPos = targetHRP.Position + (targetHRP.Velocity * ping)
    
    -- ĐÃ FIX 1: Dùng Y của targetPos (Y của mục tiêu) thay vì oldCF.Position.Y
    local blinkPos = Vector3.new(
        targetPos.X + RNG:NextNumber(-1.1, 1.1),
        targetPos.Y, 
        targetPos.Z + RNG:NextNumber(-1.1, 1.1)
    )

    if cam then
        cam.CameraType = Enum.CameraType.Scriptable
        cam.CFrame = camCF
    end

    hrp.Velocity = Vector3.zero
    
    -- ĐÃ FIX 2: Giữ nguyên góc xoay (Rotation) của nhân vật, chỉ update mỗi Position
    hrp.CFrame = CFrame.new(blinkPos) * (oldCF - oldCF.Position)

    RunService.RenderStepped:Wait()

    hrp.CFrame = oldCF
    hrp.Velocity = oldVel

    if cam then
        cam.CFrame = camCF
        cam.CameraType = oldCamType
    end
end

task.spawn(function()
    while true do
        task.wait()
        pcall(ForsakenReachLogic)
    end
end)

-- API cho UI
getgenv().HitboxDevilAPI = {
    SetEnabled = function(val) S.Enabled = val end,
    SetDistance = function(val) S.Distance = tonumber(val) or 120 end
}

-- aura farming

local orbitingSwords = {}
local isDying = false
local isAttacking = false
local swordSystemActive = false
local connectionRender = nil -- RenderStepped connection

-- ==================== SOUND ID ====================
local SWORD_SOUND_ID = "rbxassetid://12222200"
local TRIGGER_SOUND_ID = "rbxassetid://12222225"

-- ==================== CẤU HÌNH ====================
local TOTAL_SWORDS = 7
local SPAWN_DELAY = 0.3
local FALL_HEIGHT = 50
local FALL_DURATION = 1.0
local radius = 4.5
local speed = 1.5
local heightOffset = 0
local ATTACK_RANGE = 300

local RAINBOW_COLORS = {
    Color3.fromRGB(255, 0, 0),
    Color3.fromRGB(255, 127, 0),
    Color3.fromRGB(255, 255, 0),
    Color3.fromRGB(0, 255, 0),
    Color3.fromRGB(0, 0, 255),
    Color3.fromRGB(75, 0, 130),
    Color3.fromRGB(148, 0, 211)
}

-- ==================== TÌM KIẾM TEMPLATE ====================
local swordTemplate = survivorsFolder:WaitForChild("Shedletsky"):WaitForChild("Sword")

if not swordTemplate then
    warn("Không tìm thấy kiếm gốc!")
    return
end

-- ==================== HÀM CLONE KIẾM ====================
local function cloneVisibleSword()
    local clone = swordTemplate:Clone()
    clone.Name = "OrbitingSword"

    local parts = {}
    if clone:IsA("BasePart") then table.insert(parts, clone) end
    for _, desc in pairs(clone:GetDescendants()) do
        if desc:IsA("BasePart") then table.insert(parts, desc) end
    end

    if #parts == 0 then
        clone:Destroy()
        return nil, nil
    end

    for _, part in ipairs(parts) do
        part.Anchored = true
        part.CanCollide = false
        part.Massless = true
        part.Transparency = 1
    end

    for _, desc in pairs(clone:GetDescendants()) do
        if desc:IsA("JointInstance") or desc:IsA("WeldConstraint") or desc:IsA("LuaSourceContainer") then
            desc:Destroy()
        end
    end

    if clone:IsA("Model") and not clone.PrimaryPart then
        clone.PrimaryPart = parts[1]
    end

    clone.Parent = Workspace
    return clone, parts
end

-- ==================== HÀM SPAWN KIẾM ====================
local function spawnSwordSequentially(index)
    local sword, parts = cloneVisibleSword()
    if not sword then return end

    local glow = Instance.new("Highlight")
    glow.Name = "RainbowGlow"
    glow.Adornee = sword
    glow.FillTransparency = 1
    glow.OutlineTransparency = 0
    glow.OutlineColor = RAINBOW_COLORS[index]
    glow.Parent = sword

    local angle = (index - 1) * (math.pi * 2 / TOTAL_SWORDS)

    local flyProgress = Instance.new("NumberValue")
    flyProgress.Name = "FlyProgress"
    flyProgress.Value = 0
    flyProgress.Parent = sword

    local swordData = {
        Object = sword,
        Parts = parts,
        Angle = angle,
        State = "Falling",
        CurrentOffset = FALL_HEIGHT,
        FlyValue = flyProgress,
        TargetCharacter = nil
    }
    table.insert(orbitingSwords, swordData)

    for _, part in ipairs(parts) do part.Transparency = 0 end

    if playerCharacter and playerCharacter:FindFirstChild("HumanoidRootPart") then
        local sound = Instance.new("Sound")
        sound.SoundId = SWORD_SOUND_ID
        sound.Volume = 0.6
        sound.Parent = playerCharacter.HumanoidRootPart
        sound:Play()
        task.delay(2, function() sound:Destroy() end)
    end

    local fallValue = Instance.new("NumberValue")
    fallValue.Value = FALL_HEIGHT
    local tweenInfo = TweenInfo.new(FALL_DURATION, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out)
    local tween = TweenService:Create(fallValue, tweenInfo, {Value = 0})
    tween:Play()

    fallValue.Changed:Connect(function(newValue)
        swordData.CurrentOffset = newValue
    end)

    tween.Completed:Connect(function()
        if swordData.State ~= "Ascending" then
            swordData.State = "Orbiting"
        end
        fallValue:Destroy()
    end)
end

-- ==================== TÌM KILLER GẦN NHẤT ====================
local function getNearestKillerCharacter()
    if not playerCharacter or not playerCharacter:FindFirstChild("HumanoidRootPart") then return nil end
    local playerRoot = playerCharacter.HumanoidRootPart

    local nearestChar = nil
    local minDistance = ATTACK_RANGE

    for _, kPlayer in ipairs(killersFolder:GetChildren()) do
        if kPlayer:IsA("Player") or kPlayer.ClassName == "ObjectValue" or kPlayer:IsA("Model") then
            local char = kPlayer:IsA("Player") and kPlayer.Character or kPlayer
            if char and char:IsA("Model") then
                local humanoid = char:FindFirstChild("Humanoid")
                local root = char:FindFirstChild("HumanoidRootPart")
                if humanoid and humanoid.Health > 0 and root then
                    local dist = (root.Position - playerRoot.Position).Magnitude
                    if dist < minDistance then
                        minDistance = dist
                        nearestChar = char
                    end
                end
            end
        end
    end
    return nearestChar
end

-- ==================== TẤN CÔNG ====================
local function executeAttack(killerChar)
    isAttacking = true

    for i, data in ipairs(orbitingSwords) do
        if data.State == "Ascending" then continue end
        task.delay((i - 1) * 0.1, function()
            data.TargetCharacter = killerChar
            TweenService:Create(data.FlyValue, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Value = 1}):Play()
        end)
    end

    task.wait(0.5 + 1.0)

    for i, data in ipairs(orbitingSwords) do
        if data.State == "Ascending" then continue end
        task.delay((i - 1) * 0.1, function()
            local tween = TweenService:Create(data.FlyValue, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {Value = 0})
            tween:Play()
            tween.Completed:Connect(function()
                data.TargetCharacter = nil
            end)
        end)
    end

    task.wait(0.5)
    isAttacking = false
end

-- ==================== CHECK SOUND ====================
local function checkSound(sound)
    if not swordSystemActive then return end
    if sound:IsA("Sound") and (sound.SoundId == TRIGGER_SOUND_ID or sound.SoundId:match("%d+$") == TRIGGER_SOUND_ID:match("%d+$")) then
        if not isAttacking and not isDying then
            local targetKiller = getNearestKillerCharacter()
            if targetKiller then
                task.spawn(function()
                    executeAttack(targetKiller)
                end)
            end
        end
    end
end

-- ==================== CLEANUP ====================
local function cleanupAllSwords()
    for _, data in ipairs(orbitingSwords) do
        if data.Object and data.Object.Parent then
            data.Object:Destroy()
        end
    end
    table.clear(orbitingSwords)
end

-- Gán vào getgenv để UI gọi được
getgenv().CleanupSwords = cleanupAllSwords

-- ==================== VÒNG LẶP CHÍNH ====================
local function createRenderLoop()
    if connectionRender then connectionRender:Disconnect() end

    connectionRender = RunService.RenderStepped:Connect(function()
        if not swordSystemActive then return end

        local myCharacter = localPlayer.Character
        if not myCharacter then return end

        local myHumanoid = myCharacter:FindFirstChild("Humanoid")
        local myRoot = myCharacter:FindFirstChild("HumanoidRootPart")
        if not myHumanoid or not myRoot then return end

        -- CHECK CHẾT
        if myHumanoid.Health <= 0 then
            if not isDying then
                isDying = true
                for _, data in ipairs(orbitingSwords) do
                    data.State = "Ascending"
                    local cframeVal = Instance.new("CFrameValue")
                    cframeVal.Value = data.Object:GetPivot()

                    local ascendTween = TweenService:Create(cframeVal,
                        TweenInfo.new(1.5, Enum.EasingStyle.Exponential, Enum.EasingDirection.In),
                        {Value = cframeVal.Value * CFrame.new(0, 100, 0)})

                    cframeVal.Changed:Connect(function(newCFrame)
                        if data.Object and data.Object.Parent then
                            data.Object:PivotTo(newCFrame)
                        end
                    end)
                    ascendTween:Play()
                    task.delay(1.5, function()
                        if data.Object then data.Object:Destroy() end
                        cframeVal:Destroy()
                    end)
                end
            end
            return
        end

        -- CẬP NHẬT VỊ TRÍ KIẾM
        local now = tick()

        for _, data in ipairs(orbitingSwords) do
            if data.State == "Ascending" then continue end

            local orbitAngle = data.Angle + (speed * now)

            local selfX = myRoot.Position.X + math.cos(orbitAngle) * radius
            local selfZ = myRoot.Position.Z + math.sin(orbitAngle) * radius
            local selfY = myRoot.Position.Y + heightOffset + data.CurrentOffset
            local selfPos = Vector3.new(selfX, selfY, selfZ)

            local killerPos = selfPos
            if data.TargetCharacter and data.TargetCharacter:FindFirstChild("HumanoidRootPart") then
                local kRoot = data.TargetCharacter.HumanoidRootPart
                local kX = kRoot.Position.X + math.cos(orbitAngle) * radius
                local kZ = kRoot.Position.Z + math.sin(orbitAngle) * radius
                local kY = kRoot.Position.Y + heightOffset
                killerPos = Vector3.new(kX, kY, kZ)
            end

            local progress = data.FlyValue.Value
            local finalPos = selfPos:Lerp(killerPos, progress)

            local currentCenter = myRoot.Position:Lerp(
                (data.TargetCharacter and data.TargetCharacter:FindFirstChild("HumanoidRootPart") and data.TargetCharacter.HumanoidRootPart.Position or myRoot.Position),
                progress
            )

            local lookAtPos = Vector3.new(
                currentCenter.X + math.cos(orbitAngle + 0.1) * radius,
                finalPos.Y,
                currentCenter.Z + math.sin(orbitAngle + 0.1) * radius
            )

            local finalCFrame = CFrame.lookAt(finalPos, lookAtPos) * CFrame.Angles(math.rad(90), 0, 0)
            data.Object:PivotTo(finalCFrame)
        end
    end)
end

-- ==================== KHỞI ĐỘNG / DỪNG HỆ THỐNG ====================
local function startSwordSystem()
    if swordSystemActive then return end
    swordSystemActive = true
    isDying = false
    isAttacking = false

    -- Spawn kiếm
    for i = 1, TOTAL_SWORDS do
        task.delay((i - 1) * SPAWN_DELAY, function()
            if swordSystemActive then
                spawnSwordSequentially(i)
            end
        end)
    end

    -- Lắng nghe sound
    Workspace.DescendantAdded:Connect(checkSound)
    SoundService.DescendantAdded:Connect(checkSound)

    -- Bắt đầu vòng lặp
    createRenderLoop()
    print("[Kiếm] Hệ thống đã BẬT")
end

local function stopSwordSystem()
    swordSystemActive = false
    if connectionRender then
        connectionRender:Disconnect()
        connectionRender = nil
    end
    cleanupAllSwords()
    print("[Kiếm] Hệ thống đã TẮT")
end

-- ==================== LẮNG NGHE TOGGLE TỪ getgenv ====================
local lastToggleState = false

task.spawn(function()
    while true do
        local currentState = getgenv().ShedletskySwordEnabled
        if currentState ~= lastToggleState then
            lastToggleState = currentState
            if currentState then
                startSwordSystem()
            else
                stopSwordSystem()
            end
        end
        task.wait(0.3)
    end
end)

-- ==================== RESPAWN HANDLER ====================
localPlayer.CharacterAdded:Connect(function(char)
    playerCharacter = char
    isDying = false
    isAttacking = false
    cleanupAllSwords()

    -- Nếu đang bật thì khởi động lại
    if swordSystemActive then
        task.wait(0.3)
        for i = 1, TOTAL_SWORDS do
            task.delay((i - 1) * SPAWN_DELAY, function()
                if swordSystemActive then
                    spawnSwordSequentially(i)
                end
            end)
        end
    end
end)

-- Auto-start nếu toggle đã bật từ trước
if getgenv().ShedletskySwordEnabled then
    startSwordSystem()
end
