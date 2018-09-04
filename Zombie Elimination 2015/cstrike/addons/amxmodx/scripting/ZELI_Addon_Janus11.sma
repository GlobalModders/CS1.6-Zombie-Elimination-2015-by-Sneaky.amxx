#include <amxmodx>
#include <engine>
#include <fakemeta>
#include <fakemeta_util>
#include <fun>
#include <hamsandwich>
#include <xs>
#include <cstrike>
#include <zombie_eli>

#define ENG_NULLENT		-1
#define EV_INT_WEAPONKEY	EV_INT_impulse
#define JANUS11_WEAPONKEY 702453
#define IsValidUser(%1) (1 <= %1 <= g_MaxPlayers)

const USE_STOPPED = 0
const OFFSET_ACTIVE_ITEM = 373
const OFFSET_WEAPONOWNER = 41
const OFFSET_LINUX = 5
const OFFSET_LINUX_WEAPONS = 4

#if cellbits == 32
const OFFSET_CLIPAMMO = 51
#else
const OFFSET_CLIPAMMO = 65
#endif

#define WEAP_LINUX_XTRA_OFF		4
#define m_fKnown					44
#define m_flNextPrimaryAttack 		46
#define m_flNextSecondaryAttack 		47
#define m_flTimeWeaponIdle			48
#define m_iClip					51
#define m_fInReload				54
#define m_fInSpecialReload 			55
#define PLAYER_LINUX_XTRA_OFF	5
#define m_flNextAttack				83

#define JANUS11_SHOOT1		2
#define JANUS11_DRAW			6
#define JANUS11_RELOAD_AFTER	4

new gmsgWeaponList, sTrail

#define write_coord_f(%1)	engfunc(EngFunc_WriteCoord,%1)

new const Fire_Sounds[][] = { "weapons/janus11-1.wav", "weapons/janus11-1.wav", "weapons/janus11-1.wav"}

new JANUS11_V_MODEL[64] = "models/v_janus11.mdl"
new JANUS11_P_MODEL[64] = "models/p_janus11.mdl"
//new JANUS11_W_MODEL[64] = "models/w_janus11.mdl"
new const GRENADE_MODEL[] = "models/grenade.mdl"

new const GUNSHOT_DECALS[] = { 41, 42, 43, 44, 45 }

new g_Janus11, g_FrozenTech

new cvar_dmg1_janus11, cvar_dmg2_janus11, cvar_recoil_janus11, cvar_transform_janus11, cvar_clip_janus11, cvar_janus11_ammo, g_has_janus11[33], g_Ham_Bot, muzzle

new g_MaxPlayers, g_orig_event_janus11, g_IsInPrimaryAttack
new Float:cl_pushangle[33][3], m_iBlood[2]
new g_clip_ammo[33], oldweap[33], g_reload[33], janus11_mode[33], janus11_signal[33], Float:StartOrigin2[3]
const PRIMARY_WEAPONS_BIT_SUM = 
(1<<CSW_SCOUT)|(1<<CSW_XM1014)|(1<<CSW_MAC10)|(1<<CSW_AUG)|(1<<CSW_UMP45)|(1<<CSW_SG550)|(1<<CSW_GALIL)|(1<<CSW_FAMAS)|(1<<CSW_AWP)|(1<<
CSW_MP5NAVY)|(1<<CSW_M249)|(1<<CSW_M3)|(1<<CSW_M4A1)|(1<<CSW_TMP)|(1<<CSW_G3SG1)|(1<<CSW_SG552)|(1<<CSW_AK47)|(1<<CSW_P90)
new const WEAPONENTNAMES[][] = { "", "weapon_p228", "", "weapon_scout", "weapon_hegrenade", "weapon_xm1014", "weapon_c4", "weapon_mac10",
			"weapon_aug", "weapon_smokegrenade", "weapon_elite", "weapon_fiveseven", "weapon_ump45", "weapon_sg550",
			"weapon_mp5navy", "weapon_famas", "weapon_usp", "weapon_glock18", "weapon_awp", "weapon_mp5navy", "weapon_m249",
			"weapon_m3", "weapon_m4a1", "weapon_tmp", "weapon_g3sg1", "weapon_flashbang", "weapon_deagle", "weapon_sg552",
			"weapon_ak47", "weapon_knife", "weapon_p90" }

