-- PlayerESPHandler.lua
-- FIX: Nil crash on LocalPlayer character, billboard destroy, Settings lazy-load

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CoreGui = game:GetService("CoreGui")
local RunService = game:GetService("RunService")

local PlayerESPHandler = {}
PlayerESPHandler.__index = PlayerESPHandler

-- Lazy-loaded: don't block script execution if Settings folder isn't ready yet
local SETTINGS_FOLDER = nil
local function getSettingsFolder()
    if SETTINGS_FOLDER and SETTINGS_FOLDER.Parent then return SETTINGS_FOLDER end
    SETTINGS_FOLDER = ReplicatedStorage:FindFirstChild("Settings")
    return SETTINGS_FOLDER
end

function PlayerESPHandler.new()
    local self = setmetatable({}, PlayerESPHandler)
    self.enabled = false
    self.billboards = {}
    self.dataCache = {} 
    self.connections = {}
    self.maxDistance = math.huge -- Infinite
    return self
end

function PlayerESPHandler:GetPlayerData(player)
    local now = tick()
    if self.dataCache[player] and (now - self.dataCache[player].LastUpdate < 0.5) then
        return self.dataCache[player].Weapon, self.dataCache[player].IsObserving
    end

    local weapon = "None"
    local isObserving = false
    
    local settingsFolder = getSettingsFolder()
    if settingsFolder then
        local playerSettings = settingsFolder:FindFirstChild(player.Name)
        if playerSettings then
            local wVal = playerSettings:FindFirstChild("CurrentWeapon")
            if wVal then weapon = tostring(wVal.Value) end
            local sVal = playerSettings:FindFirstChild("CurrentSkill")
            if sVal and type(sVal.Value) == "string" and string.find(string.lower(sVal.Value), "sense") then
                isObserving = true
            end
        end
    end
    
    self.dataCache[player] = { Weapon = weapon, IsObserving = isObserving, LastUpdate = now }
    return weapon, isObserving
end

function PlayerESPHandler:CreateBillboard(player)
    if self.billboards[player] then
        self.billboards[player].gui:Destroy()
        self.billboards[player] = nil
    end
    
    local billboard = Instance.new("BillboardGui")
    billboard.Name = "PuppyESP_" .. player.Name
    billboard.Size = UDim2.new(0, 250, 0, 70) 
    billboard.StudsOffset = Vector3.new(0, 4, 0)
    billboard.AlwaysOnTop = true
    billboard.Parent = CoreGui 
    
    local nameLabel = Instance.new("TextLabel")
    nameLabel.Size = UDim2.new(1, 0, 0.4, 0)
    nameLabel.BackgroundTransparency = 1
    nameLabel.TextColor3 = Color3.new(1, 1, 1)
    nameLabel.TextStrokeTransparency = 0.3
    nameLabel.Font = Enum.Font.GothamBold
    nameLabel.TextSize = 18
    nameLabel.Text = player.Name
    nameLabel.Parent = billboard
    
    local infoLabel = Instance.new("TextLabel")
    infoLabel.Size = UDim2.new(1, 0, 0.4, 0)
    infoLabel.Position = UDim2.new(0, 0, 0.4, 0)
    infoLabel.BackgroundTransparency = 1
    infoLabel.TextColor3 = Color3.new(0.9, 0.9, 0.9)
    infoLabel.TextStrokeTransparency = 0.3
    infoLabel.Font = Enum.Font.GothamSemibold
    infoLabel.TextSize = 14
    infoLabel.Text = "..."
    infoLabel.Parent = billboard
    
    self.billboards[player] = {
        gui = billboard,
        nameLbl = nameLabel,
        infoLbl = infoLabel
    }
end

function PlayerESPHandler:Update()
    if not self.enabled then return end
    
    -- Guard: need our own character + root to calculate distances
    local myChar = Players.LocalPlayer.Character
    local myRoot = myChar and myChar:FindFirstChild("HumanoidRootPart")
    
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= Players.LocalPlayer and player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
            if not self.billboards[player] then self:CreateBillboard(player) end
            
            local data = self.billboards[player]
            if not data then continue end
            
            local char = player.Character
            local hrp = char:FindFirstChild("HumanoidRootPart")
            local hum = char:FindFirstChildOfClass("Humanoid")
            
            if not hrp then
                data.gui.Enabled = false
                continue
            end
            
            data.gui.Adornee = hrp
            
            local weapon, isObserving = self:GetPlayerData(player)
            local hp = hum and math.floor(hum.Health) or 0
            local maxHp = hum and math.floor(hum.MaxHealth) or 100
            
            -- Safe distance calculation (uses 0 if our root doesn't exist)
            local dist = 0
            if myRoot then
                dist = math.floor((myRoot.Position - hrp.Position).Magnitude)
            end
            
            local color = isObserving and Color3.fromRGB(0, 220, 255) or Color3.fromRGB(255, 255, 255)
            if dist < 100 and dist > 0 then color = Color3.fromRGB(255, 50, 50) end
            
            data.nameLbl.TextColor3 = color
            data.nameLbl.Text = string.format("%s [%dm]", player.Name, dist)
            
            data.infoLbl.TextColor3 = color
            data.infoLbl.Text = string.format("HP: %d/%d\nWep: %s", hp, maxHp, weapon)
            
            data.gui.Enabled = true
        else
            if self.billboards[player] then
                self.billboards[player].gui.Adornee = nil
                self.billboards[player].gui.Enabled = false
            end
        end
    end
end

function PlayerESPHandler:enable()
    if self.enabled then return end
    self.enabled = true
    self.connections.Update = RunService.RenderStepped:Connect(function() self:Update() end)
    self.connections.PlayerRem = Players.PlayerRemoving:Connect(function(p)
        if self.billboards[p] then
            self.billboards[p].gui:Destroy()
            self.billboards[p] = nil
        end
        self.dataCache[p] = nil
    end)
end

function PlayerESPHandler:disable()
    self.enabled = false
    if self.connections.Update then self.connections.Update:Disconnect() self.connections.Update = nil end
    if self.connections.PlayerRem then self.connections.PlayerRem:Disconnect() self.connections.PlayerRem = nil end
    for _, b in pairs(self.billboards) do b.gui:Destroy() end
    self.billboards = {}
    self.dataCache = {}
end

return PlayerESPHandler
