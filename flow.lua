--[[
    Flow UI 1.0.0 — component library for Roblox executors
    single file build, generated from src/ by build.mjs
]]

local __modules = {}
local __loaded = {}

-- PURE-BEGIN:flowStartupCheckpoint
local __flowStartupCheckpointCount = 0
local function __flowStartupCheckpoint()
    __flowStartupCheckpointCount += 1
    if __flowStartupCheckpointCount % 2 == 0
        and task
        and type(task.wait) == "function"
    then
        task.wait()
    end
end
-- PURE-END:flowStartupCheckpoint

--[[
    Detection hygiene.

    cloneref hands back a reference the game cannot compare against its own, so a
    script that hooks game.GetService or keeps a table of "known" service objects
    has nothing of ours to match. Services are fetched once and cached.
]]
local __cloneref = cloneref or clonereference or function(object)
    return object
end

local __serviceCache = {}

local function __service(name)
    local hit = __serviceCache[name]
    if hit then
        return hit
    end
    local ok, service = pcall(function()
        return game:GetService(name)
    end)
    if not ok or not service then
        return nil
    end
    local cloned
    ok, cloned = pcall(__cloneref, service)
    if ok and cloned then
        service = cloned
    end
    __serviceCache[name] = service
    return service
end

local function __require(name)
    local hit = __loaded[name]
    if hit ~= nil then
        return hit
    end
    local factory = __modules[name]
    if not factory then
        error("flow: no module named " .. tostring(name), 2)
    end
    local value = factory(__require)
    __loaded[name] = value
    return value
end

__flowStartupCheckpoint()
__modules["core/audio"] = function(require)
__flowStartupCheckpoint()
local SoundService = __service("SoundService")

--[[
    Short UI sounds. Every clip ships with the Roblox client under rbxasset://,
    so nothing here can be moderated, rate-limited or fail to fetch.

    One Sound instance per name is reused rather than cloned — replaying cuts the
    previous tail, which is what you want when a toggle is spammed.
]]

local Audio = {}

Audio.enabled = true
-- 0.4 was inaudible over game audio — the clips are short, soft system sounds
-- and the quietest of them landed near 0.09. The per-clip ratios below are
-- unchanged, so the balance between them is the same, just louder overall.
Audio.volume = 0.7

Audio.set = {
    -- pitch is what separates on from off; same clip, brighter or duller
    on = { Id = "rbxasset://sounds/switch.wav", Speed = 1.2, Volume = 1 },
    off = { Id = "rbxasset://sounds/switch.wav", Speed = 0.9, Volume = 0.85 },
    click = { Id = "rbxasset://sounds/clickfast.wav", Speed = 1.5, Volume = 0.7 },
    select = { Id = "rbxasset://sounds/clickfast.wav", Speed = 1.9, Volume = 0.5 },
    open = { Id = "rbxasset://sounds/switch3.wav", Speed = 1.1, Volume = 0.75 },
    close = { Id = "rbxasset://sounds/switch3.wav", Speed = 0.85, Volume = 0.65 },
    -- switch.wav at 2.4x is ~0.1s, short enough to read as a detent rather than a click
    tick = { Id = "rbxasset://sounds/switch.wav", Speed = 2.4, Volume = 0.32 },
}

local pool = {}
local holder

-- The sound pool used to live in SoundService, where any game script could
-- enumerate a folder called "FlowAudio". It now sits inside the protected GUI
-- container alongside everything else; a Sound parented to a GUI still plays 2D.
function Audio.attach(host)
    Audio.host = host
    if holder then
        pcall(function()
            holder:Destroy()
        end)
        holder = nil
        table.clear(pool)
    end
end

local function container()
    if holder and holder.Parent then
        return holder
    end
    holder = Instance.new("Folder")
    holder.Name = ""

    local target = Audio.host
    local ok = target ~= nil
        and pcall(function()
            holder.Parent = target
        end)
    if not ok then
        pcall(function()
            holder.Parent = __service("SoundService")
        end)
    end
    return holder
end

local function instance(name)
    local hit = pool[name]
    if hit and hit.Parent then
        return hit
    end

    local spec = Audio.set[name]
    if not spec then
        return nil
    end

    local sound = Instance.new("Sound")
    sound.Name = "flow_" .. name
    sound.SoundId = spec.Id
    sound.PlaybackSpeed = spec.Speed or 1
    sound.Parent = container()

    pool[name] = sound
    return sound
end

function Audio.play(name, speed)
    if not Audio.enabled then
        return
    end
    local spec = Audio.set[name]
    if not spec then
        return
    end
    pcall(function()
        local sound = instance(name)
        if not sound then
            return
        end
        sound.Volume = Audio.volume * (spec.Volume or 1)
        sound.PlaybackSpeed = speed or spec.Speed or 1
        sound.TimePosition = 0
        sound:Play()
    end)
end

-- replace a clip, e.g. Flow.Audio.define("on", { Id = "rbxassetid://123", Speed = 1 })
function Audio.define(name, spec)
    Audio.set[name] = spec
    local hit = pool[name]
    if hit then
        hit:Destroy()
        pool[name] = nil
    end
end

function Audio.destroy()
    for _, sound in pairs(pool) do
        pcall(function()
            sound:Destroy()
        end)
    end
    table.clear(pool)
    if holder then
        pcall(function()
            holder:Destroy()
        end)
        holder = nil
    end
end

return Audio
end

__flowStartupCheckpoint()
__modules["core/craft"] = function(require)
__flowStartupCheckpoint()
local Util = require("core/util")
local Theme = require("core/theme")
local Icons = require("core/icons")

local Craft = {}

local function fill(props, defaults)
    for k, v in pairs(defaults) do
        if props[k] == nil then
            props[k] = v
        end
    end
    return props
end

function Craft.frame(props)
    local token = props.Token
    local radius = props.Radius
    local edge = props.Edge
    local edgeAlpha = props.EdgeTransparency
    props.Token, props.Radius, props.Edge, props.EdgeTransparency = nil, nil, nil, nil

    fill(props, { BorderSizePixel = 0, BackgroundColor3 = Theme.get(token or "surface") })
    local f = Util.new("Frame", props)

    if token then
        Theme.bind(f, "BackgroundColor3", token)
    end
    if radius then
        Util.corner(f, radius)
    end
    if edge then
        local s = Util.stroke(f, Theme.get(edge), 1, edgeAlpha or 0)
        Theme.bind(s, "Color", edge)
    end
    return f
end

function Craft.text(props)
    local token = props.Token
    props.Token = nil

    fill(props, {
        BackgroundTransparency = 1,
        FontFace = Theme.font.medium,
        TextSize = 14,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Center,
        Size = UDim2.fromScale(1, 1),
        Text = "",
    })

    local l = Util.new("TextLabel", props)
    if props.TextColor3 == nil then
        Theme.bind(l, "TextColor3", token or "text")
    end
    return l
end

function Craft.button(props)
    local token = props.Token
    local radius = props.Radius
    local edge = props.Edge
    props.Token, props.Radius, props.Edge = nil, nil, nil

    fill(props, {
        AutoButtonColor = false,
        Text = "",
        BorderSizePixel = 0,
        BackgroundTransparency = token and 0 or 1,
        BackgroundColor3 = Theme.get(token or "surfaceAlt"),
    })

    local b = Util.new("TextButton", props)
    if token then
        Theme.bind(b, "BackgroundColor3", token)
    end
    if radius then
        Util.corner(b, radius)
    end
    if edge then
        local s = Util.stroke(b, Theme.get(edge), 1, 0)
        Theme.bind(s, "Color", edge)
    end
    return b
end

function Craft.scroll(props)
    fill(props, {
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ScrollBarThickness = 3,
        ScrollBarImageTransparency = 0.25,
        ScrollBarImageColor3 = Theme.get("raisedHi"),
        CanvasSize = UDim2.new(),
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        ScrollingDirection = Enum.ScrollingDirection.Y,
        ElasticBehavior = Enum.ElasticBehavior.Never,
        TopImage = "rbxasset://textures/ui/Scroll/scroll-middle.png",
        BottomImage = "rbxasset://textures/ui/Scroll/scroll-middle.png",
    })
    local s = Util.new("ScrollingFrame", props)
    Theme.bind(s, "ScrollBarImageColor3", "raisedHi")
    return s
end

function Craft.divider(parent, order, inset)
    local d = Craft.frame({
        Name = "Divider",
        Token = "lineSoft",
        Size = UDim2.new(1, -(inset or 0) * 2, 0, 1),
        Position = UDim2.fromOffset(inset or 0, 0),
        LayoutOrder = order or 0,
        Parent = parent,
    })
    return d
end

function Craft.tile(props)
    local holder = Craft.frame({
        Name = "Tile",
        Token = props.Token or "surfaceAlt",
        Radius = props.Radius or Theme.radius.tile,
        Size = UDim2.fromOffset(props.Size or 26, props.Size or 26),
        Position = props.Position,
        AnchorPoint = props.AnchorPoint,
        LayoutOrder = props.LayoutOrder,
        ZIndex = props.ZIndex or 2,
        Parent = props.Parent,
    })
    local glyph = Icons.draw({
        Icon = props.Icon or "cube",
        Size = props.IconSize or math.floor((props.Size or 26) * 0.55),
        Token = props.IconToken,
        Color = props.IconColor or Theme.get("textDim"),
        Hole = Theme.get(props.Token or "surfaceAlt"),
        ZIndex = (props.ZIndex or 2) + 1,
        Parent = holder,
    })
    return holder, glyph
end

function Craft.chip(props)
    local holder = Craft.frame({
        Name = "Chip",
        Token = props.Token or "raised",
        Radius = props.Radius or Theme.radius.chip,
        Size = UDim2.fromOffset(0, props.Height or 22),
        AutomaticSize = Enum.AutomaticSize.X,
        LayoutOrder = props.LayoutOrder,
        ZIndex = props.ZIndex or 2,
        Parent = props.Parent,
    })
    Util.pad(holder, 0, props.PadX or 7, 0, props.PadX or 7)
    local label = Craft.text({
        Name = "Value",
        Text = props.Text or "",
        Token = props.TextToken or "textDim",
        TextSize = props.TextSize or 12,
        FontFace = Theme.font.semi,
        AutomaticSize = Enum.AutomaticSize.X,
        Size = UDim2.new(0, 0, 1, 0),
        TextXAlignment = Enum.TextXAlignment.Center,
        ZIndex = (props.ZIndex or 2) + 1,
        Parent = holder,
    })
    return holder, label
end

function Craft.head(props)
    local row = Craft.frame({
        Name = "Head",
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        LayoutOrder = props.LayoutOrder or 0,
        ZIndex = props.ZIndex or 2,
        Parent = props.Parent,
    })
    Util.list(row, 3)

    Craft.text({
        Name = "Title",
        Text = props.Name or "",
        Token = "text",
        TextSize = 13.5,
        FontFace = Theme.font.semi,
        Size = UDim2.new(1, props.Trim or 0, 0, 17),
        ZIndex = (props.ZIndex or 2) + 1,
        Parent = row,
    })

    if props.Desc and props.Desc ~= "" then
        Craft.text({
            Name = "Desc",
            Text = props.Desc,
            Token = "textFaint",
            TextSize = 12,
            FontFace = Theme.font.regular,
            TextWrapped = true,
            LineHeight = 1.15,
            Size = UDim2.new(1, props.Trim or 0, 0, 0),
            AutomaticSize = Enum.AutomaticSize.Y,
            ZIndex = (props.ZIndex or 2) + 1,
            Parent = row,
        })
    end

    return row
end

function Craft.gradient(parent, from, to, rotation, transparency)
    return Util.new("UIGradient", {
        Color = ColorSequence.new(from, to),
        Rotation = rotation or 0,
        Transparency = transparency or NumberSequence.new(0),
        Parent = parent,
    })
end

return Craft
end

__flowStartupCheckpoint()
__modules["core/icons"] = function(require)
__flowStartupCheckpoint()
local Util = require("core/util")
local Theme = require("core/theme")
local Lucide = require("core/lucide")

local Icons = {}

--[[
    Real Lucide artwork, drawn from spritesheets, is the default. The vector set
    below stays as the fallback for anything Lucide has no glyph for, and as the
    escape hatch if you would rather not depend on image assets at all:

        Flow.Icons.sprites = false
]]
Icons.sprites = Lucide

--[[
    Icons are authored on a 100x100 grid in the style of Lucide: 2px strokes on a
    24px canvas, round caps, no fills. On this grid that is a stroke weight of 8.

    line() is the workhorse — give it two endpoints and it works out the centre,
    length and angle itself, so an icon reads as a list of pen strokes rather than
    a pile of hand-computed rotations.
]]

local WEIGHT = 9.5

local function line(x1, y1, x2, y2, t, a)
    t = t or WEIGHT
    local dx, dy = x2 - x1, y2 - y1
    local len = math.sqrt(dx * dx + dy * dy)
    -- + t so the rounded caps sit past the endpoints, the way a round linecap does
    return { "bar", (x1 + x2) / 2, (y1 + y2) / 2, len + t, t, math.deg(math.atan2(dy, dx)), 999, a or 0 }
end

local function circle(x, y, d, t, a)
    return { "ring", x, y, d, d, 0, 999, a or 0, t or WEIGHT }
end

local function rect(x, y, w, h, r, t, a)
    return { "box", x, y, w, h, 0, r or 0, a or 0, t or WEIGHT }
end

local function disc(x, y, d, a)
    return { "dot", x, y, d, d, 0, 999, a or 0 }
end

-- solid shape rather than an outline, for glyphs that read better filled at 13px
local function slab(x, y, w, h, rot, r, a)
    return { "bar", x, y, w, h, rot or 0, r or 0, a or 0 }
end

local function hole(x, y, d)
    return { "hole", x, y, d, d, 0, 999, 0 }
end

-- Names that resolve to a real image instead of drawn primitives. Anything that
-- takes an Icon accepts these the same way it accepts a shape name.
Icons.images = {
    -- the Image asset, not the Decal that wraps it (78239445499664) — decal ids
    -- do not render in ImageLabel.Image
    brand = "rbxassetid://120877581663049",
}

local set = {
    -- kept as the fallback silhouette if the brand image ever fails to load
    ["brand-vector"] = { slab(44, 50, 12, 60, -12, 5), slab(59, 26, 34, 12, -12, 5), slab(55, 50, 26, 12, -12, 5) },

    ----------------------------------------------------------------------------
    -- glyphs
    ----------------------------------------------------------------------------

    plus = { line(50, 20, 50, 80), line(20, 50, 80, 50) },
    minus = { line(20, 50, 80, 50) },
    close = { line(24, 24, 76, 76), line(76, 24, 24, 76) },
    check = { line(16, 52, 40, 76), line(40, 76, 84, 26) },

    ["chevron-down"] = { line(24, 38, 50, 64), line(76, 38, 50, 64) },
    ["chevron-up"] = { line(24, 62, 50, 36), line(76, 62, 50, 36) },
    ["chevron-right"] = { line(38, 24, 64, 50), line(38, 76, 64, 50) },
    ["chevron-left"] = { line(62, 24, 36, 50), line(62, 76, 36, 50) },
    ["chevrons-right"] = {
        line(20, 26, 46, 50),
        line(20, 74, 46, 50),
        line(52, 26, 78, 50),
        line(52, 74, 78, 50),
    },
    ["arrow-right"] = { line(16, 50, 84, 50), line(58, 24, 84, 50), line(58, 76, 84, 50) },
    ["arrow-up"] = { line(50, 84, 50, 16), line(24, 42, 50, 16), line(76, 42, 50, 16) },
    dots = { disc(20, 50, 12), disc(50, 50, 12), disc(80, 50, 12) },

    ----------------------------------------------------------------------------
    -- interface
    ----------------------------------------------------------------------------

    search = { circle(44, 44, 48), line(68, 68, 86, 86) },
    -- rim + hub + stubby teeth that touch the rim: reads as a cog, not a sun
    gear = {
        circle(50, 50, 46, 9),
        disc(50, 50, 16),
        line(50, 14, 50, 27, 15),
        line(50, 86, 50, 73, 15),
        line(14, 50, 27, 50, 15),
        line(86, 50, 73, 50, 15),
        line(24, 24, 33, 33, 15),
        line(76, 76, 67, 67, 15),
        line(76, 24, 67, 33, 15),
        line(24, 76, 33, 67, 15),
    },
    bell = {
        line(28, 64, 28, 44),
        line(72, 64, 72, 44),
        line(28, 44, 50, 24),
        line(72, 44, 50, 24),
        line(18, 66, 82, 66),
        disc(50, 82, 13),
    },
    user = {
        circle(50, 30, 32),
        line(18, 86, 18, 74),
        line(82, 86, 82, 74),
        line(18, 74, 34, 60),
        line(82, 74, 66, 60),
        line(34, 60, 66, 60),
    },
    users = {
        circle(40, 30, 28),
        line(12, 86, 12, 74),
        line(68, 86, 68, 74),
        line(12, 74, 26, 62),
        line(68, 74, 54, 62),
        line(26, 62, 54, 62),
        circle(76, 32, 22, 7, 0.35),
        line(88, 84, 88, 72, 7, 0.35),
        line(88, 72, 78, 62, 7, 0.35),
    },
    keyboard = {
        rect(50, 50, 84, 54, 10),
        disc(30, 42, 8),
        disc(50, 42, 8),
        disc(70, 42, 8),
        line(34, 62, 66, 62),
    },
    logout = {
        line(24, 18, 24, 82),
        line(24, 18, 52, 18),
        line(24, 82, 52, 82),
        line(46, 50, 88, 50),
        line(72, 34, 88, 50),
        line(72, 66, 88, 50),
    },
    folder = {
        line(12, 28, 40, 28),
        line(40, 28, 50, 42),
        line(12, 28, 12, 80),
        line(12, 80, 88, 80),
        line(88, 80, 88, 42),
        line(50, 42, 88, 42),
    },
    sliders = { line(12, 32, 88, 32), disc(66, 32, 20), line(12, 68, 88, 68), disc(34, 68, 20) },
    filter = { line(16, 26, 84, 26), line(30, 50, 70, 50), line(42, 74, 58, 74) },
    palette = { circle(50, 50, 76), disc(36, 38, 13), disc(62, 34, 13), disc(66, 60, 13) },
    info = { circle(50, 50, 76), disc(50, 30, 10), line(50, 46, 50, 70) },
    alert = { circle(50, 50, 76), line(50, 28, 50, 54), disc(50, 70, 10) },
    code = { line(34, 30, 14, 50), line(14, 50, 34, 70), line(66, 30, 86, 50), line(86, 50, 66, 70) },
    link = { line(42, 58, 58, 42), line(36, 64, 22, 78), line(64, 36, 78, 22), circle(24, 76, 30, 8), circle(76, 24, 30, 8) },
    cloud = { disc(36, 58, 34), disc(64, 52, 42), slab(50, 66, 56, 24, 0, 12) },
    badge = {
        circle(50, 34, 44),
        line(34, 60, 26, 90),
        line(66, 60, 74, 90),
        line(26, 90, 50, 78),
        line(74, 90, 50, 78),
    },
    chart = { line(14, 84, 86, 84), line(30, 84, 30, 58), line(50, 84, 50, 36), line(70, 84, 70, 20) },
    signal = { line(18, 84, 18, 70), line(38, 84, 38, 54), line(60, 84, 60, 36), line(82, 84, 82, 18) },
    gauge = { circle(50, 52, 68), disc(50, 52, 12), line(50, 52, 70, 32) },
    clock = { circle(50, 50, 76), line(50, 28, 50, 52), line(50, 52, 68, 62) },
    hourglass = {
        line(22, 16, 78, 16),
        line(22, 84, 78, 84),
        line(30, 16, 30, 34),
        line(70, 16, 70, 34),
        line(30, 34, 50, 50),
        line(70, 34, 50, 50),
        line(30, 84, 30, 66),
        line(70, 84, 70, 66),
        line(30, 66, 50, 50),
        line(70, 66, 50, 50),
    },
    refresh = {
        circle(50, 50, 62),
        line(62, 12, 80, 20),
        line(80, 20, 74, 38),
        line(38, 88, 20, 80),
        line(20, 80, 26, 62),
    },
    power = { circle(50, 56, 58), line(50, 14, 50, 44) },
    pin = { circle(50, 40, 44), disc(50, 40, 14), line(50, 62, 50, 88) },
    grid = { rect(31, 31, 26, 26, 5, 7), rect(69, 31, 26, 26, 5, 7), rect(31, 69, 26, 26, 5, 7), rect(69, 69, 26, 26, 5, 7) },
    layers = { slab(50, 34, 46, 46, 45, 8), slab(50, 62, 46, 46, 45, 8, 0.55) },
    expand = {
        line(14, 32, 14, 14),
        line(14, 14, 32, 14),
        line(68, 14, 86, 14),
        line(86, 14, 86, 32),
        line(86, 68, 86, 86),
        line(86, 86, 68, 86),
        line(32, 86, 14, 86),
        line(14, 86, 14, 68),
    },
    cube = { rect(50, 50, 64, 64, 12), line(50, 18, 50, 50, 7), line(50, 50, 22, 66, 7), line(50, 50, 78, 66, 7) },
    wand = { line(20, 80, 74, 26), disc(80, 20, 15), disc(24, 24, 10), disc(84, 58, 10) },
    sparkle = { line(50, 16, 50, 84, 9), line(16, 50, 84, 50, 9), line(28, 28, 72, 72, 7), line(72, 28, 28, 72, 7) },

    ----------------------------------------------------------------------------
    -- combat
    ----------------------------------------------------------------------------

    target = {
        circle(50, 50, 66),
        disc(50, 50, 14),
        line(50, 8, 50, 20),
        line(50, 80, 50, 92),
        line(8, 50, 20, 50),
        line(80, 50, 92, 50),
    },
    swords = {
        line(22, 78, 80, 20, 9),
        line(78, 78, 20, 20, 9),
        line(12, 70, 30, 88),
        line(88, 70, 70, 88),
    },
    shield = {
        line(20, 26, 50, 14),
        line(80, 26, 50, 14),
        line(20, 26, 20, 52),
        line(80, 26, 80, 52),
        line(20, 52, 50, 88),
        line(80, 52, 50, 88),
    },
    heart = { disc(34, 40, 40), disc(66, 40, 40), slab(50, 58, 48, 48, 45, 9) },
    flame = { disc(50, 68, 42), slab(50, 36, 34, 34, 45, 9) },
    bolt = {
        line(58, 10, 24, 54),
        line(24, 54, 52, 54),
        line(52, 54, 42, 90),
        line(42, 90, 76, 46),
        line(76, 46, 48, 46),
        line(48, 46, 58, 10),
    },
    ban = { circle(50, 50, 74), line(26, 74, 74, 26) },
    lock = { rect(50, 68, 56, 40, 9), line(34, 48, 34, 34), line(66, 48, 66, 34), line(34, 34, 50, 24), line(66, 34, 50, 24) },
    hitbox = {
        rect(50, 50, 62, 62, 10),
        disc(50, 50, 14),
        line(50, 24, 50, 36, 6, 0.35),
        line(50, 64, 50, 76, 6, 0.35),
        line(24, 50, 36, 50, 6, 0.35),
        line(64, 50, 76, 50, 6, 0.35),
    },
    skull = { disc(50, 42, 56), slab(50, 76, 36, 22, 0, 7), hole(36, 42, 16), hole(64, 42, 16) },
    magnet = {
        line(26, 72, 26, 40, 9),
        line(74, 72, 74, 40, 9),
        line(26, 40, 50, 20, 9),
        line(74, 40, 50, 20, 9),
        line(18, 72, 34, 72),
        line(66, 72, 82, 72),
    },

    ----------------------------------------------------------------------------
    -- movement
    ----------------------------------------------------------------------------

    fly = { line(12, 50, 88, 20), line(88, 20, 56, 86), line(56, 86, 46, 56), line(46, 56, 12, 50) },
    jump = { line(50, 64, 50, 18), line(30, 38, 50, 18), line(70, 38, 50, 18), line(18, 86, 82, 86) },
    noclip = { rect(50, 50, 62, 62, 10), line(26, 74, 74, 26) },
    teleport = { circle(26, 74, 28), circle(74, 26, 28), line(42, 58, 58, 42) },
    orbit = { circle(50, 50, 60), disc(50, 50, 18), disc(86, 28, 14) },

    ----------------------------------------------------------------------------
    -- visuals
    ----------------------------------------------------------------------------

    eye = { circle(50, 50, 50), disc(50, 50, 18), line(8, 50, 20, 50), line(80, 50, 92, 50) },
    esp = {
        line(16, 34, 16, 16),
        line(16, 16, 34, 16),
        line(66, 16, 84, 16),
        line(84, 16, 84, 34),
        line(84, 66, 84, 84),
        line(84, 84, 66, 84),
        line(34, 84, 16, 84),
        line(16, 84, 16, 66),
        disc(50, 50, 16),
    },
    tracer = { disc(50, 18, 18), line(50, 34, 50, 76), line(50, 86, 30, 60), line(50, 86, 70, 60) },
    ghost = { disc(50, 44, 52), slab(50, 62, 52, 32, 0, 7), hole(38, 42, 12), hole(62, 42, 12) },
    radar = { circle(50, 50, 78), circle(50, 50, 42, 7, 0.4), disc(50, 50, 11), line(50, 50, 76, 30) },
    wall = { rect(50, 50, 76, 60, 6), line(12, 50, 88, 50), line(50, 20, 50, 50), line(32, 50, 32, 80), line(68, 50, 68, 80) },

    ----------------------------------------------------------------------------
    -- utility
    ----------------------------------------------------------------------------

    backpack = { rect(50, 62, 58, 48, 10), line(36, 38, 36, 26), line(64, 38, 64, 26), line(36, 26, 64, 26), line(38, 62, 62, 62) },
    coin = { circle(50, 50, 70), line(50, 32, 50, 68), line(38, 40, 62, 40), line(38, 60, 62, 60) },
    flask = { line(40, 14, 40, 44), line(60, 14, 60, 44), line(32, 14, 68, 14), line(40, 44, 20, 82), line(60, 44, 80, 82), line(20, 82, 80, 82) },
    crown = {
        line(14, 30, 24, 76),
        line(24, 76, 76, 76),
        line(76, 76, 86, 30),
        line(14, 30, 32, 46),
        line(32, 46, 50, 20),
        line(50, 20, 68, 46),
        line(68, 46, 86, 30),
    },
    star = { line(50, 14, 50, 86, 9), line(14, 50, 86, 50, 9), line(26, 26, 74, 74, 8), line(74, 26, 26, 74, 8) },
    branch = { circle(28, 22, 24), circle(28, 78, 24), line(28, 34, 28, 66), line(40, 78, 68, 78), circle(80, 78, 24) },
}

-- Second names for the same glyph, so modules can be named after what they do.
-- Resolved before both the sprite and the vector lookup.
local alias = {
    crosshair = "target",
    aim = "target",
    combat = "swords",
    movement = "chevrons-right",
    visuals = "eye",
    render = "expand",
    speed = "chevrons-right",
    settings = "gear",
    fps = "gauge",
    ping = "signal",
    box = "cube",
    scan = "esp",
    cog = "gear",

    silentaim = "target",
    aimbot = "target",
    killaura = "swords",
    reach = "expand",
    nametags = "badge",
    chams = "layers",
    fullbright = "sparkle",
    xray = "eye",
    antiafk = "clock",
    autofarm = "refresh",
    serverhop = "link",
    rejoin = "refresh",
    bhop = "jump",
    walkspeed = "chevrons-right",
    jumppower = "jump",
    infjump = "jump",
    godmode = "shield",
    player = "user",
    utility = "sliders",
    exploit = "code",
    world = "orbit",
    item = "cube",
    tool = "swords",
}

for from, to in pairs(alias) do
    set[from] = set[to]
end

Icons.alias = alias

Icons.set = set

function Icons.list()
    local names = {}
    for k in pairs(set) do
        table.insert(names, k)
    end
    for k in pairs(Icons.images) do
        if not set[k] then
            table.insert(names, k)
        end
    end
    for k in pairs(Icons.sprites or {}) do
        if not set[k] and not Icons.images[k] then
            table.insert(names, k)
        end
    end
    table.sort(names)
    return names
end

function Icons.define(name, parts)
    set[name] = parts
end

-- register an image under a shape name, e.g. Icons.image("brand", "rbxassetid://123")
function Icons.image(name, asset)
    Icons.images[name] = asset
end

-- authoring helpers, exposed so custom icons can be written the same way
Icons.line = line
Icons.circle = circle
Icons.rect = rect
Icons.disc = disc
Icons.slab = slab
Icons.hole = hole

local function assetOf(name)
    if typeof(name) ~= "string" then
        return nil
    end
    local mapped = Icons.images[name]
    if mapped then
        return mapped
    end
    if name:match("^rbxasset") or name:match("^rbxthumb") or name:match("^http") then
        return name
    end
    return nil
end

function Icons.draw(props)
    local size = props.Size or 16
    local name = props.Icon
    if typeof(name) == "string" and Icons.alias[name] and not Icons.images[name] then
        name = Icons.alias[name]
    end
    local holder = Util.new("Frame", {
        Name = "Icon",
        BackgroundTransparency = 1,
        Size = UDim2.fromOffset(size, size),
        Position = props.Position or UDim2.fromScale(0.5, 0.5),
        AnchorPoint = props.AnchorPoint or Vector2.new(0.5, 0.5),
        ZIndex = props.ZIndex or 2,
        Parent = props.Parent,
    })

    -- a Lucide sprite wins over the vector drawing when one exists
    local sprite = Icons.sprites and typeof(name) == "string" and Icons.sprites[name]
    if sprite and not Icons.images[name] then
        local img = Util.new("ImageLabel", {
            BackgroundTransparency = 1,
            Size = UDim2.fromScale(1, 1),
            Image = "rbxassetid://" .. tostring(sprite[1]),
            ImageRectSize = Vector2.new(sprite[2], sprite[3]),
            ImageRectOffset = Vector2.new(sprite[4], sprite[5]),
            ImageTransparency = props.Transparency or 0,
            ZIndex = holder.ZIndex,
            Parent = holder,
        })
        if props.Token then
            Theme.bind(img, "ImageColor3", props.Token)
        else
            img.ImageColor3 = props.Color or Theme.get("text")
        end
        holder:SetAttribute("Image", true)
        return holder
    end

    local asset = assetOf(name)
    if asset then
        local img = Util.new("ImageLabel", {
            BackgroundTransparency = 1,
            Size = UDim2.fromScale(1, 1),
            Image = asset,
            ImageTransparency = props.Transparency or 0,
            ScaleType = Enum.ScaleType.Fit,
            ZIndex = holder.ZIndex,
            Parent = holder,
        })
        -- brand marks keep their own colours unless a tint is explicitly requested
        if props.Token then
            Theme.bind(img, "ImageColor3", props.Token)
        elseif props.Color then
            img.ImageColor3 = props.Color
        end
        holder:SetAttribute("Image", true)
        Icons.rescue(holder, img, props, size)
        return holder
    end

    local parts = set[name]
    if not parts then
        return holder
    end

    local unit = size / 100
    local fill = props.Color or Theme.get("text")
    local void = props.Hole or Theme.get("surface")
    local alpha = props.Transparency or 0

    for _, p in ipairs(parts) do
        local kind, x, y, w, h, rot, r, a, t = p[1], p[2], p[3], p[4], p[5], p[6], p[7], p[8], p[9]
        local piece = Util.new("Frame", {
            Name = kind,
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.fromScale(x / 100, y / 100),
            Size = UDim2.fromOffset(math.max(w * unit, 1), math.max(h * unit, 1)),
            Rotation = rot,
            BorderSizePixel = 0,
            BackgroundTransparency = alpha + (a or 0) * (1 - alpha),
            ZIndex = holder.ZIndex,
            Parent = holder,
        })

        if r and r > 0 then
            Util.corner(piece, r >= 999 and UDim.new(1, 0) or UDim.new(0, math.max(r * unit, 1)))
        end

        if kind == "ring" or kind == "box" then
            piece.BackgroundTransparency = 1
            local edge = Util.stroke(piece, fill, math.max((t or WEIGHT) * unit, 1), alpha + (a or 0) * (1 - alpha))
            if props.Token then
                Theme.bind(edge, "Color", props.Token)
            end
        elseif kind == "hole" then
            piece.BackgroundColor3 = void
            piece.ZIndex = holder.ZIndex + 1
            if props.HoleToken then
                Theme.bind(piece, "BackgroundColor3", props.HoleToken)
            end
        else
            piece.BackgroundColor3 = fill
            if props.Token then
                Theme.bind(piece, "BackgroundColor3", props.Token)
            end
        end
    end

    return holder
