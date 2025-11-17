--!strict

--[[
    OpenRPC Library v8.0.0
    A fully typed, Discord Rich Presence library for Roblox
    
    Author: morefeinn
    License: MIT
]]

export type ActivityPreset = "Game" | "Custom" | "Minimal" | "Detailed"

export type Button = {
    label: string,
    url: string
}

export type Activity = {
    details: string?,
    state: string?,
    largeImage: string?,
    largeText: string?,
    smallImage: string?,
    smallText: string?,
    buttons: {Button}
}

export type Config = {
    Port: number?,
    UpdateInterval: number?,
    AutoUpdate: boolean?,
    Debug: boolean?,
    AntiDetection: boolean?,
    ClientID: string?,
    Preset: ActivityPreset?,
    LogLevel: ("None" | "Error" | "Warn" | "Info" | "Debug")?,
}

export type State = {
    Connected: boolean,
    Executor: string,
    LastUpdate: number,
    GameInfo: GameInfo?,
    RequestFuncName: string,
}

export type GameInfo = {
    Name: string,
    Description: string,
    Creator: any,
    Created: string,
    Updated: string,
}

export type EventCallback = (any?) -> ()

type RequestFunction = (data: {[string]: any}) -> any
type CloneRefFunction = (instance: Instance) -> Instance

local DiscordRPC = {}
DiscordRPC.__index = DiscordRPC

local VERSION: string = "8.0.0"
local INSTANCES: {DiscordRPC} = {}

local cloneref: CloneRefFunction = (cloneref :: any) or function(obj: Instance): Instance 
    return obj 
end

local HttpService = cloneref(game:GetService("HttpService"))
local Players = cloneref(game:GetService("Players"))
local MarketplaceService = cloneref(game:GetService("MarketplaceService"))
local RunService = cloneref(game:GetService("RunService"))
local LocalPlayer = Players.LocalPlayer :: Player

local LOG_COLORS = {
    None = "",
    Error = "❌",
    Warn = "⚠️",
    Info = "ℹ️",
    Debug = "🔍"
}

local LOG_LEVELS = {
    None = 0,
    Error = 1,
    Warn = 2,
    Info = 3,
    Debug = 4
}

local PRESETS: {[ActivityPreset]: (self: DiscordRPC) -> ()} = {
    Game = function(self: DiscordRPC)
        self:SetGameActivity({
            showGameName = true,
            showPlayers = true,
            showJoinButton = true,
        })
    end,
    
    Custom = function(self: DiscordRPC)
        self:SetActivity("Custom Activity", "Using DiscordRPC")
    end,
    
    Minimal = function(self: DiscordRPC)
        self:SetActivity("Playing Roblox", nil)
    end,
    
    Detailed = function(self: DiscordRPC)
        self:SetGameActivity({
            showGameName = true,
            showPlayers = true,
            showJoinButton = true,
            showProfile = true,
            gameIcon = true,
            playerAvatar = true,
        })
    end
}

local ExploitDetection = {}

function ExploitDetection.GetExecutor(): string
    local identifiers: {[string]: any} = {
        syn = "Synapse X",
        KRNL_LOADED = "KRNL",
        OXYGEN_LOADED = "Oxygen U",
        is_sirhurt_closure = "SirHurt",
        SENTINEL_V2 = "Sentinel",
        WrapGlobal = "WeAreDevs",
        issentinelclosure = "Sentinel",
        is_protosmasher_closure = "ProtoSmasher",
        EVON_LOADED = "Evon",
        fluxus = "Fluxus",
    }
    
    if getgenv().getexecutorname then
        local success, name = pcall(function()
            return (getgenv().getexecutorname :: any)()
        end)
        if success and name then
            return name :: string
        end
    end
    
    for key: string, name: any in pairs(identifiers) do
        if (getgenv() :: any)[key] or (_G :: any)[key] then
            return name :: string
        end
    end
    
    return "Unknown Executor"
