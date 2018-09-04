#include <amxmodx>
#include <engine>
#include <fakemeta>
#include <fakemeta_util>
#include <hamsandwich>
#include <cstrike>
#include <fun>
#include <zombie_eli>

#define PLUGIN "Janus 1"
#define VERSION "1.0"
#define AUTHOR "m4m3ts"

#define CSW_JANUS1 CSW_FIVESEVEN
#define weapon_janus1 "weapon_fiveseven"
#define model_lama "models/w_fiveseven.mdl"
#define RAHASIA 41546

#define AMMO 5
#define RELOAD_TIME 3.0
#define TIME_STAB 1.5
#define ATTACK_TIME 3.0
#define SHOOT_TIME 0.5
#define SHOOT_B_TIME 0.4
#define DAMAGE 190.0
#define NAMACLASSNYA "janus1"

const PDATA_SAFE = 2
const OFFSET_LINUX_WEAPONS = 4
const OFFSET_WEAPONOWNER = 41
const m_flNextAttack = 83
const m_szAnimExtention = 492

new const v_model[] = "models/v_janus1.mdl"
new const p_model[] = "models/p_janus1.mdl"
//new const w_model[] = "models/w_janus1.mdl"
new const GRENADE_MODEL[] = "models/grenade.mdl"
new const GRENADE_EXPLOSION[] = "sprites/fexplo.spr"
new cvar_dmg_janus1, cvar_ammo_janus1

new const weapon_sound[7][] = 
{
	"weapons/janus1-1.wav",
	"weapons/janus1-2.wav",
	"weapons/janus1_exp.wav",
	"weapons/janus1_draw.wav",
	"weapons/janus1_change1.wav",
	"weapons/janus1_change2.wav",
	"weapons/m79_draw.wav"
}


new const WeaponResource[4][] = 
{
	"sprites/weapon_janus1.txt",
	"sprites/640hud7.spr",
	"sprites/640hud12.spr",
	"sprites/640hud100.spr"
}

enum
{
	ANIM_IDLE = 0,
	ANIM_DRAW_NORMAL,
	ANIM_SHOOT_NORMAL,
	ANIM_SHOOT_ABIS,
	ANIM_SHOOT_SIGNAL,
	ANIM_CHANGE_1,
	ANIM_IDLE_B,
	ANIM_DRAW_B,
	ANIM_SHOOT_B,
	ANIM_SHOOT_B2,
	ANIM_CHANGE_2,
	ANIM_SIGNAL,
	ANIM_DRAW_SIGNAL,
	ANIM_SHOOT2_SIGNAL
}

new sExplo

new g_had_janus1[33], g_janus_ammo[33], shoot_mode[33], hit_janus1[33], hit_on[33]
new g_old_weapon[33]
new sTrail, g_MaxPlayers

new g_Janus11, g_Wukong
new g_Janus12, g_Medic
new g_Janus13, g_Engineer
new g_Janus14, g_Heavy
new g_Janus15, g_FrozenTech
new g_Janus16, g_PyroTech

const SECONDARY_WEAPONS_BIT_SUM = (1<<CSW_P228)|(1<<CSW_ELITE)|(1<<CSW_FIVESEVEN)|(1<<CSW_USP)|(1<<CSW_GLOCK18)|(1<<CSW_DEAGLE)

