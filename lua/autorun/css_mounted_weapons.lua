AddCSLuaFile()

include("css_weapons/sh_stats.lua")
include("css_weapons/sh_behavior.lua")
include("css_weapons/sh_ballistics.lua")
include("css_weapons/sh_recoil.lua")

if SERVER then
	AddCSLuaFile("css_weapons/sh_stats.lua")
	AddCSLuaFile("css_weapons/sh_behavior.lua")
	AddCSLuaFile("css_weapons/sh_ballistics.lua")
	AddCSLuaFile("css_weapons/sh_recoil.lua")
end

CSSWeapons.Mounted = file.Exists("models/weapons/v_rif_ak47.mdl", "GAME")
if not CSSWeapons.Mounted then
	ErrorNoHalt("[css_mounted_weapons] Counter-Strike: Source is not mounted. Guns were not registered.\n")
end

hook.Add("CalcView", "CSSMountedWeaponsPunch", function(ply, origin, angles, fov)
	local wep = ply:GetActiveWeapon()
	if not IsValid(wep) or not wep.IsCSSWeapon then return end
	local view = Angle(angles.p + wep:GetPunchP(), angles.y + wep:GetPunchY(), angles.r)
	return { origin = origin, angles = view, fov = fov }
end)

local Pistol = {
	glock = true, usp = true, deagle = true, elite = true, fiveseven = true, p228 = true,
}
local Shotgun = { m3 = true, xm1014 = true }
local Sniper = { awp = true, scout = true, sg550 = true, g3sg1 = true }
local SMG = { mac10 = true, tmp = true, mp5navy = true, ump45 = true, p90 = true }

-- Same HL2 pools as Authentic CS:S SWEPs. Deagle shares rifle ammo.
local HL2Ammo = {
	ak47 = "ar2", aug = "ar2", awp = "ar2", galil = "ar2", sg552 = "ar2", famas = "ar2",
	m4a1 = "ar2", m249 = "ar2", sg550 = "ar2", g3sg1 = "ar2", scout = "ar2", deagle = "ar2",
	mac10 = "SMG1", tmp = "SMG1", mp5navy = "SMG1", ump45 = "SMG1", p90 = "SMG1",
	glock = "Pistol", usp = "Pistol", elite = "Pistol", fiveseven = "Pistol", p228 = "Pistol",
	m3 = "buckshot", xm1014 = "buckshot",
}

local IconLetter = {
	ak47 = "b", aug = "e", awp = "r", deagle = "f", elite = "s", famas = "t",
	fiveseven = "u", g3sg1 = "i", galil = "v", glock = "c", m249 = "z", m3 = "k",
	m4a1 = "w", mac10 = "l", mp5navy = "x", p228 = "y", p90 = "m", scout = "n",
	sg550 = "o", sg552 = "A", tmp = "d", ump45 = "q", usp = "a", xm1014 = "B",
}

hook.Add("Initialize", "CSSMountedWeaponsRegister", function()
	if not CSSWeapons.Mounted then return end
	if not weapons.GetStored("css_weapon_base") then
		ErrorNoHalt("[css_mounted_weapons] css_weapon_base is not installed. Guns were not registered.\n")
		return
	end
	local base = weapons.GetStored("weapon_css_base")
	if not base then
		ErrorNoHalt("[css_mounted_weapons] weapon_css_base did not load.\n")
		return
	end
	for id, stats in pairs(CSSWeapons.Stats) do
		local behavior = CSSWeapons.Behavior[id] or {}
		local gunType = CSS_Rifle
		if Pistol[id] then
			gunType = CSS_Pistol
		elseif Shotgun[id] then
			gunType = CSS_Shotgun
		elseif Sniper[id] then
			gunType = CSS_Sniper
		elseif SMG[id] then
			gunType = CSS_Smg
		end

		local automatic = stats.FullAuto == 1
		if gunType == CSS_Pistol and CSSServerConvars.weapons_pistols_automatic:GetBool() then
			automatic = true
		end

		local swep = table.Copy(base)
		swep.CSSID = id
		swep.PrintName = behavior.Name or id
		swep.ClassName = stats.Class
		swep.Spawnable = true
		swep.Category = "Counter-Strike: Source"
		swep.ViewModel = CSS_Viewmodel(stats.viewmodel)
		swep.WorldModel = Model(stats.playermodel)
		swep.UseHands = CSS_UsingArms()
		swep.ViewModelRightHanded = behavior.ViewModelRightHanded or false
		swep.HoldType = behavior.Hold or "ar2"
		swep.IconOverride = stats.Icon
		swep.IconLetter = IconLetter[id] or "b"
		swep.Type = gunType
		swep.Slot = CSS_SelectSlot(gunType)
		swep.SlotPos = stats.bucket_position or 0
		swep.MaxPlayerSpeed = stats.MaxPlayerSpeed or 250
		swep.CSMuzzleScale = stats.MuzzleFlashScale or 1
		swep.Primary = {
			ClipSize = stats.clip_size or 30,
			DefaultClip = stats.clip_size or 30,
			Automatic = automatic,
			Ammo = CSS_GetAmmo(HL2Ammo[id] or "ar2", stats.primary_ammo),
			Damage = stats.Damage,
			Delay = stats.CycleTime or 0.1,
			Sound = Sound(stats.Sound.single_shot),
			-- Hitgroup scale is already applied. This stops the gamemode's extra 1.5x headshot.
			DamageHeadshot = 1,
		}
		swep.Secondary = { ClipSize = -1, DefaultClip = -1, Automatic = false, Ammo = "none" }

		if behavior.Silencer then
			swep.Silenced = false
			swep.SilencingTime = behavior.Silencer.Time
			swep.WorldModelSilenced = Model(behavior.Silencer.World)
			swep.WorldModelUnsilenced = Model(stats.playermodel)
			swep.Primary.SoundSilenced = Sound(stats.Sound.special1)
		end
		if behavior.Burst then
			swep.BurstFire = true
			swep.BurstDelay = behavior.Burst.Cycle
			swep.BurstShotDelay = behavior.Burst.ShotDelay
			swep.BurstAmount = (behavior.Burst.ShotsAfter or 0) + 1
		end
		if behavior.Zoom then
			swep.ScopeLevels = behavior.Zoom
			swep.MaxScopingLevel = #behavior.Zoom
			swep.ScopingTime = behavior.ZoomTime or 0.1
			swep.ScopeMoveSpeed = behavior.ZoomSpeed
			swep.StayScopedAfterShot = not behavior.ResumeZoom
			swep.ScopeDrawOverlay = Sniper[id] and true or false
			if Sniper[id] then
				swep.HideCrosshair = true
			end
		end
		if Shotgun[id] then
			swep.Shotgun = true
		end

		weapons.Register(swep, stats.Class)
	end
end)
