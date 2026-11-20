--[[
    KizzDev | Legends Battlegrounds  v3
    UI custom bertema ungu (mirip referensi) - tanpa library
    Buka/tutup menu : tombol mahkota melayang / RightCtrl
    Aimlock         : tombol 🔒 melayang / tombol T  |  ganti target: ⇄ / tombol Y
    Kontrol game    : Q dash, F block, G awaken, M1 klik kiri, skill 1-4
]]

-- ================= CONFIG TAMPILAN =================
local UI_CFG = {
    Name        = "KizzDev",
    Tagline     = "Best Script Hub for Roblox",
    ProfileName = "KizzDev",
    ProfileRole = "Admin",
    FollowText  = "@kizzdev",
    -- Gambar banner (opsional). Isi salah satu:
    BannerId    = "",                       -- contoh: "rbxassetid://123456789"
    BannerFile  = "KizzDev/banner.png",     -- file PNG di folder workspace executor
    LogoFile    = "KizzDev/logo.png",       -- logo mahkota (opsional)
    -- LINK gambar (direct link .png/.jpg), otomatis diunduh sekali lalu disimpan:
    BannerUrl   = "",                       -- contoh: "https://raw.githubusercontent.com/user/repo/main/banner.png"
    LogoUrl     = "https://postimg.cc/TKqCHt3b",                       -- contoh: "https://i.imgur.com/xxxxxxx.png"
}

-- ================= SERVICES =================
local Players         = game:GetService("Players")
local RunService      = game:GetService("RunService")
local UIS             = game:GetService("UserInputService")
local TweenService    = game:GetService("TweenService")
local TeleportService = game:GetService("TeleportService")
local HttpService     = game:GetService("HttpService")
local Lighting        = game:GetService("Lighting")
local VirtualUser     = game:GetService("VirtualUser")
local VIM             = game:GetService("VirtualInputManager")
local Stats           = game:GetService("Stats")
local Workspace       = game:GetService("Workspace")

local LP    = Players.LocalPlayer
local Cam   = Workspace.CurrentCamera
local Mouse = LP:GetMouse()

local function guiParent()
    local ok, p = pcall(function() return (gethui and gethui()) or game:GetService("CoreGui") end)
    if ok and p then return p end
    return LP:WaitForChild("PlayerGui")
end
local PARENT = guiParent()
pcall(function()
    local old = PARENT:FindFirstChild("KizzDev_LB")
    if old then old:Destroy() end
    pcall(function() RunService:UnbindFromRenderStep("KZ_Aim") end)
end)

-- ================= STATE / CONFIG =================
local Flags, Saved, Persist = {}, {}, {}
local CFG = "KizzDev/LegendsBattlegrounds_v3.json"
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

-- ================= HELPER GAME =================
local function Root(c) c = c or LP.Character return c and c:FindFirstChild("HumanoidRootPart") end
local function Hum(c) c = c or LP.Character return c and c:FindFirstChildOfClass("Humanoid") end

local FriendCache = {}
local function IsFriend(p)
    local c = FriendCache[p.UserId]
    if c == nil then
        FriendCache[p.UserId] = false
        task.spawn(function()
            local ok, r = pcall(LP.IsFriendsWith, LP, p.UserId)
            FriendCache[p.UserId] = ok and r or false
        end)
        return false
    end
    return c
end

local function IsEnemy(p)
    if p == LP or not p.Character then return false end
    local h, r = Hum(p.Character), Root(p.Character)
    if not (h and r and h.Health > 0) then return false end
    if Flags.IgnoreFriends and IsFriend(p) then return false end
    if Flags.IgnoreFF and p.Character:FindFirstChildOfClass("ForceField") then return false end
    return true
end

local function NearestEnemy(maxDist, exclude)
    local r = Root()
    if not r then return end
    local best, bd = nil, maxDist or math.huge
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= exclude and IsEnemy(p) then
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

-- ================= FLY =================
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

-- ================= ESP =================
local ESPData, Tracers = {}, {}
local HasDrawing = (Drawing ~= nil and Drawing.new ~= nil)

local function ClearESP(p)
    local d = ESPData[p]
    if d then
        for _, o in pairs(d) do if typeof(o) == "Instance" then pcall(function() o:Destroy() end) end end
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

-- ================= ANTI LAG =================
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

local function SetLive()
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

-- ================= AIMLOCK (sticky, anti-bug) =================
local AimTarget, LockActive = nil, true
local camHeld, lockDist, lockPitch = false, 12, -0.15

local function TargetPart(p)
    local c = p and p.Character
    return c and (c:FindFirstChild(Flags.AimPart or "HumanoidRootPart") or Root(c))
end

local function PickTarget(exclude)
    local r = Root()
    if not r then return end
    local prio = Flags.AimPriority or "Terdekat (karakter)"
    local maxD = Flags.AimMaxDist or 60
    local best, bs = nil, math.huge
    local vs = Cam.ViewportSize
    local center = Vector2.new(vs.X / 2, vs.Y / 2)
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= exclude and IsEnemy(p) then
            local tr = Root(p.Character)
            local d = (tr.Position - r.Position).Magnitude
            if d <= maxD then
                local score
                if prio == "Terdekat (crosshair)" then
                    local pos, vis = Cam:WorldToViewportPoint(tr.Position)
                    if vis then
                        local s = (Vector2.new(pos.X, pos.Y) - center).Magnitude
                        if s <= (Flags.AimFOV or 300) then score = s end
                    end
                elseif prio == "HP terendah" then
                    score = Hum(p.Character).Health
                else
                    score = d
                end
                if score and score < bs then best, bs = p, score end
            end
        end
    end
    return best
end

local function ValidTarget(p)
    if not p or not IsEnemy(p) then return false end
    local r = Root()
    if not r then return false end
    return (Root(p.Character).Position - r.Position).Magnitude <= (Flags.AimMaxDist or 60) * 1.25
end

local function ReleaseCam()
    if camHeld then
        camHeld = false
        pcall(function() Cam.CameraType = Enum.CameraType.Custom end)
    end
end

RunService:BindToRenderStep("KZ_Aim", Enum.RenderPriority.Camera.Value + 1, function(dt)
    local r = Root()
    local t = AimTarget
    if not (Flags.AimLock and LockActive and t and r) then ReleaseCam() return end
    local tr = TargetPart(t)
    if not tr then ReleaseCam() return end
    local focus = r.Position + Vector3.new(0, 2, 0)
    if not camHeld then
        camHeld = true
        lockDist = math.clamp((Cam.CFrame.Position - focus).Magnitude, 6, 30)
        lockPitch = math.clamp(Cam.CFrame.LookVector.Y, -0.45, 0.45)
        Cam.CameraType = Enum.CameraType.Scriptable
    end
    local aimPos = tr.Position
    if Flags.Predict then aimPos += tr.AssemblyLinearVelocity * (Flags.PredictTime or 0.1) end
    local d = aimPos - focus
    local want
    if Flags.AimYawOnly then
        local hz = Vector3.new(d.X, 0, d.Z)
        if hz.Magnitude < 0.3 then return end
        want = hz.Unit * math.sqrt(1 - lockPitch * lockPitch) + Vector3.new(0, lockPitch, 0)
    else
        if d.Magnitude < 0.3 then return end
        want = d.Unit
    end
    local cur = Cam.CFrame.LookVector
    local alpha = 1 - (1 - math.clamp(Flags.AimSmooth or 0.35, 0.02, 1)) ^ (dt * 60)
    local nl = cur:Lerp(want, alpha)
    nl = nl.Magnitude > 0.05 and nl.Unit or want
    local pos = focus - nl * lockDist
    Cam.CFrame = CFrame.lookAt(pos, pos + nl)
end)

