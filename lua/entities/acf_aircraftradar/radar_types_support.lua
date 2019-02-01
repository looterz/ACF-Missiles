print("aircraft radar type support loaded")

ACFM.RadarBehaviour["DIR-AA"] = 
{
	GetDetectedEnts = function(self)
		return ACFM_GetAircraftInCone(self:GetPos(), self:GetForward(), self.ConeDegs)
	end,
	GetDetectedFlares = function(self)
		return ACFM_GetFlaresInCone(self:GetPos(), self:GetForward(), self.ConeDegs)
	end,
}
