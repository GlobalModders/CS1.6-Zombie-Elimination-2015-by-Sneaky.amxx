#include <amxmodx>
#include <fakemeta>
#include <fakemeta_util>
#include <hamsandwich>
#include <cstrike>
#include <fun>
#include <zombie_eli>

#define PLUGIN "[CSO] Quad Barrel (2014)"
#define VERSION "1.0"
#define AUTHOR "Dias"

#define DAMAGE 325 // 325 for Zombie / 85 for Human

#define CLIP 4
#define BPAMMO 100

#define SPEED 0.35
#define RELOAD_TIME 3.0
#define KNOCKPOWER 1000

#define MODEL_V "models/v_qbarrel.mdl"
#define MODEL_P "models/p_qbarrel.mdl"
#define MODEL_W "models/w_qbarrel.mdl"

new const WeaponSounds[5][] = 
{
	"weapons/qbarrel_shoot.wav",
	"weapons/qbarrel_draw.wav",
	"weapons/qbarrel_clipin1.wav",
	"weapons/qbarrel_clipin2.wav",
	"weapons/qbarrel_clipout1.wav"
}

enum
{
	ANIM_IDLE = 0,
	ANIM_SHOOT1,
	ANIM_SHOOT2,
	ANIM_RELOAD,
	ANIM_DRAW
}

#define CSW_QUADBARREL CSW_M3
#define weapon_quadbarrel "weapon_m3"

#define WEAPON_SECRETCODE 20102014
#define OLD_W_MODEL "models/w_m3.mdl"
#define OLD_EVENT "events/m3.sc"
#define ANIM_EXT "shotgun"

// MACROS
#define Get_BitVar(%1,%2) (%1 & (1 << (%2 & 31)))
#define Set_BitVar(%1,%2) %1 |= (1 << (%2 & 31))
#define UnSet_BitVar(%1,%2) %1 &= ~(1 << (%2 & 31))

// Main Vars
new g_Had_QB, g_OldWeapon[33], g_SpecialShot, Float:Recoil[33]
new g_HamBot, g_MsgCurWeapon, g_MsgAmmoX, g_Event_QB, g_SmokePuff_Id

// Safety
new g_IsConnected, g_IsAlive, g_PlayerWeapon[33]

new g_QB, g_Engineer
new g_QB2, g_Medic

public plugin_init()
{
	register_plugin(PLUGIN, VERSION, AUTHOR)
	Register_SafetyFunc()
	
	register_event("CurWeapon", "Event_CurWeapon", "be", "1=1")
	
	register_forward(FM_SetModel, "fw_SetModel")
	register_forward(FM_CmdStart, "fw_CmdStart")
	register_forward(FM_UpdateClientData, "fw_UpdateClientData_Post", 1)	
	register_forward(FM_PlaybackEvent, "fw_PlaybackEvent")	
	
	RegisterHam(Ham_TraceAttack, "player", "fw_TraceAttack")
	RegisterHam(Ham_TraceAttack, "player", "fw_TraceAttack_Post", 1)
	RegisterHam(Ham_TraceAttack, "worldspawn", "fw_TraceAttack")		
	
	RegisterHam(Ham_Item_Deploy, weapon_quadbarrel, "fw_Item_Deploy_Post", 1)	
	RegisterHam(Ham_Item_AddToPlayer, weapon_quadbarrel, "fw_Item_AddToPlayer_Post", 1)
	RegisterHam(Ham_Weapon_WeaponIdle, weapon_quadbarrel, "fw_Weapon_WeaponIdle_Post", 1)
	RegisterHam(Ham_Item_PostFrame, weapon_quadbarrel, "fw_Item_PostFrame")
	RegisterHam(Ham_Weapon_Reload, weapon_quadbarrel, "fw_Weapon_Reload_Post", 1)
	RegisterHam(Ham_Weapon_PrimaryAttack, weapon_quadbarrel, "fw_Weapon_PrimaryAttack")
	RegisterHam(Ham_Weapon_PrimaryAttack, weapon_quadbarrel, "fw_Weapon_PrimaryAttack_Post", 1)
	
	// Cache
	g_MsgCurWeapon = get_user_msgid("CurWeapon")
	g_MsgAmmoX = get_user_msgid("AmmoX")
	
	// CMD
	register_clcmd("say /g1231et", "Get_QuadBarrel")
	
	g_Engineer = ZombieEli_GetClassID("Engineer")
	g_QB = ZombieEli_RegisterWeapon(g_Engineer, "CSO Quad Barrel Shotgun", WPN_PRIMARY, 2, 0)
	
	g_Medic = ZombieEli_GetClassID("Medic")
	g_QB2 = ZombieEli_RegisterWeapon(g_Medic, "CSO Quad Barrel Shotgun", WPN_PRIMARY, 2, 0)
}

