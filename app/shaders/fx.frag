#version 440
// The opening / closing effects of the launcher (FxLayer.qml, ⚙ > Effects). One shader for all twenty:
// `mode` picks one. The launcher is a frozen picture (`source`) that covers `rect` of the layer; every
// effect works backwards: for each pixel P of the layer it decides which point of the picture goes there
// (or nothing), so nothing needs a mesh. All lengths are in layer pixels, `unit` is the px scale
// (1 on a 1080 p screen; the small preview in the menu uses the same shader at a smaller scale).
// `p` is the effect's own progress: 0 hidden, 1 shown, and past 1 while a spring overshoots.
// Output is premultiplied alpha, like the texture.
//
// Build (needs qt6-shadertools):  shaders/build.sh

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float mode;    // 1 fluid, 2 bounce, 3 genie, 4 dissolve, 5 glitch, 6 matrix, 7 decrypt, 8 synthgrid, 9 spotlights, 10 laser, 11 blackhole, 12 fireworks, 13 rain, 14 beams, 15 vhs, 16 fade, 17 slide, 18 meet, 19 corners, 20 blocks
    float p;
    float unit;
    vec2 res;      // the layer's size
    vec4 rect;     // where the picture is (x, y, w, h)
    vec4 body;     // where the launcher itself is inside it (a docked panel has a gap on its edge)
    vec2 origin;   // where fluid / bounce / dissolve grow from
    vec2 gorigin;  // where genie is sucked into
    vec2 dir;      // genie's axis: unit vector from gorigin toward the launcher
    vec2 sdir;     // slide: unit vector toward the side it comes from; meet: (1, 0) halves from left and right, (0, 1) from top and bottom
} ubuf;

layout(binding = 1) uniform sampler2D source;

// the picture at layer point Q (nothing outside it)
vec4 tex(vec2 Q) {
    vec2 uv = (Q - ubuf.rect.xy) / ubuf.rect.zw;
    if (uv.x < 0.0 || uv.y < 0.0 || uv.x > 1.0 || uv.y > 1.0) return vec4(0.0);
    return textureLod(source, uv, 0.0);
}

float aa() { return max(ubuf.unit, 0.6); } // an edge is about one pixel wide however small the layer is

float hash(vec2 q) {
    q = fract(q * vec2(123.34, 456.21));
    q += dot(q, q + 45.32);
    return fract(q.x * q.y);
}
float vnoise(vec2 q) {
    vec2 i = floor(q), f = fract(q);
    f = f * f * (3.0 - 2.0 * f);
    return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}
float fbm(vec2 q) {
    float v = 0.0, a = 0.5;
    for (int i = 0; i < 4; i++) { v += a * vnoise(q); q *= 2.03; a *= 0.5; }
    return v;
}
float sdRound(vec2 q, vec2 half_, float r) {
    vec2 d = abs(q) - half_ + r;
    return length(max(d, 0.0)) + min(max(d.x, d.y), 0.0) - r;
}

// ---- fluid: grows out of a point like a drop of liquid, its depth lagging its width, surface rippling,
// the corners round while it is small and firm up as it settles; springs a little past its size (p > 1)
vec4 fluid(vec2 P) {
    float p = clamp(ubuf.p, 0.0, 1.6);
    vec2 O = ubuf.origin;
    vec2 ax = abs(ubuf.dir);
    float sl = 0.04 + 0.96 * pow(p, 0.8);
    float sd = 0.04 + 0.96 * pow(p, 1.45);
    vec2 s = ax.x > 0.5 ? vec2(sd, sl) : vec2(sl, sd);
    float u = ubuf.unit;
    float amp = clamp(4.0 * p * (1.0 - p), 0.0, 1.0) * 9.0 * u;
    vec2 Pw = P + vec2(sin(P.y / u * 0.045 + p * 13.0), sin(P.x / u * 0.045 + p * 9.0)) * amp;
    vec2 Q = O + (Pw - O) / s;
    vec2 c = O + (ubuf.body.xy + ubuf.body.zw * 0.5 - O) * s;
    vec2 h = ubuf.body.zw * 0.5 * s;
    float r = min(mix(min(h.x, h.y), 16.0 * u, smoothstep(0.0, 1.0, p)), min(h.x, h.y));
    float m = 1.0 - smoothstep(-aa(), aa(), sdRound(Pw - c, h, r));
    m = mix(m, 1.0, smoothstep(0.85, 1.0, p)); // settled: the launcher's own corners take over
    return tex(Q) * m * smoothstep(0.0, 0.25, p);
}

