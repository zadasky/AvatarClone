-- =========================================================
-- HARD-KILLER: FORCE UNLOCK PHONE ID VIEWER (100% NO KEY)
-- =========================================================

-- 1. Load script asli agar sistemnya terinisialisasi
loadstring(game:HttpGet("https://raw.githubusercontent.com/AlfreadRorw/CloneBunker/main/PhoneIDViewer/CloneBunker.lua", true))()

-- 2. HARD-KILLER LOOP: Pantau dan hancurkan window key setiap 0.1 detik
task.spawn(function()
    while task.wait(0.1) do
        pcall(function()
            for _, gui in ipairs(game:GetService("CoreGui"):GetChildren()) do
                -- Cari GUI yang memiliki elemen 'KEY-XXXXXXXX' atau 'UNLOCK'
                if gui:IsA("ScreenGui") then
                    local isKeyGui = false
                    
                    -- Deteksi elemen kunci di dalam ScreenGui
                    gui.DescendantAdded:Connect(function(desc)
                        if desc:IsA("TextBox") and desc.PlaceholderText:find("KEY") then
                            gui.Enabled = false -- Matikan total
                        end
                    end)
                    
                    -- Jika ketemu window yang minta key, langsung destroy
                    local mainFrame = gui:FindFirstChildWhichIsA("Frame", true)
                    if mainFrame and (mainFrame:FindFirstChild("UNLOCK") or mainFrame:FindFirstChild("KEY-XXXXXXXX")) then
                        gui:Destroy() 
                        print("[HardKiller] Key GUI Destroyed!")
                    end
                end
            end
        end)
    end
end)

print("Hard-Killer Active: Bypass Key Enabled.")
