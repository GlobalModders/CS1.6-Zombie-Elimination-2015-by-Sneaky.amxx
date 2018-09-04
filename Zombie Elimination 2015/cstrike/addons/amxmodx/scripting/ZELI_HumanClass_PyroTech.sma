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

#define PLUGIN "[ZELI] H-Class: Pyro Tech"
#define VERSION "1.0"
#define AUTHOR "Dias Pendragon Leon"

// Class Setting
#define CLASS_NAME "Pyro Tech"
#define CLASS_MODEL "zeli_hm_pyrotech"
#define CLASS_CLAWMODEL ""
#define CLASS_TEAM TEAM_HUMAN

const CLASS_HEALTH = 100
const CLASS_ARMOR = 100
const Float:CLASS_GRAVITY = 1.0
const Float:CLASS_SPEED = 250.0

new g_PyroTech
new g_Behemoth, g_FireDamage, g_FireDuration

// MACROS
#define Get_BitVar(%1,%2) (%1 & (1 << (%2 & 31)))
#define Set_BitVar(%1,%2) %1 |= (1 << (%2 & 31))
#define UnSet_BitVar(%1,%2) %1 &= ~(1 << (%2 & 31))

new const FireSprite[] = "sprites/zombie_elimination/flame.spr"

// Behemoth
// Weapon
#define MODEL_V "models/v_hegrenade.mdl"
#define MODEL_P "models/p_hegrenade.mdl"
#define MODEL_W "models/w_hegrenade.mdl"
#define MODEL_W_OLD "models/w_hegrenade.mdl"

#define EXP_SPR "sprites/zombie_elimination/zombiebomb_exp.spr"
#define EXP_SOUND "zombie_elimination/zombi_bomb_exp.wav"

#define CSW_BEHEMOTH CSW_HEGRENADE
#define weapon_behemoth "weapon_hegrenade"

// Behemoth's Poison
#define IMPACT_EXPLOSION 0
#define EFFECT_RADIUS 240.0
#define EFFECT_HOLDTIME 10.0

#define TASK_HOLD 2120152

// MACROS
#define Get_BitVar(%1,%2) (%1 & (1 << (%2 & 31)))
#define Set_BitVar(%1,%2) %1 |= (1 << (%2 & 31))
#define UnSet_BitVar(%1,%2) %1 &= ~(1 << (%2 & 31))

new const Float:BEHEMOTH_COLOR[3] = {255.0, 127.0, 0.0}

enum
{
	ANIM_IDLE = 0,
	ANIM_PULLPIN,
	ANIM_THROW,
	ANIM_DRAW
}

new g_Had_Behemoth, g_IsEffected, Float:EffectDelay[33]
new g_Trail_SprID, g_Exp_SprID, g_Ring_SprID
new g_MaxPlayers, g_HamBot, g_MsgShakeScreen, g_MsgFadeScreen

// Safety
new g_IsConnected, g_IsAlive, g_PlayerWeapon[33]

public plugin_init()
{
	register_plugin(PLUGIN, VERSION, AUTHOR)
	
	register_event("DeathMsg", "Event_Death", "a")
	
	Register_SafetyFunc()
	register_forward(FM_SetModel, "fw_SetModel")

	RegisterHam(Ham_Touch, "grenade", "fw_GrenadeTouch")
	RegisterHam(Ham_Think, "grenade", "fw_GrenadeThink")
	RegisterHam(Ham_Item_Deploy, weapon_behemoth, "fw_Item_Deploy_Post", 1)	
	
	register_think("afterburn", "fw_FireBurn_Think")
	
	g_MaxPlayers = get_maxplayers()
	g_MsgShakeScreen = get_user_msgid("ScreenShake")
	g_MsgFadeScreen = get_user_msgid("ScreenFade")
}

