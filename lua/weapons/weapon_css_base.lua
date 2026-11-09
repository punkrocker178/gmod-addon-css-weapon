AddCSLuaFile()

include("css_weapons/sh_stats.lua")
include("css_weapons/sh_behavior.lua")
include("css_weapons/sh_ballistics.lua")
include("css_weapons/sh_recoil.lua")

SWEP.Base = "css_weapon_base"
SWEP.PrintName = "CSS Weapon"
SWEP.Category = "Counter-Strike: Source"
SWEP.Spawnable = false
SWEP.AdminOnly = false
SWEP.CSSWeapon = true
SWEP.IsCSSWeapon = true

-- The base spray table and viewpunch are not the CS:S kick.
SWEP.Recoil = false
SWEP.SprayPattern = { "none" }

-- css_weapon_base defaults these on, and a nil field is filled from that parent.
-- false stays put. Zoom guns replace them at registration.
SWEP.ScopeLevels = false
SWEP.ScopeDrawOverlay = false
SWEP.MaxScopingLevel = 0

local function blankAccuracy()
	return {
		Spread = 0,
		Crouch = 0,
		Stand = 0,
		Jump = 0,
		Land = 0,
		Ladder = 0,
		Move = 0,
		Maximum = 1,
	}
end

-- SetAccuracy assigns one of these. Empty tables keep that call from nil-ing Accuracy.
SWEP.Accuracy = blankAccuracy()
SWEP.AccuracyNormal = blankAccuracy()
SWEP.AccuracyBurst = blankAccuracy()
SWEP.AccuracySilenced = blankAccuracy()
SWEP.AccuracyUnSilenced = blankAccuracy()
SWEP.AccuracyScoped = blankAccuracy()
SWEP.AccuracyUnScoped = blankAccuracy()

function SWEP:SetupMoreDataTables()
	self:NetworkVar("Float", "AccuracyPenalty")
	self:NetworkVar("Float", "PunchP")
	self:NetworkVar("Float", "PunchY")
	self:NetworkVar("Float", "PunchVelP")
	self:NetworkVar("Float", "PunchVelY")
	self:NetworkVar("Float", "NextBurst")
	self:NetworkVar("Int", "ShotsFired")
	self:NetworkVar("Int", "Direction")
	self:NetworkVar("Int", "CSSBurstLeft")
	self:NetworkVar("Bool", "KeepAlt")
end

function SWEP:Stats()
	return CSSWeapons.Stats[self.CSSID] or CSSWeapons.Stats.ak47
end

function SWEP:Behavior()
	return CSSWeapons.Behavior[self.CSSID] or {}
end

function SWEP:SpreadIsAlt()
	if self:GetSilenced() or self:GetBurst() or self:GetKeepAlt() then return true end
	return self:GetScopingLevel() > 0
end

function SWEP:Seed()
	local ply = self:GetOwner()
	local cmd = IsValid(ply) and ply.GetCurrentCommand and ply:GetCurrentCommand()
	local seed = 0
	if cmd then seed = bit.band(cmd:CommandNumber(), 255) end
	return bit.band(seed + 1, 255)
end

function SWEP:PostDeploy()
	local ply = self:GetOwner()
	if IsValid(ply) then
		self.SavedMaxSpeed = ply:GetMaxSpeed()
	end
	self:SetKeepAlt(false)
	self:SetShotsFired(0)
	self:SetCSSBurstLeft(0)
	self:SetPunchP(0)
	self:SetPunchY(0)
	self:SetPunchVelP(0)
	self:SetPunchVelY(0)
end

function SWEP:PostHolster()
	local ply = self:GetOwner()
	if IsValid(ply) and self.SavedMaxSpeed and self.SavedMaxSpeed > 0 then
		ply:SetMaxSpeed(self.SavedMaxSpeed)
	end
end

-- Silence flips at the end of the base delay. Skip the base accuracy-table swap.
function SWEP:HandleEvent(event)
	if event ~= self.Event.Silence then return end
	local silenced = not self:GetSilenced()
	self:SetSilenced(silenced)
	local model = silenced and self.WorldModelSilenced or self.WorldModelUnsilenced
	if model then
		self:SetWorldModel(model)
	end
	return true
