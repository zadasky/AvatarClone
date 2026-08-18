-- ================================================
-- PHONE GUI - Full Rewrite
-- Fix: pcall key validation, auto-login, notif reply, chat muncul sekali
-- ================================================

local Services    = _G.Services
local T           = _G.T or {}
local Helpers     = _G.Helpers or {}
local Config      = _G.Config or {}
local LocalPlayer = _G.LocalPlayer
local Storage     = _G.Storage
local Firebase    = _G.Firebase

-- ==================== LOCAL HELPER ALIASES ====================
local function mkCorner(o, r)
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, r or 10)
    c.Parent = o
    return c
end
local function mkStroke(o, col, t, tr)
    local s = Instance.new("UIStroke")
    s.Color = col or Color3.fromRGB(200,200,200)
    s.Thickness = t or 1
    s.Transparency = tr or 0
    s.Parent = o
    return s
end
local function mkTween(o, props, tm, style)
    local ts = game:GetService("TweenService")
    ts:Create(o, TweenInfo.new(tm or 0.25, style or Enum.EasingStyle.Quart, Enum.EasingDirection.Out), props):Play()
end

local corner   = Helpers.corner   or mkCorner
local stroke   = Helpers.stroke   or mkStroke
local tween    = Helpers.tween    or mkTween
local pressFX  = Helpers.pressFX  or function(b)
    local orig = b.Size
    b.MouseButton1Down:Connect(function() mkTween(b, {Size = UDim2.new(orig.X.Scale*.95, orig.X.Offset*.95, orig.Y.Scale*.95, orig.Y.Offset*.95)}, 0.1) end)
    b.MouseButton1Up:Connect(function()   mkTween(b, {Size = orig}, 0.1) end)
end

-- ==================== GUI ROOT ====================
local gui = Instance.new("ScreenGui")
gui.Name = "PhoneGUI"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 998
gui.ZIndexBehavior = Enum.ZIndexBehavior.Global

local function getGuiParent()
    local ok, r = pcall(function()
        if gethui then return gethui() end
        if syn and syn.protect_gui then
            local sg = Instance.new("ScreenGui")
            syn.protect_gui(sg)
            sg.Parent = game:GetService("CoreGui")
            return sg
        end
        return game:GetService("CoreGui")
    end)
    return ok and r or game:GetService("CoreGui")
end
gui.Parent = getGuiParent()

-- ==================== PHONE FRAME ====================
local phone = Instance.new("Frame", gui)
phone.Size = UDim2.new(0, 0, 0, 0)
phone.Position = UDim2.new(0.5, 0, 0.52, 0)
phone.AnchorPoint = Vector2.new(0.5, 0.5)
phone.BackgroundColor3 = T.BG or Color3.fromRGB(255, 255, 255)
phone.BorderSizePixel = 0
phone.Visible = false
phone.ClipsDescendants = true
corner(phone, 38)
stroke(phone, T.Accent or Color3.fromRGB(30, 30, 30), 2, 0.15)

local PHONE_SIZE = UDim2.new(0, 320, 0, 560)

local function isPortrait()
    local cam = Services.Workspace.CurrentCamera
    if not cam then return true end
    return cam.ViewportSize.Y >= cam.ViewportSize.X
end

local function getGridIconSize()
    return isPortrait() and UDim2.new(0, 72, 0, 86) or UDim2.new(0, 68, 0, 78)
end

-- ==================== SCREEN AREA ====================
local sa = Instance.new("Frame", phone)
sa.Size = UDim2.new(1, -16, 1, -16)
sa.Position = UDim2.new(0, 8, 0, 8)
sa.BackgroundColor3 = T.BG or Color3.fromRGB(255, 255, 255)
sa.BorderSizePixel = 0
sa.ClipsDescendants = true
corner(sa, 30)

-- ==================== STATUS BAR ====================
local sb = Instance.new("Frame", sa)
sb.Size = UDim2.new(1, 0, 0, 34)
sb.BackgroundTransparency = 1
sb.ZIndex = 100