end

--[[
    A dead asset id renders as nothing at all, which reads as a missing icon
    rather than a broken one. Scripts carry plenty of them — ids get moderated or
    deleted long after the script was written — so when the fetch actually fails,
    swap in a drawn glyph.

    The replacement pieces are moved into the original holder rather than nested
    inside a second one, because Icons.tint colours the holder's direct children.
]]
function Icons.rescue(holder, img, props, size)
    task.spawn(function()
        if img.IsLoaded then
            return
        end

        local failed = false
        local provider = __service("ContentProvider")
        if provider then
            -- PreloadAsync yields until the fetch settles, but with a card full
            -- of icons the status callback does not reliably fire for every
            -- one, so its verdict is only ever used to fail fast
            pcall(function()
                provider:PreloadAsync({ img }, function(_, status)
                    failed = status ~= Enum.AssetFetchStatus.Success
                end)
            end)
        end

        -- the authority is IsLoaded: once the fetch has settled, an image that
        -- still has not loaded is one that never will
        if not failed then
            local deadline = os.clock() + 5
            while not img.IsLoaded and os.clock() < deadline do
                task.wait(0.25)
            end
            failed = not img.IsLoaded
        end

        if not failed or img.IsLoaded or not holder.Parent then
            return
        end

        local spare = Icons.draw({
            Icon = props.Fallback or "cube",
            Size = size,
            Token = props.Token,
            Color = props.Color,
            Hole = props.Hole,
            HoleToken = props.HoleToken,
            Transparency = props.Transparency,
            ZIndex = props.ZIndex,
        })
        img:Destroy()
        -- the fallback may itself be a sprite rather than a drawn glyph, and
        -- Icons.tint reads this attribute to decide how to colour the holder
        holder:SetAttribute("Image", spare:GetAttribute("Image"))
        for _, piece in ipairs(spare:GetChildren()) do
            piece.Parent = holder
        end
        spare:Destroy()
    end)
end

function Icons.tint(holder, color, void)
    if holder:GetAttribute("Image") then
        local img = holder:FindFirstChildWhichIsA("ImageLabel")
        if img then
            img.ImageColor3 = color
        end
        return
    end
    for _, piece in ipairs(holder:GetChildren()) do
        if piece:IsA("Frame") then
            local edge = piece:FindFirstChildWhichIsA("UIStroke")
            if edge then
                edge.Color = color
            elseif piece.Name == "hole" then
                if void then
                    piece.BackgroundColor3 = void
                end
            else
                piece.BackgroundColor3 = color
            end
        end
    end
end

function Icons.fade(holder, transparency)
    for _, piece in ipairs(holder:GetChildren()) do
        if piece:IsA("Frame") then
            local edge = piece:FindFirstChildWhichIsA("UIStroke")
            if edge then
                Util.tween(edge, { Transparency = transparency }, Util.ease.snap)
            else
                Util.tween(piece, { BackgroundTransparency = transparency }, Util.ease.snap)
            end
        end
    end
end

return Icons
end

__flowStartupCheckpoint()
__modules["core/luarmor"] = function(require)
__flowStartupCheckpoint()
--[[
    Reads the runtime variables Luarmor injects into a protected script.

        LRM_SecondsLeft      seconds until the key expires, math.huge if auth_expire is unset
        LRM_IsUserPremium    whitelist flag
        LRM_UserNote         note attached to the key
        LRM_LinkedDiscordID  discord id the key is bound to
        LRM_TotalExecutions  executions made by this key
        LRM_ScriptName / LRM_ScriptVersion

    https://docs.luarmor.net/luarmor-user-manual-and-f.a.q

    Nothing here errors when the script is not Luarmor-protected — every reader
    returns nil and the UI falls back to showing no key.
]]

local Luarmor = {}

local HOUR = 3600
local DAY = 86400
local YEAR = 365 * DAY

-- anything longer than this counts as premium rather than a trial key
Luarmor.PremiumAfter = 60 * HOUR

-- set by hand to preview a state, e.g. Luarmor.override = { SecondsLeft = math.huge }
Luarmor.override = nil

local NAMES = {
    "LRM_SecondsLeft",
    "LRM_IsUserPremium",
    "LRM_UserNote",
    "LRM_LinkedDiscordID",
    "LRM_TotalExecutions",
    "LRM_ScriptName",
    "LRM_ScriptVersion",
    "LRM_ScriptKey",
}

-- Luarmor puts its variables in the protected script's own environment, which may
-- be the executor global table, _G, or a caller's env depending on how the script
-- was loaded, so check all of them.
local function readGlobal(name)
    local envs = {}

    if getgenv then
        local ok, env = pcall(getgenv)
        if ok and type(env) == "table" then
            table.insert(envs, env)
        end
    end

    table.insert(envs, _G)

    if getfenv then
        for level = 1, 6 do
            local ok, env = pcall(getfenv, level)
            if ok and type(env) == "table" then
                table.insert(envs, env)
            end
        end
    end

    for _, env in ipairs(envs) do
        local ok, value = pcall(function()
            return env[name]
        end)
        if ok and value ~= nil then
            return value
        end
    end

    return nil
end

function Luarmor.info()
    local out = {}
    for _, name in ipairs(NAMES) do
        out[name] = readGlobal(name)
    end
    return out
end

-- nil when there is no key data at all
function Luarmor.secondsLeft()
    if Luarmor.override and Luarmor.override.SecondsLeft ~= nil then
        return Luarmor.override.SecondsLeft
    end
    local value = readGlobal("LRM_SecondsLeft")
    if type(value) ~= "number" then
        return nil
    end
    return value
end

function Luarmor.isLifetime()
    local left = Luarmor.secondsLeft()
    if left == nil then
        return false
    end
    -- math.huge is the documented "no auth_expire" value; the year check catches
    -- keys given an absurd expiry instead of none at all
    return left == math.huge or left > 50 * YEAR
end

function Luarmor.isPremium()
    local left = Luarmor.secondsLeft()
    if left == nil then
        local flag = readGlobal("LRM_IsUserPremium")
        if type(flag) == "boolean" then
            return flag
        end
        return false
    end
    return Luarmor.isLifetime() or left >= Luarmor.PremiumAfter
end

function Luarmor.plan()
    return Luarmor.isPremium() and "Premium" or "Free"
end

-- "Lifetime", "12d 4h", "3h 20m", "45m", "Expired", or "No key"
function Luarmor.duration()
    local left = Luarmor.secondsLeft()
    if left == nil then
        return "No key"
    end
    if Luarmor.isLifetime() then
        return "Lifetime"
    end
    if left <= 0 then
        return "Expired"
    end

    local days = math.floor(left / DAY)
    local hours = math.floor((left % DAY) / HOUR)
    local minutes = math.floor((left % HOUR) / 60)

    if days > 0 then
        return string.format("%dd %dh", days, hours)
    end
    if hours > 0 then
        return string.format("%dh %dm", hours, minutes)
    end
    return string.format("%dm", math.max(minutes, 1))
end

-- nil for lifetime keys and when there is no key
function Luarmor.expiry()
    local left = Luarmor.secondsLeft()
    if left == nil or left <= 0 or Luarmor.isLifetime() then
        return nil
    end
    return os.date("%d.%m.%Y %H:%M", os.time() + math.floor(left))
end

function Luarmor.note()
    local value = readGlobal("LRM_UserNote")
    if type(value) == "string" and value ~= "" and value ~= "Not specified" then
        return value
    end
    return nil
end

return Luarmor
end

__flowStartupCheckpoint()
__modules["core/lucide"] = function(require)
__flowStartupCheckpoint()
--[[
    Lucide sprite data, generated by tools/fetch-icons.mjs — do not edit by hand.

    Source: latte-soft/lucide-roblox (MIT), artwork from lucide.dev (ISC).
    Each entry is { assetId, rectWidth, rectHeight, rectOffsetX, rectOffsetY }
    against the 48px spritesheets.
]]

return {
    ["alert"] = { 16898613869, 48, 48, 967, 0 }, -- triangle-alert
    ["arrow-right"] = { 16898612629, 48, 48, 453, 820 }, -- arrow-right
    ["arrow-up"] = { 16898612629, 48, 48, 967, 355 }, -- arrow-up
    ["backpack"] = { 16898612629, 48, 48, 710, 869 }, -- backpack
    ["badge"] = { 16898612629, 48, 48, 918, 661 }, -- award
    ["ban"] = { 16898612629, 48, 48, 196, 967 }, -- ban
    ["bell"] = { 16898612819, 48, 48, 820, 257 }, -- bell
    ["bolt"] = { 16898613869, 48, 48, 918, 906 }, -- zap
    ["branch"] = { 16898613353, 48, 48, 918, 906 }, -- git-branch
    ["chart"] = { 16898612629, 48, 48, 918, 759 }, -- bar-chart-3
    ["check"] = { 16898612819, 48, 48, 710, 869 }, -- check
    ["chevron-down"] = { 16898612819, 48, 48, 196, 918 }, -- chevron-down
    ["chevron-left"] = { 16898612819, 48, 48, 404, 967 }, -- chevron-left
    ["chevron-right"] = { 16898612819, 48, 48, 869, 759 }, -- chevron-right
    ["chevron-up"] = { 16898612819, 48, 48, 710, 918 }, -- chevron-up
    ["chevrons-right"] = { 16898612819, 48, 48, 967, 710 }, -- chevrons-right
    ["clock"] = { 16898613044, 48, 48, 771, 661 }, -- clock
    ["close"] = { 16898613869, 48, 48, 869, 906 }, -- x
    ["cloud"] = { 16898613044, 48, 48, 918, 306 }, -- cloud
    ["code"] = { 16898613044, 48, 48, 355, 869 }, -- code
    ["coin"] = { 16898613044, 48, 48, 257, 771 }, -- circle-dollar-sign
    ["crown"] = { 16898613044, 48, 48, 404, 918 }, -- crown
    ["cube"] = { 16898612819, 48, 48, 771, 196 }, -- box
    ["dots"] = { 16898613353, 48, 48, 771, 49 }, -- ellipsis
    ["esp"] = { 16898613699, 48, 48, 771, 857 }, -- scan-line
    ["expand"] = { 16898613613, 48, 48, 771, 563 }, -- maximize
    ["eye"] = { 16898613353, 48, 48, 771, 563 }, -- eye
    ["filter"] = { 16898613353, 48, 48, 612, 869 }, -- filter
    ["flame"] = { 16898613353, 48, 48, 967, 306 }, -- flame
    ["flask"] = { 16898613353, 48, 48, 453, 820 }, -- flask-conical
    ["fly"] = { 16898613699, 48, 48, 98, 820 }, -- plane
    ["folder"] = { 16898613353, 48, 48, 404, 967 }, -- folder
    ["gauge"] = { 16898613353, 48, 48, 771, 955 }, -- gauge
    ["gear"] = { 16898613777, 48, 48, 771, 257 }, -- settings
    ["ghost"] = { 16898613353, 48, 48, 869, 906 }, -- ghost
    ["grid"] = { 16898613509, 48, 48, 918, 404 }, -- layout-grid
    ["heart"] = { 16898613509, 48, 48, 661, 771 }, -- heart
    ["hitbox"] = { 16898613699, 48, 48, 967, 196 }, -- scan
    ["hourglass"] = { 16898613509, 48, 48, 49, 918 }, -- hourglass
    ["info"] = { 16898613509, 48, 48, 612, 869 }, -- info
    ["jump"] = { 16898612629, 48, 48, 918, 306 }, -- arrow-big-up
    ["keyboard"] = { 16898613509, 48, 48, 453, 820 }, -- keyboard
    ["layers"] = { 16898613509, 48, 48, 98, 967 }, -- layers
    ["link"] = { 16898613509, 48, 48, 918, 453 }, -- link
    ["lock"] = { 16898613509, 48, 48, 918, 857 }, -- lock
    ["logout"] = { 16898613509, 48, 48, 820, 955 }, -- log-out
    ["magnet"] = { 16898613509, 48, 48, 967, 906 }, -- magnet
    ["minus"] = { 16898613613, 48, 48, 771, 196 }, -- minus
    ["noclip"] = { 16898612819, 48, 48, 820, 147 }, -- box-select
    ["orbit"] = { 16898613613, 48, 48, 967, 612 }, -- orbit
    ["palette"] = { 16898613613, 48, 48, 453, 918 }, -- palette
    ["pin"] = { 16898613613, 48, 48, 820, 257 }, -- map-pin
    ["plus"] = { 16898613699, 48, 48, 257, 918 }, -- plus
    ["power"] = { 16898613699, 48, 48, 820, 147 }, -- power
    ["radar"] = { 16898613699, 48, 48, 820, 404 }, -- radar
    ["refresh"] = { 16898613699, 48, 48, 404, 869 }, -- refresh-cw
    ["search"] = { 16898613699, 48, 48, 918, 857 }, -- search
    ["shield"] = { 16898613777, 48, 48, 869, 0 }, -- shield
    ["signal"] = { 16898613777, 48, 48, 918, 0 }, -- signal
    ["skull"] = { 16898613777, 48, 48, 49, 869 }, -- skull
    ["sliders"] = { 16898613777, 48, 48, 820, 355 }, -- sliders-horizontal
    ["sparkle"] = { 16898613777, 48, 48, 918, 49 }, -- sparkles
    ["star"] = { 16898613777, 48, 48, 967, 147 }, -- star
    ["swords"] = { 16898613777, 48, 48, 967, 759 }, -- swords
    ["target"] = { 16898613044, 48, 48, 453, 869 }, -- crosshair
    ["teleport"] = { 16898613869, 48, 48, 771, 857 }, -- waypoints
    ["tracer"] = { 16898613509, 48, 48, 967, 759 }, -- locate-fixed
    ["user"] = { 16898613869, 48, 48, 661, 869 }, -- user
    ["users"] = { 16898613869, 48, 48, 967, 98 }, -- users
    ["wall"] = { 16898612819, 48, 48, 918, 306 }, -- brick-wall
    ["wand"] = { 16898613869, 48, 48, 453, 918 }, -- wand-sparkles
}
end

__flowStartupCheckpoint()
__modules["core/state"] = function(require)
__flowStartupCheckpoint()
local HttpService = __service("HttpService")

local State = {}

State.flags = {}
State.controls = {}
State.folder = "flow"

local listeners = {}

function State.register(flag, control)
    if not flag then
        return
    end
    State.controls[flag] = control
end

--[[
    Hand a flag back when the control behind it dies. Guarded on identity: a
    reload builds the new card before the old tree is torn down, so an
    unconditional clear would wipe the live registration and leave
    Flow:Set("flag", v) pointing at nothing.
]]
function State.release(flag, control)
    if flag and State.controls[flag] == control then
        State.controls[flag] = nil
    end
end

function State.get(flag)
    return State.flags[flag]
end

function State.set(flag, value, silent)
    State.flags[flag] = value
    local control = State.controls[flag]
    if control and control.Set and not silent then
        control:Set(value)
    end
    local bucket = listeners[flag]
    if bucket then
        for _, fn in ipairs(bucket) do
            task.spawn(fn, value)
        end
    end
end

function State.watch(flag, fn)
    listeners[flag] = listeners[flag] or {}
    table.insert(listeners[flag], fn)
    return function()
        local bucket = listeners[flag]
        if not bucket then
            return
        end
        for i, v in ipairs(bucket) do
            if v == fn then
                table.remove(bucket, i)
                break
            end
        end
    end
end

local function pack(value)
    local kind = typeof(value)
    if kind == "Color3" then
        return {
            __k = "Color3",
            r = math.floor(value.R * 255 + 0.5),
            g = math.floor(value.G * 255 + 0.5),
            b = math.floor(value.B * 255 + 0.5),
        }
    elseif kind == "EnumItem" then
        return { __k = "Enum", group = tostring(value.EnumType), item = value.Name }
    elseif kind == "Vector2" then
        return { __k = "Vector2", x = value.X, y = value.Y }
    elseif kind == "UDim2" then
        return {
            __k = "UDim2",
            xs = value.X.Scale,
            xo = value.X.Offset,
            ys = value.Y.Scale,
            yo = value.Y.Offset,
        }
    elseif kind == "table" then
        local out = {}
        for k, v in pairs(value) do
            out[k] = pack(v)
        end
        return out
    end
    return value
end

local function unpack(value)
    if typeof(value) ~= "table" then
        return value
    end
    local kind = value.__k
    if kind == "Color3" then
        return Color3.fromRGB(value.r, value.g, value.b)
    elseif kind == "Enum" then
        local ok, item = pcall(function()
            return Enum[value.group:gsub("^Enum%.", "")][value.item]
        end)
        return ok and item or nil
    elseif kind == "Vector2" then
        return Vector2.new(value.x, value.y)
    elseif kind == "UDim2" then
        return UDim2.new(value.xs, value.xo, value.ys, value.yo)
    end
    local out = {}
    for k, v in pairs(value) do
        out[k] = unpack(v)
    end
    return out
end

State.pack = pack
State.unpack = unpack

local function canWrite()
    return writefile ~= nil and readfile ~= nil and isfile ~= nil
end

-- every one of these can throw rather than return false on a sandboxed or
-- permission-limited executor, and an unhandled throw here surfaces as a dead
-- Save button with no explanation
local function ensureFolder()
    if not isfolder or not makefolder then
        return false
    end
    return (pcall(function()
        if not isfolder(State.folder) then
            makefolder(State.folder)
        end
        if not isfolder(State.folder .. "/configs") then
            makefolder(State.folder .. "/configs")
        end
    end))
end

-- config names reach the filesystem, so anything that could climb out of the
-- folder or break a path is stripped rather than trusted
local function safeName(name)
    name = tostring(name or "default"):gsub("[^%w%-_ %.]", "")
    name = name:gsub("^%s+", ""):gsub("%s+$", ""):gsub("%.+$", "")
    if name == "" then
        return "default"
    end
    return name:sub(1, 64)
end

State.safeName = safeName

function State.dump(extra)
    local out = { flags = {}, extra = extra and pack(extra) or nil }
    for flag, value in pairs(State.flags) do
        out.flags[flag] = pack(value)
    end
    return out
end

function State.apply(data)
    if typeof(data) ~= "table" or typeof(data.flags) ~= "table" then
        return false
    end
    for flag, value in pairs(data.flags) do
        State.set(flag, unpack(value))
    end
    return true
end

function State.save(name, extra)
    if not canWrite() then
        return false, "executor has no file access"
    end
    ensureFolder()
    local ok, encoded = pcall(HttpService.JSONEncode, HttpService, State.dump(extra))
    if not ok then
        return false, "could not encode config"
    end
    local wrote = pcall(writefile, State.folder .. "/configs/" .. safeName(name) .. ".json", encoded)
    if not wrote then
        return false, "executor refused the write"
    end
    return true
end

function State.load(name)
    if not canWrite() then
        return false, "executor has no file access"
    end
    local path = State.folder .. "/configs/" .. safeName(name) .. ".json"
    local there, present = pcall(isfile, path)
    if not there or not present then
        return false, "config not found"
    end
    local read, body = pcall(readfile, path)
    if not read then
        return false, "config could not be read"
    end
    local ok, decoded = pcall(HttpService.JSONDecode, HttpService, body)
    if not ok or type(decoded) ~= "table" then
        return false, "config is corrupt"
    end
    State.apply(decoded)
    return true, decoded.extra and unpack(decoded.extra) or nil
end

function State.remove(name)
    if not delfile then
        return false
    end
    local path = State.folder .. "/configs/" .. safeName(name) .. ".json"
    local there, present = pcall(isfile, path)
    if there and present then
        return (pcall(delfile, path))
    end
    return false
end

function State.configs()
    local out = {}
    if not listfiles or not isfolder then
        return out
    end
    local ok, entries = pcall(function()
        if not isfolder(State.folder .. "/configs") then
            return nil
        end
        return listfiles(State.folder .. "/configs")
    end)
    if not ok or type(entries) ~= "table" then
        return out
    end
    for _, path in ipairs(entries) do
        local name = path:match("([^/\\]+)%.json$")
        if name then
            table.insert(out, name)
        end
    end
    table.sort(out)
    return out
end

return State
end

__flowStartupCheckpoint()
__modules["core/theme"] = function(require)
__flowStartupCheckpoint()
local Theme = {}

local rgb = Color3.fromRGB

local base = {
    backdrop = rgb(16, 15, 21),
    surface = rgb(23, 22, 30),
    surfaceAlt = rgb(29, 28, 37),
    raised = rgb(37, 35, 47),
    raisedHi = rgb(46, 44, 58),

    line = rgb(43, 41, 55),
    lineSoft = rgb(32, 31, 41),

    text = rgb(234, 233, 241),
    textDim = rgb(150, 147, 166),
    textFaint = rgb(104, 101, 121),

    danger = rgb(238, 92, 100),
    success = rgb(72, 205, 141),
    warning = rgb(240, 178, 78),

    white = rgb(255, 255, 255),
    black = rgb(0, 0, 0),
}

Theme.tokens = {}
Theme.accent = rgb(124, 92, 255)
Theme.radius = { window = 12, card = 10, control = 8, chip = 6, tile = 7 }
-- one left/right inset for every band inside a window: header, tab strip, card
-- lanes and footer. They drifted to 16, 18 and 18 and the 2px told.
Theme.gutter = 14

--[[
    The fixed bands a window is built from. These used to be literals scattered
    across window.lua — a 72 here, a 121 and a 122 there, each one silently
    derived from the two above it — so tightening the chrome meant finding all of
    them and getting the arithmetic right by hand. One table, and `top` is the
    y where the page starts.
]]
Theme.chrome = {}

--[[
    Two densities.

    `compact` is the desktop build: a mouse pointer is one pixel, so the only
    limit on how tight the chrome gets is legibility.

    `touch` exists because none of that holds on a phone. A fingertip covers
    around 9mm, the interface is additionally scaled down to fit a small screen,
    and 28px of tab strip at 0.8 scale is a 22px target — under half of what
    every mobile guideline asks for. Touch mode buys the difference back on the
    things that are actually pressed and leaves the rest alone.

    Set before anything is built, so this is a table swap rather than a relayout.
]]
local densities = {
    compact = {
        header = 58,
        strip = 40,
        footer = 36,
        -- the collapsed height of a module card, and the gap between cards and lanes
        card = 44,
        gap = 10,
        -- press targets: tab button, header icon button, search field
        tab = 28,
        icon = 30,
        field = 30,
        switch = Vector2.new(38, 21),
    },
    touch = {
        header = 62,
        strip = 48,
        footer = 38,
        card = 48,
        gap = 10,
        tab = 38,
        icon = 38,
        field = 36,
        switch = Vector2.new(46, 26),
    },
}

function Theme.density(mode)
    local picked = densities[mode] or densities.compact
    for k, v in pairs(picked) do
        Theme.chrome[k] = v
    end
    Theme.chrome.mode = densities[mode] and mode or "compact"
    Theme.chrome.top = Theme.chrome.header + Theme.chrome.strip
    return Theme.chrome
end

Theme.density("compact")

local family = "rbxasset://fonts/families/BuilderSans.json"

Theme.font = {
    regular = Font.new(family, Enum.FontWeight.Regular),
    medium = Font.new(family, Enum.FontWeight.Medium),
    semi = Font.new(family, Enum.FontWeight.SemiBold),
    bold = Font.new(family, Enum.FontWeight.Bold),
}

-- instance -> { [property] = token }. Keyed by instance rather than kept as a
-- flat list so re-binding a property replaces the token instead of appending a
-- second entry that races the first.
local bindings = {}
local watchers = {}

local function derive()
    for k, v in pairs(base) do
        Theme.tokens[k] = v
    end
    local a = Theme.accent
    Theme.tokens.accent = a
    Theme.tokens.accentDeep = a:Lerp(base.black, 0.34)
    Theme.tokens.accentGlow = a:Lerp(base.white, 0.28)
    Theme.tokens.accentSoft = a:Lerp(base.surface, 0.74)
    Theme.tokens.accentEdge = a:Lerp(base.line, 0.45)
end

derive()

function Theme.get(token)
    return Theme.tokens[token] or base.text
end

function Theme.bind(inst, prop, token)
    inst[prop] = Theme.get(token)

    local props = bindings[inst]
    if not props then
        props = {}
        bindings[inst] = props
        --[[
            Dropping the entry here is what keeps this table bounded. The sweep
            in setAccent cannot do it: Roblox happily accepts a property write on
            a destroyed instance, so the pcall around it never fails and nothing
            was ever pruned. Every notification toast, overlay panel and tooltip
            left its labels behind for the rest of the session, and each accent
            change then had to walk all of them.

            A weak-keyed table looks like the tidier fix but is wrong here: the
            Lua handle for an instance is collectable while the instance is still
            in the tree, so elements nothing else holds a reference to would
            silently stop following the theme.
        ]]
        inst.Destroying:Connect(function()
            bindings[inst] = nil
        end)
    end
    props[prop] = token

    return inst
end

-- point an existing binding at a different token. Writing the property directly
-- would hold only until the next accent change re-ran the binding list.
function Theme.rebind(inst, prop, token)
    return Theme.bind(inst, prop, token)
end

function Theme.watch(fn)
    table.insert(watchers, fn)
    return function()
        for i, v in ipairs(watchers) do
            if v == fn then
                table.remove(watchers, i)
                break
            end
        end
    end
end

function Theme.setAccent(color)
    Theme.accent = color
    derive()

    for inst, props in pairs(bindings) do
        local ok = pcall(function()
            for prop, token in pairs(props) do
                inst[prop] = Theme.get(token)
            end
        end)
        if not ok then
            bindings[inst] = nil
        end
    end

    for i = #watchers, 1, -1 do
        local fn = watchers[i]
        local ok, keep = pcall(fn)
        if not ok or keep == false then
            table.remove(watchers, i)
        end
    end
end

--[[
    Watchers only pruned themselves on the next accent change, because that is
    the only thing that ever ran them. A session that never touches the accent —
    most of them — kept every watcher from every reload. This runs the same prune
    pass on demand and repaints nothing that is still alive.
]]
function Theme.sweep()
    local dropped = 0
    for inst in pairs(bindings) do
        if not inst.Parent then
            bindings[inst] = nil
            dropped = dropped + 1
        end
    end
    for i = #watchers, 1, -1 do
        local ok, keep = pcall(watchers[i])
        if not ok or keep == false then
            table.remove(watchers, i)
            dropped = dropped + 1
        end
    end
    return dropped
end

function Theme.setFont(assetPath)
    Theme.font.regular = Font.new(assetPath, Enum.FontWeight.Regular)
    Theme.font.medium = Font.new(assetPath, Enum.FontWeight.Medium)
    Theme.font.semi = Font.new(assetPath, Enum.FontWeight.SemiBold)
    Theme.font.bold = Font.new(assetPath, Enum.FontWeight.Bold)
end

return Theme
end

__flowStartupCheckpoint()
__modules["core/util"] = function(require)
__flowStartupCheckpoint()
local TweenService = __service("TweenService")
local UserInputService = __service("UserInputService")
local RunService = __service("RunService")

local Util = {}

