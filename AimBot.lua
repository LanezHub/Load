local client = game:GetService('Players').LocalPlayer;
local set_identity = (type(syn) == 'table' and syn.set_thread_identity) or setidentity or setthreadcontext
local function fail(r) return client:Kick(r) end
local function UrlLoad(url)
	local success, result = pcall(game.HttpGet, game, url)
	if (not success) then
		return fail(string.format('Failed to GET url %q for reason: %q', url, tostring(result)))
	end
	local fn, err = loadstring(result)
	if (type(fn) ~= 'function') then
		return fail(string.format('Failed to loadstring url %q for reason: %q', url, tostring(err)))
	end
	local results = {pcall(fn)}
	if (not results[1]) then
		return fail(string.format('Failed to initialize url %q for reason: %q', url, tostring(results[2])))
	end
	return unpack(results, 2)
end

if type(set_identity) ~= 'function' then return fail('Unsupported exploit (missing "set_thread_identity")') end
if type(getconnections) ~= 'function' then return fail('Unsupported exploit (missing "getconnections")') end
if type(getloadedmodules) ~= 'function' then return fail('Unsupported exploit (misssing "getloadedmodules")') end
if type(getgc) ~= 'function' then return fail('Unsupported exploit (misssing "getgc")') end

local deltaX = deltaX or 0.385
local deltaY = deltaX or 0.5

local gameValues = UrlLoad("https://raw.githubusercontent.com/LanezHub/Load/main/GameValues")