public plugin_precache()
{
	precache_model(MODEL_V)
	precache_model(MODEL_P)
	precache_model(MODEL_W)
	
	for(new i = 0; i < sizeof(WeaponSounds); i++)
		precache_sound(WeaponSounds[i])
	
	register_forward(FM_PrecacheEvent, "fw_PrecacheEvent_Post", 1)	
	g_SmokePuff_Id = engfunc(EngFunc_PrecacheModel, "sprites/wall_puff1.spr")	
	
	
}

public zeli_weapon_selected(id, ItemID, ClassID)
{
	if(ItemID == g_QB) Get_QuadBarrel(id)
	if(ItemID == g_QB2) Get_QuadBarrel(id)
}

public zeli_weapon_removed(id, ItemID)
{
	if(ItemID == g_QB) Remove_QuadBarrel(id)	
	if(ItemID == g_QB2) Remove_QuadBarrel(id)	
}

public fw_PrecacheEvent_Post(type, const name[])
{
	if(equal(OLD_EVENT, name))
		g_Event_QB = get_orig_retval()
}

public client_putinserver(id)
{
	Safety_Connected(id)
	
	if(!g_HamBot && is_user_bot(id))
	{
		g_HamBot = 1
		set_task(0.1, "Do_Register_HamBot", id)
	}
}

public Do_Register_HamBot(id) 
{
	Register_SafetyFuncBot(id)
	RegisterHamFromEntity(Ham_TraceAttack, id, "fw_TraceAttack")
	RegisterHamFromEntity(Ham_TraceAttack, id, "fw_TraceAttack_Post", 1)
}

public client_disconnect(id)
{
	Safety_Disconnected(id)
}

public Get_QuadBarrel(id)
{
	Remove_QuadBarrel(id)
	
	UnSet_BitVar(g_SpecialShot, id)
	Set_BitVar(g_Had_QB, id)
	
	give_item(id, weapon_quadbarrel)
	cs_set_user_bpammo(id, CSW_QUADBARREL, BPAMMO)
	
	static Ent; Ent = fm_get_user_weapon_entity(id, CSW_QUADBARREL)
	if(pev_valid(Ent)) cs_set_weapon_ammo(Ent, CLIP)
	
	engfunc(EngFunc_MessageBegin, MSG_ONE_UNRELIABLE, g_MsgCurWeapon, {0, 0, 0}, id)
	write_byte(1)
	write_byte(CSW_QUADBARREL)
	write_byte(CLIP)
	message_end()
}

public Remove_QuadBarrel(id)
{
	UnSet_BitVar(g_Had_QB, id)
}

public Hook_Weapon(id)
{
	engclient_cmd(id, weapon_quadbarrel)
	return PLUGIN_HANDLED
}

public Event_CurWeapon(id)
{
	if(!is_alive(id))
		return
	
	static CSWID; CSWID = read_data(2)

	if((CSWID == CSW_QUADBARREL && g_OldWeapon[id] == CSW_QUADBARREL) && Get_BitVar(g_Had_QB, id)) 
	{
		static Ent; Ent = fm_get_user_weapon_entity(id, CSW_QUADBARREL)
		if(pev_valid(Ent)) 
		{
			set_pdata_float(Ent, 46, get_pdata_float(Ent, 46, 4) * SPEED, 4)
			set_pdata_float(Ent, 47, get_pdata_float(Ent, 46, 4) * SPEED, 4)
		}
	}
	
	g_OldWeapon[id] = CSWID
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
	
	if(equal(model, OLD_W_MODEL))
	{
		static weapon
		weapon = fm_get_user_weapon_entity(entity, CSW_QUADBARREL)
		
		if(!pev_valid(weapon))
			return FMRES_IGNORED
		
		if(Get_BitVar(g_Had_QB, id))
		{
			set_pev(weapon, pev_impulse, WEAPON_SECRETCODE)
			engfunc(EngFunc_SetModel, entity, MODEL_W)
			
			Remove_QuadBarrel(id)
			
			return FMRES_SUPERCEDE
		}
	}

	return FMRES_IGNORED;
}

