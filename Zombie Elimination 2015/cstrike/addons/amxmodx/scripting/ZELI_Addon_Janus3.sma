#include <amxmodx>
#include <engine>
#include <fakemeta>
#include <fakemeta_util>
#include <fun>
#include <hamsandwich>
#include <xs>
#include <cstrike>
#include <zombie_eli>

#define ENG_NULLENT			-1
#define EV_INT_WEAPONKEY	EV_INT_impulse
#define janus3_WEAPONKEY 	5879122
#define MAX_PLAYERS  		32
#define WEAPON_ANIMEXT "carbine"

const USE_STOPPED = 0
const OFFSET_ACTIVE_ITEM = 373
const OFFSET_WEAPONOWNER = 41
const OFFSET_LINUX = 5
const OFFSET_LINUX_WEAPONS = 4
const m_szAnimExtention = 492

#if cellbits == 32
const OFFSET_CLIPAMMO = 51
#else
const OFFSET_CLIPAMMO = 65
#endif

#define WEAP_LINUX_XTRA_OFF		4
#define m_fKnown					44
#define m_flNextPrimaryAttack 		46
#define m_flTimeWeaponIdle			48
#define m_iClip					51
#define m_fInReload				54
#define PLAYER_LINUX_XTRA_OFF	5
#define m_flNextAttack				83
#define janus3_READY 20
#define janus3_RELOAD_TIME	3.0

enum
{
	ANIM_IDLE = 0,
	ANIM_RELOAD_NORMAL,
	ANIM_DRAW_NORMAL,
	ANIM_SHOOT_NORMAL,
	ANIM_SHOOT_SIGNAL,
	ANIM_CHANGE_1,
	ANIM_IDLE_B,
	ANIM_DRAW_B,
	ANIM_SHOOT_B,
	ANIM_SHOOT_B2,
	ANIM_SHOOT_B3,
	ANIM_CHANGE_2,
	ANIM_SIGNAL,
	ANIM_RELOAD_SIGNAL,
	ANIM_DRAW_SIGNAL
}

#define write_coord_f(%1)	engfunc(EngFunc_WriteCoord,%1)

new const Fire_Sounds[][] = { "weapons/janusmk5-12.wav" }
new const Fire_Sounds2[][] = { "weapons/janusmk5-2.wav" }

new janus3_V_MODEL[64] = "models/v_janus3.mdl"
new janus3_P_MODEL[64] = "models/p_janus3.mdl"
//new janus3_W_MODEL[64] = "models/w_janus3.mdl"

new const GUNSHOT_DECALS[] = { 41, 42, 43, 44, 45 }

new cvar_dmg_janus3, cvar_dmg2_janus3, cvar_recoil_janus3, cvar_recoil2_janus3, cvar_clip_janus3, cvar_spd_janus3, cvar_spd2_janus3, cvar_janus3_ammo
new g_MaxPlayers, g_orig_event_janus3, g_IsInPrimaryAttack
new Float:cl_pushangle[MAX_PLAYERS + 1][3], m_iBlood[2]
new g_has_janus3[33], g_clip_ammo[33], g_janus3_TmpClip[33], oldweap[33], janus3_mode[33], janus3_signal[33], siap_janus3[33]
new gmsgWeaponList, g_Ham_Bot

new g_Janus3, g_FrozenTech

const PRIMARY_WEAPONS_BIT_SUM = 
(1<<CSW_SCOUT)|(1<<CSW_XM1014)|(1<<CSW_MAC10)|(1<<CSW_AUG)|(1<<CSW_UMP45)|(1<<CSW_SG550)|(1<<CSW_GALIL)|(1<<CSW_FAMAS)|(1<<CSW_AWP)|(1<<
CSW_MP5NAVY)|(1<<CSW_M249)|(1<<CSW_M3)|(1<<CSW_M4A1)|(1<<CSW_TMP)|(1<<CSW_G3SG1)|(1<<CSW_SG552)|(1<<CSW_AK47)|(1<<CSW_P90)
new const WEAPONENTNAMES[][] = { "", "weapon_p228", "", "weapon_scout", "weapon_hegrenade", "weapon_xm1014", "weapon_c4", "weapon_mac10",
			"weapon_aug", "weapon_smokegrenade", "weapon_elite", "weapon_fiveseven", "weapon_ump45", "weapon_sg550",
			"weapon_galil", "weapon_famas", "weapon_usp", "weapon_glock18", "weapon_awp", "weapon_mp5navy", "weapon_m249",
			"weapon_m3", "weapon_m4a1", "weapon_tmp", "weapon_g3sg1", "weapon_flashbang", "weapon_deagle", "weapon_sg552",
			"weapon_ak47", "weapon_knife", "weapon_p90" }