// ---- bounce: pops up from a point on a damped spring, stretched while it travels and squashed as it
// lands, with a slight tilt that straightens out
vec4 bounce(vec2 P) {
    float p = max(ubuf.p, 0.0);
    vec2 O = ubuf.origin;
    float sc = mix(0.55, 1.0, p);
    float k = sc - 1.0;
    vec2 s = vec2(sc * (1.0 + 0.5 * k), sc * (1.0 - 0.5 * k));
    float a = (1.0 - clamp(p, 0.0, 1.0)) * 0.07;
    mat2 R = mat2(cos(a), -sin(a), sin(a), cos(a));
    vec2 Q = O + (R * (P - O)) / s;
    return tex(Q) * smoothstep(0.0, 0.3, p);
}

// ---- genie: the launcher is poured out of the origin through a funnel that opens as it arrives
vec4 genie(vec2 P) {
    float p = clamp(ubuf.p, 0.0, 1.0);
    vec2 d = ubuf.dir;
    vec2 n = vec2(d.y, d.x);
    vec2 O = ubuf.gorigin;
    vec2 c = ubuf.body.xy + ubuf.body.zw * 0.5;
    float len = abs(d.x) * ubuf.body.z + abs(d.y) * ubuf.body.w;
    float hw = 0.5 * (abs(n.x) * ubuf.body.z + abs(n.y) * ubuf.body.w);
    float gap = dot(c - O, d) - len * 0.5;        // from the origin to the launcher's near side
    float across = dot(c - O, n);                 // the launcher's centre line, sideways from the origin
    vec2 r = P - O;
    float k = dot(r, d), b = dot(r, n);
    float nearK = gap * (1.0 - p);                // the near side travels in while it unfolds
    float lenNow = max(len * pow(p, 0.75), 0.001);
    float sa = (k - nearK) / lenNow;              // 0 at the near end of what is shown, 1 at the far end
    float x = clamp(sa / max(1.0 - p, 0.001), 0.0, 1.0);
    float f = x * x * (3.0 - 2.0 * x);            // 0 in the neck of the funnel, 1 once it has opened
    float w = mix(0.03, 1.0, f) * hw;
    float line = mix(0.0, across, f);
    float sb = (b - line) / max(w, 0.001);
    // an edge one pixel wide on the screen, whatever its slope: the distance is divided by how fast it changes per pixel
    float eAcross = w - abs(b - line);
    float eAlong = min(k - nearK, nearK + lenNow - k);
    float inAcross = clamp(eAcross / max(fwidth(eAcross), 1e-4) + 0.5, 0.0, 1.0);
    float inAlong = clamp(eAlong / max(fwidth(eAlong), 1e-4) + 0.5, 0.0, 1.0);
    vec2 Q = c + d * ((sa - 0.5) * len) + n * (sb * hw);
    float m = mix(inAcross * inAlong, 1.0, smoothstep(0.9, 1.0, p)); // settled: no soft edge left to jump from
    return tex(Q) * m * smoothstep(0.0, 0.15, p);
}

// ---- dissolve: burns in from the origin along a ragged front of noise; the edge glows
vec3 fire(float h) { // 0 ember .. 1 white-hot
    vec3 c = mix(vec3(0.45, 0.06, 0.02), vec3(1.0, 0.45, 0.06), smoothstep(0.0, 0.55, h));
    return mix(c, vec3(1.0, 0.92, 0.55), smoothstep(0.6, 1.0, h));
}
vec4 dissolve(vec2 P) {
    vec4 c = tex(P);
    if (c.a <= 0.0) return vec4(0.0);
    float p = clamp(ubuf.p, 0.0, 1.0);
    float u = ubuf.unit;
    float n = fbm(P / (85.0 * u) + p * 1.7) / 0.94;
    float g = distance(P, ubuf.origin) / (0.75 * length(ubuf.body.zw));
    float m = 0.55 * g + 0.45 * n;                       // when this pixel is reached, about 0 .. 1.1
    float w = 0.13;                                      // the width of the glowing edge
    float T = p * (1.1 + w + 0.02);
    if (m <= T) {
        float heat = clamp(1.0 - (T - m) / w, 0.0, 1.0);
        heat = heat * heat;
        vec3 col = mix(c.rgb, fire(heat) * c.a, clamp(heat * 1.15, 0.0, 0.94));
        return vec4(col, c.a);
    }
    float e = 1.0 - smoothstep(0.0, 0.045, m - T);       // a short lick of flame past the front
    return vec4(fire(1.0) * e * 0.85 * c.a, e * 0.85 * c.a);
}