local ease = {
    out = TweenInfo.new(0.18, Enum.EasingStyle.Quart, Enum.EasingDirection.Out),
    snap = TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
    glide = TweenInfo.new(0.34, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
    spring = TweenInfo.new(0.42, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
}

Util.ease = ease

function Util.new(class, props, kids)
    local inst = Instance.new(class)
    local parent
    if props then
        parent = props.Parent
        props.Parent = nil
        for k, v in pairs(props) do
            inst[k] = v
        end
    end
    if kids then
        for _, v in ipairs(kids) do
            v.Parent = inst
        end
    end
    if parent then
        inst.Parent = parent
    end
    return inst
end

function Util.corner(parent, radius)
    return Util.new("UICorner", {
        CornerRadius = typeof(radius) == "UDim" and radius or UDim.new(0, radius or 8),
        Parent = parent,
    })
end

function Util.stroke(parent, color, thickness, transparency)
    return Util.new("UIStroke", {
        Color = color or Color3.fromRGB(255, 255, 255),
        Thickness = thickness or 1,
        Transparency = transparency or 0,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
        Parent = parent,
    })
end

function Util.pad(parent, top, right, bottom, left)
    return Util.new("UIPadding", {
        PaddingTop = UDim.new(0, top or 0),
        PaddingRight = UDim.new(0, right or top or 0),
        PaddingBottom = UDim.new(0, bottom or top or 0),
        PaddingLeft = UDim.new(0, left or right or top or 0),
        Parent = parent,
    })
end

function Util.list(parent, gap, dir, align, valign)
    return Util.new("UIListLayout", {
        Padding = UDim.new(0, gap or 0),
        FillDirection = dir or Enum.FillDirection.Vertical,
        SortOrder = Enum.SortOrder.LayoutOrder,
        HorizontalAlignment = align or Enum.HorizontalAlignment.Left,
        VerticalAlignment = valign or Enum.VerticalAlignment.Top,
        Parent = parent,
    })
end

function Util.tween(inst, props, info)
    local t = TweenService:Create(inst, info or ease.out, props)
    t:Play()
    return t
end

function Util.clamp(v, lo, hi)
    return v < lo and lo or (v > hi and hi or v)
end

function Util.round(v, step)
    if not step or step <= 0 then
        return v
    end
    return math.floor(v / step + 0.5) * step
end

function Util.decimals(step)
    if not step or step >= 1 then
        return 0
    end
    local s = string.format("%.6f", step):gsub("0+$", "")
    return #(s:match("%.(%d*)") or "")
end

function Util.format(v, step)
    local d = Util.decimals(step)
    if d == 0 then
        return tostring(math.floor(v + 0.5))
    end
    return string.format("%." .. d .. "f", v)
end

function Util.hover(button, target, idle, over, dur)
    target = target or button
    local info = TweenInfo.new(dur or 0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
    button.MouseEnter:Connect(function()
        Util.tween(target, over, info)
    end)
    button.MouseLeave:Connect(function()
        Util.tween(target, idle, info)
    end)
end

--[[
    Every draggable, slider and keybind used to open its own UserInputService
    connection. A window with 20 modules meant ~100 global handlers firing on
    every mouse move.

    Now there is one engine connection per phase and components register into it.
    Dragging and sliding go further: only one can be active at a time, so they
    share a single handler and a single piece of state rather than one each.
]]

local hub = { began = {}, changed = {}, ended = {} }
local wired = false

local function wire()
    if wired then
        return
    end
    wired = true

    UserInputService.InputBegan:Connect(function(input, typing)
        for i = #hub.began, 1, -1 do
            hub.began[i](input, typing)
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        for i = #hub.changed, 1, -1 do
            hub.changed[i](input)
        end
    end)
    UserInputService.InputEnded:Connect(function(input)
        for i = #hub.ended, 1, -1 do
            hub.ended[i](input)
        end
    end)
end

-- Util.onInput("began" | "changed" | "ended", fn) -> disconnect
function Util.onInput(phase, fn)
    wire()
    local list = hub[phase]
    if not list then
        return function() end
    end
    table.insert(list, fn)
    return function()
        for i, entry in ipairs(list) do
            if entry == fn then
                table.remove(list, i)
                break
            end
        end
    end
end

local function isPress(input)
    return input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch
end

local function isMove(input)
    return input.UserInputType == Enum.UserInputType.MouseMovement
        or input.UserInputType == Enum.UserInputType.Touch
end

local gesture

Util.onInput("changed", function(input)
    if not gesture or not isMove(input) then
        return
    end
    gesture.move(input)
end)

Util.onInput("ended", function(input)
    if not gesture or not isPress(input) then
        return
    end
    local done = gesture
    gesture = nil
    if done.finish then
        done.finish()
    end
end)

function Util.drag(handle, target, onFinish)
    handle.InputBegan:Connect(function(input)
        if not isPress(input) then
            return
        end
        local origin, start = input.Position, target.Position
        gesture = {
            move = function(moved)
                local delta = moved.Position - origin
                target.Position =
                    UDim2.new(start.X.Scale, start.X.Offset + delta.X, start.Y.Scale, start.Y.Offset + delta.Y)
            end,
            finish = onFinish and function()
                onFinish(target.Position)
            end or nil,
        }
    end)
end

function Util.slide(track, onChange, onRelease)
    local function push(x)
        local alpha = Util.clamp((x - track.AbsolutePosition.X) / math.max(track.AbsoluteSize.X, 1), 0, 1)
        onChange(alpha)
        return alpha
    end

    track.InputBegan:Connect(function(input)
        if not isPress(input) then
            return
        end
        local alpha = push(input.Position.X)
        gesture = {
            move = function(moved)
                alpha = push(moved.Position.X)
            end,
            finish = onRelease and function()
                onRelease(alpha)
            end or nil,
        }
    end)
end

function Util.keyName(key)
    if typeof(key) == "EnumItem" then
        if key.EnumType == Enum.UserInputType then
            local n = key.Name:gsub("MouseButton", "MB")
            return n
        end
        local n = key.Name
        n = n:gsub("^Left", "L"):gsub("^Right", "R")
        n = n:gsub("^KeyPad", "Num")
        if n:match("^Zero$") then n = "0" end
        return n
    end
    return "None"
end

--[[
    Where the interface lives decides whether a game can see it at all.

    gethui() is the good case: a container game scripts cannot reach, since
    CoreGui returns nil at LocalScript identity. protectgui + CoreGui is the
    fallback. PlayerGui is the last resort and is fully visible to the game —
    Util.protected is left false so callers can warn about it.
]]
Util.protected = false
Util.host = "unknown"

function Util.root()
    local gui = Util.new("ScreenGui", {
        Name = "\0" .. tostring(math.random(1e8, 1e9)),
        ResetOnSpawn = false,
        IgnoreGuiInset = true,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
        DisplayOrder = 9999,
    })

    if RunService:IsStudio() then
        gui.Parent = __service("Players").LocalPlayer:WaitForChild("PlayerGui", 5)
        return gui
    end

    -- executors name the hidden container differently; any of them is the good
    -- case, and only checking gethui threw away a working one
    for _, resolver in ipairs({
        gethui,
        get_hidden_gui,
        gethiddengui,
        get_hidden_ui,
        gethiddenui,
    }) do
        if type(resolver) == "function" then
            local ok, holder = pcall(resolver)
            if ok and typeof(holder) == "Instance" then
                local placed = pcall(function()
                    gui.Parent = holder
                end)
                if placed then
                    Util.protected = true
                    Util.host = "hidden"
                    return gui
                end
            end
        end
    end

    local protect = protectgui or (syn and syn.protect_gui)
    if protect then
        pcall(protect, gui)
    end

    local ok = pcall(function()
        gui.Parent = __service("CoreGui")
    end)
    if ok then
        -- CoreGui is already out of a game script's reach: GetService("CoreGui")
        -- returns nil at identity 2. protectgui hardens it further against other
        -- elevated code, but its absence does not make this PlayerGui.
        Util.protected = true
        Util.host = protect and "coregui+protect" or "coregui"
        return gui
    end

    gui.Parent = __service("Players").LocalPlayer:WaitForChild("PlayerGui", 5)
    Util.host = "playergui"
    -- last resort: the tree is readable here, so hide the root from the calls a
    -- game script would use to find it
    Util.protected = Util.conceal(gui)
    if Util.protected then
        Util.host = "playergui+hooked"
    end
    return gui
end

--[[
    Concealment for executors that offer no hidden container.

    In PlayerGui the interface is an ordinary ScreenGui the game can enumerate.
    The root already carries a NUL-prefixed random name so it cannot be indexed,
    but GetChildren and GetDescendants still hand it over. This filters it out of
    the handful of calls a detection script actually uses.

    Honest limits, because this is the weakest tier by definition:
      - the hook itself is detectable by code that checksums __namecall
      - it hides the instance, never the behaviour
      - it only engages when the good paths are unavailable, so the common case
        pays nothing for it
]]
local hidden = setmetatable({}, { __mode = "k" })

local ENUMERATE = { GetChildren = true, GetDescendants = true }
local LOOKUP = {
    FindFirstChild = true,
    FindFirstChildOfClass = true,
    FindFirstChildWhichIsA = true,
    WaitForChild = true,
}

local function isHidden(value)
    if typeof(value) ~= "Instance" then
        return false
    end
    if hidden[value] then
        return true
    end
    -- a descendant of the root gives it away just as well; the walk is bounded
    -- by how shallow a ScreenGui tree is
    local node = value.Parent
    for _ = 1, 12 do
        if not node then
            return false
        end
        if hidden[node] then
            return true
        end
        node = node.Parent
    end
    return false
end

function Util.conceal(gui)
    if type(hookmetamethod) ~= "function"
        or type(getnamecallmethod) ~= "function"
        or type(newcclosure) ~= "function"
    then
        return false
    end

    hidden[gui] = true
    if Util.concealing then
        return true
    end

    local ok = pcall(function()
        local old
        old = hookmetamethod(game, "__namecall", newcclosure(function(self, ...)
            local method = getnamecallmethod()

            -- the library walks its own tree constantly (tinting an icon, finding
            -- a card's header). Filtering those calls would hide the interface
            -- from itself, so only calls made from outside the root are censored.
            if (ENUMERATE[method] or LOOKUP[method]) and isHidden(self) then
                return old(self, ...)
            end

            if ENUMERATE[method] then
                local list = old(self, ...)
                if type(list) == "table" then
                    for i = #list, 1, -1 do
                        if isHidden(list[i]) then
                            table.remove(list, i)
                        end
                    end
                end
                return list
            end

            if LOOKUP[method] then
                local found = old(self, ...)
                if isHidden(found) then
                    return nil
                end
                return found
            end

            return old(self, ...)
        end))
    end)

    Util.concealing = ok
    return ok
end

-- touch with no keyboard is the reliable mobile signal; viewport width alone
-- misreads a small windowed desktop client
function Util.isMobile()
    local touch = UserInputService.TouchEnabled
    local keyboard = UserInputService.KeyboardEnabled
    if touch and not keyboard then
        return true
    end
    local camera = __service("Workspace").CurrentCamera
    return camera ~= nil and camera.ViewportSize.X < 820
end

function Util.viewport()
    local camera = __service("Workspace").CurrentCamera
    return camera and camera.ViewportSize or Vector2.new(1280, 720)
end

--[[
    Binding to CurrentCamera once was not enough. The engine replaces the camera
    on respawn and on anything that scripts a cutscene, and the old connection
    goes with it — so a phone that rotated after dying never re-fitted and the
    window stayed clipped off the edge of the screen. Follow the swap instead.
]]
function Util.onViewport(fn)
    local workspace = __service("Workspace")
    local bound

    local function attach()
        if bound then
            bound:Disconnect()
            bound = nil
        end
        local camera = workspace.CurrentCamera
        if not camera then
            return
        end
        bound = camera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
            fn(camera.ViewportSize)
        end)
    end

    attach()

    local swap = workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
        attach()
        local camera = workspace.CurrentCamera
        if camera then
            fn(camera.ViewportSize)
        end
    end)

    return function()
        swap:Disconnect()
        if bound then
            bound:Disconnect()
            bound = nil
        end
    end
end

function Util.inset()
    local ok, gap = pcall(function()
        return __service("GuiService"):GetGuiInset().Y
    end)
    return ok and gap or 36
end

--[[
    The only per-frame connection in the library, so it is worth it being cheap
    and worth it stopping.

    It used to keep a growing list of frame times and `table.remove(samples, 1)`
    the front off it every frame — an O(n) shift, sixty times a second, forever,
    because the connection was never handed back and never disconnected. A
    watermark that had been destroyed an hour ago was still sampling.

    Now it is a counter and a window: two adds and a compare per frame, and the
    caller gets a stop function.
]]
function Util.fps()
    local frames, elapsed = 0, 0
    local value = 60

    local connection = RunService.RenderStepped:Connect(function(dt)
        frames = frames + 1
        elapsed = elapsed + dt
        if elapsed >= 0.5 then
            value = frames / elapsed
            frames, elapsed = 0, 0
        end
    end)

    return function()
        return math.floor(value + 0.5)
    end, function()
        connection:Disconnect()
    end
end

function Util.ping()
    local Stats = __service("Stats")
    return function()
        local ok, v = pcall(function()
            return Stats.Network.ServerStatsItem["Data Ping"]:GetValue()
        end)
        if ok and v then
            return math.floor(v + 0.5)
        end
        return 0
    end
end

--[[
    GetUserThumbnailAsync is a yielding web request. The player list called it for
    every row on every refresh — eight round trips a second, forever — which is
    the single most expensive thing the library used to do.

    rbxthumb:// is the content-url form of the same image: the engine resolves and
    caches it itself, no API call and no yield. The result is memoised anyway so a
    row that redraws does not even rebuild the string.
]]
local thumbs = {}

function Util.thumbnail(userId, size)
    local px = 150
    if typeof(size) == "EnumItem" then
        px = tonumber(size.Name:match("^Size(%d+)")) or 150
    elseif type(size) == "number" then
        px = size
    end
    local key = tostring(userId) .. "@" .. px
    local hit = thumbs[key]
    if hit then
        return hit
    end
    local url = "rbxthumb://type=AvatarHeadShot&id=" .. tostring(userId) .. "&w=" .. px .. "&h=" .. px
    thumbs[key] = url
    return url
end

return Util
end

__flowStartupCheckpoint()
__modules["hud/keybinds"] = function(require)
__flowStartupCheckpoint()
local Util = require("core/util")
local Theme = require("core/theme")
local Panel = require("hud/panel")

local Keybinds = {}
Keybinds.__index = Keybinds

function Keybinds.new(props)
    local self = setmetatable({}, Keybinds)
    self.panel = Panel.new({
        Title = props.Title or "Keybinds",
        Icon = "keyboard",
        Width = props.Width or 212,
        Position = props.Position or UDim2.fromOffset(18, 300),
        AnchorPoint = props.AnchorPoint,
        Parent = props.Parent,
        OnMove = props.OnMove,
    })
    self.Frame = self.panel.Frame
    self.source = props.Modules or {}
    self.binds = props.Binds or {}
    self:Sync()
    return self
end

function Keybinds:Sync()
    self.panel:Clear()
    local shown = 0
    for _, card in ipairs(self.source) do
        if card.Bind then
            shown = shown + 1
            self.panel:Row({
                Name = card.Name,
                Icon = card.Icon,
                Value = Util.keyName(card.Bind),
                Color = card.Enabled and Theme.get("accent") or Theme.get("textFaint"),
                LayoutOrder = shown,
            })
        end
    end

    -- a keybind added as a control rather than on a module header still belongs
    -- on this list; without it a script's binds are invisible
    for _, entry in ipairs(self.binds) do
        local key = entry.Control and entry.Control.Value or entry.Bind
        if key then
            shown = shown + 1
            self.panel:Row({
                Name = entry.Name,
                Icon = entry.Icon,
                Value = Util.keyName(key),
                Color = Theme.get("accent"),
                LayoutOrder = shown,
            })
        end
    end

    self.Frame.Visible = shown > 0 and not self.Hidden
end

function Keybinds:SetVisible(state)
    self.Hidden = not state
    self:Sync()
end

return Keybinds
end

__flowStartupCheckpoint()
__modules["hud/notify"] = function(require)
__flowStartupCheckpoint()
local Util = require("core/util")
local Theme = require("core/theme")
local Craft = require("core/craft")
local Icons = require("core/icons")
local Overlay = require("ui/overlay")

local Notify = {}

Notify.history = {}

local stack

local tone = {
    info = "accent",
    success = "success",
    danger = "danger",
    warning = "warning",
}

function Notify.attach(layer)
    stack = Craft.frame({
        Name = "Toasts",
        BackgroundTransparency = 1,
        Size = UDim2.fromOffset(276, 400),
        Position = UDim2.new(1, -18, 1, -18),
        AnchorPoint = Vector2.new(1, 1),
        Parent = layer,
    })
    Util.list(stack, 8, Enum.FillDirection.Vertical, Enum.HorizontalAlignment.Right, Enum.VerticalAlignment.Bottom)
end

function Notify.push(opts)
    opts = opts or {}
    local kind = tone[opts.Kind or "info"] or "accent"
    table.insert(Notify.history, 1, {
        Title = opts.Title or "Notice",
        Text = opts.Text or "",
        Icon = opts.Icon or "info",
        Kind = kind,
        Stamp = os.date("%H:%M"),
    })
    while #Notify.history > 24 do
        table.remove(Notify.history)
    end

    if not stack then
        return
    end

    local card = Util.new("CanvasGroup", {
        Name = "Toast",
        BackgroundColor3 = Theme.get("surface"),
        BorderSizePixel = 0,
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        GroupTransparency = 1,
        Position = UDim2.fromOffset(44, 0),
        Parent = stack,
    })
    Theme.bind(card, "BackgroundColor3", "surface")
    Util.corner(card, 12)
    local edge = Util.stroke(card, Theme.get("line"), 1, 0.2)
    Theme.bind(edge, "Color", "line")

    -- scale is what makes the entrance feel like it arrives rather than slides;
    -- it animates alongside position and fade
    local scale = Util.new("UIScale", { Scale = 0.92, Parent = card })

    local inner = Craft.frame({
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        ZIndex = 3,
        Parent = card,
    })
    Util.pad(inner, 12, 12, 13, 13)

    Craft.tile({
        Icon = opts.Icon or "info",
        Size = 28,
        Token = "surfaceAlt",
        IconToken = kind,
        Position = UDim2.fromOffset(0, 1),
        AnchorPoint = Vector2.new(0, 0),
        ZIndex = 4,
        Parent = inner,
    })

    local words = Craft.frame({
        BackgroundTransparency = 1,
        Size = UDim2.new(1, -39, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        Position = UDim2.fromOffset(39, 0),
        ZIndex = 4,
        Parent = inner,
    })
    Util.list(words, 2)

    Craft.text({
        Text = opts.Title or "Notice",
        Token = "text",
        TextSize = 13.5,
        FontFace = Theme.font.semi,
        Size = UDim2.new(1, 0, 0, 17),
        ZIndex = 5,
        Parent = words,
    })

    if opts.Text and opts.Text ~= "" then
        Craft.text({
            Text = opts.Text,
            Token = "textFaint",
            TextSize = 12,
            FontFace = Theme.font.regular,
            TextWrapped = true,
            LineHeight = 1.15,
            Size = UDim2.new(1, 0, 0, 0),
            AutomaticSize = Enum.AutomaticSize.Y,
            ZIndex = 5,
            Parent = words,
        })
    end

    local rail = Craft.frame({
        Token = "raised",
        Size = UDim2.new(1, -24, 0, 2),
        Position = UDim2.new(0, 12, 1, -7),
        Radius = UDim.new(1, 0),
        ZIndex = 4,
        Parent = card,
    })
    local burn = Craft.frame({
        Token = kind,
        Size = UDim2.fromScale(1, 1),
        Radius = UDim.new(1, 0),
        ZIndex = 5,
        Parent = rail,
    })

    local life = opts.Duration or 4
    local dying = false

    -- entrance: fade, glide and settle at once
    Util.tween(card, { GroupTransparency = 0, Position = UDim2.fromOffset(0, 0) }, Util.ease.glide)
    Util.tween(scale, { Scale = 1 }, TweenInfo.new(0.42, Enum.EasingStyle.Back, Enum.EasingDirection.Out))

    local countdown = Util.tween(burn, { Size = UDim2.fromScale(0, 1) }, TweenInfo.new(life, Enum.EasingStyle.Linear))

    local function dismiss()
        if dying then
            return
        end
        dying = true
        countdown:Cancel()

        local exit = TweenInfo.new(0.26, Enum.EasingStyle.Quint, Enum.EasingDirection.In)
        Util.tween(card, { GroupTransparency = 1, Position = UDim2.fromOffset(44, 0) }, exit)
        Util.tween(scale, { Scale = 0.94 }, exit)

        -- collapse the footprint so toasts below glide up instead of snapping
        task.delay(0.16, function()
            if card.Parent then
                card.AutomaticSize = Enum.AutomaticSize.None
                Util.tween(
                    card,
                    { Size = UDim2.new(1, 0, 0, 0) },
                    TweenInfo.new(0.2, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
                )
            end
        end)
        task.delay(0.42, function()
            card:Destroy()
        end)
    end

    -- hovering holds the toast open, so a long message can actually be read
    local hover = Craft.button({
        Name = "Hit",
        BackgroundTransparency = 1,
        Size = UDim2.fromScale(1, 1),
        ZIndex = 6,
        Parent = card,
    })

    local held = false
    hover.MouseEnter:Connect(function()
        held = true
        countdown:Pause()
        Util.tween(scale, { Scale = 1.02 }, Util.ease.out)
    end)
    hover.MouseLeave:Connect(function()
        held = false
        if not dying then
            countdown:Play()
            Util.tween(scale, { Scale = 1 }, Util.ease.out)
        end
    end)
    hover.MouseButton1Click:Connect(dismiss)

    task.delay(life, function()
        while held and not dying do
            task.wait(0.1)
        end
        dismiss()
    end)

    return card
end

function Notify.panel(anchor)
    Overlay.toggle({
        Key = anchor,
        Anchor = anchor,
        Width = 246,
        Align = "right",
        Build = function(panel)
            Util.pad(panel, 10)
            Util.list(panel, 6)

            Craft.text({
                Text = "Notifications",
                Token = "textFaint",
                TextSize = 10.5,
                FontFace = Theme.font.bold,
                Size = UDim2.new(1, 0, 0, 12),
                LayoutOrder = 1,
                ZIndex = 3,
                Parent = panel,
            })

            if #Notify.history == 0 then
                Craft.text({
                    Text = "Nothing here yet.",
                    Token = "textFaint",
                    TextSize = 11.5,
                    Size = UDim2.new(1, 0, 0, 34),
                    LayoutOrder = 2,
                    ZIndex = 3,
                    Parent = panel,
                })
                return
            end

            local feed = Craft.scroll({
                Size = UDim2.new(1, 0, 0, math.min(#Notify.history * 44, 240)),
                LayoutOrder = 2,
                Parent = panel,
            })
            Util.list(feed, 2)

            for i, entry in ipairs(Notify.history) do
                local row = Craft.frame({
                    BackgroundTransparency = 1,
                    Size = UDim2.new(1, 0, 0, 42),
                    LayoutOrder = i,
                    ZIndex = 3,
                    Parent = feed,
                })
                Craft.tile({
                    Icon = entry.Icon,
                    Size = 22,
                    Token = "surfaceAlt",
                    IconToken = entry.Kind,
                    Position = UDim2.new(0, 2, 0.5, 0),
                    AnchorPoint = Vector2.new(0, 0.5),
                    ZIndex = 4,
                    Parent = row,
                })
                Craft.text({
                    Text = entry.Title,
                    Token = "text",
                    TextSize = 12,
                    FontFace = Theme.font.semi,
                    Position = UDim2.fromOffset(32, 6),
                    Size = UDim2.new(1, -70, 0, 14),
                    ZIndex = 4,
                    Parent = row,
                })
                Craft.text({
                    Text = entry.Text,
                    Token = "textFaint",
                    TextSize = 10.5,
                    TextTruncate = Enum.TextTruncate.AtEnd,
                    Position = UDim2.fromOffset(32, 21),
                    Size = UDim2.new(1, -40, 0, 13),
                    ZIndex = 4,
                    Parent = row,
                })
                Craft.text({
                    Text = entry.Stamp,
                    Token = "textFaint",
                    TextSize = 10,
                    TextXAlignment = Enum.TextXAlignment.Right,
                    Position = UDim2.fromOffset(0, 6),
                    Size = UDim2.new(1, -2, 0, 14),
                    ZIndex = 4,
                    Parent = row,
                })
            end
        end,
    })
end

return Notify
end

__flowStartupCheckpoint()
__modules["hud/panel"] = function(require)
__flowStartupCheckpoint()
local Util = require("core/util")
local Theme = require("core/theme")
local Craft = require("core/craft")
local Icons = require("core/icons")

local Panel = {}
Panel.__index = Panel

function Panel.glass(props)
    local frame = Craft.frame({
        Name = props.Name or "Panel",
        Token = "backdrop",
        Radius = props.Radius or 10,
        BackgroundTransparency = props.Transparency or 0.12,
        Size = props.Size or UDim2.fromOffset(200, 0),
        Position = props.Position or UDim2.fromOffset(20, 20),
        AnchorPoint = props.AnchorPoint,
        AutomaticSize = props.AutomaticSize or Enum.AutomaticSize.Y,
        Parent = props.Parent,
    })
    local edge = Util.stroke(frame, Theme.get("line"), 1, 0.4)
    Theme.bind(edge, "Color", "line")
    return frame
end

function Panel.new(props)
    local self = setmetatable({}, Panel)
    self.rows = {}

    local frame = Panel.glass({
        Name = props.Title or "Panel",
        Size = UDim2.fromOffset(props.Width or 196, 0),
        Position = props.Position,
        AnchorPoint = props.AnchorPoint,
        Parent = props.Parent,
    })
    Util.list(frame, 0)
    self.Frame = frame

    if props.Title then
        local head = Craft.frame({
            Name = "Head",
            BackgroundTransparency = 1,
            Size = UDim2.new(1, 0, 0, 36),
            LayoutOrder = 1,
            Parent = frame,
        })

        local cell = Craft.frame({
            BackgroundTransparency = 1,
            Size = UDim2.fromOffset(36, 36),
            Parent = head,
        })
        Icons.draw({ Icon = props.Icon or "grid", Size = 15, Token = "textDim", ZIndex = 3, Parent = cell })

        Craft.frame({
            Token = "line",
            Size = UDim2.fromOffset(1, 15),
            Position = UDim2.new(0, 36, 0.5, 0),
            AnchorPoint = Vector2.new(0, 0.5),
            BackgroundTransparency = 0.35,
            ZIndex = 3,
            Parent = head,
        })

        Craft.text({
            Text = props.Title,
            Token = "text",
            TextSize = 13,
            FontFace = Theme.font.semi,
            Position = UDim2.fromOffset(48, 0),
            Size = UDim2.new(1, -58, 1, 0),
            ZIndex = 3,
            Parent = head,
        })

        Craft.frame({
            Token = "line",
            Size = UDim2.new(1, 0, 0, 1),
            Position = UDim2.fromOffset(0, 35),
            BackgroundTransparency = 0.45,
            ZIndex = 3,
            Parent = head,
        })
    end

    local body = Craft.frame({
        Name = "Body",
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        LayoutOrder = 2,
        Parent = frame,
    })
    -- callers tune spacing through props; a second UIPadding or UIListLayout on the
    -- same frame fights the first one, so the body only ever gets these
    Util.list(body, props.Gap or 0)
    Util.pad(body, props.PadTop or 5, props.PadX or 0, props.PadBottom or 6, props.PadX or 0)
    self.Body = body

    if props.Draggable ~= false then
        Util.drag(frame, frame, props.OnMove)
    end

    return self
end

function Panel:Row(props)
    local row = Craft.frame({
        Name = "",
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, props.Height or 30),
        LayoutOrder = props.LayoutOrder or (#self.rows + 1),
        Parent = self.Body,
    })

    local cell = Craft.frame({
        BackgroundTransparency = 1,
        Size = UDim2.fromOffset(36, props.Height or 30),
        Parent = row,
    })
    local glyph = Icons.draw({
        Icon = props.Icon or "cube",
        Size = 15,
        Color = props.Color or Theme.get("accent"),
        ZIndex = 3,
        Parent = cell,
    })

    Craft.frame({
        Token = "line",
        Size = UDim2.fromOffset(1, 13),
        Position = UDim2.new(0, 36, 0.5, 0),
        AnchorPoint = Vector2.new(0, 0.5),
        BackgroundTransparency = 0.5,
        ZIndex = 3,
        Parent = row,
    })

    local label = Craft.text({
        Text = props.Name or "",
        Token = "textDim",
        TextSize = 12.5,
        FontFace = Theme.font.medium,
        Position = UDim2.fromOffset(48, 0),
        Size = UDim2.new(1, -92, 1, 0),
        TextTruncate = Enum.TextTruncate.AtEnd,
        ZIndex = 3,
        Parent = row,
    })

    local value = Craft.text({
        Text = props.Value or "",
        Token = "textFaint",
        TextSize = 12,
        FontFace = Theme.font.semi,
        TextXAlignment = Enum.TextXAlignment.Right,
        Position = UDim2.new(1, -13, 0, 0),
        AnchorPoint = Vector2.new(1, 0),
        Size = UDim2.new(0, 64, 1, 0),
        ZIndex = 3,
        Parent = row,
    })

    local entry = { Frame = row, Label = label, Value = value, Glyph = glyph }
    table.insert(self.rows, entry)
    return entry
end

function Panel:Clear()
    for _, entry in ipairs(self.rows) do
        entry.Frame:Destroy()
    end
    table.clear(self.rows)
end

function Panel:SetVisible(state)
    self.Hidden = not state
    self.Frame.Visible = state and true or false
end

return Panel
end

__flowStartupCheckpoint()
__modules["hud/stats"] = function(require)
__flowStartupCheckpoint()
local Players = __service("Players")

local Util = require("core/util")
local Theme = require("core/theme")
local Craft = require("core/craft")
local Panel = require("hud/panel")

local Stats = {}
Stats.__index = Stats

local lp = Players.LocalPlayer

local function rootOf(player)
    local char = player.Character
    return char and char:FindFirstChild("HumanoidRootPart")
end

function Stats.new(props)
    local self = setmetatable({}, Stats)
    self.rows = {}
    self.auto = props.Auto ~= false
    self.limit = props.Limit or 6

    self.panel = Panel.new({
        Title = props.Title or "Stats",
        Icon = props.Icon or "user",
        Width = props.Width or 232,
        Position = props.Position,
        Parent = props.Parent,
        OnMove = props.OnMove,
    })
    self.Frame = self.panel.Frame
    self.Body = self.panel.Body

    self.alive = true
    if self.auto then
        local interval = props.Interval or 1
        task.spawn(function()
            while self.alive do
                -- a panel the user has switched off still ran a full distance
                -- sort against every player in the server, once a second
                if not self.Hidden then
                    self:Sync()
                end
                task.wait(interval)
            end
        end)
    end

    return self
end

-- one line: avatar, display name, right-aligned readout
function Stats:Row(props)
    local row = Craft.frame({
        Name = "",
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 33),
        LayoutOrder = props.LayoutOrder or (#self.rows + 1),
        Parent = self.Body,
    })

    local avatar = Util.new("ImageLabel", {
        Name = "Face",
        BackgroundColor3 = Theme.get("raised"),
        BorderSizePixel = 0,
        Size = UDim2.fromOffset(23, 23),
        Position = UDim2.new(0, 12, 0.5, 0),
        AnchorPoint = Vector2.new(0, 0.5),
        ZIndex = 3,
        Parent = row,
    })
    Util.corner(avatar, 6)
    Theme.bind(avatar, "BackgroundColor3", "raised")
    if props.UserId then
        avatar.Image = Util.thumbnail(props.UserId)
    end

    Craft.frame({
        Token = "line",
        Size = UDim2.fromOffset(1, 14),
        Position = UDim2.new(0, 45, 0.5, 0),
        AnchorPoint = Vector2.new(0, 0.5),
        BackgroundTransparency = 0.5,
        ZIndex = 3,
        Parent = row,
    })

    local label = Craft.text({
        Text = props.Name or "",
        Token = props.Live and "text" or "textDim",
        TextSize = 12.5,
        FontFace = props.Live and Theme.font.semi or Theme.font.medium,
        TextTruncate = Enum.TextTruncate.AtEnd,
        Position = UDim2.fromOffset(57, 0),
        Size = UDim2.new(1, -120, 1, 0),
        ZIndex = 3,
        Parent = row,
    })

    local value = Craft.text({
        Text = props.Value or "",
        Token = "textFaint",
        TextSize = 12,
        FontFace = Theme.font.semi,
        TextXAlignment = Enum.TextXAlignment.Right,
        Position = UDim2.new(1, -13, 0, 0),
        AnchorPoint = Vector2.new(1, 0),
        Size = UDim2.new(0, 60, 1, 0),
        ZIndex = 3,
        Parent = row,
    })
    if props.Color then
        value.TextColor3 = props.Color
    end

    local entry = { Frame = row, Label = label, Value = value, Avatar = avatar }
    table.insert(self.rows, entry)
    return entry
end

function Stats:Clear()
    for _, entry in ipairs(self.rows) do
        entry.Frame:Destroy()
    end
    table.clear(self.rows)
end

--[[
    Nearest players first, distance in studs.

    This used to Clear() and rebuild: every row destroyed and re-created once a
    second, eight instances apiece, each one firing off a yielding thumbnail
    request. Rows are kept and rewritten now, and the ones past the end of the
    list are hidden rather than destroyed — so a steady server costs a sort and a
    handful of string writes, and nothing is allocated at all.
]]
function Stats:Sync()
    local hrp = rootOf(lp)
    local found = self.scratch or {}
    self.scratch = found
    table.clear(found)

    for _, plr in ipairs(Players:GetPlayers()) do
        local other = rootOf(plr)
        local distance
        if plr == lp then
            distance = 0
        elseif hrp and other then
            distance = (other.Position - hrp.Position).Magnitude
        end
        if distance then
            table.insert(found, { player = plr, distance = distance })
        end
    end

    table.sort(found, function(a, b)
        return a.distance < b.distance
    end)

    local shown = math.min(#found, self.limit)
    for i = 1, shown do
        local hit = found[i]
        local mine = hit.player == lp
        local entry = self.rows[i]
        if not entry then
            entry = self:Row({ LayoutOrder = i })
        end
        entry.Frame.Visible = true

        local name = hit.player.DisplayName
        if entry.name ~= name then
            entry.name = name
            entry.Label.Text = name
        end

        local face = Util.thumbnail(hit.player.UserId)
        if entry.face ~= face then
            entry.face = face
            entry.Avatar.Image = face
        end

        local text = mine and "you" or string.format("%dm", math.floor(hit.distance + 0.5))
        if entry.text ~= text then
            entry.text = text
            entry.Value.Text = text
        end

        if entry.mine ~= mine then
            entry.mine = mine
            entry.Label.FontFace = mine and Theme.font.semi or Theme.font.medium
            Theme.rebind(entry.Label, "TextColor3", mine and "text" or "textDim")
            Theme.rebind(entry.Value, "TextColor3", mine and "accent" or "textFaint")
        end
    end

    for i = shown + 1, #self.rows do
        self.rows[i].Frame.Visible = false
    end
end

function Stats:SetVisible(state)
    self.Hidden = not state
    self.Frame.Visible = state and true or false
end

function Stats:Destroy()
    self.alive = false
    self.Frame:Destroy()
end

return Stats
end

__flowStartupCheckpoint()
__modules["hud/target"] = function(require)
__flowStartupCheckpoint()
local Players = __service("Players")

local Util = require("core/util")
local Theme = require("core/theme")
local Craft = require("core/craft")
local Icons = require("core/icons")
local Panel = require("hud/panel")

local Target = {}
Target.__index = Target

local lp = Players.LocalPlayer

local marks = { "cube", "shield", "bolt", "wing", "heart" }

local function rootOf(player)
    local char = player.Character
    return char and char:FindFirstChild("HumanoidRootPart")
end

function Target.new(props)
    local self = setmetatable({}, Target)
    self.auto = props.Auto ~= false

    local frame = Panel.glass({
        Name = "TargetHud",
        Size = UDim2.fromOffset(props.Width or 244, 76),
        AutomaticSize = Enum.AutomaticSize.None,
        Radius = 11,
        Position = props.Position or UDim2.new(1, -238, 0, 18),
        Parent = props.Parent,
    })
    self.Frame = frame

    local avatar = Util.new("ImageLabel", {
        Name = "Face",
        BackgroundColor3 = Theme.get("raised"),
        BorderSizePixel = 0,
        Size = UDim2.fromOffset(52, 52),
        Position = UDim2.fromOffset(12, 12),
        ZIndex = 3,
        Parent = frame,
    })
    Util.corner(avatar, 10)
    Theme.bind(avatar, "BackgroundColor3", "raised")
    self.Avatar = avatar

    self.Name = Craft.text({
        Text = "No target",
        Token = "text",
        TextSize = 13.5,
        FontFace = Theme.font.semi,
        TextTruncate = Enum.TextTruncate.AtEnd,
        Position = UDim2.fromOffset(74, 11),
        Size = UDim2.new(1, -142, 0, 17),
        ZIndex = 3,
        Parent = frame,
    })

    self.Health = Craft.text({
        Text = "--",
        Token = "textFaint",
        TextSize = 12.5,
        FontFace = Theme.font.semi,
        TextXAlignment = Enum.TextXAlignment.Right,
        Position = UDim2.new(1, -13, 0, 11),
        AnchorPoint = Vector2.new(1, 0),
        Size = UDim2.fromOffset(64, 17),
        ZIndex = 3,
        Parent = frame,
    })

    local rail = Craft.frame({
        Token = "raised",
        Radius = UDim.new(1, 0),
        Size = UDim2.new(1, -87, 0, 6),
        Position = UDim2.fromOffset(74, 35),
        ZIndex = 3,
        Parent = frame,
    })
    self.Bar = Craft.frame({
        Token = "success",
        Radius = UDim.new(1, 0),
        Size = UDim2.fromScale(1, 1),
        ZIndex = 4,
        Parent = rail,
    })

    local strip = Craft.frame({
        BackgroundTransparency = 1,
        Size = UDim2.new(1, -87, 0, 16),
        Position = UDim2.fromOffset(74, 49),
        ZIndex = 3,
        Parent = frame,
    })
    Util.list(strip, 10, Enum.FillDirection.Horizontal, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Center)

    self.marks = {}
    for i, icon in ipairs(marks) do
        local cell = Craft.frame({
            BackgroundTransparency = 1,
            Size = UDim2.fromOffset(15, 15),
            LayoutOrder = i,
            ZIndex = 4,
            Parent = strip,
        })
        self.marks[i] = Icons.draw({ Icon = icon, Size = 15, Color = Theme.get("textFaint"), ZIndex = 5, Parent = cell })
    end

    Util.drag(frame, frame, props.OnMove)

    self.alive = true

    -- both loops used to run flat out whether or not the widget was on screen.
    -- Pick walks every player in the server and Paint runs ten times a second,
    -- so a hidden target readout was costing more than most visible ones.
    task.spawn(function()
        while self.alive do
            if self.auto and not self.Hidden then
                self:Pick()
            end
            task.wait(0.4)
        end
    end)

    task.spawn(function()
        while self.alive do
            if not self.Hidden then
                self:Paint()
            end
            task.wait(0.1)
        end
    end)

    return self
end

function Target:Pick()
    local hrp = rootOf(lp)
    if not hrp then
        self:SetTarget(nil)
        return
    end
    local best, bestDist
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= lp then
            local other = rootOf(plr)
            if other then
                local d = (other.Position - hrp.Position).Magnitude
                if not bestDist or d < bestDist then
                    best, bestDist = plr, d
                end
            end
        end
    end
    self:SetTarget(best)
end

function Target:SetTarget(player)
    if self.player == player then
        return
    end
    self.player = player
    if not player then
        self.Name.Text = "No target"
        self.Health.Text = "--"
        self.Avatar.Image = ""
        return
    end
    self.Name.Text = player.DisplayName
    task.spawn(function()
        local url = Util.thumbnail(player.UserId)
        if self.player == player then
            self.Avatar.Image = url
        end
    end)
end

function Target:Paint()
    local player = self.player
    if not player or not player.Parent then
        self.Frame.BackgroundTransparency = 0.35
        return
    end
    self.Frame.BackgroundTransparency = 0.12

    local char = player.Character
    local hum = char and char:FindFirstChildWhichIsA("Humanoid")
    if not hum then
        self.Health.Text = "--"
        return
    end

    local alpha = Util.clamp(hum.Health / math.max(hum.MaxHealth, 1), 0, 1)
    self.Health.Text = string.format("%d/%d", math.floor(hum.Health + 0.5), math.floor(hum.MaxHealth + 0.5))
    Util.tween(self.Bar, { Size = UDim2.fromScale(alpha, 1) }, Util.ease.snap)
    self.Bar.BackgroundColor3 = alpha > 0.55 and Theme.get("success")
        or (alpha > 0.25 and Theme.get("warning") or Theme.get("danger"))

    local tool = char and char:FindFirstChildWhichIsA("Tool") ~= nil
    local shielded = char and char:FindFirstChildWhichIsA("ForceField") ~= nil
    local quick = hum.WalkSpeed > 17
    local springy = hum.JumpPower > 51 or hum.UseJumpPower == false
    local hurt = alpha < 1

    local states = { tool, shielded, quick, springy, hurt }
    for i, glyph in ipairs(self.marks) do
        Icons.tint(glyph, states[i] and Theme.get("accent") or Theme.get("textFaint"))
    end
end

function Target:SetVisible(state)
    self.Hidden = not state
    self.Frame.Visible = state and true or false
end

function Target:Destroy()
    self.alive = false
    self.Frame:Destroy()
end

return Target
end

__flowStartupCheckpoint()
__modules["hud/trigger"] = function(require)
__flowStartupCheckpoint()
local Util = require("core/util")
local Theme = require("core/theme")
local Craft = require("core/craft")
local Icons = require("core/icons")
local Panel = require("hud/panel")

-- A pill that opens and closes the menu, so the interface is reachable without
-- knowing the keybind. Sits top centre by default and is draggable.
local Trigger = {}
Trigger.__index = Trigger

function Trigger.new(props)
    local self = setmetatable({}, Trigger)
    self.onToggle = props.OnToggle
    self.open = props.Default ~= false

    local frame = Panel.glass({
        Name = "Trigger",
        Size = UDim2.fromOffset(0, 36),
        AutomaticSize = Enum.AutomaticSize.X,
        Radius = 10,
        Position = props.Position or UDim2.new(0.5, -70, 0, props.Top or 18),
        Parent = props.Parent,
    })
    self.Frame = frame

    -- the pill auto-sizes, so centre it once its real width is known
    if not props.Position then
        task.defer(function()
            if frame.Parent then
                frame.Position = UDim2.new(0.5, -math.floor(frame.AbsoluteSize.X / 2), 0, props.Top or 18)
            end
        end)
    end

    local button = Craft.button({
        Name = "Hit",
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 1, 0),
        ZIndex = 5,
        Parent = frame,
    })

    local row = Craft.frame({
        BackgroundTransparency = 1,
        Size = UDim2.new(0, 0, 1, 0),
        AutomaticSize = Enum.AutomaticSize.X,
        ZIndex = 3,
        Parent = frame,
    })
    Util.pad(row, 0, 12, 0, 9)
    Util.list(row, 9, Enum.FillDirection.Horizontal, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Center)

    -- bare logo, matching the window header rather than sitting in a tile
    local markName = props.Mark or "brand"
    local mark = Craft.frame({
        Name = "Mark",
        BackgroundTransparency = 1,
        Size = UDim2.fromOffset(24, 24),
        LayoutOrder = 1,
        ZIndex = 4,
        Parent = row,
    })
    Icons.draw({ Icon = markName, Size = 24, ZIndex = 5, Parent = mark })

    Craft.text({
        Name = "Label",
        Text = props.Text or "FLOW",
        Token = "text",
        TextSize = 13,
        FontFace = Theme.font.bold,
        AutomaticSize = Enum.AutomaticSize.X,
        Size = UDim2.new(0, 0, 1, 0),
        LayoutOrder = 2,
        ZIndex = 4,
        Parent = row,
    })

    Craft.frame({
        Token = "line",
        Size = UDim2.fromOffset(1, 16),
        BackgroundTransparency = 0.35,
        LayoutOrder = 3,
        ZIndex = 4,
        Parent = row,
    })

    local caretCell = Craft.frame({
        BackgroundTransparency = 1,
        Size = UDim2.fromOffset(16, 16),
        LayoutOrder = 4,
        ZIndex = 4,
        Parent = row,
    })
    self.Caret = Icons.draw({ Icon = "chevron-down", Size = 15, Token = "textDim", ZIndex = 5, Parent = caretCell })

    -- count of enabled modules: on mobile this pill is the only always-visible
    -- surface, so it carries the one number worth glancing at
    self.Badge = Craft.frame({
        Name = "Badge",
        Token = "accent",
        Radius = UDim.new(1, 0),
        Size = UDim2.fromOffset(18, 18),
        Position = UDim2.new(1, -4, 0, -4),
        AnchorPoint = Vector2.new(1, 0),
        Visible = false,
        ZIndex = 7,
        Parent = frame,
    })
    self.BadgeText = Craft.text({
        Name = "Count",
        Text = "0",
        Token = "white",
        TextSize = 11,
        FontFace = Theme.font.bold,
        TextXAlignment = Enum.TextXAlignment.Center,
        Size = UDim2.fromScale(1, 1),
        ZIndex = 8,
        Parent = self.Badge,
    })

    Util.hover(button, frame, { BackgroundTransparency = 0.12 }, { BackgroundTransparency = 0 })

    -- a drag should move the pill, not fire the toggle
    local moved, downAt = false, nil
    button.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            moved, downAt = false, input.Position
        end
    end)
    button.InputChanged:Connect(function(input)
        if downAt and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            if (input.Position - downAt).Magnitude > 6 then
                moved = true
            end
        end
    end)
    button.MouseButton1Click:Connect(function()
        if not moved then
            self:Toggle()
        end
    end)

    Util.drag(frame, frame, props.OnMove)

    self:Paint()
    return self
end

function Trigger:Toggle(state)
    if state == nil then
        state = not self.open
    end
    self.open = state and true or false
    self:Paint()
    if self.onToggle then
        task.spawn(self.onToggle, self.open)
    end
end

function Trigger:Paint()
    Util.tween(self.Caret, { Rotation = self.open and 180 or 0 }, Util.ease.out)
    Icons.tint(self.Caret, self.open and Theme.get("accent") or Theme.get("textDim"))
end

-- n enabled modules; hides itself at zero so an idle menu stays clean
function Trigger:SetCount(n)
    n = tonumber(n) or 0
    local show = n > 0
    self.BadgeText.Text = n > 99 and "99+" or tostring(n)
    self.Badge.Size = UDim2.fromOffset(n > 9 and 22 or 18, 18)

    if show ~= self.Badge.Visible then
        self.Badge.Visible = show
        if show then
            local pop = Util.new("UIScale", { Scale = 0.6, Parent = self.Badge })
            Util.tween(pop, { Scale = 1 }, Util.ease.spring)
            task.delay(0.5, function()
                if pop.Parent then
                    pop:Destroy()
                end
            end)
        end
    end
end

function Trigger:SetVisible(state)
    self.Hidden = not state
    self.Frame.Visible = state and true or false
end

function Trigger:Destroy()
    self.Frame:Destroy()
end

return Trigger
end

__flowStartupCheckpoint()
__modules["hud/watermark"] = function(require)
__flowStartupCheckpoint()
local Players = __service("Players")

local Util = require("core/util")
local Theme = require("core/theme")
local Craft = require("core/craft")
local Icons = require("core/icons")
local Panel = require("hud/panel")

local Watermark = {}
Watermark.__index = Watermark

local lp = Players.LocalPlayer

function Watermark.new(props)
    local self = setmetatable({}, Watermark)

    local frame = Panel.glass({
        Name = "Watermark",
        Size = UDim2.fromOffset(0, 34),
        AutomaticSize = Enum.AutomaticSize.X,
        Radius = 9,
        Position = props.Position or UDim2.fromOffset(18, 18),
        Parent = props.Parent,
    })
    Util.pad(frame, 0, 13, 0, 6)
    Util.list(frame, 10, Enum.FillDirection.Horizontal, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Center)
    self.Frame = frame

    local avatar = Util.new("ImageLabel", {
        Name = "Avatar",
        BackgroundColor3 = Theme.get("raised"),
        BorderSizePixel = 0,
        Size = UDim2.fromOffset(23, 23),
        LayoutOrder = 1,
        ZIndex = 3,
        Parent = frame,
    })
    Util.corner(avatar, 6)
    task.spawn(function()
        avatar.Image = Util.thumbnail(lp.UserId)
    end)

    local identity = Craft.frame({
        BackgroundTransparency = 1,
        Size = UDim2.new(0, 0, 1, 0),
        AutomaticSize = Enum.AutomaticSize.X,
        LayoutOrder = 2,
        ZIndex = 3,
        Parent = frame,
    })
    Util.list(identity, 6, Enum.FillDirection.Horizontal, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Center)

    local userCell = Craft.frame({
        BackgroundTransparency = 1,
        Size = UDim2.fromOffset(14, 14),
        LayoutOrder = 1,
        ZIndex = 4,
        Parent = identity,
    })
    Icons.draw({ Icon = "user", Size = 14, Token = "textDim", ZIndex = 5, Parent = userCell })

    Craft.text({
        Text = props.Name or lp.DisplayName,
        Token = "text",
        TextSize = 13,
        FontFace = Theme.font.semi,
        AutomaticSize = Enum.AutomaticSize.X,
        Size = UDim2.new(0, 0, 1, 0),
        LayoutOrder = 2,
        ZIndex = 4,
        Parent = identity,
    })

    if props.Tag then
        local badge = Craft.frame({
            Token = "accentSoft",
            Radius = 5,
            Size = UDim2.fromOffset(0, 17),
            AutomaticSize = Enum.AutomaticSize.X,
            LayoutOrder = 3,
            ZIndex = 4,
            Parent = identity,
        })
        Util.pad(badge, 0, 5, 0, 5)
        Craft.text({
            Text = props.Tag,
            Token = "accentGlow",
            TextSize = 10.5,
            FontFace = Theme.font.bold,
            AutomaticSize = Enum.AutomaticSize.X,
            Size = UDim2.new(0, 0, 1, 0),
            TextXAlignment = Enum.TextXAlignment.Center,
            ZIndex = 5,
            Parent = badge,
        })
    end

    local function stat(icon, order)
        local group = Craft.frame({
            BackgroundTransparency = 1,
            Size = UDim2.new(0, 0, 1, 0),
            AutomaticSize = Enum.AutomaticSize.X,
            LayoutOrder = order,
            ZIndex = 3,
            Parent = frame,
        })
        Util.list(group, 5, Enum.FillDirection.Horizontal, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Center)

        local cell = Craft.frame({
            BackgroundTransparency = 1,
            Size = UDim2.fromOffset(14, 14),
            LayoutOrder = 1,
            ZIndex = 4,
            Parent = group,
        })
        Icons.draw({ Icon = icon, Size = 14, Token = "accent", ZIndex = 5, Parent = cell })

        local value = Craft.text({
            Text = "0",
            Token = "text",
            TextSize = 13,
            FontFace = Theme.font.semi,
            AutomaticSize = Enum.AutomaticSize.X,
            Size = UDim2.new(0, 0, 1, 0),
            LayoutOrder = 2,
            ZIndex = 4,
            Parent = group,
        })

        local unit = Craft.text({
            Text = "",
            Token = "textFaint",
            TextSize = 11,
            FontFace = Theme.font.medium,
            AutomaticSize = Enum.AutomaticSize.X,
            Size = UDim2.new(0, 0, 1, 0),
            LayoutOrder = 3,
            ZIndex = 4,
            Parent = group,
        })

        return value, unit
    end

    local function split(order)
        Craft.frame({
            Token = "line",
            Size = UDim2.fromOffset(1, 16),
            BackgroundTransparency = 0.35,
            LayoutOrder = order,
            ZIndex = 3,
            Parent = frame,
        })
    end

    split(3)
    local pingValue, pingUnit = stat("signal", 4)
    pingUnit.Text = "ms"
    split(5)
    local fpsValue, fpsUnit = stat("gauge", 6)
    fpsUnit.Text = "fps"
    split(7)
    local playerValue, playerUnit = stat("users", 8)
    playerUnit.Text = "players"

    -- the sampler is the library's only RenderStepped connection, so hold on to
    -- the stop function: without it a destroyed watermark kept sampling for the
    -- rest of the session, and every reload of the script added another one
    local readFps, stopFps = Util.fps()
    local readPing = Util.ping()
    self.stopFps = stopFps

    self.alive = true

    task.spawn(function()
        while self.alive do
            if not self.Hidden then
                fpsValue.Text = tostring(readFps())
            end
            task.wait(0.25)
        end
    end)

    task.spawn(function()
        while self.alive do
            if not self.Hidden then
                pingValue.Text = tostring(readPing())
                playerValue.Text = tostring(#Players:GetPlayers())
            end
            task.wait(1)
        end
    end)

    -- pinned by default so it keeps its clearance from the Roblox topbar;
    -- pass Draggable = true to let it be moved
    self.Fixed = not props.Draggable
    if props.Draggable then
        Util.drag(frame, frame, props.OnMove)
    end

    return self
end

function Watermark:SetVisible(state)
    self.Hidden = not state
    self.Frame.Visible = state and true or false
end

function Watermark:Destroy()
    self.alive = false
    if self.stopFps then
        self.stopFps()
        self.stopFps = nil
    end
    self.Frame:Destroy()
end

return Watermark
end

__flowStartupCheckpoint()
__modules["init"] = function(require)
__flowStartupCheckpoint()
local UserInputService = __service("UserInputService")
local RunService = __service("RunService")

local Util = require("core/util")
local Theme = require("core/theme")
local Craft = require("core/craft")
local Icons = require("core/icons")
local State = require("core/state")
local Overlay = require("ui/overlay")
local Controls = require("ui/controls")
local Window = require("ui/window")
local Notify = require("hud/notify")
local Panel = require("hud/panel")
local Watermark = require("hud/watermark")
local Keybinds = require("hud/keybinds")
local Target = require("hud/target")
local Audio = require("core/audio")
local Luarmor = require("core/luarmor")
local Stats = require("hud/stats")
local Trigger = require("hud/trigger")

local Flow = {}
Flow.__index = Flow

Flow.Version = "1.0.0"
Flow.Theme = Theme
Flow.Icons = Icons
Flow.Util = Util
Flow.State = State
Flow.Options = State.flags
Flow.Controls = Controls
Flow.Luarmor = Luarmor
Flow.Audio = Audio

-- false means the interface landed in PlayerGui and the game can enumerate it
Flow.Protected = false

-- display name and order for the HUD toggles in the settings popup
local HUD_META = {
    trigger = { Label = "Menu button", Order = 1 },
    watermark = { Label = "Watermark", Order = 2 },
    stats = { Label = "Players", Order = 3 },
    keybinds = { Label = "Keybinds", Order = 4 },
    target = { Label = "Target HUD", Order = 5 },
}

local function register(self, key, widget)
    local meta = HUD_META[key]
    widget.Key = key
    widget.Label = meta and meta.Label or key
    widget.Order = meta and meta.Order or 99
    self.hud[key] = widget
    return widget
end

local function layer(root, name, z)
    return Craft.frame({
        Name = name,
        BackgroundTransparency = 1,
        Size = UDim2.fromScale(1, 1),
        ZIndex = z,
        Parent = root,
    })
end

function Flow.new(opts)
    opts = opts or {}
    local self = setmetatable({}, Flow)

    self.modules = {}
    -- standalone keybind controls (a control, not a module) so the Keybinds
    -- panel can list them too
    self.binds = {}
    self.windows = {}
    self.hud = {}
    self.menuKey = opts.Key or Enum.KeyCode.RightShift
    self.configName = "default"

    --[[
        Density is picked before a single instance is built, because every fixed
        height in the library reads Theme.chrome at construction time. Auto by
        default; pass Density = "compact" to keep the desktop metrics on a phone,
        or "touch" to force the bigger targets on a desktop with a touchscreen.
    ]]
    local density = opts.Density
    if density == nil then
        density = Util.isMobile() and "touch" or "compact"
    end
    Theme.density(density)

    if opts.Accent then
        Theme.setAccent(opts.Accent)
    end
    if opts.Folder then
        State.folder = opts.Folder
    end
    if opts.Sound ~= nil then
        Audio.enabled = opts.Sound and true or false
    end
    -- true for a 2s toast, or a number for a custom duration
    self.notifyToggles = opts.NotifyToggles
    if opts.Volume then
        Audio.volume = opts.Volume
    end

    local root = Util.root()
    self.Root = root
    Audio.attach(root)

    Flow.Protected = Util.protected
    Flow.Host = Util.host
    self.Protected = Util.protected
    self.Host = Util.host
    if not Util.protected and not RunService:IsStudio() then
        warn("[flow] no hidden container on this executor - the interface is in PlayerGui and is visible to the game")
    end

    self.layers = {
        hud = layer(root, "Hud", 1),
        window = layer(root, "Windows", 10),
        overlay = layer(root, "Overlay", 100),
        toast = layer(root, "Toasts", 200),
    }

    self.userScale = opts.Scale or 1
    self.scale = Util.new("UIScale", { Scale = self.userScale, Parent = self.layers.window })
    self.hudScale = Util.new("UIScale", { Scale = self.userScale, Parent = self.layers.hud })

    self.unfit = Util.onViewport(function()
        self:Fit()
    end)

    Overlay.attach(self.layers.overlay)
    Notify.attach(self.layers.toast)

    self.listener = Util.onInput("began", function(input, typing)
        if typing or not self.menuKey then
            return
        end
        if input.KeyCode == self.menuKey or input.UserInputType == self.menuKey then
            self:ToggleMenu()
        end
    end)

    return self
end

function Flow:Window(opts)
    local window = Window.new(self, opts or {})
    table.insert(self.windows, window)
    task.defer(function()
        self:Fit()
    end)
    return window
end

--[[
    One place that reacts to the viewport: interface scale on small screens, then
    every window re-fits and folds its columns. Runs on creation and on any
    viewport change, so rotating a phone lands correctly instead of clipping.
]]
function Flow:Fit()
    local viewport = Util.viewport()
    local mobile = Util.isMobile()

    local scale = self.userScale or 1
    if mobile then
        --[[
            The floor was 0.65, which is where the interface stopped being
            usable: a 21px switch came out at 13px of glass, under a third of a
            fingertip. Windows already clamp their own width to the viewport, so
            scaling this far down was never what made things fit — it only ever
            made them small. 0.8 keeps text legible and targets pressable.
        ]]
        scale = scale * Util.clamp(viewport.X / 1000, 0.8, 1)
    end
    self.scale.Scale = scale
    self.hudScale.Scale = scale

    for _, window in ipairs(self.windows) do
        window:Fit(viewport)
    end

    self.mobile = mobile
    return mobile, scale
end

function Flow:Watermark(opts)
    opts = opts or {}
    opts.Parent = self.layers.hud
    opts.Position = opts.Position or UDim2.fromOffset(18, Util.inset() + 52)
    return register(self, "watermark", Watermark.new(opts))
end

function Flow:Keybinds(opts)
    opts = opts or {}
    opts.Parent = self.layers.hud
    opts.Modules = self.modules
    opts.Binds = self.binds
    -- bottom right, growing upward as binds are added
    opts.Position = opts.Position or UDim2.new(1, -18, 1, -18)
    opts.AnchorPoint = opts.AnchorPoint or Vector2.new(1, 1)
    return register(self, "keybinds", Keybinds.new(opts))
end

function Flow:Target(opts)
    opts = opts or {}
    opts.Parent = self.layers.hud
    opts.Position = opts.Position or UDim2.new(1, -236, 0, Util.inset() + 14)
    return register(self, "target", Target.new(opts))
end

function Flow:Stats(opts)
    opts = opts or {}
    opts.Parent = self.layers.hud
    opts.Position = opts.Position or UDim2.fromOffset(18, Util.inset() + 300)
    return register(self, "stats", Stats.new(opts))
end

function Flow:Trigger(opts)
    opts = opts or {}
    opts.Parent = self.layers.hud
    -- flush to the very top of the screen; the ScreenGui ignores the GUI inset,
    -- so this is the real top edge, and top-centre is clear of the Roblox topbar
    opts.Top = opts.Top or 6
    opts.OnToggle = function(open)
        self:ToggleMenu(open)
    end
    return register(self, "trigger", Trigger.new(opts))
end

-- single entry point for opening/closing, so the keybind and the pill agree
-- every registered HUD widget, in a stable order
function Flow:HudWidgets()
    local out = {}
    for _, widget in pairs(self.hud) do
        table.insert(out, widget)
    end
    table.sort(out, function(a, b)
        if a.Order == b.Order then
            return tostring(a.Label) < tostring(b.Label)
        end
        return (a.Order or 99) < (b.Order or 99)
    end)
    return out
end

function Flow:ToggleMenu(state)
    if state == nil then
        local first = self.windows[1]
        state = first == nil or not first.open
    end
    Audio.play(state and "open" or "close")
    for _, window in ipairs(self.windows) do
        window:Toggle(state)
    end
    local trigger = self.hud.trigger
    if trigger and trigger.open ~= state then
        trigger.open = state
        trigger:Paint()
    end
    return state
end

function Flow:Panel(opts)
    opts = opts or {}
    opts.Parent = self.layers.hud
    return Panel.new(opts)
end

function Flow:Notify(opts)
    return Notify.push(opts)
end

function Flow:announce(card, enabled)
    if self.hud.keybinds then
        self.hud.keybinds:Sync()
    end

    -- opt-in, because twenty modules means twenty toasts if you are not careful
    if self.notifyToggles then
        Notify.push({
            Title = card.Name,
            Text = enabled and "Enabled" or "Disabled",
            Icon = card.Icon,
            Kind = enabled and "success" or "info",
            Duration = self.notifyToggles == true and 2 or self.notifyToggles,
        })
    end
    local trigger = self.hud.trigger
    if trigger then
        local live = 0
        for _, module in ipairs(self.modules) do
            if module.Enabled then
                live = live + 1
            end
        end
        trigger:SetCount(live)
    end
end

function Flow:rebind()
    if self.hud.keybinds then
        self.hud.keybinds:Sync()
    end
end

function Flow:SetAccent(color)
    Theme.setAccent(color)
    self:retint()
end

function Flow:retint()
    for _, window in ipairs(self.windows) do
        if window.MarkGradient then
            window.MarkGradient.Color = ColorSequence.new(Theme.get("accentGlow"), Theme.get("accentDeep"))
        end
        for _, tab in ipairs(window.tabs) do
            Icons.tint(tab.Glyph, window.active == tab and Theme.get("accent") or Theme.get("textFaint"))
        end
    end
    for _, card in ipairs(self.modules) do
        card:paint()
    end
    if self.hud.keybinds then
        self.hud.keybinds:Sync()
    end
end

function Flow:SetScale(value)
    self.userScale = value
    self:Fit()
end

function Flow:Get(flag)
    return State.flags[flag]
end

function Flow:Set(flag, value)
    State.set(flag, value)
end

function Flow:Watch(flag, fn)
    return State.watch(flag, fn)
end

function Flow:layout()
    local out = { hud = {}, scale = self.scale.Scale, accent = Theme.accent, windows = {} }
    out.shown = {}
    for name, widget in pairs(self.hud) do
        if widget.Frame then
            if not widget.Fixed then
                out.hud[name] = widget.Frame.Position
            end
            out.shown[name] = widget.Hidden ~= true
        end
    end
    for i, window in ipairs(self.windows) do
        out.windows[i] = window.Shell.Position
    end
    return out
end

function Flow:restore(data)
    if typeof(data) ~= "table" then
        return
    end
    if data.accent then
        self:SetAccent(data.accent)
    end
    if data.scale then
        self:SetScale(data.scale)
    end
    for name, position in pairs(data.hud or {}) do
        local widget = self.hud[name]
        if widget and widget.Frame and not widget.Fixed then
            widget.Frame.Position = position
        end
    end
    for name, shown in pairs(data.shown or {}) do
        local widget = self.hud[name]
        if widget and widget.SetVisible then
            widget:SetVisible(shown)
        end
    end
    for i, position in pairs(data.windows or {}) do
        local window = self.windows[i]
        if window then
            window.Shell.Position = position
        end
    end
end

function Flow:Save(name)
    self.configName = name or self.configName
    return State.save(self.configName, self:layout())
end

function Flow:Load(name)
    local ok, extra = State.load(name or self.configName)
    if ok then
        self:restore(extra)
    end
    return ok, extra
end

function Flow:Configs()
    return State.configs()
end

function Flow:Unload()
    self:Destroy()
end

--[[
    A script is re-executed constantly, so unloading has to leave nothing behind
    at all. What used to survive: the watermark's RenderStepped sampler, every
    card's two engine-wide input handlers, the flag registry pointing at dead
    controls, and the theme watcher list. None of it was visible — the tree was
    gone — but it all still ran, and it all stacked up reload after reload.

    Destroying the root first is deliberate: cards and controls release their own
    handlers off Destroying, so by the time the sweep runs the lists are already
    correct and it only has to catch what has no owner.
]]
function Flow:Destroy()
    if self.listener then
        self.listener()
        self.listener = nil
    end
    if self.unfit then
        self.unfit()
        self.unfit = nil
    end
    for _, widget in pairs(self.hud) do
        if widget.Destroy then
            pcall(function()
                widget:Destroy()
            end)
        end
    end
    Overlay.close(true)
    Audio.destroy()
    self.Root:Destroy()
    Theme.sweep()
    table.clear(self.modules)
    table.clear(self.windows)
    table.clear(self.binds)
    table.clear(self.hud)
end

setmetatable(Flow, {
    __call = function(_, opts)
        return Flow.new(opts)
    end,
})

-- Scripts written against the previous library reach it as
-- `loadstring(game:HttpGet(url))().Legacy`. Deliberately not folded into
-- Flow.new: both APIs take a single options table, and telling them apart by
-- sniffing keys would be a guess.
Flow.Legacy = require("ui/legacy")(Flow)

return Flow
end

__flowStartupCheckpoint()
__modules["ui/card"] = function(require)
__flowStartupCheckpoint()
local Util = require("core/util")
local Theme = require("core/theme")
local Craft = require("core/craft")
local Icons = require("core/icons")
local State = require("core/state")
local Overlay = require("ui/overlay")
local Controls = require("ui/controls")
local Audio = require("core/audio")

local Card = {}
Card.__index = Card

function Card.new(tab, opts)
    local self = setmetatable({}, Card)
    self.tab = tab
    self.flow = tab.flow
    self.Name = opts.Name or "Module"
    self.Icon = opts.Icon or "cube"
    self.Flag = opts.Flag
    self.Enabled = opts.Default and true or false
    self.Bind = opts.Keybind
    self.BindMode = opts.BindMode or "Toggle"
    self.Callback = opts.Callback
    self.terms = self.Name:lower()
    self.controls = {}

    local root = Craft.frame({
        -- deliberately unnamed: on an executor without gethui the tree ends up in
        -- PlayerGui, and "Silent Aim" in the hierarchy is a free confession
        Name = "",
        Token = "surface",
        Radius = Theme.radius.card,
        Edge = "lineSoft",
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        LayoutOrder = opts.LayoutOrder or 0,
        ClipsDescendants = true,
        Parent = opts.Parent,
    })
    Util.list(root, 0)
    self.Frame = root
    self.edge = root:FindFirstChildWhichIsA("UIStroke")

    local header = Craft.button({
        Name = "Header",
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, Theme.chrome.card),
        LayoutOrder = 1,
        ZIndex = 3,
        Parent = root,
    })
    Util.pad(header, 0, 12, 0, 12)
    self.Header = header

    local tile = Craft.tile({
        Icon = self.Icon,
        Size = 26,
        Token = "surfaceAlt",
        IconToken = "accent",
        Position = UDim2.new(0, 0, 0.5, 0),
        AnchorPoint = Vector2.new(0, 0.5),
        ZIndex = 4,
        Parent = header,
    })
    self.Tile = tile

    local title = Craft.text({
        Name = "Title",
        Text = self.Name,
        Token = "text",
        TextSize = 13.5,
        FontFace = Theme.font.semi,
        TextTruncate = Enum.TextTruncate.AtEnd,
        Position = UDim2.fromOffset(36, 0),
        Size = UDim2.new(1, -126, 1, 0),
        ZIndex = 4,
        Parent = header,
    })
    self.Title = title

    local cluster = Craft.frame({
        Name = "Cluster",
        BackgroundTransparency = 1,
        Size = UDim2.new(0, 0, 1, 0),
        AutomaticSize = Enum.AutomaticSize.X,
        Position = UDim2.new(1, 0, 0.5, 0),
        AnchorPoint = Vector2.new(1, 0.5),
        ZIndex = 4,
        Parent = header,
    })
    Util.list(
        cluster,
        6,
        Enum.FillDirection.Horizontal,
        Enum.HorizontalAlignment.Right,
        Enum.VerticalAlignment.Center
    )

    local caretCell = Craft.frame({
        Name = "CaretCell",
        BackgroundTransparency = 1,
        Size = UDim2.fromOffset(16, 16),
        Visible = false,
        LayoutOrder = 0,
        ZIndex = 5,
        Parent = cluster,
    })
    self.CaretCell = caretCell
    self.Caret = Icons.draw({ Icon = "chevron-down", Size = 14, Token = "textFaint", ZIndex = 6, Parent = caretCell })

    local bindChip
    bindChip = Controls.keybind(cluster, {
        Default = self.Bind,
        LayoutOrder = 1,
        ZIndex = 5,
        Callback = function(key)
            self.Bind = key
            self.flow:rebind()
        end,
        OnPress = function()
            if self.BindMode == "Toggle" then
                self:Set(not self.Enabled)
            end
        end,
        OnRightClick = function(chip)
            self:BindMenu(chip, bindChip)
        end,
    })
    self.BindControl = bindChip

    local switch = Controls.switch(cluster, {
        Default = self.Enabled,
        LayoutOrder = 3,
        ZIndex = 5,
        Callback = function(v)
            self:Set(v, true)
        end,
    })
    self.Switch = switch

    local clip = Craft.frame({
        Name = "Clip",
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 0),
        LayoutOrder = 2,
        ClipsDescendants = true,
        ZIndex = 2,
        Parent = root,
    })
    self.Clip = clip

    local body = Craft.frame({
        Name = "Body",
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        ZIndex = 2,
        Parent = clip,
    })
    Util.list(body, 11)
    Util.pad(body, 0, 12, 12, 12)
    self.Body = body

    self.Expanded = opts.Expanded and true or false

    local function resize(animate)
        local target = self.Expanded and body.AbsoluteSize.Y or 0
        if animate == false then
            clip.Size = UDim2.new(1, 0, 0, target)
        else
            Util.tween(clip, { Size = UDim2.new(1, 0, 0, target) }, Util.ease.glide)
        end
    end
    self.resize = resize

    body:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
        if self.Expanded then
            clip.Size = UDim2.new(1, 0, 0, body.AbsoluteSize.Y)
        end
    end)

    header.MouseButton1Click:Connect(function()
        if not self.expandable then
            return
        end
        self:Expand(not self.Expanded)
    end)

    Util.hover(header, self.edge, { Transparency = 0 }, { Transparency = 0.45 })

    self.holdBegan = Util.onInput("began", function(input, typing)
        if typing or self.BindMode ~= "Hold" or not self.Bind then
            return
        end
        if input.KeyCode == self.Bind or input.UserInputType == self.Bind then
            self:Set(true)
        end
    end)

    self.holdEnded = Util.onInput("ended", function(input)
        if self.BindMode ~= "Hold" or not self.Bind then
            return
        end
        if input.KeyCode == self.Bind or input.UserInputType == self.Bind then
            self:Set(false)
        end
    end)

    --[[
        These two are engine-wide handlers, and nothing used to take them back.
        A script that reloads twenty times — which is the whole executor
        workflow — left forty dead cards listening on every key press, each one
        reaching into a destroyed frame.

        Destroying is the right hook rather than an explicit Destroy call: it
        fires however the card dies, including Root:Destroy() on unload.
    ]]
    root.Destroying:Connect(function()
        self.holdBegan()
        self.holdEnded()
        if self.Flag then
            State.release(self.Flag, self)
        end
    end)

    if self.Flag then
        State.register(self.Flag, self)
        State.flags[self.Flag] = self.Enabled
    end

    Theme.watch(function()
        if not root.Parent then
            return false
        end
        self:paint()
    end)

    task.defer(function()
        resize(false)
        self:paint()
        self:refresh()
    end)

    return self
end

-- right-clicking the keybind chip: pick how the key behaves, rebind it, or clear it
function Card:BindMenu(anchor, chip)
    Overlay.toggle({
        Key = anchor,
        Anchor = anchor,
        Width = 186,
        Align = "right",
        Build = function(panel)
            Util.pad(panel, 6)
            Util.list(panel, 2)

            local function row(order, height)
                local button = Overlay.row({ Parent = panel, LayoutOrder = order, Height = height or 32 })
                Util.pad(button, 0, 9, 0, 9)
                return button
            end

            local function label(parent, text, token, size, x)
                return Craft.text({
                    Text = text,
                    Token = token,
                    TextSize = size or 12.5,
                    Position = UDim2.fromOffset(x or 0, 0),
                    Size = UDim2.new(1, -(x or 0), 1, 0),
                    ZIndex = 5,
                    Parent = parent,
                })
            end

            label(
                Craft.frame({
                    BackgroundTransparency = 1,
                    Size = UDim2.new(1, 0, 0, 16),
                    LayoutOrder = 1,
                    ZIndex = 3,
                    Parent = panel,
                }),
                "Key behaviour",
                "textFaint",
                11,
                2
            )

            for i, mode in ipairs({ "Toggle", "Hold" }) do
                local button = row(i + 1, 32)
                local live = self.BindMode == mode

                local cell = Craft.frame({
                    BackgroundTransparency = 1,
                    Size = UDim2.fromOffset(15, 15),
                    Position = UDim2.new(0, 0, 0.5, 0),
                    AnchorPoint = Vector2.new(0, 0.5),
                    ZIndex = 4,
                    Parent = button,
                })
                Icons.draw({
                    Icon = mode == "Toggle" and "power" or "target",
                    Size = 14,
                    Token = live and "accent" or "textFaint",
                    ZIndex = 5,
                    Parent = cell,
                })

                local text = label(button, mode, live and "text" or "textDim", 12.5, 24)
                text.FontFace = live and Theme.font.semi or Theme.font.medium

                if live then
                    local tick = Craft.frame({
                        BackgroundTransparency = 1,
                        Size = UDim2.fromOffset(14, 14),
                        Position = UDim2.new(1, 0, 0.5, 0),
                        AnchorPoint = Vector2.new(1, 0.5),
                        ZIndex = 4,
                        Parent = button,
                    })
                    Icons.draw({ Icon = "check", Size = 13, Token = "accent", ZIndex = 5, Parent = tick })
                end

                button.MouseButton1Click:Connect(function()
                    self.BindMode = mode
                    -- leaving hold mode with the key down would strand the module on
                    if mode == "Toggle" and self.Enabled and self.heldOn then
                        self.heldOn = false
                    end
                    Overlay.close()
                end)
            end

            Craft.divider(panel, 4)

            local rebind = row(5)
            local rebindCell = Craft.frame({
                BackgroundTransparency = 1,
                Size = UDim2.fromOffset(15, 15),
                Position = UDim2.new(0, 0, 0.5, 0),
                AnchorPoint = Vector2.new(0, 0.5),
                ZIndex = 4,
                Parent = rebind,
            })
            Icons.draw({ Icon = "keyboard", Size = 14, Token = "textFaint", ZIndex = 5, Parent = rebindCell })
            label(rebind, "Rebind key", "textDim", 12.5, 24)
            rebind.MouseButton1Click:Connect(function()
                Overlay.close()
                task.defer(chip.Capture, chip)
            end)

            local clear = row(6)
            local clearCell = Craft.frame({
                BackgroundTransparency = 1,
                Size = UDim2.fromOffset(15, 15),
                Position = UDim2.new(0, 0, 0.5, 0),
                AnchorPoint = Vector2.new(0, 0.5),
                ZIndex = 4,
                Parent = clear,
            })
            Icons.draw({ Icon = "close", Size = 13, Token = "danger", ZIndex = 5, Parent = clearCell })
            label(clear, "Clear bind", "danger", 12.5, 24)
            clear.MouseButton1Click:Connect(function()
                chip:Set(nil)
                Overlay.close()
            end)
        end,
    })
end

function Card:paint()
    local glyph = self.Tile:FindFirstChild("Icon")
    if glyph then
        Icons.tint(glyph, self.Enabled and Theme.get("accent") or Theme.get("textFaint"))
    end
    self.Tile.BackgroundColor3 = self.Enabled and Theme.get("accentSoft") or Theme.get("surfaceAlt")
end

function Card:Set(value, fromSwitch)
    self.Enabled = value and true or false
    if not fromSwitch then
        -- the switch only makes noise when clicked, so a keybind toggle speaks here
        self.Switch:Set(self.Enabled, true)
        Audio.play(self.Enabled and "on" or "off")
    end
    if self.Flag then
        State.set(self.Flag, self.Enabled, true)
    end

    local glyph = self.Tile:FindFirstChild("Icon")
    if glyph then
        Icons.tint(glyph, self.Enabled and Theme.get("accent") or Theme.get("textFaint"))
    end
    Util.tween(self.Tile, {
        BackgroundColor3 = self.Enabled and Theme.get("accentSoft") or Theme.get("surfaceAlt"),
    }, Util.ease.snap)

    if self.Callback then
        task.spawn(self.Callback, self.Enabled)
    end
    self.flow:announce(self, self.Enabled)
end

function Card:Expand(open)
    self.Expanded = open and true or false
    self.resize(true)
    Util.tween(self.Caret, { Rotation = self.Expanded and 180 or 0 }, Util.ease.out)
end

-- the chevron is the only hint that a card opens, so it appears the moment the
-- card gains its first control and hides again if it has none
function Card:refresh()
    self.expandable = #self.controls > 0
    self.CaretCell.Visible = self.expandable
    self.Header.AutoButtonColor = false
end

function Card:Match(query)
    if query == "" then
        return true
    end
    return self.terms:find(query, 1, true) ~= nil
end

function Card:Remember(name)
    if name then
        self.terms = self.terms .. " " .. tostring(name):lower()
    end
end

local function order(self)
    self.slot = (self.slot or 0) + 1
    task.defer(function()
        self:refresh()
    end)
    return self.slot
end

function Card:Toggle(opts)
    opts.LayoutOrder = order(self)
    self:Remember(opts.Name)
    local c = Controls.toggle(self.Body, opts)
    table.insert(self.controls, c)
    return c
end

function Card:Slider(opts)
    opts.LayoutOrder = order(self)
    self:Remember(opts.Name)
    local c = Controls.slider(self.Body, opts)
    table.insert(self.controls, c)
    return c
end

function Card:Segmented(opts)
    opts.LayoutOrder = order(self)
    self:Remember(opts.Name)
    local c = Controls.segmented(self.Body, opts)
    table.insert(self.controls, c)
    return c
end

function Card:Icons(opts)
    opts.LayoutOrder = order(self)
    self:Remember(opts.Name)
    local c = Controls.iconpicker(self.Body, opts)
    table.insert(self.controls, c)
    return c
end

function Card:Dropdown(opts)
    opts.LayoutOrder = order(self)
    self:Remember(opts.Name)
    local c = Controls.dropdown(self.Body, opts)
    table.insert(self.controls, c)
    return c
end

function Card:Buttons(opts)
    opts.LayoutOrder = order(self)
    self:Remember(opts.Name)
    local c = Controls.buttons(self.Body, opts)
    table.insert(self.controls, c)
    return c
end

function Card:Button(opts)
    return self:Buttons({ Name = opts.Name, Desc = opts.Desc, Buttons = { opts } })
end

function Card:Color(opts)
    opts.LayoutOrder = order(self)
    self:Remember(opts.Name)
    local c = Controls.color(self.Body, opts)
    table.insert(self.controls, c)
    return c
end

function Card:Input(opts)
    opts.LayoutOrder = order(self)
    self:Remember(opts.Name)
    local c = Controls.input(self.Body, opts)
    table.insert(self.controls, c)
    return c
end

function Card:Keybind(opts)
    opts.LayoutOrder = order(self)
    self:Remember(opts.Name)
    local row = Craft.frame({
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        LayoutOrder = opts.LayoutOrder,
        Parent = self.Body,
    })
    local head = Craft.head({ Name = opts.Name, Desc = opts.Desc, Parent = row })
    head.Size = UDim2.new(1, -70, 0, 0)
    opts.Position = UDim2.new(1, 0, 0, 9)
    opts.AnchorPoint = Vector2.new(1, 0.5)
    local c = Controls.keybind(row, opts)
    table.insert(self.controls, c)
    return c
end

function Card:Label(opts)
    opts.LayoutOrder = order(self)
    return Controls.label(self.Body, opts)
end

function Card:Divider()
    return Controls.divider(self.Body, { LayoutOrder = order(self) })
end

return Card
end

__flowStartupCheckpoint()
__modules["ui/controls"] = function(require)
__flowStartupCheckpoint()
local UserInputService = __service("UserInputService")

local Util = require("core/util")
local Theme = require("core/theme")
local Craft = require("core/craft")
local Icons = require("core/icons")
local State = require("core/state")
local Overlay = require("ui/overlay")
local Audio = require("core/audio")

local Controls = {}

local function shell(parent, opts, free)
    local root = Craft.frame({
        Name = "",
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        LayoutOrder = opts.LayoutOrder or 0,
        ZIndex = 2,
        Parent = parent,
    })
    if not free then
        Util.list(root, opts.Gap or 8)
    end
    return root
end

local function bindFlag(control, opts)
    if opts.Flag then
        State.register(opts.Flag, control)
        State.flags[opts.Flag] = control.Value
    end
end

local function repaint(control, frame)
    Theme.watch(function()
        if not frame.Parent then
            return false
        end
        control:Set(control.Value, true)
    end)
end

local function emit(control, opts, value)
    control.Value = value
    if opts.Flag then
        State.set(opts.Flag, value, true)
    end
    if opts.Callback then
        task.spawn(opts.Callback, value)
    end
end

function Controls.switch(parent, opts)
    opts = opts or {}
    local control = { Value = opts.Default and true or false }
    -- the most-pressed control in the library, so it follows the touch density
    local metric = Theme.chrome.switch
    local width = opts.Width or metric.X
    local height = opts.Height or metric.Y

    local track = Craft.button({
        Name = "Switch",
        Token = "raised",
        Radius = UDim.new(1, 0),
        Size = UDim2.fromOffset(width, height),
        Position = opts.Position,
        AnchorPoint = opts.AnchorPoint,
        LayoutOrder = opts.LayoutOrder,
        ZIndex = opts.ZIndex or 3,
        Parent = parent,
    })

    local glow = Util.stroke(track, Theme.get("accent"), 1, 1)
    Theme.bind(glow, "Color", "accentGlow")

    local knob = Craft.frame({
        Name = "Knob",
        Token = "textFaint",
        Radius = UDim.new(1, 0),
        Size = UDim2.fromOffset(height - 5, height - 5),
        Position = UDim2.new(0, 2, 0.5, 0),
        AnchorPoint = Vector2.new(0, 0.5),
        ZIndex = (opts.ZIndex or 3) + 1,
        Parent = track,
    })

    local span = width - height + 3

    function control:Set(value, silent)
        control.Value = value and true or false
        Util.tween(track, { BackgroundColor3 = control.Value and Theme.get("accent") or Theme.get("raised") })
        Util.tween(knob, {
            Position = UDim2.new(0, control.Value and span or 2, 0.5, 0),
            BackgroundColor3 = control.Value and Theme.get("white") or Theme.get("textFaint"),
        })
        Util.tween(glow, { Transparency = control.Value and 0.55 or 1 })
        if not silent then
            Audio.play(control.Value and "on" or "off")
            emit(control, opts, control.Value)
        end
    end

    track.MouseButton1Click:Connect(function()
        control:Set(not control.Value)
    end)

    control.Frame = track
    control:Set(control.Value, true)
    repaint(control, track)
    bindFlag(control, opts)
    return control
end

function Controls.toggle(parent, opts)
    local control = {}
    local root = shell(parent, opts, true)
    local head = Craft.head({ Name = opts.Name, Desc = opts.Desc, Parent = root })
    -- clear the switch plus a thumb's worth of gap, whatever density is running
    head.Size = UDim2.new(1, -(Theme.chrome.switch.X + 16), 0, 0)

    local switch = Controls.switch(root, {
        Default = opts.Default,
        Position = UDim2.new(1, 0, 0, 10),
        AnchorPoint = Vector2.new(1, 0.5),
        Callback = function(v)
            emit(control, opts, v)
        end,
    })

    control.Value = switch.Value
    control.Frame = root
    control.Head = head

    function control:Set(value, silent)
        switch:Set(value, true)
        control.Value = switch.Value
        if not silent then
            emit(control, opts, control.Value)
        end
    end

    bindFlag(control, opts)
    return control
end

function Controls.slider(parent, opts)
    opts = opts or {}
    local min, max = opts.Min or 0, opts.Max or 100
    local step = opts.Step or ((max - min) <= 3 and 0.05 or 1)
    local control = { Value = Util.clamp(opts.Default or min, min, max) }

    local root = shell(parent, opts)
    if opts.Name then
        Craft.head({ Name = opts.Name, Desc = opts.Desc, Parent = root })
    end

    local lane = Craft.frame({
        Name = "Lane",
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 18),
        LayoutOrder = 2,
        Parent = root,
    })

    local track = Craft.frame({
        Name = "Track",
        Token = "raised",
        Radius = UDim.new(1, 0),
        Size = UDim2.new(1, 0, 0, 7),
        Position = UDim2.fromScale(0, 0.5),
        AnchorPoint = Vector2.new(0, 0.5),
        ZIndex = 2,
        Parent = lane,
    })

    local ticks = Craft.frame({
        Name = "Ticks",
        BackgroundTransparency = 1,
        Size = UDim2.new(1, -14, 1, 0),
        Position = UDim2.fromOffset(7, 0),
        ZIndex = 3,
        Parent = track,
    })
    Util.list(ticks, 0, Enum.FillDirection.Horizontal, Enum.HorizontalAlignment.Center)
    for i = 1, opts.Ticks or 11 do
        local cell = Craft.frame({
            Name = "Cell",
            BackgroundTransparency = 1,
            Size = UDim2.new(1 / (opts.Ticks or 11), 0, 1, 0),
            LayoutOrder = i,
            ZIndex = 3,
            Parent = ticks,
        })
        Craft.frame({
            Name = "Tick",
            Token = "textFaint",
            Radius = UDim.new(1, 0),
            BackgroundTransparency = 0.35,
            Size = UDim2.fromOffset(3, 3),
            Position = UDim2.fromScale(0.5, 0.5),
            AnchorPoint = Vector2.new(0.5, 0.5),
            ZIndex = 3,
            Parent = cell,
        })
    end

    local fill = Craft.frame({
        Name = "Fill",
        Token = "accent",
        Radius = UDim.new(1, 0),
        Size = UDim2.fromScale(0, 1),
        ZIndex = 4,
        Parent = track,
    })

    local knob = Craft.frame({
        Name = "Knob",
        Token = "white",
        Radius = UDim.new(1, 0),
        Size = UDim2.fromOffset(16, 16),
        Position = UDim2.fromScale(0, 0.5),
        AnchorPoint = Vector2.new(0.5, 0.5),
        ZIndex = 6,
        Parent = lane,
    })
    local knobEdge = Util.stroke(knob, Theme.get("accent"), 2, 0)
    Theme.bind(knobEdge, "Color", "accent")

    local readout = Craft.chip({
        Text = "0",
        Token = "raised",
        TextToken = "text",
        Height = 20,
        ZIndex = 7,
        Parent = lane,
    })
    readout.AnchorPoint = Vector2.new(0.5, 0.5)
    readout.Position = UDim2.new(0, 0, 0.5, -23)
    readout.BackgroundTransparency = 1
    local readoutText = readout:FindFirstChild("Value")
    readoutText.TextTransparency = 1

    local function paint(alpha)
        fill.Size = UDim2.fromScale(alpha, 1)
        knob.Position = UDim2.new(alpha, 0, 0.5, 0)
        readout.Position = UDim2.new(alpha, 0, 0.5, -23)
        readoutText.Text = Util.format(control.Value, step) .. (opts.Suffix or "")
    end

    -- one detent per step, pitched up as the value rises, throttled so a long
    -- drag across a 2000-wide range does not machine-gun
    local lastTick = 0
    local function detent()
        local now = os.clock()
        if now - lastTick < 0.035 then
            return
        end
        lastTick = now
        local alpha = (control.Value - min) / math.max(max - min, 1e-6)
        Audio.play("tick", 2.05 + alpha * 0.85)
    end

    local function apply(alpha, silent)
        local raw = min + (max - min) * alpha
        local previous = control.Value
        control.Value = Util.clamp(Util.round(raw, step), min, max)
        paint((control.Value - min) / math.max(max - min, 1e-6))
        if not silent then
            if control.Value ~= previous then
                detent()
            end
            emit(control, opts, control.Value)
        end
    end

    local function reveal(on)
        Util.tween(readout, { BackgroundTransparency = on and 0 or 1 }, Util.ease.snap)
        Util.tween(readoutText, { TextTransparency = on and 0 or 1 }, Util.ease.snap)
        Util.tween(knob, { Size = UDim2.fromOffset(on and 18 or 16, on and 18 or 16) }, Util.ease.snap)
    end

    local hot = false
    lane.MouseEnter:Connect(function()
        hot = true
        reveal(true)
    end)
    lane.MouseLeave:Connect(function()
        hot = false
        task.delay(0.05, function()
            if not hot then
                reveal(false)
            end
        end)
    end)

    Util.slide(lane, function(a)
        apply(a)
        reveal(true)
    end, function()
        if not hot then
            reveal(false)
        end
    end)

    function control:Set(value, silent)
        control.Value = Util.clamp(Util.round(value, step), min, max)
        paint((control.Value - min) / math.max(max - min, 1e-6))
        if not silent then
            emit(control, opts, control.Value)
        end
    end

    control.Frame = root
    apply((control.Value - min) / math.max(max - min, 1e-6), true)
    bindFlag(control, opts)
    return control
end

function Controls.segmented(parent, opts)
    opts = opts or {}
    local list = opts.Options or {}
    local control = { Value = opts.Default or list[1] }

    local root = shell(parent, opts)
    if opts.Name then
        Craft.head({ Name = opts.Name, Desc = opts.Desc, Parent = root })
    end

    local strip = Craft.frame({
        Name = "Strip",
        Token = "surfaceAlt",
        Radius = Theme.radius.control,
        Size = UDim2.new(1, 0, 0, opts.Height or 38),
        LayoutOrder = 2,
        ClipsDescendants = true,
        Parent = root,
    })
    Util.pad(strip, 3)

    local highlight = Craft.frame({
        Name = "Highlight",
        Token = "accent",
        Radius = 6,
        Size = UDim2.new(1 / math.max(#list, 1), -2, 1, 0),
        ZIndex = 2,
        Parent = strip,
    })

    local cells = {}
    for i, name in ipairs(list) do
        local cell = Craft.button({
            Name = "",
            BackgroundTransparency = 1,
            Size = UDim2.new(1 / #list, 0, 1, 0),
            Position = UDim2.fromScale((i - 1) / #list, 0),
            ZIndex = 3,
            Parent = strip,
        })
        local label = Craft.text({
            Text = name,
            Token = "textDim",
            TextSize = 12.5,
            FontFace = Theme.font.semi,
            TextXAlignment = Enum.TextXAlignment.Center,
            ZIndex = 4,
            Parent = cell,
        })
        cells[name] = { cell = cell, label = label, index = i }
        cell.MouseButton1Click:Connect(function()
            control:Set(name)
        end)
    end

    function control:Set(value, silent)
        local hit = cells[value]
        if not hit then
            return
        end
        control.Value = value
        Util.tween(highlight, {
            Position = UDim2.new((hit.index - 1) / #list, 1, 0, 0),
        }, Util.ease.out)
        for _, entry in pairs(cells) do
            Util.tween(entry.label, {
                TextColor3 = entry.index == hit.index and Theme.get("white") or Theme.get("textDim"),
            }, Util.ease.snap)
        end
        if not silent then
            Audio.play("select")
            emit(control, opts, value)
        end
    end

    control.Frame = root
    control:Set(control.Value, true)
    repaint(control, root)
    bindFlag(control, opts)
    return control
end

-- a row of round icon buttons; the live one carries an accent ring
function Controls.iconpicker(parent, opts)
    opts = opts or {}

    local list = {}
    for i, entry in ipairs(opts.Options or {}) do
        if typeof(entry) == "string" then
            list[i] = { Icon = entry, Value = entry }
        else
            list[i] = { Icon = entry.Icon, Value = entry.Value or entry.Icon, Name = entry.Name }
        end
    end

    local control = { Value = opts.Default or (list[1] and list[1].Value) }

    local root = shell(parent, opts)
    if opts.Name then
        Craft.head({ Name = opts.Name, Desc = opts.Desc, Parent = root })
    end

    local size = opts.Size or 38
    local row = Craft.frame({
        Name = "Row",
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, size),
        LayoutOrder = 2,
        Parent = root,
    })
    Util.list(row, opts.Gap or 8, Enum.FillDirection.Horizontal)

    local cells = {}
    for i, entry in ipairs(list) do
        local button = Craft.button({
            Name = "",
            Token = "surfaceAlt",
            Radius = UDim.new(1, 0),
            Size = UDim2.fromOffset(size, size),
            LayoutOrder = i,
            ZIndex = 3,
            Parent = row,
        })
        local ring = Util.stroke(button, Theme.get("accent"), 1.5, 1)
        Theme.bind(ring, "Color", "accent")
        local glyph = Icons.draw({
            Icon = entry.Icon,
            Size = math.floor(size * 0.48),
            Color = Theme.get("textFaint"),
            ZIndex = 4,
            Parent = button,
        })

        cells[i] = { button = button, ring = ring, glyph = glyph, value = entry.Value }
        button.MouseButton1Click:Connect(function()
            control:Set(entry.Value)
        end)
    end

    function control:Set(value, silent)
        control.Value = value
        for _, cell in ipairs(cells) do
            local live = cell.value == value
            Util.tween(cell.ring, { Transparency = live and 0.1 or 1 }, Util.ease.snap)
            Util.tween(cell.button, {
                BackgroundColor3 = live and Theme.get("accentSoft") or Theme.get("surfaceAlt"),
            }, Util.ease.snap)
            Icons.tint(cell.glyph, live and Theme.get("accent") or Theme.get("textFaint"))
        end
        if not silent then
            Audio.play("select")
            emit(control, opts, value)
        end
    end

    control.Frame = root
    control:Set(control.Value, true)
    repaint(control, root)
    bindFlag(control, opts)
    return control
end

-- `options` is the list the caller declared. Reading the selection back in that
-- order keeps the caption agreeing with the rows in the open panel; sorting it
-- alphabetically instead turned { Players, NPCs } into "NPCs, Players" and threw
-- away the priority the caller chose.
local function joinValues(value, empty, options, limit)
    if typeof(value) == "table" then
        local picked = {}
        if type(options) == "table" and #options > 0 then
            for _, option in ipairs(options) do
                if value[option] == true then
                    table.insert(picked, option)
                end
            end
            -- a flag can carry a value that is no longer in Options; still show it
            for k, v in pairs(value) do
                if v == true and not table.find(picked, k) then
                    table.insert(picked, k)
                end
            end
        else
            for k, v in pairs(value) do
                if v == true then
                    table.insert(picked, k)
                end
            end
            table.sort(picked)
        end

        if #picked == 0 then
            return empty or "None"
        end

        -- past a few names the row truncates mid-word, which reads as a glitch;
        -- a count is shorter and says how much is hidden
        limit = limit or 3
        if #picked > limit then
            local head = table.move(picked, 1, limit, 1, {})
            return table.concat(head, ", ") .. " +" .. (#picked - limit)
        end
        return table.concat(picked, ", ")
    end
    return value ~= nil and tostring(value) or (empty or "None")
end

function Controls.dropdown(parent, opts)
    opts = opts or {}
    local list = opts.Options or {}
    local multi = opts.Multi and true or false
    local control = { Value = opts.Default or (multi and {} or list[1]) }

    local root = shell(parent, opts)
    if opts.Name then
        Craft.head({ Name = opts.Name, Desc = opts.Desc, Parent = root })
    end

    local field = Craft.button({
        Name = "Field",
        Token = "surfaceAlt",
        Radius = Theme.radius.control,
        Edge = "lineSoft",
        Size = UDim2.new(1, 0, 0, opts.Height or 38),
        LayoutOrder = 2,
        Parent = root,
    })
    Util.pad(field, 0, 12, 0, 13)

    local caption = Craft.text({
        Name = "Caption",
        Text = joinValues(control.Value, opts.Empty, list, opts.MaxTags),
        Token = "text",
        TextSize = 13,
        TextTruncate = Enum.TextTruncate.AtEnd,
        Size = UDim2.new(1, -20, 1, 0),
        Parent = field,
    })

    local arrow = Icons.draw({
        Icon = "chevron-down",
        Size = 14,
        Token = "textFaint",
        Position = UDim2.new(1, 0, 0.5, 0),
        AnchorPoint = Vector2.new(1, 0.5),
        Parent = field,
    })

    Util.hover(field, field, { BackgroundColor3 = Theme.get("surfaceAlt") }, { BackgroundColor3 = Theme.get("raised") })

    local function refresh()
        caption.Text = joinValues(control.Value, opts.Empty, list, opts.MaxTags)
    end

    local function build(panel)
        Util.pad(panel, 6)
        local scroller = Craft.scroll({
            Size = UDim2.new(1, 0, 0, math.min(#list * 36, opts.MaxHeight or 252)),
            Parent = panel,
        })
        Util.list(scroller, 2)

        for i, name in ipairs(list) do
            local row = Overlay.row({ Parent = scroller, LayoutOrder = i, Height = 34 })
            Util.pad(row, 0, 9, 0, 11)

            local label = Craft.text({
                Text = name,
                Token = "textDim",
                TextSize = 13,
                Size = UDim2.new(1, -24, 1, 0),
                ZIndex = 4,
                Parent = row,
            })

            local mark = Icons.draw({
                Icon = multi and "check" or "check",
                Size = 12,
                Token = "accent",
                Position = UDim2.new(1, 0, 0.5, 0),
                AnchorPoint = Vector2.new(1, 0.5),
                ZIndex = 4,
                Parent = row,
            })

            local function sync()
                local on
                if multi then
                    on = control.Value[name] == true
                else
                    on = control.Value == name
                end
                mark.Visible = on
                label.TextColor3 = on and Theme.get("text") or Theme.get("textDim")
                label.FontFace = on and Theme.font.semi or Theme.font.medium
            end

            sync()
            row.MouseButton1Click:Connect(function()
                if multi then
                    local copy = {}
                    for k, v in pairs(control.Value) do
                        copy[k] = v
                    end
                    copy[name] = not copy[name] or nil
                    control:Set(copy)
                    for _, sibling in ipairs(scroller:GetChildren()) do
                        if sibling:IsA("TextButton") then
                            local other = sibling:FindFirstChildWhichIsA("TextLabel")
                            local tick = sibling:FindFirstChild("Icon")
                            if other and tick then
                                local on = control.Value[other.Text] == true
                                tick.Visible = on
                                other.TextColor3 = on and Theme.get("text") or Theme.get("textDim")
                            end
                        end
                    end
                else
                    control:Set(name)
                    Overlay.close()
                end
            end)
        end
    end

    field.MouseButton1Click:Connect(function()
        Overlay.toggle({
            Key = field,
            Anchor = field,
            Width = field.AbsoluteSize.X,
            Build = build,
            OnClose = function()
                Util.tween(arrow, { Rotation = 0 }, Util.ease.snap)
            end,
        })
        Audio.play(Overlay.isOpen(field) and "open" or "close")
        Util.tween(arrow, { Rotation = Overlay.isOpen(field) and 180 or 0 }, Util.ease.snap)
    end)

    function control:Set(value, silent)
        control.Value = value
        refresh()
        if not silent then
            emit(control, opts, value)
        end
    end

    function control:Options(newList)
        list = newList
        if not multi and not table.find(list, control.Value) then
            control:Set(list[1])
        else
            refresh()
        end
    end

    control.Frame = root
    bindFlag(control, opts)
    return control
end

function Controls.buttons(parent, opts)
    opts = opts or {}
    local defs = opts.Buttons or {}
    local root = shell(parent, opts)
    if opts.Name then
        Craft.head({ Name = opts.Name, Desc = opts.Desc, Parent = root })
    end

    local row = Craft.frame({
        Name = "Row",
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, opts.Height or 36),
        LayoutOrder = 2,
        Parent = root,
    })
    local gap = 6
    Util.list(row, gap, Enum.FillDirection.Horizontal)

    -- an optional round accent button pinned to the end of the row
    local trail = opts.Trailing
    local trailSize = trail and (opts.Height or 32) or 0
    local reserve = trail and (trailSize + gap) or 0

    local made = {}
    for i, def in ipairs(defs) do
        local n = #defs
        local button = Craft.button({
            Name = def.Name or "Button",
            Token = def.Accent and "accent" or "surfaceAlt",
            Radius = Theme.radius.control,
            Size = UDim2.new(1 / n, -(gap * (n - 1) + reserve) / n, 1, 0),
            LayoutOrder = i,
            Parent = row,
        })

        local inner = Craft.frame({
            BackgroundTransparency = 1,
            Size = UDim2.fromScale(1, 1),
            Parent = button,
        })
        Util.list(
            inner,
            6,
            Enum.FillDirection.Horizontal,
            Enum.HorizontalAlignment.Center,
            Enum.VerticalAlignment.Center
        )

        if def.Icon then
            local holder = Craft.frame({
                BackgroundTransparency = 1,
                Size = UDim2.fromOffset(15, 15),
                LayoutOrder = 1,
                Parent = inner,
            })
            Icons.draw({
                Icon = def.Icon,
                Size = 15,
                Token = def.Accent and "white" or "textFaint",
                Parent = holder,
            })
        end

        Craft.text({
            Text = def.Name or "",
            Token = def.Accent and "white" or "textDim",
            TextSize = 12.5,
            FontFace = Theme.font.semi,
            AutomaticSize = Enum.AutomaticSize.X,
            Size = UDim2.new(0, 0, 1, 0),
            TextXAlignment = Enum.TextXAlignment.Center,
            LayoutOrder = 2,
            Parent = inner,
        })

        if not def.Accent then
            Util.hover(button, button, { BackgroundColor3 = Theme.get("surfaceAlt") }, { BackgroundColor3 = Theme.get("raised") })
        end

        button.MouseButton1Click:Connect(function()
            Util.tween(button, { BackgroundColor3 = Theme.get("raisedHi") }, Util.ease.snap)
            task.delay(0.1, function()
                Util.tween(button, {
                    BackgroundColor3 = def.Accent and Theme.get("accent") or Theme.get("surfaceAlt"),
                }, Util.ease.snap)
            end)
            Audio.play("click")
            if def.Callback then
                task.spawn(def.Callback)
            end
        end)

        table.insert(made, button)
    end

    if trail then
        local knob = Craft.button({
            Name = "Trailing",
            Token = trail.Accent == false and "surfaceAlt" or "accent",
            Radius = UDim.new(1, 0),
            Size = UDim2.fromOffset(trailSize, trailSize),
            LayoutOrder = #defs + 1,
            Parent = row,
        })
        Icons.draw({
            Icon = trail.Icon or "plus",
            Size = math.floor(trailSize * 0.42),
            Color = trail.Accent == false and Theme.get("textFaint") or Theme.get("white"),
            Parent = knob,
        })
        knob.MouseButton1Click:Connect(function()
            if trail.Callback then
                task.spawn(trail.Callback)
            end
        end)
        made.Trailing = knob
    end

    return { Frame = root, Buttons = made }
end

function Controls.input(parent, opts)
    opts = opts or {}
    local control = { Value = opts.Default or "" }
    local root = shell(parent, opts)
    if opts.Name then
        Craft.head({ Name = opts.Name, Desc = opts.Desc, Parent = root })
    end

    local field = Craft.frame({
        Name = "Field",
        Token = "surfaceAlt",
        Radius = Theme.radius.control,
        Edge = "lineSoft",
        Size = UDim2.new(1, 0, 0, opts.Height or 34),
        LayoutOrder = 2,
        ClipsDescendants = true,
        Parent = root,
    })
    Util.pad(field, 0, 11, 0, 11)

    local box = Util.new("TextBox", {
        BackgroundTransparency = 1,
        Size = UDim2.fromScale(1, 1),
        Text = control.Value,
        PlaceholderText = opts.Placeholder or "",
        FontFace = Theme.font.medium,
        TextSize = 13,
        TextXAlignment = Enum.TextXAlignment.Left,
        ClearTextOnFocus = false,
        ZIndex = 3,
        Parent = field,
    })
    Theme.bind(box, "TextColor3", "text")
    Theme.bind(box, "PlaceholderColor3", "textFaint")

    local edge = field:FindFirstChildWhichIsA("UIStroke")
    box.Focused:Connect(function()
        Util.tween(edge, { Color = Theme.get("accent"), Transparency = 0.2 }, Util.ease.snap)
    end)
    box.FocusLost:Connect(function(enter)
        Util.tween(edge, { Color = Theme.get("lineSoft"), Transparency = 0 }, Util.ease.snap)
        control.Value = box.Text
        if opts.Flag then
            State.flags[opts.Flag] = box.Text
        end
        if opts.Callback and (enter or not opts.OnEnter) then
            task.spawn(opts.Callback, box.Text, enter)
        end
    end)

    function control:Set(value, silent)
        control.Value = tostring(value or "")
        box.Text = control.Value
        if not silent then
            emit(control, opts, control.Value)
        end
    end

    control.Frame = root
    control.Box = box
    bindFlag(control, opts)
    return control
end

function Controls.keybind(parent, opts)
    opts = opts or {}
    local control = { Value = opts.Default }
    local capturing = false

    --[[
        Drawn as a key cap rather than a text pill: a hairline edge so it reads
        as a physical key against the card, and padding that widens for a single
        character so "B" is a square cap instead of a sliver next to "MB3".

        The padding is what sets the width, not a UISizeConstraint. A minimum
        width leaves the label parked against the left inset with the whole
        remainder banked up on the right, which is exactly the lopsided cap this
        replaces.
    ]]
    local holder = Craft.button({
        Name = "Keybind",
        Token = "raised",
        Radius = Theme.radius.tile,
        Edge = "line",
        Size = UDim2.fromOffset(0, opts.Height or 22),
        AutomaticSize = Enum.AutomaticSize.X,
        Position = opts.Position,
        AnchorPoint = opts.AnchorPoint,
        LayoutOrder = opts.LayoutOrder,
        ZIndex = opts.ZIndex or 3,
        Parent = parent,
    })
    local inset = Util.pad(holder, 0, 8, 0, 8)

    local label = Craft.text({
        Name = "Value",
        Text = Util.keyName(control.Value),
        Token = "textDim",
        TextSize = 11.5,
        FontFace = Theme.font.semi,
        AutomaticSize = Enum.AutomaticSize.X,
        Size = UDim2.new(0, 0, 1, 0),
        TextXAlignment = Enum.TextXAlignment.Center,
        ZIndex = (opts.ZIndex or 3) + 2,
        Parent = holder,
    })

    Util.hover(holder, holder, { BackgroundColor3 = Theme.get("raised") }, { BackgroundColor3 = Theme.get("raisedHi") })

    function control:Set(key, silent)
        control.Value = key
        label.Text = Util.keyName(key)
        label.TextColor3 = key and Theme.get("text") or Theme.get("textFaint")

        -- a lone letter gets a wider inset on both sides, so the cap is square
        -- rather than a sliver, and the glyph stays centred either way
        local wide = utf8.len(label.Text) == 1 and 11 or 8
        inset.PaddingLeft = UDim.new(0, wide)
        inset.PaddingRight = UDim.new(0, wide)

        -- an unbound chip carried the same fill as a bound one, so a row of them
        -- read as "MB3, V, None, B" all at equal weight; empty ones now recede
        holder.BackgroundTransparency = key and 0 or 0.6
        local edge = holder:FindFirstChildOfClass("UIStroke")
        if edge then
            edge.Transparency = key and 0 or 0.65
        end
        if not silent then
            emit(control, opts, key)
        end
    end

    function control:Capture()
        if capturing then
            return
        end
        capturing = true
        label.Text = "..."
        label.TextColor3 = Theme.get("accent")
        -- waiting for a key is an active state even from an empty chip
        holder.BackgroundTransparency = 0
        local edge = holder:FindFirstChildOfClass("UIStroke")
        if edge then
            edge.Transparency = 0
        end
    end

    holder.MouseButton1Click:Connect(function()
        control:Capture()
    end)

    -- right click clears the bind unless the caller wants its own menu there
    holder.MouseButton2Click:Connect(function()
        local wasCapturing = capturing
        capturing = false
        if opts.OnRightClick then
            -- the chip is left mid-capture otherwise: still reading "..." with no
            -- listener behind it, since the menu takes over from here
            if wasCapturing then
                control:Set(control.Value, true)
            end
            opts.OnRightClick(holder, control)
        else
            control:Set(nil)
        end
    end)

    control.Listener = Util.onInput("began", function(input, typing)
        if typing then
            return
        end
        if capturing then
            if input.UserInputType == Enum.UserInputType.Keyboard then
                capturing = false
                control:Set(input.KeyCode ~= Enum.KeyCode.Escape and input.KeyCode or nil)
            elseif input.UserInputType == Enum.UserInputType.MouseButton3 then
                capturing = false
                control:Set(Enum.UserInputType.MouseButton3)
            end
            return
        end
        if not control.Value or not opts.OnPress then
            return
        end
        if input.KeyCode == control.Value or input.UserInputType == control.Value then
            opts.OnPress()
        end
    end)

    holder.Destroying:Connect(function()
        control.Listener()
    end)

    control.Frame = holder
    control:Set(control.Value, true)
    repaint(control, holder)
    bindFlag(control, opts)
    return control
end

local function hsvFrom(color)
    local h, s, v = Color3.toHSV(color)
    return h, s, v
end

function Controls.color(parent, opts)
    opts = opts or {}
    local control = { Value = opts.Default or Theme.get("accent") }
    local presets = opts.Presets
        or {
            Color3.fromRGB(124, 92, 255),
            Color3.fromRGB(92, 150, 255),
            Color3.fromRGB(70, 205, 190),
            Color3.fromRGB(80, 205, 137),
            Color3.fromRGB(240, 178, 78),
            Color3.fromRGB(238, 92, 100),
        }

    local root = shell(parent, opts)
    if opts.Name then
        Craft.head({ Name = opts.Name, Desc = opts.Desc, Parent = root })
    end

    local row = Craft.frame({
        Name = "Swatches",
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 21),
        LayoutOrder = 2,
        Parent = root,
    })
    Util.list(row, 9, Enum.FillDirection.Horizontal)

    local custom = Craft.button({
        Name = "Custom",
        Token = "white",
        Radius = UDim.new(1, 0),
        Size = UDim2.fromOffset(21, 21),
        LayoutOrder = 0,
        Parent = row,
    })
    Craft.gradient(
        custom,
        Color3.fromRGB(255, 90, 90),
        Color3.fromRGB(120, 90, 255),
        0
    ).Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 84, 84)),
        ColorSequenceKeypoint.new(0.2, Color3.fromRGB(255, 205, 76)),
        ColorSequenceKeypoint.new(0.4, Color3.fromRGB(88, 226, 124)),
        ColorSequenceKeypoint.new(0.6, Color3.fromRGB(76, 214, 226)),
        ColorSequenceKeypoint.new(0.8, Color3.fromRGB(124, 92, 255)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 92, 214)),
    })

    local dots = {}
    for i, preset in ipairs(presets) do
        local dot = Craft.button({
            Name = "Swatch",
            Radius = UDim.new(1, 0),
            BackgroundColor3 = preset,
            BackgroundTransparency = 0,
            Size = UDim2.fromOffset(17, 17),
            LayoutOrder = i,
            Parent = row,
        })
        local ring = Util.stroke(dot, Theme.get("white"), 2, 1)
        dots[i] = { dot = dot, ring = ring, color = preset }
        dot.MouseButton1Click:Connect(function()
            control:Set(preset)
        end)
    end

    local function markSelection()
        for _, entry in ipairs(dots) do
            local same = math.abs(entry.color.R - control.Value.R) < 0.01
                and math.abs(entry.color.G - control.Value.G) < 0.01
                and math.abs(entry.color.B - control.Value.B) < 0.01
            Util.tween(entry.ring, { Transparency = same and 0.15 or 1 }, Util.ease.snap)
            Util.tween(entry.dot, { Size = UDim2.fromOffset(same and 19 or 17, same and 19 or 17) }, Util.ease.snap)
        end
        Util.tween(custom, { Size = UDim2.fromOffset(21, 21) }, Util.ease.snap)
    end

    local function picker(panel)
        Util.pad(panel, 10)
        Util.list(panel, 9)

        local h, s, v = hsvFrom(control.Value)

        local field = Craft.frame({
            Name = "Field",
            BackgroundColor3 = Color3.fromHSV(h, 1, 1),
            Radius = 8,
            Size = UDim2.new(1, 0, 0, 132),
            LayoutOrder = 1,
            ZIndex = 3,
            Parent = panel,
        })

        local sat = Craft.frame({
            BackgroundColor3 = Color3.fromRGB(255, 255, 255),
            Radius = 8,
            Size = UDim2.fromScale(1, 1),
            ZIndex = 4,
            Parent = field,
        })
        Util.new("UIGradient", {
            Color = ColorSequence.new(Color3.fromRGB(255, 255, 255)),
            Transparency = NumberSequence.new({
                NumberSequenceKeypoint.new(0, 0),
                NumberSequenceKeypoint.new(1, 1),
            }),
            Parent = sat,
        })

        local val = Craft.frame({
            BackgroundColor3 = Color3.fromRGB(0, 0, 0),
            Radius = 8,
            Size = UDim2.fromScale(1, 1),
            ZIndex = 5,
            Parent = field,
        })
        Util.new("UIGradient", {
            Color = ColorSequence.new(Color3.fromRGB(0, 0, 0)),
            Rotation = 90,
            Transparency = NumberSequence.new({
                NumberSequenceKeypoint.new(0, 1),
                NumberSequenceKeypoint.new(1, 0),
            }),
            Parent = val,
        })

        local cursor = Craft.frame({
            BackgroundTransparency = 1,
            Size = UDim2.fromOffset(12, 12),
            AnchorPoint = Vector2.new(0.5, 0.5),
            Radius = UDim.new(1, 0),
            ZIndex = 7,
            Parent = field,
        })
        Util.stroke(cursor, Color3.fromRGB(255, 255, 255), 2, 0)

        local hueBar = Craft.frame({
            Radius = UDim.new(1, 0),
            Size = UDim2.new(1, 0, 0, 10),
            BackgroundColor3 = Color3.fromRGB(255, 255, 255),
            LayoutOrder = 2,
            ZIndex = 3,
            Parent = panel,
        })
        Util.new("UIGradient", {
            Color = ColorSequence.new({
                ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 0, 0)),
                ColorSequenceKeypoint.new(0.17, Color3.fromRGB(255, 255, 0)),
                ColorSequenceKeypoint.new(0.33, Color3.fromRGB(0, 255, 0)),
                ColorSequenceKeypoint.new(0.5, Color3.fromRGB(0, 255, 255)),
                ColorSequenceKeypoint.new(0.67, Color3.fromRGB(0, 0, 255)),
                ColorSequenceKeypoint.new(0.83, Color3.fromRGB(255, 0, 255)),
                ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 0, 0)),
            }),
            Parent = hueBar,
        })

        local hueKnob = Craft.frame({
            Token = "white",
            Radius = UDim.new(1, 0),
            Size = UDim2.fromOffset(14, 14),
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.new(h, 0, 0.5, 0),
            ZIndex = 5,
            Parent = hueBar,
        })
        Util.stroke(hueKnob, Theme.get("line"), 2, 0.4)

        local footer = Craft.frame({
            BackgroundTransparency = 1,
            Size = UDim2.new(1, 0, 0, 30),
            LayoutOrder = 3,
            ZIndex = 3,
            Parent = panel,
        })

        local preview = Craft.frame({
            BackgroundColor3 = control.Value,
            Radius = 7,
            Size = UDim2.fromOffset(30, 30),
            ZIndex = 4,
            Parent = footer,
        })

        local hexBox = Craft.frame({
            Token = "surfaceAlt",
            Radius = 7,
            Size = UDim2.new(1, -38, 1, 0),
            Position = UDim2.fromOffset(38, 0),
            ZIndex = 4,
            Parent = footer,
        })
        Util.pad(hexBox, 0, 9, 0, 9)
        local hex = Util.new("TextBox", {
            BackgroundTransparency = 1,
            Size = UDim2.fromScale(1, 1),
            FontFace = Theme.font.semi,
            TextSize = 12,
            TextXAlignment = Enum.TextXAlignment.Left,
            ClearTextOnFocus = false,
            Text = "#" .. control.Value:ToHex():upper(),
            ZIndex = 5,
            Parent = hexBox,
        })
        Theme.bind(hex, "TextColor3", "text")

        local function push(silent)
            local color = Color3.fromHSV(h, s, v)
            field.BackgroundColor3 = Color3.fromHSV(h, 1, 1)
            cursor.Position = UDim2.fromScale(s, 1 - v)
            hueKnob.Position = UDim2.new(h, 0, 0.5, 0)
            preview.BackgroundColor3 = color
            hex.Text = "#" .. color:ToHex():upper()
            control:Set(color, silent)
        end

        push(true)

        field.InputChanged:Connect(function(input)
            if input.UserInputType ~= Enum.UserInputType.MouseMovement then
                return
            end
            if not UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) then
                return
            end
            s = Util.clamp((input.Position.X - field.AbsolutePosition.X) / math.max(field.AbsoluteSize.X, 1), 0, 1)
            v = 1 - Util.clamp((input.Position.Y - field.AbsolutePosition.Y) / math.max(field.AbsoluteSize.Y, 1), 0, 1)
            push()
        end)

        field.InputBegan:Connect(function(input)
            if input.UserInputType ~= Enum.UserInputType.MouseButton1 then
                return
            end
            s = Util.clamp((input.Position.X - field.AbsolutePosition.X) / math.max(field.AbsoluteSize.X, 1), 0, 1)
            v = 1 - Util.clamp((input.Position.Y - field.AbsolutePosition.Y) / math.max(field.AbsoluteSize.Y, 1), 0, 1)
            push()
        end)

        Util.slide(hueBar, function(a)
            h = a
            push()
        end)

        hex.FocusLost:Connect(function()
            local ok, color = pcall(Color3.fromHex, (hex.Text:gsub("#", "")))
            if ok and color then
                h, s, v = hsvFrom(color)
                push()
            else
                hex.Text = "#" .. control.Value:ToHex():upper()
            end
        end)
    end

    custom.MouseButton1Click:Connect(function()
        Overlay.toggle({ Key = custom, Anchor = custom, Width = 224, Build = picker, Align = "left" })
    end)

    function control:Set(value, silent)
        if typeof(value) ~= "Color3" then
            return
        end
        control.Value = value
        markSelection()
        if not silent then
            emit(control, opts, value)
        end
    end

    control.Frame = root
    markSelection()
    Theme.watch(function()
        if not root.Parent then
            return false
        end
        markSelection()
    end)
    bindFlag(control, opts)
    return control
