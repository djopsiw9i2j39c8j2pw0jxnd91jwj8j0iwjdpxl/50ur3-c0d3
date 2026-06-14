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

-- KHỞI TẠO BIẾN GLOBAL ĐỂ CHỨA HÀM
getgenv().HutaoAuraSword = {}

-- BỎ KHOẢNG ĐỢI YIELD Ở NGOÀI CÙNG, ĐẶT TEMPLATE LÀ NIL ĐỂ HUB LOAD MƯỢT
local swordTemplate = nil 

-- SOUND ID CONFIG
local SWORD_SOUND_ID = "rbxassetid://12222200" 

-- ================= DANH SÁCH SOUND TRIGER ================= --
local TRIGGER_SOUND_IDS = {
	["12222225"] = true,
	["83851356262523"] = true, 
}

-- ================= CẤU HÌNH ================= --
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

local orbitingSwords = {}
local isDying = false           
local isAttacking = false       
local auraConnections = {} 
local isAuraActive = false 
local isCurrentlyShedletsky = false 
local soundListenerConn = nil
local templateDescendantsCount = 0

-- ================= HÀM DỌN DẸP KIẾM NHANH ================= --
local function clearSwords()
	for _, data in ipairs(orbitingSwords) do
		if data.FallTween then 
			data.FallTween:Cancel() 
		end
		if data.FlyTween then 
			data.FlyTween:Cancel() 
		end
		if data.Object then 
			local glow = data.Object:FindFirstChild("RainbowGlow")
			if glow then glow:Destroy() end
			data.Object:Destroy() 
		end
		if data.FlyValue then data.FlyValue:Destroy() end
		if data.FallValue then data.FallValue:Destroy() end
	end
	table.clear(orbitingSwords)
end

-- ================= HÀM XỬ LÝ KIẾM ================= --
local function cloneVisibleSword()
	if not swordTemplate then return nil, nil end 
	
	local clone = swordTemplate:Clone()
	local cloneCount = #clone:GetDescendants()
	
	if cloneCount < templateDescendantsCount or cloneCount == 0 then
		clone:Destroy()
		return nil, nil
	end
	
	clone.Name = "OrbitingSword"
	local parts = {}
	
	local function processPart(part)
		if part:IsA("BasePart") then
			local lowerName = part.Name:lower()
			if lowerName:find("hitbox") or lowerName:find("sensor") or lowerName:find("damager") then
				part.Transparency = 1
			else
				table.insert(parts, part)
			end
		end
	end

	if clone:IsA("BasePart") then processPart(clone) end
	for _, desc in pairs(clone:GetDescendants()) do
		processPart(desc)
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
	
	local descendants = clone:GetDescendants()
	for i = 1, #descendants do
		local desc = descendants[i]
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

local function spawnSwordSequentially(index)
	local sword, parts = cloneVisibleSword()
	
	if not sword then
		task.delay(0.5, function()
			if isAuraActive and isCurrentlyShedletsky then
				spawnSwordSequentially(index)
			end
		end)
		return 
	end
	
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
		FallValue = nil,
		FallTween = nil,
		FlyTween = nil,
		TargetCharacter = nil 
	}
	table.insert(orbitingSwords, swordData)
	
	for _, part in ipairs(parts) do 
		part.Transparency = 0 
	end
	
	local currentChar = localPlayer.Character
	if currentChar and currentChar:FindFirstChild("HumanoidRootPart") then
		local sound = Instance.new("Sound")
		sound.SoundId = SWORD_SOUND_ID
		sound.Volume = 0.6
		sound.Parent = currentChar.HumanoidRootPart
		sound:Play()
		task.delay(2, function() sound:Destroy() end)
	end
	
	-- ===== FALL TWEEN ===== --
	local fallValue = Instance.new("NumberValue")
	fallValue.Value = FALL_HEIGHT
	swordData.FallValue = fallValue
	
	local tweenInfo = TweenInfo.new(FALL_DURATION, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out)
	local fallTween = TweenService:Create(fallValue, tweenInfo, {Value = 0})  
	swordData.FallTween = fallTween
	
	fallValue.Changed:Connect(function(newValue)
		swordData.CurrentOffset = newValue
	end)
	
	fallTween:Play()
	
	fallTween.Completed:Connect(function()
		if swordData.State ~= "Ascending" then
			swordData.State = "Orbiting"
		end
		fallValue:Destroy()
		swordData.FallValue = nil
		swordData.FallTween = nil
	end)