public fw_CmdStart(id, uc_handle, seed)
{
	if(!is_alive(id))
		return
	if(get_player_weapon(id) != CSW_QUADBARREL || !Get_BitVar(g_Had_QB, id))
		return
		
	static NewButton; NewButton = get_uc(uc_handle, UC_Buttons)
	
	static Ent; Ent = fm_get_user_weapon_entity(id, CSW_QUADBARREL)
	if(!pev_valid(Ent)) return
	
	static Float:flNextAttack; flNextAttack = get_pdata_float(id, 83, 5)
	static Ammo; Ammo = cs_get_weapon_ammo(Ent)
	
	if(NewButton & IN_ATTACK2)
	{
		if(flNextAttack > 0.0) return
		
		for(new i = 0; i < Ammo; i++)
		{
			Set_BitVar(g_SpecialShot, id)
			ExecuteHamB(Ham_Weapon_PrimaryAttack, Ent)
			UnSet_BitVar(g_SpecialShot, id)
		}
	} 
}

public fw_UpdateClientData_Post(id, sendweapons, cd_handle)
{
	if(!is_alive(id))
		return FMRES_IGNORED	
	if(get_player_weapon(id) == CSW_QUADBARREL && Get_BitVar(g_Had_QB, id))
		set_cd(cd_handle, CD_flNextAttack, get_gametime() + 0.001) 
	
	return FMRES_HANDLED
}

public fw_PlaybackEvent(flags, invoker, eventid, Float:delay, Float:origin[3], Float:angles[3], Float:fparam1, Float:fparam2, iParam1, iParam2, bParam1, bParam2)
{
	if (!is_connected(invoker))
		return FMRES_IGNORED		
	if(get_player_weapon(invoker) == CSW_QUADBARREL && Get_BitVar(g_Had_QB, invoker) && eventid == g_Event_QB)
	{
		engfunc(EngFunc_PlaybackEvent, flags | FEV_HOSTONLY, invoker, eventid, delay, origin, angles, fparam1, fparam2, iParam1, iParam2, bParam1, bParam2)	

		Set_WeaponAnim(invoker, ANIM_SHOOT1)
		emit_sound(invoker, CHAN_WEAPON, WeaponSounds[0], 1.0, ATTN_NORM, 0, PITCH_LOW)	

		return FMRES_SUPERCEDE
	}
	
	return FMRES_HANDLED
}

public fw_TraceAttack(Ent, Attacker, Float:Damage, Float:Dir[3], ptr, DamageType)
{
	if(!is_connected(Attacker))
		return HAM_IGNORED	
	if(get_player_weapon(Attacker) != CSW_QUADBARREL || !Get_BitVar(g_Had_QB, Attacker))
		return HAM_IGNORED
		
	static Float:flEnd[3], Float:vecPlane[3]

	get_tr2(ptr, TR_vecEndPos, flEnd)
	get_tr2(ptr, TR_vecPlaneNormal, vecPlane)		
	
	if(!is_connected(Ent))
	{
		make_bullet(Attacker, flEnd)
		fake_smoke(Attacker, ptr)
	}
	
	SetHamParamFloat(3, float(DAMAGE) / 6.0)

	return HAM_HANDLED	
}

public fw_TraceAttack_Post(Ent, Attacker, Float:Damage, Float:Dir[3], ptr, DamageType)
{
	if(!is_connected(Attacker))
		return HAM_IGNORED	
	if(get_player_weapon(Attacker) != CSW_QUADBARREL || !Get_BitVar(g_Had_QB, Attacker))
		return HAM_IGNORED
	if(cs_get_user_team(Ent) == cs_get_user_team(Attacker))
		return HAM_IGNORED
		
	if (!(DamageType & DMG_BULLET))
		return HAM_IGNORED
	if (Damage <= 0.0 || GetHamReturnStatus() == HAM_SUPERCEDE || get_tr2(ptr, TR_pHit) != Ent)
		return HAM_IGNORED
	
	// Get distance between players
	static origin1[3], origin2[3]
	get_user_origin(Ent, origin1)
	get_user_origin(Attacker, origin2)
	
	// Max distance exceeded
	if (get_distance(origin1, origin2) > 1024)
		return HAM_IGNORED
		
	// Get victim's velocity
	static Float:velocity[3]
	pev(Ent, pev_velocity, velocity)
	
	// Use damage on knockback calculation
	xs_vec_mul_scalar(Dir, Damage, Dir)
	
	// Use weapon power on knockback calculation
	xs_vec_mul_scalar(Dir, float(KNOCKPOWER), Dir)
	
	// Apply ducking knockback multiplier
	new ducking = pev(Ent, pev_flags) & (FL_DUCKING | FL_ONGROUND) == (FL_DUCKING | FL_ONGROUND)
	if (ducking) xs_vec_mul_scalar(Dir, 0.5, Dir)
	
	// Add up the new vector
	xs_vec_add(velocity, Dir, Dir)
	
	// Should knockback also affect vertical velocity?
	Dir[2] = velocity[2]
	
	// Set the knockback'd victim's velocity
	set_pev(Ent, pev_velocity, Dir)
		
	return HAM_IGNORED
}

