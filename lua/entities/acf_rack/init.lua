-- init.lua

AddCSLuaFile( "shared.lua" )
AddCSLuaFile( "cl_init.lua" )

include('shared.lua')



DEFINE_BASECLASS("acf_grenade")



if SERVER then
    concommand.Add("loadRack", function(ply, args)
		local lookAt = ply:GetEyeTrace()
        local lookEnt = lookAt.Entity
        if IsValid(lookEnt) and lookEnt:GetClass() == "acf_rack" then
            lookEnt:LoadAmmo(0, false)
        end
	end)
end




function ENT:GetReloadTime(nextMsl)
    local interval = IsValid(nextMsl) and ( ( ( nextMsl.BulletData.RoundVolume / 500 ) ^ 0.60 ) * self.RoFmod * self.PGRoFmod ) or 0 
    self:SetNetworkedBeamInt(	"Interval",		interval)
    
    return interval
end




function ENT:Initialize()

    self.BaseClass.Initialize(self)

	self.SpecialHealth = true	--If true needs a special ACF_Activate function
	self.SpecialDamage = true	--If true needs a special ACF_OnDamage function
	self.ReloadTime = 1
	self.Ready = true
	self.Firing = nil
	self.NextFire = 0
	self.LastSend = 0
	self.Owner = self
	
	self.IsMaster = true
	self.CurAmmo = 1
	self.Sequence = 1
	
    self.BulletData = {}
		self.BulletData.Type = "Empty"
		self.BulletData.PropMass = 0
		self.BulletData.ProjMass = 0
	
	self.Inaccuracy 	= 1
	
	self.Inputs = WireLib.CreateSpecialInputs( self, { "Fire",      "Reload",   "Target Pos" },
                                                     { "NORMAL",    "NORMAL",   "VECTOR"    } )
                                                     
	self.Outputs = WireLib.CreateSpecialOutputs( self, 	{ "Ready",	"Entity",	"Shots Left",  "Position" },
														{ "NORMAL",	"ENTITY",	"NORMAL",      "VECTOR" } )
                                                        
	Wire_TriggerOutput(self, "Entity", self)
	Wire_TriggerOutput(self, "Ready", 1)
	self.WireDebugName = "ACF Rack"
	
	self.lastCol = self:GetColor() or Color(255, 255, 255)
	self.nextColCheck = CurTime() + 2
    
    self.Missiles = {}   

    self.AmmoLink = {}
    
end



function ENT:ACF_Activate( Recalc )
	
	local EmptyMass = self.Mass --math.max(self.Mass, self:GetPhysicsObject():GetMass() - self.Mass)

	self.ACF = self.ACF or {} 
	
	local PhysObj = self:GetPhysicsObject()
	if not self.ACF.Aera then
		self.ACF.Aera = PhysObj:GetSurfaceArea() * 6.45
	end
	if not self.ACF.Volume then
		self.ACF.Volume = PhysObj:GetVolume() * 16.38
	end
	
	local Armour = EmptyMass*1000 / self.ACF.Aera / 0.78 --So we get the equivalent thickness of that prop in mm if all it's weight was a steel plate
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



//* TODO
function ENT:ACF_OnDamage( Entity , Energy , FrAera , Angle , Inflictor )	--This function needs to return HitRes

	local HitRes = ACF_PropDamage( Entity , Energy , FrAera , Angle , Inflictor )	--Calling the standard damage prop function
	
	local curammo = table.Count(self.Missiles)
	
	// Detonate rack if damage causes ammo rupture, or a penetrating shot hits some ammo.
	if not HitRes.Kill then
		local Ratio = (HitRes.Damage * (self.ACF.MaxHealth - self.ACF.Health) / self.ACF.MaxHealth)^0.2
		local ammoRatio = self.MagSize / curammo
		local chance = math.Rand(0,1)
		//print(Ratio, ammoRatio, chance, ( Ratio * ammoRatio ) > chance, HitRes.Overkill > 0 and chance > (1 - ammoRatio))
		if ( Ratio * ammoRatio ) > chance or HitRes.Overkill > 0 and chance > (1 - ammoRatio) then  
			self.Inflictor = Inflictor
			HitRes.Kill = true
		end
	end
	
	if HitRes.Kill then
		local CanDo = hook.Run("ACF_AmmoExplode", self, nil ) --  which bulletdata to use?!  let's let them figure that out.
		if CanDo == false then return HitRes end
		self.Exploding = true
		if( Inflictor and Inflictor:IsValid() and Inflictor:IsPlayer() ) then
			self.Inflictor = Inflictor
		end
		if curammo > 0 then
			self:DetonateAmmo(Inflictor)
		else
			ACF_HEKill( self , VectorRand() )
		end
	end
	
	return HitRes --This function needs to return HitRes