public plugin_precache()
{
	// Register Class
	g_PyroTech = ZombieEli_RegisterClass(CLASS_NAME, CLASS_HEALTH, CLASS_ARMOR, CLASS_GRAVITY, CLASS_SPEED, CLASS_MODEL, CLASS_CLAWMODEL, CLASS_TEAM, 0)

	// Skill
	g_Behemoth = ZombieEli_RegisterSkill(g_PyroTech, "Claw of Behemoth", 3)
	g_FireDamage = ZombieEli_RegisterSkill(g_PyroTech, "Fire Damage", 3)
	g_FireDuration = ZombieEli_RegisterSkill(g_PyroTech, "Fire Duration", 3)
	
	precache_model(FireSprite)
	
	// Weapon
	precache_model(MODEL_V)
	precache_model(MODEL_P)
	precache_model(MODEL_W)
	
	precache_sound(EXP_SOUND)
	
	// Cache
	g_Trail_SprID = precache_model("sprites/laserbeam.spr")
	g_Ring_SprID = precache_model("sprites/shockwave.spr")
	g_Exp_SprID = precache_model(EXP_SPR)
}

public plugin_natives()
{
	register_native("PyroTech_AfterBurn", "Where_The_Love_Begins", 1)
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
}

public client_disconnect(id)
{
	Safety_Disconnected(id)
}

public zeli_user_spawned(id, ClassID)
{
	Stop_Behemoth(id)
	Remove_AfterBurn(id)
}

public zeli_class_active(id, ClassID)
{
	if(ClassID != g_PyroTech)
		return
		
	static Chance; 
	switch(ZombieEli_GetSP(id, g_Behemoth))
	{
		case 1: Chance = 20
		case 2: Chance = 40
		case 3: Chance = 80
		default:  Chance = -1
	}
	
	static Rand; Rand = random_num(0, 100)

	if(Rand <= Chance)
		Get_Behemoth(id)
}

public zeli_class_unactive(id, ClassID)
{
	if(ClassID != g_PyroTech)
		return
		
	UnSet_BitVar(g_Had_Behemoth, id)
}

public zeli_user_infected(id, ClassID)
{
	Stop_Behemoth(id)
	Remove_AfterBurn(id)
}

public zeli_levelup(id, ClassID, NewLevel)
{
	if(ClassID != g_PyroTech)
		return
	if(NewLevel == 10)
	{
		IG_ClientPrintColor(id, "!gYou reached Lv.10!n -> !tYou get 'Fire Cyclone' when you are spawned!!n")
	}
}

public Where_The_Love_Begins(Victim, Attacker)
{
	if(!is_alive(Victim)) return
	if(!is_connected(Attacker)) return
	if(ZombieEli_IsZombie(Attacker)) return
	if(!ZombieEli_IsZombie(Victim)) return
	if(ZombieEli_GetClass(Attacker) != g_PyroTech) return
	
	static SP;
	static Damage, Time
	
	SP = ZombieEli_GetSP(Attacker, g_FireDamage)
	switch(SP)
	{
		case 1: Damage = 15
		case 2: Damage = 25
		case 3: Damage = 35
		default: Damage = 5
	}
	
	SP = ZombieEli_GetSP(Attacker, g_FireDuration)
	switch(SP)
	{
		case 1: Time = 12
		case 2: Time = 15
		case 3: Time = 18
		default: Time = 10
	}
	
	Make_AfterBurn(Victim, Attacker, float(Time), Damage)
}

public Make_AfterBurn(id, attacker, Float:Time, Damage)
{
	static Ent; Ent = fm_find_ent_by_owner(-1, "afterburn", id)
	if(!pev_valid(Ent))
	{
		new iEnt = create_entity("env_sprite")
		static Float:MyOrigin[3]
		
		pev(id, pev_origin, MyOrigin)
		
		// set info for ent
		set_pev(iEnt, pev_movetype, MOVETYPE_FLY)
		set_pev(iEnt, pev_rendermode, kRenderTransAdd)
		set_pev(iEnt, pev_renderamt, 250.0)
		set_pev(iEnt, pev_scale, 0.375)
		set_pev(iEnt, pev_fuser1, get_gametime() + Time)	// time remove
		set_pev(iEnt, pev_iuser1, Damage)
		
		entity_set_string(iEnt, EV_SZ_classname, "afterburn")
		engfunc(EngFunc_SetModel, iEnt, FireSprite)
		set_pev(iEnt, pev_origin, MyOrigin)
		set_pev(iEnt, pev_owner, id)
		set_pev(iEnt, pev_aiment, id)
		set_pev(iEnt, pev_frame, 0.0)
		set_pev(iEnt, pev_iuser4, attacker)
		
		set_pev(iEnt, pev_nextthink, get_gametime() + 0.05)
	} else {
		set_pev(Ent, pev_fuser1, get_gametime() + Time)	// time remove
		set_pev(Ent, pev_iuser1, Damage)
		
		set_pev(Ent, pev_nextthink, get_gametime() + 0.05)
	}
}

