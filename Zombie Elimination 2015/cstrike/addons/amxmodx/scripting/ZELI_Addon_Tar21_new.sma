#include <amxmodx>
#include <fakemeta>
#include <fakemeta_util>
#include <hamsandwich>
#include <cstrike>
#include <zombie_eli>

#define PLUGIN "Primary: TAR-21"
#define VERSION "1.0"
#define AUTHOR "SORPACK.COM | GLOBALMODDERS.NET"

#define V_MODEL "models/ZombieDarkness/Weapon/Pri2/v_tar21.mdl"
#define P_MODEL "models/ZombieDarkness/Weapon/Pri2/p_tar21.mdl"
//#define W_MODEL "models/ZombieDarkness/Weapon/Pri2/w_pri1.mdl"

#define CSW_BASEDON CSW_AUG
#define weapon_basedon "weapon_aug"

#define DAMAGE 28
#define CLIP 30
#define BPAMMO 180
#define SPEED 1.25
#define RECOIL 1.0
#define RELOAD_TIME 3.0

#define SHOOT_ANIM random_num(3, 5)
#define DRAW_ANIM 2
#define RELOAD_ANIM 1

#define BODY_NUM 3

#define WEAPON_SECRETCODE 54542
#define WEAPON_EVENT "events/aug.sc"
#define OLD_W_MODEL "models/w_aug.mdl"

#define FIRE_SOUND "weapons/tar21-1.wav"

//new g_Weapon
new g_Had_Weapon, g_Old_Weapon[33], Float:g_Recoil[33][3], g_Clip[33]
new g_weapon_event, g_ShellId, g_SmokePuff_SprId
new g_HamBot, g_Msg_CurWeapon

new g_Medic, g_tar211
new g_Engineer, g_tar212
new g_PyroTech, g_tar213
new g_FrozenTech, g_tar214
new g_Heavy, g_tar215
new g_Wukong, g_tar216


// MACROS
#define Get_BitVar(%1,%2) (%1 & (1 << (%2 & 31)))
#define Set_BitVar(%1,%2) %1 |= (1 << (%2 & 31))
#define UnSet_BitVar(%1,%2) %1 &= ~(1 << (%2 & 31))

