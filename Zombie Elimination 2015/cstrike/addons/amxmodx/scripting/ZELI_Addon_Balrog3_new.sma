#include <amxmodx>
#include <fakemeta>
#include <fakemeta_util>
#include <hamsandwich>
#include <cstrike>
#include <zombie_eli>

#define PLUGIN "Balrog-III"
#define VERSION "1.0"
#define AUTHOR "Dias"

#define V_MODEL "models/v_balrog3.mdl"
#define P_MODEL "models/p_balrog3.mdl"
//#define W_MODEL "models/w_balrog3.mdl"

#define DAMAGE 24
#define BPAMMO 240
#define ACTIVE_CLIP 15

#define CSW_BALROG3 CSW_MP5NAVY
#define weapon_balrog3 "weapon_mp5navy"

#define WEAPON_SECRETCODE 4962
#define WEAPON_EVENT "events/mp5n.sc"
#define OLD_W_MODEL "models/w_mp5.mdl"

new const Balrog3_Sounds[6][] =
{
	"weapons/balrig3-1.wav",
	"weapons/balrig3-2.wav",
	"weapons/balrig3_boltpull.wav",
	"weapons/balrig3_clipin.wav",
	"weapons/balrig3_clipout.wav",
	"weapons/balrig3_draw.wav"
}

#define EXPLOSE_SPR "sprites/balrog5stack.spr"

enum
{
	ANIM_IDLE = 0,
	ANIM_DRAW,
	ANIM_RELOAD,
	ANIM_SHOOT_A,
	ANIM_SHOOT_B
}


new g_Had_Balrog3[33], g_Shoot_Special[33], g_Holding_Attack[33], g_Shoot_Count[33], g_Old_Weapon[33], g_Current_Weapon[33]
new g_Exp_SprId, g_balrog3_event, g_ShellId, g_SmokePuff_SprId

new g_Balrog3, g_PyroTech
new g_Balrog32, g_Medic

public plugin_init() 
{
	register_plugin(PLUGIN, VERSION, AUTHOR)
	
	register_event("CurWeapon", "Event_CurWeapon", "be", "1=1")
	
	register_forward(FM_UpdateClientData, "fw_UpdateClientData_Post", 1)	
	register_forward(FM_PlaybackEvent, "fw_PlaybackEvent")	
	register_forward(FM_SetModel, "fw_SetModel")
	register_forward(FM_CmdStart, "fw_CmdStart")		
	
	RegisterHam(Ham_TraceAttack, "worldspawn", "fw_TraceAttack")
	RegisterHam(Ham_TraceAttack, "player", "fw_TraceAttack")	
	RegisterHam(Ham_Weapon_PrimaryAttack, weapon_balrog3, "fw_Weapon_PrimaryAttack")
	RegisterHam(Ham_Weapon_PrimaryAttack, weapon_balrog3, "fw_Weapon_PrimaryAttack_Post", 1)
	RegisterHam(Ham_Item_AddToPlayer, weapon_balrog3, "fw_Item_AddToPlayer_Post", 1)
	
	register_clcmd("admin_get_balrog3", "Get_Balrog3", ADMIN_BAN)
	
	g_PyroTech = ZombieEli_GetClassID("Pyro Tech")
	g_Balrog3 = ZombieEli_RegisterWeapon(g_Medic, "CSO Balrog-III", WPN_PRIMARY, 6, 0)
	
	g_Medic = ZombieEli_GetClassID("Medic")
	g_Balrog32 = ZombieEli_RegisterWeapon(g_Medic, "CSO Balrog-III", WPN_PRIMARY, 6, 0)
}

public plugin_precache()
{
	engfunc(EngFunc_PrecacheModel, V_MODEL)
	engfunc(EngFunc_PrecacheModel, P_MODEL)
	//engfunc(EngFunc_PrecacheModel, W_MODEL)
	
	for(new i = 0; i < sizeof(Balrog3_Sounds); i++)
		engfunc(EngFunc_PrecacheSound, Balrog3_Sounds[i])
		
	g_Exp_SprId = engfunc(EngFunc_PrecacheModel, EXPLOSE_SPR)
	g_SmokePuff_SprId = engfunc(EngFunc_PrecacheModel, "sprites/wall_puff1.spr")
	g_ShellId = engfunc(EngFunc_PrecacheModel, "models/pshell.mdl")
	
	register_forward(FM_PrecacheEvent, "fw_PrecacheEvent_Post", 1)
}

public zeli_weapon_selected(id, ItemID, ClassID)
{
	if(ItemID == g_Balrog3) Get_Balrog3(id)
	if(ItemID == g_Balrog3) Get_Balrog32(id)
}

public zeli_weapon_removed(id, ItemID)
{
	if(ItemID == g_Balrog3) Remove_Balrog3(id)
	if(ItemID == g_Balrog3) Remove_Balrog32(id)
}

public fw_PrecacheEvent_Post(type, const name[])
{
	if(equal(WEAPON_EVENT, name))
		g_balrog3_event = get_orig_retval()		
}

