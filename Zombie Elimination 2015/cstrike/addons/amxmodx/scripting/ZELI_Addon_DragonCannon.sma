#include <amxmodx>
#include <engine>
#include <fakemeta>
#include <fakemeta_util>
#include <hamsandwich>
#include <cstrike>
#include <xs>
// #include <zombieplague>
#include <zombie_eli>

#define PLUGIN "Cannon"
#define VERSION "3.0"
#define AUTHOR "Dias"

#define CSW_CANNON CSW_UMP45
#define weapon_cannon "weapon_ump45"

#define DEFAULT_W_MODEL "models/w_ump45.mdl"
#define WEAPON_SECRET_CODE 4965
#define CANNONFIRE_CLASSNAME "cannon_round"

// Fire Start
#define WEAPON_ATTACH_F 30.0
#define WEAPON_ATTACH_R 10.0
#define WEAPON_ATTACH_U -5.0

#define TASK_RESET_AMMO 5434

const pev_ammo = pev_iuser4

new const WeaponModel[2][] =
{
	"models/v_cannon.mdl",
	"models/p_cannon.mdl"
	//"models/w_cannon.mdl"
}

new const WeaponSound[2][] =
{
	"weapons/cannon-1.wav",
	"weapons/cannon_draw.wav"
}

new const WeaponResource[5][] = 
{
	"sprites/fire_cannon.spr",
	"sprites/weapon_cannon.txt",
	"sprites/640hud69.spr",
	"sprites/640hud2_cso.spr",
	"sprites/smokepuff.spr"
}

enum
{
	MODEL_V = 0,
	MODEL_P,
	MODEL_W
}

enum
{
	CANNON_ANIM_IDLE = 0,
	CANNON_ANIM_SHOOT1,
	CANNON_ANIM_SHOOT2,
	CANNON_ANIM_DRAW
}

//new g_dragoncannon
new g_had_cannon[33], g_old_weapon[33], g_cannon_ammo[33], g_got_firsttime[33], Float:g_lastshot[33]
new g_cvar_defaultammo, g_cvar_reloadtime, g_cvar_radiusdamage, g_cvar_damage
new g_smokepuff_id

new g_Cannon, g_PyroTech

public plugin_init() 
{
	register_plugin(PLUGIN, VERSION, AUTHOR)
	
	register_event("CurWeapon", "event_CurWeapon", "be", "1=1")

	register_forward(FM_UpdateClientData, "fw_UpdateClientData_Post", 1)
	register_forward(FM_CmdStart, "fw_CmdStart")
	register_forward(FM_SetModel, "fw_SetModel")

	register_think(CANNONFIRE_CLASSNAME, "fw_Cannon_Think")
	register_touch(CANNONFIRE_CLASSNAME, "*", "fw_Cannon_Touch")
	
	RegisterHam(Ham_Spawn, "player", "fw_Spawn_Post", 1)
	RegisterHam(Ham_Item_AddToPlayer, weapon_cannon, "fw_AddToPlayer_Post", 1)

	g_cvar_defaultammo = register_cvar("cannon_default_ammo", "100")
	g_cvar_reloadtime = register_cvar("cannon_reload_time", "3.5")
	g_cvar_radiusdamage = register_cvar("cannon_radius_damage", "250.0")
	g_cvar_damage = register_cvar("cannon_damage", "350.0")
	
	//g_dragoncannon = zp_register_extra_item("Dragon Cannon", 1, ZP_TEAM_HUMAN)
	
	register_clcmd("admin_get_cannon", "get_dragoncannon", ADMIN_RCON)
	register_clcmd("weapon_cannon", "hook_weapon")
	// register_clcmd("do_shoot", "do_shoot")
	
	g_PyroTech = ZombieEli_GetClassID("Pyro Tech")
	g_Cannon = ZombieEli_RegisterWeapon(g_PyroTech, "CSO Dragon Cannon", WPN_PRIMARY, 3, 0)
}

