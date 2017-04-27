if modifier_rtd_timer == nil then
  modifier_rtd_timer = class( {} )
end

function modifier_rtd_timer:DeclareFunctions()
  return {}
end

function modifier_rtd_timer:IsHidden()
  return false
end

function modifier_rtd_timer:IsPurgable()
  return false
end

function modifier_rtd_timer:IsPurgeException()
  return false
end

function modifier_rtd_timer:RemoveOnDeath()
  return false
end

function modifier_rtd_timer:IsPermanent()
  return false
end

function modifier_rtd_timer:GetTexture()
  return "holdout_guardian_angel"
end

function modifier_rtd_timer:DestroyOnExpire()
  return true
end