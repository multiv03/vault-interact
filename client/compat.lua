-- vault-interact: lo que hace falta para sustituir a ox_target.
--  · `_puente`: la puerta de entrada del recurso puente (puente/ox_target), que
--    pasa aquí cada llamada a exports.ox_target con el recurso que la hizo.
--  · Las funciones de qtarget, que ox_target también traía (provide 'qtarget').
local API = LSI.API
local Q = {}
LSI.Qtarget = Q

--- Las opciones de qtarget/qb-target → las de ox_target (como hacía ox_target).
local function Convertir(datos)
    datos = datos or {}
    local distancia = datos.distance
    local opciones = datos.options or {}
    local lista = {}
    for _, v in ipairs(opciones) do lista[#lista + 1] = v end
    -- a veces llegan como tabla con nombres (o mezclada)
    for k, v in pairs(opciones) do
        if type(k) ~= 'number' and type(v) == 'table' then lista[#lista + 1] = v end
    end
    for _, v in ipairs(lista) do
        v.onSelect = v.action
        v.distance = v.distance or distancia
        v.name = v.name or v.label
        v.groups = v.job
        v.items = v.item or v.required_item
        if v.event and v.type and v.type ~= 'client' then
            if v.type == 'server' then
                v.serverEvent = v.event
            elseif v.type == 'command' then
                v.command = v.event
            end
            v.event, v.type = nil, nil
        end
        v.action, v.job, v.item, v.required_item = nil, nil, nil, nil
        v.qtarget = true
    end
    return lista
end

--- La altura de una zona de PolyZone: entre minZ y maxZ, o sin límite.
local function Altura(op, z)
    if op.minZ and op.maxZ then return (op.minZ + op.maxZ) / 2, math.abs(op.maxZ - op.minZ) end
    return z, 1000.0
end

function Q.AddBoxZone(r, nombre, centro, largo, ancho, op, top)
    op = op or {}
    local x, y, z = LSI.Vec(centro)
    local cz, alto = Altura(op, z)
    return API.addBoxZone(r, {
        name = nombre,
        coords = vector3(x, y, cz),
        size = vector3(ancho, largo, alto),
        rotation = op.heading,
        debug = op.debugPoly,
        options = Convertir(top),
    })
end

function Q.AddPolyZone(r, nombre, puntos, op, top)
    op = op or {}
    local cz, alto = Altura(op, GetEntityCoords(PlayerPedId()).z)
    local p = {}
    for i, v in ipairs(puntos) do
        local x, y = LSI.Vec(v)
        p[i] = vector3(x, y, cz)
    end
    return API.addPolyZone(r, { name = nombre, points = p, thickness = alto, debug = op.debugPoly, options = Convertir(top) })
end

function Q.AddCircleZone(r, nombre, centro, radio, op, top)
    op = op or {}
    return API.addSphereZone(r, { name = nombre, coords = centro, radius = radio, debug = op.debugPoly, options = Convertir(top) })
end

function Q.RemoveZone(r, id) API.removeZone(r, id, true) end

function Q.AddTargetBone(r, huesos, top)
    if type(huesos) ~= 'table' then huesos = { huesos } end
    local opciones = Convertir(top)
    for _, v in ipairs(opciones) do v.bones = huesos end
    API.addGlobalVehicle(r, opciones)
end

function Q.AddTargetEntity(r, ents, top)
    if type(ents) ~= 'table' then ents = { ents } end
    local opciones = Convertir(top)
    for _, ent in ipairs(ents) do
        if NetworkGetEntityIsNetworked(ent) then
            API.addEntity(r, NetworkGetNetworkIdFromEntity(ent), opciones)
        else
            API.addLocalEntity(r, ent, opciones)
        end
    end
end

function Q.RemoveTargetEntity(r, ents, nombres)
    if type(ents) ~= 'table' then ents = { ents } end
    for _, ent in ipairs(ents) do
        if NetworkGetEntityIsNetworked(ent) then
            API.removeEntity(r, NetworkGetNetworkIdFromEntity(ent), nombres)
        else
            API.removeLocalEntity(r, ent, nombres)
        end
    end
end

function Q.AddTargetModel(r, m, top) API.addModel(r, m, Convertir(top)) end
function Q.RemoveTargetModel(r, m, nombres) API.removeModel(r, m, nombres) end
function Q.Ped(r, top) API.addGlobalPed(r, Convertir(top)) end
function Q.RemovePed(r, nombres) API.removeGlobalPed(r, nombres) end
function Q.Vehicle(r, top) API.addGlobalVehicle(r, Convertir(top)) end
function Q.RemoveVehicle(r, nombres) API.removeGlobalVehicle(r, nombres) end
function Q.Object(r, top) API.addGlobalObject(r, Convertir(top)) end
function Q.RemoveObject(r, nombres) API.removeGlobalObject(r, nombres) end
function Q.Player(r, top) API.addGlobalPlayer(r, Convertir(top)) end
function Q.RemovePlayer(r, nombres) API.removeGlobalPlayer(r, nombres) end

--- La entrada del puente: _puente('addBoxZone', recurso, ...) o _puente('qt:AddBoxZone', recurso, ...).
LSI.Export('_puente', function(nombre, recurso, ...)
    local f
    if type(nombre) == 'string' and nombre:sub(1, 3) == 'qt:' then
        f = Q[nombre:sub(4)]
    else
        f = API[nombre]
    end
    if not f then error(('%s: unknown function %s'):format(LSI.Recurso, tostring(nombre)), 2) end
    return f(recurso or GetInvokingResource() or LSI.Recurso, ...)
end)
