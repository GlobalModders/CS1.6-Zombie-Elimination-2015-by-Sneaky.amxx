#include <amxmodx>
#include <engine>
#include <fakemeta>
#include <fakemeta_util>
#include <hamsandwich>
#include <cstrike>
//#include <zombieplague>
#include <zombie_eli>

#define PLUGIN "[ZP] Extra Item: Spas12Ex2"
#define VERSION "1.0"
#define AUTHOR "Dias"

#define CSW_SPAS12EX2 CSW_M3
#define weapon_spas12ex2 "weapon_m3"

new const v_model[] = "models/zombie_plague/v_spas12ex2.mdl"
new const p_model[] = "models/zombie_plague/p_spas12ex2.mdl"
//new const w_model[] = "models/zombie_plague/w_spas12ex2.mdl"
new const spas12ex2_sound[4][] = {
	"weapons/spas12ex-1.wav",
	"weapons/spas12_reload.wav",
	"weapons/spas12_insert.wav",
	"weapons/spas12_draw.wav"
}

new g_had_spas12ex2[33], g_orig_event_spas12ex2, is_attacking[33], Float:g_last_postframe[33]
new g_bloodspray, g_blood, Float:g_last_change[33], Float:g_last_fire[33], g_mode[33]
new cvar_damage_mode1, cvar_damage_mode2

new g_Medic, g_Spas121
new g_Engineer, g_Spas122
new g_Heavy, g_Spas123
new g_FrozenTech, g_Spas124
new g_PyroTech, g_Spas125
new g_Wukong, g_Spas126

public plugin_init()
{
	register_plugin(PLUGIN, VERSION, AUTHOR)
	
	register_event("HLTV", "event_newround", "a", "1=0", "2=0")
	register_event("CurWeapon", "event_curweapon", "be", "1=1")
	
	RegisterHam(Ham_TakeDamage, "player", "fw_takedmg")
	RegisterHam(Ham_TraceAttack, "worldspawn", "TraceAttack", 1)
	RegisterHam(Ham_TraceAttack, "player", "TraceAttack", 1)	
	RegisterHam(Ham_Item_AddToPlayer, weapon_spas12ex2, "fw_item_addtoplayer", 1)
	RegisterHam(Ham_Item_PostFrame, weapon_spas12ex2, "fw_item_postframe")
	
	register_forward(FM_UpdateClientData, "fw_UpdateClientData_Post", 1)
	register_forward(FM_PlaybackEvent, "fw_PlaybackEvent")
	register_forward(FM_SetModel, "fw_SetModel")	
	register_forward(FM_CmdStart, "fw_CmdStart")
	
	cvar_damage_mode1 = register_cvar("zp_damage_mode1", "1.75")
	cvar_damage_mode2 = register_cvar("zp_damage_mode2", "1.25")
	
	//spas12ex2_item = zp_register_extra_item("Spas12 Superior", 30, ZP_TEAM_HUMAN)
	  /////////////////////////////////////////////
	 // Register Weapon for Frozen Tech Class //
	/////////////////////////////////////////////
	g_FrozenTech = ZombieEli_GetClassID("Frozen Tech")
	g_Spas121 = ZombieEli_RegisterWeapon(g_FrozenTech, "SPAS-12ex2", WPN_PRIMARY, 0, 0)
	
	  /////////////////////////////////////////////
	 //  Register Weapon for Pyro Tech Class  //
	/////////////////////////////////////////////	
	g_PyroTech = ZombieEli_GetClassID("Pyro Tech")
	g_Spas122 = ZombieEli_RegisterWeapon(g_PyroTech, "SPAS-12ex2", WPN_PRIMARY, 0, 0)	

	  /////////////////////////////////////////////
	 //    Register Weapon for Medic Class    //
	/////////////////////////////////////////////	
	g_Medic = ZombieEli_GetClassID("Medic")
	g_Spas123 = ZombieEli_RegisterWeapon(g_Medic, "SPAS-12ex2", WPN_PRIMARY, 0, 0)	

	  /////////////////////////////////////////////
	 //    Register Weapon for Heavy Class    //
	/////////////////////////////////////////////	
	g_Heavy = ZombieEli_GetClassID("Heavy")
	g_Spas124 = ZombieEli_RegisterWeapon(g_Heavy, "SPAS-12ex2", WPN_PRIMARY, 0, 0)	
	
	  /////////////////////////////////////////////
	 //  Register Weapon for Engineer Class   //
	/////////////////////////////////////////////	
	g_Engineer = ZombieEli_GetClassID("Engineer")
	g_Spas125 = ZombieEli_RegisterWeapon(g_Engineer, "SPAS-12ex2", WPN_PRIMARY, 0, 0)	
	
	  /////////////////////////////////////////////
	 //   Register Weapon for Wukong Class    //
	/////////////////////////////////////////////	
	g_Wukong = ZombieEli_GetClassID("Sun Wukong")
	g_Spas126 = ZombieEli_RegisterWeapon(g_Wukong, "SPAS-12ex2", WPN_PRIMARY, 0, 0)		
}

