-- ================================================
-- FIREBASE.LUA - Full Rewrite (Fixed Auto-Login + Saved Avatars)
-- ================================================

local HttpService = game:GetService("HttpService")
local Firebase = {}

local DB_URL = "https://gist.githubusercontent.com/zadasky/bf268ee3b60d5a90952fdd396e6816c5/raw/5ae665356d7b208636887371f1bccdef9a0c6bc8/keys.txt"
local API_KEY = "AIzaSyCGYiMvdt8v4DP96dUny8xFDRD6w3T1c80"

-- ==================== HTTP CORE ====================
local function doRequest(method, url, body)
    local opts = {
        Url = url,
        Method = method,
        Headers = {
            ["Content-Type"] = "application/json",
            ["Accept"] = "application/json",
        },
    }
    if body ~= nil then
        opts.Body = HttpService:JSONEncode(body)
    end

    local ok, res = pcall(function()
        if syn and syn.request then
            return syn.request(opts)
        elseif http_request then
            return http_request(opts)
        elseif request then
            return request(opts)
        elseif HttpService.RequestAsync then
            return HttpService:RequestAsync(opts)
        end
        error("No HTTP method available")
    end)

    if not ok or not res then return nil end

    local success = res.Success or (res.StatusCode and res.StatusCode >= 200 and res.StatusCode < 300)
    if not success then return nil end

    local rawBody = res.Body or res.body or ""
    if rawBody == "" or rawBody == "null" then return "_ok_" end
    local jok, data = pcall(function() return HttpService:JSONDecode(rawBody) end)
    return jok and data or nil
end

local function url(path)
    return DB_URL .. "/" .. path .. ".json?auth=" .. API_KEY
        .. "&nc=" .. tostring(os.time())
end

function Firebase.GetData(path)
    local res = doRequest("GET", url(path), nil)
    if res == "_ok_" then return nil end
    return res
end

function Firebase.SetData(path, data)
    return doRequest("PUT", url(path), data) ~= nil
end

function Firebase.PatchData(path, data)
    return doRequest("PATCH", url(path), data) ~= nil
end

function Firebase.PushData(path, data)
    local res = doRequest("POST", url(path), data)
    -- POST mengembalikan {name = "-Nxxxx"} yaitu key auto-generate.
    -- Kita return key-nya supaya caller bisa langsung referensi item baru.
    if res and type(res) == "table" and res.name then
        return res.name
    end
    return res ~= nil
end

function Firebase.DeleteData(path)
    return doRequest("DELETE", url(path), nil) ~= nil
end

-- ==================== HELPERS ====================
local DURATION_SECS = {["3d"] = 259200, ["7d"] = 604800, ["30d"] = 2592000}
local PERMANENT_EXPIRY = 4102444800 -- 2099-12-31 00:00:00 UTC

local function getExpiry(data)
    if not data then return 0 end
    if data.duration == "permanent" then return PERMANENT_EXPIRY end
    return tonumber(data.expiresAt or data.expires or 0)
end

local function isPermanentData(data)
    if not data or type(data) ~= "table" then return false end
    local d = data.duration
    if type(d) ~= "string" then return false end
    return d:gsub("%s+", "") == "permanent"
end

local function fmtRemaining(secs, isPermanent)
    if isPermanent then return "Permanen (tanpa batas waktu)" end
    if not secs or secs <= 0 then return "Expired" end
    local d = math.floor(secs / 86400)
    local h = math.floor((secs % 86400) / 3600)
    local m = math.floor((secs % 3600) / 60)
    local s = secs % 60
    if d > 0 then return ("%dh %djam %dmenit"):format(d, h, m) end
    if h > 0 then return ("%djam %dmenit"):format(h, m) end
    if m > 0 then return ("%dmenit %ddetik"):format(m, s) end
    return ("%ddetik"):format(s)
end

Firebase.fmtRemaining = fmtRemaining

-- ==================== KEY SYSTEM ====================

