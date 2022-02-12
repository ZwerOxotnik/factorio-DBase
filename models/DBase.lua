---@class DB : module
local M = {}

--#region Global data
---@type table<string, any>
local mod_data
--#endregion


--#region Events

local function on_new_team_base(event)
	local surface = event.surface
	if not (surface and surface.index) then return end
	local force = event.force
	if not (force and force.index) then return end

	local position = event.position
	local x = math.ceil(position.x)
	local y = math.ceil(position.y)
	local reserve_base_surface = game.get_surface("reserve_base_surface")
	reserve_base_surface.clone_area{
		source_area = {{-250, -250}, {250, 250}},
		destination_area = {{x - 250, y - 250}, {x + 250, y + 250}},
		destination_surface = surface,
		destination_force = force,
		clone_tiles = false,
		clone_entities = true,
		clone_decoratives = false,
		clear_destination_entities = false,
		clear_destination_decoratives= true,
		expand_map = true,
		create_build_effect_smoke = false
	}
end

--#endregion


--#region Pre-game stage

local function add_remote_interface()
	-- https://lua-api.factorio.com/latest/LuaRemote.html
	remote.remove_interface("DBase") -- For safety
	remote.add_interface("DBase", {})
end

local function link_data()
	mod_data = global.DB
end

local function update_global_data()
	global.DB = global.DB or {}
	mod_data = global.DB
	mod_data.players_prev_pos = mod_data.players_prev_pos or {}

	link_data()

	local reserve_base_surface = game.get_surface("reserve_base_surface")
	if reserve_base_surface == nil then
		reserve_base_surface = game.create_surface("reserve_base_surface", {
			width = 500,
			height = 500,
			peaceful_mode = true,
			starting_area = 'none',
			default_enable_all_autoplace_controls = false,
			seed = 0
		})
		reserve_base_surface.generate_with_lab_tiles = true
	end

	script.on_event(
		remote.call("EasyAPI", "get_event_name", "on_new_team_base"),
		on_new_team_base
	)
end


M.on_init = update_global_data
M.on_load = function()
	link_data()
	script.on_event(
		remote.call("EasyAPI", "get_event_name", "on_new_team_base"),
		on_new_team_base
	)
end
M.on_configuration_changed = update_global_data
M.add_remote_interface = add_remote_interface

--#endregion


M.commands = {
	["change-DBase"] = function(cmd)
		local player_index = cmd.player_index
		local player = game.get_player(player_index)

		--TODO: detach the player from character
		local reserve_base_surface = game.get_surface("reserve_base_surface")
		if player.surface == reserve_base_surface then
			local player_data = mod_data.players_prev_pos[player_index]
			if player_data == nil or not (player_data.surface and player_data.surface.valid) then
				--TODO: change message
				player.print({"error.error-message-box-title"})
				return
			end
			player.teleport(player_data.position, player_data.surface)
			if player_data.force and player_data.force.valid then
				player.force = player_data.force
			end
			mod_data.players_prev_pos[player_index] = nil
		else
			mod_data.players_prev_pos[player_index] = {
				surface = player.surface,
				position = player.position,
				force = player.force,
				character = player.character,
				tick = game.tick
			}
			player.force = "neutral"
			player.teleport({0, 0}, reserve_base_surface)
		end
	end,
}


return M
