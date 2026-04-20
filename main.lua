-- ================================================================
-- ESP by lrnz — Bloodlines Exploit Suite
-- Main Entry Point: FluentUI Menu + All Module Integration
-- ================================================================
-- Loads: FluentUI (GitHub), SaveManager (GitHub), InterfaceManager (GitHub)
-- Loads: All handlers from LOCAL workspace files via readfile()
-- ================================================================

-- ================================================================
-- 1. SERVICES
-- ================================================================
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local LocalPlayer = Players.LocalPlayer

-- ================================================================
-- 2. LOAD FLUENT UI + ADDONS (Only GitHub calls in the entire script)
-- ================================================================
local Fluent = loadstring(game:HttpGet("https://github.com/dawid-scripts/Fluent/releases/latest/download/main.lua"))()
local SaveManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/SaveManager.lua"))()
local InterfaceManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/InterfaceManager.lua"))()

-- ================================================================
-- 3. LOAD LOCAL HANDLERS (readfile from executor workspace)
-- ================================================================
local function safeLoadModule(filename)
    local ok, result = pcall(function()
        if not readfile then
            warn("[Main] readfile not available. Cannot load: " .. filename)
            return nil
        end
        if isfile and not isfile(filename) then
            warn("[Main] File not found: " .. filename)
            return nil
        end
        return loadstring(readfile(filename))()
    end)
    if ok and result then
        print("[Main] ✅ Loaded: " .. filename)
        return result
    else
        warn("[Main] ❌ Failed to load: " .. filename .. " — " .. tostring(result))
        return nil
    end
end

local PlayerESPHandler = safeLoadModule("PlayerESPHandler.lua")
local MobESPHandler = safeLoadModule("MobESPHandler.lua")
local ItemESPHandler = safeLoadModule("ItemESPHandler.lua")
local ChakraESPHandler = safeLoadModule("ChakraESPHandler.lua")
local CorruptedESPHandler = safeLoadModule("CorruptedESPHandler.lua")
local AutoFarmHandler = safeLoadModule("AutoFarmHandler.lua")

-- Instantiate handlers that use .new() constructor
local playerESP = PlayerESPHandler and PlayerESPHandler.new() or nil
local mobESP = MobESPHandler and MobESPHandler.new() or nil
local itemESP = ItemESPHandler and ItemESPHandler.new() or nil
local chakraESP = ChakraESPHandler and ChakraESPHandler.new() or nil
local corruptedESP = CorruptedESPHandler and CorruptedESPHandler.new() or nil

-- ================================================================
-- 4. PLAYER FEATURES (Inline — no external handler needed)
-- ================================================================
local PlayerFeatures = {
    -- State
    NoclipEnabled = false,
    FlyEnabled = false,
    OriginalWalkSpeed = 16,
    OriginalJumpPower = 50,
    -- Connections
    _noclipConn = nil,
    _flyConn = nil,
    _flyBodyVelocity = nil,
    _flyBodyGyro = nil,
}

-- ---- NOCLIP ----
function PlayerFeatures.startNoclip()
    if PlayerFeatures._noclipConn then return end
    PlayerFeatures.NoclipEnabled = true
    PlayerFeatures._noclipConn = RunService.Stepped:Connect(function()
        if not PlayerFeatures.NoclipEnabled then return end
        local char = LocalPlayer.Character
        if not char then return end
        for _, part in ipairs(char:GetDescendants()) do
            if part:IsA("BasePart") then
                part.CanCollide = false
            end
        end
    end)
    print("[Player] Noclip ON")
end

function PlayerFeatures.stopNoclip()
    PlayerFeatures.NoclipEnabled = false
    if PlayerFeatures._noclipConn then
        PlayerFeatures._noclipConn:Disconnect()
        PlayerFeatures._noclipConn = nil
    end
    -- Restore collisions
    local char = LocalPlayer.Character
    if char then
        for _, part in ipairs(char:GetDescendants()) do
            if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
                part.CanCollide = true
            end
        end
    end
    print("[Player] Noclip OFF")
end

