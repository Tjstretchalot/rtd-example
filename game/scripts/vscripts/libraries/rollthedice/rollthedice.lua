if rollthedice then return end

LinkLuaModifier( "modifier_rtd_timer", "libraries/rollthedice/modifier_rtd_timer.lua", LUA_MODIFIER_MOTION_NONE )

rollthedice = class( {} )
rollthedice.rtd_cooldown = (RTD_COOLDOWN == nil) and 60 or RTD_COOLDOWN

function rollthedice:OnPlayerChat( keys, playerID )
  local teamonly = keys.teamonly
  local userID = keys.userid

  local text = keys.text
  if (teamonly == 1) or (text ~= "rtd") then return end
  
  if not PlayerResource:HasSelectedHero( playerID ) then 
    GameRules:SendCustomMessage( "#rtd_alert_no_selected_hero", DOTA_TEAM_NOTEAM, 1 )
    return
  end
  
  local hero = PlayerResource:GetSelectedHeroEntity( playerID )
  
  if not hero:IsAlive() then 
    GameRules:SendCustomMessage( "#rtd_alert_dead", DOTA_TEAM_NOTEAM, 1 )
    return
  end
  
  if self:HasRTDModifier( hero ) then
    GameRules:SendCustomMessage( "#rtd_alert_too_soon", DOTA_TEAM_NOTEAM, 1 )
    return
  end
  
  self:AddRTDModifier( hero )
  
  local roll = RandomInt( 1, 100 )
  
  local result = self.results[roll]
  local modifier = result.modifier
  
  GameRules:SendCustomMessage( "#" .. tostring(modifier.name), DOTA_TEAM_NOTEAM, 1 )
  
  local created_keys = { playerid = playerID }
  if modifier.is_datadriven then 
    for _, obj in ipairs(modifier.datadriven_objects) do 
      obj:OnCreated( created_keys )
    end
  else 
    modifier.lua_object:OnCreated( created_keys )
  end
end

function rollthedice:HasRTDModifier( hero )
  return hero:HasModifier( "modifier_rtd_timer" )
end

function rollthedice:AddRTDModifier( hero )
  hero:AddNewModifier( hero, nil, "modifier_rtd_timer", { Duration = self.rtd_cooldown } )
end

local rtd_result = {
  index = 0,
  modifier_name = nil,
  modifier = nil
}

function rtd_result:CreateNew( o )
  o = o or {}
  setmetatable( o, self )
  self.__index = self
  return o
end

function rtd_result:Link( modifiers )
  for _, mod in ipairs(modifiers) do 
    if mod.name == self.modifier_name then 
      self.modifier = mod
      return
    end
  end
  
  print( '[RTD] Failed to link result with modifier! modifier_name='.. tostring(modifier_name) .. ' for index='..tostring(index))
end

local rtd_modifier = {
  name = nil,
  is_lua = false,
  is_datadriven = false,
  script_file = nil,
  ability_special = {},
  datadriven_objects = {},
  lua_object = {}
}

function rtd_modifier:CreateNew( o )
  o = o or {}
  setmetatable( o, self )
  self.__index = self
  
  -- prevent confusing reuse of tables
  o.ability_special = {}
  o.datadriven_objects = {}
  
  return o
end

local function rtd_stringstarts(String,Start)
   return string.sub(String,1,string.len(Start))==Start
end

function rtd_modifier:GetAbilitySpecialByName( name )
  return self.ability_special[name]
end

