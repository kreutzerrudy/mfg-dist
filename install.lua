-- mfg installer (spec/delivery-draft.md GD6): one small program for every role,
-- fetching the role's files one by one from the dist repo, by hash.
--
--   wget run <dist>/install.lua [role] [--from <dist url>]
--
-- The role defaults to what tools/publish.sh baked in (install-hmi.lua is this file
-- with "hmi"); the dist URL to the one it was published at.
--
-- NOTHING IS WRITTEN UNTIL EVERYTHING IS IN HAND. It fetches the build's manifest,
-- then ccryptolib's SHA-256 (so it can check what it fetches), then every file the
-- computer does not already hold with the right hash, each checked against the
-- manifest as it arrives. Only then does it check the space, remove the code the new
-- build dropped (GD6.3), and write. A failed download leaves the computer as it was.
--
-- The trust is the repo's, as it always was for an installer run with `wget run`:
-- this is how the controller installs itself (GD3.3), and it has no anchor above
-- it. A node the controller minted checks its files against a manifest the
-- controller signed instead (GD4); this program writes the manifest unsigned, as
-- deploy.sh does, and the node resolves its own first config at boot (B5.5a).
--
-- It mirrors deploy.sh's boot layout: /boot replaced whole except /boot/signer, the
-- role's manifest as /boot/firmware, the intent naming the role (and the node, when
-- /net/hostname exists), a trial record, stage 0 as /startup.lua. It never touches
-- /net, /mfg/state or /mfg/enroll.cfg.
local DIST = "https://raw.githubusercontent.com/kreutzerrudy/mfg-dist/main"
local DEFAULT_ROLE = "controller"

local args = {...}
local role = nil
local i = 1
while i <= #args do
    if args[i] == "--from" then
        DIST = args[i + 1]
        i = i + 2
    else
        role = role or args[i]
        i = i + 1
    end
end
role = role or DEFAULT_ROLE
DIST = DIST:gsub("/+$", "")

local PROTECTED = {"net", "mfg/state", "boot", "startup.lua", "mfg/enroll.cfg"}
-- The code a build ships, where a file it no longer ships is removed (GD6.3).
local CODE = {"mfg/common", "mfg/boot", "mfg/storage", "mfg/controller", "mfg/tools",
    "mfg/turtle", "mfg/station", "mfg/hmi", "ccryptolib"}

local function fail(text)
    error(text .. " -- install stopped; nothing was changed", 0)
end

-- One URL, binary, with a retry or two: a blob pushed a minute ago may not be on
-- GitHub's raw cache yet.
local function get(path)
    local url = DIST .. "/" .. path
    local last
    for attempt = 1, 3 do
        local handle, why = http.get(url, nil, true)
        if handle then
            local body = handle.readAll()
            handle.close()
            return body
        end
        last = why
        if attempt < 3 then sleep(attempt * 2) end
    end
    return nil, ("%s: %s"):format(url, tostring(last))
end

local function yielder()
    local n = 0
    return function()
        n = n + 1
        if n % 20 == 0 then os.queueEvent("mfg_install"); os.pullEvent("mfg_install") end
    end
end

print(("mfg installer: %s, from %s"):format(role, DIST))

--== the manifest ================================================================--

local build = (get("builds/latest") or fail("cannot reach " .. DIST .. "/builds/latest"))
    :gsub("%s", "")
local manifestText, why = get(("builds/%s/%s.manifest"):format(build, role))
if not manifestText then fail(("no %s manifest in build %s (%s)"):format(role, build, why)) end

