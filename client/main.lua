-- vault-interact: mirar y pulsar.
-- Todo lo que se puede usar en el mundo llega como "proveedor": una función que
-- da los puntos cercanos (candidatos), otra que dice qué pone la etiqueta y lo
-- que hacen las teclas. Hay dos clases:
--  · Los de otros recursos (Registrar): deciden ellos qué hace cada tecla.
--  · El de las interacciones (target.lua): la API de ox_target, con un menú de
--    opciones que se elige con la rueda y E.
-- Cada Config.Intervalo ms se piden los puntos; en cada frame solo se mide cuál
-- queda más cerca del rayo de la cámara. Sin raycast de físicas para los de los
-- recursos: vale para props sin colisión, huecos de un estante o un punto en el aire.
--
--   exports[recurso]:Registrar(nombre, {   (en inglés: registerProvider, ver docs/providers.md)
--       candidatos = function() return { { id, x, y, z, umbral?, alcance?, siempre?, entidades?, indicador?, ... } } end,
--       etiqueta   = function(c) return { titulo, sub?, aviso?, cantidad?, precio?, teclas = { { k = 'E', t = 'Coger' } } } end,
--       teclas     = { 'E', 'G' },              -- las que usa (se bloquean mientras se mira un punto suyo)
--       pulsar     = function(c, tecla) end,    -- al pulsar
--       mantener   = function(c, tecla) end,    -- mientras sigue pulsada (cada Config.CadaMantener ms)
--       soltar     = function(c, tecla) end,    -- al soltar
--       mirando    = function(c) end,           -- cada 400 ms mientras se mira
--       cambio     = function(c) end,           -- cuando cambia lo que se mira (c = nil: nada)
--       cadaFrame  = function(c) end,           -- en cada frame mientras se mira
--   })
-- Los campos de cada candidato que no son de aquí vuelven tal cual en los avisos.
local Llamar, Enviar = LSI.Llamar, LSI.Enviar

local proveedores = {}   -- [nombre] = { o = opciones, recurso, teclas = { [letra] = control } }
local cands = {}
local hayTarget = false  -- algún candidato es de target.lua: hace falta el rayo de físicas
local objetivo, clave, etiquetaVista
local pausado = false
local forzar = false
local siguienteMantener = {}
local siguienteMirando = 0
local contornados = {}
local puntosVistos = false

local function D2(ax, ay, az, bx, by, bz)
    local dx, dy, dz = ax - bx, ay - by, az - bz
    return dx * dx + dy * dy + dz * dz
end

-- ── La etiqueta (NUI) ────────────────────────────────────────────────────────
local function Ocultar()
    if etiquetaVista then Enviar('etiqueta', false) etiquetaVista = false end
end

