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

-- Không khai báo lại Services vì script chính đã có

if getgenv().CoreESPManager then
    getgenv().CoreESPManager:Destroy()
end

local CoreESPManager = {
    System = {
        Objects = {}, -- Lưu trữ: [id_nhóm][object] = data
        EnabledGroups = {}, -- Trạng thái bật/tắt của từng nhóm ID
        Connections = {},
        UpdateLoop = nil,
        LastUpdateTick = 0
    },
    Config = {
        FONT_SIZE = 12,
        UPDATE_RATE = 0.1, -- Tốc độ làm mới (giây)
        MAX_DISTANCE = math.huge
    }
}
getgenv().CoreESPManager = CoreESPManager

local Sys = CoreESPManager.System

-- Hàm hỗ trợ nội bộ
local function getRoot(model)
    if not model then return nil end
    if model:IsA("BasePart") then return model end
    return model.PrimaryPart or model:FindFirstChild("HumanoidRootPart") or model:FindFirstChildWhichIsA("BasePart")
end

local function getHumanoid(model)
    return model and model:FindFirstChildWhichIsA("Humanoid")
end

-- Dọn dẹp hệ thống cũ
function CoreESPManager:Destroy()
    if Sys.UpdateLoop then Sys.UpdateLoop:Disconnect() end
    for _, con in ipairs(Sys.Connections) do pcall(con.Disconnect, con) end
    for id, objects in pairs(Sys.Objects) do
        for obj, _ in pairs(objects) do
            self:Remove(id, obj)
        end
    end
    Sys.Objects = {}
end

-- Tạo UI bảo vệ
local function CreateProtectedHighlight(object, color, transparency)
    local h = Instance.new("Highlight")
    h.Name = "CoreESPHighlight"
    h.FillColor = color or Color3.new(1, 1, 1)
    h.OutlineColor = Color3.new(1, 1, 1)
    h.FillTransparency = transparency or 0.5
    h.OutlineTransparency = 0
    h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    h.Adornee = object
    h.Enabled = true
    h.Parent = CoreGui
    return h
end

local function CreateProtectedBillboard(root, color, fontSize)
    local billboard = Instance.new("BillboardGui")
    billboard.Name = "CoreESPBillboard"
    billboard.AlwaysOnTop = true
    billboard.LightInfluence = 0
    billboard.ResetOnSpawn = false
    billboard.MaxDistance = CoreESPManager.Config.MAX_DISTANCE
    billboard.Size = UDim2.new(0, 220, 0, 50)
    billboard.StudsOffset = Vector3.new(0, 3, 0)
    billboard.Adornee = root

    local text = Instance.new("TextLabel")
    text.BackgroundTransparency = 1
    text.Size = UDim2.new(1, 0, 1, 0)
    text.Font = Enum.Font.GothamBold
    text.TextColor3 = color or Color3.new(1, 1, 1)
    text.TextStrokeTransparency = 0
    text.TextStrokeColor3 = Color3.new(0, 0, 0)
    text.TextSize = fontSize
    text.TextScaled = false
    text.Parent = billboard

    billboard.Parent = CoreGui
    return billboard, text
end

-- API: Xóa ESP
function CoreESPManager:Remove(id, object)
    if not Sys.Objects[id] or not Sys.Objects[id][object] then return end
    local data = Sys.Objects[id][object]
    
    if data.Connections then
        for _, connection in ipairs(data.Connections) do pcall(connection.Disconnect, connection) end
    end
    
    if data.Highlight then pcall(data.Highlight.Destroy, data.Highlight) end
    if data.Billboard then pcall(data.Billboard.Destroy, data.Billboard) end
    
    Sys.Objects[id][object] = nil
end

-- API: Bật/Tắt hiển thị của một nhóm (id)
function CoreESPManager:SetGroupVisible(id, state)
    Sys.EnabledGroups[id] = state
    if not Sys.Objects[id] then return end
    
    for object, data in pairs(Sys.Objects[id]) do
        if data.Highlight then data.Highlight.Enabled = state end
        if data.Billboard then data.Billboard.Enabled = state end
    end
