local TOOL = {}

TOOL.printname = "Physics Gun"
TOOL.order = 3

TOOL.base = "gun"
TOOL.suppress_default = true

function TOOL:Initialize()
    self.released = 0
end

function TOOL:GetTarget()
    local ray = MakeTransformation(GetCameraTransform()):Raycast(100, -1)
    local body = Body(GetShapeBody(ray.shape))
    if not body then return end

    local min, max = body:GetWorldBounds()
    if (min - max):Volume() > 8000 then return end -- I really don't want to accidentally grab the world.

    return body, ray.hitpos, ray.dist
end

function TOOL:LeftClick()
    local body, hitpos, dist = self:GetTarget()
    if not body then return end

    self.grabbed = body
    self.grabbed:SetDynamic(true)
    self.grabbed:SetVelocity(Vector(0,0,0))
    local grtr = self.grabbed:GetTransform()
    self.relative = grtr:ToLocal(hitpos)
    self.rotation = MakeTransformation(TransformToLocalTransform(GetPlayerTransform(), self.grabbed:GetTransform()))
    self.dist = dist
end

function TOOL:RightClick()
    if not self.grabbed then return end
    self.grabbed:SetDynamic(false)
    self.grabbed = nil
    self.released = GetTime()
end

function TOOL:LeftClickReleased()
    self.grabbed = nil
    self.released = GetTime()
end

function TOOL:MouseWheel(ds)
    if self.released > GetTime() - 0.5 then return true end
    if self.grabbed then
        self.dist = math.max(self.dist + ds, 2)
        return true
    end
end

local offset = Vector(0.375,-0.425,-1.4)
function TOOL:Tick()
    if not self.grabbed or not self.grabbed:IsValid() then
        if InputPressed("r") then
            local body = self:GetTarget()
            if not body then return end
            body:SetDynamic(true)
            body:SetVelocity(Vector(0,0,0))
        end
        return
    end
    local r, g, b = math.random(), math.random(), math.random()
    self.grabbed:DrawOutline(r, g, b, 1)
    local bodytr = self.grabbed:GetTransform()
    local onbody = bodytr:ToGlobal(self.relative)
    local camtr = MakeTransformation(GetCameraTransform())
    local aimpos = camtr:ToGlobal(Vector(0,0,-self.dist))
    DebugCross(onbody, 1, 0, 0)
    DebugCross(aimpos, 0, 0, 1)
    DebugLine(onbody, aimpos, 0, 1, 0)

    local nozzle = camtr:ToGlobal(offset)
    DebugLine(nozzle, onbody, 1, 0, 0)
    DebugLine(nozzle, aimpos, 0, 0, 1)
    local points = {[0] = nozzle}
    for i = 1, 7 do
        local t = i/8
        local t2 = t^1.3
        points[i] = nozzle:Lerp(aimpos, t2):Lerp(nozzle:Lerp(onbody, t2), t)
    end
    points[8] = onbody
    for i = 1, 8 do render.drawline(points[i-1], points[i], {r=r, g=g, b=b}) end

    local dist = onbody:Distance(aimpos)
    local force = (aimpos - onbody) * 15
    self.grabbed:SetVelocity(force)

    if InputDown("e") then
        if InputPressed("e") then
            self.startrot = self.rotation.rot
            self.mousex, self.mousey = 0, 0
        end
        UiMakeInteractive()
        local dx, dy = UiGetMousePos()
        local w, h = UiWidth(), UiHeight()
        dx, dy = dx - w/2, dy - h/2
        self.rotation.rot = QuatEuler((dy - self.mousey)/h*360,(dx - self.mousex)/w*360, 0) * self.rotation.rot
        self.mousex, self.mousey = dx, dy
    end

    local nrot = TransformToParentTransform(GetPlayerTransform(), self.rotation)
    local p, y, r = (bodytr.rot * MakeQuaternion(nrot.rot):Conjugate()):ToEuler()
    local diff = -Vector(p, y, r)

    self.grabbed:SetAngularVelocity(diff / 5)
end

RegisterTool("physgun", TOOL)