public Remove_AfterBurn(id)
{
	static Ent; Ent = fm_find_ent_by_owner(-1, "afterburn", id)
	if(pev_valid(Ent) == 2) 
	{
		set_pev(Ent, pev_nextthink, get_gametime() + 0.05)
		set_pev(Ent, pev_flags, FL_KILLME)
	}
}

public fw_FireBurn_Think(iEnt)
{
	if(!pev_valid(iEnt)) 
		return
	
	static Float:fFrame
	pev(iEnt, pev_frame, fFrame)

	// effect exp
	fFrame += 1.0
	if(fFrame > 7.0) fFrame = 0.0

	set_pev(iEnt, pev_frame, fFrame)
	set_pev(iEnt, pev_nextthink, get_gametime() + 0.05)
	
	static id; id = pev(iEnt, pev_owner)
	static attacker; attacker = pev(iEnt, pev_iuser4)
	if(!is_alive(id))
	{
		engfunc(EngFunc_RemoveEntity, iEnt)
		return;
	}
	if(!is_connected(attacker))
	{
		engfunc(EngFunc_RemoveEntity, iEnt)
		return;
	}
	
	if(get_gametime() - 2.0 > pev(iEnt, pev_fuser2))
	{
		ExecuteHamB(Ham_TakeDamage, id, 0, attacker, 0.0, DMG_BURN)
		if((get_user_health(id) - pev(iEnt, pev_iuser1)) > 0) set_user_health(id, get_user_health(id) - pev(iEnt, pev_iuser1))
		else ExecuteHamB(Ham_TakeDamage, id, 0, attacker, pev(iEnt, pev_iuser1) * 10.0, DMG_BURN)
		set_pev(iEnt, pev_fuser2, get_gametime())
	}
	
	// time remove
	static Float:fTimeRemove
	pev(iEnt, pev_fuser1, fTimeRemove)
	if (get_gametime() >= fTimeRemove)
	{
		engfunc(EngFunc_RemoveEntity, iEnt)
		return;
	}
}

// Behemoth SHIT
public Get_Behemoth(id)
{
	Set_BitVar(g_Had_Behemoth, id)
	give_item(id, weapon_behemoth)
	
	if(get_user_weapon(id) == CSW_BEHEMOTH)
	{
		set_pev(id, pev_viewmodel2, MODEL_V)
		set_pev(id, pev_weaponmodel2, MODEL_P)
	
		Set_Player_NextAttack(id, 0.75)
		Set_WeaponAnim(id, ANIM_DRAW)
	}
}

public Stop_Behemoth(id)
{
	if(!is_connected(id))
		return
	
	Release_Player(id+TASK_HOLD)
}

public Event_Death()
{
	static Victim; Victim = read_data(2)
	if(Get_BitVar(g_IsEffected, Victim))
		Release_Player(Victim+TASK_HOLD)
}

public fw_SetModel(Ent, const Model[])
{
	static id; id = pev(Ent, pev_owner)
	if(!is_user_connected(id)) return FMRES_IGNORED
		
	static Float:DMGTime; pev(Ent, pev_dmgtime, DMGTime)
	if(DMGTime == 0.0) return FMRES_IGNORED
	
	if(equal(Model, MODEL_W_OLD) && Get_BitVar(g_Had_Behemoth, id))
	{
		static Team; Team = _:cs_get_user_team(id)
		static RGB[3]
		
		// Set Frostnade
		set_pev(Ent, pev_team, Team)
		set_pev(Ent, pev_bInDuck, 445)
		
		// Glow
		set_pev(Ent, pev_rendermode, kRenderNormal)
		set_pev(Ent, pev_renderfx, kRenderFxGlowShell)
		set_pev(Ent, pev_rendercolor, BEHEMOTH_COLOR)
		set_pev(Ent, pev_renderamt, 16.0)
		
		engfunc(EngFunc_SetModel, Ent, MODEL_W)
		
		FVecIVec(BEHEMOTH_COLOR, RGB)
		Create_Trail(Ent, 10, 10, RGB, 250)
		
		// Remove
		UnSet_BitVar(g_Had_Behemoth, id)
		
		return FMRES_SUPERCEDE
	}
	
	return FMRES_IGNORED
}