end

function Controls.label(parent, opts)
    local root = shell(parent, opts)
    Craft.head({ Name = opts.Name, Desc = opts.Desc, Parent = root })
    return { Frame = root }
end

function Controls.divider(parent, opts)
    local root = Craft.frame({
        Name = "Divider",
        Token = "lineSoft",
        Size = UDim2.new(1, 0, 0, 1),
        LayoutOrder = (opts and opts.LayoutOrder) or 0,
        Parent = parent,
    })
    return { Frame = root }
end

return Controls
end

__flowStartupCheckpoint()
__modules["ui/overlay"] = function(require)
__flowStartupCheckpoint()
local Util = require("core/util")
local Theme = require("core/theme")
local Craft = require("core/craft")

local Overlay = {}

local layer
local live

function Overlay.attach(target)
    layer = target
end

function Overlay.close(instant)
    if not live then
        return
    end
    local dying = live
    live = nil
    if dying.onClose then
        task.spawn(dying.onClose)
    end
    if instant then
        dying.scrim:Destroy()
        return
    end
    Util.tween(dying.panel, { GroupTransparency = 1 }, Util.ease.snap)
    Util.tween(dying.scale, { Scale = 0.97 }, Util.ease.snap)
    task.delay(0.14, function()
        if dying.scrim.Parent then
            dying.scrim:Destroy()
        end
    end)