end

-- ================= TÌM KILLER GẦN NHẤT ================= --
local function getNearestKillerCharacter()
	local currentChar = localPlayer.Character
	if not currentChar or not currentChar:FindFirstChild("HumanoidRootPart") then return nil end
	local playerRoot = currentChar.HumanoidRootPart
	
	local nearestChar = nil
	local minDistance = ATTACK_RANGE
	
	local killers = killersFolder:GetChildren()
	for i = 1, #killers do
		local kPlayer = killers[i]
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

-- ================= HÀM ĐIỀU KHIỂN PHÓNG / THU KIẾM ================= --
local function executeAttack(killerChar)
	isAttacking = true
	
	local swords = orbitingSwords
	for i = 1, #swords do
		local data = swords[i]
		if data.State == "Ascending" then continue end
		
		task.delay((i - 1) * 0.1, function() 
			data.TargetCharacter = killerChar
			
			if data.FlyTween then 
				data.FlyTween:Cancel() 
			end
			
			data.FlyTween = TweenService:Create(data.FlyValue, 
				TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), 
				{Value = 1})
			data.FlyTween:Play()
		end)
	end

	task.wait(3.5)

	for i = 1, #swords do
		local data = swords[i]
		if data.State == "Ascending" then continue end
		
		task.delay((i - 1) * 0.1, function()
			if data.FlyTween then 
				data.FlyTween:Cancel() 
			end
			
			data.FlyTween = TweenService:Create(data.FlyValue, 
				TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.In), 
				{Value = 0})
			data.FlyTween:Play()
			
			data.FlyTween.Completed:Connect(function()
				data.TargetCharacter = nil 
				data.FlyTween = nil
			end)
		end)
	end

	task.wait(0.5)
	isAttacking = false
end

-- ================= HỆ THỐNG CHECK SOUND KÍCH HOẠT ================= --
local function disconnectSoundListener()
	if soundListenerConn then
		soundListenerConn:Disconnect()
		soundListenerConn = nil
	end
end

local function connectSoundListener(character)
	disconnectSoundListener()
	
	if not character then return end
	
	soundListenerConn = character.DescendantAdded:Connect(function(descendant)
		if not descendant:IsA("Sound") then return end
		if isAttacking or isDying or not isCurrentlyShedletsky then return end
		
		local soundDigits = descendant.SoundId:match("%d+$")
		
		if soundDigits and TRIGGER_SOUND_IDS[soundDigits] then
			local targetKiller = getNearestKillerCharacter()
			if targetKiller then
				task.spawn(function()
					executeAttack(targetKiller)
				end)
			end
		end
	end)
end

-- ================= HÀM QUẢN LÝ BẬT / TẮT AURA ================= --
local function cleanUpAura()
	isAuraActive = false 
	isCurrentlyShedletsky = false
	
	disconnectSoundListener()
	
	for _, conn in pairs(auraConnections) do
		if conn then conn:Disconnect() end
	end
	table.clear(auraConnections)
	
	clearSwords()
	
	isDying = false
	isAttacking = false
	
	-- ===== FIX: Reset swordTemplate khi Stop để lần Start sau tìm lại ===== --
	swordTemplate = nil
	templateDescendantsCount = 0
end

-- ================= FIX: HÀM TÌM SWORD TEMPLATE TỪ CHARACTER ================= --
local function findSwordTemplate(character)
	if not character then return false end
	if character.Name ~= "Shedletsky" then return false end
	
	local sword = character:WaitForChild("Sword", 5)
	if sword then
		swordTemplate = sword
		templateDescendantsCount = #swordTemplate:GetDescendants()
		return true
	end
	return false
end

-- ================= ORBIT UPDATE ================= --
local function updateOrbit()
	local myCharacter = localPlayer.Character
	if not myCharacter then return end
	
	local myHumanoid = myCharacter:FindFirstChild("Humanoid")
	local myRoot = myCharacter:FindFirstChild("HumanoidRootPart")
	if not myHumanoid or not myRoot then return end
	
	if myHumanoid.Health <= 0 then
		if not isDying then
			isDying = true
			local swords = orbitingSwords
			for i = 1, #swords do
				local data = swords[i]
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
	
	local now = tick()
	
	local swords = orbitingSwords
	for i = 1, #swords do
		local data = swords[i]
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
end

