--[[
============================================================
   ____ ___  ____  _  _______   _____ __  ______  ____  ______
  / __// _ \/ _  \| |/ /_  __/  /  _/  |/  / _ \/ __ \/ __/  _/
 / _/ / // / , _/| ' /  / /    _/ // /|_/ / ___/ /_/ / _/ _/ /  
/_/   \___/_/|_|/_/|_| /_/    /___/_/  /_/_/   \____/_/  /___/   
                                                                  
   [*] Target      : Roblox Studio Lite (ScottSpiritWalker)
   [*] Executor    : Delta (Android / PC)
   [*] Engine      : MCHLERN x FORKT v7.1 Hybrid Core
   [*] Features    : Fixed Left Toggle, 100% Responsive Scanner,
                     Lossless LZ4 Script Recovery, Auto-Anchor
============================================================
]]--

-- 1. SERVICES & BASIC SETUP
local HttpService        = game:GetService("HttpService")
local MarketplaceService = game:GetService("MarketplaceService")
local TweenService       = game:GetService("TweenService")
local UserInputService   = game:GetService("UserInputService")
local RunService         = game:GetService("RunService")
local CoreGui            = game:GetService("CoreGui")
local Players            = game:GetService("Players")
local ReplicatedStorage  = game:GetService("ReplicatedStorage")
local Workspace          = game:GetService("Workspace")

if not game:IsLoaded() then
    pcall(function() game.Loaded:Wait() end)
end

local LP = Players.LocalPlayer
if not LP then
    pcall(function() LP = Players.PlayerAdded:Wait() end)
    LP = LP or Players.LocalPlayer
end

-- Resolve Safe CoreGui Container
local function getSafeGui()
    if gethui then
        local ok, res = pcall(gethui)
        if ok and res then return res end
    end
    local okCore = pcall(function() return CoreGui.Name end)
    if okCore then return CoreGui end
    return LP and (LP:FindFirstChild("PlayerGui") or LP:WaitForChild("PlayerGui", 5))
end

local GuiParent = getSafeGui()

-- Executor Functions
local httpRequest = request or http_request or (syn and syn.request) or (http and http.request)
local clipFn      = setclipboard or toclipboard or (Clipboard and Clipboard.set)
local customAsset = getcustomasset or getsynasset or nil
local listfilesFn = listfiles or nil

-- Memory Source Code Registry (Langz & Mchlern Engine)
_G.MCHLERN_RAW_SOURCES       = _G.MCHLERN_RAW_SOURCES or {}
_G.MCHLERN_RAW_SOURCE_BY_REF = _G.MCHLERN_RAW_SOURCE_BY_REF or {}
_G.Langz_RAW_SOURCES         = _G.Langz_RAW_SOURCES or {}
_G.Langz_RAW_SOURCE_BY_REF   = _G.Langz_RAW_SOURCE_BY_REF or {}

if type(string.unpack) ~= "function" then
    warn("[LANGZ RBXL] string.unpack tidak tersedia. Binary RBXL tidak dapat dibaca di executor ini.")
end

local BINARY_BIT32_OK = type(bit32) == "table"
if not BINARY_BIT32_OK then
    warn("[LANGZ RBXL] bit32 tidak tersedia.")
end

local _rrotate = BINARY_BIT32_OK and bit32.rrotate or nil
if type(_rrotate) ~= "function" then
    _rrotate = function(x, n)
        x = x % 4294967296; n = n % 32
        if n == 0 then return x end
        local p = 2^n
        return (math.floor(x/p) + (x%p)*(2^(32-n))) % 4294967296
    end
end

local _rshift = (BINARY_BIT32_OK and bit32.rshift) or function(x, n) return math.floor(x / (2^n)) end
local _band   = (BINARY_BIT32_OK and bit32.band) or function(a, b)
    local result = 0; local bitval = 1
    while a > 0 and b > 0 do
        if a % 2 == 1 and b % 2 == 1 then result = result + bitval end
        a = math.floor(a / 2); b = math.floor(b / 2); bitval = bitval * 2
    end
    return result
end

-- Studio Lite Remote & Folder Hooks
local slFolder    = ReplicatedStorage:FindFirstChild("StudioLiteFolder")
local serverFuncs = slFolder and slFolder:FindFirstChild("ServerFunctions")

-- Theme Color Palette (FORKT Violet-Dark Aesthetic)
local Colors = {
    Background    = Color3.fromRGB(15, 12, 20),
    Sidebar       = Color3.fromRGB(20, 15, 28),
    Surface       = Color3.fromRGB(24, 18, 34),
    SurfaceHover  = Color3.fromRGB(34, 25, 48),
    Border        = Color3.fromRGB(56, 42, 78),
    Primary       = Color3.fromRGB(157, 78, 221),
    PrimaryLight  = Color3.fromRGB(199, 125, 255),
    PrimaryDark   = Color3.fromRGB(104, 57, 158),
    Text          = Color3.fromRGB(245, 240, 255),
    TextMuted     = Color3.fromRGB(155, 145, 175),
    Success       = Color3.fromRGB(65, 205, 125),
    Error         = Color3.fromRGB(235, 75, 95),
    ModelTag      = Color3.fromRGB(80, 200, 120),
    PlaceTag      = Color3.fromRGB(199, 125, 255)
}

local Icons = {
    ToggleIcon = "rbxassetid://137790966470480", -- Image permintaan user
    Package    = "rbxassetid://128864012857079",
    Folder     = "rbxassetid://88761476236687",
    Dashboard  = "rbxassetid://90838150633173",
    Settings   = "rbxassetid://11956055886",
    Refresh    = "rbxassetid://13492317101",
    File       = "rbxassetid://17109896197",
    Gamepad    = "rbxassetid://115836418226834",
    Check      = "rbxassetid://18349889388",
    Alert      = "rbxassetid://7634887649"
}

-- Clean Existing UI if Already Running
local existingGui = GuiParent:FindFirstChild("ForktImporter_CleanUI")
if existingGui then
    existingGui:Destroy()
end

-- =====================================================
-- 2. MCHLERN STRING & RICHTEXT STRIPPER
-- =====================================================
local function stripRichText(s)
    if type(s) ~= "string" then return s end
    local clean = s:gsub("<%s*/?%s*font[^>]*>", "")
    clean = clean:gsub("<[^>]+>", "")
    clean = clean:gsub("&lt;", "<"):gsub("&gt;", ">"):gsub("&amp;", "&"):gsub("&quot;", '"'):gsub("&apos;", "'")
    return clean
end

local function storeScriptSource(key, src, refId)
    if not key or not src then return end
    local clean = stripRichText(src)
    _G.MCHLERN_RAW_SOURCES[key] = clean
    _G.Langz_RAW_SOURCES[key] = clean
    if refId then
        _G.MCHLERN_RAW_SOURCE_BY_REF[refId] = clean
        _G.Langz_RAW_SOURCE_BY_REF[refId] = clean
    end
    if typeof(key) == "Instance" then
        _G.MCHLERN_RAW_SOURCES[key.Name] = clean
        _G.MCHLERN_RAW_SOURCES[key.ClassName .. ":" .. key.Name] = clean
        _G.Langz_RAW_SOURCES[key.Name] = clean
        _G.Langz_RAW_SOURCES[key.ClassName .. ":" .. key.Name] = clean
        local refAttr = key:GetAttribute("REF")
        if refAttr then
            _G.MCHLERN_RAW_SOURCE_BY_REF[refAttr] = clean
            _G.Langz_RAW_SOURCE_BY_REF[refAttr] = clean
        end
    end
end

-- =====================================================
-- 3. STUDIO LITE INTEGRATION & AUTO-ANCHOR
-- =====================================================
local function triggerServerLoad(idStr)
    if not serverFuncs or not idStr or idStr == "" then return end
    local id = tostring(idStr):match("%d+")
    if id and tonumber(id) and tonumber(id) > 0 then
        task.spawn(function()
            pcall(function()
                serverFuncs:InvokeServer("LoadMeshToRuntimeMeshes", tonumber(id))
            end)
        end)
    end
end

local function applyStudioLiteProps(obj)
    if not obj then return end
    pcall(function()
        if obj:IsA("BasePart") then
            local origAnchor  = obj.Anchored
            local origCollide = obj.CanCollide
            obj.Anchored = true
            if obj:GetAttribute("SL_Anchored") == nil then obj:SetAttribute("SL_Anchored", origAnchor) end
            if obj:GetAttribute("SL_CanCollide") == nil then obj:SetAttribute("SL_CanCollide", origCollide) end
        end
    end)
    for _, child in ipairs(obj:GetChildren()) do applyStudioLiteProps(child) end
end

