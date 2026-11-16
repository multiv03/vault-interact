-- vault-interact: las zonas en cuentas puras (caja, esfera, polígono y punto
-- suelto), con el mismo formato que las de ox_lib: si un punto está dentro, a
-- qué distancia queda y dónde las cruza el rayo de la cámara.
LSI.Zonas = {}
local Z = LSI.Zonas
local Vec = LSI.Vec
local sqrt, abs, max, min = math.sqrt, math.abs, math.max, math.min

--- La rotación en grados: un número o un vector (solo cuenta el giro en Z).
local function Grados(r)
    if r == nil then return 0.0 end
    if type(r) == 'number' then return r end
    local _, _, z = Vec(r)
    return z or tonumber(r) or 0.0
end

--- Las coordenadas de un punto del mundo en el sistema de la caja (x, y).
local function Local(z, x, y)
    local dx, dy = x - z.cx, y - z.cy
    return dx * z.cos + dy * z.sin, -dx * z.sin + dy * z.cos
end

local function DentroPoligono(pts, x, y)
    local dentro, j = false, #pts
    for i = 1, #pts do
        local xi, yi, xj, yj = pts[i][1], pts[i][2], pts[j][1], pts[j][2]
        if (yi > y) ~= (yj > y) and x < (xj - xi) * (y - yi) / (yj - yi) + xi then dentro = not dentro end
        j = i
    end
    return dentro
end

--- Distancia (2D) de un punto a un segmento.
local function Segmento(px, py, ax, ay, bx, by)
    local abx, aby = bx - ax, by - ay
    local l = abx * abx + aby * aby
    local t = l > 0 and ((px - ax) * abx + (py - ay) * aby) / l or 0
    t = max(0, min(1, t))
    local dx, dy = ax + abx * t - px, ay + aby * t - py
    return sqrt(dx * dx + dy * dy)
end