public plugin_init()
{
	register_plugin("Janus-3", "1.0", "m4m3ts")
	register_cvar("janus3_version", "m4m3ts", FCVAR_SERVER|FCVAR_SPONLY)
	register_message(get_user_msgid("DeathMsg"), "message_DeathMsg")
	register_event("CurWeapon","CurrentWeapon","be","1=1")
	RegisterHam(Ham_Item_AddToPlayer, "weapon_galil", "fw_janus3_AddToPlayer")
	RegisterHam(Ham_Use, "func_tank", "fw_UseStationary_Post", 1)
	RegisterHam(Ham_Use, "func_tankmortar", "fw_UseStationary_Post", 1)
	RegisterHam(Ham_Use, "func_tankrocket", "fw_UseStationary_Post", 1)
	RegisterHam(Ham_Use, "func_tanklaser", "fw_UseStationary_Post", 1)
	for (new i = 1; i < sizeof WEAPONENTNAMES; i++)
	if (WEAPONENTNAMES[i][0]) RegisterHam(Ham_Item_Deploy, WEAPONENTNAMES[i], "fw_Item_Deploy_Post", 1)
	RegisterHam(Ham_Weapon_PrimaryAttack, "weapon_galil", "fw_janus3_PrimaryAttack")
	RegisterHam(Ham_Weapon_PrimaryAttack, "weapon_galil", "fw_janus3_PrimaryAttack_Post", 1)
	RegisterHam(Ham_Item_PostFrame, "weapon_galil", "janus3_ItemPostFrame")
	RegisterHam(Ham_Weapon_Reload, "weapon_galil", "janus3_Reload")
	RegisterHam(Ham_Weapon_Reload, "weapon_galil", "janus3_Reload_Post", 1)
	RegisterHam(Ham_TakeDamage, "player", "fw_TakeDamage")
	RegisterHam(Ham_Weapon_WeaponIdle, "weapon_galil", "fw_janus3idleanim", 1)
	register_forward(FM_SetModel, "fw_SetModel")
	register_forward(FM_CmdStart, "fw_CmdStart")
	register_forward(FM_UpdateClientData, "fw_UpdateClientData_Post", 1)
	register_forward(FM_PlaybackEvent, "fwPlaybackEvent")
	
	RegisterHam(Ham_TraceAttack, "worldspawn", "fw_TraceAttack", 1)
	RegisterHam(Ham_TraceAttack, "func_breakable", "fw_TraceAttack", 1)
	RegisterHam(Ham_TraceAttack, "func_wall", "fw_TraceAttack", 1)
	RegisterHam(Ham_TraceAttack, "func_door", "fw_TraceAttack", 1)
	RegisterHam(Ham_TraceAttack, "func_door_rotating", "fw_TraceAttack", 1)
	RegisterHam(Ham_TraceAttack, "func_plat", "fw_TraceAttack", 1)
	RegisterHam(Ham_TraceAttack, "func_rotating", "fw_TraceAttack", 1)

	cvar_dmg_janus3 = register_cvar("janus3_dmg", "1.0")
	cvar_dmg2_janus3 = register_cvar("janus3_dmg2", "2.0")
	cvar_recoil_janus3 = register_cvar("janus3_recoil", "0.8")
	cvar_recoil2_janus3 = register_cvar("janus3_recoil2", "0.45")
	cvar_clip_janus3 = register_cvar("janus3_clip", "50")
	cvar_spd_janus3 = register_cvar("janus3_spd", "1.1")
	cvar_spd2_janus3 = register_cvar("janus3_spd2", "0.07")
	cvar_janus3_ammo = register_cvar("janus3_ammo", "200")
		
	g_MaxPlayers = get_maxplayers()
        gmsgWeaponList = get_user_msgid("WeaponList")
		
	g_FrozenTech = ZombieEli_GetClassID("Frozen Tech")
	g_Janus3 = ZombieEli_RegisterWeapon(g_FrozenTech, "CSO Janus-3", WPN_PRIMARY, 4, 0)
}

