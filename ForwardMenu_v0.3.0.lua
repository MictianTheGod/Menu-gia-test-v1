--[[
    ForwardMenu v0.3.0
    Aimware v5.1.13 / LuaJIT

    UI / telemetry shell ONLY.
    No aimbot, anti-aim, rage, resolver, trigger, movement automation,
    CreateMove manipulation, view-angle writes, packet manipulation, or
    gameplay advantage logic is present in this file.

    Visual target:
      - dark GameSense-inspired developer-tool shell
      - Forward Loader visual language
      - compact left navigation
      - dense group-box controls
      - animated hover / selection / sliders
      - read-only diagnostics and UI settings

    Safe callbacks used:
      Draw, Unload
]]

local MODULE_ID = "ForwardMenu"
local VERSION = "0.3.0"
local SAFE_MODE = true

------------------------------------------------------------
-- THEME
------------------------------------------------------------
local Theme = {
    bg              = {9, 9, 9, 255},
    window          = {14, 14, 14, 255},
    sidebar         = {16, 16, 16, 255},
    header          = {15, 15, 15, 255},
    group           = {20, 20, 20, 255},
    group2          = {23, 23, 23, 255},
    control         = {27, 27, 27, 255},
    control_hover   = {34, 34, 34, 255},
    control_press   = {39, 39, 39, 255},
    border          = {43, 43, 43, 255},
    border2         = {55, 55, 55, 255},
    text            = {238, 238, 238, 255},
    text2           = {204, 204, 204, 255},
    muted           = {139, 139, 139, 255},
    muted2          = {99, 99, 99, 255},
    accent          = {118, 210, 0, 255},
    accent_dim      = {77, 139, 0, 255},
    accent_soft     = {118, 210, 0, 22},
    accent_glow     = {118, 210, 0, 45},
    warn            = {225, 165, 55, 255},
    danger          = {210, 70, 70, 255},
    white_soft      = {255, 255, 255, 18},
    shadow          = {0, 0, 0, 105},
}

------------------------------------------------------------
-- STATE
------------------------------------------------------------
local menu = {
    open = true,
    x = 205,
    y = 105,
    w = 930,
    h = 650,

    nav_w = 224,
    header_h = 54,

    tab = 1,
    nav_hover = -1,
    control_hover = nil,

    mouse_down = false,
    mouse_pressed = false,
    mouse_released = false,
    dragging = false,
    drag_dx = 0,
    drag_dy = 0,

    settings_open = false,
    toast = nil,
    toast_at = 0,

    ui_scale = 1,
    accent_preset = 1,
    animations = true,
    compact = false,

    telemetry = true,
    frame_overlay = true,
    fps_counter = true,
    network_monitor = true,
    event_logger = true,
    auto_record = false,

    graph_scale = 50,
    sample_rate = 64,
    graph_mode = 1,
    event_filter = 1,
    inspector_object = 1,
    profiler_mode = 1,
    refresh_rate = 60,

    selected_event = 1,
    selected_module = 1,
}

local timing = {
    last = globals.RealTime(),
    now = globals.RealTime(),
    dt = 0,
}

local anim = {
    tab = 1,
    sidebar_fade = 0,
    hover = {},
    press = {},
    slider = {},
    pulse = 0,
}

------------------------------------------------------------
-- DATA
------------------------------------------------------------
local Tabs = {
    {id="dashboard", name="Dashboard", group="GENERAL", glyph="D"},
    {id="telemetry", name="Telemetry", group="MONITOR", glyph="T"},
    {id="network", name="Network", group="MONITOR", glyph="N"},
    {id="events", name="Events", group="MONITOR", glyph="E"},
    {id="inspector", name="Inspector", group="TOOLS", glyph="I"},
    {id="profiler", name="Profiler", group="TOOLS", glyph="P"},
    {id="configs", name="Configs", group="MISC", glyph="C"},
    {id="ui", name="Interface", group="MISC", glyph="U"},
    {id="lua", name="Lua", group="MISC", glyph="L"},
    {id="about", name="About", group="MISC", glyph="A"},
}

local Modules = {
    {id="telemetry", title="Telemetry", desc="Timing and frame diagnostics", enabled=true},
    {id="network", title="Network", desc="Read-only network statistics", enabled=true},
    {id="events", title="Events", desc="Local event timeline", enabled=true},
    {id="inspector", title="Inspector", desc="Read-only runtime state", enabled=true},
    {id="profiler", title="Profiler", desc="UI execution timing", enabled=true},
    {id="recorder", title="Recorder", desc="Local session snapshots", enabled=true},
}

local EventLog = {
    {t=0, level="OK", msg="ForwardMenu initialized"},
    {t=0, level="INFO", msg="Safe UI mode enabled"},
    {t=0, level="OK", msg="Draw callback registered"},
}

------------------------------------------------------------
-- UTILS
------------------------------------------------------------
local function clamp(v, a, b)
    if v < a then return a end
    if v > b then return b end
    return v
end

local function lerp(a, b, t)
    return a + (b - a) * t
end

local function smooth(current, target, speed)
    local dt = timing.dt
    if dt <= 0 then return current end
    local f = 1 - math.exp(-speed * dt)
    return current + (target - current) * clamp(f, 0, 1)
end

local function in_box(mx, my, x, y, w, h)
    return mx >= x and mx <= x + w and my >= y and my <= y + h
end

local function color(c, a)
    draw.Color(c[1], c[2], c[3], a or c[4] or 255)
end

local function fill(x1, y1, x2, y2, c, a)
    color(c, a)
    draw.FilledRect(x1, y1, x2, y2)
end

local function outline(x1, y1, x2, y2, c, a)
    color(c, a)
    draw.OutlinedRect(x1, y1, x2, y2)
end