-- ---- FLY ----
function PlayerFeatures.startFly()
    if PlayerFeatures.FlyEnabled then return end
    PlayerFeatures.FlyEnabled = true

    local char = LocalPlayer.Character
    if not char then return end
    local rootPart = char:FindFirstChild("HumanoidRootPart")
    local humanoid = char:FindFirstChildOfClass("Humanoid")
    if not rootPart or not humanoid then return end

    -- Create BodyGyro for rotation
    local bg = Instance.new("BodyGyro")
    bg.P = 9e4
    bg.D = 500
    bg.MaxTorque = Vector3.new(9e9, 9e9, 9e9)
    bg.Parent = rootPart
    PlayerFeatures._flyBodyGyro = bg

    -- Create BodyVelocity for movement
    local bv = Instance.new("BodyVelocity")
    bv.MaxForce = Vector3.new(9e9, 9e9, 9e9)
    bv.Velocity = Vector3.new(0, 0, 0)
    bv.Parent = rootPart
    PlayerFeatures._flyBodyVelocity = bv

    local flySpeed = humanoid.WalkSpeed
    if flySpeed < 50 then flySpeed = 50 end

    PlayerFeatures._flyConn = RunService.Heartbeat:Connect(function()
        if not PlayerFeatures.FlyEnabled then return end
        local cam = Workspace.CurrentCamera
        if not cam then return end

        -- Keep the BodyGyro pointing at camera look direction
        bg.CFrame = cam.CFrame

        local moveDir = Vector3.new(0, 0, 0)
        if UserInputService:IsKeyDown(Enum.KeyCode.W) then
            moveDir = moveDir + cam.CFrame.LookVector
        end
        if UserInputService:IsKeyDown(Enum.KeyCode.S) then
            moveDir = moveDir - cam.CFrame.LookVector
        end
        if UserInputService:IsKeyDown(Enum.KeyCode.A) then
            moveDir = moveDir - cam.CFrame.RightVector
        end
        if UserInputService:IsKeyDown(Enum.KeyCode.D) then
            moveDir = moveDir + cam.CFrame.RightVector
        end
        if UserInputService:IsKeyDown(Enum.KeyCode.Space) then
            moveDir = moveDir + Vector3.new(0, 1, 0)
        end
        if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then
            moveDir = moveDir - Vector3.new(0, 1, 0)
        end

        if moveDir.Magnitude > 0 then
            bv.Velocity = moveDir.Unit * flySpeed
        else
            bv.Velocity = Vector3.new(0, 0, 0)
        end
    end)
    print("[Player] Fly ON")
end

function PlayerFeatures.stopFly()
    PlayerFeatures.FlyEnabled = false
    if PlayerFeatures._flyConn then
        PlayerFeatures._flyConn:Disconnect()
        PlayerFeatures._flyConn = nil
    end
    if PlayerFeatures._flyBodyVelocity then
        PlayerFeatures._flyBodyVelocity:Destroy()
        PlayerFeatures._flyBodyVelocity = nil
    end
    if PlayerFeatures._flyBodyGyro then
        PlayerFeatures._flyBodyGyro:Destroy()
        PlayerFeatures._flyBodyGyro = nil
    end
    print("[Player] Fly OFF")
end

-- ---- SPEED ----
function PlayerFeatures.setWalkSpeed(value)
    local char = LocalPlayer.Character
    if not char then return end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if hum then hum.WalkSpeed = value end
end

function PlayerFeatures.setJumpPower(value)
    local char = LocalPlayer.Character
    if not char then return end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if hum then hum.JumpPower = value end
end

-- Keep speed persistent across respawns
local function onCharacterAdded(char)
    char:WaitForChild("Humanoid", 10)
    task.wait(0.5) -- Let the game set its defaults first
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum then return end

    -- Re-apply speed values from Fluent Options if they exist
    if Fluent and Fluent.Options then
        if Fluent.Options.WalkSpeed then
            hum.WalkSpeed = Fluent.Options.WalkSpeed.Value
        end
        if Fluent.Options.JumpPower then
            hum.JumpPower = Fluent.Options.JumpPower.Value
        end
    end

    -- Re-enable features that were active
    if PlayerFeatures.FlyEnabled then
        PlayerFeatures.stopFly()
        task.wait(0.2)
        PlayerFeatures.startFly()
    end
end
LocalPlayer.CharacterAdded:Connect(onCharacterAdded)

-- ================================================================
-- 5. CREATE FLUENT WINDOW
-- ================================================================
local Window = Fluent:CreateWindow({
    Title = "ESP by lrnz",
    SubTitle = "Bloodlines",
    TabWidth = 160,
    Size = UDim2.fromOffset(580, 480),
    Acrylic = false, -- Desativa blur para evitar detecção
    Theme = "Dark",
    MinimizeKey = Enum.KeyCode.RightControl
})

local Options = Fluent.Options

-- ================================================================
-- 6. TABS
-- ================================================================
local Tabs = {
    Player   = Window:AddTab({ Title = "Player",    Icon = "user" }),
    ESP      = Window:AddTab({ Title = "ESP",       Icon = "eye" }),
    AutoFarm = Window:AddTab({ Title = "Auto Farm", Icon = "wheat" }),
    Settings = Window:AddTab({ Title = "Settings",  Icon = "settings" }),
}