end
//*/



function ENT:DetonateAmmo(inflictor)
    
    self:TrimNullMissiles()
    
    local fillerMass = 0
    local fragMass = 0
    
    while IsValid(self:PeekMissile()) do
    
        local missile = self:PopMissile()
        
        local bdata = missile.BulletData
        
        if bdata.FillerMass then 
            fillerMass = fillerMass + bdata.FillerMass
        end
        
        if bdata.CasingMass then
            fragMass = fragMass + bdata.CasingMass
        elseif bdata.FillerMass and bdata.ProjMass then
            fragMass = fragMass + (bdata.ProjMass - bdata.FillerMass)
        end
        
        missile:Remove()
        
    end
    
    if fillerMass > 0 then
    
        if not IsValid(inflictor) then inflictor = nil end
    
        self.BulletData = {}
        
        self.BulletData["Id"]		= "203mmHW"
        self.BulletData["ProjLength"]		= "162.39"
        self.BulletData["PropLength"]		= "0.01"
        self.BulletData["Type"]		= "HE"
        self.BulletData["FillerMass"]		= fillerMass
        
        local bdata = ACF_CompactBulletData(self.BulletData)
        
        self:SetBulletData(bdata)
        
        self:Detonate()
        
    end
    
end




function ENT:CanLinkCrate(crate)
    
    local bdata = crate.BulletData
    
    -- Don't link if it's a refill crate
	if bdata["RoundType"] == "Refill" or bdata["Type"] == "Refill" then
		return false, "Refill crates cannot be linked!"
	end
    
    -- Don't link if it's a blacklisted round type for this gun
	local Blacklist = ACF.AmmoBlacklist[ bdata.RoundType or bdata.Type ] or {}
	
	if table.HasValue( Blacklist, self.Class ) then
		return false, "That round type cannot be used with this gun!"
	end
    
    -- Don't link if it's not a missile.
    local gun = list.Get("ACFEnts").Guns[bdata.Id]
    local Classes = list.Get("ACFClasses").GunClass
    
    if "missile" ~= Classes[gun.gunclass].type then 
        return false, "Racks cannot be linked to ammo crates of type '" .. bdata.gunclass .. "'!" 
    end
    
	-- Don't link if it's already linked
	for k, v in pairs( self.AmmoLink ) do
		if v == crate then
			return false, "That crate is already linked to this gun!"
		end
	end
    
    
    return true
    
end




function ENT:Link( Target )

	-- Don't link if it's not an ammo crate
	if not IsValid( Target ) or Target:GetClass() ~= "acf_ammo" then
		return false, "Racks can only be linked to ammo crates!"
	end
	
	
    local ret, msg = self:CanLinkCrate(Target)
	if not ret then
		return false, msg
	end
	
    
	table.insert( self.AmmoLink, Target )
	table.insert( Target.Master, self )
	
    
	return true, "Link successful!"
	
end




function ENT:Unlink( Target )

	local Success = false
	for Key,Value in pairs(self.AmmoLink) do
		if Value == Target then
			table.remove(self.AmmoLink,Key)
			Success = true
		end
	end
	
	if Success then
		return true, "Unlink successful!"
	else
		return false, "That entity is not linked to this gun!"
	end
	
end



function ENT:UnloadAmmo()
    -- we're ok with mixed munitions.
end



local WireTable = { "gmod_wire_adv_pod", "gmod_wire_pod", "gmod_wire_keyboard", "gmod_wire_joystick", "gmod_wire_joystick_multi" }