end

function Overlay.isOpen(key)
    return live ~= nil and (key == nil or live.key == key)
end

function Overlay.toggle(opts)
    if live and opts.Key and live.key == opts.Key then
        Overlay.close()
        return nil
    end
    return Overlay.open(opts)
end

function Overlay.open(opts)
    Overlay.close(true)

    local anchor = opts.Anchor
    local width = opts.Width or (anchor and anchor.AbsoluteSize.X) or 200
    local gap = opts.Gap or 6

    local scrim = Craft.button({
        Name = "Scrim",
        BackgroundTransparency = 1,
        Size = UDim2.fromScale(1, 1),
        ZIndex = 1,
        Parent = layer,
    })

    local panel = Util.new("CanvasGroup", {
        Name = "Popup",
        BackgroundColor3 = Theme.get("surface"),
        BorderSizePixel = 0,
        GroupTransparency = 1,
        Size = UDim2.fromOffset(width, opts.Height or 0),
        AutomaticSize = opts.Height and Enum.AutomaticSize.None or Enum.AutomaticSize.Y,
        ZIndex = 2,
        Parent = scrim,
    })
    Theme.bind(panel, "BackgroundColor3", "surface")
    Util.corner(panel, opts.Radius or 10)
    local edge = Util.stroke(panel, Theme.get("line"), 1, 0.25)
    Theme.bind(edge, "Color", "line")

    local scale = Util.new("UIScale", { Scale = 0.97, Parent = panel })

    if opts.Build then
        opts.Build(panel)
    end

    local function place()
        if not anchor or not anchor.Parent then
            panel.Position = opts.Position or UDim2.fromScale(0.5, 0.5)
            panel.AnchorPoint = Vector2.new(0.5, 0.5)
            return
        end
        local origin = layer.AbsolutePosition
        local a = anchor.AbsolutePosition - origin
        local s = anchor.AbsoluteSize
        local h = panel.AbsoluteSize.Y
        local x = a.X
        if opts.Align == "right" then
            x = a.X + s.X - width
        elseif opts.Align == "center" then
            x = a.X + s.X * 0.5 - width * 0.5
        end
        x = Util.clamp(x, 8, math.max(layer.AbsoluteSize.X - width - 8, 8))

        local y = a.Y + s.Y + gap
        if y + h > layer.AbsoluteSize.Y - 8 then
            local up = a.Y - h - gap
            if up > 8 then
                y = up
            else
                y = math.max(layer.AbsoluteSize.Y - h - 8, 8)
            end
        end
        panel.Position = UDim2.fromOffset(math.floor(x), math.floor(y))
    end

    place()
    local resize = panel:GetPropertyChangedSignal("AbsoluteSize"):Connect(place)

    live = { scrim = scrim, panel = panel, scale = scale, key = opts.Key, onClose = opts.OnClose }

    scrim.MouseButton1Click:Connect(function()
        Overlay.close()
    end)

    -- escape dismisses whatever is open, the way a desktop menu would
    local escape = Util.onInput("began", function(input, typing)
        if not typing and input.KeyCode == Enum.KeyCode.Escape then
            Overlay.close()
        end
    end)

    scrim.Destroying:Connect(function()
        resize:Disconnect()
        escape()
    end)

    task.defer(function()
        place()
        Util.tween(panel, { GroupTransparency = 0 }, Util.ease.out)
        Util.tween(scale, { Scale = 1 }, Util.ease.out)
    end)

    return panel