public plugin_init()
{
	register_plugin("Janus-11", "1.0", "m4m3ts")
	register_cvar("janus11_version", "m4m3ts", FCVAR_SERVER|FCVAR_SPONLY)
	register_event("CurWeapon","CurrentWeapon","be","1=1")
	RegisterHam(Ham_Item_AddToPlayer, "weapon_m3", "fw_JANUS11_AddToPlayer")
	RegisterHam(Ham_Use, "func_tank", "fw_UseStationary_Post", 1)
	RegisterHam(Ham_Use, "func_tankmortar", "fw_UseStationary_Post", 1)
	RegisterHam(Ham_Use, "func_tankrocket", "fw_UseStationary_Post", 1)
	RegisterHam(Ham_Use, "func_tanklaser", "fw_UseStationary_Post", 1)
	
	for (new i = 1; i < sizeof WEAPONENTNAMES; i++)
		if (WEAPONENTNAMES[i][0]) RegisterHam(Ham_Item_Deploy, WEAPONENTNAMES[i], "fw_Item_Deploy_Post", 1)
	
	RegisterHam(Ham_Weapon_PrimaryAttack, "weapon_m3", "fw_JANUS11_PrimaryAttack")
	RegisterHam(Ham_Weapon_PrimaryAttack, "weapon_m3", "fw_JANUS11_PrimaryAttack_Post", 1)
	RegisterHam(Ham_Weapon_Reload, "weapon_m3", "JANUS11_Reload")
	RegisterHam(Ham_Weapon_Reload, "weapon_m3", "JANUS11_Reload_Post", 1)
	RegisterHam(Ham_Weapon_WeaponIdle, "weapon_m3", "fw_janus11idleanim", 1)
	
	RegisterHam(Ham_Killed, "player", "fw_PlayerKilled")
	
	register_forward(FM_CmdStart, "fw_CmdStart")
	register_forward(FM_SetModel, "fw_SetModel")
	register_forward(FM_UpdateClientData, "fw_UpdateClientData_Post", 1)
	register_forward(FM_PlaybackEvent, "fwPlaybackEvent")
	
	gmsgWeaponList = get_user_msgid("WeaponList")
	
	RegisterHam(Ham_TraceAttack, "player", "fw_TraceAttack")
	RegisterHam(Ham_TraceAttack, "worldspawn", "fw_TraceAttack", 1)
	RegisterHam(Ham_TraceAttack, "func_breakable", "fw_TraceAttack", 1)
	RegisterHam(Ham_TraceAttack, "func_wall", "fw_TraceAttack", 1)
	RegisterHam(Ham_TraceAttack, "func_door", "fw_TraceAttack", 1)
	RegisterHam(Ham_TraceAttack, "func_door_rotating", "fw_TraceAttack", 1)
	RegisterHam(Ham_TraceAttack, "func_plat", "fw_TraceAttack", 1)
	RegisterHam(Ham_TraceAttack, "func_rotating", "fw_TraceAttack", 1)

	RegisterHam(Ham_TakeDamage, "player", "fw_TakeDamage")
	
	cvar_recoil_janus11 = register_cvar("janus11_recoil", "0.65")           
	cvar_clip_janus11 = register_cvar("janus11_clip", "15")
	cvar_janus11_ammo = register_cvar("janus11_ammo", "64")
	cvar_dmg1_janus11 = register_cvar("janus11_dmg1", "15.0")
	cvar_dmg2_janus11 = register_cvar("janus11_dmg2", "30.0")
	cvar_transform_janus11 = register_cvar("janus11_transform", "15")
	
	register_clcmd("get_janus1111", "give_janus11", ADMIN_KICK)
	
	g_MaxPlayers = get_maxplayers()
	
	g_FrozenTech = ZombieEli_GetClassID("Frozen Tech")
	g_Janus11 = ZombieEli_RegisterWeapon(g_FrozenTech, "CSO Janus-11", WPN_PRIMARY, 4, 0)
}