function ENT:GetUser( inp )
	if inp:GetClass() == "gmod_wire_adv_pod" then
		if inp.Pod then
			return inp.Pod:GetDriver()
		end
	elseif inp:GetClass() == "gmod_wire_pod" then
		if inp.Pod then
			return inp.Pod:GetDriver()
		end
	elseif inp:GetClass() == "gmod_wire_keyboard" then
		if inp.ply then
			return inp.ply 
		end
	elseif inp:GetClass() == "gmod_wire_joystick" then
		if inp.Pod then 
			return inp.Pod:GetDriver()
		end
	elseif inp:GetClass() == "gmod_wire_joystick_multi" then
		if inp.Pod then 
			return inp.Pod:GetDriver()
		end
	elseif inp:GetClass() == "gmod_wire_expression2" then
		if inp.Inputs["Fire"] then
			return self:GetUser(inp.Inputs["Fire"].Src) 
		elseif inp.Inputs["Shoot"] then
			return self:GetUser(inp.Inputs["Shoot"].Src) 
		elseif inp.Inputs then
			for _,v in pairs(inp.Inputs) do
				if table.HasValue(WireTable, v.Src:GetClass()) then
					return self:GetUser(v.Src) 
				end
			end
		end
	end
	return inp.Owner or inp:GetOwner()
	
end




function ENT:TriggerInput( iname , value )
	
	if ( iname == "Fire" and value ~= 0 and ACF.GunfireEnabled ) then
		if self.NextFire < CurTime() then
			self.User = self:GetUser(self.Inputs["Fire"].Src)
			if not IsValid(self.User) then self.User = self.Owner end
			self:FireMissile()
			self:Think()
		end
		self.Firing = true
	elseif ( iname == "Fire" and value == 0 ) then
		self.Firing = false
    elseif (iname == "Reload" and value ~= 0 ) then
        self:Reload()
    elseif (iname == "Target Pos" and value ~= nil) then
        Wire_TriggerOutput(self, "Position", value)
	end		
end




function ENT:Reload()


    if self.Ready or not IsValid(self:PeekMissile()) then
        self:LoadAmmo(0, true)
    end
    
end




function RetDist( enta, entb )
	if not ((enta and enta:IsValid()) or (entb and entb:IsValid())) then return 0 end
	return enta:GetPos():Distance(entb:GetPos())
end




local function RetDist( enta, entb )    -- wat
	if not ((enta and enta:IsValid()) or (entb and entb:IsValid())) then return 0 end
	disp = enta:GetPos() - entb:GetPos()
	dist = math.sqrt( disp.x * disp.x + disp.y * disp.y + disp.z * disp.z )
	return dist
end




function ENT:Think()

    local Ammo = table.Count(self.Missiles)

	local Time = CurTime()
	if self.LastSend+1 <= Time then
		
        for Key, Crate in pairs(self.AmmoLink) do
			if IsValid( Crate ) and Crate.Load then
				if RetDist( self, Crate ) >= 512 then
					self:Unlink( Crate )
					soundstr =  "physics/metal/metal_box_impact_bullet" .. tostring(math.random(1, 3)) .. ".wav"
					self:EmitSound(soundstr,500,100)
				end
			end
		end
        
		Wire_TriggerOutput(self, "Shots Left", Ammo)
		
        self:TrimNullMissiles()
		self:SetNetworkedBeamString("GunType",		self.Id)
		self:SetNetworkedBeamInt(	"Ammo",			Ammo)
        
        local interval = self:GetReloadTime(self:PeekMissile())
		self:SetNetworkedBeamInt(	"Interval",		interval)
		
		self.LastSend = Time
	
	end
	
	if self.NextFire <= Time and Ammo > 0 and Ammo <= self.MagSize then
        self.Ready = true
        Wire_TriggerOutput(self, "Ready", 1)
        --print(self.Firing , Ammo > 0)
		if self.Firing then
            self.ReloadTime = nil
			self:FireMissile()
        elseif (self.Inputs.Reload and self.Inputs.Reload.Value ~= 0) and self:CanReload() then
            self.ReloadTime = nil
            self:Reload()
        elseif self.ReloadTime and self.ReloadTime > 1 then
            self:EmitSound( "acf_extra/airfx/weapon_select.wav", 500, 100 )
            self.ReloadTime = nil
		end
    elseif self.NextFire <= Time and Ammo == 0 then
        if (self.Inputs.Reload and self.Inputs.Reload.Value ~= 0) and self:CanReload() then
            self.ReloadTime = nil
            self:Reload()
        end
    end
    
	self:NextThink(Time)
	return true
	
end




function ENT:TrimNullMissiles()
    for k, v in pairs(self.Missiles) do
        if not IsValid(v) then
            table.remove(self.Missiles, k)
        end
    end
end