local detectedGame = game.GameId
local values = gameValues[detectedGame or "POPCat"] or {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local player = Players.LocalPlayer
local isBB = detectedGame == 1168263273
local tshell
if isBB then
	tshell = require(ReplicatedStorage:WaitForChild("TS")) -- thanks BB :3
end

local module = game:GetObjects("rbxassetid://8309102950")[1]
module.Parent = game.CoreGui
local chamTemplate = module.ChamTemplate
local chams = module.Chams
local infos = module.InfoBillboards

-- deep copy a table
function DeepCopy(orig)
	local orig_type = type(orig)
	local copy
	if orig_type == 'table' then
		copy = {}
		for orig_key, orig_value in next, orig, nil do
			copy[DeepCopy(orig_key)] = DeepCopy(orig_value)
		end
		setmetatable(copy, DeepCopy(getmetatable(orig)))
	else --// number, string, boolean, etc
		copy = orig
	end
	return copy
end

if not getgenv().config then
	getgenv().config = {
		keybinds = {
			aim1 = "MouseButton2";
			aim2 = "MouseButton3";
		};
		aimbot = {
			enabled = true;
			ignoreTeam = false;
			prediction = 3;
			showRange = true;
			range = 60;
			aimPart1 = "Head";
			aimPart2 = "HumanoidRootPart";
			mouseOffsetX = 0;
			mouseOffsetY = 0;
		};
		esp = {
			enabled = true;
			chamsEnabled = false;
			infoEnabled = true;
			ffa = false;
			showFriendlies = false;
			showTeamColor = false;
			chamsTransparency = 0.5;
		};
	}
else wait() end


local gameSettings = UserSettings():GetService("UserGameSettings")
local camera = function()
	return workspace.Camera or workspace.CurrentCamera 
end
local playerGui = player.PlayerGui
local mouse = player:GetMouse()
local mouseX = mouse.X
local mouseY = mouse.Y + 36
local internalMousePos = nil
local internalOffsetX = 0
local internalOffsetY = 0
local windowZ = 1
local scriptTerminated = false
local aiming1 = false
local aiming2 = false
local aiming = false
local target = nil

local rad = math.rad
local deg = math.deg
local clamp = math.clamp
local abs = math.abs
local floor = math.floor

local keybindFuncs = {
	aim1 = function (isBegin)
		aiming1 = isBegin
	end;
	aim2 = function (isBegin)
		aiming2 = isBegin
	end;
}

getgenv().fov_circle = Drawing.new("Circle")
local fov_circle = getgenv().fov_circle
fov_circle.Thickness = 1
fov_circle.NumSides = 100
fov_circle.Radius = 60
fov_circle.Filled = false
fov_circle.Visible = false
fov_circle.ZIndex = 999
fov_circle.Transparency = 1
fov_circle.Color = Color3.fromRGB(255, 255, 255)

-- IsVisible Wall
local function IsVisible(v)
	local MyChar = v.Me
	local Ray = Ray.new(camera.CFrame.p, (v.Target[getgenv().config.aimbot.aimPart1].Position - camera.CFrame.p).unit * 2048)
	return workspace:FindPartOnRayWithIgnoreList(Ray, {MyChar:FindFirstChild("HumanoidRootPart")})
end
-- wrapper function for mousemoverel / Input.MoveMouse
function MoveMouse(x, y)
	if not mousemoverel then
		if Input then
			Input.MoveMouse(x, y)
		end
	else
		mousemoverel(x, y)
	end
end

-- returns the mouse sensitivity
function GetMouseSens ()
	return gameSettings.MouseSensitivity
end

-- rotates the camera by a given angle (in degrees)
function RotateCamera (x, y)
	local sens = GetMouseSens()

	local _deltaX = deltaX
	local _deltaY = deltaY

	if gameAiming then
		_deltaX = aimDeltaX
		_deltaY = aimDeltaY
	end

	local pixelX = x / sens / _deltaX / UserInputService.MouseDeltaSensitivity
	local pixelY = y / sens / _deltaY / UserInputService.MouseDeltaSensitivity

	MoveMouse(pixelY, pixelX)
end

-- automatically centers the mouse on a certain world position
function LookAt (pos)
	local ray = camera:ViewportPointToRay(mouseX, mouseY)
	local tX, tY, tZ = CFrame.new(camera.CFrame.Position, pos):ToOrientation()
	local cX, cY, cZ = CFrame.new(camera.CFrame.Position, camera.CFrame.Position + ray.Direction):ToOrientation()

	local xDiff = deg(cX) - deg(tX)
	local yDiff = deg(cY) - deg(tY)
	if yDiff > 180 then
		yDiff -= 360
	elseif yDiff < -180 then
		yDiff += 360
	end
	local dampening = 0.9
	RotateCamera(xDiff * dampening, yDiff * dampening)
end

-- updates variables
function UpdateValues (deltaTime)
	deltaTime = deltaTime or 1 / 60
	aiming = aiming1 or aiming2
	camera = workspace.CurrentCamera
	mouse = player:GetMouse()
	if not internalMousePos then
		mouseX = mouse.X + getgenv().config.aimbot.mouseOffsetX + internalOffsetX
		mouseY = mouse.Y + 36 + getgenv().config.aimbot.mouseOffsetY + internalOffsetY
	else
		mouseX = internalMousePos.X
		mouseY = internalMousePos.Y
	end
end

local draggables = {}

local elements = {}
local bindButtons = {}

-- esp functions

function ChamsEnabled ()
	return getgenv().config.esp.enabled and getgenv().config.esp.chamsEnabled
end

function InfoEnabled ()
	return getgenv().config.esp.enabled and getgenv().config.esp.infoEnabled
end

function GetInfoString (plr)
	local char = GetChar(plr)
	if char then
		local health
		local maxHealth = 100
		if isBB then
			health = 150
			if char.Parent:FindFirstChild("Health") then
				health = char.Parent.Health.Value
			end
			maxHealth = 150
		else
			if char:FindFirstChild("Humanoid") then
				health = char.Humanoid.Health
				maxHealth = char.Humanoid.MaxHealth
			end
		end

		local pos = GetPlayerPos(plr) or camera.CFrame.Position
		local dist = floor((pos - camera.CFrame.Position).Magnitude)
		if health then
			return plr.Name .. "\n" .. dist .. " studs [" .. floor(health) .. "/" .. floor(maxHealth) .. "]"
		else
			return plr.Name .. "\n" .. dist .. " studs"
		end
	else
		return plr.Name .. "\n(NO CHARACTER DETECTED)"
	end
end

function IsEnemyESP (plr)
	if not isBB then
		return plr.Team ~= player.Team or getgenv().config.esp.ffa
	else
		return tshell.Teams:GetPlayerTeam(plr) ~= tshell.Teams:GetPlayerTeam(player) or getgenv().config.esp.ffa
	end
end

function IsVisibleESP (plr)
	return (getgenv().config.esp.showFriendlies or IsEnemyESP(plr)) and not IsDead(plr)
end

function GetColor (plr)
	if getgenv().config.esp.showTeamColor then
		return plr.TeamColor.Color
	elseif IsEnemyESP(plr) then
		return Color3.new(1, 0, 0) -- enemy color
	else
		return Color3.new(0, 1, 0) -- friendly color
	end
end

local infoTable = {}

function UpdateInfos ()
	if InfoEnabled() then
		for i, plr in pairs(Players:GetPlayers()) do
			if not infoTable[plr.UserId] and GetChar(plr) and IsVisibleESP(plr) then
				ApplyInfo(plr)
			end
		end
		for id, billboard in pairs(infoTable) do
			local plr = Players:GetPlayerByUserId(id)
			if not plr or not IsVisibleESP(plr) or not billboard.Parent then
				billboard:Destroy()
				infoTable[id] = nil
				continue
			end

			local char = GetChar(plr)
			local part = billboard.Adornee
			if not part or not part.Parent or (part.Name ~= getgenv().config.aimbot.aimPart1 and part.Name ~= getgenv().config.aimbot.aimPart2) or (char and not part:IsDescendantOf(char)) then
				part = GetPlayerPosPart(plr)
			end
			local color = GetColor(plr)
			billboard.Label.TextColor3 = color or Color3.new(1, 0, 1)
			billboard.Label.Text = tostring(GetInfoString(plr))

			if part then
				billboard.Enabled = true
				billboard.Adornee = part
			else
				billboard.Enabled = false
			end
			RunService.RenderStepped:Wait()
			RunService.RenderStepped:Wait()
		end
	else
		infos:ClearAllChildren()
		infoTable = {}
	end
end

function ApplyInfo (plr)
	if plr == player then return end
	infoTable[plr.UserId] = infoTable[plr.UserId] or module.InfoTemplate:Clone()
	local billboard = infoTable[plr.UserId]
	billboard.Parent = infos
	billboard.Name = plr.Name
end

local chamTable = {}
function UpdateChams ()
	if ChamsEnabled() then
		for i, plr in pairs(Players:GetPlayers()) do
			if not chamTable[plr.UserId] and GetChar(plr) and IsVisibleESP(plr) then
				ApplyChams(plr)
			end
		end
		for id, arr in pairs(chamTable) do
			local plr = Players:GetPlayerByUserId(id)
			local char = GetChar(plr)
			if not plr or not IsVisibleESP(plr) or (arr.__CHAR and char ~= arr.__CHAR) then
				for part, cham in pairs(arr) do
					if part == "__CHAR" then continue end
					cham:Destroy()
				end
				chamTable[id] = nil
				continue
			end

			local color = GetColor(plr)
			for part, cham in pairs(arr) do
				if part == "__CHAR" then continue end
				for i, surface in pairs(cham:GetChildren()) do
					surface.Frame.BackgroundTransparency = getgenv().config.esp.chamsTransparency
					surface.Frame.BackgroundColor3 = color
				end
			end
			RunService.RenderStepped:Wait()
			RunService.RenderStepped:Wait()
		end
	else
		chams:ClearAllChildren()
		chamTable = {}
	end
end

function ApplyChamsToPart (part)
	local c = chamTemplate:Clone()
	c.Parent = chams
	c.Name = part:GetFullName()
	for i, surface in pairs(c:GetChildren()) do
		surface.Adornee = part
	end
	part.AncestryChanged:Connect(function()
		if part.Parent == nil then
			c:Destroy()
		end
	end)
	return c
end

function ApplyChams (plr)
	if plr == player then return end
	chamTable[plr.UserId] = chamTable[plr.UserId] or {}
	local arr = chamTable[plr.UserId]
	local char = GetChar(plr)
	if char then
		arr.__CHAR = char	
		for i, part in pairs(char:GetChildren()) do
			if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" and not arr[part] then
				arr[part] = ApplyChamsToPart(part)
			end
		end
	end
end

-- aimbot functions
function IsEnemyAimbot (plr)
	if getgenv().config.aimbot.ignoreTeam then
		return true
	end
	if not isBB then
		return plr.Team ~= player.Team
	else
		return tshell.Teams:GetPlayerTeam(plr) ~= tshell.Teams:GetPlayerTeam(player)
	end
end

function GetPlayerPosPart(plr)
	local aimbot = getgenv().config.aimbot
	local names = {aimbot.aimPart1, aimbot.aimPart2}
	local char = GetChar(plr)
	if char then
		if not IsDead(plr) then
			local baseParts = {}
			for i, part in pairs(char:GetDescendants()) do
				if part:IsA("BasePart") and not baseParts[part.Name] then
					baseParts[part.Name] = part
				end
			end
			for i, name in pairs(names) do
				if baseParts[name] then
					return baseParts[name]
				end
			end
		end
	end
end

function GetPlayerPos (plr)
	return (GetPlayerPosPart(plr) or {}).Position
end

-- misc
function IsDead (plr)
	local char = GetChar(plr)
	return not (
		char and char.Parent and (
			(char.Parent:FindFirstChild("Health") and char.Parent.Health:IsA("NumberValue") and char.Parent.Health.Value <= 0) or
				(not char:FindFirstChild("Humanoid") or char.Humanoid:GetState() ~= Enum.HumanoidStateType.Dead)
		)
	)
end

function GetChar (plr)
	if not plr then
		return
	end
	if not isBB then
		return plr.Character
	else
		local char = tshell.Characters:GetCharacter(plr)
		return char and char:FindFirstChild("Body")
	end
end

--

local gameAimButton = gameAimButton or values.aimButton or Enum.UserInputType.MouseButton2
local gameAiming = false

local function onPressOrRelease (input, isBegin)
	for name, bind in pairs(getgenv().config.keybinds) do
		if (input.KeyCode and input.KeyCode.Name == bind) or (input.UserInputType and input.UserInputType.Name == bind) then
			keybindFuncs[name](isBegin)
		end
	end
	if input.KeyCode == gameAimButton or input.UserInputType == gameAimButton then
		gameAiming = isBegin
	end
end
local inputBeganSignal = UserInputService.InputBegan:Connect(function(input, gpc)
	if not gpc then
		onPressOrRelease(input, true)
	end
end)
local inputEndedSignal = UserInputService.InputEnded:Connect(function(input, gpc)
	if not gpc then
		onPressOrRelease(input, false)
	end
end)

deltaX = values.deltaX or deltaX
deltaY = values.deltaY or deltaY
local aimDeltaX = aimDeltaX or values.aimDeltaX or deltaX
local aimDeltaY = aimDeltaY or values.aimDeltaY or deltaY
if values.mouseOffsetX then
	internalOffsetX = values.mouseOffsetX
end
if values.mouseOffsetY then
	internalOffsetY = values.mouseOffsetY
end

-- aimbot + esp settings windows
UpdateValues()
local prevTargetDiff = nil
local prevCamRotation = nil

if detectedGame == 113491250 then
	-- PF Character Patcher Script by el3tric
	-- Thanks lmao i was pulling my hair out trying to figure it out
	local client = {}; do
		for i,v in pairs(getgc(true)) do
			if (type(v) == "table") then
				if rawget(v, "getbodyparts") then
					client.chartable = debug.getupvalue(v.getbodyparts, 1)
				end
			end
		end
	end

	game:GetService("RunService").RenderStepped:Connect(function()
		for i,v in pairs(game.Players:GetPlayers()) do
			if (v and client.chartable[v]) then
				local char = client.chartable[v]
				char.head.Parent.Name = v.Name
				v.Character = char.head.Parent
			end
		end
	end)
end

RunService:BindToRenderStep("TemporalMainLoop", 1, function(deltaTime)
	UpdateValues()
	local function f (num)
		return math.floor(num * 1000) / 1000
	end

	if scriptTerminated then
		RunService:UnbindFromRenderStep("TemporalMainLoop")
		return
	end

	if detectedGame == 1168263273 then
		if player.PlayerGui:FindFirstChild("Core_UI") then
			local core = player.PlayerGui.Core_UI
			if core.Center_Dot.Visible then
				internalMousePos = core.Center_Dot.Dot.AbsolutePosition + core.Center_Dot.Dot.AbsoluteSize / 2 + Vector2.new(0, 36)
			else
				internalMousePos = core.Crosshairs.Center.AbsolutePosition + core.Crosshairs.Center.AbsoluteSize / 2 + Vector2.new(0, 36)
			end
		else
			internalMousePos = nil
		end
	end

	-- aimbot aiming
	local aimbot = getgenv().config.aimbot
	local char = GetChar(player)
	if aimbot.enabled and char then
		if aiming and target then
			local pos = GetPlayerPos(target)
			if pos then
				local diffDiff = Vector3.new()
				local targetDiff = char:GetPivot().Position - pos
				if prevTargetDiff then
					diffDiff = targetDiff - prevTargetDiff
				end
				LookAt(pos - diffDiff * aimbot.prediction)
				prevTargetDiff = targetDiff
			else

			end
		else
			prevTargetDiff = nil
		end
	else wait() end
	-- esp update
	local esp = getgenv().config.esp
	-- range circle update
	fov_circle.Position = Vector2.new(mouseX, mouseY)
	fov_circle.Visible = getgenv().config.aimbot.enabled and getgenv().config.aimbot.showRange
	fov_circle.Size = UDim2.fromOffset(getgenv().config.aimbot.range, getgenv().config.aimbot.range)
end)

spawn(function()
	while not scriptTerminated do
		UpdateChams()
		wait(0.25)
		--RunService.RenderStepped:Wait()
	end
end)

spawn(function()
	while not scriptTerminated do
		UpdateInfos()
		RunService.RenderStepped:Wait()
	end
end)

-- aimbot targetting loop
while true do wait(0.1)
	if scriptTerminated then
		break
	end
	local aimbot = getgenv().config.aimbot
	if aimbot.enabled and aiming then
		if target then
			if not IsDead(target) then

			else
				target = nil
			end
		else
			local closest = {
				player = nil;
				distance = math.huge;
			}

			for i, plr in pairs(Players:GetPlayers()) do
				if plr ~= player and IsEnemyAimbot(plr) and not IsDead(plr) then
					local pos = GetPlayerPos(plr)
					if pos then
						local point = camera:WorldToViewportPoint(pos)
						local dist = (Vector2.new(mouseX, mouseY) - Vector2.new(point.X, point.Y)).Magnitude
						if point.Z > 0 and dist <= aimbot.range then
							local dist3 = (pos - camera.CFrame.Position).Magnitude
							if dist3 < closest.distance then
								closest.player = plr
								closest.distance = dist3
							end
						end
					end
				end
			end
			target = closest.player
		end
	else
		target = nil
	end
end

return gameValues