local files, byPath = {}, {}
for line in manifestText:gmatch("[^\r\n]+") do
    local path, size, sha = line:match("^file (%S+) (%d+) (%x+)$")
    if path then
        for _, guard in ipairs(PROTECTED) do
            if path == guard or path:sub(1, #guard + 1) == guard .. "/" then
                fail("the manifest names a protected path: " .. path)
            end
        end
        local f = {path = path, size = tonumber(size), sha256 = sha:lower()}
        files[#files + 1] = f
        byPath[path] = f
    end
end
local id = manifestText:match("\nid (%x+)")
if #files == 0 or not id then fail("the manifest lists no files") end
print(("build %s: %d files"):format(build, #files))

--== SHA-256, from the build itself ================================================--

-- ccryptolib's hash and what it requires, fetched first and loaded from memory, so
-- every other file can be checked as it arrives. It checks itself too: a transfer
-- that corrupted it would not agree with its own hash.
local fetched = {}
local KIT = {"ccryptolib/sha256.lua", "ccryptolib/internal/util.lua",
    "ccryptolib/internal/packing.lua", "ccryptolib/internal/hw.lua", "ccryptolib/config.lua"}
for _, path in ipairs(KIT) do
    local f = byPath[path] or fail("the build has no " .. path)
    local bytes, bad = get("blobs/" .. f.sha256)
    if not bytes then fail(bad) end
    if #bytes ~= f.size then fail(path .. ": wrong size") end
    fetched[path] = bytes
end
local preload = {}
local function kitRequire(name)
    if preload[name] then return preload[name] end
    local path = name:gsub("%.", "/") .. ".lua"
    if fetched[path] then
        local fn, err = load(fetched[path], "=" .. path, "t", setmetatable({require = kitRequire}, {__index = _G}))
        if not fn then fail(path .. ": " .. tostring(err)) end
        preload[name] = fn()
        return preload[name]
    end
    -- The ROM's own modules (cc.expect), loaded by hand: a program started some
    -- other way than by the shell may have no `require` of its own.
    local rom = "/rom/modules/main/" .. name:gsub("%.", "/") .. ".lua"
    if fs.exists(rom) then
        local fn, err = loadfile(rom, nil, _ENV)
        if not fn then fail(rom .. ": " .. tostring(err)) end
        preload[name] = fn()
        return preload[name]
    end
    if require then return require(name) end
    fail("cannot load " .. name)
end
local sha256 = kitRequire("ccryptolib.sha256")
local function hex(bytes)
    return (bytes:gsub(".", function(c) return ("%02x"):format(c:byte()) end))
end
local function hashOf(bytes) return hex(sha256.digest(bytes)) end
for _, path in ipairs(KIT) do
    if hashOf(fetched[path]) ~= byPath[path].sha256 then fail(path .. ": does not match the manifest") end
end

--== every other file, unless already here ========================================--

local function readFile(path)
    if not fs.exists(path) or fs.isDir(path) then return nil end
    local h = fs.open(path, "rb")
    if not h then return nil end
    local bytes = h.readAll()
    h.close()
    return bytes
end

local tick = yielder()
local kept, got = 0, 0
for n, f in ipairs(files) do
    if not fetched[f.path] then
        local have = readFile(f.path)
        if have and #have == f.size and hashOf(have) == f.sha256 then
            kept = kept + 1
        else
            local bytes, bad = get("blobs/" .. f.sha256)
            if not bytes then fail(bad) end
            if #bytes ~= f.size or hashOf(bytes) ~= f.sha256 then
                fail(f.path .. ": does not match the manifest")
            end
            fetched[f.path] = bytes
            got = got + 1
        end
    end
    if n % 25 == 0 then print(("  %d/%d"):format(n, #files)) end
    tick()
end
print(("fetched %d files, %d already here"):format(got + #KIT, kept))

--== space, and what the new build dropped ========================================--

local stale, freed = {}, 0
local function sweep(dir)
    if not fs.isDir(dir) then return end
    for _, name in ipairs(fs.list(dir)) do
        local path = fs.combine(dir, name)
        if fs.isDir(path) then
            sweep(path)
        elseif name:match("%.lua$") and not byPath[path] then
            stale[#stale + 1] = path
            freed = freed + fs.getSize(path)
        end
    end
end
for _, dir in ipairs(CODE) do sweep(dir) end
if fs.isDir("mfg/firmware") then
    for _, name in ipairs(fs.list("mfg/firmware")) do
        local path = "mfg/firmware/" .. name
        if name:match("%.manifest$") and not (role == "controller" and name == "controller.manifest") then
            stale[#stale + 1] = path
            freed = freed + fs.getSize(path)
        end
    end
end

local need = -freed
for path, bytes in pairs(fetched) do
    need = need + #bytes
    if fs.exists(path) and not fs.isDir(path) then need = need - fs.getSize(path) end
end
local free = fs.getFreeSpace("/")
if need > free then
    fail(("not enough space: need %d more bytes, %d free"):format(need, free))
end

--== write ======================================================================--

local function writeFile(path, bytes)
    local dir = fs.getDir(path)
    if dir ~= "" then fs.makeDir(dir) end
    local h = fs.open(path, "wb")
    if not h then error("cannot write " .. path, 0) end
    h.write(bytes)
    h.close()
end

for _, path in ipairs(stale) do fs.delete(path) end
if #stale > 0 then
    print(("removed %d files this build no longer ships (%d bytes)"):format(#stale, freed))
end

for path, bytes in pairs(fetched) do
    writeFile(path, bytes)
    tick()
end

-- The boot layout, as deploy.sh writes it (B6.10).
local signer = readFile("boot/signer")
fs.delete("boot")
if signer then writeFile("boot/signer", signer) end
writeFile("boot/firmware", manifestText)
if role == "controller" then writeFile("mfg/firmware/controller.manifest", manifestText) end
local intent = ("role %s\n"):format(role)
local hostname = readFile("net/hostname")
if hostname and hostname:gsub("%s", "") ~= "" then
    intent = intent .. ("node %s\n"):format((hostname:gsub("%s", "")))
end
writeFile("boot/intent", intent)
writeFile("boot/record", ('{ active = "%s", rev = 0, state = "trial", tries = 0, origin = "disk" }\n')
    :format(id))
-- Stage 0 is mfg/boot/loader.lua, as deploy and mint write it.
local loader = readFile("mfg/boot/loader.lua") or fail("the build has no mfg/boot/loader.lua")
writeFile("startup.lua", loader)

-- Every file, read back and checked, before saying it worked.
local bad = {}
for _, f in ipairs(files) do
    local bytes = readFile(f.path)
    if not bytes or #bytes ~= f.size or hashOf(bytes) ~= f.sha256 then bad[#bad + 1] = f.path end
    tick()
end
if #bad > 0 then
    printError(("%d files did not write correctly (%s); do not reboot"):format(#bad,
        table.concat(bad, ", ", 1, math.min(#bad, 5))))
    return
end
print(("installed %s, %d files. Reboot to start."):format(role, #files))
