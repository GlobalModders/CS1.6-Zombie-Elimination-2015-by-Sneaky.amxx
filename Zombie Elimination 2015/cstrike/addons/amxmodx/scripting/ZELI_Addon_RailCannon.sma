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
#define RAILCANNON_WEAPONKEY 756144798
#define IsValidUser(%1) (1 <= %1 <= g_MaxPlayers)

#define SMOKE_CLASS "smokess"

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

#define RAILCANNON_DRAW			7

#define TASK_SOUND 2573+10
#define TASK_SETRUM2 2573+20

new gmsgWeaponList, sTrail

#define write_coord_f(%1)	engfunc(EngFunc_WriteCoord,%1)

new const Fire_Sounds[] = "weapons/railcanon-1.wav"
new const MuzzleFlash[] = "sprites/muzzleflash19.spr"

//////////// Change Here For Customize //////////////////////////

const Float:cvar_recoil_railcannon = 0.65
const cvar_clip_railcannon = 24
const cvar_railcannon_ammo = 90

const Float:damage_mode1 = 5.0
const Float:damage_mode2 = 8.0
const Float:damage_mode3 = 15.0

/////////////////////////////////////////////////////////////////

new RAILCANNON_V_MODEL[64] = "models/v_railcannon.mdl"
new RAILCANNON_P_MODEL[64] = "models/p_railcannon.mdl"
//new RAILCANNON_W_MODEL[64] = "models/w_railcannon.mdl"

new const GUNSHOT_DECALS[] = { 41, 42, 43, 44, 45 }

new g_has_railcannon[33], g_Ham_Bot

new g_RailCannon, g_FrozenTech

new g_MaxPlayers, g_orig_event_railcannon, g_IsInPrimaryAttack, g_MuzzleFlash_SprId
new Float:cl_pushangle[33][3], m_iBlood[2], zz[33], udah[33]
new g_clip_ammo[33], oldweap[33], g_reload[33], railcannon_mode[33], Float:StartOrigin2[3], g_SpecialAmmo[33]
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
	register_plugin("Rail Cannon", "1.0", "m4m3ts")
	register_cvar("rail_version", "m4m3ts", FCVAR_SERVER|FCVAR_SPONLY)
	register_event("CurWeapon","CurrentWeapon","be","1=1")
	register_think(SMOKE_CLASS, "fw_Fire_smoke")
	RegisterHam(Ham_Item_AddToPlayer, "weapon_m3", "fw_RAILCANNON_AddToPlayer")
	RegisterHam(Ham_Use, "func_tank", "fw_UseStationary_Post", 1)
	RegisterHam(Ham_Use, "func_tankmortar", "fw_UseStationary_Post", 1)
	RegisterHam(Ham_Use, "func_tankrocket", "fw_UseStationary_Post", 1)
	RegisterHam(Ham_Use, "func_tanklaser", "fw_UseStationary_Post", 1)
	
	for (new i = 1; i < sizeof WEAPONENTNAMES; i++)
		if (WEAPONENTNAMES[i][0]) RegisterHam(Ham_Item_Deploy, WEAPONENTNAMES[i], "fw_Item_Deploy_Post", 1)
	
	RegisterHam(Ham_Weapon_PrimaryAttack, "weapon_m3", "fw_RAIL_PrimaryAttack")
	RegisterHam(Ham_Weapon_PrimaryAttack, "weapon_m3", "fw_RAIL_PrimaryAttack_Post", 1)
	RegisterHam(Ham_Weapon_Reload, "weapon_m3", "RAILCANNON_Reload")
	RegisterHam(Ham_Weapon_Reload, "weapon_m3", "RAILCANNON_Reload_Post", 1)
	RegisterHam(Ham_Weapon_WeaponIdle, "weapon_m3", "fw_railcannonidleanim", 1)
	
	RegisterHam(Ham_Killed, "player", "fw_PlayerKilled")
	
	register_forward(FM_CmdStart, "fw_CmdStart")
	register_forward(FM_SetModel, "fw_SetModel")
	register_forward(FM_UpdateClientData, "fw_UpdateClientData_Post", 1)
	register_forward(FM_PlaybackEvent, "fwPlaybackEvent")
	register_forward(FM_TraceLine,"fw_traceline",1)
	
	gmsgWeaponList = get_user_msgid("WeaponList")
	
	RegisterHam(Ham_TraceAttack, "player", "fw_TraceAttack")
	RegisterHam(Ham_TraceAttack, "worldspawn", "fw_TraceAttack", 1)
	RegisterHam(Ham_TraceAttack, "func_breakable", "fw_TraceAttack", 1)
	RegisterHam(Ham_TraceAttack, "func_wall", "fw_TraceAttack", 1)
	RegisterHam(Ham_TraceAttack, "func_door", "fw_TraceAttack", 1)
	RegisterHam(Ham_TraceAttack, "func_door_rotating", "fw_TraceAttack", 1)
	RegisterHam(Ham_TraceAttack, "func_plat", "fw_TraceAttack", 1)
	RegisterHam(Ham_TraceAttack, "func_rotating", "fw_TraceAttack", 1)
	
	register_clcmd("get_railcannon", "give_railcannon", ADMIN_KICK)
	g_MaxPlayers = get_maxplayers()
	
	g_FrozenTech = ZombieEli_GetClassID("Frozen Tech")
	g_RailCannon = ZombieEli_RegisterWeapon(g_FrozenTech, "CSO Rail Cannon", WPN_PRIMARY, 4, 0)
	
}

