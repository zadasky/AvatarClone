-- Bypass Key & Load Script
local success, err = pcall(function()
    loadstring(game:HttpGet("https://raw.githubusercontent.com/AlfreadRorw/AvatarClone/main/Loader.lua", true))()
end)

if not success then
    warn("Gagal load, error: " .. tostring(err))
end

-- Force Bypass Firebase
_G.Firebase = {
    GetData = function() return true end,
    SetData = function() return true end,
    DeleteData = function() return true end
}
