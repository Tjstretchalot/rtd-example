if rollthedice then return end

rollthedice = class( {} )

function rollthedice:OnPlayerChat( keys )
  local teamonly = keys.teamonly
  local userID = keys.userid
  local playerID = self.vUserIds[userID]:GetPlayerID()

  local text = keys.text
end