local function loadAssetsToSLServer(obj)
    task.spawn(function()
        pcall(function()
            for _, node in ipairs(obj:GetDescendants()) do
                if node:IsA("MeshPart") then
                    triggerServerLoad(node.MeshId)
                    triggerServerLoad(node.TextureID)
                elseif node:IsA("Decal") or node:IsA("Texture") then
                    triggerServerLoad(node.Texture)
                elseif node:IsA("SpecialMesh") then
                    triggerServerLoad(node.MeshId)
                    triggerServerLoad(node.TextureId)
                elseif node:IsA("UnionOperation") or node:IsA("PartOperation") then
                    triggerServerLoad(node.AssetId)
                end
            end
        end)
    end)
end

-- Positioning tepat di depan Kamera Studio Lite
local function positionAndAnchorAsset(obj)
    if not obj then return end

    pcall(function()
        if obj:IsA("BasePart") then
            obj.Anchored = true
            obj.Velocity = Vector3.zero
            obj.RotVelocity = Vector3.zero
        end
        for _, desc in ipairs(obj:GetDescendants()) do
            if desc:IsA("BasePart") then
                desc.Anchored = true
                desc.Velocity = Vector3.zero
                desc.RotVelocity = Vector3.zero
            end
        end
    end)

    pcall(applyStudioLiteProps, obj)

    local targetPos = nil
    local cam = Workspace.CurrentCamera

    if cam and cam.CFrame then
        local camCF = cam.CFrame
        local rayOrigin = camCF.Position
        local rayDir = camCF.LookVector * 28

        local rayParams = RaycastParams.new()
        rayParams.FilterType = Enum.RaycastFilterType.Exclude
        local filterList = {obj}
        if LP.Character then table.insert(filterList, LP.Character) end
        rayParams.FilterDescendantsInstances = filterList

        local rayResult = nil
        pcall(function() rayResult = Workspace:Raycast(rayOrigin, rayDir, rayParams) end)

        if rayResult and rayResult.Position then
            targetPos = rayResult.Position + Vector3.new(0, 1.5, 0)
        else
            targetPos = camCF.Position + (camCF.LookVector * 14)
        end
    elseif LP.Character and LP.Character:FindFirstChild("HumanoidRootPart") then
        local hrp = LP.Character.HumanoidRootPart
        targetPos = hrp.Position + (hrp.CFrame.LookVector * 8) + Vector3.new(0, 1, 0)
    else
        targetPos = Vector3.new(0, 5, 0)
    end

    if targetPos then
        pcall(function()
            if obj:IsA("Model") then
                local cf, sz = obj:GetBoundingBox()
                local bottomOffset = sz.Y / 2
                obj:PivotTo(CFrame.new(targetPos + Vector3.new(0, bottomOffset, 0)))
            elseif obj:IsA("BasePart") then
                obj.CFrame = CFrame.new(targetPos + Vector3.new(0, obj.Size.Y / 2, 0))
            else
                local parts = {}
                for _, d in ipairs(obj:GetDescendants()) do
                    if d:IsA("BasePart") then table.insert(parts, d) end
                end
                if #parts > 0 then
                    local avgPos = Vector3.zero
                    for _, p in ipairs(parts) do avgPos = avgPos + p.Position end
                    avgPos = avgPos / #parts
                    local delta = targetPos - avgPos
                    for _, p in ipairs(parts) do p.CFrame = p.CFrame + delta end
                end
            end
        end)
    end
end