public Get_Balrog3(id)
{
	if(!is_user_alive(id))
		return
		
	g_Had_Balrog3[id] = 1
	g_Shoot_Special[id] = 0
	g_Holding_Attack[id] = 0
	g_Shoot_Count[id] = 0
	
	fm_give_item(id, weapon_balrog3)
	
	cs_set_user_bpammo(id, CSW_BALROG3, BPAMMO)
}

public Remove_Balrog3(id)
{
	if(!is_user_connected(id))
		return
		
	g_Had_Balrog3[id] = 0
	g_Shoot_Special[id] = 0	
}

public Event_CurWeapon(id)
{
	if(!is_user_alive(id))
		return
	
	if(get_user_weapon(id) != g_Current_Weapon[id]) g_Current_Weapon[id] = get_user_weapon(id)
	
	if(get_user_weapon(id) == CSW_BALROG3 && g_Had_Balrog3[id])
	{
		if(g_Old_Weapon[id] != CSW_BALROG3)
		{
			set_pev(id, pev_viewmodel2, V_MODEL)
			set_pev(id, pev_weaponmodel2, P_MODEL)
		}
	}
	
	g_Old_Weapon[id] = get_user_weapon(id)
}

public fw_UpdateClientData_Post(id, sendweapons, cd_handle)
{
	if(!is_user_alive(id) || !is_user_connected(id))
		return FMRES_IGNORED	
	if(get_user_weapon(id) == CSW_BALROG3 && g_Had_Balrog3[id])
		set_cd(cd_handle, CD_flNextAttack, get_gametime() + 0.001) 
	
	return FMRES_HANDLED
}

public fw_PlaybackEvent(flags, invoker, eventid, Float:delay, Float:origin[3], Float:angles[3], Float:fparam1, Float:fparam2, iParam1, iParam2, bParam1, bParam2)
{
	if (!is_user_connected(invoker))
		return FMRES_IGNORED	
	if(get_user_weapon(invoker) != CSW_BALROG3 || !g_Had_Balrog3[invoker])
		return FMRES_IGNORED
	if(eventid != g_balrog3_event)
		return FMRES_IGNORED
	
	engfunc(EngFunc_PlaybackEvent, flags | FEV_HOSTONLY, invoker, eventid, delay, origin, angles, fparam1, fparam2, iParam1, iParam2, bParam1, bParam2)
	
	if(!g_Shoot_Special[invoker] && cs_get_user_bpammo(invoker, CSW_BALROG3) > 0)
	{
		g_Shoot_Count[invoker]++
		if(g_Shoot_Count[invoker] >= ACTIVE_CLIP)
		{
			g_Shoot_Special[invoker] = 1
			
			static Ent; Ent = fm_get_user_weapon_entity(invoker, CSW_BALROG3)
			if(pev_valid(Ent)) g_Shoot_Count[invoker] = cs_get_weapon_ammo(Ent)
		}
	} else if(g_Shoot_Special[invoker]) {
		cs_set_user_bpammo(invoker, CSW_BALROG3, cs_get_user_bpammo(invoker, CSW_BALROG3) - 1)
		
		if(cs_get_user_bpammo(invoker, CSW_BALROG3) <= 0)
		{
			g_Shoot_Special[invoker] = 0
			g_Shoot_Count[invoker] = 0
		}
	}
	
	set_weapon_anim(invoker, g_Shoot_Special[invoker] == 1 ? ANIM_SHOOT_B : ANIM_SHOOT_A)
	emit_sound(invoker, CHAN_WEAPON, g_Shoot_Special[invoker] == 1 ? Balrog3_Sounds[1] : Balrog3_Sounds[0], VOL_NORM, ATTN_NORM, 0, PITCH_NORM)
	
	Eject_Shell(invoker, g_ShellId, 0.0)
		
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
		static weapon; weapon = fm_find_ent_by_owner(-1, weapon_balrog3, entity)
		
		if(!pev_valid(weapon))
			return FMRES_IGNORED;
		
		if(g_Had_Balrog3[iOwner])
		{
			Remove_Balrog3(iOwner)
			
			set_pev(weapon, pev_impulse, WEAPON_SECRETCODE)
			//engfunc(EngFunc_SetModel, entity, W_MODEL)
			
			return FMRES_SUPERCEDE
		}
	}

	return FMRES_IGNORED;
}

public fw_CmdStart(id, uc_handle, seed)
{
	if(!is_user_alive(id))
		return
	if(g_Current_Weapon[id] != CSW_BALROG3 || !g_Had_Balrog3[id])
		return
		
	static NewButton; NewButton = get_uc(uc_handle, UC_Buttons)
	static OldButton; OldButton = pev(id, pev_oldbuttons)
	
	if(NewButton & IN_ATTACK)
	{
		if(!g_Holding_Attack[id]) g_Holding_Attack[id] = 1
	} else if((NewButton & IN_ATTACK2) && !(OldButton & IN_ATTACK2)) {
		if(cs_get_user_zoom(id) == 1) cs_set_user_zoom(id, CS_SET_AUGSG552_ZOOM, 1)
		else cs_set_user_zoom(id, CS_SET_NO_ZOOM, 1)
	} else {
		if(OldButton & IN_ATTACK)
		{
			if(g_Holding_Attack[id]) 
			{
				g_Holding_Attack[id] = 0
				g_Shoot_Count[id] = 0
				g_Shoot_Special[id] = 0
			}
		}
	}
}

