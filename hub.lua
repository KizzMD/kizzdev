--[[
    KizzDev | Legends Battlegrounds  v2
    UI custom (tanpa library) - tema ungu KizzDev
    Tombol K (melayang) / RightCtrl = buka tutup menu
    Kontrol game: Q dash, F block, G awaken, M1 klik kiri, skill 1-4
]]

-- ============ SERVICES ============
local Players        = game:GetService("Players")
local RunService     = game:GetService("RunService")
local UIS            = game:GetService("UserInputService")
local TweenService   = game:GetService("TweenService")
local TeleportService= game:GetService("TeleportService")
local HttpService    = game:GetService("HttpService")
local Lighting       = game:GetService("Lighting")
local VirtualUser    = game:GetService("VirtualUser")
local VIM            = game:GetService("VirtualInputManager")
local Stats          = game:GetService("Stats")
local Workspace      = game:GetService("Workspace")

local LP  = Players.LocalPlayer
local Cam = Workspace.CurrentCamera

-- ============ BERSIHKAN VERSI LAMA ============
local function guiParent()
    local ok, p = pcall(function() return (gethui and gethui()) or game:GetService("CoreGui") end)
    if ok and p then return p end
    return LP:WaitForChild("PlayerGui")
end
local PARENT = guiParent()
pcall(function()
    local old = PARENT:FindFirstChild("KizzDev_LB")
    if old then old:Destroy() end
end)

-- ============ STATE / CONFIG ============
local Flags, Saved, Persist = {}, {}, {}
local CFG = "KizzDev/LegendsBattlegrounds.json"
pcall(function()
    if isfile and isfile(CFG) then Saved = HttpService:JSONDecode(readfile(CFG)) end
end)

local saveQueued = false
local function queueSave()
    if not writefile or saveQueued then return end
    saveQueued = true
    task.delay(1.5, function()
        saveQueued = false
        pcall(function()
            if makefolder and not isfolder("KizzDev") then makefolder("KizzDev") end
            local d = {}
            for k in pairs(Persist) do d[k] = Flags[k] end
            writefile(CFG, HttpService:JSONEncode(d))
        end)
    end)
end