end

function ExploitDetection.GetRequestFunction(): (RequestFunction?, string?)
    local functionNames: {string} = {
        "request",
        "http_request", 
        "http.request",
        "syn.request"
    }
    
    for _, funcName: string in ipairs(functionNames) do
        local func = loadstring("return " .. funcName)
        if func then
            local success, result = pcall(func)
            if success and type(result) == "function" then
                return result :: RequestFunction, funcName
            end
        end
    end
    
    return nil, nil
end

export type DiscordRPC = typeof(setmetatable({} :: {
    _config: {
        Port: number,
        UpdateInterval: number,
        AutoUpdate: boolean,
        Debug: boolean,
        AntiDetection: boolean,
        ClientID: string,
        Preset: ActivityPreset,
        LogLevel: string,
    },
    _state: {
        Connected: boolean,
        StartTime: number,
        LastUpdate: number,
        Activity: Activity,
        Callbacks: {[string]: EventCallback},
        Connections: {RBXScriptConnection},
        LastSentData: string?,
        GameInfo: GameInfo?,
        Executor: string,
        RequestFunc: RequestFunction?,
        RequestFuncName: string,
    },
    _logLevel: number,
}, DiscordRPC))

function DiscordRPC.new(config: Config?): DiscordRPC
    local self = setmetatable({} :: any, DiscordRPC)
    
    local cfg = config or {}
    
    self._config = {
        Port = cfg.Port or 8080,
        UpdateInterval = cfg.UpdateInterval or 5,
        AutoUpdate = if cfg.AutoUpdate ~= nil then cfg.AutoUpdate else true,
        Debug = cfg.Debug or false,
        AntiDetection = if cfg.AntiDetection ~= nil then cfg.AntiDetection else true,
        ClientID = cfg.ClientID or "1436600503692824586",
        Preset = cfg.Preset or "Game",
        LogLevel = cfg.LogLevel or (if cfg.Debug then "Debug" else "Info"),
    }
    
    self._logLevel = LOG_LEVELS[self._config.LogLevel] or LOG_LEVELS.Info
    
    self._state = {
        Connected = false,
        StartTime = os.time(),
        LastUpdate = 0,
        Activity = {
            details = nil,
            state = nil,
            largeImage = nil,
            largeText = nil,
            smallImage = nil,
            smallText = nil,
            buttons = {}
        },
        Callbacks = {},
        Connections = {},
        LastSentData = nil,
        GameInfo = nil,
        Executor = ExploitDetection.GetExecutor(),
        RequestFunc = nil,
        RequestFuncName = "",
    }
    
    local requestFunc, funcName = ExploitDetection.GetRequestFunction()
    if not requestFunc or not funcName then
        error("[DiscordRPC] No request function found. Executor not supported.")
    end
    
    self._state.RequestFunc = requestFunc
    self._state.RequestFuncName = funcName
    
    self:_log("Debug", "Initialized with executor:", self._state.Executor)
    self:_log("Debug", "Using request function:", funcName)
    
    task.spawn(function()
        (self :: any):_fetchGameInfo()
    end)
    
    if self._config.AutoUpdate then
        (self :: any):_setupAutoUpdate()
    end
    
    table.insert(INSTANCES, self :: any)
    
    return self :: any
end

function DiscordRPC:_log(level: string, ...: any): ()
    local levelNum = LOG_LEVELS[level] or 0
    if levelNum > self._logLevel then
        return
    end
    
    local args = {...}
    local message = ""
    
    for i, v in ipairs(args) do
        message = message .. tostring(v)
        if i < #args then
            message = message .. " "
        end
    end
    
    local icon = LOG_COLORS[level] or ""
    local prefix = string.format("[DiscordRPC v%s]", VERSION)
    
    if level == "Error" then
        warn(prefix, icon, message)
    else
        print(prefix, icon, message)
    end
end