public fw_TraceAttack(Victim, Attacker, Float:Damage, Float:Direction[3], Ptr, DamageBits)
{
	if(!is_user_alive(Attacker))
		return HAM_IGNORED	
	if(get_user_weapon(Attacker) != CSW_BALROG3 || !g_Had_Balrog3[Attacker])
		return HAM_IGNORED
		
	static Float:flEnd[3], Float:vecPlane[3]
	
	get_tr2(Ptr, TR_vecEndPos, flEnd)
	get_tr2(Ptr, TR_vecPlaneNormal, vecPlane)		
		
	if(!is_user_alive(Victim))
	{
		Make_BulletHole(Attacker, flEnd, Damage)
		Make_BulletSmoke(Attacker, Ptr)
	}
	
	if(g_Shoot_Special[Attacker])
	{
		Make_BalrogEffect(Attacker, Ptr)
		radius_damage(Attacker, flEnd, float(DAMAGE), 96.0)
	}
	
	SetHamParamFloat(3, float(DAMAGE))
	
	return HAM_IGNORED
}

public fw_Weapon_PrimaryAttack(Ent)
{
	if(!pev_valid(Ent))
		return
	static Id; Id = pev(Ent, pev_owner)
	if(!g_Had_Balrog3[Id])
		return
	
	if(g_Shoot_Special[Id]) set_pdata_float(Ent, 62, 0.4, 4)
	else set_pdata_float(Ent, 62, 0.2, 4)
}

public fw_Weapon_PrimaryAttack_Post(Ent)
{
	if(!pev_valid(Ent))
		return
	static Id; Id = pev(Ent, pev_owner)
	if(!g_Had_Balrog3[Id])
		return
	
	if(g_Shoot_Special[Id] && cs_get_weapon_ammo(Ent) > 0) 
	{
		cs_set_weapon_ammo(Ent, g_Shoot_Count[Id])
		set_pdata_float(Ent, 46, get_pdata_float(Ent, 46, 4) * 0.75, 4)	
	}
}

public fw_Item_AddToPlayer_Post(ent, id)
{
	if(!pev_valid(ent))
		return HAM_IGNORED
		
	if(pev(ent, pev_impulse) == WEAPON_SECRETCODE)
	{
		g_Had_Balrog3[id] = 1
		set_pev(ent, pev_impulse, 0)
	}		

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

public Make_BalrogEffect(id, TrResult)
{
	static Float:vecSrc[3], Float:vecEnd[3], TE_FLAG
	
	get_weapon_attachment(id, vecSrc)
	global_get(glb_v_forward, vecEnd)
    
	xs_vec_mul_scalar(vecEnd, 8192.0, vecEnd)
	xs_vec_add(vecSrc, vecEnd, vecEnd)

	get_tr2(TrResult, TR_vecEndPos, vecSrc)
	get_tr2(TrResult, TR_vecPlaneNormal, vecEnd)
    
	xs_vec_mul_scalar(vecEnd, 5.0, vecEnd)
	xs_vec_add(vecSrc, vecEnd, vecEnd)
    
	TE_FLAG |= TE_EXPLFLAG_NODLIGHTS
	TE_FLAG |= TE_EXPLFLAG_NOSOUND
	TE_FLAG |= TE_EXPLFLAG_NOPARTICLES
	
	engfunc(EngFunc_MessageBegin, MSG_PAS, SVC_TEMPENTITY, vecEnd, 0)
	write_byte(TE_EXPLOSION)
	engfunc(EngFunc_WriteCoord, vecEnd[0])
	engfunc(EngFunc_WriteCoord, vecEnd[1])
	engfunc(EngFunc_WriteCoord, vecEnd[2])
	write_short(g_Exp_SprId)
	write_byte(5)
	write_byte(30)
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

stock radius_damage(id, Float:Origin[3], Float:Damage, Float:Radius)
{
	static Victim; Victim = -1

	while((Victim = engfunc(EngFunc_FindEntityInSphere, Victim, Origin, Radius)) != 0)
	{
		if(!is_user_alive(Victim) || id == Victim) 
			continue

		ExecuteHamB(Ham_TakeDamage, Victim, fm_get_user_weapon_entity(id, get_user_weapon(id)), id, Damage, DMG_BULLET)
	}
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
	if(!is_user_alive(id))
		return
	
	set_pev(id, pev_weaponanim, anim)
	
	message_begin(MSG_ONE_UNRELIABLE, SVC_WEAPONANIM, {0, 0, 0}, id)
	write_byte(anim)
	write_byte(pev(id, pev_body))
	message_end()
}
/* AMXX-Studio Notes - DO NOT MODIFY BELOW HERE
*{\\ rtf1\\ ansi\\ deff0{\\ fonttbl{\\ f0\\ fnil Tahoma;}}\n\\ viewkind4\\ uc1\\ pard\\ lang1033\\ f0\\ fs16 \n\\ par }
*/