-- ============================================================
--                        UI FRAMEWORK
-- ============================================================
local C = {
    bg = Color3.fromRGB(10, 6, 20), side = Color3.fromRGB(14, 9, 26),
    card = Color3.fromRGB(18, 11, 32), cardHi = Color3.fromRGB(30, 19, 54),
    acc = Color3.fromRGB(138, 64, 255), acc2 = Color3.fromRGB(196, 92, 255),
    text = Color3.fromRGB(242, 238, 252), sub = Color3.fromRGB(150, 138, 182),
    line = Color3.fromRGB(78, 44, 140), off = Color3.fromRGB(46, 36, 74),
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
local function corner(o, r) return new("UICorner", {CornerRadius = UDim.new(0, r or 8), Parent = o}) end
local function stroke(o, col, th, tr)
    return new("UIStroke", {Color = col or C.line, Thickness = th or 1, Transparency = tr or 0, Parent = o,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border})
end
local function gradient(o, a, b, rot)
    return new("UIGradient", {Parent = o, Color = ColorSequence.new(a or C.acc, b or C.acc2), Rotation = rot or 0})
end
local function tween(o, t, props)
    TweenService:Create(o, TweenInfo.new(t, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), props):Play()
end

local Gui = new("ScreenGui", {Name = "KizzDev_LB", ResetOnSpawn = false, ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
    DisplayOrder = 999, IgnoreGuiInset = true, Parent = PARENT})

-- Registry flag <-> tampilan
local Views, Hooks = {}, {}
local function AddView(flag, f) Views[flag] = Views[flag] or {} table.insert(Views[flag], f) end
local function SetFlag(flag, v)
    Flags[flag] = v
    for _, f in ipairs(Views[flag] or {}) do pcall(f, v) end
    if Hooks[flag] then task.spawn(Hooks[flag], v) end
end

-- Toast
local Toasts = new("Frame", {Parent = Gui, BackgroundTransparency = 1, AnchorPoint = Vector2.new(1, 1),
    Position = UDim2.new(1, -14, 1, -14), Size = UDim2.fromOffset(240, 300)})
new("UIListLayout", {Parent = Toasts, VerticalAlignment = Enum.VerticalAlignment.Bottom,
    HorizontalAlignment = Enum.HorizontalAlignment.Right, Padding = UDim.new(0, 6)})

local function Notify(msg)
    local f = new("Frame", {Parent = Toasts, BackgroundColor3 = C.card, Size = UDim2.fromOffset(240, 0),
        AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1})
    corner(f, 10) local st = stroke(f, C.acc, 1, 1)
    new("UIPadding", {Parent = f, PaddingTop = UDim.new(0, 8), PaddingBottom = UDim.new(0, 8),
        PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12)})
    local l = new("TextLabel", {Parent = f, BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y, Text = msg, TextWrapped = true, Font = Enum.Font.GothamMedium,
        TextSize = 12, TextColor3 = C.text, TextXAlignment = Enum.TextXAlignment.Left, TextTransparency = 1})
    tween(f, 0.2, {BackgroundTransparency = 0}) tween(l, 0.2, {TextTransparency = 0}) tween(st, 0.2, {Transparency = 0.2})
    task.delay(2.8, function()
        if f.Parent then
            tween(f, 0.25, {BackgroundTransparency = 1}) tween(l, 0.25, {TextTransparency = 1}) tween(st, 0.25, {Transparency = 1})
            task.wait(0.3) f:Destroy()
        end
    end)
end

-- ================= WINDOW =================
local W, H = 740, 420
local Main = new("Frame", {Parent = Gui, Name = "Main", BackgroundColor3 = C.bg, AnchorPoint = Vector2.new(0.5, 0.5),
    Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(W, H), ClipsDescendants = true})
corner(Main, 16)
new("UIStroke", {Parent = Main, Color = C.acc, Thickness = 6, Transparency = 0.8, ApplyStrokeMode = Enum.ApplyStrokeMode.Border})
local edge = new("UIStroke", {Parent = Main, Color = Color3.new(1, 1, 1), Thickness = 1.6, ApplyStrokeMode = Enum.ApplyStrokeMode.Border})
gradient(edge, C.acc2, C.acc, 45)
new("Frame", {Parent = Main, Size = UDim2.fromScale(1, 1), BackgroundColor3 = C.bg, ZIndex = 0, BorderSizePixel = 0},
    {new("UIGradient", {Color = ColorSequence.new(Color3.fromRGB(14, 8, 28), Color3.fromRGB(26, 12, 52)), Rotation = 90})})

local Scale = new("UIScale", {Parent = Main})
local function fitScale()
    local v = Cam.ViewportSize
    Scale.Scale = math.clamp(math.min(v.X / (W + 40), v.Y / (H + 40)), 0.45, 1.2) * (Flags.UIScale or 1)
end
Connect(Cam:GetPropertyChangedSignal("ViewportSize"), fitScale)

-- Header / banner
local Header = new("Frame", {Parent = Main, Size = UDim2.new(1, 0, 0, 104), BorderSizePixel = 0, ZIndex = 1,
    BackgroundColor3 = Color3.new(1, 1, 1)})
new("UIGradient", {Parent = Header, Rotation = 0, Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0, Color3.fromRGB(26, 10, 56)),
    ColorSequenceKeypoint.new(0.55, Color3.fromRGB(70, 30, 140)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(150, 110, 235))})})

local function loadImage(id, file, url)
    if id and id ~= "" then return id end
    if getcustomasset and isfile and writefile then
        local ok, res = pcall(function()
            if url and url ~= "" then
                if makefolder and not isfolder("KizzDev") then makefolder("KizzDev") end
                local h = 0
                for i = 1, #url do h = (h * 31 + url:byte(i)) % 1000000007 end
                local path = "KizzDev/cache_" .. h .. ".png"
                if not isfile(path) then writefile(path, game:HttpGet(url)) end
                return getcustomasset(path)
            end
            if file and isfile(file) then return getcustomasset(file) end
        end)
        if ok and res then return res end
    end
end

local bannerImg = loadImage(UI_CFG.BannerId, UI_CFG.BannerFile, UI_CFG.BannerUrl)
if bannerImg then
    local img = new("ImageLabel", {Parent = Header, BackgroundTransparency = 1, AnchorPoint = Vector2.new(1, 0),
        Position = UDim2.new(1, 0, 0, 0), Size = UDim2.new(0.62, 0, 1, 0), Image = bannerImg,
        ScaleType = Enum.ScaleType.Crop, ZIndex = 2})
    new("UIGradient", {Parent = img, Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.35, 0.1), NumberSequenceKeypoint.new(1, 0)})})
else
    -- hiasan sederhana pengganti gambar
    local orb = new("Frame", {Parent = Header, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.8, 0, 0.55, 0),
        Size = UDim2.fromOffset(190, 190), BackgroundColor3 = Color3.fromRGB(200, 160, 255), BackgroundTransparency = 0.6,
        ZIndex = 2})
    corner(orb, 95)
    new("UIGradient", {Parent = orb, Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(1, 1)}), Rotation = 90})
end
new("Frame", {Parent = Header, Size = UDim2.new(1, 0, 0, 42), AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1),
    BackgroundColor3 = C.bg, BorderSizePixel = 0, ZIndex = 3}, {new("UIGradient", {Rotation = 90,
    Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, 0.15)})})})

local sparkPos = {{0.33, 0.12, 14}, {0.46, 0.7, 10}, {0.62, 0.2, 12}, {0.7, 0.62, 16}, {0.9, 0.28, 10}, {0.05, 0.75, 12}}
for _, s in ipairs(sparkPos) do
    new("TextLabel", {Parent = Header, BackgroundTransparency = 1, Text = "✦", TextSize = s[3], ZIndex = 4,
        Position = UDim2.new(s[1], 0, s[2], 0), Size = UDim2.fromOffset(20, 20), TextColor3 = Color3.fromRGB(220, 180, 255),
        TextTransparency = 0.25, Font = Enum.Font.GothamBold})
end

local logoImg = loadImage(nil, UI_CFG.LogoFile, UI_CFG.LogoUrl)
if logoImg then
    new("ImageLabel", {Parent = Header, BackgroundTransparency = 1, Position = UDim2.fromOffset(24, 14),
        Size = UDim2.fromOffset(74, 66), Image = logoImg, ScaleType = Enum.ScaleType.Fit, ZIndex = 5})