local Running = true
local Conns = {}
local function Connect(sig, fn)
    local c = sig:Connect(fn)
    Conns[#Conns + 1] = c
    return c
end

-- ============ HELPER GAME ============
local function Root(c) c = c or LP.Character return c and c:FindFirstChild("HumanoidRootPart") end
local function Hum(c) c = c or LP.Character return c and c:FindFirstChildOfClass("Humanoid") end

local function IsEnemy(p)
    if p == LP or not p.Character then return false end
    local h, r = Hum(p.Character), Root(p.Character)
    return h and r and h.Health > 0
end

local function NearestEnemy(maxDist)
    local r = Root()
    if not r then return end
    local best, bd = nil, maxDist or math.huge
    for _, p in ipairs(Players:GetPlayers()) do
        if IsEnemy(p) then
            local d = (Root(p.Character).Position - r.Position).Magnitude
            if d < bd then best, bd = p, d end
        end
    end
    return best, bd
end

local function Tap(key, t)
    VIM:SendKeyEvent(true, key, false, game)
    task.wait(t or 0.03)
    VIM:SendKeyEvent(false, key, false, game)
end

local function Click()
    local c = Cam.ViewportSize / 2
    VIM:SendMouseButtonEvent(c.X, c.Y, 0, true, game, 0)
    VIM:SendMouseButtonEvent(c.X, c.Y, 0, false, game, 0)
end

local ActionPrio = {
    [Enum.AnimationPriority.Action] = true, [Enum.AnimationPriority.Action2] = true,
    [Enum.AnimationPriority.Action3] = true, [Enum.AnimationPriority.Action4] = true,
}
local function IsAttacking(p)
    local h = p.Character and Hum(p.Character)
    local a = h and h:FindFirstChildOfClass("Animator")
    if not a then return false end
    for _, t in ipairs(a:GetPlayingAnimationTracks()) do
        if t.IsPlaying and ActionPrio[t.Priority] and t.WeightCurrent > 0 then return true end
    end
    return false
end

-- ============ FLY ============
local flyBV, flyBG
local function StopFly()
    if flyBV then flyBV:Destroy() flyBV = nil end
    if flyBG then flyBG:Destroy() flyBG = nil end
    local h = Hum()
    if h then h.PlatformStand = false end
end
local function StartFly()
    local r, h = Root(), Hum()
    if not r or not h then return end
    StopFly()
    flyBV = Instance.new("BodyVelocity")
    flyBV.MaxForce = Vector3.new(1e9, 1e9, 1e9)
    flyBV.Velocity = Vector3.zero
    flyBV.Parent = r
    flyBG = Instance.new("BodyGyro")
    flyBG.MaxTorque = Vector3.new(1e9, 1e9, 1e9)
    flyBG.P = 9e4
    flyBG.CFrame = r.CFrame
    flyBG.Parent = r
    h.PlatformStand = true
end

-- ============ ESP ============
local ESPData = {}
local Tracers = {}
local HasDrawing = (Drawing ~= nil and Drawing.new ~= nil)

local function ClearESP(p)
    local d = ESPData[p]
    if d then
        for _, o in pairs(d) do pcall(function() o:Destroy() end) end
        ESPData[p] = nil
    end
    if Tracers[p] then pcall(function() Tracers[p]:Remove() end) Tracers[p] = nil end
end

local function BuildESP(p)
    ClearESP(p)
    if p == LP or not p.Character then return end
    local head = p.Character:FindFirstChild("Head")
    local hl = Instance.new("Highlight")
    hl.Name = "KZ_ESP"
    hl.FillColor = Color3.fromRGB(150, 70, 255)
    hl.OutlineColor = Color3.new(1, 1, 1)
    hl.FillTransparency = 0.55
    hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    hl.Adornee = p.Character
    hl.Parent = p.Character
    local d = {hl = hl}
    if head then
        local bb = Instance.new("BillboardGui")
        bb.Name = "KZ_TAG"
        bb.Size = UDim2.fromOffset(140, 34)
        bb.StudsOffset = Vector3.new(0, 2.6, 0)
        bb.AlwaysOnTop = true
        bb.Adornee = head
        bb.Parent = head
        local tl = Instance.new("TextLabel")
        tl.Size = UDim2.fromScale(1, 1)
        tl.BackgroundTransparency = 1
        tl.TextColor3 = Color3.new(1, 1, 1)
        tl.TextStrokeTransparency = 0.3
        tl.Font = Enum.Font.GothamBold
        tl.TextSize = 12
        tl.Parent = bb
        d.bb, d.tl = bb, tl
    end
    ESPData[p] = d
end

local function RefreshESP()
    for _, p in ipairs(Players:GetPlayers()) do
        if Flags.ESP and p ~= LP then BuildESP(p) else ClearESP(p) end
    end
end

local function HookPlayer(p)
    if p == LP then return end
    Connect(p.CharacterAdded, function()
        task.wait(1)
        if Flags.ESP then BuildESP(p) end
    end)
end
for _, p in ipairs(Players:GetPlayers()) do HookPlayer(p) end
Connect(Players.PlayerAdded, HookPlayer)
Connect(Players.PlayerRemoving, ClearESP)

-- ============ ANTI LAG ============
local SavedFx = {}
local FxClass = {ParticleEmitter = true, Trail = true, Beam = true, Fire = true, Smoke = true, Sparkles = true}

local function KillFx(v, super)
    if v.Name == "KZ_ESP" or v.Name == "KZ_TAG" then return end
    local cn = v.ClassName
    if FxClass[cn] then
        if super then
            task.defer(function() pcall(function() v:Destroy() end) end)
        elseif v.Enabled then
            v.Enabled = false
            SavedFx[#SavedFx + 1] = v
        end
    elseif cn == "Explosion" then
        v.Visible = false
    elseif super then
        if v:IsA("BasePart") then
            if not v:IsA("Terrain") then
                v.Material = Enum.Material.SmoothPlastic
                v.Reflectance = 0
                v.CastShadow = false
            end
        elseif cn == "Decal" or cn == "Texture" then
            v.Transparency = 1
        elseif cn == "SurfaceAppearance" then
            task.defer(function() pcall(function() v:Destroy() end) end)
        elseif cn == "PointLight" or cn == "SpotLight" or cn == "SurfaceLight" then
            v.Enabled = false
        elseif cn == "Accessory" and v.Parent ~= LP.Character then
            task.defer(function() pcall(function() v:Destroy() end) end)
        end
    end
end

local function LightingLow(super)
    pcall(function()
        Lighting.GlobalShadows = false
        Lighting.FogEnd = 9e9
        for _, e in ipairs(Lighting:GetChildren()) do
            if e:IsA("PostEffect") then e.Enabled = false
            elseif e:IsA("Atmosphere") then e.Density = 0 e.Haze = 0
            elseif super and (e:IsA("Sky") or e:IsA("Clouds")) then e:Destroy() end
        end
        if super then
            Lighting.Brightness = 1
            Lighting.EnvironmentDiffuseScale = 0
            Lighting.EnvironmentSpecularScale = 0
            if sethiddenproperty then
                pcall(sethiddenproperty, Lighting, "Technology", Enum.Technology.Compatibility)
            end
            local t = Workspace.Terrain
            t.WaterWaveSize = 0 t.WaterWaveSpeed = 0 t.WaterReflectance = 0 t.WaterTransparency = 1
            if sethiddenproperty then pcall(sethiddenproperty, t, "Decoration", false) end
            settings().Rendering.QualityLevel = Enum.QualityLevel.Level01
        end
    end)
end

local LagConn
local function ProcessAll(super)
    task.spawn(function()
        local n = 0
        for _, v in ipairs(Workspace:GetDescendants()) do
            if not Running then return end
            pcall(KillFx, v, super)
            n += 1
            if n % 300 == 0 then task.wait() end
        end
        LightingLow(super)
    end)
end

local function SetLive(super)
    if LagConn then LagConn:Disconnect() LagConn = nil end
    LagConn = Workspace.DescendantAdded:Connect(function(v)
        if Flags.AntiLag or Flags.SuperLag then pcall(KillFx, v, Flags.SuperLag) end
    end)
    Conns[#Conns + 1] = LagConn
end

local function RestoreFx()
    for _, v in ipairs(SavedFx) do
        pcall(function() if v.Parent then v.Enabled = true end end)
    end
    SavedFx = {}
    pcall(function() Lighting.GlobalShadows = true end)
end

-- ============================================================
--                           UI
-- ============================================================
local C = {
    bg = Color3.fromRGB(13, 13, 18), side = Color3.fromRGB(17, 17, 24),
    row = Color3.fromRGB(24, 24, 33), rowHi = Color3.fromRGB(32, 32, 44),
    acc = Color3.fromRGB(150, 70, 255), acc2 = Color3.fromRGB(215, 90, 255),
    text = Color3.fromRGB(236, 236, 244), sub = Color3.fromRGB(135, 135, 155),
    line = Color3.fromRGB(40, 40, 56), off = Color3.fromRGB(52, 52, 70),
}

local function new(class, props, kids)
    local o = Instance.new(class)
    local parent
    for k, v in pairs(props or {}) do
        if k == "Parent" then parent = v else o[k] = v end
    end
    for _, c in ipairs(kids or {}) do c.Parent = o end
    if parent then o.Parent = parent end
    return o
end
local function corner(o, r) new("UICorner", {CornerRadius = UDim.new(0, r or 6), Parent = o}) end
local function stroke(o, col, th, tr)
    new("UIStroke", {Color = col or C.line, Thickness = th or 1, Transparency = tr or 0, Parent = o,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border})
end
local function tween(o, t, props)
    TweenService:Create(o, TweenInfo.new(t, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), props):Play()
end

local Gui = new("ScreenGui", {Name = "KizzDev_LB", ResetOnSpawn = false, ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
    DisplayOrder = 999, IgnoreGuiInset = true, Parent = PARENT})

-- Toast
local Toasts = new("Frame", {Parent = Gui, BackgroundTransparency = 1, AnchorPoint = Vector2.new(1, 1),
    Position = UDim2.new(1, -14, 1, -14), Size = UDim2.fromOffset(230, 300)})
new("UIListLayout", {Parent = Toasts, VerticalAlignment = Enum.VerticalAlignment.Bottom,
    HorizontalAlignment = Enum.HorizontalAlignment.Right, Padding = UDim.new(0, 6)})

local function Notify(msg)
    local f = new("Frame", {Parent = Toasts, BackgroundColor3 = C.row, Size = UDim2.fromOffset(230, 0),
        AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1})
    corner(f, 6) stroke(f, C.acc, 1, 0.4)
    new("UIPadding", {Parent = f, PaddingTop = UDim.new(0, 8), PaddingBottom = UDim.new(0, 8),
        PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10)})
    local l = new("TextLabel", {Parent = f, BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y, Text = msg, TextWrapped = true, Font = Enum.Font.Gotham,
        TextSize = 12, TextColor3 = C.text, TextXAlignment = Enum.TextXAlignment.Left, TextTransparency = 1})
    tween(f, 0.2, {BackgroundTransparency = 0}) tween(l, 0.2, {TextTransparency = 0})
    task.delay(2.8, function()
        if f.Parent then
            tween(f, 0.25, {BackgroundTransparency = 1}) tween(l, 0.25, {TextTransparency = 1})
            task.wait(0.3) f:Destroy()
        end
    end)
end

-- Window
local Main = new("Frame", {Parent = Gui, Name = "Main", BackgroundColor3 = C.bg, AnchorPoint = Vector2.new(0.5, 0.5),
    Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(580, 370), ClipsDescendants = true})
corner(Main, 10) stroke(Main, C.line, 1)
local Scale = new("UIScale", {Parent = Main})
local function fitScale()
    local v = Cam.ViewportSize
    Scale.Scale = math.clamp(math.min(v.X / 640, v.Y / 420), 0.5, 1)
end
fitScale()
Connect(Cam:GetPropertyChangedSignal("ViewportSize"), fitScale)

local Top = new("Frame", {Parent = Main, BackgroundColor3 = C.side, Size = UDim2.new(1, 0, 0, 40), BorderSizePixel = 0})
new("Frame", {Parent = Top, BackgroundColor3 = C.acc, Position = UDim2.new(0, 0, 1, -1), Size = UDim2.new(1, 0, 0, 1),
    BorderSizePixel = 0}, {new("UIGradient", {Color = ColorSequence.new(C.acc, C.acc2)})})
local Title = new("TextLabel", {Parent = Top, BackgroundTransparency = 1, Position = UDim2.fromOffset(14, 0),
    Size = UDim2.fromOffset(90, 40), Text = "KIZZDEV", Font = Enum.Font.GothamBlack, TextSize = 18,
    TextColor3 = Color3.new(1, 1, 1), TextXAlignment = Enum.TextXAlignment.Left})
new("UIGradient", {Parent = Title, Color = ColorSequence.new(C.acc, C.acc2)})
new("TextLabel", {Parent = Top, BackgroundTransparency = 1, Position = UDim2.fromOffset(104, 0),
    Size = UDim2.fromOffset(200, 40), Text = "Legends Battlegrounds", Font = Enum.Font.Gotham, TextSize = 12,
    TextColor3 = C.sub, TextXAlignment = Enum.TextXAlignment.Left})
local StatLbl = new("TextLabel", {Parent = Top, BackgroundTransparency = 1, AnchorPoint = Vector2.new(1, 0),
    Position = UDim2.new(1, -78, 0, 0), Size = UDim2.fromOffset(150, 40), Text = "-- FPS | -- ms",
    Font = Enum.Font.GothamMedium, TextSize = 11, TextColor3 = C.sub, TextXAlignment = Enum.TextXAlignment.Right})

local function topBtn(txt, x, col)
    local b = new("TextButton", {Parent = Top, AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, x, 0.5, 0),
        Size = UDim2.fromOffset(26, 26), BackgroundColor3 = C.row, Text = txt, Font = Enum.Font.GothamBold,
        TextSize = 14, TextColor3 = C.text, AutoButtonColor = false})
    corner(b, 6)
    b.MouseEnter:Connect(function() tween(b, 0.12, {BackgroundColor3 = col}) end)
    b.MouseLeave:Connect(function() tween(b, 0.12, {BackgroundColor3 = C.row}) end)
    return b
end
local BtnMin = topBtn("–", -40, C.rowHi)
local BtnClose = topBtn("×", -10, Color3.fromRGB(190, 50, 70))

local Side = new("Frame", {Parent = Main, BackgroundColor3 = C.side, Position = UDim2.fromOffset(0, 41),
    Size = UDim2.new(0, 124, 1, -41), BorderSizePixel = 0})
new("UIListLayout", {Parent = Side, Padding = UDim.new(0, 3)})
new("UIPadding", {Parent = Side, PaddingTop = UDim.new(0, 8), PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8)})

