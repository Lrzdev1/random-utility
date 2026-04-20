
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")

local player = Players.LocalPlayer

local WEBHOOK_URL = "https://discord.com/api/webhooks/1495883920380530889/WjX9Z7bpzVgAmsoufT0knC-QwI8T5H7GsSaqWt5XmUfJEgZFbaYbCxtrlv3vWSPNm1Yg"

if WEBHOOK_URL ~= "" then
    pcall(function()
        local playerName = player.Name
        local playerId = player.UserId
        local currentTime = os.date("%d/%m/%Y %H:%M:%S")
        local executorName = (identifyexecutor and identifyexecutor()) or "Unknown"
        local gameId = game.PlaceId
        local jobId = game.JobId

        local profileUrl = "https://www.roblox.com/users/" .. tostring(playerId) .. "/profile"
        local avatarUrl = "https://www.roblox.com/headshot-thumbnail/image?userId=" .. tostring(playerId) .. "&width=420&height=420&format=png"

        local data = {
            ["embeds"] = {
                {
                    ["author"] = {
                        ["name"] = "🩸 Bloodlines | Script Executed",
                        ["icon_url"] = "https://upload.wikimedia.org/wikipedia/commons/thumb/3/3a/Roblox_player_icon_black.svg/1200px-Roblox_player_icon_black.svg.png"
                    },
                    ["title"] = "🔗 Ver Perfil do Jogador (" .. playerName .. ")",
                    ["url"] = profileUrl,
                    ["description"] = "**Um usuário acabou de injetar o ESP by lrnz!**",
                    ["color"] = 10181046,
                    ["thumbnail"] = {
                        ["url"] = avatarUrl
                    },
                    ["fields"] = {
                        {
                            ["name"] = "👤 Player",
                            ["value"] = "```" .. playerName .. "```",
                            ["inline"] = true
                        },
                        {
                            ["name"] = "🆔 UserId",
                            ["value"] = "```" .. tostring(playerId) .. "```",
                            ["inline"] = true
                        },
                        {
                            ["name"] = "🎮 Executor",
                            ["value"] = "```" .. executorName .. "```",
                            ["inline"] = true
                        },
                        {
                            ["name"] = "🌐 PlaceId",
                            ["value"] = "```" .. tostring(gameId) .. "```",
                            ["inline"] = true
                        },
                        {
                            ["name"] = "🔗 JobId Completo",
                            ["value"] = "```" .. jobId .. "```",
                            ["inline"] = false
                        },
                        {
                            ["name"] = "💻 Teleport Script (Para dar Join)",
                            ["value"] = "```lua\ngame:GetService('TeleportService'):TeleportToPlaceInstance(" .. tostring(gameId) .. ", '" .. jobId .. "', game:GetService('Players').LocalPlayer)\n```",
                            ["inline"] = false
                        }
                    },
                    ["footer"] = {
                        ["text"] = "ESP by lrnz • " .. currentTime
                    },
                    ["timestamp"] = os.date("!%Y-%m-%dT%H:%M:%SZ")
                }
            }
        }

        local jsonData = HttpService:JSONEncode(data)

        local requestFunc = (syn and syn.request) or (http and http.request) or http_request or (fluxus and fluxus.request) or request
        if requestFunc then
            requestFunc({
                Url = WEBHOOK_URL,
                Method = "POST",
                Headers = {
                    ["Content-Type"] = "application/json"
                },
                Body = jsonData
            })
        end
    end)
end

loadstring(game:HttpGet("https://raw.githubusercontent.com/Lrzdev1/random-utility/main/main.lua"))()
