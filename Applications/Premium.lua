-- ================================================
-- PREMIUM APP - Mega Upgrade v2
-- Dark Elegant UI, Persistent Toggle State, Saved Avatars, 10 New Features
-- ================================================

local Services       = _G.Services
local LocalPlayer    = _G.LocalPlayer
local Firebase       = _G.Firebase
local Config         = _G.Config or {}
local Helpers        = _G.Helpers or {}
local appContent     = _G.appContent

local UIS            = Services.UserInputService
local Workspace      = Services.Workspace
local TweenService   = game:GetService("TweenService")

-- ==================== PERSISTENT STATE (di _G, supaya TIDAK reset saat phone dibuka-tutup) ====================
-- PENTING: ini fix untuk bug toggle balik OFF. Sebelumnya trollStates adalah
-- local variable di dalam file yang di-reload tiap kali Premium.lua di-Load()
-- ulang oleh Loader saat app dibuka lagi. Sekarang disimpan di _G supaya
-- bertahan selama sesi game berjalan, terlepas dari berapa kali openPremiumApp
-- dipanggil ulang.
_G.PremiumState = _G.PremiumState or {
    selectedTargetId = nil,
    selectedTargetName = "Pilih Player",
    tpOnTapActive = false,
    trollStates = {}, -- trollStates[targetId][actionKey] = true/false
    lastCommandTime = 0,
}
local State = _G.PremiumState

local COMMAND_COOLDOWN = 1.2

local tapConnectionBegan = nil
local tapConnectionEnded = nil
local inputStartPos = nil

-- ==================== PALETTE ELEGAN ====================
local P = {
    bg          = Color3.fromRGB(10, 10, 14),
    bgCard      = Color3.fromRGB(20, 20, 27),
    bgCard2     = Color3.fromRGB(26, 26, 34),
    bgElevated  = Color3.fromRGB(32, 32, 42),
    accent      = Color3.fromRGB(168, 110, 255),
    accentSoft  = Color3.fromRGB(120, 80, 200),
    accentGlow  = Color3.fromRGB(198, 150, 255),
    green       = Color3.fromRGB(80, 220, 150),
    red         = Color3.fromRGB(255, 90, 100),
    gold        = Color3.fromRGB(255, 195, 90),
    blue        = Color3.fromRGB(100, 170, 255),
    textMain    = Color3.fromRGB(240, 240, 245),
    textSub     = Color3.fromRGB(150, 150, 165),
    textFaint   = Color3.fromRGB(95, 95, 110),
    border      = Color3.fromRGB(45, 45, 58),
}

-- ==================== ACCESS VALIDATION ====================
local function hasAccess()
    if LocalPlayer.UserId == (Config.DEVELOPER_USER_ID or 10164114772) then return true end
    if Firebase and Firebase.IsPermanentUser then
        return Firebase.IsPermanentUser(LocalPlayer.UserId)
    end
    return false
end
_G.hasPremiumAccess = hasAccess

-- ==================== HELPER: gradient card ====================
local function applyGradient(inst, c1, c2, rotation)
    local g = Instance.new("UIGradient", inst)
    g.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, c1),
        ColorSequenceKeypoint.new(1, c2),
    })
    g.Rotation = rotation or 45
    return g
end

local function softShadow(inst)
    local shadow = Instance.new("ImageLabel")
    shadow.Name = "Shadow"
    shadow.BackgroundTransparency = 1
    shadow.Image = "rbxassetid://1316045217"
    shadow.ImageColor3 = Color3.new(0,0,0)
    shadow.ImageTransparency = 0.7
    shadow.ScaleType = Enum.ScaleType.Slice
    shadow.SliceCenter = Rect.new(10,10,118,118)
    shadow.Size = UDim2.new(1, 16, 1, 16)
    shadow.Position = UDim2.new(0, -8, 0, -6)
    shadow.ZIndex = inst.ZIndex - 1
    shadow.Parent = inst.Parent
    return shadow
end

-- ==================== FIREBASE SENDER HELPER ====================
local function sendCommand(cmdType, extraData, silent)
    if not State.selectedTargetId then
        _G.showDynamicNotification("⚠️ Pilih target di Tab Target!", P.red)
        return false
    end

    if os.clock() - State.lastCommandTime < COMMAND_COOLDOWN then
        _G.showDynamicNotification("⏳ Cooldown! Jangan spam.", P.gold)
        return false
    end
    State.lastCommandTime = os.clock()

    local data = { type = cmdType, timestamp = os.time() }
    if extraData then
        for k, v in pairs(extraData) do data[k] = v end
    end
    pcall(function() Firebase.PushCommand(State.selectedTargetId, data) end)
    if not silent then
        _G.showDynamicNotification("✅ Perintah " .. cmdType .. " terkirim!", P.green)
    end
    return true
end

