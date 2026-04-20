-- Boss Farm Module for Bloodlines V2
-- Ported features from JitlerHub: Charging, Dash+Attack, Weapon Detection,
-- Knocked/Grip, Per-Boss Animation Monitors, Auto-Loot, Advanced Boss Loop

local BossFarm = {}
BossFarm.__index = BossFarm

-- ============================================
-- SERVICES & DEPENDENCIES
-- ============================================
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

local GAME_ID = 10266164381
local HOP_MARKER_FILE = "PuppyHub_HopMarker.txt"
local LOG_FILE = "PuppyHub_BossFarm_Log.txt"

-- Cached remote references
local function GetDataEvent()
    local events = ReplicatedStorage:FindFirstChild("Events")
    return events and events:FindFirstChild("DataEvent")
end

local function GetDataFunction()
    local events = ReplicatedStorage:FindFirstChild("Events")
    return events and events:FindFirstChild("DataFunction")
end

local function writeHopMarker(context)
    if not writefile then return false end

    local payload = tostring(tick()) .. "|" .. tostring(game.PlaceId) .. "|" .. tostring(game.JobId) .. "|" .. tostring(context or "unknown")
    for _ = 1, 3 do
        local ok = pcall(function()
            writefile(HOP_MARKER_FILE, payload)
        end)
        if ok and isfile and isfile(HOP_MARKER_FILE) then
            return true
        end
        task.wait(0.05)
    end

    warn("[BossFarm] Failed to verify hop marker write for " .. tostring(context))
    return false
end

-- ============================================
-- SETTINGS
-- ============================================
BossFarm.Settings = {
    Enabled = false,
    SelectedBosses = {},
    ServerHopIfChakraSense = false,
    ServerHopIfNoBoss = false,
    HideThenHopOnThreat = false,
    HideThreatTimeout = 30,
    AttackInterval = 0.12,
    HealthCheckInterval = 0.3,
    PlayerDetectionRadius = 300,
    PlayerVerticalTolerance = 150,
    AutoLootOnKill = true,
    -- Advanced Boss Loop
    BossLoopEnabled = false,
    HopAfterLoop = false,
    WeaponHeightBoost = 0,
    -- Auto Sell
    AutoSellTrinkets = false,
    AutoSellGems = false,
    -- Webhook
    WebhookURL = "",
}

-- ============================================
-- WEAPON CONFIGS
-- ============================================
local WEAPON_KEYWORDS = {
    "kunai", "asumai", "katana", "zabunagi", "resanagi", "haldberd", "gunbai", "executioner", "samehada"
}

-- ============================================
-- BOSS CONFIGS (Expanded)
-- ============================================
local BOSS_CONFIGS = {
    ["Wooden Golem"] = {
        height = 16, positionAbove = true,
        dangerousAnimations = {
            ["120758909308511"] = true,
            ["116907126244057"] = true,
        },
        animationResponse = "teleport",
        safePosition = Vector3.new(-2950.580, 321.173, -275.704),
    },
    ["Hyuga Boss"] = {
        height = 10.75, positionAbove = true,
        hasVoidZone = true,
        lootSpot = Vector3.new(-663.8, -359.9, -728.9),
    },
    ["Lava Snake"] = {
        height = 38, positionAbove = true,
        triggerSpawn = true,
        triggerPos = Vector3.new(-547.6, -541.7, -1281.8),
        lootSpot = Vector3.new(-546.7, -546.9, -1461.6),
    },
    ["Haku Boss"] = {
        height = 10.75, positionAbove = true,
        hasIceDragon = true,
        lootSpot = Vector3.new(-3788.1, -238.5, -9723.9),
    },
    ["Barbarit The Rose"] = {
        height = 14, positionAbove = true,
        dangerousAnimations = { ["9954909571"] = true },
        animationResponse = "height", safeHeightBoost = 10,
    },
    ["Barbarit The Hallowed"] = {
        height = 16, positionAbove = true,
        dangerousAnimations = { ["9954909571"] = true },
        animationResponse = "height", safeHeightBoost = 10,
    },
    ["Manda"] = {
        height = 38, positionAbove = true,
        triggerSpawn = true,
        dangerousAnimations = { ["9954909571"] = true },
        animationResponse = "height", safeHeightBoost = 15,
    },
    ["Tairock"] = {
        height = 10.75, positionAbove = true,
        triggerSpawn = true,
    },
    ["Hallowed Tairock"] = {
        height = 10.75, positionAbove = true,
    },
    ["Chakra Knight"] = {
        height = 15, positionAbove = false,
        dangerousAnimations = { ["10141233349"] = true },
        animationResponse = "height", safeHeightBoost = 10,
    },
    ["Hallowed Chakra Knight"] = {
        height = 15, positionAbove = false,
        dangerousAnimations = { ["10141233349"] = true },
        animationResponse = "height", safeHeightBoost = 10,
    },
    ["The Barbarian"] = {
        height = 14, positionAbove = true,
    },
    ["The Ringed Samurai"] = {
        height = 14, positionAbove = true,
        triggerSpawn = true,
        triggerPos = Vector3.new(1418.9, -474.4, -595.8),
        minionRadius = 100,
        minionHeight = 5.5,
    },
}

local bossDatabase = {}
for bossName, _ in pairs(BOSS_CONFIGS) do table.insert(bossDatabase, bossName) end
table.sort(bossDatabase)

-- ============================================
-- TRINKET SET (For Auto-Loot)
-- ============================================
local TRINKET_NAMES = {
    "Gold Bracelet", "Gold Ring", "Silver Ring", "Silver Bracelet", "Silver Necklace", "Gold Necklace",
    "Gold Enclosed Ring", "Silver Enclosed Ring", "Ring Schematics", "Ring Of The Neoncat",
    "Ring Of Resistance", "Ring Of Nourishment", "Ring Of Favor", "Ring Of Remedy", "Ring Of Vitality",
    "Ring Of Infusion", "Bloodbite Ring", "Ring Of Beauty", "Ring Of Dexterity", "Ring Of A Helping Hand",
    "Aqua Gem", "Flame Gem", "Spark Gem", "Black Flame Gem", "Ground Gem", "Ice Gem", "Wind Gem",
    "Poison Gem", "Extraction Spoon", "Scalpel", "Chakra Heart", "Fruit Of Forgetfulness",
    "Progression Soul", "Memory Soul", "Summoning Scroll", "Life Up Fruit", "Mastery Scroll",
    "Trait Scroll", "Kusanagi Schematics", "Raijin Schematics", "Staff Schematics",
    "Samehada Schematics", "Gunbai Schematics",
}
local TrinketSet = {}
for _, n in ipairs(TRINKET_NAMES) do TrinketSet[n] = true end

local GEM_NAMES = {
    "Aqua Gem", "Flame Gem", "Spark Gem", "Black Flame Gem",
    "Ground Gem", "Ice Gem", "Wind Gem", "Poison Gem",
}
local GemSet = {}
for _, n in ipairs(GEM_NAMES) do GemSet[n] = true end
local GEM_CAP = 20

-- Trinket sell values (for bulk sell calculation)
local TRINKET_VALUES = {
    ["Silver Enclosed Ring"] = 3, ["Silver Ring"] = 2, ["Silver Bracelet"] = 2,
    ["Gold Enclosed Ring"] = 5, ["Gold Necklace"] = 5, ["Silver Necklace"] = 3,
    ["Gold Bracelet"] = 3, ["Gold Ring"] = 5,
}

-- ============================================
-- SAFE SPOTS
-- ============================================
local SECRET_SPOT = Vector3.new(-3933, 1120, -4571)
local SECRET_SPOT_BACKUP = Vector3.new(-2605.41016, 629.647888, -5373.87207)
local HYUGA_DANGER_DODGE_SPOT = Vector3.new(-1469.2, -100, -9610.4)
local HYUGA_ARENA_ESCAPE_SPOT = HYUGA_DANGER_DODGE_SPOT
local HYUGA_ARENA_REGION_MIN = Vector3.new(-748.399169921875, -367.0005187988281, -846.8639526367188)
local HYUGA_ARENA_REGION_MAX = Vector3.new(-599.4711303710938, -269.55303955078125, -693.4671630859375)
local HAKU_SAFE_SPOT = Vector3.new(-9788.1, 1010.5, -9723.9)
local WOODEN_GOLEM_DODGE_SPOTS = {
    Vector3.new(-4514.50048828125, 336.9197692871094, -2998.1533203125),
    Vector3.new(-4522.03564453125, 336.9197082519531, -2877.849365234375),
    Vector3.new(-4724.2041015625, 336.91973876953125, -2856.17919921875),
    Vector3.new(-4727.5517578125, 336.9197692871094, -3005.190673828125),
}
local WOODEN_GOLEM_DODGE_DURATION = 6.7
local WOODEN_GOLEM_TWEEN_DURATION = 0.01
-- ============================================
-- CHARGE ANIMATION
-- ============================================
local CHARGE_ANIM_ID = "rbxassetid://9864206537"

-- ============================================
-- STATE
-- ============================================
local State = {
    running = false,
    mode = "idle",
    runId = 0,
    panicId = 0,
    currentBoss = nil,       -- boss name string
    currentModel = nil,      -- boss Model reference
    currentHumanoid = nil,   -- boss Humanoid reference
    connections = {},
    threads = {},
    workerConnections = {},
    workerThreads = {},
    playerWatchers = {},
    localCharacterConnections = {},
    localCharacterStatusConnections = {},
    settingsConnections = {},
    characterBaseParts = {},
    lastBossPosition = nil,
    healthThreshold = 0,
    farmThread = nil,
    inDanger = false,
    -- Charging
    chargingActive = false,
    chargeAnimTrack = nil,
    -- Weapon
    detectedWeapon = "Fist",
    weaponHeightBoost = 0,
    -- Per-boss height boosts (dynamic, change during animations)
    bossHeightBoost = 0,
    hyugaArenaUnsafe = false,
    hyugaArenaUnsafeSince = 0,
    hyugaArenaTimeoutRequested = false,
    -- Haku safe spot
    hakuSafeSpot = false,
    hakuSafeSpotEndTime = 0,
    -- Knocked
    knockedThread = nil,
    -- Anchor + Attack
    anchorConn = nil,
    attackThread = nil,
    -- Boss Loop
    bossLoopThread = nil,
    dangerMonitorThread = nil,
    -- Boss Loop resume tracking
    bossLoopIndex = 0,       -- tracks which boss in the loop we're on (for resume)
    -- Boss death flag (prevents anchor from calling stopCurrent on boss death)
    bossDeathDetected = false,
    -- Looting flag (prevents farmBoss from exiting during loot)
    isLooting = false,
    -- EVACUATION FLAG: when true, ALL positioning/combat is frozen immediately
    evacuating = false,
    workersActive = false,
    serverHopInProgress = false,
    deathQuitTriggered = false,
    deathCheckInProgress = false,
    deathCheckToken = 0,
    lastIncomingDamageAt = 0,
    lastKnownHealth = 0,
    lifeForceBaseline = nil,
    forcedPosition = nil,
    combatStabilizeUntil = 0,
    bossDeathAttackUntil = 0,
    bossDeathHoldCFrame = nil,
    skippedBossUntil = {},
    hideState = {
        active = false,
        spot = nil,
        reason = nil,
        startedAt = 0,
        lastDangerAt = 0,
        hopDeadline = 0,
        wasLoop = false,
        resumeSingle = false,
        resumeIndex = 0,
        hopStarted = false,
        keepHoldingDuringHop = false,
    },
    threatCache = {
        nearby = false,
        nearbyPlayer = nil,
        senseActive = false,
        sensePlayer = nil,
        currentBossContested = false,
        currentBossPlayer = nil,
        primarySpotContested = false,
        backupSpotContested = false,
        updatedAt = 0,
    },
    recentEvents = {},
    logSessionStarted = false,
}