public plugin_precache()
{
	precache_model(JANUS11_V_MODEL)
	precache_model(JANUS11_P_MODEL)
	//precache_model(JANUS11_W_MODEL)
	for(new i = 0; i < sizeof Fire_Sounds; i++)
		precache_sound(Fire_Sounds[i])	
		
	precache_model(GRENADE_MODEL)
	sTrail = precache_model("sprites/laserbeam.spr")
	muzzle = engfunc(EngFunc_PrecacheModel, "sprites/smokepuff.spr")
	
	precache_sound("weapons/janus11_after_reload.wav")
	precache_sound("weapons/janus11_change1.wav")
	precache_sound("weapons/janus11_change2.wav")
	precache_sound("weapons/janus11_draw.wav")
	precache_sound("weapons/janus11_insert.wav")
	precache_sound("weapons/janus11-4.wav")
	precache_sound("weapons/uts15_reload.wav")
	
	precache_generic("sprites/weapon_janus11.txt")
	
	precache_generic("sprites/640hud107.spr")
	precache_generic("sprites/640hud13.spr")
		
	register_clcmd("weapon_janus11", "weapon_hook")	
					
	m_iBlood[0] = precache_model("sprites/blood.spr")
	m_iBlood[1] = precache_model("sprites/bloodspray.spr")

	register_forward(FM_PrecacheEvent, "fwPrecacheEvent_Post", 1)
}

public zeli_weapon_selected(id, ItemID, ClassID)
{
	if(ItemID == g_Janus11) give_janus11(id)
}

public zeli_weapon_removed(id, ItemID)
{
	if(ItemID == g_Janus11) Remove_Janus11(id)
}


public weapon_hook(id)
{
	engclient_cmd(id, "weapon_m3")
	return PLUGIN_HANDLED
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
	RegisterHamFromEntity(Ham_TraceAttack, id, "fw_TraceAttack", 1)
	RegisterHamFromEntity(Ham_TraceAttack, id, "fw_TraceAttack")
}


public nyala(id)
{
	janus11_mode[id] = 2
}

public Remove_Janus11(id)
{
	g_has_janus11[id] = false
}

public fw_PlayerKilled(id)
{
	g_has_janus11[id] = false
}

public fw_TraceAttack(iEnt, iAttacker, Float:flDamage, Float:fDir[3], ptr, iDamageType)
{
	if(!is_user_alive(iAttacker))
		return

	new g_currentweapon = get_user_weapon(iAttacker)

	if(g_currentweapon != CSW_M3 || !g_has_janus11[iAttacker])
		return
	
	if(janus11_mode[iAttacker] == 3) SetHamParamFloat(3, get_pcvar_float(cvar_dmg2_janus11))
	else SetHamParamFloat(3, get_pcvar_float(cvar_dmg1_janus11))
	
	
	static Float:flEnd[3]
	get_tr2(ptr, TR_vecEndPos, flEnd)
		
	if(!is_user_alive(iEnt))
	{
		message_begin(MSG_BROADCAST, SVC_TEMPENTITY)
		write_byte(TE_DECAL)
		write_coord_f(flEnd[0])
		write_coord_f(flEnd[1])
		write_coord_f(flEnd[2])
		write_byte(GUNSHOT_DECALS[random_num (0, sizeof GUNSHOT_DECALS -1)])
		write_short(iEnt)
		message_end()

		message_begin(MSG_BROADCAST, SVC_TEMPENTITY)
		write_byte(TE_WORLDDECAL)
		write_coord_f(flEnd[0])
		write_coord_f(flEnd[1])
		write_coord_f(flEnd[2])
		write_byte(GUNSHOT_DECALS[random_num (0, sizeof GUNSHOT_DECALS -1)])
		message_end()
		
		message_begin(MSG_BROADCAST, SVC_TEMPENTITY)
		write_byte(TE_GUNSHOTDECAL)
		write_coord_f(flEnd[0])
		write_coord_f(flEnd[1])
		write_coord_f(flEnd[2])
		write_short(iAttacker)
		write_byte(GUNSHOT_DECALS[random_num (0, sizeof GUNSHOT_DECALS -1)])
		message_end()
	}
	
	if(janus11_mode[iAttacker] == 3)
	{
		get_position(iAttacker, 20.0, 5.0, 5.0, StartOrigin2)
		
		message_begin(MSG_BROADCAST, SVC_TEMPENTITY)
		write_byte(TE_BEAMPOINTS)
		engfunc(EngFunc_WriteCoord, StartOrigin2[0])
		engfunc(EngFunc_WriteCoord, StartOrigin2[1])
		engfunc(EngFunc_WriteCoord, StartOrigin2[2] - 10.0)
		engfunc(EngFunc_WriteCoord, flEnd[0])
		engfunc(EngFunc_WriteCoord, flEnd[1])
		engfunc(EngFunc_WriteCoord, flEnd[2])
		write_short(sTrail)
		write_byte(0) // start frame
		write_byte(0) // framerate
		write_byte(5) // life
		write_byte(5) // line width
		write_byte(0) // amplitude
		write_byte(220)
		write_byte(88)
		write_byte(0) // blue
		write_byte(255) // brightness
		write_byte(0) // speed
		message_end()
	}
}