// ---- glitch: tearing bands, split colour channels, dropped blocks and scanlines, calming down as it arrives.
// The noise is re-drawn 22 times over the run (a frame seed from p), so it flickers instead of sliding.
vec4 glitch(vec2 P) {
    float p = clamp(ubuf.p, 0.0, 1.0);
    float u = ubuf.unit;
    float f = floor(p * 22.0);
    float amt = 1.0 - p;
    float band = floor(P.y / (12.0 * u));
    float wide = floor(P.y / (64.0 * u));
    float shift = 0.0;
    if (hash(vec2(band, f)) > 1.0 - 0.5 * amt) shift += (hash(vec2(band, f + 3.0)) - 0.5) * 80.0 * u * amt;
    if (hash(vec2(wide, f + 7.0)) > 1.0 - 0.3 * amt) shift += (hash(vec2(f, wide)) - 0.5) * 240.0 * u * amt;
    float ca = (12.0 * amt * amt + abs(shift) * 0.1) * u;
    vec2 Q = P + vec2(shift, 0.0);
    vec4 cr = tex(Q + vec2(ca, 0.0)), cg = tex(Q), cb = tex(Q - vec2(ca, 0.0));
    vec4 c = vec4(cr.r, cg.g, cb.b, max(cg.a, max(cr.a, cb.a)));
    c.rgb *= mix(1.0, 0.86 + 0.14 * sin(P.y / u * 3.14159), amt);          // scanlines
    float flash = step(0.985, hash(vec2(floor(P.y / u), f))) * amt * 0.4;   // a bright line now and then
    c.rgb += vec3(flash) * c.a;
    float keep = step(amt * 0.95, hash(floor(P / (u * vec2(64.0, 22.0))) + f * 1.7)); // blocks that have not arrived
    return c * keep;
}

// ---- the terminal effects (the ones of Omarchy's screensaver, terminaltexteffects): the launcher is treated as a
// grid of terminal cells, 12 x 24 px at 1080 p, and a cell shows a made-up glyph (a 3 x 5 dot pattern) while it is
// being drawn. They play in place: none depends on where the launcher opened from.
vec2 cellSize() { return vec2(12.0, 24.0) * ubuf.unit; }
bool inBody(vec2 L) { return L.x >= 0.0 && L.y >= 0.0 && L.x <= ubuf.body.z && L.y <= ubuf.body.w; }

// a 3 x 5 dot glyph inside a cell (cuv 0..1 across it); which dots are on is decided by id and seed
float glyph(vec2 cuv, vec2 id, float seed) {
    vec2 g = floor(cuv * vec2(5.0, 7.0));
    if (g.x < 0.5 || g.x > 3.5 || g.y < 0.5 || g.y > 5.5) return 0.0;
    return step(0.48, hash(g + id * 13.7 + seed));
}

// ---- matrix: columns of falling glyphs, each with a bright head and a fading green trail; the launcher shows
// through wherever a trail has passed
vec4 matrix(vec2 P) {
    float p = clamp(ubuf.p, 0.0, 1.0);
    vec4 c = tex(P);
    vec2 L = P - ubuf.body.xy;
    if (!inBody(L)) return vec4(0.0);
    vec2 cell = cellSize();
    vec2 id = floor(L / cell);
    float hc = hash(vec2(id.x, 3.1));
    float delay = hc * 0.4;
    float lenN = 0.3 + 0.35 * hash(vec2(id.x, 7.7));           // the trail, in launcher heights
    float t = clamp((p - delay) / 0.6, 0.0, 1.0);
    float head = t * (1.0 + lenN);                             // the head, in launcher heights from the top
    float y = (id.y + 0.5) * cell.y / ubuf.body.w;
    float dist = head - y;                                     // how far behind the head this cell is
    if (dist < 0.0) return vec4(0.0);
    float a = 1.0 - clamp(dist / lenN, 0.0, 1.0);              // 1 at the head .. 0 at the end of the trail
    float g = glyph(fract(L / cell), id, floor(p * 30.0 + hc * 8.0) * 0.37);
    float lead = 1.0 - smoothstep(0.0, 1.6 * cell.y / ubuf.body.w, dist);
    vec3 col = mix(vec3(0.15, 1.0, 0.4) * (0.3 + 0.7 * a), vec3(0.85, 1.0, 0.9), lead);
    float ga = g * a;
    float reveal = smoothstep(0.0, lenN, dist);
    return vec4(col * ga, ga) + c * reveal * (1.0 - ga);
}

// ---- decrypt: every cell starts as scrambled glyphs, flickering, then resolves into the picture with a flash
vec4 decrypt(vec2 P) {
    float p = clamp(ubuf.p, 0.0, 1.0);
    vec4 c = tex(P);
    vec2 L = P - ubuf.body.xy;
    if (!inBody(L)) return vec4(0.0);
    vec2 cell = cellSize();
    vec2 id = floor(L / cell);
    float a0 = hash(id + 1.7) * 0.5;                            // starts scrambling
    float b0 = min(a0 + 0.22 + hash(id + 5.3) * 0.25, 0.93);    // resolves
    if (p < a0) return vec4(0.0);
    if (p >= b0) {
        float k = 1.0 - smoothstep(0.0, 0.07, p - b0);
        return c + vec4(vec3(0.7, 1.0, 0.92) * k * 0.5 * c.a, 0.0);
    }
    float g = glyph(fract(L / cell), id, floor(p * 36.0) * 0.61 + hash(id) * 10.0);
    vec3 col = mix(vec3(0.25, 0.55, 1.0), vec3(0.3, 1.0, 0.7), hash(id + 9.1));
    vec4 back = vec4(vec3(0.02, 0.05, 0.08) * 0.85, 0.85);
    return vec4(col * g, g) + back * (1.0 - g);
}

