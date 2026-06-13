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
