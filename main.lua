-- ================================================================
-- ESP by lrnz — Bloodlines Exploit Suite
-- Main Entry Point: FluentUI Menu + All Module Integration
-- ================================================================
-- GitHub Calls: FluentUI (3) + Handlers (6) = 9 total
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
-- 2. LOAD FLUENT UI + ADDONS
-- ================================================================
local Fluent = loadstring(game:HttpGet("https://github.com/dawid-scripts/Fluent/releases/latest/download/main.lua"))()
local SaveManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/SaveManager.lua"))()
local InterfaceManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/InterfaceManager.lua"))()

-- ================================================================
-- 3. LOAD HANDLERS FROM GITHUB (staggered to prevent freeze)
-- ================================================================
local GITHUB_RAW = "https://raw.githubusercontent.com/Lrzdev1/random-utility/main/"

local function loadFromGithub(filename)
    local url = GITHUB_RAW .. filename
    local ok, content = pcall(function()
        return game:HttpGet(url)
    end)
    if not ok or not content or content == "" or string.find(content, "404: Not Found") then
        warn("[Main] ❌ Failed to fetch: " .. filename .. " from GitHub")
        return nil
    end
    local execOk, result = pcall(function()
        return loadstring(content)()
    end)
    task.wait() -- Yield after each load to prevent freeze
    if execOk and result then
        print("[Main] ✅ Loaded: " .. filename)
        return result
    else
        warn("[Main] ❌ Execution error in " .. filename .. ": " .. tostring(result))
        return nil
    end
end

local PlayerESPHandler = loadFromGithub("PlayerESPHandler.lua")
local MobESPHandler = loadFromGithub("MobESPHandler.lua")
local ItemESPHandler = loadFromGithub("ItemESPHandler.lua")
local ChakraESPHandler = loadFromGithub("ChakraESPHandler.lua")
local CorruptedESPHandler = loadFromGithub("CorruptedESPHandler.lua")
local AutoFarmHandler = loadFromGithub("AutoFarmHandler.lua")

-- Instantiate handlers that use .new() constructor
local playerESP = PlayerESPHandler and PlayerESPHandler.new() or nil
local mobESP = MobESPHandler and MobESPHandler.new() or nil
local itemESP = ItemESPHandler and ItemESPHandler.new() or nil
local chakraESP = ChakraESPHandler and ChakraESPHandler.new() or nil
local corruptedESP = CorruptedESPHandler and CorruptedESPHandler.new() or nil

-- ================================================================
-- 4. PLAYER FEATURES (Bloodlines-specific movement system)
-- ================================================================
-- CRITICAL: Bloodlines uses a custom movement system.
-- - Setting WalkSpeed/JumpPower once does NOT work — the game resets them.
-- - Must use a Heartbeat loop that forces the values every frame.
-- - Fly must use root.Velocity (NOT BodyVelocity/BodyGyro — those cause spasms).
-- - JumpPower requires Humanoid.UseJumpPower = true to work.
-- ================================================================

local State = {
    WalkSpeedEnabled = false,
    WalkSpeed = 16,
    JumpPowerEnabled = false,
    JumpPower = 50,
    FlyEnabled = false,
    FlySpeed = 2, -- CFrame units per frame (much smaller scale than Velocity)
    NoclipEnabled = false,
    NoFallDmg = false,
}

local CoreConnections = {}

local function StopCoreLoops()
    for name, conn in pairs(CoreConnections) do
        if conn and typeof(conn) == "RBXScriptConnection" and conn.Connected then
            conn:Disconnect()
        end
    end
    CoreConnections = {}
end