// ---- synthgrid: a neon grid grows from the middle, then its cells fill in with the picture in random order
// and the grid fades away
vec4 synthgrid(vec2 P) {
    float p = clamp(ubuf.p, 0.0, 1.0);
    float u = ubuf.unit;
    vec4 c = tex(P);
    vec2 L = P - ubuf.body.xy;
    if (!inBody(L)) return vec4(0.0);
    float cs = 30.0 * u;
    vec2 id = floor(L / cs);
    vec2 f = fract(L / cs);
    vec2 d = min(f, 1.0 - f) * cs;
    float line = min(d.x, d.y);
    float core = 1.0 - smoothstep(0.0, max(1.3 * u, 0.7), line);
    float glow = exp(-line / (5.0 * u + 0.5));
    float r = length(L - ubuf.body.zw * 0.5) / (0.5 * length(ubuf.body.zw));
    float reach = p * 2.6;
    float on = (1.0 - smoothstep(reach - 0.2, reach, r)) * (1.0 - smoothstep(0.75, 1.0, p));
    vec3 neon = mix(vec3(1.0, 0.25, 0.85), vec3(0.25, 0.9, 1.0), L.y / ubuf.body.w);
    float I = clamp(core + 0.45 * glow, 0.0, 1.0) * on;
    float start = 0.3 + hash(id + 2.3) * 0.5;
    float fill = smoothstep(start, start + 0.12, p);
    float flash = fill * (1.0 - fill) * 4.0;
    return vec4(neon * I, I) + (c * fill + vec4(neon * flash * 0.35 * c.a, 0.0)) * (1.0 - I);
}

// ---- spotlights: four lights search the launcher, lighting what they cross, then converge on the middle and grow
vec4 spotlights(vec2 P) {
    float p = clamp(ubuf.p, 0.0, 1.0);
    float u = ubuf.unit;
    vec4 c = tex(P);
    if (c.a <= 0.0) return vec4(0.0);
    vec2 B = ubuf.body.zw;
    vec2 L = P - ubuf.body.xy;
    float conv = smoothstep(0.4, 0.75, p);
    float grow = smoothstep(0.5, 1.0, p);
    float R = mix(0.2 * min(B.x, B.y), 0.75 * length(B), grow);
    float lit = 0.0, rim = 0.0;
    for (int i = 0; i < 4; i++) {
        float fi = float(i);
        vec2 path = vec2(0.5 + 0.36 * sin(6.2832 * (p * (0.8 + 0.15 * fi) + fi * 0.27)),
                         0.5 + 0.34 * cos(6.2832 * (p * (1.0 - 0.12 * fi) + fi * 0.41)));
        float dd = distance(L, mix(path, vec2(0.5), conv) * B);
        lit = max(lit, 1.0 - smoothstep(R * 0.8, R, dd));
        rim = max(rim, exp(-abs(dd - R * 0.9) / (8.0 * u + 0.5)));
    }
    lit *= smoothstep(0.0, 0.12, p);
    rim *= (1.0 - grow) * lit;
    vec3 warm = vec3(1.0, 0.96, 0.85);
    return c * lit + vec4(warm * (rim * 0.3 + 0.09 * lit * (1.0 - grow)) * c.a, 0.0); // the light itself, and a lit rim
}