public plugin_precache()
{
	precache_model(RAILCANNON_V_MODEL)
	precache_model(RAILCANNON_P_MODEL)
	//precache_model(RAILCANNON_W_MODEL)
	precache_sound(Fire_Sounds)	
		
	sTrail = precache_model("sprites/laserbeam.spr")
	
	precache_sound("weapons/railcanon_clipin.wav")
	precache_sound("weapons/railcanon_chage1_start.wav")
	precache_sound("weapons/railcanon_chage3_loop.wav")
	precache_sound("weapons/railcanon_draw.wav")
	precache_sound("weapons/railcanon_clipout.wav")
	precache_sound("weapons/railcanon-2.wav")
	
	g_MuzzleFlash_SprId = engfunc(EngFunc_PrecacheModel, MuzzleFlash)
	precache_generic("sprites/weapon_railcannon.txt")
	
	precache_generic("sprites/640hud112.spr")
	precache_generic("sprites/640hud13.spr")
		
	register_clcmd("weapon_railcannon", "weapon_hook")	
					
	m_iBlood[0] = precache_model("sprites/blood.spr")
	m_iBlood[1] = precache_model("sprites/bloodspray.spr")
	precache_model("sprites/wall_puff1.spr")

	register_forward(FM_PrecacheEvent, "fwPrecacheEvent_Post", 1)
}

public zeli_weapon_selected(id, ItemID, ClassID)
{
	if(ItemID == g_RailCannon) give_railcannon(id)
}

public zeli_weapon_removed(id, ItemID)
{
	if(ItemID == g_RailCannon) Remove_RailCannon(id)
}

public Remove_RailCannon(id)
{
	g_has_railcannon[id] = false
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
	RegisterHamFromEntity(Ham_TraceAttack, id, "fw_TraceAttack", 1)
	RegisterHamFromEntity(Ham_TraceAttack, id, "fw_TraceAttack")
}

public fw_PlayerKilled(id)
{
	g_has_railcannon[id] = false
}