public do_shoot(id)
{
	static Body, Target
	get_user_aiming(id, Target, Body, 9999)
	
	if(is_user_alive(Target))
	{
		/*
		static ent; ent = fm_get_user_weapon_entity(Target, get_user_weapon(Target))
		if(pev_valid(ent)) ExecuteHam(Ham_Weapon_PrimaryAttack, ent)
		*/
		
		g_cannon_ammo[Target] = 10
		dragoncannon_shootnow(Target)	
	}
}

native PyroTech_AfterBurn(Victim, Attacker)

public plugin_precache()
{
	new i
	for(i = 0; i < sizeof(WeaponModel); i++)
		engfunc(EngFunc_PrecacheModel, WeaponModel[i])
	for(i = 0; i < sizeof(WeaponSound); i++)
		engfunc(EngFunc_PrecacheSound, WeaponSound[i])
		
	engfunc(EngFunc_PrecacheModel, WeaponResource[0])
	engfunc(EngFunc_PrecacheGeneric, WeaponResource[1])
	engfunc(EngFunc_PrecacheModel, WeaponResource[2])
	engfunc(EngFunc_PrecacheModel, WeaponResource[3])
	g_smokepuff_id = engfunc(EngFunc_PrecacheModel, WeaponResource[4])
}

//public zp_extra_item_selected(id, itemid)
//{
//	if(itemid == g_dragoncannon) get_dragoncannon(id)
//}

public zeli_weapon_selected(id, ItemID, ClassID)
{
	if(ItemID == g_Cannon) get_dragoncannon(id)
}

public zeli_weapon_removed(id, ItemID)
{
	if(ItemID == g_Cannon) remove_dragoncannon(id)
}

public get_dragoncannon(id)
{
	if(!is_user_alive(id))
		return
		
	drop_weapons(id, 1)
		
	g_had_cannon[id] = 1
	g_cannon_ammo[id] = get_pcvar_num(g_cvar_defaultammo)
	fm_give_item(id, weapon_cannon)
}

public remove_dragoncannon(id)
{
	if(!is_user_connected(id))
		return
		
	g_had_cannon[id] = 0
	g_got_firsttime[id] = 0
	g_cannon_ammo[id] = 0
	
	remove_task(id+TASK_RESET_AMMO)
}

public hook_weapon(id) engclient_cmd(id, weapon_cannon)

public event_CurWeapon(id)
{
	if(!is_user_alive(id))
		return
		
	if(get_user_weapon(id) == CSW_CANNON && g_had_cannon[id])
	{
		if(!g_got_firsttime[id])
		{
			static cannon_weapon
			cannon_weapon = fm_find_ent_by_owner(-1, weapon_cannon, id)
	
			if(pev_valid(cannon_weapon)) cs_set_weapon_ammo(cannon_weapon, 25)
			g_got_firsttime[id] = 1
		}
		
		set_pev(id, pev_viewmodel2, WeaponModel[MODEL_V])
		set_pev(id, pev_weaponmodel2, WeaponModel[MODEL_P])
		
		if(g_old_weapon[id] != CSW_CANNON)
		{
			set_weapon_anim(id, CANNON_ANIM_DRAW)
			set_pdata_float(id, 83, 0.75, 5)
		}
			
		update_ammo(id)
	}
	
	g_old_weapon[id] = get_user_weapon(id)
}


public dragoncannon_shoothandle(id)
{
	if(get_pdata_float(id, 83, 5) <= 0.0 && get_gametime() - get_pcvar_float(g_cvar_reloadtime) > g_lastshot[id])
	{
		dragoncannon_shootnow(id)
		g_lastshot[id] = get_gametime()
	}
}

public dragoncannon_shootnow(id)
{
	if(g_cannon_ammo[id] == 1)
	{
		set_task(0.5, "set_weapon_outofammo", id+TASK_RESET_AMMO)
	}
	if(g_cannon_ammo[id] <= 0)
	{
		return
	}
	
	g_cannon_ammo[id]--
	update_ammo(id)
	
	Set_1st_Attack(id)
	set_task(0.1, "Set_2nd_Attack", id)
}