end

function Overlay.row(props)
    local row = Craft.button({
        Name = "Row",
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, props.Height or 32),
        LayoutOrder = props.LayoutOrder or 0,
        ZIndex = 3,
        Parent = props.Parent,
    })
    Util.corner(row, 7)
    Util.hover(row, row, { BackgroundTransparency = 1 }, { BackgroundTransparency = 0 })
    Theme.bind(row, "BackgroundColor3", "raised")
    return row
end

return Overlay
end

__flowStartupCheckpoint()
__modules["ui/tab"] = function(require)
__flowStartupCheckpoint()
local Util = require("core/util")
local Theme = require("core/theme")
local Craft = require("core/craft")
local Icons = require("core/icons")
local Card = require("ui/card")
local Audio = require("core/audio")

local Tab = {}
Tab.__index = Tab

function Tab.new(window, opts)
    local self = setmetatable({}, Tab)
    self.flow = window.flow
    self.window = window
    self.Name = opts.Name or "Tab"
    self.Icon = opts.Icon or "cube"
    self.cards = {}
    self.slot = 0

    local page = Util.new("CanvasGroup", {
        Name = "",
        BackgroundTransparency = 1,
        Size = UDim2.fromScale(1, 1),
        GroupTransparency = 1,
        Visible = false,
        Parent = window.Body,
    })
    self.Page = page

    local scroller = Craft.scroll({
        Name = "Scroller",
        Size = UDim2.fromScale(1, 1),
        Parent = page,
    })
    -- Theme.gutter, not a local guess: the header, the tab strip and these lanes
    -- all start at the same x, so the left edge of a card lines up with the logo
    -- and the first tab. They used to sit at 16, 18 and 18.
    local padLeft, padRight = Theme.gutter, Theme.gutter
    local padTop, padBottom = 12, 14
    Util.pad(scroller, padTop, padRight, padBottom, padLeft)
    self.Scroller = scroller
    -- what the page costs on top of the lanes themselves, so Window:Resize can
    -- turn a lane height into a window height
    self.pageInset = padTop + padBottom

    local gap = Theme.chrome.gap

    local lanes = Craft.frame({
        Name = "Lanes",
        BackgroundTransparency = 1,
        Size = UDim2.new(1, -(padLeft + padRight), 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        Parent = scroller,
    })
    Util.list(lanes, gap, Enum.FillDirection.Horizontal)
    self.Lanes = lanes
    self.gap = gap

    local count = window.columns
    self.columns = {}
    for i = 1, count do
        local lane = Craft.frame({
            Name = "Lane" .. i,
            BackgroundTransparency = 1,
            Size = UDim2.new(1 / count, -gap * (count - 1) / count, 0, 0),
            AutomaticSize = Enum.AutomaticSize.Y,
            LayoutOrder = i,
            Parent = lanes,
        })
        Util.list(lane, gap)
        self.columns[i] = lane
    end
    self.active = count
    self.spread = count

    -- cards expanding, a filter hiding half of them, a lane rebalance: all of it
    -- lands here as a lane height change, and the window follows it
    -- no tween: a card expanding is already animating its own height, so setting
    -- the window directly makes the frame grow in lockstep with the card instead
    -- of chasing it a beat behind
    lanes:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
        if window.active == self then
            window:Resize(false)
        end
    end)

    -- Tabs are laid out as: [divider] [tab] [divider] [tab] ... so each one owns a
    -- padded footprint with a hairline between neighbours. Explicit LayoutOrder
    -- keeps that interleaving stable.
    local slot = (#window.tabs + 1) * 10

    if #window.tabs > 0 then
        Craft.frame({
            Name = "Split",
            Token = "line",
            Size = UDim2.fromOffset(1, 14),
            BackgroundTransparency = 0.55,
            LayoutOrder = slot - 5,
            ZIndex = 3,
            Parent = window.Strip,
        })
    end

    local button = Craft.button({
        Name = "",
        Token = "surfaceAlt",
        BackgroundTransparency = 1,
        Size = UDim2.new(0, 0, 0, Theme.chrome.tab),
        AutomaticSize = Enum.AutomaticSize.X,
        LayoutOrder = slot,
        ZIndex = 3,
        Parent = window.Strip,
    })
    Util.corner(button, 8)
    Util.list(
        button,
        7,
        Enum.FillDirection.Horizontal,
        Enum.HorizontalAlignment.Center,
        Enum.VerticalAlignment.Center
    )
    Util.pad(button, 0, 11, 0, 11)
    self.Button = button

    local holder = Craft.frame({
        BackgroundTransparency = 1,
        Size = UDim2.fromOffset(15, 15),
        LayoutOrder = 1,
        ZIndex = 4,
        Parent = button,
    })
    self.Glyph = Icons.draw({ Icon = self.Icon, Size = 15, Color = Theme.get("textFaint"), ZIndex = 5, Parent = holder })

    self.Label = Craft.text({
        Text = self.Name,
        Token = "textFaint",
        TextSize = 13.5,
        FontFace = Theme.font.semi,
        AutomaticSize = Enum.AutomaticSize.X,
        Size = UDim2.new(0, 0, 1, 0),
        LayoutOrder = 2,
        ZIndex = 4,
        Parent = button,
    })

    button.MouseButton1Click:Connect(function()
        if window.active ~= self then
            Audio.play("click")
        end
        window:Select(self)
    end)

    -- inactive tabs had no hover feedback at all; now they lift toward the
    -- active colour so the strip feels clickable
    button.MouseEnter:Connect(function()
        self.hot = true
        self:Paint()
    end)
    button.MouseLeave:Connect(function()
        self.hot = false
        self:Paint()
    end)

    Theme.watch(function()
        if not button.Parent then
            return false
        end
        self:Paint()
        return true
    end)

    return self
end

function Tab:Module(opts)
    self.slot = self.slot + 1
    opts.LayoutOrder = self.slot
    -- Balance settles this properly a frame or two later; the point of picking a
    -- lane now is only that the card is never parented to a folded-away one and
    -- flickers out of sight until then
    local lanes = math.clamp(self.spread or #self.columns, 1, #self.columns)
    local pick = opts.Column and math.min(opts.Column, lanes) or ((self.slot - 1) % lanes + 1)
    opts.Parent = self.columns[pick]
    local card = Card.new(self, opts)
    card.pinned = opts.Column
    table.insert(self.cards, card)
    table.insert(self.flow.modules, card)
    self:Balance()
    return card
end

-- lane widths are set here and nowhere else, so the two things that decide them
-- can't disagree: how wide the window is (Reflow) and how many cards there are
-- to fill them (Balance)
function Tab:Spread(count)
    count = math.clamp(count, 1, #self.columns)
    if self.spread == count then
        return
    end
    self.spread = count
    local gap = self.gap or Theme.chrome.gap
    for i, lane in ipairs(self.columns) do
        lane.Visible = i <= count
        lane.Size = UDim2.new(1 / count, -gap * (count - 1) / count, 0, 0)
    end
end

-- narrow screens fold the card lanes down rather than squeezing three columns
-- into an unreadable width
function Tab:Reflow(count)
    count = math.clamp(count, 1, #self.columns)
    if self.active == count then
        return
    end
    self.active = count
    self:Balance()
end

function Tab:Balance()
    self.pending = (self.pending or 0) + 1
    local token = self.pending
    task.delay(0.08, function()
        if self.pending ~= token then
            return
        end
        local room = self.active or #self.columns
        -- a three-column tab holding two modules used to draw them a third of the
        -- way across and leave the last lane blank. Fold to the number of cards
        -- instead, but never past two: one module stretched over a whole window
        -- is a row of very lonely toggles.
        local lanes = math.clamp(#self.cards, math.min(2, room), room)
        self:Spread(lanes)
        local gap = self.gap or Theme.chrome.gap
        local heights = table.create(lanes, 0)
        for i, card in ipairs(self.cards) do
            local pinned = card.pinned and math.min(card.pinned, lanes) or nil
            if pinned then
                local lane = self.columns[pinned]
                heights[pinned] = heights[pinned] + card.Frame.AbsoluteSize.Y + gap
                card.Frame.LayoutOrder = i
                card.Frame.Parent = lane
            else
                local pick = 1
                for c = 2, lanes do
                    if heights[c] + 0.5 < heights[pick] then
                        pick = c
                    end
                end
                heights[pick] = heights[pick] + card.Frame.AbsoluteSize.Y + gap
                card.Frame.LayoutOrder = i
                if card.Frame.Parent ~= self.columns[pick] then
                    card.Frame.Parent = self.columns[pick]
                end
            end
        end
    end)
end

function Tab:Filter(query)
    local hits = 0
    for _, card in ipairs(self.cards) do
        local ok = card:Match(query)
        card.Frame.Visible = ok
        if ok then
            hits = hits + 1
        end
    end
    return hits
end

-- single source of truth for tab colour: active beats hover beats idle
function Tab:Paint()
    local live = self.window.active == self
    local label = live and Theme.get("text") or (self.hot and Theme.get("textDim") or Theme.get("textFaint"))
    local glyph = live and Theme.get("accent") or (self.hot and Theme.get("textDim") or Theme.get("textFaint"))
    local fill = live and 0.45 or (self.hot and 0.75 or 1)
    Util.tween(self.Label, { TextColor3 = label }, Util.ease.snap)
    Util.tween(self.Button, { BackgroundTransparency = fill }, Util.ease.snap)
    Icons.tint(self.Glyph, glyph)
end

function Tab:Show()
    self.Page.Visible = true
    self.Page.Position = UDim2.fromOffset(0, 8)
    Util.tween(self.Page, { GroupTransparency = 0, Position = UDim2.fromOffset(0, 0) }, Util.ease.glide)
    self:Paint()
    -- tabs are rarely the same length, so the window has to re-measure on a swap
    -- rather than keep whatever the last one asked for
    self.window:Resize()
end

function Tab:Hide()
    Util.tween(self.Page, { GroupTransparency = 1 }, Util.ease.snap)
    self:Paint()
    task.delay(0.14, function()
        if self.window.active ~= self then
            self.Page.Visible = false
        end
    end)
end

return Tab
end

__flowStartupCheckpoint()
__modules["ui/window"] = function(require)
__flowStartupCheckpoint()
local Players = __service("Players")
local UserInputService = __service("UserInputService")

local Util = require("core/util")
local Theme = require("core/theme")
local Craft = require("core/craft")
local Icons = require("core/icons")
local State = require("core/state")
local Overlay = require("ui/overlay")
local Controls = require("ui/controls")
local Tab = require("ui/tab")
local Audio = require("core/audio")
local Luarmor = require("core/luarmor")
local Notify = require("hud/notify")

local Window = {}
Window.__index = Window

local lp = Players.LocalPlayer

local swatches = {
    Color3.fromRGB(124, 92, 255),
    Color3.fromRGB(92, 124, 255),
    Color3.fromRGB(70, 178, 240),
    Color3.fromRGB(64, 206, 186),
    Color3.fromRGB(80, 205, 137),
    Color3.fromRGB(240, 178, 78),
    Color3.fromRGB(238, 108, 92),
    Color3.fromRGB(236, 94, 178),
}

local function iconButton(parent, icon, order, size)
    local button = Craft.button({
        Name = icon,
        BackgroundTransparency = 1,
        Size = UDim2.fromOffset(size or 30, size or 30),
        LayoutOrder = order,
        ZIndex = 4,
        Parent = parent,
    })
    Util.corner(button, 8)
    local glyph = Icons.draw({ Icon = icon, Size = math.floor((size or 30) * 0.52), Token = "textDim", ZIndex = 5, Parent = button })
    Util.hover(button, button, { BackgroundTransparency = 1 }, { BackgroundTransparency = 0 })
    Theme.bind(button, "BackgroundColor3", "surfaceAlt")
    return button, glyph
end

function Window.new(flow, opts)
    local self = setmetatable({}, Window)
    self.flow = flow
    self.tabs = {}
    self.columns = opts.Columns or 3
    self.open = true

    local size = opts.Size or UDim2.fromOffset(900, 580)
    self.wanted = Vector2.new(size.X.Offset, size.Y.Offset)
    self.minColumns = opts.MinColumns or 1
    -- Size is a ceiling, not a fixed height: the window ends where the page it is
    -- showing ends. AutoHeight = false pins it to the ceiling instead.
    self.autoHeight = opts.AutoHeight ~= false
    self.chromeTop = Theme.chrome.top
    self.footerHeight = 0
    self.width = size.X.Offset
    self.room = size.Y.Offset
    local bleed = 36
    self.baseSize = UDim2.new(size.X.Scale, size.X.Offset + bleed, size.Y.Scale, size.Y.Offset + bleed)

    local shell = Util.new("CanvasGroup", {
        Name = "Window",
        BackgroundTransparency = 1,
        Size = self.baseSize,
        Position = opts.Position or UDim2.fromScale(0.5, 0.5),
        AnchorPoint = Vector2.new(0.5, 0.5),
        Parent = flow.layers.window,
    })
    self.Shell = shell

    for i = 1, 3 do
        Craft.frame({
            Name = "Halo",
            Token = "black",
            Radius = Theme.radius.window + i * 4,
            BackgroundTransparency = 0.72 + i * 0.08,
            Size = UDim2.new(1, -bleed + i * 11, 1, -bleed + i * 11),
            Position = UDim2.fromScale(0.5, 0.5),
            AnchorPoint = Vector2.new(0.5, 0.5),
            ZIndex = 4 - i,
            Parent = shell,
        })
    end

    local root = Craft.frame({
        Name = "Chrome",
        Token = "backdrop",
        Radius = Theme.radius.window,
        Size = UDim2.new(1, -bleed, 1, -bleed),
        Position = UDim2.fromScale(0.5, 0.5),
        AnchorPoint = Vector2.new(0.5, 0.5),
        ClipsDescendants = true,
        ZIndex = 5,
        Parent = shell,
    })
    local edge = Util.stroke(root, Theme.get("line"), 1, 0.15)
    Theme.bind(edge, "Color", "line")
    self.Frame = root

    local header = Craft.frame({
        Name = "Header",
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, Theme.chrome.header),
        ZIndex = 3,
        Parent = root,
    })
    Util.pad(header, 0, Theme.gutter, 0, Theme.gutter)
    self.Header = header
    Craft.frame({
        Name = "Rule",
        Token = "lineSoft",
        -- bleeds back out through the padding to stop 2px short of each edge
        Size = UDim2.new(1, Theme.gutter * 2 - 4, 0, 1),
        Position = UDim2.new(0, -Theme.gutter + 2, 1, 0),
        AnchorPoint = Vector2.new(0, 1),
        ZIndex = 4,
        Parent = header,
    })

    local brand = Craft.frame({
        Name = "Brand",
        BackgroundTransparency = 1,
        Size = UDim2.new(0, 0, 1, 0),
        AutomaticSize = Enum.AutomaticSize.X,
        ZIndex = 4,
        Parent = header,
    })
    Util.list(brand, 9, Enum.FillDirection.Horizontal, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Center)

    local markName = opts.Mark or "brand"
    local mark

    if Icons.images[markName] then
        -- a logo already reads as its own shape, so it sits bare rather than in a
        -- tile; ScaleType.Fit keeps it square inside the cell whatever its aspect
        mark = Craft.frame({
            Name = "Mark",
            BackgroundTransparency = 1,
            Size = UDim2.fromOffset(36, 36),
            LayoutOrder = 1,
            ZIndex = 5,
            Parent = brand,
        })
        Icons.draw({ Icon = markName, Size = 36, ZIndex = 6, Parent = mark })
    else
        mark = Craft.frame({
            Name = "Mark",
            Token = "accent",
            Radius = 9,
            Size = UDim2.fromOffset(30, 30),
            LayoutOrder = 1,
            ZIndex = 5,
            Parent = brand,
        })
        self.MarkGradient = Craft.gradient(mark, Theme.get("accentGlow"), Theme.get("accentDeep"), 62)
        Theme.watch(function()
            if not mark.Parent then
                return false
            end
            self.MarkGradient.Color = ColorSequence.new(Theme.get("accentGlow"), Theme.get("accentDeep"))
        end)
        Icons.draw({ Icon = markName, Size = 17, Color = Theme.get("white"), ZIndex = 6, Parent = mark })
    end

    local words = Craft.frame({
        BackgroundTransparency = 1,
        Size = UDim2.fromOffset(0, 0),
        AutomaticSize = Enum.AutomaticSize.XY,
        LayoutOrder = 2,
        ZIndex = 5,
        Parent = brand,
    })
    Util.list(words, 1)
    self.BrandWords = words

    Craft.text({
        Name = "Title",
        Text = opts.Title or "FLOW",
        Token = "text",
        TextSize = 17,
        FontFace = Theme.font.bold,
        AutomaticSize = Enum.AutomaticSize.X,
        Size = UDim2.fromOffset(0, 19),
        ZIndex = 6,
        Parent = words,
    })
    -- the strap under the title is opt-in; nothing is drawn unless Build is given
    if opts.Build then
        local buildRow = Craft.frame({
            Name = "BuildRow",
            BackgroundTransparency = 1,
            Size = UDim2.fromOffset(0, 14),
            AutomaticSize = Enum.AutomaticSize.X,
            LayoutOrder = 2,
            ZIndex = 6,
            Parent = words,
        })
        Util.list(buildRow, 6, Enum.FillDirection.Horizontal, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Center)

        Craft.frame({
            Name = "Live",
            Token = "accent",
            Radius = UDim.new(1, 0),
            Size = UDim2.fromOffset(5, 5),
            LayoutOrder = 1,
            ZIndex = 7,
            Parent = buildRow,
        })

        Craft.text({
            Name = "Build",
            Text = opts.Build,
            Token = "textFaint",
            TextSize = 11.5,
            FontFace = Theme.font.regular,
            AutomaticSize = Enum.AutomaticSize.X,
            Size = UDim2.new(0, 0, 1, 0),
            LayoutOrder = 2,
            ZIndex = 7,
            Parent = buildRow,
        })
    end

    local actions = Craft.frame({
        Name = "Actions",
        BackgroundTransparency = 1,
        Size = UDim2.new(0, 0, 1, 0),
        AutomaticSize = Enum.AutomaticSize.X,
        Position = UDim2.new(1, 0, 0, 0),
        AnchorPoint = Vector2.new(1, 0),
        ZIndex = 4,
        Parent = header,
    })
    Util.list(actions, 8, Enum.FillDirection.Horizontal, Enum.HorizontalAlignment.Right, Enum.VerticalAlignment.Center)

    local searchBox = Craft.frame({
        Name = "Search",
        Token = "surfaceAlt",
        Radius = Theme.radius.control,
        Edge = "lineSoft",
        Size = UDim2.fromOffset(opts.SearchWidth or 200, Theme.chrome.field),
        LayoutOrder = 1,
        ZIndex = 5,
        Parent = actions,
    })
    self.SearchBox = searchBox
    self.SearchWidth = opts.SearchWidth or 200
    Util.pad(searchBox, 0, 9, 0, 29)
    Icons.draw({
        Icon = "search",
        Size = 14,
        Token = "textFaint",
        Position = UDim2.new(0, -19, 0.5, 0),
        AnchorPoint = Vector2.new(0.5, 0.5),
        ZIndex = 6,
        Parent = searchBox,
    })
    local search = Util.new("TextBox", {
        BackgroundTransparency = 1,
        Size = UDim2.fromScale(1, 1),
        Text = "",
        PlaceholderText = "Search",
        FontFace = Theme.font.medium,
        TextSize = 13,
        TextXAlignment = Enum.TextXAlignment.Left,
        ClearTextOnFocus = false,
        ZIndex = 6,
        Parent = searchBox,
    })
    Theme.bind(search, "TextColor3", "text")
    Theme.bind(search, "PlaceholderColor3", "textFaint")
    self.Search = search

    local bell = iconButton(actions, "bell", 2, Theme.chrome.icon)
    local gear = iconButton(actions, "gear", 3, Theme.chrome.icon)

    Craft.frame({
        Name = "Split",
        Token = "line",
        Size = UDim2.fromOffset(1, 18),
        LayoutOrder = 4,
        ZIndex = 5,
        Parent = actions,
    })

    local account = Craft.button({
        Name = "Account",
        BackgroundTransparency = 1,
        Size = UDim2.new(0, 0, 0, 34),
        AutomaticSize = Enum.AutomaticSize.X,
        LayoutOrder = 5,
        ZIndex = 5,
        Parent = actions,
    })
    Util.corner(account, 9)
    Util.pad(account, 0, 7, 0, 4)
    Theme.bind(account, "BackgroundColor3", "surfaceAlt")
    Util.hover(account, account, { BackgroundTransparency = 1 }, { BackgroundTransparency = 0 })

    local accountRow = Craft.frame({
        BackgroundTransparency = 1,
        Size = UDim2.new(0, 0, 1, 0),
        AutomaticSize = Enum.AutomaticSize.X,
        ZIndex = 6,
        Parent = account,
    })
    Util.list(accountRow, 7, Enum.FillDirection.Horizontal, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Center)

    local avatar = Util.new("ImageLabel", {
        Name = "Avatar",
        BackgroundColor3 = Theme.get("raised"),
        BorderSizePixel = 0,
        Size = UDim2.fromOffset(27, 27),
        LayoutOrder = 1,
        ZIndex = 7,
        Parent = accountRow,
    })
    Util.corner(avatar, 7)
    task.spawn(function()
        avatar.Image = Util.thumbnail(lp.UserId)
    end)

    local names = Craft.frame({
        BackgroundTransparency = 1,
        Size = UDim2.fromOffset(0, 27),
        AutomaticSize = Enum.AutomaticSize.X,
        LayoutOrder = 2,
        ZIndex = 7,
        Parent = accountRow,
    })
    Util.list(names, 0)
    self.AccountNames = names

    Craft.text({
        Text = opts.User or lp.DisplayName,
        Token = "text",
        TextSize = 13,
        FontFace = Theme.font.semi,
        AutomaticSize = Enum.AutomaticSize.X,
        Size = UDim2.fromOffset(0, 14),
        ZIndex = 8,
        Parent = names,
    })
    self.PlanLabel = Craft.text({
        Text = opts.Tag or Luarmor.plan(),
        -- premium wears the accent, free wears green; set here as well as in
        -- RefreshPlan so the tag never changes colour on the first profile open
        Token = Luarmor.isPremium() and "accent" or "success",
        TextSize = 10.5,
        FontFace = Theme.font.semi,
        AutomaticSize = Enum.AutomaticSize.X,
        Size = UDim2.fromOffset(0, 12),
        ZIndex = 8,
        Parent = names,
    })
    -- an explicit Tag is the caller's to own; otherwise the plan tracks the key
    self.PlanFixed = opts.Tag ~= nil

    local caret = Craft.frame({
        BackgroundTransparency = 1,
        Size = UDim2.fromOffset(12, 12),
        LayoutOrder = 3,
        ZIndex = 7,
        Parent = accountRow,
    })
    Icons.draw({ Icon = "chevron-down", Size = 11, Token = "textFaint", ZIndex = 8, Parent = caret })

    --[[
        The strip scrolls horizontally. A window fits about nine tabs across, and
        a plain frame simply drew the rest past its own edge where they could
        never be clicked. The scrollbar is hidden — it would land on the rule
        below — so the strip is driven by wheel and drag, and Window:Reveal
        brings a selected tab into view.

        A hidden scrollbar and a mouse wheel are both desktop assumptions, and a
        phone has neither: nothing said there were more tabs and nothing but a
        lucky swipe would reach them. Window:Rail adds an arrow at each end that
        appears only when there is something past it — see below.
    ]]
    local strip = Craft.scroll({
        Name = "Strip",
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, Theme.chrome.strip),
        Position = UDim2.fromOffset(0, Theme.chrome.header),
        ScrollingDirection = Enum.ScrollingDirection.X,
        AutomaticCanvasSize = Enum.AutomaticSize.X,
        CanvasSize = UDim2.new(),
        ScrollBarThickness = 0,
        ScrollBarImageTransparency = 1,
        ClipsDescendants = true,
        ZIndex = 3,
        Parent = root,
    })
    Util.pad(strip, 0, Theme.gutter, 0, Theme.gutter)
    Util.list(strip, 6, Enum.FillDirection.Horizontal, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Center)
    self.Strip = strip

    -- the marker sits outside the strip, so scrolling has to drag it along or it
    -- would drift away from the tab it belongs to
    strip:GetPropertyChangedSignal("CanvasPosition"):Connect(function()
        if self.active then
            self:Mark(self.active, false)
        end
        self:Rail()
    end)

    self:BuildRail(root)

    local top = Theme.chrome.top

    Craft.frame({
        Name = "Rule",
        Token = "lineSoft",
        Size = UDim2.new(1, 0, 0, 1),
        Position = UDim2.new(0, 0, 0, top - 1),
        ZIndex = 4,
        Parent = root,
    })

    local marker = Craft.frame({
        Name = "Marker",
        Token = "accent",
        Radius = UDim.new(1, 0),
        Size = UDim2.fromOffset(0, 2),
        Position = UDim2.fromOffset(Theme.gutter, top - 3),
        ZIndex = 5,
        Parent = root,
    })
    self.Marker = marker

    local body = Craft.frame({
        Name = "Body",
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 1, -top),
        Position = UDim2.fromOffset(0, top),
        ZIndex = 2,
        Parent = root,
    })
    self.Body = body

    Util.drag(header, shell)

    search:GetPropertyChangedSignal("Text"):Connect(function()
        self:Filter(search.Text)
    end)

    search.FocusLost:Connect(function(_, cause)
        if cause and cause.KeyCode == Enum.KeyCode.Escape then
            search.Text = ""
        end
    end)

    account.MouseButton1Click:Connect(function()
        self:Profile(account)
    end)
    gear.MouseButton1Click:Connect(function()
        self:Settings(gear)
    end)
    bell.MouseButton1Click:Connect(function()
        Notify.panel(bell)
    end)

    self.Account = { Name = opts.User or lp.DisplayName, Tag = opts.Tag or Luarmor.plan() }

    return self
end

--[[
    A bar across the bottom of the window: who made it, where the connection is,
    and a way out to a community. Purely cosmetic, but a sparse tab leaves a lot
    of empty surface and a hub with nothing along the bottom reads unfinished.

    Every slot is optional and nothing is drawn for one that is not configured.
]]

-- Region comes from a public IP lookup, which means two things worth knowing:
-- it geolocates whoever is RUNNING the script, not the Roblox server, and it
-- hands their IP to a third party. Pass a plain string instead to skip both.
local function lookupRegion(done)
    task.spawn(function()
        local ok, body = pcall(function()
            return game:HttpGet("http://ip-api.com/json/?fields=status,country,countryCode,city")
        end)
        if not ok then
            return done(nil)
        end
        local parsed
        ok, parsed = pcall(function()
            return __service("HttpService"):JSONDecode(body)
        end)
        if not ok or type(parsed) ~= "table" or parsed.status ~= "success" then
            return done(nil)
        end
        if parsed.city and parsed.countryCode then
            return done(parsed.city .. ", " .. parsed.countryCode)
        end
        done(parsed.country or parsed.countryCode)
    end)
end

function Window:Footer(opts)
    opts = opts or {}
    if self.FooterBar then
        self.FooterBar:Destroy()
        self.FooterBar = nil
    end

    local height = opts.Height or Theme.chrome.footer
    local bar = Craft.frame({
        Name = "Footer",
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, height),
        Position = UDim2.new(0, 0, 1, 0),
        AnchorPoint = Vector2.new(0, 1),
        ZIndex = 3,
        Parent = self.Frame,
    })
    Util.pad(bar, 0, Theme.gutter, 0, Theme.gutter)
    self.FooterBar = bar

    Craft.frame({
        Name = "Rule",
        Token = "lineSoft",
        Size = UDim2.new(1, Theme.gutter * 2 - 4, 0, 1),
        Position = UDim2.new(0, -Theme.gutter + 2, 0, 0),
        ZIndex = 4,
        Parent = bar,
    })

    -- pages stop above the bar rather than scrolling underneath it
    self.footerHeight = height
    self.Body.Size = UDim2.new(1, 0, 1, -(self.chromeTop + height))
    self:Resize(false)

    ----------------------------------------------------------------------------
    -- left: sticker + credit
    ----------------------------------------------------------------------------

    local left = Craft.frame({
        Name = "Credit",
        BackgroundTransparency = 1,
        Size = UDim2.fromOffset(0, 0),
        AutomaticSize = Enum.AutomaticSize.XY,
        Position = UDim2.new(0, 0, 0.5, 0),
        AnchorPoint = Vector2.new(0, 0.5),
        ZIndex = 4,
        Parent = bar,
    })
    Util.list(left, 6, Enum.FillDirection.Horizontal, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Center)

    local function emoji()
        if not opts.Emoji then
            return nil
        end
        return Craft.text({
            Name = "Sticker",
            -- BuilderSans has no glyph for these, so the engine falls back to its
            -- emoji font: a text label, not an icon
            Text = opts.Emoji,
            TextSize = 15,
            AutomaticSize = Enum.AutomaticSize.X,
            Size = UDim2.fromOffset(0, 18),
            LayoutOrder = 1,
            ZIndex = 5,
            Parent = left,
        })
    end

    if opts.Sticker then
        local size = opts.StickerSize or 24
        -- the usual thing to put here is a profile picture, so it is cropped to
        -- a circle by default. StickerRound = false leaves a fitted square for a
        -- transparent sticker that should not lose its corners.
        local round = opts.StickerRound ~= false
        local image = Util.new("ImageLabel", {
            Name = "Sticker",
            BackgroundTransparency = 1,
            Image = opts.Sticker,
            ScaleType = round and Enum.ScaleType.Crop or Enum.ScaleType.Fit,
            Size = UDim2.fromOffset(size, size),
            LayoutOrder = 1,
            ZIndex = 5,
            Parent = left,
        })
        if round then
            Util.corner(image, UDim.new(1, 0))
        end

        -- an id that is still in moderation, private, or simply wrong resolves to
        -- nothing and leaves a hole in the row. Fall back to the emoji instead.
        task.spawn(function()
            pcall(function()
                __service("ContentProvider"):PreloadAsync({ image })
            end)
            if image.Parent and not image.IsLoaded and opts.Emoji then
                image:Destroy()
                emoji()
            end
        end)
    else
        emoji()
    end

    if opts.Credit then
        Craft.text({
            Name = "Text",
            Text = opts.Credit,
            Token = "textDim",
            TextSize = 12.5,
            FontFace = Theme.font.medium,
            AutomaticSize = Enum.AutomaticSize.X,
            Size = UDim2.fromOffset(0, 16),
            LayoutOrder = 2,
            ZIndex = 5,
            Parent = left,
        })
    end

    ----------------------------------------------------------------------------
    -- right: region readout + link out
    ----------------------------------------------------------------------------

    local right = Craft.frame({
        Name = "Links",
        BackgroundTransparency = 1,
        Size = UDim2.fromOffset(0, 0),
        AutomaticSize = Enum.AutomaticSize.XY,
        Position = UDim2.new(1, 0, 0.5, 0),
        AnchorPoint = Vector2.new(1, 0.5),
        ZIndex = 4,
        Parent = bar,
    })
    Util.list(right, 12, Enum.FillDirection.Horizontal, Enum.HorizontalAlignment.Right, Enum.VerticalAlignment.Center)

    if opts.Region then
        local row = Craft.frame({
            Name = "Region",
            BackgroundTransparency = 1,
            Size = UDim2.fromOffset(0, 18),
            AutomaticSize = Enum.AutomaticSize.X,
            LayoutOrder = 1,
            ZIndex = 5,
            Parent = right,
        })
        Util.list(row, 5, Enum.FillDirection.Horizontal, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Center)

        -- Icons.draw centres itself by default, which a list layout then shifts
        -- by half its own size; anchoring at the corner puts it back
        local mark = Icons.draw({
            Icon = "signal",
            Size = 12,
            Token = "textFaint",
            Position = UDim2.new(),
            AnchorPoint = Vector2.new(0, 0),
            ZIndex = 6,
            Parent = row,
        })
        mark.LayoutOrder = 1

        local text = Craft.text({
            Name = "Value",
            Text = type(opts.Region) == "string" and opts.Region or "Locating",
            Token = "textFaint",
            TextSize = 12,
            AutomaticSize = Enum.AutomaticSize.X,
            Size = UDim2.fromOffset(0, 16),
            LayoutOrder = 2,
            ZIndex = 6,
            Parent = row,
        })

        if opts.Region == true then
            lookupRegion(function(value)
                if text.Parent then
                    text.Text = value or "Unknown"
                end
            end)
        end
    end

    if opts.Discord then
        -- an invite is a link to follow, a username is a name to add: show the
        -- name itself rather than hiding it behind the word "Discord"
        local invite = opts.Discord:match("^https?://") ~= nil or opts.Discord:match("discord%.gg/") ~= nil
        local label = opts.DiscordLabel or (invite and "Discord" or opts.Discord)

        local button = Craft.button({
            Name = "Discord",
            Token = "surfaceAlt",
            Radius = Theme.radius.chip,
            Edge = "lineSoft",
            Size = UDim2.fromOffset(0, 26),
            AutomaticSize = Enum.AutomaticSize.X,
            LayoutOrder = 2,
            ZIndex = 5,
            Parent = right,
        })
        Util.pad(button, 0, 11, 0, 11)

        -- no icon: the name is the label, and a glyph in front of it only
        -- repeated what the text already said
        Craft.text({
            Name = "Value",
            Text = label,
            Token = "textDim",
            TextSize = 12,
            FontFace = Theme.font.semi,
            AutomaticSize = Enum.AutomaticSize.X,
            Size = UDim2.new(0, 0, 1, 0),
            ZIndex = 6,
            Parent = button,
        })

        Util.hover(button, button, { BackgroundColor3 = Theme.get("surfaceAlt") }, { BackgroundColor3 = Theme.get("raised") })

        -- opening a browser is not something a UI library should do behind the
        -- user's back, so the invite goes to the clipboard and says so
        button.MouseButton1Click:Connect(function()
            Audio.play("click")
            local copied = setclipboard ~= nil and pcall(setclipboard, opts.Discord)
            self.flow:Notify({
                Title = copied and (invite and "Invite copied" or "Username copied") or "Discord",
                Text = opts.Discord,
                Icon = invite and "link" or "user",
                Kind = copied and "success" or nil,
                Duration = 4,
            })
        end)
    end

    return bar
end

--[[
    The window is exactly as tall as the page it is showing, up to the ceiling
    Fit worked out from Size and the viewport. A tab with two cards used to draw
    them into the top corner of a 680px frame and leave the rest empty; now the
    frame ends where the cards do, and a tab with more than fits scrolls.

    Nothing here touches width — lanes are fractional, so a narrower window would
    only make the cards narrower, not the layout tighter.
]]
function Window:Resize(animate)
    local height = self.room

    if self.autoHeight then
        local tab = self.active
        local lanes = tab and tab.Lanes
        if lanes then
            -- AbsoluteSize is in screen pixels, so undo the interface scale to get
            -- back to the offsets the window is actually built in
            local k = math.max(self.flow.scale.Scale, 0.01)
            local chrome = self.chromeTop + self.footerHeight + (tab.pageInset or 0)
            -- a tab with nothing in it still needs somewhere to say so
            local least = math.min(chrome + 90, self.room)
            height = math.clamp(lanes.AbsoluteSize.Y / k + chrome, least, self.room)
        end
    end

    height = math.floor(height + 0.5)
    if self.height == height and self.shellWidth == self.width then
        return
    end
    self.height = height
    self.shellWidth = self.width

    local bleed = 36
    self.baseSize = UDim2.fromOffset(self.width + bleed, height + bleed)
    if not self.open then
        return
    end

    -- a plain assignment loses to a tween that is still running, and the window
    -- ends up wherever the stale one was headed. Every size change goes through
    -- here so there is exactly one to cancel.
    if self.sizeTween then
        self.sizeTween:Cancel()
        self.sizeTween = nil
    end
    if animate == false then
        self.Shell.Size = self.baseSize
    else
        self.sizeTween = Util.tween(self.Shell, { Size = self.baseSize }, Util.ease.glide)
    end
end

--[[
    The header is two independently anchored halves: the brand on the left, the
    actions on the right. Neither knew how much room the other needed, so on a
    phone the search field simply drew straight over the logo.

    Three tiers, widest first. The account avatar, the bell and the gear survive
    all of them — they are the ones that are actually pressed.
]]
function Window:Compress(width)
    local tier = (width < 470 and 2) or (width < 640 and 1) or 0
    if self.tier == tier then
        return
    end
    self.tier = tier

    if self.BrandWords then
        self.BrandWords.Visible = tier == 0
    end
    if self.AccountNames then
        self.AccountNames.Visible = tier == 0
    end
    if self.SearchBox then
        self.SearchBox.Visible = tier < 2
        if tier == 1 then
            self.SearchBox.Size = UDim2.fromOffset(124, Theme.chrome.field)
        else
            self.SearchBox.Size = UDim2.fromOffset(self.SearchWidth or 200, Theme.chrome.field)
        end
        -- a hidden field that still holds a query would filter every tab with no
        -- way to see or clear it
        if tier == 2 and self.Search and self.Search.Text ~= "" then
            self.Search.Text = ""
        end
    end
end

-- Keep the window inside the viewport and drop card lanes when it gets narrow,
-- so a phone gets one readable column instead of three slivers.
function Window:Fit(viewport)
    viewport = viewport or Util.viewport()

    local margin = viewport.X < 700 and 12 or 40
    local width = math.min(self.wanted.X, viewport.X - margin * 2)
    local room = math.min(self.wanted.Y, viewport.Y - margin * 2)
    self.width = math.max(width, 280)
    self.room = math.max(room, 240)

    self:Compress(self.width)

    -- roughly 300px of usable width per lane before cards stop being readable
    local lanes = math.clamp(math.floor(self.width / 300), self.minColumns, self.columns)
    for _, tab in ipairs(self.tabs) do
        tab:Reflow(lanes)
    end

    self:Resize(false)

    -- keep the window on screen after a resize or rotation
    local half = self.Shell.AbsoluteSize / 2
    local pos = self.Shell.Position
    self.Shell.Position = UDim2.new(
        pos.X.Scale,
        Util.clamp(pos.X.Offset, -viewport.X * pos.X.Scale + half.X, viewport.X - viewport.X * pos.X.Scale - half.X),
        pos.Y.Scale,
        Util.clamp(pos.Y.Offset, -viewport.Y * pos.Y.Scale + half.Y, viewport.Y - viewport.Y * pos.Y.Scale - half.Y)
    )

    return lanes
end

function Window:Tab(opts)
    local tab = Tab.new(self, opts)
    table.insert(self.tabs, tab)
    if not self.active then
        self:Select(tab)
    end
    return tab
end

-- slide the underline to a tab. Positions are read live rather than cached so
-- this stays correct while the strip scrolls.
function Window:Mark(tab, animate)
    if not tab or not tab.Button then
        return
    end
    local k = math.max(self.flow.scale.Scale, 0.01)
    local origin = self.Strip.AbsolutePosition.X
    local target = {
        Position = UDim2.fromOffset(math.floor((tab.Button.AbsolutePosition.X - origin) / k), self.chromeTop - 3),
        Size = UDim2.fromOffset(math.floor(tab.Button.AbsoluteSize.X / k), 2),
    }
    if animate == false then
        self.Marker.Position = target.Position
        self.Marker.Size = target.Size
    else
        Util.tween(self.Marker, target, Util.ease.glide)
    end
end

--[[
    An arrow at each end of the tab strip.

    A hidden scrollbar leaves nothing on screen to say the strip goes further, and
    on a phone there is no wheel to find out with. Roblox will scroll the frame
    from a touch drag, but only if you already know to try — and a drag that
    starts on a tab reads as a press until the finger moves, which is not a thing
    to make someone discover.

    So: a tappable arrow, which every pointer has, showing only on the side that
    has something past it. It sits outside the strip rather than inside, or it
    would scroll away with the tabs it belongs to.
]]
function Window:BuildRail(root)
    local size = math.max(Theme.chrome.strip - 12, 24)
    local pad = Theme.chrome.strip

    local function arrow(icon, side)
        local button = Craft.button({
            Name = "Rail",
            Token = "backdrop",
            BackgroundTransparency = 0,
            Size = UDim2.fromOffset(pad, Theme.chrome.strip),
            Position = UDim2.new(side, 0, 0, Theme.chrome.header),
            AnchorPoint = Vector2.new(side, 0),
            Visible = false,
            ZIndex = 6,
            Parent = root,
        })
        -- the tabs fade out under the arrow instead of being cut off by it
        local wash = Craft.gradient(button, Theme.get("backdrop"), Theme.get("backdrop"), side == 0 and 0 or 180)
        wash.Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 0),
            NumberSequenceKeypoint.new(0.55, 0),
            NumberSequenceKeypoint.new(1, 1),
        })
        Theme.watch(function()
            if not button.Parent then
                return false
            end
            local backdrop = Theme.get("backdrop")
            wash.Color = ColorSequence.new(backdrop, backdrop)
        end)

        local glyph = Icons.draw({
            Icon = icon,
            Size = math.floor(size * 0.62),
            Token = "textDim",
            ZIndex = 7,
            Parent = button,
        })

        button.MouseEnter:Connect(function()
            Icons.tint(glyph, Theme.get("text"))
        end)
        button.MouseLeave:Connect(function()
            Icons.tint(glyph, Theme.get("textDim"))
        end)
        button.MouseButton1Click:Connect(function()
            Audio.play("click")
            self:Nudge(side == 0 and -1 or 1)
        end)

        return button
    end

    self.RailLeft = arrow("chevron-left", 0)
    self.RailRight = arrow("chevron-right", 1)

    -- a tab being added changes the canvas without moving it, so CanvasPosition
    -- alone would never fire
    self.Strip:GetPropertyChangedSignal("AbsoluteCanvasSize"):Connect(function()
        self:Rail()
    end)
    self.Strip:GetPropertyChangedSignal("AbsoluteWindowSize"):Connect(function()
        self:Rail()
    end)