-- ── Contorno ─────────────────────────────────────────────────────────────────
local function Contornear(lista)
    for _, o in ipairs(contornados) do if DoesEntityExist(o) then SetEntityDrawOutline(o, false) end end
    contornados = {}
    if not Config.Contorno.activo or type(lista) ~= 'table' then return end
    for _, o in ipairs(lista) do
        if o and o ~= 0 and DoesEntityExist(o) then
            SetEntityDrawOutline(o, true)
            contornados[#contornados + 1] = o
        end
    end
end

local function Firma(lista)
    if type(lista) ~= 'table' then return '' end
    return table.concat(lista, ',')
end

-- ── Pedir los puntos ─────────────────────────────────────────────────────────
local function Recalcular()
    local nuevos, t = {}, false
    if not pausado then
        for nombre, p in pairs(proveedores) do
            local lista = Llamar(p.o.candidatos)
            if type(lista) == 'table' then
                for _, c in ipairs(lista) do
                    if type(c) == 'table' and c.x and c.y and c.z then
                        c._p = nombre
                        if p.interno then t = true end
                        nuevos[#nuevos + 1] = c
                    end
                end
            end
        end
    end
    cands, hayTarget = nuevos, t
end

CreateThread(function()
    local cuando = 0
    while true do
        if forzar or GetGameTimer() >= cuando then
            forzar = false
            cuando = GetGameTimer() + Config.Intervalo
            Recalcular()
        end
        Wait(50)
    end
end)

-- ── Elegir el objetivo con el rayo de la cámara ──────────────────────────────
local function Rayo()
    local o = GetFinalRenderedCamCoord()
    local r = GetFinalRenderedCamRot(2)
    local rx, rz = math.rad(r.x), math.rad(r.z)
    return o, -math.sin(rz) * math.cos(rx), math.cos(rz) * math.cos(rx), math.sin(rx)
end

-- Lo que toca de verdad el rayo (paredes, vehículos, peds, objetos). Solo lo
-- necesitan los puntos de target.lua y se repite cada 80 ms.
local golpe = { hit = false, ent = 0, x = 0.0, y = 0.0, z = 0.0, d = math.huge }
local siguienteGolpe = 0

local function Golpe(o, dx, dy, dz)
    local ahora = GetGameTimer()
    if ahora < siguienteGolpe then return golpe end
    siguienteGolpe = ahora + 80
    local ped = PlayerPedId()
    local veh = GetVehiclePedIsIn(ped, false)
    -- en un vehículo, solo el mapa y los objetos: el propio coche y su conductor no tapan
    local flags = veh ~= 0 and 17 or 31
    local h = StartExpensiveSynchronousShapeTestLosProbe(o.x, o.y, o.z, o.x + dx * 15.0, o.y + dy * 15.0,
        o.z + dz * 15.0, flags, veh ~= 0 and veh or ped, 7)
    local _, hit, fin, _, ent = GetShapeTestResult(h)
    golpe.hit = hit == true or hit == 1
    if golpe.hit then
        golpe.ent, golpe.x, golpe.y, golpe.z = ent or 0, fin.x, fin.y, fin.z
        golpe.d = math.sqrt(D2(fin.x, fin.y, fin.z, o.x, o.y, o.z))
    else
        golpe.ent, golpe.d = 0, math.huge
    end
    return golpe
end

--- El candidato que queda más cerca del rayo. Un candidato `siempre` gana sin mirar;
--- `alcance` limita la distancia desde el jugador (a la altura del pecho).
local function Elegir()
    if #cands == 0 then return nil end
    local o, dx, dy, dz = Rayo()
    local ped = GetEntityCoords(PlayerPedId())
    local g = hayTarget and Golpe(o, dx, dy, dz)
    local sinTarget = Config.OcultarConNui and IsNuiFocused()
    local mejor, mejorD = nil, math.huge
    for _, c in ipairs(cands) do
        if c.siempre then return c end
        if not c.soloIndicador and not (c._t and sinTarget) then
            if c._t then LSI.Posicion(c) end
            local vx, vy, vz = c.x - o.x, c.y - o.y, c.z - o.z
            local t = vx * dx + vy * dy + vz * dz
            local px, py, pz = o.x + dx * t - c.x, o.y + dy * t - c.y, o.z + dz * t - c.z
            local d = math.sqrt(px * px + py * py + pz * pz)
            local vale
            if c._t then
                vale = LSI.Apuntado(c, g, o, dx, dy, dz, t, d)
            else
                vale = t > 0 and d < (c.umbral or Config.Umbral)
                    and (not c.alcance or D2(ped.x, ped.y, ped.z + 0.5, c.x, c.y, c.z) < c.alcance * c.alcance)
            end
            if vale and d < mejorD then mejor, mejorD = c, d end
        end
    end
    return mejor
end

-- ── Indicadores: los puntos pequeños de lo que hay cerca ─────────────────────
local function Indicadores(activo)
    if not Config.Indicadores.activo then return end
    local lista, n = {}, 0
    if not (Config.OcultarConNui and IsNuiFocused()) then
        for _, c in ipairs(cands) do
            if (c.ind or c.indicador) and c ~= activo and n < Config.Indicadores.max then
                if c._t then LSI.Posicion(c) end
                local ok, sx, sy = GetScreenCoordFromWorldCoord(c.x, c.y, c.z)
                if ok then
                    n = n + 1
                    lista[n] = { sx, sy, c.soloIndicador and 0 or 1 }
                end
            end
        end
    end
    if n > 0 then
        Enviar('puntos', lista)
        puntosVistos = true
    elseif puntosVistos then
        Enviar('puntos', false)
        puntosVistos = false
    end
end

-- ── Bucle de cada frame (solo con puntos cerca) ──────────────────────────────
local function Cambiar(c)
    local antes = objetivo and proveedores[objetivo._p]
    if antes and (not c or c._p ~= objetivo._p) then Llamar(antes.o.cambio, nil) end
    objetivo = c
    if c then Llamar(proveedores[c._p].o.cambio, c) end
end

CreateThread(function()
    local firmaContorno = ''
    while true do
        if #cands == 0 or pausado or IsPauseMenuActive() then
            if objetivo then Cambiar(nil) end
            if clave then Ocultar() clave = nil Contornear(nil) firmaContorno = '' end
            if puntosVistos then Enviar('puntos', false) puntosVistos = false end
            Wait(200)
        else
            local c = Elegir()
            local p = c and proveedores[c._p]
            if not p then
                if objetivo then Cambiar(nil) end
                if clave then Ocultar() clave = nil Contornear(nil) firmaContorno = '' end
            else
                local ok, sx, sy = GetScreenCoordFromWorldCoord(c.x, c.y, c.z)
                local k = c._p .. ':' .. tostring(c.id)
                if k ~= clave or c ~= objetivo then
                    -- los puntos se rehacen cada intervalo: mismo id = mismo objetivo
                    if k ~= clave then Cambiar(c) else objetivo = c end
                    local et = Llamar(p.o.etiqueta, c)
                    if type(et) == 'table' then
                        et.x, et.y = sx, sy
                        Enviar('etiqueta', et)
                        etiquetaVista = true
                    else
                        Ocultar()
                    end
                    local f = Firma(c.entidades)
                    if f ~= firmaContorno or k ~= clave then Contornear(c.entidades) firmaContorno = f end
                    clave = k
                end
                if ok and etiquetaVista then Enviar('pos', { x = sx, y = sy }) end
                -- las teclas de este proveedor
                local ahora = GetGameTimer()
                for letra, control in pairs(p.teclas) do
                    DisableControlAction(0, control, true)
                    if IsDisabledControlJustPressed(0, control) then
                        Llamar(p.o.pulsar, c, letra)
                        siguienteMantener[letra] = ahora + Config.CadaMantener
                    elseif p.o.mantener and IsDisabledControlPressed(0, control) and ahora >= (siguienteMantener[letra] or 0) then
                        siguienteMantener[letra] = ahora + Config.CadaMantener
                        Llamar(p.o.mantener, c, letra)
                    end
                    if IsDisabledControlJustReleased(0, control) then Llamar(p.o.soltar, c, letra) end
                end
                if p.o.mirando and ahora >= siguienteMirando then
                    siguienteMirando = ahora + 400
                    Llamar(p.o.mirando, c)
                end
                if p.o.cadaFrame then Llamar(p.o.cadaFrame, c) end
            end
            Indicadores(c)
            Wait(0)
        end
    end
end)

-- ── Registrar ────────────────────────────────────────────────────────────────
local function Registrar(nombre, o, recurso, interno)
    if type(nombre) ~= 'string' or nombre == '' then
        LSI.Aviso('%s: registerProvider needs a name (text)', tostring(recurso))
        return false
    end
    if type(o) ~= 'table' or not o.candidatos then
        LSI.Aviso("%s: provider '%s' needs a `candidates` function", tostring(recurso), nombre)
        return false
    end
    local teclas = {}
    for _, letra in ipairs(type(o.teclas) == 'table' and o.teclas or { 'E' }) do
        if Config.Teclas[letra] then
            teclas[letra] = Config.Teclas[letra]
        else
            LSI.Aviso("%s: key '%s' of provider '%s' is not in Config.Keys", tostring(recurso), tostring(letra), nombre)
        end
    end
    proveedores[nombre] = { o = o, recurso = recurso, teclas = teclas, interno = interno }
    forzar = true
    return true
end

--- Para target.lua: su proveedor, el que lleva las interacciones.
function LSI.RegistrarInterno(nombre, o) return Registrar(nombre, o, nil, true) end

--- La etiqueta se rehace en el siguiente frame (cambió la opción elegida...).
function LSI.Rehacer() clave = nil end

--- Los puntos se piden ya, sin esperar al intervalo.
function LSI.Forzar() forzar = true end

-- ── La API en inglés → la interna ────────────────────────────────────────────
local EN_OPC = { candidates = 'candidatos', label = 'etiqueta', keys = 'teclas', onPress = 'pulsar',
    onHold = 'mantener', onRelease = 'soltar', onLook = 'mirando', onChange = 'cambio', onFrame = 'cadaFrame' }
local EN_PUNTO = { threshold = 'umbral', reach = 'alcance', always = 'siempre', entities = 'entidades', indicator = 'indicador' }
local EN_ETIQ = { title = 'titulo', subtitle = 'sub', warning = 'aviso', amount = 'cantidad', price = 'precio', keys = 'teclas' }

local function Copiar(t, mapa)
    for en, es in pairs(mapa) do
        if t[es] == nil then t[es] = t[en] end
    end
end

local function DesdeIngles(o)
    if type(o) ~= 'table' then return o end
    local r = {}
    for en, es in pairs(EN_OPC) do r[es] = o[en] end
    local candidates, label = o.candidates, o.label
    if candidates then
        r.candidatos = function()
            local lista = candidates()
            if type(lista) == 'table' then
                for _, c in ipairs(lista) do if type(c) == 'table' then Copiar(c, EN_PUNTO) end end
            end
            return lista
        end
    end
    if label then
        r.etiqueta = function(c)
            local e = label(c)
            if type(e) == 'table' then
                Copiar(e, EN_ETIQ)
                for _, t in ipairs(type(e.teclas) == 'table' and e.teclas or {}) do
                    if type(t) == 'table' then t.k, t.t = t.k or t.key, t.t or t.text end
                end
            end
            return e
        end
    end
    return r
end

-- ── Exports ──────────────────────────────────────────────────────────────────
local function Quitar(nombre)
    proveedores[nombre] = nil
    if objetivo and objetivo._p == nombre then objetivo = nil clave = nil Ocultar() Contornear(nil) end
    forzar = true
end

local function Refrescar() clave = nil forzar = true end
local function Pausar(si) pausado = si == true forzar = true end

--- Registra (o sustituye) un proveedor. Se quita solo si su recurso se para.
LSI.Export('registerProvider', function(nombre, o) return Registrar(nombre, DesdeIngles(o), GetInvokingResource()) end)
LSI.Export('removeProvider', Quitar)
--- La etiqueta se rehace (cambió lo que dice) y los puntos se piden ya.
LSI.Export('refresh', Refrescar)
--- Lo que se está mirando: { provider, id } o nil.
LSI.Export('getCurrentTarget', function() return objetivo and { provider = objetivo._p, id = objetivo.id } or nil end)
--- Esconde la etiqueta y no atiende teclas (p. ej. con una pantalla abierta).
LSI.Export('pause', Pausar)

-- Los nombres de ls_interact 2.x (en español), para quien ya los usa.
LSI.Export('Registrar', function(nombre, o) return Registrar(nombre, o, GetInvokingResource()) end)
LSI.Export('Quitar', Quitar)
LSI.Export('Refrescar', Refrescar)
LSI.Export('Objetivo', function() return objetivo and { proveedor = objetivo._p, id = objetivo.id } or nil end)
LSI.Export('Pausar', Pausar)

-- Un recurso que se para se lleva sus proveedores.
AddEventHandler('onResourceStop', function(res)
    if res == LSI.Recurso then Contornear(nil) return end
    for nombre, p in pairs(proveedores) do
        if p.recurso == res then
            proveedores[nombre] = nil
            if objetivo and objetivo._p == nombre then objetivo = nil clave = nil Ocultar() Contornear(nil) end
        end
    end
end)

CreateThread(function()
    local c = Config.Contorno.color
    SetEntityDrawOutlineColor(c[1], c[2], c[3], c[4])
    Wait(500)
    Enviar('tema', Config.Tema)
    Enviar('idioma', { numeros = LSI.T.number_format, precio = LSI.T.price_format })
end)