local Content = new("Frame", {Parent = Main, BackgroundTransparency = 1, Position = UDim2.fromOffset(124, 41),
    Size = UDim2.new(1, -124, 1, -41)})

-- drag
local function makeDraggable(handle, target)
    local dragging, start, startPos
    handle.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
            dragging, start, startPos = true, i.Position, target.Position
        end
    end)
    Connect(UIS.InputChanged, function(i)
        if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
            local d = i.Position - start
            target.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
        end
    end)
    Connect(UIS.InputEnded, function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)
end
makeDraggable(Top, Main)

-- Tombol melayang
local Float = new("TextButton", {Parent = Gui, Size = UDim2.fromOffset(42, 42), Position = UDim2.new(0, 14, 0.4, 0),
    BackgroundColor3 = C.bg, Text = "K", Font = Enum.Font.GothamBlack, TextSize = 20, TextColor3 = C.acc2,
    AutoButtonColor = false, Visible = false})
corner(Float, 21) stroke(Float, C.acc, 2)
makeDraggable(Float, Float)

local function setMenu(v)
    Main.Visible = v
    Float.Visible = not v
end
local floatDown
Float.MouseButton1Click:Connect(function() setMenu(true) end)
BtnMin.MouseButton1Click:Connect(function() setMenu(false) end)
Connect(UIS.InputBegan, function(i, gp)
    if not gp and i.KeyCode == Enum.KeyCode.RightControl then setMenu(not Main.Visible) end
end)