end

--[[
    How far the strip can travel, and where it is.

    Worth stating because it is not what the property names suggest: under a
    UIScale, CanvasPosition lives in the same scaled space as AbsoluteCanvasSize
    and AbsoluteWindowSize, not in the frame's own offsets. Measured, not
    assumed — the engine clamps CanvasPosition to exactly this difference.
]]
function Window:railRange()
    local strip = self.Strip
    local span = strip.AbsoluteCanvasSize.X - strip.AbsoluteWindowSize.X
    return math.max(span, 0), strip.CanvasPosition.X
end

function Window:Rail()
    if not self.RailLeft then
        return
    end
    local span, at = self:railRange()
    self.RailLeft.Visible = span > 2 and at > 2
    self.RailRight.Visible = span > 2 and at < span - 2
end

-- one arrow tap moves most of a screenful, keeping a tab or two of overlap so
-- the strip does not feel like it jumped somewhere unrelated
function Window:Nudge(direction)
    local strip = self.Strip
    local span, at = self:railRange()
    local step = math.max(strip.AbsoluteWindowSize.X * 0.7, 60)
    local target = Util.clamp(at + step * direction, 0, span)
    Util.tween(strip, { CanvasPosition = Vector2.new(target, 0) }, Util.ease.out)
end

-- scroll a tab into view, so selecting one that sits past the strip's edge
-- actually shows it
function Window:Reveal(tab)
    local strip = self.Strip
    if not tab or not tab.Button or not strip:IsA("ScrollingFrame") then
        return
    end
    local left = tab.Button.AbsolutePosition.X - strip.AbsolutePosition.X + strip.CanvasPosition.X
    local right = left + tab.Button.AbsoluteSize.X
    local view = strip.AbsoluteWindowSize.X
    -- leave room for the arrow rather than tucking the tab underneath it
    local margin = Theme.chrome.strip
    local target = strip.CanvasPosition.X
    if left - margin < target then
        target = math.max(left - margin, 0)
    elseif right + margin > target + view then
        target = right - view + margin
    end
    local span = select(1, self:railRange())
    target = Util.clamp(target, 0, span)
    if math.abs(target - strip.CanvasPosition.X) > 1 then
        Util.tween(strip, { CanvasPosition = Vector2.new(target, 0) }, Util.ease.out)
    end
