-- OpenClaw Bot Mod for Minetest
-- physical=true, NEVER use set_pos after spawn, velocity only

local BRIDGE_URL = "http://bridge:8080/api"
local POLL_INTERVAL = 0.5
local MOVE_SPEED = 4.0

local http = minetest.request_http_api()
if not http then
    minetest.log("error", "[openclaw_bot] HTTP API not available")
    return
end

local agents = {}

local AGENT_TEXTURES = {
    iori    = {"character.png"},
    tsumugi = {"character.png"},
    saku    = {"character.png"},
}

local AGENT_OFFSETS = {
    iori    = {x =  3, z =  0},
    tsumugi = {x = -3, z =  0},
    saku    = {x =  0, z =  3},
}

local function get_player()
    for _, player in ipairs(minetest.get_connected_players()) do
        return player
    end
    return nil
end

local function is_valid_ref(ref)
    if not ref then return false end
    local ok, pos = pcall(function() return ref:get_pos() end)
    return ok and pos ~= nil
end

local function spawn_agent(agent_id, pos)
    local obj = minetest.add_entity(pos, "openclaw_bot:agent", agent_id)
    if obj then
        local tex = AGENT_TEXTURES[agent_id] or {"character.png"}
        obj:set_properties({textures = tex})
        minetest.log("action", "[openclaw_bot] Spawned: " .. agent_id .. " at y=" .. pos.y)
        return obj
    end
    return nil
end

local function ensure_agent(agent_id)
    local a = agents[agent_id]
    if a and is_valid_ref(a.obj_ref) then
        return a
    end

    local player = get_player()
    local offset = AGENT_OFFSETS[agent_id] or {x = math.random(-3, 3), z = math.random(-3, 3)}
    local x, z, y
    if player then
        local ppos = player:get_pos()
        x = ppos.x + offset.x
        z = ppos.z + offset.z
        y = ppos.y
    else
        x = offset.x
        z = offset.z
        y = 10.5
    end
    local obj = spawn_agent(agent_id, {x = x, y = y, z = z})
    if obj then
        agents[agent_id] = {
            target_pos = nil,
            is_moving = false,
            facing = {x = 0, z = 1},
            obj_ref = obj,
        }
        return agents[agent_id]
    end
    return nil
end

---------------------------------------------------------------
-- Entity definition
---------------------------------------------------------------
minetest.register_entity("openclaw_bot:agent", {
    initial_properties = {
        visual = "mesh",
        mesh = "character.b3d",
        textures = {"character.png"},
        visual_size = {x = 1, y = 1},
        collisionbox = {-0.3, 0, -0.3, 0.3, 1.7, 0.3},
        hp_max = 20,
        physical = true,
        collide_with_objects = true,
        static_save = false,
    },
    agent_id = "",

    on_activate = function(self, staticdata)
        if staticdata and staticdata ~= "" then
            self.agent_id = staticdata
        end
        if not self.agent_id or self.agent_id == "" then
            self.object:remove()
            return
        end
        local tex = AGENT_TEXTURES[self.agent_id] or {"character.png"}
        self.object:set_properties({
            textures = tex,
            nametag = self.agent_id,
            nametag_color = "#FFFFFF",
        })
        local a = agents[self.agent_id]
        if a and is_valid_ref(a.obj_ref) then
            self.object:remove()
            return
        end
        agents[self.agent_id] = {
            target_pos = a and a.target_pos or nil,
            is_moving = false,
            facing = {x = 0, z = 1},
            obj_ref = self.object,
        }
    end,
})

---------------------------------------------------------------
-- Command execution - teleport removes and respawns
---------------------------------------------------------------
local function execute_command(agent_id, cmd)
    local a = ensure_agent(agent_id)
    if not a then return end

    if cmd.action == "move" then
        local t = cmd.target
        if t and t.x and t.y and t.z then
            a.target_pos = {x = t.x, y = t.y, z = t.z}
        end

    elseif cmd.action == "teleport" then
        local t = cmd.target
        if t and t.x and t.y and t.z then
            a.target_pos = nil
            a.is_moving = false
            if a.obj_ref then
                pcall(function() a.obj_ref:remove() end)
            end
            local player = get_player()
            local y = player and player:get_pos().y or 10.5
            local obj = spawn_agent(agent_id, {x = t.x, y = y, z = t.z})
            if obj then
                a.obj_ref = obj
            end
        end

    elseif cmd.action == "dig" then
        local pos = a.obj_ref:get_pos()
        local p = cmd.pos or {x = math.floor(pos.x), y = math.floor(pos.y), z = math.floor(pos.z)}
        minetest.remove_node(p)

    elseif cmd.action == "place" then
        local pos = a.obj_ref:get_pos()
        local p = cmd.pos or {x = math.floor(pos.x), y = math.floor(pos.y) + 1, z = math.floor(pos.z)}
        minetest.set_node(p, {name = cmd.node or "default:stone"})

    elseif cmd.action == "chat" then
        minetest.chat_send_all("[" .. agent_id .. "] " .. (cmd.message or "..."))

    elseif cmd.action == "set_time" then
        minetest.set_timeofday(cmd.time or 0.5)

    elseif cmd.action == "look" then
        local pos = a.obj_ref:get_pos()
        if not pos then return end
        local surroundings = {}
        for dx = -2, 2 do
            for dy = -1, 2 do
                for dz = -2, 2 do
                    local check = {x = math.floor(pos.x) + dx, y = math.floor(pos.y) + dy, z = math.floor(pos.z) + dz}
                    local node = minetest.get_node(check)
                    if node.name ~= "air" and node.name ~= "ignore" then
                        table.insert(surroundings, {pos = check, node = node.name})
                    end
                end
            end
        end
        http.fetch({
            url = BRIDGE_URL .. "/look/" .. agent_id,
            method = "POST",
            data = minetest.write_json({surroundings = surroundings}),
            extra_headers = {"Content-Type: application/json"},
        }, function() end)
    end