public fwPrecacheEvent_Post(type, const name[])
{
	if (equal("events/m3.sc", name))
	{
		g_orig_event_janus11 = get_orig_retval()
		return FMRES_HANDLED
	}
	return FMRES_IGNORED
}

public client_connect(id)
{
	g_has_janus11[id] = false
}

public client_disconnect(id)
{
	g_has_janus11[id] = false
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
	
	if(equal(model, "models/w_m3.mdl"))
	{
		static iStoredAugID
		
		iStoredAugID = find_ent_by_owner(ENG_NULLENT, "weapon_m3", entity)
	
		if(!is_valid_ent(iStoredAugID))
			return FMRES_IGNORED
	
		if(g_has_janus11[iOwner])
		{
			entity_set_int(iStoredAugID, EV_INT_WEAPONKEY, JANUS11_WEAPONKEY)
			
			g_has_janus11[iOwner] = false
			
			//entity_set_model(entity, JANUS11_W_MODEL)
			
			return FMRES_SUPERCEDE
		}
	}
	return FMRES_IGNORED
}

public give_janus11(id)
{
	drop_weapons(id, 1)
	new iWep2 = give_item(id,"weapon_m3")
	if( iWep2 > 0 )
	{
		cs_set_weapon_ammo(iWep2, get_pcvar_num(cvar_clip_janus11))
		cs_set_user_bpammo (id, CSW_M3, get_pcvar_num(cvar_janus11_ammo))
		UTIL_PlayWeaponAnimation(id, JANUS11_DRAW)
		set_weapons_timeidle(id, CSW_M3, 1.0)
		set_player_nextattackx(id, 1.0)
	}
	g_has_janus11[id] = true
	janus11_mode[id] = 1
	janus11_signal[id] = 0
	message_begin(MSG_ONE, gmsgWeaponList, {0,0,0}, id)
	write_string("weapon_janus11")
	write_byte(5)
	write_byte(32)
	write_byte(-1)
	write_byte(-1)
	write_byte(0)
	write_byte(5)
	write_byte(21)
	write_byte(0)
	message_end()
}

public fw_TakeDamage(victim, inflictor, attacker, Float:damage)
{
	if (victim != attacker && is_user_connected(attacker))
	{
		if(get_user_weapon(attacker) == CSW_M3)
		{
			if(g_has_janus11[attacker])
			{
				if(janus11_mode[attacker] != 3)
				{
					janus11_signal[attacker] ++
				}
			}
		}
	}
}

public fw_JANUS11_AddToPlayer(janus11, id)
{
	if(!is_valid_ent(janus11) || !is_user_connected(id))
		return HAM_IGNORED
	
	if(entity_get_int(janus11, EV_INT_WEAPONKEY) == JANUS11_WEAPONKEY)
	{
		g_has_janus11[id] = true
		
		message_begin(MSG_ONE, gmsgWeaponList, {0,0,0}, id)
		write_string("weapon_janus11")
		write_byte(5)
		write_byte(32)
		write_byte(-1)
		write_byte(-1)
		write_byte(0)
		write_byte(5)
		write_byte(21)
		write_byte(0)
		message_end()
		
		entity_set_int(janus11, EV_INT_WEAPONKEY, 0)

		return HAM_HANDLED
	}
	return HAM_IGNORED
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
	if( read_data(2) != CSW_M3 ) {
		if( g_reload[id] ) {
			g_reload[id] = 0
			remove_task( id + 1331 )
		}
	}
	replace_weapon_models(id, read_data(2))
}