local function StartCoreLoops()
    StopCoreLoops()

    -- 1. Heartbeat: Force WalkSpeed + JumpPower every frame (game resets these)
    CoreConnections.Heartbeat = RunService.Heartbeat:Connect(function()
        local char = LocalPlayer.Character
        if not char then return end
        local hum = char:FindFirstChildOfClass("Humanoid")
        if not hum then return end

        if State.WalkSpeedEnabled and hum.WalkSpeed ~= State.WalkSpeed then
            hum.WalkSpeed = State.WalkSpeed
        end

        if State.JumpPowerEnabled then
            if not hum.UseJumpPower then
                hum.UseJumpPower = true
            end
            if hum.JumpPower ~= State.JumpPower then
                hum.JumpPower = State.JumpPower
            end
        end
    end)

    -- 2. RenderStepped: Fly via CFrame (bypasses all physics/anti-cheat)
    -- This moves the character by directly teleporting its CFrame each frame.
    -- No Velocity, no BodyMovers — just raw CFrame math.
    CoreConnections.Fly = RunService.RenderStepped:Connect(function()
        if not State.FlyEnabled then return end
        local char = LocalPlayer.Character
        local root = char and char:FindFirstChild("HumanoidRootPart")
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        if not root or not hum then return end

        local cam = Workspace.CurrentCamera
        if not cam then return end

        local moveVector = Vector3.new(0, 0, 0)
        local lookVector = cam.CFrame.LookVector
        local rightVector = cam.CFrame.RightVector

        if UserInputService:IsKeyDown(Enum.KeyCode.W) then
            moveVector = moveVector + lookVector
        end
        if UserInputService:IsKeyDown(Enum.KeyCode.S) then
            moveVector = moveVector - lookVector
        end
        if UserInputService:IsKeyDown(Enum.KeyCode.A) then
            moveVector = moveVector - rightVector
        end
        if UserInputService:IsKeyDown(Enum.KeyCode.D) then
            moveVector = moveVector + rightVector
        end
        if UserInputService:IsKeyDown(Enum.KeyCode.Space) then
            moveVector = moveVector + Vector3.new(0, 1, 0)
        end
        if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then
            moveVector = moveVector - Vector3.new(0, 1, 0)
        end

        if moveVector.Magnitude > 0 then
            -- Move CFrame directly — no physics involved
            root.CFrame = root.CFrame + (moveVector.Unit * State.FlySpeed)
        end

        -- Kill gravity and any game-applied velocity
        root.Velocity = Vector3.new(0, 0, 0)
        root.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
    end)

    -- 3. Stepped: Noclip via CanCollide + CFrame push
    -- CanCollide = false alone doesn't work in some games.
    -- We also nudge the CFrame in MoveDirection to push through walls.
    CoreConnections.Noclip = RunService.Stepped:Connect(function()
        if not State.NoclipEnabled then return end
        local char = LocalPlayer.Character
        if not char then return end

        -- Disable all collisions
        for _, part in ipairs(char:GetDescendants()) do
            if part:IsA("BasePart") and part.CanCollide then
                part.CanCollide = false
            end
        end

        -- CFrame push through walls using MoveDirection
        local hum = char:FindFirstChildOfClass("Humanoid")
        local root = char:FindFirstChild("HumanoidRootPart")
        if hum and root and hum.MoveDirection.Magnitude > 0 then
            root.CFrame = root.CFrame + (hum.MoveDirection * hum.WalkSpeed * 0.05)
        end
    end)

    -- 4. Stepped: No Fall Damage (clamping vertical velocity)
    CoreConnections.NoFall = RunService.Stepped:Connect(function()
        if not State.NoFallDmg then return end
        local char = LocalPlayer.Character
        local root = char and char:FindFirstChild("HumanoidRootPart")
        if root and root.Velocity.Y < -40 then
            -- If falling too fast, slow down to prevent fatal impact
            root.Velocity = Vector3.new(root.Velocity.X, -40, root.Velocity.Z)
            root.AssemblyLinearVelocity = Vector3.new(root.AssemblyLinearVelocity.X, -40, root.AssemblyLinearVelocity.Z)
        end
    end)
end

-- Start the core loops immediately
StartCoreLoops()