public plugin_precache()
{
	precache_model(janus3_V_MODEL)
	precache_model(janus3_P_MODEL)
	//precache_model(janus3_W_MODEL)
	for(new i = 0; i < sizeof Fire_Sounds; i++)
	precache_sound(Fire_Sounds[i])
	for(new i = 0; i < sizeof Fire_Sounds2; i++)
	precache_sound(Fire_Sounds2[i])
	precache_sound("weapons/janus3_boltpull1.wav")
	precache_sound("weapons/janus3_boltpull2.wav")
	precache_sound("weapons/janus3_clipin.wav")
	precache_sound("weapons/janus3_clipout.wav")
	precache_sound("weapons/janus3_draw.wav")
	precache_sound("weapons/janus3_change1.wav")
	precache_sound("weapons/janus3_change2.wav")
	m_iBlood[0] = precache_model("sprites/blood.spr")
	m_iBlood[1] = precache_model("sprites/bloodspray.spr")
        precache_generic("sprites/weapon_janus3.txt")
   	precache_generic("sprites/640hud109.spr")
    	precache_generic("sprites/640hud7.spr")
	
	register_clcmd("weapon_janus3", "weapon_hook")	
	register_forward(FM_PrecacheEvent, "fwPrecacheEvent_Post", 1)
	register_clcmd("get_janus3", "give_janus3", ADMIN_KICK)
}

public client_putinserver(id)
{
	if(!g_Ham_Bot && is_user_bot(id))
	{
		g_Ham_Bot = 1
		set_task(0.1, "Do_RegisterHam_Bot", id)
	}
}

public Do_RegisterHam_Bot(id)
{
	RegisterHamFromEntity(Ham_TakeDamage, id, "fw_TakeDamage")
}

public zeli_weapon_selected(id, ItemID, ClassID)
{
	if(ItemID == g_Janus3) give_janus3(id)
}

public zeli_weapon_removed(id, ItemID)
{
	if(ItemID == g_Janus3) Remove_Janus3(id)
}

public weapon_hook(id)
{
    	engclient_cmd(id, "weapon_galil")
    	return PLUGIN_HANDLED
}

public fw_TraceAttack(iEnt, iAttacker, Float:flDamage, Float:fDir[3], ptr, iDamageType)
{
	if(!is_user_alive(iAttacker))
		return

	new g_currentweapon = get_user_weapon(iAttacker)

	if(g_currentweapon != CSW_GALIL) return
	
	if(!g_has_janus3[iAttacker]) return

	static Float:flEnd[3]
	get_tr2(ptr, TR_vecEndPos, flEnd)
	
	if(iEnt)
	{
		message_begin(MSG_BROADCAST, SVC_TEMPENTITY)
		write_byte(TE_DECAL)
		write_coord_f(flEnd[0])
		write_coord_f(flEnd[1])
		write_coord_f(flEnd[2])
		write_byte(GUNSHOT_DECALS[random_num (0, sizeof GUNSHOT_DECALS -1)])
		write_short(iEnt)
		message_end()
	}
	else
	{
		message_begin(MSG_BROADCAST, SVC_TEMPENTITY)
		write_byte(TE_WORLDDECAL)
		write_coord_f(flEnd[0])
		write_coord_f(flEnd[1])
		write_coord_f(flEnd[2])
		write_byte(GUNSHOT_DECALS[random_num (0, sizeof GUNSHOT_DECALS -1)])
		message_end()
	}
	message_begin(MSG_BROADCAST, SVC_TEMPENTITY)
	write_byte(TE_GUNSHOTDECAL)
	write_coord_f(flEnd[0])
	write_coord_f(flEnd[1])
	write_coord_f(flEnd[2])
	write_short(iAttacker)
	write_byte(GUNSHOT_DECALS[random_num (0, sizeof GUNSHOT_DECALS -1)])
	message_end()
}