public plugin_precache()
{
	g_blood = precache_model("sprites/blood.spr")
	g_bloodspray = precache_model("sprites/bloodspray.spr")		
	
	precache_model(v_model)
	precache_model(p_model)
	//precache_model(w_model)
	
	for(new i = 0; i < sizeof(spas12ex2_sound); i++)
		precache_sound(spas12ex2_sound[i])	
		
	engfunc(EngFunc_PrecacheGeneric, "sprites/weapon_spas12ex2.txt")
	engfunc(EngFunc_PrecacheGeneric, "sprites/spas12ex2.spr")			
		
	register_forward(FM_PrecacheEvent, "fw_PrecacheEvent_Post", 1)
}
public zeli_weapon_selected(id, ItemID, ClassID)
{
	if(ItemID == g_Spas121) Get_Spas12ex2(id)
	if(ItemID == g_Spas122) Get_Spas12ex2(id)
	if(ItemID == g_Spas123) Get_Spas12ex2(id)
	if(ItemID == g_Spas124) Get_Spas12ex2(id)
	if(ItemID == g_Spas125) Get_Spas12ex2(id)
	if(ItemID == g_Spas126) Get_Spas12ex2(id)
}

public zeli_weapon_removed(id, ItemID)
{
	if(ItemID == g_Spas121) Remove_Spas12ex2(id)
	if(ItemID == g_Spas122) Remove_Spas12ex2(id)
	if(ItemID == g_Spas123) Remove_Spas12ex2(id)
	if(ItemID == g_Spas124) Remove_Spas12ex2(id)
	if(ItemID == g_Spas125) Remove_Spas12ex2(id)
	if(ItemID == g_Spas126) Remove_Spas12ex2(id)
}
public Get_Spas12ex2(id, itemid)
{
	//if(itemid != spas12ex2_item)
		//return
	
	g_had_spas12ex2[id] = 1
	g_mode[id] = 1
	
	fm_give_item(id, weapon_spas12ex2)
	cs_set_user_bpammo(id, CSW_SPAS12EX2, 64)
}

public Remove_Spas12ex2(id)
{
	g_had_spas12ex2[id] = 0
	g_mode[id] = 0
}

//public zp_user_humanized_post(id)
//{
//	g_had_spas12ex2[id] = 0
//	g_mode[id] = 0
//}


public fw_PrecacheEvent_Post(type, const name[])
{
	if (equal("events/m3.sc", name))
	{
		g_orig_event_spas12ex2 = get_orig_retval()
		return FMRES_HANDLED
	}
	
	return FMRES_IGNORED
}

public event_newround()
{
	new iPlayers[32], iNumber
	get_players(iPlayers, iNumber)
	
	for(new i = 0; i < iNumber; i++)
	{
		new id = iPlayers[i]
		
		if(is_user_alive(id) && is_user_connected(id))
			g_had_spas12ex2[i] = 0
	}
}