-- ============================================
-- UTILS
-- ============================================
local Utils = {}

function Utils.appendLogLine(line)
    if not writefile then return end

    local text = tostring(line or "")
    local ok = false

    if appendfile then
        ok = pcall(function()
            appendfile(LOG_FILE, text .. "\n")
        end)
    end

    if ok then return end

    pcall(function()
        local previous = ""
        if isfile and isfile(LOG_FILE) and readfile then
            previous = readfile(LOG_FILE)
            if #previous > 0 and not previous:match("\n$") then
                previous = previous .. "\n"
            end
        end
        writefile(LOG_FILE, previous .. text .. "\n")
    end)
end

function Utils.ensureLogSession()
    if State.logSessionStarted then return end
    State.logSessionStarted = true
    Utils.appendLogLine(string.rep("=", 72))
    Utils.appendLogLine(string.format("[%s] [SESSION] BossFarm loaded | place=%s | job=%s | player=%s",
        os.date("%Y-%m-%d %H:%M:%S"),
        tostring(game.PlaceId),
        tostring(game.JobId),
        tostring(LocalPlayer and LocalPlayer.Name or "?")
    ))
end

function Utils.log(message, level)
    local prefix = "[Boss Farm]"
    Utils.ensureLogSession()
    Utils.appendLogLine(string.format("[%s] [%s] %s",
        os.date("%Y-%m-%d %H:%M:%S"),
        tostring(level == "warn" and "WARN" or "INFO"),
        tostring(message)
    ))
    if level == "warn" then warn(prefix, message) else print(prefix, message) end
end

function Utils.formatVector3(vec)
    if not vec then return "nil" end
    return string.format("(%.1f, %.1f, %.1f)", vec.X, vec.Y, vec.Z)
end

function Utils.recordEvent(label, details)
    local entry = {
        at = os.date("%H:%M:%S"),
        label = tostring(label or "event"),
        details = details and tostring(details) or nil,
    }

    table.insert(State.recentEvents, entry)
    if #State.recentEvents > 12 then
        table.remove(State.recentEvents, 1)
    end

    Utils.ensureLogSession()
    Utils.appendLogLine(string.format("[%s] [EVENT] %s%s",
        os.date("%Y-%m-%d %H:%M:%S"),
        tostring(entry.label),
        entry.details and (" | " .. tostring(entry.details)) or ""
    ))
end

function Utils.getDebugSnapshot()
    local pData = Utils.getPlayerData()
    local forced = Safety and Safety.getForcedPosition and Safety.getForcedPosition() or nil
    local currentBossRoot = Utils.getBossRoot(State.currentModel)
    local lines = {
        "**Mode:** " .. tostring(State.mode),
        "**Boss:** " .. tostring(State.currentBoss or "None"),
        "**Running:** " .. tostring(State.running) .. " | **Evacuating:** " .. tostring(State.evacuating) .. " | **Looting:** " .. tostring(State.isLooting),
        "**Player HP:** " .. tostring(pData and math.floor(pData.humanoid.Health + 0.5) or "nil"),
        "**LifeForce Baseline:** " .. tostring(State.lifeForceBaseline),
        "**Player Pos:** " .. Utils.formatVector3(pData and pData.rootPart.Position or nil),
        "**Boss Pos:** " .. Utils.formatVector3(currentBossRoot and currentBossRoot.Position or State.lastBossPosition),
        "**Forced Pos:** " .. Utils.formatVector3(forced and forced.position or nil),
        "**Forced Reason:** " .. tostring(forced and forced.reason or "None"),
        "**Hide Reason:** " .. tostring(State.hideState and State.hideState.reason or "None"),
        "**Nearby Threat:** " .. tostring(State.threatCache and State.threatCache.nearbyPlayer or "None"),
        "**Sense Threat:** " .. tostring(State.threatCache and State.threatCache.sensePlayer or "None"),
        "**Boss Contested:** " .. tostring(State.threatCache and State.threatCache.currentBossPlayer or "None"),
        "**Hyuga Unsafe:** " .. tostring(State.hyugaArenaUnsafe),
        "**Last Damage Age:** " .. string.format("%.2fs", math.max(0, tick() - (State.lastIncomingDamageAt or 0))),
    }

    if #State.recentEvents > 0 then
        local history = {}
        for _, event in ipairs(State.recentEvents) do
            local line = "- `" .. tostring(event.at) .. "` " .. tostring(event.label)
            if event.details and event.details ~= "" then
                line = line .. " | " .. event.details
            end
            table.insert(history, line)
        end
        table.insert(lines, "**Recent Events:**\n" .. table.concat(history, "\n"))
    end

    return table.concat(lines, "\n")
end

function Utils.writeDebugSnapshot(reason)
    Utils.ensureLogSession()
    Utils.appendLogLine(string.format("[%s] [SNAPSHOT] %s",
        os.date("%Y-%m-%d %H:%M:%S"),
        tostring(reason or "No reason")
    ))
    for line in string.gmatch(Utils.getDebugSnapshot(), "[^\n]+") do
        Utils.appendLogLine("  " .. line:gsub("%*%*", ""))
    end
end

function Utils.notify(text, duration)
    pcall(function()
        game:GetService("StarterGui"):SetCore("SendNotification", {
            Title = "Bloodlines Farm"; Text = text; Duration = duration or 3;
        })
    end)
end

function Utils.getPlayerData()
    local character = LocalPlayer.Character
    if not character then return nil end
    local rootPart = character:FindFirstChild("HumanoidRootPart")
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if not rootPart or not humanoid then return nil end
    return { character = character, rootPart = rootPart, humanoid = humanoid }
end

function Utils.isValidBoss(boss)
    if not boss or not boss.Parent or not boss:IsA("Model") then return false end
    local humanoid = boss:FindFirstChildOfClass("Humanoid")
    local rootPart = boss:FindFirstChild("HumanoidRootPart")
    return humanoid and rootPart and humanoid.Health > 0
end

function Utils.getBossRoot(model)
    if not model or not model.Parent then return nil end
    return model:FindFirstChild("HumanoidRootPart")
        or model:FindFirstChild("Head")
        or model:FindFirstChild("Torso")
        or model:FindFirstChildWhichIsA("BasePart")
end

-- Uses client-side Terrain water to grant absolute fall damage immunity upon arrival
function Utils.safeTeleport(targetCFrame)
    local pData = Utils.getPlayerData()
    if not pData then return end
    local pos = targetCFrame.Position
    
    if (pData.rootPart.Position - pos).Magnitude < 50 then
        pData.rootPart.CFrame = targetCFrame
        return
    end
    
    -- Spawn a larger water bubble at destination to absorb fall damage reliably.
    pcall(function() workspace.Terrain:FillBall(pos, 27, Enum.Material.Water) end)
    RunService.Heartbeat:Wait()
    -- Teleport directly into the water
    pData.rootPart.CFrame = targetCFrame
    -- Let physics engine fully register the Swim state before removing the bubble.
    task.wait(0.5)
    -- Remove the water
    pcall(function() workspace.Terrain:FillBall(pos, 27, Enum.Material.Air) end)
end
function Utils.disconnectAll()
    for i = #State.connections, 1, -1 do
        local conn = State.connections[i]
        if conn and typeof(conn) == "RBXScriptConnection" then
            pcall(function() conn:Disconnect() end)
        end
        State.connections[i] = nil
    end
end

function Utils.cancelAllThreads()
    for i = #State.threads, 1, -1 do
        if State.threads[i] then
            pcall(task.cancel, State.threads[i])
        end
        State.threads[i] = nil
    end
end

function Utils.addConnection(conn)
    table.insert(State.connections, conn)
    return conn
end

function Utils.addThread(thread)
    table.insert(State.threads, thread)
    return thread
end

function Utils.addWorkerConnection(conn)
    table.insert(State.workerConnections, conn)
    return conn
end

function Utils.addWorkerThread(thread)
    table.insert(State.workerThreads, thread)
    return thread
end

function Utils.disconnectWorkerConnections()
    for i = #State.workerConnections, 1, -1 do
        local conn = State.workerConnections[i]
        if conn and typeof(conn) == "RBXScriptConnection" then
            pcall(function() conn:Disconnect() end)
        end
        State.workerConnections[i] = nil
    end
end

function Utils.cancelWorkerThreads()
    for i = #State.workerThreads, 1, -1 do
        if State.workerThreads[i] then
            pcall(task.cancel, State.workerThreads[i])
        end
        State.workerThreads[i] = nil
    end
end

function Utils.disconnectConnections(list)
    for i = #list, 1, -1 do
        if list[i] and typeof(list[i]) == "RBXScriptConnection" then
            pcall(function() list[i]:Disconnect() end)
        end
        list[i] = nil
    end
end

function Utils.removeArrayItem(list, item)
    for i = #list, 1, -1 do
        if list[i] == item then
            table.remove(list, i)
            return
        end
    end
end

function Utils.rebuildCharacterBaseParts(character)
    State.characterBaseParts = {}
    if not character then return end
    for _, descendant in ipairs(character:GetDescendants()) do
        if descendant:IsA("BasePart") then
            table.insert(State.characterBaseParts, descendant)
        end
    end
end

function Utils.setMode(mode)
    if State.mode ~= mode then
        Utils.recordEvent("Mode", tostring(State.mode) .. " -> " .. tostring(mode))
    end
    State.mode = mode
end

function Utils.isInsideRegion(position, minPosition, maxPosition)
    if not position then return false end
    return position.X >= minPosition.X and position.X <= maxPosition.X
        and position.Y >= minPosition.Y and position.Y <= maxPosition.Y
        and position.Z >= minPosition.Z and position.Z <= maxPosition.Z
end

-- Simulate natural player movement near a position (anti-detection)
-- Walks randomly within a radius, varying speed and direction like a real player
function Utils.randomWalkAt(spot, radius)
    radius = radius or 6
    local pData = Utils.getPlayerData()
    if not pData then return end
    
    local angle = math.random() * math.pi * 2
    local distance = math.random() * radius
    local offset = Vector3.new(math.cos(angle) * distance, 0, math.sin(angle) * distance)
    local targetPos = spot + offset
    pcall(function()
        pData.humanoid:MoveTo(targetPos)
    end)
end

