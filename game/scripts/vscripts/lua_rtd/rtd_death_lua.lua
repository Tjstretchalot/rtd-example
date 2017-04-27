if not rtd_death_lua then 
  rtd_death_lua = class( {} )
end

function rtd_death_lua:OnCreated( keys )
  local playerid = keys.playerid
  local hero = PlayerResource:GetSelectedHeroEntity( playerid )
  
  hero:AddNewModifier( hero, nil, 'modifier_kill', { Duration = self:GetSpecialValueFor('duration') } )
end