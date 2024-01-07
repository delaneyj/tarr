-- foo
function _init()
    screen_title = 0
    screen_game = 1
    screen_over = 2
    screen = screen_title

    show_debug = false
    pings = {
        speed = 3,
        decay = 0.15,
        max_r = 0,
        submarine_offset = {x = 27, y = 13},
        sent = {},
        bounced = {}
    }

    creatures = {}

    levels = {
        {
            name = "surface",
            bgcolor = 12,
            mapX = 0,
            creatures = {
                count = 10,
                sprites = {
                    {name = "fish", idx = 1, w = 2, h = 2},
                    {name = "turtle", idx = 3, w = 2, h = 2},
                    {name = "shark", idx = 33, w = 2, h = 2}
                }
            }
        }, {
            name = "twilight",
            bgcolor = 1,
            mapX = 17,
            creatures = {
                count = 10,
                sprites = {
                    {name = "jellfish", idx = 35, w = 1, h = 2},
                    {name = "oarfish", idx = 33, w = 2, h = 1},
                    {name = "snake", idx = 69, w = 2, h = 1}
                }
            }
        }, {
            name = "deep",
            bgcolor = 0,
            mapX = 34,
            creatures = {
                count = 10,
                sprites = {
                    {name = "x", idx = 6, w = 1, h = 1},
                    {name = "y", idx = 7, w = 1, h = 1},
                    {name = "z", idx = 8, w = 1, h = 1}
                }
            }
        }
    }

    level_idx = 1
    level = levels[level_idx]

    submarine = {
        x = 63,
        y = 63,
        sprite = {idx = 14, w = 4, h = 2},
        fuel = {current = 1000, max = 1000, burn_rate = 1},
        speed = {x = 1, y = 0.35}
    }

    level_completed = false
end

function _update()
    if screen == screen_title then
        update_title()
    elseif screen == screen_game then
        update_game()
    elseif screen == screen_over then
        update_over()
    end
end

function _draw()
    if screen == screen_title then
        draw_title()
    elseif screen >= screen_game then
        draw_game()
        if screen == screen_over then draw_over() end
    end
end

