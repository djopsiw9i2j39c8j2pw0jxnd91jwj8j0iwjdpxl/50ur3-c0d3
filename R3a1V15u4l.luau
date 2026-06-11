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

-- // ESP Common System - getgenv() Based (FIXED)
-- // Khởi tạo getgenv() settings nếu chưa có
getgenv().ESP_Settings = getgenv().ESP_Settings or {
    Color = Color3.fromRGB(255, 0, 0),
    TextEnabled = true,
    HighlightEnabled = true,
    TracerEnabled = false,
    ShowHP = false,
    ShowDistance = false
}

-- // ESP Registry - Quản lý tất cả ESP đang hoạt động
local ESPRegistry = {}
local nextESP_ID = 0

-- // Hàm lấy Settings mới nhất từ getgenv (FIX)
local function GetSettings()
    return getgenv().ESP_Settings
end

-- // Hàm tạo ESP duy nhất không trùng lặp
local function CreateUniqueESP(targetPlayer, ownerButton)
    nextESP_ID = nextESP_ID + 1
    local espID = "ESP_" .. nextESP_ID
    local espData = {
        ID = espID,
        Player = targetPlayer,
        Owner = ownerButton,
        Highlight = nil,
        Billboard = nil,
        Tracer = nil,
        Connections = {},
        Active = true
    }
    
    -- // Tạo Highlight (viền trắng, màu trong theo settings)
    local function CreateHighlight(character)
        if not character or not character:FindFirstChild("HumanoidRootPart") then return end
        if character:FindFirstChild(espID .. "_Highlight") then return end
        
        local settings = GetSettings()
        local highlight = Instance.new("Highlight")
        highlight.Name = espID .. "_Highlight"
        highlight.FillColor = settings.Color
        highlight.FillTransparency = 0.5
        highlight.OutlineColor = Color3.fromRGB(255, 255, 255)
        highlight.OutlineTransparency = 0
        highlight.Adornee = character
        highlight.Parent = character
        highlight.Enabled = settings.HighlightEnabled
        espData.Highlight = highlight
    end
    
    -- // Tạo Billboard Text (size 10)
    local function CreateBillboard(character)
        if not character or not character:FindFirstChild("Head") then return end
        if character.Head:FindFirstChild(espID .. "_Billboard") then return end
        
        local settings = GetSettings()
        local billboard = Instance.new("BillboardGui")
        billboard.Name = espID .. "_Billboard"
        billboard.Adornee = character.Head
        billboard.Size = UDim2.new(0, 300, 0, 60)
        billboard.StudsOffset = Vector3.new(0, 2.5, 0)
        billboard.AlwaysOnTop = true
        billboard.Enabled = settings.TextEnabled
        billboard.Parent = character.Head
        
        local label = Instance.new("TextLabel")
        label.Name = "Label"
        label.Size = UDim2.new(1, 0, 1, 0)
        label.BackgroundTransparency = 1
        label.TextColor3 = settings.Color
        label.TextStrokeTransparency = 0.5
        label.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
        label.TextSize = 10
        label.Font = Enum.Font.SourceSansBold
        label.TextWrapped = true
        label.Parent = billboard
        
        espData.Billboard = billboard
        espData.BillboardLabel = label
    end
    
    -- // Tạo Tracer
    local function CreateTracer()
        if espData.Tracer then espData.Tracer:Remove() end
        
        local settings = GetSettings()
        local tracer = Drawing.new("Line")
        tracer.Color = settings.Color
        tracer.Thickness = 1.5
        tracer.Transparency = 1
        tracer.Visible = settings.TracerEnabled
        espData.Tracer = tracer
    end
    
    -- // Cập nhật Billboard Text
    local function UpdateBillboardText()
        if not espData.BillboardLabel then return end
        
        local settings = GetSettings()
        local character = targetPlayer.Character
        if not character or not character:FindFirstChild("Humanoid") then return end
        
        local name = targetPlayer.Name
        local textParts = {name}
        
        if settings.ShowDistance then
            if playerCharacter and playerCharacter:FindFirstChild("HumanoidRootPart") and character:FindFirstChild("HumanoidRootPart") then
                local distance = math.floor((playerCharacter.HumanoidRootPart.Position - character.HumanoidRootPart.Position).Magnitude)
                textParts[#textParts + 1] = "[" .. distance .. "m]"
            end
        end
        
        if settings.ShowHP then
            local hp = math.floor(character.Humanoid.Health)
            local maxHP = math.floor(character.Humanoid.MaxHealth)
            textParts[#textParts + 1] = "[HP: " .. hp .. "/" .. maxHP .. "]"
        end
        
        espData.BillboardLabel.Text = table.concat(textParts, " ")
    end
    
    -- // Loop cập nhật liên tục
    local function UpdateLoop()
        if not espData.Active then return end
        
        local settings = GetSettings()
        local character = targetPlayer.Character
        
        if character then
            -- Highlight
            if espData.Highlight then
                espData.Highlight.Enabled = settings.HighlightEnabled
                espData.Highlight.FillColor = settings.Color
            elseif settings.HighlightEnabled then
                CreateHighlight(character)
            end
            
            -- Billboard
            if espData.Billboard then
                espData.Billboard.Enabled = settings.TextEnabled
                if settings.TextEnabled then
                    espData.BillboardLabel.TextColor3 = settings.Color
                    UpdateBillboardText()
                end
            elseif settings.TextEnabled then
                CreateBillboard(character)
            end
            
            -- Tracer
            if settings.TracerEnabled then
                if not espData.Tracer then
                    CreateTracer()
                end
                if character:FindFirstChild("HumanoidRootPart") and playerCharacter and playerCharacter:FindFirstChild("HumanoidRootPart") then
                    local rootPos = character.HumanoidRootPart.Position
                    local myRootPos = playerCharacter.HumanoidRootPart.Position
                    local screenPos, onScreen = Camera:WorldToViewportPoint(rootPos)
                    local myScreenPos, _ = Camera:WorldToViewportPoint(myRootPos)
                    
                    if onScreen and espData.Tracer then
                        espData.Tracer.From = Vector2.new(myScreenPos.X, myScreenPos.Y)
                        espData.Tracer.To = Vector2.new(screenPos.X, screenPos.Y)
                        espData.Tracer.Visible = true
                        espData.Tracer.Color = settings.Color
                    elseif espData.Tracer then
                        espData.Tracer.Visible = false
                    end
                end
            elseif espData.Tracer then
                espData.Tracer.Visible = false
            end
        end
    end
    
    -- // Đăng ký loop vào Heartbeat
    local heartbeatConn = RunService.Heartbeat:Connect(UpdateLoop)
    table.insert(espData.Connections, heartbeatConn)
    
    -- // CharacterAdded
    local charAddedConn = targetPlayer.CharacterAdded:Connect(function(character)
        task.wait(0.3)
        if espData.Highlight then espData.Highlight:Destroy(); espData.Highlight = nil end
        if espData.Billboard then espData.Billboard:Destroy(); espData.Billboard = nil; espData.BillboardLabel = nil end
        if espData.Tracer then espData.Tracer:Remove(); espData.Tracer = nil end
        
        local settings = GetSettings()
        if settings.HighlightEnabled then CreateHighlight(character) end
        if settings.TextEnabled then CreateBillboard(character) end
        if settings.TracerEnabled then CreateTracer() end
    end)
    table.insert(espData.Connections, charAddedConn)
    
    -- // Khởi tạo lần đầu
    local settings = GetSettings()
    local currentChar = targetPlayer.Character
    if currentChar then
        if settings.HighlightEnabled then CreateHighlight(currentChar) end
        if settings.TextEnabled then CreateBillboard(currentChar) end
    end
    if settings.TracerEnabled then CreateTracer() end
    
    return espData
end

-- // Hàm xóa ESP
local function RemoveESP(espData)
    espData.Active = false
    for _, conn in ipairs(espData.Connections) do
        conn:Disconnect()
    end
    espData.Connections = {}
    if espData.Highlight then espData.Highlight:Destroy(); espData.Highlight = nil end
    if espData.Billboard then espData.Billboard:Destroy(); espData.Billboard = nil end
    if espData.Tracer then espData.Tracer:Remove(); espData.Tracer = nil end
end

-- // ESP Manager
local ESPManager = {}

function ESPManager:RegisterESP(targetPlayer, ownerButton)
    for id, esp in pairs(ESPRegistry) do
        if esp.Player == targetPlayer and esp.Owner == ownerButton then
            RemoveESP(esp)
            ESPRegistry[id] = nil
        end
    end
    
    local espData = CreateUniqueESP(targetPlayer, ownerButton)
    ESPRegistry[espData.ID] = espData
    return espData.ID
end

function ESPManager:UnregisterESP(espID)
    if ESPRegistry[espID] then
        RemoveESP(ESPRegistry[espID])
        ESPRegistry[espID] = nil
    end
end

function ESPManager:UnregisterAllFromButton(ownerButton)
    for id, esp in pairs(ESPRegistry) do
        if esp.Owner == ownerButton then
            RemoveESP(esp)
            ESPRegistry[id] = nil
        end
    end
end

function ESPManager:UnregisterAll()
    for id, esp in pairs(ESPRegistry) do
        RemoveESP(esp)
    end
    ESPRegistry = {}
end

function ESPManager:RefreshAllESP()
    local settings = GetSettings()
    for _, esp in pairs(ESPRegistry) do
        if esp.Active then
            if esp.Billboard then
                esp.Billboard.Enabled = settings.TextEnabled
                esp.BillboardLabel.TextColor3 = settings.Color
            end
            if esp.Highlight then
                esp.Highlight.Enabled = settings.HighlightEnabled
                esp.Highlight.FillColor = settings.Color
            end
        end
    end
end

return ESPManager