else
    local crown = new("TextLabel", {Parent = Header, BackgroundTransparency = 1, Position = UDim2.fromOffset(22, 8),
        Size = UDim2.fromOffset(80, 70), Text = "♛", TextSize = 62, Font = Enum.Font.GothamBlack, ZIndex = 5,
        TextColor3 = Color3.new(1, 1, 1)})
    gradient(crown, Color3.fromRGB(170, 90, 255), Color3.fromRGB(110, 50, 220), 90)
end
local Logo = new("TextLabel", {Parent = Header, BackgroundTransparency = 1, Position = UDim2.fromOffset(104, 8),
    Size = UDim2.fromOffset(300, 54), RichText = true, ZIndex = 5, TextXAlignment = Enum.TextXAlignment.Left,
    Text = '<i><b><font color="#ffffff">Kizz</font><font color="#b565ff">Dev</font></b></i>',
    Font = Enum.Font.GothamBlack, TextSize = 46, TextColor3 = Color3.new(1, 1, 1)})
new("TextLabel", {Parent = Header, BackgroundTransparency = 1, Position = UDim2.fromOffset(112, 62),
    Size = UDim2.fromOffset(300, 20), Text = UI_CFG.Tagline .. "  ★", Font = Enum.Font.GothamMedium, TextSize = 13,
    TextColor3 = C.text, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 5})
local StatLbl = new("TextLabel", {Parent = Header, BackgroundTransparency = 1, Position = UDim2.fromOffset(112, 82),
    Size = UDim2.fromOffset(200, 16), Text = "", Font = Enum.Font.Gotham, TextSize = 10, TextColor3 = C.sub,
    TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 5})

-- pill minimize / close
local Pill = new("Frame", {Parent = Header, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -14, 0, 14),
    Size = UDim2.fromOffset(92, 34), BackgroundColor3 = Color3.fromRGB(10, 6, 20), BackgroundTransparency = 0.2, ZIndex = 6})
corner(Pill, 17) stroke(Pill, C.acc2, 1.2, 0.2)
local function pillBtn(txt, x)
    local b = new("TextButton", {Parent = Pill, BackgroundTransparency = 1, Position = UDim2.fromOffset(x, 0),
        Size = UDim2.fromOffset(46, 34), Text = txt, Font = Enum.Font.GothamBold, TextSize = 18,
        TextColor3 = C.text, AutoButtonColor = false, ZIndex = 7})
    b.MouseEnter:Connect(function() tween(b, 0.12, {TextColor3 = C.acc2}) end)
    b.MouseLeave:Connect(function() tween(b, 0.12, {TextColor3 = C.text}) end)
    return b
end
local BtnMin, BtnClose = pillBtn("—", 0), pillBtn("✕", 46)

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
makeDraggable(Header, Main)

-- Tombol melayang (mahkota)
local Float = new("TextButton", {Parent = Gui, Size = UDim2.fromOffset(48, 48), Position = UDim2.new(0, 14, 0.35, 0),
    BackgroundColor3 = C.bg, Text = "♛", Font = Enum.Font.GothamBlack, TextSize = 26, TextColor3 = C.acc2,
    AutoButtonColor = false, Visible = false})
corner(Float, 24) stroke(Float, C.acc, 2)
makeDraggable(Float, Float)
local function setMenu(v) Main.Visible = v Float.Visible = not v end
Float.MouseButton1Click:Connect(function() setMenu(true) end)
BtnMin.MouseButton1Click:Connect(function() setMenu(false) end)

-- Sidebar
local Side = new("Frame", {Parent = Main, BackgroundTransparency = 1, Position = UDim2.fromOffset(12, 108),
    Size = UDim2.fromOffset(148, 232)})
new("UIListLayout", {Parent = Side, Padding = UDim.new(0, 3)})

local Content = new("Frame", {Parent = Main, BackgroundTransparency = 1, Position = UDim2.fromOffset(172, 106),
    Size = UDim2.new(1, -184, 1, -116)})

local Tabs = {}
local function newTab(name, icon)
    local btn = new("TextButton", {Parent = Side, Size = UDim2.new(1, 0, 0, 30), BackgroundColor3 = Color3.new(1, 1, 1),
        BackgroundTransparency = 1, Text = "", AutoButtonColor = false})
    corner(btn, 10)
    local grad = new("UIGradient", {Parent = btn, Color = ColorSequence.new(Color3.fromRGB(122, 60, 255), Color3.fromRGB(70, 40, 190)),
        Enabled = true})
    local st = stroke(btn, C.acc2, 1.2, 1)
    local ic = new("TextLabel", {Parent = btn, BackgroundTransparency = 1, Position = UDim2.fromOffset(10, 0),
        Size = UDim2.fromOffset(24, 30), Text = icon, TextSize = 15, Font = Enum.Font.GothamBold, TextColor3 = C.sub})
    local lb = new("TextLabel", {Parent = btn, BackgroundTransparency = 1, Position = UDim2.fromOffset(40, 0),
        Size = UDim2.new(1, -60, 1, 0), Text = name, TextSize = 13, Font = Enum.Font.GothamMedium,
        TextColor3 = C.sub, TextXAlignment = Enum.TextXAlignment.Left})
    local dot = new("Frame", {Parent = btn, AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -10, 0.5, 0),
        Size = UDim2.fromOffset(8, 8), BackgroundColor3 = C.acc2, Visible = false})
    corner(dot, 4)
    local page = new("ScrollingFrame", {Parent = Content, BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1),
        CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollBarThickness = 3,
        ScrollBarImageColor3 = C.acc, BorderSizePixel = 0, Visible = false})
    new("UIListLayout", {Parent = page, Padding = UDim.new(0, 7)})
    new("UIPadding", {Parent = page, PaddingRight = UDim.new(0, 8), PaddingBottom = UDim.new(0, 8)})
    local function select()
        for _, t in pairs(Tabs) do
            t.page.Visible = false t.dot.Visible = false
            tween(t.btn, 0.15, {BackgroundTransparency = 1})
            tween(t.st, 0.15, {Transparency = 1})
            tween(t.ic, 0.15, {TextColor3 = C.sub}) tween(t.lb, 0.15, {TextColor3 = C.sub})
        end
        page.Visible = true dot.Visible = true
        tween(btn, 0.15, {BackgroundTransparency = 0.05}) tween(st, 0.15, {Transparency = 0.1})
        tween(ic, 0.15, {TextColor3 = Color3.new(1, 1, 1)}) tween(lb, 0.15, {TextColor3 = Color3.new(1, 1, 1)})
    end
    btn.MouseButton1Click:Connect(select)
    Tabs[name] = {btn = btn, page = page, dot = dot, st = st, ic = ic, lb = lb, select = select}
    return page
end

-- Kartu profil
local Profile = new("Frame", {Parent = Main, Position = UDim2.new(0, 12, 1, -62), Size = UDim2.fromOffset(148, 52),
    BackgroundColor3 = C.card})
corner(Profile, 12) stroke(Profile, C.line, 1.2)
local av = new("ImageLabel", {Parent = Profile, Position = UDim2.fromOffset(7, 7), Size = UDim2.fromOffset(38, 38),
    BackgroundColor3 = C.cardHi, Image = "rbxthumb://type=AvatarHeadShot&id=" .. LP.UserId .. "&w=150&h=150"})
corner(av, 19) stroke(av, C.acc2, 1.2)
new("TextLabel", {Parent = Profile, BackgroundTransparency = 1, Position = UDim2.fromOffset(52, 6),
    Size = UDim2.fromOffset(80, 20), Text = UI_CFG.ProfileName .. " ✔", Font = Enum.Font.GothamBold, TextSize = 13,
    TextColor3 = C.text, TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd})
