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

-- ================= HÀM DỌN DẸP KIẾM NHANH ================= --
local function clearSwords()
	for _, data in ipairs(orbitingSwords) do
		if data.Object then data.Object:Destroy() end
		if data.FlyValue then data.FlyValue:Destroy() end
	end
	table.clear(orbitingSwords)
end

-- ================= HÀM XỬ LÝ KIẾM ================= --
local function cloneVisibleSword()
	if not swordTemplate then return nil, nil end 
	
	local clone = swordTemplate:Clone()
	
	local originCount = #swordTemplate:GetDescendants()
	local cloneCount = #clone:GetDescendants()
	
	if cloneCount < originCount or cloneCount == 0 then
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

-- ================= TÌM KILLER GẦN NHẤT ================= --
local function getNearestKillerCharacter()
	local currentChar = localPlayer.Character
	if not currentChar or not currentChar:FindFirstChild("HumanoidRootPart") then return nil end
	local playerRoot = currentChar.HumanoidRootPart
	
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

-- ================= HÀM ĐIỀU KHIỂN PHÓNG / THU KIẾM ================= --
local function executeAttack(killerChar)
	isAttacking = true
	
	for i, data in ipairs(orbitingSwords) do
		if data.State == "Ascending" then continue end
		task.delay((i - 1) * 0.1, function() 
			data.TargetCharacter = killerChar
			TweenService:Create(data.FlyValue, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Value = 1}):Play()
		end)
	end

	task.wait(0.5 + 3.0)

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

-- ================= HỆ THỐNG CHECK SOUND KÍCH HOẠT (ĐÃ FIX BUG 1 + TỐI ƯU) ================= --
local function connectSoundListener(character)
	if not character then return end
	
	-- Chỉ lắng nghe sound được thêm vào CHÍNH character của mình
	local conn = character.DescendantAdded:Connect(function(descendant)
		if not descendant:IsA("Sound") then return end
		
		local soundDigits = descendant.SoundId:match("%d+$")
		
		if soundDigits and TRIGGER_SOUND_IDS[soundDigits] then
			if not isAttacking and not isDying and isCurrentlyShedletsky then
				local targetKiller = getNearestKillerCharacter()
				if targetKiller then
					task.spawn(function()
						executeAttack(targetKiller)
					end)
				end
			end
		end
	end)
	
	table.insert(auraConnections, conn)
end

-- ================= HÀM QUẢN LÝ BẬT / TẮT AURA ================= --
local function cleanUpAura()
	isAuraActive = false 
	isCurrentlyShedletsky = false
	
	for _, conn in pairs(auraConnections) do
		if conn then conn:Disconnect() end
	end
	table.clear(auraConnections)
	
	clearSwords()
	
	isDying = false
	isAttacking = false
end

local function startAura()
	cleanUpAura() 
	isAuraActive = true
	
	task.spawn(function()
		-- ===== FIX BUG 2: TÌM ĐÚNG SHEDLETSKY CỦA LOCALPLAYER ===== --
		if not swordTemplate then
			-- Chờ character của mình load
			local myChar = localPlayer.Character or localPlayer.CharacterAdded:Wait()
			
			-- Kiểm tra character hiện tại có phải Shedletsky không
			if myChar.Name == "Shedletsky" then
				-- Tìm Sword TRONG character của mình (không phải của người khác)
				swordTemplate = myChar:WaitForChild("Sword", 5)
			else
				-- Nếu hiện tại không phải Shedletsky, chờ CharacterAdded
				local newChar = localPlayer.CharacterAdded:Wait()
				if newChar.Name == "Shedletsky" then
					swordTemplate = newChar:WaitForChild("Sword", 5)
				end
			end
		end
		-- ===== HẾT FIX BUG 2 =====
		
		if not swordTemplate then
			warn("Không tìm thấy kiếm gốc!")
			return
		end
		
		if not isAuraActive then return end 
		
		-- ===== FIX + TỐI ƯU CHECK SOUND ===== --
		-- Kết nối sound listener cho character hiện tại
		if localPlayer.Character then
			connectSoundListener(localPlayer.Character)
		end
		-- ===== HẾT FIX + TỐI ƯU =====
		
		table.insert(auraConnections, localPlayer.CharacterAdded:Connect(function(newChar)
			isCurrentlyShedletsky = false 
			isDying = false
			isAttacking = false
			clearSwords()
			
			-- Kết nối lại sound listener cho character mới
			connectSoundListener(newChar)
		end))
		
		table.insert(auraConnections, RunService.RenderStepped:Connect(function()  
			local myCharacter = localPlayer.Character  
			if not myCharacter then return end
			
			local isShedletskyNow = (myCharacter.Name == "Shedletsky")
			
			if isShedletskyNow and not isCurrentlyShedletsky then
				isCurrentlyShedletsky = true
				isDying = false
				isAttacking = false
				clearSwords()
				
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
				
			elseif not isShedletskyNow and isCurrentlyShedletsky then
				isCurrentlyShedletsky = false
				clearSwords()
			end

			if not isCurrentlyShedletsky then return end
			
			local myHumanoid = myCharacter:FindFirstChild("Humanoid")
			local myRoot = myCharacter:FindFirstChild("HumanoidRootPart")
			if not myHumanoid or not myRoot then return end
			
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
		end))
	end)
end

-- XUẤT HÀM RA GETGENV ĐỂ TRUY CẬP ĐƯỢC TỪ FILE KHÁC
getgenv().HutaoAuraSword.Start = startAura
getgenv().HutaoAuraSword.Stop = cleanUpAura