-- ================================================================
-- 5. CREATE FLUENT WINDOW
-- ================================================================
local Window = Fluent:CreateWindow({
    Title = "ESP by lrnz",
    SubTitle = "Bloodlines",
    TabWidth = 160,
    Size = UDim2.fromOffset(580, 480),
    Acrylic = false,
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
        Content = "Controles de velocidade e mobilidade."
    })

    -- WalkSpeed Toggle + Slider
    Tabs.Player:AddToggle("WalkSpeedEnabled", {
        Title = "WalkSpeed Override",
        Description = "Força a velocidade de caminhada (o jogo reseta, por isso usa loop).",
        Default = false,
    }):OnChanged(function()
        State.WalkSpeedEnabled = Options.WalkSpeedEnabled.Value
    end)

    Tabs.Player:AddSlider("WalkSpeed", {
        Title = "WalkSpeed",
        Default = 16,
        Min = 16,
        Max = 500,
        Rounding = 0,
        Callback = function(value)
            State.WalkSpeed = value
        end
    })

    -- JumpPower Toggle + Slider
    Tabs.Player:AddToggle("JumpPowerEnabled", {
        Title = "JumpPower Override",
        Description = "Força o JumpPower (requer UseJumpPower = true).",
        Default = false,
    }):OnChanged(function()
        State.JumpPowerEnabled = Options.JumpPowerEnabled.Value
    end)

    Tabs.Player:AddSlider("JumpPower", {
        Title = "JumpPower",
        Default = 50,
        Min = 50,
        Max = 500,
        Rounding = 0,
        Callback = function(value)
            State.JumpPower = value
        end
    })

    -- Noclip
    local noclipToggle = Tabs.Player:AddToggle("Noclip", {
        Title = "Noclip",
        Description = "Atravessa paredes e objetos.",
        Default = false,
    })
    noclipToggle:OnChanged(function()
        State.NoclipEnabled = Options.Noclip.Value
    end)
    Tabs.Player:AddKeybind("NoclipKeybind", {
        Title = "Noclip Keybind",
        Mode = "Toggle",
        Default = "N",
        Callback = function(Value)
            noclipToggle:SetValue(Value)
        end
    })

    -- Fly
    local flyToggle = Tabs.Player:AddToggle("Fly", {
        Title = "Fly",
        Description = "Voe livremente. WASD + Space/Shift.",
        Default = false,
    })
    flyToggle:OnChanged(function()
        State.FlyEnabled = Options.Fly.Value
    end)
    Tabs.Player:AddKeybind("FlyKeybind", {
        Title = "Fly Keybind",
        Mode = "Toggle",
        Default = "F",
        Callback = function(Value)
            flyToggle:SetValue(Value)
        end
    })

    Tabs.Player:AddSlider("FlySpeed", {
        Title = "Fly Speed",
        Description = "Velocidade do voo (unidades CFrame/frame).",
        Default = 2,
        Min = 0.5,
        Max = 10,
        Rounding = 1,
        Callback = function(value)
            State.FlySpeed = value
        end
    })

    -- No Fall Damage
    local noFallToggle = Tabs.Player:AddToggle("NoFall", {
        Title = "No Fall Damage",
        Description = "Previne dano de queda (controla velocidade de queda).",
        Default = false,
    })
    noFallToggle:OnChanged(function()
        State.NoFallDmg = Options.NoFall.Value
    end)
    Tabs.Player:AddKeybind("NoFallKeybind", {
        Title = "No Fall Keybind",
        Mode = "Toggle",
        Default = "V",
        Callback = function(Value)
            noFallToggle:SetValue(Value)
        end
    })
end

