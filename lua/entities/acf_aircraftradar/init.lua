
AddCSLuaFile( "cl_init.lua" )
AddCSLuaFile( "shared.lua" )

include('shared.lua')
include('radar_types_support.lua')

CreateConVar('sbox_max_acf_aircraftradar', 6)

function ENT:Initialize()
	
	self.BaseClass.Initialize(self)
	
	self.Inputs = WireLib.CreateInputs( self, { "Active" } )
	self.Outputs = WireLib.CreateOutputs( self, {"Detected", "ClosestDistance", "Entities [ARRAY]", "Position [ARRAY]", "Velocity [ARRAY]"} )
	
	self.ThinkDelay = 0.1
	self.StatusUpdateDelay = 0.5
	self.LastStatusUpdate = CurTime()
	
	self.LegalMass = self.Weight or 0
	
	self.Active = false
	
	self:CreateRadar((self.ACFName or "Aircraft Radar"), (self.ConeDegs or 0))
	
	self:EnableClientInfo(true)
	
	self:ConfigureForClass()
	
	self:SetActive(false)
	
end

function ENT:ConfigureForClass()

	local behaviour = ACFM.RadarBehaviour[self.Class]
	
	if not behaviour then return end
	
	self.GetDetectedEnts = behaviour.GetDetectedEnts

end

function ENT:TriggerInput( inp, value )
	if inp == "Active" then
		self:SetActive(value ~= 0)
	end
end

function ENT:SetActive(active)

	self.Active = active
	
	if active then
		local sequence = self:LookupSequence("active") or 0
		self:ResetSequence(sequence)
		self.AutomaticFrameAdvance = true
	else
		local sequence = self:LookupSequence("idle") or 0
		self:ResetSequence(sequence)
		self.AutomaticFrameAdvance = false
	end

end

function MakeACF_AircraftRadar(Owner, Pos, Angle, Id)

	if not Owner:CheckLimit("_acf_aircraftradar") then return false end

	local weapon = ACF.Weapons.Guns[Data1]

	local radar = ACF.Weapons.Radar[Id]
	
	if not radar then return false end
	
	local Radar = ents.Create("acf_aircraftradar")
	if not Radar:IsValid() then return false end
	Radar:SetAngles(Angle)
	Radar:SetPos(Pos)
	
	Radar.Model 	= radar.model
	Radar.Weight 	= radar.weight
	Radar.ACFName 	= radar.name
	Radar.ConeDegs 	= radar.viewcone
	Radar.Range 	= radar.range
	Radar.Id 		= Id
	Radar.Class 	= radar.class
	
	Radar:Spawn()
	Radar:SetPlayer(Owner)
	
	if CPPI then
		Radar:CPPISetOwner(Owner)
	end
	
	Radar.Owner = Owner
	
	Radar:SetModelEasy(radar.model)
	
	Owner:AddCount( "_acf_aircraftradar", Radar )
	Owner:AddCleanup( "acfmenu", Radar )
	
	return Radar
	
end
list.Set( "ACFCvars", "acf_aircraftradar", {"id"} )
duplicator.RegisterEntityClass("acf_aircraftradar", MakeACF_AircraftRadar, "Pos", "Angle", "Id" )

function ENT:CreateRadar(ACFName, ConeDegs)
	
	self.ConeDegs = ConeDegs
	self.ACFName = ACFName
	
	self:RefreshClientInfo()
	
end

function ENT:RefreshClientInfo()

	self:SetNWFloat("ConeDegs", self.ConeDegs)
	self:SetNWFloat("Range", self.Range)
	self:SetNWString("Id", self.ACFName)
	self:SetNWString("Name", self.ACFName)

end

function ENT:SetModelEasy(mdl)

	local Rack = self
	
	Rack:SetModel( mdl )	
	Rack.Model = mdl
	
	Rack:PhysicsInit( SOLID_VPHYSICS )      	
	Rack:SetMoveType( MOVETYPE_VPHYSICS )     	
	Rack:SetSolid( SOLID_VPHYSICS )
	
	local phys = Rack:GetPhysicsObject()  	
	if (phys:IsValid()) then 
		phys:SetMass(Rack.Weight)
	end 	
	
end