-- ================= START AURA (ĐÃ FIX) ================= --
local function startAura()
	cleanUpAura() 
	isAuraActive = true
	
	task.spawn(function()
		-- ===== FIX: Luôn tìm swordTemplate khi Start (không cache cứng) ===== --
		local myChar = localPlayer.Character
		
		-- Nếu đang trong game và là Shedletsky, tìm sword ngay
		if myChar and myChar.Name == "Shedletsky" then
			findSwordTemplate(myChar)
		end
		
		-- Nếu chưa tìm thấy (chưa vào game hoặc chưa phải Shedletsky), chờ CharacterAdded
		if not swordTemplate then
			local newChar = localPlayer.CharacterAdded:Wait()
			findSwordTemplate(newChar)
		end
		
		if not swordTemplate then
			warn("Không tìm thấy kiếm gốc! Hãy chắc chắn bạn đang là Shedletsky.")
			isAuraActive = false
			return
		end
		
		if not isAuraActive then return end 
		
		-- Kết nối sound listener cho character hiện tại
		if localPlayer.Character then
			connectSoundListener(localPlayer.Character)
		end
		
		-- CharacterAdded handler: KHÔNG reset isCurrentlyShedletsky ở đây nữa
		-- vì RenderStepped sẽ tự phát hiện và xử lý chuyển đổi nhân vật
		table.insert(auraConnections, localPlayer.CharacterAdded:Connect(function(newChar)
			disconnectSoundListener()
			clearSwords()
			isDying = false
			isAttacking = false
			
			-- ===== FIX: Tìm lại swordTemplate từ character mới ===== --
			-- KHÔNG reset isCurrentlyShedletsky, để RenderStepped tự xử lý
			-- Nhưng clear swords để tránh bug
		end))
		
		-- RenderStepped cho orbit
		table.insert(auraConnections, RunService.RenderStepped:Connect(function()
			if not isAuraActive then return end
			
			local myCharacter = localPlayer.Character  
			if not myCharacter then return end
			
			local isShedletskyNow = (myCharacter.Name == "Shedletsky")
			
			-- Phát hiện chuyển ĐẾN Shedletsky
			if isShedletskyNow and not isCurrentlyShedletsky then
				isCurrentlyShedletsky = true
				isDying = false
				isAttacking = false
				clearSwords()
				
				-- ===== FIX: Tìm lại swordTemplate ===== --
				findSwordTemplate(myCharacter)
				
				if swordTemplate then
					connectSoundListener(myCharacter)
					
					task.spawn(function()
						task.wait(1)
						if not isCurrentlyShedletsky or not isAuraActive then return end 
						
						for i = 1, TOTAL_SWORDS do
							task.delay((i - 1) * SPAWN_DELAY, function()
								if isAuraActive and isCurrentlyShedletsky then
									spawnSwordSequentially(i)
								end
							end)
						end
					end)
				end
				
			-- Phát hiện chuyển KHỎI Shedletsky
			elseif not isShedletskyNow and isCurrentlyShedletsky then
				isCurrentlyShedletsky = false
				disconnectSoundListener()
				clearSwords()
			end

			if not isCurrentlyShedletsky then return end
			
			updateOrbit()
		end))
	end)
end

-- XUẤT HÀM RA GETGENV ĐỂ TRUY CẬP ĐƯỢC TỪ FILE KHÁC
getgenv().HutaoAuraSword.Start = startAura
getgenv().HutaoAuraSword.Stop = cleanUpAura

-- Full Misc

