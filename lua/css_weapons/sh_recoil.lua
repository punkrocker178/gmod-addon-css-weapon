-- KickBack and the Source view-punch spring (PUNCH_DAMPING 9, PUNCH_SPRING_CONSTANT 65).
-- Bullets use eye angles + 2 * punch. The drawn view uses 1 * punch.

CSSWeapons = CSSWeapons or {}

function CSSWeapons.DecayPunch(p, y, vp, vy, dt)
	if p * p + y * y < 0.001 and vp * vp + vy * vy < 0.001 then
		return 0, 0, 0, 0
	end
	p = p + vp * dt
	y = y + vy * dt
	local damping = 1 - 9 * dt
	if damping < 0 then damping = 0 end
	vp = vp * damping
	vy = vy * damping
	local spring = math.Clamp(65 * dt, 0, 2)
	vp = vp - p * spring
	vy = vy - y * spring
	return math.Clamp(p, -89, 89), math.Clamp(y, -179, 179), vp, vy
end

function CSSWeapons.KickBack(wep, seed, shots, upBase, latBase, upMod, latMod, upMax, latMax, dirChange)
	local up, lat
	if shots <= 1 then
		up, lat = upBase, latBase
	else
		up = upBase + shots * upMod
		lat = latBase + shots * latMod
	end

	local p = wep:GetPunchP() - up
	if p < -upMax then p = -upMax end

	local dir = wep:GetDirection()
	local y = wep:GetPunchY()
	if dir == 1 then
		y = y + lat
		if y > latMax then y = latMax end
	else
		y = y - lat
		if y < -latMax then y = -latMax end
	end

	local roll = math.floor(util.SharedRandom("css_kickdir", 0, dirChange, seed))
	if roll == 0 then
		dir = 1 - dir
	end

	wep:SetPunchP(p)
	wep:SetPunchY(y)
	wep:SetDirection(dir)
end

function CSSWeapons.ApplyRecoil(wep, ply, seed)
	local behavior = CSSWeapons.Behavior[wep.CSSID] or {}
	local shots = wep:GetShotsFired()
	if behavior.PunchRange then
		local lo, hi = behavior.PunchRange[1], behavior.PunchRange[2]
		if not ply:OnGround() and behavior.PunchRangeAir then
			lo, hi = behavior.PunchRangeAir[1], behavior.PunchRangeAir[2]
		end
		local amount = math.floor(util.SharedRandom("css_punch", lo, hi + 1, seed))
		if amount > hi then amount = hi end
		wep:SetPunchP(wep:GetPunchP() - amount)
		return
	end
	if behavior.PunchFloat then
		local px = util.SharedRandom("css_punch_x", behavior.PunchFloat[1], behavior.PunchFloat[2], seed)
		local py = util.SharedRandom("css_punch_y", behavior.PunchFloat[3], behavior.PunchFloat[4], seed)
		local p = wep:GetPunchP()
		wep:SetPunchP(p - (px + p / 4))
		wep:SetPunchY(wep:GetPunchY() + py)
		return
	end
	if behavior.Kick then
		local kick
		local speed = ply:GetVelocity():Length2D()
		local airborne = not ply:OnGround()
		if behavior.KickAirFirst and airborne then
			kick = behavior.Kick.Air
		elseif speed > 5 then
			kick = behavior.Kick.Move
		elseif airborne then
			kick = behavior.Kick.Air
		elseif ply:Crouching() then
			kick = behavior.Kick.Duck
		else
			kick = behavior.Kick.Stand
		end
		CSSWeapons.KickBack(wep, seed, shots, unpack(kick))
	elseif behavior.Punch and behavior.Punch ~= 0 then
		wep:SetPunchP(wep:GetPunchP() - behavior.Punch)
	end
end
