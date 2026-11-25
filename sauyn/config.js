const CONFIG={url:'https://srvdmrwjvzcohborknow.supabase.co',key:'YOUR_PUBLISHABLE_KEY'};
const db=window.supabase.createClient(CONFIG.url,CONFIG.key,{auth:{storageKey:'sauyn-host-auth'}});
const $=id=>document.getElementById(id);
async function rpc(name,args={}){const {data,error}=await db.rpc(name,args);if(error)throw Error(error.message);return data;}
