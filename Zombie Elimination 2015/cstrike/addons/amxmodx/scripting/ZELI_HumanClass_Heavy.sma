#include <amxmodx>
#include <amxmisc>
#include <engine>
#include <fakemeta>
#include <fakemeta_util>
#include <hamsandwich>
#include <cstrike>
#include <fun>
#include <zombie_eli>
#include <infinitygame>
#include <c4>

#define PLUGIN "[ZELI] H-Class: Heavy"
#define VERSION "1.0"
#define AUTHOR "Dias Pendragon Leon"

// Class Setting
#define CLASS_NAME "Heavy"
#define CLASS_MODEL "zeli_hm_heavy"
#define CLASS_CLAWMODEL ""
#define CLASS_TEAM TEAM_HUMAN

const CLASS_HEALTH = 100
const CLASS_ARMOR = 100
const Float:CLASS_GRAVITY = 1.25
const Float:CLASS_SPEED = 150.0

new g_Heavy
new g_HeavyHealth, g_HeavyArmor, g_HeavyKB

#define Get_BitVar(%1,%2)		(%1 & (1 << (%2 & 31)))
#define Set_BitVar(%1,%2)		(%1 |= (1 << (%2 & 31)));
#define UnSet_BitVar(%1,%2)		(%1 &= ~(1 << (%2 & 31)));

// Knockback
new Float:kb_weapon_power[] = 
{
	-1.0,	// ---
	2.4,	// P228
	-1.0,	// ---
	6.5,	// SCOUT
	-1.0,	// ---
	8.0,	// XM1014
	-1.0,	// ---
	2.3,	// MAC10
	5.0,	// AUG
	-1.0,	// ---
	2.4,	// ELITE
	2.0,	// FIVESEVEN
	2.4,	// UMP45
	5.3,	// SG550
	5.5,	// GALIL
	5.5,	// FAMAS
	2.2,	// USP
	2.0,	// GLOCK18
	10.0,	// AWP
	2.5,	// MP5NAVY
	5.2,	// M249
	8.0,	// M3
	5.0,	// M4A1
	2.4,	// TMP
	6.5,	// G3SG1
	-1.0,	// ---
	5.3,	// DEAGLE
	5.0,	// SG552
	6.0,	// AK47
	-1.0,	// ---
	2.0		// P90
}

new Float:CheckTime3[33], g_SkillHud

// Shit


#define V_SATCHEL_RADIO   "models/v_satchel_radio.mdl"
#define P_SATCHEL_RADIO   "models/p_satchel_radio.mdl"
#define V_SATCHEL         "models/v_n_satchel.mdl"
#define P_SATCHEL         "models/p_n_satchel.mdl"
#define W_SATCHEL         "models/w_n_satchel.mdl"
#define SPRITE_EXPLOSION  "sprites/zerogxplode-big1.spr"

#define C4_KNOCKBACK      2.7
#define C4_DAMAGE         1100.0
#define C4_RADIUS         370.0 
#define C4_SETTIME        4


#define m_pPlayer		   41
#define m_pNext			   42
#define m_iId                      43
#define m_flNextPrimaryAttack 	   46
#define m_rgpPlayerItems	   367
#define m_iActiveItem              373

#define m_fArmedTime               79
#define m_flC4Blow                 100 
#define m_fAttenu                  101
#define m_flNextBeep               102
#define m_flNextFreq               103        
#define m_flNextFreqInterval       105
#define m_flNextBlink              106
#define m_bJustBlew                108
#define m_bOnBombZone              235
#define m_afButtonPressed          246
#define m_bStartedArming           312
#define m_bInArmingAnimation_C4    313
#define m_bBombPlacedAnimation     337
#define m_bIsC4                    385
#define m_bHasC4                   773

#define IsValidPev(%0)                  (pev_valid(%0) == 2)
#define STATEMENT_FALLBACK(%0,%1,%2)	public %0() <> {return %1;} public %0() <%2> {return %1;}

#define PRECACHE_MODEL(%0)	        engfunc(EngFunc_PrecacheModel, %0)
#define PRECACHE_SOUND(%0)	        engfunc(EngFunc_PrecacheSound, %0)