function DiscordRPC:Log(level: string, ...: any): ()
    self:_log(level, ...)
end

function DiscordRPC:_request(endpoint: string, data: {[string]: any}): (boolean, any)
    if not self._state.RequestFunc then
        return false, "No request function available"
    end
    
    local url = string.format("http://127.0.0.1:%d%s", self._config.Port, endpoint)
    
    local requestData = {
        Url = url,
        Method = "POST",
        Headers = {["Content-Type"] = "application/json"},
        Body = HttpService:JSONEncode(data)
    }
    
    local success, result = pcall(self._state.RequestFunc :: any, requestData)
    
    if success and result.StatusCode >= 200 and result.StatusCode < 300 then
        return true, result
    elseif success then
        return false, "HTTP " .. tostring(result.StatusCode)
    else
        return false, tostring(result)
    end
end

function DiscordRPC:_fetchGameInfo(): ()
    local success, info = pcall(function()
        return MarketplaceService:GetProductInfo(game.PlaceId)
    end)
    
    if success and info then
        self._state.GameInfo = info :: any
        self:_log("Debug", "Fetched game info:", info.Name)
    end
end

function DiscordRPC:_setupAutoUpdate(): ()
    local connection = RunService.Heartbeat:Connect(function()
        if not self._state.Connected then return end
        
        if tick() - self._state.LastUpdate >= self._config.UpdateInterval then
            pcall(function()
                self:Update()
            end)
        end
    end)
    
    table.insert(self._state.Connections, connection)
end

function DiscordRPC:Connect(): (boolean, string?)
    self:_log("Info", "Connecting to bridge...")
    
    local testSuccess = pcall(function()
        game:HttpGet(string.format("http://127.0.0.1:%d/health", self._config.Port))
    end)
    
    if not testSuccess then
        local errorMsg = string.format("Bridge not running on port %d. Start: python bridge.py", self._config.Port)
        self:_log("Error", errorMsg)
        
        if self._state.Callbacks.OnError then
            self._state.Callbacks.OnError(errorMsg)
        end
        
        return false, errorMsg
    end
    
    local success, response = self:_request("", {
        details = "Connecting...",
        state = "Initializing",
        url = "https://www.roblox.com/games/" .. tostring(game.PlaceId),
        profile_url = "https://www.roblox.com/users/" .. tostring(LocalPlayer.UserId) .. "/profile",
    })
    
    if success then
        self._state.Connected = true
        self:_log("Info", "Connected successfully!")
        
        if self._state.Callbacks.OnConnect then
            self._state.Callbacks.OnConnect()
        end
        
        if self._config.Preset then
            local preset = PRESETS[self._config.Preset]
            if preset then
                preset(self)
                self:Update()
            end
        end
        
        return true, nil
    else
        local errorMsg = "Connection failed: " .. tostring(response)
        self:_log("Error", errorMsg)
        
        if self._state.Callbacks.OnError then
            self._state.Callbacks.OnError(errorMsg)
        end
        
        return false, errorMsg
    end
end

function DiscordRPC:SetActivity(details: string?, state: string?): DiscordRPC
    if details then
        self._state.Activity.details = tostring(details)
    end
    
    if state then
        self._state.Activity.state = tostring(state)
    end
    
    return self
end

function DiscordRPC:SetDetails(details: string): DiscordRPC
    self._state.Activity.details = tostring(details)
    return self
end

function DiscordRPC:SetState(state: string): DiscordRPC
    self._state.Activity.state = tostring(state)
    return self
end

function DiscordRPC:SetLargeImage(imageKey: string, text: string?): DiscordRPC
    self._state.Activity.largeImage = imageKey
    self._state.Activity.largeText = text
    return self
end

function DiscordRPC:SetSmallImage(imageKey: string, text: string?): DiscordRPC
    self._state.Activity.smallImage = imageKey
    self._state.Activity.smallText = text
    return self