replace_weapon_models(id, weaponid)
{
	switch (weaponid)
	{
		case CSW_M3:
		{
			if(g_has_janus11[id])
			{
				set_pev(id, pev_viewmodel2, JANUS11_V_MODEL)
				set_pev(id, pev_weaponmodel2, JANUS11_P_MODEL)
				if(oldweap[id] != CSW_M3) 
				{
					if(janus11_mode[id] == 1) UTIL_PlayWeaponAnimation(id, JANUS11_DRAW)
					if(janus11_mode[id] == 2) UTIL_PlayWeaponAnimation(id, 16)
					if(janus11_mode[id] == 3) UTIL_PlayWeaponAnimation(id, 9)
					set_weapons_timeidle(id, CSW_M3, 1.0)
					set_player_nextattackx(id, 1.0)

					message_begin(MSG_ONE, gmsgWeaponList, {0,0,0}, id)
					write_string("weapon_janus11")
					write_byte(5)
					write_byte(32)
					write_byte(-1)
					write_byte(-1)
					write_byte(0)
					write_byte(5)
					write_byte(CSW_M3)
					message_end()
				}
			}
		}
	}
	oldweap[id] = weaponid
}

public fw_UpdateClientData_Post(Player, SendWeapons, CD_Handle)
{
	if(!is_user_alive(Player) || get_user_weapon(Player) != CSW_M3 || !g_has_janus11[Player])
		return FMRES_IGNORED
	
	set_cd(CD_Handle, CD_flNextAttack, halflife_time () + 0.001)
	return FMRES_HANDLED
}

public fw_JANUS11_PrimaryAttack(Weapon)
{
	new Player = get_pdata_cbase(Weapon, 41, 4)
	
	if (!g_has_janus11[Player])
		return
	
	g_IsInPrimaryAttack = 1
	pev(Player,pev_punchangle,cl_pushangle[Player])
	
	g_clip_ammo[Player] = cs_get_weapon_ammo(Weapon)
	if(janus11_mode[Player] != 3 && g_clip_ammo[Player]) mujel(Player)
}

public fw_JANUS11_PrimaryAttack_Post(Weapon)
{
	g_IsInPrimaryAttack = 0
	new Player = get_pdata_cbase(Weapon, 41, 4)
	
	new szClip, szAmmo
	get_user_weapon(Player, szClip, szAmmo)
	
	if(!is_user_alive(Player))
		return

	if(g_has_janus11[Player] && janus11_mode[Player] != 3)
	{
		if (!g_clip_ammo[Player])
			return
			
		g_reload[Player] = 0
		remove_task( Player + 1331 )
		new Float:push[3]
		pev(Player,pev_punchangle,push)
		xs_vec_sub(push,cl_pushangle[Player],push)
		
		xs_vec_mul_scalar(push,get_pcvar_float(cvar_recoil_janus11),push)
		xs_vec_add(push,cl_pushangle[Player],push)
		set_pev(Player,pev_punchangle,push)
		
		emit_sound(Player, CHAN_WEAPON, Fire_Sounds[random( sizeof(Fire_Sounds))], VOL_NORM, ATTN_NORM, 0, PITCH_NORM)
		
		if(janus11_signal[Player] >= get_pcvar_num(cvar_transform_janus11))
		{
			janus11_mode[Player] = 2
		}
		
		if(janus11_mode[Player] == 2) UTIL_PlayWeaponAnimation(Player, 15)
		else UTIL_PlayWeaponAnimation(Player, JANUS11_SHOOT1)
		
		set_weapons_timeidle(Player, CSW_M3, 0.7)
		set_player_nextattackx(Player, 0.7)
	}
	else
	{
		if(!g_has_janus11[Player])
			return
		
		new Float:push[3]
		pev(Player,pev_punchangle,push)
		xs_vec_sub(push,cl_pushangle[Player],push)
		
		xs_vec_mul_scalar(push,get_pcvar_float(cvar_recoil_janus11),push)
		xs_vec_add(push,cl_pushangle[Player],push)
		set_pev(Player,pev_punchangle,push)
		
		emit_sound(Player, CHAN_WEAPON, "weapons/janus11-4.wav", VOL_NORM, ATTN_NORM, 0, PITCH_NORM)
		
		fm_set_weapon_ammo(Weapon, szClip++)
		set_weapons_timeidle(Player, CSW_M3, 0.45)
		set_player_nextattackx(Player, 0.45)
		UTIL_PlayWeaponAnimation(Player, 8)
	}
}