public fw_TraceAttack(iEnt, iAttacker, Float:flDamage, Float:fDir[3], ptr, iDamageType)
{
	if(!is_user_alive(iAttacker))
		return

	new g_currentweapon = get_user_weapon(iAttacker)

	if(g_currentweapon != CSW_M3 || !g_has_railcannon[iAttacker])
		return
	
	if(railcannon_mode[iAttacker] == 3) SetHamParamFloat(3, damage_mode3)
	if(railcannon_mode[iAttacker] == 2) SetHamParamFloat(3, damage_mode2)
	if(railcannon_mode[iAttacker] == 1) SetHamParamFloat(3, damage_mode1)
	
	static Float:flEnd[3], Float:test[3], Float:myOrigin[3]
	
	pev(iAttacker, pev_origin, myOrigin)
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
		
		fm_get_aim_origin(iAttacker, test)
		if(railcannon_mode[iAttacker] == 3) fake_smokes(iAttacker, test)
	}
	
	if(railcannon_mode[iAttacker] == 2)
	{
		get_position(iAttacker, 20.0, 0.0, 10.0, StartOrigin2)
		
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
	
	if(railcannon_mode[iAttacker] == 3)
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
		write_byte(8) // life
		write_byte(8) // line width
		write_byte(0) // amplitude
		write_byte(220)
		write_byte(88)
		write_byte(0) // blue
		write_byte(50) // brightness
		write_byte(0) // speed
		message_end()	
	}
	
}

public fake_smokes(id, Float:Origin[3])
{
	new ent_test; ent_test = engfunc(EngFunc_CreateNamedEntity, engfunc(EngFunc_AllocString, "env_sprite"))
	
	engfunc(EngFunc_SetModel, ent_test, "sprites/wall_puff1.spr")
	entity_set_string(ent_test, EV_SZ_classname, SMOKE_CLASS)
	set_pev(ent_test, pev_nextthink, get_gametime() + 0.04)
	set_pev(ent_test, pev_movetype, MOVETYPE_NONE)
	set_pev(ent_test, pev_rendermode, kRenderTransAdd)
	set_pev(ent_test, pev_renderamt, 20.0)
	set_pev(ent_test, pev_scale, 1.0)
	set_pev(ent_test, pev_origin, Origin)
	set_pev(ent_test, pev_frame, 0.0)
	set_pev(ent_test, pev_iuser2, get_user_team(id))

	set_pev(ent_test, pev_solid, SOLID_NOT)
	dllfunc(DLLFunc_Spawn, ent_test)
}

public fw_Fire_smoke(iEnt)
{
	if(!pev_valid(iEnt)) 
		return
	
	new Float:fFrame
	pev(iEnt, pev_frame, fFrame)

	// effect exp
	fFrame += 1.0

	set_pev(iEnt, pev_frame, fFrame)
	set_pev(iEnt, pev_scale, 1.0)
	set_pev(iEnt, pev_nextthink, get_gametime() + 0.02)
	
	if(fFrame > 30.0) engfunc(EngFunc_RemoveEntity, iEnt)
}

public fw_traceline(Float:v1[3],Float:v2[3],noMonsters,id,ptr)
{
	if(!is_user_alive(id))
		return HAM_IGNORED	
	if(get_user_weapon(id) != CSW_M3 || !g_has_railcannon[id])
		return HAM_IGNORED
	if(railcannon_mode[id] != 3)
		return HAM_IGNORED
	
	// get crosshair aim
	static Float:aim[3];
	get_aim(id,v1,aim);
	
	// do another trace to this spot
	new trace = create_tr2();
	engfunc(EngFunc_TraceLine,v1,aim,noMonsters,id,trace);
	
	// copy ints
	set_tr2(ptr,TR_AllSolid,get_tr2(trace,TR_AllSolid));
	set_tr2(ptr,TR_StartSolid,get_tr2(trace,TR_StartSolid));
	set_tr2(ptr,TR_InOpen,get_tr2(trace,TR_InOpen));
	set_tr2(ptr,TR_InWater,get_tr2(trace,TR_InWater));
	set_tr2(ptr,TR_pHit,get_tr2(trace,TR_pHit));
	set_tr2(ptr,TR_iHitgroup,get_tr2(trace,TR_iHitgroup));

	// copy floats
	get_tr2(trace,TR_flFraction,aim[0]);
	set_tr2(ptr,TR_flFraction,aim[0]);
	get_tr2(trace,TR_flPlaneDist,aim[0]);
	set_tr2(ptr,TR_flPlaneDist,aim[0]);
	
	// copy vecs
	get_tr2(trace,TR_vecEndPos,aim);
	set_tr2(ptr,TR_vecEndPos,aim);
	get_tr2(trace,TR_vecPlaneNormal,aim);
	set_tr2(ptr,TR_vecPlaneNormal,aim);

	// get rid of new trace
	free_tr2(trace);

	return FMRES_IGNORED;
}