public plugin_init()
{
	register_plugin(PLUGIN, VERSION, AUTHOR)
	
	register_event("CurWeapon", "Event_CurWeapon", "be", "1=1")
	
	register_forward(FM_UpdateClientData, "fw_UpdateClientData_Post", 1)	
	register_forward(FM_PlaybackEvent, "fw_PlaybackEvent")	
	register_forward(FM_SetModel, "fw_SetModel")	
	
	RegisterHam(Ham_TraceAttack, "worldspawn", "fw_TraceAttack_World")
	RegisterHam(Ham_TraceAttack, "player", "fw_TraceAttack_Player")
	RegisterHam(Ham_Weapon_PrimaryAttack, weapon_basedon, "fw_Weapon_PrimaryAttack")
	RegisterHam(Ham_Weapon_PrimaryAttack, weapon_basedon, "fw_Weapon_PrimaryAttack_Post", 1)
	RegisterHam(Ham_Item_AddToPlayer, weapon_basedon, "fw_Item_AddToPlayer_Post", 1)
	RegisterHam(Ham_Weapon_Reload, weapon_basedon, "fw_Weapon_Reload")
	RegisterHam(Ham_Weapon_Reload, weapon_basedon, "fw_Weapon_Reload_Post", 1)
	RegisterHam(Ham_Item_PostFrame, weapon_basedon, "fw_Item_PostFrame")		
	
	g_Msg_CurWeapon = get_user_msgid("CurWeapon")
	//g_Weapon = zd_weapon_register("TAR-21", WEAPON_PRIMARY, CSW_BASEDON, 0)
	
	  /////////////////////////////////////////////
	 // Register Weapon for Frozen Tech Class //
	/////////////////////////////////////////////
	g_FrozenTech = ZombieEli_GetClassID("Frozen Tech")
	g_tar211 = ZombieEli_RegisterWeapon(g_FrozenTech, "CSO Tar-21", WPN_PRIMARY, 1, 0)
	
	  /////////////////////////////////////////////
	 //  Register Weapon for Pyro Tech Class  //
	/////////////////////////////////////////////	
	g_PyroTech = ZombieEli_GetClassID("Pyro Tech")
	g_tar212 = ZombieEli_RegisterWeapon(g_PyroTech, "CSO Tar-21", WPN_PRIMARY, 1, 0)	

	  /////////////////////////////////////////////
	 //    Register Weapon for Medic Class    //
	/////////////////////////////////////////////	
	g_Medic = ZombieEli_GetClassID("Medic")
	g_tar213 = ZombieEli_RegisterWeapon(g_Medic, "CSO Tar-21", WPN_PRIMARY, 1, 0)	

	  /////////////////////////////////////////////
	 //    Register Weapon for Heavy Class    //
	/////////////////////////////////////////////	
	g_Heavy = ZombieEli_GetClassID("Heavy")
	g_tar214 = ZombieEli_RegisterWeapon(g_Heavy, "CSO Tar-21", WPN_PRIMARY, 1, 0)	
	
	  /////////////////////////////////////////////
	 //  Register Weapon for Engineer Class   //
	/////////////////////////////////////////////	
	g_Engineer = ZombieEli_GetClassID("Engineer")
	g_tar215 = ZombieEli_RegisterWeapon(g_Engineer, "CSO Tar-21", WPN_PRIMARY, 1, 0)	
	
	  /////////////////////////////////////////////
	 //   Register Weapon for Wukong Class    //
	/////////////////////////////////////////////	
	g_Wukong = ZombieEli_GetClassID("Sun Wukong")
	g_tar216 = ZombieEli_RegisterWeapon(g_Wukong, "CSO Tar-21", WPN_PRIMARY, 1, 0)		
}

public plugin_precache()
{
	engfunc(EngFunc_PrecacheModel, V_MODEL)
	engfunc(EngFunc_PrecacheModel, P_MODEL)
	//engfunc(EngFunc_PrecacheModel, W_MODEL)
	engfunc(EngFunc_PrecacheSound, FIRE_SOUND)
	
	g_SmokePuff_SprId = engfunc(EngFunc_PrecacheModel, "sprites/wall_puff1.spr")
	g_ShellId = engfunc(EngFunc_PrecacheModel, "models/rshell.mdl")	
	
	register_forward(FM_PrecacheEvent, "fw_PrecacheEvent_Post", 1)
}

public zeli_weapon_selected(id, ItemID, ClassID)
{
	if(ItemID == g_tar211) Get_Weapon(id)
	if(ItemID == g_tar212) Get_Weapon(id)
	if(ItemID == g_tar213) Get_Weapon(id)
	if(ItemID == g_tar214) Get_Weapon(id)
	if(ItemID == g_tar215) Get_Weapon(id)
	if(ItemID == g_tar216) Get_Weapon(id)
}

public zeli_weapon_removed(id, ItemID)
{
	if(ItemID == g_tar211) Remove_Weapon(id)
	if(ItemID == g_tar212) Remove_Weapon(id)
	if(ItemID == g_tar213) Remove_Weapon(id)
	if(ItemID == g_tar214) Remove_Weapon(id)
	if(ItemID == g_tar215) Remove_Weapon(id)
	if(ItemID == g_tar216) Remove_Weapon(id)
}

public fw_PrecacheEvent_Post(type, const name[])
{
	if(equal(WEAPON_EVENT, name))
		g_weapon_event = get_orig_retval()		
}

public client_putinserver(id)
{
	if(!g_HamBot && is_user_bot(id))
	{
		g_HamBot = 1
		set_task(0.1, "Do_RegisterHam", id)
	}
}