public plugin_init()
{
	register_plugin(PLUGIN, VERSION, AUTHOR)
	register_cvar("janus1_version", "m4m3ts", FCVAR_SERVER|FCVAR_SPONLY)
	register_forward(FM_CmdStart, "fw_CmdStart")
	register_forward(FM_SetModel, "fw_SetModel")
	register_forward(FM_UpdateClientData, "fw_UpdateClientData_Post", 1)
	register_message(get_user_msgid("DeathMsg"), "message_DeathMsg")
	register_think(NAMACLASSNYA, "fw_Think")
	register_touch(NAMACLASSNYA, "*", "fw_touch")
	RegisterHam(Ham_Spawn, "player", "Player_Spawn", 1)
	RegisterHam(Ham_Killed, "player", "fw_PlayerKilled")
	RegisterHam(Ham_Item_AddToPlayer, weapon_janus1, "fw_AddToPlayer_Post", 1)
	RegisterHam(Ham_Weapon_WeaponIdle, weapon_janus1, "fw_janusidleanim", 1)
	register_event("CurWeapon", "Event_CurWeapon", "be", "1=1")
	g_MaxPlayers = get_maxplayers()
	register_clcmd("weapon_janus1", "hook_weapon")
	
	//item_janus1 = zp_register_extra_item("Janus-1", 14, ZP_TEAM_HUMAN)
	
	cvar_dmg_janus1 = register_cvar("ze_janus1_dmg", "190.0")
	cvar_ammo_janus1 = register_cvar("ze_janus1_ammo", "10")
	
	  /////////////////////////////////////////////
	 // Register Weapon for Frozen Tech Class //
	/////////////////////////////////////////////
	g_FrozenTech = ZombieEli_GetClassID("Frozen Tech")
	g_Janus11 = ZombieEli_RegisterWeapon(g_FrozenTech, "CSO Janus-1", WPN_SECONDARY, 0, 0)
	
	  /////////////////////////////////////////////
	 //  Register Weapon for Pyro Tech Class  //
	/////////////////////////////////////////////	
	g_PyroTech = ZombieEli_GetClassID("Pyro Tech")
	g_Janus12 = ZombieEli_RegisterWeapon(g_PyroTech, "CSO Janus-1", WPN_SECONDARY, 0, 0)	

	  /////////////////////////////////////////////
	 //    Register Weapon for Medic Class    //
	/////////////////////////////////////////////	
	g_Medic = ZombieEli_GetClassID("Medic")
	g_Janus13 = ZombieEli_RegisterWeapon(g_Medic, "CSO Janus-1", WPN_SECONDARY, 0, 0)	

	  /////////////////////////////////////////////
	 //    Register Weapon for Heavy Class    //
	/////////////////////////////////////////////	
	g_Heavy = ZombieEli_GetClassID("Heavy")
	g_Janus14 = ZombieEli_RegisterWeapon(g_Heavy, "CSO Janus-1", WPN_SECONDARY, 0, 0)	
	
	  /////////////////////////////////////////////
	 //  Register Weapon for Engineer Class   //
	/////////////////////////////////////////////	
	g_Engineer = ZombieEli_GetClassID("Engineer")
	g_Janus15 = ZombieEli_RegisterWeapon(g_Engineer, "CSO Janus-1", WPN_SECONDARY, 0, 0)	
	
	  /////////////////////////////////////////////
	 //   Register Weapon for Wukong Class    //
	/////////////////////////////////////////////	
	g_Wukong = ZombieEli_GetClassID("Sun Wukong")
	g_Janus16 = ZombieEli_RegisterWeapon(g_Wukong, "CSO Janus-1", WPN_SECONDARY, 0, 0)	
}

public plugin_precache()
{
	precache_model(v_model)
	precache_model(p_model)
	//precache_model(w_model)
	precache_model(GRENADE_MODEL)
	sExplo = precache_model(GRENADE_EXPLOSION)
	
	for(new i = 0; i < sizeof(weapon_sound); i++) 
		precache_sound(weapon_sound[i])
	
	precache_generic(WeaponResource[0])
	for(new i = 1; i < sizeof(WeaponResource); i++)
		precache_model(WeaponResource[i])
	
	sTrail = precache_model("sprites/laserbeam.spr")
}

public zeli_weapon_selected(id, ItemID, ClassID)
{
	if(ItemID == g_Janus11) get_janus1(id)
	if(ItemID == g_Janus12) get_janus1(id)
	if(ItemID == g_Janus13) get_janus1(id)
	if(ItemID == g_Janus14) get_janus1(id)
	if(ItemID == g_Janus15) get_janus1(id)
	if(ItemID == g_Janus16) get_janus1(id)
}

public zeli_weapon_removed(id, ItemID)
{
	if(ItemID == g_Janus11) remove_janus(id)
	if(ItemID == g_Janus12) remove_janus(id)
	if(ItemID == g_Janus13) remove_janus(id)
	if(ItemID == g_Janus14) remove_janus(id)
	if(ItemID == g_Janus15) remove_janus(id)
	if(ItemID == g_Janus16) remove_janus(id)
}


//public zp_user_infected_post(id)
//{
//	remove_janus(id)
//}

public Player_Spawn(id)
{
	remove_janus(id)
}

public fw_PlayerKilled(id)
{
	remove_janus(id)
}

public hook_weapon(id)
{
	engclient_cmd(id, weapon_janus1)
	return
}

//public zp_extra_item_selected(id, itemid)
//{
//	if(itemid == item_janus1) get_janus1(id)
//}

