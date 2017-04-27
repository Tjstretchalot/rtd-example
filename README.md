# rtd-example

This is a gamemode to showcase the -rtd command that you can put into
your mods. [RTD](https://forums.alliedmods.net/showthread.php?p=849987) is a common command in counter-strike gamemodes that 
lets players "roll-the-dice" (with a cooldown) to get random modifiers
like 15 seconds invunerability, max gold, negative gold, instant death,
30 seconds max speed, etc.

## Barebones installation

To install rtd in your gamemode:

- copy [rollthedice.lua](https://github.com/Tjstretchalot/rtd-example/blob/master/game/scripts/vscripts/libraries/rollthedice.lua)
into your game/scripts/vscripts/libraries folder 
- copy [game/scripts/vscripts/lua_rtd/](https://github.com/Tjstretchalot/rtd-example/blob/master/game/scripts/vscripts/lua_rtd/) to the same spot in your gamemode
- copy [game/scripts/rtd/](https://github.com/Tjstretchalot/rtd-example/blob/master/game/scripts/rtd/) to the same spot in your gamemode

- In addon_game_mode.lua initialize it with

    require ('libraries/rollthedice')
    
- In [events.lua](https://github.com/Tjstretchalot/rtd-example/blob/master/game/scripts/vscripts/events.lua) under GameMode:OnPlayerChat(keys)
call 

    rollthedice:OnPlayerChat(keys)

and rollthedice will take care of the rest!

## Configuration

The main configuration files are [rollthedice_results.txt](https://github.com/Tjstretchalot/rtd-example/blob/master/game/scripts/rtd/rollthedice_results.txt) and 
[rollthedice_modifiers.txt](https://github.com/Tjstretchalot/rtd-example/blob/master/game/scripts/rtd/rollthedice_results.txt).

### rollthedice_results.txt

This file maps rolls to their respective results. Rolls are between 1 and 99 (inclusive). An example file is like so:

<pre>
"RollTheDice"
{
  "Results"
  {
    "01" "rtd_nothing"
    "02" "rtd_nothing"
    <omitted>
    "98" "rtd_nothing"
    "99" "rtd_nothing"
  }
}
</pre>

This would map every roll to the modifier rtd_nothing, which would need to be defined in rollthedice_modifiers.txt

### rollthedice_modifiers.txt

This file describes the results that are defined in rollthedice_results.txt. An example of the file with nothing
defined would be:

<pre>
"RollTheDice"
{
}
</pre>

From here you can add modifiers in one of two ways: DataDriven or Lua. The datadriven option is not as comprehensive
as datadriven abilities or items. You may specifiy "AbilitySpecial" like usual, and reference it in the normal fashion.

#### Lua Modifiers

A lua modifier will attach to a script file which must define a class that matches the name of the modifier in the 
global context. The class will be provided the context which rollthedice runs in, and rollthedice will strip the modifier
from the global context once it has acquired it. The class may override or use the following functions:

```lua
-- Called when a player lands on this result. The player is guarranteed
-- to have selected a hero and be alive.
-- 
-- @param keys (table)
--   keys.playerid - the player id who got the result
function rtd_example:OnCreated( keys )

-- Returns the special value for the specified name.
--
-- @params name (string)
--   the name of the special value to find
function rtd_example:GetSpecialValueFor( name )
```

Example:

<pre>
"RollTheDice"
{
  "rtd_example"
  {
    "BaseClass" "rtd_lua" // choices are rtd_datadriven or rtd_lua
    "ScriptFile" "scripts/vscripts/lua_rtd/rtd_example.lua"
    
    "AbilitySpecial"
    {
      "01"
      {
        "var_type" "FIELD_INTEGER"
        "duration" "10"
      }
    }
  }
}
</pre>

with rtd_example.lua as 

```lua
if not rtd_example then 
  rtd_example = class( {} )
end

function rtd_example:OnCreated( keys )
  local playerid = keys.playerid
  local hero = PlayerResource:GetSelectedHeroEntity( playerid )
  
  hero:AddNewModifier( hero, nil, 'modifier_kill', { Duration: self:GetSpecialValueFor('duration') } )
end
```

#### DataDriven modifiers

DataDriven modifiers may currently only apply a modifier to the player. This is done as follows:

Example:

<pre>
"RollTheDice"
{
  "rtd_example"
  {
    "BaseClass" "rtd_datadriven" // choices are rtd_datadriven or rtd_lua
    
    "AbilitySpecial"
    {
      "01"
      {
        "var_type" "FIELD_INTEGER"
        "duration" "10"
      }
    }
    
    "Modifiers"
    {
      "01"
      {
        "OnCreated"
        {
          "ApplyModifier"
          {
            "ModifierName" "modifier_kill" // As if you were using AddNewModifier
            "Data" // This is passed as modifierData to AddNewModifier
            {
              "Duration" "%duration"
            }
          }
        }
      }
    }
  }
}
</pre>