public fwPrecacheEvent_Post(type, const name[])
{
	if (equal("events/galil.sc", name))
	{
		g_orig_event_janus3 = get_orig_retval()
		return FMRES_HANDLED
	}
	return FMRES_IGNORED
}

public client_connect(id)
{
	g_has_janus3[id] = false
}

public client_disconnect(id)
{
	g_has_janus3[id] = false
}

public fw_SetModel(entity, model[])
{
	if(!is_valid_ent(entity))
		return FMRES_IGNORED
	
	static szClassName[33]
	entity_get_string(entity, EV_SZ_classname, szClassName, charsmax(szClassName))
		
	if(!equal(szClassName, "weaponbox"))
		return FMRES_IGNORED
	
	static iOwner
	
	iOwner = entity_get_edict(entity, EV_ENT_owner)
	
	if(equal(model, "models/w_galil.mdl"))
	{
		static iStoredAugID
		
		iStoredAugID = find_ent_by_owner(ENG_NULLENT, "weapon_galil", entity)
	
		if(!is_valid_ent(iStoredAugID))
			return FMRES_IGNORED
	
		if(g_has_janus3[iOwner])
		{
			entity_set_int(iStoredAugID, EV_INT_WEAPONKEY, janus3_WEAPONKEY)
			
			g_has_janus3[iOwner] = false
			
			//entity_set_model(entity, janus3_W_MODEL)
			
			return FMRES_SUPERCEDE
		}
	}
	return FMRES_IGNORED
}
public Remove_Janus3(id)
{
	g_has_janus3[id] = true
}

public give_janus3(id)
{
	drop_weapons(id, 1)
	new iWep2 = give_item(id,"weapon_galil")
	if( iWep2 > 0 )
	{
		cs_set_weapon_ammo(iWep2, get_pcvar_num(cvar_clip_janus3))
		cs_set_user_bpammo (id, CSW_GALIL, get_pcvar_num(cvar_janus3_ammo))	
		UTIL_PlayWeaponAnimation(id, ANIM_DRAW_NORMAL)
		set_pdata_float(id, m_flNextAttack, 1.0, PLAYER_LINUX_XTRA_OFF)
	}
	g_has_janus3[id] = true
	siap_janus3[id] = 1
	janus3_mode[id] = 1
	janus3_signal[id] = 0
	update_ammo(id)
	
	message_begin(MSG_ONE, gmsgWeaponList, {0,0,0}, id)
	write_string("weapon_janus3")
	write_byte(4)
	write_byte(90)
	write_byte(-1)
	write_byte(-1)
	write_byte(0)
	write_byte(17)
	write_byte(CSW_GALIL)
	write_byte(0)
	message_end()
}

public fw_janus3_AddToPlayer(janus3, id)
{
	if(!is_valid_ent(janus3) || !is_user_connected(id))
		return HAM_IGNORED
	
	if(entity_get_int(janus3, EV_INT_WEAPONKEY) == janus3_WEAPONKEY)
	{
		g_has_janus3[id] = true
		
		entity_set_int(janus3, EV_INT_WEAPONKEY, 0)

		message_begin(MSG_ONE, gmsgWeaponList, {0,0,0}, id)
		write_string("weapon_janus3")
		write_byte(4)
		write_byte(90)
		write_byte(-1)
		write_byte(-1)
		write_byte(0)
		write_byte(17)
		write_byte(CSW_GALIL)
		write_byte(0)
		message_end()
		
	}
            else
	{
		message_begin(MSG_ONE, gmsgWeaponList, {0,0,0}, id)
		write_string("weapon_galil")
		write_byte(4)
		write_byte(90)
		write_byte(-1)
		write_byte(-1)
		write_byte(0)
		write_byte(17)
		write_byte(CSW_GALIL)
		write_byte(0)
		message_end()
	}
	return HAM_IGNORED
}