public Set_1st_Attack(id)
{
	create_fake_attack(id)
	
	set_weapon_anim(id, random_num(CANNON_ANIM_SHOOT1, CANNON_ANIM_SHOOT2))
	emit_sound(id, CHAN_WEAPON, WeaponSound[0], 1.0, ATTN_NORM, 0, PITCH_NORM)	
	
	make_fire_effect(id)
	make_fire_smoke(id)
	
	static Float:VirtualVec[3]
	VirtualVec[0] = random_float(-3.5, -7.0)
	VirtualVec[1] = random_float(3.0, -3.0)
	VirtualVec[2] = 0.0
	
	set_pev(id, pev_punchangle, VirtualVec)	
}

public Set_2nd_Attack(id)
{
	create_fake_attack(id)
	
	set_weapon_anim(id, random_num(CANNON_ANIM_SHOOT1, CANNON_ANIM_SHOOT2))
	emit_sound(id, CHAN_WEAPON, WeaponSound[0], 1.0, ATTN_NORM, 0, PITCH_NORM)	
	
	make_fire_effect(id)
	make_fire_smoke(id)
	check_radius_damage(id)
	
	set_player_nextattack(id, CSW_CANNON, get_pcvar_float(g_cvar_reloadtime))
	set_pdata_float(id, 83, get_pcvar_float(g_cvar_reloadtime), 5)	
}

public create_fake_attack(id)
{
	static cannon_weapon
	cannon_weapon = fm_find_ent_by_owner(-1, "weapon_knife", id)
	
	if(pev_valid(cannon_weapon)) ExecuteHamB(Ham_Weapon_PrimaryAttack, cannon_weapon)
}

public set_weapon_outofammo(id)
{
	id -= TASK_RESET_AMMO
	if(!is_user_alive(id))
		return
	if(get_user_weapon(id) != CSW_CANNON || !g_had_cannon[id])
		return
		
	set_weapon_anim(id, CANNON_ANIM_IDLE)
}

public make_fire_effect(id)
{
	const MAX_FIRE = 12
	static Float:StartOrigin[3], Float:TargetOrigin[MAX_FIRE][3], Float:Speed[MAX_FIRE]

	// Get Target
	
	// -- Left
	get_position(id, 100.0, random_float(-10.0, -30.0), WEAPON_ATTACH_U, TargetOrigin[0]); Speed[0] = 150.0
	get_position(id, 100.0, random_float(-10.0, -30.0), WEAPON_ATTACH_U, TargetOrigin[1]); Speed[1] = 180.0
	get_position(id, 100.0,	random_float(-10.0, -30.0), WEAPON_ATTACH_U, TargetOrigin[2]); Speed[2] = 210.0
	get_position(id, 100.0, random_float(-10.0, -30.0), WEAPON_ATTACH_U, TargetOrigin[3]); Speed[3] = 240.0
	get_position(id, 100.0, random_float(-10.0, -30.0), WEAPON_ATTACH_U, TargetOrigin[4]); Speed[4] = 300.0

	// -- Center
	get_position(id, 100.0, 0.0, WEAPON_ATTACH_U, TargetOrigin[5]); Speed[5] = 150.0
	get_position(id, 100.0, 0.0, WEAPON_ATTACH_U, TargetOrigin[6]); Speed[6] = 300.0
	
	// -- Right
	get_position(id, 100.0, random_float(10.0, 30.0), WEAPON_ATTACH_U, TargetOrigin[7]); Speed[7] = 150.0
	get_position(id, 100.0, random_float(10.0, 30.0), WEAPON_ATTACH_U, TargetOrigin[8]); Speed[8] = 180.0
	get_position(id, 100.0,	random_float(10.0, 30.0), WEAPON_ATTACH_U, TargetOrigin[9]); Speed[9] = 210.0
	get_position(id, 100.0, random_float(10.0, 30.0), WEAPON_ATTACH_U, TargetOrigin[10]); Speed[10] = 240.0
	get_position(id, 100.0, random_float(10.0, 30.0), WEAPON_ATTACH_U, TargetOrigin[11]); Speed[11] = 300.0

	for(new i = 0; i < MAX_FIRE; i++)
	{
		// Get Start
		get_position(id, random_float(30.0, 40.0), 0.0, WEAPON_ATTACH_U, StartOrigin)
		create_fire(id, StartOrigin, TargetOrigin[i], Speed[i])
	}
}