function ENT:PeekMissile()

    self:TrimNullMissiles()

    local NextIdx = #self.Missiles
	if NextIdx <= 0 then return false end

    local missile = self.Missiles[NextIdx]

    return missile, NextIdx

end




function ENT:PopMissile()

    local missile, curShot = self:PeekMissile()

    if missile == false then return false end
    
    self.Missiles[curShot] = nil
    
    return missile, curShot
    
end




function ENT:FindNextCrate()

	local MaxAmmo = table.getn(self.AmmoLink)
	local AmmoEnt = nil
	local i = 0
	
	while i <= MaxAmmo and not (AmmoEnt and AmmoEnt:IsValid() and AmmoEnt.Ammo > 0) do
		
		self.CurAmmo = self.CurAmmo + 1
		if self.CurAmmo > MaxAmmo then self.CurAmmo = 1 end
		
		AmmoEnt = self.AmmoLink[self.CurAmmo]
		if AmmoEnt and AmmoEnt:IsValid() and AmmoEnt.Ammo > 0 and AmmoEnt.Load then
			return AmmoEnt
		end
		AmmoEnt = nil
		
		i = i + 1
	end
	
	return false
end




function ENT:CanReload()
    
    local Ammo = table.Count(self.Missiles)
	if Ammo >= self.MagSize then return false end
    
    local Crate = self:FindNextCrate()
    if not IsValid(Crate) then return false end
    
    local curtime = CurTime()
	if curtime < self.NextFire then return false end
    
    return true
    
end




function ENT:AddMissile()

    self:TrimNullMissiles()
    
    local Ammo = table.Count(self.Missiles)
	if Ammo >= self.MagSize then return false end
    
    local Crate = self:FindNextCrate()
    if not IsValid(Crate) then return false end
    
    local NextIdx = #self.Missiles
    
    
    local missile = ents.Create("ent_cre_missile")
    missile.Owner = ply
    missile.DoNotDuplicate = true
    missile.Launcher = self
    
    local BulletData = ACF_CompactBulletData(Crate)
    BulletData.IsShortForm = true    
    BulletData.Owner = ply
    missile:SetBulletData(BulletData)
    
    local attach, muzzle = self:GetMuzzle(NextIdx, missile)
    missile:SetPos(muzzle.Pos)
    missile:SetAngles(muzzle.Ang)
    
    missile:Spawn()
    missile:SetParent(self)
    
    self:EmitSound( "acf_extra/tankfx/resupply_single.wav", 500, 100 )
    
    self.Missiles[NextIdx+1] = missile
    
    Crate.Ammo = Crate.Ammo - 1
    
    return missile
    
end




function ENT:LoadAmmo( AddTime, Reload )
    
    if not self:CanReload() then return false end
    
    local missile = self:AddMissile()

    self:TrimNullMissiles()
    Ammo = table.Count(self.Missiles)
	self:SetNetworkedBeamInt("Ammo",	Ammo)
	
    local ReloadTime = 1
    
    if IsValid(missile) then
        ReloadTime = self:GetReloadTime(missile)
    end
    
	self.NextFire = CurTime() + ReloadTime
	if AddTime then
		self.NextFire = CurTime() + ReloadTime + AddTime
	end
	self.Ready = false
    self.ReloadTime = ReloadTime
    
	Wire_TriggerOutput(self, "Ready", 0)
	
	self:OnLoaded()
	
	self:Think()
	return true	
	
end




function ENT:OnLoaded()
	
end



if SERVER then
	concommand.Add("makeRack", function(ply, args)
		local rack = ents.Create("acf_rack")
        
		local pos = (ply:GetShootPos() + ply:GetAimVector() * 64)
		local ang = (ply:GetAimVector():Angle())

		local BulletData = {}
		BulletData["Colour"]		= Color(255, 255, 255)
		BulletData["Data10"]		= "0.00"
		BulletData["Data5"]		= "301.94"
		BulletData["Data6"]		= "30.000000"
		BulletData["Data7"]		= "0"
		BulletData["Data8"]		= "0"
		BulletData["Data9"]		= "0"
		BulletData["Id"]		= "80mmM"
		BulletData["ProjLength"]		= "12.00"
		BulletData["PropLength"]		= "0.01"
		BulletData["Type"]		= "HE"
		BulletData.IsShortForm = true
		
        local rack = MakeACF_Rack(ply, pos, ang, "4xRK", nil, BulletData)
	end)