// ---- laser: a laser etches the launcher row by row, back and forth, leaving it glowing hot and cooling; sparks fly
vec4 laser(vec2 P) {
    float p = clamp(ubuf.p, 0.0, 1.0);
    float u = ubuf.unit;
    vec4 c = tex(P);
    vec2 L = P - ubuf.body.xy;
    if (!inBody(L)) return vec4(0.0);
    float rowH = max(18.0 * u, ubuf.body.w / 24.0);
    float n = ceil(ubuf.body.w / rowH);
    float r = floor(L.y / rowH);
    float fx = L.x / ubuf.body.z;
    float e = r + (mod(r, 2.0) < 0.5 ? fx : 1.0 - fx);          // when the laser gets here, in rows
    float s = p * (n + 3.5);
    float age = s - e;
    vec4 out_ = vec4(0.0);
    if (age >= 0.0) {
        float heat = exp(-age * 2.4) * (1.0 - smoothstep(0.9, 1.0, p));
        vec3 hot = mix(vec3(0.2, 0.75, 1.0), vec3(0.9, 1.0, 1.0), heat * heat);
        out_ = c + vec4(hot * heat * 0.7 * c.a, 0.0);
    }
    float k = floor(s);
    if (k < n && p < 0.98) {
        float fh = fract(s);
        vec2 head = ubuf.body.xy + vec2((mod(k, 2.0) < 0.5 ? fh : 1.0 - fh) * ubuf.body.z, (k + 0.5) * rowH);
        float dh = distance(P, head);
        float g = exp(-dh / (7.0 * u + 0.5)) + 0.35 * exp(-dh / (34.0 * u + 1.0));
        float fr = floor(p * 90.0);
        for (int i = 0; i < 7; i++) {
            vec2 o = (vec2(hash(vec2(float(i), fr)), hash(vec2(fr, float(i) + 9.0))) - vec2(0.5, 0.9)) * vec2(64.0, 46.0) * u;
            g += 1.0 - smoothstep(0.0, 2.2 * u + 0.5, distance(P, head + o));
        }
        vec3 lc = mix(vec3(0.3, 0.9, 1.0), vec3(1.0), clamp(g - 0.4, 0.0, 1.0));
        out_ += vec4(lc * g, clamp(g, 0.0, 1.0));
    }
    return out_;
}

// ---- blackhole: a black hole opens in the middle; the launcher bursts out of it, spiralling outwards in blocks
// that settle into place, the middle first
vec4 blackhole(vec2 P) {
    float p = clamp(ubuf.p, 0.0, 1.0);
    float u = ubuf.unit;
    vec2 B = ubuf.body.zw;
    vec2 C = ubuf.body.xy + B * 0.5;
    vec2 d = P - C;
    float rn = length(d) / (0.5 * length(B));
    float tt = clamp((p - 0.15 - 0.45 * rn) / 0.4, 0.0, 1.0);          // how far out of the hole this radius is
    float S = 0.03 + 0.97 * (1.0 - pow(1.0 - tt, 3.0));
    float a = (1.0 - tt) * 5.0 * (1.0 - 0.3 * min(rn, 1.0));
    mat2 R = mat2(cos(a), sin(a), -sin(a), cos(a));
    vec2 Q = C + R * d / S;
    vec2 cs = cellSize();
    vec2 Qq = ubuf.body.xy + (floor((Q - ubuf.body.xy) / cs) + 0.5) * cs;   // blocks while it flies
    vec4 c = tex(mix(Qq, Q, smoothstep(0.55, 0.95, tt)));
    float rh = min(B.x, B.y) * 0.075 * sin(3.14159 * clamp(p / 0.7, 0.0, 1.0));
    float dh = length(d);
    float disc = 1.0 - smoothstep(rh - aa(), rh + aa(), dh);
    float ring = exp(-abs(dh - rh * 1.3) / (5.0 * u + 0.5)) * clamp(rh / (0.03 * min(B.x, B.y)), 0.0, 1.0);
    vec3 rc = mix(vec3(1.0, 0.45, 0.1), vec3(0.6, 0.3, 1.0), 0.5 + 0.5 * sin(atan(d.y, d.x) * 3.0 + p * 30.0));
    vec4 lit = c + vec4(rc * ring * 0.9, ring * 0.8) * (1.0 - c.a);
    return vec4(0.0, 0.0, 0.02, 1.0) * disc + lit * (1.0 - disc);
}