public fw_Item_Deploy_Post(Ent)
{
	if(pev_valid(Ent) != 2)
		return
	static Id; Id = get_pdata_cbase(Ent, 41, 4)
	if(get_pdata_cbase(Id, 373) != Ent)
		return
	if(!Get_BitVar(g_Had_QB, Id))
		return

	set_pev(Id, pev_viewmodel2, MODEL_V)
	set_pev(Id, pev_weaponmodel2, MODEL_P)
	
	Set_WeaponAnim(Id, ANIM_DRAW)
	set_pdata_string(Id, (492) * 4, ANIM_EXT, -1 , 20)
}

public fw_Item_AddToPlayer_Post(ent, id)
{
	if(pev(ent, pev_impulse) == WEAPON_SECRETCODE)
	{
		Set_BitVar(g_Had_QB, id)
		set_pev(ent, pev_impulse, 0)
	}	
}

public fw_Weapon_WeaponIdle_Post(iEnt)
{
	if(pev_valid(iEnt) != 2)
		return 
	static id; id = get_pdata_cbase(iEnt, 41, 4)
	if(get_pdata_cbase(id, 373) != iEnt)
		return
	if(!Get_BitVar(g_Had_QB, id))
		return
	
	static SpecialReload; SpecialReload = get_pdata_int(iEnt, 55, 4)
	if(!SpecialReload && get_pdata_float(iEnt, 48, 4) <= 0.25)
	{
		Set_WeaponAnim(id, ANIM_IDLE)
		set_pdata_float(iEnt, 48, 20.0, 4)
	}	
}

public fw_Item_PostFrame(iEnt)
{
	if(pev_valid(iEnt) != 2)
		return 
	static id; id = get_pdata_cbase(iEnt, 41, 4)
	if(get_pdata_cbase(id, 373) != iEnt)
		return
	if(!Get_BitVar(g_Had_QB, id))
		return

	static iBpAmmo ; iBpAmmo = get_pdata_int(id, 381, 5)
	static iClip ; iClip = get_pdata_int(iEnt, 51, 4)
	static iMaxClip ; iMaxClip = CLIP

	if(get_pdata_int(iEnt, 54, 4) && get_pdata_float(id, 83, 5) <= 0.0)
	{
		static j; j = min(iMaxClip - iClip, iBpAmmo)
		set_pdata_int(iEnt, 51, iClip + j, 4)
		set_pdata_int(id, 381, iBpAmmo-j, 5)
		
		set_pdata_int(iEnt, 54, 0, 4)
		if(iBpAmmo > CLIP) cs_set_weapon_ammo(iEnt, min(iBpAmmo, CLIP))
		else cs_set_weapon_ammo(iEnt, iClip + iBpAmmo)
	
		// Update the fucking ammo hud
		message_begin(MSG_ONE_UNRELIABLE, g_MsgCurWeapon, _, id)
		write_byte(1)
		write_byte(CSW_QUADBARREL)
		write_byte(CLIP)
		message_end()
		
		message_begin(MSG_ONE_UNRELIABLE, g_MsgAmmoX, _, id)
		write_byte(3)
		write_byte(cs_get_user_bpammo(id, CSW_QUADBARREL))
		message_end()
	
		return
	}
}

public fw_Weapon_Reload_Post(iEnt)
{
	if(pev_valid(iEnt) != 2)
		return 
	static id; id = get_pdata_cbase(iEnt, 41, 4)
	if(get_pdata_cbase(id, 373) != iEnt)
		return
	if(!Get_BitVar(g_Had_QB, id))
		return

	static CurBpAmmo; CurBpAmmo = cs_get_user_bpammo(id, CSW_QUADBARREL)
	if(CurBpAmmo  <= 0)
		return

	set_pdata_int(iEnt, 55, 0, 4)
	set_pdata_float(id, 83, RELOAD_TIME, 5)
	set_pdata_float(iEnt, 48, RELOAD_TIME + 0.5, 4)
	set_pdata_float(iEnt, 46, RELOAD_TIME + 0.25, 4)
	set_pdata_float(iEnt, 47, RELOAD_TIME + 0.25, 4)
	set_pdata_int(iEnt, 54, 1, 4)
	
	Set_WeaponAnim(id, ANIM_RELOAD)
}