end



function MakeACF_Rack (Owner, Pos, Angle, Id, UpdateRack)

	if not Owner:CheckLimit("_acf_gun") then return false end
	
	local Rack = UpdateRack or ents.Create("acf_rack")
	local List = ACF.Weapons.Rack
	local Classes = ACF.Classes.Rack
    
	if not Rack:IsValid() then return false end
    
	Rack:SetAngles(Angle)
	Rack:SetPos(Pos)
    
	if not UpdateRack then 
		Rack:Spawn()
		Owner:AddCount("_acf_gun", Rack)
		Owner:AddCleanup( "acfmenu", Rack )
	end
	
    Id = Id or Rack.Id
    
	Rack:SetPlayer(Owner)
	Rack.Owner = Owner
	Rack.Id = Id
	--Rack.BulletData.Id = Id
	
	local gundef = List[Id] or error("Couldn't find the " .. tostring(Id) .. " gun-definition!")
	
	Rack.Caliber	= gundef["caliber"]
	Rack.Model = gundef["model"]
	Rack.Mass = gundef["weight"]
	Rack.Class = gundef["gunclass"]
    
	-- Custom BS for karbine. Per Rack ROF.
	Rack.PGRoFmod = 1
	if(gundef["rofmod"]) then
		Rack.PGRoFmod = math.max(0, gundef["rofmod"])
	end
    
	-- Custom BS for karbine. Magazine Size, Mag reload Time
	Rack.MagSize = 1
	if(gundef["magsize"]) then
		Rack.MagSize = math.max(Rack.MagSize, gundef["magsize"] or 1)
	end
	Rack.MagReload = 0
	if(gundef["magreload"]) then
		Rack.MagReload = math.max(Rack.MagReload, gundef["magreload"])
	end
	
    
	local gunclass = Classes[Rack.Class] or error("Couldn't find the " .. tostring(Rack.Class) .. " gun-class!")
    
	Rack:SetNWString( "Class" , Rack.Class )
	Rack:SetNWString( "ID" , Rack.Id )
	Rack.Muzzleflash = gundef.muzzleflash or gunclass.muzzleflash or ""
	Rack.RoFmod = gunclass["rofmod"]
	Rack.Sound = gundef.sound or gunclass.sound or "vo/npc/barney/ba_turret.wav"
	Rack:SetNWString( "Sound", Rack.Sound )
	Rack.Inaccuracy = gunclass["spread"]
	
    
	if not UpdateRack or Rack.Model ~= Rack:GetModel() then
		Rack:SetModel( Rack.Model )	
	
		Rack:PhysicsInit( SOLID_VPHYSICS )      	
		Rack:SetMoveType( MOVETYPE_VPHYSICS )     	
		Rack:SetSolid( SOLID_VPHYSICS )
	end
	
    
	local phys = Rack:GetPhysicsObject()  	
	if (phys:IsValid()) then 
		phys:SetMass(Rack.Mass)
	end 	

	hook.Call("ACF_RackCreate", nil, Rack)
	
	return Rack
	
end

list.Set( "ACFCvars", "acf_rack" , {"id"} )
duplicator.RegisterEntityClass("acf_rack", MakeACF_Rack, "Pos", "Angle", "Id")




function ENT:GetInaccuracy()
    return self.Inaccuracy * ACF.GunInaccuracyScale
end