public get_janus1(id)
{
	if(!is_user_alive(id))
		return
	drop_weapons(id, 1)
	g_had_janus1[id] = 1
	g_janus_ammo[id] = get_pcvar_num(cvar_ammo_janus1)
	shoot_mode[id] = 1
	hit_janus1[id] = 0
	hit_on[id] = 0
	
	give_item(id, weapon_janus1)
	if(get_user_weapon(id) == CSW_JANUS1 && g_had_janus1[id]) peluru_hud(id)
	
	static weapon_ent; weapon_ent = fm_find_ent_by_owner(-1, weapon_janus1, id)
	if(pev_valid(weapon_ent)) cs_set_weapon_ammo(weapon_ent, 1)
}

public remove_janus(id)
{
	g_had_janus1[id] = 0
	g_janus_ammo[id] = 0
}
	
public fw_UpdateClientData_Post(id, sendweapons, cd_handle)
{
	if(!is_user_alive(id) || !is_user_connected(id))
		return FMRES_IGNORED	
	if(get_user_weapon(id) == CSW_JANUS1 && g_had_janus1[id])
		set_cd(cd_handle, CD_flNextAttack, get_gametime() + 0.001) 
	
	return FMRES_HANDLED
}

public message_DeathMsg(msg_id, msg_dest, id)
{
	static szTruncatedWeapon[33], iAttacker, iVictim
        
	get_msg_arg_string(4, szTruncatedWeapon, charsmax(szTruncatedWeapon))
        
	iAttacker = get_msg_arg_int(1)
	iVictim = get_msg_arg_int(2)
        
	if(!is_user_connected(iAttacker) || iAttacker == iVictim) return PLUGIN_CONTINUE
        
	if(get_user_weapon(iAttacker) == CSW_JANUS1)
	{
		if(g_had_janus1[iAttacker])
			set_msg_arg_string(4, "grenade")
	}
                
	return PLUGIN_CONTINUE
}

public Event_CurWeapon(id)
{
	if(!is_user_alive(id))
		return
		
	if(get_user_weapon(id) == CSW_JANUS1 && g_had_janus1[id])
	{
		set_pev(id, pev_viewmodel2, v_model)
		set_pev(id, pev_weaponmodel2, p_model)
		if(shoot_mode[id] == 1) set_weapon_anim(id, ANIM_DRAW_NORMAL)
		if(shoot_mode[id] == 2) set_weapon_anim(id, ANIM_DRAW_SIGNAL)
		if(shoot_mode[id] == 3) set_weapon_anim(id, ANIM_DRAW_B)
		peluru_hud(id)
	}
	
	g_old_weapon[id] = get_user_weapon(id)
}

public fw_CmdStart(id, uc_handle, seed)
{
	if(!is_user_alive(id) || !is_user_connected(id))
		return
	if(get_user_weapon(id) != CSW_JANUS1 || !g_had_janus1[id])
		return
	
	static ent; ent = fm_get_user_weapon_entity(id, CSW_JANUS1)
	if(!pev_valid(ent))
		return
	if(get_pdata_float(ent, 46, OFFSET_LINUX_WEAPONS) > 0.0 || get_pdata_float(ent, 47, OFFSET_LINUX_WEAPONS) > 0.0) 
		return
	
	static CurButton
	CurButton = get_uc(uc_handle, UC_Buttons)
	
	if(CurButton & IN_ATTACK)
	{
		CurButton &= ~IN_ATTACK
		set_uc(uc_handle, UC_Buttons, CurButton)
			
		if(g_janus_ammo[id] == 1 && get_pdata_float(id, 83, 5) <= 0.0)
		{
			set_weapon_anim(id, ANIM_SHOOT_ABIS)
			emit_sound(id, CHAN_WEAPON, weapon_sound[1], 1.0, ATTN_NORM, 0, PITCH_NORM)
			g_janus_ammo[id]--
			Firejanus1(id)
			peluru_hud(id)
			set_weapons_timeidle(id, CSW_JANUS1, SHOOT_TIME)
			set_player_nextattackx(id, SHOOT_TIME)
		}
		if(g_janus_ammo[id] >= 2  && shoot_mode[id] == 1 && get_pdata_float(id, 83, 5) <= 0.0)
		{
			set_weapon_anim(id, ANIM_SHOOT_NORMAL)
			g_janus_ammo[id]--
			Firejanus1(id)
			peluru_hud(id)
			emit_sound(id, CHAN_WEAPON, weapon_sound[0], 1.0, ATTN_NORM, 0, PITCH_NORM)
			set_weapons_timeidle(id, CSW_JANUS1, ATTACK_TIME)
			set_player_nextattackx(id, ATTACK_TIME)
		}
		if(shoot_mode[id] == 3 && get_pdata_float(id, 83, 5) <= 0.0)
		{
			set_weapon_anim(id, ANIM_SHOOT_B2)
			Firejanus1(id)
			emit_sound(id, CHAN_WEAPON, weapon_sound[1], 1.0, ATTN_NORM, 0, PITCH_NORM)
			set_weapons_timeidle(id, CSW_JANUS1, SHOOT_B_TIME)
			set_player_nextattackx(id, SHOOT_B_TIME)
		}
	}
	else if(CurButton & IN_ATTACK2)
	{
		if(shoot_mode[id] == 2)
		{
			set_weapon_anim(id, ANIM_CHANGE_1)
			shoot_mode[id] = 3
			peluru_hud(id)
			set_task(8.5, "back_normal", id)
			set_task(8.5, "back_normal2", id)
			set_weapons_timeidle(id, CSW_JANUS1, TIME_STAB)
			set_player_nextattackx(id, TIME_STAB)
		}
	}
}