function Utils.getLifeForceValue()
    local value = nil

    pcall(function()
        local clientGui = PlayerGui:FindFirstChild("ClientGui")
        local mainframe = clientGui and clientGui:FindFirstChild("Mainframe")
        local loadout = mainframe and mainframe:FindFirstChild("Loadout")
        local hud = loadout and loadout:FindFirstChild("HUD")
        local lifeForceFrame = hud and hud:FindFirstChild("LifeForce")
        local lifeForceLabel = lifeForceFrame and lifeForceFrame:FindFirstChild("LifeForce")
        local text = lifeForceLabel and lifeForceLabel.Text or nil
        if type(text) == "string" then
            local numberText = text:match("(%d+)")
            if numberText then
                value = tonumber(numberText)
            end
        end
    end)

    return value
end

-- ============================================
-- CHARGING SYSTEM
-- ============================================
local Charging = {}

function Charging.start()
    if State.chargingActive then return end
    State.chargingActive = true

    -- Fire charging remote
    pcall(function()
        local dataEvent = GetDataEvent()
        if dataEvent then dataEvent:FireServer("Charging") end
    end)

    -- Play charge animation locally
    pcall(function()
        local char = LocalPlayer.Character
        if not char then return end
        local hum = char:FindFirstChildOfClass("Humanoid")
        if not hum then return end
        local animator = hum:FindFirstChildOfClass("Animator")
        if not animator then
            animator = Instance.new("Animator")
            animator.Parent = hum
        end
        local anim = Instance.new("Animation")
        anim.AnimationId = CHARGE_ANIM_ID
        local track = animator:LoadAnimation(anim)
        track.Looped = true
        track:Play()
        State.chargeAnimTrack = track
    end)

    Utils.log("Charging started")
end

function Charging.stop()
    if not State.chargingActive then return end
    State.chargingActive = false

    pcall(function()
        if State.chargeAnimTrack then
            State.chargeAnimTrack:Stop()
            State.chargeAnimTrack = nil
        end
    end)

    pcall(function()
        local dataEvent = GetDataEvent()
        if dataEvent then dataEvent:FireServer("StopCharging") end
    end)

    Utils.log("Charging stopped")
end

-- ============================================
-- WEAPON DETECTION
-- ============================================
local Weapons = {}

function Weapons.scanHotbar()
    local found = nil
    pcall(function()
        local gui = PlayerGui
        local clientGui = gui and gui:FindFirstChild("ClientGui")
        local mainframe = clientGui and clientGui:FindFirstChild("Mainframe")
        local loadout = mainframe and mainframe:FindFirstChild("Loadout")
        if not loadout then return end
        for j = 1, 11 do
            local slot = loadout:FindFirstChild("Slot" .. j)
            if not slot then continue end
            local slotText = slot:FindFirstChild("SlotText")
            local itemName = slotText and slotText:IsA("TextLabel") and slotText.Text or ""
            if itemName ~= "" then
                local l = string.lower(itemName)
                for _, kw in ipairs(WEAPON_KEYWORDS) do
                    if string.find(l, kw) then
                        found = itemName
                        return
                    end
                end
            end
        end
    end)
    return found or "Fist"
end

function Weapons.equip(weaponName)
    if weaponName == "Fist" or weaponName == "" then return end
    pcall(function()
        local dataEvent = GetDataEvent()
        if dataEvent then
            dataEvent:FireServer("Item", "Selected", weaponName)
        end
    end)
end

-- ============================================
-- DISCORD WEBHOOK
-- ============================================
local Webhook = {}

function Webhook.send(title, description, color)
    local url = BossFarm.Settings.WebhookURL
    if not url or url == "" then return end
    
    pcall(function()
        local requestFunc = (syn and syn.request) or (http and http.request) or http_request or (fluxus and fluxus.request) or request
        if not requestFunc then return end
        
        local payload = HttpService:JSONEncode({
            embeds = {{
                title = title,
                description = description,
                color = color or 3447003,
                footer = {
                    text = "Puppy Hub | " .. LocalPlayer.Name .. " | Server: " .. string.sub(game.JobId, 1, 8)
                },
                timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ")
            }}
        })
        
        requestFunc({
            Url = url,
            Method = "POST",
            Headers = {["Content-Type"] = "application/json"},
            Body = payload
        })
    end)
end

-- ============================================
-- PLAYER SAFETY (Horizontal + Vertical Tolerance)
-- ============================================
local Safety = {}

function Safety.getCharacterRoot(character)
    if not character then return nil end
    return character:FindFirstChild("HumanoidRootPart")
        or character:FindFirstChild("UpperTorso")
        or character:FindFirstChild("Torso")
        or character:FindFirstChild("Head")
end

function Safety.isPlayerNearPosition(position, radius, verticalTolerance)
    radius = radius or BossFarm.Settings.PlayerDetectionRadius
    verticalTolerance = verticalTolerance or BossFarm.Settings.PlayerVerticalTolerance
    
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character then
            local root = Safety.getCharacterRoot(player.Character)
            if root then
                -- Check for absurd positions (players at spawn/loading)
                if math.abs(root.Position.X) > 1e6 or math.abs(root.Position.Y) > 1e6 then
                    continue
                end
                
                local horizontal = Vector3.new(root.Position.X, 0, root.Position.Z)
                local center = Vector3.new(position.X, 0, position.Z)
                local horizontalDist = (horizontal - center).Magnitude
                local verticalDist = math.abs(root.Position.Y - position.Y)
                
                if horizontalDist <= radius and verticalDist <= verticalTolerance then
                    return true, player.Name
                end
            end
        end
    end
    return false
end

function Safety.isBossContested(model, radius)
    local bossRoot = Utils.getBossRoot(model)
    if not bossRoot then return false end
    return Safety.isPlayerNearPosition(bossRoot.Position, radius)
end

function Safety.isChakraSenseActive()
    local SETTINGS_FOLDER = ReplicatedStorage:FindFirstChild("Settings")
    
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then
            -- Check ReplicatedStorage Settings for "sense" skill
            if SETTINGS_FOLDER then
                local pSettings = SETTINGS_FOLDER:FindFirstChild(player.Name)
                if pSettings then
                    local sVal = pSettings:FindFirstChild("CurrentSkill")
                    if sVal and type(sVal.Value) == "string" and string.find(string.lower(sVal.Value), "sense") then
                        return true, player.Name
                    end
                end
            end
        end
    end
    return false
end

function Safety.getSafeSpot()
    local pd = Utils.getPlayerData()
    if pd then
        -- Prefer staying at the one we are already at
        if (pd.rootPart.Position - SECRET_SPOT_BACKUP).Magnitude < 50 then return SECRET_SPOT_BACKUP end
        if (pd.rootPart.Position - SECRET_SPOT).Magnitude < 50 then return SECRET_SPOT end
    end
    
    local primaryContested = Safety.isPlayerNearPosition(SECRET_SPOT, BossFarm.Settings.PlayerDetectionRadius)
    if not primaryContested then return SECRET_SPOT end
    
    local backupContested = Safety.isPlayerNearPosition(SECRET_SPOT_BACKUP, BossFarm.Settings.PlayerDetectionRadius)
    if not backupContested then return SECRET_SPOT_BACKUP end
    
    return nil -- both are compromised!
end

function Safety.evacuateAndHop(reason)
    -- IMMEDIATELY freeze all positioning
    State.evacuating = true
    State.running = false
    
    -- STOP anchor + combat BEFORE teleporting (prevents Heartbeat from snapping us back)
    if State.anchorConn then State.anchorConn:Disconnect(); State.anchorConn = nil end
    if State.attackThread then pcall(task.cancel, State.attackThread); State.attackThread = nil end
    Charging.stop()
    
    Utils.log("Evacuating: " .. tostring(reason))
    Utils.notify("Evacuating: " .. tostring(reason), 5)
    Webhook.send("⚠️ Evacuating & Hopping", reason, 15158332)
    
    local safeSpot = Safety.getSafeSpot()
    if safeSpot then
        local pd = Utils.getPlayerData()
        if pd then
            local distToSpot = (pd.rootPart.Position - safeSpot).Magnitude
            if distToSpot > 20 then
                Utils.safeTeleport(CFrame.new(safeSpot))
            end
        end
    end
    
    -- Full cleanup
    Farm.stopCurrent()
    if State.farmThread then pcall(task.cancel, State.farmThread); State.farmThread = nil end
    if State.bossLoopThread then pcall(task.cancel, State.bossLoopThread); State.bossLoopThread = nil end
    if State.dangerMonitorThread then pcall(task.cancel, State.dangerMonitorThread); State.dangerMonitorThread = nil end
    Utils.disconnectAll()
    Utils.cancelAllThreads()
    BossFarm.Settings.Enabled = false
    BossFarm.Settings.BossLoopEnabled = false
    
    -- Wait and walk while hopping (if we have a safe spot)
    task.spawn(function()
        while State.evacuating do
            if safeSpot then
                local cpd = Utils.getPlayerData()
                if cpd then 
                    -- Ignore Y axis distance so gravity drop doesn't cause forced rubberbanding
                    local dist = Vector3.new(cpd.rootPart.Position.X - safeSpot.X, 0, cpd.rootPart.Position.Z - safeSpot.Z).Magnitude
                    if dist > 30 then
                        cpd.rootPart.CFrame = CFrame.new(safeSpot) 
                    end
                end
                Utils.randomWalkAt(safeSpot, 6)
            end
            task.wait(math.random(15, 30) / 10)
        end
    end)
    
    ServerHop.execute(true)
end

function Safety.startMonitor()
    if State.dangerMonitorThread then pcall(task.cancel, State.dangerMonitorThread) end
    State.dangerMonitorThread = task.spawn(function()
        while State.running do
            local senseActive, sensePlayer = Safety.isChakraSenseActive()
            if senseActive then
                if BossFarm.Settings.ServerHopIfChakraSense then
                    Safety.evacuateAndHop("Chakra Sense (" .. sensePlayer .. ")")
                else
                    Safety.evacuateAndHide("Chakra Sense (" .. sensePlayer .. ")")
                end
                return
            end
            task.wait()
        end
    end)
end

