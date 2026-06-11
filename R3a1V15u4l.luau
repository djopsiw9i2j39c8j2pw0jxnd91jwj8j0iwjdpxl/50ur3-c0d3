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

-- File Thư Viện ESP Logic (Cho lên GitHub/Pastebin Raw)
if getgenv().ESP_API_LOADED then return end
getgenv().ESP_API_LOADED = true

getgenv().ESP_API = {}

-- [5] Kích cỡ Text cố định là 10 theo yêu cầu
local TEXT_SIZE = 10 

-- Hàm khởi tạo ESP cho 1 mục tiêu
function getgenv().ESP_API.Create(targetModel)
    local espObjects = {
        Text = Drawing.new("Text"),
        Tracer = Drawing.new("Line"),
        Highlight = Instance.new("Highlight")
    }
    
    -- Setup Text
    espObjects.Text.Size = TEXT_SIZE
    espObjects.Text.Center = true
    espObjects.Text.Outline = true
    espObjects.Text.ZIndex = 9999 -- [5] Chống bị các script khác đè mất
    
    -- Setup Tia/Dây
    espObjects.Tracer.Thickness = 1
    espObjects.Tracer.ZIndex = 9999
    
    -- Setup Highlight (Phát sáng)
    espObjects.Highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop -- Luôn hiện xuyên tường
    espObjects.Highlight.OutlineColor = Color3.fromRGB(255, 255, 255) -- [1] Viền luôn CỐ ĐỊNH MÀU TRẮNG
    espObjects.Highlight.OutlineTransparency = 0
    espObjects.Highlight.FillTransparency = 0.5
    
    -- Giấu Highlight vào CoreGui để chống game phát hiện/xóa
    local success = pcall(function()
        espObjects.Highlight.Parent = CoreGui
    end)
    if not success then
        espObjects.Highlight.Parent = targetModel 
    end

    return espObjects
end

-- Hàm cập nhật khung hình 
-- Thêm tham số `buttonSettings` để mỗi nút truyền cài đặt riêng (màu sắc, bật/tắt) của nút đó vào
function getgenv().ESP_API.Update(espObjects, targetModel, targetName, localPlayerPos, buttonSettings)
    -- Nếu mục tiêu chết hoặc mất RootPart thì ẩn hết
    if not targetModel or not targetModel:FindFirstChild("HumanoidRootPart") then
        espObjects.Text.Visible = false
        espObjects.Tracer.Visible = false
        espObjects.Highlight.Enabled = false
        return
    end

    local rootPart = targetModel.HumanoidRootPart
    local humanoid = targetModel:FindFirstChildOfClass("Humanoid")
    
    local pos, onScreen = Camera:WorldToViewportPoint(rootPart.Position)
    local distance = (localPlayerPos - rootPart.Position).Magnitude
    
    -- [1] Lấy màu từ cài đặt CỦA TỪNG NÚT truyền vào (mặc định là trắng nếu lỗi)
    local nodeColor = buttonSettings.Color or Color3.fromRGB(255, 255, 255)

    -- Xử lý Highlight
    if buttonSettings.Highlight_Enabled then
        espObjects.Highlight.Enabled = true
        espObjects.Highlight.FillColor = nodeColor -- Màu trong chạy theo màu của nút
        espObjects.Highlight.Adornee = targetModel -- Liên tục bám sát
    else
        espObjects.Highlight.Enabled = false
    end

    -- Xử lý Text & Tracer (Chỉ vẽ nếu mục tiêu nằm trong màn hình)
    if onScreen then
        -- Xử lý Text
        if buttonSettings.Text_Enabled then
            local textStr = targetName
            
            -- [3] Logic hiển thị Text theo khoảng cách và máu
            if buttonSettings.Show_Distance and not buttonSettings.Show_Health then
                textStr = textStr .. " [" .. math.floor(distance) .. "m]"
            elseif not buttonSettings.Show_Distance and buttonSettings.Show_Health and humanoid then
                textStr = textStr .. " [HP : " .. math.floor(humanoid.Health) .. "/" .. math.floor(humanoid.MaxHealth) .. "]"
            elseif buttonSettings.Show_Distance and buttonSettings.Show_Health and humanoid then
                textStr = textStr .. " [" .. math.floor(distance) .. "m] [HP : " .. math.floor(humanoid.Health) .. "/" .. math.floor(humanoid.MaxHealth) .. "]"
            end
            
            espObjects.Text.Text = textStr
            espObjects.Text.Position = Vector2.new(pos.X, pos.Y - 25) -- Lệch lên trên
            espObjects.Text.Color = nodeColor -- Text chạy theo màu của nút
            espObjects.Text.Visible = true
        else
            espObjects.Text.Visible = false
        end

        -- Xử lý Tia
        if buttonSettings.Tracer_Enabled then
            espObjects.Tracer.From = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y)
            espObjects.Tracer.To = Vector2.new(pos.X, pos.Y)
            espObjects.Tracer.Color = nodeColor -- Tia chạy theo màu của nút
            espObjects.Tracer.Visible = true
        else
            espObjects.Tracer.Visible = false
        end
    else
        espObjects.Text.Visible = false
        espObjects.Tracer.Visible = false
    end
end

-- Hàm dọn dẹp khi tắt
function getgenv().ESP_API.Remove(espObjects)
    if espObjects then
        if espObjects.Text then espObjects.Text:Remove() end
        if espObjects.Tracer then espObjects.Tracer:Remove() end
        if espObjects.Highlight then espObjects.Highlight:Destroy() end
    end
end