function ENT:FireMissile()
    
	if self.Ready and self:GetPhysicsObject():GetMass() >= self.Mass and not self:GetParent():IsValid() then
        
        local nextMsl = self:PeekMissile()
    
        local CanDo = true
        if nextMsl then CanDo = hook.Run("ACF_FireShell", self, nextMsl.BulletData ) end
        if CanDo == false then return end
        
        local ReloadTime = 0.5
        local missile, curShot = self:PopMissile()
        
        
        if missile then
        
            ReloadTime = self:GetReloadTime(missile)
        
            local attach, muzzle = self:GetMuzzle(curShot - 1, missile)
        
            local MuzzlePos = muzzle.Pos--self:LocalToWorld(muzzle.Pos)
            local MuzzleVec = muzzle.Ang:Forward()
            
            local coneAng = math.tan(math.rad(self:GetInaccuracy())) 
            local randUnitSquare = (self:GetUp() * (2 * math.random() - 1) + self:GetRight() * (2 * math.random() - 1))
            local spread = randUnitSquare:GetNormalized() * coneAng * (math.random() ^ (1 / math.Clamp(ACF.GunInaccuracyBias, 0.5, 4)))
            local ShootVec = (MuzzleVec + spread):GetNormalized()
            
            local filter = {}
            for k, v in pairs(self.Missiles) do
                filter[#filter+1] = v
            end
            filter[#filter+1] = self
            filter[#filter+1] = missile
            
            missile.Filter = filter
            
            missile:SetParent(nil)
            --missile:SetPos(MuzzlePos)
            --missile:SetAngles(ShootVec:Angle())
            local bdata = missile.BulletData
            
            bdata.Pos = MuzzlePos
            bdata.Flight = ShootVec * (bdata.MuzzleVel or missile.MinimumSpeed or 1)
            
            missile:Launch()
            
            self:MuzzleEffect( attach, missile.BulletData )
            
            self:TrimNullMissiles()
            Ammo = table.Count(self.Missiles)
            self:SetNetworkedBeamInt("Ammo",	Ammo)
            
        else
            self:EmitSound("weapons/pistol/pistol_empty.wav",500,100)
        end
        
        self.Ready = false
        Wire_TriggerOutput(self, "Ready", 0)
        self.NextFire = CurTime() + ReloadTime
        self.ReloadTime = ReloadTime
        
	else
		self:EmitSound("weapons/pistol/pistol_empty.wav",500,100)
	end

end




function ENT:MuzzleEffect( attach, bdata )
	
    self:EmitSound( "phx/epicmetal_hard.wav", 500, 100 )
    
	-- local Effect = EffectData()
		-- Effect:SetEntity( self )
		-- Effect:SetScale( self.BulletData["PropMass"] )
		-- Effect:SetAttachment( attach )
		-- Effect:SetSurfaceProp( ACF.RoundTypes[bdata.Type]["netid"]  )	--Encoding the ammo type into a table index
	-- util.Effect( "ACF_MissileLaunch", Effect, true, true )

end




function ENT:ReloadEffect()

	-- local Effect = EffectData()
		-- Effect:SetEntity( self )
		-- Effect:SetScale( 0 )
		-- Effect:SetMagnitude( self.ReloadTime or 1 )
		-- Effect:SetSurfaceProp( ACF.RoundTypes[self.BulletData["Type"]]["netid"]  )	--Encoding the ammo type into a table index
	-- util.Effect( "ACF_MuzzleFlash", Effect, true, true )
	
end





function ENT:PreEntityCopy()

    local info = {}
	local entids = {}
	for Key, Value in pairs(self.AmmoLink) do					--First clean the table of any invalid entities
		if not Value:IsValid() then
			table.remove(self.AmmoLink, Value)
		end
	end
	for Key, Value in pairs(self.AmmoLink) do					--Then save it
		table.insert(entids, Value:EntIndex())
	end
	info.entities = entids
	if info.entities then
		duplicator.StoreEntityModifier( self, "ACFAmmoLink", info )
	end

    duplicator.StoreEntityModifier( self, "ACFRackInfo", {Id = self.Id} )

    //Wire dupe info
	self.BaseClass.PreEntityCopy( self )
	
end




function ENT:PostEntityPaste( Player, Ent, CreatedEntities )
	
    self.Id = Ent.EntityMods.ACFRackInfo.Id

	MakeACF_Rack(self.Owner, self:GetPos(), self:GetAngles(), self.Id, self)

    if (Ent.EntityMods) and (Ent.EntityMods.ACFAmmoLink) and (Ent.EntityMods.ACFAmmoLink.entities) then
		local AmmoLink = Ent.EntityMods.ACFAmmoLink
		if AmmoLink.entities and table.Count(AmmoLink.entities) > 0 then
			for _,AmmoID in pairs(AmmoLink.entities) do
				local Ammo = CreatedEntities[ AmmoID ]
				if Ammo and Ammo:IsValid() and Ammo:GetClass() == "acf_ammo" then
					self:Link( Ammo )
				end
			end
		end
		Ent.EntityMods.ACFAmmoLink = nil
	end
    
    
    //Wire dupe info
	self.BaseClass.PostEntityPaste( self, Player, Ent, CreatedEntities )
    
end




function ENT:OnRemove()
	Wire_Remove(self.Entity)
end

function ENT:OnRestore()
    Wire_Restored(self.Entity)
end