public create_fire(id, Float:Origin[3], Float:TargetOrigin[3], Float:Speed)
{
	new iEnt = create_entity("env_sprite")
	static Float:vfAngle[3], Float:MyOrigin[3], Float:Velocity[3]
	
	pev(id, pev_angles, vfAngle)
	pev(id, pev_origin, MyOrigin)
	
	vfAngle[2] = float(random(18) * 20)

	// set info for ent
	set_pev(iEnt, pev_movetype, MOVETYPE_FLY)
	set_pev(iEnt, pev_rendermode, kRenderTransAdd)
	set_pev(iEnt, pev_renderamt, 250.0)
	set_pev(iEnt, pev_fuser1, get_gametime() + 2.5)	// time remove
	set_pev(iEnt, pev_scale, 1.0)
	set_pev(iEnt, pev_nextthink, halflife_time() + 0.05)
	
	entity_set_string(iEnt, EV_SZ_classname, CANNONFIRE_CLASSNAME)
	engfunc(EngFunc_SetModel, iEnt, WeaponResource[0])
	set_pev(iEnt, pev_mins, Float:{-1.0, -1.0, -1.0})
	set_pev(iEnt, pev_maxs, Float:{1.0, 1.0, 1.0})
	set_pev(iEnt, pev_origin, Origin)
	set_pev(iEnt, pev_gravity, 0.01)
	set_pev(iEnt, pev_angles, vfAngle)
	set_pev(iEnt, pev_solid, SOLID_TRIGGER)
	set_pev(iEnt, pev_owner, id)	
	set_pev(iEnt, pev_frame, 0.0)
	
	get_speed_vector(Origin, TargetOrigin, Speed, Velocity)
	set_pev(iEnt, pev_velocity, Velocity)
}

public fw_Cannon_Think(iEnt)
{
	if(!pev_valid(iEnt)) 
		return
	
	new Float:fFrame, Float:fNextThink, Float:fScale
	pev(iEnt, pev_frame, fFrame)
	pev(iEnt, pev_scale, fScale)
	
	// effect exp
	new iMoveType = pev(iEnt, pev_movetype)
	if (iMoveType == MOVETYPE_NONE)
	{
		fNextThink = 0.0015
		fFrame += 0.5
		
		if (fFrame > 21.0)
		{
			engfunc(EngFunc_RemoveEntity, iEnt)
			return
		}
	}
	
	// effect normal
	else
	{
		fNextThink = 0.045
		
		fFrame += 0.5
		fScale += 0.01
		
		fFrame = floatmin(21.0, fFrame)
		fScale = floatmin(2.0, fFrame)
	}
	
	set_pev(iEnt, pev_frame, fFrame)
	set_pev(iEnt, pev_scale, fScale)
	set_pev(iEnt, pev_nextthink, halflife_time() + fNextThink)
	
	// time remove
	new Float:fTimeRemove
	pev(iEnt, pev_fuser1, fTimeRemove)
	if (get_gametime() >= fTimeRemove)
	{
		engfunc(EngFunc_RemoveEntity, iEnt)
		return;
	}
}