public event_curweapon(id)
{
	if(!is_user_alive(id) || !is_user_connected(id))
		return
	//if(zp_get_user_zombie(id))
		//return
	if(get_user_weapon(id) != CSW_SPAS12EX2 || !g_had_spas12ex2[id])
		return	
		
	set_pev(id, pev_viewmodel2, v_model)
	set_pev(id, pev_weaponmodel2, p_model)
		
	return 	
}

public fw_UpdateClientData_Post(id, sendweapons, cd_handle)
{
	if(!is_user_alive(id) || !is_user_connected(id))
		return FMRES_IGNORED
	//if(zp_get_user_zombie(id))
		//return FMRES_IGNORED	
	if(get_user_weapon(id) != CSW_SPAS12EX2 || !g_had_spas12ex2[id])
		return FMRES_IGNORED
		
	set_cd(cd_handle, CD_flNextAttack, halflife_time() + 0.001) 
	
	return FMRES_HANDLED
}

public fw_PlaybackEvent(flags, invoker, eventid, Float:delay, Float:origin[3], Float:angles[3], Float:fparam1, Float:fparam2, iParam1, iParam2, bParam1, bParam2)
{
	if (eventid != g_orig_event_spas12ex2)
		return FMRES_IGNORED
	if (!(1 <= invoker <= get_maxplayers()) || !is_attacking[invoker])
		return FMRES_IGNORED
	
	playback_event(flags | FEV_HOSTONLY, invoker, eventid, delay, origin, angles, fparam1, fparam2, iParam1, iParam2, bParam1, bParam2)
	return FMRES_SUPERCEDE
}

public fw_SetModel(entity, model[])
{
	if(!is_valid_ent(entity))
		return FMRES_IGNORED;
	
	static szClassName[33]
	entity_get_string(entity, EV_SZ_classname, szClassName, charsmax(szClassName))
	
	if(!equal(szClassName, "weaponbox"))
		return FMRES_IGNORED;
	
	static iOwner
	iOwner = entity_get_edict(entity, EV_ENT_owner)
	
	if(equal(model, "models/w_m3.mdl"))
	{
		static weapon
		weapon = find_ent_by_owner(-1, weapon_spas12ex2, entity)
		
		if(!is_valid_ent(weapon))
			return FMRES_IGNORED;
		
		if(g_had_spas12ex2[iOwner])
		{
			entity_set_int(weapon, EV_INT_impulse, 121)
			g_had_spas12ex2[iOwner] = 0
			set_pev(weapon, pev_iuser4, g_mode[iOwner])
			
			//entity_set_model(entity, w_model)
			
			return FMRES_SUPERCEDE
		}
	}
	
	return FMRES_IGNORED;
}

public fw_CmdStart(id, uc_handle, seed)
{
	if(!is_user_alive(id) || !is_user_connected(id))
		return FMRES_IGNORED
	//if(zp_get_user_zombie(id))
		//return FMRES_IGNORED
	if(get_user_weapon(id) != CSW_SPAS12EX2 || !g_had_spas12ex2[id])
		return FMRES_IGNORED

	new CurButton
	CurButton = get_uc(uc_handle, UC_Buttons)

	if(CurButton & IN_ATTACK2)
	{
		static Float:CurTime
		CurTime = get_gametime()
		
		if(CurTime - 0.5 > g_last_change[id])
		{
			if(g_mode[id] == 1)
			{
				g_mode[id] = 2
				client_print(id, print_center, "Switch to Auto-Mode")
			} else if(g_mode[id] == 2) {
				client_print(id, print_center, "Switch to Normal-Mode")
				g_mode[id] = 1
			}
			
			g_last_change[id] = CurTime
		}
	}
	
	if(CurButton & IN_ATTACK)
	{
		static Float:CurTime
		CurTime = get_gametime()
		
		CurButton &= ~IN_ATTACK
		set_uc(uc_handle, UC_Buttons, CurButton)
		
		static ent
		ent = find_ent_by_owner(-1, weapon_spas12ex2, id)
		
		if(cs_get_weapon_ammo(ent) <= 0 || get_pdata_int(ent, 54, 4))
			return FMRES_IGNORED
		
		if(g_mode[id] == 1)
		{
			if(CurTime - 1.0 > g_last_fire[id])
			{
				emit_sound(id, CHAN_WEAPON, spas12ex2_sound[0], 1.0, ATTN_NORM, 0, PITCH_NORM)
		
				ExecuteHamB(Ham_Weapon_PrimaryAttack, ent)
				set_task(0.5, "do_playsound_finish", id)
				set_weapon_anim(id, 1)
				
				g_last_fire[id] = CurTime
			}			
		} else if(g_mode[id] == 2) {
			if(CurTime - 0.3 > g_last_fire[id])
			{
				emit_sound(id, CHAN_WEAPON, spas12ex2_sound[0], 1.0, ATTN_NORM, 0, PITCH_NORM)
		
				ExecuteHamB(Ham_Weapon_PrimaryAttack, ent)
				set_weapon_anim(id, 7)
				
				g_last_fire[id] = CurTime
			}					
		}
		

		
	}	
	
	return FMRES_HANDLED
}