public update_ammo(id)
{
	if(!is_user_alive(id))
		return
	
	static weapon_ent; weapon_ent = fm_get_user_weapon_entity(id, CSW_GALIL)
	if(!pev_valid(weapon_ent)) return
	
	engfunc(EngFunc_MessageBegin, MSG_ONE_UNRELIABLE, get_user_msgid("CurWeapon"), {0, 0, 0}, id)
	write_byte(1)
	write_byte(CSW_GALIL)
	write_byte(cs_get_weapon_ammo(weapon_ent))
	message_end()
	
	message_begin(MSG_ONE_UNRELIABLE, get_user_msgid("AmmoX"), _, id)
	write_byte(1)
	write_byte(cs_get_user_bpammo(id, CSW_GALIL))
	message_end()
}

public fw_UseStationary_Post(entity, caller, activator, use_type)
{
	if (use_type == USE_STOPPED && is_user_connected(caller))
		replace_weapon_models(caller, get_user_weapon(caller))
}

public fw_Item_Deploy_Post(weapon_ent)
{
	static owner
	owner = fm_cs_get_weapon_ent_owner(weapon_ent)
	
	static weaponid
	weaponid = cs_get_weapon_id(weapon_ent)
	
	replace_weapon_models(owner, weaponid)
}

public CurrentWeapon(id)
{
     replace_weapon_models(id, read_data(2))

     if(read_data(2) != CSW_GALIL || !g_has_janus3[id])
          return
     
     static Float:iSpeed
     if(g_has_janus3[id])
          if(janus3_mode[id] != 3) iSpeed = get_pcvar_float(cvar_spd_janus3)
     
     static weapon[32],Ent
     get_weaponname(read_data(2),weapon,31)
     Ent = find_ent_by_owner(-1,weapon,id)
     if(Ent)
     {
          static Float:Delay
          Delay = get_pdata_float( Ent, 46, 4) * iSpeed
          if (Delay > 0.0)
          {
               set_pdata_float(Ent, 46, Delay, 4)
          }
     }
}

replace_weapon_models(id, weaponid)
{
	switch (weaponid)
	{
		case CSW_GALIL:
		{	
			if(g_has_janus3[id])
			{
				set_pev(id, pev_viewmodel2, janus3_V_MODEL)
				set_pev(id, pev_weaponmodel2, janus3_P_MODEL)
				if(oldweap[id] != CSW_GALIL) 
				{
					if(janus3_mode[id] == 1) UTIL_PlayWeaponAnimation(id, ANIM_DRAW_NORMAL)
					if(janus3_mode[id] == 2) UTIL_PlayWeaponAnimation(id, ANIM_DRAW_SIGNAL)
					if(janus3_mode[id] == 3) UTIL_PlayWeaponAnimation(id, ANIM_DRAW_B)
					set_pdata_string(id, m_szAnimExtention * 4, WEAPON_ANIMEXT, -1 , 20)
					set_pdata_float(id, m_flNextAttack, 1.0, PLAYER_LINUX_XTRA_OFF)

					message_begin(MSG_ONE, gmsgWeaponList, {0,0,0}, id)
					write_string("weapon_janus3")
					write_byte(4)
					write_byte(90)
					write_byte(-1)
					write_byte(-1)
					write_byte(0)
					write_byte(17)
					write_byte(CSW_GALIL)
					write_byte(0)
					message_end()

				}
			}
		}
	}
	oldweap[id] = weaponid
}

public fw_UpdateClientData_Post(Player, SendWeapons, CD_Handle)
{
	if(!is_user_alive(Player) || (get_user_weapon(Player) != CSW_GALIL || !g_has_janus3[Player]))
		return FMRES_IGNORED
	
	set_cd(CD_Handle, CD_flNextAttack, halflife_time () + 0.001)
	return FMRES_HANDLED
}

public fw_janus3_PrimaryAttack(Weapon)
{
	new Player = get_pdata_cbase(Weapon, 41, 4)
	
	if (!g_has_janus3[Player])
		return
	
	g_IsInPrimaryAttack = 1
	pev(Player,pev_punchangle,cl_pushangle[Player])
	
	g_clip_ammo[Player] = cs_get_weapon_ammo(Weapon)
}