-- Tabs
local Tabs, ActiveTab = {}, nil
local function newTab(name)
    local btn = new("TextButton", {Parent = Side, Size = UDim2.new(1, 0, 0, 32), BackgroundColor3 = C.row,
        BackgroundTransparency = 1, Text = "   " .. name, Font = Enum.Font.GothamMedium, TextSize = 13,
        TextColor3 = C.sub, TextXAlignment = Enum.TextXAlignment.Left, AutoButtonColor = false})
    corner(btn, 6)
    local bar = new("Frame", {Parent = btn, BackgroundColor3 = C.acc, Size = UDim2.new(0, 3, 0.6, 0),
        Position = UDim2.new(0, 0, 0.2, 0), Visible = false, BorderSizePixel = 0})
    corner(bar, 2)
    local page = new("ScrollingFrame", {Parent = Content, BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1),
        CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollBarThickness = 3,
        ScrollBarImageColor3 = C.acc, BorderSizePixel = 0, Visible = false})
    new("UIListLayout", {Parent = page, Padding = UDim.new(0, 6)})
    new("UIPadding", {Parent = page, PaddingTop = UDim.new(0, 10), PaddingLeft = UDim.new(0, 10),
        PaddingRight = UDim.new(0, 12), PaddingBottom = UDim.new(0, 10)})
    local function select()
        for _, t in pairs(Tabs) do
            t.page.Visible = false t.bar.Visible = false
            tween(t.btn, 0.15, {BackgroundTransparency = 1, TextColor3 = C.sub})
        end
        page.Visible = true bar.Visible = true
        tween(btn, 0.15, {BackgroundTransparency = 0, TextColor3 = C.text})
    end
    btn.MouseButton1Click:Connect(select)
    Tabs[name] = {btn = btn, page = page, bar = bar, select = select}
    return page
end

-- Komponen
local function Section(page, text)
    local l = new("TextLabel", {Parent = page, BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 22),
        Text = string.upper(text), Font = Enum.Font.GothamBold, TextSize = 11, TextColor3 = C.acc2,
        TextXAlignment = Enum.TextXAlignment.Left})
    new("UIPadding", {Parent = l, PaddingTop = UDim.new(0, 6)})
end

local function Row(page, h)
    local f = new("Frame", {Parent = page, BackgroundColor3 = C.row, Size = UDim2.new(1, 0, 0, h or 34)})
    corner(f, 7)
    return f
end
local function rowLabel(f, text, w)
    return new("TextLabel", {Parent = f, BackgroundTransparency = 1, Position = UDim2.fromOffset(12, 0),
        Size = UDim2.new(w or 1, -24, 0, 34), Text = text, Font = Enum.Font.Gotham, TextSize = 13,
        TextColor3 = C.text, TextXAlignment = Enum.TextXAlignment.Left})
end

local function Toggle(page, text, flag, cb)
    Flags[flag] = false
    local f = Row(page, 34)
    rowLabel(f, text)
    local sw = new("Frame", {Parent = f, AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -12, 0.5, 0),
        Size = UDim2.fromOffset(38, 20), BackgroundColor3 = C.off})
    corner(sw, 10)
    local knob = new("Frame", {Parent = sw, Size = UDim2.fromOffset(14, 14), Position = UDim2.fromOffset(3, 3),
        BackgroundColor3 = Color3.new(1, 1, 1)})
    corner(knob, 7)
    local hit = new("TextButton", {Parent = f, BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Text = ""})
    local function set(v)
        Flags[flag] = v
        tween(sw, 0.15, {BackgroundColor3 = v and C.acc or C.off})
        tween(knob, 0.15, {Position = v and UDim2.fromOffset(21, 3) or UDim2.fromOffset(3, 3)})
        if cb then task.spawn(cb, v) end
    end
    hit.MouseButton1Click:Connect(function() set(not Flags[flag]) end)
    return set
end

local function Slider(page, text, flag, min, max, default, step, cb)
    step = step or 1
    local v = Saved[flag]
    if type(v) ~= "number" then v = default end
    Flags[flag] = v
    Persist[flag] = true
    local f = Row(page, 48)
    rowLabel(f, text)
    local val = new("TextLabel", {Parent = f, BackgroundTransparency = 1, AnchorPoint = Vector2.new(1, 0),
        Position = UDim2.new(1, -12, 0, 0), Size = UDim2.fromOffset(60, 30), Text = tostring(v),
        Font = Enum.Font.GothamMedium, TextSize = 12, TextColor3 = C.acc2, TextXAlignment = Enum.TextXAlignment.Right})
    local track = new("Frame", {Parent = f, Position = UDim2.new(0, 12, 0, 34), Size = UDim2.new(1, -24, 0, 5),
        BackgroundColor3 = C.off})
    corner(track, 3)
    local fill = new("Frame", {Parent = track, Size = UDim2.fromScale((v - min) / (max - min), 1), BackgroundColor3 = C.acc})
    corner(fill, 3)
    new("UIGradient", {Parent = fill, Color = ColorSequence.new(C.acc, C.acc2)})
    local knob = new("Frame", {Parent = fill, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(1, 0.5),
        Size = UDim2.fromOffset(12, 12), BackgroundColor3 = Color3.new(1, 1, 1)})
    corner(knob, 6)
    local dragging = false
    local function update(x)
        local a = math.clamp((x - track.AbsolutePosition.X) / track.AbsoluteSize.X, 0, 1)
        local n = min + (max - min) * a
        n = math.floor(n / step + 0.5) * step
        n = tonumber(string.format("%.3f", math.clamp(n, min, max)))
        Flags[flag] = n
        val.Text = tostring(n)
        fill.Size = UDim2.fromScale((n - min) / (max - min), 1)
        if cb then cb(n) end
        queueSave()
    end
    f.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            page.ScrollingEnabled = false
            update(i.Position.X)
        end
    end)
    Connect(UIS.InputChanged, function(i)
        if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
            update(i.Position.X)
        end
    end)
    Connect(UIS.InputEnded, function(i)
        if dragging and (i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch) then
            dragging = false
            page.ScrollingEnabled = true
        end
    end)