public do_playsound_finish(id)
{
	if(get_user_weapon(id) != CSW_SPAS12EX2 || !g_had_spas12ex2[id])
		return
	
	emit_sound(id, CHAN_WEAPON, spas12ex2_sound[1], 1.0, ATTN_NORM, 0, PITCH_NORM)
}

public TraceAttack(iEnt, iAttacker, Float:flDamage, Float:fDir[3], ptr, iDamageType)
{
	if(!is_user_alive(iAttacker) || !is_user_connected(iAttacker))
		return HAM_IGNORED
	//if(zp_get_user_zombie(iAttacker))
		//return FMRES_IGNORED			
	if(get_user_weapon(iAttacker) != CSW_SPAS12EX2 || !g_had_spas12ex2[iAttacker])
		return HAM_IGNORED
	
	static Float:flEnd[3]
	get_tr2(ptr, TR_vecEndPos, flEnd)

	make_bullet(iAttacker, flEnd)

	return HAM_HANDLED
}

public fw_takedmg(victim, inflictor, attacker, Float:damage, damagebits)
{
	if(!is_user_alive(victim) || !is_user_alive(attacker))
		return HAM_IGNORED
		
	//if(zp_get_user_zombie(attacker) || !zp_get_user_zombie(victim))
		//return HAM_IGNORED

	if(get_user_weapon(attacker) == CSW_SPAS12EX2 && g_had_spas12ex2[attacker])
	{
		static Float:Damage
		if(g_mode[attacker] == 1)
			Damage = get_pcvar_float(cvar_damage_mode1)
		else if(g_mode[attacker] == 2)
			Damage = get_pcvar_float(cvar_damage_mode2)
	
		SetHamParamFloat(4, damage * Damage)
	}
	
	return HAM_HANDLED
}

public fw_item_addtoplayer(ent, id)
{
	if(!is_valid_ent(ent))
		return HAM_IGNORED
		
	//if(zp_get_user_zombie(id))
		//return HAM_IGNORED
			
	if(entity_get_int(ent, EV_INT_impulse) == 121)
	{
		g_had_spas12ex2[id] = 1
		g_mode[id] = pev(ent, pev_iuser4)
		
		entity_set_int(id, EV_INT_impulse, 0)
		
		return HAM_HANDLED
	}	
	
	if(g_had_spas12ex2[id])
	{
		message_begin(MSG_ONE, get_user_msgid("WeaponList"), _, id)
		write_string("weapon_spas12ex2");    // WeaponName
		write_byte(5)                  // PrimaryAmmoID
		write_byte(32)                  // PrimaryAmmoMaxAmount
		write_byte(-1)                   // SecondaryAmmoID
		write_byte(-1)                   // SecondaryAmmoMaxAmount
		write_byte(0)                    // SlotID (0...N)
		write_byte(5)                    // NumberInSlot (1...N)
		write_byte(CSW_SPAS12EX2)            // WeaponID
		write_byte(0)                   // Flags
		message_end()
	}	

	return HAM_HANDLED
}