-- Khởi tạo Database nếu chưa có
if not getgenv().MiscModule then
    getgenv().MiscModule = {
        Settings = {
            FullBright = false, Fog = false, InfiniteZoom = false, AntiSlow = false, ShowChat = false,
            RemoveNPCNoli = false, AntiAFK = true, RemoveEffects = false, RemoveBlackScreen = true, AntiAdmin = true
        },
        Constants = {
            DefaultCamera = { Max = 128, Min = 0.5 },
            EffectNames = {
                BlurEffect = true, ColorCorrectionEffect = true, BloomEffect = true, SunRaysEffect = true,
                DepthOfFieldEffect = true, ScreenFlash = true, HitEffect = true, DamageOverlay = true,
                BloodEffect = true, Vignette = true, BlackScreen = true, WhiteScreen = true,
                ShockEffect = true, Darkness = true, JumpScare = true, LowHealthOverlay = true,
                Flashbang = true, FadeEffect = true
            },
            EffectClasses = {
                BlurEffect = true, BloomEffect = true, SunRaysEffect = true, 
                DepthOfFieldEffect = true, ColorCorrectionEffect = true
            },
            AntiSlowConfigs = {
                {"SlowedStatus"},
                {"StunningKiller", "EatFriedChicken", "GuestBlocking", "PunchAbility", "SubspaceTripmine", "TaphTripwire", "PlasmaBeam", "SpawnProtection", "c00lgui", "ShootingGun", "TwoTimeStab", "TwoTimeCrouching", "DrinkingCola", "DrinkingSlateskin", "SlateskinStatus", "EatingGhostburger"},
                {"BloxyColaItem", "Medkit"},
                {"Emoting"},
                {"DispenserConstruction", "SentryConstruction"}
            },
            AdminNames = {
                "Enoderen", "SoyS3BASTIAN", "aateeer", "sayso_1230", "fractalintersection", 
                "KeyAfterKey", "Exedious", "Agrovient", "isaac3523", "Proffessor738", "Roblox"
            }
        },
        Cache = {
            EffectCons = {}, BlackScreenCons = {}, AntiAFKCons = {}, AntiAFKConn = nil,
            ChatWindow = game:GetService("TextChatService"):FindFirstChild("ChatWindowConfiguration"),
            AntiAdminLoop = nil, NoliTracked = {}
        }
    }
end

local M = getgenv().MiscModule
local UI = getgenv().WindUI or WindUI -- Đảm bảo gọi được WindUI từ Global

-- Khởi tạo API cho GUI gọi
getgenv().HutaoMiscAPI = {}
local API = getgenv().HutaoMiscAPI

-- ================= CÁC HÀM XỬ LÝ NỘI BỘ ================= --
local function ApplyVisuals()
    if M.Settings.FullBright then
        Lighting.Ambient = Color3.fromRGB(200, 200, 200)
        Lighting.Brightness = 4
        Lighting.GlobalShadows = false
    end
    if M.Settings.Fog then
        Lighting.FogStart = 0
        Lighting.FogEnd = 999999
        local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
        if atmosphere then atmosphere.Density = 0 atmosphere.Haze = 0 end
    end
    if M.Settings.InfiniteZoom then
        localPlayer.CameraMaxZoomDistance = math.huge
        localPlayer.CameraMinZoomDistance = M.Constants.DefaultCamera.Min
    end
end

local function ResetFullBright()
    Lighting.Ambient = Color3.fromRGB(128, 128, 128)
    Lighting.Brightness = 1
    Lighting.GlobalShadows = true
end

local function ResetFog()
    Lighting.FogStart = 200
    Lighting.FogEnd = 1000
    local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
    if atmosphere then atmosphere.Density = 0.3 atmosphere.Haze = 0.5 end
end

local function ResetZoom()
    localPlayer.CameraMaxZoomDistance = M.Constants.DefaultCamera.Max
    localPlayer.CameraMinZoomDistance = M.Constants.DefaultCamera.Min
end

local function processAntiSlow()
    if not M.Settings.AntiSlow or not localPlayer.Character then return end
    local speedFolder = localPlayer.Character:FindFirstChild("SpeedMultipliers")
    if speedFolder then
        for _, group in ipairs(M.Constants.AntiSlowConfigs) do
            for i = 1, #group do
                local obj = speedFolder:FindFirstChild(group[i])
                if obj and obj:IsA("NumberValue") and obj.Value ~= 1 then obj.Value = 1 end
            end
        end
    end
    local pg = localPlayer:FindFirstChild("PlayerGui")
    if pg then
        local mainUI = pg:FindFirstChild("MainUI")
        local status = mainUI and mainUI:FindFirstChild("StatusContainer")
        local slowUI = status and status:FindFirstChild("Slowness")
        if slowUI then slowUI.Visible = false end
    end