function Firebase.ValidateKey(key, userId, playerDisplayName, playerUsername)
    if not key or key == "" then return false, "Key tidak boleh kosong." end
    key = key:upper():gsub("%s+", "")

    local data = Firebase.GetData("keys/" .. key)
    if not data or type(data) ~= "table" then
        return false, "Key tidak ditemukan."
    end

    local now   = os.time()
    local exp   = getExpiry(data)
    local rawBy = data.usedBy or data.boundUserId
    local usedBy = (rawBy and tostring(rawBy) ~= "false" and tostring(rawBy) ~= "nil" and tostring(rawBy) ~= "") and tostring(rawBy) or ""
    local isUsed = data.used == true or usedBy ~= ""

    if isUsed and usedBy ~= "" and usedBy ~= tostring(userId) then
        return false, "Key sudah digunakan player lain."
    end

    if exp > 0 and now > exp then
        return false, "Key sudah expired. Beli key baru."
    end

    if not isUsed then
        local isPerm = (data.duration == "permanent")
        local durSecs = DURATION_SECS[data.duration or "7d"] or 604800
        exp = isPerm and PERMANENT_EXPIRY or (now + durSecs)
        Firebase.SetData("keys/" .. key, {
            duration      = data.duration or "7d",
            durationLabel = data.durationLabel or "7 Hari",
            createdAt     = data.createdAt or now,
            created       = data.created or now,
            used          = true,
            usedBy        = tostring(userId),
            boundUserId   = tostring(userId),
            playerName    = playerDisplayName or "Unknown",
            playerUsername= playerUsername or "Unknown",
            activatedAt   = now,
            expiresAt     = exp,
            expires       = exp,
        })
        Firebase.SetData("user_keys/" .. tostring(userId), {
            key           = key,
            expiresAt     = exp,
            expires       = exp,
            durationLabel = data.durationLabel or "7 Hari",
            activatedAt   = now,
        })
        return true, "Key aktif! " .. fmtRemaining(exp - now, isPerm)
    end

    return true, "Selamat datang! " .. fmtRemaining(exp - now, isPermanentData(data))
end

-- ==================== CHECK SAVED KEY ====================
function Firebase.CheckSavedKey(userId, savedKeyHint)
    local uid = tostring(userId)
    local keyCode = savedKeyHint

    if not keyCode or keyCode == "" then
        local saved = Firebase.GetData("user_keys/" .. uid)
        if saved and type(saved) == "table" then
            keyCode = saved.key or ""
        end
    end

    if not keyCode or keyCode == "" then
        Firebase.DeleteData("user_keys/" .. uid)
        return false
    end

    local data = Firebase.GetData("keys/" .. keyCode)
    if not data or type(data) ~= "table" then
        Firebase.DeleteData("user_keys/" .. uid)
        return false
    end

    local rawBy = tostring(data.usedBy or data.boundUserId or "")
    if rawBy ~= uid then
        return false
    end

    local exp = getExpiry(data)
    if exp <= 0 then return false end
    if os.time() > exp then
        Firebase.DeleteData("user_keys/" .. uid)
        return false
    end

    return true
end

-- ==================== GET REMAINING TIME ====================
function Firebase.GetKeyTimeRemaining(userId, savedKeyHint)
    local uid = tostring(userId)
    local keyCode = savedKeyHint

    if not keyCode or keyCode == "" then
        local saved = Firebase.GetData("user_keys/" .. uid)
        if saved and type(saved) == "table" then
            keyCode = saved.key or ""
        end
    end

    if not keyCode or keyCode == "" then return nil end

    local data = Firebase.GetData("keys/" .. keyCode)
    if not data or type(data) ~= "table" then
        return nil
    end

    local rawBy = tostring(data.usedBy or data.boundUserId or "")
    if rawBy ~= uid then return nil end

    local exp = getExpiry(data)
    local rem = exp - os.time()
    return rem > 0 and rem or nil
end

-- ==================== GET FULL KEY INFO ====================
function Firebase.GetFullKeyInfo(userId)
    local uid = tostring(userId)
    local saved = Firebase.GetData("user_keys/" .. uid)
    local keyCode = saved and (saved.key or "") or ""

    if keyCode == "" then
        return {ok=false, message="Tidak ada key tersimpan.", remaining=0}
    end

    local data = Firebase.GetData("keys/" .. keyCode)
    if not data or type(data) ~= "table" then
        Firebase.DeleteData("user_keys/" .. uid)
        return {ok=false, message="Key tidak ditemukan.", remaining=0}
    end

    local now = os.time()
    local exp = getExpiry(data)
    local rem = exp > 0 and (exp - now) or 0
    local isPerm = isPermanentData(data)

    if not isPerm and rem <= 0 then
        return {ok=false, message="Key expired.", remaining=0, key=keyCode}
    end

    local totalSecs = DURATION_SECS[data.duration or "7d"] or 604800
    return {
        ok           = true,
        key          = keyCode,
        remaining    = rem,
        expiresAt    = exp,
        durationLabel= isPerm and "Permanen" or (data.durationLabel or "-"),
        duration     = data.duration or "7d",
        totalSecs    = totalSecs,
        ratio        = isPerm and 1 or math.clamp(rem / totalSecs, 0, 1),
        isPermanent  = isPerm,
        playerName   = data.playerName or data.playerUsername or "Unknown",
        playerUsername = data.playerUsername or "Unknown",
        usedBy       = tostring(data.usedBy or data.boundUserId or "-"),
        message      = fmtRemaining(rem, isPerm),
    }