public fw_GrenadeTouch(Ent, Touched)
{
	if(!pev_valid(Ent) || pev(Ent, pev_bInDuck) != 445) 
		return HAM_IGNORED
		
	static Impact; Impact = IMPACT_EXPLOSION
	if(Impact) set_pev(Ent, pev_dmgtime, get_gametime())
	
	return HAM_IGNORED
}

public fw_GrenadeThink(Ent)
{
	if(!pev_valid(Ent) || pev(Ent, pev_bInDuck) != 445) 
		return HAM_IGNORED
	
	static Float:DMGTime; pev(Ent, pev_dmgtime, DMGTime)
	if(DMGTime > get_gametime()) 
		return HAM_IGNORED
	
	Behemoth_Explosion(Ent)
	engfunc(EngFunc_RemoveEntity, Ent)

	return HAM_SUPERCEDE
}

public fw_Item_Deploy_Post(Ent)
{
	if(pev_valid(Ent) != 2)
		return
	static Id; Id = get_pdata_cbase(Ent, 41, 4)
	if(get_pdata_cbase(Id, 373) != Ent)
		return
	if(!Get_BitVar(g_Had_Behemoth, Id))
		return

	set_pev(Id, pev_viewmodel2, MODEL_V)
	set_pev(Id, pev_weaponmodel2, MODEL_P)
	
	Set_WeaponAnim(Id, ANIM_DRAW)
}

public Behemoth_Explosion(Ent)
{
	static Team; Team = pev(Ent, pev_team)
	static Float:Origin[3]; pev(Ent, pev_origin, Origin)
	
	// Effect
	engfunc(EngFunc_MessageBegin, MSG_PVS, SVC_TEMPENTITY, Origin, 0)
	write_byte(TE_EXPLOSION)
	engfunc(EngFunc_WriteCoord, Origin[0])
	engfunc(EngFunc_WriteCoord, Origin[1])
	engfunc(EngFunc_WriteCoord, Origin[2])
	write_short(g_Exp_SprID) // sprite index
	write_byte(30)	// scale in 0.1's
	write_byte(20)	// framerate
	write_byte(TE_EXPLFLAG_NODLIGHTS | TE_EXPLFLAG_NOSOUND)	// flags
	message_end()
	
	static RGB[3]; FVecIVec(BEHEMOTH_COLOR, RGB)
	Effect_Ring(Origin, g_Ring_SprID, RGB, EFFECT_RADIUS)
	
	emit_sound(Ent, CHAN_BODY, EXP_SOUND, VOL_NORM, ATTN_NORM, 0, PITCH_NORM)
	
	// Check Affect
	static TeamCheck; TeamCheck = 0
	static Float:Origin2[3]
	for(new i = 0; i < g_MaxPlayers; i++)
	{
		if(!is_alive(i)) continue
		if(pev(Ent, pev_owner) == i) continue
		
		TeamCheck = (_:cs_get_user_team(i) == Team)
		if(TeamCheck) continue
		if(entity_range(Ent, i) > EFFECT_RADIUS) continue
		pev(i, pev_origin, Origin2)
		if(is_wall_between_points(Origin, Origin2, 0)) continue
		
		Activate_Behemoth(i)
	}
}

