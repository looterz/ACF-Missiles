print("missile radar type support loaded")

ACFM.RadarBehaviour["DIR-AM"] = 
{
	GetDetectedEnts = function(self)
		return ACFM_GetMissilesInCone(self:GetPos(), self:GetForward(), self.ConeDegs)
	end
}

ACFM.RadarBehaviour["OMNI-AM"] = 
{
	GetDetectedEnts = function(self)
		return ACFM_GetMissilesInSphere(self:GetPos(), self.Range)
	end
}