end

local function Button(page, text, cb)
    local b = new("TextButton", {Parent = page, BackgroundColor3 = C.row, Size = UDim2.new(1, 0, 0, 34), Text = text,
        Font = Enum.Font.GothamMedium, TextSize = 13, TextColor3 = C.text, AutoButtonColor = false})
    corner(b, 7) stroke(b, C.line, 1)
    b.MouseEnter:Connect(function() tween(b, 0.12, {BackgroundColor3 = C.rowHi}) end)
    b.MouseLeave:Connect(function() tween(b, 0.12, {BackgroundColor3 = C.row}) end)
    b.MouseButton1Click:Connect(function() task.spawn(cb) end)
    return b
end

local function Dropdown(page, text, flag, getOpts, default, cb)
    local v = Saved[flag]
    if v == nil then v = default end
    Flags[flag] = v
    Persist[flag] = true
    local box = new("Frame", {Parent = page, BackgroundColor3 = C.row, Size = UDim2.new(1, 0, 0, 34),
        AutomaticSize = Enum.AutomaticSize.Y, ClipsDescendants = true})
    corner(box, 7)
    local head = new("TextButton", {Parent = box, BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 34), Text = ""})
    rowLabel(head, text)
    local cur = new("TextLabel", {Parent = head, BackgroundTransparency = 1, AnchorPoint = Vector2.new(1, 0),
        Position = UDim2.new(1, -12, 0, 0), Size = UDim2.fromOffset(150, 34), Text = tostring(v or "-") .. "  ▾",
        Font = Enum.Font.GothamMedium, TextSize = 12, TextColor3 = C.acc2, TextXAlignment = Enum.TextXAlignment.Right})
    local list = new("Frame", {Parent = box, BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 34),
        Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, Visible = false})
    new("UIListLayout", {Parent = list})
    local function choose(o)
        Flags[flag] = o
        cur.Text = tostring(o) .. "  ▾"
        list.Visible = false
        if cb then cb(o) end
        queueSave()
    end
    local function rebuild()
        for _, c in ipairs(list:GetChildren()) do if c:IsA("TextButton") then c:Destroy() end end
        for _, o in ipairs(getOpts()) do
            local ob = new("TextButton", {Parent = list, Size = UDim2.new(1, 0, 0, 28), BackgroundColor3 = C.rowHi,
                BackgroundTransparency = 0.4, Text = "   " .. tostring(o), Font = Enum.Font.Gotham, TextSize = 12,
                TextColor3 = C.text, TextXAlignment = Enum.TextXAlignment.Left, AutoButtonColor = false, BorderSizePixel = 0})
            ob.MouseButton1Click:Connect(function() choose(o) end)
        end
    end
    head.MouseButton1Click:Connect(function()
        if not list.Visible then rebuild() end
        list.Visible = not list.Visible
    end)
    return {Rebuild = rebuild, Set = choose}
end

-- ============================================================
--                         ISI TAB
-- ============================================================
local pCombat = newTab("Combat")
local pVisual = newTab("Visual")
local pMove   = newTab("Movement")
local pTP     = newTab("Teleport")
local pPerf   = newTab("Performa")
local pMisc   = newTab("Misc")

-- ---- COMBAT ----
Section(pCombat, "Auto Attack")
Toggle(pCombat, "Auto M1 (target terdekat)", "AutoM1")
Slider(pCombat, "Jarak Serang", "M1Range", 5, 40, 14, 1)
Slider(pCombat, "Delay M1 (detik)", "M1Delay", 0.05, 0.6, 0.14, 0.01)
Toggle(pCombat, "Hadap Target Otomatis", "FaceTarget")
Section(pCombat, "Auto Skill (1-4)")
Toggle(pCombat, "Auto Skill Aktif", "AutoSkill")
Toggle(pCombat, "Skill 1", "Skill1")
Toggle(pCombat, "Skill 2", "Skill2")
Toggle(pCombat, "Skill 3", "Skill3")
Toggle(pCombat, "Skill 4", "Skill4")
Slider(pCombat, "Delay Antar Skill (detik)", "SkillDelay", 0.2, 3, 0.8, 0.05)
Slider(pCombat, "Jarak Pakai Skill", "SkillRange", 5, 60, 25, 1)
Section(pCombat, "Defense")
Toggle(pCombat, "Auto Block (F) saat musuh nyerang", "AutoBlock")
Slider(pCombat, "Jarak Deteksi Block", "BlockRange", 5, 35, 16, 1)
Toggle(pCombat, "Auto Awaken (G)", "AutoAwaken")
Toggle(pCombat, "Anti Ragdoll", "AntiRagdoll")
Section(pCombat, "Target")
Toggle(pCombat, "Nempel di Belakang Target", "Stick")
Slider(pCombat, "Jarak Nempel", "StickDist", 2, 8, 3.5, 0.5)
Toggle(pCombat, "Aim Lock Kamera (target terdekat di layar)", "AimLock")
Dropdown(pCombat, "Bagian Aim", "AimPart", function() return {"HumanoidRootPart", "Head", "UpperTorso"} end, "HumanoidRootPart")
Slider(pCombat, "FOV Aim (px)", "AimFOV", 50, 700, 260, 10)
Slider(pCombat, "Kehalusan Aim", "AimSmooth", 0.05, 1, 0.3, 0.05)
Section(pCombat, "Hitbox")
Toggle(pCombat, "Hitbox Expander", "Hitbox", function(v)
    if not v then
        for _, p in ipairs(Players:GetPlayers()) do
            local r = p ~= LP and Root(p.Character)
            if r then r.Size = Vector3.new(2, 2, 1) r.Transparency = 1 r.CanCollide = true end
        end
    end
end)
Slider(pCombat, "Ukuran Hitbox", "HitboxSize", 2, 30, 10, 1)