local clockLbl = Instance.new("TextLabel", sb)
clockLbl.Size = UDim2.new(0, 80, 0, 30)
clockLbl.Position = UDim2.new(0, 14, 0, 0)
clockLbl.BackgroundTransparency = 1
clockLbl.Text = os.date("%H:%M")
clockLbl.TextColor3 = T.Text or Color3.fromRGB(30, 30, 30)
clockLbl.Font = Enum.Font.GothamBold
clockLbl.TextSize = 13
clockLbl.TextXAlignment = Enum.TextXAlignment.Left
clockLbl.ZIndex = 101
task.spawn(function()
    while clockLbl.Parent do
        clockLbl.Text = os.date("%H:%M")
        task.wait(30)
    end
end)

-- ==================== DYNAMIC ISLAND ====================
local di = Instance.new("Frame", sa)
di.Size = UDim2.new(0, 90, 0, 24)
di.Position = UDim2.new(0.5, -45, 0, 4)
di.BackgroundColor3 = Color3.new(0, 0, 0)
di.ZIndex = 110
corner(di, 100)

local diStroke = stroke(di, Color3.new(1,1,1), 1.5, 0.6)

local dil = Instance.new("TextLabel", di)
dil.Size = UDim2.new(1, -8, 1, 0)
dil.Position = UDim2.new(0, 4, 0, 0)
dil.BackgroundTransparency = 1
dil.Text = ""
dil.TextColor3 = Color3.new(1,1,1)
dil.Font = Enum.Font.GothamBold
dil.TextSize = 11
dil.TextXAlignment = Enum.TextXAlignment.Center
dil.ZIndex = 111

-- Dynamic Island notification queue
local diQueue, diProcessing, diId = {}, false, 0
local function diProcess()
    if #diQueue == 0 then diProcessing = false; return end
    diProcessing = true
    local info = table.remove(diQueue, 1)
    diId = diId + 1
    local myId = diId
    dil.Text = info.text
    diStroke.Color = info.color or Color3.new(1,1,1)
    local tw = math.min(260, 12 * #info.text + 40)
    tween(di, {Size=UDim2.new(0,tw,0,32), Position=UDim2.new(0.5,-tw/2,0,2)}, 0.25, Enum.EasingStyle.Back)
    task.delay(2.2, function()
        if diId ~= myId then return end
        tween(di, {Size=UDim2.new(0,90,0,24), Position=UDim2.new(0.5,-45,0,4)}, 0.25)
        task.delay(0.3, function()
            if diId == myId then dil.Text = ""; diProcess() end
        end)
    end)
end

function _G.showDynamicNotification(text, color)
    table.insert(diQueue, {text=text, color=color})
    if not diProcessing then diProcess() end
end

-- ==================== HOME SCREEN ====================
local sh = Instance.new("Frame", sa)
sh.Size = UDim2.new(1, 0, 1, -60)
sh.Position = UDim2.new(0, 0, 0, 34)
sh.BackgroundTransparency = 1
sh.ClipsDescendants = true

local home = Instance.new("Frame", sh)
home.Size = UDim2.new(1, 0, 1, 0)
home.BackgroundTransparency = 1
home.ClipsDescendants = true

local homeWall = Instance.new("Frame", home)
homeWall.Size = UDim2.new(1, 0, 1, 0)
homeWall.BackgroundColor3 = Color3.fromRGB(240, 240, 250)
homeWall.ZIndex = 0
corner(homeWall, 30)

-- ==================== DOCK ====================
local dockArea = Instance.new("Frame", home)
dockArea.Size = UDim2.new(0, 224, 0, 64)
dockArea.Position = UDim2.new(0.5, -112, 1, -84)
dockArea.BackgroundTransparency = 1
dockArea.ZIndex = 5

local dockBg = Instance.new("Frame", dockArea)
dockBg.Size = UDim2.new(1, 0, 0, 56)
dockBg.Position = UDim2.new(0, 0, 0, 4)
dockBg.BackgroundColor3 = Color3.fromRGB(255,255,255)
dockBg.BackgroundTransparency = 0.1
corner(dockBg, 20)

local dockGrid = Instance.new("UIGridLayout", dockBg)
dockGrid.CellSize = UDim2.new(0, 70, 0, 50)
dockGrid.CellPadding = UDim2.new(0, 2, 0, 0)
dockGrid.HorizontalAlignment = Enum.HorizontalAlignment.Center
dockGrid.VerticalAlignment = Enum.VerticalAlignment.Center
dockGrid.FillDirection = Enum.FillDirection.Horizontal

-- ==================== APP GRID ====================
local appGrid = Instance.new("ScrollingFrame", home)
appGrid.Size = UDim2.new(1, -16, 1, -156)
appGrid.Position = UDim2.new(0, 8, 0, 70)
appGrid.BackgroundTransparency = 1
appGrid.ScrollBarThickness = 3
appGrid.ScrollBarImageColor3 = T.Accent or Color3.fromRGB(30,30,30)
appGrid.CanvasSize = UDim2.new(0,0,0,0)
appGrid.AutomaticCanvasSize = Enum.AutomaticSize.Y
appGrid.BorderSizePixel = 0

local gridLayout = Instance.new("UIGridLayout", appGrid)
gridLayout.CellSize = getGridIconSize()
gridLayout.CellPadding = UDim2.new(0, 10, 0, 12)
gridLayout.SortOrder = Enum.SortOrder.LayoutOrder
gridLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
gridLayout.VerticalAlignment = Enum.VerticalAlignment.Top

-- ==================== KEY SCREEN ====================
local keyScreen = Instance.new("Frame", sa)
keyScreen.Size = UDim2.new(1, 0, 1, 0)
keyScreen.BackgroundColor3 = Color3.fromRGB(12, 12, 18)
keyScreen.ZIndex = 80
keyScreen.Visible = false
keyScreen.BorderSizePixel = 0
keyScreen.ClipsDescendants = true
corner(keyScreen, 30)

-- Background gradient
local ksBg = Instance.new("UIGradient", keyScreen)
ksBg.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0, Color3.fromRGB(20,20,30)),
    ColorSequenceKeypoint.new(0.5, Color3.fromRGB(10,10,16)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(15,20,35)),
})
ksBg.Rotation = 135