end

function DiscordRPC:SetButtons(buttons: {Button}): DiscordRPC
    if type(buttons) ~= "table" then
        error("[DiscordRPC] Buttons must be a table")
    end
    
    self._state.Activity.buttons = {}
    
    for i, button in ipairs(buttons) do
        if i > 2 then break end
        
        if button.label and button.url then
            table.insert(self._state.Activity.buttons, {
                label = tostring(button.label),
                url = tostring(button.url)
            })
        end
    end
    
    return self
end

function DiscordRPC:AddButton(label: string, url: string): DiscordRPC
    if #self._state.Activity.buttons >= 2 then
        self:_log("Warn", "Maximum 2 buttons allowed. Removing oldest.")
        table.remove(self._state.Activity.buttons, 1)
    end
    
    table.insert(self._state.Activity.buttons, {
        label = tostring(label),
        url = tostring(url)
    })
    
    return self
end

function DiscordRPC:ClearButtons(): DiscordRPC
    self._state.Activity.buttons = {}
    return self
end

function DiscordRPC:SetGameActivity(options: {
    showGameName: boolean?,
    showPlayers: boolean?,
    showJoinButton: boolean?,
    showProfile: boolean?,
    gameIcon: boolean?,
    playerAvatar: boolean?,
}?): DiscordRPC
    local opts = options or {}
    
    local gameName = if self._state.GameInfo then self._state.GameInfo.Name else "Roblox Game"
    local playerCount = #Players:GetPlayers()
    local maxPlayers = Players.MaxPlayers
    
    if opts.showGameName ~= false then
        self._state.Activity.details = gameName
    end
    
    if opts.showPlayers ~= false then
        self._state.Activity.state = string.format("%d/%d Players", playerCount, maxPlayers)
    end
    
    if opts.showJoinButton ~= false then
        self:AddButton("Join Game", "https://www.roblox.com/games/" .. tostring(game.PlaceId))
    end
    
    if opts.showProfile then
        self:AddButton("View Profile", "https://www.roblox.com/users/" .. tostring(LocalPlayer.UserId) .. "/profile")
    end
    
    if opts.gameIcon ~= false then
        self:SetLargeImage(
            "https://www.roblox.com/asset-thumbnail/image?assetId=" .. tostring(game.PlaceId) .. "&width=512&height=512",
            gameName
        )
    end
    
    if opts.playerAvatar ~= false then
        self:SetSmallImage(
            "https://www.roblox.com/headshot-thumbnail/image?userId=" .. tostring(LocalPlayer.UserId) .. "&width=150&height=150",
            LocalPlayer.DisplayName .. " (@" .. LocalPlayer.Name .. ")"
        )
    end
    
    return self
end

function DiscordRPC:SetPlayerActivity(activity: string, location: string?): DiscordRPC
    local char = LocalPlayer.Character
    if not char then
        self._state.Activity.state = "Respawning"
        return self
    end
    
    local humanoid = char:FindFirstChildOfClass("Humanoid")
    if not humanoid then
        self._state.Activity.state = "Loading"
        return self
    end
    
    local state = activity or "Playing"
    
    if location then
        state = state .. " in " .. location
    end
    
    local playerCount = #Players:GetPlayers()
    local maxPlayers = Players.MaxPlayers
    state = state .. " • " .. tostring(playerCount) .. "/" .. tostring(maxPlayers) .. " Players"
    
    if humanoid.Health > 0 and humanoid.Health < humanoid.MaxHealth then
        local healthPercent = math.floor((humanoid.Health / humanoid.MaxHealth) * 100)
        state = state .. " • " .. tostring(healthPercent) .. "% HP"
    end
    
    self._state.Activity.state = state
    
    return self
end