public back_normal(id)
{
	if(get_user_weapon(id) != CSW_JANUS1 || !g_had_janus1[id])
		return
		
	set_weapon_anim(id, ANIM_CHANGE_2)
	emit_sound(id, CHAN_WEAPON, weapon_sound[5], 1.0, ATTN_NORM, 0, PITCH_NORM)
	set_weapons_timeidle(id, CSW_JANUS1, TIME_STAB)
	set_player_nextattackx(id, TIME_STAB)
	peluru_hud(id)
}

public back_normal2(id)
{
	shoot_mode[id] = 1
	hit_janus1[id] = 0
}

public ready_transform(id)
{
	shoot_mode[id] = 2
	set_weapons_timeidle(id, CSW_JANUS1, TIME_STAB)
	set_player_nextattackx(id, TIME_STAB)
}

public fw_janusidleanim(Weapon)
{
	new id = get_pdata_cbase(Weapon, 41, 4)

	if(!is_user_alive(id) || !g_had_janus1[id] || get_user_weapon(id) != CSW_JANUS1)
		return HAM_IGNORED;

	if(shoot_mode[id] == 1) 
		return HAM_SUPERCEDE;
	
	if(shoot_mode[id] == 3 && get_pdata_float(Weapon, 48, 4) <= 0.25)
	{
		set_weapon_anim(id, ANIM_IDLE_B)
		set_pdata_float(Weapon, 48, 20.0, 4)
		return HAM_SUPERCEDE;
	}
	
	if(shoot_mode[id] == 2 && get_pdata_float(Weapon, 48, 4) <= 0.25) 
	{
		set_weapon_anim(id, ANIM_SIGNAL)
		set_pdata_float(Weapon, 48, 20.0, 4)
		return HAM_SUPERCEDE;
	}

	return HAM_IGNORED;
}

public Firejanus1(id)
{
	new Float:origin[3],Float:velocity[3],Float:angles[3]
	engfunc(EngFunc_GetAttachment, id, 0, origin,angles)
	pev(id,pev_angles,angles)
	new ent = create_entity( "info_target" ) 
	set_pev( ent, pev_classname, NAMACLASSNYA )
	set_pev( ent, pev_solid, SOLID_BBOX )
	set_pev( ent, pev_movetype, MOVETYPE_TOSS )
	set_pev( ent, pev_mins, { -0.1, -0.1, -0.1 } )
	set_pev( ent, pev_maxs, { 0.1, 0.1, 0.1 } )
	entity_set_model( ent, GRENADE_MODEL )
	set_pev( ent, pev_origin, origin )
	set_pev( ent, pev_angles, angles )
	set_pev( ent, pev_owner, id )
	velocity_by_aim( id, 1350, velocity )
	set_pev( ent, pev_velocity, velocity )
	message_begin(MSG_BROADCAST, SVC_TEMPENTITY)
	write_byte(TE_BEAMFOLLOW) // Temporary entity ID
	write_short(ent) // Entity
	write_short(sTrail) // Sprite index
	write_byte(10) // Life
	write_byte(3) // Line width
	write_byte(255) // Red
	write_byte(255) // Green
	write_byte(255) // Blue
	write_byte(50) // Alpha
	message_end() 
	return PLUGIN_CONTINUE
}