-- Glow orbs dekoratif
local function mkOrb(parent, size, pos, col, trans)
    local f = Instance.new("Frame", parent)
    f.Size = size; f.Position = pos
    f.BackgroundColor3 = col
    f.BackgroundTransparency = trans or 0.85
    f.ZIndex = 81; f.BorderSizePixel = 0
    corner(f, 100)
    return f
end
mkOrb(keyScreen, UDim2.new(0,200,0,200), UDim2.new(0.5,-100,0,-80), Color3.fromRGB(0,150,255))
mkOrb(keyScreen, UDim2.new(0,150,0,150), UDim2.new(1,-60,1,-60), Color3.fromRGB(139,92,246))

-- Content area
local ksContent = Instance.new("Frame", keyScreen)
ksContent.Size = UDim2.new(1,-40,1,-40)
ksContent.Position = UDim2.new(0,20,0,20)
ksContent.BackgroundTransparency = 1
ksContent.ZIndex = 82

local ksLayout = Instance.new("UIListLayout", ksContent)
ksLayout.Padding = UDim.new(0,12)
ksLayout.SortOrder = Enum.SortOrder.LayoutOrder
ksLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
ksLayout.VerticalAlignment = Enum.VerticalAlignment.Center

-- Lock icon frame
local lockFrame = Instance.new("Frame", ksContent)
lockFrame.Size = UDim2.new(0,80,0,80)
lockFrame.BackgroundColor3 = Color3.fromRGB(255,255,255)
lockFrame.BackgroundTransparency = 0.9
lockFrame.LayoutOrder = 0; lockFrame.ZIndex = 83
corner(lockFrame, 20)
stroke(lockFrame, Color3.fromRGB(255,255,255), 2, 0.8)