public Do_RegisterHam(id)
{
	RegisterHamFromEntity(Ham_TraceAttack, id, "fw_TraceAttack_Player")	
}

public weapon_bought(id, ItemID)
{
	if(ItemID == g_tar211) Get_Weapon(id)
	if(ItemID == g_tar212) Get_Weapon(id)
	if(ItemID == g_tar213) Get_Weapon(id)
	if(ItemID == g_tar214) Get_Weapon(id)
	if(ItemID == g_tar215) Get_Weapon(id)
	if(ItemID == g_tar216) Get_Weapon(id)
}

public weapon_remove(id, ItemID)
{
	if(ItemID == g_tar211) Remove_Weapon(id)
	if(ItemID == g_tar212) Remove_Weapon(id)
	if(ItemID == g_tar213) Remove_Weapon(id)
	if(ItemID == g_tar214) Remove_Weapon(id)
	if(ItemID == g_tar215) Remove_Weapon(id)
	if(ItemID == g_tar216) Remove_Weapon(id)
}

public weapon_addammo(id, ItemID)
{
	if(ItemID == g_tar211) Give_FuckingAmmo(id, CSW_BASEDON, 0)
	if(ItemID == g_tar212) Give_FuckingAmmo(id, CSW_BASEDON, 0)
	if(ItemID == g_tar213) Give_FuckingAmmo(id, CSW_BASEDON, 0)
	if(ItemID == g_tar214) Give_FuckingAmmo(id, CSW_BASEDON, 0)
	if(ItemID == g_tar215) Give_FuckingAmmo(id, CSW_BASEDON, 0)
	if(ItemID == g_tar216) Give_FuckingAmmo(id, CSW_BASEDON, 0)
}

public Get_Weapon(id)
{
	Set_BitVar(g_Had_Weapon, id)
	fm_give_item(id, weapon_basedon)	
	
	// Set Ammo
	static Ent; Ent = fm_get_user_weapon_entity(id, CSW_BASEDON)
	if(pev_valid(Ent)) cs_set_weapon_ammo(Ent, CLIP)
	
	Give_FuckingAmmo(id, CSW_BASEDON, 0)
	
	engfunc(EngFunc_MessageBegin, MSG_ONE_UNRELIABLE, g_Msg_CurWeapon, {0, 0, 0}, id)
	write_byte(1)
	write_byte(CSW_BASEDON)
	write_byte(CLIP)
	message_end()	
}

public Remove_Weapon(id)
{
	UnSet_BitVar(g_Had_Weapon, id)
}

public Event_CurWeapon(id)
{
	if(!is_user_alive(id))
		return
	
	static CSWID; CSWID = read_data(2)
	
	if((CSWID == CSW_BASEDON && g_Old_Weapon[id] != CSW_BASEDON) && Get_BitVar(g_Had_Weapon, id))
	{
		set_pev(id, pev_viewmodel2, V_MODEL)
		set_pev(id, pev_weaponmodel2, P_MODEL)
		
		set_weapon_anim(id, DRAW_ANIM)
		//Draw_NewWeapon(id, CSWID)
	} else if((CSWID == CSW_BASEDON && g_Old_Weapon[id] == CSW_BASEDON) && Get_BitVar(g_Had_Weapon, id)) {
		static Ent; Ent = fm_get_user_weapon_entity(id, CSW_BASEDON)
		if(!pev_valid(Ent))
		{
			g_Old_Weapon[id] = get_user_weapon(id)
			return
		}
		
		if(cs_get_user_zoom(id) == 1)
		{
			set_pev(id, pev_viewmodel2, V_MODEL)
		} else if(cs_get_user_zoom(id) == 2 || cs_get_user_zoom(id) == 3) {
			set_pev(id, pev_viewmodel2, "")
		}
		
		set_pdata_float(Ent, 46, get_pdata_float(Ent, 46, 4) * SPEED, 4)
	} else if(CSWID != CSW_BASEDON && g_Old_Weapon[id] == CSW_BASEDON) Draw_NewWeapon(id, CSWID)
	
	g_Old_Weapon[id] = get_user_weapon(id)
}

