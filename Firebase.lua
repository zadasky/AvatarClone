-- ================================================
-- PHONE ID VIEWER - Modular Loader (BYPASS KEY)
-- ================================================

local BASE_URL = "https://raw.githubusercontent.com/zadasky/AvatarClone/refs/heads/patch-1/"

local function Load(path)
    local ok, result = pcall(function()
        return loadstring(game:HttpGet(BASE_URL .. path, true))()
    end)
    if not ok then
        warn("[PhoneIDViewer] Failed: " .. path .. " | " .. tostring(result))
    end
    return ok and result or nil
end

-- ==================== SERVICES ====================
local Services = {
    Players = game:GetService("Players"),
    TweenService = game:GetService("TweenService"),
    UserInputService = game:GetService("UserInputService"),
    HttpService = game:GetService("HttpService"),
    Workspace = game:GetService("Workspace"),
    RunService = game:GetService("RunService"),
    ReplicatedStorage = game:GetService("ReplicatedStorage"),
    SoundService = game:GetService("SoundService"),
    TeleportService = game:GetService("TeleportService"),
    CoreGui = game:GetService("CoreGui"),
    MarketplaceService = game:GetService("MarketplaceService"),
}
_G.Services = Services

local LocalPlayer = Services.Players.LocalPlayer
_G.LocalPlayer = LocalPlayer

-- ==================== LOAD CORE MODULES ====================
local Config = Load("Config.lua")
_G.Config = Config

local Theme = Load("Core/Theme.lua")
_G.T = Theme

local Helpers = Load("Core/Helpers.lua")
_G.Helpers = Helpers

-- ==================== LOADING NOTIFICATION ====================
Load("Core/LoadingNotif.lua")

-- ==================== LOAD MODULES WITH PROGRESS ====================
local totalSteps = 25
local currentStep = 0

local function updateProgress(stepName)
    currentStep = currentStep + 1
    if _G.updateLoadingProgress then
        _G.updateLoadingProgress(currentStep, totalSteps, stepName)
    end
end

-- Tampilkan loading notification
if _G.showLoadingNotification then
    _G.showLoadingNotification()
end

-- Load Storage
updateProgress("Storage")
local Storage = Load("Core/Storage.lua")
_G.Storage = Storage

-- Bypass Firebase (Dilewati agar tidak cek key)
updateProgress("Firebase (Bypassed)")
_G.Firebase = {
    GetData = function() return true end,
    SetData = function() return true end,
    DeleteData = function() return true end
}

-- Load Phone
updateProgress("Phone GUI")
local Phone = Load("Core/Phone.lua")
_G.Phone = Phone

-- Load Icons
updateProgress("Icons")
local Icons = Load("Core/Icons.lua")
_G.Icons = Icons

-- Load BuildIcons
updateProgress("Build Icons")
Load("Core/BuildIcons.lua")

Load("Core/CommandListener.lua")

-- ==================== LOAD APPLICATIONS ====================
local AppList = {
    {path = "Applications/Players.lua", name = "Players"},
    {path = "Applications/Clone.lua", name = "Clone"},
    {path = "Applications/Preset.lua", name = "Preset"},
    {path = "Applications/Favorites.lua", name = "Favorites"},
    {path = "Applications/Items.lua", name = "Items"},
    {path = "Applications/Teleport.lua", name = "Teleport"},
    {path = "Applications/Size.lua", name = "Size"},
    {path = "Applications/Volume.lua", name = "Volume"},
    {path = "Applications/Friends.lua", name = "Friends"},
    {path = "Applications/Server.lua", name = "Server"},
    {path = "Applications/Bundle.lua", name = "Bundle"},
    {path = "Applications/AvatarItems.lua", name = "AvatarItems"},
    {path = "Applications/WhoOnline.lua", name = "WhoOnline"},
    {path = "Applications/Messages.lua", name = "Messages"},
    {path = "Applications/Command.lua", name = "Command"},
    {path = "Applications/Settings.lua", name = "Settings"},
    {path = "Applications/Premium.lua", name = "Premium"},
    {path = "Applications/AlfreadAI.lua", name = "AlfreadAI"},
    {path = "Applications/Shader.lua", name = "Shader"},
    {path = "Applications/Games.lua", name = "Games"},
    {path = "Applications/Emote.lua", name = "Emote"},
}

for _, app in ipairs(AppList) do
    updateProgress(app.name)
    Load(app.path)
end

-- Load FloatingIcon
updateProgress("Floating Icon")
Load("Core/FloatingIcon.lua")

-- Selesai
if _G.finishLoading then
    _G.finishLoading()
end

print("[PhoneIDViewer] Successfully loaded without key!")
