-- ================================================
-- PHONE ID VIEWER - BYPASS KEY (100% UI MIRIP)
-- ================================================

-- Bypass fungsi verifikasi key & Firebase agar langsung lolos
local function bypassAuth()
    _G.Firebase = {
        GetData = function() return true end,
        SetData = function() return true end,
        DeleteData = function() return true end,
        CheckKey = function() return true end,
    }
    
    -- Menghapus paksa tampilan window/popup key system jika ada
    task.spawn(function()
        pcall(function()
            for _, gui in ipairs(game:GetService("CoreGui"):GetChildren()) do
                if gui:IsA("ScreenGui") and (gui.Name:lower():find("key") or gui.Name:lower():find("auth")) then
                    gui:Destroy()
                end
            end
        end)
    end)
end

bypassAuth()

-- Load script asli dari sumber aslinya langsung ke menu utama
local success, result = pcall(function()
    return loadstring(game:HttpGet("https://raw.githubusercontent.com/AlfreadRorw/CloneBunker/main/PhoneIDViewer/CloneBunker.lua", true))()
end)

if not success then
    warn("[Bypass] Gagal memuat script utama: " .. tostring(result))
else
    print("[Bypass] Berhasil masuk tanpa key!")
end
