// KizzDev Saver — Cloudflare Worker (API + proxy unduhan). Tampilan ada di /public.
import * as mod from "scrapr";
const scrapr = mod.default || mod;

const CORS = { "Access-Control-Allow-Origin": "*", "Access-Control-Allow-Headers": "Content-Type,x-api-key", "Access-Control-Allow-Methods": "GET,POST,OPTIONS", "Access-Control-Expose-Headers": "Content-Length" };
const UA = "Mozilla/5.0 (Linux; Android 13) AppleWebKit/537.36 Chrome/124 Mobile Safari/537.36";
const J = (o, s = 200) => new Response(JSON.stringify(o), { status: s, headers: { "content-type": "application/json; charset=utf-8", ...CORS } });
const get = (p) => { const [a, b] = p.split("."); return scrapr && scrapr[a] && scrapr[a][b]; };
const timeout = (p, ms) => Promise.race([p, new Promise((_, r) => setTimeout(() => r(new Error("timeout " + ms / 1000 + "s")), ms))]);

const PLATFORMS = [
  { id: "tiktok",    name: "TikTok",      re: /(^|\.)tiktok\.com$/,                      s: ["tiktok.tiktokio", "tiktok.snaptik", "tiktok.ssstik"] },
  { id: "instagram", name: "Instagram",   re: /(^|\.)(instagram\.com|instagr\.am)$/,     s: ["instagram.downreels", "instagram.indown"] },
  { id: "twitter",   name: "X / Twitter", re: /(^|\.)(twitter|x)\.com$/,                 s: ["twitter.tvd", "twitter.tweeload"] },
  { id: "facebook",  name: "Facebook",    re: /(^|\.)(facebook\.com|fb\.watch|fb\.me)$/, s: ["facebook.snapsave"] },
  { id: "pinterest", name: "Pinterest",   re: /(^|\.)(pinterest\.[a-z.]+|pin\.it)$/,     s: ["pinterest.pindown"] },
  { id: "threads",   name: "Threads",     re: /(^|\.)threads\.(net|com)$/,               s: ["threads.threadster"] },
  { id: "bilibili",  name: "Bilibili",    re: /(^|\.)(bilibili\.com|b23\.tv)$/,          s: ["bilibili.snapwc"] },
  { id: "douyin",    name: "Douyin",      re: /(^|\.)douyin\.com$/,                      s: ["douyin.direct"] },
];

async function resolve(raw, forced) {
  let u; try { u = new URL(String(raw || "").trim()); } catch { u = null; }
  if (!u || !/^https?:$/.test(u.protocol)) return [400, { status: false, message: "Link tidak valid. Tempel link lengkap berawalan https://" }];
  const host = u.hostname.toLowerCase();
  const pf = forced ? PLATFORMS.find((p) => p.id === forced) : PLATFORMS.find((p) => p.re.test(host));
  if (!pf) return [400, { status: false, message: forced ? "Platform tidak dikenal" : "Platform belum didukung" }];
  if (forced && !pf.re.test(host)) return [400, { status: false, message: "Link bukan dari " + forced }];
  const tried = [];
  for (const name of pf.s) {
    const fn = get(name);
    if (!fn) { tried.push({ s: name, error: "scraper tidak termuat" }); continue; }
    try {
      const r = await timeout(fn(u.toString()), 25000);
      if (r && r.status && r.result) {
        let d = r.result.downloads || []; if (!Array.isArray(d)) d = [d];
        d = d.map((x) => (typeof x === "string" ? { url: x } : x)).filter((x) => x && x.url);
        if (d.length) return [200, { status: true, platform: pf.id, via: name, result: { ...r.result, downloads: d } }];
        tried.push({ s: name, error: "tidak ada link unduhan" });
      } else tried.push({ s: name, error: (r && r.message) || "gagal" });
    } catch (e) { tried.push({ s: name, error: String((e && e.message) || e).slice(0, 120) }); }
  }
  return [502, { status: false, message: "Semua scraper " + pf.name + " gagal. Coba lagi nanti atau pakai link lain.", tried }];
}

async function proxy(raw, name) {
  let u; try { u = new URL(String(raw || "")); } catch { return J({ status: false, message: "url tidak valid" }, 400); }
  if (!/^https?:$/.test(u.protocol)) return J({ status: false, message: "protokol tidak valid" }, 400);
  const r = await fetch(u, { headers: { "User-Agent": UA }, redirect: "follow" });
  if (!r.ok || !r.body) return J({ status: false, message: "sumber membalas " + r.status }, 502);
  const fn = String(name || "kizzdev").replace(/[^\w.\- ]+/g, "").slice(0, 80) || "kizzdev";
  const h = new Headers(CORS);
  h.set("Content-Type", r.headers.get("content-type") || "application/octet-stream");
  h.set("Content-Disposition", 'attachment; filename="' + fn + '"');
  const len = r.headers.get("content-length"); if (len) h.set("Content-Length", len);
  return new Response(r.body, { headers: h });
}

export default {
  async fetch(req, env) {
    const url = new URL(req.url);
    const path = url.pathname.replace(/\/$/, "");
    if (req.method === "OPTIONS") return new Response(null, { status: 204, headers: CORS });
    const KEY = (env && env.API_KEY) || "";
    const authed = !KEY || req.headers.get("x-api-key") === KEY || url.searchParams.get("apikey") === KEY;
    const body = async () => { try { return await req.json(); } catch { return {}; } };
    try {
      if (path === "/api/health") return J({ status: true, ok: true, loaded: Object.keys(scrapr || {}) });
      if (path === "/api/platforms") return J({ status: true, platforms: PLATFORMS.map(({ id, name }) => ({ id, name })) });
      if (path === "/api/resolve" && req.method === "POST") { const [c, b] = await resolve((await body()).url); return J(b, c); }
      if (path === "/api/proxy") return await proxy(url.searchParams.get("url"), url.searchParams.get("name"));
      if (path === "/api/download") {
        if (!authed) return J({ status: false, message: "API key salah/kosong" }, 401);
        const raw = req.method === "POST" ? (await body()).url : url.searchParams.get("url");
        const [c, b] = await resolve(raw); return J(b, c);
      }
      const m = path.match(/^\/api\/([a-z]+)$/);
      if (m) {
        if (!authed) return J({ status: false, message: "API key salah/kosong" }, 401);
        const [c, b] = await resolve(url.searchParams.get("url"), m[1]); return J(b, c);
      }
    } catch (e) { return J({ status: false, message: String((e && e.message) || e) }, 500); }
    return J({ status: false, message: "Endpoint tidak ditemukan" }, 404);
  },
};
