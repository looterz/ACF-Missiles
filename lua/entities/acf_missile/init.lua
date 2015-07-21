AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")

include("shared.lua")


DEFINE_BASECLASS("acf_explosive")




function ENT:Initialize()

	self.BaseClass.Initialize(self)

	if !IsValid(self.Entity.Owner) then
		self.Owner = player.GetAll()[1]
	end

	self.Entity:SetOwner(self.Entity.Owner)

    self.VelocityOffset = -1
    
	self.PhysObj = self.Entity:GetPhysicsObject()
	self.PhysObj:EnableGravity( false )
	self.PhysObj:EnableMotion( false )
	
	self.SpecialDamage = true	--If true needs a special ACF_OnDamage function
	self.SpecialHealth = true	--If true needs a special ACF_Activate function
    
end




function ENT:SetBulletData(bdata)

    self.BaseClass.SetBulletData(self, bdata)
    
    local gun = list.Get("ACFEnts").Guns[bdata.Id]
    
    self:SetModelEasy( gun.round.model or gun.model or "models/missiles/aim9.mdl" )
    
    self:ParseBulletData(bdata)
	
    local roundWeight = ACF_GetGunValue(bdata, "weight") or 10
    
    local phys = self.Entity:GetPhysicsObject()  	
	if (IsValid(phys)) then  		
		phys:SetMass( roundWeight ) 
	end 
    
    self.RoundWeight = roundWeight
    
    self:ConfigureFlight()
    
end




function ENT:ParseBulletData(bdata)
    
    local guidance  = bdata.Data7
    local fuse      = bdata.Data8
    
    if guidance then        
        xpcall( -- we're eating arbitrary user input, so let's not fuck up if they fuck up
                function()
                    guidance = self:CreateConfigurable(guidance, ACF.Guidance, bdata, "guidance")
                    if guidance then self:SetGuidance(guidance) end
                end,
                
                ErrorNoHalt
              )
    end
    
    if fuse then
        xpcall( -- we're eating arbitrary user input, so let's not fuck up if they fuck up
                function()
                    fuse = self:CreateConfigurable(fuse, ACF.Fuse, bdata, "fuses")
                    if fuse then self:SetFuse(fuse) end
                end,
                
                ErrorNoHalt
              )        
    end
    
end




local Cast = 
{
    number = function(str) return tonumber(str) end,
    string = function(str) return str end,
    boolean = function(str) return tobool(str) end
}