end

local function processRemoveNoli()
    if not M.Settings.RemoveNPCNoli then 
        table.clear(M.Cache.NoliTracked) return 
    end
    for model, _ in pairs(M.Cache.NoliTracked) do
        if not model or not model.Parent then M.Cache.NoliTracked[model] = nil end
    end
    for _, v in ipairs(workspace:GetDescendants()) do
        if v:IsA("Model") and v.Name == "Noli" then
            if Players:GetPlayerFromCharacter(v) then
                M.Cache.NoliTracked[v] = nil
            elseif v:FindFirstChildOfClass("Humanoid") then
                if not M.Cache.NoliTracked[v] then M.Cache.NoliTracked[v] = tick()
                elseif tick() - M.Cache.NoliTracked[v] >= 5 then
                    pcall(v.Destroy, v)
                    M.Cache.NoliTracked[v] = nil
                end
            end
        end
    end
end

local function processAntiAdmin()
    if not M.Settings.AntiAdmin then return end
    local myName = localPlayer.Name
    for _, player in ipairs(Players:GetPlayers()) do
        if player.Name ~= myName and table.find(M.Constants.AdminNames, player.Name) then
            pcall(function()
                if UI then UI:Notify({ Title = "hutaohub:Anti_Admin_Forsaken", Content = "hutaohub:Anti_Admin_Forsaken_Content", Duration = 3, Icon = "shield" }) end
            end)
            warn("[AntiAdmin] Phát hiện admin: " .. player.Name .. " - Server hop sau 1 giây.")
            task.wait(1)
            pcall(function() TeleportService:Teleport(game.PlaceId, localPlayer) end)
            return
        end
    end
end

local function TryRemoveEffect(obj)
    if not M.Settings.RemoveEffects or not obj or not obj.Parent then return end
    local remove = M.Constants.EffectNames[obj.Name] or M.Constants.EffectClasses[obj.ClassName]
    if not remove and (obj:IsA("ScreenGui") or obj:IsA("BillboardGui") or obj:IsA("SurfaceGui")) then
        local lname = string.lower(obj.Name)
        remove = string.find(lname, "overlay") or string.find(lname, "effect")
    end
    if remove then pcall(obj.Destroy, obj) end
end

local function TryRemoveBlackScreen(obj)
    if not M.Settings.RemoveBlackScreen or not obj or not obj.Parent then return end
    local nameLower = string.lower(obj.Name)
    local isBlackTarget = (nameLower == "blackscreen") or (nameLower == "fadescreen") or (nameLower == "fadeeffect") or (nameLower == "darkness") or (nameLower == "loadinggui")
    if not isBlackTarget and obj:IsA("Frame") then
        isBlackTarget = string.find(nameLower, "black") or string.find(nameLower, "fade")
    end
    if isBlackTarget then pcall(obj.Destroy, obj) end
end

local function cleanAllBlackScreens()
    if not M.Settings.RemoveBlackScreen then return end
    local pg = localPlayer:FindFirstChild("PlayerGui")
    if not pg then return end
    for _, obj in ipairs(pg:GetDescendants()) do TryRemoveBlackScreen(obj) end
end

local function performAntiAFKAction()
    pcall(function()
        VirtualUser:CaptureController()
        VirtualUser:Button2Down(Vector2.new(0, 0), workspace.CurrentCamera.CFrame)
        task.wait(0.1)
        VirtualUser:Button2Up(Vector2.new(0, 0), workspace.CurrentCamera.CFrame)
    end)
end

-- ================= VÒNG LẶP BACKGROUND ================= --
task.spawn(function()
    while true do
        if M.Settings.FullBright or M.Settings.Fog or M.Settings.InfiniteZoom then ApplyVisuals() end
        processAntiSlow()
        processRemoveNoli()
        cleanAllBlackScreens()
        task.wait(0.5)
    end
end)

task.spawn(function()
    while true do
        if M.Settings.AntiAdmin then processAntiAdmin() end
        task.wait(1)
    end
end)