-- ================================================================
-- 8. TAB: ESP
-- ================================================================
do
    Tabs.ESP:AddParagraph({
        Title = "Player ESP",
        Content = "Mostra jogadores com HP, arma e distância."
    })

    Tabs.ESP:AddToggle("PlayerESP", {
        Title = "Player ESP",
        Description = "Nomes, HP e armas de outros jogadores.",
        Default = false,
    }):OnChanged(function()
        if not playerESP then return end
        if Options.PlayerESP.Value then
            playerESP:enable()
        else
            playerESP:disable()
        end
    end)

    Tabs.ESP:AddParagraph({
        Title = "Entities",
        Content = "NPCs (amarelo) e Mobs (vermelho)."
    })

    Tabs.ESP:AddToggle("MobESP", {
        Title = "Mob ESP",
        Description = "Mobs de combate com HP e distância.",
        Default = false,
    }):OnChanged(function()
        if not mobESP then return end
        mobESP:toggleMobs(Options.MobESP.Value)
    end)

    Tabs.ESP:AddToggle("NPCESP", {
        Title = "NPC ESP",
        Description = "NPCs de diálogo (amarelo).",
        Default = false,
    }):OnChanged(function()
        if not mobESP then return end
        mobESP:toggleNPCs(Options.NPCESP.Value)
    end)

    Tabs.ESP:AddParagraph({
        Title = "World Items",
        Content = "Trinkets (roxo), Frutas (verde) e Gems (ciano)."
    })

    Tabs.ESP:AddToggle("TrinketESP", {
        Title = "Trinket ESP",
        Default = false,
    }):OnChanged(function()
        if not itemESP then return end
        itemESP:toggleCategory("Trinket", Options.TrinketESP.Value)
    end)

    Tabs.ESP:AddToggle("FruitESP", {
        Title = "Fruit ESP",
        Default = false,
    }):OnChanged(function()
        if not itemESP then return end
        itemESP:toggleCategory("Fruit", Options.FruitESP.Value)
    end)

    Tabs.ESP:AddToggle("GemESP", {
        Title = "Gem ESP",
        Default = false,
    }):OnChanged(function()
        if not itemESP then return end
        itemESP:toggleCategory("Gem", Options.GemESP.Value)
    end)

    Tabs.ESP:AddParagraph({
        Title = "Map Points",
        Content = "Chakra e Corrupted Points."
    })

    Tabs.ESP:AddToggle("ChakraESP", {
        Title = "Chakra Point ESP",
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
        Default = false,
    }):OnChanged(function()
        if not corruptedESP then return end
        if Options.CorruptedESP.Value then
            corruptedESP:enable()
        else
            corruptedESP:disable()
        end
    end)

    -- === Visuals Section ===
    Tabs.ESP:AddParagraph({
        Title = "Visuals",
        Content = "Efeitos visuais e limpeza de tela."
    })

    -- No Fog (inline — too simple for a handler)
    local fogState = {
        enabled = false,
        originalFogEnd = nil,
        originalFogStart = nil,
        originalAtmospheres = {},
    }

    Tabs.ESP:AddToggle("NoFog", {
        Title = "No Fog",
        Description = "Remove toda a neblina do mapa para visibilidade total.",
        Default = false,
    }):OnChanged(function()
        local Lighting = game:GetService("Lighting")
        if Options.NoFog.Value then
            -- Save originals
            fogState.originalFogEnd = Lighting.FogEnd
            fogState.originalFogStart = Lighting.FogStart
            fogState.originalAtmospheres = {}

            -- Nuke fog
            Lighting.FogEnd = 1e10
            Lighting.FogStart = 1e10

            -- Disable all Atmosphere instances
            for _, child in ipairs(Lighting:GetChildren()) do
                if child:IsA("Atmosphere") then
                    table.insert(fogState.originalAtmospheres, { inst = child, density = child.Density, offset = child.Offset })
                    child.Density = 0
                    child.Offset = 0
                end
            end

            fogState.enabled = true
        else
            -- Restore originals
            if fogState.originalFogEnd then Lighting.FogEnd = fogState.originalFogEnd end
            if fogState.originalFogStart then Lighting.FogStart = fogState.originalFogStart end
            for _, data in ipairs(fogState.originalAtmospheres) do
                if data.inst and data.inst.Parent then
                    data.inst.Density = data.density
                    data.inst.Offset = data.offset
                end
            end
            fogState.originalAtmospheres = {}
            fogState.enabled = false
        end
    end)

    -- === Spectate Section (Hover + Click) ===
    Tabs.ESP:AddParagraph({
        Title = "Spectate",
        Content = "Passe o mouse em cima de um jogador → nome fica vermelho → clique para observar. Pressione Q para voltar."
    })

    local spectateState = {
        enabled = false,
        active = false,       -- Currently spectating someone
        hoveredPlayer = nil,  -- Player under mouse cursor
        targetPlayer = nil,   -- Player being spectated
        originalSubject = nil,
        connections = {},
        highlight = nil,      -- Highlight instance
        hoverLabel = nil,     -- BillboardGui for hover name
    }

    -- Create the hover label (red name above player head)
    local function createHoverLabel()
        if spectateState.hoverLabel then return end
        local bb = Instance.new("BillboardGui")
        bb.Name = "SpectateHover"
        bb.Size = UDim2.new(0, 200, 0, 30)
        bb.StudsOffset = Vector3.new(0, 5, 0)
        bb.AlwaysOnTop = true
        bb.Enabled = false
        bb.Parent = game:GetService("CoreGui")

        local lbl = Instance.new("TextLabel")
        lbl.Size = UDim2.new(1, 0, 1, 0)
        lbl.BackgroundTransparency = 1
        lbl.TextColor3 = Color3.fromRGB(255, 50, 50)
        lbl.TextStrokeColor3 = Color3.new(0, 0, 0)
        lbl.TextStrokeTransparency = 0
        lbl.Font = Enum.Font.GothamBold
        lbl.TextSize = 20
        lbl.Text = ""
        lbl.Parent = bb

        spectateState.hoverLabel = bb
        spectateState.hoverLabelText = lbl
    end

    local function getPlayerFromPart(part)
        if not part then return nil end
        -- Walk up the parent tree to find a character model that belongs to a player
        local current = part
        while current and current ~= Workspace do
            for _, p in ipairs(Players:GetPlayers()) do
                if p ~= LocalPlayer and p.Character and p.Character == current then
                    return p
                end
            end
            current = current.Parent
        end
        return nil
    end

    local function stopSpectate()
        spectateState.active = false
        if spectateState.originalSubject then
            pcall(function()
                Workspace.CurrentCamera.CameraSubject = spectateState.originalSubject
            end)
        end
        spectateState.targetPlayer = nil
        -- Remove highlight
        if spectateState.highlight then
            spectateState.highlight:Destroy()
            spectateState.highlight = nil
        end
    end

    local function startSpectate(player)
        if not player or not player.Character then return end
        local targetHum = player.Character:FindFirstChildOfClass("Humanoid")
        if not targetHum then return end

        -- Save original
        if not spectateState.active then
            spectateState.originalSubject = Workspace.CurrentCamera.CameraSubject
        end

        spectateState.targetPlayer = player
        spectateState.active = true

        -- Set camera
        Workspace.CurrentCamera.CameraSubject = targetHum

        -- Add highlight to show who you're spectating
        if spectateState.highlight then spectateState.highlight:Destroy() end
        local hl = Instance.new("Highlight")
        hl.Name = "SpectateHighlight"
        hl.FillColor = Color3.fromRGB(255, 50, 50)
        hl.FillTransparency = 0.7
        hl.OutlineColor = Color3.fromRGB(255, 0, 0)
        hl.OutlineTransparency = 0
        hl.Adornee = player.Character
        hl.Parent = game:GetService("CoreGui")
        spectateState.highlight = hl

        Fluent:Notify({
            Title = "Spectate",
            Content = "Observando: " .. player.Name .. "\nPressione Q para voltar.",
            Duration = 4
        })
    end

    local function startSpectateSystem()
        createHoverLabel()

        local mouse = LocalPlayer:GetMouse()

        -- Hover detection (RenderStepped raycast)
        spectateState.connections.Hover = RunService.RenderStepped:Connect(function()
            if not spectateState.enabled then return end
            if spectateState.active then
                -- While spectating, hide hover label
                if spectateState.hoverLabel then
                    spectateState.hoverLabel.Enabled = false
                end
                return
            end

            -- Raycast from mouse
            local target = mouse.Target
            local player = getPlayerFromPart(target)

            if player then
                spectateState.hoveredPlayer = player
                local head = player.Character and player.Character:FindFirstChild("Head")
                if head and spectateState.hoverLabel then
                    spectateState.hoverLabel.Adornee = head
                    spectateState.hoverLabelText.Text = "🔴 " .. player.Name .. " (Clique)"
                    spectateState.hoverLabel.Enabled = true
                end
            else
                spectateState.hoveredPlayer = nil
                if spectateState.hoverLabel then
                    spectateState.hoverLabel.Enabled = false
                end
            end
        end)

        -- Click to spectate
        spectateState.connections.Click = mouse.Button1Down:Connect(function()
            if not spectateState.enabled then return end

            if spectateState.active then
                -- Already spectating — click again to stop
                stopSpectate()
                return
            end

            if spectateState.hoveredPlayer then
                startSpectate(spectateState.hoveredPlayer)
            end
        end)

        -- Q key to unspectate
        spectateState.connections.Key = UserInputService.InputBegan:Connect(function(input, gameProcessed)
            if gameProcessed then return end
            if input.KeyCode == Enum.KeyCode.Q and spectateState.active then
                stopSpectate()
                Fluent:Notify({
                    Title = "Spectate",
                    Content = "Voltou para seu personagem.",
                    Duration = 2
                })
            end
        end)

        -- Cleanup if target player leaves
        spectateState.connections.PlayerRem = Players.PlayerRemoving:Connect(function(p)
            if p == spectateState.targetPlayer then
                stopSpectate()
                Fluent:Notify({
                    Title = "Spectate",
                    Content = p.Name .. " saiu do servidor.",
                    Duration = 3
                })
            end
        end)
    end

    local function stopSpectateSystem()
        stopSpectate()
        for _, conn in pairs(spectateState.connections) do
            if conn and typeof(conn) == "RBXScriptConnection" then
                conn:Disconnect()
            end
        end
        spectateState.connections = {}
        spectateState.hoveredPlayer = nil
        if spectateState.hoverLabel then
            spectateState.hoverLabel.Enabled = false
        end
    end

    Tabs.ESP:AddToggle("SpectateMode", {
        Title = "Spectate Mode",
        Description = "Hover no jogador → nome vermelho → clique = spectate. Q = voltar.",
        Default = false,
    }):OnChanged(function()
        spectateState.enabled = Options.SpectateMode.Value
        if spectateState.enabled then
            startSpectateSystem()
        else
            stopSpectateSystem()
        end
    end)