end

function Window:Select(tab)
    if self.active == tab then
        return
    end
    -- swap the pointer first: Tab:Paint() derives its state from window.active,
    -- so hiding before the swap would repaint the outgoing tab as still active
    local previous = self.active
    self.active = tab
    if previous then
        previous:Hide()
    end
    tab:Show()
    task.defer(function()
        self:Reveal(tab)
        self:Mark(tab, true)
    end)
end

function Window:Filter(query)
    query = (query or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
    local best
    for _, tab in ipairs(self.tabs) do
        local hits = tab:Filter(query)
        if hits > 0 and not best then
            best = tab
        end
    end
    if query ~= "" and best and self.active ~= best and self.active:Filter(query) == 0 then
        self:Select(best)
    end
end

function Window:Toggle(state)
    if state == nil then
        state = not self.open
    end
    self.open = state
    Overlay.close(true)
    if self.sizeTween then
        self.sizeTween:Cancel()
        self.sizeTween = nil
    end
    if state then
        self.Shell.Visible = true
        self.sizeTween = Util.tween(self.Shell, { GroupTransparency = 0, Size = self.baseSize }, Util.ease.out)
    else
        self.sizeTween = Util.tween(self.Shell, {
            GroupTransparency = 1,
            Size = UDim2.new(
                self.baseSize.X.Scale,
                self.baseSize.X.Offset - 26,
                self.baseSize.Y.Scale,
                self.baseSize.Y.Offset - 18
            ),
        }, Util.ease.snap)
        task.delay(0.2, function()
            if not self.open then
                self.Shell.Visible = false
            end
        end)
    end
end

-- key state is a countdown, so re-read it rather than trusting what was true at
-- construction; otherwise the header can say Free while the menu says 27d left
function Window:RefreshPlan()
    if self.PlanFixed or not self.PlanLabel or not self.PlanLabel.Parent then
        return
    end
    local plan = Luarmor.plan()
    self.Account.Tag = plan
    self.PlanLabel.Text = plan
    Theme.rebind(self.PlanLabel, "TextColor3", Luarmor.isPremium() and "accent" or "success")
end

function Window:Profile(anchor)
    self:RefreshPlan()
    local entries = self.ProfileItems
        or {
            { Name = "Profile", Icon = "user" },
            { Name = "Log out", Icon = "logout", Danger = true, Callback = function()
                self.flow:Unload()
            end },
        }
    Overlay.toggle({
        Key = anchor,
        Anchor = anchor,
        Width = 216,
        Align = "right",
        Build = function(panel)
            Util.pad(panel, 12, 10, 10, 10)
            Util.list(panel, 8)

            local top = Craft.frame({
                BackgroundTransparency = 1,
                Size = UDim2.new(1, 0, 0, 38),
                LayoutOrder = 1,
                ZIndex = 3,
                Parent = panel,
            })
            local face = Util.new("ImageLabel", {
                BackgroundColor3 = Theme.get("raised"),
                BorderSizePixel = 0,
                Size = UDim2.fromOffset(36, 36),
                ZIndex = 4,
                Parent = top,
            })
            Util.corner(face, 10)
            task.spawn(function()
                face.Image = Util.thumbnail(lp.UserId)
            end)
            Craft.text({
                Text = self.Account.Name,
                Token = "text",
                TextSize = 13,
                FontFace = Theme.font.semi,
                Position = UDim2.fromOffset(46, 2),
                Size = UDim2.new(1, -46, 0, 16),
                ZIndex = 4,
                Parent = top,
            })
            Craft.text({
                Text = self.Account.Tag,
                Token = Luarmor.isPremium() and "accent" or "success",
                TextSize = 11,
                Position = UDim2.fromOffset(46, 18),
                Size = UDim2.new(1, -46, 0, 14),
                ZIndex = 4,
                Parent = top,
            })

            -- real key state from Luarmor, not a made-up level
            local meter = Craft.frame({
                BackgroundTransparency = 1,
                Size = UDim2.new(1, 0, 0, 32),
                LayoutOrder = 2,
                ZIndex = 3,
                Parent = panel,
            })
            Craft.text({
                Text = "Subscription",
                Token = "textDim",
                TextSize = 12,
                FontFace = Theme.font.semi,
                Size = UDim2.new(0.5, 0, 0, 15),
                ZIndex = 4,
                Parent = meter,
            })
            Craft.text({
                Text = Luarmor.duration(),
                Token = Luarmor.isPremium() and "accent" or "textDim",
                TextSize = 12,
                FontFace = Theme.font.bold,
                TextXAlignment = Enum.TextXAlignment.Right,
                Size = UDim2.new(0.5, 0, 0, 15),
                Position = UDim2.fromScale(0.5, 0),
                ZIndex = 4,
                Parent = meter,
            })

            local expiry = Luarmor.expiry()
            local footnote
            if expiry then
                footnote = "Expires " .. expiry
            elseif Luarmor.isLifetime() then
                footnote = "Never expires"
            else
                footnote = "No key detected"
            end

            local note = Luarmor.note()
            if note then
                footnote = footnote .. " · " .. note
            end

            Craft.text({
                Text = footnote,
                Token = "textFaint",
                TextSize = 11,
                TextTruncate = Enum.TextTruncate.AtEnd,
                Position = UDim2.fromOffset(0, 17),
                Size = UDim2.new(1, 0, 0, 14),
                ZIndex = 4,
                Parent = meter,
            })

            Craft.divider(panel, 3)

            local group = Craft.frame({
                BackgroundTransparency = 1,
                Size = UDim2.new(1, 0, 0, 0),
                AutomaticSize = Enum.AutomaticSize.Y,
                LayoutOrder = 4,
                ZIndex = 3,
                Parent = panel,
            })
            Util.list(group, 1)

            for i, item in ipairs(entries) do
                local row = Overlay.row({ Parent = group, LayoutOrder = i, Height = 31 })
                Util.pad(row, 0, 8, 0, 8)
                local holder = Craft.frame({
                    BackgroundTransparency = 1,
                    Size = UDim2.fromOffset(14, 14),
                    Position = UDim2.new(0, 0, 0.5, 0),
                    AnchorPoint = Vector2.new(0, 0.5),
                    ZIndex = 4,
                    Parent = row,
                })
                Icons.draw({
                    Icon = item.Icon or "cube",
                    Size = 13,
                    Token = item.Danger and "danger" or "textFaint",
                    ZIndex = 5,
                    Parent = holder,
                })
                Craft.text({
                    Text = item.Name,
                    Token = item.Danger and "danger" or "textDim",
                    TextSize = 12,
                    Position = UDim2.fromOffset(22, 0),
                    Size = UDim2.new(1, -38, 1, 0),
                    ZIndex = 5,
                    Parent = row,
                })
                if not item.Danger then
                    local tip = Craft.frame({
                        BackgroundTransparency = 1,
                        Size = UDim2.fromOffset(12, 12),
                        Position = UDim2.new(1, 0, 0.5, 0),
                        AnchorPoint = Vector2.new(1, 0.5),
                        ZIndex = 4,
                        Parent = row,
                    })
                    Icons.draw({ Icon = "chevron-right", Size = 11, Token = "textFaint", ZIndex = 5, Parent = tip })
                end
                row.MouseButton1Click:Connect(function()
                    Overlay.close()
                    if item.Callback then
                        task.spawn(item.Callback)
                    end
                end)
            end
        end,
    })
end

function Window:Settings(anchor)
    Overlay.toggle({
        Key = anchor,
        Anchor = anchor,
        Width = 280,
        Align = "right",
        Build = function(host)
            Util.pad(host, 12, 8, 12, 12)

            local panel = Craft.scroll({
                Name = "Body",
                Size = UDim2.new(1, 0, 0, 0),
                Parent = host,
            })
            Util.list(panel, 12)
            Util.pad(panel, 0, 8, 0, 0)

            -- cap the height against the viewport rather than a fixed number
            task.defer(function()
                if not panel.Parent then
                    return
                end
                local screen = self.flow.layers.overlay.AbsoluteSize.Y
                local cap = math.max(math.min(screen - 140, 470), 220)
                panel.Size = UDim2.new(1, 0, 0, math.min(panel.AbsoluteCanvasSize.Y, cap))
            end)

            Craft.text({
                Text = "Interface",
                Token = "textFaint",
                TextSize = 10.5,
                FontFace = Theme.font.bold,
                Size = UDim2.new(1, 0, 0, 12),
                LayoutOrder = 1,
                ZIndex = 3,
                Parent = panel,
            })

            -- Equal-width cells so the row spans the panel evenly, and the selection
            -- ring lives in its own frame rather than as an outward stroke on the dot
            -- (a 2px border on an 18px dot needs 22px of row and clips otherwise).
            local palette = Craft.frame({
                Name = "Palette",
                BackgroundTransparency = 1,
                Size = UDim2.new(1, 0, 0, 28),
                LayoutOrder = 2,
                ZIndex = 3,
                Parent = panel,
            })
            Util.list(palette, 0, Enum.FillDirection.Horizontal, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Center)

            local rings = {}

            local function near(a, b)
                return math.abs(a.R - b.R) < 0.01 and math.abs(a.G - b.G) < 0.01 and math.abs(a.B - b.B) < 0.01
            end

            local function markAccent()
                for _, entry in ipairs(rings) do
                    local same = near(entry.color, Theme.accent)
                    Util.tween(entry.ring, { Transparency = same and 0.15 or 1 }, Util.ease.snap)
                    Util.tween(entry.dot, {
                        Size = UDim2.fromOffset(same and 16 or 18, same and 16 or 18),
                    }, Util.ease.snap)
                end
            end

            for i, color in ipairs(swatches) do
                local cell = Craft.frame({
                    Name = "Cell",
                    BackgroundTransparency = 1,
                    Size = UDim2.new(1 / #swatches, 0, 1, 0),
                    LayoutOrder = i,
                    ZIndex = 3,
                    Parent = palette,
                })

                local halo = Craft.frame({
                    Name = "Ring",
                    BackgroundTransparency = 1,
                    Radius = UDim.new(1, 0),
                    Size = UDim2.fromOffset(26, 26),
                    Position = UDim2.fromScale(0.5, 0.5),
                    AnchorPoint = Vector2.new(0.5, 0.5),
                    ZIndex = 4,
                    Parent = cell,
                })
                local ring = Util.stroke(halo, color, 1.5, 1)

                local dot = Craft.button({
                    Name = "Swatch",
                    Radius = UDim.new(1, 0),
                    BackgroundColor3 = color,
                    BackgroundTransparency = 0,
                    Size = UDim2.fromOffset(18, 18),
                    Position = UDim2.fromScale(0.5, 0.5),
                    AnchorPoint = Vector2.new(0.5, 0.5),
                    ZIndex = 5,
                    Parent = cell,
                })

                rings[i] = { ring = ring, dot = dot, color = color }
                dot.MouseButton1Click:Connect(function()
                    Theme.setAccent(color)
                    markAccent()
                    self.flow:retint()
                end)
            end
            markAccent()

            Controls.slider(panel, {
                Name = "Interface scale",
                Min = 0.75,
                Max = 1.35,
                Step = 0.05,
                Default = self.flow.scale.Scale,
                LayoutOrder = 3,
                Callback = function(v)
                    self.flow:SetScale(v)
                end,
            })

            local bindRow = Craft.frame({
                BackgroundTransparency = 1,
                Size = UDim2.new(1, 0, 0, 0),
                AutomaticSize = Enum.AutomaticSize.Y,
                LayoutOrder = 4,
                ZIndex = 3,
                Parent = panel,
            })
            local head = Craft.head({ Name = "Menu key", Desc = "Opens and closes this window.", Parent = bindRow })
            head.Size = UDim2.new(1, -70, 0, 0)
            Controls.keybind(bindRow, {
                Default = self.flow.menuKey,
                Position = UDim2.new(1, 0, 0, 9),
                AnchorPoint = Vector2.new(1, 0.5),
                ZIndex = 4,
                Callback = function(key)
                    self.flow.menuKey = key
                end,
            })

            Craft.divider(panel, 5)

            -- nothing is forced on: every HUD widget can be switched off here
            Craft.text({
                Text = "Interface elements",
                Token = "textFaint",
                TextSize = 10.5,
                FontFace = Theme.font.bold,
                Size = UDim2.new(1, 0, 0, 12),
                LayoutOrder = 6,
                ZIndex = 3,
                Parent = panel,
            })

            local widgets = self.flow:HudWidgets()
            if #widgets == 0 then
                Craft.text({
                    Text = "No HUD widgets loaded.",
                    Token = "textFaint",
                    TextSize = 11.5,
                    Size = UDim2.new(1, 0, 0, 18),
                    LayoutOrder = 7,
                    ZIndex = 3,
                    Parent = panel,
                })
            end

            for i, widget in ipairs(widgets) do
                Controls.toggle(panel, {
                    Name = widget.Label,
                    Default = widget.Hidden ~= true,
                    LayoutOrder = 7 + i,
                    Callback = function(on)
                        widget:SetVisible(on)
                    end,
                })
            end

            Craft.divider(panel, 30)

            Craft.text({
                Text = "Sound",
                Token = "textFaint",
                TextSize = 10.5,
                FontFace = Theme.font.bold,
                Size = UDim2.new(1, 0, 0, 12),
                LayoutOrder = 31,
                ZIndex = 3,
                Parent = panel,
            })

            Controls.toggle(panel, {
                Name = "Sound effects",
                Default = Audio.enabled,
                LayoutOrder = 32,
                Callback = function(on)
                    Audio.enabled = on
                    if on then
                        Audio.play("click")
                    end
                end,
            })

            Controls.slider(panel, {
                Name = "Volume",
                Min = 0,
                Max = 1,
                Step = 0.05,
                Default = Audio.volume,
                LayoutOrder = 33,
                Callback = function(v)
                    Audio.volume = v
                end,
            })

            Craft.divider(panel, 34)

            Craft.text({
                Text = "Configs",
                Token = "textFaint",
                TextSize = 10.5,
                FontFace = Theme.font.bold,
                Size = UDim2.new(1, 0, 0, 12),
                LayoutOrder = 35,
                ZIndex = 3,
                Parent = panel,
            })

            local nameField = Controls.input(panel, {
                Placeholder = "config name",
                Default = self.flow.configName or "default",
                LayoutOrder = 36,
                Height = 30,
            })

            Controls.buttons(panel, {
                LayoutOrder = 37,
                Height = 30,
                Buttons = {
                    {
                        Name = "Save",
                        Icon = "check",
                        Accent = true,
                        Callback = function()
                            local ok, err = State.save(nameField.Value, self.flow:layout())
                            self.flow.configName = nameField.Value
                            Notify.push({
                                Title = ok and "Config saved" or "Save failed",
                                Text = ok and nameField.Value or err,
                                Icon = ok and "check" or "alert",
                                Kind = ok and "success" or "danger",
                            })
                        end,
                    },
                    {
                        Name = "Load",
                        Icon = "folder",
                        Callback = function()
                            local ok, data = State.load(nameField.Value)
                            if ok then
                                self.flow:restore(data)
                            end
                            Notify.push({
                                Title = ok and "Config loaded" or "Load failed",
                                Text = ok and nameField.Value or tostring(data),
                                Icon = ok and "check" or "alert",
                                Kind = ok and "success" or "danger",
                            })
                        end,
                    },
                },
            })
        end,
    })
end

return Window
end

--[[
    Legacy API shim.

    Scripts written against the previous Flow library carried one nesting level
    more than this one:

        Library.new{...}          ->  Flow.new{...} + ui:Window{...}
        Window:CreateSection{...} ->  (no level of its own; supplies a fallback icon)
        Section:AddTab{...}       ->  win:Tab{...}
        Tab:AddGroup{Side=...}    ->  tab:Module{Column=1|2}
        Group:AddToggle{...}      ->  card:Toggle{...}

    A Module card owns an on/off switch and a keybind chip; an old Group was a
    plain titled box. Group-backed cards therefore hide both and stay enabled, so
    a card that was never meant to toggle cannot be switched off and silently
    kill the controls inside it.

    Control objects are augmented in place rather than wrapped, so `.Value`,
    `.Frame` and `:Set(v, silent)` keep working next to the legacy `:Get()` and
    `:UpdateOptions()` helpers.

    Reached as `loadstring(game:HttpGet(url))().Legacy` — kept off `Flow.new` so
    the two `.new({...})` signatures can never be confused for one another.
]]
__flowStartupCheckpoint()
__modules["ui/legacy"] = function(require)
__flowStartupCheckpoint()
local Luarmor = require("core/luarmor")

return function(Flow)
    local Compat = {}
    Compat.Flow = Flow

    -- the old library exposed these at its top level and scripts reach for them
    -- directly (`Library.Icons` and friends), so mirror them rather than
    -- handing back nil
    Compat.Version = Flow.Version
    Compat.Icons = Flow.Icons
    Compat.Theme = Flow.Theme
    Compat.Util = Flow.Util
    Compat.State = Flow.State
    Compat.Audio = Flow.Audio
    Compat.Luarmor = Flow.Luarmor
    Compat.Controls = Flow.Controls
    Compat.Protected = Flow.Protected

    -- background pollers started for dropdown auto-refresh, stopped on unload
    local refreshers = {}

    local function stopRefreshers()
        for i = #refreshers, 1, -1 do
            refreshers[i].alive = false
            refreshers[i] = nil
        end
    end

    local function schedule(interval, fn)
        local handle = { alive = true }
        table.insert(refreshers, handle)
        task.spawn(function()
            while handle.alive do
                task.wait(interval)
                if not handle.alive then
                    return
                end
                pcall(fn)
            end
        end)
        return handle
    end

    -- old scripts pass bare numeric asset ids in a few places
    local function icon(...)
        for i = 1, select("#", ...) do
            local value = select(i, ...)
            if type(value) == "number" then
                return "rbxassetid://" .. tostring(value)
            end
            if type(value) == "string" and value ~= "" then
                return value
            end
        end
        return nil
    end

    -- `:Get()` and friends that the old control objects exposed
    local function augment(control)
        if type(control) ~= "table" then
            return control
        end
        if not control.Get then
            function control:Get()
                return self.Value
            end
        end
        if control.Options and not control.UpdateOptions then
            control.UpdateOptions = control.Options
            control.SetOptions = control.Options
            control.SetValues = control.Options

            --[[
                Scripts probe for whichever of these the old library happened to
                expose, in their own order:

                    if type(d.Refresh) == "function" then d:Refresh(list)
                    elseif type(d.SetOptions) == "function" then ...

                A no-op Refresh satisfies the first branch and swallows the
                update, leaving the list empty with nothing raised. So every name
                a script might reach for has to actually do the work.
            ]]
            function control:Refresh(list)
                if type(list) == "table" then
                    self:Options(list)
                elseif self.Pull then
                    self:Pull()
                end
            end

            -- and the rebuild-one-at-a-time shape
            function control:Clear()
                self.staged = {}
                self:Options({})
            end

            function control:Add(item)
                self.staged = self.staged or {}
                table.insert(self.staged, item)
                self:Options(self.staged)
            end
        end
        if not control.Refresh then
            -- a toggle or slider has nothing to refresh; keep the call safe
            function control:Refresh() end
        end
        return control
    end

    local function labelText(control, text)
        local head = control and control.Frame and control.Frame:FindFirstChild("Head")
        if not head then
            return
        end
        local desc = head:FindFirstChild("Desc")
        local title = head:FindFirstChild("Title")
        local target = (desc and desc.Text ~= "" and desc) or title or desc
        if target then
            target.Text = tostring(text)
        end
    end

    -- -----------------------------------------------------------------------
    -- Group  ->  Module card
    -- -----------------------------------------------------------------------

    local Group = {}
    Group.__index = Group

    function Group.new(card)
        return setmetatable({ card = card, Frame = card.Frame, Card = card }, Group)
    end

    function Group:AddToggle(opts)
        opts = opts or {}
        return augment(self.card:Toggle({
            Name = opts.Name,
            Desc = opts.Desc or opts.Description,
            Default = opts.Default,
            Flag = opts.Flag,
            Callback = opts.Callback,
        }))
    end

    function Group:AddSlider(opts)
        opts = opts or {}
        -- the slider derives its decimal places from the step, so `Decimals`
        -- only matters when it is finer than the increment
        local step = opts.Increment or opts.Step
        if opts.Decimals and opts.Decimals > 0 then
            local fromDecimals = 10 ^ -opts.Decimals
            if not step or step > fromDecimals then
                step = step or fromDecimals
            end
        end
        return augment(self.card:Slider({
            Name = opts.Name,
            Desc = opts.Desc or opts.Description,
            Min = opts.Min,
            Max = opts.Max,
            Default = opts.Default,
            Step = step,
            Suffix = opts.Suffix,
            Flag = opts.Flag,
            Callback = opts.Callback,
        }))
    end

    local function buildDropdown(self, opts, multi)
        opts = opts or {}
        local list = opts.Options
        if not list and type(opts.OptionsProvider) == "function" then
            local ok, provided = pcall(opts.OptionsProvider)
            list = (ok and type(provided) == "table") and provided or {}
        end

        local control = self.card:Dropdown({
            Name = opts.Name,
            Desc = opts.Desc or opts.Description,
            Options = list or {},
            Default = opts.Default,
            Multi = multi,
            Empty = opts.Empty,
            Flag = opts.Flag,
            Callback = opts.Callback,
        })

        -- the old library refreshed dropdown contents from a provider on a timer
        if type(opts.OptionsProvider) == "function" then
            local function flatten(values)
                local flat = {}
                for _, v in ipairs(values or {}) do
                    flat[#flat + 1] = tostring(v)
                end
                return table.concat(flat, "\0")
            end
            local last = flatten(list)
            local function pull()
                local ok, provided = pcall(opts.OptionsProvider)
                if not ok or type(provided) ~= "table" then
                    return
                end
                local key = flatten(provided)
                if key ~= last then
                    last = key
                    control:Options(provided)
                end
            end
            if opts.AutoRefresh then
                control.refresher = schedule(tonumber(opts.RefreshInterval) or 5, pull)
            end
            control.Pull = pull
        end

        return augment(control)
    end

    function Group:AddDropdown(opts)
        return buildDropdown(self, opts, false)
    end

    function Group:AddMultiDropdown(opts)
        return buildDropdown(self, opts, true)
    end

    function Group:AddButton(opts)
        opts = opts or {}
        return augment(self.card:Button({
            Name = opts.Name,
            Desc = opts.Desc or opts.Description,
            Icon = icon(opts.Icon),
            Accent = opts.Accent,
            Callback = opts.Callback,
        }))
    end

    function Group:AddLabel(opts)
        if type(opts) == "string" then
            opts = { Text = opts }
        end
        opts = opts or {}
        local text = opts.Text or opts.Name or ""
        local control = self.card:Label(opts.Wrap and { Desc = text } or { Name = text })
        control.Wrapped = opts.Wrap and true or false

        -- Craft.head always lays out a 17px title row; on a wrapped label that
        -- row is empty and would sit as a blank gap above the body copy
        if control.Wrapped then
            local head = control.Frame and control.Frame:FindFirstChild("Head")
            local title = head and head:FindFirstChild("Title")
            if title and title.Text == "" then
                title.Visible = false
            end
        end

        function control:SetText(value)
            labelText(self, value)
        end
        control.Set = control.SetText
        return control
    end

    function Group:AddDivider()
        return self.card:Divider()
    end

    function Group:AddKeybind(opts)
        opts = opts or {}
        local flow = self.card.flow
        -- old: Callback fires on press, ChangedCallback fires on rebind.
        -- new: OnPress fires on press, Callback fires on rebind.
        local control = self.card:Keybind({
            Name = opts.Name,
            Desc = opts.Desc or opts.Description,
            Default = opts.Default,
            Flag = opts.Flag,
            OnPress = opts.Callback,
            Callback = function(key)
                -- keep the Keybinds panel in step with a rebind
                if flow.hud and flow.hud.keybinds then
                    flow.hud.keybinds:Sync()
                end
                if opts.ChangedCallback then
                    opts.ChangedCallback(key)
                end
            end,
        })
        control.Mode = opts.Mode or "Toggle"

        -- list it on the Keybinds panel; a module header bind lands there
        -- automatically, a control one has to be registered
        table.insert(flow.binds, {
            Name = opts.Name or self.Name or "Keybind",
            Icon = icon(opts.Icon, self.Icon, "keyboard"),
            Control = control,
        })
        if flow.hud and flow.hud.keybinds then
            flow.hud.keybinds:Sync()
        end

        return augment(control)
    end

    function Group:AddColorPicker(opts)
        opts = opts or {}
        return augment(self.card:Color({
            Name = opts.Name,
            Desc = opts.Desc or opts.Description,
            Default = opts.Default,
            Presets = opts.Presets,
            Flag = opts.Flag,
            Callback = opts.Callback,
        }))
    end

    local function buildInput(self, opts)
        opts = opts or {}
        return augment(self.card:Input({
            Name = opts.Name,
            Desc = opts.Desc or opts.Description,
            Placeholder = opts.Placeholder,
            Default = opts.Default,
            Flag = opts.Flag,
            -- old `EnterOnly` means "only fire once the user commits with return"
            OnEnter = opts.EnterOnly and true or nil,
            Callback = opts.Callback,
        }))
    end

    function Group:AddTextInput(opts)
        return buildInput(self, opts)
    end

    function Group:AddTextbox(opts)
        return buildInput(self, opts)
    end

    function Group:AddInput(opts)
        return buildInput(self, opts)
    end

    -- a few scripts nest named pages inside a group. There is no level below a
    -- card, so each page becomes its own sibling card titled "<Group> · <Page>",
    -- keeping the controls grouped and in the same column.
    function Group:AddTabs(names)
        local pages = {}
        for _, name in ipairs(names or {}) do
            pages[name] = self.tab:AddGroup({
                Name = self.Name and (self.Name .. " · " .. name) or name,
                Side = self.Side,
                Icon = self.Icon,
            })
        end
        return pages
    end

    function Group:Set(state)
        self.card:Set(state)
    end

    function Group:Destroy()
        self.card.Frame:Destroy()
    end

    -- -----------------------------------------------------------------------
    -- Tab
    -- -----------------------------------------------------------------------

    local Tab = {}
    Tab.__index = Tab

    function Tab.new(tab, sectionIcon)
        return setmetatable({ tab = tab, Frame = tab.Frame, sectionIcon = sectionIcon }, Tab)
    end

    function Tab:AddGroup(opts)
        if type(opts) == "string" then
            opts = { Name = opts }
        end
        opts = opts or {}

        local card = self.tab:Module({
            Name = opts.Name or "Group",
            Icon = icon(opts.Icon, opts.FallbackIcon, self.sectionIcon, "cube"),
            Column = (opts.Side == "Right") and 2 or 1,
            Default = true,
            Expanded = true,
        })

        -- an old Group is a plain container: no switch, no keybind chip, and it
        -- can never be turned off from the header
        if card.Switch and card.Switch.Frame then
            card.Switch.Frame.Visible = false
        end
        if card.BindControl and card.BindControl.Frame then
            card.BindControl.Frame.Visible = false
        end
        card.Enabled = true

        local group = Group.new(card)
        group.Name = opts.Name
        group.Side = opts.Side
        group.Icon = opts.Icon
        group.tab = self
        return group
    end

    function Tab:Select()
        self.tab.window:Select(self.tab)
    end

    -- -----------------------------------------------------------------------
    -- Section — collapses away; only its icon survives as a per-tab fallback
    -- -----------------------------------------------------------------------

    local Section = {}
    Section.__index = Section

    function Section.new(window, opts)
        return setmetatable({
            window = window,
            Name = opts.Name or opts.Title,
            Icon = icon(opts.Icon, opts.FallbackIcon),
        }, Section)
    end

    function Section:AddTab(opts)
        opts = opts or {}
        local name = opts.Name or "Tab"

        -- two sections can each own a tab called "Main"; with the section level
        -- gone those would collide in one strip, so the section name splits them
        local taken = self.window.tabNames
        if taken[name] and self.Name then
            name = self.Name .. " · " .. name
        end
        taken[name] = true

        local tab = self.window.win:Tab({
            Name = name,
            Icon = icon(opts.Icon, opts.FallbackIcon, self.Icon, "cube"),
        })

        -- `Description` was a subtitle under the old tab name. The strip is a
        -- single row of labelled buttons with nowhere to put it, and Tab carries
        -- no search terms of its own, so it is dropped rather than faked.

        local proxy = Tab.new(tab, self.Icon)
        if opts.Default then
            self.window.win:Select(tab)
        end
        return proxy
    end

    -- -----------------------------------------------------------------------
    -- Window — what Library.new() returned
    --
    -- The old library table *was* the window class: scripts called
    -- `Library.new(...)` and the result answered `:CreateSection`, `:Notify`
    -- and `:Destroy`. Some scripts validate the download by checking for those
    -- very fields, so Compat is the class rather than a separate table.
    -- -----------------------------------------------------------------------

    Compat.__index = Compat

    function Compat.new(opts)
        opts = opts or {}

        local ui = Flow.new({
            Accent = opts.AccentColor,
            Key = opts.ToggleKey,
            Folder = opts.Folder or "flow",
            Scale = opts.Scale,
            Sound = opts.Sound,
            Volume = opts.Volume,
        })

        -- the old library previewed a key state through its own options
        if opts.LuarmorSecondsLeft then
            Luarmor.override = { SecondsLeft = opts.LuarmorSecondsLeft }
        end

        local title = opts.Name or opts.Title or "FLOW"

        local win = ui:Window({
            Title = title,
            Build = opts.Subtitle or opts.Build,
            Size = opts.Size,
            -- old groups pick a side, so two lanes reproduce that exactly
            Columns = opts.Columns or 2,
            MinColumns = opts.MinColumns or 1,
            User = opts.User,
            Mark = opts.Mark,
        })

        --[[
            The old library built a status pill at top centre on its own — script
            name, ping and fps, doubling as the menu toggle. HUD widgets are
            opt-in here, so a converted script would come up with none at all and
            "No HUD widgets loaded" under Interface elements.

            Trigger is that top-centre toggle; Watermark carries the ping/fps
            readout the old pill showed alongside it. Both appear as switches in
            settings, so anyone who does not want them can turn them off, and the
            choice is saved with the config.
        ]]
        if opts.Hud ~= false then
            pcall(function()
                ui:Trigger({ Text = title })
            end)
            pcall(function()
                ui:Watermark({ Name = opts.User, Tag = opts.Tag })
            end)
            pcall(function()
                ui:Keybinds()
            end)
        end

        return setmetatable({
            ui = ui,
            win = win,
            Flow = Flow,
            Options = ui.Options,
            tabNames = {},
        }, Compat)
    end

    function Compat:CreateSection(opts)
        if type(opts) == "string" then
            opts = { Name = opts }
        end
        return Section.new(self, opts or {})
    end

    function Compat:SetToggleKey(key)
        self.ui.menuKey = key
        return self
    end

    function Compat:Notify(opts)
        opts = opts or {}
        return self.ui:Notify({
            Title = opts.Title,
            Text = opts.Description or opts.Content or opts.Text or opts.SubText,
            Icon = icon(opts.Icon),
            Kind = opts.Kind,
            Duration = opts.Duration,
        })
    end

    function Compat:SetAccentColor(color)
        self.ui:SetAccent(color)
    end

    function Compat:Toggle(state)
        self.ui:ToggleMenu(state)
    end

    function Compat:Get(flag)
        return self.ui:Get(flag)
    end

    function Compat:Set(flag, value)
        return self.ui:Set(flag, value)
    end

    function Compat:Destroy()
        stopRefreshers()
        self.ui:Unload()
    end

    Compat.Unload = Compat.Destroy

    -- callable as both Legacy.new{...} and Legacy{...}
    setmetatable(Compat, {
        __call = function(_, opts)
            return Compat.new(opts)
        end,
    })

    return Compat
end
end

return __require("init")