// ---- fireworks: rockets climb to five bursts; each burst sprays sparks and lights up the cells around it, which
// drop into place; whatever the bursts did not reach lands at the end
vec4 fireworks(vec2 P) {
    float p = clamp(ubuf.p, 0.0, 1.0);
    float u = ubuf.unit;
    vec2 B = ubuf.body.zw;
    vec2 L = P - ubuf.body.xy;
    if (!inBody(L)) return vec4(0.0);
    vec2 cell = cellSize();
    vec2 id = floor(L / cell);
    vec2 cc = ubuf.body.xy + (id + 0.5) * cell;
    float diag = length(B);
    float arrival = 0.82 + 0.06 * hash(id + 4.4);
    vec3 warm = vec3(1.0, 0.8, 0.3);
    vec4 spark = vec4(0.0);
    for (int k = 0; k < 5; k++) {
        float fk = float(k);
        vec2 b = ubuf.body.xy + vec2(0.12 + 0.76 * hash(vec2(fk, 1.7)), 0.18 + 0.4 * hash(vec2(fk, 4.1))) * B;
        float tk = 0.14 + 0.11 * fk + 0.03 * hash(vec2(fk, 9.9));
        arrival = min(arrival, tk + distance(cc, b) / (0.55 * diag) * 0.42);
        vec3 col = mix(warm, mix(vec3(1.0, 0.3, 0.7), vec3(0.3, 0.8, 1.0), hash(vec2(fk, 5.5))), step(0.35, hash(vec2(fk, 2.2))));
        float lu = (p - (tk - 0.13)) / 0.13;                                  // the rocket
        if (lu > 0.0 && lu < 1.0) {
            vec2 start = vec2(b.x + (hash(vec2(fk, 6.6)) - 0.5) * 0.1 * B.x, ubuf.body.y + B.y);
            for (int j = 0; j < 4; j++) {
                float tj = lu - float(j) * 0.07;
                if (tj > 0.0) {
                    float g = exp(-distance(P, mix(start, b, tj * (2.0 - tj))) / (3.5 * u + 0.6)) * (1.0 - float(j) * 0.22);
                    spark += vec4(mix(vec3(1.0), warm, float(j) * 0.3) * g, g);
                }
            }
        }
        float age = p - tk;                                                   // the sparks
        if (age > 0.0 && age < 0.3) {
            float fade = 1.0 - age / 0.3;
            for (int j = 0; j < 14; j++) {
                float fj = float(j);
                float ang = 6.2832 * (fj + hash(vec2(fk, fj)) * 0.6) / 14.0;
                float sp = (0.7 + 0.6 * hash(vec2(fj, fk + 3.0))) * 0.3 * diag * pow(age / 0.3, 0.6);
                vec2 pos = b + vec2(cos(ang), sin(ang)) * sp + vec2(0.0, 1.2 * B.y * age * age);
                float g = exp(-distance(P, pos) / (3.6 * u + 0.6)) * fade;
                spark += vec4(col * g, g);
            }
        }
    }
    float settle = clamp((p - arrival) / 0.18, 0.0, 1.0);
    vec4 c = tex(P + vec2(0.0, (1.0 - settle) * (1.0 - settle) * 60.0 * u)) * step(arrival, p);
    float k = 1.0 - smoothstep(0.0, 0.035, p - arrival);                // a thin bright ring where the wave lands
    c += vec4(warm * k * 0.3 * c.a, 0.0);
    return c + min(spark, vec4(1.0)) * (1.0 - c.a * 0.5);
}

// ---- rain: every cell falls from the top as a thin streak and lands in its place with a splash
vec4 rain(vec2 P) {
    float p = clamp(ubuf.p, 0.0, 1.0);
    float u = ubuf.unit;
    vec2 B = ubuf.body.zw;
    vec4 c = tex(P);
    vec2 L = P - ubuf.body.xy;
    if (!inBody(L)) return vec4(0.0);
    vec2 cell = cellSize();
    vec2 id = floor(L / cell);
    float land = 0.5 * hash(id + 2.1) + 0.15 + 0.25 * (id.y + 0.5) * cell.y / B.y;
    vec4 base = vec4(0.0);
    if (p >= land) {
        float k = 1.0 - smoothstep(0.0, 0.07, p - land);
        base = c + vec4(vec3(0.6, 0.85, 1.0) * k * 0.5 * c.a, 0.0);
    }
    float rows = ceil(B.y / cell.y);
    float lane = abs(fract(L.x / cell.x) - 0.5) * cell.x;
    float lit = 0.0;
    if (lane < 1.3 * u + 0.5) {
        for (int r = 0; r < 64; r++) {
            if (float(r) >= rows) break;
            float home = (float(r) + 0.5) * cell.y;
            float s = 0.5 * hash(vec2(id.x, float(r)) + 2.1);
            float f = clamp((p - s) / (0.15 + 0.25 * home / B.y), 0.0, 1.0);
            if (f > 0.0 && f < 1.0) {
                float dy = L.y - home * f * f;                                // below (+) or above (-) the head
                float tail = 3.0 * cell.y;
                if (dy <= 0.0 && dy > -tail) lit = max(lit, 1.0 + dy / tail);
                if (abs(dy) < 2.0 * u + 0.5) lit = 1.5;
            }
        }
    }
    vec3 rc = mix(vec3(0.3, 0.6, 1.0), vec3(0.85, 0.95, 1.0), clamp(lit - 1.0, 0.0, 1.0));
    float la = min(lit, 1.0) * 0.9;
    return base + vec4(rc * la, la) * (1.0 - base.a);
}