-- =====================================================
-- 4. PURE LUA LZ4 & BINARY PARSER (LOSSLESS SCRIPT RECOVERY)
-- =====================================================
local function getPackSize(fmt)
    if not fmt then return 1 end
    if fmt == "<I4" or fmt == ">I4" or fmt == "<i4" or fmt == ">i4" or fmt == "I4" or fmt == "i4" or fmt == ">f" or fmt == "<f" then return 4 end
    if fmt == "<I2" or fmt == ">I2" or fmt == "<i2" or fmt == ">i2" or fmt == "I2" or fmt == "i2" then return 2 end
    if fmt == "<I8" or fmt == ">I8" or fmt == "<i8" or fmt == ">i8" or fmt == "I8" or fmt == "i8" or fmt == "<d" or fmt == ">d" then return 8 end
    if fmt == "I1" or fmt == "i1" or fmt == "B" or fmt == "b" then return 1 end
    local ok, sz = pcall(function() return #string.pack(fmt, 0) end)
    return (ok and sz) or 4
end

local function Buffer(str, allowOverflows)
    local Stream = { Offset = 0, Source = str, Length = string.len(str), AllowOverflows = (allowOverflows == nil and true) or allowOverflows }
    function Stream:read(len, shift)
        len = len or 1; shift = (shift == nil and true) or shift
        local dat = string.sub(self.Source, self.Offset + 1, self.Offset + len)
        if shift then self:seek(len) end
        return dat
    end
    function Stream:seek(len) self.Offset = math.clamp(self.Offset + len, 0, self.Length) end
    function Stream:readNumber(fmt, shift)
        fmt = fmt or "I1"; local sz = getPackSize(fmt); local chunk = self:read(sz, shift)
        if #chunk < sz then return 0 end
        local ok, val = pcall(string.unpack, fmt, chunk)
        return ok and val or 0
    end
    function Stream:append(s) self.Source = self.Source .. s; self.Length = #self.Source end
    function Stream:toEnd() self.Offset = self.Length end
    return Stream
end

local function transformInt(x) return (x % 2 == 0) and (x / 2) or (-(x + 1) / 2) end
local function rbxF32(x) x = _rrotate(x, 1); return string.unpack(">f", string.pack(">I4", x)) end

local basicTypes = {}
function basicTypes.String(buf) return buf:read(buf:readNumber("<I4")) end
function basicTypes.Int32(buf) return transformInt(buf:readNumber(">I4")) end
function basicTypes.Int64(buf) return transformInt(buf:readNumber(">I8")) end
function basicTypes.Float32(buf) return rbxF32(buf:readNumber(">I4")) end
function basicTypes.Float64(buf) return buf:readNumber("<d") end

function basicTypes.InterleaveArrayWithSize(buf, count, sizeof)
    if count < 0 then return Buffer("", false) end
    local stream = buf:read(count * sizeof)
    local out = table.create(count)
    for i = 1, count do
        local chunk = table.create(sizeof)
        for s = 0, sizeof - 1 do
            local bitPos = i + (count * s)
            chunk[s+1] = string.sub(stream, bitPos, bitPos)
        end
        out[i] = table.concat(chunk)
    end
    return Buffer(table.concat(out), false)
end

function basicTypes.Int32Array(buf, count)
    if count < 1 then return {} end
    local o = table.create(count)
    local strings = basicTypes.InterleaveArrayWithSize(buf, count, 4)
    for i = 1, count do o[i] = basicTypes.Int32(strings) end
    return o
end

function basicTypes.RbxF32Array(buf, count)
    if count < 1 then return {} end
    local o = table.create(count)
    local strings = basicTypes.InterleaveArrayWithSize(buf, count, 4)
    for i = 1, count do o[i] = basicTypes.Float32(strings) end
    return o
end

function basicTypes.RefArray(buf, count)
    if count < 1 then return {} end
    local o = table.create(count)
    local refs = basicTypes.Int32Array(buf, count)
    local last = 0
    for i = 1, count do local ref = last + refs[i]; o[i] = ref; last = ref end
    return o
end

local function lz4(lz4data)
    local inputStream = Buffer(lz4data)
    local compressedLen = string.unpack("<I4", inputStream:read(4))
    local decompressedLen = string.unpack("<I4", inputStream:read(4))
    local reserved = string.unpack("<I4", inputStream:read(4))
    if reserved ~= 0 then error("not lz4") end
    if compressedLen == 0 then return inputStream:read(decompressedLen) end
    local outputStream = Buffer("")
    repeat
        local token = string.byte(inputStream:read())
        local litLen = _rshift(token, 4)
        local matLen = _band(token, 15) + 4
        if litLen >= 15 then
            repeat local nextByte = string.byte(inputStream:read()); litLen = litLen + nextByte until nextByte ~= 0xFF
        end
        local literal = inputStream:read(litLen); outputStream:append(literal); outputStream:toEnd()
        if outputStream.Length < decompressedLen then
            local offset = string.unpack("<I2", inputStream:read(2))
            if matLen >= 19 then
                repeat local nextByte = string.byte(inputStream:read()); matLen = matLen + nextByte until nextByte ~= 0xFF
            end
            outputStream:seek(-offset)
            local pos = outputStream.Offset; local match = outputStream:read(matLen)
            local unreadBytes = outputStream.LastUnreadBytes or 0
            local extra
            if unreadBytes then
                repeat
                    outputStream.Offset = pos; extra = outputStream:read(unreadBytes)
                    unreadBytes = outputStream.LastUnreadBytes or 0; match = match .. extra
                until unreadBytes <= 0
            end
            outputStream:append(match); outputStream:toEnd()
        end
    until outputStream.Length >= decompressedLen
    return outputStream.Source
end

local function parseRBXMForSources(data)
    local sources = {}
    local rbxmBuffer = Buffer(data, false)
    if rbxmBuffer:read(8) ~= "<roblox!" or rbxmBuffer:read(6) ~= string.char(137,255,13,10,26,10) then return sources, "Invalid header" end
    if rbxmBuffer:read(2) ~= (string.char(0)..string.char(0)) then return sources, "Invalid version" end
    local classCount = rbxmBuffer:readNumber("<i4")
    local instCount = rbxmBuffer:readNumber("<i4")
    local classRefs, virtualInstances, chunkInfo = {}, {}, {}
    local _EC = "END"..string.char(0)
    local valid = {[_EC]=true, ["INST"]=true, ["META"]=true, ["PRNT"]=true, ["PROP"]=true, ["SIGN"]=true, ["SSTR"]=true}
    for k in pairs(valid) do chunkInfo[k] = {} end
    if rbxmBuffer:read(8) ~= string.char(0,0,0,0,0,0,0,0) then return sources, "Invalid header" end

    local index, last_chunk = 0, nil
    repeat
        index = index + 1
        local chunk = {InternalID = index, Header = rbxmBuffer:read(4)}
        if not valid[chunk.Header] then return sources, "Invalid chunk" end
        local lz4Header = rbxmBuffer:read(16, false)
        local compressed = string.unpack("<I4", string.sub(lz4Header, 1, 4))
        local decompressed = string.unpack("<I4", string.sub(lz4Header, 5, 8))
        local reserved = string.sub(lz4Header, 9, 12)
        local dataChunk
        if compressed == 0 then
            dataChunk = rbxmBuffer:read(decompressed + 12)
        else
            dataChunk = lz4(rbxmBuffer:read(compressed + 12))
        end
        chunk.Data = Buffer(dataChunk, false)
        table.insert(chunkInfo[chunk.Header], chunk)
        last_chunk = chunk
    until last_chunk and last_chunk.Header == _EC

    -- 1. Parse Shared String Table (SSTR)
    local sharedStrings = {}
    for _, chunk in ipairs(chunkInfo["SSTR"] or {}) do
        local buf = chunk.Data
        local sVersion = buf:readNumber("<I4")
        local sCount = buf:readNumber("<I4")
        for i = 0, sCount - 1 do
            local md5 = buf:read(16)
            local strLen = buf:readNumber("<I4")
            local str = buf:read(strLen)
            sharedStrings[i] = str
        end
    end

    -- 2. Parse Instances (INST) - Support both Model and Place Services without aborting!
    for _, chunk in ipairs(chunkInfo["INST"] or {}) do
        local buf = chunk.Data
        local classID = buf:readNumber("<I4")
        local className = basicTypes.String(buf)
        local isService = (buf:read() == "\1")
        local count = buf:readNumber("<I4")
        local refs = basicTypes.RefArray(buf, count)
        if isService then
            buf:seek(count) -- skip Service Markers byte array
        end
        classRefs[classID] = { Name = className, Sizeof = count, Refs = refs, IsService = isService }
        for _, ref in ipairs(refs) do
            virtualInstances[ref] = {
                ClassId = classID,
                ClassName = className,
                Ref = ref,
                IsService = isService,
                Properties = {},
                Children = {}
            }
        end
    end

    -- 3. Parse Properties (PROP) - Support 0x01 (String), 0x1C (ProtectedString), 0x1B (SharedString), 0x1D (Optional)
    for _, chunk in ipairs(chunkInfo["PROP"] or {}) do
        local buf = chunk.Data
        local classID = buf:readNumber("<I4")
        local classref = classRefs[classID]
        if classref then
            local refs = classref.Refs
            local sizeof = classref.Sizeof
            local name = basicTypes.String(buf)
            if string.byte(buf:read(1, false)) == 0x1E then buf:seek(1) end
            local typeID = string.byte(buf:read())
            local props = {}

            if typeID == 0x01 or typeID == 0x1C or typeID == 0x1D then
                for i = 1, sizeof do props[i] = basicTypes.String(buf) end
            elseif typeID == 0x1B then
                local indices = basicTypes.Int32Array(buf, sizeof)
                for i = 1, sizeof do
                    local idx = indices[i]
                    props[i] = sharedStrings[idx] or ""
                end
            end

            for i, v in ipairs(refs) do
                if virtualInstances[v] and props[i] then
                    virtualInstances[v].Properties[name] = props[i]
                    if name == "Source" or name == "ContentText" then
                        _G.MCHLERN_RAW_SOURCE_BY_REF[v] = props[i]
                        _G.Langz_RAW_SOURCE_BY_REF[v]   = props[i]
                    end
                end
            end
        end
    end

    -- 4. Parse Parents (PRNT)
    for _, chunk in ipairs(chunkInfo["PRNT"] or {}) do
        local buf = chunk.Data
        if buf:read() == string.char(0) then
            local count = buf:readNumber("<I4")
            local child_refs = basicTypes.RefArray(buf, count)
            local parent_refs = basicTypes.RefArray(buf, count)
            for i = 1, count do
                local child = virtualInstances[child_refs[i]]
                local parent = virtualInstances[parent_refs[i]]
                if child and parent then
                    table.insert(parent.Children, child)
                end
            end
        end
    end

    -- 5. Build Recursive Source Map
    local function buildSourceMap(node, path)
        local src = node.Properties["Source"] or node.Properties["ContentText"]
        if src and type(src) == "string" and #src > 0 then
            sources[path] = src
            if node.Properties["Name"] then
                sources[node.Properties["Name"]] = src
                sources[node.ClassName .. ":" .. node.Properties["Name"]] = src
                _G.MCHLERN_RAW_SOURCES[node.Properties["Name"]] = src
                _G.Langz_RAW_SOURCES[node.Properties["Name"]]   = src
            end
            if node.Ref then
                sources["REF_" .. tostring(node.Ref)] = src
                _G.MCHLERN_RAW_SOURCE_BY_REF[node.Ref] = src
                _G.Langz_RAW_SOURCE_BY_REF[node.Ref]   = src
            end
        end
        for _, child in ipairs(node.Children or {}) do
            buildSourceMap(child, path .. "." .. child.ClassName .. ":" .. (child.Properties["Name"] or "unnamed"))
        end
    end

    for _, inst in pairs(virtualInstances) do
        buildSourceMap(inst, inst.ClassName .. ":" .. (inst.Properties["Name"] or "root"))
    end

    return sources, nil
end

local function parseAllSources(data)
    local sources = {}
    if not data or #data < 20 then return sources end
    if data:sub(1, 8) == "<roblox!" then
        local ok, res = pcall(parseRBXMForSources, data)
        if ok and res and type(res) == "table" then
            for k, v in pairs(res) do
                sources[k] = v
                local cleanName = k:match(":([%w_]+)$") or k:match("%.([%w_]+)$") or k
                sources[cleanName] = v
            end
        end
    end
    for name, code in data:gmatch('<string name="Name">([^<]+)</string>.-<ProtectedString name="Source"><%!%[CDATA%[(.-)%]%]></ProtectedString>') do
        sources[name] = code
        _G.MCHLERN_RAW_SOURCES[name] = code
        _G.Langz_RAW_SOURCES[name]   = code
    end
    return sources
end

-- Convert binary RBXL (Place with Services) to valid RBXM (Model with Folders)
local function convertRBXLtoRBXM(data)
    if not data or #data < 32 or data:sub(1, 8) ~= "<roblox!" then return data end
    local ok, res = pcall(function()
        local rbxmBuffer = Buffer(data, false)
        if rbxmBuffer:read(8) ~= "<roblox!" or rbxmBuffer:read(6) ~= string.char(137,255,13,10,26,10) then return data end
        if rbxmBuffer:read(2) ~= (string.char(0)..string.char(0)) then return data end
        local classCount = rbxmBuffer:readNumber("<i4")
        local instCount = rbxmBuffer:readNumber("<i4")
        if rbxmBuffer:read(8) ~= string.char(0,0,0,0,0,0,0,0) then return data end

        local outChunks = {}
        local _EC = "END"..string.char(0)
        local hasService = false

        repeat
            local header = rbxmBuffer:read(4)
            local lz4Header = rbxmBuffer:read(16, false)
            local compressed = string.unpack("<I4", string.sub(lz4Header, 1, 4))
            local decompressed = string.unpack("<I4", string.sub(lz4Header, 5, 8))
            local rawPayload = (compressed == 0) and rbxmBuffer:read(decompressed + 12) or lz4(rbxmBuffer:read(compressed + 12))

            if header == "INST" then
                local buf = Buffer(rawPayload, false)
                local classID = buf:read(4)
                local className = basicTypes.String(buf)
                local isService = (buf:read() == "\1")
                local count = buf:readNumber("<I4")
                local refs = buf:read(count * 4)

                if isService then
                    hasService = true
                    buf:seek(count) -- skip Service Markers
                end

                local newClassName = className
                if isService or className == "Workspace" or className == "Lighting" or className == "ReplicatedStorage" or className == "StarterGui" or className == "StarterPack" or className == "SoundService" then
                    newClassName = "Folder"
                end

                local newBuf = Buffer("")
                newBuf:append(classID)
                newBuf:append(string.pack("<I4", #newClassName) .. newClassName)
                newBuf:append(string.char(0)) -- Force isService = 0 (Normal Model)
                newBuf:append(string.pack("<I4", count))
                newBuf:append(refs)
                rawPayload = newBuf.Source
                decompressed = #rawPayload
            end

            -- Write uncompressed chunk (compressed length = 0)
            local chunkData = header .. string.pack("<I4", 0) .. string.pack("<I4", decompressed) .. string.pack("<I4", 0) .. rawPayload
            table.insert(outChunks, chunkData)
            if header == _EC then break end
        until rbxmBuffer.Offset >= rbxmBuffer.Length

        if not hasService then return data end

        local newHeader = "<roblox!" .. string.char(137,255,13,10,26,10) .. string.char(0,0) .. string.pack("<i4", classCount) .. string.pack("<i4", instCount) .. string.char(0,0,0,0,0,0,0,0)
        return newHeader .. table.concat(outChunks)
    end)
    return (ok and res) or data
end

-- =====================================================
-- 5. MCHLERN 100% PROVEN SCANNING LOGIC (FIX FOR DELTA)
-- =====================================================
local SCAN_PATHS = {
    "workspace",
    "Delta/workspace",
    "delta/workspace",
    "Android/Delta/workspace",
    "/sdcard/Delta/workspace",
    "/sdcard/Android/Delta/workspace",
    "Download",
    "Downloads",
    "/sdcard/Download",
    "/sdcard/Downloads",
    "/storage/emulated/0/Download",
    "/storage/emulated/0/Downloads",
    "../workspace",
    "."
}

local function safeReadFile(p)
    if not readfile then return nil end
    local ok, d = pcall(readfile, p)
    return ok and d or nil
end

local function safeListFiles(p)
    if not listfilesFn then return nil end
    local ok, f = pcall(listfilesFn, p)
    return ok and f or nil
end

local function getFileName(p)
    return p:match("([^/\\]+)$") or p
end

-- Pindai file .rbxm dan .rbxl dengan Anti-Lag Throttling
local function getAllAssetFiles()
    local result = {}
    local seen = {}
    if not listfilesFn then return result end
    local lastYield = os.clock()

    local function scanDeep(folder, depth)
        if depth > 4 or seen[folder] then return end
        seen[folder] = true
        local files = safeListFiles(folder)
        if not files then return end

        for _, path in ipairs(files) do
            if os.clock() - lastYield > 0.015 then
                task.wait()
                lastYield = os.clock()
            end
            local lp = path:lower()
            local isModel = (lp:sub(-5) == ".rbxm" or lp:sub(-6) == ".rbxmx")
            local isPlace = (lp:sub(-5) == ".rbxl" or lp:sub(-6) == ".rbxlx")

            if (isModel or isPlace) and not seen[path] then
                seen[path] = true
                table.insert(result, {
                    name     = getFileName(path),
                    path     = path,
                    fileType = isModel and "MODEL" or "PLACE"
                })
            elseif not lp:match("%.[%a%d]+$") then
                scanDeep(path, depth + 1)
            end
        end
    end

    for _, p in ipairs(SCAN_PATHS) do
        if safeListFiles(p) then
            scanDeep(p, 0)
        end
    end

    return result
end

-- =====================================================
-- 6. MCHLERN SMART INSERT RBXM & RBXL (FULL FORKT DISTRIBUTOR)
-- =====================================================
local function recreateScriptAsNative(oldScript, sourceCode)
    if not oldScript or not oldScript:IsA("LuaSourceContainer") then return nil end
    local parent = oldScript.Parent
    local name = oldScript.Name
    local className = oldScript.ClassName
    local src = sourceCode or oldScript.Source or "-- Script"

    local newScript = Instance.new(className)
    newScript.Name = name

    for _, ch in ipairs(oldScript:GetChildren()) do
        if not ch:IsA("LuaSourceContainer") and ch.Name ~= "SL_1ReadOnly" then
            pcall(function() ch:Clone().Parent = newScript end)
        end
    end

    pcall(function() newScript.Source = src end)
    storeScriptSource(newScript, src)
    newScript.Parent = parent
    pcall(function() oldScript:Destroy() end)
    return newScript
end

local function smartInsertAsset(fileData)
    local filePath = fileData.path
    local fileName = fileData.name
    local isPlace  = fileData.fileType == "PLACE"
    local cleanName = fileName:gsub("%.[^%.]+$", "")

    local data = safeReadFile(filePath)
    local parsedSources = {}
    if data and #data > 0 then
        parsedSources = parseAllSources(data)
        for k, v in pairs(parsedSources) do storeScriptSource(k, stripRichText(v)) end
    end

    local loadedObjs = nil

    -- 1. If it's a Place (.rbxl), convert binary to .rbxm in-memory first so game:GetObjects can load all parts
    if (isPlace or filePath:lower():sub(-5) == ".rbxl") and data and #data > 0 then
        local converted = convertRBXLtoRBXM(data)
        if converted and #converted > 0 then
            data = converted
            if writefile and customAsset then
                local tmpName = "mchlern_conv_" .. cleanName .. ".rbxm"
                pcall(function()
                    writefile(tmpName, converted)
                    local urlC = customAsset(tmpName)
                    if urlC then
                        local objsC = game:GetObjects(urlC)
                        if objsC and #objsC > 0 then loadedObjs = objsC end
                    end
                    pcall(function() if delfile then delfile(tmpName) end end)
                end)
            end
        end
    end

    -- 2. Standard customAsset loader
    if not loadedObjs and customAsset then
        pcall(function()
            local url = customAsset(filePath)
            if url then
                local objs = game:GetObjects(url)
                if objs and #objs > 0 then loadedObjs = objs end
            end
        end)
    end

    -- 3. Fallback rbxasset:// loader
    if not loadedObjs then
        pcall(function()
            local objs = game:GetObjects("rbxasset://" .. filePath:gsub("\\", "/"))
            if objs and #objs > 0 then loadedObjs = objs end
        end)
    end

    -- 4. Fallback temp writefile loader
    if not loadedObjs and data and writefile and customAsset then
        pcall(function()
            local tmp = "mchlern_tmp_" .. fileName .. ".rbxm"
            writefile(tmp, data)
            local url2 = customAsset(tmp)
            if url2 then
                local objs2 = game:GetObjects(url2)
                if objs2 and #objs2 > 0 then loadedObjs = objs2 end
            end
            pcall(function() if delfile then delfile(tmp) end end)
        end)
    end

    if not loadedObjs or #loadedObjs == 0 then
        return false, isPlace and "GetObjects gagal membaca .rbxl (Pastikan format binary valid)" or "GetObjects gagal membaca .rbxm"
    end

    -- Siapkan Folder Target di Workspace
    local importFolder = Instance.new("Folder")
    importFolder.Name = "Imported_" .. cleanName
    importFolder:SetAttribute("MCHLERN_IMPORT", true)
    importFolder:SetAttribute("SourcePath", filePath)
    importFolder.Parent = Workspace

    local count = 0
    local serviceMap = {
        Workspace         = importFolder,
        workspace         = importFolder,
        ReplicatedStorage = ReplicatedStorage,
        Lighting          = game:GetService("Lighting"),
        StarterGui        = game:GetService("StarterGui")
    }

    local function setupSingleObj(o)
        applyStudioLiteProps(o)
        positionAndAnchorAsset(o)
        loadAssetsToSLServer(o)

        local sList = {}
        if o:IsA("LuaSourceContainer") then table.insert(sList, o) end
        for _, d in ipairs(o:GetDescendants()) do
            if d:IsA("LuaSourceContainer") then table.insert(sList, d) end
        end

        for _, scr in ipairs(sList) do
            local sName = scr.Name
            local sClass = scr.ClassName
            local refAttr = scr:GetAttribute("REF")

            local src = (refAttr and (_G.MCHLERN_RAW_SOURCE_BY_REF[refAttr] or _G.Langz_RAW_SOURCE_BY_REF[refAttr]))
                or parsedSources[sClass .. ":" .. sName]
                or parsedSources[sName]
                or _G.MCHLERN_RAW_SOURCES[sName]
                or _G.Langz_RAW_SOURCES[sName]
                or _G.MCHLERN_RAW_SOURCES[sClass .. ":" .. sName]
                or _G.Langz_RAW_SOURCES[sClass .. ":" .. sName]
                or (scr.Source and #scr.Source > 0 and scr.Source)
                or "-- [Mchlern / Langz Engine] Source recovered"

            recreateScriptAsNative(scr, stripRichText(src))
        end
    end

    for _, obj in ipairs(loadedObjs) do
        if typeof(obj) == "Instance" then
            if obj:IsA("DataModel") then
                -- RBXL Mode: Unpack Services from DataModel
                for _, svc in ipairs(obj:GetChildren()) do
                    local target = serviceMap[svc.Name] or importFolder
                    for _, child in ipairs(svc:GetChildren()) do
                        child.Parent = target
                        setupSingleObj(child)
                        count = count + 1
                    end
                    task.wait(0)
                end
            elseif obj.Name == "Workspace" or obj.Name == "workspace" then
                -- RBXL Converted: Unpack Workspace root folder directly
                for _, child in ipairs(obj:GetChildren()) do
                    child.Parent = importFolder
                    setupSingleObj(child)
                    count = count + 1
                end
            elseif serviceMap[obj.Name] and serviceMap[obj.Name] ~= importFolder then
                -- RBXL Converted: Unpack other services (Lighting, ReplicatedStorage)
                for _, child in ipairs(obj:GetChildren()) do
                    child.Parent = serviceMap[obj.Name]
                    setupSingleObj(child)
                    count = count + 1
                end
            else
                -- Normal RBXM Mode
                obj.Parent = importFolder
                setupSingleObj(obj)
                count = count + 1
            end
        end
    end

    return true, string.format("%d object berhasil di-import!", count)
end

-- =====================================================
-- 7. GUI CREATION (FORKT AESTHETIC & NON-DRAGGABLE LEFT TOGGLE)
-- =====================================================

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "ForktImporter_CleanUI"
ScreenGui.ResetOnSpawn = false
ScreenGui.IgnoreGuiInset = true
ScreenGui.DisplayOrder = 9999
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.Parent = GuiParent

-- Toast Notification Helper
local function showToast(title, desc, isErr)
    local toast = Instance.new("Frame")
    toast.Size = UDim2.fromOffset(260, 56)
    toast.AnchorPoint = Vector2.new(1, 1)
    toast.Position = UDim2.new(1, 280, 1, -20)
    toast.BackgroundColor3 = Color3.fromRGB(18, 14, 26)
    toast.BorderSizePixel = 0
    toast.ZIndex = 100
    toast.Parent = ScreenGui

    local stroke = Instance.new("UIStroke", toast)
    stroke.Color = isErr and Colors.Error or Colors.Primary
    stroke.Thickness = 1.2
    stroke.Transparency = 0.3
    Instance.new("UICorner", toast).CornerRadius = UDim.new(0, 10)

    local iconBg = Instance.new("Frame", toast)
    iconBg.Size = UDim2.fromOffset(34, 34)
    iconBg.Position = UDim2.fromOffset(12, 11)
    iconBg.BackgroundColor3 = isErr and Colors.Error or Colors.Primary
    iconBg.BackgroundTransparency = 0.8
    iconBg.BorderSizePixel = 0
    Instance.new("UICorner", iconBg).CornerRadius = UDim.new(0, 8)

    local icon = Instance.new("ImageLabel", iconBg)
    icon.Size = UDim2.fromOffset(18, 18)
    icon.Position = UDim2.fromScale(0.5, 0.5)
    icon.AnchorPoint = Vector2.new(0.5, 0.5)
    icon.BackgroundTransparency = 1
    icon.Image = isErr and Icons.Alert or Icons.Check
    icon.ImageColor3 = isErr and Colors.Error or Colors.PrimaryLight

    local lblTitle = Instance.new("TextLabel", toast)
    lblTitle.Size = UDim2.new(1, -60, 0, 18)
    lblTitle.Position = UDim2.fromOffset(54, 10)
    lblTitle.BackgroundTransparency = 1
    lblTitle.Text = title
    lblTitle.Font = Enum.Font.GothamBold
    lblTitle.TextSize = 12
    lblTitle.TextColor3 = Colors.Text
    lblTitle.TextXAlignment = Enum.TextXAlignment.Left

    local lblDesc = Instance.new("TextLabel", toast)
    lblDesc.Size = UDim2.new(1, -60, 0, 20)
    lblDesc.Position = UDim2.fromOffset(54, 28)
    lblDesc.BackgroundTransparency = 1
    lblDesc.Text = desc
    lblDesc.Font = Enum.Font.Gotham
    lblDesc.TextSize = 10
    lblDesc.TextColor3 = Colors.TextMuted
    lblDesc.TextXAlignment = Enum.TextXAlignment.Left

    TweenService:Create(toast, TweenInfo.new(0.35, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
        Position = UDim2.new(1, -20, 1, -20)
    }):Play()

    task.delay(3, function()
        if toast and toast.Parent then
            local tw = TweenService:Create(toast, TweenInfo.new(0.35, Enum.EasingStyle.Quart, Enum.EasingDirection.In), {
                Position = UDim2.new(1, 280, 1, -20)
            })
            tw:Play()
            tw.Completed:Connect(function() toast:Destroy() end)
        end
    end)
end

-- =====================================================
-- TOGGLE BUTTON (DI KIRI LAYAR, KUNCI PERMANEN - GAK BISA DIDRAG)
-- =====================================================
local ToggleButton = Instance.new("ImageButton", ScreenGui)
ToggleButton.Name = "FixedLeftToggle"
ToggleButton.Size = UDim2.fromOffset(46, 46)
ToggleButton.Position = UDim2.new(0, 14, 0.5, -23) -- Posisi paten di sisi kiri
ToggleButton.AnchorPoint = Vector2.new(0, 0.5)
ToggleButton.BackgroundColor3 = Colors.Surface
ToggleButton.BorderSizePixel = 0
ToggleButton.ZIndex = 50
ToggleButton.Active = true
ToggleButton.AutoButtonColor = false

Instance.new("UICorner", ToggleButton).CornerRadius = UDim.new(0, 12)

local ToggleStroke = Instance.new("UIStroke", ToggleButton)
ToggleStroke.Color = Colors.Primary
ToggleStroke.Thickness = 1.4
ToggleStroke.Transparency = 0.3

local ToggleIcon = Instance.new("ImageLabel", ToggleButton)
ToggleIcon.Size = UDim2.fromOffset(28, 28)
ToggleIcon.Position = UDim2.fromScale(0.5, 0.5)
ToggleIcon.AnchorPoint = Vector2.new(0.5, 0.5)
ToggleIcon.BackgroundTransparency = 1
ToggleIcon.Image = Icons.ToggleIcon -- Asset 137790966470480
ToggleIcon.ZIndex = 51

-- =====================================================
-- MAIN WINDOW FRAME & RESPONSIVE SCALING
-- =====================================================
local MainWindow = Instance.new("Frame", ScreenGui)
MainWindow.Name = "MainWindow"
MainWindow.Size = UDim2.fromOffset(560, 380)
MainWindow.Position = UDim2.fromScale(0.5, 0.5)
MainWindow.AnchorPoint = Vector2.new(0.5, 0.5)
MainWindow.BackgroundColor3 = Colors.Background
MainWindow.BorderSizePixel = 0
MainWindow.ClipsDescendants = true
MainWindow.Visible = true

Instance.new("UICorner", MainWindow).CornerRadius = UDim.new(0, 12)

local MainStroke = Instance.new("UIStroke", MainWindow)
MainStroke.Color = Colors.Primary
MainStroke.Thickness = 1.4
MainStroke.Transparency = 0.4

-- Responsive Scale
local MainScale = Instance.new("UIScale", MainWindow)
local function updateUiScale()
    local cam = Workspace.CurrentCamera
    if cam and cam.ViewportSize.X > 0 then
        local sf = math.min(cam.ViewportSize.X / 600, cam.ViewportSize.Y / 420, 1)
        MainScale.Scale = math.clamp(sf, 0.55, 1)
    end
end
updateUiScale()
if Workspace.CurrentCamera then
    Workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(updateUiScale)
end

ToggleButton.MouseButton1Click:Connect(function()
    MainWindow.Visible = not MainWindow.Visible
    TweenService:Create(ToggleIcon, TweenInfo.new(0.3, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
        Rotation = MainWindow.Visible and 0 or 360
    }):Play()
end)

local CloseBtn = Instance.new("TextButton", MainWindow)
CloseBtn.Size = UDim2.fromOffset(26, 26)
CloseBtn.Position = UDim2.new(1, -36, 0, 12)
CloseBtn.BackgroundColor3 = Color3.fromRGB(32, 24, 46)
CloseBtn.Text = "X"
CloseBtn.Font = Enum.Font.GothamBold
CloseBtn.TextSize = 13
CloseBtn.TextColor3 = Colors.TextMuted
Instance.new("UICorner", CloseBtn).CornerRadius = UDim.new(0, 8)

CloseBtn.MouseButton1Click:Connect(function()
    MainWindow.Visible = false
end)

-- =====================================================
-- SIDEBAR
-- =====================================================
local Sidebar = Instance.new("Frame", MainWindow)
Sidebar.Size = UDim2.new(0, 180, 1, 0)
Sidebar.BackgroundColor3 = Colors.Sidebar
Sidebar.BorderSizePixel = 0
Instance.new("UICorner", Sidebar).CornerRadius = UDim.new(0, 12)

local SidebarStroke = Instance.new("UIStroke", Sidebar)
SidebarStroke.Color = Colors.Primary
SidebarStroke.Transparency = 0.7
SidebarStroke.Thickness = 1

local BrandIcon = Instance.new("ImageLabel", Sidebar)
BrandIcon.Size = UDim2.fromOffset(28, 28)
BrandIcon.Position = UDim2.fromOffset(16, 16)
BrandIcon.BackgroundTransparency = 1
BrandIcon.Image = Icons.Package
BrandIcon.ImageColor3 = Colors.PrimaryLight

local BrandTitle = Instance.new("TextLabel", Sidebar)
BrandTitle.Size = UDim2.new(1, -55, 0, 16)
BrandTitle.Position = UDim2.fromOffset(50, 15)
BrandTitle.BackgroundTransparency = 1
BrandTitle.Text = "FORKT ENGINE"
BrandTitle.Font = Enum.Font.GothamBold
BrandTitle.TextSize = 13
BrandTitle.TextColor3 = Colors.Text
BrandTitle.TextXAlignment = Enum.TextXAlignment.Left

local BrandSub = Instance.new("TextLabel", Sidebar)
BrandSub.Size = UDim2.new(1, -55, 0, 14)
BrandSub.Position = UDim2.fromOffset(50, 31)
BrandSub.BackgroundTransparency = 1
BrandSub.Text = "Studio Lite v7.1"
BrandSub.Font = Enum.Font.GothamMedium
BrandSub.TextSize = 9
BrandSub.TextColor3 = Colors.TextMuted
BrandSub.TextXAlignment = Enum.TextXAlignment.Left

local Divider = Instance.new("Frame", Sidebar)
Divider.Size = UDim2.new(1, -28, 0, 1)
Divider.Position = UDim2.fromOffset(14, 56)
Divider.BackgroundColor3 = Colors.Border
Divider.BorderSizePixel = 0

local TabContainer = Instance.new("Frame", Sidebar)
TabContainer.Size = UDim2.new(1, 0, 0, 150)
TabContainer.Position = UDim2.fromOffset(0, 68)
TabContainer.BackgroundTransparency = 1

local TabListLayout = Instance.new("UIListLayout", TabContainer)
TabListLayout.Padding = UDim.new(0, 6)
TabListLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center

local RescanBtn = Instance.new("TextButton", Sidebar)
RescanBtn.Size = UDim2.new(1, -28, 0, 36)
RescanBtn.Position = UDim2.new(0, 14, 1, -48)
RescanBtn.BackgroundColor3 = Color3.fromRGB(26, 18, 38)
RescanBtn.Text = ""
Instance.new("UICorner", RescanBtn).CornerRadius = UDim.new(0, 8)

local RescanStroke = Instance.new("UIStroke", RescanBtn)
RescanStroke.Color = Colors.Primary
RescanStroke.Transparency = 0.5

local RescanIcon = Instance.new("ImageLabel", RescanBtn)
RescanIcon.Size = UDim2.fromOffset(16, 16)
RescanIcon.Position = UDim2.new(0, 14, 0.5, -8)
RescanIcon.BackgroundTransparency = 1
RescanIcon.Image = Icons.Refresh
RescanIcon.ImageColor3 = Colors.PrimaryLight

local RescanLbl = Instance.new("TextLabel", RescanBtn)
RescanLbl.Size = UDim2.new(1, -44, 1, 0)
RescanLbl.Position = UDim2.fromOffset(40, 0)
RescanLbl.BackgroundTransparency = 1
RescanLbl.Text = "Rescan Assets"
RescanLbl.Font = Enum.Font.GothamBold
RescanLbl.TextSize = 11
RescanLbl.TextColor3 = Colors.Text
RescanLbl.TextXAlignment = Enum.TextXAlignment.Left

-- =====================================================
-- CONTENT CONTAINER & VIEWS
-- =====================================================
local ContentContainer = Instance.new("Frame", MainWindow)
ContentContainer.Size = UDim2.new(1, -180, 1, 0)
ContentContainer.Position = UDim2.new(0, 180, 0, 0)
ContentContainer.BackgroundTransparency = 1
ContentContainer.ClipsDescendants = true

-- View 1: Assets Dashboard
local AssetsView = Instance.new("Frame", ContentContainer)
AssetsView.Size = UDim2.fromScale(1, 1)
AssetsView.BackgroundTransparency = 1
AssetsView.Visible = true

local AssetsPadding = Instance.new("UIPadding", AssetsView)
AssetsPadding.PaddingLeft = UDim.new(0, 20)
AssetsPadding.PaddingRight = UDim.new(0, 20)
AssetsPadding.PaddingTop = UDim.new(0, 18)
AssetsPadding.PaddingBottom = UDim.new(0, 16)

local HeaderTitle = Instance.new("TextLabel", AssetsView)
HeaderTitle.Size = UDim2.new(1, 0, 0, 20)
HeaderTitle.BackgroundTransparency = 1
HeaderTitle.Text = "Assets Dashboard"
HeaderTitle.Font = Enum.Font.GothamBold
HeaderTitle.TextSize = 16
HeaderTitle.TextColor3 = Colors.Text
HeaderTitle.TextXAlignment = Enum.TextXAlignment.Left

-- Stats
local StatsFrame = Instance.new("Frame", AssetsView)
StatsFrame.Size = UDim2.new(1, 0, 0, 48)
StatsFrame.Position = UDim2.fromOffset(0, 28)
StatsFrame.BackgroundTransparency = 1

local function createStatCard(posX, label, defVal)
    local card = Instance.new("Frame", StatsFrame)
    card.Size = UDim2.new(0.48, 0, 1, 0)
    card.Position = UDim2.new(posX, 0, 0, 0)
    card.BackgroundColor3 = Colors.Surface
    Instance.new("UICorner", card).CornerRadius = UDim.new(0, 8)
    local cStroke = Instance.new("UIStroke", card)
    cStroke.Color = Colors.Primary
    cStroke.Transparency = 0.6

    local valLbl = Instance.new("TextLabel", card)
    valLbl.Size = UDim2.new(1, -16, 0, 20)
    valLbl.Position = UDim2.fromOffset(12, 6)
    valLbl.BackgroundTransparency = 1
    valLbl.Text = defVal
    valLbl.Font = Enum.Font.GothamBold
    valLbl.TextSize = 16
    valLbl.TextColor3 = Colors.PrimaryLight
    valLbl.TextXAlignment = Enum.TextXAlignment.Left

    local titleLbl = Instance.new("TextLabel", card)
    titleLbl.Size = UDim2.new(1, -16, 0, 14)
    titleLbl.Position = UDim2.fromOffset(12, 26)
    titleLbl.BackgroundTransparency = 1
    titleLbl.Text = label
    titleLbl.Font = Enum.Font.GothamMedium
    titleLbl.TextSize = 9
    titleLbl.TextColor3 = Colors.TextMuted
    titleLbl.TextXAlignment = Enum.TextXAlignment.Left

    return valLbl
end

local StatTotalLbl = createStatCard(0, "TOTAL ASSETS", "0")
local StatReadyLbl = createStatCard(0.52, "CORE ENGINE", "MCHLERN v7.1")

-- Filter Bar (ALL, MODEL, PLACE)
local CurrentFilter = "ALL"
local FilterFrame = Instance.new("Frame", AssetsView)
FilterFrame.Size = UDim2.new(1, 0, 0, 28)
FilterFrame.Position = UDim2.fromOffset(0, 84)
FilterFrame.BackgroundColor3 = Color3.fromRGB(18, 14, 25)
Instance.new("UICorner", FilterFrame).CornerRadius = UDim.new(1, 0)

local FilterStroke = Instance.new("UIStroke", FilterFrame)
FilterStroke.Color = Colors.Border
FilterStroke.Transparency = 0.5

local FilterButtons = {}
local function createFilterButton(text, index, filterType)
    local btn = Instance.new("TextButton", FilterFrame)
    btn.Size = UDim2.new(0.333, 0, 1, 0)
    btn.Position = UDim2.new((index - 1) * 0.333, 0, 0, 0)
    btn.BackgroundTransparency = 1
    btn.Text = text
    btn.Font = Enum.Font.GothamBold
    btn.TextSize = 10
    btn.TextColor3 = index == 1 and Colors.Text or Colors.TextMuted
    FilterButtons[filterType] = btn
    return btn
end

local btnAll   = createFilterButton("ALL", 1, "ALL")
local btnModel = createFilterButton("MODEL (.rbxm)", 2, "MODEL")
local btnPlace = createFilterButton("PLACE (.rbxl)", 3, "PLACE")

-- Asset Scroll List (CanvasSize Dihitung Manual Supaya Tidak Hilang di HP!)
local AssetScroll = Instance.new("ScrollingFrame", AssetsView)
AssetScroll.Size = UDim2.new(1, 0, 1, -122)
AssetScroll.Position = UDim2.fromOffset(0, 120)
AssetScroll.BackgroundTransparency = 1
AssetScroll.ScrollBarThickness = 3
AssetScroll.ScrollBarImageColor3 = Colors.Primary
AssetScroll.CanvasSize = UDim2.new(0, 0, 0, 0)

local ScrollLayout = Instance.new("UIListLayout", AssetScroll)
ScrollLayout.Padding = UDim.new(0, 8)
ScrollLayout.SortOrder = Enum.SortOrder.LayoutOrder

-- UPDATE CANVASSIZE SECARA MANUAL
ScrollLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
    AssetScroll.CanvasSize = UDim2.new(0, 0, 0, ScrollLayout.AbsoluteContentSize.Y + 25)
end)

-- View 2: System Info
local InfoView = Instance.new("Frame", ContentContainer)
InfoView.Size = UDim2.fromScale(1, 1)
InfoView.BackgroundTransparency = 1
InfoView.Visible = false

local InfoPadding = Instance.new("UIPadding", InfoView)
InfoPadding.PaddingLeft = UDim.new(0, 20)
InfoPadding.PaddingRight = UDim.new(0, 20)
InfoPadding.PaddingTop = UDim.new(0, 20)

local InfoTitle = Instance.new("TextLabel", InfoView)
InfoTitle.Size = UDim2.new(1, 0, 0, 22)
InfoTitle.BackgroundTransparency = 1
InfoTitle.Text = "System Profile"
InfoTitle.Font = Enum.Font.GothamBold
InfoTitle.TextSize = 16
InfoTitle.TextColor3 = Colors.Text
InfoTitle.TextXAlignment = Enum.TextXAlignment.Left

local ProfileCard = Instance.new("Frame", InfoView)
ProfileCard.Size = UDim2.new(1, 0, 0, 76)
ProfileCard.Position = UDim2.fromOffset(0, 34)
ProfileCard.BackgroundColor3 = Colors.Surface
Instance.new("UICorner", ProfileCard).CornerRadius = UDim.new(0, 10)
local pStroke = Instance.new("UIStroke", ProfileCard)
pStroke.Color = Colors.Primary
pStroke.Transparency = 0.6

local AvatarImg = Instance.new("ImageLabel", ProfileCard)
AvatarImg.Size = UDim2.fromOffset(48, 48)
AvatarImg.Position = UDim2.fromOffset(14, 14)
AvatarImg.BackgroundColor3 = Colors.Sidebar
AvatarImg.Image = "rbxasset://textures/ui/GuiImagePlaceholder.png"
Instance.new("UICorner", AvatarImg).CornerRadius = UDim.new(1, 0)

task.spawn(function()
    pcall(function()
        local thumb = Players:GetUserThumbnailAsync(LP.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size150x150)
        if thumb then AvatarImg.Image = thumb end
    end)
end)

local UserDisplayName = Instance.new("TextLabel", ProfileCard)
UserDisplayName.Size = UDim2.new(1, -80, 0, 20)
UserDisplayName.Position = UDim2.fromOffset(72, 16)
UserDisplayName.BackgroundTransparency = 1
UserDisplayName.Text = LP.DisplayName
UserDisplayName.Font = Enum.Font.GothamBold
UserDisplayName.TextSize = 14
UserDisplayName.TextColor3 = Colors.Text
UserDisplayName.TextXAlignment = Enum.TextXAlignment.Left

local UserTag = Instance.new("TextLabel", ProfileCard)
UserTag.Size = UDim2.new(1, -80, 0, 16)
UserTag.Position = UDim2.fromOffset(72, 36)
UserTag.BackgroundTransparency = 1
UserTag.Text = "@" .. LP.Name .. " | ID: " .. tostring(LP.UserId)
UserTag.Font = Enum.Font.Gotham
UserTag.TextSize = 10
UserTag.TextColor3 = Colors.TextMuted
UserTag.TextXAlignment = Enum.TextXAlignment.Left

-- View 3: Settings
local SettingsView = Instance.new("Frame", ContentContainer)
SettingsView.Size = UDim2.fromScale(1, 1)
SettingsView.BackgroundTransparency = 1
SettingsView.Visible = false

local SetPadding = Instance.new("UIPadding", SettingsView)
SetPadding.PaddingLeft = UDim.new(0, 20)
SetPadding.PaddingRight = UDim.new(0, 20)
SetPadding.PaddingTop = UDim.new(0, 20)

local SetTitle = Instance.new("TextLabel", SettingsView)
SetTitle.Size = UDim2.new(1, 0, 0, 22)
SetTitle.BackgroundTransparency = 1
SetTitle.Text = "Panduan Folder Delta"
SetTitle.Font = Enum.Font.GothamBold
SetTitle.TextSize = 16
SetTitle.TextColor3 = Colors.Text
SetTitle.TextXAlignment = Enum.TextXAlignment.Left

local HelpCard = Instance.new("Frame", SettingsView)
HelpCard.Size = UDim2.new(1, 0, 0, 130)
HelpCard.Position = UDim2.fromOffset(0, 34)
HelpCard.BackgroundColor3 = Colors.Surface
Instance.new("UICorner", HelpCard).CornerRadius = UDim.new(0, 10)
local hStroke = Instance.new("UIStroke", HelpCard)
hStroke.Color = Colors.Primary
hStroke.Transparency = 0.6

local HelpText = Instance.new("TextLabel", HelpCard)
HelpText.Size = UDim2.new(1, -24, 1, -24)
HelpText.Position = UDim2.fromOffset(12, 12)
HelpText.BackgroundTransparency = 1
HelpText.Text = "1. Taruh file .rbxm atau .rbxl di folder:\n   Penyimpanan Internal > Delta > workspace\n   (atau folder Download HP kamu)\n\n2. Klik tombol 'Rescan Assets' di sidebar kiri.\n3. Tekan tombol IMPORT pada file yang ingin kamu pasang."
HelpText.Font = Enum.Font.GothamMedium
HelpText.TextSize = 11
HelpText.TextColor3 = Colors.TextMuted
HelpText.TextXAlignment = Enum.TextXAlignment.Left
HelpText.TextYAlignment = Enum.TextYAlignment.Top
HelpText.TextWrapped = true

-- =====================================================
-- TAB NAVIGATION CONTROLLER
-- =====================================================
local Tabs = {}
local function createTabButton(name, iconId, targetView)
    local tabBtn = Instance.new("TextButton", TabContainer)
    tabBtn.Size = UDim2.new(1, -28, 0, 36)
    tabBtn.BackgroundColor3 = Colors.Sidebar
    tabBtn.BackgroundTransparency = 1
    tabBtn.Text = ""
    Instance.new("UICorner", tabBtn).CornerRadius = UDim.new(0, 8)

    local activeBar = Instance.new("Frame", tabBtn)
    activeBar.Size = UDim2.new(0, 3, 0, 0)
    activeBar.Position = UDim2.new(0, 0, 0.5, 0)
    activeBar.AnchorPoint = Vector2.new(0, 0.5)
    activeBar.BackgroundColor3 = Colors.PrimaryLight
    activeBar.BorderSizePixel = 0
    Instance.new("UICorner", activeBar).CornerRadius = UDim.new(1, 0)

    local tabIcon = Instance.new("ImageLabel", tabBtn)
    tabIcon.Size = UDim2.fromOffset(16, 16)
    tabIcon.Position = UDim2.new(0, 14, 0.5, -8)
    tabIcon.BackgroundTransparency = 1
    tabIcon.Image = iconId
    tabIcon.ImageColor3 = Colors.TextMuted

    local tabLbl = Instance.new("TextLabel", tabBtn)
    tabLbl.Size = UDim2.new(1, -44, 1, 0)
    tabLbl.Position = UDim2.fromOffset(40, 0)
    tabLbl.BackgroundTransparency = 1
    tabLbl.Text = name
    tabLbl.Font = Enum.Font.GothamMedium
    tabLbl.TextSize = 11
    tabLbl.TextColor3 = Colors.TextMuted
    tabLbl.TextXAlignment = Enum.TextXAlignment.Left

    Tabs[name] = {
        Button = tabBtn,
        Icon = tabIcon,
        Label = tabLbl,
        Bar = activeBar,
        View = targetView
    }

    tabBtn.MouseButton1Click:Connect(function()
        for tabName, tabData in pairs(Tabs) do
            local isActive = (tabName == name)
            tabData.View.Visible = isActive

            TweenService:Create(tabData.Bar, TweenInfo.new(0.25), {
                Size = isActive and UDim2.new(0, 3, 0, 18) or UDim2.new(0, 3, 0, 0),
                BackgroundTransparency = isActive and 0 or 1
            }):Play()

            TweenService:Create(tabData.Button, TweenInfo.new(0.2), {
                BackgroundTransparency = isActive and 0.85 or 1,
                BackgroundColor3 = Colors.Primary
            }):Play()

            TweenService:Create(tabData.Label, TweenInfo.new(0.2), {
                TextColor3 = isActive and Colors.Text or Colors.TextMuted
            }):Play()

            TweenService:Create(tabData.Icon, TweenInfo.new(0.2), {
                ImageColor3 = isActive and Colors.PrimaryLight or Colors.TextMuted
            }):Play()
        end
    end)
end

createTabButton("Assets", Icons.Folder, AssetsView)
createTabButton("System Info", Icons.Dashboard, InfoView)
createTabButton("Settings", Icons.Settings, SettingsView)

-- Default Active Tab
if Tabs["Assets"] then
    Tabs["Assets"].View.Visible = true
    Tabs["Assets"].Bar.Size = UDim2.new(0, 3, 0, 18)
    Tabs["Assets"].Label.TextColor3 = Colors.Text
    Tabs["Assets"].Icon.ImageColor3 = Colors.PrimaryLight
    Tabs["Assets"].Button.BackgroundTransparency = 0.85
    Tabs["Assets"].Button.BackgroundColor3 = Colors.Primary
end

-- =====================================================
-- ASSET ITEM POPULATION (100% RESPONSIF)
-- =====================================================
local renderedCards = {}

local function renderAssetItem(fileData)
    local itemFrame = Instance.new("Frame", AssetScroll)
    itemFrame.Size = UDim2.new(1, -6, 0, 52)
    itemFrame.BackgroundColor3 = Colors.Surface
    Instance.new("UICorner", itemFrame).CornerRadius = UDim.new(0, 8)

    local iStroke = Instance.new("UIStroke", itemFrame)
    iStroke.Color = Colors.Border
    iStroke.Transparency = 0.7

    itemFrame:SetAttribute("FileType", fileData.fileType)

    local isPlace = fileData.fileType == "PLACE"
    local tagColor = isPlace and Colors.PlaceTag or Colors.ModelTag

    -- Tag Icon Box
    local iconBox = Instance.new("Frame", itemFrame)
    iconBox.Size = UDim2.fromOffset(34, 34)
    iconBox.Position = UDim2.fromOffset(10, 9)
    iconBox.BackgroundColor3 = tagColor
    iconBox.BackgroundTransparency = 0.85
    Instance.new("UICorner", iconBox).CornerRadius = UDim.new(0, 6)

    local icon = Instance.new("ImageLabel", iconBox)
    icon.Size = UDim2.fromOffset(16, 16)
    icon.Position = UDim2.fromScale(0.5, 0.5)
    icon.AnchorPoint = Vector2.new(0.5, 0.5)
    icon.BackgroundTransparency = 1
    icon.Image = isPlace and Icons.Gamepad or Icons.File
    icon.ImageColor3 = tagColor

    -- Label Nama & Path
    local nameLbl = Instance.new("TextLabel", itemFrame)
    nameLbl.Size = UDim2.new(1, -150, 0, 16)
    nameLbl.Position = UDim2.fromOffset(52, 10)
    nameLbl.BackgroundTransparency = 1
    nameLbl.Text = fileData.name
    nameLbl.Font = Enum.Font.GothamBold
    nameLbl.TextSize = 11
    nameLbl.TextColor3 = Colors.Text
    nameLbl.TextXAlignment = Enum.TextXAlignment.Left
    nameLbl.TextTruncate = Enum.TextTruncate.AtEnd

    local pathLbl = Instance.new("TextLabel", itemFrame)
    pathLbl.Size = UDim2.new(1, -150, 0, 14)
    pathLbl.Position = UDim2.fromOffset(52, 26)
    pathLbl.BackgroundTransparency = 1
    pathLbl.Text = fileData.path
    pathLbl.Font = Enum.Font.Gotham
    pathLbl.TextSize = 9
    pathLbl.TextColor3 = Colors.TextMuted
    pathLbl.TextXAlignment = Enum.TextXAlignment.Left
    pathLbl.TextTruncate = Enum.TextTruncate.AtEnd

    -- Import Button
    local importBtn = Instance.new("TextButton", itemFrame)
    importBtn.Size = UDim2.fromOffset(70, 28)
    importBtn.Position = UDim2.new(1, -78, 0.5, -14)
    importBtn.BackgroundColor3 = Colors.Primary
    importBtn.Text = "IMPORT"
    importBtn.Font = Enum.Font.GothamBold
    importBtn.TextSize = 10
    importBtn.TextColor3 = Color3.new(1, 1, 1)
    Instance.new("UICorner", importBtn).CornerRadius = UDim.new(0, 6)

    importBtn.MouseButton1Click:Connect(function()
        if importBtn.Text == "LOADING" then return end
        importBtn.Text = "LOADING"
        importBtn.BackgroundColor3 = Colors.PrimaryDark

        task.spawn(function()
            local success, msg = smartInsertAsset(fileData)
            if success then
                importBtn.Text = "DONE"
                importBtn.BackgroundColor3 = Colors.Success
                showToast("Import Sukses", msg, false)
            else
                importBtn.Text = "FAIL"
                importBtn.BackgroundColor3 = Colors.Error
                showToast("Import Gagal", msg, true)
            end

            task.wait(2)
            if importBtn and importBtn.Parent then
                importBtn.Text = "IMPORT"
                importBtn.BackgroundColor3 = Colors.Primary
            end
        end)
    end)

    table.insert(renderedCards, { card = itemFrame, ftype = fileData.fileType })
    return itemFrame
end

local function applyFilter(filter)
    CurrentFilter = filter
    for fType, btn in pairs(FilterButtons) do
        local isSelected = (fType == filter)
        TweenService:Create(btn, TweenInfo.new(0.2), {
            TextColor3 = isSelected and Colors.Text or Colors.TextMuted
        }):Play()
    end

    for _, item in ipairs(renderedCards) do
        local visible = (filter == "ALL") or (item.ftype == filter)
        item.card.Visible = visible
    end
    AssetScroll.CanvasSize = UDim2.new(0, 0, 0, ScrollLayout.AbsoluteContentSize.Y + 25)
end

btnAll.MouseButton1Click:Connect(function() applyFilter("ALL") end)
btnModel.MouseButton1Click:Connect(function() applyFilter("MODEL") end)
btnPlace.MouseButton1Click:Connect(function() applyFilter("PLACE") end)

local isScanning = false
local function performScan()
    if isScanning then return end
    isScanning = true
    RescanLbl.Text = "Scanning..."

    -- Bersihkan list lama
    for _, child in ipairs(AssetScroll:GetChildren()) do
        if child:IsA("Frame") then child:Destroy() end
    end
    renderedCards = {}

    task.spawn(function()
        local files = getAllAssetFiles()

        for _, fileData in ipairs(files) do
            renderAssetItem(fileData)
            task.wait(0.01)
        end

        AssetScroll.CanvasSize = UDim2.new(0, 0, 0, ScrollLayout.AbsoluteContentSize.Y + 25)
        applyFilter(CurrentFilter)
        StatTotalLbl.Text = tostring(#files)
        RescanLbl.Text = "Rescan Assets"
        isScanning = false

        if #files > 0 then
            showToast("Scan Selesai", string.format("Ditemukan %d file asset di memori HP.", #files), false)
        else
            showToast("Folder Kosong", "Taruh file di Delta/workspace atau Download.", true)
        end
    end)
end

RescanBtn.MouseButton1Click:Connect(performScan)

-- Jalankan scan pertama kali saat script dijalankan
task.defer(performScan)
showToast("FORKT Importer", "Engine MCHLERN v7.1 siap digunakan di Studio Lite!", false)
