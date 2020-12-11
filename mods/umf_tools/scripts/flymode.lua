
local enabledvar = "game.mods.umftools.flying"

local function aorb(a, b, d)
	return (a and d or 0) - (b and d or 0)
end

local function incrouch()
	return MakeVector(GetCameraTransform().pos):DistSquare(GetPlayerTransform().pos) < 2
end

local target
hook.add("base.tick", "umftools.fly", function(dt)
	if InputPressed("v") then SetBool(enabledvar, not GetBool(enabledvar)) target = nil end
	if not GetBool(enabledvar) then return end

	local v = MakeVector(GetPlayerVelocity())
	local current_pos = MakeVector(GetPlayerTransform().pos)
	if not target or v:Length() > 1 then target = current_pos end

	local f, b, l, r, s = InputDown("up"), InputDown("down"), InputDown("left"), InputDown("right"), InputDown("space")
	if f or b or l or r or s then
		local dist = incrouch() and 0.1 or 1
		local fup = s and dist or 0
		target = target + TransformToParentVec(GetCameraTransform(), Vec(aorb(r, l, dist), (f and fup or 0), aorb(b, not s and f, dist))) + Vec(0, (f and 0 or fup) + 0.0166666, 0)
	end
	SetPlayerVelocity((target - current_pos)*10)
end)