public Activate_Behemoth(id)
{
	if(Get_BitVar(g_IsEffected, id))
	{
		// Hold Time
		remove_task(id+TASK_HOLD)
		set_task(EFFECT_HOLDTIME + random_float(-0.5, 1.0), "Release_Player", id+TASK_HOLD)
		
		return
	}

	Set_BitVar(g_IsEffected, id)
	
	// Effect
	static RGB[3]; FVecIVec(BEHEMOTH_COLOR, RGB)
	set_user_rendering(id, kRenderFxGlowShell, RGB[0], RGB[1], RGB[2], kRenderNormal, 1);
	
	// Hold Time
	remove_task(id+TASK_HOLD)
	set_task(EFFECT_HOLDTIME + random_float(-0.5, 1.0), "Release_Player", id+TASK_HOLD)
}

public Release_Player(id)
{
	id -= TASK_HOLD
	
	if(!is_connected(id))
		return
		
	UnSet_BitVar(g_IsEffected, id)
	set_user_rendering(id)
}

public client_PreThink(id)
{
	if(!is_alive(id))
		return
	if(!Get_BitVar(g_IsEffected, id))
		return
		
	if(get_gametime() - 0.5 > EffectDelay[id])
	{
		// PunchAngles
		static Float:Vector[3];
		Vector[0] = random_float(0.0, 25.0)
		Vector[1] = random_float(0.0, 25.0)
		Vector[2] = random_float(0.0, 5.0)
		set_pev(id, pev_punchangle, Vector)
		
		// ShakeScreen
		message_begin(MSG_ONE_UNRELIABLE, g_MsgShakeScreen, {0,0,0} ,id)
		write_short(FixedUnsigned16(10.0, (1<<12)))
		write_short(FixedUnsigned16(1.0, (1<<12)))
		write_short(FixedUnsigned16(1.0, (1<<12)))
		message_end()
		
		// FadeScreen
		message_begin(MSG_ONE_UNRELIABLE, g_MsgFadeScreen, {0,0,0} ,id)
		write_short(FixedUnsigned16(0.25, (1<<12)))    // Duration
		write_short(FixedUnsigned16(0.25, (1<<12)))    // Hold time
		write_short(0x0000)    // Fade type (I think this is what i have to change)
		write_byte(random_num(0, 255))        // Red
		write_byte(random_num(0, 255))    // Green
		write_byte(random_num(0, 255))        // Blue
		write_byte(100)    // Alpha
		message_end()
		
		EffectDelay[id] = get_gametime()
	}
}

FixedUnsigned16(Float:flValue, iScale)
{
	new iOutput
	iOutput = floatround(flValue * iScale);

	if ( iOutput < 0 )
		iOutput = 0;

	if ( iOutput > 0xFFFF )
	iOutput = 0xFFFF;

	return iOutput;
}  