get_aim(id,Float:source[3],Float:ret[3])
{
	static Float:vAngle[3], Float:pAngle[3], Float:dir[3], Float:temp[3];

	// get aiming direction from forward global based on view angle and punch angle
	pev(id,pev_v_angle,vAngle);
	pev(id,pev_punchangle,pAngle);
	xs_vec_add(vAngle,pAngle,temp);
	engfunc(EngFunc_MakeVectors,temp);
	global_get(glb_v_forward,dir);
	
	/* vecEnd = vecSrc + vecDir * flDistance; */
	xs_vec_mul_scalar(dir,8192.0,temp);
	xs_vec_add(source,temp,ret);
}

public fwPrecacheEvent_Post(type, const name[])
{
	if (equal("events/m3.sc", name))
	{
		g_orig_event_railcannon = get_orig_retval()
		return FMRES_HANDLED
	}
	return FMRES_IGNORED
}

public client_connect(id)
{
	g_has_railcannon[id] = false
}

public client_disconnect(id)
{
	g_has_railcannon[id] = false
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
	
		if(g_has_railcannon[iOwner])
		{
			entity_set_int(iStoredAugID, EV_INT_WEAPONKEY, RAILCANNON_WEAPONKEY)
			
			g_has_railcannon[iOwner] = false
			
			//entity_set_model(entity, RAILCANNON_W_MODEL)
			
			return FMRES_SUPERCEDE
		}
	}
	return FMRES_IGNORED
}