new g_IsC4[33 char], IsBombPlanted[33 char];
new HamHook: ham_WeaponBoxSpawn, HamHook: ham_WeaponIlePost;
new g_SpritEexp;

// Safety
new g_HamBot
new g_IsConnected, g_IsAlive, g_PlayerWeapon[33]

public plugin_init()
{
	register_plugin(PLUGIN, VERSION, AUTHOR)
	
	Register_SafetyFunc()
	
	register_forward(FM_CmdStart, "fw_Megatron")
	RegisterHam(Ham_TraceAttack, "player", "fw_PlayerTraceAttack_Post", 1)
	
	RegisterHam(Ham_Item_Deploy, "weapon_c4", "ham_Deploy_C4_Post", 1);
	RegisterHam(Ham_Weapon_PrimaryAttack, "weapon_c4", "ham_PrimaryAttack_C4_Pre", 0);
	RegisterHam(Ham_Weapon_PrimaryAttack, "weapon_c4", "ham_PrimaryAttack_C4_Post", 1);
	RegisterHam(Ham_Weapon_AddWeapon, "weapon_c4", "ham_addWeapon_C4_Pre", 0);
	RegisterHam(Ham_Weapon_WeaponIdle, "weapon_c4", "ham_WeaponIdle_C4_Pre", 0);
	ham_WeaponIlePost = RegisterHam(Ham_Weapon_WeaponIdle, "weapon_c4", "ham_WeaponIdle_C4_Post", 1);
	DisableHamForward(ham_WeaponIlePost);
	RegisterHam(Ham_CS_Item_CanDrop, "weapon_c4", "ham_CanDrop_C4_Pre", 0);
	RegisterHam(Ham_Killed, "player", "ham_Killed_Post", 1);
	
	DisableHamForward(ham_WeaponBoxSpawn = RegisterHam(Ham_Spawn, "weaponbox", "ham_WeaponboxSpawn_Post", 1));
	
	register_forward(FM_SetModel, "fwd_SetModel", 0);
	register_touch("weaponbox", "player", "Touch_WeaponBox");
	
	register_logevent("LogEvent_Round_End", 2, "1=Round_End")
	
	register_message(107, "MsgHook_StatusIcon");
	register_message(77, "MsgHook_TextMsg");
	
	set_msg_block(145, BLOCK_SET); //HudTextArgs
	set_msg_block(121, BLOCK_SET); //BombPickup
	set_msg_block(120, BLOCK_SET); //BombDrop
	
	g_SkillHud = CreateHudSyncObj(3)
	
	// CMD
	//register_clcmd("drop", "CMD_Drop")
}

public plugin_precache()
{
	// Register Class
	g_Heavy = ZombieEli_RegisterClass(CLASS_NAME, CLASS_HEALTH, CLASS_ARMOR, CLASS_GRAVITY, CLASS_SPEED, CLASS_MODEL, CLASS_CLAWMODEL, CLASS_TEAM, 0)

	// Register Skill
	g_HeavyHealth = ZombieEli_RegisterSkill(g_Heavy, "Health", 3)
	g_HeavyArmor = ZombieEli_RegisterSkill(g_Heavy, "Armor", 3)
	g_HeavyKB = ZombieEli_RegisterSkill(g_Heavy, "Knockback", 3)
	
	// Shit
	PRECACHE_MODEL(V_SATCHEL_RADIO);
	PRECACHE_MODEL(P_SATCHEL_RADIO);
	PRECACHE_MODEL(V_SATCHEL);
	PRECACHE_MODEL(P_SATCHEL);
	PRECACHE_MODEL(W_SATCHEL);
	
	g_SpritEexp = PRECACHE_MODEL(SPRITE_EXPLOSION);
}

public client_putinserver(id)
{
	Safety_Connected(id)
	
	g_IsC4{id} = 0;
	IsBombPlanted{id} = 0;
	
	if(!g_HamBot && is_user_bot(id))
	{
		g_HamBot = 1
		set_task(0.1, "Do_Register_HamBot", id)
	}
}

public Do_Register_HamBot(id) 
{
	Register_SafetyFuncBot(id)
	RegisterHamFromEntity(Ham_TraceAttack, id, "fw_PlayerTraceAttack_Post", 1)
}