// ---- beams: a light runs along every row and every column of the grid; a cell shows once either has passed it
vec4 beams(vec2 P) {
    float p = clamp(ubuf.p, 0.0, 1.0);
    float u = ubuf.unit;
    vec2 B = ubuf.body.zw;
    vec4 c = tex(P);
    vec2 L = P - ubuf.body.xy;
    if (!inBody(L)) return vec4(0.0);
    vec2 cell = cellSize();
    vec2 id = floor(L / cell);
    float dr = 0.4 * hash(vec2(id.y, 8.8));
    float rdir = mod(id.y, 2.0) < 0.5 ? 1.0 : -1.0;
    float dc = 0.4 * hash(vec2(id.x, 5.5));
    float fxc = (id.x + 0.5) * cell.x / B.x;
    float fyc = (id.y + 0.5) * cell.y / B.y;
    float arrival = min(dr + 0.45 * (rdir > 0.0 ? fxc : 1.0 - fxc), dc + 0.45 * fyc);
    vec4 out_ = vec4(0.0);
    if (p >= arrival) {
        float heat = exp(-(p - arrival) * 14.0) * (1.0 - smoothstep(0.9, 1.0, p));
        out_ = c + vec4(vec3(0.5, 0.9, 1.0) * heat * 0.6 * c.a, 0.0);
    }
    float g = 0.0;
    float hr = (p - dr) / 0.45;                                                // the row's beam
    if (hr > 0.0 && hr < 1.0 && abs(fract(L.y / cell.y) - 0.5) * cell.y < 1.5 * u + 0.5)
        g += exp(-abs(L.x - (rdir > 0.0 ? hr : 1.0 - hr) * B.x) / (3.0 * u + 0.5));
    float hc = (p - dc) / 0.45;                                                // the column's beam
    if (hc > 0.0 && hc < 1.0 && abs(fract(L.x / cell.x) - 0.5) * cell.x < 1.5 * u + 0.5)
        g += exp(-abs(L.y - hc * B.y) / (3.0 * u + 0.5));
    g = min(g, 1.0);
    return out_ + vec4(mix(vec3(0.4, 0.85, 1.0), vec3(1.0), g * g) * g, g) * (1.0 - out_.a * 0.4);
}

// ---- vhs: an old tape settling: lines wobble and tear sideways, a tracking band rolls up the picture, colours
// bleed, detail smears and snow crackles in the band
vec4 vhs(vec2 P) {
    float p = clamp(ubuf.p, 0.0, 1.0);
    float u = max(ubuf.unit, 0.5);
    float amt = pow(1.0 - p, 1.4);
    vec2 L = P - ubuf.body.xy;
    float y = L.y / ubuf.body.w;
    float ln = floor(P.y / (2.0 * u));
    float fr = floor(p * 24.0);
    float wob = (vnoise(vec2(ln * 0.05, fr * 0.7)) - 0.5) * 60.0 * u * amt;
    float jit = (hash(vec2(ln, fr + 3.0)) - 0.5) * 50.0 * u * step(0.92, hash(vec2(floor(ln / 5.0), fr))) * amt;
    float band = exp(-abs(y - fract(1.2 - p * 1.7)) * 14.0);
    float bandShift = band * (hash(vec2(ln, fr)) - 0.3) * 120.0 * u * amt;
    float head = smoothstep(0.92, 1.0, y) * (10.0 + 40.0 * hash(vec2(ln, fr + 1.0))) * u * amt;
    float dx = wob + jit + bandShift + head;
    float blur = (2.0 + (10.0 + 10.0 * band) * amt) * u;
    vec4 acc = vec4(0.0);
    for (int i = -2; i <= 2; i++) acc += tex(P + vec2(dx + float(i) * blur, 0.0));
    acc /= 5.0;
    float ca = (4.0 + 14.0 * amt) * u;
    vec4 c = vec4(mix(acc.r, tex(P + vec2(dx + ca, 0.0)).r, 0.7), acc.g, mix(acc.b, tex(P + vec2(dx - ca, 0.0)).b, 0.7), acc.a);
    c.rgb = mix(c.rgb, vec3(dot(c.rgb, vec3(0.3, 0.59, 0.11))), 0.55 * amt);
    c.rgb *= mix(1.0, 0.88 + 0.12 * sin(P.y / u * 3.14159), amt);
    float sn = hash(floor(P / (1.5 * u)) + fr * 7.3);
    c.rgb = max(c.rgb + vec3(sn - 0.5) * (0.25 + 0.6 * band) * amt * c.a, 0.0);
    return c * smoothstep(0.0, 0.2, p);
}

// ---- the basic ones, which used to be the full-screen styles: fade, slide, meet, corners, blocks -- now in every mode

// fade: the launcher comes up out of nothing with a slight zoom
vec4 fade(vec2 P) {
    float p = clamp(ubuf.p, 0.0, 1.0);
    vec2 C = ubuf.body.xy + ubuf.body.zw * 0.5;
    return tex(C + (P - C) / (0.96 + 0.04 * p)) * p;
}

