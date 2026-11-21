--[[
    KizzDev | Legends Battlegrounds  v5
    UI: Rayfield (tema ungu KizzDev) + HUD/cooldown overlay
    Menu   : RightCtrl / logo melayang
    Aimlock: tombol 🔒 melayang / T  |  ganti target: ⇄ / Y
    Game   : Q dash, F block, G awaken, M1 klik kiri, skill 1-4
]]

-- ================= MUAT RAYFIELD =================
local Rayfield
do
    local ok, lib = pcall(function() return loadstring(game:HttpGet("https://sirius.menu/rayfield"))() end)
    if not ok or not lib then
        warn("[KizzDev] Gagal memuat Rayfield: " .. tostring(lib))
        return
    end
    Rayfield = lib
end

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
local CFG = "KizzDev/LegendsBattlegrounds_v5.json"
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

local Targets
local FriendCache = {}
local function IsFriend(p)
    if p.IsNPC then return false end
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
    for _, p in ipairs(Targets()) do
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
    hl.FillColor = Flags.ESPColor or Color3.fromRGB(150, 70, 255)
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
    if Flags.OnlyChosen then
        local cp = Players:FindFirstChild(tostring(Flags.ChosenTarget))
        if cp and cp ~= exclude and IsEnemy(cp) then return cp end
        return nil
    end
    local prio = Flags.AimPriority or "Terdekat (karakter)"
    local maxD = Flags.AimMaxDist or 60
    local best, bs = nil, math.huge
    local vs = Cam.ViewportSize
    local center = Vector2.new(vs.X / 2, vs.Y / 2)
    for _, p in ipairs(Targets()) do
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
    if Flags.OnlyChosen and p.Name ~= Flags.ChosenTarget then return false end
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
--            HELPER, TARGET (PLAYER + NPC) & MODUL v5
-- ============================================================
local Shared = {Kills = 0, Dmg = 0, PB = 0}
local C = {
    bg = Color3.fromRGB(10, 6, 20), panel = Color3.fromRGB(16, 10, 30),
    acc = Color3.fromRGB(150, 70, 255), acc2 = Color3.fromRGB(212, 104, 255),
    text = Color3.fromRGB(240, 236, 250), sub = Color3.fromRGB(150, 140, 178),
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
    return new("UIStroke", {Color = col or Color3.new(1, 1, 1), Thickness = th or 1, Transparency = tr or 0, Parent = o,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border})
end
local function tween(o, t, props)
    TweenService:Create(o, TweenInfo.new(t, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), props):Play()
end

local Gui = new("ScreenGui", {Name = "KizzDev_LB", ResetOnSpawn = false, ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
    DisplayOrder = 999, IgnoreGuiInset = true, Parent = PARENT})

local CT, CTDist = nil, math.huge   -- target tempur aktif (diisi loop Heartbeat)

local function Notify(msg)
    pcall(function() Rayfield:Notify({Title = "KizzDev", Content = tostring(msg), Duration = 3.5}) end)
end

local logoImg = nil -- Logo eksternal/embedded dihapus sesuai permintaan.

-- ============ TARGET: PLAYER + NPC ============
local NPCList, NPCObjs = {}, setmetatable({}, {__mode = "k"})
local function npcObj(model)
    local o = NPCObjs[model]
    if not o then
        o = {Character = model, Name = model.Name, DisplayName = model.Name, UserId = 0, IsNPC = true}
        NPCObjs[model] = o
    end
    return o
end
task.spawn(function()
    while Running do
        if Flags.IncludeNPC then
            local list, n = {}, 0
            for _, h in ipairs(Workspace:GetDescendants()) do
                n += 1
                if n % 600 == 0 then task.wait() end
                if h:IsA("Humanoid") and h.Health > 0 then
                    local m = h.Parent
                    if m and m:IsA("Model") and m ~= LP.Character and not Players:GetPlayerFromCharacter(m)
                        and m:FindFirstChild("HumanoidRootPart") then
                        list[#list + 1] = npcObj(m)
                    end
                end
            end
            NPCList = list
        else
            NPCList = {}
        end
        task.wait(3)
    end
end)
Targets = function()
    local t = Players:GetPlayers()
    for _, o in ipairs(NPCList) do t[#t + 1] = o end
    return t
end

-- ============ HITBOX ============
local HBOrig, HBLast = {}, 0
local function RestoreHitbox()
    for part, o in pairs(HBOrig) do
        pcall(function()
            if part.Parent then
                part.Size = o.Size part.Transparency = o.Transparency
                part.CanCollide = o.CanCollide part.Material = o.Material
            end
        end)
    end
    HBOrig = {}
end
local function ApplyHitbox()
    if tick() - HBLast < 0.15 then return end
    HBLast = tick()
    local r = Root()
    local size = Flags.HitboxSize or 10
    local range = Flags.HitboxRange or 120
    for _, p in ipairs(Targets()) do
        if p ~= LP and p.Character then
            local part = p.Character:FindFirstChild(Flags.HitboxPart or "HumanoidRootPart")
            if part and part:IsA("BasePart") then
                local ok = true
                if r and range < 400 then ok = (part.Position - r.Position).Magnitude <= range end
                if ok then
                    if not HBOrig[part] then
                        HBOrig[part] = {Size = part.Size, Transparency = part.Transparency,
                            CanCollide = part.CanCollide, Material = part.Material}
                    end
                    part.Size = Vector3.new(size, size, size)
                    part.Transparency = Flags.HitboxTrans or 0.75
                    part.CanCollide = false
                    part.Material = Enum.Material.Neon
                end
            end
        end
    end
end

-- ============ SKILL COOLDOWN TRACKER ============
local SkillUntil = {0, 0, 0, 0}
local function SkillReady(i) return tick() >= (SkillUntil[i] or 0) end
local function MarkSkill(i) SkillUntil[i] = tick() + (Flags["SkillCD" .. i] or 10) end
do
    local digit = {[Enum.KeyCode.One] = 1, [Enum.KeyCode.Two] = 2, [Enum.KeyCode.Three] = 3, [Enum.KeyCode.Four] = 4}
    Connect(UIS.InputBegan, function(i)
        local n = digit[i.KeyCode]
        if n and not UIS:GetFocusedTextBox() and SkillReady(n) then MarkSkill(n) end
    end)
end

-- ============ SERVER HOP ============
local function ServerHop()
    local ok, data = pcall(function()
        return HttpService:JSONDecode(game:HttpGet(
            "https://games.roblox.com/v1/games/" .. game.PlaceId .. "/servers/Public?sortOrder=Asc&limit=100"))
    end)
    if ok and data and data.data then
        for _, s in ipairs(data.data) do
            if s.playing < s.maxPlayers and s.id ~= game.JobId then
                TeleportService:TeleportToPlaceInstance(game.PlaceId, s.id, LP)
                return true
            end
        end
    end
    Notify("Server lain tidak ditemukan")
    return false
end

-- ============ DAMAGE INDICATOR + PERFECT BLOCK (hook per target) ============
do
    local Debris = game:GetService("Debris")
    local hookedH = setmetatable({}, {__mode = "k"})
    local hookedA = setmetatable({}, {__mode = "k"})
    local lastPB = 0

    local function show(char, amount, mine)
        local part = char:FindFirstChild("Head") or char:FindFirstChild("HumanoidRootPart")
        if not part then return end
        local big = amount >= (Flags.DmgBig or 25)
        local col = mine and Color3.fromRGB(255, 90, 110) or (Flags.DmgColor or Color3.new(1, 1, 1))
        if big and not mine then col = Color3.fromRGB(255, 170, 60) end
        local bb = Instance.new("BillboardGui")
        bb.Name = "KZ_TAG"
        bb.Size = UDim2.fromOffset(120, 36)
        bb.AlwaysOnTop = true
        bb.Adornee = part
        bb.StudsOffsetWorldSpace = Vector3.new(math.random(-12, 12) / 10, 3, math.random(-12, 12) / 10)
        local tl = Instance.new("TextLabel")
        tl.Size = UDim2.fromScale(1, 1)
        tl.BackgroundTransparency = 1
        tl.Text = "-" .. tostring(math.floor(amount + 0.5))
        tl.Font = Enum.Font.GothamBlack
        tl.TextSize = math.clamp((Flags.DmgSize or 18) + (big and 6 or 0), 10, 44)
        tl.TextColor3 = col
        tl.TextStrokeColor3 = Color3.new(0, 0, 0)
        tl.TextStrokeTransparency = 0.2
        tl.Parent = bb
        bb.Parent = part
        TweenService:Create(bb, TweenInfo.new(0.9, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
            {StudsOffsetWorldSpace = bb.StudsOffsetWorldSpace + Vector3.new(0, 3.5, 0)}):Play()
        TweenService:Create(tl, TweenInfo.new(0.9), {TextTransparency = 1, TextStrokeTransparency = 1}):Play()
        Debris:AddItem(bb, 1)
    end

    local function hookHealth(p, mine)
        local ch = p.Character
        local h = ch and Hum(ch)
        if not h or hookedH[h] then return end
        hookedH[h] = true
        local last = h.Health
        h.HealthChanged:Connect(function(nh)
            local d = last - nh
            last = nh
            if not Running or d < (Flags.DmgMin or 1) then return end
            if mine then
                if Flags.DmgSelf then pcall(show, ch, d, true) end
            else
                if Flags.DmgIndicator then pcall(show, ch, d, false) end
                if CT and CT == p then Shared.Dmg += d end
            end
        end)
    end

    local function hookPB(p)
        local h = p.Character and Hum(p.Character)
        local a = h and h:FindFirstChildOfClass("Animator")
        if not a or hookedA[a] then return end
        hookedA[a] = true
        a.AnimationPlayed:Connect(function(track)
            if not (Running and Flags.PerfectBlock) then return end
            if not ActionPrio[track.Priority] then return end
            local r, tr = Root(), p.Character and Root(p.Character)
            if not r or not tr then return end
            if (tr.Position - r.Position).Magnitude > (Flags.PBRange or 14) then return end
            if Flags.PBFacing then
                local toMe = r.Position - tr.Position
                if toMe.Magnitude > 0 and tr.CFrame.LookVector:Dot(toMe.Unit) < 0.2 then return end
            end
            if tick() - lastPB < (Flags.PBCooldown or 0.5) then return end
            lastPB = tick()
            task.delay(Flags.PBDelay or 0.12, function()
                if not (Running and Flags.PerfectBlock) then return end
                local r2, tr2 = Root(), p.Character and Root(p.Character)
                if Flags.PBFace and r2 and tr2 then
                    r2.CFrame = CFrame.lookAt(r2.Position, Vector3.new(tr2.Position.X, r2.Position.Y, tr2.Position.Z))
                end
                VIM:SendKeyEvent(true, Enum.KeyCode.F, false, game)
                task.wait(Flags.PBHold or 0.28)
                VIM:SendKeyEvent(false, Enum.KeyCode.F, false, game)
                Shared.PB += 1
            end)
        end)
    end

    task.spawn(function()
        while Running do
            task.wait(1)
            if Flags.DmgIndicator or Flags.DmgSelf or Flags.PerfectBlock then
                pcall(function()
                    hookHealth({Character = LP.Character}, true)
                    for _, p in ipairs(Targets()) do
                        if p ~= LP then
                            hookHealth(p, false)
                            hookPB(p)
                        end
                    end
                end)
            end
        end
    end)
end

-- ============ KILL COUNTER + FARM IDLE ============
do
    local counted = setmetatable({}, {__mode = "k"})
    local lastHum, idleSince = nil, tick()
    task.spawn(function()
        while Running do
            task.wait(0.2)
            if CT and CT.Character then
                local h = Hum(CT.Character)
                if h then lastHum = h end
                idleSince = tick()
            end
            if lastHum and lastHum.Health <= 0 and not counted[lastHum] then
                counted[lastHum] = true
                Shared.Kills += 1
                lastHum = nil
            end
            if Flags.AutoFarm and Flags.FarmHop and not CT and tick() - idleSince > (Flags.FarmHopSec or 25) then
                idleSince = tick() + 60
                Notify("Tidak ada target, pindah server...")
                ServerHop()
            end
        end
    end)
end

-- ============================================================
--                 UI RAYFIELD (tema KizzDev)
-- ============================================================
local Els, FlagHooks = {}, {}
local function SetFlag(flag, v)
    v = v and true or false
    local changed = Flags[flag] ~= v
    Flags[flag] = v
    local e = Els[flag]
    if e then pcall(function() e:Set(v) end) end
    -- Jalankan efek toggle secara langsung agar preset tidak bergantung pada
    -- apakah versi Rayfield memanggil Callback ketika Set() digunakan.
    if changed and FlagHooks[flag] then
        task.spawn(function()
            local ok, err = pcall(FlagHooks[flag], v)
            if not ok then warn("[KizzDev] preset " .. flag .. ": " .. tostring(err)) end
        end)
    end
    if Persist[flag] then queueSave() end
end

-- Deteksi apakah jendela Rayfield sedang terbuka (dipakai loop auto-klik)
local RFGui
local function findRF()
    if RFGui and RFGui.Parent then return RFGui end
    for _, root in ipairs({PARENT, game:GetService("CoreGui"), LP:FindFirstChild("PlayerGui")}) do
        local ok, g = pcall(function() return root and root:FindFirstChild("Rayfield") end)
        if ok and g then RFGui = g return g end
    end
end
local Main = setmetatable({}, {__index = function(_, k)
    if k == "Visible" then
        local ok, vis = pcall(function()
            local g = findRF()
            local m = g and g:FindFirstChild("Main")
            return g and g.Enabled and m and m.Visible and m.AbsoluteSize.Y > 120
        end)
        return (ok and vis) and true or false
    end
end})

local Splash = nil -- Splash overlay dihapus agar tidak menutupi menu.

-- ================= TEMA =================
local function buildTheme()
    local base = Rayfield.Theme and (Rayfield.Theme.Amethyst or Rayfield.Theme.Default)
    if typeof(base) ~= "table" then return "Amethyst" end
    local t = {}
    for k, v in pairs(base) do t[k] = v end
    local function set(k, col) if t[k] ~= nil then t[k] = col end end
    set("TextColor", Color3.fromRGB(245, 240, 255))
    set("Background", Color3.fromRGB(12, 8, 22))
    set("Topbar", Color3.fromRGB(24, 13, 44))
    set("Shadow", Color3.fromRGB(8, 4, 16))
    set("NotificationBackground", Color3.fromRGB(16, 10, 30))
    set("NotificationActionsBackground", Color3.fromRGB(230, 200, 255))
    set("TabBackground", Color3.fromRGB(26, 16, 48))
    set("TabStroke", Color3.fromRGB(70, 40, 130))
    set("TabBackgroundSelected", Color3.fromRGB(150, 70, 255))
    set("TabTextColor", Color3.fromRGB(200, 180, 235))
    set("SelectedTabTextColor", Color3.fromRGB(255, 255, 255))
    set("ElementBackground", Color3.fromRGB(20, 13, 36))
    set("ElementBackgroundHover", Color3.fromRGB(32, 21, 56))
    set("SecondaryElementBackground", Color3.fromRGB(16, 10, 30))
    set("ElementStroke", Color3.fromRGB(62, 36, 112))
    set("SecondaryElementStroke", Color3.fromRGB(46, 28, 86))
    set("SliderBackground", Color3.fromRGB(110, 50, 200))
    set("SliderProgress", Color3.fromRGB(176, 84, 255))
    set("SliderStroke", Color3.fromRGB(200, 130, 255))
    set("ToggleBackground", Color3.fromRGB(20, 13, 36))
    set("ToggleEnabled", Color3.fromRGB(176, 84, 255))
    set("ToggleDisabled", Color3.fromRGB(80, 66, 110))
    set("ToggleEnabledStroke", Color3.fromRGB(210, 140, 255))
    set("ToggleDisabledStroke", Color3.fromRGB(110, 96, 140))
    set("ToggleEnabledOuterStroke", Color3.fromRGB(110, 50, 200))
    set("ToggleDisabledOuterStroke", Color3.fromRGB(50, 40, 76))
    set("DropdownSelected", Color3.fromRGB(36, 22, 62))
    set("DropdownUnselected", Color3.fromRGB(22, 14, 40))
    set("InputBackground", Color3.fromRGB(16, 10, 30))
    set("InputStroke", Color3.fromRGB(90, 50, 160))
    set("PlaceholderColor", Color3.fromRGB(150, 130, 190))
    return t
end

local function Boot(msg)
    if Shared.SplashMsg then pcall(function() Shared.SplashMsg.Text = msg end) end
end
local function tryWindow(cfg)
    return pcall(function() return Rayfield:CreateWindow(cfg) end)
end
local Window
do
    Boot("Membuat jendela...")
    local cfg = {
        Name = "KizzDev  |  Legends Battlegrounds",
        LoadingTitle = "KizzDev",
        LoadingSubtitle = "Legends Battlegrounds v5",
        ShowText = "KizzDev",
        Theme = buildTheme(),
        ToggleUIKeybind = Enum.KeyCode.RightControl,
        DisableRayfieldPrompts = true,
        DisableBuildWarnings = true,
        ConfigurationSaving = {Enabled = false},
        KeySystem = false,
    }
    local ok, res = tryWindow(cfg)
    if not ok then
        warn("[KizzDev] CreateWindow gagal: " .. tostring(res))
        Boot("Mode aman...")
        pcall(function() Rayfield:Destroy() end)
        local ok2, lib = pcall(function() return loadstring(game:HttpGet("https://sirius.menu/rayfield"))() end)
        if ok2 and lib then Rayfield = lib end
        local ok3, res3 = tryWindow({Name = "KizzDev  |  Legends Battlegrounds", LoadingTitle = "KizzDev",
            LoadingSubtitle = "Mode aman", Theme = "Amethyst", DisableRayfieldPrompts = true, DisableBuildWarnings = true,
            ConfigurationSaving = {Enabled = false}, KeySystem = false})
        if not ok3 then
            warn("[KizzDev] CreateWindow mode aman gagal: " .. tostring(res3))
            Boot("Gagal membuat UI: " .. tostring(res3))
            Running = false
            return
        end
        res = res3
    end
    Window = res
    Boot("Membangun menu...")
end

local function Safe(name, fn)
    local ok, err = pcall(fn)
    if not ok then
        warn("[KizzDev] error di " .. name .. ": " .. tostring(err))
        Notify("Error " .. name .. ": " .. tostring(err))
        Boot("Error " .. name .. ": " .. tostring(err))
    end
end

local T = {}
local function mkTab(key, name, icon)
    local ok, t = pcall(function() return Window:CreateTab(name, icon) end)
    if not ok or not t then t = Window:CreateTab(name) end
    T[key] = t
    return t
end
mkTab("Home", "Dashboard", "layout-dashboard")
mkTab("Combat", "Combat", "swords")
mkTab("Aim", "Aimlock", "crosshair")
mkTab("Farm", "Auto Farm", "repeat")
mkTab("Def", "Defense", "shield")
mkTab("Vis", "Visual", "eye")
mkTab("Move", "Movement", "zap")
mkTab("Perf", "Performance", "gauge")
mkTab("Util", "Utility", "wrench")
mkTab("Set", "Settings", "settings")

-- ================= WRAPPER ELEMEN =================
local function Tg(tab, text, flag, hook)
    if Flags[flag] == nil then Flags[flag] = false end
    FlagHooks[flag] = hook
    Persist[flag] = true
    Els[flag] = tab:CreateToggle({Name = text, CurrentValue = Flags[flag] and true or false, Callback = function(v)
        v = v and true or false
        if Flags[flag] == v then return end
        Flags[flag] = v
        if hook then task.spawn(hook, v) end
        queueSave()
    end})
end

local function Sl(tab, text, flag, min, max, default, step, cb)
    local v = Saved[flag]
    if type(v) ~= "number" then v = default end
    v = math.clamp(v, min, max)
    Flags[flag] = v
    Persist[flag] = true
    Els[flag] = tab:CreateSlider({Name = text, Range = {min, max}, Increment = step or 1, Suffix = "", CurrentValue = v,
        Callback = function(n)
            if Flags[flag] == n then return end
            Flags[flag] = n
            if cb then cb(n) end
            queueSave()
        end})
end

local function Dd(tab, text, flag, opts, default, cb)
    local v = Saved[flag]
    if v == nil then v = default end
    Flags[flag] = v
    Persist[flag] = true
    local dd = tab:CreateDropdown({Name = text, Options = opts, CurrentOption = {tostring(v)}, MultipleOptions = false,
        Callback = function(o)
            local val = typeof(o) == "table" and o[1] or o
            if val == nil or Flags[flag] == val then return end
            Flags[flag] = val
            if cb then cb(val) end
            queueSave()
        end})
    return dd
end

local function Btn(tab, text, cb)
    tab:CreateButton({Name = text, Callback = function() task.spawn(cb) end})
end

local function Inp(tab, text, flag, default, placeholder)
    local v = Saved[flag]
    if type(v) ~= "string" then v = default end
    Flags[flag] = v
    Persist[flag] = true
    tab:CreateInput({Name = text, CurrentValue = v, PlaceholderText = placeholder or "", RemoveTextAfterFocusLost = false,
        Callback = function(txt) Flags[flag] = txt queueSave() end})
end

local function Col(tab, text, flag, default)
    Flags[flag] = default
    pcall(function()
        tab:CreateColorPicker({Name = text, Color = default, Callback = function(c) Flags[flag] = c end})
    end)
end

local function PlayerNames()
    local t = {"(pilih)"}
    for _, p in ipairs(Players:GetPlayers()) do if p ~= LP then t[#t + 1] = p.Name end end
    return t
end
local PlayerDDs = {}
local function refreshPlayers()
    local names = PlayerNames()
    for _, dd in ipairs(PlayerDDs) do pcall(function() dd:Refresh(names) end) end
end
Connect(Players.PlayerAdded, function() task.wait(0.5) refreshPlayers() end)
Connect(Players.PlayerRemoving, function() task.wait(0.2) refreshPlayers() end)

local function ApplyFarm(on)
    local tele = (Flags.FarmMode or "Teleport (cepat)") == "Teleport (cepat)"
    SetFlag("AutoM1", on)
    SetFlag("FaceTarget", on)
    SetFlag("Stick", on and tele)
    SetFlag("Chase", on and not tele)
    local sk = on and (Flags.FarmSkills and true or false)
    SetFlag("AutoSkill", sk)
    for i = 1, 4 do SetFlag("Skill" .. i, sk) end
    SetFlag("AutoBlock", on and (Flags.FarmBlock and true or false))
    if on then Notify("Auto Farm aktif") else Notify("Auto Farm mati") end
end

local LockBtn
local function ToggleLock()
    LockActive = not LockActive
    if LockBtn then
        LockBtn.Text = LockActive and "🔒" or "🔓"
        LockBtn.BackgroundColor3 = LockActive and Color3.fromRGB(86, 38, 170) or C.bg
    end
    if not LockActive then AimTarget = nil end
    Notify(LockActive and "Aimlock: kunci aktif" or "Aimlock: dilepas")
end
local function SwitchTarget()
    local n = PickTarget(AimTarget)
    if n then AimTarget = n LockActive = true Notify("Target: " .. n.DisplayName) else Notify("Tidak ada target lain") end
end
Shared.ToggleLock = ToggleLock

Flags.AntiAFK = true

-- ---------- DASHBOARD ----------
Safe("Dashboard", function()
    local t = T.Home
    t:CreateSection("Selamat datang")
    -- Paragraph header dihapus: sebelumnya terpotong dan terlihat seperti teks KizzDev liar.
    t:CreateSection("Status")
    Shared.Status = t:CreateLabel("Kill: 0  |  Damage: 0  |  Target: -")
    Shared.StatEl = t:CreateLabel("FPS -- | Ping --")
    t:CreateSection("Preset Cepat")
    Tg(t, "Preset: Auto Fight (M1 + aimlock + skill + block)", "PresetFight", function(on)
        for _, f in ipairs({"AutoM1", "AimLock", "AutoSkill", "Skill1", "Skill2", "Skill3", "Skill4", "AutoBlock", "FaceTarget", "Chase"}) do
            SetFlag(f, on)
        end
        LockActive = on
        if not on then AimTarget = nil end
        Notify(on and "Auto Fight aktif. 🔒 / T kunci target, ⇄ / Y ganti target" or "Auto Fight mati")
    end)
    Tg(t, "Preset: Combo Fight (aimlock + auto combo)", "PresetCombo", function(on)
        for _, f in ipairs({"AimLock", "AutoCombo", "FaceTarget", "Chase", "AutoBlock"}) do SetFlag(f, on) end
        LockActive = on
        if not on then AimTarget = nil end
        Notify(on and "Combo Fight aktif" or "Combo Fight mati")
    end)
    Tg(t, "Preset: Auto Farm (player + NPC)", "PresetFarm", function(on)
        SetFlag("IncludeNPC", on)
        SetFlag("AutoFarm", on)
    end)
    Tg(t, "Preset: Full ESP", "PresetESP", function(on)
        for _, f in ipairs({"ESP", "ESPInfo", "Tracer"}) do SetFlag(f, on) end
    end)
    Tg(t, "Preset: Super Anti Lag", "PresetLag", function(on) SetFlag("SuperLag", on) end)
    t:CreateSection("Kontrol")
    t:CreateParagraph({Title = "Tombol", Content = "RightCtrl = buka/tutup menu\nShow KizzDev = buka/tutup menu\nT = kunci/lepas aimlock\nY = ganti target"})
end)

-- ---------- COMBAT ----------
Safe("Combat", function()
    local t = T.Combat
    t:CreateSection("Auto Attack")
    Tg(t, "Auto M1 (serang target)", "AutoM1")
    Sl(t, "Jarak Serang", "M1Range", 5, 40, 14, 1)
    Sl(t, "Delay M1 (detik)", "M1Delay", 0.05, 0.6, 0.14, 0.01)
    Tg(t, "Karakter Hadap Target", "FaceTarget")
    Tg(t, "Auto Chase (kejar target)", "Chase")
    Sl(t, "Jarak Berhenti Chase", "ChaseStop", 3, 12, 6, 1)
    Tg(t, "Gap Closer: dash (Q) kalau target jauh", "GapClose")
    Sl(t, "Jarak Gap Closer", "GapRange", 12, 60, 24, 1)

    t:CreateSection("Combo Builder")
    Tg(t, "Auto Combo", "AutoCombo")
    Inp(t, "Urutan Combo", "ComboSeq", "M1 M1 M1 M1 1 2 3 4", "contoh: M1 M1 2 Q 3")
    Sl(t, "Delay Antar Langkah", "ComboDelay", 0.05, 1, 0.18, 0.01)
    Sl(t, "Jarak Combo", "ComboRange", 5, 40, 14, 1)
    t:CreateParagraph({Title = "Cara tulis combo", Content = "M1 = pukulan, angka 1-9 / huruf = tombol (Q dash, F block, G awaken), W0.5 = tunggu 0.5 detik. Pisahkan dengan spasi."})

    t:CreateSection("Auto Skill")
    Tg(t, "Auto Skill Aktif", "AutoSkill")
    Tg(t, "Hormati Cooldown (pakai Skill Cooldown Display)", "SkillSmart")
    Tg(t, "Skill 1", "Skill1")
    Tg(t, "Skill 2", "Skill2")
    Tg(t, "Skill 3", "Skill3")
    Tg(t, "Skill 4", "Skill4")
    Sl(t, "Delay Antar Skill (detik)", "SkillDelay", 0.2, 3, 0.8, 0.05)
    Sl(t, "Jarak Pakai Skill", "SkillRange", 5, 60, 25, 1)

    t:CreateSection("Posisi")
    Tg(t, "Nempel di Belakang Target", "Stick")
    Sl(t, "Jarak Nempel", "StickDist", 2, 8, 3.5, 0.5)
    Tg(t, "Orbit / Strafe Mengelilingi Target", "Orbit")
    Sl(t, "Radius Orbit", "OrbitRadius", 3, 20, 7, 1)
    Sl(t, "Kecepatan Orbit", "OrbitSpeed", 0.5, 8, 2.5, 0.5)

    t:CreateSection("Hitbox Expander")
    Tg(t, "Hitbox Expander", "Hitbox", function(v) if not v then RestoreHitbox() end end)
    Dd(t, "Bagian Hitbox", "HitboxPart", {"HumanoidRootPart", "Head", "UpperTorso", "Torso"}, "HumanoidRootPart",
        function() RestoreHitbox() end)
    Sl(t, "Ukuran Hitbox", "HitboxSize", 2, 40, 10, 1)
    Sl(t, "Transparansi Hitbox", "HitboxTrans", 0, 1, 0.75, 0.05)
    Sl(t, "Jarak Maksimum Hitbox", "HitboxRange", 20, 400, 120, 10)
    t:CreateParagraph({Title = "Catatan", Content = "Hitbox hanya mengubah ukuran di sisi kamu. Efeknya terasa kalau game memakai deteksi hit di sisi client."})

    t:CreateSection("Filter Target")
    Tg(t, "Abaikan Teman", "IgnoreFriends")
    Tg(t, "Abaikan Pemain ber-ForceField (spawn)", "IgnoreFF")
    Tg(t, "Sertakan NPC / Dummy sebagai target", "IncludeNPC")
end)

-- ---------- AIMLOCK ----------
Safe("Aimlock", function()
    local t = T.Aim
    t:CreateSection("Aimlock")
    Tg(t, "Aimlock Aktif", "AimLock", function(v)
        if v then LockActive = true Notify("Aimlock aktif. 🔒 / T = kunci, ⇄ / Y = ganti target") end
    end)
    Dd(t, "Prioritas Target", "AimPriority", {"Terdekat (karakter)", "Terdekat (crosshair)", "HP terendah"}, "Terdekat (karakter)")
    Dd(t, "Bagian Aim", "AimPart", {"HumanoidRootPart", "Head", "UpperTorso"}, "HumanoidRootPart")
    Sl(t, "Jarak Maksimum Kunci", "AimMaxDist", 15, 150, 60, 5)
    Sl(t, "Kehalusan (1 = instan)", "AimSmooth", 0.05, 1, 0.35, 0.05)
    Sl(t, "FOV (mode crosshair)", "AimFOV", 50, 700, 300, 10)
    Tg(t, "Kunci Horizontal Saja (anti pusing)", "AimYawOnly")
    Tg(t, "Prediksi Gerakan Musuh", "Predict")
    Sl(t, "Waktu Prediksi", "PredictTime", 0.02, 0.4, 0.1, 0.01)
    t:CreateSection("Pilih Target Manual")
    PlayerDDs[#PlayerDDs + 1] = Dd(t, "Pemain Pilihan", "ChosenTarget", PlayerNames(), "(pilih)")
    Tg(t, "Kunci Hanya Pemain Pilihan", "OnlyChosen")
    Btn(t, "Ganti Target", function()
        local n = PickTarget(AimTarget)
        if n then AimTarget = n Notify("Target: " .. n.DisplayName) else Notify("Tidak ada target lain") end
    end)
    Btn(t, "Lepas / Kunci Ulang", function() ToggleLock() end)
end)

-- ---------- AUTO FARM ----------
Safe("Auto Farm", function()
    local t = T.Farm
    t:CreateSection("Auto Farm")
    Tg(t, "Auto Farm (cari, kejar, serang otomatis)", "AutoFarm", function(on) ApplyFarm(on) end)
    Dd(t, "Mode Gerak", "FarmMode", {"Teleport (cepat)", "Jalan (aman)"}, "Teleport (cepat)",
        function() if Flags.AutoFarm then ApplyFarm(true) end end)
    Sl(t, "Jarak Cari Target", "FarmRange", 50, 1000, 400, 10)
    Tg(t, "Pakai Skill 1-4 saat farm", "FarmSkills", function() if Flags.AutoFarm then ApplyFarm(true) end end)
    Tg(t, "Auto Block saat farm", "FarmBlock", function() if Flags.AutoFarm then ApplyFarm(true) end end)
    Tg(t, "Auto Respawn", "AutoRespawn")
    t:CreateSection("Pindah Server")
    Tg(t, "Pindah server kalau tidak ada target", "FarmHop")
    Sl(t, "Tunggu Sebelum Pindah (detik)", "FarmHopSec", 10, 120, 25, 5)
    t:CreateSection("Statistik")
    Shared.FarmLabel = t:CreateLabel("Kill: 0  |  Damage total: 0")
    Btn(t, "Reset Statistik", function() Shared.Kills = 0 Shared.Dmg = 0 Shared.PB = 0 Notify("Statistik direset") end)
    t:CreateParagraph({Title = "Cara kerja", Content = "Farm mencari target terdekat (player, plus NPC kalau 'Sertakan NPC' di tab Combat aktif), mendekat, lalu menyerang. Preset 'Auto Farm' di Dashboard menyalakan semuanya sekaligus."})
end)

-- ---------- DEFENSE ----------
Safe("Defense", function()
    local t = T.Def
    t:CreateSection("Block & Dodge")
    Tg(t, "Auto Block (F) saat musuh nyerang", "AutoBlock")
    Sl(t, "Jarak Deteksi Serangan", "BlockRange", 5, 35, 16, 1)
    Tg(t, "Auto Dodge (Q) saat musuh nyerang", "AutoDodge")
    Tg(t, "Auto Awaken (G)", "AutoAwaken")
    Tg(t, "Anti Ragdoll", "AntiRagdoll")

    t:CreateSection("Perfect Block Assist")
    Tg(t, "Perfect Block Assist", "PerfectBlock")
    Sl(t, "Jarak Deteksi", "PBRange", 5, 35, 14, 1)
    Sl(t, "Delay Setelah Animasi Serangan (detik)", "PBDelay", 0, 0.5, 0.12, 0.01)
    Sl(t, "Lama Block (detik)", "PBHold", 0.1, 1, 0.28, 0.02)
    Sl(t, "Jeda Antar Block (detik)", "PBCooldown", 0.2, 2, 0.5, 0.05)
    Tg(t, "Hanya jika musuh menghadap kamu", "PBFacing")
    Tg(t, "Hadap penyerang saat block", "PBFace")
    Shared.PBLabel = t:CreateLabel("Perfect Block terpicu: 0")
    t:CreateParagraph({Title = "Cara kerja", Content = "Saat animasi serangan musuh mulai, script menunggu Delay lalu menekan F sebentar. Atur Delay supaya pas dengan momen pukulan mendarat (coba 0.08 sampai 0.2)."})

    t:CreateSection("Keselamatan")
    Tg(t, "Kabur Otomatis saat HP Rendah", "LowHPEscape")
    Sl(t, "Batas HP (%)", "EscapeHP", 5, 70, 25, 1)
    Dd(t, "Cara Kabur", "EscapeMode", {"Menjauh dari musuh", "Teleport ke posisi tersimpan"}, "Menjauh dari musuh")
    Btn(t, "Simpan Posisi Aman Sekarang", function()
        if Root() then Shared.savedCF = Root().CFrame Notify("Posisi aman disimpan") end
    end)
    Tg(t, "Anti Void (balik ke tempat aman)", "AntiVoid")
end)

-- ---------- VISUAL ----------
Safe("Visual", function()
    local t = T.Vis
    t:CreateSection("ESP")
    Tg(t, "ESP Highlight + Nama", "ESP", function() RefreshESP() end)
    Tg(t, "Tampilkan HP & Jarak", "ESPInfo")
    Tg(t, "Warna ESP Sesuai HP", "HPChams")
    Col(t, "Warna ESP", "ESPColor", Color3.fromRGB(150, 70, 255))
    Tg(t, "Tracer (garis ke pemain)", "Tracer", function(v)
        if v and not HasDrawing then Notify("Executor kamu tidak punya Drawing API") end
    end)

    t:CreateSection("Damage Indicator")
    Tg(t, "Damage Indicator (angka damage ke musuh)", "DmgIndicator")
    Tg(t, "Tampilkan Damage yang Kamu Terima", "DmgSelf")
    Sl(t, "Ukuran Angka", "DmgSize", 10, 36, 18, 1)
    Sl(t, "Batas Hit Besar (damage)", "DmgBig", 5, 100, 25, 1)
    Sl(t, "Damage Minimum Ditampilkan", "DmgMin", 1, 20, 1, 1)
    Col(t, "Warna Angka", "DmgColor", Color3.new(1, 1, 1))

    t:CreateSection("Skill Cooldown Display")
    Tg(t, "Tampilkan Cooldown Skill 1-4", "CDDisplay", function(v) if Shared.CDHud then Shared.CDHud.Visible = v end end)
    Sl(t, "Cooldown Skill 1 (detik)", "SkillCD1", 1, 60, 8, 0.5)
    Sl(t, "Cooldown Skill 2 (detik)", "SkillCD2", 1, 60, 10, 0.5)
    Sl(t, "Cooldown Skill 3 (detik)", "SkillCD3", 1, 60, 12, 0.5)
    Sl(t, "Cooldown Skill 4 (detik)", "SkillCD4", 1, 60, 15, 0.5)
    Btn(t, "Reset Semua Cooldown", function() SkillUntil = {0, 0, 0, 0} Notify("Cooldown direset") end)
    t:CreateParagraph({Title = "Catatan", Content = "Display menghitung dari saat kamu atau script menekan tombol skill 1-4. Isi durasi cooldown tiap skill sesuai karakter yang kamu pakai."})

    t:CreateSection("HUD & Kamera")
    Tg(t, "Lingkaran FOV Aim", "ShowFOV")
    Flags.TargetHUD = true
    Tg(t, "HUD Info Target", "TargetHUD")
    Sl(t, "Field of View Kamera", "CamFOV", 40, 120, 70, 1, function(v) Cam.FieldOfView = v end)
    Sl(t, "Zoom Maksimum Kamera", "Zoom", 20, 500, 128, 10, function(v) LP.CameraMaxZoomDistance = v end)
end)

-- ---------- MOVEMENT ----------
Safe("Movement", function()
    local t = T.Move
    t:CreateSection("Kecepatan & Lompat")
    Tg(t, "WalkSpeed", "Speed", function(v) if not v and Hum() then Hum().WalkSpeed = 16 end end)
    Sl(t, "Nilai Speed", "SpeedVal", 16, 150, 40, 1)
    Tg(t, "CFrame Speed (lebih aman)", "CFSpeed")
    Sl(t, "Nilai CFrame Speed", "CFSpeedVal", 10, 120, 40, 1)
    Tg(t, "JumpPower", "Jump", function(v)
        if not v and Hum() then Hum().UseJumpPower = true Hum().JumpPower = 50 end
    end)
    Sl(t, "Nilai Jump", "JumpVal", 50, 300, 90, 5)
    Tg(t, "Infinite Jump", "InfJump")
    t:CreateSection("Terbang & Lainnya")
    Tg(t, "Fly", "Fly", function(v) if v then StartFly() else StopFly() end end)
    Sl(t, "Kecepatan Fly", "FlySpeed", 20, 250, 70, 5)
    Tg(t, "Noclip", "Noclip")
    Tg(t, "Spin", "Spin")
    Tg(t, "Ctrl + Klik = Teleport", "ClickTP")
    Sl(t, "Gravitasi", "Gravity", 20, 400, 196, 2, function(v) Workspace.Gravity = v end)
end)

-- ---------- PERFORMANCE ----------
Safe("Performance", function()
    local t = T.Perf
    t:CreateSection("Anti Lag")
    Tg(t, "Anti Lag (matikan efek & bayangan)", "AntiLag", function(v)
        if v then SetLive() ProcessAll(false) Notify("Anti Lag aktif: efek skill dimatikan")
        elseif not Flags.SuperLag then RestoreFx() end
    end)
    Tg(t, "SUPER Anti Lag (grafik minimum)", "SuperLag", function(v)
        if v then SetLive() ProcessAll(true) Notify("Super Anti Lag aktif. Rejoin untuk mengembalikan tampilan") end
    end)
    Btn(t, "Hapus Semua Efek Sekarang (sekali)", function() ProcessAll(true) Notify("Membersihkan efek & tekstur...") end)
    t:CreateSection("FPS & Render")
    Sl(t, "Batas FPS", "FPSCap", 30, 360, 144, 10, function(v) if setfpscap then setfpscap(v) end end)
    Sl(t, "Kualitas Grafik (1 = terendah)", "Quality", 1, 10, 1, 1, function(v)
        pcall(function() settings().Rendering.QualityLevel = v end)
    end)
    Tg(t, "Matikan Render 3D (hemat baterai)", "NoRender", function(v)
        pcall(function() RunService:Set3dRenderingEnabled(not v) end)
    end)
    Btn(t, "Bersihkan Memori", function() collectgarbage("collect") Notify("Memori dibersihkan") end)
    t:CreateSection("Lingkungan")
    Tg(t, "Fullbright", "Fullbright", function(v)
        if v then
            Lighting.Brightness = 2 Lighting.Ambient = Color3.new(1, 1, 1) Lighting.OutdoorAmbient = Color3.new(1, 1, 1)
        else
            Lighting.Brightness = 1 Lighting.Ambient = Color3.fromRGB(70, 70, 70) Lighting.OutdoorAmbient = Color3.fromRGB(70, 70, 70)
        end
    end)
    Tg(t, "Hapus Kabut", "NoFog", function(v) if v then Lighting.FogEnd = 9e9 end end)
    Sl(t, "Waktu (jam)", "ClockTime", 0, 24, 14, 0.5, function(v) Lighting.ClockTime = v end)
end)

-- ---------- UTILITY ----------
Safe("Utility", function()
    local t = T.Util
    t:CreateSection("Teleport")
    PlayerDDs[#PlayerDDs + 1] = Dd(t, "Pilih Pemain", "TPTarget", PlayerNames(), "(pilih)")
    Btn(t, "Teleport ke Pemain", function()
        local p = Players:FindFirstChild(tostring(Flags.TPTarget))
        local r, tr = Root(), p and Root(p.Character)
        if r and tr then r.CFrame = tr.CFrame * CFrame.new(0, 0, 3) else Notify("Pemain tidak ditemukan") end
    end)
    Btn(t, "Teleport ke Pemain Terdekat", function()
        local p = NearestEnemy()
        local r = Root()
        if p and r then r.CFrame = Root(p.Character).CFrame * CFrame.new(0, 0, 3) else Notify("Tidak ada pemain") end
    end)
    Btn(t, "Teleport ke Pemain Acak", function()
        local l = {}
        for _, p in ipairs(Players:GetPlayers()) do if IsEnemy(p) then l[#l + 1] = p end end
        local r = Root()
        if #l > 0 and r then r.CFrame = Root(l[math.random(#l)].Character).CFrame * CFrame.new(0, 0, 3) end
    end)
    Tg(t, "Spectate Pemain Terpilih", "Spectate", function(v)
        local p = Players:FindFirstChild(tostring(Flags.TPTarget))
        if v and p and p.Character and Hum(p.Character) then Cam.CameraSubject = Hum(p.Character)
        elseif Hum() then Cam.CameraSubject = Hum() end
    end)
    Btn(t, "Simpan Posisi Sekarang", function()
        if Root() then Shared.savedCF = Root().CFrame Notify("Posisi disimpan") end
    end)
    Btn(t, "Teleport ke Posisi Tersimpan", function()
        if Shared.savedCF and Root() then Root().CFrame = Shared.savedCF else Notify("Belum ada posisi tersimpan") end
    end)
    t:CreateSection("Server")
    Tg(t, "Anti AFK", "AntiAFK")
    Tg(t, "Auto Rejoin saat Disconnect", "AutoRejoin")
    Btn(t, "Reset Karakter", function() if Hum() then Hum().Health = 0 end end)
    Btn(t, "Rejoin Server", function() TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, LP) end)
    Btn(t, "Server Hop (server paling sepi)", function() ServerHop() end)
    Btn(t, "Salin Job ID", function()
        if setclipboard then setclipboard(game.JobId) Notify("Job ID disalin") end
    end)
end)

-- ---------- SETTINGS ----------
Safe("Settings", function()
    local t = T.Set
    t:CreateSection("Tampilan")
    Tg(t, "Tampilkan FPS & Ping di Dashboard", "ShowStats")
    t:CreateSection("Config")
    Btn(t, "Simpan Pengaturan Sekarang", function() queueSave() Notify("Pengaturan disimpan") end)
    Btn(t, "Reset Pengaturan Tersimpan", function()
        pcall(function() if delfile and isfile(CFG) then delfile(CFG) end end)
        Notify("Config dihapus. Jalankan ulang script")
    end)
    t:CreateSection("Script")
    Btn(t, "Tutup Script (Unload)", function() if Shared.Unload then Shared.Unload() end end)
end)

-- stat FPS/Ping (dipakai loop FPS)
local statLast = ""
local StatLbl = setmetatable({}, {__newindex = function(_, k, v)
    if k == "Text" and Shared.StatEl and v ~= statLast then
        statLast = v
        pcall(function() Shared.StatEl:Set(v == "" and "FPS/Ping: dimatikan" or v) end)
    end
end})

-- ============================================================
--        OVERLAY: AIM BUTTONS, HUD TARGET, COOLDOWN, LOGO
-- ============================================================
local AimBtns = new("Frame", {Parent = Gui, BackgroundTransparency = 1, AnchorPoint = Vector2.new(1, 0.5),
    Position = UDim2.new(1, -16, 0.55, 0), Size = UDim2.fromOffset(54, 116), Visible = false})
new("UIListLayout", {Parent = AimBtns, SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 8)})
local function roundBtn(txt)
    local b = new("TextButton", {Parent = AimBtns, Size = UDim2.fromOffset(54, 54), BackgroundColor3 = C.bg,
        BackgroundTransparency = 0.12, Text = txt, TextSize = 22, Font = Enum.Font.GothamBold, TextColor3 = C.text,
        AutoButtonColor = false})
    corner(b, 27) stroke(b, C.acc2, 2, 0.05)
    return b
end
LockBtn = roundBtn("🔒")
local SwitchBtn = roundBtn("⇄")
LockBtn.BackgroundColor3 = Color3.fromRGB(86, 38, 170)
LockBtn.MouseButton1Click:Connect(ToggleLock)
SwitchBtn.MouseButton1Click:Connect(SwitchTarget)
-- tombol aim muncul saat Aimlock aktif
task.spawn(function()
    while Running do
        task.wait(0.3)
        AimBtns.Visible = Flags.AimLock and true or false
    end
end)

local HUD = new("Frame", {Parent = Gui, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 16),
    Size = UDim2.fromOffset(230, 34), BackgroundColor3 = C.bg, BackgroundTransparency = 0.12, Visible = false})
corner(HUD, 17) stroke(HUD, C.acc2, 1.5, 0.1)
local HUDl = new("TextLabel", {Parent = HUD, BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Text = "",
    Font = Enum.Font.GothamBold, TextSize = 12, TextColor3 = C.text})

-- Skill Cooldown Display
do
    local hud = new("Frame", {Parent = Gui, AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -150),
        Size = UDim2.fromOffset(4 * 60 + 3 * 8, 60), BackgroundTransparency = 1, Visible = false, Active = true})
    new("UIListLayout", {Parent = hud, FillDirection = Enum.FillDirection.Horizontal, SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(0, 8)})
    local cells = {}
    for i = 1, 4 do
        local f = new("Frame", {Parent = hud, Size = UDim2.fromOffset(60, 60), BackgroundColor3 = C.bg,
            BackgroundTransparency = 0.15, LayoutOrder = i, ClipsDescendants = true})
        corner(f, 12)
        local st = stroke(f, C.acc2, 1.6, 0.1)
        local fill = new("Frame", {Parent = f, AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1),
            Size = UDim2.fromScale(1, 0), BackgroundColor3 = C.acc, BackgroundTransparency = 0.45, BorderSizePixel = 0})
        new("TextLabel", {Parent = f, BackgroundTransparency = 1, Position = UDim2.fromOffset(6, 3), Size = UDim2.fromOffset(20, 14),
            Text = tostring(i), Font = Enum.Font.GothamBlack, TextSize = 12, TextColor3 = C.acc2, TextXAlignment = Enum.TextXAlignment.Left})
        local tx = new("TextLabel", {Parent = f, BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Text = "OK",
            Font = Enum.Font.GothamBold, TextSize = 14, TextColor3 = C.text})
        cells[i] = {fill = fill, tx = tx, st = st}
    end
    Shared.CDHud = hud
    -- bisa digeser
    local dragging, start, startPos
    hud.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
            dragging, start, startPos = true, i.Position, hud.Position
        end
    end)
    Connect(UIS.InputChanged, function(i)
        if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
            local d = i.Position - start
            hud.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
        end
    end)
    Connect(UIS.InputEnded, function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then dragging = false end
    end)
    task.spawn(function()
        while Running do
            task.wait(0.05)
            if Flags.CDDisplay then
                for i = 1, 4 do
                    local rem = SkillUntil[i] - tick()
                    local cd = Flags["SkillCD" .. i] or 10
                    local c = cells[i]
                    if rem > 0 then
                        c.fill.Size = UDim2.fromScale(1, math.clamp(rem / cd, 0, 1))
                        c.tx.Text = string.format("%.1f", rem)
                        c.tx.TextColor3 = C.sub
                        c.st.Transparency = 0.6
                    else
                        c.fill.Size = UDim2.fromScale(1, 0)
                        c.tx.Text = "OK"
                        c.tx.TextColor3 = Color3.fromRGB(150, 255, 190)
                        c.st.Transparency = 0.05
                    end
                end
            end
        end
    end)
end

-- Animasi tepi neon pada tombol bawaan Rayfield "Show KizzDev".
-- Tidak membuat tombol K bulat tambahan dan tidak mengubah fungsi tombol.
task.spawn(function()
    local decorated = setmetatable({}, {__mode = "k"})
    while Running do
        task.wait(0.5)
        local root = findRF()
        if root then
            for _, obj in ipairs(root:GetDescendants()) do
                if obj:IsA("TextButton")
                    and string.find(string.lower(obj.Text or ""), "kizzdev", 1, true)
                    and not decorated[obj] then
                    decorated[obj] = true
                    pcall(function()
                        obj.TextColor3 = C.acc2
                        local textGrad = Instance.new("UIGradient")
                        textGrad.Color = ColorSequence.new({
                            ColorSequenceKeypoint.new(0, Color3.fromRGB(235, 190, 255)),
                            ColorSequenceKeypoint.new(0.5, Color3.fromRGB(160, 75, 255)),
                            ColorSequenceKeypoint.new(1, Color3.fromRGB(245, 210, 255)),
                        })
                        textGrad.Parent = obj

                        local edge = Instance.new("UIStroke")
                        edge.Name = "KizzDevNeonEdge"
                        edge.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
                        edge.Color = Color3.fromRGB(190, 105, 255)
                        edge.Thickness = 1.5
                        edge.Transparency = 0.18
                        edge.Parent = obj

                        local edgeGrad = Instance.new("UIGradient")
                        edgeGrad.Color = ColorSequence.new({
                            ColorSequenceKeypoint.new(0, Color3.fromRGB(110, 35, 220)),
                            ColorSequenceKeypoint.new(0.5, Color3.fromRGB(245, 175, 255)),
                            ColorSequenceKeypoint.new(1, Color3.fromRGB(125, 55, 255)),
                        })
                        edgeGrad.Parent = edge

                        task.spawn(function()
                            while Running and obj.Parent and edge.Parent do
                                tween(textGrad, 2.8, {Rotation = 360})
                                tween(edgeGrad, 2.8, {Rotation = 360})
                                tween(edge, 0.8, {Transparency = 0.08, Thickness = 2.2})
                                task.wait(0.85)
                                tween(edge, 0.8, {Transparency = 0.42, Thickness = 1.35})
                                task.wait(0.85)
                                pcall(function()
                                    textGrad.Rotation = 0
                                    edgeGrad.Rotation = 0
                                end)
                            end
                        end)
                    end)
                end
            end
        end
    end
end)

-- Menu siap; tidak ada splash overlay.
Boot("Siap")

-- ============================================================
--                    LOGIKA / LOOP
-- ============================================================

Connect(UIS.InputBegan, function(i, gp)
    if gp then return end
    if i.KeyCode == Enum.KeyCode.T and Flags.AimLock then ToggleLock()
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
                    if h and h.MaxHealth > 0 and d.hl then
                        d.hl.FillColor = Flags.HPChams and Color3.fromHSV(0.33 * math.clamp(h.Health / h.MaxHealth, 0, 1), 0.85, 1) or (Flags.ESPColor or Color3.fromRGB(150, 70, 255))
                    end
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
                if Flags[names[i]] and (not Flags.SkillSmart or SkillReady(i)) then
                    Tap(keys[i], 0.04)
                    MarkSkill(i)
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
            for _, p in ipairs(Targets()) do
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
    elseif Flags.AutoM1 or Flags.AutoSkill or Flags.Chase or Flags.Stick or Flags.AutoCombo or Flags.GapClose or Flags.Orbit or Flags.AutoFarm then
        CT, CTDist = NearestEnemy(Flags.AutoFarm and (Flags.FarmRange or 400) or math.max(Flags.M1Range or 14, Flags.SkillRange or 25, 60))
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

    if Flags.Hitbox then ApplyHitbox() end
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

-- ============================================================
--                  LOGIKA TAMBAHAN v4
-- ============================================================
do
    local digits = {"One", "Two", "Three", "Four", "Five", "Six", "Seven", "Eight", "Nine"}
    local function keyOf(tok)
        if tok:match("^%d$") then return Enum.KeyCode[digits[tonumber(tok)] or "One"] end
        if #tok == 1 then
            local ok, kc = pcall(function() return Enum.KeyCode[tok] end)
            if ok then return kc end
        end
    end

    -- Auto Combo
    task.spawn(function()
        while Running do
            task.wait(0.1)
            if Flags.AutoCombo and CT and CTDist <= (Flags.ComboRange or 14) and not Main.Visible then
                for tok in string.gmatch(tostring(Flags.ComboSeq or ""), "%S+") do
                    if not (Running and Flags.AutoCombo and CT and CTDist <= (Flags.ComboRange or 14)) then break end
                    local up = string.upper(tok)
                    if up == "M1" then
                        Click()
                    elseif up:match("^W[%d%.]+$") then
                        task.wait(tonumber(up:sub(2)) or 0)
                    else
                        local kc = keyOf(up)
                        if kc then
                            Tap(kc, 0.04)
                            local n = tonumber(up)
                            if n and n >= 1 and n <= 4 then MarkSkill(n) end
                        end
                    end
                    task.wait(Flags.ComboDelay or 0.18)
                end
            end
        end
    end)

    -- Gap Closer (dash ke target kalau jauh)
    local lastGap = 0
    task.spawn(function()
        while Running do
            task.wait(0.25)
            local r = Root()
            if Flags.GapClose and CT and r and CTDist > (Flags.GapRange or 24) and CTDist < 110
                and tick() - lastGap > 1.8 and not Main.Visible then
                lastGap = tick()
                local tp = Root(CT.Character)
                if tp then
                    r.CFrame = CFrame.lookAt(r.Position, Vector3.new(tp.Position.X, r.Position.Y, tp.Position.Z))
                    VIM:SendKeyEvent(true, Enum.KeyCode.W, false, game)
                    Tap(Enum.KeyCode.Q, 0.04)
                    task.wait(0.25)
                    VIM:SendKeyEvent(false, Enum.KeyCode.W, false, game)
                end
            end
        end
    end)

    -- Orbit / strafe
    local ang = 0
    Connect(RunService.Heartbeat, function(dt)
        if not (Flags.Orbit and CT) then return end
        local r = Root()
        local tr = CT.Character and Root(CT.Character)
        if not r or not tr then return end
        ang += dt * (Flags.OrbitSpeed or 2.5)
        local rad = Flags.OrbitRadius or 7
        local goal = Vector3.new(tr.Position.X + math.cos(ang) * rad, r.Position.Y, tr.Position.Z + math.sin(ang) * rad)
        local pos = r.Position:Lerp(goal, math.clamp(dt * 10, 0, 1))
        r.CFrame = CFrame.lookAt(pos, Vector3.new(tr.Position.X, pos.Y, tr.Position.Z))
    end)

    -- Kabur saat HP rendah
    local lastEscape = 0
    task.spawn(function()
        while Running do
            task.wait(0.1)
            if Flags.LowHPEscape then
                local h, r = Hum(), Root()
                if h and r and h.MaxHealth > 0 and h.Health > 0
                    and (h.Health / h.MaxHealth * 100) <= (Flags.EscapeHP or 25) and tick() - lastEscape > 4 then
                    lastEscape = tick()
                    if Flags.EscapeMode == "Teleport ke posisi tersimpan" and Shared.savedCF then
                        r.CFrame = Shared.savedCF
                    else
                        local e = NearestEnemy(90)
                        local dir = e and (r.Position - Root(e.Character).Position) or (-r.CFrame.LookVector)
                        dir = Vector3.new(dir.X, 0, dir.Z)
                        if dir.Magnitude < 0.1 then dir = Vector3.new(1, 0, 0) end
                        r.CFrame = r.CFrame + dir.Unit * 90 + Vector3.new(0, 4, 0)
                    end
                    Notify("HP rendah! Kabur")
                end
            end
        end
    end)

    -- Auto Rejoin
    task.spawn(function()
        pcall(function()
            local gui = game:GetService("CoreGui"):WaitForChild("RobloxPromptGui", 10)
            local po = gui and gui:WaitForChild("promptOverlay", 10)
            if po then
                Connect(po.ChildAdded, function(c)
                    if Flags.AutoRejoin and c.Name == "ErrorPrompt" then
                        task.wait(2)
                        TeleportService:Teleport(game.PlaceId, LP)
                    end
                end)
            end
        end)
    end)
end


-- Status dashboard
do
    local last = {}
    local function setLbl(key, el, txt)
        if el and last[key] ~= txt then
            last[key] = txt
            pcall(function() el:Set(txt) end)
        end
    end
    task.spawn(function()
        while Running do
            task.wait(0.6)
            local k, d = Shared.Kills, math.floor(Shared.Dmg)
            setLbl("st", Shared.Status, string.format("Kill: %d  |  Damage: %d  |  Target: %s", k, d, CT and CT.DisplayName or "-"))
            setLbl("fm", Shared.FarmLabel, string.format("Kill: %d  |  Damage total: %d", k, d))
            setLbl("pb", Shared.PBLabel, "Perfect Block terpicu: " .. Shared.PB)
        end
    end)
end

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
    pcall(RestoreHitbox)
    Gui:Destroy()
    pcall(function() Rayfield:Destroy() end)
end
Shared.Unload = Unload

Notify("KizzDev LB v5 siap. Gunakan RightCtrl atau Show KizzDev untuk menu.")