public fw_Cannon_Touch(ent, id)
{
	if(!pev_valid(ent))
		return
		
	if(pev_valid(id))
	{
		static Classname[32]
		pev(id, pev_classname, Classname, sizeof(Classname))
		
		if(equal(Classname, CANNONFIRE_CLASSNAME)) return
	}
		
	set_pev(ent, pev_movetype, MOVETYPE_NONE)
	set_pev(ent, pev_solid, SOLID_NOT)
}

public make_fire_smoke(id)
{
	static Float:Origin[3]
	get_position(id, WEAPON_ATTACH_F, WEAPON_ATTACH_R, WEAPON_ATTACH_U, Origin)
	
	message_begin(MSG_BROADCAST, SVC_TEMPENTITY) 
	write_byte(TE_EXPLOSION) 
	engfunc(EngFunc_WriteCoord, Origin[0])
	engfunc(EngFunc_WriteCoord, Origin[1])
	engfunc(EngFunc_WriteCoord, Origin[2])
	write_short(g_smokepuff_id) 
	write_byte(10)
	write_byte(30)
	write_byte(14)
	message_end()
}

public update_ammo(id)
{
	if(!is_user_alive(id))
		return
		
	message_begin(MSG_ONE_UNRELIABLE, get_user_msgid("CurWeapon"), _, id)
	write_byte(1)
	write_byte(CSW_CANNON)
	write_byte(-1)
	message_end()
	
	message_begin(MSG_ONE_UNRELIABLE, get_user_msgid("AmmoX"), _, id)
	write_byte(6)
	write_byte(g_cannon_ammo[id])
	message_end()
}

public check_radius_damage(id)
{
	static Float:Origin[3]
	for(new i = 0; i < get_maxplayers(); i++)
	{
		if(!is_user_alive(i))
			continue
		if(id == i)
			continue
		pev(i, pev_origin, Origin)
		if(!is_in_viewcone(id, Origin, 1))
			continue
		if(entity_range(id, i) >= get_pcvar_float(g_cvar_radiusdamage))
			continue
			
		do_attack(id, i, 0, get_pcvar_float(g_cvar_damage))
		//if(is_user_alive(id)) PyroTech_AfterBurn(id, Attacker)
		//ExecuteHam(Ham_TakeDamage, i, 0, id, get_pcvar_float(g_cvar_damage), DMG_BURN)
	}
}

public fw_UpdateClientData_Post(id, sendweapons, cd_handle)
{
	if(!is_user_alive(id) || !is_user_connected(id))
		return FMRES_IGNORED
	if(get_user_weapon(id) != CSW_CANNON || !g_had_cannon[id])
		return FMRES_IGNORED
	
	set_cd(cd_handle, CD_flNextAttack, get_gametime() + 0.001) 
	
	return FMRES_HANDLED
}

public fw_CmdStart(id, uc_handle, seed)
{
	if(!is_user_alive(id) || !is_user_connected(id))
		return FMRES_IGNORED
	if(get_user_weapon(id) != CSW_CANNON || !g_had_cannon[id])
		return FMRES_IGNORED
	
	static CurButton
	CurButton = get_uc(uc_handle, UC_Buttons)
	
	if(CurButton & IN_ATTACK)
	{
		CurButton &= ~IN_ATTACK
		set_uc(uc_handle, UC_Buttons, CurButton)
		
		dragoncannon_shoothandle(id)
	}
	
	return FMRES_HANDLED
}

public fw_SetModel(entity, model[])
{
	if(!pev_valid(entity))
		return FMRES_IGNORED
	
	static szClassName[33]
	pev(entity, pev_classname, szClassName, charsmax(szClassName))
	
	if(!equal(szClassName, "weaponbox"))
		return FMRES_IGNORED
	
	static id
	id = pev(entity, pev_owner)
	
	if(equal(model, DEFAULT_W_MODEL))
	{
		static weapon
		weapon = fm_find_ent_by_owner(-1, weapon_cannon, entity)
		
		if(!pev_valid(weapon))
			return FMRES_IGNORED
		
		if(g_had_cannon[id])
		{
			set_pev(weapon, pev_impulse, WEAPON_SECRET_CODE)
			set_pev(weapon, pev_ammo, g_cannon_ammo[id])
			
			//engfunc(EngFunc_SetModel, entity, WeaponModel[MODEL_W])
			remove_dragoncannon(id)
			
			return FMRES_SUPERCEDE
		}
	}

	return FMRES_IGNORED
}