end

function SWEP:ToggleBurst()
	if not self:CanSecondaryAttack() then return end
	self:SetNextSecondaryFire(CurTime() + 0.25)
	local burst = not self:GetBurst()
	self:SetBurst(burst)
	local ply = self:GetOwner()
	if not IsValid(ply) then return end
	ply:PrintMessage(HUD_PRINTCENTER, burst and self.BurstOnMsg or self.BurstOffMsg)
end

function SWEP:PostResetScoping(returnAfterShot)
	if self:Behavior().ZoomKeepMode and not returnAfterShot then
		self:SetKeepAlt(true)
	end
end

function SWEP:PostReload()
	self:SetShotsFired(0)
end

function SWEP:Reload()
	if self:GetCSSBurstLeft() > 0 then return end
	if self.Shotgun then
		self:ShotgunReload()
		if self.ShotgunReloading then
			self:SetReloading(true)
			self:SetShotsFired(0)
		end
		return
	end
	self.BaseClass.Reload(self)
	-- Reload unscope is not the SG552 "stay in zoom accuracy" unscope.
	if self:Behavior().Zoom then
		self:SetKeepAlt(false)
	end
end

function SWEP:SecondaryAttack()
	if not self:CanSecondaryAttack() then return end
	self:SetReloading(false)
	if self.Silenced ~= nil then
		self:AttachSilencer()
		return
	end
	if self.BurstFire then
		self:ToggleBurst()
		return
	end
	if not self:Behavior().Zoom or not self.ScopeLevels then return end
	local entering = self:GetScopingLevel() == 0 and not self:GetScopingIn()
	if entering then
		self:SetKeepAlt(false)
		if self:Behavior().ZoomInaccuracy then
			local stats = self:Stats()
			self:SetAccuracyPenalty(self:GetAccuracyPenalty() + (stats.InaccuracyAltSwitch or 0))
		end
	end
	self:Scope()
end

-- shoot1 and shoot2 share one activity. An unseeded pick differs between client and server,
-- and the same sequence will not restart while a long slide or pump is still playing.
function SWEP:SendAnimation(weaponAnim, playerAnim)
	local owner = self:GetOwner()
	if not IsValid(owner) then
		self:SendWeaponAnim(weaponAnim)
		return
	end

	local vm = owner:GetViewModel()
	if IsValid(vm) then
		local seq
		if vm.SelectWeightedSequenceSeeded then
			seq = vm:SelectWeightedSequenceSeeded(weaponAnim, self:GetShotsFired())
		end
		if not seq or seq < 0 then
			seq = vm:SelectWeightedSequence(weaponAnim)
		end
		if seq and seq >= 0 then
			if vm:GetSequence() == seq then
				local park = -1
				if vm.SelectWeightedSequenceSeeded then
					park = vm:SelectWeightedSequenceSeeded(ACT_VM_IDLE, 0)
				end
				if not park or park < 0 or park == seq then
					park = seq == 0 and 1 or 0
				end
				if park ~= seq and park < vm:GetSequenceCount() then
					vm:SetSequence(park)
				end
			end
			vm:SendViewModelMatchingSequence(seq)
			vm:SetPlaybackRate(1)
		else
			self:SendWeaponAnim(weaponAnim)
		end
	else
		self:SendWeaponAnim(weaponAnim)
	end

	if not CLIENT or IsFirstTimePredicted() then
		owner:SetAnimation(playerAnim)
	end
end