-- ==================== TP-ON-TAP LOGIC ====================
local function setupTapListener(state)
    State.tpOnTapActive = state
    if tapConnectionBegan then tapConnectionBegan:Disconnect() end
    if tapConnectionEnded then tapConnectionEnded:Disconnect() end

    if State.tpOnTapActive then
        _G.showDynamicNotification("TP On-Tap: AKTIF! Ketuk (jangan geser) layar.", P.accent)

        tapConnectionBegan = UIS.InputBegan:Connect(function(input, gp)
            if gp then return end
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                inputStartPos = input.Position
            end
        end)

        tapConnectionEnded = UIS.InputEnded:Connect(function(input, gp)
            if gp or not inputStartPos or not State.selectedTargetId then return end
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                local dist = (input.Position - inputStartPos).Magnitude
                if dist < 15 then
                    local cam = Workspace.CurrentCamera
                    local ray = cam:ScreenPointToRay(input.Position.X, input.Position.Y)
                    local params = RaycastParams.new()
                    params.FilterDescendantsInstances = {LocalPlayer.Character}
                    params.FilterType = Enum.RaycastFilterType.Exclude

                    local result = Workspace:Raycast(ray.Origin, ray.Direction * 1000, params)
                    if result then
                        local cmdData = {
                            type = "teleport_to_point",
                            x = result.Position.X, y = result.Position.Y + 3.5, z = result.Position.Z,
                            fromPlaceId = game.PlaceId, fromJobId = game.JobId, timestamp = os.time()
                        }
                        pcall(function() Firebase.PushCommand(State.selectedTargetId, cmdData) end)

                        local part = Instance.new("Part", Workspace)
                        part.Size = Vector3.new(2, 0.2, 2)
                        part.Position = result.Position
                        part.Anchored = true
                        part.CanCollide = false
                        part.Material = Enum.Material.Neon
                        part.Color = P.accent
                        part.Shape = Enum.PartType.Cylinder
                        task.delay(1.5, function() part:Destroy() end)
                    end
                end
            end
        end)
    else
        _G.showDynamicNotification("TP On-Tap: NONAKTIF", P.textSub)
    end
end