public fw_CmdStart(id, uc_handle, seed) 
{
	new ammo, clip, weapon = get_user_weapon(id, clip, ammo)
	if (!g_has_janus11[id] || weapon != CSW_M3 || !is_user_alive(id))
		return
	
	static CurButton
	CurButton = get_uc(uc_handle, UC_Buttons)
	
	if(CurButton & IN_ATTACK)
	{
		new wpn = fm_get_user_weapon_entity(id, get_user_weapon(id))
		
		new Id = pev( wpn, pev_owner ), clip, bpammo
		get_user_weapon( Id, clip, bpammo )
		if( g_has_janus11[ Id ] ) {
		if( clip >= 2 ) {
			if( g_reload[Id] ) {
				remove_task( Id + 1331 )
				g_reload[Id] = 0
				UTIL_PlayWeaponAnimation(Id,JANUS11_SHOOT1)
				emit_sound(Id, CHAN_WEAPON, Fire_Sounds[random( sizeof(Fire_Sounds))], VOL_NORM, ATTN_NORM, 0, PITCH_NORM)
				push(id)
				set_weapons_timeidle(id, CSW_M3, 0.7)
				set_player_nextattackx(id, 0.7)
				
				ExecuteHamB(Ham_Weapon_PrimaryAttack, wpn)
			}
		}
		else if( clip == 1 )
		{
			if(get_pdata_float(Id, 83, 4) <= 0.3)
			{
				if( g_reload[Id] ) {
				remove_task( Id + 1331 )
				g_reload[Id] = 0
				UTIL_PlayWeaponAnimation(Id,JANUS11_SHOOT1)
				emit_sound(Id, CHAN_WEAPON, Fire_Sounds[random( sizeof(Fire_Sounds))], VOL_NORM, ATTN_NORM, 0, PITCH_NORM)
				push(id)
				set_weapons_timeidle(id, CSW_M3, 0.7)
				set_player_nextattackx(id, 0.7)
				
				ExecuteHamB(Ham_Weapon_PrimaryAttack, wpn)
			}
			}
		}
	}
	}
	
	else if(CurButton & IN_ATTACK2)
	{
		if(janus11_mode[id] == 2 && get_pdata_float(id, 83, 5) <= 0.0)
		{
			new clip, bpammo, weapon = find_ent_by_owner( -1, "weapon_m3", id )
			get_user_weapon(id, clip, bpammo )
			
			if(clip == 0) cs_set_weapon_ammo( weapon, 1 )
			
			remove_task(id)
			remove_task( id + 1331 )
			g_reload[id] = 0
			UTIL_PlayWeaponAnimation(id, 1)
			janus11_mode[id] = 3
			set_weapons_timeidle(id, CSW_M3, 1.7)
			set_player_nextattackx(id, 1.7)
			set_task(7.4, "back_normal", id)
			set_task(7.4, "back_normal2", id)
		}
	}
}

public mujel(id)
{
	static Float:Origin[3], TE_FLAG
	get_position(id, 32.0, 6.0, -15.0, Origin)
	
	TE_FLAG |= TE_EXPLFLAG_NODLIGHTS
	TE_FLAG |= TE_EXPLFLAG_NOSOUND
	TE_FLAG |= TE_EXPLFLAG_NOPARTICLES
	
	engfunc(EngFunc_MessageBegin, MSG_ONE_UNRELIABLE, SVC_TEMPENTITY, Origin, id)
	write_byte(TE_EXPLOSION)
	engfunc(EngFunc_WriteCoord, Origin[0])
	engfunc(EngFunc_WriteCoord, Origin[1])
	engfunc(EngFunc_WriteCoord, Origin[2])
	write_short(muzzle)
	write_byte(6)
	write_byte(40)
	write_byte(TE_FLAG)
	message_end()
}