function SWEP:Shoot(opt)
	opt = opt or {}
	local ply = self:GetOwner()
	if not IsValid(ply) then return end
	local stats = self:Stats()
	local behavior = self:Behavior()
	local alt = opt.alt
	if alt == nil then alt = self:SpreadIsAlt() end
	local seed = self:Seed()

	self:SetShotsFired(self:GetShotsFired() + 1)
	self:TakePrimaryAmmo(1)
	local spreadAlt = alt
	if behavior.Alternate and bit.band(self:Clip1(), 1) == 0 then
		spreadAlt = true
		opt.anim = opt.anim or ACT_VM_SECONDARYATTACK
	end

	local damage = stats.Damage or 0
	local rangeMod = stats.RangeModifier or 1
	if self:GetSilenced() and behavior.Silencer then
		if behavior.Silencer.Damage then damage = behavior.Silencer.Damage end
		if behavior.Silencer.RangeModifier then rangeMod = behavior.Silencer.RangeModifier end
	end
	if opt.damage then damage = opt.damage end
	if opt.rangeMod then rangeMod = opt.rangeMod end

	local inaccuracy = CSSWeapons.GetInaccuracy(self, ply, stats, alt)
	local spread = CSSWeapons.Stat(stats, "Spread", spreadAlt)
	local samples = CSSWeapons.SampleCone(seed, math.max(1, stats.Bullets or 1), inaccuracy, spread)
	local ang = ply:EyeAngles()
	ang.p = ang.p + self:GetPunchP() * 2
	ang.y = ang.y + self:GetPunchY() * 2
	local src = ply:GetShootPos()

	local impacts = {}
	if SERVER then ply:LagCompensation(true) end
	for i = 1, #samples do
		local _, pel = CSSWeapons.FireOneBullet(ply, self, src, ang, samples[i][1], samples[i][2], stats, {
			damage = damage,
			rangeMod = rangeMod,
		})
		if SERVER and pel then
			for j = 1, #pel do
				impacts[#impacts + 1] = pel[j]
			end
		end
	end
	if SERVER then
		ply:LagCompensation(false)
		CSSWeapons.SendImpacts(ply, impacts)
	end

	-- The viewmodel keeps this sequence until something else replaces it. Deagle slide
	-- and M3 pump are still that sequence on the next shot. Prediction replay has to
	-- send it again; gating it leaves the cycle stuck and the shot has no animation.
	self:SendAnimation(opt.anim or self:GetAnimation("Fire"), PLAYER_ATTACK1)
	if not CLIENT or IsFirstTimePredicted() then
		self:EmitSound(self:GetSound("PrimaryFire"))
		if not self:GetSilenced() and not behavior.NoMuzzle then
			ply:MuzzleFlash()
		end
	end

	self:SetAccuracyPenalty(self:GetAccuracyPenalty() + CSSWeapons.Stat(stats, "InaccuracyFire", alt))
	if opt.recoil ~= false then
		CSSWeapons.ApplyRecoil(self, ply, seed)
	end
end

-- Blocks the base spray-pattern bullet if a parent path calls this.
function SWEP:ShootBullet()
	self:Shoot()
end

function SWEP:PrimaryAttack()
	local ply = self:GetOwner()
	if not IsValid(ply) or not ply:Alive() then return end
	if CurTime() < self:GetNextPrimaryFire() then return end
	if ply:WaterLevel() >= 3 then
		if not CLIENT or IsFirstTimePredicted() then
			self:EmitSound("Default.ClipEmpty")
		end
		self:SetNextPrimaryFire(CurTime() + 0.15)
		return
	end
	if self:Clip1() <= 0 then
		if not CLIENT or IsFirstTimePredicted() then
			if self.Type == CSS_Pistol then
				self:EmitSound("Default.ClipEmpty_Pistol")
			else
				self:EmitSound("Default.ClipEmpty_Rifle")
			end
		end
		self:SetNextPrimaryFire(CurTime() + 0.1)
		return
	end

	local stats = self:Stats()
	local behavior = self:Behavior()
	local cycle = self.Primary.Delay or stats.CycleTime or 0.1
	if behavior.ZoomCycle and self:GetScopingLevel() > 0 then
		cycle = behavior.ZoomCycle
	end
	local opt = {}
	if self.BurstFire and self:GetBurst() then
		cycle = self.BurstDelay or cycle
		opt.alt = true
		opt.anim = ACT_VM_SECONDARYATTACK
	end

	local zoomed = self:GetScopingIn()
	self:Shoot(opt)
	self:SetNextPrimaryFire(CurTime() + cycle)
	self:SetReloading(false)

	if self.BurstFire and self:GetBurst() and behavior.Burst then
		self:SetCSSBurstLeft(behavior.Burst.ShotsAfter)
		self:SetNextBurst(CurTime() + behavior.Burst.ShotDelay)
	end
	if behavior.ResumeZoom and zoomed then
		self:ResetScoping(true)
	end
end

function SWEP:Think2()
	local ply = self:GetOwner()
	if not IsValid(ply) then return end

	if self.Shotgun then
		self:ShotgunReloadThink()
		if SERVER then
			local reloading = self.ShotgunReloading and true or false
			if self:GetReloading() ~= reloading then
				self:SetReloading(reloading)
			end
		end
	elseif self:GetReloading() and CurTime() >= self:GetNextPrimaryFire() then
		self:SetReloading(false)
	end

	local stats = self:Stats()
	local behavior = self:Behavior()
	local alt = self:SpreadIsAlt()

	local p, y, vp, vy = CSSWeapons.DecayPunch(self:GetPunchP(), self:GetPunchY(), self:GetPunchVelP(), self:GetPunchVelY(), FrameTime())
	self:SetPunchP(p)
	self:SetPunchY(y)
	self:SetPunchVelP(vp)
	self:SetPunchVelY(vy)

	if not self.NextAccuracy or CurTime() >= self.NextAccuracy then
		CSSWeapons.UpdateAccuracy(self, ply, stats, alt, engine.TickInterval())
		self.NextAccuracy = CurTime() + engine.TickInterval()
	end

	local grounded = ply:OnGround()
	local vz = ply:GetVelocity().z
	if self.WasGrounded == nil then self.WasGrounded = grounded end
	if self.WasGrounded and not grounded then
		CSSWeapons.AddJumpInaccuracy(self, stats, alt, math.max(vz, 0))
	elseif not self.WasGrounded and grounded then
		CSSWeapons.AddLandInaccuracy(self, stats, alt, math.abs(self.LastZ or 0))
	end
	self.WasGrounded = grounded
	self.LastZ = vz

	if not ply:KeyDown(IN_ATTACK) and self:GetCSSBurstLeft() <= 0 and CurTime() >= self:GetNextPrimaryFire() then
		self:SetShotsFired(0)
	end

	local guard = 0
	while self:GetCSSBurstLeft() > 0 and CurTime() >= self:GetNextBurst() and guard < 3 do
		guard = guard + 1
		if self:Clip1() <= 0 then
			self:SetCSSBurstLeft(0)
			break
		end
		local burst = behavior.Burst or {}
		self:Shoot({
			alt = true,
			damage = burst.FollowDamage,
			rangeMod = burst.FollowRangeMod,
			recoil = false,
		})
		self:SetCSSBurstLeft(self:GetCSSBurstLeft() - 1)
		if self:GetCSSBurstLeft() > 0 then
			self:SetNextBurst(self:GetNextBurst() + (burst.ShotDelay or 0.06))
		end
	end

	local speed = stats.MaxPlayerSpeed or 250
	if self:GetScopingLevel() > 0 and behavior.ZoomSpeed then
		speed = behavior.ZoomSpeed
	end
	self.CSSMaxSpeed = speed
	ply:SetMaxSpeed(speed)
end

-- The ring texture already has a clear center. Draw that only, not the lens
-- material the base puts underneath it.
local cssScopeMat
local cssScopeBlack = Color(0, 0, 0, 255)
local cssScopeWhite = Color(255, 255, 255, 255)

function SWEP:DrawHUDBackground()
	if not self:GetScopingIn() or not self.ScopeDrawOverlay then return end
	if not cssScopeMat or cssScopeMat:IsError() then
		cssScopeMat = Material("hud/scope_full")
	end
	if cssScopeMat:IsError() then return end

	local size = ScrH()
	local cx = ScrW() / 2 - size / 2
	local cy = ScrH() / 2 - size / 2

	surface.SetDrawColor(cssScopeBlack)
	surface.DrawRect(0, 0, cx, size)
	surface.DrawRect(cx + size, 0, ScrW(), size)

	surface.SetDrawColor(cssScopeWhite)
	surface.SetMaterial(cssScopeMat)
	surface.DrawTexturedRect(cx, cy, size, size)
end
