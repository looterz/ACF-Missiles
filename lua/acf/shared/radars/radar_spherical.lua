
-- Anti-Missile
ACF_DefineRadarClass("OMNI-AM", {
	name = "Spherical Anti-missile Radar",
	desc = "A missile radar with full 360-degree detection but a limited range.  Only detects launched missiles.\nThese may be parented to what they are welded to."
})

ACF_DefineRadar("SmallOMNI-AM", {
	name 		= "Small Spherical Radar",
	ent			= "acf_missileradar",
	desc 		= "A lightweight omni-directional radar with a smaller range.",
	model		= "models/radar/radar_sp_sml.mdl",
	class 		= "OMNI-AM",
	weight 		= 300,
	range 		= 7874 -- range in inches.
})

ACF_DefineRadar("MediumOMNI-AM", {
	name 		= "Medium Spherical Radar",
	ent			= "acf_missileradar",
	desc 		= "A omni-directional radar with a regular range.",
	model		= "models/radar/radar_sp_mid.mdl", -- medium one is for now called big one - will be changed
	class 		= "OMNI-AM",
	weight 		= 600,
	range 		= 15748 -- range in inches.
})

ACF_DefineRadar("LargeOMNI-AM", {
	name 		= "Large Spherical Radar",
	ent			= "acf_missileradar",
	desc 		= "A heavy omni-directional radar with a large range.",
	model		= "models/radar/radar_sp_big.mdl",
	class 		= "OMNI-AM",
	weight 		= 1200,
	range 		= 31496 -- range in inches.
})

-- Anti-Aircraft
ACF_DefineRadarClass("OMNI-AA", {
	name = "Spherical Anti-aircraft Radar",
	desc = "An aircraft radar with full 360-degree detection but a limited range.  Only detects airborne vehicles.\nThese may be parented to what they are welded to."
})

ACF_DefineRadar("SmallOMNI-AA", {
	name 		= "Small Spherical Radar",
	ent			= "acf_aircraftradar",
	desc 		= "A lightweight omni-directional radar with a smaller range.",
	model		= "models/radar/radar_sp_sml.mdl",
	class 		= "OMNI-AM",
	weight 		= 300,
	range 		= 7874 -- range in inches.
})

ACF_DefineRadar("MediumOMNI-AA", {
	name 		= "Medium Spherical Radar",
	ent			= "acf_aircraftradar",
	desc 		= "A omni-directional radar with a regular range.",
	model		= "models/radar/radar_sp_mid.mdl", -- medium one is for now called big one - will be changed
	class 		= "OMNI-AM",
	weight 		= 600,
	range 		= 15748 -- range in inches.
})

ACF_DefineRadar("LargeOMNI-AA", {
	name 		= "Large Spherical Radar",
	ent			= "acf_aircraftradar",
	desc 		= "A heavy omni-directional radar with a large range.",
	model		= "models/radar/radar_sp_big.mdl",
	class 		= "OMNI-AM",
	weight 		= 1200,
	range 		= 31496 -- range in inches.
})
