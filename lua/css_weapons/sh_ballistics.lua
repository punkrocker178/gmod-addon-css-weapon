-- Model-2 cone, damage falloff, hitgroups, armor, and the CS:S penetration path
-- used when sv_penetration_type is absent (this install's server.dll).

CSSWeapons = CSSWeapons or {}

CSSWeapons.Ammo = {
	BULLET_PLAYER_50AE = { Power = 30, Distance = 1000, Armor = 0.5 },
	BULLET_PLAYER_762MM = { Power = 39, Distance = 5000, Armor = 0.5 },
	BULLET_PLAYER_556MM = { Power = 35, Distance = 4000, Armor = 0.5 },
	BULLET_PLAYER_556MM_BOX = { Power = 35, Distance = 4000, Armor = 0.5 },
	BULLET_PLAYER_338MAG = { Power = 45, Distance = 8000, Armor = 0.5 },
	BULLET_PLAYER_9MM = { Power = 21, Distance = 800, Armor = 0.5 },
	BULLET_PLAYER_45ACP = { Power = 15, Distance = 500, Armor = 0.5 },
	BULLET_PLAYER_357SIG = { Power = 25, Distance = 800, Armor = 0.5 },
	BULLET_PLAYER_57MM = { Power = 30, Distance = 2000, Armor = 0.5 },
	BULLET_PLAYER_BUCKSHOT = { Power = 0, Distance = 0, Armor = 0.5 },
}

-- Source surface modifiers keyed by the material character CS:S uses.
-- penetrationModifier, damageModifier.
CSSWeapons.Surface = {
	C = { Pen = 0.25, Dmg = 0.5 },
	M = { Pen = 0.5, Dmg = 0.4 },
	W = { Pen = 1, Dmg = 0.6 },
	Y = { Pen = 1, Dmg = 0.99 },
	G = { Pen = 1, Dmg = 0.99 },
	F = { Pen = 1, Dmg = 0.75 },
	D = { Pen = 0.6, Dmg = 0.6 },
	P = { Pen = 0.4, Dmg = 0.45 },
	L = { Pen = 0.5, Dmg = 0.5 },
	T = { Pen = 0.25, Dmg = 0.5 },
	V = { Pen = 0.5, Dmg = 0.45 },
	N = { Pen = 0.6, Dmg = 0.6 },
}

local MAT_CHAR = {
	[MAT_CONCRETE] = "C",
	[MAT_TILE] = "T",
	[MAT_METAL] = "M",
	[MAT_VENT] = "V",
	[MAT_WOOD] = "W",
	[MAT_GLASS] = "Y",
	[MAT_GRATE] = "G",
	[MAT_FLESH] = "F",
	[MAT_BLOODYFLESH] = "F",
	[MAT_ALIENFLESH] = "F",
	[MAT_DIRT] = "D",
	[MAT_SAND] = "N",
	[MAT_GRASS] = "D",
	[MAT_FOLIAGE] = "D",
	[MAT_COMPUTER] = "P",
	[MAT_PLASTIC] = "L",
}

function CSSWeapons.Stat(stats, key, alt)
	if alt then
		local value = stats[key .. "Alt"]
		if value ~= nil then return value end
	end
	return stats[key] or 0
end

function CSSWeapons.HitgroupScale(group)
	if group == HITGROUP_HEAD then return 4 end
	if group == HITGROUP_STOMACH then return 1.25 end
	if group == HITGROUP_LEFTLEG or group == HITGROUP_RIGHTLEG then return 0.75 end
	return 1
end

function CSSWeapons.HitgroupArmored(group)
	return group == HITGROUP_HEAD
		or group == HITGROUP_CHEST
		or group == HITGROUP_STOMACH
		or group == HITGROUP_LEFTARM
		or group == HITGROUP_RIGHTARM
end

local JUMP_VELOCITY = math.sqrt(2 * 800 * 57)

function CSSWeapons.UpdateAccuracy(wep, ply, stats, alt, dt)
	local ladder = ply:GetMoveType() == MOVETYPE_LADDER
	local grounded = ply:OnGround()
	local ducking = ply:Crouching()
	local penalty
	if ladder then
		penalty = CSSWeapons.Stat(stats, "InaccuracyStand", alt) + CSSWeapons.Stat(stats, "InaccuracyLadder", alt)
	elseif ducking then
		penalty = CSSWeapons.Stat(stats, "InaccuracyCrouch", alt)
	else
		penalty = CSSWeapons.Stat(stats, "InaccuracyStand", alt)
	end
	if wep.GetReloading and wep:GetReloading() then
		penalty = penalty + (stats.InaccuracyReload or 0)
	end

	local current = wep:GetAccuracyPenalty()
	if penalty > current then
		current = penalty
	else
		local recovery
		if not grounded then
			recovery = (stats.RecoveryTimeCrouch or 0.3) * 3
		elseif ducking and not ladder then
			recovery = stats.RecoveryTimeCrouch
		else
			recovery = stats.RecoveryTimeStand
		end
		if not recovery or recovery <= 0 then recovery = 0.3 end
		local frac = math.exp(dt * -(math.log(10) / recovery))
		current = Lerp(frac, penalty, current)
	end
	wep:SetAccuracyPenalty(current)
end

function CSSWeapons.GetInaccuracy(wep, ply, stats, alt)
	local maxSpeed = wep.CSSMaxSpeed or stats.MaxPlayerSpeed or 250
	if maxSpeed <= 0 then maxSpeed = 250 end
	local speed = ply:GetVelocity():Length2D()
	local move = CSSWeapons.Stat(stats, "InaccuracyMove", alt)
	local frac = math.Clamp((speed - maxSpeed * 0.34) / (maxSpeed * 0.95 - maxSpeed * 0.34), 0, 1)
	return wep:GetAccuracyPenalty() + frac * move
end

function CSSWeapons.AddJumpInaccuracy(wep, stats, alt, impulse)
	wep:SetAccuracyPenalty(wep:GetAccuracyPenalty() + CSSWeapons.Stat(stats, "InaccuracyJump", alt) * impulse / JUMP_VELOCITY)
end

function CSSWeapons.AddLandInaccuracy(wep, stats, alt, velocity)
	wep:SetAccuracyPenalty(wep:GetAccuracyPenalty() + CSSWeapons.Stat(stats, "InaccuracyLand", alt) * velocity / JUMP_VELOCITY)
end

-- fx_cs_shared.cpp: one inaccuracy disk plus one spread disk per pellet.
-- The seed is incremented once before RandomSeed, matching FX_FireBullets.
function CSSWeapons.SampleCone(seed, bullets, inaccuracy, spread)
	local function unit(slot, lo, hi)
		return util.SharedRandom("css_spread_" .. slot, lo, hi, seed)
	end
	local theta0 = unit(0, 0, math.pi * 2)
	local radius0 = unit(1, 0, inaccuracy)
	local x0 = radius0 * math.cos(theta0)
	local y0 = radius0 * math.sin(theta0)
	local samples = {}
	local slot = 2
	for i = 1, bullets do
		local theta = unit(slot, 0, math.pi * 2)
		local radius = unit(slot + 1, 0, spread)
		slot = slot + 2
		samples[i] = { x0 + radius * math.cos(theta), y0 + radius * math.sin(theta) }
	end
	return samples
end

function CSSWeapons.MaterialOf(tr)
	local char = MAT_CHAR[tr.MatType] or "C"
	local mods = CSSWeapons.Surface[char] or CSSWeapons.Surface.C
	return char, mods.Pen, mods.Dmg
end

local DECAL_FOR = {
	[MAT_CONCRETE] = "Impact.Concrete",
	[MAT_TILE] = "Impact.Concrete",
	[MAT_METAL] = "Impact.Metal",
	[MAT_VENT] = "Impact.Metal",
	[MAT_GRATE] = "Impact.Metal",
	[MAT_WOOD] = "Impact.Wood",
	[MAT_GLASS] = "Impact.Glass",
	[MAT_DIRT] = "Impact.Concrete",
	[MAT_SAND] = "Impact.Concrete",
	[MAT_GRASS] = "Impact.Concrete",
	[MAT_FOLIAGE] = "Impact.Concrete",
	[MAT_PLASTIC] = "Impact.Concrete",
	[MAT_COMPUTER] = "Impact.Metal",
	[MAT_FLESH] = "Blood",
	[MAT_BLOODYFLESH] = "Blood",
	[MAT_ALIENFLESH] = "Blood",
}

local function IsCharacter(ent)
	if not IsValid(ent) or ent:IsWorld() then return false end
	if ent:IsPlayer() or ent:IsNPC() or ent:IsNextBot() then return true end
	if ent.IsValidZombie and ent:IsValidZombie() then return true end
	return false
end

-- Distance along dir from pos to the far side of the entity's world box.
-- Point contents never see an NPC or nextbot, so a short step still starts inside them.
local function ExitDistance(ent, pos, dir)
	local mins, maxs = ent:WorldSpaceAABB()
	local function slab(origin, delta, lo, hi)
		if math.abs(delta) < 1e-6 then
			if origin < lo or origin > hi then return nil end
			return 0
		end
		local t1 = (lo - origin) / delta
		local t2 = (hi - origin) / delta
		return math.max(t1, t2)
	end
	local tx = slab(pos.x, dir.x, mins.x, maxs.x)
	local ty = slab(pos.y, dir.y, mins.y, maxs.y)
	local tz = slab(pos.z, dir.z, mins.z, maxs.z)
	if not tx or not ty or not tz then return 8 end
	return math.max(tx, ty, tz, 0) + 1
end

if SERVER then
	util.AddNetworkString("css_weapons_impact")
end

local function DrawImpact(pos, normal, mat, character, ent)
	local decal = character and "Blood" or DECAL_FOR[mat] or "Impact.Concrete"
	util.Decal(decal, pos + normal * 8, pos - normal * 8, LocalPlayer())
	if not character then return end
	local ed = EffectData()
	ed:SetOrigin(pos)
	ed:SetNormal(normal)
	ed:SetScale(8)
	ed:SetColor(BLOOD_COLOR_RED)
	if IsValid(ent) then
		ed:SetEntity(ent)
	end
	util.Effect("BloodImpact", ed)
end

function CSSWeapons.BulletImpact(tr)
	if not CLIENT or not IsFirstTimePredicted() then return end
	if not tr or tr.HitSky or not tr.Hit then return end
	DrawImpact(tr.HitPos, tr.HitNormal or vector_origin, tr.MatType, IsCharacter(tr.Entity), tr.Entity)
end

if CLIENT then
	net.Receive("css_weapons_impact", function()
		local count = net.ReadUInt(6)
		for _ = 1, count do
			local pos = net.ReadVector()
			local normal = net.ReadVector()
			local mat = net.ReadUInt(8)
			local character = net.ReadBool()
			local ent = net.ReadEntity()
			DrawImpact(pos, normal, mat, character, ent)
		end
	end)
end

function CSSWeapons.SendImpacts(ply, impacts)
	if not SERVER or not impacts or #impacts == 0 then return end
	local count = math.min(#impacts, 63)
	net.Start("css_weapons_impact")
	net.WriteUInt(count, 6)
	for i = 1, count do
		local hit = impacts[i]
		net.WriteVector(hit.pos)
		net.WriteVector(hit.normal)
		net.WriteUInt(bit.band(hit.mat or 0, 255), 8)
		net.WriteBool(hit.character and true or false)
		net.WriteEntity(IsValid(hit.ent) and hit.ent or Entity(0))
	end
	-- The shooter already drew this from their predicted trace.
	-- Singleplayer and bots never run that trace on a client.
	if game.SinglePlayer() then
		net.Send(ply)
	elseif IsValid(ply) and ply:IsPlayer() and not ply:IsBot() then
		net.SendOmit(ply)
	else
		net.Broadcast()
	end
end

local function NoteImpact(impacts, tr)
	if not SERVER or not impacts or not tr or tr.HitSky or not tr.Hit then return end
	if #impacts >= 63 then return end
	local ent = tr.Entity
	impacts[#impacts + 1] = {
		pos = tr.HitPos,
		normal = tr.HitNormal or vector_origin,
		mat = tr.MatType or 0,
		character = IsCharacter(ent),
		ent = IsValid(ent) and ent or nil,
	}
end

local function TraceToExit(enterPos, dir, filter)
	local step = 4
	local traveled = 0
	while traveled < 128 do
		traveled = traveled + step
		local pos = enterPos + dir * traveled
		if bit.band(util.PointContents(pos), MASK_SHOT) == 0 then
			local back = util.TraceLine({
				start = pos,
				endpos = pos - dir * step,
				mask = MASK_SHOT,
				filter = filter,
			})
			if not back.StartSolid and back.Fraction < 1 then
				return back
			end
			if not back.StartSolid and back.Fraction == 1 then
				back.HitPos = pos
				back.MatType = MAT_CONCRETE
				return back
			end
		end
	end
end

function CSSWeapons.DamageScale(wep)
	if not CSSServerConvars or not CSSServerConvars.weapons_damage_multiplier then return 1 end
	local scale = CSSServerConvars.weapons_damage_multiplier:GetFloat()
	local byType = {
		CSSServerConvars.weapons_rifle_damage_multiplier,
		CSSServerConvars.weapons_pistol_damage_multiplier,
		CSSServerConvars.weapons_smg_damage_multiplier,
		CSSServerConvars.weapons_shotgun_damage_multiplier,
		CSSServerConvars.weapons_sniper_damage_multiplier,
	}
	local typeConvar = wep and wep.Type and byType[wep.Type]
	if typeConvar then
		scale = scale * typeConvar:GetFloat()
	end
	return scale
end

local function ApplyDamage(ply, wep, tr, damage, dir, ammo)
	if not IsValid(tr.Entity) or tr.HitSky then return damage end
	local scaled = damage * CSSWeapons.HitgroupScale(tr.HitGroup)
	local armorLeft = nil
	if tr.Entity:IsPlayer() and CSSWeapons.HitgroupArmored(tr.HitGroup) and tr.Entity:Armor() > 0 then
		local ratio = ammo.Armor or 0.5
		local bonus = 0.5
		local healthDamage = scaled * ratio
		local armorDamage = (scaled - healthDamage) * bonus
		local armor = tr.Entity:Armor()
		if armorDamage > armor then
			armorDamage = armor / bonus
			healthDamage = scaled - armorDamage
			armorLeft = 0
		else
			armorLeft = armor - armorDamage
		end
		scaled = healthDamage
	end
	scaled = scaled * CSSWeapons.DamageScale(wep)
	if SERVER and scaled > 0 then
		if armorLeft ~= nil then
			tr.Entity:SetArmor(math.max(0, armorLeft))
		end
		local info = DamageInfo()
		info:SetDamage(scaled)
		info:SetAttacker(IsValid(ply) and ply or wep)
		info:SetInflictor(wep)
		info:SetDamageType(DMG_BULLET)
		info:SetDamagePosition(tr.HitPos)
		info:SetDamageForce(dir * scaled * 25)
		tr.Entity:TakeDamageInfo(info)
	end
	return scaled
end

function CSSWeapons.FireOneBullet(ply, wep, src, ang, spreadX, spreadY, stats, opts)
	local forward = ang:Forward()
	local right = ang:Right()
	local up = ang:Up()
	local dir = forward + right * spreadX + up * spreadY
	dir:Normalize()

	local ammo = CSSWeapons.Ammo[stats.primary_ammo] or CSSWeapons.Ammo.BULLET_PLAYER_9MM
	local damage = opts.damage or stats.Damage or 0
	local rangeMod = opts.rangeMod or stats.RangeModifier or 1
	local range = stats.Range or 8192
	local penCount = stats.Penetration or 0
	local power = ammo.Power
	local maxPenDistance = ammo.Distance
	local penScale = 1
	if CSSServerConvars and CSSServerConvars.weapons_penetration then
		if not CSSServerConvars.weapons_penetration:GetBool() then
			penCount = 0
		end
		penScale = CSSServerConvars.weapons_penetration_mult:GetFloat()
	end
	power = power * penScale
	maxPenDistance = maxPenDistance * penScale
	local traveled = 0
	local filter = { ply }
	local hits = {}
	local hurt = {}
	local impacts = {}

	while damage >= 1 and traveled < range do
		local remain = range - traveled
		local tr = util.TraceLine({
			start = src,
			endpos = src + dir * remain,
			mask = MASK_SHOT,
			filter = filter,
		})
		local segment = tr.Fraction * remain
		if segment < 0.001 and tr.Hit then
			segment = 0.001
		end
		traveled = traveled + segment
		damage = damage * rangeMod ^ (segment / 500)

		if tr.Fraction == 1 or tr.HitSky then
			hits[#hits + 1] = tr.HitPos
			break
		end

		hits[#hits + 1] = tr.HitPos
		local ent = tr.Entity
		local character = IsCharacter(ent)
		if IsValid(ent) and not ent:IsWorld() then
			if not hurt[ent] then
				hurt[ent] = true
				CSSWeapons.BulletImpact(tr)
				NoteImpact(impacts, tr)
				ApplyDamage(ply, wep, tr, damage, dir, ammo)
			end
			filter[#filter + 1] = ent
		else
			CSSWeapons.BulletImpact(tr)
			NoteImpact(impacts, tr)
		end

		if traveled > maxPenDistance and penCount > 0 then
			penCount = 0
		end
		if penCount <= 0 or power <= 0 then
			break
		end

		-- A character has no brush contents, so the wall exit trace "exits"
		-- a few units later and the next trace hits that same character again.
		if character then
			local skip = ExitDistance(ent, tr.HitPos, dir)
			local penMod = 1
			local dmgMod = 0.75
			if skip > power * penMod then break end
			damage = damage * dmgMod * rangeMod ^ (skip / 500)
			power = power - skip / penMod
			traveled = traveled + skip
			src = tr.HitPos + dir * skip
			penCount = penCount - 1
		else
			local char, penMod, dmgMod = CSSWeapons.MaterialOf(tr)
			local grate = bit.band(tr.Contents or 0, CONTENTS_GRATE) ~= 0
			local nodraw = bit.band(tr.SurfaceFlags or 0, SURF_NODRAW) ~= 0
			if penMod < 0.1 then break end

			local exitTr = TraceToExit(tr.HitPos, dir, filter)
			if not exitTr then break end
			local exitChar, exitPen, exitDmg = CSSWeapons.MaterialOf(exitTr)
			if grate or nodraw then
				penMod = 1
				dmgMod = 0.99
			else
				if exitPen < penMod then penMod = exitPen end
				if exitDmg < dmgMod then dmgMod = exitDmg end
			end
			if char == exitChar and (exitChar == "W" or exitChar == "M") then
				penMod = penMod * 2
			end

			local thickness = exitTr.HitPos:Distance(tr.HitPos)
			if thickness > power * penMod then break end
			damage = damage * dmgMod
			power = power - thickness / penMod
			traveled = traveled + thickness
			CSSWeapons.BulletImpact(exitTr)
			NoteImpact(impacts, exitTr)
			src = exitTr.HitPos
			penCount = penCount - 1
		end
		if damage < 1 then break end
	end

	return hits, impacts
end

function CSSWeapons.PointBlankDamage(stats, hitgroup, armored, armorAmount)
	local damage = (stats.Damage or 0) * CSSWeapons.HitgroupScale(hitgroup)
	if not armored or not armorAmount or armorAmount <= 0 then return damage end
	if not CSSWeapons.HitgroupArmored(hitgroup) then return damage end
	local ammo = CSSWeapons.Ammo[stats.primary_ammo] or { Armor = 0.5 }
	local ratio = ammo.Armor or 0.5
	local healthDamage = damage * ratio
	local armorDamage = (damage - healthDamage) * 0.5
	if armorDamage > armorAmount then
		healthDamage = damage - armorAmount / 0.5
	end
	return healthDamage
end