public fw_Think_Plasma(ptr)
{
	if(!pev_valid(ptr))
		return
		
	static Float:RenderAmt; pev(ptr, pev_renderamt, RenderAmt)
	
	RenderAmt += 50.0
	RenderAmt = float(clamp(floatround(RenderAmt), 0, 255))
	
	set_pev(ptr, pev_renderamt, RenderAmt)
	set_pev(ptr, pev_nextthink, halflife_time() + 0.1)
}

public fw_touch(ptr, ptd)
{
	// If ent is valid
	if (pev_valid(ptr))
	{
			// Get it's origin
			new Float:originF[3]
			pev(ptr, pev_origin, originF)
			engfunc(EngFunc_MessageBegin, MSG_PAS, SVC_TEMPENTITY, originF, 0)
			write_byte(TE_WORLDDECAL)
			engfunc(EngFunc_WriteCoord, originF[0])
			engfunc(EngFunc_WriteCoord, originF[1])
			engfunc(EngFunc_WriteCoord, originF[2])
			write_byte(engfunc(EngFunc_DecalIndex,"{scorch3"))
			message_end()
			// Draw explosion
			message_begin(MSG_BROADCAST, SVC_TEMPENTITY)
			write_byte(TE_EXPLOSION) // Temporary entity ID
			engfunc(EngFunc_WriteCoord, originF[0]) // engfunc because float
			engfunc(EngFunc_WriteCoord, originF[1])
			engfunc(EngFunc_WriteCoord, originF[2]+30.0)
			write_short(sExplo) // Sprite index
			write_byte(35) // Scale
			write_byte(35) // Framerate
			write_byte(0) // Flags
			message_end()
			emit_sound(ptr, CHAN_WEAPON, weapon_sound[2], 1.0, ATTN_NORM, 0, PITCH_NORM)
			
			Damage_janus1(ptr, ptd)
			
			engfunc(EngFunc_RemoveEntity, ptr)
	}
		
}

public Damage_janus1(ptr, ptd)
{
	static Owner; Owner = pev(ptr, pev_owner)
	static Attacker
	if(!is_user_alive(Owner)) 
	{
		Attacker = 0
		return
	} else Attacker = Owner
		
	for(new i = 0; i < g_MaxPlayers; i++)
	{
		if(!is_user_alive(i))
			continue
		if(entity_range(i, ptr) > 200.0)
			continue
		//if(!zp_get_user_zombie(i))
			//continue
			
		ExecuteHamB(Ham_TakeDamage, i, 0, Attacker, get_pcvar_float(cvar_dmg_janus1), DMG_BULLET)
		hit_on[Attacker] = 1
	}
	
	if(hit_on[Attacker] && hit_janus1[Attacker] < 6)
	{
		hit_janus1[Attacker] ++
		hit_on[Attacker] = 0
	}
	
	if(hit_janus1[Attacker] == 5 && shoot_mode[Attacker] == 1) set_task(0.5, "ready_transform", Attacker)
}

public fw_SetModel(entity, model[])
{
	if(!pev_valid(entity))
		return FMRES_IGNORED
	
	static Classname[64]
	pev(entity, pev_classname, Classname, sizeof(Classname))
	
	if(!equal(Classname, "weaponbox"))
		return FMRES_IGNORED
	
	static id
	id = pev(entity, pev_owner)
	
	if(equal(model, model_lama))
	{
		static weapon
		weapon = fm_get_user_weapon_entity(entity, CSW_JANUS1)
		
		if(!pev_valid(weapon))
			return FMRES_IGNORED
		
		if(g_had_janus1[id])
		{
			set_pev(weapon, pev_impulse, RAHASIA)
			set_pev(weapon, pev_iuser4, g_janus_ammo[id])
			//engfunc(EngFunc_SetModel, entity, w_model)
			
			g_had_janus1[id] = 0
			g_janus_ammo[id] = 0
			
			return FMRES_SUPERCEDE
		}
	}

	return FMRES_IGNORED;
}