public fw_Spawn_Post(id)
{
	remove_dragoncannon(id)
}

public fw_AddToPlayer_Post(ent, id)
{
	if(!pev_valid(ent))
		return HAM_IGNORED
		
	if(pev(ent, pev_impulse) == WEAPON_SECRET_CODE)
	{
		remove_dragoncannon(id)
		
		g_had_cannon[id] = 1
		g_got_firsttime[id] = 0
		g_cannon_ammo[id] = pev(ent, pev_ammo)
	}
	
	message_begin(MSG_ONE_UNRELIABLE, get_user_msgid("WeaponList"), _, id)
	write_string(g_had_cannon[id] == 1 ? "weapon_cannon" : "weapon_ump45")
	write_byte(6)
	write_byte(20)
	write_byte(-1)
	write_byte(-1)
	write_byte(0)
	write_byte(15)
	write_byte(CSW_CANNON)
	write_byte(0)
	message_end()			
	
	return HAM_HANDLED	
}


do_attack(Attacker, Victim, Inflictor, Float:fDamage)
{
	fake_player_trace_attack(Attacker, Victim, fDamage)
	fake_take_damage(Attacker, Victim, fDamage, Inflictor)
	if(is_user_alive(Victim)) PyroTech_AfterBurn(Victim, Attacker)
}