-- ================================================================
-- 7. TAB: PLAYER
-- ================================================================
do
    Tabs.Player:AddParagraph({
        Title = "Movimento",
        Content = "Controles de velocidade e mobilidade do personagem."
    })

    -- WalkSpeed Slider
    local WalkSpeedSlider = Tabs.Player:AddSlider("WalkSpeed", {
        Title = "WalkSpeed",
        Description = "Velocidade de caminhada do personagem.",
        Default = 16,
        Min = 16,
        Max = 500,
        Rounding = 0,
        Callback = function(value)
            PlayerFeatures.setWalkSpeed(value)
        end
    })

    -- JumpPower Slider
    local JumpPowerSlider = Tabs.Player:AddSlider("JumpPower", {
        Title = "JumpPower",
        Description = "Força do pulo do personagem.",
        Default = 50,
        Min = 50,
        Max = 500,
        Rounding = 0,
        Callback = function(value)
            PlayerFeatures.setJumpPower(value)
        end
    })

    -- Noclip Toggle
    Tabs.Player:AddToggle("Noclip", {
        Title = "Noclip",
        Description = "Atravessa paredes e objetos sólidos.",
        Default = false,
    }):OnChanged(function()
        if Options.Noclip.Value then
            PlayerFeatures.startNoclip()
        else
            PlayerFeatures.stopNoclip()
        end
    end)

    -- Fly Toggle
    Tabs.Player:AddToggle("Fly", {
        Title = "Fly",
        Description = "Voe livremente. WASD + Space/Shift para subir/descer.",
        Default = false,
    }):OnChanged(function()
        if Options.Fly.Value then
            PlayerFeatures.startFly()
        else
            PlayerFeatures.stopFly()
        end
    end)
end

-- ================================================================
-- 8. TAB: ESP
-- ================================================================
do
    -- === Player ESP Section ===
    Tabs.ESP:AddParagraph({
        Title = "Player ESP",
        Content = "Mostra outros jogadores com informações de HP, arma e distância."
    })

    Tabs.ESP:AddToggle("PlayerESP", {
        Title = "Player ESP",
        Description = "Exibe nomes, HP e armas de outros jogadores.",
        Default = false,
    }):OnChanged(function()
        if not playerESP then return end
        if Options.PlayerESP.Value then
            playerESP:enable()
        else
            playerESP:disable()
        end
    end)

    -- === Mob & NPC ESP Section ===
    Tabs.ESP:AddParagraph({
        Title = "Entities",
        Content = "NPCs de diálogo (amarelo) e Mobs de combate (vermelho)."
    })

    Tabs.ESP:AddToggle("MobESP", {
        Title = "Mob ESP",
        Description = "Exibe mobs de combate com HP e distância.",
        Default = false,
    }):OnChanged(function()
        if not mobESP then return end
        mobESP:toggleMobs(Options.MobESP.Value)
    end)

    Tabs.ESP:AddToggle("NPCESP", {
        Title = "NPC ESP",
        Description = "Exibe NPCs de diálogo (amarelo).",
        Default = false,
    }):OnChanged(function()
        if not mobESP then return end
        mobESP:toggleNPCs(Options.NPCESP.Value)
    end)

    -- === Item ESP Section ===
    Tabs.ESP:AddParagraph({
        Title = "World Items",
        Content = "Trinkets (roxo), Frutas (verde) e Gems (ciano)."
    })

    Tabs.ESP:AddToggle("TrinketESP", {
        Title = "Trinket ESP",
        Description = "Exibe trinkets no chão (roxo).",
        Default = false,
    }):OnChanged(function()
        if not itemESP then return end
        itemESP:toggleCategory("Trinket", Options.TrinketESP.Value)
    end)

    Tabs.ESP:AddToggle("FruitESP", {
        Title = "Fruit ESP",
        Description = "Exibe frutas no chão (verde).",
        Default = false,
    }):OnChanged(function()
        if not itemESP then return end
        itemESP:toggleCategory("Fruit", Options.FruitESP.Value)
    end)

    Tabs.ESP:AddToggle("GemESP", {
        Title = "Gem ESP",
        Description = "Exibe gems no chão (ciano).",
        Default = false,
    }):OnChanged(function()
        if not itemESP then return end
        itemESP:toggleCategory("Gem", Options.GemESP.Value)
    end)

    -- === Map Points Section ===
    Tabs.ESP:AddParagraph({
        Title = "Map Points",
        Content = "Pontos de Chakra e Corrupted espalhados pelo mapa."
    })

    Tabs.ESP:AddToggle("ChakraESP", {
        Title = "Chakra Point ESP",
        Description = "Exibe todos os pontos de Chakra (ciano).",
        Default = false,
    }):OnChanged(function()
        if not chakraESP then return end
        if Options.ChakraESP.Value then
            chakraESP:enable()
        else
            chakraESP:disable()
        end
    end)

    Tabs.ESP:AddToggle("CorruptedESP", {
        Title = "Corrupted Point ESP",
        Description = "Exibe pontos corrompidos (roxo escuro).",
        Default = false,
    }):OnChanged(function()
        if not corruptedESP then return end
        if Options.CorruptedESP.Value then
            corruptedESP:enable()
        else
            corruptedESP:disable()
        end
    end)
