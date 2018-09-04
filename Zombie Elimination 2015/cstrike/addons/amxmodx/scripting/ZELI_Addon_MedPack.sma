/*AMXPRO http://amxpro.do.am*/

#include <amxmodx>
#include <fakemeta_util>
#include <amxmisc>
#include <fun>
#include <fakemeta>
#include <cstrike>
#include <hamsandwich>
#include <Vexd_Utilities>
#include <zombie_eli>

#define PLUGIN "medkit"
#define VERSION "3.0"
#define AUTHOR "MaHu"

const Wep_c4 = ((1<<CSW_C4))
//icon
#define ICON_HIDE 0
#define ICON_SHOW 1
#define ICON_FLASH 2
//models/sound
#define V_MODEL "models/medkit/v_medkit.mdl"
#define P_MODEL "models/medkit/p_medkit.mdl"
//#define W_MODEL "models/medkit/w_medkit.mdl"
#define HEALING "medkit/healing.wav"

new  cvar_hp, cvar_cost,g_healspr,gmsgIcon,bool:g_HasMedkit[32]
new const  sprite_heal[] = "sprites/heal.spr"

new g_MedPack, g_Medic

public  plugin_init() {
	register_plugin(PLUGIN, VERSION, AUTHOR)
	//commands
	register_concmd("amx_medkit", "CmdGivemedkit", ADMIN_BAN, "<name>")
	//cvars
	cvar_hp = register_cvar("medkit_hp", "50")
	cvar_cost = register_cvar("medkit_cost","0")
	
	//RegisterHam(Ham_Spawn, "player", "fwHamPlayerSpawnPost", 1)

	//RegisterHam(Ham_Spawn, "player", "Spawn", 1)
	register_touch("medkit", "player", "touch_medkit")
	//register_event("DeathMsg", "Death", "a")
	register_event("CurWeapon","checkWeapon","be","1=1")
	//register_clcmd("drop","drop_medkit")
	gmsgIcon = get_user_msgid("StatusIcon")
	
	g_Medic = ZombieEli_GetClassID("Medic")
	g_MedPack = ZombieEli_RegisterWeapon(g_Medic, "Bonus Medical Pack", WPN_BONUS, 3, 0)
}

public plugin_precache( )
{
	precache_sound(HEALING)
	precache_model(V_MODEL)
	precache_model(P_MODEL)
	//precache_model(W_MODEL)
	precache_model("models/rpgrocket.mdl")
	g_healspr = engfunc(EngFunc_PrecacheModel, sprite_heal)
}

public zeli_weapon_selected(id, ItemID, ClassID)
{
	if(ItemID == g_MedPack) giveweapon(id)
}

public zeli_weapon_removed(id, ItemID)
{
	if(ItemID == g_MedPack) gaben(id)
}
public gaben(id)
{
	g_HasMedkit[id] = false
}

public giveweapon(id)
{
	give_item(id,"weapon_c4")
	g_HasMedkit[id] = true
	client_print(id, print_chat, "Sneaky.amxx is a god, we all know this.. dont we?")
	message_begin( MSG_ONE, gmsgIcon, {0,0,0}, id )
	write_byte( ICON_SHOW )
	write_string("plus")
	write_byte(222)
	write_byte(255)
	write_byte(0)
	message_end()
}


public touch_medkit(ent, id)
{
	if(!is_valid_ent(ent) || !is_user_alive(id)) 
		return PLUGIN_CONTINUE
	client_cmd(id, "spk items/ammopickup2")
	give_item(id,"weapon_c4");
	g_HasMedkit[id] = true;
	remove_entity(ent)
	message_begin( MSG_ONE, gmsgIcon, {0,0,0}, id )
	write_byte(ICON_SHOW)
	write_string("plus")
	write_byte(222)
	write_byte(255)
	write_byte(0)
	message_end()
	
	return PLUGIN_CONTINUE
}

public medkit(id){
	
	if(g_HasMedkit[id]){
	client_print(id,print_chat,"[MEDKIT 2.0] you already have medkit")
	return PLUGIN_HANDLED
}
	if(cs_get_user_money(id)< get_pcvar_num(cvar_cost)){
	client_print(id,print_chat,"[MEDKIT 2.0]you need $ %d to buy medkit",get_pcvar_num(cvar_cost))
	return PLUGIN_HANDLED
}
	else{
	cs_set_user_money(id,cs_get_user_money(id) - get_pcvar_num(cvar_cost))
	give_item(id,"weapon_c4")
	g_HasMedkit[id] = true
	client_print(id, print_chat, "[MEDKIT 2.0] you bought medkit")
	message_begin( MSG_ONE, gmsgIcon, {0,0,0}, id )
	write_byte( ICON_SHOW )
	write_string("plus")
	write_byte(222)
	write_byte(255)
	write_byte(0)
	message_end()

	return PLUGIN_HANDLED
	
	}
	//return PLUGIN_HANDLED
}

public client_PreThink(id)
{    
	new temp[2], weapon = get_user_weapon(id, temp[0], temp[1])
	if( get_user_button( id ) & IN_ATTACK  && weapon == CSW_C4 && g_HasMedkit[id]){
	if( get_user_oldbutton( id ) & IN_ATTACK )
{  
	g_HasMedkit[id] = false
	SetView(id, 1)
	set_user_maxspeed(id,1.0);
	static Float:originF[3]
	pev(id, pev_origin, originF)
	engfunc(EngFunc_MessageBegin, MSG_PVS, SVC_TEMPENTITY, originF, 0)
	write_byte(TE_SPRITE)
	engfunc(EngFunc_WriteCoord, originF[0]+random_float(-5.0, 5.0))
	engfunc(EngFunc_WriteCoord, originF[1]+random_float(-5.0, 5.0))
	engfunc(EngFunc_WriteCoord, originF[2]+random_float(-10.0, 10.0))
	write_short(g_healspr)
	write_byte(random_num(5, 10))
	write_byte(200)
	message_end()
	set_task(2.0,"heal",id)
	emit_sound(id, CHAN_ITEM, HEALING, VOL_NORM, ATTN_NORM, 0, PITCH_NORM)
}
}
}

