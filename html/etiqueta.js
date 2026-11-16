/* vault-interact — la etiqueta flotante. Lua manda { tipo, datos }:
     etiqueta: { titulo, sub?, aviso?, cantidad?, precio?, teclas: [{ k, t }], x, y } o false
               o, con las interacciones: { opciones: [{ t, i?, c?, h? }], sel, tecla, ayuda?, x, y }
     pos:      { x, y } (0..1 de la pantalla), cada frame mientras se mira
     puntos:   [[x, y, cerca], ...] o false: los indicadores
     progreso: 0..1 mientras se mantiene la tecla, o false
     tema:     colores de Config.Tema
     idioma:   { numeros, precio }: cómo se escriben los precios (de locales/)
   Con ?demo (o ?demo=menu) se ve un ejemplo en un navegador normal. */
(function () {
  'use strict';
  const $ = (s, el) => (el || document).querySelector(s);
  const esc = (s) => String(s == null ? '' : s).replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
  const clase = (s) => String(s).replace(/[^a-z0-9\- ]/gi, '');
  const color = (s) => String(s).replace(/[^#a-z0-9(),.% ]/gi, '');
  const et = $('#etiqueta');
  const capa = $('#puntos');
  const pool = [];
  let x = 0.5, y = 0.5, vista = false;
  let idioma = { numeros: 'en-US', precio: '$%s' };

  function colocar() {
    et.style.transform = 'translate3d(' + (x * innerWidth) + 'px,' + (y * innerHeight) + 'px,0) translate(-6px,-15px)';
  }

  function teclas(d) {
    return (d.teclas || []).map((t) => '<span class="et-op"><kbd>' + esc(t.k) + '</kbd>' + esc(t.t) + '</span>').join('');
  }

  function opciones(d) {
    const sel = d.sel || 1;
    return d.opciones.map((o, i) => {
      const elegida = i + 1 === sel;
      const ico = o.i ? '<i class="et-ico ' + clase(o.i) + '"' + (o.c ? ' style="color:' + color(o.c) + '"' : '') + '></i>' : '';
      const marca = elegida ? '<kbd' + (o.h ? ' class="mant"' : '') + '>' + esc(d.tecla || 'E') + '</kbd>' : '<span class="et-marca"></span>';
      return '<span class="et-op' + (elegida ? ' sel' : '') + '">' + (elegida ? '<span class="et-barra"></span>' : '') +
        marca + ico + '<span class="et-txt">' + esc(o.t) + '</span></span>';
    }).join('');
  }

  function etiqueta(d) {
    if (!d) { et.classList.add('oculto'); vista = false; return; }
    const menu = Array.isArray(d.opciones);
    et.classList.toggle('menu', menu);
    $('.et-titulo', et).textContent = d.titulo || '';
    $('.et-cant', et).textContent = d.cantidad == null ? '' : (typeof d.cantidad === 'number' ? '×' + d.cantidad : d.cantidad);
    const pr = $('.et-precio', et), pil = $('.et-pildora', et);
    if (d.precio != null) {
      pr.textContent = typeof d.precio === 'number' ? String(idioma.precio).replace('%s', Math.round(d.precio).toLocaleString(idioma.numeros)) : d.precio;
      pr.classList.remove('oculto'); pil.classList.add('con-precio');
    } else { pr.classList.add('oculto'); pil.classList.remove('con-precio'); }
    pil.classList.toggle('oculto', !d.titulo && d.cantidad == null && d.precio == null);
    const sub = $('.et-sub', et);
    sub.textContent = d.sub || '';
    sub.classList.toggle('oculto', !d.sub);
    sub.classList.toggle('aviso', !!d.aviso);
    $('.et-teclas', et).innerHTML = menu ? opciones(d) : teclas(d);
    const ayuda = $('.et-ayuda', et);
    ayuda.textContent = d.ayuda || '';
    ayuda.classList.toggle('oculto', !d.ayuda);
    if (d.x != null) { x = d.x; y = d.y; colocar(); }
    if (!vista) { et.classList.remove('entra'); void et.offsetWidth; et.classList.add('entra'); }
    et.classList.remove('oculto');
    vista = true;
  }

  function progreso(p) {
    const op = $('.et-op.sel', et);
    if (!op) return;
    if (p === false || p == null) op.style.removeProperty('--p');
    else op.style.setProperty('--p', Math.max(0, Math.min(1, p)));
  }

  function puntos(lista) {
    lista = Array.isArray(lista) ? lista : [];
    while (pool.length < lista.length) {
      const s = document.createElement('span');
      s.className = 'ind';
      capa.appendChild(s);
      pool.push(s);
    }
    for (let i = 0; i < pool.length; i++) {
      const s = pool[i], p = lista[i];
      if (!p) { s.style.display = 'none'; continue; }
      s.style.display = '';
      s.style.transform = 'translate3d(' + (p[0] * innerWidth) + 'px,' + (p[1] * innerHeight) + 'px,0)';
      s.classList.toggle('cerca', p[2] === 1);
    }
  }

  const TEMA = { acento: '--acento', acentoPared: '--acento-pared', tinta: '--tinta', fondo: '--fondo', texto: '--texto', suave: '--suave', aviso: '--aviso' };
  const H = {
    etiqueta,
    progreso,
    puntos,
    pos(d) { x = d.x; y = d.y; colocar(); },
    idioma(d) { if (d) idioma = { numeros: d.numeros || 'en-US', precio: d.precio || '$%s' }; },
    tema(t) { Object.keys(TEMA).forEach((k) => { if (t && t[k]) document.documentElement.style.setProperty(TEMA[k], t[k]); }); },
  };
  window.addEventListener('message', (e) => { const m = e.data || {}; if (H[m.tipo]) H[m.tipo](m.datos); });

  const demo = new URLSearchParams(location.search).get('demo');
  if (demo !== null) {
    document.body.classList.add('demo');
    if (demo === 'menu') {
      const d = {
        opciones: [
          { t: 'Open shop', i: 'fa-solid fa-basket-shopping' },
          { t: 'Rob register', i: 'fa-solid fa-mask', c: '#ff8f8f', h: true },
          { t: 'Talk', i: 'fa-solid fa-comment' },
        ],
        sel: 2, tecla: 'E', ayuda: 'Wheel or ↑ ↓', x: 0.42, y: 0.42,
      };
      etiqueta(d);
      puntos([[0.62, 0.48, 1], [0.7, 0.55, 0], [0.25, 0.6, 0]]);
      let p = 0;
      setInterval(() => { p = p >= 1 ? 0 : p + 0.02; progreso(p); }, 40);
    } else {
      etiqueta({ titulo: 'Strawberry donut', cantidad: 4, precio: 3, teclas: [{ k: 'E', t: 'Take' }, { k: 'G', t: 'Put back' }, { k: 'Q', t: 'Inspect' }], x: 0.42, y: 0.42 });
    }
  }
})();