-- Lock icon (UI-built, no emoji)
local lbody = Instance.new("Frame", lockFrame)
lbody.Size = UDim2.new(0,28,0,22); lbody.Position = UDim2.new(0.5,-14,0.58,0)
lbody.BackgroundColor3 = Color3.fromRGB(255,255,255); lbody.ZIndex = 84
corner(lbody, 6)
local lhole = Instance.new("Frame", lbody)
lhole.Size = UDim2.new(0,6,0,8); lhole.Position = UDim2.new(0.5,-3,0.5,-4)
lhole.BackgroundColor3 = Color3.fromRGB(100,80,200); lhole.ZIndex = 85
corner(lhole, 3)
local lshack = Instance.new("Frame", lockFrame)
lshack.Size = UDim2.new(0,18,0,16); lshack.Position = UDim2.new(0.5,-9,0.3,-2)
lshack.BackgroundTransparency = 1; lshack.ZIndex = 84
corner(lshack, 100)
stroke(lshack, Color3.fromRGB(255,255,255), 3.5, 0)

-- Title
local ksTitle = Instance.new("TextLabel", ksContent)
ksTitle.Size = UDim2.new(1,0,0,34)
ksTitle.BackgroundTransparency = 1
ksTitle.Text = "PHONE ID VIEWER"
ksTitle.TextColor3 = Color3.new(1,1,1)
ksTitle.Font = Enum.Font.GothamBlack
ksTitle.TextSize = 22
ksTitle.LayoutOrder = 1; ksTitle.ZIndex = 83

-- Desc
local ksDesc = Instance.new("TextLabel", ksContent)
ksDesc.Size = UDim2.new(1,-20,0,32)
ksDesc.BackgroundTransparency = 1
ksDesc.Text = "Masukkan access key untuk membuka semua fitur premium."
ksDesc.TextColor3 = Color3.fromRGB(150,150,170)
ksDesc.Font = Enum.Font.Gotham
ksDesc.TextSize = 11; ksDesc.TextWrapped = true
ksDesc.LayoutOrder = 2; ksDesc.ZIndex = 83

-- Input container
local ksInputFrame = Instance.new("Frame", ksContent)
ksInputFrame.Size = UDim2.new(1,0,0,50)
ksInputFrame.BackgroundColor3 = Color3.fromRGB(25,25,38)
ksInputFrame.LayoutOrder = 3; ksInputFrame.ZIndex = 84
corner(ksInputFrame, 14)
stroke(ksInputFrame, Color3.fromRGB(255,255,255), 1, 0.8)

local keyInput = Instance.new("TextBox", ksInputFrame)
keyInput.Size = UDim2.new(1,-20,1,0)
keyInput.Position = UDim2.new(0,10,0,0)
keyInput.BackgroundTransparency = 1
keyInput.Text = ""
keyInput.PlaceholderText = "KEY-XXXXXXXX"
keyInput.PlaceholderColor3 = Color3.fromRGB(100,100,130)
keyInput.TextColor3 = Color3.new(1,1,1)
keyInput.Font = Enum.Font.GothamBold
keyInput.TextSize = 15
keyInput.TextXAlignment = Enum.TextXAlignment.Center
keyInput.ClearTextOnFocus = false
keyInput.ZIndex = 85

-- Status
local ksStatus = Instance.new("TextLabel", ksContent)
ksStatus.Size = UDim2.new(1,0,0,22)
ksStatus.BackgroundTransparency = 1
ksStatus.Text = ""
ksStatus.TextColor3 = Color3.fromRGB(255,255,255)
ksStatus.Font = Enum.Font.GothamBold
ksStatus.TextSize = 11
ksStatus.LayoutOrder = 4; ksStatus.ZIndex = 83

-- Unlock button
local ksUnlockBtn = Instance.new("TextButton", ksContent)
ksUnlockBtn.Size = UDim2.new(1,0,0,48)
ksUnlockBtn.BackgroundColor3 = Color3.fromRGB(255,255,255)
ksUnlockBtn.Text = "UNLOCK"
ksUnlockBtn.TextColor3 = Color3.fromRGB(0,0,0)
ksUnlockBtn.Font = Enum.Font.GothamBlack
ksUnlockBtn.TextSize = 16
ksUnlockBtn.AutoButtonColor = false
ksUnlockBtn.LayoutOrder = 5; ksUnlockBtn.ZIndex = 84
corner(ksUnlockBtn, 14)
pressFX(ksUnlockBtn)

