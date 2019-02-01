print("aircraft radar type support loaded")

ACFM.RadarBehaviour["DIR-AA"] = 
{
	GetDetectedEnts = function(self)
		return ACFM_GetAircraftInCone(self:GetPos(), self:GetForward(), self.ConeDegs)
	end
}

ACFM.RadarBehaviour["OMNI-AA"] = 
{
	GetDetectedEnts = function(self)
		return ACFM_GetAircraftInSphere(self:GetPos(), self.Range)
	end
}