function ENT:Think()
 	
	if self.Inputs.Active.Value ~= 0 and self:AllowedToScan() then
		self:ScanForAircraft()
	else
		self:ClearOutputs()
	end
	
	local curTime = CurTime()
	
	self:NextThink(curTime + self.ThinkDelay)
	
	if (self.LastStatusUpdate + self.StatusUpdateDelay < curTime) then
		self:UpdateStatus()
		self.LastStatusUpdate = curTime
	end
	
	return true
		
end

--adapted from acf engine checks, thanks ferv
--returns if passes weldparent check.  True means good, false means bad
function ENT:CheckWeldParent()
	
	local entParent = self:GetParent()

	-- if it's not parented we're fine
	if not IsValid( self:GetParent() ) then return true end

	--if welded to parent, it's ok
	for k, v in pairs( constraint.FindConstraints( self, "Weld" ) ) do
		if v.Ent1 == entParent or v.Ent2 == entParent then return true end
	end

	return false
	
end

function ENT:UpdateStatus()

	local phys = self.Entity:GetPhysicsObject()  	
	if not IsValid(phys) then 
		self:SetNetworkedBool("Status", "Physics error, please respawn this") 
		return 
	end

	if phys:GetMass() < self.LegalMass then
		self:SetNetworkedBool("Status", "Illegal mass, should be " .. self.LegalMass .. " kg") 
		return 
	end
	
	if not self:CheckWeldParent() then
		self:SetNetworkedBool("Status", "Deactivated: parenting is disallowed") 
		return 
	end
	
	if not self.Active then
		self:SetNetworkedBool("Status", "Inactive")
	elseif self.Outputs.Detected.Value > 0 then
		self:SetNetworkedBool("Status", self.Outputs.Detected.Value .. " objects detected!")
	else
		self:SetNetworkedBool("Status", "Active")
	end

end

function ENT:AllowedToScan()

	if not self.Active then return false end

	local phys = self.Entity:GetPhysicsObject()  	
	if not IsValid(phys) then print("invalid phys") return false end
	--TODO: replace self:getParent with a function check on if weldparent valid.
	return ( phys:GetMass() == self.LegalMass ) and ( not IsValid(self:GetParent()) )

end

function ENT:GetDetectedEnts()

	print("reached base GetDetectedEnts")

end

function ENT:ScanForAircraft()

	local aircraft = self:GetDetectedEnts() or {}
	local entArray = {}
	local posArray = {}
	local velArray = {}
	local i = 0
	local closest
	local closestSqr = 999999
	local thisPos = self:GetPos()
	
	for _, veh in pairs(aircraft) do
		if (IsValid(veh)) then
			i = i + 1
		
			entArray[i] = veh
			posArray[i] = veh:GetPos()
			velArray[i] = veh:GetVelocity()
			
			local curSqr = thisPos:DistToSqr(veh:GetPos())
			if curSqr < closestSqr then
				closest = veh:GetPos()
				closestSqr = curSqr
			end
		end
	end
	
	if not closest then closestSqr = 0 end
	
	WireLib.TriggerOutput( self, "Detected", i )
	WireLib.TriggerOutput( self, "ClosestDistance", math.sqrt(closestSqr) )
	WireLib.TriggerOutput( self, "Entities", entArray )
	WireLib.TriggerOutput( self, "Position", posArray )
	WireLib.TriggerOutput( self, "Velocity", velArray )

	if i > (self.LastAircraftCount or 0) then
		self:EmitSound( self.Sound or ACFM.DefaultRadarSound, 500, 100 )
	end
	
	self.LastAircraftCount = i
	
end

function ENT:ClearOutputs()

	if #self.Outputs.Entities.Value > 0 then
		WireLib.TriggerOutput( self, "Entities", {} )
	end

	if #self.Outputs.Position.Value > 0 then
		WireLib.TriggerOutput( self, "Position", {} )
		WireLib.TriggerOutput( self, "ClosestDistance", 0 )
	end
	
	if #self.Outputs.Velocity.Value > 0 then
		WireLib.TriggerOutput( self, "Velocity", {} )
	end

end

function ENT:EnableClientInfo(bool)
	self.ClientInfo = bool
	self:SetNetworkedBool("VisInfo", bool)
	
	if bool then
		self:RefreshClientInfo()
	end
end