public fwPlaybackEvent(flags, invoker, eventid, Float:delay, Float:origin[3], Float:angles[3], Float:fparam1, Float:fparam2, iParam1, iParam2, bParam1, bParam2)
{
	if ((eventid != g_orig_event_janus3) || !g_IsInPrimaryAttack)
		return FMRES_IGNORED
	if (!(1 <= invoker <= g_MaxPlayers))
    return FMRES_IGNORED

	playback_event(flags | FEV_HOSTONLY, invoker, eventid, delay, origin, angles, fparam1, fparam2, iParam1, iParam2, bParam1, bParam2)
	return FMRES_SUPERCEDE
}

public fw_janus3_PrimaryAttack_Post(Weapon)
{
	g_IsInPrimaryAttack = 0
	new Player = get_pdata_cbase(Weapon, 41, 4)
	
	new szClip, szAmmo
	get_user_weapon(Player, szClip, szAmmo)
	
	if(!is_user_alive(Player))
		return
	if(!g_has_janus3[Player])
		return

	if(janus3_mode[Player] != 3)
	{
		if (!g_clip_ammo[Player])
			return

		new Float:push[3]
		pev(Player,pev_punchangle,push)
		xs_vec_sub(push,cl_pushangle[Player],push)
		
		xs_vec_mul_scalar(push,get_pcvar_float(cvar_recoil_janus3),push)
		xs_vec_add(push,cl_pushangle[Player],push)
		set_pev(Player,pev_punchangle,push)
		
		emit_sound(Player, CHAN_WEAPON, Fire_Sounds[0], VOL_NORM, ATTN_NORM, 0, PITCH_NORM)
		if(janus3_signal[Player] >= janus3_READY && siap_janus3[Player])
		{
			janus3_mode[Player] = 2
			set_task(12.7, "janus3_mode1", Player)
			emit_sound(Player, CHAN_VOICE, "weapons/change1_ready.wav", VOL_NORM, ATTN_NORM, 0, PITCH_NORM)
			siap_janus3[Player] = 0
		}
		
		if(janus3_mode[Player] == 2) UTIL_PlayWeaponAnimation(Player, ANIM_SHOOT_SIGNAL)
		else UTIL_PlayWeaponAnimation(Player, ANIM_SHOOT_NORMAL)
	}
	else
	{
		if (!g_clip_ammo[Player]) szClip = 2
		
		new Float:push[3]
		pev(Player,pev_punchangle,push)
		xs_vec_sub(push,cl_pushangle[Player],push)
		
		xs_vec_mul_scalar(push,get_pcvar_float(cvar_recoil2_janus3),push)
		xs_vec_add(push,cl_pushangle[Player],push)
		set_pev(Player,pev_punchangle,push)
		
		emit_sound(Player, CHAN_WEAPON, Fire_Sounds2[0], VOL_NORM, ATTN_NORM, 0, PITCH_NORM)
		fm_set_weapon_ammo(Weapon, szClip++)
		set_weapons_timeidle(Player, CSW_GALIL, get_pcvar_float(cvar_spd2_janus3))
		set_player_nextattackx(Player, get_pcvar_float(cvar_spd2_janus3))
		UTIL_PlayWeaponAnimation(Player, random_num(ANIM_SHOOT_B,ANIM_SHOOT_B3))
	}
}

public janus3_mode1(id)
{
	janus3_mode[id] = 1
	janus3_signal[id] = 0
	siap_janus3[id] = 1
	remove_task(id)
}

public fw_janus3idleanim(Weapon)
{
	new id = get_pdata_cbase(Weapon, 41, 4)

	if(!is_user_alive(id) || !g_has_janus3[id] || get_user_weapon(id) != CSW_GALIL)
		return HAM_IGNORED;

	if(janus3_mode[id] == 1) 
		return HAM_SUPERCEDE;
	
	if(janus3_mode[id] == 3 && get_pdata_float(Weapon, 48, 4) <= 0.25)
	{
		UTIL_PlayWeaponAnimation(id, ANIM_IDLE_B)
		set_pdata_float(Weapon, 48, 20.0, 4)
		return HAM_SUPERCEDE;
	}
	
	if(janus3_mode[id] == 2 && get_pdata_float(Weapon, 48, 4) <= 0.25) 
	{
		UTIL_PlayWeaponAnimation(id, ANIM_SIGNAL)
		set_pdata_float(Weapon, 48, 20.0, 4)
		return HAM_SUPERCEDE;
	}

	return HAM_IGNORED;
}