// slide: in from the side sdir points to, from beyond the edge of the screen
vec4 slide(vec2 P) {
    float p = clamp(ubuf.p, 0.0, 1.0);
    vec2 d = ubuf.sdir;
    float dist = d.x > 0.5 ? ubuf.res.x - ubuf.body.x
               : (d.x < -0.5 ? ubuf.body.x + ubuf.body.z
               : (d.y > 0.5 ? ubuf.res.y - ubuf.body.y : ubuf.body.y + ubuf.body.w));
    return tex(P - d * (1.0 - p) * dist);
}

// meet: two halves come in from opposite sides and join in the middle
vec4 meet(vec2 P) {
    float p = clamp(ubuf.p, 0.0, 1.0);
    float k = 1.0 - p;
    vec2 O = ubuf.body.xy, B = ubuf.body.zw;
    if (abs(ubuf.sdir.x) > 0.5) {
        float h = B.x * 0.5;
        float qa = P.x + k * h;
        if (qa >= O.x && qa <= O.x + h) return tex(vec2(qa, P.y));
        float qb = P.x - k * h;
        if (qb > O.x + h && qb <= O.x + B.x) return tex(vec2(qb, P.y));
        return vec4(0.0);
    }
    float h = B.y * 0.5;
    float qa = P.y + k * h;
    if (qa >= O.y && qa <= O.y + h) return tex(vec2(P.x, qa));
    float qb = P.y - k * h;
    if (qb > O.y + h && qb <= O.y + B.y) return tex(vec2(P.x, qb));
    return vec4(0.0);
}

// corners: four quadrants come in diagonally from the corners
vec4 corners(vec2 P) {
    float k = 1.0 - clamp(ubuf.p, 0.0, 1.0);
    vec2 O = ubuf.body.xy, h = ubuf.body.zw * 0.5;
    for (int i = 0; i < 4; i++) {
        vec2 sgn = vec2(mod(float(i), 2.0) < 0.5 ? -1.0 : 1.0, i < 2 ? -1.0 : 1.0);
        vec2 home = O + vec2(sgn.x < 0.0 ? 0.0 : h.x, sgn.y < 0.0 ? 0.0 : h.y);
        vec2 Q = P - sgn * k * h;
        if (Q.x >= home.x && Q.y >= home.y && Q.x < home.x + h.x && Q.y < home.y + h.y) return tex(Q);
    }
    return vec4(0.0);
}

// blocks: a 6 x 4 grid of blocks pops in, the bottom row first; a block drops a little and grows as it arrives
vec4 blocks(vec2 P) {
    float p = clamp(ubuf.p, 0.0, 1.0);
    vec2 O = ubuf.body.xy;
    vec2 bs = ubuf.body.zw / vec2(6.0, 4.0);
    vec2 L = P - O;
    for (int j = 0; j < 2; j++) {                    // this cell, and the one above (a block sits a little low while it arrives)
        vec2 id = floor(L / bs) - vec2(0.0, float(j));
        if (id.x < 0.0 || id.y < 0.0 || id.x > 5.0 || id.y > 3.0) continue;
        float order = (3.0 - id.y) * 6.0 + id.x;
        float t = clamp((p - order / 24.0 * 0.7) / (0.3 + 0.7 / 24.0), 0.0, 1.0);
        float e = t * t * (3.0 - 2.0 * t);
        vec2 cc = O + (id + 0.5) * bs;
        vec2 Q = cc + (P - cc - vec2(0.0, (1.0 - e) * bs.y * 0.2)) / (0.7 + 0.3 * e);
        vec2 q = Q - (O + id * bs);
        if (q.x >= 0.0 && q.y >= 0.0 && q.x < bs.x && q.y < bs.y) return tex(Q) * e;
    }
    return vec4(0.0);
}

void main() {
    vec2 P = qt_TexCoord0 * ubuf.res;
    int m = int(ubuf.mode + 0.5);
    vec4 c = vec4(0.0);
    if (m == 1) c = fluid(P);
    else if (m == 2) c = bounce(P);
    else if (m == 3) c = genie(P);
    else if (m == 4) c = dissolve(P);
    else if (m == 5) c = glitch(P);
    else if (m == 6) c = matrix(P);
    else if (m == 7) c = decrypt(P);
    else if (m == 8) c = synthgrid(P);
    else if (m == 9) c = spotlights(P);
    else if (m == 10) c = laser(P);
    else if (m == 11) c = blackhole(P);
    else if (m == 12) c = fireworks(P);
    else if (m == 13) c = rain(P);
    else if (m == 14) c = beams(P);
    else if (m == 15) c = vhs(P);
    else if (m == 16) c = fade(P);
    else if (m == 17) c = slide(P);
    else if (m == 18) c = meet(P);
    else if (m == 19) c = corners(P);
    else if (m == 20) c = blocks(P);
    fragColor = c * smoothstep(0.0, 0.015, ubuf.p) * ubuf.qt_Opacity;
}
