local TOOL = {}

TOOL.printname = "Gravity Gun"
TOOL.order = 3

TOOL.base = "shotgun"
TOOL.suppress_default = true

local DEBUG = false

function TOOL:Initialize()
	self.grabbed = nil
	self.volume = 0
end

function TOOL:LeftClick()
	self.grabbed = {}
end

function TOOL:RightClick()
	if not self.grabbed then return end
	local camtr = MakeTransformation(GetCameraTransform())
	local vel = camtr.rot:Forward() * - 100
	for i = 1, #self.grabbed do
		if self.grabbed[i].body:IsValid() then
			self.grabbed[i].body:SetVelocity(vel)
		end
	end
	self.grabbed = nil
	self.volume = 0
end

function TOOL:LeftClickReleased()
	self.grabbed = nil
	self.volume = 0
end

local function getbodycenter(body)
	local center, weight = VEC_ZERO, 0
	local shapes = body:GetShapes()
	for i = 1, #shapes do
		local min, max = shapes[i]:GetWorldBounds()
		local sweight = (max - min):Volume()
		weight = weight + sweight
		center = center + (min + max) / 2 * sweight
	end
	return center / weight
end

function TOOL:ApproxBallRadius()
	return (self.volume ^ 0.333) / 2
end

function TOOL:FindBody(camtr, target, radius)
	local rejected = {}
	for i = 1, 20 do
		QueryRequire("dynamic")
		for i = 1, #rejected do QueryRejectBody(rejected[i].handle) end
		for i = 1, #self.grabbed do QueryRejectBody(self.grabbed[i].body.handle) end
		local res = camtr:Raycast(4 + radius * 2, -1, radius / 2 + 0.5)
		if not res.hit then break end

		local body = Body(GetShapeBody(res.shape))
		local min, max = body:GetWorldBounds()
		if math.max(max[1] - min[1], max[2] - min[2], max[3] - min[3]) < radius + 2 then
			local diff = target - (min + max) / 2
			local len = diff:Length()
			QueryRequire("static")
			local h = QueryRaycast(target, diff/len, len)
			if not h then return body end
		end
		rejected[#rejected + 1] = body
	end
end

function TOOL:Tick()
	if not InputDown("lmb") then self:LeftClickReleased() end
	if self.grabbed then
		local camtr = MakeTransformation(GetCameraTransform())
		local radius = math.max(self:ApproxBallRadius(), 1)
		local target = camtr:ToGlobal(Vector(0, 0, -1 - radius * 2))
		for i = 1, 20 do
			local body = self:FindBody(camtr, target, radius)
			if not body then break end
			local min, max = body:GetWorldBounds()
			self.grabbed[#self.grabbed + 1] = {
				body = body,
				offset = body:GetTransform():ToLocal(getbodycenter(body)),
				volume = (max - min):Volume()
			}
			self.volume = self.volume + self.grabbed[#self.grabbed].volume
		end
		local r, g, b = math.random(), math.random(), math.random()
		local i = 1
		while i <= #self.grabbed do
			local object = self.grabbed[i]
			if not object.body:IsValid() then
				self.volume = self.volume - self.grabbed[i].volume
				table.remove(self.grabbed, i)
			else
				local starget = object.body:GetTransform():ToGlobal(object.offset)
				local diff = target - starget
				object.body:SetVelocity(diff*4)
				object.body:DrawOutline(r, g, b, 1)
				if diff:Length() > radius * 10 then
					self.volume = self.volume - self.grabbed[i].volume
					table.remove(self.grabbed, i)
				else
					i = i + 1
				end
			end
		end
	end
end

RegisterTool("gravgun", TOOL)