new("TextLabel", {Parent = Profile, BackgroundTransparency = 1, Position = UDim2.fromOffset(52, 26),
    Size = UDim2.fromOffset(80, 18), Text = "♛ " .. UI_CFG.ProfileRole, Font = Enum.Font.GothamMedium, TextSize = 11,
    TextColor3 = C.acc2, TextXAlignment = Enum.TextXAlignment.Left})

-- ================= KOMPONEN =================
local function Card(parent, h)
    local f = new("Frame", {Parent = parent, BackgroundColor3 = C.card, Size = UDim2.new(1, 0, 0, h or 36)})
    corner(f, 10) stroke(f, C.line, 1, 0.1)
    return f
end

local function Header2(page, icon, text, rightText, rightCb)
    local f = new("Frame", {Parent = page, BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 24)})
    new("TextLabel", {Parent = f, BackgroundTransparency = 1, Size = UDim2.new(1, 0, 1, 0),
        RichText = true, Text = '<font color="#c45cff">' .. icon .. '</font>  ' .. text, Font = Enum.Font.GothamBold,
        TextSize = 14, TextColor3 = C.text, TextXAlignment = Enum.TextXAlignment.Left})
    if rightText then
        local b = new("TextButton", {Parent = f, BackgroundTransparency = 1, AnchorPoint = Vector2.new(1, 0),
            Position = UDim2.new(1, 0, 0, 0), Size = UDim2.fromOffset(90, 24), Text = rightText, Font = Enum.Font.GothamMedium,
            TextSize = 12, TextColor3 = C.sub, TextXAlignment = Enum.TextXAlignment.Right, AutoButtonColor = false})
        b.MouseButton1Click:Connect(function() if rightCb then rightCb() end end)
    end
end

local function makeSwitch(parent, flag)
    local sw = new("Frame", {Parent = parent, AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -12, 0.5, 0),
        Size = UDim2.fromOffset(46, 24), BackgroundColor3 = C.off})
    corner(sw, 12)
    local g = new("UIGradient", {Parent = sw, Color = ColorSequence.new(Color3.fromRGB(150, 70, 255), Color3.fromRGB(100, 60, 235)),
        Enabled = false})
    local knob = new("Frame", {Parent = sw, Size = UDim2.fromOffset(18, 18), Position = UDim2.fromOffset(3, 3),
        BackgroundColor3 = Color3.new(1, 1, 1)})
    corner(knob, 9)
    local function paint(v)
        g.Enabled = v
        sw.BackgroundColor3 = v and Color3.new(1, 1, 1) or C.off
        tween(knob, 0.15, {Position = v and UDim2.fromOffset(25, 3) or UDim2.fromOffset(3, 3)})
    end
    paint(Flags[flag] and true or false)
    AddView(flag, paint)
end

local function ensureFlag(flag) if Flags[flag] == nil then Flags[flag] = false end end

local function Toggle(page, text, flag, hook)
    ensureFlag(flag)
    if hook then Hooks[flag] = hook end
    local f = Card(page, 36)
    local hit = new("TextButton", {Parent = f, BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Text = ""})
    new("TextLabel", {Parent = f, BackgroundTransparency = 1, Position = UDim2.fromOffset(14, 0),
        Size = UDim2.new(1, -80, 1, 0), Text = text, Font = Enum.Font.GothamMedium, TextSize = 13, TextColor3 = C.text,
        TextXAlignment = Enum.TextXAlignment.Left})
    makeSwitch(f, flag)
    hit.MouseButton1Click:Connect(function() SetFlag(flag, not Flags[flag]) end)
end

local function Slider(page, text, flag, min, max, default, step, cb)
    step = step or 1
    local v = Saved[flag]
    if type(v) ~= "number" then v = default end
    Flags[flag] = v
    Persist[flag] = true
    local f = Card(page, 50)
    new("TextLabel", {Parent = f, BackgroundTransparency = 1, Position = UDim2.fromOffset(14, 0),
        Size = UDim2.new(1, -90, 0, 30), Text = text, Font = Enum.Font.GothamMedium, TextSize = 13, TextColor3 = C.text,
        TextXAlignment = Enum.TextXAlignment.Left})
    local val = new("TextLabel", {Parent = f, BackgroundTransparency = 1, AnchorPoint = Vector2.new(1, 0),
        Position = UDim2.new(1, -14, 0, 0), Size = UDim2.fromOffset(70, 30), Text = tostring(v),
        Font = Enum.Font.GothamBold, TextSize = 12, TextColor3 = C.acc2, TextXAlignment = Enum.TextXAlignment.Right})
    local track = new("Frame", {Parent = f, Position = UDim2.new(0, 14, 0, 36), Size = UDim2.new(1, -28, 0, 6),
        BackgroundColor3 = C.off})
    corner(track, 3)
    local fill = new("Frame", {Parent = track, Size = UDim2.fromScale((v - min) / (max - min), 1), BackgroundColor3 = Color3.new(1, 1, 1)})
    corner(fill, 3) gradient(fill, C.acc, C.acc2)
    local knob = new("Frame", {Parent = fill, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(1, 0.5),
        Size = UDim2.fromOffset(14, 14), BackgroundColor3 = Color3.new(1, 1, 1)})
    corner(knob, 7) stroke(knob, C.acc, 2)
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
    local b = new("TextButton", {Parent = page, BackgroundColor3 = C.card, Size = UDim2.new(1, 0, 0, 36), Text = text,
        Font = Enum.Font.GothamBold, TextSize = 13, TextColor3 = C.text, AutoButtonColor = false})
    corner(b, 10) stroke(b, C.line, 1, 0.1)
    b.MouseEnter:Connect(function() tween(b, 0.12, {BackgroundColor3 = C.cardHi}) end)
    b.MouseLeave:Connect(function() tween(b, 0.12, {BackgroundColor3 = C.card}) end)
    b.MouseButton1Click:Connect(function() task.spawn(cb) end)
    return b
end

local function Label(page, text)
    local f = new("TextLabel", {Parent = page, BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y, Text = text, TextWrapped = true, Font = Enum.Font.Gotham, TextSize = 11,
        TextColor3 = C.sub, TextXAlignment = Enum.TextXAlignment.Left})
    return f
end