local function round_fill(x1, y1, x2, y2, r, c, a)
    color(c, a)
    draw.RoundedRectFill(x1, y1, x2, y2, r, 1, 1, 1, 1)
end

local function round_outline(x1, y1, x2, y2, r, c, a)
    color(c, a)
    draw.RoundedRect(x1, y1, x2, y2, r, 1, 1, 1, 1)
end

local function txt(font, x, y, value, c, shadow)
    if not font then return end
    draw.SetFont(font)
    color(c or Theme.text)
    if shadow then
        draw.TextShadow(math.floor(x), math.floor(y), tostring(value))
    else
        draw.Text(math.floor(x), math.floor(y), tostring(value))
    end
end

local function txt_size(font, value)
    draw.SetFont(font)
    return draw.GetTextSize(tostring(value))
end

local function txt_center(font, cx, y, value, c)
    local w = txt_size(font, value)
    txt(font, cx - w * 0.5, y, value, c)
end

local function txt_vcenter(font, x, y, h, value, c)
    local _, th = txt_size(font, value)
    txt(font, x, y + (h - th) * 0.5, value, c)
end

local function safe_font(name, size, weight)
    local ok, f = pcall(draw.CreateFont, name, size, weight)
    if ok and f then return f end
    ok, f = pcall(draw.CreateFont, "Verdana", size, weight)
    if ok and f then return f end
    return nil
end

local Fonts = {}
local function init_fonts()
    Fonts.title = safe_font("Bahnschrift", 20, 700)
    Fonts.h2 = safe_font("Bahnschrift", 15, 700)
    Fonts.body = safe_font("Bahnschrift", 13, 600)
    Fonts.small = safe_font("Verdana", 10, 600)
    Fonts.tiny = safe_font("Verdana", 9, 600)
    Fonts.mono = safe_font("Consolas", 10, 500)
    Fonts.icon = safe_font("Verdana", 11, 700)
end

------------------------------------------------------------
-- TIMING / INPUT
------------------------------------------------------------
local function update_time()
    local now = globals.RealTime()
    local dt = globals.AbsoluteFrameTime()
    if not dt or dt <= 0 or dt > 0.1 then dt = now - timing.last end
    timing.dt = clamp(dt or 0, 0, 0.05)
    timing.now = now
    timing.last = now
end

local function update_mouse(mx, my)
    local down = input.IsButtonDown(1)
    menu.mouse_pressed = down and not menu.mouse_down
    menu.mouse_released = (not down) and menu.mouse_down
    menu.mouse_down = down
end

local function toast(msg, level)
    menu.toast = {msg=tostring(msg), level=level or "INFO"}
    menu.toast_at = timing.now
end