function Safety.evacuateAndHide(reason)
    -- IMMEDIATELY freeze all positioning
    State.evacuating = true
    State.running = false
    
    -- STOP anchor + combat BEFORE teleporting (prevents Heartbeat from snapping us back)
    if State.anchorConn then State.anchorConn:Disconnect(); State.anchorConn = nil end
    if State.attackThread then pcall(task.cancel, State.attackThread); State.attackThread = nil end
    Charging.stop()
    
    Utils.log("Hiding: " .. tostring(reason))
    Utils.notify("Hiding at Safe Spot! Waiting for danger to clear...", 5)
    
    -- Decide which safe spot to use
    local safeSpot = Safety.getSafeSpot()
    if not safeSpot then
        Safety.evacuateAndHop("Both safe spots compromised!")
        return
    end
    
    -- Remember if we were in boss loop mode and what index we were at
    local wasInBossLoop = BossFarm.Settings.BossLoopEnabled
    local resumeIndex = State.bossLoopIndex
    
    -- NOW teleport to safe spot if not already there (anchor is already dead, can't fight back)
    local pd = Utils.getPlayerData()
    if pd then
        local distToSpot = (pd.rootPart.Position - safeSpot).Magnitude
        if distToSpot > 20 then
            Utils.safeTeleport(CFrame.new(safeSpot))
        end
    end
    
    -- Full cleanup
    Farm.stopCurrent()
    Utils.disconnectAll()
    Utils.cancelAllThreads()
    if State.bossLoopThread then pcall(task.cancel, State.bossLoopThread); State.bossLoopThread = nil end
    if State.dangerMonitorThread then pcall(task.cancel, State.dangerMonitorThread); State.dangerMonitorThread = nil end
    
    task.spawn(function()
        local safeTimer = 0
        local dangerTimer = 0
        while BossFarm.Settings.Enabled or wasInBossLoop do
            -- HOLD safe spot every tick (absolute enforcement)
            local cpd = Utils.getPlayerData()
            if cpd then
                -- Ignore Y axis distance so gravity drop doesn't cause forced rubberbanding
                local dist = Vector3.new(cpd.rootPart.Position.X - safeSpot.X, 0, cpd.rootPart.Position.Z - safeSpot.Z).Magnitude
                if dist > 30 then
                    cpd.rootPart.CFrame = CFrame.new(safeSpot)
                end
            end
            Utils.randomWalkAt(safeSpot, 6)
            
            local senseActive, sensePlayer = Safety.isChakraSenseActive()
            local contested = Safety.isPlayerNearPosition(safeSpot, BossFarm.Settings.PlayerDetectionRadius)
            
            if senseActive or contested then
                safeTimer = 0
                dangerTimer = dangerTimer + 2
                if dangerTimer >= 30 then
                    Safety.evacuateAndHop("Danger > 30s (" .. (sensePlayer or "Someone nearby") .. ")")
                    return
                end
            else
                break -- Coast is clear at the safe spot, break the loop instantly to attempt resume
            end
            task.wait(2)
        end
        
        -- Clear evacuation flag BEFORE resuming
        State.evacuating = false
        
        Utils.notify("Coast is clear! Resuming Farm...", 5)
        if wasInBossLoop then
            BossFarm.Settings.BossLoopEnabled = true
            State.bossLoopIndex = resumeIndex
            State.running = true
            BossLoop.start()
        elseif BossFarm.Settings.Enabled then
            State.running = true
            Farm.start()
        end
    end)
end

-- ============================================
-- SAFETY RUNTIME OVERRIDES (Frame-Level Panic + Cached Watchers)
-- ============================================
local BossLoop
local HIDE_RESUME_CLEAR_TIME = 0.35
local HAKU_FORCE_PRIORITY = 80
local HYUGA_ARENA_ESCAPE_PRIORITY = 75
local HYUGA_DODGE_PRIORITY = 70
local RINGED_SAMURAI_DODGE_PRIORITY = 65
local WOODEN_GOLEM_DODGE_PRIORITY = 60
local GENERIC_DODGE_PRIORITY = 40

local function newHideState()
    return {
        active = false,
        spot = nil,
        reason = nil,
        startedAt = 0,
        lastDangerAt = 0,
        hopDeadline = 0,
        hardHoldUntil = 0,
        wasLoop = false,
        resumeSingle = false,
        resumeIndex = 0,
        hopStarted = false,
        keepHoldingDuringHop = false,
        lastSwapAt = 0,
    }
end

local function newThreatCache()
    return {
        nearby = false,
        nearbyPlayer = nil,
        senseActive = false,
        sensePlayer = nil,
        currentBossContested = false,
        currentBossPlayer = nil,
        primarySpotContested = false,
        backupSpotContested = false,
        updatedAt = 0,
    }
end

local function isReasonablePosition(position)
    return position
        and math.abs(position.X) <= 1e6
        and math.abs(position.Y) <= 1e6
        and math.abs(position.Z) <= 1e6
end

function Safety.hasSenseKeyword(value)
    return type(value) == "string" and string.find(string.lower(value), "sense") ~= nil
end

function Safety.containerHasSenseTool(container)
    if not container then return false end
    for _, child in ipairs(container:GetChildren()) do
        if child:IsA("Tool") and Safety.hasSenseKeyword(child.Name) then
            return true
        end
    end
    return false
end

function Safety.isWithinRange(targetPosition, centerPosition, radius, verticalTolerance)
    radius = radius or BossFarm.Settings.PlayerDetectionRadius
    verticalTolerance = verticalTolerance or BossFarm.Settings.PlayerVerticalTolerance

    local horizontalTarget = Vector3.new(targetPosition.X, 0, targetPosition.Z)
    local horizontalCenter = Vector3.new(centerPosition.X, 0, centerPosition.Z)
    local horizontalDist = (horizontalTarget - horizontalCenter).Magnitude
    local verticalDist = math.abs(targetPosition.Y - centerPosition.Y)
    return horizontalDist <= radius and verticalDist <= verticalTolerance, horizontalDist, verticalDist
end

function Safety.refreshWatcherSense(watcher)
    watcher.senseActive = Safety.hasSenseKeyword(watcher.currentSkill)
        or watcher.characterToolSense == true
        or watcher.backpackToolSense == true
end

function Safety.bindWatcherCharacter(watcher, character)
    Utils.disconnectConnections(watcher.characterConnections)
    watcher.character = character
    watcher.root = nil
    watcher.humanoid = nil
    watcher.characterToolSense = false

    if not character then
        Safety.refreshWatcherSense(watcher)
        return
    end

    local function refreshCharacterState()
        watcher.character = character
        watcher.root = Safety.getCharacterRoot(character)
        watcher.humanoid = character:FindFirstChildOfClass("Humanoid")
        watcher.characterToolSense = Safety.containerHasSenseTool(character)
        Safety.refreshWatcherSense(watcher)
    end

    refreshCharacterState()
    table.insert(watcher.characterConnections, character.ChildAdded:Connect(refreshCharacterState))
    table.insert(watcher.characterConnections, character.ChildRemoved:Connect(refreshCharacterState))
    table.insert(watcher.characterConnections, character.AncestryChanged:Connect(function(_, parent)
        if not parent then
            watcher.character = nil
            watcher.root = nil
            watcher.humanoid = nil
            watcher.characterToolSense = false
            Safety.refreshWatcherSense(watcher)
        end
    end))
end

function Safety.bindWatcherBackpack(watcher, backpack)
    Utils.disconnectConnections(watcher.backpackConnections)
    watcher.backpack = backpack
    watcher.backpackToolSense = false

    if not backpack then
        Safety.refreshWatcherSense(watcher)
        return
    end

    local function refreshBackpackState()
        watcher.backpack = backpack
        watcher.backpackToolSense = Safety.containerHasSenseTool(backpack)
        Safety.refreshWatcherSense(watcher)
    end

    refreshBackpackState()
    table.insert(watcher.backpackConnections, backpack.ChildAdded:Connect(refreshBackpackState))
    table.insert(watcher.backpackConnections, backpack.ChildRemoved:Connect(refreshBackpackState))
end

function Safety.bindWatcherSettings(watcher)
    Utils.disconnectConnections(watcher.settingConnections)
    Utils.disconnectConnections(watcher.settingValueConnections)
    watcher.currentSkill = nil

    local settingsFolder = State.settingsFolder
    local playerSettings = settingsFolder and settingsFolder:FindFirstChild(watcher.player.Name)
    if not playerSettings then
        Safety.refreshWatcherSense(watcher)
        return
    end

    local function bindCurrentSkill()
        Utils.disconnectConnections(watcher.settingValueConnections)
        local sVal = playerSettings:FindFirstChild("CurrentSkill")
        watcher.currentSkill = sVal and tostring(sVal.Value) or nil
        if sVal then
            table.insert(watcher.settingValueConnections, sVal:GetPropertyChangedSignal("Value"):Connect(function()
                watcher.currentSkill = tostring(sVal.Value)
                Safety.refreshWatcherSense(watcher)
            end))
        end
        Safety.refreshWatcherSense(watcher)
    end

    bindCurrentSkill()
    table.insert(watcher.settingConnections, playerSettings.ChildAdded:Connect(function(child)
        if child.Name == "CurrentSkill" then
            bindCurrentSkill()
        end
    end))
    table.insert(watcher.settingConnections, playerSettings.ChildRemoved:Connect(function(child)
        if child.Name == "CurrentSkill" then
            bindCurrentSkill()
        end
    end))
end

function Safety.destroyPlayerWatcher(player)
    local watcher = State.playerWatchers[player]
    if not watcher then return end

    Utils.disconnectConnections(watcher.connections)
    Utils.disconnectConnections(watcher.characterConnections)
    Utils.disconnectConnections(watcher.backpackConnections)
    Utils.disconnectConnections(watcher.settingConnections)
    Utils.disconnectConnections(watcher.settingValueConnections)
    State.playerWatchers[player] = nil
end

function Safety.ensurePlayerWatcher(player)
    if not player or player == LocalPlayer or State.playerWatchers[player] then
        return
    end

    local watcher = {
        player = player,
        connections = {},
        characterConnections = {},
        backpackConnections = {},
        settingConnections = {},
        settingValueConnections = {},
        character = nil,
        humanoid = nil,
        root = nil,
        currentSkill = nil,
        characterToolSense = false,
        backpackToolSense = false,
        senseActive = false,
    }
    State.playerWatchers[player] = watcher

    Safety.bindWatcherCharacter(watcher, player.Character)
    Safety.bindWatcherBackpack(watcher, player:FindFirstChildOfClass("Backpack"))
    Safety.bindWatcherSettings(watcher)

    table.insert(watcher.connections, player.CharacterAdded:Connect(function(character)
        Safety.bindWatcherCharacter(watcher, character)
    end))
    table.insert(watcher.connections, player.CharacterRemoving:Connect(function()
        Safety.bindWatcherCharacter(watcher, nil)
    end))
    table.insert(watcher.connections, player.ChildAdded:Connect(function(child)
        if child:IsA("Backpack") then
            Safety.bindWatcherBackpack(watcher, child)
        end
    end))
    table.insert(watcher.connections, player.ChildRemoved:Connect(function(child)
        if child:IsA("Backpack") then
            Safety.bindWatcherBackpack(watcher, nil)
        end
    end))
end

function Safety.refreshSettingsFolder()
    Utils.disconnectConnections(State.settingsConnections)
    State.settingsFolder = ReplicatedStorage:FindFirstChild("Settings")

    table.insert(State.settingsConnections, ReplicatedStorage.ChildAdded:Connect(function(child)
        if child.Name == "Settings" then
            Safety.refreshSettingsFolder()
        end
    end))
    table.insert(State.settingsConnections, ReplicatedStorage.ChildRemoved:Connect(function(child)
        if child.Name == "Settings" then
            Safety.refreshSettingsFolder()
        end
    end))

    if State.settingsFolder then
        table.insert(State.settingsConnections, State.settingsFolder.ChildAdded:Connect(function()
            for _, watcher in pairs(State.playerWatchers) do
                Safety.bindWatcherSettings(watcher)
            end
        end))
        table.insert(State.settingsConnections, State.settingsFolder.ChildRemoved:Connect(function()
            for _, watcher in pairs(State.playerWatchers) do
                Safety.bindWatcherSettings(watcher)
            end
        end))
    end

    for _, watcher in pairs(State.playerWatchers) do
        Safety.bindWatcherSettings(watcher)
    end
end

function Safety.startLocalCharacterWatcher()
    Utils.disconnectConnections(State.localCharacterConnections)
    State.localCharacterDescendantConnections = State.localCharacterDescendantConnections or {}
    State.localCharacterStatusConnections = State.localCharacterStatusConnections or {}
    Utils.disconnectConnections(State.localCharacterDescendantConnections)
    Utils.disconnectConnections(State.localCharacterStatusConnections)

    local function bindLocalCharacter(character)
        Utils.disconnectConnections(State.localCharacterDescendantConnections)
        Utils.disconnectConnections(State.localCharacterStatusConnections)
        Utils.rebuildCharacterBaseParts(character)
        if not character then return end

        local humanoid = character:FindFirstChildOfClass("Humanoid")
        if humanoid then
            State.lastKnownHealth = humanoid.Health
            table.insert(State.localCharacterStatusConnections, humanoid.HealthChanged:Connect(function(health)
                Safety.handleIncomingDamage(health)
            end))
            table.insert(State.localCharacterStatusConnections, humanoid.Died:Connect(function()
                Safety.scheduleDeathCheck("Humanoid.Died fired")
            end))
        end

        table.insert(State.localCharacterDescendantConnections, character.DescendantAdded:Connect(function(descendant)
            if descendant:IsA("BasePart") then
                table.insert(State.characterBaseParts, descendant)
            end
        end))
        table.insert(State.localCharacterDescendantConnections, character.DescendantRemoving:Connect(function(descendant)
            if descendant:IsA("BasePart") then
                Utils.removeArrayItem(State.characterBaseParts, descendant)
            end
        end))
    end

    bindLocalCharacter(LocalPlayer.Character)
    table.insert(State.localCharacterConnections, LocalPlayer.CharacterAdded:Connect(bindLocalCharacter))
    table.insert(State.localCharacterConnections, LocalPlayer.CharacterRemoving:Connect(function()
        Utils.disconnectConnections(State.localCharacterStatusConnections)
        Utils.disconnectConnections(State.localCharacterDescendantConnections)
        Utils.rebuildCharacterBaseParts(nil)
    end))
end

function Safety.isWatcherValid(watcher)
    if not watcher or not watcher.character or not watcher.character.Parent then
        return false
    end
    if not watcher.humanoid or watcher.humanoid.Health <= 0 then
        return false
    end
    if not watcher.root or not watcher.root.Parent then
        return false
    end
    if not isReasonablePosition(watcher.root.Position) then
        return false
    end
    return true, watcher.root
end

function Safety.isPlayerNearPosition(position, radius, verticalTolerance)
    local nearestName = nil
    local nearestDistance = math.huge

    for _, watcher in pairs(State.playerWatchers) do
        local valid, root = Safety.isWatcherValid(watcher)
        if valid then
            local isNear, horizontalDist = Safety.isWithinRange(root.Position, position, radius, verticalTolerance)
            if isNear and horizontalDist < nearestDistance then
                nearestDistance = horizontalDist
                nearestName = watcher.player.Name
            end
        end
    end

    return nearestName ~= nil, nearestName
end

function Safety.isBossContested(model, radius)
    local bossRoot = Utils.getBossRoot(model)
    if not bossRoot then return false end
    return Safety.isPlayerNearPosition(bossRoot.Position, radius)
end

function Safety.isChakraSenseActive()
    if not BossFarm.Settings.ServerHopIfChakraSense then
        return false
    end

    if State.threatCache.senseActive then
        return true, State.threatCache.sensePlayer
    end

    for _, watcher in pairs(State.playerWatchers) do
        if watcher.senseActive then
            return true, watcher.player.Name
        end
    end
    return false
end

function Safety.updateThreatCache()
    local cache = newThreatCache()
    local playerData = Utils.getPlayerData()
    local myPosition = playerData and playerData.rootPart.Position or nil
    local bossRoot = Utils.getBossRoot(State.currentModel)

    local nearestPlayerDistance = math.huge
    local nearestBossDistance = math.huge

    for _, watcher in pairs(State.playerWatchers) do
        local valid, root = Safety.isWatcherValid(watcher)
        if valid then
            local rootPosition = root.Position

            if watcher.senseActive and not cache.senseActive then
                cache.senseActive = true
                cache.sensePlayer = watcher.player.Name
            end

            if myPosition then
                local nearMe, horizontalDist = Safety.isWithinRange(rootPosition, myPosition)
                if nearMe and horizontalDist < nearestPlayerDistance then
                    nearestPlayerDistance = horizontalDist
                    cache.nearby = true
                    cache.nearbyPlayer = watcher.player.Name
                end
            end

            if bossRoot then
                local nearBoss, bossDist = Safety.isWithinRange(rootPosition, bossRoot.Position)
                if nearBoss and bossDist < nearestBossDistance then
                    nearestBossDistance = bossDist
                    cache.currentBossContested = true
                    cache.currentBossPlayer = watcher.player.Name
                end
            end

            if not cache.primarySpotContested and Safety.isWithinRange(rootPosition, SECRET_SPOT) then
                cache.primarySpotContested = true
            end
            if not cache.backupSpotContested and Safety.isWithinRange(rootPosition, SECRET_SPOT_BACKUP) then
                cache.backupSpotContested = true
            end
        end
    end

    cache.updatedAt = tick()
    State.threatCache = cache
end

function Safety.getSafeSpot()
    local playerData = Utils.getPlayerData()
    local cache = State.threatCache

    if State.hideState.active and State.hideState.spot then
        return State.hideState.spot
    end

    if playerData then
        if (playerData.rootPart.Position - SECRET_SPOT).Magnitude < 50 then
            return SECRET_SPOT
        end
        if (playerData.rootPart.Position - SECRET_SPOT_BACKUP).Magnitude < 50 then
            return SECRET_SPOT_BACKUP
        end
    end

    if not cache.primarySpotContested then
        return SECRET_SPOT
    end
    if not cache.backupSpotContested then
        return SECRET_SPOT_BACKUP
    end

    return SECRET_SPOT
end

function Safety.getThreatReason()
    local cache = State.threatCache
    if BossFarm.Settings.ServerHopIfChakraSense and cache.senseActive then
        return true, "Chakra Sense (" .. tostring(cache.sensePlayer or "?") .. ")"
    end
    if cache.nearby then
        return true, "Player Nearby (" .. tostring(cache.nearbyPlayer or "?") .. ")"
    end
    if cache.currentBossContested then
        return true, "Boss Contested (" .. tostring(cache.currentBossPlayer or "?") .. ")"
    end
    return false, nil
end

function Safety.isSoftHideReason(reason)
    if type(reason) ~= "string" then
        return false
    end

    local isSense = string.find(reason, "Chakra Sense", 1, true) ~= nil
    local isBossContested = string.find(reason, "Boss Contested", 1, true) ~= nil
    if not isSense and not isBossContested then
        return false
    end

    local cache = State.threatCache
    return not cache.nearby
end

function Safety.shouldImmediateHopHide(reason)
    if type(reason) ~= "string" then
        return false
    end

    return string.find(reason, "Player Nearby", 1, true) ~= nil
end

function Safety.getAlternateHideSpot(currentSpot)
    if currentSpot and (currentSpot - SECRET_SPOT).Magnitude <= 1 then
        return SECRET_SPOT_BACKUP
    end
    return SECRET_SPOT
end

function Safety.forceTeleport(targetPosition)
    if not targetPosition then return end
    local playerData = Utils.getPlayerData()
    if not playerData then return end

    local targetCFrame = CFrame.new(targetPosition)
    if (playerData.rootPart.Position - targetPosition).Magnitude > 35 then
        Utils.safeTeleport(targetCFrame)
    else
        playerData.rootPart.CFrame = targetCFrame
    end
end

function Safety.swapHideSpot(reason)
    if not State.hideState.active then return false end

    local now = tick()
    if State.hideState.lastSwapAt and (now - State.hideState.lastSwapAt) < 0.25 then
        return false
    end

    local alternateSpot = Safety.getAlternateHideSpot(State.hideState.spot or SECRET_SPOT)
    State.hideState.spot = alternateSpot
    State.hideState.lastSwapAt = now
    State.hideState.lastDangerAt = now
    State.hideState.hardHoldUntil = now + 0.15
    Utils.log("Swapping hide spot: " .. tostring(reason or "Unknown"))
    Safety.forceTeleport(alternateSpot)
    return true
end

function Safety.captureLifeForceBaseline()
    local currentLifeForce = Utils.getLifeForceValue()
    if currentLifeForce ~= nil then
        State.lifeForceBaseline = currentLifeForce
    end
end

function Safety.pauseForDeathCheck()
    State.deathCheckInProgress = true
    Charging.stop()
    if State.anchorConn then State.anchorConn:Disconnect(); State.anchorConn = nil end
    if State.attackThread then pcall(task.cancel, State.attackThread); State.attackThread = nil end
    if State.knockedThread then pcall(task.cancel, State.knockedThread); State.knockedThread = nil end
    Utils.disconnectAll()
    Utils.cancelAllThreads()
    Utils.setMode("idle")
end

function Safety.resumeAfterDeathCheck()
    State.deathCheckInProgress = false
end

function Safety.quitForDeath()
    if State.deathQuitTriggered then return end
    if not (State.workersActive or State.running or BossFarm.Settings.Enabled or BossFarm.Settings.BossLoopEnabled or State.hideState.active or State.mode == "hopping") then
        return
    end

    State.deathQuitTriggered = true
    Utils.log("Character died. Quitting for safety.", "warn")
    Utils.writeDebugSnapshot("quitForDeath")
    Webhook.send("☠️ Death Debug", Utils.getDebugSnapshot(), 15158332)

    BossFarm.Settings.Enabled = false
    BossFarm.Settings.BossLoopEnabled = false
    State.running = false
    State.evacuating = false
    State.serverHopInProgress = false

    pcall(function() Farm.stopCurrent() end)
    pcall(function()
        if State.farmThread then pcall(task.cancel, State.farmThread); State.farmThread = nil end
        if State.bossLoopThread then pcall(task.cancel, State.bossLoopThread); State.bossLoopThread = nil end
    end)
    pcall(function() Safety.stopWorkers() end)

    task.defer(function()
        pcall(function()
            LocalPlayer:Kick("died, quitting for safety")
        end)
    end)
end

function Safety.scheduleDeathCheck(reason)
    if State.deathQuitTriggered then return end

    State.deathCheckToken = State.deathCheckToken + 1
    local currentToken = State.deathCheckToken
    Utils.recordEvent("Death Check", tostring(reason))

    if not State.deathCheckInProgress then
        Utils.log("Suspected death detected: " .. tostring(reason))
        Safety.pauseForDeathCheck()
    end

    task.delay(0.3, function()
        if State.deathQuitTriggered or State.deathCheckToken ~= currentToken then
            return
        end

        local currentLifeForce = Utils.getLifeForceValue()
        local baselineLifeForce = State.lifeForceBaseline

        if currentLifeForce ~= nil and baselineLifeForce ~= nil and currentLifeForce < baselineLifeForce then
            Utils.log("LifeForce dropped from " .. tostring(baselineLifeForce) .. " to " .. tostring(currentLifeForce) .. ".", "warn")
            Utils.recordEvent("Death Confirmed", tostring(baselineLifeForce) .. " -> " .. tostring(currentLifeForce))
            Safety.quitForDeath()
            return
        end

        Utils.log("Death check cleared. LifeForce unchanged.", "warn")
        Utils.recordEvent("Death Cleared", "LifeForce unchanged")
        Safety.resumeAfterDeathCheck()
    end)
end

local function getHideResumeClearTime(reason)
    local clearTime = HIDE_RESUME_CLEAR_TIME
    if type(reason) == "string" and string.find(reason, "Chakra Sense", 1, true) then
        clearTime = 2.5
    end
    if State.lastIncomingDamageAt ~= 0 and tick() - State.lastIncomingDamageAt <= 2 then
        clearTime = math.max(clearTime, 2.5)
    end
    return clearTime
end

function Safety.handleIncomingDamage(newHealth)
    local previousHealth = State.lastKnownHealth or newHealth or 0
    State.lastKnownHealth = newHealth or previousHealth

    if not newHealth then
        return
    end

    if newHealth <= 0 then
        Safety.scheduleDeathCheck("Health reached 0")
        return
    end

    if newHealth < previousHealth then
        State.lastIncomingDamageAt = tick()
        Utils.recordEvent("Damage", string.format("%.1f -> %.1f", previousHealth, newHealth))
        if State.hideState.active or State.evacuating or State.mode == "hopping" then
            Safety.swapHideSpot("Damage while evacuating")
        end
    end
end

function Safety.clearForcedPosition(reasonMatch)
    if reasonMatch and State.forcedPosition and State.forcedPosition.reason ~= reasonMatch then
        return
    end

    if State.forcedPosition then
        Utils.recordEvent("Forced Clear", tostring(State.forcedPosition.reason or "Unknown"))
    end
    State.forcedPosition = nil
    if State.mode == "dodging" then
        if State.running and State.currentBoss and not State.hideState.active then
            Utils.setMode("engaging")
        else
            Utils.setMode("idle")
        end
    end
end

function Safety.getForcedPosition()
    local forced = State.forcedPosition
    if not forced then return nil end

    if forced.expiresAt ~= 0 and tick() >= forced.expiresAt then
        Safety.clearForcedPosition()
        return nil
    end

    return forced
end

function Safety.setForcedPosition(position, duration, priority, reason)
    if not position then return end

    priority = priority or 0
    local current = Safety.getForcedPosition()
    if current and current.priority and current.priority > priority then
        return
    end

    State.forcedPosition = {
        position = position,
        expiresAt = (duration and duration > 0) and (tick() + duration) or 0,
        priority = priority,
        reason = reason,
    }
    Utils.recordEvent("Forced Position", tostring(reason or "Unknown") .. " -> " .. Utils.formatVector3(position))

    if not State.hideState.active and State.mode ~= "hopping" and State.mode ~= "regen" and State.mode ~= "looting" then
        Utils.setMode("dodging")
    end
end

function Safety.pauseForThreat()
    State.panicId = State.panicId + 1
    State.runId = State.runId + 1
    State.running = false
    State.evacuating = true
    State.isLooting = false
    Charging.stop()
    Farm.stopCurrent()
    if State.farmThread then pcall(task.cancel, State.farmThread); State.farmThread = nil end
    if State.bossLoopThread then pcall(task.cancel, State.bossLoopThread); State.bossLoopThread = nil end
end

function Safety.startHop(reason)
    if State.serverHopInProgress then return end

    State.serverHopInProgress = true
    State.hideState.hopStarted = true
    State.hideState.keepHoldingDuringHop = not (type(reason) == "string" and string.find(reason, "Loop complete", 1, true) ~= nil)
    Utils.setMode("hopping")
    Utils.log("Evacuating: " .. tostring(reason))
    Utils.writeDebugSnapshot("startHop: " .. tostring(reason))
    Utils.notify("Evacuating: " .. tostring(reason), 5)
    Webhook.send("⚠️ Evacuating & Hopping", reason or "Unknown danger", 15158332)
    ServerHop.execute(true)
end

function Safety.enterHide(reason)
    local now = tick()

    if State.hideState.active then
        State.hideState.reason = reason or State.hideState.reason
        State.hideState.lastDangerAt = now
        if BossFarm.Settings.HideThenHopOnThreat then
            Safety.startHop(reason or State.hideState.reason)
        end
        return
    end

    local wasLoop = BossFarm.Settings.BossLoopEnabled == true
    local resumeSingle = BossFarm.Settings.Enabled == true and not wasLoop
    local resumeIndex = State.bossLoopIndex or 0

    Safety.pauseForThreat()

    State.hideState = {
        active = true,
        spot = Safety.getSafeSpot(),
        reason = reason,
        startedAt = now,
        lastDangerAt = now,
        hopDeadline = now + (BossFarm.Settings.HideThreatTimeout or 30),
        hardHoldUntil = now + 0.15,
        wasLoop = wasLoop,
        resumeSingle = resumeSingle,
        resumeIndex = resumeIndex,
        hopStarted = false,
        keepHoldingDuringHop = false,
    }

    Utils.setMode("hiding")
    Utils.log("Hiding: " .. tostring(reason))
    Utils.recordEvent("Hide Enter", tostring(reason))
    Utils.notify("Hiding at Safe Spot...", 4)
    Safety.forceTeleport(State.hideState.spot)

    if BossFarm.Settings.HideThenHopOnThreat then
        Safety.startHop(reason)
    end
end

function Safety.resumeAfterHide()
    if State.serverHopInProgress then return end

    local hideState = State.hideState
    State.hideState = newHideState()
    State.evacuating = false
    State.running = false
    Safety.clearForcedPosition()
    Utils.setMode("idle")
    Utils.recordEvent("Hide Resume", tostring(hideState.reason or "Unknown"))

    if hideState.wasLoop and BossFarm.Settings.BossLoopEnabled then
        State.bossLoopIndex = hideState.resumeIndex or 0
        Utils.notify("Coast is clear! Resuming Loop...", 4)
        BossLoop.start()
    elseif hideState.resumeSingle and BossFarm.Settings.Enabled then
        Utils.notify("Coast is clear! Resuming Farm...", 4)
        Farm.start()
    end
end

function Safety.startWorkers()
    if State.workersActive then return end

    State.workersActive = true
    State.threatCache = newThreatCache()
    State.serverHopInProgress = false
    State.deathQuitTriggered = false
    State.deathCheckInProgress = false
    State.deathCheckToken = 0
    State.lastIncomingDamageAt = 0
    Safety.captureLifeForceBaseline()

    Safety.startLocalCharacterWatcher()
    for _, player in ipairs(Players:GetPlayers()) do
        Safety.ensurePlayerWatcher(player)
    end
    Safety.refreshSettingsFolder()

    Utils.addWorkerConnection(Players.PlayerAdded:Connect(function(player)
        Safety.ensurePlayerWatcher(player)
    end))
    Utils.addWorkerConnection(Players.PlayerRemoving:Connect(function(player)
        Safety.destroyPlayerWatcher(player)
    end))
 
    Utils.addWorkerThread(task.spawn(function()
        while State.workersActive do
            Safety.updateThreatCache()
            task.wait()
        end
    end))

    Utils.addWorkerConnection(RunService.Heartbeat:Connect(function()
        local forced = Safety.getForcedPosition()
        local hasThreat, threatReason = Safety.getThreatReason()

        if State.hideState.active then
            local playerData = Utils.getPlayerData()
            local hideSpot = Safety.getSafeSpot()
            if State.hideState.spot == nil then
                State.hideState.spot = hideSpot
            else
                hideSpot = State.hideState.spot
            end

            if State.lastIncomingDamageAt ~= 0 and tick() - State.lastIncomingDamageAt <= 1 then
                Safety.swapHideSpot("Recent damage while hidden")
                hideSpot = State.hideState.spot
            end

            if playerData and hideSpot and (not State.hideState.hopStarted or State.hideState.keepHoldingDuringHop) then
                local currentPos = playerData.rootPart.Position
                local horizontalDist = Vector3.new(currentPos.X - hideSpot.X, 0, currentPos.Z - hideSpot.Z).Magnitude
                local recentDamage = State.lastIncomingDamageAt ~= 0 and tick() - State.lastIncomingDamageAt <= 1
                local hardHoldActive = (State.hideState.hardHoldUntil or 0) > tick()
                local softHide = Safety.isSoftHideReason(State.hideState.reason) and not recentDamage

                if hardHoldActive then
                    playerData.rootPart.CFrame = CFrame.new(hideSpot)
                elseif softHide then
                    if horizontalDist > 35 then
                        playerData.rootPart.CFrame = CFrame.new(hideSpot)
                    else
                        if not State.hideState.lastWalkTick then
                            State.hideState.lastWalkTick = 0
                        end
                        if tick() - State.hideState.lastWalkTick >= 1.5 then
                            State.hideState.lastWalkTick = tick()
                            Utils.randomWalkAt(hideSpot, 6)
                        end
                    end
                else
                    playerData.rootPart.CFrame = CFrame.new(hideSpot)
                end
            end

            if hasThreat then
                State.hideState.lastDangerAt = tick()
            end

            if not State.hideState.hopStarted then
                local activeReason = threatReason or State.hideState.reason
                if Safety.shouldImmediateHopHide(activeReason) then
                    Safety.startHop(activeReason)
                elseif BossFarm.Settings.HideThenHopOnThreat then
                    Safety.startHop(State.hideState.reason or threatReason)
                elseif hasThreat and tick() >= State.hideState.hopDeadline then
                    Safety.startHop("Danger > " .. tostring(BossFarm.Settings.HideThreatTimeout or 30) .. "s (" .. tostring(threatReason or State.hideState.reason or "Unknown") .. ")")
                elseif not hasThreat and tick() - State.hideState.lastDangerAt >= getHideResumeClearTime(State.hideState.reason) then
                    Safety.resumeAfterHide()
                end
            end
            return
        end

        if hasThreat and (State.running or BossFarm.Settings.Enabled or BossFarm.Settings.BossLoopEnabled) and State.mode ~= "hopping" then
            Safety.enterHide(threatReason)
            return
        end

        if forced and not State.hideState.active and State.mode ~= "hopping" then
            local playerData = Utils.getPlayerData()
            if playerData then
                playerData.rootPart.CFrame = CFrame.new(forced.position)
            end
        end
    end))
end

function Safety.stopWorkers()
    State.workersActive = false
    Utils.disconnectWorkerConnections()
    Utils.cancelWorkerThreads()
    Utils.disconnectConnections(State.localCharacterConnections)
    State.localCharacterDescendantConnections = State.localCharacterDescendantConnections or {}
    State.localCharacterStatusConnections = State.localCharacterStatusConnections or {}
    Utils.disconnectConnections(State.localCharacterDescendantConnections)
    Utils.disconnectConnections(State.localCharacterStatusConnections)
    Utils.disconnectConnections(State.settingsConnections)

    local playersToClear = {}
    for player in pairs(State.playerWatchers) do
        table.insert(playersToClear, player)
    end
    for _, player in ipairs(playersToClear) do
        Safety.destroyPlayerWatcher(player)
    end

    State.playerWatchers = {}
    State.characterBaseParts = {}
    State.hideState = newHideState()
    State.threatCache = newThreatCache()
    State.serverHopInProgress = false
    State.workersActive = false
    State.lastIncomingDamageAt = 0
    State.lastKnownHealth = 0
    Safety.clearForcedPosition()
end

function Safety.startMonitor()
    Safety.startWorkers()
end

function Safety.evacuateAndHop(reason)
    Safety.enterHide(reason)
    Safety.startHop(reason)
end

function Safety.evacuateAndHide(reason)
    Safety.enterHide(reason)
end

-- ============================================
-- BOSS DETECTION
-- ============================================
local Detection = {}

function Detection.isTemporarilySkipped(bossName)
    local expiresAt = State.skippedBossUntil and State.skippedBossUntil[bossName]
    return expiresAt and expiresAt > tick()
end

function Detection.findBoss(bossName)
    if Detection.isTemporarilySkipped(bossName) then
        return nil, nil
    end

    -- Search workspace root, NPCs, Mobs, Enemies folders
    for _, folderName in ipairs({"NPCs", "Mobs", "Enemies"}) do
        local folder = workspace:FindFirstChild(folderName)
        if folder then
            for _, model in ipairs(folder:GetChildren()) do
                if model:IsA("Model") and model.Name == bossName then
                    local hum = model:FindFirstChildOfClass("Humanoid")
                    if hum and hum.Health > 0 then return hum, model end
                end
            end
        end
    end
    -- Search workspace root
    for _, child in ipairs(workspace:GetChildren()) do
        if child.Name == bossName and child:IsA("Model") then
            local hum = child:FindFirstChildOfClass("Humanoid")
            if hum and hum.Health > 0 then return hum, child end
        end
    end
    return nil, nil
end

function Detection.findAnySelectedBoss()
    for bossName, isSelected in pairs(BossFarm.Settings.SelectedBosses) do
        if isSelected then
            local hum, model = Detection.findBoss(bossName)
            if hum and model then return hum, model, bossName end
        end
    end
    return nil, nil, nil
end

function Detection.triggerSpawnIfNeeded(bossName, config)
    if Detection.isTemporarilySkipped(bossName) then
        return false
    end

    if not config.triggerSpawn then return false end
    
    local targetPos = nil
    if config.triggerPos then
        targetPos = config.triggerPos
    elseif bossName == "Lava Snake" then
        targetPos = Vector3.new(-547.6, -541.7, -1281.8)
    end
    
    if targetPos then
        local contested, nearPlayer = Safety.isPlayerNearPosition(targetPos, BossFarm.Settings.PlayerDetectionRadius)
        if contested then
            Safety.evacuateAndHide("Players at " .. bossName .. " spawn! (" .. tostring(nearPlayer) .. ")")
            return false
        end
        
        local pData = Utils.getPlayerData()
        if pData then
            pData.rootPart.CFrame = CFrame.new(targetPos)
        end
        task.wait(2)
        return true
    end
    return false
end

function Detection.waitForBossSpawn(bossName, config, timeout)
    timeout = timeout or 16
    Detection.triggerSpawnIfNeeded(bossName, config)
    if not State.running then return nil, nil end
    
    local start = tick()
    repeat
        local hum, model = Detection.findBoss(bossName)
        if hum and model then return hum, model end
        task.wait(1)
    until tick() - start >= timeout
    
    return nil, nil
end

-- ============================================
-- PER-BOSS ANIMATION MONITORS
-- ============================================
local AnimMonitors = {}

-- Generic animation monitor (for bosses with simple danger anims)
function AnimMonitors.setupGeneric(model, config)
    if not config.dangerousAnimations then return end
    local hum = model:FindFirstChildOfClass("Humanoid")
    if not hum then return end
    local animator = hum:FindFirstChildOfClass("Animator")
    if not animator then return end
    
    Utils.addConnection(animator.AnimationPlayed:Connect(function(track)
        if not State.running then return end
        local assetId = track.Animation.AnimationId:match("rbxassetid://(%d+)") or track.Animation.AnimationId
        if config.dangerousAnimations[assetId] then
            if config.animationResponse == "teleport" and config.safePosition then
                Safety.setForcedPosition(config.safePosition, 1.25, GENERIC_DODGE_PRIORITY, tostring(model.Name) .. " danger")
            else
                local boost = config.safeHeightBoost or 15
                State.bossHeightBoost = boost
                State.inDanger = true
                
                Utils.addThread(task.spawn(function()
                    while track and track.IsPlaying and State.running do task.wait(0.1) end
                    task.wait(0.5)
                    State.bossHeightBoost = 0
                    State.inDanger = false
                end))
            end
        end
    end))
end

-- Hyuga Boss: arena enforcement + dangerous animation dodge
function AnimMonitors.setupHyuga(model)
    local bossRoot = model:FindFirstChild("HumanoidRootPart")
    if not bossRoot then return end
    
    Utils.addThread(task.spawn(function()
        -- Initial approach height reduction
        State.bossHeightBoost = -2
        task.wait(5)
        if State.bossHeightBoost == -2 then State.bossHeightBoost = 0 end
    end))
    
    Utils.addThread(task.spawn(function()
        local currentRunId = State.runId
        local lastEscapeTeleport = 0

        while State.running and model and model.Parent and State.runId == currentRunId do
            local bossPosition = bossRoot.Position
            local playerData = Utils.getPlayerData()
            local playerPosition = playerData and playerData.rootPart.Position or nil
            local playerOutsideArena = false

            if playerData and State.currentBoss == "Hyuga Boss" then
                if not Utils.isInsideRegion(playerPosition, HYUGA_ARENA_REGION_MIN, HYUGA_ARENA_REGION_MAX) then
                    playerOutsideArena = true
                else
                    for i = 1, #State.characterBaseParts do
                        local part = State.characterBaseParts[i]
                        if part and part.Parent and not Utils.isInsideRegion(part.Position, HYUGA_ARENA_REGION_MIN, HYUGA_ARENA_REGION_MAX) then
                            playerOutsideArena = true
                            break
                        end
                    end
                end
            end

            if not Utils.isInsideRegion(bossPosition, HYUGA_ARENA_REGION_MIN, HYUGA_ARENA_REGION_MAX) then
                if not State.hyugaArenaUnsafe then
                    State.hyugaArenaUnsafe = true
                    State.hyugaArenaUnsafeSince = tick()
                    Utils.log("Hyuga left arena. Holding escape spot.")
                end

                Safety.setForcedPosition(HYUGA_ARENA_ESCAPE_SPOT, 0.25, HYUGA_ARENA_ESCAPE_PRIORITY, "Hyuga arena unsafe")

                if playerData then
                    local dist = (playerData.rootPart.Position - HYUGA_ARENA_ESCAPE_SPOT).Magnitude
                    if dist > 12 and (tick() - lastEscapeTeleport) >= 0.2 then
                        lastEscapeTeleport = tick()
                        Utils.safeTeleport(CFrame.new(HYUGA_ARENA_ESCAPE_SPOT))
                    else
                        playerData.rootPart.CFrame = CFrame.new(HYUGA_ARENA_ESCAPE_SPOT)
                    end
                end

                if tick() - State.hyugaArenaUnsafeSince >= 30 then
                    State.hyugaArenaTimeoutRequested = true
                    State.skippedBossUntil["Hyuga Boss"] = tick() + 30
                    Utils.log("Hyuga stayed outside arena for 30s. Skipping.", "warn")
                    return
                end
            elseif playerData
                and playerOutsideArena
                and State.mode == "engaging"
                and not State.evacuating
                and not State.hideState.active
                and not State.serverHopInProgress
                and not Safety.getForcedPosition()
                then
                if tick() - lastEscapeTeleport >= 0.2 then
                    lastEscapeTeleport = tick()
                    Utils.log("Player body left Hyuga arena. Pulling back to safe spot.")
                    Utils.safeTeleport(CFrame.new(HYUGA_ARENA_ESCAPE_SPOT))
                else
                    playerData.rootPart.CFrame = CFrame.new(HYUGA_ARENA_ESCAPE_SPOT)
                end
            elseif State.hyugaArenaUnsafe then
                State.hyugaArenaUnsafe = false
                State.hyugaArenaUnsafeSince = 0
                Safety.clearForcedPosition("Hyuga arena unsafe")
            end

            RunService.Heartbeat:Wait()
        end
        State.hyugaArenaUnsafe = false
        State.hyugaArenaUnsafeSince = 0
        Safety.clearForcedPosition("Hyuga arena unsafe")
    end))
    
    -- Hyuga dangerous animations
    local hum = model:FindFirstChildOfClass("Humanoid")
    if not hum then return end
    local animator = hum:FindFirstChildOfClass("Animator")
    if not animator then return end
    
    local dangerAnims = { ["8699113073"] = true, ["8580099842"] = true }
    Utils.addConnection(animator.AnimationPlayed:Connect(function(track)
        if not State.running then return end
        local assetId = track.Animation.AnimationId:match("rbxassetid://(%d+)") or track.Animation.AnimationId
        if dangerAnims[assetId] then
            local currentRunId = State.runId
            Utils.addThread(task.spawn(function()
                while track and track.IsPlaying and State.running and State.runId == currentRunId and State.currentBoss == "Hyuga Boss" do
                    Safety.setForcedPosition(HYUGA_DANGER_DODGE_SPOT, 0.4, HYUGA_DODGE_PRIORITY, "Hyuga danger")
                    task.wait()
                end
                if State.runId == currentRunId then
                    Safety.setForcedPosition(HYUGA_DANGER_DODGE_SPOT, 0.6, HYUGA_DODGE_PRIORITY, "Hyuga danger")
                end
            end))
        end
    end))
end

function AnimMonitors.setupWoodenGolem(model, config)
    if not config or not config.dangerousAnimations then return end

    local hum = model:FindFirstChildOfClass("Humanoid")
    if not hum then return end
    local animator = hum:FindFirstChildOfClass("Animator")
    if not animator then return end

    local function abortOrbitIfUnsafe(currentRunId)
        if State.runId ~= currentRunId
            or not State.running
            or State.evacuating
            or State.hideState.active
            or State.mode == "hopping"
            or State.currentBoss ~= "Wooden Golem" then
            return true
        end

        local hasThreat, threatReason = Safety.getThreatReason()
        if hasThreat then
            Safety.enterHide(threatReason or "Wooden Golem danger interrupted")
            return true
        end

        return false
    end

    Utils.addConnection(animator.AnimationPlayed:Connect(function(track)
        if not State.running then return end

        local assetId = track.Animation.AnimationId:match("rbxassetid://(%d+)") or track.Animation.AnimationId
        if not config.dangerousAnimations[assetId] then
            return
        end

        local currentRunId = State.runId
        Utils.addThread(task.spawn(function()
            local deadline = tick() + WOODEN_GOLEM_DODGE_DURATION
            local currentIndex = 1
            local currentSpot = WOODEN_GOLEM_DODGE_SPOTS[currentIndex]

            if abortOrbitIfUnsafe(currentRunId) then
                return
            end

            Safety.setForcedPosition(currentSpot, WOODEN_GOLEM_TWEEN_DURATION + 0.01, WOODEN_GOLEM_DODGE_PRIORITY, "Wooden Golem danger")
            local playerData = Utils.getPlayerData()
            if playerData then
                playerData.rootPart.CFrame = CFrame.new(currentSpot)
            end

            while tick() < deadline do
                if abortOrbitIfUnsafe(currentRunId) then
                    return
                end

                local nextIndex = currentIndex + 1
                if nextIndex > #WOODEN_GOLEM_DODGE_SPOTS then
                    nextIndex = 1
                end

                local nextSpot = WOODEN_GOLEM_DODGE_SPOTS[nextIndex]
                local segmentStart = tick()

                while tick() < deadline do
                    if abortOrbitIfUnsafe(currentRunId) then
                        return
                    end

                    local elapsed = tick() - segmentStart
                    local alpha = math.clamp(elapsed / WOODEN_GOLEM_TWEEN_DURATION, 0, 1)
                    local position = currentSpot:Lerp(nextSpot, alpha)

                    Safety.setForcedPosition(position, WOODEN_GOLEM_TWEEN_DURATION + 0.05, WOODEN_GOLEM_DODGE_PRIORITY, "Wooden Golem danger")
                    local orbitPlayerData = Utils.getPlayerData()
                    if orbitPlayerData then
                        orbitPlayerData.rootPart.CFrame = CFrame.new(position)
                    end

                    if alpha >= 1 then
                        break
                    end

                    RunService.Heartbeat:Wait()
                end

                currentIndex = nextIndex
                currentSpot = nextSpot
            end

            if not abortOrbitIfUnsafe(currentRunId) then
                Safety.setForcedPosition(currentSpot, 0.15, WOODEN_GOLEM_DODGE_PRIORITY, "Wooden Golem danger")
            end
        end))
    end))
end

-- Haku Boss: Ice Dragon dodge
function AnimMonitors.setupHaku()
    local debris = workspace:FindFirstChild("Debris")
    
    local function monitorDebris(debrisFolder)
        Utils.addConnection(debrisFolder.ChildAdded:Connect(function(child)
            if not State.running then return end
            local dur = nil
            if child.Name == "IceDragonHead" then dur = 4
            elseif child:IsA("Beam") and child.Name == "Beam121" then dur = 1
            end
            
            if dur then
                State.hakuSafeSpot = true
                State.hakuSafeSpotEndTime = tick() + dur
                Safety.setForcedPosition(HAKU_SAFE_SPOT, dur + 0.15, HAKU_FORCE_PRIORITY, "Haku danger")
            end
        end))
    end
    
    if debris then
        monitorDebris(debris)
    else
        -- Wait for Debris folder to appear
        local conn
        conn = workspace.ChildAdded:Connect(function(c)
            if c.Name == "Debris" then
                conn:Disconnect()
                monitorDebris(c)
            end
        end)
        Utils.addConnection(conn)
    end
end

-- Ringed Samurai: dodge slam
function AnimMonitors.setupRingedSamurai(model)
    local hum = model:FindFirstChildOfClass("Humanoid")
    if not hum then return end
    local animator = hum:FindFirstChildOfClass("Animator")
    if not animator then return end
    
    Utils.addConnection(animator.AnimationPlayed:Connect(function(track)
        if not State.running then return end
        local assetId = track.Animation.AnimationId:match("rbxassetid://(%d+)") or track.Animation.AnimationId
        if assetId == "137738911755203" then
            local currentRunId = State.runId
            Utils.addThread(task.spawn(function()
                Safety.forceTeleport(HYUGA_ARENA_ESCAPE_SPOT)
                while track and track.IsPlaying and State.running and State.runId == currentRunId and State.currentBoss == "The Ringed Samurai" do
                    Safety.setForcedPosition(HYUGA_ARENA_ESCAPE_SPOT, 0.2, RINGED_SAMURAI_DODGE_PRIORITY, "Ringed Samurai danger")
                    task.wait()
                end
                if State.runId == currentRunId and State.currentBoss == "The Ringed Samurai" then
                    Safety.setForcedPosition(HYUGA_ARENA_ESCAPE_SPOT, 0.35, RINGED_SAMURAI_DODGE_PRIORITY, "Ringed Samurai danger")
                end
            end))
        end
    end))
end

-- Setup all animation monitors for a given boss
function AnimMonitors.setup(model, bossName, config)
    State.bossHeightBoost = 0
    State.hyugaArenaUnsafe = false
    State.hyugaArenaUnsafeSince = 0
    State.hyugaArenaTimeoutRequested = false
    State.hakuSafeSpot = false
    Safety.clearForcedPosition()
    
    if bossName == "Hyuga Boss" then
        AnimMonitors.setupHyuga(model)
    elseif bossName == "Wooden Golem" then
        AnimMonitors.setupWoodenGolem(model, config)
    elseif bossName == "Haku Boss" then
        AnimMonitors.setupHaku()
    elseif bossName == "The Ringed Samurai" then
        AnimMonitors.setupRingedSamurai(model)
    end
    
    -- Generic animation handler for all bosses that define dangerousAnimations
    if config.dangerousAnimations and next(config.dangerousAnimations) then
        -- Don't double-setup for bosses with dedicated handlers
        if bossName ~= "Hyuga Boss" and bossName ~= "Wooden Golem" then
            AnimMonitors.setupGeneric(model, config)
        end
    end
end

-- ============================================
-- KNOCKED DETECTION + AUTO GRIP
-- ============================================
local Knocked = {}

function Knocked.waitForBeingGripped(model, timeout)
    timeout = timeout or 6
    local start = tick()
    
    while tick() - start <= timeout do
        local bg = model and model.Parent and model:FindFirstChild("BeingGripped", true)
        local gripped = false
        pcall(function()
            if bg and (bg.Value == true or bg.Value == "ON" or bg.Value == 1) then
                gripped = true
            end
        end)
        if gripped then return true end
        task.wait(0.15)
    end
    return false
end

function Knocked.findRingedSamuraiMinions(model)
    local config = BOSS_CONFIGS["The Ringed Samurai"] or {}
    local center = nil
    local bossRoot = Utils.getBossRoot(model)
    if bossRoot then
        center = bossRoot.Position
    else
        center = config.triggerPos
    end
    if not center then return {} end

    local radius = config.minionRadius or 100
    local results = {}

    local function scanContainer(container)
        if not container then return end
        for _, child in ipairs(container:GetChildren()) do
            if child ~= model and child:IsA("Model") then
                local lowerName = string.lower(child.Name)
                if string.find(lowerName, "lavalight", 1, true) then
                    local hum = child:FindFirstChildOfClass("Humanoid")
                    local root = Utils.getBossRoot(child)
                    if hum and hum.Health > 0 and root and (root.Position - center).Magnitude <= radius then
                        table.insert(results, {
                            model = child,
                            humanoid = hum,
                            root = root,
                            distance = (root.Position - center).Magnitude,
                        })
                    end
                end
            end
        end
    end

    scanContainer(workspace)
    scanContainer(workspace:FindFirstChild("NPCs"))
    scanContainer(workspace:FindFirstChild("Mobs"))
    scanContainer(workspace:FindFirstChild("Enemies"))

    table.sort(results, function(a, b)
        return a.distance < b.distance
    end)

    return results
end

function Knocked.clearRingedSamuraiMinions(model, dataEvent)
    local minions = Knocked.findRingedSamuraiMinions(model)
    if #minions == 0 then
        return false
    end

    Utils.recordEvent("Ringed Adds", "Found " .. tostring(#minions) .. " LavaLight")

    local config = BOSS_CONFIGS["The Ringed Samurai"] or {}
    local yOffset = config.minionHeight or 5.5

    for _, minionData in ipairs(minions) do
        if not State.running or State.currentBoss ~= "The Ringed Samurai" then
            break
        end

        local minion = minionData.model
        local hum = minionData.humanoid
        local root = Utils.getBossRoot(minion)
        if hum and hum.Health > 0 and root then
            Utils.recordEvent("Ringed Add Clear", tostring(minion.Name))

            local clearDeadline = tick() + 4
            while State.running and hum.Parent and hum.Health > 0 and root.Parent and tick() < clearDeadline do
                local pData = Utils.getPlayerData()
                if not pData then break end

                local holdPos = root.Position + Vector3.new(0, yOffset, 0)
                pData.rootPart.CFrame = CFrame.lookAt(holdPos, root.Position)
                pcall(function() dataEvent:FireServer("Dash", "Sub", root.Position) end)
                task.wait(0.03)
                pcall(function() dataEvent:FireServer("CheckMeleeHit", nil, "NormalAttack", false) end)
                task.wait(0.08)
            end
        end
    end

    return true
end

function Knocked.retryGripUntilSuccess(model, maxAttempts)
    maxAttempts = maxAttempts or 12
    local bossRoot = Utils.getBossRoot(model)
    if not bossRoot then return false end
    
    local dataEvent = GetDataEvent()
    if not dataEvent then return false end
    
    for _ = 1, maxAttempts do
        if State.currentBoss == "The Ringed Samurai" then
            local clearedAdds = Knocked.clearRingedSamuraiMinions(model, dataEvent)
            if clearedAdds then
                bossRoot = Utils.getBossRoot(model)
                if not bossRoot then return false end
            end
        end

        local pData = Utils.getPlayerData()
        if pData then
            pData.rootPart.CFrame = CFrame.new(bossRoot.Position)
        end
        
        task.wait(0.08)
        pcall(function() dataEvent:FireServer("Grip") end)
        
        if Knocked.waitForBeingGripped(model, 0.6) then
            return true
        end
    end
    return false
end

function Knocked.monitor(model)
    if State.knockedThread then pcall(task.cancel, State.knockedThread) end
    if not model then return end
    
    local settings = model:FindFirstChild("Settings")
    if not settings then return end
    local knocked = settings:FindFirstChild("Knocked")
    if not knocked then return end
    
    local currentRunId = State.runId
    State.knockedThread = task.spawn(function()
        while State.running and model and model.Parent and State.runId == currentRunId do
            local isKnocked = false
            pcall(function()
                if knocked.Value == true
                    or (type(knocked.Value) == "string" and knocked.Value:upper() == "ON")
                    or (type(knocked.Value) == "number" and knocked.Value ~= 0) then
                    isKnocked = true
                end
            end)
            
            if isKnocked then
                Utils.notify("Boss knocked! Gripping...", 2)
                
                -- Stop positioning + attacking while we grip
                if State.anchorConn then State.anchorConn:Disconnect(); State.anchorConn = nil end
                if State.attackThread then pcall(task.cancel, State.attackThread); State.attackThread = nil end
                Charging.stop()
                
                local success = Knocked.retryGripUntilSuccess(model, 12)
                if success then
                    Utils.notify("Grip confirmed!", 2)
                else
                    Utils.notify("Grip retry timed out.", 2)
                end
                
                task.wait(0.5)
                -- Signal death to farmBoss so it handles loot collection properly
                -- Do NOT call Farm.stopCurrent() here — it resets State.currentBoss
                -- which causes farmBoss to exit the loop before reaching loot collection
                State.bossDeathDetected = true
                return
            end
            task.wait(0.2)
        end
    end)
end

-- ============================================
-- AUTO LOOT (PARTIAL)
-- ============================================
local Loot = {}
-- [TRUNCATED]