public back_normal(id)
{
	if(get_user_weapon(id) != CSW_M3 || !g_has_janus11[id])
		return
		
	UTIL_PlayWeaponAnimation(id, 10)
	set_weapons_timeidle(id, CSW_M3, 1.4)
	set_player_nextattackx(id, 1.4)
}

public back_normal2(id)
{
	janus11_mode[id] = 1
	janus11_signal[id] = 0
}

public fw_janus11idleanim(Weapon)
{
	new id = get_pdata_cbase(Weapon, 41, 4)

	if(!is_user_alive(id) || !g_has_janus11[id] || get_user_weapon(id) != CSW_M3)
		return HAM_IGNORED;
	
	if(janus11_mode[id] == 1 && get_pdata_float(Weapon, 48, 4) <= 0.25)
	{
		UTIL_PlayWeaponAnimation(id, 0)
		set_pdata_float(Weapon, 48, 20.0, 4)
		return HAM_SUPERCEDE;
	}
	
	if(janus11_mode[id] == 3 && get_pdata_float(Weapon, 48, 4) <= 0.25)
	{
		UTIL_PlayWeaponAnimation(id, 7)
		set_pdata_float(Weapon, 48, 20.0, 4)
		return HAM_SUPERCEDE;
	}
	
	if(janus11_mode[id] == 2 && get_pdata_float(Weapon, 48, 4) <= 0.25) 
	{
		UTIL_PlayWeaponAnimation(id, 11)
		set_pdata_float(Weapon, 48, 20.0, 4)
		return HAM_SUPERCEDE;
	}

	return HAM_IGNORED;
}

public push(id)
{
    static Float:vektor[3]
    vektor[0] = -3.0
    vektor[1] = 0.0
    vektor[2] = 0.0    
    
    set_pev(id, pev_punchangle, vektor)        
}

public fwPlaybackEvent(flags, invoker, eventid, Float:delay, Float:origin[3], Float:angles[3], Float:fparam1, Float:fparam2, iParam1, iParam2, bParam1, bParam2)
{
	if ((eventid != g_orig_event_janus11) || !g_IsInPrimaryAttack)
		return FMRES_IGNORED
		
	if (!(1 <= invoker <= g_MaxPlayers))
		return FMRES_IGNORED

	playback_event(flags | FEV_HOSTONLY, invoker, eventid, delay, origin, angles, fparam1, fparam2, iParam1, iParam2, bParam1, bParam2)
	return FMRES_SUPERCEDE
}

public JANUS11_Reload( wpn ) {
	if(janus11_mode[pev( wpn, pev_owner )] == 3)
	      return HAM_SUPERCEDE
		  
	if( g_has_janus11[ pev( wpn, pev_owner ) ] ) {
		JANUS11_Reload_Post( wpn )
		return HAM_SUPERCEDE
	}
	return HAM_IGNORED
}

public JANUS11_Reload_Post(weapon) {
	new id = pev( weapon, pev_owner )
	if(janus11_mode[id] == 3)
	      return HAM_SUPERCEDE
	new clip, bpammo
	get_user_weapon(id, clip, bpammo )
	if( g_has_janus11[ id ] && clip < get_pcvar_num(cvar_clip_janus11) && bpammo > 0 ) {
		if(!task_exists( id+1331 )) set_task( 0.1, "reload", id+1331 )
		}
	return HAM_IGNORED
}