public client_disconnect(id)
{
	Safety_Disconnected(id)
	
	if (g_IsC4{id})
	{
		static iC4;
		iC4 = -1;
	
		while ((iC4 = find_ent_by_model(iC4, "grenade", W_SATCHEL)))
		{
			if (pev(iC4, pev_owner) != id)
				continue;
			
			g_IsC4{id} = 0;
			
			if (task_exists(id+5100))
			{
				remove_task(id+5100);
			}	
			remove_entity(iC4);
		}
	}
}

public zeli_user_spawned(id, ClassID)
{
	remove_task(id+6666)
}

public CMD_Drop(id)
{
	if(!is_alive(id))
		return PLUGIN_CONTINUE
	if(ZombieEli_IsZombie(id))
		return PLUGIN_CONTINUE
	if(ZombieEli_GetClass(id) != g_Heavy)
		return PLUGIN_CONTINUE
		
	if(ZombieEli_GetLevel(id, ZombieEli_GetClass(id)) >= 10)
	{
		
	}
		
	return PLUGIN_HANDLED
}

public fw_Megatron(id)
{
	if(!is_alive(id))
		return
	if(ZombieEli_IsZombie(id))
		return
	if(ZombieEli_GetClass(id) != g_Heavy)
		return
	
	if(get_gametime() - 1.0 > CheckTime3[id])
	{
		set_hudmessage(200, 200, 200, -1.0, 0.83 - 0.02, 0, 1.1, 1.1, 0.0, 0.0)
		ShowSyncHudMsg(id, g_SkillHud, "Ultimate Skill: Satchel [5]")
		
		CheckTime3[id] = get_gametime()
	}	
}

public zeli_class_active(id, ClassID)
{
	if(ClassID != g_Heavy)
		return
	
	static SP, AddData
	// HP
	SP = ZombieEli_GetSP(id, g_HeavyHealth)
	AddData = 0
	
	switch(SP)
	{
		case 1: AddData = 55 * 1
		case 2: AddData = 55 * 2
		case 3: AddData = 55 * 3
		default: AddData = 0
	}
	
	set_user_health(id, get_user_health(id) + AddData)
	ZombieEli_SetMaxHP(id, get_user_health(id))
	
	// Armor
	SP = ZombieEli_GetSP(id, g_HeavyArmor)
	AddData = 0
	
	switch(SP)
	{
		case 1: AddData = 55 * 1
		case 2: AddData = 55 * 2
		case 3: AddData = 55 * 3
		default: AddData = 0
	}
	
	set_user_armor(id, get_user_armor(id) + AddData)
	
	// Bomb
	if(ZombieEli_GetLevel(id, ClassID) >= 10) give_item(id, "weapon_c4")
}

public zeli_class_unactive(id, ClassID)
{
	if(ClassID == g_Heavy)
		strip_user_c4(id)
}

public zeli_user_infected(id, ClassID)
{
	remove_task(id+6666)
}

public zeli_levelup(id, ClassID, NewLevel)
{
	if(ClassID != g_Heavy)
		return
	if(NewLevel == 10)
	{
		give_item(id, "weapon_c4")
		IG_ClientPrintColor(id, "!gYou reached Lv.10!n -> !t[5] = Satchel!n")
	}
}