public fw_Weapon_PrimaryAttack(iEnt)
{
	if(pev_valid(iEnt) != 2)
		return 
	static id; id = get_pdata_cbase(iEnt, 41, 4)
	if(get_pdata_cbase(id, 373) != iEnt)
		return
	if(!Get_BitVar(g_Had_QB, id))
		return
		
	pev(id, pev_punchangle, Recoil[id])
	
	return
}

public fw_Weapon_PrimaryAttack_Post(iEnt)
{
	if(pev_valid(iEnt) != 2)
		return 
	static id; id = get_pdata_cbase(iEnt, 41, 4)
	if(get_pdata_cbase(id, 373) != iEnt)
		return
	if(!Get_BitVar(g_Had_QB, id))
		return
	if(!Get_BitVar(g_SpecialShot, id))
		return
		
	static Float:Push[3]
	pev(id, pev_punchangle, Push)
	xs_vec_sub(Push, Recoil[id], Push)
	
	xs_vec_mul_scalar(Push, 0.25, Push)
	xs_vec_add(Push, Recoil[id], Push)
	
	set_pev(id, pev_punchangle, Push)
	
	return
}

public Get_EndOrigin(Float:Start[3], Float:End[3], Float:Result[3], IgnoreEnt)
{
	static TraceID
	engfunc(EngFunc_TraceLine, Start, End, DONT_IGNORE_MONSTERS, IgnoreEnt, TraceID)
	
	get_tr2(TraceID, TR_vecEndPos, Result)
}

stock Set_WeaponAnim(id, anim)
{
	set_pev(id, pev_weaponanim, anim)
	
	message_begin(MSG_ONE_UNRELIABLE, SVC_WEAPONANIM, {0, 0, 0}, id)
	write_byte(anim)
	write_byte(pev(id, pev_body))
	message_end()
}

stock Set_Weapon_Idle(id, WeaponId ,Float:TimeIdle)
{
	static entwpn; entwpn = fm_get_user_weapon_entity(id, WeaponId)
	if(!pev_valid(entwpn)) 
		return
		
	set_pdata_float(entwpn, 46, TimeIdle, 4)
	set_pdata_float(entwpn, 47, TimeIdle, 4)
	set_pdata_float(entwpn, 48, TimeIdle + 0.5, 4)
}

stock Set_Player_NextAttack(id, Float:NextTime) set_pdata_float(id, 83, NextTime, 5)
stock make_bullet(id, Float:Origin[3])
{
	// Find target
	new decal = random_num(41, 45)
	const loop_time = 2
	
	static Body, Target
	get_user_aiming(id, Target, Body, 999999)
	
	if(is_user_connected(Target))
		return
	
	for(new i = 0; i < loop_time; i++)
	{
		// Put decal on "world" (a wall)
		message_begin(MSG_BROADCAST, SVC_TEMPENTITY)
		write_byte(TE_WORLDDECAL)
		engfunc(EngFunc_WriteCoord, Origin[0])
		engfunc(EngFunc_WriteCoord, Origin[1])
		engfunc(EngFunc_WriteCoord, Origin[2])
		write_byte(decal)
		message_end()
		
		// Show sparcles
		message_begin(MSG_BROADCAST, SVC_TEMPENTITY)
		write_byte(TE_GUNSHOTDECAL)
		engfunc(EngFunc_WriteCoord, Origin[0])
		engfunc(EngFunc_WriteCoord, Origin[1])
		engfunc(EngFunc_WriteCoord, Origin[2])
		write_short(id)
		write_byte(decal)
		message_end()
	}
}