public Draw_NewWeapon(id, CSW_ID)
{
	if(CSW_ID == CSW_BASEDON)
	{
		static ent
		ent = fm_get_user_weapon_entity(id, CSW_BASEDON)
		
		if(pev_valid(ent) && Get_BitVar(g_Had_Weapon, id))
		{
			set_pev(ent, pev_effects, pev(ent, pev_effects) &~ EF_NODRAW) 
			engfunc(EngFunc_SetModel, ent, P_MODEL)	
			set_pev(ent, pev_body, BODY_NUM)
		}
	} else {
		static ent
		ent = fm_get_user_weapon_entity(id, CSW_BASEDON)
		
		if(pev_valid(ent)) set_pev(ent, pev_effects, pev(ent, pev_effects) | EF_NODRAW) 			
	}
	
}

public fw_UpdateClientData_Post(id, sendweapons, cd_handle)
{
	if(!is_user_alive(id))
		return FMRES_IGNORED	
	if(get_user_weapon(id) == CSW_BASEDON && Get_BitVar(g_Had_Weapon, id))
		set_cd(cd_handle, CD_flNextAttack, get_gametime() + 0.001) 
	
	return FMRES_HANDLED
}

public fw_PlaybackEvent(flags, invoker, eventid, Float:delay, Float:origin[3], Float:angles[3], Float:fparam1, Float:fparam2, iParam1, iParam2, bParam1, bParam2)
{
	if (!is_user_connected(invoker))
		return FMRES_IGNORED	
	if(get_user_weapon(invoker) != CSW_BASEDON || !Get_BitVar(g_Had_Weapon, invoker))
		return FMRES_IGNORED
	if(eventid != g_weapon_event)
		return FMRES_IGNORED
	
	engfunc(EngFunc_PlaybackEvent, flags | FEV_HOSTONLY, invoker, eventid, delay, origin, angles, fparam1, fparam2, iParam1, iParam2, bParam1, bParam2)
	
	set_weapon_anim(invoker, SHOOT_ANIM)
	emit_sound(invoker, CHAN_WEAPON, FIRE_SOUND, VOL_NORM, ATTN_NORM, 0, PITCH_LOW)
	
	if(cs_get_user_zoom(invoker) == 1) Eject_Shell(invoker, g_ShellId, 0.0)
		
	return FMRES_SUPERCEDE
}

public fw_SetModel(entity, model[])
{
	if(!pev_valid(entity))
		return FMRES_IGNORED
	
	static Classname[32]
	pev(entity, pev_classname, Classname, sizeof(Classname))
	
	if(!equal(Classname, "weaponbox"))
		return FMRES_IGNORED
	
	static iOwner
	iOwner = pev(entity, pev_owner)
	
	if(equal(model, OLD_W_MODEL))
	{
		static weapon; weapon = fm_find_ent_by_owner(-1, weapon_basedon, entity)
		
		if(!pev_valid(weapon))
			return FMRES_IGNORED;
		
		if(Get_BitVar(g_Had_Weapon, iOwner))
		{
			Remove_Weapon(iOwner)
			
			set_pev(weapon, pev_impulse, WEAPON_SECRETCODE)
			//engfunc(EngFunc_SetModel, entity, W_MODEL)
			set_pev(entity, pev_body, BODY_NUM)
			
			return FMRES_SUPERCEDE
		}
	}

	return FMRES_IGNORED;
}

