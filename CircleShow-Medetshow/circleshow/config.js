const CONFIG = { url: 'https://YOUR_PROJECT.supabase.co', key: 'YOUR_PUBLISHABLE_KEY' };
const db = window.supabase.createClient(CONFIG.url, CONFIG.key);
async function rpc(name,args={}) { const {data,error}=await db.rpc(name,args); if(error) throw new Error(error.message); return data; }
const $ = id => document.getElementById(id);