-- ---- VISUAL ----
Section(pVisual, "ESP")
Toggle(pVisual, "ESP Highlight + Nama", "ESP", function() RefreshESP() end)
Toggle(pVisual, "Tampilkan HP & Jarak", "ESPInfo")
Toggle(pVisual, "Tracer (garis ke pemain)", "Tracer", function(v)
    if v and not HasDrawing then Notify("Executor kamu tidak punya Drawing API") end
end)
Toggle(pVisual, "Lingkaran FOV Aim", "ShowFOV")
Section(pVisual, "Dunia")
local setFB = Toggle(pVisual, "Fullbright", "Fullbright", function(v)
    if v then
        Lighting.Brightness = 2 Lighting.ClockTime = 14 Lighting.Ambient = Color3.new(1, 1, 1)
        Lighting.OutdoorAmbient = Color3.new(1, 1, 1)
    else
        Lighting.Brightness = 1 Lighting.Ambient = Color3.fromRGB(70, 70, 70)
        Lighting.OutdoorAmbient = Color3.fromRGB(70, 70, 70)
    end
end)
Toggle(pVisual, "Hapus Kabut", "NoFog", function(v) if v then Lighting.FogEnd = 9e9 end end)
Slider(pVisual, "Field of View Kamera", "CamFOV", 40, 120, 70, 1, function(v) Cam.FieldOfView = v end)
Slider(pVisual, "Zoom Maksimum Kamera", "Zoom", 20, 500, 128, 10, function(v) LP.CameraMaxZoomDistance = v end)

-- ---- MOVEMENT ----
Section(pMove, "Kecepatan & Lompat")
Toggle(pMove, "WalkSpeed", "Speed", function(v) if not v and Hum() then Hum().WalkSpeed = 16 end end)
Slider(pMove, "Nilai Speed", "SpeedVal", 16, 150, 40, 1)
Toggle(pMove, "CFrame Speed (lebih aman)", "CFSpeed")
Slider(pMove, "Nilai CFrame Speed", "CFSpeedVal", 10, 120, 40, 1)
Toggle(pMove, "JumpPower", "Jump", function(v)
    if not v and Hum() then Hum().UseJumpPower = true Hum().JumpPower = 50 end
end)
Slider(pMove, "Nilai Jump", "JumpVal", 50, 300, 90, 5)
Toggle(pMove, "Infinite Jump", "InfJump")
Section(pMove, "Lainnya")
Toggle(pMove, "Noclip", "Noclip")
Toggle(pMove, "Fly", "Fly", function(v) if v then StartFly() else StopFly() end end)
Slider(pMove, "Kecepatan Fly", "FlySpeed", 20, 250, 70, 5)
Toggle(pMove, "Anti Void", "AntiVoid")
Toggle(pMove, "Spin", "Spin")