if M.Cache.ChatWindow then
    M.Cache.ChatWindow:GetPropertyChangedSignal("Enabled"):Connect(function()
        if M.Cache.ChatWindow.Enabled ~= M.Settings.ShowChat then
            M.Cache.ChatWindow.Enabled = M.Settings.ShowChat
        end
    end)
end

-- ================= API PUBLIC CHO GUI ================= --
function API.ServerHop()
    local placeId = game.PlaceId
    print("[ServerHop] Đang rời server hiện tại...")
    local success, err = pcall(function() TeleportService:Teleport(placeId, localPlayer) end)
    if success then
        if UI then UI:Notify({ Title = "hutaohub:Rejoin_Starting", Content = "hutaohub:Rejoin_Starting_Content1", Duration = 3, Icon = "info" }) end
    else
        warn("[ServerHop] Lỗi khi Teleport:", err)
        if UI then UI:Notify({ Title = "hutaohub:Teleport_Error", Content = tostring(err), Duration = 4, Icon = "alert" }) end
    end
end

function API.SetFullBright(state)
    M.Settings.FullBright = state
    if state then ApplyVisuals() else ResetFullBright() end
end

function API.SetRemoveFog(state)
    M.Settings.Fog = state
    if state then ApplyVisuals() else ResetFog() end
end

function API.SetInfiniteZoom(state)
    M.Settings.InfiniteZoom = state
    if not state then ResetZoom() end
end

function API.SetRemoveEffects(state)
    M.Settings.RemoveEffects = state
    for i = 1, #M.Cache.EffectCons do M.Cache.EffectCons[i]:Disconnect() end
    table.clear(M.Cache.EffectCons)

    if not state then return end
    local pg = localPlayer:FindFirstChild("PlayerGui")
    if pg then
        for _, obj in ipairs(pg:GetDescendants()) do TryRemoveEffect(obj) end
        table.insert(M.Cache.EffectCons, pg.DescendantAdded:Connect(TryRemoveEffect))
    end
    for _, obj in ipairs(Lighting:GetDescendants()) do TryRemoveEffect(obj) end
    table.insert(M.Cache.EffectCons, Lighting.DescendantAdded:Connect(TryRemoveEffect))
end

function API.SetRemoveBlackScreen(state)
    M.Settings.RemoveBlackScreen = state
    for i = 1, #M.Cache.BlackScreenCons do M.Cache.BlackScreenCons[i]:Disconnect() end
    table.clear(M.Cache.BlackScreenCons)

    if not state then return end
    cleanAllBlackScreens()
    local pg = localPlayer:FindFirstChild("PlayerGui")
    if pg then table.insert(M.Cache.BlackScreenCons, pg.DescendantAdded:Connect(TryRemoveBlackScreen)) end
end

function API.SetAntiSlow(state) M.Settings.AntiSlow = state end
function API.SetShowChat(state) 
    M.Settings.ShowChat = state
    if M.Cache.ChatWindow then M.Cache.ChatWindow.Enabled = state end
end

function API.SetAntiScreenRec(state)
    if type(setfflag) ~= "function" then return end
    pcall(function()
        setfflag("AbuseReportScreenshot", state and "False" or "True")
        setfflag("AbuseReportScreenshotPercentage", state and "0" or "100")
    end)
end

function API.SetRemoveFakeNoli(state) M.Settings.RemoveNPCNoli = state end
function API.SetAntiAdmin(state) M.Settings.AntiAdmin = state end

function API.SetAntiAFK(state)
    M.Settings.AntiAFK = state
    if not getconnections then return end
    local idleCons = getconnections(localPlayer.Idled)

    if state then
        for _, c in ipairs(idleCons) do
            M.Cache.AntiAFKCons[c] = true
            pcall(c.Disable, c)
        end
        if M.Cache.AntiAFKConn then M.Cache.AntiAFKConn:Disconnect() end
        M.Cache.AntiAFKConn = localPlayer.Idled:Connect(performAntiAFKAction)
    else
        for c in pairs(M.Cache.AntiAFKCons) do
            if c and c.Enable then pcall(c.Enable, c) end
        end
        M.Cache.AntiAFKCons = {}
        if M.Cache.AntiAFKConn then
            M.Cache.AntiAFKConn:Disconnect()
            M.Cache.AntiAFKConn = nil
        end
    end
end