public Effect_Ring(Float:Origin[3], SpriteID, RGB[3], Float:Radius)
{
	// smallest ring
	engfunc(EngFunc_MessageBegin, MSG_PVS, SVC_TEMPENTITY, Origin, 0)
	write_byte(TE_BEAMCYLINDER);
	engfunc(EngFunc_WriteCoord, Origin[0])
	engfunc(EngFunc_WriteCoord, Origin[1])
	engfunc(EngFunc_WriteCoord, Origin[2])
	engfunc(EngFunc_WriteCoord, Origin[0])
	engfunc(EngFunc_WriteCoord, Origin[1])
	engfunc(EngFunc_WriteCoord, Origin[2] + 100.0)
	write_short(SpriteID); // sprite
	write_byte(0); // start frame
	write_byte(0); // framerate
	write_byte(4); // life
	write_byte(60); // width
	write_byte(0); // noise
	write_byte(RGB[0]); // red
	write_byte(RGB[1]); // green
	write_byte(RGB[2]); // blue
	write_byte(250); // brightness
	write_byte(0); // speed
	message_end();

	// medium ring
	engfunc(EngFunc_MessageBegin, MSG_PVS, SVC_TEMPENTITY, Origin, 0)
	write_byte(TE_BEAMCYLINDER);
	engfunc(EngFunc_WriteCoord, Origin[0])
	engfunc(EngFunc_WriteCoord, Origin[1])
	engfunc(EngFunc_WriteCoord, Origin[2])
	engfunc(EngFunc_WriteCoord, Origin[0])
	engfunc(EngFunc_WriteCoord, Origin[1])
	engfunc(EngFunc_WriteCoord, Origin[2] + 250.0)
	write_short(SpriteID); // sprite
	write_byte(0); // start frame
	write_byte(0); // framerate
	write_byte(4); // life
	write_byte(60); // width
	write_byte(0); // noise
	write_byte(RGB[0]); // red
	write_byte(RGB[1]); // green
	write_byte(RGB[2]); // blue
	write_byte(200); // brightness
	write_byte(0); // speed
	message_end();

	// largest ring
	engfunc(EngFunc_MessageBegin, MSG_PVS, SVC_TEMPENTITY, Origin, 0)
	write_byte(TE_BEAMCYLINDER);
	engfunc(EngFunc_WriteCoord, Origin[0])
	engfunc(EngFunc_WriteCoord, Origin[1])
	engfunc(EngFunc_WriteCoord, Origin[2])
	engfunc(EngFunc_WriteCoord, Origin[0])
	engfunc(EngFunc_WriteCoord, Origin[1])
	engfunc(EngFunc_WriteCoord, Origin[2] + 500.0)
	write_short(SpriteID); // sprite
	write_byte(0); // start frame
	write_byte(0); // framerate
	write_byte(4); // life
	write_byte(60); // width
	write_byte(0); // noise
	write_byte(RGB[0]); // red
	write_byte(RGB[1]); // green
	write_byte(RGB[2]); // blue
	write_byte(150); // brightness
	write_byte(0); // speed
	message_end();

	// light effect
	engfunc(EngFunc_MessageBegin, MSG_PVS, SVC_TEMPENTITY, Origin, 0)
	write_byte(TE_DLIGHT);
	engfunc(EngFunc_WriteCoord, Origin[0])
	engfunc(EngFunc_WriteCoord, Origin[1])
	engfunc(EngFunc_WriteCoord, Origin[2])
	write_byte(floatround(Radius/5.0)); // radius
	write_byte(RGB[0]); // r
	write_byte(RGB[1]); // g
	write_byte(RGB[2]); // b
	write_byte(8); // life
	write_byte(60); // decay rate
	message_end();
}

public Create_Trail(Ent, Life, Width, RGB[3], Brightness)
{
	Clear_Trail(Ent)

	message_begin(MSG_BROADCAST,SVC_TEMPENTITY)
	write_byte(TE_BEAMFOLLOW)
	write_short(Ent)
	write_short(g_Trail_SprID); // sprite
	write_byte(Life); // life
	write_byte(Width); // width
	write_byte(RGB[0]); // red
	write_byte(RGB[1]); // green
	write_byte(RGB[2]); // blue
	write_byte(Brightness); // brightness
	message_end();
}

public Clear_Trail(Ent)
{
	message_begin(MSG_BROADCAST, SVC_TEMPENTITY)
	write_byte(TE_KILLBEAM)
	write_short(Ent)
	message_end()
}

stock Set_Player_NextAttack(id, Float:NextTime) set_pdata_float(id, 83, NextTime, 5)
stock Set_WeaponAnim(id, anim)
{
	set_pev(id, pev_weaponanim, anim)
	
	message_begin(MSG_ONE_UNRELIABLE, SVC_WEAPONANIM, {0, 0, 0}, id)
	write_byte(anim)
	write_byte(pev(id, pev_body))
	message_end()
}

stock is_wall_between_points(Float:start[3], Float:end[3], ignore_ent)
{
	static ptr
	ptr = create_tr2()

	engfunc(EngFunc_TraceLine, start, end, IGNORE_MONSTERS, ignore_ent, ptr)
	
	static Float:EndPos[3]
	get_tr2(ptr, TR_vecEndPos, EndPos)

	free_tr2(ptr)
	return floatround(get_distance_f(end, EndPos))
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
/* AMXX-Studio Notes - DO NOT MODIFY BELOW HERE
*{\\ rtf1\\ ansi\\ deff0{\\ fonttbl{\\ f0\\ fnil Tahoma;}}\n\\ viewkind4\\ uc1\\ pard\\ lang3076\\ f0\\ fs16 \n\\ par }
*/