end

-- ================================================================
-- 9. TAB: AUTO FARM
-- ================================================================
do
    Tabs.AutoFarm:AddParagraph({
        Title = "Fruit Farming",
        Content = "Controla o summon automático de frutas e a coleta."
    })

    Tabs.AutoFarm:AddToggle("AutoSummon", {
        Title = "Auto Summon",
        Description = "Ativa automaticamente a ferramenta de Fruit Summoning a cada 16s.",
        Default = false,
    }):OnChanged(function()
        if not AutoFarmHandler then return end
        AutoFarmHandler.toggleSummon(Options.AutoSummon.Value)
    end)

    Tabs.AutoFarm:AddToggle("AutoPickup", {
        Title = "Auto Pickup",
        Description = "Coleta frutas automaticamente dentro do range configurado.",
        Default = false,
    }):OnChanged(function()
        if not AutoFarmHandler then return end
        -- Se Auto Summon estiver ligado, ele já controla o pickup.
        -- Se não, toggle direto.
        if not Options.AutoSummon.Value then
            AutoFarmHandler.togglePickup(Options.AutoPickup.Value)
        end
    end)

    Tabs.AutoFarm:AddSlider("PickupRange", {
        Title = "Pickup Range",
        Description = "Raio de coleta em studs.",
        Default = 50,
        Min = 10,
        Max = 200,
        Rounding = 0,
        Callback = function(value)
            if AutoFarmHandler then
                AutoFarmHandler.Settings.PickupRange = value
            end
        end
    })

    Tabs.AutoFarm:AddParagraph({
        Title = "Segurança",
        Content = "Proteções contra detecção por outros jogadores."
    })

    Tabs.AutoFarm:AddToggle("HopOnDanger", {
        Title = "Server Hop on Danger",
        Description = "Troca de servidor automaticamente se um jogador se aproximar.",
        Default = true,
    }):OnChanged(function()
        if AutoFarmHandler then
            AutoFarmHandler.Settings.ServerHopOnDanger = Options.HopOnDanger.Value
        end
    end)

    Tabs.AutoFarm:AddToggle("HopOnSense", {
        Title = "Server Hop on Chakra Sense",
        Description = "Troca de servidor se alguém ativar Chakra Sense.",
        Default = true,
    }):OnChanged(function()
        if AutoFarmHandler then
            AutoFarmHandler.Settings.ServerHopOnChakraSense = Options.HopOnSense.Value
        end
    end)

    Tabs.AutoFarm:AddSlider("DangerRadius", {
        Title = "Danger Radius",
        Description = "Distância mínima para considerar um jogador como ameaça.",
        Default = 300,
        Min = 50,
        Max = 1000,
        Rounding = 0,
        Callback = function(value)
            if AutoFarmHandler then
                AutoFarmHandler.Settings.DangerRadius = value
            end
        end
    })

    -- Emergency Stop button
    Tabs.AutoFarm:AddButton({
        Title = "🚨 Emergency Stop",
        Description = "Para TODOS os sistemas de farm imediatamente.",
        Callback = function()
            if AutoFarmHandler then
                AutoFarmHandler.emergencyStop()
            end
            -- Reset the toggles in the UI
            pcall(function() Options.AutoSummon:SetValue(false) end)
            pcall(function() Options.AutoPickup:SetValue(false) end)
            Fluent:Notify({
                Title = "Emergency Stop",
                Content = "Todos os sistemas de farm foram desligados.",
                Duration = 4
            })
        end
    })
end

-- ================================================================
-- 10. TAB: SETTINGS
-- ================================================================
do
    SaveManager:SetLibrary(Fluent)
    InterfaceManager:SetLibrary(Fluent)

    SaveManager:IgnoreThemeSettings()
    SaveManager:SetIgnoreIndexes({})

    InterfaceManager:SetFolder("ESPbyLrnz")
    SaveManager:SetFolder("ESPbyLrnz/bloodlines")

    InterfaceManager:BuildInterfaceSection(Tabs.Settings)
    SaveManager:BuildConfigSection(Tabs.Settings)
end

-- ================================================================
-- 11. FINALIZE
-- ================================================================
Window:SelectTab(1)

Fluent:Notify({
    Title = "ESP by lrnz",
    Content = "Script carregado com sucesso!",
    Duration = 5
})

-- Auto-load saved config if one exists
SaveManager:LoadAutoloadConfig()

print("[Main] ✅ ESP by lrnz loaded successfully.")