public fw_item_postframe(ent)
{
	static id
	id = pev(ent, pev_owner)
	
	if(!is_user_alive(id) || !is_user_connected(id))
		return HAM_IGNORED
	//if(zp_get_user_zombie(iAttacker))
	//	return FMRES_IGNORED			
	if(get_user_weapon(id) != CSW_SPAS12EX2 || !g_had_spas12ex2[id])
		return HAM_IGNORED	

	static spas12ex2
	spas12ex2 = fm_find_ent_by_owner(-1, weapon_spas12ex2, id)
	
	if(get_pdata_int(spas12ex2, 55, 4) == 1)
	{
		static Float:CurTime
		CurTime = get_gametime()
		
		if(CurTime - 0.4 > g_last_postframe[id])
		{
			set_weapon_anim(id, 3)
			g_last_postframe[id] = CurTime
		}
	}

	return HAM_HANDLED
}

stock make_bullet(id, Float:Origin[3])
{
	// Find target
	new target, body
	get_user_aiming(id, target, body, 999999)
	
	if(target > 0 && target <= get_maxplayers())
	{
		new Float:fStart[3], Float:fEnd[3], Float:fRes[3], Float:fVel[3]
		pev(id, pev_origin, fStart)
		
		// Get ids view direction
		velocity_by_aim(id, 64, fVel)
		
		// Calculate position where blood should be displayed
		fStart[0] = Origin[0]
		fStart[1] = Origin[1]
		fStart[2] = Origin[2]
		fEnd[0] = fStart[0]+fVel[0]
		fEnd[1] = fStart[1]+fVel[1]
		fEnd[2] = fStart[2]+fVel[2]
		
		// Draw traceline from victims origin into ids view direction to find
		// the location on the wall to put some blood on there
		new res
		engfunc(EngFunc_TraceLine, fStart, fEnd, 0, target, res)
		get_tr2(res, TR_vecEndPos, fRes)
		
		// Show some blood :)
		message_begin(MSG_BROADCAST, SVC_TEMPENTITY) 
		write_byte(TE_BLOODSPRITE)
		write_coord(floatround(fStart[0])) 
		write_coord(floatround(fStart[1])) 
		write_coord(floatround(fStart[2])) 
		write_short(g_bloodspray)
		write_short(g_blood)
		write_byte(70)
		write_byte(random_num(1,2))
		message_end()
		
		
		} else {
		new decal = 41
		
		// Check if the wall hit is an entity
		if(target)
		{
			// Put decal on an entity
			message_begin(MSG_BROADCAST, SVC_TEMPENTITY)
			write_byte(TE_DECAL)
			write_coord(floatround(Origin[0]))
			write_coord(floatround(Origin[1]))
			write_coord(floatround(Origin[2]))
			write_byte(decal)
			write_short(target)
			message_end()
			} else {
			// Put decal on "world" (a wall)
			message_begin(MSG_BROADCAST, SVC_TEMPENTITY)
			write_byte(TE_WORLDDECAL)
			write_coord(floatround(Origin[0]))
			write_coord(floatround(Origin[1]))
			write_coord(floatround(Origin[2]))
			write_byte(decal)
			message_end()
		}
		
		// Show sparcles
		message_begin(MSG_BROADCAST, SVC_TEMPENTITY)
		write_byte(TE_GUNSHOTDECAL)
		write_coord(floatround(Origin[0]))
		write_coord(floatround(Origin[1]))
		write_coord(floatround(Origin[2]))
		write_short(id)
		write_byte(decal)
		message_end()
	}
}

stock set_weapon_anim(id, anim)
{
	set_pev(id, pev_weaponanim, anim)

	message_begin(MSG_ONE_UNRELIABLE, SVC_WEAPONANIM, _, id)
	write_byte(anim)
	write_byte(pev(id,pev_body))
	message_end()
}