-- ==================== MAIN APP UI ====================
function _G.openPremiumApp()
    if not hasAccess() then
        _G.showDynamicNotification("Akses Ditolak! Membutuhkan Key Permanen.", P.red)
        if _G.goHome then _G.goHome() end
        return
    end

    for _, child in ipairs(appContent:GetChildren()) do
        if child:IsA("GuiObject") then child:Destroy() end
    end

    appContent.BackgroundColor3 = P.bg

    -- ==================== HEADER (Elegan dengan glow) ====================
    local headerFrame = Instance.new("Frame", appContent)
    headerFrame.Size = UDim2.new(1, 0, 0, 44)
    headerFrame.BackgroundColor3 = P.bgCard
    headerFrame.BorderSizePixel = 0
    Helpers.corner(headerFrame, 12)
    applyGradient(headerFrame, P.bgCard, P.bgCard2, 90)

    local crownIcon = Instance.new("TextLabel", headerFrame)
    crownIcon.Size = UDim2.new(0, 30, 1, 0)
    crownIcon.Position = UDim2.new(0, 8, 0, 0)
    crownIcon.BackgroundTransparency = 1
    crownIcon.Text = "👑"
    crownIcon.TextSize = 16
    crownIcon.Font = Enum.Font.GothamBold

    local statusLbl = Instance.new("TextLabel", headerFrame)
    statusLbl.Size = UDim2.new(1, -46, 1, 0)
    statusLbl.Position = UDim2.new(0, 38, 0, 0)
    statusLbl.BackgroundTransparency = 1
    statusLbl.Text = "TARGET: " .. string.upper(State.selectedTargetName)
    statusLbl.TextColor3 = P.accentGlow
    statusLbl.Font = Enum.Font.GothamBlack
    statusLbl.TextSize = 12
    statusLbl.TextXAlignment = Enum.TextXAlignment.Left
    statusLbl.TextTruncate = Enum.TextTruncate.AtEnd

    -- ==================== TABS ====================
    local tabContainer = Instance.new("ScrollingFrame", appContent)
    tabContainer.Size = UDim2.new(1, 0, 0, 38)
    tabContainer.Position = UDim2.new(0, 0, 0, 50)
    tabContainer.BackgroundTransparency = 1
    tabContainer.CanvasSize = UDim2.new(0, 0, 0, 0)
    tabContainer.AutomaticCanvasSize = Enum.AutomaticSize.X
    tabContainer.ScrollBarThickness = 0

    local tabLayout = Instance.new("UIListLayout", tabContainer)
    tabLayout.FillDirection = Enum.FillDirection.Horizontal
    tabLayout.Padding = UDim.new(0, 6)

    local contentArea = Instance.new("Frame", appContent)
    contentArea.Size = UDim2.new(1, 0, 1, -94)
    contentArea.Position = UDim2.new(0, 0, 0, 94)
    contentArea.BackgroundTransparency = 1

    local tabs = {}
    local tabFrames = {}

    local function switchTab(tabName)
        for name, frame in pairs(tabFrames) do frame.Visible = (name == tabName) end
        for name, btn in pairs(tabs) do
            if name == tabName then
                TweenService:Create(btn, TweenInfo.new(0.2), {BackgroundColor3 = P.accent}):Play()
                btn.TextColor3 = Color3.new(1, 1, 1)
            else
                TweenService:Create(btn, TweenInfo.new(0.2), {BackgroundColor3 = P.bgElevated}):Play()
                btn.TextColor3 = P.textSub
            end
        end
    end

    local function createTab(name, icon)
        local btn = Instance.new("TextButton", tabContainer)
        btn.Size = UDim2.new(0, 82, 1, 0)
        btn.BackgroundColor3 = P.bgElevated
        btn.Text = (icon and (icon .. " ") or "") .. name
        btn.TextColor3 = P.textSub
        btn.Font = Enum.Font.GothamBold
        btn.TextSize = 11
        btn.AutoButtonColor = false
        Helpers.corner(btn, 8)
        tabs[name] = btn

        local frame = Instance.new("ScrollingFrame", contentArea)
        frame.Size = UDim2.new(1, 0, 1, 0)
        frame.BackgroundTransparency = 1
        frame.ScrollBarThickness = 2
        frame.ScrollBarImageColor3 = P.accent
        frame.AutomaticCanvasSize = Enum.AutomaticSize.Y
        frame.CanvasSize = UDim2.new(0,0,0,0)
        frame.Visible = false
        tabFrames[name] = frame

        local pad = Instance.new("UIPadding", frame)
        pad.PaddingTop = UDim.new(0, 4)
        pad.PaddingBottom = UDim.new(0, 20)

        local listLay = Instance.new("UIListLayout", frame)
        listLay.Padding = UDim.new(0, 8)
        listLay.HorizontalAlignment = Enum.HorizontalAlignment.Center

        if Helpers.pressFX then Helpers.pressFX(btn) end
        btn.MouseButton1Click:Connect(function() switchTab(name) end)
        return frame
    end

    -- ==================== CARD HELPER (dipakai berulang di banyak tab) ====================
    local function addCard(parent, title, desc, btnText, btnColor, callback)
        local card = Instance.new("Frame", parent)
        card.Size = UDim2.new(0.95, 0, 0, 78)
        card.BackgroundColor3 = P.bgCard2
        Helpers.corner(card, 12)
        Helpers.stroke(card, P.border, 1, 0.4)

        local tLbl = Instance.new("TextLabel", card)
        tLbl.Size = UDim2.new(1, -84, 0, 20); tLbl.Position = UDim2.new(0, 12, 0, 10)
        tLbl.BackgroundTransparency = 1; tLbl.Text = title; tLbl.Font = Enum.Font.GothamBold
        tLbl.TextSize = 13; tLbl.TextXAlignment = Enum.TextXAlignment.Left
        tLbl.TextColor3 = P.textMain

        local dLbl = Instance.new("TextLabel", card)
        dLbl.Size = UDim2.new(1, -84, 0, 40); dLbl.Position = UDim2.new(0, 12, 0, 30)
        dLbl.BackgroundTransparency = 1; dLbl.Text = desc; dLbl.Font = Enum.Font.Gotham
        dLbl.TextSize = 10; dLbl.TextXAlignment = Enum.TextXAlignment.Left; dLbl.TextWrapped = true
        dLbl.TextColor3 = P.textSub

        local btn = Instance.new("TextButton", card)
        btn.Size = UDim2.new(0, 68, 0, 36); btn.Position = UDim2.new(1, -78, 0.5, -18)
        btn.BackgroundColor3 = btnColor or P.accent; btn.TextColor3 = Color3.new(1,1,1)
        btn.Text = btnText; btn.Font = Enum.Font.GothamBold; btn.TextSize = 11
        btn.AutoButtonColor = false
        Helpers.corner(btn, 9)
        if Helpers.pressFX then Helpers.pressFX(btn) end
        btn.MouseButton1Click:Connect(callback)
        return card, btn
    end

    -- ==================== TAB 1: TARGET ====================
    local targetFrame = createTab("Target", "🎯")

    local refBtn = Instance.new("TextButton", targetFrame)
    refBtn.Size = UDim2.new(0.95, 0, 0, 38)
    refBtn.BackgroundColor3 = P.accent
    refBtn.Text = "🔄  Refresh Player Online"
    refBtn.TextColor3 = Color3.new(1,1,1)
    refBtn.Font = Enum.Font.GothamBold
    refBtn.TextSize = 12
    refBtn.AutoButtonColor = false
    Helpers.corner(refBtn, 10)
    applyGradient(refBtn, P.accent, P.accentSoft, 90)
    if Helpers.pressFX then Helpers.pressFX(refBtn) end

    local playerListContainer = Instance.new("Frame", targetFrame)
    playerListContainer.Size = UDim2.new(0.95, 0, 0, 0)
    playerListContainer.AutomaticSize = Enum.AutomaticSize.Y
    playerListContainer.BackgroundTransparency = 1
    local pLayout = Instance.new("UIListLayout", playerListContainer)
    pLayout.Padding = UDim.new(0, 8)

    local function loadPlayers()
        for _, c in ipairs(playerListContainer:GetChildren()) do if c:IsA("GuiButton") then c:Destroy() end end
        task.spawn(function()
            local ok, players = pcall(function() return Firebase.GetOnlinePlayers() end)
            if not ok or not players then return end

            for uidStr, pData in pairs(players) do
                local uid = tonumber(uidStr)
                if uid == LocalPlayer.UserId then continue end

                local isOnline = pData.isOnline
                if pData.lastSeen and (os.time() - pData.lastSeen) > 120 then isOnline = false end
                if not isOnline then continue end

                local isSelected = (State.selectedTargetId == uid)

                local pRow = Instance.new("TextButton", playerListContainer)
                pRow.Size = UDim2.new(1, 0, 0, 58)
                pRow.BackgroundColor3 = isSelected and P.accentSoft or P.bgCard2
                pRow.AutoButtonColor = false
                Helpers.corner(pRow, 12)
                Helpers.stroke(pRow, isSelected and P.accent or P.border, isSelected and 1.5 or 1, isSelected and 0.1 or 0.4)

                local av = Instance.new("ImageLabel", pRow)
                av.Size = UDim2.new(0, 42, 0, 42)
                av.Position = UDim2.new(0, 10, 0.5, -21)
                av.BackgroundColor3 = P.bgElevated
                av.Image = "https://www.roblox.com/headshot-thumbnail/image?userId=" .. uidStr .. "&width=150&height=150&format=png"
                Helpers.corner(av, 100)
                Helpers.stroke(av, isSelected and P.accentGlow or P.border, isSelected and 2 or 1, 0)

                local onlineDot = Instance.new("Frame", av)
                onlineDot.Size = UDim2.new(0, 10, 0, 10)
                onlineDot.Position = UDim2.new(1, -10, 1, -10)
                onlineDot.BackgroundColor3 = P.green
                Helpers.corner(onlineDot, 100)
                Helpers.stroke(onlineDot, P.bgCard2, 2, 0)

                local nameLbl = Instance.new("TextLabel", pRow)
                nameLbl.Size = UDim2.new(1, -68, 0, 18)
                nameLbl.Position = UDim2.new(0, 62, 0, 10)
                nameLbl.BackgroundTransparency = 1
                nameLbl.Text = pData.username or "User"
                nameLbl.TextColor3 = P.textMain
                nameLbl.Font = Enum.Font.GothamBold
                nameLbl.TextSize = 13
                nameLbl.TextXAlignment = Enum.TextXAlignment.Left

                local mapLbl = Instance.new("TextLabel", pRow)
                mapLbl.Size = UDim2.new(1, -68, 0, 14)
                mapLbl.Position = UDim2.new(0, 62, 0, 30)
                mapLbl.BackgroundTransparency = 1
                mapLbl.Text = "🗺️ " .. (pData.mapName or "Unknown Map")
                mapLbl.TextColor3 = P.textSub
                mapLbl.Font = Enum.Font.Gotham
                mapLbl.TextSize = 10
                mapLbl.TextXAlignment = Enum.TextXAlignment.Left

                if isSelected then
                    local checkLbl = Instance.new("TextLabel", pRow)
                    checkLbl.Size = UDim2.new(0, 24, 0, 24)
                    checkLbl.Position = UDim2.new(1, -30, 0.5, -12)
                    checkLbl.BackgroundTransparency = 1
                    checkLbl.Text = "✓"
                    checkLbl.TextColor3 = P.accentGlow
                    checkLbl.Font = Enum.Font.GothamBlack
                    checkLbl.TextSize = 16
                end

                pRow.MouseButton1Click:Connect(function()
                    State.selectedTargetId = uid
                    State.selectedTargetName = pData.username or tostring(uid)
                    statusLbl.Text = "TARGET: " .. string.upper(State.selectedTargetName)
                    loadPlayers()
                    _G.showDynamicNotification("Target: " .. State.selectedTargetName, P.accent)
                end)
            end
        end)
    end
    refBtn.MouseButton1Click:Connect(loadPlayers)
    loadPlayers()

    -- ==================== TAB 2: TELEPORT ====================
    local tpFrame = createTab("Teleport", "📍")

    addCard(tpFrame, "Tarik ke Saya", "Menarik target lintas server langsung ke Anda.", "Tarik", P.accent, function()
        sendCommand("teleport_to_dev", { devUserId = LocalPlayer.UserId, devPlaceId = game.PlaceId, devJobId = game.JobId })
    end)

    local _, tapBtn = addCard(tpFrame, "TP On-Tap", "Ketuk layar untuk memindahkan target ke titik tersebut.", State.tpOnTapActive and "ON" or "OFF",
        State.tpOnTapActive and P.green or P.bgElevated, function() end)
    tapBtn.MouseButton1Click:Connect(function()
        setupTapListener(not State.tpOnTapActive)
        tapBtn.Text = State.tpOnTapActive and "ON" or "OFF"
        TweenService:Create(tapBtn, TweenInfo.new(0.2), {BackgroundColor3 = State.tpOnTapActive and P.green or P.bgElevated}):Play()
    end)

    -- ==================== TAB 3: ADMIN & CHAT ====================
    local chatFrame = createTab("Admin", "💬")

    local chatInputCard = Instance.new("Frame", chatFrame)
    chatInputCard.Size = UDim2.new(0.95, 0, 0, 50)
    chatInputCard.BackgroundColor3 = P.bgCard2
    Helpers.corner(chatInputCard, 12)
    Helpers.stroke(chatInputCard, P.border, 1, 0.4)

    local chatInput = Instance.new("TextBox", chatInputCard)
    chatInput.Size = UDim2.new(1, -20, 1, -14)
    chatInput.Position = UDim2.new(0, 10, 0, 7)
    chatInput.BackgroundColor3 = P.bgElevated
    chatInput.PlaceholderText = "Ketik pesan publik..."
    chatInput.Text = ""
    chatInput.Font = Enum.Font.Gotham
    chatInput.TextSize = 12
    chatInput.TextColor3 = P.textMain
    chatInput.ClearTextOnFocus = false
    Helpers.corner(chatInput, 8)

    local sendChatBtn = Instance.new("TextButton", chatFrame)
    sendChatBtn.Size = UDim2.new(0.95, 0, 0, 38)
    sendChatBtn.BackgroundColor3 = P.green
    sendChatBtn.Text = "Paksa Target Bicara (Global)"
    sendChatBtn.TextColor3 = Color3.new(1,1,1)
    sendChatBtn.Font = Enum.Font.GothamBold
    sendChatBtn.TextSize = 12
    sendChatBtn.AutoButtonColor = false
    Helpers.corner(sendChatBtn, 10)
    if Helpers.pressFX then Helpers.pressFX(sendChatBtn) end

    sendChatBtn.MouseButton1Click:Connect(function()
        if sendCommand("force_chat", { message = chatInput.Text }) then chatInput.Text = "" end
    end)

    addCard(chatFrame, "Refresh Avatar", "Kirim command 're' untuk refresh tampilan avatar target.", "Kirim", P.blue, function()
        sendCommand("force_remote", { remotePath = Config.REMOTE_PATH or "Remotes.Command.CommandEvent", cmd = "re" })
    end)

    -- ===== FITUR BARU 1: Screen Message =====
    local msgInputCard = Instance.new("Frame", chatFrame)
    msgInputCard.Size = UDim2.new(0.95, 0, 0, 50)
    msgInputCard.BackgroundColor3 = P.bgCard2
    Helpers.corner(msgInputCard, 12)
    Helpers.stroke(msgInputCard, P.border, 1, 0.4)

    local msgInput = Instance.new("TextBox", msgInputCard)
    msgInput.Size = UDim2.new(1, -20, 1, -14)
    msgInput.Position = UDim2.new(0, 10, 0, 7)
    msgInput.BackgroundColor3 = P.bgElevated
    msgInput.PlaceholderText = "Pesan banner full-screen..."
    msgInput.Text = ""
    msgInput.Font = Enum.Font.Gotham
    msgInput.TextSize = 12
    msgInput.TextColor3 = P.textMain
    msgInput.ClearTextOnFocus = false
    Helpers.corner(msgInput, 8)

    local sendMsgBtn = Instance.new("TextButton", chatFrame)
    sendMsgBtn.Size = UDim2.new(0.95, 0, 0, 38)
    sendMsgBtn.BackgroundColor3 = P.gold
    sendMsgBtn.Text = "📢 Kirim Banner Layar"
    sendMsgBtn.TextColor3 = Color3.fromRGB(30,25,10)
    sendMsgBtn.Font = Enum.Font.GothamBold
    sendMsgBtn.TextSize = 12
    sendMsgBtn.AutoButtonColor = false
    Helpers.corner(sendMsgBtn, 10)
    if Helpers.pressFX then Helpers.pressFX(sendMsgBtn) end
    sendMsgBtn.MouseButton1Click:Connect(function()
        if msgInput.Text == "" then
            _G.showDynamicNotification("Isi pesan dulu!", P.red)
            return
        end
        if sendCommand("screen_message", { message = msgInput.Text, duration = 5 }) then
            msgInput.Text = ""
        end
    end)

    -- ===== FITUR BARU 2: Kick =====
    addCard(chatFrame, "Kick Target", "Keluarkan target dari server saat ini.", "Kick", P.red, function()
        sendCommand("kick", { reason = "Dikeluarkan oleh Admin." })
    end)

    -- ==================== TAB 4: AVATAR (fitur ganti avatar tersimpan) ====================
    local avatarFrame = createTab("Avatar", "👤")

    -- --- Simpan avatar target saat ini ---
    local saveAvatarCard = Instance.new("Frame", avatarFrame)
    saveAvatarCard.Size = UDim2.new(0.95, 0, 0, 96)
    saveAvatarCard.BackgroundColor3 = P.bgCard2
    Helpers.corner(saveAvatarCard, 12)
    Helpers.stroke(saveAvatarCard, P.border, 1, 0.4)

    local saveTitle = Instance.new("TextLabel", saveAvatarCard)
    saveTitle.Size = UDim2.new(1, -20, 0, 20); saveTitle.Position = UDim2.new(0, 12, 0, 10)
    saveTitle.BackgroundTransparency = 1; saveTitle.Text = "💾 Simpan Avatar Target"
    saveTitle.Font = Enum.Font.GothamBold; saveTitle.TextSize = 13
    saveTitle.TextColor3 = P.textMain; saveTitle.TextXAlignment = Enum.TextXAlignment.Left

    local saveDesc = Instance.new("TextLabel", saveAvatarCard)
    saveDesc.Size = UDim2.new(1, -20, 0, 30); saveDesc.Position = UDim2.new(0, 12, 0, 30)
    saveDesc.BackgroundTransparency = 1
    saveDesc.Text = "Ambil snapshot avatar yang sedang dipakai target, simpan untuk dipakai ulang kapan saja."
    saveDesc.Font = Enum.Font.Gotham; saveDesc.TextSize = 10; saveDesc.TextWrapped = true
    saveDesc.TextColor3 = P.textSub; saveDesc.TextXAlignment = Enum.TextXAlignment.Left

    local saveAvatarBtn = Instance.new("TextButton", saveAvatarCard)
    saveAvatarBtn.Size = UDim2.new(1, -24, 0, 32); saveAvatarBtn.Position = UDim2.new(0, 12, 0, 58)
    saveAvatarBtn.BackgroundColor3 = P.accent
    saveAvatarBtn.Text = "📸 Ambil & Simpan Snapshot"
    saveAvatarBtn.TextColor3 = Color3.new(1,1,1)
    saveAvatarBtn.Font = Enum.Font.GothamBold; saveAvatarBtn.TextSize = 11
    saveAvatarBtn.AutoButtonColor = false
    Helpers.corner(saveAvatarBtn, 8)
    if Helpers.pressFX then Helpers.pressFX(saveAvatarBtn) end

    local savedAvatarListContainer = Instance.new("Frame", avatarFrame)
    savedAvatarListContainer.Size = UDim2.new(0.95, 0, 0, 0)
    savedAvatarListContainer.AutomaticSize = Enum.AutomaticSize.Y
    savedAvatarListContainer.BackgroundTransparency = 1
    local savedLayout = Instance.new("UIListLayout", savedAvatarListContainer)
    savedLayout.Padding = UDim.new(0, 8)

    local function loadSavedAvatars()
        for _, c in ipairs(savedAvatarListContainer:GetChildren()) do if c:IsA("GuiObject") then c:Destroy() end end

        local sectionLbl = Instance.new("TextLabel", savedAvatarListContainer)
        sectionLbl.Size = UDim2.new(1, 0, 0, 22)
        sectionLbl.BackgroundTransparency = 1
        sectionLbl.Text = "📂 Avatar Tersimpan"
        sectionLbl.TextColor3 = P.accentGlow
        sectionLbl.Font = Enum.Font.GothamBold
        sectionLbl.TextSize = 12
        sectionLbl.TextXAlignment = Enum.TextXAlignment.Left

        task.spawn(function()
            local ok, avatars = pcall(function() return Firebase.GetSavedAvatars(LocalPlayer.UserId) end)
            if not ok or not avatars or type(avatars) ~= "table" then
                local empty = Instance.new("TextLabel", savedAvatarListContainer)
                empty.Size = UDim2.new(1, 0, 0, 40)
                empty.BackgroundTransparency = 1
                empty.Text = "Belum ada avatar tersimpan."
                empty.TextColor3 = P.textFaint
                empty.Font = Enum.Font.Gotham
                empty.TextSize = 11
                return
            end

            for avatarId, avData in pairs(avatars) do
                if type(avData) == "table" then
                    local card = Instance.new("Frame", savedAvatarListContainer)
                    card.Size = UDim2.new(1, 0, 0, 70)
                    card.BackgroundColor3 = P.bgCard2
                    Helpers.corner(card, 12)
                    Helpers.stroke(card, P.border, 1, 0.4)

                    local av = Instance.new("ImageLabel", card)
                    av.Size = UDim2.new(0, 50, 0, 50)
                    av.Position = UDim2.new(0, 10, 0.5, -25)
                    av.BackgroundColor3 = P.bgElevated
                    av.Image = avData.sourceUserId and ("https://www.roblox.com/headshot-thumbnail/image?userId=" .. avData.sourceUserId .. "&width=150&height=150&format=png") or ""
                    Helpers.corner(av, 10)

                    local nameLbl = Instance.new("TextLabel", card)
                    nameLbl.Size = UDim2.new(1, -180, 0, 18)
                    nameLbl.Position = UDim2.new(0, 68, 0, 10)
                    nameLbl.BackgroundTransparency = 1
                    nameLbl.Text = avData.name or "Avatar"
                    nameLbl.TextColor3 = P.textMain
                    nameLbl.Font = Enum.Font.GothamBold
                    nameLbl.TextSize = 12
                    nameLbl.TextXAlignment = Enum.TextXAlignment.Left
                    nameLbl.TextTruncate = Enum.TextTruncate.AtEnd

                    local countLbl = Instance.new("TextLabel", card)
                    countLbl.Size = UDim2.new(1, -180, 0, 16)
                    countLbl.Position = UDim2.new(0, 68, 0, 30)
                    countLbl.BackgroundTransparency = 1
                    countLbl.Text = (avData.assetIds and #avData.assetIds or 0) .. " item · dari " .. (avData.sourceName or "?")
                    countLbl.TextColor3 = P.textSub
                    countLbl.Font = Enum.Font.Gotham
                    countLbl.TextSize = 9
                    countLbl.TextXAlignment = Enum.TextXAlignment.Left

                    local applyBtn = Instance.new("TextButton", card)
                    applyBtn.Size = UDim2.new(0, 58, 0, 30)
                    applyBtn.Position = UDim2.new(1, -136, 0.5, -15)
                    applyBtn.BackgroundColor3 = P.accent
                    applyBtn.Text = "Apply"
                    applyBtn.TextColor3 = Color3.new(1,1,1)
                    applyBtn.Font = Enum.Font.GothamBold
                    applyBtn.TextSize = 10
                    applyBtn.AutoButtonColor = false
                    Helpers.corner(applyBtn, 7)
                    if Helpers.pressFX then Helpers.pressFX(applyBtn) end
                    applyBtn.MouseButton1Click:Connect(function()
                        if not State.selectedTargetId then
                            _G.showDynamicNotification("⚠️ Pilih target dulu di Tab Target!", P.red)
                            return
                        end
                        applyBtn.Text = "..."
                        sendCommand("apply_avatar", {
                            assetIds = avData.assetIds,
                            remotePath = Config.REMOTE_PATH or "Remotes.Command.CommandEvent",
                        }, true)
                        _G.showDynamicNotification("👤 Avatar '" .. (avData.name or "?") .. "' dikirim + auto reset!", P.accent)
                        task.delay(1, function() applyBtn.Text = "Apply" end)
                    end)

                    local delBtn = Instance.new("TextButton", card)
                    delBtn.Size = UDim2.new(0, 58, 0, 30)
                    delBtn.Position = UDim2.new(1, -68, 0.5, -15)
                    delBtn.BackgroundColor3 = P.red
                    delBtn.Text = "Hapus"
                    delBtn.TextColor3 = Color3.new(1,1,1)
                    delBtn.Font = Enum.Font.GothamBold
                    delBtn.TextSize = 10
                    delBtn.AutoButtonColor = false
                    Helpers.corner(delBtn, 7)
                    if Helpers.pressFX then Helpers.pressFX(delBtn) end
                    delBtn.MouseButton1Click:Connect(function()
                        pcall(function() Firebase.DeleteSavedAvatar(LocalPlayer.UserId, avatarId) end)
                        _G.showDynamicNotification("Avatar dihapus", P.textSub)
                        loadSavedAvatars()
                    end)
                end
            end
        end)
    end

    saveAvatarBtn.MouseButton1Click:Connect(function()
        if not State.selectedTargetId then
            _G.showDynamicNotification("⚠️ Pilih target dulu di Tab Target!", P.red)
            return
        end
        saveAvatarBtn.Text = "Mengambil data..."
        task.spawn(function()
            local ok, result = pcall(function()
                return HttpService and HttpService:JSONDecode(HttpService:GetAsync(
                    "https://avatar.roblox.com/v1/users/" .. State.selectedTargetId .. "/avatar"
                ))
            end)
            local assetIds = {}
            if ok and result and result.assets then
                for _, asset in ipairs(result.assets) do
                    if asset.id then table.insert(assetIds, tostring(asset.id)) end
                end
            end

            if #assetIds == 0 then
                saveAvatarBtn.Text = "📸 Ambil & Simpan Snapshot"
                _G.showDynamicNotification("Gagal ambil data avatar / kosong.", P.red)
                return
            end

            pcall(function()
                Firebase.SaveAvatarSnapshot(LocalPlayer.UserId, {
                    name = State.selectedTargetName .. " - " .. os.date("%d/%m %H:%M"),
                    assetIds = assetIds,
                    sourceUserId = State.selectedTargetId,
                    sourceName = State.selectedTargetName,
                    savedAt = os.time(),
                })
            end)

            saveAvatarBtn.Text = "📸 Ambil & Simpan Snapshot"
            _G.showDynamicNotification("✅ Avatar tersimpan! (" .. #assetIds .. " item)", P.green)
            loadSavedAvatars()
        end)
    end)

    loadSavedAvatars()

    -- ===== FITUR BARU 3: Strip Avatar =====
    addCard(avatarFrame, "Strip Avatar", "Copot semua aksesoris & pakaian target (jadi avatar default).", "Strip", P.red, function()
        sendCommand("strip_avatar", {})
    end)

    -- ==================== TAB 5: TROLL (dengan state persist) ====================
    local trollFrame = createTab("Troll", "😈")

    local function getTrollState(actionKey)
        local t = State.trollStates[State.selectedTargetId]
        if not t then return false end
        return t[actionKey] == true
    end

    local function setTrollState(actionKey, val)
        State.trollStates[State.selectedTargetId] = State.trollStates[State.selectedTargetId] or {}
        State.trollStates[State.selectedTargetId][actionKey] = val
    end

    local function addTrollToggle(parent, title, desc, actionOn, actionOff, color)
        local card = Instance.new("Frame", parent)
        card.Size = UDim2.new(0.95, 0, 0, 72)
        card.BackgroundColor3 = P.bgCard2
        Helpers.corner(card, 12)
        Helpers.stroke(card, P.border, 1, 0.4)

        local tLbl = Instance.new("TextLabel", card)
        tLbl.Size = UDim2.new(1, -90, 0, 20); tLbl.Position = UDim2.new(0, 12, 0, 8)
        tLbl.BackgroundTransparency = 1; tLbl.Text = title; tLbl.Font = Enum.Font.GothamBold
        tLbl.TextSize = 13; tLbl.TextXAlignment = Enum.TextXAlignment.Left; tLbl.TextColor3 = P.textMain

        local dLbl = Instance.new("TextLabel", card)
        dLbl.Size = UDim2.new(1, -90, 0, 35); dLbl.Position = UDim2.new(0, 12, 0, 28)
        dLbl.BackgroundTransparency = 1; dLbl.Text = desc; dLbl.Font = Enum.Font.Gotham
        dLbl.TextSize = 10; dLbl.TextXAlignment = Enum.TextXAlignment.Left; dLbl.TextWrapped = true
        dLbl.TextColor3 = P.textSub

        local isOn = getTrollState(actionOn)

        local btn = Instance.new("TextButton", card)
        btn.Size = UDim2.new(0, 72, 0, 36); btn.Position = UDim2.new(1, -82, 0.5, -18)
        btn.BackgroundColor3 = isOn and P.green or color
        btn.TextColor3 = Color3.new(1,1,1)
        btn.Text = isOn and "ON" or "OFF"
        btn.Font = Enum.Font.GothamBold; btn.TextSize = 12
        btn.AutoButtonColor = false
        Helpers.corner(btn, 8)
        if Helpers.pressFX then Helpers.pressFX(btn) end

        btn.MouseButton1Click:Connect(function()
            if not State.selectedTargetId then
                _G.showDynamicNotification("⚠️ Pilih target dulu!", P.red)
                return
            end

            local nowOn = not getTrollState(actionOn)
            setTrollState(actionOn, nowOn)

            if nowOn then
                btn.Text = "ON"
                TweenService:Create(btn, TweenInfo.new(0.2), {BackgroundColor3 = P.green}):Play()
                sendCommand("troll_action", { action = actionOn })
            else
                btn.Text = "OFF"
                TweenService:Create(btn, TweenInfo.new(0.2), {BackgroundColor3 = color}):Play()
                sendCommand("troll_action", { action = actionOff })
            end
        end)

        return btn
    end

    addTrollToggle(trollFrame, "Jail", "Mengurung target di dalam kotak transparan.", "jail", "unjail", Color3.fromRGB(230, 126, 34))
    addTrollToggle(trollFrame, "Freeze", "Membekukan karakter target agar tidak bisa bergerak.", "freeze", "unfreeze", Color3.fromRGB(52, 152, 219))
    addTrollToggle(trollFrame, "Blind", "Membuat layar target menjadi gelap gulita.", "blind", "unblind", Color3.fromRGB(44, 62, 80))
    addTrollToggle(trollFrame, "Blur Vision", "Membuat pandangan target menjadi kabur dan pusing.", "blur", "unblur", Color3.fromRGB(142, 68, 173))
    addTrollToggle(trollFrame, "Fire Aura", "Membakar target dengan api visual.", "fire", "unfire", Color3.fromRGB(192, 57, 43))
    addTrollToggle(trollFrame, "Smoke Aura", "Menutupi target dengan asap tebal.", "smoke", "unsmoke", Color3.fromRGB(127, 140, 141))
    addTrollToggle(trollFrame, "Force Sit", "Memaksa target terus duduk.", "forcesit", "unforcesit", Color3.fromRGB(243, 156, 18))
    addTrollToggle(trollFrame, "Spin", "Memutar badan target seperti gasing.", "spin", "unspin", Color3.fromRGB(211, 84, 0))
    addTrollToggle(trollFrame, "Slow Walk", "Membuat kecepatan jalan target sangat lambat.", "slow", "unslow", Color3.fromRGB(52, 73, 94))
    addTrollToggle(trollFrame, "High Jump", "Memberikan efek lompatan super tinggi.", "highjump", "unhighjump", Color3.fromRGB(26, 188, 156))

    -- ===== 6 TOGGLE BARU dari 10 fitur =====
    addTrollToggle(trollFrame, "Rainbow Body", "Warna tubuh target berubah-ubah seperti pelangi.", "rainbow", "unrainbow", Color3.fromRGB(255, 100, 200))
    addTrollToggle(trollFrame, "Giant Size", "Membesarkan ukuran karakter target 3x.", "giant", "ungiant", Color3.fromRGB(90, 130, 255))
    addTrollToggle(trollFrame, "Tiny Size", "Mengecilkan ukuran karakter target.", "tiny", "untiny", Color3.fromRGB(255, 180, 60))
    addTrollToggle(trollFrame, "Invisible", "Membuat karakter target transparan/tak terlihat.", "invisible", "uninvisible", Color3.fromRGB(120, 120, 140))
    addTrollToggle(trollFrame, "Low Gravity", "Mengurangi gravitasi server (semua orang melayang).", "gravity_low", "gravity_normal", Color3.fromRGB(80, 200, 255))
    addTrollToggle(trollFrame, "Mute Sound", "Membisukan semua suara di layar target.", "deafen", "undeafen", Color3.fromRGB(160, 90, 200))

    -- ===== INSTANT TROLL ACTIONS =====
    local instantLbl = Instance.new("TextLabel", trollFrame)
    instantLbl.Size = UDim2.new(0.95, 0, 0, 26)
    instantLbl.BackgroundTransparency = 1
    instantLbl.Text = "⚡ INSTANT ACTION (SEKALI KLIK):"
    instantLbl.TextColor3 = P.accentGlow
    instantLbl.Font = Enum.Font.GothamBold
    instantLbl.TextSize = 11
    instantLbl.TextXAlignment = Enum.TextXAlignment.Left

    local instantGrid = Instance.new("Frame", trollFrame)
    instantGrid.Size = UDim2.new(0.95, 0, 0, 0)
    instantGrid.AutomaticSize = Enum.AutomaticSize.Y
    instantGrid.BackgroundTransparency = 1

    local gridLayout = Instance.new("UIGridLayout", instantGrid)
    gridLayout.CellSize = UDim2.new(0.48, 0, 0, 42)
    gridLayout.CellPadding = UDim2.new(0.04, 0, 0, 10)

    local function addInstantBtn(name, cmd, color, isTroll)
        local btn = Instance.new("TextButton", instantGrid)
        btn.BackgroundColor3 = color; btn.Text = name; btn.TextColor3 = Color3.new(1,1,1)
        btn.Font = Enum.Font.GothamBold; btn.TextSize = 11
        btn.AutoButtonColor = false
        Helpers.corner(btn, 9)
        if Helpers.pressFX then Helpers.pressFX(btn) end
        btn.MouseButton1Click:Connect(function()
            if isTroll then
                sendCommand("troll_action", { action = cmd })
            else
                sendCommand(cmd, {})
            end
        end)
    end

    addInstantBtn("Kill", "kill", Color3.fromRGB(231, 76, 60), true)
    addInstantBtn("Fling", "fling", Color3.fromRGB(155, 89, 182), true)
    addInstantBtn("Noclip", "noclip", Color3.fromRGB(149, 165, 166), true)
    addInstantBtn("Remove Limbs", "nolimbs", Color3.fromRGB(192, 57, 43), true)
    -- 2 fitur instant baru
    addInstantBtn("Earthquake", "earthquake", Color3.fromRGB(180, 140, 40), true)
    addInstantBtn("Ragdoll Bounce", "ragdoll_bounce", Color3.fromRGB(230, 90, 180), false)

    switchTab("Target")
end

print("[Premium] Mega Upgrade v2 loaded — persistent toggle, saved avatars, 10 new features!")