function load_level(level_idx)
    creatures = {}
    -- load creatures
    for i = 1, level.creatures.count do
        local si = ceil(rnd(#level.creatures.sprites))
        local s = level.creatures.sprites[si]

        local c = {
            found = false,
            x = x,
            y = y,
            idx = s.idx,
            w = s.w,
            h = s.h,
            r = 4 * sqrt(s.w * s.w + s.h * s.h)
        }

        local has_collision_with_creatures = true
        while has_collision_with_creatures do
            c.x = rnd_min_max(16, 120 - s.w * 8)
            c.y = rnd_min_max(16, 96 - s.h * 8)

            has_collision_with_creatures = false
            for other in all(creatures) do
                if has_collision_aabb(c, other) then
                    has_collision_with_creatures = true
                    break
                end
            end
        end

        add(creatures, c)
    end
    level_completed = false
    submarine.fuel.current = submarine.fuel.max
end

function rnd_min_max(min, max) return rnd(max - min) + min end

-- >8
-- title
function update_title()
    if (btnp(4)) then
        load_level(1)
        screen = screen_game
        music(-1, 1000)
    else
        if not stat(57) then music(0, 500) end
    end
end

function center_text(text, y, color)
    local x = 64 - #text * 2
    print(text, x, y, color)
end

function draw_title()
    cls(0)
    map(51, 0, 0, 0, 16, 16)
    center_text("abyss", 4, 7)
    center_text("press z to start", 30, 7)
    center_text("use arrow keys to move", 40, 7)
    center_text("use x to ping", 50, 7)
    center_text("by tarr academy", 100, 7)
end
-- >8
-- game
function update_game()
    if level_completed then
        if btnp(4) then
            level_idx = level_idx + 1
            if level_idx > #levels then
                screen = screen_title
                level_idx = 1
                return
            end
            level = levels[level_idx]
            load_level(level_idx)
            level_completed = false
        end
        return
    end

    -- move submarine
    local sub_moved = false
    if btn(0) then
        submarine.x = submarine.x - submarine.speed.x
        sub_moved = true
    end
    if btn(1) then
        submarine.x = submarine.x + submarine.speed.x
        sub_moved = true
    end
    if btn(2) then
        submarine.y = submarine.y - submarine.speed.y
        sub_moved = true
    end
    if btn(3) then
        submarine.y = submarine.y + submarine.speed.y
        sub_moved = true
    end

    -- burn fuel
    if sub_moved then
        submarine.fuel.current = submarine.fuel.current -
                                     submarine.fuel.burn_rate
    end

    -- toggle debug
    if btnp(4) then show_debug = not show_debug end

    sonar = {x = pings.submarine_offset.x, y = pings.submarine_offset.y}
    sonar.x = sonar.x + submarine.x
    sonar.y = sonar.y + submarine.y

    -- add ping
    if btnp(5) then
        add(pings.sent, {
            creatures = {},
            x = sonar.x,
            y = sonar.y,
            r = 0,
            speed = pings.speed
        })
    end

    -- update pingsxz
    for sent_ping in all(pings.sent) do
        sent_ping.r = sent_ping.r + sent_ping.speed
        pings.max_r = max(pings.max_r, sent_ping.r)
        sent_ping.speed = sent_ping.speed - pings.decay
        if sent_ping.speed <= 0 then del(pings.sent, sent_ping) end

        -- check for collisions
        for c in all(creatures) do
            local seen = sent_ping.creatures[c]
            if not seen then
                collided = collision_circle_sprite(sent_ping, c)
                if collided.inside then
                    add(pings.bounced, {
                        x = c.x,
                        y = c.y,
                        r = sqrt(c.w * c.w + c.h * c.h),
                        speed = pings.speed,
                        from = c
                    })
                    sent_ping.creatures[c] = true
                end
            end
        end
    end

    local found_creatures = false

    for p in all(pings.bounced) do
        p.r = p.r + p.speed
        p.speed = p.speed - pings.decay
        if p.speed <= 0 then
            del(pings.bounced, p)
        elseif not p.hit_submarine then
            -- play sound if bounced back to submarine
            local collided = collision_point_circle(sonar, p)
            if collided.inside then
                local bank = flr(fit_clamp(collided.d, 8, pings.max_r, 0, 9))
                sfx(bank)
                p.hit_submarine = true
                if bank == 0 then
                    p.from.found = true
                    found_creatures = true
                end
            end
        end
    end

    -- check is sonar is in creature bounds
    for c in all(creatures) do
        if not c.found then
            if has_collision_point_rect(sonar, c) then
                c.found = true
                found_creatures = true
            end
        end
    end

    if found_creatures then sfx(0) end

    if submarine.fuel.current <= 0 then screen = screen_over end

    if found_all() then level_completed = true end
end

function found_all()
    for c in all(creatures) do if not c.found then return false end end
    return true
end

function draw_game()
    local is_over = screen == screen_over

    if screen == screen_game then
        cls(level.bgcolor)

        map(level.mapX, 0, 0, 0, 16, 16)
    else
        cls(0)
    end

    -- draw creatures
    for c in all(creatures) do
        if c.found then circ(c.x, c.y, c.r, 10) end
        if is_over or show_debug or c.found then
            local cx = c.x - c.w * 8 / 2
            local cy = c.y - c.h * 8 / 2
            spr(c.idx, cx, cy, c.w, c.h)
        end
    end

    -- draw submarine
    spr(12, submarine.x, submarine.y, 4, 2)
    -- spr(submarine.sprite.idx, submarine.x, submarine.y, submarine.sprite.w, submarine.sprite.h)

    -- draw pings
    -- if show_debug then
    for ping in all(pings.sent) do circ(ping.x, ping.y, ping.r, 7) end
    -- end

    for ping in all(pings.bounced) do
        if show_debug or ping.from.found then
            circ(ping.x, ping.y, ping.r, 8)
        end
    end

    local missing = 0
    for c in all(creatures) do if not c.found then missing = missing + 1 end end
    print("found:" .. (level.creatures.count - missing) .. "/" ..
              level.creatures.count, 10, 4, 7)
    print("fuel:" .. submarine.fuel.current .. "/" .. submarine.fuel.max, 64, 4,
          7)

    if level_completed then
        if level_idx < #levels then
            center_text("level completed", 92, 7)
            center_text("press z to continue", 100, 7)
        else
            center_text("game completed", 24, 7)
            center_text("press z to continue", 32, 7)
        end
    end
end

-- >8
-- over
function update_over() if btnp(4) then _init() end end

function draw_over()
    center_text("game over", 100, 7)
    center_text("press z to restart", 108, 7)
end

-- >8
-- utils
function collision_point_circle(p, c)
    local a = p.x - c.x
    local b = p.y - c.y
    local d = sqrt(a * a + b * b)
    return {inside = d <= c.r, d = d}
end

function collision_circle_sprite(c, s)
    local ss = sqrt(s.w * s.w + s.h * s.h)
    local s2 = ss / 2
    local dx = abs(c.x - s.x)
    local dy = abs(c.y - s.y)
    local r = c.r + s2
    local inside = dx <= r and dy <= r
    local d = sqrt(dx * dx + dy * dy)
    return {inside = inside, d = d}
end

function has_collision_point_rect(p, r)
    local tlx = r.x - r.w * 8 / 2
    local tly = r.y - r.h * 8 / 2
    local brx = r.x + r.w * 8 / 2
    local bry = r.y + r.h * 8 / 2
    return p.x >= tlx and p.x <= brx and p.y >= tly and p.y <= bry
end

function has_collision_aabb(a, b)
    local aw = a.w * 8
    local ah = a.h * 8
    local bw = b.w * 8
    local bh = b.h * 8

    if a.x + aw < b.x then return false end
    if a.x > b.x + bw then return false end
    if a.y + ah < b.y then return false end
    if a.y > b.y + bh then return false end

    return true

end

function fit(value, old_min, old_max, new_min, new_max)
    local old_range = old_max - old_min
    local new_range = new_max - new_min
    return (((value - old_min) * new_range) / old_range) + new_min
end

function fit_clamp(value, old_min, old_max, new_min, new_max)
    local f = fit(value, old_min, old_max, new_min, new_max)
    return mid(new_min, f, new_max)
end