--- Una zona nueva a partir de los datos de ox_target/ox_lib. `tipo`: 'box',
--- 'sphere', 'poly' o 'punto'. Da error si los datos no valen.
function Z.Crear(tipo, d)
    local z = { tipo = tipo }
    if tipo == 'poly' then
        local pts, alturas = {}, {}
        for i, p in ipairs(d.points or {}) do
            local x, y, pz = Vec(p)
            if not (x and y) then error('a polygon point has no x, y') end
            pts[i] = { x, y }
            alturas[#alturas + 1] = pz
        end
        if #pts < 3 then error('a polygon needs 3 points or more') end
        -- la altura del polígono: la que más se repite entre sus puntos (como ox_lib)
        local cuenta, base, mejor = {}, nil, 0
        for _, h in ipairs(alturas) do
            cuenta[h] = (cuenta[h] or 0) + 1
            if cuenta[h] > mejor then base, mejor = h, cuenta[h] end
        end
        local cx, cy = 0, 0
        for _, p in ipairs(pts) do cx, cy = cx + p[1], cy + p[2] end
        cx, cy = cx / #pts, cy / #pts
        local r = 0
        for _, p in ipairs(pts) do
            local dx, dy = p[1] - cx, p[2] - cy
            r = max(r, sqrt(dx * dx + dy * dy))
        end
        z.pts, z.cx, z.cy, z.cz = pts, cx, cy, base or 0.0
        z.hz = (tonumber(d.thickness) or 4.0) / 2
        z.radio = sqrt(r * r + z.hz * z.hz)
        z.tol = min(max(r, 0.6), 3.0)
    else
        local x, y, zz = Vec(d.coords)
        if not (x and y and zz) then error('coords is missing') end
        z.cx, z.cy, z.cz = x, y, zz
        if tipo == 'box' then
            local sx, sy, sz = 4.0, 4.0, 4.0
            if d.size then sx, sy, sz = Vec(d.size) end
            z.hx, z.hy, z.hz = (sx or 4.0) / 2, (sy or 4.0) / 2, (sz or 4.0) / 2
            local a = math.rad(Grados(d.rotation))
            z.cos, z.sin = math.cos(a), math.sin(a)
            z.radio = sqrt(z.hx * z.hx + z.hy * z.hy + z.hz * z.hz)
            z.tol = min(max(z.hx, z.hy, z.hz, 0.6), 3.0)
        elseif tipo == 'sphere' then
            z.r = tonumber(d.radius) or 2.0
            z.radio = z.r
            z.tol = min(max(z.r, 0.6), 3.0)
        elseif tipo == 'punto' then
            z.radio = 0.0
            z.tol = 0.6
        else
            error('unknown zone type: ' .. tostring(tipo))
        end
    end
    -- lo que se perdona al mirar el centro (las cajas y esferas se miran enteras)
    z.umbral = tipo == 'punto' and Config.Target.umbral or 0.3
    return z
end

function Z.Contiene(z, x, y, zz)
    local t = z.tipo
    if t == 'box' then
        if abs(zz - z.cz) > z.hz then return false end
        local lx, ly = Local(z, x, y)
        return abs(lx) <= z.hx and abs(ly) <= z.hy
    elseif t == 'sphere' then
        local dx, dy, dz = x - z.cx, y - z.cy, zz - z.cz
        return dx * dx + dy * dy + dz * dz < z.r * z.r
    elseif t == 'poly' then
        return abs(zz - z.cz) <= z.hz and DentroPoligono(z.pts, x, y)
    end
    return false
end

--- Distancia de un punto a la zona (0 si está dentro).
function Z.Distancia(z, x, y, zz)
    local t = z.tipo
    if t == 'box' then
        local lx, ly = Local(z, x, y)
        local ex = max(abs(lx) - z.hx, 0)
        local ey = max(abs(ly) - z.hy, 0)
        local ez = max(abs(zz - z.cz) - z.hz, 0)
        return sqrt(ex * ex + ey * ey + ez * ez)
    elseif t == 'sphere' then
        local dx, dy, dz = x - z.cx, y - z.cy, zz - z.cz
        return max(sqrt(dx * dx + dy * dy + dz * dz) - z.r, 0)
    elseif t == 'poly' then
        local ez = max(abs(zz - z.cz) - z.hz, 0)
        local exy = 0
        if not DentroPoligono(z.pts, x, y) then
            local pts, j = z.pts, #z.pts
            exy = math.huge
            for i = 1, #pts do
                exy = min(exy, Segmento(x, y, pts[j][1], pts[j][2], pts[i][1], pts[i][2]))
                j = i
            end
        end
        return sqrt(exy * exy + ez * ez)
    end
    local dx, dy, dz = x - z.cx, y - z.cy, zz - z.cz
    return sqrt(dx * dx + dy * dy + dz * dz)
end

--- Un eje de la caja en el método de las placas: estrecha [t0, t1] o da nil.
local function Placa(o, d, h, t0, t1)
    if abs(d) < 1e-6 then
        if abs(o) > h then return nil end
        return t0, t1
    end
    local a, b = (-h - o) / d, (h - o) / d
    if a > b then a, b = b, a end
    t0, t1 = max(t0, a), min(t1, b)
    if t0 > t1 then return nil end
    return t0, t1
end

--- Dónde entra en la zona el rayo que sale de o con dirección d (unitaria):
--- la distancia por el rayo (0 si ya se está dentro) o nil si no la cruza.
function Z.Rayo(z, ox, oy, oz, dx, dy, dz)
    local t = z.tipo
    if t == 'box' then
        local lox, loy = Local(z, ox, oy)
        local ldx, ldy = dx * z.cos + dy * z.sin, -dx * z.sin + dy * z.cos
        local t0, t1 = Placa(lox, ldx, z.hx, 0, math.huge)
        if not t0 then return nil end
        t0, t1 = Placa(loy, ldy, z.hy, t0, t1)
        if not t0 then return nil end
        t0 = Placa(oz - z.cz, dz, z.hz, t0, t1)
        return t0
    elseif t == 'sphere' then
        local lx, ly, lz = ox - z.cx, oy - z.cy, oz - z.cz
        local c = lx * lx + ly * ly + lz * lz - z.r * z.r
        if c <= 0 then return 0 end
        local b = lx * dx + ly * dy + lz * dz
        local disc = b * b - c
        if b > 0 or disc < 0 then return nil end
        return -b - sqrt(disc)
    elseif t == 'poly' then
        -- sin fórmula cerrada: se recorre el rayo a pasos de 20 cm hasta pasar la zona
        local cx, cy, cz = z.cx - ox, z.cy - oy, z.cz - oz
        local fin = min(sqrt(cx * cx + cy * cy + cz * cz) + z.radio, 20)
        local s = 0
        while s <= fin do
            if Z.Contiene(z, ox + dx * s, oy + dy * s, oz + dz * s) then return s end
            s = s + 0.2
        end
    end
    return nil
end

-- ── Debug: las zonas con `debug = true` se dibujan ───────────────────────────
local function Lados(pts, z0, z1, r, g, b)
    local n = #pts
    for i = 1, n do
        local p, q = pts[i], pts[i % n + 1]
        DrawLine(p[1], p[2], z0, q[1], q[2], z0, r, g, b, 255)
        DrawLine(p[1], p[2], z1, q[1], q[2], z1, r, g, b, 255)
        DrawLine(p[1], p[2], z0, p[1], p[2], z1, r, g, b, 255)
    end
end

function Z.Dibujar(z)
    local c = z.color or {}
    local r, g, b, a = c.r or c[1] or 255, c.g or c[2] or 42, c.b or c[3] or 24, c.a or c[4] or 100
    if z.tipo == 'box' then
        local esq = {}
        for i, s in ipairs({ { 1, 1 }, { -1, 1 }, { -1, -1 }, { 1, -1 } }) do
            local lx, ly = s[1] * z.hx, s[2] * z.hy
            esq[i] = { z.cx + lx * z.cos - ly * z.sin, z.cy + lx * z.sin + ly * z.cos }
        end
        Lados(esq, z.cz - z.hz, z.cz + z.hz, r, g, b)
    elseif z.tipo == 'poly' then
        Lados(z.pts, z.cz - z.hz, z.cz + z.hz, r, g, b)
    else
        local s = z.r or 0.1
        DrawMarker(28, z.cx, z.cy, z.cz, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, s, s, s, r, g, b, a,
            false, false, 0, false, nil, nil, false)
    end
end