end

-- API: Thêm ESP
-- config gồm: { Color = Color3, BaseName = string, FillTransparency = number, ShowHealth = boolean, ShowDistance = boolean }
function CoreESPManager:Add(id, object, config)
    if not object or not object.Parent then return end
    local root = getRoot(object)
    if not root then return end

    Sys.Objects[id] = Sys.Objects[id] or {}
    if Sys.Objects[id][object] then return end -- Chống tạo đúp

    local isEnabled = Sys.EnabledGroups[id] == nil and true or Sys.EnabledGroups[id]
    
    local billboard, textLabel = CreateProtectedBillboard(root, config.Color, CoreESPManager.Config.FONT_SIZE)
    local highlight = CreateProtectedHighlight(object, config.Color, config.FillTransparency)
    
    billboard.Enabled = isEnabled
    highlight.Enabled = isEnabled

    local data = {
        Object = object,
        Root = root,
        Billboard = billboard,
        Text = textLabel,
        Highlight = highlight,
        Config = config,
        CachedText = "",
        Connections = {}
    }

    -- Bảo vệ: Tự động xóa nếu object biến mất khỏi Workspace
    table.insert(data.Connections, object.AncestryChanged:Connect(function(_, parent)
        if not parent then CoreESPManager:Remove(id, object) end
    end))

    -- Bảo vệ: Ép UI trở lại CoreGui nếu game cố tình giấu/xóa UI
    table.insert(data.Connections, billboard.AncestryChanged:Connect(function(_, parent)
        if not parent and object.Parent and Sys.Objects[id][object] then 
            billboard.Parent = CoreGui 
        end
    end))
    table.insert(data.Connections, highlight.AncestryChanged:Connect(function(_, parent)
        if not parent and object.Parent and Sys.Objects[id][object] then
            data.Highlight = CreateProtectedHighlight(object, config.Color, config.FillTransparency)
            data.Highlight.Enabled = Sys.EnabledGroups[id]
        end
    end))

    Sys.Objects[id][object] = data
end

-- Vòng lặp cập nhật (Khoảng cách, Máu, Ép Adornee)
Sys.UpdateLoop = RunService.Heartbeat:Connect(function(delta)
    Sys.LastUpdateTick = Sys.LastUpdateTick + delta
    if Sys.LastUpdateTick < CoreESPManager.Config.UPDATE_RATE then return end
    Sys.LastUpdateTick = 0

    local myRoot = getRoot(Players.LocalPlayer.Character)
    if not myRoot then return end

    for id, objects in pairs(Sys.Objects) do
        if not Sys.EnabledGroups[id] then continue end -- Bỏ qua nếu nhóm đang bị tắt
        
        for object, data in pairs(objects) do
            -- Dọn dẹp rác nếu object lỗi nhưng event chưa kịp kích hoạt
            if not object or not object.Parent or not data.Root or not data.Root.Parent then
                CoreESPManager:Remove(id, object)
                continue
            end

            -- Chống game thay đổi Adornee
            if data.Highlight.Adornee ~= object then data.Highlight.Adornee = object end
            if data.Billboard.Adornee ~= data.Root then data.Billboard.Adornee = data.Root end

            -- Cập nhật Text
            local dist = math.floor((myRoot.Position - data.Root.Position).Magnitude)
            local displayText = data.Config.BaseName or object.Name

            if data.Config.ShowDistance then
                displayText = displayText .. string.format(" [%dm]", dist)
            end

            if data.Config.ShowHealth then
                local h = getHumanoid(object)
                if h then
                    displayText = displayText .. string.format(" [HP: %d/%d]", math.floor(h.Health), math.floor(h.MaxHealth))
                end
            end

            if data.CachedText ~= displayText then
                data.CachedText = displayText
                if data.Text then data.Text.Text = displayText end
            end
        end
    end
end)

return CoreESPManager