-- ---- TELEPORT ----
local function PlayerNames()
    local t = {}
    for _, p in ipairs(Players:GetPlayers()) do if p ~= LP then t[#t + 1] = p.Name end end
    if #t == 0 then t[1] = "(kosong)" end
    return t
end
Section(pTP, "Pemain")
Dropdown(pTP, "Pilih Pemain", "TPTarget", PlayerNames, "(pilih)")
Button(pTP, "Teleport ke Pemain", function()
    local p = Players:FindFirstChild(tostring(Flags.TPTarget))
    local r, tr = Root(), p and Root(p.Character)
    if r and tr then r.CFrame = tr.CFrame * CFrame.new(0, 0, 3) else Notify("Pemain tidak ditemukan") end
end)
Button(pTP, "Teleport ke Pemain Terdekat", function()
    local p = NearestEnemy()
    local r = Root()
    if p and r then r.CFrame = Root(p.Character).CFrame * CFrame.new(0, 0, 3) else Notify("Tidak ada pemain") end
end)
Button(pTP, "Teleport ke Pemain Acak", function()
    local list = {}
    for _, p in ipairs(Players:GetPlayers()) do if IsEnemy(p) then list[#list + 1] = p end end
    local r = Root()
    if #list > 0 and r then r.CFrame = Root(list[math.random(#list)].Character).CFrame * CFrame.new(0, 0, 3) end
end)
Toggle(pTP, "Spectate Pemain Terpilih", "Spectate", function(v)
    local p = Players:FindFirstChild(tostring(Flags.TPTarget))
    if v and p and p.Character and Hum(p.Character) then
        Cam.CameraSubject = Hum(p.Character)
    else
        if Hum() then Cam.CameraSubject = Hum() end
    end
end)
Section(pTP, "Posisi Tersimpan")
local savedCF
Button(pTP, "Simpan Posisi Sekarang", function()
    if Root() then savedCF = Root().CFrame Notify("Posisi disimpan") end
end)
Button(pTP, "Teleport ke Posisi Tersimpan", function()
    if savedCF and Root() then Root().CFrame = savedCF else Notify("Belum ada posisi tersimpan") end
end)

-- ---- PERFORMA ----
Section(pPerf, "Anti Lag")
Toggle(pPerf, "Anti Lag (matikan efek & bayangan)", "AntiLag", function(v)
    if v then
        SetLive() ProcessAll(false)
        Notify("Anti Lag aktif: efek skill dimatikan")
    else
        if not Flags.SuperLag then RestoreFx() end
    end
end)
Toggle(pPerf, "SUPER Anti Lag (grafik minimum)", "SuperLag", function(v)
    if v then
        SetLive() ProcessAll(true)
        Notify("Super Anti Lag aktif. Rejoin untuk mengembalikan tampilan")
    end
end)
Button(pPerf, "Hapus Semua Efek Sekarang (sekali)", function()
    ProcessAll(true) Notify("Membersihkan efek & tekstur...")
end)
Section(pPerf, "FPS & Render")
Slider(pPerf, "Batas FPS", "FPSCap", 30, 360, 144, 10, function(v) if setfpscap then setfpscap(v) end end)
Slider(pPerf, "Kualitas Grafik (1 = terendah)", "Quality", 1, 10, 1, 1, function(v)
    pcall(function() settings().Rendering.QualityLevel = v end)
end)
Toggle(pPerf, "Matikan Render 3D (layar putih, hemat baterai)", "NoRender", function(v)
    pcall(function() RunService:Set3dRenderingEnabled(not v) end)
end)
Button(pPerf, "Bersihkan Memori", function()
    collectgarbage("collect") Notify("Memori dibersihkan")
end)

-- ---- MISC ----
Section(pMisc, "Umum")
Toggle(pMisc, "Anti AFK", "AntiAFK")
Flags.AntiAFK = true
Toggle(pMisc, "Auto Respawn", "AutoRespawn")
Button(pMisc, "Reset Karakter", function() if Hum() then Hum().Health = 0 end end)
Section(pMisc, "Server")
Button(pMisc, "Rejoin Server", function()
    TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, LP)
end)
Button(pMisc, "Server Hop (server paling sepi)", function()
    local ok, data = pcall(function()
        return HttpService:JSONDecode(game:HttpGet(
            "https://games.roblox.com/v1/games/" .. game.PlaceId .. "/servers/Public?sortOrder=Asc&limit=100"))
    end)
    if ok and data and data.data then
        for _, s in ipairs(data.data) do
            if s.playing < s.maxPlayers and s.id ~= game.JobId then
                TeleportService:TeleportToPlaceInstance(game.PlaceId, s.id, LP)
                return
            end
        end
    end
    Notify("Server lain tidak ditemukan")
end)
Button(pMisc, "Salin Job ID", function()
    if setclipboard then setclipboard(game.JobId) Notify("Job ID disalin") end
end)
Section(pMisc, "Script")
Button(pMisc, "Simpan Pengaturan Sekarang", function()
    queueSave() Notify("Pengaturan disimpan")
end)

-- ============================================================
--                    LOGIKA / LOOP
-- ============================================================
Flags.Spectate = false
Tabs["Combat"].select()

-- FPS / Ping
local frames, lastT = 0, tick()
Connect(RunService.RenderStepped, function()
    frames += 1
    if tick() - lastT >= 0.5 then
        local fps = math.floor(frames / (tick() - lastT) + 0.5)
        local ping = 0
        pcall(function() ping = math.floor(Stats.Network.ServerStatsItem["Data Ping"]:GetValue()) end)
        StatLbl.Text = fps .. " FPS | " .. ping .. " ms"
        frames, lastT = 0, tick()
    end
end)

-- FOV circle & tracer (Drawing)
local FOVCircle
if HasDrawing then
    pcall(function()
        FOVCircle = Drawing.new("Circle")
        FOVCircle.Thickness = 1
        FOVCircle.NumSides = 64
        FOVCircle.Color = Color3.fromRGB(170, 90, 255)
        FOVCircle.Filled = false
        FOVCircle.Visible = false
    end)
end

-- Aim lock + tracer (RenderStepped)
Connect(RunService.RenderStepped, function()
    local vs = Cam.ViewportSize
    local center = Vector2.new(vs.X / 2, vs.Y / 2)

    if FOVCircle then
        FOVCircle.Visible = Flags.ShowFOV and true or false
        FOVCircle.Position = center
        FOVCircle.Radius = Flags.AimFOV
    end

    if Flags.AimLock then
        local best, bd = nil, Flags.AimFOV
        for _, p in ipairs(Players:GetPlayers()) do
            if IsEnemy(p) then
                local part = p.Character:FindFirstChild(Flags.AimPart) or Root(p.Character)
                local pos, vis = Cam:WorldToViewportPoint(part.Position)
                if vis then
                    local d = (Vector2.new(pos.X, pos.Y) - center).Magnitude
                    if d < bd then best, bd = part, d end
                end
            end
        end
        if best then
            Cam.CFrame = Cam.CFrame:Lerp(CFrame.new(Cam.CFrame.Position, best.Position), Flags.AimSmooth)
        end
    end

    if HasDrawing then
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= LP then
                local r = p.Character and Root(p.Character)
                if Flags.Tracer and r and IsEnemy(p) then
                    local ln = Tracers[p]
                    if not ln then
                        pcall(function()
                            ln = Drawing.new("Line")
                            ln.Thickness = 1
                            ln.Color = Color3.fromRGB(170, 90, 255)
                            Tracers[p] = ln
                        end)
                    end
                    if ln then
                        local pos, vis = Cam:WorldToViewportPoint(r.Position)
                        ln.Visible = vis
                        ln.From = Vector2.new(vs.X / 2, vs.Y)
                        ln.To = Vector2.new(pos.X, pos.Y)
                    end
                elseif Tracers[p] then
                    Tracers[p].Visible = false
                end
            end
        end
    end
end)

-- ESP info update
task.spawn(function()
    while Running do
        task.wait(0.25)
        if Flags.ESP then
            local myR = Root()
            for p, d in pairs(ESPData) do
                if d.tl and p.Character then
                    local h, r = Hum(p.Character), Root(p.Character)
                    local txt = p.DisplayName
                    if Flags.ESPInfo and h and r and myR then
                        txt = string.format("%s\n%d HP | %dm", p.DisplayName, h.Health,
                            (r.Position - myR.Position).Magnitude)
                    end
                    d.tl.Text = txt
                end
            end
        end
    end
end)

-- Auto M1
task.spawn(function()
    while Running do
        task.wait(Flags.M1Delay or 0.14)
        if Flags.AutoM1 then
            local t = NearestEnemy(Flags.M1Range)
            local r = Root()
            if t and r then
                if Flags.FaceTarget then
                    local tp = Root(t.Character).Position
                    r.CFrame = CFrame.lookAt(r.Position, Vector3.new(tp.X, r.Position.Y, tp.Z))
                end
                Click()
            end
        end
    end
end)

-- Auto Skill
task.spawn(function()
    local keys = {Enum.KeyCode.One, Enum.KeyCode.Two, Enum.KeyCode.Three, Enum.KeyCode.Four}
    local names = {"Skill1", "Skill2", "Skill3", "Skill4"}
    while Running do
        task.wait(Flags.SkillDelay or 0.8)
        if Flags.AutoSkill then
            local t = NearestEnemy(Flags.SkillRange)
            if t then
                for i = 1, 4 do
                    if Flags[names[i]] then
                        Tap(keys[i], 0.04)
                        task.wait(0.12)
                    end
                end
            end
        end
    end
end)

-- Auto Block
local blocking = false
task.spawn(function()
    while Running do
        task.wait(0.05)
        local want = false
        if Flags.AutoBlock then
            local r = Root()
            if r then
                for _, p in ipairs(Players:GetPlayers()) do
                    if IsEnemy(p) and (Root(p.Character).Position - r.Position).Magnitude <= Flags.BlockRange
                        and IsAttacking(p) then
                        want = true break
                    end
                end
            end
        end
        if want and not blocking then
            blocking = true
            VIM:SendKeyEvent(true, Enum.KeyCode.F, false, game)
        elseif not want and blocking then
            blocking = false
            VIM:SendKeyEvent(false, Enum.KeyCode.F, false, game)
        end
    end
end)

-- Auto Awaken
task.spawn(function()
    while Running do
        task.wait(2)
        if Flags.AutoAwaken and NearestEnemy(40) then Tap(Enum.KeyCode.G, 0.05) end
    end
end)

-- Fisika / gerak
local lastSafe
Connect(RunService.Heartbeat, function(dt)
    local char = LP.Character
    local h, r = Hum(char), Root(char)
    if not h or not r then return end

    if Flags.Speed then h.WalkSpeed = Flags.SpeedVal end
    if Flags.Jump then h.UseJumpPower = true h.JumpPower = Flags.JumpVal end
    if Flags.CFSpeed and h.MoveDirection.Magnitude > 0 then
        r.CFrame = r.CFrame + h.MoveDirection * Flags.CFSpeedVal * dt
    end
    if Flags.AutoRespawn and h.Health <= 0 then pcall(function() LP:LoadCharacter() end) end

    if Flags.AntiRagdoll and not Flags.Fly then
        local st = h:GetState()
        if st == Enum.HumanoidStateType.Ragdoll or st == Enum.HumanoidStateType.FallingDown then
            h:ChangeState(Enum.HumanoidStateType.GettingUp)
        end
        if h.PlatformStand then h.PlatformStand = false end
    end

    if Flags.Fly and flyBV and flyBG then
        local look, right = Cam.CFrame.LookVector, Cam.CFrame.RightVector
        local md = h.MoveDirection
        local dir = Vector3.zero
        if md.Magnitude > 0 then
            local flat = Vector3.new(look.X, 0, look.Z)
            local fwd = flat.Magnitude > 0 and md:Dot(flat.Unit) or 0
            dir = md + Vector3.new(0, look.Y * fwd, 0)
        end
        if UIS:IsKeyDown(Enum.KeyCode.Space) then dir += Vector3.new(0, 1, 0) end
        if UIS:IsKeyDown(Enum.KeyCode.LeftShift) then dir -= Vector3.new(0, 1, 0) end
        flyBV.Velocity = dir.Magnitude > 0 and dir.Unit * Flags.FlySpeed or Vector3.zero
        flyBG.CFrame = Cam.CFrame
    end

    if Flags.AntiVoid then
        if r.Position.Y < -150 and lastSafe then
            r.AssemblyLinearVelocity = Vector3.zero
            r.CFrame = lastSafe
        elseif r.Position.Y > -50 and h.FloorMaterial ~= Enum.Material.Air then
            lastSafe = r.CFrame + Vector3.new(0, 4, 0)
        end
    end

    if Flags.Spin and not Flags.AutoM1 then r.CFrame = r.CFrame * CFrame.Angles(0, math.rad(25), 0) end

    if Flags.Stick then
        local t = NearestEnemy(60)
        if t then
            local tr = Root(t.Character)
            local pos = (tr.CFrame * CFrame.new(0, 0, Flags.StickDist)).Position
            r.CFrame = CFrame.lookAt(pos, tr.Position)
        end
    end

    if Flags.Hitbox then
        for _, p in ipairs(Players:GetPlayers()) do
            local pr = p ~= LP and Root(p.Character)
            if pr then
                pr.Size = Vector3.new(Flags.HitboxSize, Flags.HitboxSize, Flags.HitboxSize)
                pr.Transparency = 0.75
                pr.CanCollide = false
            end
        end
    end
end)

Connect(RunService.Stepped, function()
    if Flags.Noclip and LP.Character then
        for _, v in ipairs(LP.Character:GetDescendants()) do
            if v:IsA("BasePart") then v.CanCollide = false end
        end
    end
end)

Connect(UIS.JumpRequest, function()
    if Flags.InfJump and Hum() then Hum():ChangeState(Enum.HumanoidStateType.Jumping) end
end)

Connect(LP.Idled, function()
    if Flags.AntiAFK then
        VirtualUser:CaptureController()
        VirtualUser:ClickButton2(Vector2.new())
    end
end)

Connect(LP.CharacterAdded, function()
    StopFly()
    blocking = false
    task.wait(0.5)
    if Flags.Fly then StartFly() end
end)

-- Tutup / unload
local function Unload()
    Running = false
    if blocking then VIM:SendKeyEvent(false, Enum.KeyCode.F, false, game) end
    StopFly()
    for p in pairs(ESPData) do ClearESP(p) end
    for p in pairs(Tracers) do ClearESP(p) end
    if FOVCircle then pcall(function() FOVCircle:Remove() end) end
    pcall(function() RunService:Set3dRenderingEnabled(true) end)
    for _, c in ipairs(Conns) do pcall(function() c:Disconnect() end) end
    Gui:Destroy()
end
BtnClose.MouseButton1Click:Connect(Unload)

Notify("KizzDev LB v2 siap. Tombol K / RightCtrl untuk buka tutup.")
