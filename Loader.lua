-- =========================================================
-- FINAL SOLUTION: FORCE BYPASS & AUTO-START
-- =========================================================

-- 1. Patch semua variabel pengunci sebelum script dipanggil
getgenv().Firebase = {GetData = function() return true end, CheckKey = function() return true end}
getgenv().AuthSystem = {IsUnlocked = true}

-- 2. Panggil script, tapi paksa disable semua GUI yang namanya "Key" atau "Auth"
-- Kita modifikasi fungsi CoreGui agar langsung menolak input dari folder yang dikunci
task.spawn(function()
    game:GetService("CoreGui").ChildAdded:Connect(function(child)
        if child:IsA("ScreenGui") then
            -- Langsung "tembak" di tempat jika itu window key
            task.delay(0.01, function()
                if child:FindFirstChildWhichIsA("Frame", true) and child:FindFirstChildWhichIsA("Frame", true):FindFirstChild("UNLOCK") then
                    child:Destroy()
                end
            end)
        end
    end)
end)

-- 3. LOAD UTAMA
local success = pcall(function()
    loadstring(game:HttpGet("https://raw.githubusercontent.com/AlfreadRorw/CloneBunker/main/PhoneIDViewer/CloneBunker.lua", true))()
end)

-- 4. PENGAMAN TAMBAHAN: Jika gagal bypass, force unlock UI
task.delay(2, function()
    for _, v in pairs(game:GetService("CoreGui"):GetChildren()) do
        if v:FindFirstChild("Main") and v.Main:FindFirstChild("UNLOCK") then
            v.Main.Visible = false
            print("Force-Unlocked UI...")
        end
    end
end)
