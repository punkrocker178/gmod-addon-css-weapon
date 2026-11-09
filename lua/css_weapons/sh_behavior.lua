-- Secondary behavior taken from the CS:S weapon sources that match these scripts.
-- Kick rows are up_base, lateral_base, up_modifier, lateral_modifier, up_max, lateral_max, direction_change.

CSSWeapons = CSSWeapons or {}

local function kick(move, air, duck, stand)
	return { Move = move, Air = air, Duck = duck, Stand = stand }
end

CSSWeapons.Behavior = {
	ak47 = {
		Name = "AK-47", Hold = "ar2",
		Kick = kick(
			{ 1.5, 0.45, 0.225, 0.05, 6.5, 2.5, 7 },
			{ 2, 1, 0.5, 0.35, 9, 6, 5 },
			{ 0.9, 0.35, 0.15, 0.025, 5.5, 1.5, 9 },
			{ 1, 0.375, 0.175, 0.0375, 5.75, 1.75, 8 }
		),
	},
	m4a1 = {
		Name = "Maverick M4A1", Hold = "ar2",
		Silencer = { Time = 2, World = "models/weapons/w_rif_m4a1_silencer.mdl", RangeModifier = 0.95 },
		Kick = kick(
			{ 1, 0.45, 0.28, 0.045, 3.75, 3, 7 },
			{ 1.2, 0.5, 0.23, 0.15, 5.5, 3.5, 6 },
			{ 0.6, 0.3, 0.2, 0.0125, 3.25, 2, 7 },
			{ 0.65, 0.35, 0.25, 0.015, 3.5, 2.25, 7 }
		),
	},
	famas = {
		Name = "FAMAS", Hold = "ar2", ViewModelRightHanded = true,
		Burst = { ShotsAfter = 2, ShotDelay = 0.075, Cycle = 0.55 },
		Kick = kick(
			{ 1, 0.45, 0.275, 0.05, 4, 2.5, 7 },
			{ 1.25, 0.45, 0.22, 0.18, 5.5, 4, 5 },
			{ 0.575, 0.325, 0.2, 0.011, 3.25, 2, 8 },
			{ 0.625, 0.375, 0.25, 0.0125, 3.5, 2.25, 8 }
		),
	},
	sg552 = {
		Name = "SG 552", Hold = "ar2",
		Zoom = { 55 }, ZoomTime = 0.2, ZoomSpeed = 200, ZoomCycle = 0.135, ZoomKeepMode = true,
		Kick = kick(
			{ 1, 0.45, 0.28, 0.04, 4.25, 2.5, 7 },
			{ 1.25, 0.45, 0.22, 0.18, 6, 4, 5 },
			{ 0.6, 0.35, 0.2, 0.0125, 3.7, 2, 10 },
			{ 0.625, 0.375, 0.25, 0.0125, 4, 2.25, 9 }
		),
	},
	aug = {
		Name = "AUG", Hold = "ar2",
		Zoom = { 55 }, ZoomTime = 0.2, ZoomCycle = 0.135,
		Kick = kick(
			{ 1, 0.45, 0.275, 0.05, 4, 2.5, 7 },
			{ 1.25, 0.45, 0.22, 0.18, 5.5, 4, 5 },
			{ 0.575, 0.325, 0.2, 0.011, 3.25, 2, 8 },
			{ 0.625, 0.375, 0.25, 0.0125, 3.5, 2.25, 8 }
		),
	},
	galil = {
		Name = "Galil", Hold = "ar2", ViewModelRightHanded = true,
		Kick = kick(
			{ 1, 0.45, 0.28, 0.045, 3.75, 3, 7 },
			{ 1.2, 0.5, 0.23, 0.15, 5.5, 3.5, 6 },
			{ 0.6, 0.3, 0.2, 0.0125, 3.25, 2, 7 },
			{ 0.65, 0.35, 0.25, 0.015, 3.5, 2.25, 7 }
		),
	},
	awp = {
		Name = "AWP", Hold = "ar2", Punch = 2,
		Zoom = { 40, 10 }, ZoomTime = 0.1, ZoomSpeed = 150, ResumeZoom = true, ZoomInaccuracy = true,
	},
	scout = {
		Name = "Scout", Hold = "ar2", Punch = 2,
		Zoom = { 40, 15 }, ZoomTime = 0.1, ZoomSpeed = 220, ResumeZoom = true, ZoomInaccuracy = true,
	},
	sg550 = {
		Name = "SG 550", Hold = "ar2",
		PunchFloat = { 0.75, 1.25, -0.75, 0.75 },
		Zoom = { 40, 15 }, ZoomTime = 0.1, ZoomSpeed = 150, ZoomInaccuracy = true,
	},
	g3sg1 = {
		Name = "G3SG1", Hold = "ar2",
		PunchFloat = { 0.75, 1.75, -0.75, 0.75 },
		Zoom = { 40, 15 }, ZoomTime = 0.1, ZoomSpeed = 150, ZoomInaccuracy = true,
	},
	glock = {
		Name = "Glock-18", Hold = "pistol", Punch = 0,
		Burst = { ShotsAfter = 2, ShotDelay = 0.06, Cycle = 0.5, FollowDamage = 18, FollowRangeMod = 0.9, FirstUsesPrimaryDamage = true },
	},
	usp = {
		Name = "USP", Hold = "pistol", Punch = 2,
		Silencer = { Time = 3, World = "models/weapons/w_pist_usp_silencer.mdl", Damage = 30 },
	},
	deagle = { Name = "Desert Eagle", Hold = "revolver", Punch = 2 },
	elite = { Name = "Dual Berettas", Hold = "pistol", Punch = 2, Alternate = true },
	fiveseven = { Name = "Five-SeveN", Hold = "pistol", Punch = 2 },
	p228 = { Name = "P228", Hold = "pistol", Punch = 2 },
	mac10 = {
		Name = "MAC-10", Hold = "smg", KickAirFirst = true,
		Kick = kick(
			{ 0.9, 0.45, 0.25, 0.035, 3.5, 2.75, 7 },
			{ 1.3, 0.55, 0.4, 0.05, 4.75, 3.75, 5 },
			{ 0.75, 0.4, 0.175, 0.03, 2.75, 2.5, 10 },
			{ 0.775, 0.425, 0.2, 0.03, 3, 2.75, 9 }
		),
	},
	tmp = {
		Name = "TMP", Hold = "smg", NoMuzzle = true, KickAirFirst = true,
		Kick = kick(
			{ 0.8, 0.4, 0.2, 0.03, 3, 2.5, 7 },
			{ 1.1, 0.5, 0.35, 0.045, 4.5, 3.5, 6 },
			{ 0.7, 0.35, 0.125, 0.025, 2.5, 2, 10 },
			{ 0.725, 0.375, 0.15, 0.025, 2.75, 2.25, 9 }
		),
	},
	mp5navy = {
		Name = "MP5", Hold = "smg", KickAirFirst = true,
		Kick = kick(
			{ 0.5, 0.275, 0.2, 0.03, 3, 2, 10 },
			{ 0.9, 0.475, 0.35, 0.0425, 5, 3, 6 },
			{ 0.225, 0.15, 0.1, 0.015, 2, 1, 10 },
			{ 0.25, 0.175, 0.125, 0.02, 2.25, 1.25, 10 }
		),
	},
	ump45 = {
		Name = "UMP-45", Hold = "smg", KickAirFirst = true,
		Kick = kick(
			{ 0.55, 0.3, 0.225, 0.03, 3.5, 2.5, 10 },
			{ 0.125, 0.65, 0.55, 0.0475, 5.5, 4, 10 },
			{ 0.25, 0.175, 0.125, 0.02, 2.25, 1.25, 10 },
			{ 0.275, 0.2, 0.15, 0.0225, 2.5, 1.5, 10 }
		),
	},
	p90 = {
		Name = "P90", Hold = "smg", KickAirFirst = true,
		Kick = kick(
			{ 0.45, 0.3, 0.2, 0.0275, 4, 2.25, 7 },
			{ 0.9, 0.45, 0.35, 0.04, 5.25, 3.5, 4 },
			{ 0.275, 0.2, 0.125, 0.02, 3, 1, 9 },
			{ 0.3, 0.225, 0.125, 0.02, 3.25, 1.25, 8 }
		),
	},
	m249 = {
		Name = "M249", Hold = "ar2", KickAirFirst = true, ViewModelRightHanded = true,
		Kick = kick(
			{ 1.1, 0.5, 0.3, 0.06, 4, 3, 8 },
			{ 1.8, 0.65, 0.45, 0.125, 5, 3.5, 8 },
			{ 0.75, 0.325, 0.25, 0.025, 3.5, 2.5, 9 },
			{ 0.8, 0.35, 0.3, 0.03, 3.75, 3, 9 }
		),
	},
	m3 = {
		Name = "M3", Hold = "shotgun", ShellReload = true,
		PunchRange = { 4, 6 }, PunchRangeAir = { 8, 11 },
	},
	xm1014 = {
		Name = "XM1014", Hold = "shotgun", ShellReload = true,
		PunchRange = { 3, 5 }, PunchRangeAir = { 7, 10 },
	},
}
