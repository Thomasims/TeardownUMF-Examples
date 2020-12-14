local TOOL = {}

TOOL.printname = "Physics Gun"
TOOL.order = 3

TOOL.base = "gun"
TOOL.suppress_default = true

local DEBUG = false

function TOOL:Initialize()
    self.released = 0
end

function TOOL:GetTarget()
    local ray = MakeTransformation(GetCameraTransform()):Raycast(100, -1)
    local body = Body(GetShapeBody(ray.shape))
    if not body then return end

    local min, max = body:GetWorldBounds()
    if (min - max):Volume() > 64000 then return end -- I really don't want to accidentally grab the world.

    return body, ray.hitpos, ray.dist
end

function TOOL:AttemptGrab()
    local body, hitpos, dist = self:GetTarget()
    if not body then return end

    self.grabbed = body
    self.grabbed:SetDynamic(true)
    self.grabbed:SetVelocity(Vector(0,0,0))
    local grtr = self.grabbed:GetTransform()
    self.relative = grtr:ToLocal(hitpos)
    self.rotation = MakeTransformation(TransformToLocalTransform(GetPlayerTransform(), self.grabbed:GetTransform()))
    self.dist = dist
    return self.grabbed
end

function TOOL:LeftClick()
    if not self:AttemptGrab() then self.grabbing = true end
end

function TOOL:RightClick()
    if not self.grabbed then return end
    self.grabbed:SetDynamic(false)
    self.grabbed = nil
    self.released = GetTime()
end

function TOOL:LeftClickReleased()
    self.grabbed = nil
    self.grabbing = false
end

function TOOL:MouseWheel(ds)
    if self.grabbed then
        self.dist = math.max(self.dist + ds, 2)
        self.released = GetTime()
        return true
    end
    if self.released > GetTime() - 0.5 then return true end
end

function TOOL:DrawBeam(source, target, object, r, g, b)
    local beamdata = {r=r, g=g, b=b, sprite=render.white_fade_sprite}
    if target == object then return render.drawline(source, target, beamdata) end
    local prev = source
    for i = 1, 7 do
        local t = i/8
        local t2 = t^1.3
        local newpoint = source:Lerp(target, t2):Lerp(source:Lerp(object, t2), t)
        render.drawline(prev, newpoint, beamdata)
        prev = newpoint
    end
    render.drawline(prev, object, beamdata)
end

local offset = Vector(0.375,-0.425,-1.4)
function TOOL:Tick()
    local r, g, b = math.random(), math.random(), math.random()
    local camtr = MakeTransformation(GetCameraTransform())
    local nozzle = camtr:ToGlobal(offset)

    if not self.grabbed or not self.grabbed:IsValid() then
        if InputPressed("r") then
            local body = self:GetTarget()
            if body then
            body:SetDynamic(true)
            body:SetVelocity(Vector(0,0,0))
        end
        end

        if self.grabbing then
            if self:AttemptGrab() then
                self.grabbing = false
                return
            end
            local ray = camtr:Raycast(100, -1)
            self:DrawBeam(nozzle, ray.hitpos, ray.hitpos, r, g, b)
            if not InputDown("lmb") then self:LeftClickReleased() end
        end
        return
    end

    self.grabbed:DrawOutline(r, g, b, 1)
    local bodytr = self.grabbed:GetTransform()
    local onbody = bodytr:ToGlobal(self.relative)
    local aimpos = camtr:ToGlobal(Vector(0,0,-self.dist))

    self:DrawBeam(nozzle, aimpos, onbody, r, g, b)

    if DEBUG then
        DebugCross(onbody, 1, 0, 0)
        DebugCross(aimpos, 0, 0, 1)
        DebugLine(onbody, aimpos, 0, 1, 0)
        DebugLine(nozzle, onbody, 1, 0, 0)
        DebugLine(nozzle, aimpos, 0, 0, 1)
    end

    local dist = onbody:Distance(aimpos)
    local force = (aimpos - onbody) * 15
    self.grabbed:SetVelocity(force)

    if InputDown("e") then
        if not self.startrot then
            self.startrot = self.rotation.rot
            self.mousex, self.mousey = 0, 0
        end
        UiMakeInteractive()
        local dx, dy = UiGetMousePos()
        local w, h = UiWidth(), UiHeight()
        dx, dy = dx - w/2, dy - h/2
        self.rotation.rot = QuatEuler((dy - self.mousey)/h*360,(dx - self.mousex)/w*360, 0) * self.rotation.rot
        self.mousex, self.mousey = dx, dy
    else
        self.startrot = nil
    end

    local nrot = TransformToParentTransform(GetPlayerTransform(), self.rotation)
    local p, y, r = (bodytr.rot * MakeQuaternion(nrot.rot):Conjugate()):ToEuler()
    local diff = -Vector(p, y, r)

    self.grabbed:SetAngularVelocity(diff / 5)

    if not InputDown("lmb") then self:LeftClickReleased() end
end

RegisterTool("physgun", TOOL)