public give_railcannon(id)
{
	drop_weapons(id, 1)
	new iWep2 = give_item(id,"weapon_m3")
	if( iWep2 > 0 )
	{
		cs_set_weapon_ammo(iWep2, cvar_clip_railcannon)
		cs_set_user_bpammo (id, CSW_M3, cvar_railcannon_ammo)
		UTIL_PlayWeaponAnimation(id, RAILCANNON_DRAW)
		set_weapons_timeidle(id, CSW_M3, 1.0)
		set_player_nextattackx(id, 1.0)
		g_clip_ammo[id] = cs_get_weapon_ammo(iWep2)
	}
	g_has_railcannon[id] = true
	g_SpecialAmmo[id] = 0
	udah[id] = 0
	zz[id] = 0
	railcannon_mode[id] = 1
	update_specialammo(id, g_SpecialAmmo[id], g_SpecialAmmo[id] > 0 ? 1 : 0)
	message_begin(MSG_ONE, gmsgWeaponList, {0,0,0}, id)
	write_string("weapon_railcannon")
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

public fw_RAILCANNON_AddToPlayer(railcannon, id)
{
	if(!is_valid_ent(railcannon) || !is_user_connected(id))
		return HAM_IGNORED
	
	if(entity_get_int(railcannon, EV_INT_WEAPONKEY) == RAILCANNON_WEAPONKEY)
	{
		g_has_railcannon[id] = true
		
		message_begin(MSG_ONE, gmsgWeaponList, {0,0,0}, id)
		write_string("weapon_railcannon")
		write_byte(5)
		write_byte(32)
		write_byte(-1)
		write_byte(-1)
		write_byte(0)
		write_byte(5)
		write_byte(21)
		write_byte(0)
		message_end()
		
		entity_set_int(railcannon, EV_INT_WEAPONKEY, 0)
		update_specialammo(id, g_SpecialAmmo[id], 0)
		g_SpecialAmmo[id] = 0

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
	
	update_specialammo(owner, g_SpecialAmmo[owner], 0)
	g_SpecialAmmo[owner] = 0
	
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
			if(g_has_railcannon[id])
			{
				set_pev(id, pev_viewmodel2, RAILCANNON_V_MODEL)
				set_pev(id, pev_weaponmodel2, RAILCANNON_P_MODEL)
				if(oldweap[id] != CSW_M3) 
				{
					set_weapons_timeidle(id, CSW_M3, 1.0)
					set_player_nextattackx(id, 1.0)
					UTIL_PlayWeaponAnimation(id, RAILCANNON_DRAW)
					udah[id] = 0
					zz[id] = 0
					railcannon_mode[id] = 1
					remove_task(id+TASK_SOUND)
					remove_task(id)

					message_begin(MSG_ONE, gmsgWeaponList, {0,0,0}, id)
					write_string("weapon_railcannon")
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
	if(!is_user_alive(Player) || get_user_weapon(Player) != CSW_M3 || !g_has_railcannon[Player])
		return FMRES_IGNORED
	
	set_cd(CD_Handle, CD_flNextAttack, halflife_time () + 0.001)
	return FMRES_HANDLED
}

public fw_RAIL_PrimaryAttack(Weapon)
{
	new Player = get_pdata_cbase(Weapon, 41, 4)
	
	if (!g_has_railcannon[Player])
		return
	
	g_IsInPrimaryAttack = 1
	pev(Player,pev_punchangle,cl_pushangle[Player])
	
	g_clip_ammo[Player] = cs_get_weapon_ammo(Weapon)
	if(g_clip_ammo[Player]) Make_Muzzleflash(Player)
}

public fw_RAIL_PrimaryAttack_Post(Weapon)
{
	g_IsInPrimaryAttack = 0
	new Player = get_pdata_cbase(Weapon, 41, 4)
	
	new szClip, szAmmo
	get_user_weapon(Player, szClip, szAmmo)
	
	if(!is_user_alive(Player))
		return

	if(g_has_railcannon[Player])
	{
		if (!g_clip_ammo[Player] && railcannon_mode[Player] == 1)
			return
		
		g_reload[Player] = 0
		remove_task( Player + 1331 )
		new Float:push[3]
		pev(Player,pev_punchangle,push)
		xs_vec_sub(push,cl_pushangle[Player],push)
		xs_vec_mul_scalar(push,cvar_recoil_railcannon,push)
		xs_vec_add(push,cl_pushangle[Player],push)
		set_pev(Player,pev_punchangle,push)
		
		UTIL_PlayWeaponAnimation(Player,random_num(4,5))
		set_weapons_timeidle(Player, CSW_M3, 0.3)
		set_player_nextattackx(Player, 0.3)
		g_clip_ammo[Player] --
		
		if(railcannon_mode[Player] == 3) emit_sound(Player, CHAN_WEAPON, "weapons/railcanon-2.wav", VOL_NORM, ATTN_NORM, 0, PITCH_NORM)
		else emit_sound(Player, CHAN_WEAPON, Fire_Sounds, VOL_NORM, ATTN_NORM, 0, PITCH_NORM)
		
		railcannon_mode[Player] = 1
	}
}

public Make_Muzzleflash(id)
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
	write_short(g_MuzzleFlash_SprId)
	write_byte(2)
	write_byte(30)
	write_byte(TE_FLAG)
	message_end()
}

public fw_CmdStart(id, uc_handle, seed) 
{
	new ammo, clip, weapon = get_user_weapon(id, clip, ammo)
	if (!g_has_railcannon[id] || weapon != CSW_M3 || !is_user_alive(id))
		return
	
	static ent; ent = fm_get_user_weapon_entity(id, CSW_M3)
		
	if(!pev_valid(ent))
		return
		
	static CurButton
	CurButton = get_uc(uc_handle, UC_Buttons)
	
	if(CurButton & IN_ATTACK)
	{
		new wpn = fm_get_user_weapon_entity(id, get_user_weapon(id))
		
		new Id = pev( wpn, pev_owner ), clip, bpammo
		get_user_weapon( Id, clip, bpammo )
		if( g_has_railcannon[ Id ] ) {
		if( clip >= 2 ) {
			if( g_reload[Id] ) {
				remove_task( Id + 1331 )
				g_reload[Id] = 0
			}
		}
		else if( clip == 1 )
		{
			if(get_pdata_float(Id, 83, 4) <= 0.3)
			{
				if( g_reload[Id] ) {
				remove_task( Id + 1331 )
				g_reload[Id] = 0
			}
			}
		}
	}
	}
	
	else if(CurButton & IN_ATTACK2)
	{
		if(!zz[id] && get_pdata_float(id, 83, 4) <= 0.0 && g_clip_ammo[id] >= 1)
		{
			set_weapons_timeidle(id, CSW_M3, 200.0)
			set_player_nextattackx(id, 200.0)
			UTIL_PlayWeaponAnimation(id, 1)
			emit_sound(id, CHAN_WEAPON, "weapons/railcanon_chage1_start.wav", 1.0, ATTN_NORM, 0, PITCH_NORM)
			set_task(0.6, "charge_idle2", id)
			zz[id] = 1
			udah[id] = 0
			railcannon_mode[id] = 2
			
			update_specialammo(id, g_SpecialAmmo[id], 0)
			g_SpecialAmmo[id] ++
			update_specialammo(id, g_SpecialAmmo[id], 1)
			
			new weapon = find_ent_by_owner( -1, "weapon_m3", id )
			cs_set_weapon_ammo( weapon, g_clip_ammo[id] - 1)
			g_clip_ammo[id] --
		}
	}
	
	else if(!(pev(id, pev_oldbuttons) & IN_ATTACK) && zz[id])
	{
		zz[id] = 0
		if(udah[id])
		{
			if(g_clip_ammo[id] >= 1)
			{
				ExecuteHamB(Ham_Weapon_PrimaryAttack, ent)
				set_weapons_timeidle(id, CSW_M3, 1.1)
				set_player_nextattackx(id, 1.1)
				udah[id] = 0
				remove_task(id+TASK_SOUND)
				
				update_specialammo(id, g_SpecialAmmo[id], 0)
				g_SpecialAmmo[id] = 0
				
				new weapon = find_ent_by_owner( -1, "weapon_m3", id )
				cs_set_weapon_ammo( weapon, g_clip_ammo[id] + 1)
				g_clip_ammo[id] ++
			}
			else
			{
				new weapon = find_ent_by_owner( -1, "weapon_m3", id )
				cs_set_weapon_ammo( weapon, g_clip_ammo[id] + 1)
				g_clip_ammo[id] ++
				
				ExecuteHamB(Ham_Weapon_PrimaryAttack, ent)
				set_weapons_timeidle(id, CSW_M3, 1.1)
				set_player_nextattackx(id, 1.1)
				udah[id] = 0
				remove_task(id+TASK_SOUND)
				
				update_specialammo(id, g_SpecialAmmo[id], 0)
				g_SpecialAmmo[id] = 0
			}
		}
	}
}

public charge_idle2(id)
{
	if(get_user_weapon(id) != CSW_M3 || !g_has_railcannon[id])
		return
	if(zz[id])
	{
		if(g_clip_ammo[id] >= 1)
		{
			UTIL_PlayWeaponAnimation(id, 2)
			set_weapons_timeidle(id, CSW_M3, 200.0)
			set_player_nextattackx(id, 200.0)
			set_task(0.6, "charge_idle3", id)
			
			update_specialammo(id, g_SpecialAmmo[id], 0)
			g_SpecialAmmo[id] ++
			update_specialammo(id, g_SpecialAmmo[id], 1)
			
			new weapon = find_ent_by_owner( -1, "weapon_m3", id )
			cs_set_weapon_ammo( weapon, g_clip_ammo[id] - 1)
			g_clip_ammo[id] --
		}
		else
		{
			static ent; ent = fm_get_user_weapon_entity(id, CSW_M3)
		
			if(!pev_valid(ent))
				return
			
			new weapon = find_ent_by_owner( -1, "weapon_m3", id )
			cs_set_weapon_ammo( weapon, g_clip_ammo[id] + 1)
			g_clip_ammo[id] ++
			
			ExecuteHamB(Ham_Weapon_PrimaryAttack, ent)
			set_weapons_timeidle(id, CSW_M3, 1.1)
			set_player_nextattackx(id, 1.1)
			
			update_specialammo(id, g_SpecialAmmo[id], 0)
			g_SpecialAmmo[id] = 0
		}
	}
	else
	{
		static ent; ent = fm_get_user_weapon_entity(id, CSW_M3)
		
		if(!pev_valid(ent))
			return
		ExecuteHamB(Ham_Weapon_PrimaryAttack, ent)
		set_weapons_timeidle(id, CSW_M3, 1.1)
		set_player_nextattackx(id, 1.1)
		
		update_specialammo(id, g_SpecialAmmo[id], 0)
		g_SpecialAmmo[id] = 0
		
		new weapon = find_ent_by_owner( -1, "weapon_m3", id )
		cs_set_weapon_ammo( weapon, g_clip_ammo[id] + 1)
		g_clip_ammo[id] ++
	}
}

public charge_idle3(id)
{
	if(get_user_weapon(id) != CSW_M3 || !g_has_railcannon[id])
		return
	if(zz[id])
	{
		if(g_clip_ammo[id] >= 1)
		{
			UTIL_PlayWeaponAnimation(id, 3)
			emit_sound(id, CHAN_WEAPON, "weapons/railcanon_chage3_loop.wav", 1.0, ATTN_NORM, 0, PITCH_NORM)
			set_task(0.794, "play_sound", id+TASK_SOUND,_,_,"b")
			udah[id] = 1
			railcannon_mode[id] = 3
			set_weapons_timeidle(id, CSW_M3, 200.0)
			set_player_nextattackx(id, 200.0)
			
			update_specialammo(id, g_SpecialAmmo[id], 0)
			g_SpecialAmmo[id] ++
			update_specialammo(id, g_SpecialAmmo[id], 1)
			
			new weapon = find_ent_by_owner( -1, "weapon_m3", id )
			cs_set_weapon_ammo( weapon, g_clip_ammo[id] - 1)
			g_clip_ammo[id] --
		}
		else
		{
			static ent; ent = fm_get_user_weapon_entity(id, CSW_M3)
		
			if(!pev_valid(ent))
				return
			new weapon = find_ent_by_owner( -1, "weapon_m3", id )
			cs_set_weapon_ammo( weapon, g_clip_ammo[id] + 1)
			g_clip_ammo[id] ++
			
			ExecuteHamB(Ham_Weapon_PrimaryAttack, ent)
			set_weapons_timeidle(id, CSW_M3, 1.1)
			set_player_nextattackx(id, 1.1)
			
			update_specialammo(id, g_SpecialAmmo[id], 0)
			g_SpecialAmmo[id] = 0
		}
	}
	else
	{
		static ent; ent = fm_get_user_weapon_entity(id, CSW_M3)
		
		if(!pev_valid(ent))
			return
		ExecuteHamB(Ham_Weapon_PrimaryAttack, ent)
		set_weapons_timeidle(id, CSW_M3, 1.1)
		set_player_nextattackx(id, 1.1)
		
		update_specialammo(id, g_SpecialAmmo[id], 0)
		g_SpecialAmmo[id] = 0
		
		new weapon = find_ent_by_owner( -1, "weapon_m3", id )
		cs_set_weapon_ammo( weapon, g_clip_ammo[id] + 1)
		g_clip_ammo[id] ++
	}
}

public play_sound(id)
{
	id -= TASK_SOUND
	
	if(!is_user_alive(id) || get_user_weapon(id) != CSW_M3 || !g_has_railcannon[id])
		return
	
	emit_sound(id, CHAN_WEAPON, "weapons/railcanon_chage3_loop.wav", 1.0, ATTN_NORM, 0, PITCH_NORM)
}

public fw_railcannonidleanim(Weapon)
{
	new id = get_pdata_cbase(Weapon, 41, 4)

	if(!is_user_alive(id) || !g_has_railcannon[id] || get_user_weapon(id) != CSW_M3)
		return HAM_IGNORED;
	
	if(railcannon_mode[id] == 1 && get_pdata_float(Weapon, 48, 4) <= 0.25)
	{
		UTIL_PlayWeaponAnimation(id, 0)
		set_pdata_float(Weapon, 48, 20.0, 4)
		return HAM_SUPERCEDE;
	}
	
	if(railcannon_mode[id] == 3 && get_pdata_float(Weapon, 48, 4) <= 0.01)
	{
		UTIL_PlayWeaponAnimation(id, 3)
		set_pdata_float(Weapon, 48, 1.7, 4)
		return HAM_SUPERCEDE;
	}

	return HAM_IGNORED;
}

public update_specialammo(id, Ammo, On)
{
	static AmmoSprites[33]
	format(AmmoSprites, sizeof(AmmoSprites), "number_%d", Ammo)
  	
	message_begin(MSG_ONE_UNRELIABLE, get_user_msgid("StatusIcon"), {0,0,0}, id)
	write_byte(On)
	write_string(AmmoSprites)
	write_byte(42) // red
	write_byte(255) // green
	write_byte(42) // blue
	message_end()
}

public fwPlaybackEvent(flags, invoker, eventid, Float:delay, Float:origin[3], Float:angles[3], Float:fparam1, Float:fparam2, iParam1, iParam2, bParam1, bParam2)
{
	if ((eventid != g_orig_event_railcannon) || !g_IsInPrimaryAttack)
		return FMRES_IGNORED
		
	if (!(1 <= invoker <= g_MaxPlayers))
		return FMRES_IGNORED

	playback_event(flags | FEV_HOSTONLY, invoker, eventid, delay, origin, angles, fparam1, fparam2, iParam1, iParam2, bParam1, bParam2)
	return FMRES_SUPERCEDE
}

public RAILCANNON_Reload( wpn ) {
	if(railcannon_mode[pev( wpn, pev_owner )] == 3)
	      return HAM_SUPERCEDE
		  
	if( g_has_railcannon[ pev( wpn, pev_owner ) ] ) {
		RAILCANNON_Reload_Post( wpn )
		return HAM_SUPERCEDE
	}
	return HAM_IGNORED
}

public RAILCANNON_Reload_Post(weapon) {
	new id = pev( weapon, pev_owner )
	if(railcannon_mode[id] == 3 || g_reload[id])
	      return HAM_SUPERCEDE
	new clip, bpammo
	get_user_weapon(id, clip, bpammo )
	if( g_has_railcannon[ id ] && clip < cvar_clip_railcannon && bpammo > 0 ) {
		if(!task_exists( id+1331 )) set_task( 0.1, "reload", id+1331 )
		}
	return HAM_IGNORED
}

public reload( id ) {
	id -= 1331
	set_weapons_timeidle(id, CSW_M3, 3.0)
	set_player_nextattackx(id, 3.0)
	UTIL_PlayWeaponAnimation(id, 6)
	g_reload[id] = 1
	set_task(3.0, "isi", id)
}

public isi(id)
{
	if(get_user_weapon(id) != CSW_M3 || !g_has_railcannon[id])
		return
	
	if(!g_reload[id])
		return
	
	new clip, pluru, pengurang, bpammo, weapon = find_ent_by_owner( -1, "weapon_m3", id )
	get_user_weapon(id, clip, bpammo )
	pengurang = cvar_clip_railcannon - clip
	pluru = bpammo - pengurang
	cs_set_user_bpammo( id, CSW_M3, pluru )
	
	if(bpammo <= pengurang) cs_set_weapon_ammo( weapon, clip + bpammo)
	else cs_set_weapon_ammo( weapon, cvar_clip_railcannon)
	
	g_clip_ammo[id] = cvar_clip_railcannon
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