function DiscordRPC:Update(): (boolean, string?)
    if not self._state.Connected then
        return false, "Not connected"
    end
    
    local data: {[string]: any} = {
        details = self._state.Activity.details,
        state = self._state.Activity.state,
        url = "https://www.roblox.com/games/" .. tostring(game.PlaceId),
        profile_url = "https://www.roblox.com/users/" .. tostring(LocalPlayer.UserId) .. "/profile",
    }
    
    if self._state.Activity.largeImage then
        data.large_image = self._state.Activity.largeImage
        data.large_text = self._state.Activity.largeText
    end
    
    if self._state.Activity.smallImage then
        data.small_image = self._state.Activity.smallImage
        data.small_text = self._state.Activity.smallText
    end
    
    if #self._state.Activity.buttons > 0 then
        for i, button in ipairs(self._state.Activity.buttons) do
            if i == 1 then
                data.url = button.url
            elseif i == 2 then
                data.profile_url = button.url
            end
        end
    end
    
    local dataStr = HttpService:JSONEncode(data)
    if dataStr == self._state.LastSentData and not self._config.Debug then
        return true, nil
    end
    
    local success, response = self:_request("", data)
    
    if success then
        self._state.LastUpdate = tick()
        self._state.LastSentData = dataStr
        
        if self._state.Callbacks.OnUpdate then
            self._state.Callbacks.OnUpdate(data)
        end
        
        self:_log("Debug", "Updated:", data.details or "N/A")
        return true, nil
    else
        local errorMsg = "Update failed: " .. tostring(response)
        self:_log("Error", errorMsg)
        
        if self._state.Callbacks.OnError then
            self._state.Callbacks.OnError(errorMsg)
        end
        
        return false, errorMsg
    end
end

function DiscordRPC:On(event: string, callback: EventCallback): DiscordRPC
    if type(callback) ~= "function" then
        error("[DiscordRPC] Callback must be a function")
    end
    
    local validEvents = {"OnConnect", "OnUpdate", "OnDisconnect", "OnError"}
    
    if not table.find(validEvents, event) then
        error("[DiscordRPC] Invalid event. Valid events: " .. table.concat(validEvents, ", "))
    end
    
    self._state.Callbacks[event] = callback
    
    return self
end

function DiscordRPC:GetActivity(): Activity
    return self._state.Activity
end

function DiscordRPC:GetConfig(): Config
    return self._config :: any
end

function DiscordRPC:GetState(): State
    return {
        Connected = self._state.Connected,
        Executor = self._state.Executor,
        LastUpdate = self._state.LastUpdate,
        GameInfo = self._state.GameInfo,
        RequestFuncName = self._state.RequestFuncName,
    }
end

function DiscordRPC:SetConfig(config: Config): DiscordRPC
    for key, value in pairs(config :: any) do
        if (self._config :: any)[key] ~= nil then
            (self._config :: any)[key] = value
        end
    end
    
    if config.LogLevel then
        self._logLevel = LOG_LEVELS[config.LogLevel] or self._logLevel
    end
    
    return self
end

function DiscordRPC:Disconnect(): ()
    self._state.Connected = false
    
    for _, connection in ipairs(self._state.Connections) do
        pcall(function()
            connection:Disconnect()
        end)
    end
    
    self._state.Connections = {}
    
    if self._state.Callbacks.OnDisconnect then
        self._state.Callbacks.OnDisconnect()
    end
    
    self:_log("Info", "Disconnected")
    
    for i, instance in ipairs(INSTANCES) do
        if instance == self then
            table.remove(INSTANCES, i)
            break
        end
    end
end

function DiscordRPC:Destroy(): ()
    self:Disconnect()
    setmetatable(self :: any, nil)
end

function DiscordRPC.DisconnectAll(): ()
    for _, instance in ipairs(INSTANCES) do
        pcall(function()
            instance:Disconnect()
        end)
    end
    INSTANCES = {}
end

function DiscordRPC.GetVersion(): string
    return VERSION
end

getgenv().DiscordRPC = DiscordRPC

return DiscordRPC