stock fake_smoke(id, trace_result)
{
	static Float:vecSrc[3], Float:vecEnd[3], TE_FLAG
	
	get_weapon_attachment(id, vecSrc)
	global_get(glb_v_forward, vecEnd)
    
	xs_vec_mul_scalar(vecEnd, 8192.0, vecEnd)
	xs_vec_add(vecSrc, vecEnd, vecEnd)

	get_tr2(trace_result, TR_vecEndPos, vecSrc)
	get_tr2(trace_result, TR_vecPlaneNormal, vecEnd)
    
	xs_vec_mul_scalar(vecEnd, 2.5, vecEnd)
	xs_vec_add(vecSrc, vecEnd, vecEnd)
    
	TE_FLAG |= TE_EXPLFLAG_NODLIGHTS
	TE_FLAG |= TE_EXPLFLAG_NOSOUND
	TE_FLAG |= TE_EXPLFLAG_NOPARTICLES
	
	engfunc(EngFunc_MessageBegin, MSG_PAS, SVC_TEMPENTITY, vecEnd, 0)
	write_byte(TE_EXPLOSION)
	engfunc(EngFunc_WriteCoord, vecEnd[0])
	engfunc(EngFunc_WriteCoord, vecEnd[1])
	engfunc(EngFunc_WriteCoord, vecEnd[2] - 10.0)
	write_short(g_SmokePuff_Id)
	write_byte(2)
	write_byte(50)
	write_byte(TE_FLAG)
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

stock get_position(ent, Float:forw, Float:right, Float:up, Float:vStart[])
{
	static Float:vOrigin[3], Float:vAngle[3], Float:vForward[3], Float:vRight[3], Float:vUp[3]
	
	pev(ent, pev_origin, vOrigin)
	pev(ent, pev_view_ofs,vUp) //for player
	xs_vec_add(vOrigin,vUp,vOrigin)
	pev(ent, pev_v_angle, vAngle) // if normal entity ,use pev_angles
	
	angle_vector(vAngle,ANGLEVECTOR_FORWARD,vForward) //or use EngFunc_AngleVectors
	angle_vector(vAngle,ANGLEVECTOR_RIGHT,vRight)
	angle_vector(vAngle,ANGLEVECTOR_UP,vUp)
	
	vStart[0] = vOrigin[0] + vForward[0] * forw + vRight[0] * right + vUp[0] * up
	vStart[1] = vOrigin[1] + vForward[1] * forw + vRight[1] * right + vUp[1] * up
	vStart[2] = vOrigin[2] + vForward[2] * forw + vRight[2] * right + vUp[2] * up
}

stock PlaySound(id, const sound[])
{
	if(equal(sound[strlen(sound)-4], ".mp3")) client_cmd(id, "mp3 play ^"sound/%s^"", sound)
	else client_cmd(id, "spk ^"%s^"", sound)
}

/* ===============================
------------- SAFETY -------------
=================================*/
public Register_SafetyFunc()
{
	register_event("CurWeapon", "Safety_CurWeapon", "be", "1=1")
	
	RegisterHam(Ham_Spawn, "player", "fw_Safety_Spawn_Post", 1)
	RegisterHam(Ham_Killed, "player", "fw_Safety_Killed_Post", 1)
}

public Register_SafetyFuncBot(id)
{
	RegisterHamFromEntity(Ham_Spawn, id, "fw_Safety_Spawn_Post", 1)
	RegisterHamFromEntity(Ham_Killed, id, "fw_Safety_Killed_Post", 1)
}

public Safety_Connected(id)
{
	Set_BitVar(g_IsConnected, id)
	UnSet_BitVar(g_IsAlive, id)
	
	g_PlayerWeapon[id] = 0
}

public Safety_Disconnected(id)
{
	UnSet_BitVar(g_IsConnected, id)
	UnSet_BitVar(g_IsAlive, id)
	
	g_PlayerWeapon[id] = 0
}

public Safety_CurWeapon(id)
{
	if(!is_alive(id))
		return
		
	static CSW; CSW = read_data(2)
	if(g_PlayerWeapon[id] != CSW) g_PlayerWeapon[id] = CSW
}

public fw_Safety_Spawn_Post(id)
{
	if(!is_user_alive(id))
		return
		
	Set_BitVar(g_IsAlive, id)
}

public fw_Safety_Killed_Post(id)
{
	UnSet_BitVar(g_IsAlive, id)
}

public is_alive(id)
{
	if(!(1 <= id <= 32))
		return 0
	if(!Get_BitVar(g_IsConnected, id))
		return 0
	if(!Get_BitVar(g_IsAlive, id)) 
		return 0
		
	return 1
}

public is_connected(id)
{
	if(!(1 <= id <= 32))
		return 0
	if(!Get_BitVar(g_IsConnected, id))
		return 0
	
	return 1
}

public get_player_weapon(id)
{
	if(!is_alive(id))
		return 0
	
	return g_PlayerWeapon[id]
}

/* ===============================
--------- End of SAFETY ----------
=================================*/