public fw_PlayerTraceAttack_Post(victim, attacker, Float:damage, Float:direction[3], tracehandle, damage_type)
{
	if (victim == attacker || !ZombieEli_IsZombie(victim))
		return;
	if (ZombieEli_IsZombie(attacker)/* || Get_BitVar(g_IsNightStalker, attacker)*/)
		return;
	if(ZombieEli_GetClass(attacker) != g_Heavy)
		return;
	if (!(damage_type & DMG_BULLET))
		return;
	if (damage <= 0.0 || GetHamReturnStatus() == HAM_SUPERCEDE || get_tr2(tracehandle, TR_pHit) != victim)
		return;
	
	new ducking = pev(victim, pev_flags) & (FL_DUCKING | FL_ONGROUND) == (FL_DUCKING | FL_ONGROUND)
	if (ducking) return;

	static origin1[3], origin2[3]
	get_user_origin(victim, origin1)
	get_user_origin(attacker, origin2)

	if(get_distance(origin1, origin2) > 1024)
		return ;
	
	static Float:velocity[3]
	pev(victim, pev_velocity, velocity)
	
	xs_vec_mul_scalar(direction, damage, direction)
	
	new attacker_weapon = get_user_weapon(attacker)
	
	if(kb_weapon_power[attacker_weapon] > 0.0)
		xs_vec_mul_scalar(direction, kb_weapon_power[attacker_weapon], direction)
	
	static SP; SP = ZombieEli_GetSP(attacker, g_HeavyKB)
	
	switch(SP)
	{
		case 0: xs_vec_mul_scalar(direction, 0.0, direction)
		case 1: xs_vec_mul_scalar(direction, 1.1, direction)
		case 2: xs_vec_mul_scalar(direction, 1.2, direction)
		case 3: xs_vec_mul_scalar(direction, 1.3, direction)
	}
	
	xs_vec_add(velocity, direction, direction)
	direction[2] = velocity[2]

	set_pev(victim, pev_velocity, direction)
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

// Shit


public MsgHook_StatusIcon(iMsgid, iDest, id)
{
	static szIcon[3];
	get_msg_arg_string(2, szIcon, charsmax(szIcon));
	
	if (szIcon[1] == '4')
	{
		return PLUGIN_HANDLED;
	}
	
	return PLUGIN_CONTINUE;
}

public MsgHook_TextMsg(iMsgid, iDest, id) <stStartedArming: Enabled>
{
	static szMessage[4];
	get_msg_arg_string(2, szMessage, charsmax(szMessage));
	
	if (szMessage[2] == '4')
	{
		return PLUGIN_HANDLED;
	}
	
	return PLUGIN_CONTINUE;
}
STATEMENT_FALLBACK(MsgHook_TextMsg, PLUGIN_CONTINUE, stStartedArming: Disabled)

public ham_addWeapon_C4_Pre(const entity)
{
	static id;
	if (!CheckItem(entity, id))
	{
		return HAM_IGNORED;
	}
	
	set_msg_block(92, BLOCK_ONCE); //WeapPickup (Thanks Stimul  http://amx-x.ru/viewtopic.php?f=8&t=30881)
	set_msg_block(91, BLOCK_ONCE); // AmmoPickup
		
	set_pdata_cbase(id, m_iActiveItem, entity, 5);

	ExecuteHamB(Ham_Item_Deploy, entity);	
	
	return HAM_IGNORED;
}

public ham_WeaponboxSpawn_Post(const iWeaponBox)
{
	if (IsValidPev(iWeaponBox))
	{
		state (IsValidPev(pev(iWeaponBox, pev_owner))) stC4SetModel: Enabled;
	}
	
	DisableHamForward(ham_WeaponBoxSpawn);
}

public fwd_SetModel(entity, const model[]) <stC4SetModel: Enabled>
{
	state stC4SetModel: Disabled;

	if (IsValidPev(entity))
	{
		engfunc(EngFunc_SetModel, entity, W_SATCHEL);
		return FMRES_SUPERCEDE;
	}
	
	return FMRES_IGNORED;
}
STATEMENT_FALLBACK(fwd_SetModel, FMRES_IGNORED, stC4SetModel: Disabled)	
				
public ham_CanDrop_C4_Pre(const entity)
{
	static id;
	if (!CheckItem(entity, id))
	{
		return HAM_IGNORED;
	}
	
	if (g_IsC4{id})
	{
		SetHamReturnInteger(0);
		return HAM_SUPERCEDE;
	}
	
	EnableHamForward(ham_WeaponBoxSpawn);
	
	return HAM_IGNORED;
}	

public ham_Deploy_C4_Post(const entity)
{
	static id;
	if (!CheckItem(entity, id))
	{
		return HAM_IGNORED;
	}
	
	if (g_IsC4{id})
	{
		static iszViewModel, iszPlayerModel;
		if (iszViewModel || (iszViewModel = engfunc(EngFunc_AllocString, V_SATCHEL_RADIO)))
		{
			set_pev_string(id, pev_viewmodel2, iszViewModel);
		}
		
		if (iszPlayerModel || (iszPlayerModel = engfunc(EngFunc_AllocString, P_SATCHEL_RADIO)))
		{
			set_pev_string(id, pev_weaponmodel2, iszPlayerModel);
		}
		
		PlayWeaponAnimation(id, 2);
		
		set_pdata_float(entity, m_flNextPrimaryAttack, 0.8, 4) //time anim. draw
	}
	else
	{
		static iszViewModel2, iszPlayerModel2;
		if (iszViewModel2 || (iszViewModel2 = engfunc(EngFunc_AllocString, V_SATCHEL)))
		{
			set_pev_string(id, pev_viewmodel2, iszViewModel2);
		}
		
		if (iszPlayerModel2 || (iszPlayerModel2 = engfunc(EngFunc_AllocString, P_SATCHEL)))
		{
			set_pev_string(id, pev_weaponmodel2, iszPlayerModel2);
		}
		
		set_pdata_float(entity, m_flNextPrimaryAttack, 0.9, 4)
	}
	
	
	return HAM_IGNORED;
}
	

public c4_explode(param[2], id)
{
	id -= 5100;

	static Float:fC4Origin[3], iC4;
	iC4 = param[0];
	
	g_IsC4{id} = 0;
	
	pev(iC4, pev_origin, fC4Origin);

	static Float:vOrigin[3], Float:Velocity[3];
	new Float:fDistance, Float: fDamage, Float: fTime;
	new maxplayers = get_maxplayers();
	
	static victim;
	victim = -1;

	while ((victim = find_ent_in_sphere(victim, fC4Origin, C4_RADIUS)))
	{
		if (!(1 <= victim <= maxplayers && is_user_alive(victim)))
			continue;
	
		pev(victim, pev_origin, vOrigin);
		fDistance = get_distance_f(vOrigin, fC4Origin);
		fDamage = C4_DAMAGE - floatmul(C4_DAMAGE, floatdiv(fDistance, C4_RADIUS));

		fTime = floatdiv(fDistance, fDamage);
		Velocity[0] = floatdiv((vOrigin[0] - fC4Origin[0]), fTime)*C4_KNOCKBACK;
		Velocity[1] = floatdiv((vOrigin[1] - fC4Origin[1]), fTime)*C4_KNOCKBACK;
		Velocity[2] = floatdiv((vOrigin[2] - fC4Origin[2]), fTime)*C4_KNOCKBACK;
		set_pev(victim, pev_velocity, Velocity);
		
		(pev(victim, pev_health) <= fDamage) ? ExecuteHamB(Ham_Killed, victim, id, 0) : ExecuteHamB(Ham_TakeDamage, victim, iC4, id, fDamage, DMG_BLAST);	
	}
	
	remove_entity(iC4);
	
	engfunc(EngFunc_MessageBegin, MSG_PVS, SVC_TEMPENTITY, fC4Origin, 0);
	write_byte(TE_EXPLOSION);
	engfunc(EngFunc_WriteCoord, fC4Origin[0]);
	engfunc(EngFunc_WriteCoord, fC4Origin[1]);
	engfunc(EngFunc_WriteCoord, fC4Origin[2]+25.0);
	write_short(g_SpritEexp);
	write_byte(20); //scale
	write_byte(25); //framerate
	write_byte(TE_EXPLFLAG_NOPARTICLES); //flag
	message_end();
	
	strip_user_c4(id);
}	

public ham_PrimaryAttack_C4_Pre(const entity)
{
	static id;
	if (!CheckItem(entity, id))
	{
		return HAM_IGNORED;
	}
	
	set_pdata_int(id, m_bOnBombZone, get_pdata_int(id, m_bOnBombZone, 5) | (1<<1), 5);
	
	if (g_IsC4{id})
	{
		static iC4;
		iC4 = -1;
		
		while ((iC4 = find_ent_by_model(iC4, "grenade", W_SATCHEL))) 
		{
			if (pev(iC4, pev_owner) == id)
			{
				PlayWeaponAnimation(id, 3); //Press button
				
				new param[2];
				param[0] = iC4;
				
				set_task(0.7, "c4_explode", id+5100, param, 2)
				
				break;		
			}
		}
		
		set_pdata_float(entity, m_flNextPrimaryAttack, 2.0, 4);

		return HAM_SUPERCEDE;
	}
	
	if (~pev(id, pev_flags) & FL_ONGROUND)
	{
		state stStartedArming: Enabled; //for TextMsg
		return HAM_IGNORED;
	}

	if (get_pdata_bool(entity, m_bStartedArming, 4))
	{
		state stStartedArming: Enabled;
		
		if (get_gametime() >= get_pdata_float(entity, m_fArmedTime, 4))
		{
			set_msg_block(100, BLOCK_ONCE); //block sound BOMBL
			set_msg_block(77, BLOCK_ONCE);  //The bomb has been planted!
			set_pdata_int(id, 390, 2, 5);   //No Retire
		}
	}
	else
	{
		state stStartedArming: Disabled;
	}

	return HAM_IGNORED;
}

public ham_PrimaryAttack_C4_Post(const entity) <stStartedArming: Disabled>
{
	static id;
	if (!CheckItem(entity, id))
	{
		return HAM_IGNORED;
	}
	
	set_pdata_int(id, m_bOnBombZone, get_pdata_int(id, m_bOnBombZone, 5) & ~(1<<1), 5);
	
	set_pdata_float(entity, m_fArmedTime, get_gametime() + float(C4_SETTIME), 4);
		
	engfunc(EngFunc_MessageBegin, MSG_ONE, 108, {0.0, 0.0, 0.0}, id); //BarTime
	write_short(C4_SETTIME);
	message_end();
	
	IsBombPlanted{id} = 1;
	
	return HAM_IGNORED;
}

public ham_WeaponIdle_C4_Pre(const entity)
{
	static id;
	if (!CheckItem(entity, id))
	{
		return HAM_IGNORED;
	}
	
	if (get_pdata_bool(entity, m_bStartedArming, 4))
	{
		IsBombPlanted{id} = 0;
	}
	
	return HAM_IGNORED;
}

public ham_WeaponIdle_C4_Post(const entity)
{
	static id;
	if (!CheckItem(entity, id))
	{
		return HAM_IGNORED;
	}
	
	IsBombPlanted{id} = 0;
	
	DisableHamForward(ham_WeaponIlePost);
	
	return HAM_IGNORED;
}
	

public ham_PrimaryAttack_C4_Post(const entity) <stStartedArming: Enabled>
{
	static id;
	if (!CheckItem(entity, id))
	{
		return HAM_IGNORED;
	}
	
	set_pdata_int(id, m_bOnBombZone, get_pdata_int(id, m_bOnBombZone, 5) & ~(1<<1), 5);
	

	if (g_IsC4{id})
	{
		return HAM_IGNORED;
	}
	
	if (get_gametime() >= get_pdata_float(entity, m_fArmedTime, 4) && (pev(id, pev_flags) & FL_ONGROUND)) //bugfix ONGROUND
	{	
		new wEnt = create_entity("weapon_c4"); 
		
		if(pev_valid(wEnt))
		{
			set_pev(wEnt, pev_spawnflags, SF_NORESPAWN);
			dllfunc(DLLFunc_Spawn,wEnt);	
			ExecuteHam(Ham_Item_AttachToPlayer, wEnt, id);
			
			g_IsC4{id} = 1;
			
			EnableHamForward(ham_WeaponIlePost);	
			ExecuteHamB(Ham_Item_Deploy, entity);

		}
		
		static iC4;
		iC4 = -1;
		
		while ((iC4 = find_ent_by_class(iC4, "grenade"))) 
		{
			if (pev(iC4, pev_owner) != id)
				continue;
				
			if (get_pdata_bool(iC4, m_bIsC4, 4))
			{
				engfunc(EngFunc_SetModel, iC4, W_SATCHEL);
				
				new Float: fTime = get_gametime();

				set_pdata_float(iC4, m_flNextBeep, fTime + 700.0, 4);
				set_pdata_float(iC4, m_flC4Blow, fTime + 700.0, 4);
				set_pdata_float(iC4, m_flNextBlink, fTime + 700.0, 4);
				set_pdata_float(iC4, m_flNextFreq, fTime + 700.0, 4);
				
				set_pdata_bool(iC4, m_bIsC4, false, 4); //No Defusing
			}		
		}
	}
	
	return HAM_IGNORED;
}


public ham_PrimaryAttack_C4_Post() <> { return HAM_IGNORED;}

public Touch_WeaponBox(WeaponBox, id) //zombie and owner
{
	static szModel[32];
	pev(WeaponBox, pev_model, szModel, charsmax(szModel)) 
	
	if ((pev(WeaponBox, pev_flags) & FL_ONGROUND) && equal(szModel, W_SATCHEL))
	{
		if (~pev(id, pev_weapons) & (1<<CSW_C4)) 
		{
			remove_entity(WeaponBox);
			give_item(id, "weapon_c4");
		}
	}
}

public ham_Killed_Post(victim, attacker, shouldgib)
{
	if (g_IsC4{victim})
	{
		static iC4;
		iC4 = -1;
	
		while ((iC4 = find_ent_by_model(iC4, "grenade", W_SATCHEL)))
		{
			if (pev(iC4, pev_owner) != victim)
				continue;
			
			g_IsC4{victim} = 0;
			
			if (task_exists(victim+5100))
			{
				remove_task(victim+5100);
			}	
			remove_entity(iC4);
		}
	}
}

public LogEvent_Round_End()
{
	static iC4, id;
	iC4 = -1;
	
	while ((iC4 = find_ent_by_model(iC4, "grenade", W_SATCHEL))) 
	{
		id = pev(iC4, pev_owner);
		
		if(!g_IsC4{id})
			continue;

		if (task_exists(id+5100))
		{
			remove_task(id+5100);
		}
		
		g_IsC4{id} = 0;
			
		remove_entity(iC4);
		strip_user_c4(id);
	}
}

CheckItem(const iItem, &iPlayer)
{
	if (!IsValidPev(iItem))
	{
		return 0;
	}
	
	iPlayer = get_pdata_cbase(iItem, m_pPlayer, 4);
	
	if (!IsValidPev(iPlayer))
	{
		return 0;
	}
	
	return 1;
}

PlayWeaponAnimation(const id, const iAnim)
{
	set_pev(id, pev_weaponanim, iAnim);

	engfunc(EngFunc_MessageBegin, MSG_ONE_UNRELIABLE, SVC_WEAPONANIM, {0.0, 0.0, 0.0}, id);
	write_byte(iAnim);
	write_byte(0);
	message_end();
}

strip_user_c4(const id)
{
	new entity = get_pdata_cbase(id, m_iActiveItem, 5);

	if (IsValidPev(entity) && get_pdata_int(entity, m_iId, 4) == CSW_C4)
	{
		ExecuteHam(Ham_Weapon_RetireWeapon, entity);
		
		if(!ExecuteHam(Ham_RemovePlayerItem,id, entity))
		{
			return;
		}
		
		ExecuteHam(Ham_Item_Kill, entity);
		set_pev(id, pev_weapons, pev(id,pev_weapons) & ~(1<<CSW_C4));
	}
	else
	{
		new iC4 = get_pdata_cbase(id, m_rgpPlayerItems + 5, 5);
		
		if (IsValidPev(iC4))
		{
			if(!ExecuteHam(Ham_RemovePlayerItem, id, iC4))
			{
				return;
			}
			ExecuteHam(Ham_Item_Kill, iC4);
			set_pev(id, pev_weapons, pev(id,pev_weapons) & ~(1<<CSW_C4));
		}
	}
}	

#define INT_BYTES        4 
#define BYTE_BITS        8

stock set_pdata_char(ent, charbased_offset, value, intbase_linuxdiff = 5) 
{
	value &= 0xFF ;
	new int_offset_value = get_pdata_int(ent, charbased_offset / INT_BYTES, intbase_linuxdiff);
	new bit_decal = (charbased_offset % INT_BYTES) * BYTE_BITS;
	int_offset_value &= ~(0xFF<<bit_decal);
	int_offset_value |= value<<bit_decal;
	set_pdata_int(ent, charbased_offset / INT_BYTES, int_offset_value, intbase_linuxdiff);
	
	return 1;

}