public fw_TraceAttack_World(Victim, Attacker, Float:Damage, Float:Direction[3], Ptr, DamageBits)
{
	if(!is_user_connected(Attacker))
		return HAM_IGNORED	
	if(get_user_weapon(Attacker) != CSW_BASEDON || !Get_BitVar(g_Had_Weapon, Attacker))
		return HAM_IGNORED
		
	static Float:flEnd[3], Float:vecPlane[3]
	
	get_tr2(Ptr, TR_vecEndPos, flEnd)
	get_tr2(Ptr, TR_vecPlaneNormal, vecPlane)		
		
	Make_BulletHole(Attacker, flEnd, Damage)
	Make_BulletSmoke(Attacker, Ptr)

	SetHamParamFloat(3, float(DAMAGE))
	
	return HAM_IGNORED
}

public fw_TraceAttack_Player(Victim, Attacker, Float:Damage, Float:Direction[3], Ptr, DamageBits)
{
	if(!is_user_connected(Attacker))
		return HAM_IGNORED	
	if(get_user_weapon(Attacker) != CSW_BASEDON || !Get_BitVar(g_Had_Weapon, Attacker))
		return HAM_IGNORED
		
	SetHamParamFloat(3, float(DAMAGE))
	
	static Float:MyOrigin[3], Float:VicOrigin[3], Float:Velocity[3]
	
	pev(Attacker, pev_origin, MyOrigin)
	pev(Victim, pev_origin, VicOrigin)
	
	Get_SpeedVector(MyOrigin, VicOrigin, (pev(Victim, pev_flags) & FL_DUCKING) ? 50.0 : 100.0, Velocity)
	set_pev(Victim, pev_velocity, Velocity)
	
	return HAM_IGNORED
}

public fw_Weapon_PrimaryAttack(Ent)
{
	static id; id = pev(Ent, pev_owner)
	pev(id, pev_punchangle, g_Recoil[id])
	
	return HAM_IGNORED
}

public fw_Weapon_PrimaryAttack_Post(Ent)
{
	static id; id = pev(Ent, pev_owner)
	
	if(Get_BitVar(g_Had_Weapon, id))
	{
		static Float:Push[3]
		pev(id, pev_punchangle, Push)
		xs_vec_sub(Push, g_Recoil[id], Push)
		
		xs_vec_mul_scalar(Push, RECOIL, Push)
		xs_vec_add(Push, g_Recoil[id], Push)
		
		Push[1] *= 0.5
		
		set_pev(id, pev_punchangle, Push)
	}
}

public fw_Item_AddToPlayer_Post(ent, id)
{
	if(!pev_valid(ent))
		return HAM_IGNORED
		
	if(pev(ent, pev_impulse) == WEAPON_SECRETCODE)
	{
		Set_BitVar(g_Had_Weapon, id)
		set_pev(ent, pev_impulse, 0)
	}		

	return HAM_HANDLED	
}

public fw_Item_PostFrame(ent)
{
	if(!pev_valid(ent))
		return HAM_IGNORED
	
	static id
	id = pev(ent, pev_owner)
	
	if(is_user_alive(id) && Get_BitVar(g_Had_Weapon, id))
	{	
		static Float:flNextAttack; flNextAttack = get_pdata_float(id, 83, 5)
		static bpammo; bpammo = cs_get_user_bpammo(id, CSW_BASEDON)
		static iClip; iClip = get_pdata_int(ent, 51, 4)
		static fInReload; fInReload = get_pdata_int(ent, 54, 4)
		
		if(fInReload && flNextAttack <= 0.0)
		{
			static temp1; temp1 = min(CLIP - iClip, bpammo)

			set_pdata_int(ent, 51, iClip + temp1, 4)
			cs_set_user_bpammo(id, CSW_BASEDON, bpammo - temp1)		
			
			set_pdata_int(ent, 54, 0, 4)
			
			fInReload = 0
		}		
	}
	
	return HAM_IGNORED	
}