public fw_CmdStart(id, uc_handle, seed)
{
	if(!is_user_alive(id) || !is_user_connected(id))
		return
	if(get_user_weapon(id) != CSW_GALIL || !g_has_janus3[id])
		return
	
	static ent; ent = fm_get_user_weapon_entity(id, CSW_GALIL)
	if(!pev_valid(ent))
		return
	
	static CurButton
	CurButton = get_uc(uc_handle, UC_Buttons)

	if(CurButton & IN_ATTACK2)
	{
		if(janus3_mode[id] == 2 && get_pdata_float(id, 83, 5) <= 0.0)
		{
			remove_task(id)
			UTIL_PlayWeaponAnimation(id, ANIM_CHANGE_1)
			janus3_mode[id] = 3
			set_weapons_timeidle(id, CSW_GALIL, 1.7)
			set_player_nextattackx(id, 1.7)
			set_task(8.7, "back_normal", id)
			set_task(8.7, "back_normal2", id)
		}
	}
}

public back_normal(id)
{
	if(get_user_weapon(id) != CSW_GALIL || !g_has_janus3[id])
		return
		
	UTIL_PlayWeaponAnimation(id, ANIM_CHANGE_2)
	set_weapons_timeidle(id, CSW_GALIL, 1.8)
	set_player_nextattackx(id, 1.8)
}

public back_normal2(id)
{
	janus3_mode[id] = 1
	janus3_signal[id] = 0
	siap_janus3[id] = 1
}

public fw_TakeDamage(victim, inflictor, attacker, Float:damage)
{
	if (victim != attacker && is_user_connected(attacker))
	{
		if(get_user_weapon(attacker) == CSW_GALIL)
		{
			if(g_has_janus3[attacker])
			{
				if(janus3_mode[attacker] != 3)
				{
					SetHamParamFloat(4, damage * get_pcvar_float(cvar_dmg_janus3))
					janus3_signal[attacker] ++
				}
				else SetHamParamFloat(4, damage * get_pcvar_float(cvar_dmg2_janus3))
			}
		}
	}
}

public message_DeathMsg(msg_id, msg_dest, id)
{
	static szTruncatedWeapon[33], iAttacker, iVictim
	
	get_msg_arg_string(4, szTruncatedWeapon, charsmax(szTruncatedWeapon))
	
	iAttacker = get_msg_arg_int(1)
	iVictim = get_msg_arg_int(2)
	
	if(!is_user_connected(iAttacker) || iAttacker == iVictim)
		return PLUGIN_CONTINUE
	
	if(equal(szTruncatedWeapon, "galil") && get_user_weapon(iAttacker) == CSW_GALIL)
	{
		if(g_has_janus3[iAttacker])
			set_msg_arg_string(4, "galil")
	}
	return PLUGIN_CONTINUE
}

stock fm_cs_get_current_weapon_ent(id)
{
	return get_pdata_cbase(id, OFFSET_ACTIVE_ITEM, OFFSET_LINUX)
}

stock fm_cs_get_weapon_ent_owner(ent)
{
	return get_pdata_cbase(ent, OFFSET_WEAPONOWNER, OFFSET_LINUX_WEAPONS)
}

stock UTIL_PlayWeaponAnimation(const Player, const Sequence)
{
	set_pev(Player, pev_weaponanim, Sequence)
	
	message_begin(MSG_ONE_UNRELIABLE, SVC_WEAPONANIM, .player = Player)
	write_byte(Sequence)
	write_byte(pev(Player, pev_body))
	message_end()
}

public janus3_ItemPostFrame(weapon_entity) 
{
     new id = pev(weapon_entity, pev_owner)
     if (!is_user_connected(id))
          return HAM_IGNORED

     if (!g_has_janus3[id])
          return HAM_IGNORED

     static iClipExtra
     
     iClipExtra = get_pcvar_num(cvar_clip_janus3)
     new Float:flNextAttack = get_pdata_float(id, m_flNextAttack, PLAYER_LINUX_XTRA_OFF)

     new iBpAmmo = cs_get_user_bpammo(id, CSW_GALIL)
     new iClip = get_pdata_int(weapon_entity, m_iClip, WEAP_LINUX_XTRA_OFF)

     new fInReload = get_pdata_int(weapon_entity, m_fInReload, WEAP_LINUX_XTRA_OFF) 

     if( fInReload && flNextAttack <= 0.0 )
     {
	     new j = min(iClipExtra - iClip, iBpAmmo)
	
	     set_pdata_int(weapon_entity, m_iClip, iClip + j, WEAP_LINUX_XTRA_OFF)
	     cs_set_user_bpammo(id, CSW_GALIL, iBpAmmo-j)
		
	     set_pdata_int(weapon_entity, m_fInReload, 0, WEAP_LINUX_XTRA_OFF)
	     fInReload = 0
     }
     return HAM_IGNORED
}