-- Buy key button
local ksBuyBtn = Instance.new("TextButton", ksContent)
ksBuyBtn.Size = UDim2.new(1,0,0,40)
ksBuyBtn.BackgroundColor3 = Color3.fromRGB(255,255,255)
ksBuyBtn.BackgroundTransparency = 0.9
ksBuyBtn.Text = "BUY KEY"
ksBuyBtn.TextColor3 = Color3.fromRGB(255,255,255)
ksBuyBtn.Font = Enum.Font.GothamBold
ksBuyBtn.TextSize = 13
ksBuyBtn.AutoButtonColor = false
ksBuyBtn.LayoutOrder = 6; ksBuyBtn.ZIndex = 84
corner(ksBuyBtn, 10)
stroke(ksBuyBtn, Color3.fromRGB(255,255,255), 1, 0.6)
pressFX(ksBuyBtn)

-- Build info
local ksBuild = Instance.new("TextLabel", ksContent)
ksBuild.Size = UDim2.new(1,0,0,16)
ksBuild.BackgroundTransparency = 1
ksBuild.Text = "Build v2.1.0 | © 2025 " .. (Config.DEVELOPER_USERNAME or "AlfreadR0rw")
ksBuild.TextColor3 = Color3.fromRGB(80,80,100)
ksBuild.Font = Enum.Font.Gotham
ksBuild.TextSize = 8
ksBuild.LayoutOrder = 7; ksBuild.ZIndex = 83

-- ==================== CHAT NOTIFICATION BANNER ====================
-- Notif banner masuk dari atas layar dengan tombol balas
local chatNotifBanner = nil
local chatNotifQueue = {}
local chatNotifBusy  = false

local function dismissChatNotif()
    if not chatNotifBanner then chatNotifBusy = false; return end
    local b = chatNotifBanner
    chatNotifBanner = nil
    tween(b, {Position = UDim2.new(0, 10, -0.25, 0)}, 0.3, Enum.EasingStyle.Quart)
    task.delay(0.35, function()
        pcall(function() b:Destroy() end)
        chatNotifBusy = false
        if #chatNotifQueue > 0 then
            task.wait(0.2)
            local nxt = table.remove(chatNotifQueue, 1)
            if nxt then nxt() end
        end
    end)
end