public fw_Weapon_Reload(ent)
{
	static id; id = pev(ent, pev_owner)
	if(!is_user_alive(id))
		return HAM_IGNORED
	if(!Get_BitVar(g_Had_Weapon, id))
		return HAM_IGNORED
	
	g_Clip[id] = -1
	
	static bpammo; bpammo = cs_get_user_bpammo(id, CSW_BASEDON)
	static iClip; iClip = get_pdata_int(ent, 51, 4)
	
	if(bpammo <= 0) return HAM_SUPERCEDE
	
	if(iClip >= CLIP) return HAM_SUPERCEDE		
		
	g_Clip[id] = iClip

	return HAM_HANDLED
}

public fw_Weapon_Reload_Post(ent)
{
	static id; id = pev(ent, pev_owner)
	if(!is_user_alive(id))
		return HAM_IGNORED
	if(!Get_BitVar(g_Had_Weapon, id))
		return HAM_IGNORED

	if (g_Clip[id] == -1)
		return HAM_IGNORED
	
	set_pdata_int(ent, 51, g_Clip[id], 4)
	set_pdata_int(ent, 54, 1, 4)
	
	set_weapon_anim(id, RELOAD_ANIM)
	set_pdata_float(id, 83, RELOAD_TIME, 5)

	return HAM_HANDLED
}

stock Make_BulletHole(id, Float:Origin[3], Float:Damage)
{
	// Find target
	static Decal; Decal = random_num(41, 45)
	static LoopTime; 
	
	if(Damage > 100.0) LoopTime = 2
	else LoopTime = 1
	
	for(new i = 0; i < LoopTime; i++)
	{
		// Put decal on "world" (a wall)
		message_begin(MSG_BROADCAST, SVC_TEMPENTITY)
		write_byte(TE_WORLDDECAL)
		engfunc(EngFunc_WriteCoord, Origin[0])
		engfunc(EngFunc_WriteCoord, Origin[1])
		engfunc(EngFunc_WriteCoord, Origin[2])
		write_byte(Decal)
		message_end()
		
		// Show sparcles
		message_begin(MSG_BROADCAST, SVC_TEMPENTITY)
		write_byte(TE_GUNSHOTDECAL)
		engfunc(EngFunc_WriteCoord, Origin[0])
		engfunc(EngFunc_WriteCoord, Origin[1])
		engfunc(EngFunc_WriteCoord, Origin[2])
		write_short(id)
		write_byte(Decal)
		message_end()
	}
}

public Make_BulletSmoke(id, TrResult)
{
	static Float:vecSrc[3], Float:vecEnd[3], TE_FLAG
	
	get_weapon_attachment(id, vecSrc)
	global_get(glb_v_forward, vecEnd)
    
	xs_vec_mul_scalar(vecEnd, 8192.0, vecEnd)
	xs_vec_add(vecSrc, vecEnd, vecEnd)

	get_tr2(TrResult, TR_vecEndPos, vecSrc)
	get_tr2(TrResult, TR_vecPlaneNormal, vecEnd)
    
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
	write_short(g_SmokePuff_SprId)
	write_byte(2)
	write_byte(50)
	write_byte(TE_FLAG)
	message_end()
}


stock hook_ent2(ent, Float:VicOrigin[3], Float:speed, Float:multi, type)
{
	static Float:fl_Velocity[3]
	static Float:EntOrigin[3]
	static Float:EntVelocity[3]
	
	pev(ent, pev_velocity, EntVelocity)
	pev(ent, pev_origin, EntOrigin)
	static Float:distance_f
	distance_f = get_distance_f(EntOrigin, VicOrigin)
	
	static Float:fl_Time; fl_Time = distance_f / speed
	static Float:fl_Time2; fl_Time2 = distance_f / (speed * multi)
	
	if(type == 1)
	{
		fl_Velocity[0] = ((VicOrigin[0] - EntOrigin[0]) / fl_Time2) * 1.5
		fl_Velocity[1] = ((VicOrigin[1] - EntOrigin[1]) / fl_Time2) * 1.5
		fl_Velocity[2] = (VicOrigin[2] - EntOrigin[2]) / fl_Time		
	} else if(type == 2) {
		fl_Velocity[0] = ((EntOrigin[0] - VicOrigin[0]) / fl_Time2) * 1.5
		fl_Velocity[1] = ((EntOrigin[1] - VicOrigin[1]) / fl_Time2) * 1.5
		fl_Velocity[2] = (EntOrigin[2] - VicOrigin[2]) / fl_Time
	}

	xs_vec_add(EntVelocity, fl_Velocity, fl_Velocity)
	set_pev(ent, pev_velocity, fl_Velocity)
}

