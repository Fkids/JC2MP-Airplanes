class "sAirplanes"

function sAirplanes:__init()
	self:initVars()
	self:initPool()
	Events:Subscribe("ModuleLoad", self, self.onModuleLoad)
	Events:Subscribe("ModuleUnload", self, self.onModuleUnload)
	Events:Subscribe("EntityDespawn", self, self.onEntityDespawn)
	Network:Subscribe("01", self, self.onVehicleCollide)
end

function sAirplanes:initVars()
	self.vehicles = {}
	self.count = 256 -- planes
	self.delay = 2 -- seconds
	self.timer = Timer()
	self.div1 = self.count / self.delay
	self.div2 = self.delay / self.count
end

function sAirplanes:initPool()
	self.pool = { 39, 51, 59, 59, 81 }
	-- 1x Aeroliner 474 [39]
	-- 1x Cassius 192 [51]
	-- 2x Peek Airhawk 225 [59]
	-- 1x Pell Silverbolt 6 [81]
end

-- Events
function sAirplanes:onModuleLoad()
	for vehicleId = 1, self.count do
		self:createVehicle()
	end
	self.coroutine = coroutine.create(function()
		while true do
			for _, data in pairs(self.vehicles) do
				self:updateVehicle(data)
				coroutine.yield()
			end
		end
	end)
	Events:Subscribe("PostTick", self, self.onPostTick)
end

function sAirplanes:onModuleUnload()
	self.unloading = true
	for _, data in pairs(self.vehicles) do
		self:removeVehicle(data)
	end
end

function sAirplanes:onPostTick(args)
	local amount = math.floor(math.min(args.delta * self.div1, self.count))
	if amount < 1 then
		if self.timer:GetSeconds() < self.div2 then return end
		self.timer:Restart()
		coroutine.resume(self.coroutine)
		return
	end
	for _ = 1, amount do
		coroutine.resume(self.coroutine)
	end
end

function sAirplanes:onEntityDespawn(args)
	if self.unloading then return end
	if args.entity.__type ~= "Vehicle" then return end
	local vehicleId = args.entity:GetId() + 1
	if not self.vehicles[vehicleId] then return end
	self.vehicles[vehicleId] = nil
	self:createVehicle()
end

-- Network
function sAirplanes:onVehicleCollide(args)
	local vehicleId = args[1]
	if not self.vehicles[vehicleId] then return end
	local vehicle = Vehicle.GetById(vehicleId - 1)
	if not IsValid(vehicle) then return end
	if vehicle:GetValue("Destroyed") then
		self.vehicles[vehicleId] = nil
		vehicle:Remove()
		return
	end
	vehicle:SetHealth(0.1)
	vehicle:SetValue("Destroyed", true)
	local position = args[2]
	if not position then return end
	vehicle:SetStreamPosition(position)
end

-- Custom
function sAirplanes:createVehicle()
	local yaw = math.random(-math.pi, math.pi)
	local vehicle = Vehicle.Create
	({
		model_id = self.pool[math.random(#self.pool)],
		position = Vector3(math.random(-16384, 16384), math.random(0, 100), math.random(-16384, 16384)),
		angle = Angle(yaw, 0, 0)
	})
	local vehicleId = vehicle:GetId() + 1
	vehicle:SetNetworkValue("AI", yaw)
	vehicle:SetDeathRemove(true)
	self.vehicles[vehicleId] = { vehicle, Timer() }
end

function sAirplanes:updateVehicle(data, position, angle, modelId)
	local vehicle = data[1]
	if not IsValid(vehicle) then return end
	local position = self:wrapPosition(vehicle:GetPosition())
	local velocity = vehicle:GetAngle() * Vector3.Forward * AirplaneSpeed[vehicle:GetModelId()]
	local vehicleId = vehicle:GetId() + 1
	local position = position + velocity * data[2]:GetSeconds()
	data[2]:Restart()
	vehicle:SetStreamPosition(position)
	for player in vehicle:GetStreamedPlayers() do
		Network:Send(player, "01", { vehicleId, position })
	end
end

function sAirplanes:removeVehicle(data)
	local vehicle = data[1]
	if not IsValid(vehicle) then return end
	vehicle:Remove()
end

function sAirplanes:wrapPosition(position)
	if math.abs(position.x) > 16384 then
		position.x = math.clamp(-position.x, -16000, 16000)
		return position
	end
	if math.abs(position.z) > 16384 then
		position.z = math.clamp(-position.z, -16000, 16000)
		return position
	end
	return position
end

sAirplanes = sAirplanes()