//public drop_medkit(id)
//{
//	new temp[2], weapon = get_user_weapon(id, temp[0], temp[1])
//	if(!(weapon == CSW_C4 && g_HasMedkit[id]))
//	return PLUGIN_CONTINUE
//	else{
//	fm_strip_user_gun(id,0,"weapon_c4")
//	g_HasMedkit[id] = false
//	icon_hide(id)
//	new Float:fVelocity[3], Float:fOrigin[3]
//	entity_get_vector(id, EV_VEC_origin, fOrigin)
//	VelocityByAim(id, 34, fVelocity)
//	
//	fOrigin[0] += fVelocity[0]
//	fOrigin[1] += fVelocity[1]
//
//	VelocityByAim(id, 300, fVelocity)
//	
//	new ent = create_entity("info_target")
//	entity_set_string(ent, EV_SZ_classname, "medkit")
//	entity_set_model(ent, W_MODEL)
//	entity_set_int(ent, EV_INT_movetype, MOVETYPE_TOSS)
//	entity_set_int(ent, EV_INT_solid, SOLID_TRIGGER)
//	entity_set_vector(ent, EV_VEC_origin, fOrigin)
//	entity_set_vector(ent, EV_VEC_velocity, fVelocity)
//	entity_set_float(ent, EV_FL_nextthink, halflife_time() + 0.01)
//}//
//	return PLUGIN_HANDLED
//}

public CmdGivemedkit(id,level,cid)
{
	if (!cmd_access(id,level,cid,2))
		return PLUGIN_HANDLED;
	new arg[32];
	read_argv(1,arg,31);
	
	new player = cmd_target(id,arg,7)
	if (!player) 
		return PLUGIN_HANDLED;
	new name[32];
	get_user_name(player,name,31)
	g_HasMedkit[player] = true
	give_item(player, "weapon_c4")
	message_begin( MSG_ONE, gmsgIcon, {0,0,0}, player )
	write_byte(ICON_SHOW)
	write_string("plus")
	write_byte(222)
	write_byte(255)
	write_byte( 0 )
	message_end()
	
	return PLUGIN_HANDLED
}   

public client_connect(id)
{
	g_HasMedkit[id] = false
}

public client_disconnect(id)
{
	g_HasMedkit[id] = false
}

//public Death()
//{
//	new id = read_data(2)
//	g_HasMedkit[id] = false
//	g_HasMedkit[id] = false
//	icon_hide(id)
//	new Float:fVelocity[3], Float:fOrigin[3]
//	entity_get_vector(id, EV_VEC_origin, fOrigin)
//	VelocityByAim(id, 34, fVelocity)
//	
//	fOrigin[0] += fVelocity[0]
//	fOrigin[1] += fVelocity[1]
//
//	VelocityByAim(id, 300, fVelocity)
//	
//	new ent = create_entity("info_target")
//	entity_set_string(ent, EV_SZ_classname, "medkit")
//	entity_set_model(ent, W_MODEL)
//	entity_set_int(ent, EV_INT_movetype, MOVETYPE_TOSS)
//	entity_set_int(ent, EV_INT_solid, SOLID_TRIGGER)
//	entity_set_vector(ent, EV_VEC_origin, fOrigin)
//	entity_set_vector(ent, EV_VEC_velocity, fVelocity)
//	entity_set_float(ent, EV_FL_nextthink, halflife_time() + 0.01)
//}

public checkWeapon(id)
{
	
	new temp[2], weapon = get_user_weapon(id, temp[0], temp[1])
	if(weapon == CSW_C4 && g_HasMedkit[id]){
	entity_set_string(id, EV_SZ_viewmodel, V_MODEL)
	set_pev(id, pev_weaponmodel2, P_MODEL)
	message_begin( MSG_ONE, gmsgIcon, {0,0,0}, id)
	write_byte(ICON_FLASH)
	write_string("plus")
	write_byte(222)
	write_byte(255)
	write_byte( 0 )
	message_end()
	}
	
	if(!(weapon == CSW_C4) && g_HasMedkit[id]){
	message_begin( MSG_ONE, gmsgIcon, {0,0,0}, id)
	write_byte(ICON_SHOW)
	write_string("plus")
	write_byte(222)
	write_byte(255)
	write_byte( 0 )
	message_end()
}

}

public fwHamPlayerSpawnPost(id)
{
	g_HasMedkit[id] = false
}

public Spawn(id)
{
	if(is_user_alive(id))
	g_HasMedkit[id] = false
	return HAM_HANDLED
}

public heal(id){
	new hp = get_user_health(id)
	set_user_health(id, hp+ get_pcvar_num(cvar_hp))
	fm_strip_user_gun(id,0,"weapon_c4")
	set_user_maxspeed(id,250.0)
	SetView(id, 0)
	icon_hide(id)
}
public icon_hide(id){
	message_begin( MSG_ONE, gmsgIcon, {0,0,0}, id )
	write_byte(ICON_HIDE)
	write_string("plus")
	write_byte(222)
	write_byte(255)
	write_byte(0)
	message_end()
}