stock get_weapon_attachment(id, Float:output[3], Float:fDis = 40.0)
{ 
	static Float:vfEnd[3], viEnd[3] 
	get_user_origin(id, viEnd, 3)  
	IVecFVec(viEnd, vfEnd) 
	
	static Float:fOrigin[3], Float:fAngle[3]
	
	pev(id, pev_origin, fOrigin) 
	pev(id, pev_view_ofs, fAngle)
	
	xs_vec_add(fOrigin, fAngle, fOrigin) 
	
	static Float:fAttack[3]
	
	xs_vec_sub(vfEnd, fOrigin, fAttack)
	xs_vec_sub(vfEnd, fOrigin, fAttack) 
	
	static Float:fRate
	
	fRate = fDis / vector_length(fAttack)
	xs_vec_mul_scalar(fAttack, fRate, fAttack)
	
	xs_vec_add(fOrigin, fAttack, output)
}

stock Eject_Shell(id, Shell_ModelIndex, Float:Time) // By Dias
{
	static Ent; Ent = get_pdata_cbase(id, 373, 5)
	if(!pev_valid(Ent))
		return

        set_pdata_int(Ent, 57, Shell_ModelIndex, 4)
        set_pdata_float(id, 111, get_gametime() + Time)
}

stock set_weapon_anim(id, anim)
{
	set_pev(id, pev_weaponanim, anim)
	
	message_begin(MSG_ONE_UNRELIABLE, SVC_WEAPONANIM, {0, 0, 0}, id)
	write_byte(anim)
	write_byte(pev(id, pev_body))
	message_end()
}

public Give_FuckingAmmo(id, CSWID, Silent)
{
	static Amount, Max
	switch(CSWID)
	{
		
		case CSW_P228: {Amount = 10; Max = 104;}
		case CSW_SCOUT: {Amount = 6; Max = 180;}
		case CSW_XM1014: {Amount = 8; Max = 64;}
		case CSW_MAC10: {Amount = 16; Max = 200;}
		case CSW_AUG: {Amount = 6; Max = 180;}
		case CSW_ELITE: {Amount = 16; Max = 200;}
		case CSW_FIVESEVEN: {Amount = 4; Max = 200;}
		case CSW_UMP45: {Amount = 16; Max = 200;}
		case CSW_SG550: {Amount = 6; Max = 180;}
		case CSW_GALIL: {Amount = 6; Max = 180;}
		case CSW_FAMAS: {Amount = 6; Max = 180;}
		case CSW_USP: {Amount = 18; Max = 200;}
		case CSW_GLOCK18: {Amount = 16; Max = 200;}
		case CSW_AWP: {Amount = 6; Max = 60;}
		case CSW_MP5NAVY: {Amount = 16; Max = 200;}
		case CSW_M249: {Amount = 4; Max = 200;}
		case CSW_M3: {Amount = 8; Max = 64;}
		case CSW_M4A1: {Amount = 7; Max = 180;}
		case CSW_TMP: {Amount = 7; Max = 200;}
		case CSW_G3SG1: {Amount = 7; Max = 180;}
		case CSW_DEAGLE: {Amount = 10; Max = 70;}
		case CSW_SG552: {Amount = 7; Max = 180;}
		case CSW_AK47: {Amount = 7; Max = 180;}
		case CSW_P90: {Amount = 4; Max = 200;}
		default: {Amount = 0; Max = 0;}
	}

	for(new i = 0; i < Amount; i++) give_ammo(id, Silent, CSWID, Max)
}

