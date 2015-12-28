class "cAirplanes"

function cAirplanes:__init()
	self:initVars()
	Events:Subscribe("ModuleUnload", self, self.onModuleUnload)
	Events:Subscribe("PostTick", self, self.onPostTick)
	-- Events:Subscribe("Render", self, self.onRender)
	Events:Subscribe("LocalPlayerInput", self, self.onLocalPlayerInput)
	Events:Subscribe("EntitySpawn", self, self.onEntitySpawn)
	Events:Subscribe("EntityDespawn", self, self.onEntityDespawn)
	Events:Subscribe("VehicleCollide", self, self.onVehicleCollide)
	Network:Subscribe("01", self, self.onVehicleUpdate)
end

function cAirplanes:initVars()
	self.vehicles = {}
	self.actors = {}
	self.delay = 5 -- seconds
end

-- Events
function cAirplanes:onModuleUnload()
	for _, actor in pairs(self.actors) do
		actor:Remove()
	end
end

function cAirplanes:onPostTick()
	for _, data in pairs(self.vehicles) do
		self:updateVehicle(data)
	end
end

function cAirplanes:onRender()
	-- Debug
	for _, data in pairs(self.vehicles) do
		local vehicle = data[1]
		if IsValid(vehicle) then
			local position = vehicle:GetPosition()
			Render:DrawCircle(Render:WorldToScreen(position), 10, Color.Yellow)
			if data[5] then
				local target = data[5]
				target.y = position.y
				Render:DrawCircle(Render:WorldToScreen(target), 5, Color.Red)
			end
		end
	end
end

function cAirplanes:onLocalPlayerInput(args)
	if args.input ~= Action.UseItem then return end
	local vehicle = LocalPlayer:GetVehicle()
	if not IsValid(vehicle) then return end
	local vehicleId = vehicle:GetId() + 1
	if self.vehicles[vehicleId] then return false end
end

function cAirplanes:onVehicleCollide(args)
	if args.entity.__type ~= "Vehicle" then return end
	local vehicleId = args.entity:GetId() + 1
	local data = self.vehicles[vehicleId]
	if not data then return end
	local timer = data[2]
	if timer:GetSeconds() < self.delay then return end
	timer:Restart()
	local position
	local vehicle = data[1]
	if IsValid(vehicle) then position = vehicle:GetPosition() end
	Network:Send("01", { vehicleId, position })
end

function cAirplanes:onEntitySpawn(args)
	if args.entity.__type ~= "Vehicle" then return end
	local vehicle = args.entity
	if not vehicle:GetValue("AI") then return end
	local vehicleId = vehicle:GetId() + 1
	self.vehicles[vehicleId] = self:addVehicle(vehicle)
end

function cAirplanes:onEntityDespawn(args)
	if args.entity.__type ~= "Vehicle" then return end
	local vehicleId = args.entity:GetId() + 1
	if not self.vehicles[vehicleId] then return end
	self.vehicles[vehicleId] = nil
	self.actors[vehicleId]:Remove()
	self.actors[vehicleId] = nil
end

-- Network
function cAirplanes:onVehicleUpdate(args)
	local vehicleId = args[1]
	if not self.vehicles[vehicleId] then return end
	self.vehicles[vehicleId][5] = args[2]
end

-- Custom
function cAirplanes:addVehicle(vehicle)
	local vehicleId = vehicle:GetId() + 1
	local position = vehicle:GetPosition()
	local yaw = vehicle:GetValue("AI")
	local angle = Angle(yaw, 0, 0)
	local height = self:getFlightHeight(position, angle)
	position.y = height
	local velocity = angle * Vector3.Forward * AirplaneSpeed[vehicle:GetModelId()]
	vehicle:SetPosition(position - velocity)
	vehicle:SetLinearVelocity(velocity)
	self.actors[vehicleId] = ClientActor.Create(AssetLocation.Game,
	{
		model_id = 98,
		position = position,
		angle = angle
	})
	return { vehicle, Timer(), yaw, Timer() }
end

function cAirplanes:updateVehicle(data)
	local vehicle = data[1]
	if not IsValid(vehicle) then return end
	if vehicle:GetHealth() < 0.3 then
		self:onVehicleCollide({ entity = vehicle })
		return
	end
	local vehicleId = vehicle:GetId() + 1
	local position = vehicle:GetPosition()
	local angle = Angle(data[3], 0, 0)
	local height = self:getFlightHeight(position, angle)
	local pitch = math.clamp((height - position.y) / 200, -1, 1)
	angle.pitch = math.lerp(vehicle:GetAngle().pitch, pitch, 0.05)
	vehicle:SetAngle(angle)
	local actor = self.actors[vehicleId]
	if not IsValid(actor) then return end
	if not actor:GetVehicle() then
		actor:EnterVehicle(vehicle, 0)
		return
	end
	local speed = 0
	if data[5] then
		local timer = data[4]
		local velocity = angle * Vector3.Forward * AirplaneSpeed[vehicle:GetModelId()]
		speed = Vector3.Distance2D(position, data[5] + velocity * timer:GetSeconds()) * 0.01
		local compare = Angle.FromVectors(Vector3.Forward, (data[5] - position):Normalized())
		compare.pitch = angle.pitch
		speed = speed * Angle.Dot(angle, compare) * 2 - 1
		timer:Restart()
	else
		speed = AirplaneSpeed[vehicle:GetModelId()] / 100
	end
	actor:SetInput(Action.PlaneIncTrust, math.max(speed, 0))
	actor:SetInput(Action.PlaneDecTrust, math.max(-speed, 0))
end

function cAirplanes:getFlightHeight(position, angle)
	local height = 200
	local movement = angle * Vector3.Forward
	for amount = 5, 400, 20 do
		height = math.max(Physics:GetTerrainHeight(position + amount * movement), height)
	end
	return height + 200
end

cAirplanes = cAirplanes()