local function showChatNotifBanner(fromName, messageText, chatId, replyCallback)
    local function show()
        chatNotifBusy = true
        if chatNotifBanner then
            pcall(function() chatNotifBanner:Destroy() end)
            chatNotifBanner = nil
        end

        local screenGui = gui
        local banner = Instance.new("Frame", screenGui)
        banner.Size = UDim2.new(1, -20, 0, 90)
        banner.Position = UDim2.new(0, 10, -0.25, 0)
        banner.BackgroundColor3 = Color3.fromRGB(18, 18, 26)
        banner.ZIndex = 999
        banner.ClipsDescendants = true
        banner.BorderSizePixel = 0
        corner(banner, 18)
        stroke(banner, Color3.fromRGB(0, 150, 255), 1.5, 0.3)

        -- Glow strip kiri
        local strip = Instance.new("Frame", banner)
        strip.Size = UDim2.new(0, 4, 1, -20)
        strip.Position = UDim2.new(0, 8, 0, 10)
        strip.BackgroundColor3 = Color3.fromRGB(0, 150, 255)
        strip.ZIndex = 1000
        corner(strip, 2)

        -- Dari label
        local fromLbl = Instance.new("TextLabel", banner)
        fromLbl.Size = UDim2.new(1, -80, 0, 18)
        fromLbl.Position = UDim2.new(0, 20, 0, 8)
        fromLbl.BackgroundTransparency = 1
        fromLbl.Text = "📨 " .. (fromName or "Admin")
        fromLbl.TextColor3 = Color3.fromRGB(0, 200, 255)
        fromLbl.Font = Enum.Font.GothamBlack
        fromLbl.TextSize = 12
        fromLbl.TextXAlignment = Enum.TextXAlignment.Left
        fromLbl.ZIndex = 1001

        -- Pesan
        local msgLbl = Instance.new("TextLabel", banner)
        msgLbl.Size = UDim2.new(1, -24, 0, 20)
        msgLbl.Position = UDim2.new(0, 20, 0, 27)
        msgLbl.BackgroundTransparency = 1
        msgLbl.Text = messageText or ""
        msgLbl.TextColor3 = Color3.fromRGB(200, 200, 220)
        msgLbl.Font = Enum.Font.Gotham
        msgLbl.TextSize = 11
        msgLbl.TextXAlignment = Enum.TextXAlignment.Left
        msgLbl.TextTruncate = Enum.TextTruncate.AtEnd
        msgLbl.ZIndex = 1001

        -- Tombol BALAS
        local replyBtn = Instance.new("TextButton", banner)
        replyBtn.Size = UDim2.new(0, 90, 0, 26)
        replyBtn.Position = UDim2.new(0, 20, 0, 56)
        replyBtn.BackgroundColor3 = Color3.fromRGB(0, 150, 255)
        replyBtn.Text = "↩ Balas"
        replyBtn.TextColor3 = Color3.new(1,1,1)
        replyBtn.Font = Enum.Font.GothamBold
        replyBtn.TextSize = 11
        replyBtn.AutoButtonColor = false
        replyBtn.ZIndex = 1002
        corner(replyBtn, 8)

        -- Tombol TUTUP
        local closeBtn = Instance.new("TextButton", banner)
        closeBtn.Size = UDim2.new(0, 26, 0, 26)
        closeBtn.Position = UDim2.new(1, -34, 0, 8)
        closeBtn.BackgroundTransparency = 1
        closeBtn.Text = "✕"
        closeBtn.TextColor3 = Color3.fromRGB(150,150,170)
        closeBtn.Font = Enum.Font.GothamBold
        closeBtn.TextSize = 14
        closeBtn.ZIndex = 1002

        chatNotifBanner = banner

        -- Animasi masuk
        tween(banner, {Position = UDim2.new(0, 10, 0, 10)}, 0.4, Enum.EasingStyle.Back)

        -- Quick reply inline
        local isReplying = false
        local replyBox = Instance.new("Frame", banner)
        replyBox.Size = UDim2.new(1, -20, 0, 34)
        replyBox.Position = UDim2.new(0, 10, 1, 4)  -- tersembunyi di bawah
        replyBox.BackgroundColor3 = Color3.fromRGB(28, 28, 36)
        replyBox.ZIndex = 1002
        corner(replyBox, 10)
        stroke(replyBox, Color3.fromRGB(0,150,255), 1, 0.5)

        local replyInput = Instance.new("TextBox", replyBox)
        replyInput.Size = UDim2.new(1, -46, 1, -8)
        replyInput.Position = UDim2.new(0, 8, 0, 4)
        replyInput.BackgroundTransparency = 1
        replyInput.PlaceholderText = "Balas pesan..."
        replyInput.PlaceholderColor3 = Color3.fromRGB(100,100,120)
        replyInput.Text = ""
        replyInput.TextColor3 = Color3.new(1,1,1)
        replyInput.Font = Enum.Font.Gotham
        replyInput.TextSize = 11
        replyInput.ClearTextOnFocus = false
        replyInput.ZIndex = 1003

        local sendReplyBtn = Instance.new("TextButton", replyBox)
        sendReplyBtn.Size = UDim2.new(0, 30, 0, 26)
        sendReplyBtn.Position = UDim2.new(1, -36, 0, 4)
        sendReplyBtn.BackgroundColor3 = Color3.fromRGB(0, 200, 100)
        sendReplyBtn.Text = "➤"
        sendReplyBtn.TextColor3 = Color3.new(1,1,1)
        sendReplyBtn.Font = Enum.Font.GothamBlack
        sendReplyBtn.TextSize = 13
        sendReplyBtn.AutoButtonColor = false
        sendReplyBtn.ZIndex = 1003
        corner(sendReplyBtn, 100)

        local function expandReply()
            if isReplying then return end
            isReplying = true
            -- Perluas banner ke bawah
            tween(banner, {Size = UDim2.new(1,-20,0,136)}, 0.25, Enum.EasingStyle.Quart)
            tween(replyBox, {Position = UDim2.new(0,10,0,94)}, 0.25, Enum.EasingStyle.Quart)
            task.wait(0.3)
            pcall(function() replyInput:CaptureFocus() end)
        end

        local function doSendReply()
            local txt = replyInput.Text
            if txt == "" or txt:match("^%s*$") then return end
            replyInput.Text = ""
            -- Kirim ke Firebase sebagai reply dari player
            if Firebase and Firebase.SendChat then
                pcall(function()
                    Firebase.SendChat(
                        LocalPlayer.UserId,
                        LocalPlayer.DisplayName,
                        LocalPlayer.Name,
                        txt,
                        chatId,         -- replyToId
                        fromName        -- replyToName
                    )
                end)
            end
            if replyCallback then pcall(replyCallback, txt) end
            _G.showDynamicNotification("Balasan terkirim!", Color3.fromRGB(0,200,100))
            dismissChatNotif()
        end

        replyBtn.MouseButton1Click:Connect(expandReply)
        closeBtn.MouseButton1Click:Connect(dismissChatNotif)
        sendReplyBtn.MouseButton1Click:Connect(doSendReply)
        replyInput.FocusLost:Connect(function(enter) if enter then doSendReply() end end)

        -- Auto dismiss setelah 8 detik kalau tidak dibalas
        task.delay(8, function()
            if chatNotifBanner == banner and not isReplying then
                dismissChatNotif()
            end
        end)
    end

    if chatNotifBusy then
        table.insert(chatNotifQueue, show)
    else
        show()
    end
