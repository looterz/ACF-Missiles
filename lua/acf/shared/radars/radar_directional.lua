
-- Anti-Missile
ACF_DefineRadarClass("DIR-AM", {
	name = "Directional Anti-missile Radar",
	desc = "A radar with unlimited range but a limited view cone.  Only detects launched missiles.\nThese can be parented to what they are welded to."
})

ACF_DefineRadar("SmallDIR-AM", {
	name 		= "Small Directional Radar",
	ent			= "acf_missileradar",
	desc 		= "A lightweight directional radar with a smaller view cone.",
	model		= "models/radar/radar_sml.mdl",
	class 		= "DIR-AM",
	weight 		= 200,
	viewcone 	= 25 -- half of the total cone.  'viewcone = 30' means 60 degs total viewcone.
})

ACF_DefineRadar("MediumDIR-AM", {
	name 		= "Medium Directional Radar",
	ent			= "acf_missileradar",
	desc 		= "A directional radar with a regular view cone.",
	model		= "models/radar/radar_mid.mdl", -- medium one is for now called big one - will be changed
	class 		= "DIR-AM",
	weight 		= 400,
	viewcone 	= 40 -- half of the total cone.  'viewcone = 30' means 60 degs total viewcone.
})

ACF_DefineRadar("LargeDIR-AM", {
	name 		= "Large Directional Radar",
	ent			= "acf_missileradar",
	desc 		= "A heavy directional radar with a large view cone.",
	model		= "models/radar/radar_big.mdl",
	class 		= "DIR-AM",
	weight 		= 600,
	viewcone 	= 50 -- half of the total cone.  'viewcone = 30' means 60 degs total viewcone.
})

-- Anti-Aircraft
ACF_DefineRadarClass("DIR-AA", {
	name = "Directional Anti-Aircraft Radar",
	desc = "A radar with unlimited range but a limited view cone. Only detects airborne vehicles.\nThe radar results improve the longer a lock is maintained and the results are tainted by flares.\nThese can be parented to what htey are welded to."
})

ACF_DefineRadar("SmallDIR-AA", {
	name 			= "Small Directional Radar",
	ent				= "acf_aircraftradar",
	desc 			= "A lightweight directional radar with a smaller view cone. The radar results improve the longer a lock is maintained.",
	model			= "models/radar/radar_sml.mdl",
	class 			= "DIR-AA",
	weight 			= 400,
	viewcone 		= 25, -- half of the total cone.  'viewcone = 30' means 60 degs total viewcone
	minresolution  	= -500,
	maxresolution	= 500,
	locktime		= 15
})

ACF_DefineRadar("MediumDIR-AA", {
	name 			= "Medium Directional Radar",
	ent				= "acf_aircraftradar",
	desc 			= "A directional radar with a regular view cone. The radar results improve the longer a lock is maintained.",
	model			= "models/radar/radar_mid.mdl", -- medium one is for now called big one - will be changed
	class 			= "DIR-AA",
	weight 			= 800,
	viewcone 		= 40, -- half of the total cone.  'viewcone = 30' means 60 degs total viewcone
	minresolution  	= -800,
	maxresolution	= 800,
	locktime		= 30
})

ACF_DefineRadar("LargeDIR-AA", {
	name 			= "Large Directional Radar",
	ent				= "acf_aircraftradar",
	desc 			= "A heavy directional radar with a large view cone. The radar results improve the longer a lock is maintained.",
	model			= "models/radar/radar_big.mdl",
	class 			= "DIR-AA",
	weight 			= 1200,
	viewcone 		= 50, -- half of the total cone.  'viewcone = 30' means 60 degs total viewcone.
	minresolution  	= -1000,
	maxresolution	= 1000,
	locktime		= 45
})