local function Dropdown(page, text, flag, getOpts, default, cb)
    local v = Saved[flag]
    if v == nil then v = default end
    Flags[flag] = v
    Persist[flag] = true
    local box = new("Frame", {Parent = page, BackgroundColor3 = C.card, Size = UDim2.new(1, 0, 0, 36),
        AutomaticSize = Enum.AutomaticSize.Y, ClipsDescendants = true})
    corner(box, 10) stroke(box, C.line, 1, 0.1)
    local head = new("TextButton", {Parent = box, BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 36), Text = ""})
    new("TextLabel", {Parent = head, BackgroundTransparency = 1, Position = UDim2.fromOffset(14, 0),
        Size = UDim2.new(0.5, 0, 1, 0), Text = text, Font = Enum.Font.GothamMedium, TextSize = 13, TextColor3 = C.text,
        TextXAlignment = Enum.TextXAlignment.Left})
    local cur = new("TextLabel", {Parent = head, BackgroundTransparency = 1, AnchorPoint = Vector2.new(1, 0),
        Position = UDim2.new(1, -14, 0, 0), Size = UDim2.new(0.5, -20, 1, 0), Text = tostring(v or "-") .. "  ▾",
        Font = Enum.Font.GothamBold, TextSize = 12, TextColor3 = C.acc2, TextXAlignment = Enum.TextXAlignment.Right})
    local list = new("Frame", {Parent = box, BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 36),
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
            local ob = new("TextButton", {Parent = list, Size = UDim2.new(1, 0, 0, 30), BackgroundColor3 = C.cardHi,
                BackgroundTransparency = 0.3, Text = "   " .. tostring(o), Font = Enum.Font.Gotham, TextSize = 12,
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
local pHome   = newTab("Home", "🏠")
local pCombat = newTab("Scripts", "</>")
local pVisual = newTab("Visual", "👁")
local pPlayer = newTab("Player", "👤")
local pWorld  = newTab("World", "🧊")
local pMisc   = newTab("Misc", "⚙")
local pSet    = newTab("Settings", "🎚")

-- ---------- HOME ----------
do
    local welcome = new("Frame", {Parent = pHome, BackgroundColor3 = C.card, Size = UDim2.new(1, 0, 0, 66)})
    corner(welcome, 12) stroke(welcome, C.acc, 1.2, 0.3)
    gradient(welcome, Color3.fromRGB(30, 16, 60), Color3.fromRGB(70, 30, 130), 0)
    welcome.BackgroundColor3 = Color3.new(1, 1, 1)
    local star = new("TextLabel", {Parent = welcome, BackgroundTransparency = 1, Position = UDim2.fromOffset(12, 8),
        Size = UDim2.fromOffset(48, 48), Text = "★", TextSize = 38, Font = Enum.Font.GothamBlack, TextColor3 = C.acc2})
    new("TextLabel", {Parent = welcome, BackgroundTransparency = 1, Position = UDim2.fromOffset(70, 10),
        Size = UDim2.fromOffset(250, 24), Text = "Welcome to " .. UI_CFG.Name .. "!", Font = Enum.Font.GothamBold,
        TextSize = 17, TextColor3 = Color3.new(1, 1, 1), TextXAlignment = Enum.TextXAlignment.Left})
    new("TextLabel", {Parent = welcome, BackgroundTransparency = 1, Position = UDim2.fromOffset(70, 34),
        Size = UDim2.fromOffset(250, 20), RichText = true, Font = Enum.Font.Gotham, TextSize = 12, TextColor3 = C.text,
        Text = 'Enjoy your game with our powerful scripts. <font color="#ff5ccf">♥</font>',
        TextXAlignment = Enum.TextXAlignment.Left})
    local follow = new("TextButton", {Parent = welcome, AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -10, 0.5, 0),
        Size = UDim2.fromOffset(150, 46), BackgroundColor3 = Color3.fromRGB(12, 6, 24), Text = "", AutoButtonColor = false})
    corner(follow, 23) stroke(follow, C.acc2, 1.2, 0.2)
    new("TextLabel", {Parent = follow, BackgroundTransparency = 1, Position = UDim2.fromOffset(10, 0), Size = UDim2.fromOffset(28, 46),
        Text = "♪", TextSize = 22, Font = Enum.Font.GothamBlack, TextColor3 = Color3.new(1, 1, 1)})
    new("TextLabel", {Parent = follow, BackgroundTransparency = 1, Position = UDim2.fromOffset(40, 6),
        Size = UDim2.fromOffset(105, 18), Text = "Follow Admin  →", Font = Enum.Font.GothamBold, TextSize = 12,
        TextColor3 = Color3.new(1, 1, 1), TextXAlignment = Enum.TextXAlignment.Left})
    new("TextLabel", {Parent = follow, BackgroundTransparency = 1, Position = UDim2.fromOffset(40, 24),
        Size = UDim2.fromOffset(105, 14), Text = UI_CFG.FollowText .. " ♛", Font = Enum.Font.Gotham, TextSize = 9,
        TextColor3 = C.sub, TextXAlignment = Enum.TextXAlignment.Left})
    follow.MouseButton1Click:Connect(function()
        if setclipboard then setclipboard(UI_CFG.FollowText) end
        Notify("Disalin: " .. UI_CFG.FollowText)
    end)

    Header2(pHome, "⚡", "Quick Toggle")
    local grid = new("Frame", {Parent = pHome, BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y})
    new("UIGridLayout", {Parent = grid, CellSize = UDim2.new(0.5, -4, 0, 54), CellPadding = UDim2.fromOffset(8, 8),
        SortOrder = Enum.SortOrder.LayoutOrder})
    local function quick(icon, title, sub, flag, order)
        ensureFlag(flag)
        local f = new("Frame", {Parent = grid, BackgroundColor3 = C.card, LayoutOrder = order})
        corner(f, 12) stroke(f, C.line, 1, 0.1)
        local hit = new("TextButton", {Parent = f, BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Text = ""})
        new("TextLabel", {Parent = f, BackgroundTransparency = 1, Position = UDim2.fromOffset(10, 0), Size = UDim2.fromOffset(38, 54),
            Text = icon, TextSize = 24, Font = Enum.Font.GothamBold, TextColor3 = C.acc2})
        new("TextLabel", {Parent = f, BackgroundTransparency = 1, Position = UDim2.fromOffset(54, 9), Size = UDim2.new(1, -120, 0, 18),
            Text = title, Font = Enum.Font.GothamBold, TextSize = 13, TextColor3 = C.text, TextXAlignment = Enum.TextXAlignment.Left})
        new("TextLabel", {Parent = f, BackgroundTransparency = 1, Position = UDim2.fromOffset(54, 28), Size = UDim2.new(1, -120, 0, 16),
            Text = sub, Font = Enum.Font.Gotham, TextSize = 11, TextColor3 = C.sub, TextXAlignment = Enum.TextXAlignment.Left})
        makeSwitch(f, flag)
        hit.MouseButton1Click:Connect(function() SetFlag(flag, not Flags[flag]) end)
    end
    quick("🏃", "Infinite Jump", "Fly higher!", "InfJump", 1)
    quick("⌖", "ESP Players", "See players!", "ESP", 2)
    quick("💨", "Speed Boost", "Go faster!", "Speed", 3)
    quick("⬢", "No Clip", "Walk through walls!", "Noclip", 4)

    Header2(pHome, "🔥", "Popular Scripts", "See All  →", function() Tabs["Scripts"].select() end)

    local function Preset(icon, title, sub, stats, apply)
        local f = new("Frame", {Parent = pHome, BackgroundColor3 = C.card, Size = UDim2.new(1, 0, 0, 78)})
        corner(f, 12) stroke(f, C.line, 1, 0.1)
        local ico = new("Frame", {Parent = f, Position = UDim2.fromOffset(12, 11), Size = UDim2.fromOffset(56, 56),
            BackgroundColor3 = Color3.new(1, 1, 1)})
        corner(ico, 10) stroke(ico, C.acc2, 1.2)
        gradient(ico, Color3.fromRGB(40, 20, 90), Color3.fromRGB(120, 50, 230), 45)
        new("TextLabel", {Parent = ico, BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Text = icon, TextSize = 28,
            Font = Enum.Font.GothamBlack, TextColor3 = Color3.new(1, 1, 1)})
        new("TextLabel", {Parent = f, BackgroundTransparency = 1, Position = UDim2.fromOffset(80, 10), Size = UDim2.new(1, -250, 0, 20),
            RichText = true, Text = title .. ' <font color="#b565ff">✔</font>', Font = Enum.Font.GothamBold, TextSize = 14,
            TextColor3 = C.text, TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd})
        new("TextLabel", {Parent = f, BackgroundTransparency = 1, Position = UDim2.fromOffset(80, 31), Size = UDim2.new(1, -250, 0, 16),
            Text = sub, Font = Enum.Font.Gotham, TextSize = 11, TextColor3 = C.sub, TextXAlignment = Enum.TextXAlignment.Left,
            TextTruncate = Enum.TextTruncate.AtEnd})
        new("TextLabel", {Parent = f, BackgroundTransparency = 1, Position = UDim2.fromOffset(80, 52), Size = UDim2.new(1, -250, 0, 16),
            Text = stats, Font = Enum.Font.GothamMedium, TextSize = 11, TextColor3 = C.sub, TextXAlignment = Enum.TextXAlignment.Left})
        local ex = new("TextButton", {Parent = f, AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -12, 0.5, 0),
            Size = UDim2.fromOffset(128, 40), BackgroundColor3 = Color3.new(1, 1, 1), Text = "▶  Execute",
            Font = Enum.Font.GothamBold, TextSize = 14, TextColor3 = Color3.new(1, 1, 1), AutoButtonColor = false})
        corner(ex, 20) stroke(ex, C.acc2, 1.2, 0.1)
        gradient(ex, Color3.fromRGB(160, 70, 255), Color3.fromRGB(80, 60, 235), 0)
        local on = false
        ex.MouseButton1Click:Connect(function()
            on = not on
            ex.Text = on and "■  Stop" or "▶  Execute"
            apply(on)
        end)
    end

    Preset("♛", "Legends BG Auto Fight", "Auto M1, aimlock, skill & block!", "⬇ 999K+     ★ 4.9", function(on)
        for _, f in ipairs({"AutoM1", "AimLock", "AutoSkill", "Skill1", "Skill2", "Skill3", "Skill4", "AutoBlock", "FaceTarget", "Chase"}) do
            SetFlag(f, on)
        end
        LockActive = true
        if on then setMenu(false) Notify("Auto Fight aktif. Tombol 🔒 / T untuk kunci target") else Notify("Auto Fight mati") end
    end)
    Preset("⚡", "Super Anti Lag", "Hapus efek & tekstur, FPS naik!", "⬇ 850K+     ★ 4.8", function(on)
        SetFlag("SuperLag", on)
    end)
    Preset("◉", "ESP Full", "Highlight, nama, HP, jarak & tracer", "⬇ 720K+     ★ 4.8", function(on)
        for _, f in ipairs({"ESP", "ESPInfo", "Tracer"}) do SetFlag(f, on) end
    end)
end

-- ---------- SCRIPTS (COMBAT) ----------
Header2(pCombat, "⚔", "Auto Attack")
Toggle(pCombat, "Auto M1 (serang target)", "AutoM1")
Slider(pCombat, "Jarak Serang", "M1Range", 5, 40, 14, 1)
Slider(pCombat, "Delay M1 (detik)", "M1Delay", 0.05, 0.6, 0.14, 0.01)
Toggle(pCombat, "Karakter Hadap Target", "FaceTarget")
Toggle(pCombat, "Auto Chase (kejar target)", "Chase")
Slider(pCombat, "Jarak Berhenti Chase", "ChaseStop", 3, 12, 6, 1)
Toggle(pCombat, "Nempel di Belakang Target", "Stick")
Slider(pCombat, "Jarak Nempel", "StickDist", 2, 8, 3.5, 0.5)
Header2(pCombat, "🎯", "Aimlock")
Toggle(pCombat, "Aimlock Aktif", "AimLock", function(v)
    if v then LockActive = true Notify("Aimlock aktif. Tombol 🔒 / T = kunci, ⇄ / Y = ganti target") end
end)
Dropdown(pCombat, "Prioritas Target", "AimPriority", function()
    return {"Terdekat (karakter)", "Terdekat (crosshair)", "HP terendah"} end, "Terdekat (karakter)")
Dropdown(pCombat, "Bagian Aim", "AimPart", function() return {"HumanoidRootPart", "Head", "UpperTorso"} end, "HumanoidRootPart")
Slider(pCombat, "Jarak Maksimum Kunci", "AimMaxDist", 15, 150, 60, 5)
Slider(pCombat, "Kehalusan (1 = instan)", "AimSmooth", 0.05, 1, 0.35, 0.05)
Slider(pCombat, "FOV (mode crosshair)", "AimFOV", 50, 700, 300, 10)
Toggle(pCombat, "Kunci Horizontal Saja (anti pusing)", "AimYawOnly")
Toggle(pCombat, "Prediksi Gerakan Musuh", "Predict")
Slider(pCombat, "Waktu Prediksi", "PredictTime", 0.02, 0.4, 0.1, 0.01)
Button(pCombat, "Ganti Target", function()
    local n = PickTarget(AimTarget)
    if n then AimTarget = n Notify("Target: " .. n.DisplayName) else Notify("Tidak ada target lain") end
end)
Header2(pCombat, "✦", "Auto Skill")
Toggle(pCombat, "Auto Skill Aktif", "AutoSkill")
Toggle(pCombat, "Skill 1", "Skill1")
Toggle(pCombat, "Skill 2", "Skill2")
Toggle(pCombat, "Skill 3", "Skill3")
Toggle(pCombat, "Skill 4", "Skill4")
Slider(pCombat, "Delay Antar Skill (detik)", "SkillDelay", 0.2, 3, 0.8, 0.05)
Slider(pCombat, "Jarak Pakai Skill", "SkillRange", 5, 60, 25, 1)
Header2(pCombat, "🛡", "Defense")
Toggle(pCombat, "Auto Block (F) saat musuh nyerang", "AutoBlock")
Slider(pCombat, "Jarak Deteksi Serangan", "BlockRange", 5, 35, 16, 1)
Toggle(pCombat, "Auto Dodge (Q) saat musuh nyerang", "AutoDodge")
Toggle(pCombat, "Auto Awaken (G)", "AutoAwaken")
Toggle(pCombat, "Anti Ragdoll", "AntiRagdoll")
Header2(pCombat, "◎", "Target & Hitbox")
Toggle(pCombat, "Abaikan Teman", "IgnoreFriends")
Toggle(pCombat, "Abaikan Pemain ber-ForceField", "IgnoreFF")
Toggle(pCombat, "Hitbox Expander", "Hitbox", function(v)
    if not v then
        for _, p in ipairs(Players:GetPlayers()) do
            local r = p ~= LP and Root(p.Character)
            if r then r.Size = Vector3.new(2, 2, 1) r.Transparency = 1 r.CanCollide = true end
        end
    end
end)
Slider(pCombat, "Ukuran Hitbox", "HitboxSize", 2, 30, 10, 1)

-- ---------- VISUAL ----------
Header2(pVisual, "◉", "ESP")
Toggle(pVisual, "ESP Highlight + Nama", "ESP", function() RefreshESP() end)
Toggle(pVisual, "Tampilkan HP & Jarak", "ESPInfo")
Toggle(pVisual, "Tracer (garis ke pemain)", "Tracer", function(v)
    if v and not HasDrawing then Notify("Executor kamu tidak punya Drawing API") end
end)
Header2(pVisual, "🎯", "HUD & Kamera")
Toggle(pVisual, "Lingkaran FOV Aim", "ShowFOV")
SetFlag("TargetHUD", true)
Toggle(pVisual, "HUD Info Target", "TargetHUD")
Slider(pVisual, "Field of View Kamera", "CamFOV", 40, 120, 70, 1, function(v) Cam.FieldOfView = v end)
Slider(pVisual, "Zoom Maksimum Kamera", "Zoom", 20, 500, 128, 10, function(v) LP.CameraMaxZoomDistance = v end)

-- ---------- PLAYER ----------
Header2(pPlayer, "💨", "Gerak")
Toggle(pPlayer, "WalkSpeed", "Speed", function(v) if not v and Hum() then Hum().WalkSpeed = 16 end end)
Slider(pPlayer, "Nilai Speed", "SpeedVal", 16, 150, 40, 1)
Toggle(pPlayer, "CFrame Speed (lebih aman)", "CFSpeed")
Slider(pPlayer, "Nilai CFrame Speed", "CFSpeedVal", 10, 120, 40, 1)
Toggle(pPlayer, "JumpPower", "Jump", function(v)
    if not v and Hum() then Hum().UseJumpPower = true Hum().JumpPower = 50 end
end)
Slider(pPlayer, "Nilai Jump", "JumpVal", 50, 300, 90, 5)
Toggle(pPlayer, "Infinite Jump", "InfJump")
Toggle(pPlayer, "Noclip", "Noclip")
Header2(pPlayer, "🕊", "Terbang & Lainnya")
Toggle(pPlayer, "Fly", "Fly", function(v) if v then StartFly() else StopFly() end end)
Slider(pPlayer, "Kecepatan Fly", "FlySpeed", 20, 250, 70, 5)
Toggle(pPlayer, "Anti Void", "AntiVoid")
Toggle(pPlayer, "Spin", "Spin")
Toggle(pPlayer, "Ctrl + Klik = Teleport", "ClickTP")
Slider(pPlayer, "Gravitasi", "Gravity", 20, 400, 196, 2, function(v) Workspace.Gravity = v end)

-- ---------- WORLD ----------
Header2(pWorld, "⚡", "Anti Lag")
Toggle(pWorld, "Anti Lag (matikan efek & bayangan)", "AntiLag", function(v)
    if v then SetLive() ProcessAll(false) Notify("Anti Lag aktif: efek skill dimatikan")
    elseif not Flags.SuperLag then RestoreFx() end
end)
Toggle(pWorld, "SUPER Anti Lag (grafik minimum)", "SuperLag", function(v)
    if v then SetLive() ProcessAll(true) Notify("Super Anti Lag aktif. Rejoin untuk mengembalikan tampilan") end
end)
Button(pWorld, "Hapus Semua Efek Sekarang (sekali)", function()
    ProcessAll(true) Notify("Membersihkan efek & tekstur...")
end)
Header2(pWorld, "🖥", "FPS & Render")
Slider(pWorld, "Batas FPS", "FPSCap", 30, 360, 144, 10, function(v) if setfpscap then setfpscap(v) end end)
Slider(pWorld, "Kualitas Grafik (1 = terendah)", "Quality", 1, 10, 1, 1, function(v)
    pcall(function() settings().Rendering.QualityLevel = v end)
end)
Toggle(pWorld, "Matikan Render 3D (layar kosong, hemat baterai)", "NoRender", function(v)
    pcall(function() RunService:Set3dRenderingEnabled(not v) end)
end)
Button(pWorld, "Bersihkan Memori", function() collectgarbage("collect") Notify("Memori dibersihkan") end)
Header2(pWorld, "☀", "Lingkungan")
Toggle(pWorld, "Fullbright", "Fullbright", function(v)
    if v then
        Lighting.Brightness = 2 Lighting.Ambient = Color3.new(1, 1, 1) Lighting.OutdoorAmbient = Color3.new(1, 1, 1)
    else
        Lighting.Brightness = 1 Lighting.Ambient = Color3.fromRGB(70, 70, 70) Lighting.OutdoorAmbient = Color3.fromRGB(70, 70, 70)
    end
end)
Toggle(pWorld, "Hapus Kabut", "NoFog", function(v) if v then Lighting.FogEnd = 9e9 end end)
Slider(pWorld, "Waktu (jam)", "ClockTime", 0, 24, 14, 0.5, function(v) Lighting.ClockTime = v end)

-- ---------- MISC ----------
Header2(pMisc, "📍", "Teleport")
local function PlayerNames()
    local t = {}
    for _, p in ipairs(Players:GetPlayers()) do if p ~= LP then t[#t + 1] = p.Name end end
    if #t == 0 then t[1] = "(kosong)" end
    return t
end
Dropdown(pMisc, "Pilih Pemain", "TPTarget", PlayerNames, "(pilih)")
Button(pMisc, "Teleport ke Pemain", function()
    local p = Players:FindFirstChild(tostring(Flags.TPTarget))
    local r, tr = Root(), p and Root(p.Character)
    if r and tr then r.CFrame = tr.CFrame * CFrame.new(0, 0, 3) else Notify("Pemain tidak ditemukan") end
end)
Button(pMisc, "Teleport ke Pemain Terdekat", function()
    local p = NearestEnemy()
    local r = Root()
    if p and r then r.CFrame = Root(p.Character).CFrame * CFrame.new(0, 0, 3) else Notify("Tidak ada pemain") end
end)
Button(pMisc, "Teleport ke Pemain Acak", function()
    local list = {}
    for _, p in ipairs(Players:GetPlayers()) do if IsEnemy(p) then list[#list + 1] = p end end
    local r = Root()
    if #list > 0 and r then r.CFrame = Root(list[math.random(#list)].Character).CFrame * CFrame.new(0, 0, 3) end
end)
Toggle(pMisc, "Spectate Pemain Terpilih", "Spectate", function(v)
    local p = Players:FindFirstChild(tostring(Flags.TPTarget))
    if v and p and p.Character and Hum(p.Character) then Cam.CameraSubject = Hum(p.Character)
    elseif Hum() then Cam.CameraSubject = Hum() end
end)
local savedCF
Button(pMisc, "Simpan Posisi Sekarang", function()
    if Root() then savedCF = Root().CFrame Notify("Posisi disimpan") end
end)
Button(pMisc, "Teleport ke Posisi Tersimpan", function()
    if savedCF and Root() then Root().CFrame = savedCF else Notify("Belum ada posisi tersimpan") end
end)
Header2(pMisc, "🌐", "Server")
SetFlag("AntiAFK", true)
Toggle(pMisc, "Anti AFK", "AntiAFK")
Toggle(pMisc, "Auto Respawn", "AutoRespawn")
Button(pMisc, "Reset Karakter", function() if Hum() then Hum().Health = 0 end end)
Button(pMisc, "Rejoin Server", function() TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, LP) end)
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

-- ---------- SETTINGS ----------
Header2(pSet, "🎚", "Tampilan")
Slider(pSet, "Ukuran UI", "UIScale", 0.6, 1.3, 1, 0.05, function() fitScale() end)
Toggle(pSet, "Tampilkan FPS & Ping di header", "ShowStats")
Header2(pSet, "⌨", "Kontrol")
Label(pSet, "RightCtrl = buka/tutup menu\nT = kunci/lepas aimlock\nY = ganti target\nCtrl + klik = teleport (jika aktif)")
Header2(pSet, "💾", "Config")
Button(pSet, "Simpan Pengaturan Sekarang", function() queueSave() Notify("Pengaturan disimpan") end)
Button(pSet, "Reset Pengaturan Tersimpan", function()
    pcall(function() if delfile and isfile(CFG) then delfile(CFG) end end)
    Notify("Config dihapus. Jalankan ulang script")
end)

-- ============================================================
--              TOMBOL MELAYANG AIMLOCK & HUD TARGET
-- ============================================================
local AimBtns = new("Frame", {Parent = Gui, BackgroundTransparency = 1, AnchorPoint = Vector2.new(1, 0.5),
    Position = UDim2.new(1, -16, 0.55, 0), Size = UDim2.fromOffset(52, 112), Visible = false})
new("UIListLayout", {Parent = AimBtns, Padding = UDim.new(0, 8)})
local function roundBtn(txt)
    local b = new("TextButton", {Parent = AimBtns, Size = UDim2.fromOffset(52, 52), BackgroundColor3 = C.bg,
        BackgroundTransparency = 0.15, Text = txt, TextSize = 22, Font = Enum.Font.GothamBold, TextColor3 = C.text,
        AutoButtonColor = false})
    corner(b, 26) stroke(b, C.acc2, 2, 0.1)
    return b
end
local LockBtn, SwitchBtn = roundBtn("🔒"), roundBtn("⇄")
AddView("AimLock", function(v) AimBtns.Visible = v end)

local function ToggleLock()
    LockActive = not LockActive
    LockBtn.Text = LockActive and "🔒" or "🔓"
    LockBtn.BackgroundColor3 = LockActive and Color3.fromRGB(90, 40, 180) or C.bg
    if not LockActive then AimTarget = nil end
    Notify(LockActive and "Aimlock: kunci aktif" or "Aimlock: dilepas")
end
local function SwitchTarget()
    local n = PickTarget(AimTarget)
    if n then AimTarget = n LockActive = true Notify("Target: " .. n.DisplayName) else Notify("Tidak ada target lain") end
end
LockBtn.MouseButton1Click:Connect(ToggleLock)
SwitchBtn.MouseButton1Click:Connect(SwitchTarget)
LockBtn.BackgroundColor3 = Color3.fromRGB(90, 40, 180)

local HUD = new("Frame", {Parent = Gui, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 16),
    Size = UDim2.fromOffset(220, 34), BackgroundColor3 = C.bg, BackgroundTransparency = 0.1, Visible = false})
corner(HUD, 17) stroke(HUD, C.acc2, 1.5, 0.1)
local HUDl = new("TextLabel", {Parent = HUD, BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Text = "",
    Font = Enum.Font.GothamBold, TextSize = 12, TextColor3 = C.text})

-- ============================================================
--                    LOGIKA / LOOP
-- ============================================================
fitScale()
Tabs["Home"].select()

Connect(UIS.InputBegan, function(i, gp)
    if gp then return end
    if i.KeyCode == Enum.KeyCode.RightControl then setMenu(not Main.Visible)
    elseif i.KeyCode == Enum.KeyCode.T and Flags.AimLock then ToggleLock()
    elseif i.KeyCode == Enum.KeyCode.Y and Flags.AimLock then SwitchTarget()
    elseif i.UserInputType == Enum.UserInputType.MouseButton1 and Flags.ClickTP
        and UIS:IsKeyDown(Enum.KeyCode.LeftControl) and Root() then
        Root().CFrame = CFrame.new(Mouse.Hit.Position + Vector3.new(0, 3, 0))
    end
end)

-- FPS / Ping
local frames, lastT = 0, tick()
Connect(RunService.RenderStepped, function()
    frames += 1
    if tick() - lastT >= 0.5 then
        local fps = math.floor(frames / (tick() - lastT) + 0.5)
        local ping = 0
        pcall(function() ping = math.floor(Stats.Network.ServerStatsItem["Data Ping"]:GetValue()) end)
        StatLbl.Text = Flags.ShowStats and (fps .. " FPS  |  " .. ping .. " ms") or ""
        frames, lastT = 0, tick()
    end
end)

-- FOV circle & tracer
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
Connect(RunService.RenderStepped, function()
    local vs = Cam.ViewportSize
    if FOVCircle then
        FOVCircle.Visible = Flags.ShowFOV and true or false
        FOVCircle.Position = Vector2.new(vs.X / 2, vs.Y / 2)
        FOVCircle.Radius = Flags.AimFOV
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

-- ESP info
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
                        txt = string.format("%s\n%d HP | %dm", p.DisplayName, h.Health, (r.Position - myR.Position).Magnitude)
                    end
                    d.tl.Text = txt
                end
            end
        end
    end
end)

-- Pemilihan target aimlock (sticky) + HUD
task.spawn(function()
    while Running do
        task.wait(0.1)
        if Flags.AimLock and LockActive then
            if not ValidTarget(AimTarget) then AimTarget = PickTarget() end
        else
            AimTarget = nil
        end
        local show = Flags.TargetHUD and AimTarget and Flags.AimLock and LockActive
        HUD.Visible = show and true or false
        if show then
            local h, r, me = Hum(AimTarget.Character), Root(AimTarget.Character), Root()
            if h and r and me then
                HUDl.Text = string.format("🔒 %s  |  %d HP  |  %dm", AimTarget.DisplayName, h.Health,
                    (r.Position - me.Position).Magnitude)
            end
        end
    end
end)

-- Target tempur (dipakai M1, skill, chase)
local CT, CTDist = nil, math.huge
local rotateHeld = false

-- Auto M1
task.spawn(function()
    while Running do
        task.wait(Flags.M1Delay or 0.14)
        if Flags.AutoM1 and CT and CTDist <= Flags.M1Range and not Main.Visible then Click() end
    end
end)

-- Auto Skill
task.spawn(function()
    local keys = {Enum.KeyCode.One, Enum.KeyCode.Two, Enum.KeyCode.Three, Enum.KeyCode.Four}
    local names = {"Skill1", "Skill2", "Skill3", "Skill4"}
    while Running do
        task.wait(Flags.SkillDelay or 0.8)
        if Flags.AutoSkill and CT and CTDist <= Flags.SkillRange and not Main.Visible then
            for i = 1, 4 do
                if Flags[names[i]] then
                    Tap(keys[i], 0.04)
                    task.wait(0.12)
                end
            end
        end
    end
end)

-- Auto Block / Dodge
local blocking, lastDodge = false, 0
task.spawn(function()
    while Running do
        task.wait(0.05)
        local want = false
        local r = Root()
        if r and (Flags.AutoBlock or Flags.AutoDodge) then
            for _, p in ipairs(Players:GetPlayers()) do
                if IsEnemy(p) and (Root(p.Character).Position - r.Position).Magnitude <= Flags.BlockRange
                    and IsAttacking(p) then
                    want = true break
                end
            end
        end
        local doBlock = want and Flags.AutoBlock
        if doBlock and not blocking then
            blocking = true
            VIM:SendKeyEvent(true, Enum.KeyCode.F, false, game)
        elseif not doBlock and blocking then
            blocking = false
            VIM:SendKeyEvent(false, Enum.KeyCode.F, false, game)
        end
        if want and Flags.AutoDodge and not Flags.AutoBlock and tick() - lastDodge > 1.6 then
            lastDodge = tick()
            Tap(Enum.KeyCode.Q, 0.04)
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
    if not h or not r then CT = nil return end

    -- target tempur
    local locked = Flags.AimLock and LockActive and AimTarget and IsEnemy(AimTarget)
    if locked then
        CT = AimTarget
        CTDist = (Root(CT.Character).Position - r.Position).Magnitude
    elseif Flags.AutoM1 or Flags.AutoSkill or Flags.Chase or Flags.Stick then
        CT, CTDist = NearestEnemy(math.max(Flags.M1Range or 14, Flags.SkillRange or 25, 60))
    else
        CT = nil
    end

    -- hadap target (tanpa merusak posisi)
    local face = Flags.FaceTarget and CT and (locked or (Flags.AutoM1 and CTDist <= (Flags.M1Range or 14) + 4))
    if face and not Flags.Fly then
        h.AutoRotate = false
        rotateHeld = true
        local tp = Root(CT.Character).Position
        local flat = Vector3.new(tp.X, r.Position.Y, tp.Z)
        if (flat - r.Position).Magnitude > 0.2 then r.CFrame = CFrame.lookAt(r.Position, flat) end
    elseif rotateHeld then
        h.AutoRotate = true
        rotateHeld = false
    end

    -- chase
    if Flags.Chase and CT and CTDist > (Flags.ChaseStop or 6) and not Flags.Fly then
        h:MoveTo(Root(CT.Character).Position)
    end

    -- nempel di belakang (halus)
    if Flags.Stick and CT then
        local tr = Root(CT.Character)
        local goal = (tr.CFrame * CFrame.new(0, 0, Flags.StickDist)).Position
        local pos = r.Position:Lerp(goal, math.clamp(dt * 12, 0, 1))
        r.CFrame = CFrame.lookAt(pos, Vector3.new(tr.Position.X, pos.Y, tr.Position.Z))
    end

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
        local look = Cam.CFrame.LookVector
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

    if Flags.Spin and not Flags.AutoM1 and not locked then r.CFrame = r.CFrame * CFrame.Angles(0, math.rad(25), 0) end

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
    rotateHeld = false
    AimTarget = nil
    ReleaseCam()
    task.wait(0.5)
    if Flags.Fly then StartFly() end
end)

-- Tutup / unload
local function Unload()
    Running = false
    if blocking then VIM:SendKeyEvent(false, Enum.KeyCode.F, false, game) end
    pcall(function() RunService:UnbindFromRenderStep("KZ_Aim") end)
    ReleaseCam()
    local h = Hum()
    if h then h.AutoRotate = true end
    StopFly()
    for p in pairs(ESPData) do ClearESP(p) end
    for p in pairs(Tracers) do ClearESP(p) end
    if FOVCircle then pcall(function() FOVCircle:Remove() end) end
    pcall(function() RunService:Set3dRenderingEnabled(true) end)
    for _, c in ipairs(Conns) do pcall(function() c:Disconnect() end) end
    Gui:Destroy()
end
BtnClose.MouseButton1Click:Connect(Unload)
Button(pSet, "Tutup Script (Unload)", Unload)

Notify("KizzDev LB v3 siap. Mahkota / RightCtrl = buka tutup menu.")