end

-- Expose ke global supaya Messages.lua bisa pakai
_G.showChatNotif = showChatNotifBanner

-- ==================== KEY SUBMIT LOGIC ====================
local ksChecking = false

local function doSubmitKey()
    if ksChecking then return end
    local key = keyInput.Text:upper():gsub("%s+", "")

    if key == "" then
        ksStatus.Text = "Masukkan key terlebih dahulu"
        ksStatus.TextColor3 = Color3.fromRGB(255, 200, 50)
        return
    end

    if not Firebase or not Firebase.ValidateKey then
        -- Fallback testing: langsung unlock
        _G.unlock()
        return
    end

    ksChecking = true
    ksUnlockBtn.Text = "Checking..."
    ksUnlockBtn.BackgroundColor3 = Color3.fromRGB(180,180,180)
    ksStatus.Text = "Menghubungi server..."
    ksStatus.TextColor3 = Color3.fromRGB(200,200,220)

    task.spawn(function()
        -- PENTING: wrap dua return value ke tabel
        -- supaya pcall tidak kehilangan nilai kedua di beberapa executor
        local ok, res = pcall(function()
            local v, m = Firebase.ValidateKey(
                key,
                LocalPlayer.UserId,
                LocalPlayer.DisplayName,
                LocalPlayer.Name
            )
            return {valid=v, msg=m}
        end)

        ksChecking = false
        ksUnlockBtn.Text = "UNLOCK"
        ksUnlockBtn.BackgroundColor3 = Color3.fromRGB(255,255,255)

        if ok and res and res.valid then
            ksStatus.Text = res.msg or "Key valid!"
            ksStatus.TextColor3 = Color3.fromRGB(0, 255, 100)

            -- Simpan key
            if Storage then
                if Storage.saveKey then
                    pcall(Storage.saveKey, key)
                elseif Storage.appSettings then
                    Storage.appSettings.savedKey = key
                    pcall(function()
                        if Storage.persistSettings then Storage.persistSettings() end
                    end)
                end
            end

            task.wait(0.8)
            _G.unlock()
        else
            local msg = (ok and res and res.msg) or "Key tidak valid."
            ksStatus.Text = msg
            ksStatus.TextColor3 = Color3.fromRGB(255, 80, 80)
        end
    end)
end