end

---------------------------------------------------------------
-- Global step: velocity only, never set_pos
---------------------------------------------------------------
local report_timer = 0

minetest.register_globalstep(function(dtime)
    report_timer = report_timer + dtime

    for agent_id, a in pairs(agents) do
        -- Respawn if lost
        if not is_valid_ref(a.obj_ref) then
            local player = get_player()
            if player then
                local ppos = player:get_pos()
                local offset = AGENT_OFFSETS[agent_id] or {x = 0, z = 0}
                local obj = spawn_agent(agent_id, {x = ppos.x + offset.x, y = ppos.y, z = ppos.z + offset.z})
                if obj then
                    a.obj_ref = obj
                end
            end
            goto continue
        end

        -- Movement: set_velocity on X/Z, set_yaw for facing
        if a.target_pos then
            local pos = a.obj_ref:get_pos()
            local dx = a.target_pos.x - pos.x
            local dz = a.target_pos.z - pos.z
            local dist = math.sqrt(dx * dx + dz * dz)
            if dist < 0.5 then
                a.target_pos = nil
                a.is_moving = false
                a.obj_ref:set_velocity({x = 0, y = 0, z = 0})
                a.obj_ref:set_animation({x = 0, y = 79}, 30, 0, true)
            else
                local dir_x = dx / dist
                local dir_z = dz / dist
                a.facing = {x = dir_x, z = dir_z}
                a.is_moving = true
                -- Face movement direction
                a.obj_ref:set_yaw(math.atan2(dx, dz))
                a.obj_ref:set_velocity({x = dir_x * MOVE_SPEED, y = 0, z = dir_z * MOVE_SPEED})
                a.obj_ref:set_animation({x = 168, y = 187}, 30, 0, true)
            end
        end

        -- State report
        if report_timer >= 1.0 then
            local pos = a.obj_ref:get_pos()
            if pos then
                http.fetch({
                    url = BRIDGE_URL .. "/state/" .. agent_id,
                    method = "POST",
                    data = minetest.write_json({
                        pos = {x = math.floor(pos.x), y = math.floor(pos.y), z = math.floor(pos.z)},
                        is_moving = a.is_moving,
                        facing = a.facing,
                    }),
                    extra_headers = {"Content-Type: application/json"},
                }, function() end)
            end
        end

        ::continue::
    end

    -- Report player positions
    if report_timer >= 1.0 then
        for _, player in ipairs(minetest.get_connected_players()) do
            local name = player:get_player_name()
            local ppos = player:get_pos()
            if ppos then
                http.fetch({
                    url = BRIDGE_URL .. "/player/" .. name,
                    method = "POST",
                    data = minetest.write_json({
                        pos = {x = math.floor(ppos.x), y = math.floor(ppos.y), z = math.floor(ppos.z)},
                    }),
                    extra_headers = {"Content-Type: application/json"},
                }, function() end)
            end
        end
    end

    if report_timer >= 1.0 then
        report_timer = 0
    end
end)

---------------------------------------------------------------
-- Bridge polling
---------------------------------------------------------------
local function poll_bridge()
    http.fetch({
        url = BRIDGE_URL .. "/sync",
        method = "GET",
    }, function(res)
        if res.code ~= 200 then
            minetest.after(POLL_INTERVAL, poll_bridge)
            return
        end

        local ok, data = pcall(minetest.parse_json, res.data)
        if not ok or not data then
            minetest.after(POLL_INTERVAL, poll_bridge)
            return
        end

        if data.agents then
            for _, agent_id in ipairs(data.agents) do
                if not agents[agent_id] then
                    ensure_agent(agent_id)
                end
            end
        end

        if data.commands then
            for _, cmd in ipairs(data.commands) do
                execute_command(cmd.agent_id, cmd)
            end
        end
    end)

    minetest.after(POLL_INTERVAL, poll_bridge)
end

---------------------------------------------------------------
-- Init
---------------------------------------------------------------
minetest.register_on_mods_loaded(function()
    minetest.log("action", "[openclaw_bot] Starting bridge polling")
    minetest.after(2.0, poll_bridge)
end)

minetest.register_on_shutdown(function()
    minetest.log("action", "[openclaw_bot] Shutting down")
end)