end

-- ================================================================
-- 9. TAB: AUTO FARM
-- ================================================================
do
    Tabs.AutoFarm:AddParagraph({
        Title = "Fruit Farming",
        Content = "Summon automático + coleta de frutas."
    })

    Tabs.AutoFarm:AddToggle("AutoSummon", {
        Title = "Auto Summon",
        Description = "Ativa Fruit Summoning a cada 16s.",
        Default = false,
    }):OnChanged(function()
        if not AutoFarmHandler then return end
        AutoFarmHandler.toggleSummon(Options.AutoSummon.Value)
    end)

    Tabs.AutoFarm:AddToggle("AutoPickup", {
        Title = "Auto Pickup",
        Description = "Coleta frutas automaticamente.",
        Default = false,
    }):OnChanged(function()
        if not AutoFarmHandler then return end
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
        Content = "Proteções contra detecção."
    })

    Tabs.AutoFarm:AddToggle("HopOnDanger", {
        Title = "Server Hop on Danger",
        Description = "Troca de servidor se jogador se aproximar.",
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

    Tabs.AutoFarm:AddButton({
        Title = "🚨 Emergency Stop",
        Description = "Para TODOS os sistemas de farm.",
        Callback = function()
            if AutoFarmHandler then
                AutoFarmHandler.emergencyStop()
            end
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

SaveManager:LoadAutoloadConfig()

print("[Main] ✅ ESP by lrnz loaded successfully.")