--TODO: move to global file.
function ENT:CreateConfigurable(str, configurables, bdata, wlistPath)

    -- we're parsing a string of the form "NAME:CMD=VAL:CMD=VAL"... potentially.
    
    local parts = {}
    -- split parts delimited by ':'
    for part in string.gmatch(str, "[^:]+") do parts[#parts+1] = part end
    
    if #parts <= 0 then return end
    
    
    local name = table.remove(parts, 1)
    if name and name ~= "" then
        
        -- base table for configurable object
        local class = configurables[name]
        if not class then return end
        
        
        if bdata then
            local allowed = ACF_GetGunValue(bdata, wlistPath)
            if not table.HasValue(allowed, name) then return nil end
        end
        
        
        local args = {}
        
        for _, arg in pairs(parts) do
            -- get CMD from 'CMD=VAL'
            local cmd = string.match(arg, "^[^=]+")
            if not cmd then continue end
            
            -- get VAL from 'CMD=VAL'
            local val = string.match(arg, "[^=]+$")
            if not val then continue end
            
            args[string.lower(cmd)] = val
        end
        
        
        -- construct new instance of configurable object
        local instance = class()
        if not instance.Configurable then return instance end
        
        
        -- loop through config, match up with args and set values accordingly
        for _, config in pairs(instance.Configurable) do
        
            local cmdName = config.CommandName
            
            if not cmdName then continue
            else cmdName = string.lower(cmdName) end
            
            local arg = args[cmdName]
            if not arg then continue end
            
            local type = config.Type
            
            if Cast[type] then 
                instance[config.Name] = Cast[type](arg)
            end
        
        end
        
        return instance
        
    end

end




function ENT:CalcFlight()

    if self.MissileDetonated then return end

	local Ent = self.Entity
	local Pos = self.CurPos
	local Dir = self.CurDir

	local LastPos = self.LastPos
	local LastVel = self.LastVel
	local Speed = LastVel:Length()
	local Flight = self.FlightTime

    local Time = CurTime()
    local DeltaTime = Time - self.LastThink
    self.LastThink = Time
	Flight = Flight + DeltaTime

	if Speed == 0 then
		LastVel = Dir
		Speed = 1
	end


	--Guidance calculations
	local Guidance = self.Guidance:GetGuidance(self)
	local TargetPos = Guidance.TargetPos

	if TargetPos and self.First then
        
		local Dist = Pos:Distance(TargetPos)
        
		local TargetVel = (Guidance.TargetVel or Vector(0,0,0)) / DeltaTime * 0.03
		local DirRaw = TargetPos - Pos
		local DirRawNorm = DirRaw:GetNormalized()
		local SpeedMul = math.min((Speed / DeltaTime / self.MinimumSpeed) ^ 3,1)
		--print(SpeedMul)

		--Target position projection
		local LockOffset = (((TargetVel - LastVel) / Speed + Vector(0,0,DeltaTime * self.Gravity / 1000)) * Dist) or NewDir
		local ProjOffset = LockOffset - LockOffset:Dot(DirRawNorm) * DirRawNorm
		local DirProj = TargetPos + ProjOffset - Pos
		local DirProjNorm = DirProj:GetNormalized()

		local VelAxis = LastVel:Cross(DirProj)
		local VelAxisNorm = VelAxis:GetNormalized()
        
		local AngDiff = math.deg( math.asin( math.min(VelAxis:Length() / (Dist * Speed), 0.999999) ) )

		if AngDiff > 0 then
			local Agility = self.Agility

			--Target facing
			local Ang = Dir:Angle()
			Ang:RotateAroundAxis( VelAxisNorm, math.Clamp(AngDiff * SpeedMul,-1,1) * Agility )
			local NewDir = Ang:Forward()

			--Velocity stabilisation
			local DirAxis = NewDir:Cross(DirRawNorm)
			local RawDotSimple = NewDir.x * DirRawNorm.x + NewDir.y * DirRawNorm.y + NewDir.z * DirRawNorm.z
			local RawAng = math.deg(math.acos(RawDotSimple))		--Since both vectors are normalised, calculating the dot product should be faster this way
			Ang:RotateAroundAxis( DirAxis, math.Clamp(RawAng * SpeedMul,-1,1) * (self.MinimumSpeed / 2000 + self.FinMultiplier * 100) * Agility)
			NewDir = Ang:Forward()

			--FOV check
			local TotalDotSimple = NewDir.x * DirRawNorm.x + NewDir.y * DirRawNorm.y + NewDir.z * DirRawNorm.z
			local TotalAng = math.deg(math.acos(TotalDotSimple))

			if not Guidance.ViewCone or TotalAng <= Guidance.ViewCone then  -- ViewCone is active-seeker specific
				Dir = NewDir
			end
		end

	else
    
		local DirAng = Dir:Angle()
		local VelNorm = LastVel:GetNormalized()
		local AimDiff = Dir - VelNorm
		local DiffLength = AimDiff:Length()
		if DiffLength >= 0.01 then
			local Torque = DiffLength * self.TorqueMul
			local AngVelDiff = Torque / self.Inertia * DeltaTime
			local DiffAxis = AimDiff:Cross(Dir):GetNormalized()
			self.RotAxis = self.RotAxis + DiffAxis * AngVelDiff
		end

		self.RotAxis = self.RotAxis * 0.99
        DirAng:RotateAroundAxis(self.RotAxis, self.RotAxis:Length())
		Dir = DirAng:Forward()
	end
	
    self.First = true

	--Motor cutout
	if Time > self.CutoutTime then
		if self.Motor ~= 0 then
			self.Entity:StopParticles()
			self.Motor = 0
		end
	end

	--Physics calculations
	local Vel = LastVel + (Dir * self.Motor - Vector(0,0,self.Gravity)) * ACF.VelScale * DeltaTime ^ 2
	local Up = Dir:Cross(Vel):Cross(Dir):GetNormalized()
	local Speed = Vel:Length()
	local VelNorm = Vel / Speed
	local DotSimple = Up.x * VelNorm.x + Up.y * VelNorm.y + Up.z * VelNorm.z
	Vel = Vel - Up * Speed * DotSimple * self.FinMultiplier

	local SpeedSq = Vel:LengthSqr()
	local Drag = Vel:GetNormalized() * (self.DragCoef * SpeedSq) / ACF.DragDiv * ACF.VelScale
	Vel = Vel - Drag
	local EndPos = Pos + Vel

	--Hit detection
	local tracedata={}
	tracedata.start = Pos
	tracedata.endpos = EndPos
	tracedata.filter = self.Filter
	local trace = util.TraceLine(tracedata)

	if trace.Hit then
		self.HitNorm = trace.HitNormal
		self:DoFlight(trace.HitPos)
		self.LastVel = Vel / DeltaTime
		self:Detonate()
		return
	end



	--print("Vel = "..math.Round(Vel:Length() / DeltaTime))
    
    if self.Fuse:GetDetonate(self, self.Guidance) then
		self.LastVel = Vel / DeltaTime
		self:Detonate()
		return
	end
    
	self.LastVel = Vel
	self.LastPos = Pos
	self.CurPos = EndPos
	self.CurDir = Dir
	self.FlightTime = Flight
	
	debugoverlay.Line(EndPos, EndPos + Vel:GetNormalized() * 50, 10, Color(0, 255, 0))
	debugoverlay.Line(EndPos, EndPos + Dir:GetNormalized()  * 50, 10, Color(0, 0, 255))
	--debugoverlay.Line(EndPos, EndPos + Up * 50, 10, Color(255, 0, 0))

	self:DoFlight()
end




function ENT:SetGuidance(guidance)
    
	self.Guidance = guidance
	guidance:Configure(self)

    return guidance
    
end




function ENT:SetFuse(fuse)

	self.Fuse = fuse
    fuse:Configure(self, self.Guidance or self:SetGuidance(ACF.Guidance.Dumb()))

    return fuse

end




function ENT:Launch()

	if not self.Guidance then
		self:SetGuidance(ACF.Guidance.Dumb())
	end
    
    if not self.Fuse then
        self:SetFuse(ACF.Fuse.Contact())
    end

    self.Guidance:Configure(self)
    self.Fuse:Configure(self, self.Guidance)
    
	self.Launched = true
	self.ThinkDelay = 1 / 66
	self.Filter = self.Filter or {self}
    
    self:SetParent(nil)
    
    self:ConfigureFlight()
    
	local phys = self:GetPhysicsObject()
	phys:EnableMotion(false)
	
	if self.Motor > 0 or self.MotorLength > 0.1 then
		self.CacheParticleEffect = CurTime() + 0.01
	end
	
    self:LaunchEffect()
    
	self:Think()
end




function ENT:LaunchEffect()

    local guns = list.Get("ACFEnts").Guns
    local class = guns[self.BulletData.Id]
    
    local sound = self.BulletData.Sound or ACF_GetGunValue(self.BulletData, "sound")
    
    if sound then
        self:EmitSound(sound, 511, 100)
    end
    
end




function ENT:ConfigureFlight()

	local BulletData = self.BulletData
    
	local GunData = list.Get("ACFEnts").Guns[BulletData.Id]
    
	local Round = GunData.round
	local BurnRate = Round.burnrate

    local Time = CurTime()
	self.MotorLength = BulletData.PropMass / (Round.burnrate / 1000) * (1 - Round.starterpct)
	self.Gravity = GetConVar("sv_gravity"):GetFloat()
	self.DragCoef = Round.dragcoef
	self.Motor = Round.thrust
	self.MinimumSpeed = Round.minspeed
	self.FlightTime = 0
	self.FinMultiplier = Round.finmul
	self.Agility = GunData.agility or 1
	self.CutoutTime = Time + self.MotorLength
	self.CurPos = BulletData.Pos
	self.CurDir = BulletData.Flight:GetNormalized()
	self.LastPos = self.CurPos
    self.Hit = false
	self.HitNorm = Vector(0,0,0)
	self.FirstThink = true
    self.MinArmingDelay = Round.armdelay or 0
    
    local Mass = GunData.weight
    local Length = GunData.length
	local Width = GunData.caliber
	self.Inertia = 0.08333 * Mass * (3.1416 * (Width / 2) ^ 2 + Length)
	self.TorqueMul = Length * 25
	self.RotAxis = Vector(0,0,0)
    
end




function ENT:DoFlight(ToPos, ToDir)
	--if !IsValid(self.Entity) or self.MissileDetonated then return end

	local setPos = ToPos or self.CurPos
	local setDir = ToDir or self.CurDir
    
	self:SetPos(setPos)
	self:SetAngles(setDir:Angle())
    
    self.BulletData.Pos = setPos
    --self.BulletData.Flight = self.LastVel
end




function ENT:Detonate()
 
    if self.Fuse and (CurTime() - self.Fuse.TimeStarted < self.MinArmingDelay or not self.Fuse:IsArmed()) then
        self:Dud()
        return
    end
        
    self.BulletData.Flight = self:GetForward() * (self.BulletData.MuzzleVel or 10)
    debugoverlay.Line(self.BulletData.Pos, self.BulletData.Pos + self.BulletData.Flight, 10, Color(255, 0, 0))
    
    if self.Motor ~= 0 then
        self.Entity:StopParticles()
        self.Motor = 0
    end    
     
    -- Safeguard against teleporting explosions.
    if IsValid(self.Launcher) and not self.Launched then
        return
    end
     
    self:ForceDetonate()
	
end




function ENT:ForceDetonate()

	self.MissileDetonated = true    -- careful not to conflict with base class's self.Detonated
    
    self.BaseClass.Detonate(self, self.BulletData)
	
end




function ENT:Dud()
    
    self.MissileDetonated = true

	local Dud = ents.Create( "debris" )
	Dud:SetModel( self.Entity:GetModel() )
	Dud:SetPos( self.CurPos )
	Dud:SetAngles( self.CurDir:Angle() )
	Dud:Spawn()
    self:Remove()

	local Phys = Dud:GetPhysicsObject()
	local Vel = self.LastVel

	if self.HitNorm != Vector(0,0,0) then
		local Dot = self.CurDir:Dot(self.HitNorm)
		local NewDir = self.CurDir - 2 * Dot * self.HitNorm
		local VelMul = (0.8 + Dot * 0.7) * Vel:Length()
		Vel = NewDir * VelMul
	end

	Phys:SetVelocity(Vel)
end




function ENT:Think()
	local Time = CurTime()

	if self.Launched then
	
		if self.Hit then
			self:Detonate()
			return false
		end

		if self.FirstThink == true then
			self.FirstThink = false
			self.LastThink = CurTime()
			self.LastVel = self.Launcher:GetVelocity() / 66

		end
		self:CalcFlight()
		
        if self.CacheParticleEffect and (self.CacheParticleEffect <= CurTime()) and (CurTime() < self.CutoutTime) then
            local effect = ACF_GetGunValue(self.BulletData, "effect")
            
            if effect then
                ParticleEffectAttach( effect, PATTACH_POINT_FOLLOW, self, self:LookupAttachment("exhaust") or 0 )
            end
            
            self.CacheParticleEffect = nil
        end
        
	end
	
	return self.BaseClass.Think(self)
end




function ENT:PhysicsCollide()
	if self.Launched then self:Detonate() end
end




function ENT:ACF_Activate( Recalc )
	
	local EmptyMass = self.RoundWeight or self.Mass or 10

	self.ACF = self.ACF or {} 
	
	local PhysObj = self:GetPhysicsObject()
	if not self.ACF.Aera then
		self.ACF.Aera = PhysObj:GetSurfaceArea() * 6.45
	end
	if not self.ACF.Volume then
		self.ACF.Volume = PhysObj:GetVolume() * 16.38
	end
	
	local ForceArmour = ACF_GetGunValue(self.BulletData, "armour")
	
	local Armour = ForceArmour or (EmptyMass*1000 / self.ACF.Aera / 0.78) --So we get the equivalent thickness of that prop in mm if all it's weight was a steel plate
	local Health = self.ACF.Volume/ACF.Threshold							--Setting the threshold of the prop aera gone 
	local Percent = 1 
	
	if Recalc and self.ACF.Health and self.ACF.MaxHealth then
		Percent = self.ACF.Health/self.ACF.MaxHealth
	end
	
	self.ACF.Health = Health * Percent
	self.ACF.MaxHealth = Health
	self.ACF.Armour = Armour * (0.5 + Percent/2)
	self.ACF.MaxArmour = Armour
	self.ACF.Type = nil
	self.ACF.Mass = self.Mass
	self.ACF.Density = (self:GetPhysicsObject():GetMass()*1000) / self.ACF.Volume
	self.ACF.Type = "Prop"
	
end




local nullhit = {Damage = 0, Overkill = 1, Loss = 0, Kill = false}

function ENT:ACF_OnDamage( Entity , Energy , FrAera , Angle , Inflictor )	--This function needs to return HitRes

	if self.Detonated or self.DisableDamage then return table.Copy(nullhit) end

	local HitRes = ACF_PropDamage( Entity , Energy , FrAera , Angle , Inflictor )	--Calling the standard damage prop function
	
	-- Detonate if the shot penetrates the casing.
	HitRes.Kill = HitRes.Kill or HitRes.Overkill > 0
	
	if HitRes.Kill then
	
		local CanDo = hook.Run("ACF_AmmoExplode", self, self.BulletData )
		if CanDo == false then return HitRes end
		
		self.Exploding = true
		
		if( Inflictor and Inflictor:IsValid() and Inflictor:IsPlayer() ) then
			self.Inflictor = Inflictor
		end
		
		self:ForceDetonate()
		
	end
	
	return HitRes
	
end




hook.Add("CanDrive", "acf_missile_CanDrive", function(ply, ent) 
    if ent:GetClass() == "acf_missile" then return false end
end)