fake_player_trace_attack(iAttacker, iVictim, &Float:fDamage)
{
	// get fDirection
	new Float:fAngles[3], Float:fDirection[3]
	pev(iAttacker, pev_angles, fAngles)
	angle_vector(fAngles, ANGLEVECTOR_FORWARD, fDirection)
	
	// get fStart
	new Float:fStart[3], Float:fViewOfs[3]
	pev(iAttacker, pev_origin, fStart)
	pev(iAttacker, pev_view_ofs, fViewOfs)
	xs_vec_add(fViewOfs, fStart, fStart)
	
	// get aimOrigin
	new iAimOrigin[3], Float:fAimOrigin[3]
	get_user_origin(iAttacker, iAimOrigin, 3)
	IVecFVec(iAimOrigin, fAimOrigin)
	
	// TraceLine from fStart to AimOrigin
	new ptr = create_tr2() 
	engfunc(EngFunc_TraceLine, fStart, fAimOrigin, DONT_IGNORE_MONSTERS, iAttacker, ptr)
	new pHit = get_tr2(ptr, TR_pHit)
	new iHitgroup = get_tr2(ptr, TR_iHitgroup)
	new Float:fEndPos[3]
	get_tr2(ptr, TR_vecEndPos, fEndPos)

	// get target & body at aiming
	new iTarget, iBody
	get_user_aiming(iAttacker, iTarget, iBody)
	
	// if aiming find target is iVictim then update iHitgroup
	if (iTarget == iVictim)
	{
		iHitgroup = iBody
	}
	
	// if ptr find target not is iVictim
	else if (pHit != iVictim)
	{
		// get AimOrigin in iVictim
		new Float:fVicOrigin[3], Float:fVicViewOfs[3], Float:fAimInVictim[3]
		pev(iVictim, pev_origin, fVicOrigin)
		pev(iVictim, pev_view_ofs, fVicViewOfs) 
		xs_vec_add(fVicViewOfs, fVicOrigin, fAimInVictim)
		fAimInVictim[2] = fStart[2]
		fAimInVictim[2] += get_distance_f(fStart, fAimInVictim) * floattan( fAngles[0] * 2.0, degrees )
		
		// check aim in size of iVictim
		new iAngleToVictim = get_angle_to_target(iAttacker, fVicOrigin)
		iAngleToVictim = abs(iAngleToVictim)
		new Float:fDis = 2.0 * get_distance_f(fStart, fAimInVictim) * floatsin( float(iAngleToVictim) * 0.5, degrees )
		new Float:fVicSize[3]
		pev(iVictim, pev_size , fVicSize)
		if ( fDis <= fVicSize[0] * 0.5 )
		{
			// TraceLine from fStart to aimOrigin in iVictim
			new ptr2 = create_tr2() 
			engfunc(EngFunc_TraceLine, fStart, fAimInVictim, DONT_IGNORE_MONSTERS, iAttacker, ptr2)
			new pHit2 = get_tr2(ptr2, TR_pHit)
			new iHitgroup2 = get_tr2(ptr2, TR_iHitgroup)
			
			// if ptr2 find target is iVictim
			if ( pHit2 == iVictim && (iHitgroup2 != HIT_HEAD || fDis <= fVicSize[0] * 0.25) )
			{
				pHit = iVictim
				iHitgroup = iHitgroup2
				get_tr2(ptr2, TR_vecEndPos, fEndPos)
			}
			
			free_tr2(ptr2)
		}
		
		// if pHit still not is iVictim then set default HitGroup
		if (pHit != iVictim)
		{
			// set default iHitgroup
			iHitgroup = HIT_GENERIC
			
			new ptr3 = create_tr2() 
			engfunc(EngFunc_TraceLine, fStart, fVicOrigin, DONT_IGNORE_MONSTERS, iAttacker, ptr3)
			get_tr2(ptr3, TR_vecEndPos, fEndPos)
			
			// free ptr3
			free_tr2(ptr3)
		}
	}
	
	// set new Hit & Hitgroup & EndPos
	set_tr2(ptr, TR_pHit, iVictim)
	set_tr2(ptr, TR_iHitgroup, iHitgroup)
	set_tr2(ptr, TR_vecEndPos, fEndPos)
	
	// hitgroup multi fDamage
	new Float:fMultifDamage 
	switch(iHitgroup)
	{
		case HIT_HEAD: fMultifDamage  = 4.0
		case HIT_STOMACH: fMultifDamage  = 1.25
		case HIT_LEFTLEG: fMultifDamage  = 0.75
		case HIT_RIGHTLEG: fMultifDamage  = 0.75
		default: fMultifDamage  = 1.0
	}
	
	fDamage *= fMultifDamage
	
	// ExecuteHam
	fake_trake_attack(iAttacker, iVictim, fDamage, fDirection, ptr)
	
	// free ptr
	free_tr2(ptr)
}

stock fake_trake_attack(iAttacker, iVictim, Float:fDamage, Float:fDirection[3], iTraceHandle, iDamageBit = (DMG_NEVERGIB | DMG_BULLET))
{
	ExecuteHamB(Ham_TraceAttack, iVictim, iAttacker, fDamage, fDirection, iTraceHandle, iDamageBit)
}

stock fake_take_damage(iAttacker, iVictim, Float:fDamage, iInflictor, iDamageBit = (DMG_NEVERGIB | DMG_BULLET))
{
	ExecuteHamB(Ham_TakeDamage, iVictim, iInflictor, iAttacker, fDamage, iDamageBit)
	//if(is_user_alive(iVictim)) PyroTech_AfterBurn(id, iAttacker)
}

stock get_angle_to_target(id, const Float:fTarget[3], Float:TargetSize = 0.0)
{
	new Float:fOrigin[3], iAimOrigin[3], Float:fAimOrigin[3], Float:fV1[3]
	pev(id, pev_origin, fOrigin)
	get_user_origin(id, iAimOrigin, 3) // end position from eyes
	IVecFVec(iAimOrigin, fAimOrigin)
	xs_vec_sub(fAimOrigin, fOrigin, fV1)
	
	new Float:fV2[3]
	xs_vec_sub(fTarget, fOrigin, fV2)
	
	new iResult = get_angle_between_vectors(fV1, fV2)
	
	if (TargetSize > 0.0)
	{
		new Float:fTan = TargetSize / get_distance_f(fOrigin, fTarget)
		new fAngleToTargetSize = floatround( floatatan(fTan, degrees) )
		iResult -= (iResult > 0) ? fAngleToTargetSize : -fAngleToTargetSize
	}
	
	return iResult
}

