# OpenRPC

A fully-typed Discord Rich Presence library for Roblox exploits with complete type safety and automatic updates.

OpenRPC displays your Roblox activity on Discord in real-time, showing your friends what game you're playing, current server stats, and letting them join you directly from your Discord profile.

## Documentation

Full interactive documentation with examples: [OpenRPC Docs](https://openrpc.netlify.app/)

## Features

- Automatic game detection with player count and server status
- Up to 2 custom clickable buttons for game invites and profiles  
- Rich images with game icons and player avatars
- Configurable auto-update intervals
- Full Luau strict typing with complete type definitions
- 4 built-in activity presets (Game, Custom, Minimal, Detailed)
- Automatic executor and request function detection
- Anti-detection with cloneref support
- Comprehensive event system with callbacks
- 5-level logging system (None, Error, Warn, Info, Debug)

## Quick Start

Use loadstring to always get the latest version with automatic updates:

```lua
local OpenRPC = loadstring(game:HttpGet("https://raw.githubusercontent.com/formidy/OpenRPC/refs/heads/main/src/main.luau"))()

local rpc = OpenRPC.new()
rpc:Connect()
```

## Installation

### Step 1: Install Python Dependencies

```bash
pip install pypresence
```

### Step 2: Download and Run Bridge Server

Download the bridge server:
```bash
curl -O https://raw.githubusercontent.com/formidy/OpenRPC/refs/heads/main/src/bridge.py
```

Run it:
```bash
python bridge.py
```

You should see:
```
Discord RPC Bridge started on http://127.0.0.1:8080
Connected to Discord RPC
Press Ctrl+C to stop
```

> **Note**: The included bridge.py is a reference implementation demonstrating communication between the Luau script and Discord. It is not production-ready. For serious projects or production use, consider creating a proper background application with a dashboard interface. This bridge is intended for personal use, side projects, or as a foundation for building your own solution.

### Step 3: Load in Roblox

```lua
local OpenRPC = loadstring(game:HttpGet("https://raw.githubusercontent.com/formidy/OpenRPC/refs/heads/main/src/main.luau"))()
```

## Requirements

- Python 3.7 or higher
- pypresence library
- Roblox executor with HTTP request support (request, http_request, syn.request, etc.)
- Discord desktop client running

## Basic Usage

### Simple Setup

```lua
local OpenRPC = loadstring(game:HttpGet("https://raw.githubusercontent.com/formidy/OpenRPC/refs/heads/main/src/main.luau"))()

local rpc = OpenRPC.new({
    Preset = "Game",
    UpdateInterval = 5
})

rpc:Connect()
```

### Custom Activity

```lua
local rpc = OpenRPC.new({Preset = "Custom"})
rpc:Connect()

rpc:SetActivity("Playing Arsenal", "15 Kills | 3 Deaths")
   :AddButton("Join Game", "https://www.roblox.com/games/" .. game.PlaceId)
   :Update()
```

### With Event Callbacks

```lua
local rpc = OpenRPC.new()

rpc:On("OnConnect", function()
    print("Connected to Discord!")
end)

rpc:On("OnUpdate", function(activity)
    print("Updated:", activity.details)
end)

rpc:On("OnError", function(err)
    warn("Error:", err)
end)

rpc:Connect()
```

## Configuration Options

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `Port` | number | 8080 | Bridge server HTTP port |
| `UpdateInterval` | number | 5 | Seconds between auto-updates |
| `AutoUpdate` | boolean | true | Enable automatic presence updates |
| `Debug` | boolean | false | Enable debug logging |
| `AntiDetection` | boolean | true | Use cloneref for service access |
| `ClientID` | string | 1436600503692824586 | Discord Application ID |
| `Preset` | string | "Game" | Game, Custom, Minimal, or Detailed |
| `LogLevel` | string | "Info" | None, Error, Warn, Info, or Debug |

## Activity Presets

### Game (Default)
Shows game name, player count, and join button.

```lua
local rpc = OpenRPC.new({Preset = "Game"})
```

### Custom
Basic placeholder for custom activities.

```lua
local rpc = OpenRPC.new({Preset = "Custom"})
```

### Minimal
Just displays "Playing Roblox".

```lua
local rpc = OpenRPC.new({Preset = "Minimal"})
```

### Detailed
Full-featured with game icon, player avatar, and all buttons.

```lua
local rpc = OpenRPC.new({Preset = "Detailed"})
```

## API Reference

### Constructor

```lua
OpenRPC.new(config: Config?): OpenRPC
```

Creates a new OpenRPC instance with optional configuration.

### Connection Methods

```lua
rpc:Connect(): (boolean, string?)
```
Connects to Discord and applies the preset.

```lua
rpc:Disconnect(): ()
```
Disconnects and cleans up resources.

```lua
rpc:Destroy(): ()
```
Completely destroys the instance.

### Activity Methods

```lua
rpc:SetActivity(details: string?, state: string?): OpenRPC
```
Sets both detail and state lines.

```lua
rpc:SetDetails(details: string): OpenRPC
```
Sets the first line (bold text).

```lua
rpc:SetState(state: string): OpenRPC
```
Sets the second line.

```lua
rpc:SetGameActivity(options: table?): OpenRPC
```
Automatically populates with current game info.

```lua
rpc:SetPlayerActivity(activity: string, location: string?): OpenRPC
```
Sets activity with player stats and health.

```lua
rpc:Update(): (boolean, string?)
```
Immediately sends activity to Discord.

### Button Methods

```lua
rpc:AddButton(label: string, url: string): OpenRPC
```
Adds a clickable button (max 2).

```lua
rpc:SetButtons(buttons: {Button}): OpenRPC
```
Replaces all buttons at once.

```lua
rpc:ClearButtons(): OpenRPC
```
Removes all buttons.

### Image Methods

```lua
rpc:SetLargeImage(imageKey: string, text: string?): OpenRPC
```
Sets the large image with optional tooltip.

```lua
rpc:SetSmallImage(imageKey: string, text: string?): OpenRPC
```
Sets the small image overlay.

### Event Methods

```lua
rpc:On(event: string, callback: EventCallback): OpenRPC
```

Valid events: `OnConnect`, `OnUpdate`, `OnDisconnect`, `OnError`

### Utility Methods

```lua
rpc:GetState(): State
```
Returns connection state and metadata.

```lua
rpc:GetConfig(): Config
```
Returns current configuration.

```lua
rpc:GetActivity(): Activity
```
Returns current activity object.

```lua
rpc:SetConfig(config: Config): OpenRPC
```
Updates configuration after initialization.

```lua
rpc:Log(level: string, ...: any): ()
```
Manually logs a message.

### Static Methods

```lua
OpenRPC.DisconnectAll(): ()
```
Disconnects all RPC instances.

```lua
OpenRPC.GetVersion(): string
```
Returns library version.

## Advanced Examples

### Dynamic Player Stats

```lua
local OpenRPC = loadstring(game:HttpGet("https://raw.githubusercontent.com/formidy/OpenRPC/refs/heads/main/src/main.luau"))()
local Players = game:GetService("Players")
local player = Players.LocalPlayer

local rpc = OpenRPC.new({AutoUpdate = false})
rpc:Connect()

local function updatePresence()
    local char = player.Character
    if not char then
        rpc:SetState("Respawning..."):Update()
        return
    end
    
    local humanoid = char:FindFirstChildOfClass("Humanoid")
    if not humanoid then return end
    
    local health = math.floor((humanoid.Health / humanoid.MaxHealth) * 100)
    
    rpc:SetActivity("Playing Game", 
                    string.format("HP: %d%% | %d Players", health, #Players:GetPlayers()))
       :Update()
end

game:GetService("RunService").Heartbeat:Connect(function()
    updatePresence()
    task.wait(5)
end)
```

### Error Handling with Reconnection

```lua
local OpenRPC = loadstring(game:HttpGet("https://raw.githubusercontent.com/formidy/OpenRPC/refs/heads/main/src/main.luau"))()

local rpc = OpenRPC.new()
local reconnectAttempts = 0
local maxAttempts = 5

local function connect()
    local success = rpc:Connect()
    
    if not success then
        reconnectAttempts = reconnectAttempts + 1
        
        if reconnectAttempts < maxAttempts then
            warn(string.format("Reconnect attempt %d/%d in 3s...", reconnectAttempts, maxAttempts))
            task.wait(3)
            connect()
        else
            error("Failed to connect after " .. maxAttempts .. " attempts")
        end
    else
        reconnectAttempts = 0
        print("Connected successfully!")
    end
end

rpc:On("OnError", function(err)
    if not rpc:GetState().Connected then
        connect()
    end
end)

connect()
```

### Game-Specific Presence

```lua
local OpenRPC = loadstring(game:HttpGet("https://raw.githubusercontent.com/formidy/OpenRPC/refs/heads/main/src/main.luau"))()

local rpc = OpenRPC.new()
rpc:Connect()

local gamePresets = {
    [292439477] = function()
        rpc:SetActivity("Phantom Forces", "FPS Shooter")
           :AddButton("Join Game", "https://www.roblox.com/games/292439477")
           :Update()
    end,
    
    [606849621] = function()
        rpc:SetActivity("Jailbreak", "Cops vs Robbers")
           :AddButton("Join Game", "https://www.roblox.com/games/606849621")
           :Update()
    end
}

local preset = gamePresets[game.PlaceId]
if preset then
    preset()
else
    rpc:SetGameActivity():Update()
end
```

## Troubleshooting

### Bridge Not Running

```
Bridge not running on port 8080. Start: python bridge.py
```

Make sure the bridge server is running in a terminal window.

### No Request Function Found

```
[OpenRPC] No request function found. Executor not supported.
```

Your executor doesn't support HTTP requests. Try a different executor.

### Port Already in Use

Change the port in both bridge.py and your Roblox config:

```lua
local rpc = OpenRPC.new({Port = 8081})
```

### Connection Failed

Common causes:
- Discord is not running
- Bridge server crashed or not started
- Firewall blocking localhost connections
- Wrong port configured

## Type Definitions

Complete TypeScript-style type definitions are included for strict type checking:

```lua
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
```

## Bridge Server

The Python bridge server facilitates communication between Roblox and Discord by running a local HTTP server that forwards presence updates.

### About the Bridge

The included `bridge.py` is a **reference implementation** demonstrating how to establish communication between the Luau script and Discord RPC. It is not intended for production use.

**For production or serious projects**, you should:
- Create a proper background application with a GUI dashboard
- Implement proper error handling and logging
- Add authentication and security measures
- Consider user preferences and persistence
- Package it as a standalone executable

The current bridge is suitable for:
- Personal use and experimentation
- Side projects and proof-of-concepts
- Learning how the communication protocol works
- Building your own custom solution

### Custom Discord Application

To use your own Discord Application ID:

1. Go to [Discord Developer Portal](https://discord.com/developers/applications)
2. Create a new application
3. Copy the Application ID
4. Replace `CLIENT_ID` in bridge.py
5. Set `ClientID` in your Roblox config

### Improving the Bridge

If you plan to use this in a serious project, consider:

- Creating a system tray application that runs on startup
- Adding a settings interface for configuration
- Implementing reconnection logic and health checks
- Adding support for multiple simultaneous connections
- Creating update notifications and version checking
- Building platform-specific installers

The bridge architecture is designed to be flexible enough for you to implement your own solution based on your specific needs.

## Why Use Loadstring?

Loading via `loadstring(game:HttpGet(...))` ensures you always have the latest version with:

- Bug fixes and security patches
- New features and improvements
- Performance optimizations
- Type definition updates

No need to manually re-download or update files.

## Downloads

- **Main Library**: [main.luau](https://raw.githubusercontent.com/formidy/OpenRPC/refs/heads/main/src/main.luau)
- **Bridge Server**: [bridge.py](https://raw.githubusercontent.com/formidy/OpenRPC/refs/heads/main/src/bridge.py)

## License

MIT License - See [LICENSE](LICENSE) for details.

## Credits

**Library Author**: morefeinn  
**Version**: 8.0.0  
**License**: MIT

## Support

If you encounter issues or have questions, please open an issue on GitHub.

---

Star this repository if you find it useful!