public reload( id ) {
	id -= 1331
	new clip, bpammo, weapon = find_ent_by_owner( -1, "weapon_m3", id )
	get_user_weapon(id, clip, bpammo )
	if(!g_reload[id]) {
			UTIL_PlayWeaponAnimation( id, 5 )
			if(janus11_mode[id] == 2) UTIL_PlayWeaponAnimation(id, 14)
			else UTIL_PlayWeaponAnimation(id, 5)
			g_reload[id] = 1
			set_reload_timeidle(id, CSW_M3, 0.2)
			set_task( 0.5, "reload", id+1331 )
			return
	}
	
	if( clip > get_pcvar_num(cvar_clip_janus11)-1 || bpammo < 1 ) {
		if(janus11_mode[id] == 2) UTIL_PlayWeaponAnimation(id, 13)
		else UTIL_PlayWeaponAnimation(id, 4)
		g_reload[id] = 0
		set_reload_timeidle(id, CSW_M3, 0.9)
		return
	}
	cs_set_user_bpammo( id, CSW_M3, bpammo - 1 )
	cs_set_weapon_ammo( weapon, clip + 1 )
	set_reload_timeidle(id, CSW_M3, 0.6)
	if(janus11_mode[id] == 2) UTIL_PlayWeaponAnimation(id, 12)
	else UTIL_PlayWeaponAnimation(id, 3)
	set_task( 0.4, "reload", id+1331 )
	emit_sound(id, CHAN_WEAPON, "weapons/uts15_reload.wav", VOL_NORM, ATTN_NORM, 0, PITCH_NORM)
}

stock fm_cs_get_current_weapon_ent(id)
{
	return get_pdata_cbase(id, OFFSET_ACTIVE_ITEM, OFFSET_LINUX)
}

stock fm_set_weapon_ammo(entity, amount)
{
	set_pdata_int(entity, OFFSET_CLIPAMMO, amount, OFFSET_LINUX_WEAPONS);
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

stock set_player_nextattackx(id, Float:nexttime)
{
	if(!is_user_alive(id))
		return
		
	set_pdata_float(id, m_flNextAttack, nexttime, 5)
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

stock set_weapons_timeidle(id, WeaponId ,Float:TimeIdle)
{
	if(!is_user_alive(id))
		return
		
	static entwpn; entwpn = fm_get_user_weapon_entity(id, WeaponId)
	if(!pev_valid(entwpn)) 
		return
		
	set_pdata_float(entwpn, 46, TimeIdle, WEAP_LINUX_XTRA_OFF)
	set_pdata_float(entwpn, 47, TimeIdle, WEAP_LINUX_XTRA_OFF)
	set_pdata_float(entwpn, 48, TimeIdle + 1.0, WEAP_LINUX_XTRA_OFF)
}

stock set_reload_timeidle(id, WeaponId ,Float:TimeIdle)
{
	if(!is_user_alive(id))
		return
		
	static entwpn; entwpn = fm_get_user_weapon_entity(id, WeaponId)
	if(!pev_valid(entwpn)) 
		return
		
	set_pdata_float(entwpn, 48, TimeIdle + 1.0, WEAP_LINUX_XTRA_OFF)
}

stock get_speed_vector(const Float:origin1[3],const Float:origin2[3],Float:speed, Float:new_velocity[3])
{
	new_velocity[0] = origin2[0] - origin1[0]
	new_velocity[1] = origin2[1] - origin1[1]
	new_velocity[2] = origin2[2] - origin1[2]
	new Float:num = floatsqroot(speed*speed / (new_velocity[0]*new_velocity[0] + new_velocity[1]*new_velocity[1] + new_velocity[2]*new_velocity[2]))
	new_velocity[0] *= num
	new_velocity[1] *= num
	new_velocity[2] *= num
	
	return 1;
}

stock get_position(id,Float:forw, Float:right, Float:up, Float:vStart[])
{
	static Float:vOrigin[3], Float:vAngle[3], Float:vForward[3], Float:vRight[3], Float:vUp[3]
	
	pev(id, pev_origin, vOrigin)
	pev(id, pev_view_ofs, vUp) //for player
	xs_vec_add(vOrigin, vUp, vOrigin)
	pev(id, pev_v_angle, vAngle) // if normal entity ,use pev_angles
	
	angle_vector(vAngle,ANGLEVECTOR_FORWARD, vForward) //or use EngFunc_AngleVectors
	angle_vector(vAngle,ANGLEVECTOR_RIGHT, vRight)
	angle_vector(vAngle,ANGLEVECTOR_UP, vUp)
	
	vStart[0] = vOrigin[0] + vForward[0] * forw + vRight[0] * right + vUp[0] * up
	vStart[1] = vOrigin[1] + vForward[1] * forw + vRight[1] * right + vUp[1] * up
	vStart[2] = vOrigin[2] + vForward[2] * forw + vRight[2] * right + vUp[2] * up
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