local function event(level, msg)
    EventLog[#EventLog + 1] = {t=timing.now, level=level, msg=tostring(msg)}
    if #EventLog > 32 then table.remove(EventLog, 1) end
end

local function level_color(level)
    if level == "OK" then return Theme.accent end
    if level == "WARN" then return Theme.warn end
    if level == "ERROR" then return Theme.danger end
    return Theme.text2
end

------------------------------------------------------------
-- ANIMATION
------------------------------------------------------------
local function update_animation()
    anim.tab = smooth(anim.tab, menu.tab, 15)
    anim.sidebar_fade = smooth(anim.sidebar_fade, menu.open and 1 or 0, 18)
    anim.pulse = 0.5 + 0.5 * math.sin(timing.now * 3.0)
end

local function hover_anim(key, target)
    local old = anim.hover[key] or 0
    local value = smooth(old, target and 1 or 0, 18)
    anim.hover[key] = value
    return value
end

local function slider_anim(key, target)
    local old = anim.slider[key]
    if old == nil then old = target end
    anim.slider[key] = smooth(old, target, 18)
    return anim.slider[key]
end

------------------------------------------------------------
-- WINDOW GEOMETRY
------------------------------------------------------------
local function content_rect()
    local x = menu.x + menu.nav_w
    local y = menu.y + menu.header_h
    local w = menu.w - menu.nav_w
    local h = menu.h - menu.header_h
    return x, y, w, h
end

local function group_box(x, y, w, h, title, subtitle)
    round_fill(x, y, x+w, y+h, 4, Theme.group)
    round_outline(x, y, x+w, y+h, 4, Theme.border)
    txt(Fonts.h2, x+12, y+10, title, Theme.text)
    if subtitle then txt(Fonts.tiny, x+12, y+29, subtitle, Theme.muted) end
end

local function section_title(x, y, title, subtitle)
    txt(Fonts.title, x, y, title, Theme.text)
    if subtitle then txt(Fonts.small, x, y+27, subtitle, Theme.muted) end
end

------------------------------------------------------------
-- CONTROLS
------------------------------------------------------------
local function control_bg(x, y, w, h, key, clicked)
    local mx, my = input.GetMousePos()
    local hov = in_box(mx, my, x, y, w, h)
    local hv = hover_anim(key, hov)
    local bg = Theme.control
    if clicked then bg = Theme.control_press elseif hv > 0.01 then
        bg = {math.floor(lerp(Theme.control[1], Theme.control_hover[1], hv)),
              math.floor(lerp(Theme.control[2], Theme.control_hover[2], hv)),
              math.floor(lerp(Theme.control[3], Theme.control_hover[3], hv)), 255}
    end
    round_fill(x, y, x+w, y+h, 3, bg)
    round_outline(x, y, x+w, y+h, 3, hv > 0.01 and Theme.border2 or Theme.border)
    return hov
end

local function checkbox(x, y, w, label, state, key, sub)
    local h = sub and 42 or 34
    local hov = control_bg(x, y, w, h, key, false)
    if menu.mouse_pressed and hov then return not state end
    txt_vcenter(Fonts.body, x+10, y, h, label, state and Theme.text or Theme.text2)
    if sub then txt(Fonts.tiny, x+10, y+25, sub, Theme.muted2) end

    local sx, sy, sw, sh = x+w-45, y+8, 33, 18
    round_fill(sx, sy, sx+sw, sy+sh, 9, state and Theme.accent_dim or Theme.group2)
    round_outline(sx, sy, sx+sw, sy+sh, 9, state and Theme.accent or Theme.border2)
    local kx = state and sx+sw-9 or sx+9
    color(state and Theme.text or Theme.muted)
    draw.FilledCircle(kx, sy+9, 5)
    return state
end

local function slider(x, y, w, label, value, mn, mx, key, format)
    txt(Fonts.small, x, y, label, Theme.muted)
    local shown = format and format(value) or tostring(value)
    local sw = txt_size(Fonts.small, shown)
    txt(Fonts.small, x+w-sw, y, shown, Theme.text2)

    local bar_y = y+22
    fill(x, bar_y, x+w, bar_y+2, Theme.border2)
    local n = clamp((value-mn)/(mx-mn), 0, 1)
    local animated = slider_anim(key, n)
    fill(x, bar_y, x+w*animated, bar_y+2, Theme.accent)
    color(Theme.accent, 32)
    draw.FilledCircle(x+w*animated, bar_y+1, 7)
    color(Theme.accent)
    draw.FilledCircle(x+w*animated, bar_y+1, 3)

    local mx, my = input.GetMousePos()
    if menu.mouse_down and in_box(mx, my, x-4, bar_y-8, w+8, 18) and not menu.dragging then
        local nn = clamp((mx-x)/w, 0, 1)
        return math.floor(mn + (mx-x)/w*(mx-mn) + 0.5)
    end
    return value
end

local function combo(x, y, w, label, options, selected, key)
    txt(Fonts.small, x, y, label, Theme.muted)
    local by = y+16
    local hov = control_bg(x, by, w, 28, key, false)
    local value = options[selected] or options[1]
    txt_vcenter(Fonts.body, x+10, by, 28, value, Theme.text2)
    txt(Fonts.body, x+w-18, by+7, "v", Theme.muted)

    if menu.mouse_pressed and hov then
        selected = selected + 1
        if selected > #options then selected = 1 end
        event("INFO", label .. " -> " .. value)
    end
    return selected
end

local function button(x, y, w, label, key, accent)
    local hov = control_bg(x, y, w, 30, key, false)
    txt_center(Fonts.small, x+w*0.5, y+9, label, accent and Theme.accent or Theme.text2)
    return menu.mouse_pressed and hov
end

local function badge(x, y, label, c)
    local tw = txt_size(Fonts.tiny, label)
    round_fill(x, y, x+tw+18, y+20, 10, c, 28)
    round_outline(x, y, x+tw+18, y+20, 10, c, 110)
    txt_center(Fonts.tiny, x+(tw+18)*0.5, y+6, label, c)
end

local function mini_stat(x, y, w, label, value, c)
    round_fill(x, y, x+w, y+64, 4, Theme.group)
    round_outline(x, y, x+w, y+64, 4, Theme.border)
    txt(Fonts.tiny, x+10, y+9, label, Theme.muted)
    txt(Fonts.h2, x+10, y+30, value, c or Theme.text)
end

------------------------------------------------------------
-- GRAPH
------------------------------------------------------------
local function graph(x, y, w, h, title, phase, mode)
    round_fill(x, y, x+w, y+h, 4, Theme.group)
    round_outline(x, y, x+w, y+h, 4, Theme.border)
    txt(Fonts.h2, x+12, y+10, title, Theme.text)
    txt(Fonts.tiny, x+w-70, y+12, mode or "LIVE", Theme.muted2)

    local gx, gy = x+12, y+38
    local gw, gh = w-24, h-50
    for i=1,4 do
        local yy = gy + gh*(i/5)
        fill(gx, yy, gx+gw, yy+1, Theme.border, 100)
    end

    local px = gx
    local py = gy + gh*0.5
    color(Theme.accent)
    for i=1,50 do
        local t=(i-1)/49
        local wave = 0.5 + math.sin(timing.now*(1.0+phase*0.2)+t*8+phase)*0.18
            + math.sin(timing.now*1.7+t*19+phase)*0.06
        wave = clamp(wave,0.05,0.95)
        local nx=gx+gw*t
        local ny=gy+gh*(1-wave)
        draw.Line(px,py,nx,ny)
        px,py=nx,ny
    end
    color(Theme.accent, 32)
    draw.FilledCircle(px,py,7)
    color(Theme.accent)
    draw.FilledCircle(px,py,3)
end

------------------------------------------------------------
-- SIDEBAR / HEADER
------------------------------------------------------------
local function draw_header()
    local x,y,w = menu.x, menu.y, menu.w
    fill(x, y, x+w, y+menu.header_h, Theme.header)
    fill(x, y+menu.header_h-1, x+w, y+menu.header_h, Theme.border)

    round_fill(x+14, y+15, x+36, y+37, 4, Theme.accent)
    txt_center(Fonts.icon, x+25, y+21, "F", Theme.bg)
    txt_vcenter(Fonts.body, x+47, y, menu.header_h, "ForwardTrack", Theme.text)
    txt_vcenter(Fonts.tiny, x+140, y, menu.header_h, "developer tools", Theme.muted)

    local sx=x+w-182
    round_fill(sx, y+15, sx+70, y+39, 12, Theme.group2)
    color(Theme.accent, 35)
    draw.FilledCircle(sx+13,y+27,6)
    color(Theme.accent)
    draw.FilledCircle(sx+13,y+27,3)
    txt_vcenter(Fonts.tiny,sx+24,y+15,24,"ONLINE",Theme.text2)

    local bx=x+w-103
    round_fill(bx,y+10,bx+34,y+44,4,menu.settings_open and Theme.control_hover or Theme.header)
    txt_center(Fonts.body,bx+17,y+19,"=",menu.settings_open and Theme.accent or Theme.muted)

    local cx=x+w-59
    round_fill(cx,y+10,cx+34,y+44,4,Theme.header)
    txt_center(Fonts.body,cx+17,y+19,"x",Theme.muted)
end

local function draw_sidebar()
    local x,y,w,h=menu.x,menu.y,menu.nav_w,menu.h
    fill(x,y,x+w,y+h,Theme.sidebar)
    fill(x+w-1,y,x+w,y+h,Theme.border)

    txt(Fonts.title,x+18,y+20,"FORWARD",Theme.text)
    txt(Fonts.tiny,x+19,y+43,"diagnostics",Theme.accent)

    local cy=y+80
    local group=nil
    local mx,my=input.GetMousePos()

    for i,t in ipairs(Tabs) do
        if t.group~=group then
            if group~=nil then cy=cy+12 end
            txt(Fonts.tiny,x+18,cy,t.group,Theme.muted2)
            cy=cy+18
            group=t.group
        end

        local rh=31
        local hov=in_box(mx,my,x+9,cy,w-18,rh)
        local hv=hover_anim("nav"..i,hov)
        local selected=(menu.tab==i)

        if selected then
            round_fill(x+9,cy,x+w-9,cy+rh,4,Theme.group2)
            fill(x+9,cy+4,x+11,cy+rh-4,Theme.accent,190+math.floor(anim.pulse*45))
        elseif hv>0.01 then
            round_fill(x+9,cy,x+w-9,cy+rh,4,Theme.group2,math.floor(70*hv))
        end

        txt_vcenter(Fonts.icon,x+19,cy,rh,t.glyph,selected and Theme.accent or Theme.muted)
        txt_vcenter(Fonts.body,x+42,cy,rh,t.name,selected and Theme.text or Theme.text2)
        cy=cy+rh+2
    end

    txt(Fonts.tiny,x+18,y+h-72,"ForwardMenu",Theme.muted)
    txt(Fonts.mono,x+18,y+h-53,"v"..VERSION,Theme.muted2)
    badge(x+18,y+h-31,"SAFE MODE",Theme.accent)
end

local function handle_sidebar()
    local x,y,w=menu.x,menu.y,menu.nav_w
    local cy=y+80
    local group=nil
    local mx,my=input.GetMousePos()
    for i,t in ipairs(Tabs) do
        if t.group~=group then
            if group~=nil then cy=cy+12 end
            cy=cy+18
            group=t.group
        end
        if in_box(mx,my,x+9,cy,w-18,31) and menu.mouse_pressed then
            menu.tab=i
            menu.settings_open=false
            event("INFO","Opened "..t.name)
            return true
        end
        cy=cy+33
    end
    return false
end

local function handle_header()
    local x,y,w=menu.x,menu.y,menu.w
    local mx,my=input.GetMousePos()
    local settings=x+w-103
    local close=x+w-59
    if menu.mouse_pressed and in_box(mx,my,settings,y+10,34,34) then
        menu.settings_open=not menu.settings_open
        toast(menu.settings_open and "Interface settings opened" or "Interface settings closed","INFO")
        return true
    end
    if menu.mouse_pressed and in_box(mx,my,close,y+10,34,34) then
        menu.open=false
        return true
    end
    return false
end

local function update_drag()
    local mx,my=input.GetMousePos()
    local header=in_box(mx,my,menu.x,menu.y,menu.w,menu.header_h)
    local blocked=mx>menu.x+menu.w-200

    if menu.mouse_pressed and header and not blocked then
        menu.dragging=true
        menu.drag_dx=mx-menu.x
        menu.drag_dy=my-menu.y
    end

    if not menu.mouse_down then menu.dragging=false end

    if menu.dragging then
        local sw,sh=draw.GetScreenSize()
        menu.x=clamp(mx-menu.drag_dx,8,sw-menu.w-8)
        menu.y=clamp(my-menu.drag_dy,8,sh-menu.h-8)
    end
end

------------------------------------------------------------
-- PAGES
------------------------------------------------------------
local function page_dashboard(x,y,w,h)
    section_title(x,y,"Forward Diagnostics","read-only telemetry / interface shell")
    badge(x+w-86,y+1,"SAFE",Theme.accent)

    local gy=y+58
    local left=math.floor((w-16)*0.58)
    graph(x,gy,left,214,"Frame telemetry",1,"LIVE")

    local rx=x+left+16
    local rw=w-left-16
    group_box(rx,gy,rw,214,"System","runtime state")
    local rows={{"Renderer","OK",Theme.accent},{"Draw callback","OK",Theme.accent},{"Input","READY",Theme.accent},{"Telemetry",menu.telemetry and "ACTIVE" or "OFF",menu.telemetry and Theme.accent or Theme.muted},{"Automation","DISABLED",Theme.accent}}
    for i,r in ipairs(rows) do
        local yy=gy+50+(i-1)*31
        color(r[3],35); draw.FilledCircle(rx+18,yy+5,6)
        color(r[3]); draw.FilledCircle(rx+18,yy+5,3)
        txt(Fonts.small,rx+31,yy,r[1],Theme.muted)
        txt(Fonts.small,rx+rw-62,yy,r[2],r[3])
    end

    local sy=gy+230
    local sw=math.floor((w-16)/2)
    mini_stat(x,sy,sw,"FPS",string.format("%.0f",1/math.max(timing.dt,0.001)),Theme.text)
    mini_stat(x+sw+16,sy,sw,"FRAME",string.format("%.2f ms",timing.dt*1000),Theme.text)

    local my=sy+78
    group_box(x,my,w,105,"Safe module state","gameplay-affecting APIs are not part of this UI")
    txt(Fonts.small,x+14,my+49,"Gameplay automation",Theme.muted)
    txt(Fonts.body,x+140,my+47,"DISABLED",Theme.accent)
    txt(Fonts.small,x+w-190,my+49,"callbacks",Theme.muted)
    txt(Fonts.mono,x+w-125,my+47,"Draw / Unload",Theme.text2)
end

local function page_telemetry(x,y,w,h)
    section_title(x,y,"Telemetry","frame timing, sampling and UI diagnostics")
    local gy=y+58
    local left=math.floor(w*0.54)
    group_box(x,gy,left,315,"Sampling","safe local diagnostics")

    menu.telemetry=checkbox(x+12,gy+48,left-24,"Enable telemetry",menu.telemetry,"tel")
    menu.frame_overlay=checkbox(x+12,gy+88,left-24,"Frame overlay",menu.frame_overlay,"overlay")
    menu.fps_counter=checkbox(x+12,gy+128,left-24,"FPS counter",menu.fps_counter,"fps")
    menu.network_monitor=checkbox(x+12,gy+168,left-24,"Network monitor",menu.network_monitor,"network")
    menu.event_logger=checkbox(x+12,gy+208,left-24,"Event logger",menu.event_logger,"events")
    menu.auto_record=checkbox(x+12,gy+248,left-24,"Auto record",menu.auto_record,"record","local session only")

    local rx=x+left+16
    local rw=w-left-16
    group_box(rx,gy,rw,315,"Parameters","runtime sampling")
    menu.graph_scale=slider(rx+12,gy+52,rw-24,"Graph scale",menu.graph_scale,0,100,"graph_scale")
    menu.sample_rate=slider(rx+12,gy+108,rw-24,"Sample rate",menu.sample_rate,16,128,"sample_rate")
    menu.graph_mode=combo(rx+12,gy+170,rw-24,"Graph mode",{"Line","Bars","History"},menu.graph_mode,"graph_mode")
    menu.refresh_rate=combo(rx+12,gy+228,rw-24,"UI refresh",{30,60,120,144},menu.refresh_rate==30 and 1 or menu.refresh_rate==60 and 2 or menu.refresh_rate==120 and 3 or 4,"refresh")

    graph(x,gy+332,w,145,"Timing preview",2,"READ ONLY")
end

local function page_network(x,y,w,h)
    section_title(x,y,"Network","read-only timing information")
    local gy=y+58
    local half=math.floor((w-16)/2)
    graph(x,gy,half,210,"Latency history",2,"LOCAL")
    graph(x+half+16,gy,half,210,"Tick timing",3,"LOCAL")

    group_box(x,gy+226,w,180,"Snapshot","no network writes")
    local vals={
        {"TickCount",tostring(globals.TickCount())},
        {"TickInterval",string.format("%.6f s",globals.TickInterval())},
        {"RealTime",string.format("%.2f s",globals.RealTime())},
        {"FrameCount",tostring(globals.FrameCount())},
        {"MaxClients",tostring(globals.MaxClients())},
        {"FrameTime",string.format("%.6f s",globals.AbsoluteFrameTime())},
    }
    for i,v in ipairs(vals) do
        local col=(i-1)%3
        local row=math.floor((i-1)/3)
        local xx=x+14+col*math.floor((w-28)/3)
        local yy=gy+272+row*58
        txt(Fonts.tiny,xx,yy,v[1],Theme.muted)
        txt(Fonts.mono,xx,yy+19,v[2],Theme.text)
    end
end

local function page_events(x,y,w,h)
    section_title(x,y,"Events","local timeline and filter controls")
    local gy=y+58
    local left=math.floor(w*0.68)
    group_box(x,gy,left,420,"Timeline","latest local events")
    txt(Fonts.tiny,x+14,gy+42,"TIME",Theme.muted2)
    txt(Fonts.tiny,x+85,gy+42,"LEVEL",Theme.muted2)
    txt(Fonts.tiny,x+154,gy+42,"MESSAGE",Theme.muted2)
    local yy=gy+64
    local start=math.max(1,#EventLog-14)
    for i=start,#EventLog do
        local e=EventLog[i]
        fill(x+12,yy-6,x+left-12,yy-5,Theme.border,90)
        txt(Fonts.mono,x+14,yy,string.format("%07.2f",e.t),Theme.muted2)
        txt(Fonts.tiny,x+85,yy,"["..e.level.."]",level_color(e.level))
        txt(Fonts.small,x+154,yy,e.msg,Theme.text2)
        yy=yy+23
    end

    local rx=x+left+16
    local rw=w-left-16
    group_box(rx,gy,rw,420,"Filters","presentation only")
    menu.event_filter=combo(rx+12,gy+52,rw-24,"Level",{"All","Info","OK","Warn","Error"},menu.event_filter,"event_filter")
    txt(Fonts.small,rx+12,gy+111,"Selected event",Theme.muted)
    txt(Fonts.mono,rx+12,gy+134,EventLog[menu.selected_event] and EventLog[menu.selected_event].msg or "-",Theme.text2)
    if button(rx+12,gy+174,rw-24,"CLEAR LOCAL LOG","clear_events",true) then
        EventLog={}
        event("OK","Local event log cleared")
    end
    if button(rx+12,gy+212,rw-24,"ADD TEST EVENT","test_event",false) then
        event("INFO","Manual UI test event")
        toast("Test event added","OK")
    end
end

local function page_inspector(x,y,w,h)
    section_title(x,y,"Inspector","read-only runtime objects")
    local gy=y+58
    local left=math.floor(w*0.34)
    group_box(x,gy,left,420,"Objects","selection")
    local objs={"Local state","UI state","Event queue","Telemetry","Modules"}
    for i,name in ipairs(objs) do
        local yy=gy+48+(i-1)*38
        local selected=menu.inspector_object==i
        round_fill(x+10,yy,x+left-10,yy+30,3,selected and Theme.group2 or Theme.control)
        round_outline(x+10,yy,x+left-10,yy+30,3,selected and Theme.accent_dim or Theme.border)
        txt_vcenter(Fonts.small,x+18,yy,30,name,selected and Theme.text or Theme.text2)
        local mx,my=input.GetMousePos()
        if menu.mouse_pressed and in_box(mx,my,x+10,yy,left-20,30) then menu.inspector_object=i end
    end

    local rx=x+left+16
    local rw=w-left-16
    group_box(rx,gy,rw,420,"Values","read-only")
    local vals={
        {"FrameCount",tostring(globals.FrameCount())},
        {"TickCount",tostring(globals.TickCount())},
        {"TickInterval",string.format("%.6f",globals.TickInterval())},
        {"RealTime",string.format("%.3f",globals.RealTime())},
        {"FrameTime",string.format("%.6f",globals.AbsoluteFrameTime())},
        {"MaxClients",tostring(globals.MaxClients())},
        {"MenuTab",Tabs[menu.tab].name},
        {"SafeMode",SAFE_MODE and "true" or "false"},
    }
    for i,v in ipairs(vals) do
        local yy=gy+50+(i-1)*40
        txt(Fonts.mono,rx+14,yy,v[1],Theme.muted)
        txt(Fonts.mono,rx+170,yy,v[2],Theme.text)
    end
end

local function page_profiler(x,y,w,h)
    section_title(x,y,"Profiler","local UI rendering measurements")
    local gy=y+58
    group_box(x,gy,w,350,"Module timing","diagnostic approximation")
    local rows={
        {"Update",timing.dt*1000*0.06},
        {"Draw",timing.dt*1000*0.17},
        {"Navigation",timing.dt*1000*0.02},
        {"Graph renderer",timing.dt*1000*0.04},
        {"Text renderer",timing.dt*1000*0.03},
    }
    for i,r in ipairs(rows) do
        local yy=gy+52+(i-1)*50
        txt(Fonts.small,x+16,yy,r[1],Theme.muted)
        txt(Fonts.mono,x+210,yy,string.format("%.3f ms",r[2]),Theme.text)
        fill(x+315,yy+4,x+315+clamp(r[2]*28,0,240),yy+7,Theme.accent)
    end
    menu.profiler_mode=combo(x+16,gy+302,250,"Mode",{"Frame","Average","Peak"},menu.profiler_mode,"profiler_mode")
end

local SETTINGS_FILE="forwardmenu_v030.cfg"

local function save_config()
    local data=table.concat({
        "telemetry="..(menu.telemetry and 1 or 0),
        "overlay="..(menu.frame_overlay and 1 or 0),
        "fps="..(menu.fps_counter and 1 or 0),
        "network="..(menu.network_monitor and 1 or 0),
        "events="..(menu.event_logger and 1 or 0),
        "record="..(menu.auto_record and 1 or 0),
        "graph_scale="..menu.graph_scale,
        "sample_rate="..menu.sample_rate,
        "graph_mode="..menu.graph_mode,
        "animations="..(menu.animations and 1 or 0),
        "compact="..(menu.compact and 1 or 0),
    },"\n")
    local ok,err=pcall(function() file.Write(SETTINGS_FILE,data) end)
    if ok then
        toast("Configuration saved","OK")
        event("OK","Configuration saved")
    else
        toast("Save failed: "..tostring(err),"ERROR")
    end
end

local function load_config()
    local ok,data=pcall(function() return file.Read(SETTINGS_FILE) end)
    if not ok or not data then return end
    for line in data:gmatch("[^\r\n]+") do
        local k,v=line:match("([^=]+)=(%-?%d+)")
        if k and v then
            local n=tonumber(v)
            if k=="telemetry" then menu.telemetry=n==1
            elseif k=="overlay" then menu.frame_overlay=n==1
            elseif k=="fps" then menu.fps_counter=n==1
            elseif k=="network" then menu.network_monitor=n==1
            elseif k=="events" then menu.event_logger=n==1
            elseif k=="record" then menu.auto_record=n==1
            elseif k=="graph_scale" then menu.graph_scale=clamp(n,0,100)
            elseif k=="sample_rate" then menu.sample_rate=clamp(n,16,128)
            elseif k=="graph_mode" then menu.graph_mode=clamp(n,1,3)
            elseif k=="animations" then menu.animations=n==1
            elseif k=="compact" then menu.compact=n==1
            end
        end
    end
    event("OK","Configuration loaded")
end

local function page_configs(x,y,w,h)
    section_title(x,y,"Configs","local interface and telemetry settings")
    local gy=y+58
    local left=math.floor(w*0.62)
    group_box(x,gy,left,420,"ForwardMenu","current profile")
    menu.telemetry=checkbox(x+12,gy+48,left-24,"Enable telemetry",menu.telemetry,"cfg_tel")
    menu.frame_overlay=checkbox(x+12,gy+88,left-24,"Frame overlay",menu.frame_overlay,"cfg_overlay")
    menu.fps_counter=checkbox(x+12,gy+128,left-24,"FPS counter",menu.fps_counter,"cfg_fps")
    menu.network_monitor=checkbox(x+12,gy+168,left-24,"Network monitor",menu.network_monitor,"cfg_net")
    menu.event_logger=checkbox(x+12,gy+208,left-24,"Event logger",menu.event_logger,"cfg_events")
    menu.auto_record=checkbox(x+12,gy+248,left-24,"Auto record",menu.auto_record,"cfg_record")
    if button(x+12,gy+306,left-24,"SAVE CONFIG","save_cfg",true) then save_config() end

    local rx=x+left+16
    local rw=w-left-16
    group_box(rx,gy,rw,420,"Build","module information")
    txt(Fonts.tiny,rx+14,gy+52,"VERSION",Theme.muted)
    txt(Fonts.mono,rx+14,gy+73,VERSION,Theme.text)
    txt(Fonts.tiny,rx+14,gy+112,"MODE",Theme.muted)
    txt(Fonts.mono,rx+14,gy+133,"SAFE / UI ONLY",Theme.accent)
    txt(Fonts.tiny,rx+14,gy+172,"CONFIG",Theme.muted)
    txt(Fonts.mono,rx+14,gy+193,SETTINGS_FILE,Theme.text2)
    if button(rx+14,gy+232,rw-28,"RELOAD CONFIG","reload_cfg",false) then
        load_config(); toast("Configuration reloaded","OK")
    end
end

local function page_ui(x,y,w,h)
    section_title(x,y,"Interface","appearance, animation and layout")
    local gy=y+58
    local left=math.floor(w*0.55)
    group_box(x,gy,left,420,"Appearance","Forward visual system")
    menu.animations=checkbox(x+12,gy+48,left-24,"Animations",menu.animations,"ui_anim","hover, selection and graph motion")
    menu.compact=checkbox(x+12,gy+102,left-24,"Compact navigation",menu.compact,"ui_compact")
    menu.accent_preset=combo(x+12,gy+172,left-24,"Accent",{"Lime","Ice","Amber","Violet"},menu.accent_preset,"accent")
    menu.ui_scale=combo(x+12,gy+230,left-24,"UI scale",{"100%","110%","120%"},menu.ui_scale,"scale")
    if button(x+12,gy+292,left-24,"RESET UI POSITION","reset_pos",false) then
        menu.x,menu.y=205,105
        toast("UI position reset","OK")
    end

    local rx=x+left+16
    local rw=w-left-16
    group_box(rx,gy,rw,420,"Preview","live theme status")
    round_fill(rx+14,gy+50,rw+rx-14,gy+112,4,Theme.control)
    fill(rx+14,gy+50,rx+18,gy+112,Theme.accent)
    txt(Fonts.body,rx+28,gy+63,"ForwardTrack",Theme.text)
    txt(Fonts.tiny,rx+28,gy+85,"developer tools",Theme.muted)
    txt(Fonts.tiny,rx+14,gy+144,"Accent",Theme.muted)
    txt(Fonts.mono,rx+90,gy+142,"LIME / #76D200",Theme.accent)
    txt(Fonts.tiny,rx+14,gy+182,"Renderer",Theme.muted)
    txt(Fonts.mono,rx+90,gy+180,"draw.*",Theme.text2)
    txt(Fonts.tiny,rx+14,gy+220,"Input",Theme.muted)
    txt(Fonts.mono,rx+90,gy+218,"edge-triggered",Theme.text2)
end

local function page_lua(x,y,w,h)
    section_title(x,y,"Lua","module registry and safety contract")
    local gy=y+58
    group_box(x,gy,w,220,"Module registry","safe extension surface")
    local yy=gy+48
    for _,m in ipairs(Modules) do
        txt(Fonts.mono,x+14,yy,string.format("%-11s",m.id),Theme.text2)
        txt(Fonts.small,x+122,yy,m.title,Theme.text)
        txt(Fonts.tiny,x+245,yy,m.desc,Theme.muted)
        txt(Fonts.tiny,x+w-56,yy,m.enabled and "READY" or "OFF",m.enabled and Theme.accent or Theme.muted)
        yy=yy+26
    end

    group_box(x,gy+236,w,175,"Contract","intentionally non-gameplay")
    txt(Fonts.mono,x+14,gy+282,"callbacks.Register(\"Draw\", ...)",Theme.text2)
    txt(Fonts.mono,x+14,gy+307,"callbacks.Register(\"Unload\", ...)",Theme.text2)
    txt(Fonts.small,x+14,gy+345,"No CreateMove / view-angle writes / packet writes / combat automation.",Theme.accent)
end

local function page_about(x,y,w,h)
    section_title(x,y,"About","ForwardMenu developer UI shell")
    local gy=y+58
    group_box(x,gy,w,190,"ForwardMenu","v"..VERSION)
    txt(Fonts.body,x+14,gy+50,"A custom diagnostic interface for safe telemetry and UI development.",Theme.text2)
    txt(Fonts.small,x+14,gy+80,"Visual language: dark panels, compact navigation, lime accent, animated controls.",Theme.muted)
    txt(Fonts.small,x+14,gy+104,"API surface: draw.*, input.*, globals.*, callbacks.*, file.*",Theme.muted)
    badge(x+14,gy+138,"SAFE MODE",Theme.accent)
    badge(x+112,gy+138,"UI ONLY",Theme.accent)

    group_box(x,gy+206,w,205,"Safety","hard design boundary")
    local lines={
        "No aimbot",
        "No anti-aim",
        "No resolver",
        "No movement automation",
        "No CreateMove manipulation",
        "No view-angle / packet writes",
    }
    for i,s in ipairs(lines) do
        local col=(i-1)%2
        local row=math.floor((i-1)/2)
        local xx=x+18+col*math.floor(w/2)
        local yy=gy+250+row*42
        color(Theme.accent); draw.FilledCircle(xx+3,yy+5,3)
        txt(Fonts.small,xx+14,yy,s,Theme.text2)
    end
end

local function draw_page()
    local cx,cy,cw,ch=content_rect()
    fill(cx,cy,cx+cw,cy+ch,Theme.window)
    local px=cx+30
    local py=cy+28
    local pw=cw-54
    local ph=ch-50

    local id=Tabs[menu.tab].id
    if id=="dashboard" then page_dashboard(px,py,pw,ph)
    elseif id=="telemetry" then page_telemetry(px,py,pw,ph)
    elseif id=="network" then page_network(px,py,pw,ph)
    elseif id=="events" then page_events(px,py,pw,ph)
    elseif id=="inspector" then page_inspector(px,py,pw,ph)
    elseif id=="profiler" then page_profiler(px,py,pw,ph)
    elseif id=="configs" then page_configs(px,py,pw,ph)
    elseif id=="ui" then page_ui(px,py,pw,ph)
    elseif id=="lua" then page_lua(px,py,pw,ph)
    elseif id=="about" then page_about(px,py,pw,ph)
    end
end

------------------------------------------------------------
-- SETTINGS POPUP
------------------------------------------------------------
local function draw_settings_popup()
    if not menu.settings_open then return end
    local x=menu.x+menu.w-292
    local y=menu.y+menu.header_h+10
    local w=270
    local h=152
    round_fill(x+3,y+4,x+w+3,y+h+4,5,Theme.shadow)
    round_fill(x,y,x+w,y+h,5,Theme.group)
    round_outline(x,y,x+w,y+h,5,Theme.border2)
    txt(Fonts.h2,x+12,y+12,"Interface",Theme.text)
    txt(Fonts.tiny,x+12,y+42,"Theme",Theme.muted)
    txt(Fonts.mono,x+105,y+40,"Forward / Lime",Theme.accent)
    txt(Fonts.tiny,x+12,y+70,"Toggle",Theme.muted)
    txt(Fonts.mono,x+105,y+68,"INSERT",Theme.text2)
    txt(Fonts.tiny,x+12,y+98,"Build",Theme.muted)
    txt(Fonts.mono,x+105,y+96,VERSION,Theme.text2)
    txt(Fonts.tiny,x+12,y+126,"Status",Theme.muted)
    txt(Fonts.mono,x+105,y+124,"SAFE UI",Theme.accent)
end

------------------------------------------------------------
-- WINDOW
------------------------------------------------------------
local function draw_window()
    if not menu.open then return end
    local x,y,w,h=menu.x,menu.y,menu.w,menu.h
    round_fill(x+4,y+5,x+w+4,y+h+5,6,Theme.shadow)
    round_fill(x,y,x+w,y+h,6,Theme.window)
    round_outline(x,y,x+w,y+h,6,Theme.border2)
    draw_header()
    draw_sidebar()
    draw_page()

    fill(x,y+h-25,x+w,y+h,Theme.header)
    fill(x,y+h-26,x+w,y+h-25,Theme.border)
    txt(Fonts.tiny,x+16,y+h-18,"SAFE MODE  •  UI / TELEMETRY ONLY",Theme.accent)
    txt(Fonts.tiny,x+w-124,y+h-18,"v"..VERSION,Theme.muted2)
    draw_settings_popup()

    if menu.toast then
        local age=timing.now-menu.toast_at
        if age<2.8 then
            local fade=age>2.1 and clamp((2.8-age)/0.7,0,1) or 1
            local tw=285
            local tx=x+w-tw-14
            local ty=y+h+12
            round_fill(tx,ty,tx+tw,ty+30,4,Theme.group,230*fade)
            round_outline(tx,ty,tx+tw,ty+30,4,level_color(menu.toast.level),170*fade)
            txt_vcenter(Fonts.small,tx+10,ty,30,menu.toast.msg,Theme.text)
        else
            menu.toast=nil
        end
    end
end

------------------------------------------------------------
-- INPUT ROUTING
------------------------------------------------------------
local function handle_global()
    if input.IsButtonPressed(45) then
        menu.open=not menu.open
        if menu.open then toast("ForwardMenu opened","OK") end
    end
end

local function handle_input()
    if not menu.open then return end

    local mx,my=input.GetMousePos()
    update_drag()
    if menu.dragging then return end

    if handle_header() then return end
    if handle_sidebar() then return end
end

------------------------------------------------------------
-- CALLBACKS
------------------------------------------------------------
local function on_draw()
    update_time()
    update_mouse(input.GetMousePos())
    handle_global()
    update_animation()
    handle_input()
    draw_window()
end

local function on_unload()
    -- UI-only state; nothing gameplay-related to restore.
end

------------------------------------------------------------
-- INIT
------------------------------------------------------------
init_fonts()
load_config()
event("OK",MODULE_ID.." "..VERSION.." loaded")
toast("ForwardMenu ready","OK")

callbacks.Register("Draw",MODULE_ID.."_Draw",on_draw)
callbacks.Register("Unload",MODULE_ID.."_Unload",on_unload)

------------------------------------------------------------
-- PUBLIC SAFE API
------------------------------------------------------------
ForwardMenu = {
    VERSION=VERSION,
    SAFE_MODE=SAFE_MODE,
    IsOpen=function() return menu.open end,
    Toggle=function() menu.open=not menu.open end,
    SetTab=function(index)
        index=tonumber(index) or 1
        menu.tab=clamp(math.floor(index),1,#Tabs)
    end,
    AddEvent=function(level,message) event(level or "INFO",message or "") end,
    Toast=function(message,level) toast(message,level) end,
    SaveConfig=save_config,
    LoadConfig=load_config,
    GetModules=function() return Modules end,
}

-- Explicit safety boundary:
-- No CreateMove, AimbotTarget, UserCmd.SetViewAngles, SetSendPacket,
-- gui.Command, SendStringCmd, combat automation or gameplay-state writes.