ksUnlockBtn.MouseButton1Click:Connect(doSubmitKey)
keyInput.FocusLost:Connect(function(enter) if enter then doSubmitKey() end end)
ksBuyBtn.MouseButton1Click:Connect(function()
    local url = Config.BUY_KEY_URL or "https://google.com"

    -- Tidak ada API resmi Roblox untuk membuka browser dari script biasa.
    -- Ini mencoba beberapa fungsi non-standar yang disediakan sebagian
    -- executor (tidak semua punya, makanya dibungkus pcall satu-satu).
    -- Kalau semua gagal, fallback ke copy clipboard + instruksi jelas.
    local opened = false

    local tryFns = {
        function() return _G.OpenUrl and _G.OpenUrl(url) end,
        function() return openurl and openurl(url) end,
        function() return OpenUrl and OpenUrl(url) end,
        function() return GuiService and GuiService.OpenBrowserWindow and GuiService:OpenBrowserWindow(url) end,
    }

    for _, fn in ipairs(tryFns) do
        local ok = pcall(fn)
        if ok then opened = true; break end
    end

    -- Selalu salin ke clipboard juga, apapun hasilnya di atas,
    -- supaya user selalu punya cara pasti mengakses link.
    if Helpers.copyToClipboard then
        pcall(Helpers.copyToClipboard, url)
    end

    if opened then
        _G.showDynamicNotification("Membuka link pembelian...", Color3.fromRGB(255,180,50))
    else
        _G.showDynamicNotification("Link disalin! Paste di browser kamu.", Color3.fromRGB(255,180,50))
    end
end)

-- ==================== PHONE STATE ====================
_G.PhoneState = {
    selectedPlayer = nil,
    isLocked       = false,
    isCloning      = false,
    toolEquipped   = true,
}

-- ==================== PHONE FUNCTIONS ====================
function _G.showKeyEntry()
    keyScreen.Visible = true
    keyInput.Text = ""
    ksStatus.Text = ""
    task.wait(0.15)
    pcall(function() keyInput:CaptureFocus() end)
end

function _G.hideKeyEntry()
    keyScreen.Visible = false
end

function _G.unlock()
    _G.PhoneState.isLocked = false
    keyScreen.Visible = false
    keyInput.Text = ""
    ksStatus.Text = ""
    if _G.goHome then _G.goHome() end
    _G.showDynamicNotification("Phone Unlocked!", Color3.fromRGB(0,255,100))
end

function _G.openPhone()
    if phone.Visible then return end
    phone.Visible = true
    phone.Size = UDim2.new(0,0,0,0)
    tween(phone, {Size=PHONE_SIZE}, 0.32, Enum.EasingStyle.Back)

    if _G.PhoneState.isLocked then
        -- Cek auto-login
        task.spawn(function()
            if Firebase and Firebase.CheckSavedKey then
                local ok, isValid = pcall(function()
                    return Firebase.CheckSavedKey(LocalPlayer.UserId)
                end)
                if ok and isValid then
                    _G.PhoneState.isLocked = false
                    task.wait(0.3)
                    if _G.goHome then _G.goHome() end
                    _G.showDynamicNotification("Welcome back!", Color3.fromRGB(0,255,100))
                    return
                end
            end
            task.wait(0.4)
            _G.showKeyEntry()
        end)
    else
        if _G.goHome then _G.goHome() end
    end
end

function _G.closePhone()
    if not phone.Visible then return end
    tween(phone, {Size=UDim2.new(0,0,0,0)}, 0.22)
    task.delay(0.22, function() phone.Visible = false end)
end

-- ==================== ONLINE PRESENCE ====================
task.spawn(function()
    if not Firebase or not Firebase.SetOnline then return end
    local function sendPresence()
        pcall(function()
            Firebase.SetOnline(LocalPlayer.UserId, {
                name        = LocalPlayer.Name,
                displayName = LocalPlayer.DisplayName,
                userId      = LocalPlayer.UserId,
                mapName     = tostring(game.PlaceId),
                jobId       = game.JobId,
                lastUpdate  = os.time(),
            })
        end)
    end
    sendPresence()
    while true do
        task.wait(55)
        sendPresence()
    end
end)

game:GetService("Players").LocalPlayer.OnTeleport:Connect(function()
    if Firebase and Firebase.RemoveOnline then
        pcall(function() Firebase.RemoveOnline(LocalPlayer.UserId) end)
    end
end)

-- ==================== AUTO LOCK SYSTEM ====================
-- Disabled: Phone tidak lagi menggunakan key lock.