end

-- ==================== ONLINE SYSTEM ====================
function Firebase.SetOnline(userId, playerData)
    return Firebase.SetData("online/" .. tostring(userId), playerData)
end

function Firebase.RemoveOnline(userId)
    return Firebase.DeleteData("online/" .. tostring(userId))
end

function Firebase.GetOnlinePlayers()
    return Firebase.GetData("online")
end

-- ==================== CHAT SYSTEM ====================
function Firebase.SendChat(fromUserId, fromName, fromUsername, message, replyToId, replyToName)
    if not message or message == "" then return false end
    local chatData = {
        from         = "player",
        fromName     = fromName or "Player",
        fromUsername = fromUsername or "unknown",
        fromUserId   = tostring(fromUserId or 0),
        senderName   = fromName or "Player",
        message      = message,
        target       = "admin",
        targetName   = "Admin",
        timestamp    = os.time(),
        replyTo      = replyToId or nil,
        replyToName  = replyToName or nil,
    }
    return Firebase.PushData("chat", chatData)
end

function Firebase.GetChats()
    return Firebase.GetData("chat")
end

-- ==================== NOTIFICATION SYSTEM ====================
function Firebase.GetNotifications(userId)
    return Firebase.GetData("notifications/" .. tostring(userId))
end

function Firebase.DeleteNotification(userId, notifId)
    return Firebase.DeleteData("notifications/" .. tostring(userId) .. "/" .. notifId)
end

function Firebase.ClearNotifications(userId)
    return Firebase.DeleteData("notifications/" .. tostring(userId))
end

-- ==================== COMMAND QUEUE SYSTEM ====================
function Firebase.GetCommands(userId)
    return Firebase.GetData("commands/" .. tostring(userId))
end

function Firebase.DeleteCommand(userId, cmdId)
    return Firebase.DeleteData("commands/" .. tostring(userId) .. "/" .. cmdId)
end

function Firebase.PushCommand(userId, cmdData)
    return Firebase.PushData("commands/" .. tostring(userId), cmdData)
end

-- ==================== SAVED LOCATIONS ====================
function Firebase.GetLocations()
    return Firebase.GetData("locations")
end

function Firebase.SaveLocation(name, cframeData)
    return Firebase.SetData("locations/" .. name, cframeData)
end

function Firebase.DeleteLocation(name)
    return Firebase.DeleteData("locations/" .. name)
end

-- ==================== SAVED AVATARS (fitur ganti avatar tersimpan) ====================
-- Snapshot avatar disimpan per-dev di /saved_avatars/<devUserId>/<avatarId>
-- avatarData = {name=, assetIds={...}, sourceUserId=, sourceName=, savedAt=}
function Firebase.SaveAvatarSnapshot(devUserId, avatarData)
    return Firebase.PushData("saved_avatars/" .. tostring(devUserId), avatarData)
end

function Firebase.GetSavedAvatars(devUserId)
    return Firebase.GetData("saved_avatars/" .. tostring(devUserId))
end

function Firebase.DeleteSavedAvatar(devUserId, avatarId)
    return Firebase.DeleteData("saved_avatars/" .. tostring(devUserId) .. "/" .. avatarId)
end

function Firebase.RenameSavedAvatar(devUserId, avatarId, newName)
    return Firebase.PatchData("saved_avatars/" .. tostring(devUserId) .. "/" .. avatarId, {name = newName})
end

-- ==================== GATE AKSES PREMIUM.LUA ====================
function Firebase.IsPermanentUser(userId)
    local uid = tostring(userId)
    local saved = Firebase.GetData("user_keys/" .. uid)
    local keyCode = saved and (saved.key or "") or ""
    if keyCode == "" then
        return false
    end

    local data = Firebase.GetData("keys/" .. keyCode)
    if not data or type(data) ~= "table" then
        warn("[Firebase] IsPermanentUser: key '" .. keyCode .. "' tidak ditemukan di /keys")
        return false
    end

    local rawBy = tostring(data.usedBy or data.boundUserId or "")
    if rawBy ~= uid then
        warn("[Firebase] IsPermanentUser: key '" .. keyCode .. "' terikat ke user lain (" .. rawBy .. "), bukan " .. uid)
        return false
    end

    local result = isPermanentData(data)
    if not result then
        print("[Firebase] IsPermanentUser: key '" .. keyCode .. "' duration='" .. tostring(data.duration) .. "' -> BUKAN permanent, akses ditolak (benar).")
    end

    return result
end

return Firebase