function rtd_modifier:Parse( key, value )
  local result = self:CreateNew( { name = key } )
  
  local base_class = value["BaseClass"]
  
  if base_class == 'rtd_datadriven' then 
    result.is_datadriven = true
  elseif base_class == 'rtd_lua' then 
    result.is_lua = true
  else
    print( '[RTD] Weird baseclass for ' .. tostring(key) .. ': ' .. tostring(base_class) .. ' found, expected rtd_datadriven or rtd_lua' )
    return result
  end
  
  if value["ScriptFile"] then 
    if not result.is_lua then
      print( "[RTD] Non-lua modifier " .. tostring(key) .. " has a ScriptFile key - it doesn't do anything!")
    else
      local scriptfile_path = value["ScriptFile"]
      dofile( string.sub( scriptfile_path, 1, #scriptfile_path - 4 ) )
      
      local lua_obj = _G[key]
      if not lua_obj then 
        print( "[RTD] Couldn't find lua object for " .. tostring(key) .. " when running " .. tostring(value["ScriptFile"]) )
      else
        _G[key] = nil
        
        if not lua_obj.OnCreated then 
          lua_obj.OnCreated = function(self, keys) end
        end
        
        if not lua_obj.GetSpecialValueFor then 
          lua_obj.GetSpecialValueFor = function(self, name) 
            return result:GetAbilitySpecialByName( name )
          end
        end
        
        result.lua_object = lua_obj
      end
    end
  elseif result.is_lua then 
    print( "[RTD] Lua modifier " .. tostring(key) .. " does not specify a scriptfile - it won't do anything!")
    result.lua_object = {
      OnCreated = function() end,
      GetSpecialValueFor = function() end
    }
  end
  
  if value["AbilitySpecial"] then
    for index, data in pairs(value["AbilitySpecial"]) do 
      local var_name
      local var_value
      
      for k,v in pairs(data) do
        if k ~= "var_type" then 
          var_name = k
          var_value = tonumber(v)
          break
        end
      end
      
      result.ability_special[var_name] = var_value
    end
  end
  
  if value["Modifiers"] then 
    if not result.is_datadriven then 
      print( "[RTD] Non-datadriven modifier " .. tostring(key) .. " has a Modifiers section - it doesn't do anything!" )
    end
    
    local keyvalue_modifiers = value["Modifiers"]
    for index_str, data in pairs(keyvalue_modifiers) do
      local index = tonumber(index_str)
      
      local cust_obj = {}
      
      for func_name, func_data in pairs(data) do
        if func_name == 'OnCreated' then 
          local actions = {}
          
          for action_name, action_data in pairs(func_data) do
            if action_name == 'ApplyModifier' then 
              local modifier_name = action_data["ModifierName"]
              if not modifier_name then 
                print( "[RTD] missing ModifierName for " .. tostring(action_name) .. " inside " .. tostring(func_name) .. " of modifier " .. tostring(index) .. " of " .. tostring(result.name) )
              end
              
              local modifier_data_kv = action_data["Data"]
              local modifier_data = {}
              if modifier_data_kv then 
                for modifier_data_key, modifier_data_value in pairs(modifier_data_kv) do 
                  if rtd_stringstarts(modifier_data_value, '%') then 
                    local replacement_data_name = string.sub( modifier_data_value, 2, #modifier_data_value )
                    local replacement_data_value = result:GetAbilitySpecialByName( replacement_data_name )
                    if replacement_data_value == nil then 
                      print(" [RTD] Could not find replacement value for modifier key=value  " .. tostring(modifier_data_key) .. "=" .. tostring(modifier_data_value) .. " for " .. tostring(action_name) .. " inside " .. tostring(func_name) .. " of modifier " .. tostring(index) .. " of " .. tostring(result.name) )
                    end
                    modifier_data[modifier_data_key] = replacement_data_value
                  else
                    modifier_data[modifier_data_key] = tonumber(modifier_data_value)
                  end
                end
              end
              
              table.insert(actions, function(self, keys)
                local playerid = keys.playerid
                local hero = PlayerResource:GetSelectedHeroEntity( playerid )
                
                hero:AddNewModifier( hero, nil, modifier_name, modifier_data )
              end)
            else
              print( "[RTD] Weird action_name " .. tostring(action_name) .. " inside " .. tostring(func_name) .. " of modifier " .. tostring(index) .. " of " .. tostring(result.name) )
            end
          end
          
          function cust_obj:OnCreated( keys )
            for _, action in ipairs(actions) do 
              action(self, keys)
            end
          end
        else
          print( "[RTD] Weird func_name " .. tostring(func_name) .. ' in modifier ' .. tostring(index) .. ' of ' .. tostring(result.name) )
        end
      end
      
      table.insert(result.datadriven_objects, cust_obj)
    end
  end
  return result
end


local results_kv = LoadKeyValues( "scripts/rtd/rollthedice_results.txt" )
local modifiers_kv = LoadKeyValues( "scripts/rtd/rollthedice_modifiers.txt" )

local modifiers = {}
for modifier_name, modifier_data in pairs(modifiers_kv) do 
  local modifier = rtd_modifier:Parse( modifier_name, modifier_data )
  
  table.insert( modifiers, modifier )
end

local results = {}
for index_str, result_name in pairs(results_kv["Results"]) do 
  local index = tonumber(index_str)
  local modifier_name = result_name
  local result = rtd_result:CreateNew( { index = index, modifier_name = modifier_name } )
  result:Link( modifiers )
  
  table.insert( results, result )
end

rollthedice.results = results
rollthedice.modifiers = modifiers