public janus3_Reload(weapon_entity) 
{
     new id = pev(weapon_entity, pev_owner)
     if (!is_user_connected(id))
          return HAM_IGNORED

     if (!g_has_janus3[id])
          return HAM_IGNORED

     static iClipExtra

     if(g_has_janus3[id])
          iClipExtra = get_pcvar_num(cvar_clip_janus3)

     g_janus3_TmpClip[id] = -1

     new iBpAmmo = cs_get_user_bpammo(id, CSW_GALIL)
     new iClip = get_pdata_int(weapon_entity, m_iClip, WEAP_LINUX_XTRA_OFF)

     if (iBpAmmo <= 0)
          return HAM_SUPERCEDE

     if (iClip >= iClipExtra)
          return HAM_SUPERCEDE
		  
     if(janus3_mode[id] == 3)
	      return HAM_SUPERCEDE

     g_janus3_TmpClip[id] = iClip

     return HAM_IGNORED
}

public janus3_Reload_Post(weapon_entity) 
{
	new id = pev(weapon_entity, pev_owner)
	if (!is_user_connected(id))
		return HAM_IGNORED

	if (!g_has_janus3[id])
		return HAM_IGNORED

	if (g_janus3_TmpClip[id] == -1)
		return HAM_IGNORED

	set_pdata_int(weapon_entity, m_iClip, g_janus3_TmpClip[id], WEAP_LINUX_XTRA_OFF)
	
	set_weapons_timeidle(id, CSW_GALIL, janus3_RELOAD_TIME)
	set_player_nextattackx(id, janus3_RELOAD_TIME)
	
	set_pdata_int(weapon_entity, m_fInReload, 1, WEAP_LINUX_XTRA_OFF)
	
	if(janus3_mode[id] == 2) UTIL_PlayWeaponAnimation(id, ANIM_RELOAD_SIGNAL)
	else UTIL_PlayWeaponAnimation(id, ANIM_RELOAD_NORMAL)

	return HAM_IGNORED
}

stock set_player_nextattackx(id, Float:nexttime)
{
	if(!is_user_alive(id))
		return
		
	set_pdata_float(id, m_flNextAttack, nexttime, 5)
}

stock set_weapons_timeidle(id, WeaponId ,Float:TimeIdle)
{
	if(!is_user_alive(id))
		return
		
	static entwpn; entwpn = fm_get_user_weapon_entity(id, WeaponId)
	if(!pev_valid(entwpn)) 
		return
		
	set_pdata_float(entwpn, 46, TimeIdle, WEAP_LINUX_XTRA_OFF)
	set_pdata_float(entwpn, 47, TimeIdle, WEAP_LINUX_XTRA_OFF)
	set_pdata_float(entwpn, 48, TimeIdle + 0.5, WEAP_LINUX_XTRA_OFF)
}

stock fm_set_weapon_ammo(entity, amount)
{
	set_pdata_int(entity, OFFSET_CLIPAMMO, amount, OFFSET_LINUX_WEAPONS);
}

stock drop_weapons(id, dropwhat)
{
     static weapons[32], num, i, weaponid
     num = 0
     get_user_weapons(id, weapons, num)
     
     for (i = 0; i < num; i++)
     {
          weaponid = weapons[i]
          
          if (dropwhat == 1 && ((1<<weaponid) & PRIMARY_WEAPONS_BIT_SUM))
          {
               static wname[32]
               get_weaponname(weaponid, wname, sizeof wname - 1)
               engclient_cmd(id, "drop", wname)
          }
     }
}