-- CS:S buy-menu icons are 256x64 or 256x128. The spawn list draws every
-- material into a square, which stretches them. Fit these into that square.

local PREFIX = "vgui/gfx/vgui/"

local function FitPaintAt(self, x, y, dw, dh)
	dw, dh = dw or self:GetWide(), dh or self:GetTall()
	self:LoadMaterial()

	local mat = self.m_Material
	if not mat or mat:IsError() then return true end

	local tw, th = self.ActualWidth or 0, self.ActualHeight or 0
	if tw < 1 or th < 1 then
		tw, th = mat:Width(), mat:Height()
	end

	local col = self.m_Color or color_white
	surface.SetMaterial(mat)
	surface.SetDrawColor(col.r, col.g, col.b, col.a)

	if tw < 1 or th < 1 then
		surface.DrawTexturedRect(x, y, dw, dh)
		return true
	end

	local scale = math.min(dw / tw, dh / th)
	local w, h = tw * scale, th * scale
	surface.DrawTexturedRect(x + (dw - w) * 0.5, y + (dh - h) * 0.5, w, h)
	return true
end

local function PatchContentIcon()
	local icon = vgui.GetControlTable("ContentIcon")
	if not icon or icon.CSSIconFit then return icon ~= nil end

	icon.CSSIconFit = true
	local oldPaint = icon.Paint
	function icon:Paint(w, h)
		local name = self.m_MaterialName
		if IsValid(self.Image) and isstring(name) and string.StartWith(string.lower(name), PREFIX) then
			self.Image.PaintAt = FitPaintAt
		end
		return oldPaint(self, w, h)
	end

	return true
end

if not PatchContentIcon() then
	hook.Add("OnGamemodeLoaded", "CSSMountedWeaponIcons", PatchContentIcon)
end