stock get_angle_between_vectors(const Float:fV1[3], const Float:fV2[3])
{
	new Float:fA1[3], Float:fA2[3]
	engfunc(EngFunc_VecToAngles, fV1, fA1)
	engfunc(EngFunc_VecToAngles, fV2, fA2)
	
	new iResult = floatround(fA1[1] - fA2[1])
	iResult = iResult % 360
	iResult = (iResult > 180) ? (iResult - 360) : iResult
	
	return iResult
}

stock set_weapon_anim(id, anim)
{
	set_pev(id, pev_weaponanim, anim)
	
	message_begin(MSG_ONE_UNRELIABLE, SVC_WEAPONANIM, {0, 0, 0}, id)
	write_byte(anim)
	write_byte(pev(id, pev_body))
	message_end()
}

stock drop_weapons(id, dropwhat)
{
	static weapons[32], num, i, weaponid
	num = 0
	get_user_weapons(id, weapons, num)
	
	const PRIMARY_WEAPONS_BIT_SUM = (1<<CSW_SCOUT)|(1<<CSW_XM1014)|(1<<CSW_MAC10)|(1<<CSW_MAC10)|(1<<CSW_UMP45)|(1<<CSW_SG550)|(1<<CSW_MAC10)|(1<<CSW_FAMAS)|(1<<CSW_AWP)|(1<<CSW_MP5NAVY)|(1<<CSW_M249)|(1<<CSW_M3)|(1<<CSW_M4A1)|(1<<CSW_TMP)|(1<<CSW_G3SG1)|(1<<CSW_SG552)|(1<<CSW_AK47)|(1<<CSW_P90)
	
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

stock set_player_nextattack(player, weapon_id, Float:NextTime)
{
	const m_flNextPrimaryAttack = 46
	const m_flNextSecondaryAttack = 47
	const m_flTimeWeaponIdle = 48
	const m_flNextAttack = 83
	
	static weapon
	weapon = fm_get_user_weapon_entity(player, weapon_id)
	
	set_pdata_float(player, m_flNextAttack, NextTime, 5)
	if(pev_valid(weapon))
	{
		set_pdata_float(weapon, m_flNextPrimaryAttack , NextTime, 4)
		set_pdata_float(weapon, m_flNextSecondaryAttack, NextTime, 4)
		set_pdata_float(weapon, m_flTimeWeaponIdle, NextTime, 4)
	}
}

stock get_position(id,Float:forw, Float:right, Float:up, Float:vStart[])
{
	new Float:vOrigin[3], Float:vAngle[3], Float:vForward[3], Float:vRight[3], Float:vUp[3]
	
	pev(id, pev_origin, vOrigin)
	pev(id, pev_view_ofs,vUp) //for player
	xs_vec_add(vOrigin,vUp,vOrigin)
	pev(id, pev_v_angle, vAngle) // if normal entity ,use pev_angles
	
	angle_vector(vAngle,ANGLEVECTOR_FORWARD,vForward) //or use EngFunc_AngleVectors
	angle_vector(vAngle,ANGLEVECTOR_RIGHT,vRight)
	angle_vector(vAngle,ANGLEVECTOR_UP,vUp)
	
	vStart[0] = vOrigin[0] + vForward[0] * forw + vRight[0] * right + vUp[0] * up
	vStart[1] = vOrigin[1] + vForward[1] * forw + vRight[1] * right + vUp[1] * up
	vStart[2] = vOrigin[2] + vForward[2] * forw + vRight[2] * right + vUp[2] * up
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