public fw_AddToPlayer_Post(ent, id)
{
	if(pev(ent, pev_impulse) == RAHASIA)
	{
		g_had_janus1[id] = 1
		g_janus_ammo[id] = pev(ent, pev_iuser4)
		
		set_pev(ent, pev_impulse, 0)
	}			
	
	message_begin(MSG_ONE_UNRELIABLE, get_user_msgid("WeaponList"), _, id)
	write_string((g_had_janus1[id] == 1 ? "weapon_janus1" : "weapon_fiveseven"))
	write_byte(1)
	write_byte(100)
	write_byte(-1)
	write_byte(-1)
	write_byte(1)
	write_byte(6)
	write_byte(CSW_JANUS1)
	write_byte(0)
	message_end()
}

public peluru_hud(id)
{
	if(!is_user_alive(id))
		return
	
	static weapon_ent; weapon_ent = fm_find_ent_by_owner(-1, weapon_janus1, id)
	if(pev_valid(weapon_ent)) cs_set_weapon_ammo(weapon_ent, 1)	
	
	cs_set_user_bpammo(id, CSW_FIVESEVEN, 0)
	
	engfunc(EngFunc_MessageBegin, MSG_ONE_UNRELIABLE, get_user_msgid("CurWeapon"), {0, 0, 0}, id)
	write_byte(1)
	write_byte(CSW_JANUS1)
	write_byte(-1)
	message_end()
	
	message_begin(MSG_ONE_UNRELIABLE, get_user_msgid("AmmoX"), _, id)
	write_byte(1)
	write_byte(g_janus_ammo[id])
	message_end()
}

stock set_weapon_anim(id, anim)
{
	if(!is_user_alive(id))
		return
	
	set_pev(id, pev_weaponanim, anim)
	
	message_begin(MSG_ONE_UNRELIABLE, SVC_WEAPONANIM, {0, 0, 0}, id)
	write_byte(anim)
	write_byte(pev(id, pev_body))
	message_end()
}

stock get_weapon_attachment(id, Float:output[3], Float:fDis = 40.0)
{ 
	new Float:vfEnd[3], viEnd[3] 
	get_user_origin(id, viEnd, 3)  
	IVecFVec(viEnd, vfEnd) 
	
	new Float:fOrigin[3], Float:fAngle[3]
	
	pev(id, pev_origin, fOrigin) 
	pev(id, pev_view_ofs, fAngle)
	
	xs_vec_add(fOrigin, fAngle, fOrigin) 
	
	new Float:fAttack[3]
	
	xs_vec_sub(vfEnd, fOrigin, fAttack)
	xs_vec_sub(vfEnd, fOrigin, fAttack) 
	
	new Float:fRate
	
	fRate = fDis / vector_length(fAttack)
	xs_vec_mul_scalar(fAttack, fRate, fAttack)
	
	xs_vec_add(fOrigin, fAttack, output)
}

stock drop_weapons(id, dropwhat)
{
	static weapons[32], num, i, weaponid
	num = 0
	get_user_weapons(id, weapons, num)
	 
	for (i = 0; i < num; i++)
	{
		weaponid = weapons[i]
		  
		if (dropwhat == 1 && ((1<<weaponid) & SECONDARY_WEAPONS_BIT_SUM))
		{
			static wname[32]
			get_weaponname(weaponid, wname, sizeof wname - 1)
			engclient_cmd(id, "drop", wname)
		}
	}
}

stock set_weapons_timeidle(id, WeaponId ,Float:TimeIdle)
{
	if(!is_user_alive(id))
		return
		
	static entwpn; entwpn = fm_get_user_weapon_entity(id, WeaponId)
	if(!pev_valid(entwpn)) 
		return
		
	set_pdata_float(entwpn, 46, TimeIdle, OFFSET_LINUX_WEAPONS)
	set_pdata_float(entwpn, 47, TimeIdle, OFFSET_LINUX_WEAPONS)
	set_pdata_float(entwpn, 48, TimeIdle + 0.5, OFFSET_LINUX_WEAPONS)
}

stock set_player_nextattackx(id, Float:nexttime)
{
	if(!is_user_alive(id))
		return
		
	set_pdata_float(id, m_flNextAttack, nexttime, 5)
}
/* AMXX-Studio Notes - DO NOT MODIFY BELOW HERE
*{\\ rtf1\\ ansi\\ deff0{\\ fonttbl{\\ f0\\ fnil Tahoma;}}\n\\ viewkind4\\ uc1\\ pard\\ lang1033\\ f0\\ fs16 \n\\ par }
*/