public give_ammo(id, silent, CSWID, Max)
{
	static Amount, Name[32]
		
	switch(CSWID)
	{
		case CSW_P228: {Amount = 13; formatex(Name, sizeof(Name), "357sig");}
		case CSW_SCOUT: {Amount = 30; formatex(Name, sizeof(Name), "762nato");}
		case CSW_XM1014: {Amount = 8; formatex(Name, sizeof(Name), "buckshot");}
		case CSW_MAC10: {Amount = 12; formatex(Name, sizeof(Name), "45acp");}
		case CSW_AUG: {Amount = 30; formatex(Name, sizeof(Name), "556nato");}
		case CSW_ELITE: {Amount = 30; formatex(Name, sizeof(Name), "9mm");}
		case CSW_FIVESEVEN: {Amount = 50; formatex(Name, sizeof(Name), "57mm");}
		case CSW_UMP45: {Amount = 12; formatex(Name, sizeof(Name), "45acp");}
		case CSW_SG550: {Amount = 30; formatex(Name, sizeof(Name), "556nato");}
		case CSW_GALIL: {Amount = 30; formatex(Name, sizeof(Name), "556nato");}
		case CSW_FAMAS: {Amount = 30; formatex(Name, sizeof(Name), "556nato");}
		case CSW_USP: {Amount = 12; formatex(Name, sizeof(Name), "45acp");}
		case CSW_GLOCK18: {Amount = 30; formatex(Name, sizeof(Name), "9mm");}
		case CSW_AWP: {Amount = 10; formatex(Name, sizeof(Name), "338magnum");}
		case CSW_MP5NAVY: {Amount = 30; formatex(Name, sizeof(Name), "9mm");}
		case CSW_M249: {Amount = 30; formatex(Name, sizeof(Name), "556natobox");}
		case CSW_M3: {Amount = 8; formatex(Name, sizeof(Name), "buckshot");}
		case CSW_M4A1: {Amount = 30; formatex(Name, sizeof(Name), "556nato");}
		case CSW_TMP: {Amount = 30; formatex(Name, sizeof(Name), "9mm");}
		case CSW_G3SG1: {Amount = 30; formatex(Name, sizeof(Name), "762nato");}
		case CSW_DEAGLE: {Amount = 7; formatex(Name, sizeof(Name), "50ae");}
		case CSW_SG552: {Amount = 30; formatex(Name, sizeof(Name), "556nato");}
		case CSW_AK47: {Amount = 30; formatex(Name, sizeof(Name), "762nato");}
		case CSW_P90: {Amount = 50; formatex(Name, sizeof(Name), "57mm");}
	}
	
	if(!silent) emit_sound(id, CHAN_ITEM, "items/9mmclip1.wav", VOL_NORM, ATTN_NORM, 0, PITCH_NORM)
	ExecuteHamB(Ham_GiveAmmo, id, Amount, Name, Max)
}

stock Get_SpeedVector(const Float:origin1[3],const Float:origin2[3],Float:speed, Float:new_velocity[3])
{
	new_velocity[0] = origin2[0] - origin1[0]
	new_velocity[1] = origin2[1] - origin1[1]
	new_velocity[2] = origin2[2] - origin1[2]
	new Float:num = floatsqroot(speed*speed / (new_velocity[0]*new_velocity[0] + new_velocity[1]*new_velocity[1] + new_velocity[2]*new_velocity[2]))
	new_velocity[0] *= (num * 2.0)
	new_velocity[1] *= (num * 2.0)
	new_velocity[2] *= (num / 2.0)
}  
