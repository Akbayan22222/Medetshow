const CONFIG = {
    url: 'https://srvdmrwjvzcohborknow.supabase.co',
    key: 'sb_publishable_-3TqdjX6n4FVoa-RL5k1ZQ_zcxwMrih'
};

const db = window.supabase.createClient(CONFIG.url, CONFIG.key);

async function rpc(name, args = {}) {
    const { data, error } = await db.rpc(name, args);
    if (error) throw new Error(error.message);
    return data;
}

const $ = id => document.getElementById(id);
