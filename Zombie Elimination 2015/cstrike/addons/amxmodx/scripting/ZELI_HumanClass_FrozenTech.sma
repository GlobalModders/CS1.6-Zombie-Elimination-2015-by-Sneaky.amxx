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

#define PLUGIN "[ZELI] H-Class: Frozen Tech"
#define VERSION "1.0"
#define AUTHOR "Dias Pendragon Leon"

// Class Setting
#define CLASS_NAME "Frozen Tech"
#define CLASS_MODEL "zeli_hm_frozentech"
#define CLASS_CLAWMODEL ""
#define CLASS_TEAM TEAM_HUMAN

const CLASS_HEALTH = 100
const CLASS_ARMOR = 100
const Float:CLASS_GRAVITY = 1.0
const Float:CLASS_SPEED = 250.0

new g_FrozenTech
new g_FrostNade_Chance, g_FrozenShield, g_FrostBite

// Frostnade
// Weapon
#define MODEL_V "models/v_flashbang.mdl"
#define MODEL_P "models/p_flashbang.mdl"
#define MODEL_W "models/w_flashbang.mdl"

#define MODEL_W_OLD "models/w_flashbang.mdl"

#define CSW_FROSTNOVA CSW_FLASHBANG
#define weapon_frostnova "weapon_flashbang"

// Frost Nova
#define MODEL_ICEBLOCK "models/zombie_elimination/avfrost_iceblock.mdl"

#define SOUND_EXPLOSION "zombie_elimination/frostnova.wav"
#define SOUND_HIT "zombie_elimination/impalehit.wav"
#define SOUND_RELEASE "zombie_elimination/impalelaunch1.wav"

#define IMPACT_EXPLOSION 1
#define FROST_RADIUS 240.0
#define FROST_HOLDTIME 5.0

new const Float:NOVA_COLOR[3] = {0.0, 127.0, 255.0}

#define TASK_HOLD 212015

// MACROS
#define Get_BitVar(%1,%2) (%1 & (1 << (%2 & 31)))
#define Set_BitVar(%1,%2) %1 |= (1 << (%2 & 31))
#define UnSet_BitVar(%1,%2) %1 &= ~(1 << (%2 & 31))

enum
{
	ANIM_IDLE = 0,
	ANIM_PULLPIN,
	ANIM_THROW,
	ANIM_DRAW
}

new g_Had_FrostNova, g_IsFrozen, Float:g_FrozenOrigin[33][3], g_MyNova[33]
new g_Trail_SprID/*, g_Smoke_SprID*/, g_Exp_SprID, g_Ball_SprID, g_Flame_SprID
new g_GlassGib_SprID, g_MsgStatusIcon
new g_MaxPlayers, g_HamBot

// Frozen Shield
#define TASK_SHIELD 389687
new const ShieldSound[2][] = 
{
	"zombie_elimination/frozen_shield1.wav",
	"zombie_elimination/frozen_shield2.wav"
}
new g_ShieldReady[33]

// Frostbite
#define TASK_FROSTBITE 594378
new g_HitFrostBite, Float:BiteDelay[33], g_MyDamage[33], g_Attacker[33]

// Frozen Hook
#define TE_BEAMENTPOINT 1
#define TE_KILLBEAM 99
#define DELTA_T 0.1				// seconds
#define BEAMLIFE 100			// deciseconds
#define MOVEACCELERATION 150	// units per second^2
#define REELSPEED 300			// units per second

/* Hook Stuff */
new gHookLocation[33][3]
new gHookLenght[33]
new bool:gIsHooked[33]
new gAllowedHook[33]
new Float:gBeamIsCreated[33]
new beam

// Safety
new g_IsConnected, g_IsAlive, g_PlayerWeapon[33]

public plugin_init()
{
	register_plugin(PLUGIN, VERSION, AUTHOR)
	
	register_event("DeathMsg", "Event_Death", "a")
	
	Register_SafetyFunc()
	register_forward(FM_SetModel, "fw_SetModel")
	register_forward(FM_CmdStart, "fw_CmdStart")

	RegisterHam(Ham_Touch, "grenade", "fw_GrenadeTouch")
	RegisterHam(Ham_Think, "grenade", "fw_GrenadeThink")
	RegisterHam(Ham_Item_Deploy, weapon_frostnova, "fw_Item_Deploy_Post", 1)	
	RegisterHam(Ham_TraceAttack, "player", "fw_PlayerTraceAttack_Post", 1)
	
	g_MaxPlayers = get_maxplayers()
	g_MsgStatusIcon = get_user_msgid("StatusIcon")
	
	// CMD
	register_clcmd("drop", "CMD_Drop")
}

public plugin_precache()
{
	// Register Class
	g_FrozenTech = ZombieEli_RegisterClass(CLASS_NAME, CLASS_HEALTH, CLASS_ARMOR, CLASS_GRAVITY, CLASS_SPEED, CLASS_MODEL, CLASS_CLAWMODEL, CLASS_TEAM, 0)

	// Register Skill
	g_FrostNade_Chance = ZombieEli_RegisterSkill(g_FrozenTech, "Frost Nade Chance", 3)
	g_FrozenShield = ZombieEli_RegisterSkill(g_FrozenTech, "Frozen Shield", 3)
	g_FrostBite = ZombieEli_RegisterSkill(g_FrozenTech, "Frost Bite", 3)
	
	// Frostnade
	// Weapon
	precache_model(MODEL_V)
	precache_model(MODEL_P)
	precache_model(MODEL_W)
	
	// Frost Nave
	precache_model(MODEL_ICEBLOCK)
	
	precache_sound(SOUND_EXPLOSION)
	precache_sound(SOUND_HIT)
	precache_sound(SOUND_RELEASE)
	
	// Cache
	g_Trail_SprID = precache_model("sprites/laserbeam.spr")
	//g_Smoke_SprID = precache_model("sprites/steam1.spr")
	g_Exp_SprID = precache_model("sprites/shockwave.spr")
	g_Ball_SprID = precache_model("sprites/zombie_elimination/avfrost_blueball.spr")
	g_Flame_SprID = precache_model("sprites/zombie_elimination/avfrost_blueflame.spr")
	
	g_GlassGib_SprID = precache_model("models/glassgibs.mdl")
	
	// Shield
	for(new i = 0; i < sizeof(ShieldSound); i++)
		precache_sound(ShieldSound[i])
		
	// Hook
	beam = precache_model("sprites/zbeam4.spr")
	precache_sound("weapons/xbow_hit2.wav")
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
	
	RegisterHamFromEntity(Ham_TraceAttack, id, "fw_PlayerTraceAttack_Post", 1)
}

public client_disconnect(id)
{
	Safety_Disconnected(id)
}

public zeli_user_spawned(id, ClassID)
{
	if(gIsHooked[id]) RopeRelease(id)
	
	message_begin(MSG_ONE_UNRELIABLE, g_MsgStatusIcon, {0,0,0}, id)
	write_byte(0)
	write_string("dmg_cold")
	write_byte(0)
	write_byte(255)
	write_byte(255)
	message_end()
	
	g_ShieldReady[id] = 0
	remove_task(id+TASK_SHIELD)
	remove_task(id+TASK_FROSTBITE)
	
	UnSet_BitVar(g_HitFrostBite, id)
	Stop_FrostNova(id, 0)
}

public zeli_class_active(id, ClassID)
{
	if(ClassID != g_FrozenTech)
		return
		
	g_ShieldReady[id] = 0
	gAllowedHook[id] = 1
		
	static Chance; 
	switch(ZombieEli_GetSP(id, g_FrostNade_Chance))
	{
		case 1: Chance = 20
		case 2: Chance = 35
		case 3: Chance = 50
		default:  Chance = -1
	}
	
	static Rand; Rand = random_num(0, 100)

	if(Rand <= Chance)
		Get_FrostNova(id)
}

public zeli_class_unactive(id, ClassID)
{
	UnSet_BitVar(g_Had_FrostNova, id)
}

public zeli_user_infected(id, ClassID)
{
	message_begin(MSG_ONE_UNRELIABLE, g_MsgStatusIcon, {0,0,0}, id)
	write_byte(0)
	write_string("dmg_cold")
	write_byte(0)
	write_byte(255)
	write_byte(255)
	message_end()
	
	if(gIsHooked[id]) RopeRelease(id)
	
	g_ShieldReady[id] = 0
	remove_task(id+TASK_SHIELD)
	remove_task(id+TASK_FROSTBITE)
	
	UnSet_BitVar(g_HitFrostBite, id)
	Stop_FrostNova(id, 0)
}

public zeli_levelup(id, ClassID, NewLevel)
{
	if(ClassID != g_FrozenTech)
		return
	if(NewLevel == 10)
	{
		IG_ClientPrintColor(id, "!gYou reached Lv.10!n -> !tHold [E] to use 'Frozen Hook!!n")
	}
}

public fw_CmdStart(id, uc_handle, seed)
{
	if(!is_alive(id))
		return
	if(ZombieEli_IsZombie(id))
		return
	if(ZombieEli_GetClass(id) != g_FrozenTech)
		return
		
	static New, Old;
	New = get_uc(uc_handle, UC_Buttons)
	Old = pev(id, pev_oldbuttons)
	
	if((New & IN_USE) && !(Old & IN_USE))
	{
		hook_on(id)
	} else {
		if(!(New & IN_USE) && (Old & IN_USE))
		{
			hook_off(id)
		}
	}
}

public CMD_Drop(id)
{
	if(!is_alive(id))
		return PLUGIN_CONTINUE
	if(ZombieEli_GetClass(id) != g_FrozenTech)
		return PLUGIN_CONTINUE
	
	static SP; SP = ZombieEli_GetSP(id, g_FrozenShield)
	if(SP <= 0) return PLUGIN_HANDLED
	
	if(g_ShieldReady[id] == -1 || g_ShieldReady[id]) return PLUGIN_HANDLED
	
	static Float:Time;
	switch(SP)
	{
		case 1: Time = 5.0
		case 2: Time = 10.0
		case 3: Time = 15.0
		default:  Time = 0.0
	}

	g_ShieldReady[id] = 1
	
	fm_set_user_rendering(id, kRenderFxGlowShell, 0, 255, 255, kRenderNormal, 16)
	
	remove_task(id+TASK_SHIELD)
	set_task(Time, "Remove_Shield", id+TASK_SHIELD)
	
	emit_sound(id, CHAN_ITEM, ShieldSound[random_num(0, sizeof(ShieldSound) -1)], VOL_NORM, ATTN_NORM, 0, PITCH_NORM)
	IG_ClientPrintColor(id, "!gYou've activated !t'Frozen Shield'!g for !t%i!g second(s)!", floatround(Time))
	
	return PLUGIN_HANDLED
}

public fw_PlayerTraceAttack_Post(Victim, Attacker, Float:Damage, Float:Direction[3], Trace, DamageBits)
{
	if(Victim == Attacker)
		return HAM_IGNORED
	if(!is_connected(Victim) || !is_connected(Attacker))
		return HAM_IGNORED
	if(ZombieEli_IsZombie(Attacker) && !ZombieEli_IsZombie(Victim))
	{
		if(ZombieEli_GetClass(Victim) != g_FrozenTech)
			return HAM_IGNORED
		
		if(g_ShieldReady[Victim] == 1)
		{
			emit_sound(Attacker, CHAN_ITEM, SOUND_HIT, VOL_NORM, ATTN_NORM, 0, PITCH_NORM)
			Freeze_Player(Attacker)
		}
	}
	if(!ZombieEli_IsZombie(Attacker) && ZombieEli_IsZombie(Victim))
	{
		if(ZombieEli_GetClass(Attacker) != g_FrozenTech)
			return HAM_IGNORED
			
		static SP; SP = ZombieEli_GetSP(Attacker, g_FrostBite)
		if(SP <= 0) return HAM_IGNORED
		if(task_exists(Victim+TASK_FROSTBITE)) return HAM_IGNORED
		
		set_pdata_float(Victim, 108, 0.1, 5)
		
		switch(SP)
		{
			case 1: g_MyDamage[Victim] = 30
			case 2: g_MyDamage[Victim] = 45
			case 3: g_MyDamage[Victim] = 60
			default: g_MyDamage[Victim] = 30
		}
		
		message_begin(MSG_ONE_UNRELIABLE, g_MsgStatusIcon, {0,0,0}, Victim)
		write_byte(1)
		write_string("dmg_cold")
		write_byte(0)
		write_byte(255)
		write_byte(255)
		message_end()
		
		g_Attacker[Victim] = Attacker
		Set_BitVar(g_HitFrostBite, Victim)
		set_task(10.0, "Remove_FrostBite", Victim+TASK_FROSTBITE)
	}
		
	return HAM_HANDLED
}

public Remove_FrostBite(id)
{
	id -= TASK_FROSTBITE
	
	if(!is_alive(id))
		return
		
	UnSet_BitVar(g_HitFrostBite, id)
}

public Remove_Shield(id)
{
	id -= TASK_SHIELD
	
	if(!is_alive(id))
		return
	if(ZombieEli_GetClass(id) != g_FrozenTech)
		return
		
	g_ShieldReady[id] = -1
	fm_set_user_rendering(id)
	
	IG_ClientPrintColor(id, "!tFrozen Shield!g is unactivated!")
}

public Get_FrostNova(id)
{
	Set_BitVar(g_Had_FrostNova, id)
	give_item(id, weapon_frostnova)
	
	if(get_user_weapon(id) == CSW_FROSTNOVA)
	{
		set_pev(id, pev_viewmodel2, MODEL_V)
		set_pev(id, pev_weaponmodel2, MODEL_P)
	
		Set_Player_NextAttack(id, 0.75)
		Set_WeaponAnim(id, ANIM_DRAW)
	}
}

public Stop_FrostNova(id, Effect)
{
	if(!is_connected(id))
		return
	
	UnSet_BitVar(g_IsFrozen, id)
	if(pev_valid(g_MyNova[id])) 
	{	
		set_pev(g_MyNova[id], pev_nextthink, get_gametime() + 0.05)
		set_pev(g_MyNova[id], pev_flags, FL_KILLME)
		g_MyNova[id] = -1
	}
	
	if(Effect)
	{
		set_user_rendering(id)
		
		// Effect
		static Float:Origin[3]; pev(id, pev_origin, Origin)
	
		engfunc(EngFunc_MessageBegin, MSG_PVS, SVC_TEMPENTITY, Origin, 0)
		write_byte(TE_IMPLOSION);
		engfunc(EngFunc_WriteCoord, Origin[0])
		engfunc(EngFunc_WriteCoord, Origin[1])
		engfunc(EngFunc_WriteCoord, Origin[2] + 8.0)
		write_byte(64)
		write_byte(10)
		write_byte(3)
		message_end()
	
		engfunc(EngFunc_MessageBegin, MSG_PVS, SVC_TEMPENTITY, Origin, 0)
		write_byte(TE_SPARKS);
		engfunc(EngFunc_WriteCoord, Origin[0])
		engfunc(EngFunc_WriteCoord, Origin[1])
		engfunc(EngFunc_WriteCoord, Origin[2])
		message_end();
	
		// add the shatter
		engfunc(EngFunc_MessageBegin, MSG_PVS, SVC_TEMPENTITY, Origin, 0)
		write_byte(TE_BREAKMODEL);
		engfunc(EngFunc_WriteCoord, Origin[0])
		engfunc(EngFunc_WriteCoord, Origin[1])
		engfunc(EngFunc_WriteCoord, Origin[2] + 24.0)
		engfunc(EngFunc_WriteCoord, 16.0)
		engfunc(EngFunc_WriteCoord, 16.0)
		engfunc(EngFunc_WriteCoord, 16.0)
		write_coord(random_num(-50,50)); // velocity x
		write_coord(random_num(-50,50)); // velocity y
		engfunc(EngFunc_WriteCoord, 25.0)
		write_byte(10); // random velocity
		write_short(g_GlassGib_SprID); // model
		write_byte(25); // count
		write_byte(25); // life
		write_byte(0x01/*BREAK_GLASS*/); // flags
		message_end();
		
		static RGB[3]; FVecIVec(NOVA_COLOR, RGB)
		
		engfunc(EngFunc_MessageBegin, MSG_PVS, SVC_TEMPENTITY, Origin, 0)
		write_byte(TE_BEAMCYLINDER);
		engfunc(EngFunc_WriteCoord, Origin[0])
		engfunc(EngFunc_WriteCoord, Origin[1])
		engfunc(EngFunc_WriteCoord, Origin[2])
		engfunc(EngFunc_WriteCoord, Origin[0])
		engfunc(EngFunc_WriteCoord, Origin[1])
		engfunc(EngFunc_WriteCoord, Origin[2] + 250.0)
		write_short(g_Exp_SprID); // sprite
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
		
		// Sound
		emit_sound(id, CHAN_ITEM, SOUND_RELEASE, VOL_NORM, ATTN_NORM, 0, PITCH_NORM)
	}
}

public Event_Death()
{
	static Victim; Victim = read_data(2)
	if(Get_BitVar(g_IsFrozen, Victim))
		Release_Player(Victim+TASK_HOLD)
		
	g_ShieldReady[Victim] = 0
	remove_task(Victim+TASK_SHIELD)
	remove_task(Victim+TASK_FROSTBITE)
	
	UnSet_BitVar(g_HitFrostBite, Victim)
}

public fw_SetModel(Ent, const Model[])
{
	static id; id = pev(Ent, pev_owner)
	if(!is_user_connected(id)) return FMRES_IGNORED
		
	static Float:DMGTime; pev(Ent, pev_dmgtime, DMGTime)
	if(DMGTime == 0.0) return FMRES_IGNORED
	
	if(equal(Model, MODEL_W_OLD) && Get_BitVar(g_Had_FrostNova, id))
	{
		static Team; Team = _:cs_get_user_team(id)
		static RGB[3]
		
		// Set Frostnade
		set_pev(Ent, pev_team, Team)
		set_pev(Ent, pev_bInDuck, 444)
		
		// Glow
		set_pev(Ent, pev_rendermode, kRenderNormal)
		set_pev(Ent, pev_renderfx, kRenderFxGlowShell)
		set_pev(Ent, pev_rendercolor, NOVA_COLOR)
		set_pev(Ent, pev_renderamt, 16.0)
		
		engfunc(EngFunc_SetModel, Ent, MODEL_W)
		
		FVecIVec(NOVA_COLOR, RGB)
		Create_Trail(Ent, 10, 10, RGB, 250)
		
		// Remove
		UnSet_BitVar(g_Had_FrostNova, id)
		
		return FMRES_SUPERCEDE
	}
	
	return FMRES_IGNORED
}

public fw_GrenadeTouch(Ent, Touched)
{
	if(!pev_valid(Ent) || pev(Ent, pev_bInDuck) != 444) 
		return HAM_IGNORED
		
	static Impact; Impact = IMPACT_EXPLOSION
	if(Impact) set_pev(Ent, pev_dmgtime, get_gametime())
	
	return HAM_IGNORED
}

public fw_GrenadeThink(Ent)
{
	if(!pev_valid(Ent) || pev(Ent, pev_bInDuck) != 444) 
		return HAM_IGNORED
	
	static Float:DMGTime; pev(Ent, pev_dmgtime, DMGTime)
	if(DMGTime > get_gametime()) 
		return HAM_IGNORED
	
	AvalancheFrost_Explosion(Ent)
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
	if(!Get_BitVar(g_Had_FrostNova, Id))
		return

	set_pev(Id, pev_viewmodel2, MODEL_V)
	set_pev(Id, pev_weaponmodel2, MODEL_P)
	
	Set_WeaponAnim(Id, ANIM_DRAW)
}

public AvalancheFrost_Explosion(Ent)
{
	static Team; Team = pev(Ent, pev_team)
	static Float:Origin[3]; pev(Ent, pev_origin, Origin)
	
	// Effect
	/*
	engfunc(EngFunc_MessageBegin, MSG_PVS, SVC_TEMPENTITY, Origin, 0)
	write_byte(TE_SMOKE);
	engfunc(EngFunc_WriteCoord, Origin[0])
	engfunc(EngFunc_WriteCoord, Origin[1])
	engfunc(EngFunc_WriteCoord, Origin[2] + 60.0)
	write_short(g_Smoke_SprID); // sprite
	write_byte(random_num(30,40)); // scale
	write_byte(5); // framerate
	message_end();*/
	
	engfunc(EngFunc_MessageBegin, MSG_PVS, SVC_TEMPENTITY, Origin, 0)
	write_byte(TE_EXPLOSION)
	engfunc(EngFunc_WriteCoord, Origin[0])
	engfunc(EngFunc_WriteCoord, Origin[1])
	engfunc(EngFunc_WriteCoord, Origin[2])
	write_short(g_Flame_SprID)	// sprite index
	write_byte(15)	// scale in 0.1's
	write_byte(20)	// framerate
	write_byte(TE_EXPLFLAG_NODLIGHTS | TE_EXPLFLAG_NOSOUND)	// flags
	message_end()
	
	engfunc(EngFunc_MessageBegin, MSG_PVS, SVC_TEMPENTITY, Origin, 0)
	write_byte(TE_SPRITETRAIL)
	engfunc(EngFunc_WriteCoord, Origin[0])
	engfunc(EngFunc_WriteCoord, Origin[1])
	engfunc(EngFunc_WriteCoord, Origin[2])
	engfunc(EngFunc_WriteCoord, Origin[0])
	engfunc(EngFunc_WriteCoord, Origin[1])
	engfunc(EngFunc_WriteCoord, Origin[2] + 50)
	write_short(g_Ball_SprID) // (sprite index)
	write_byte(25) // (count)
	write_byte(random_num(2, 5)) // (life in 0.1's)
	write_byte(5) // byte (scale in 0.1's)
	write_byte(random_num(10, 50)) // (velocity along vector in 10's)
	write_byte(5) // (randomness of velocity in 10's)
	message_end()
	
	static RGB[3]; FVecIVec(NOVA_COLOR, RGB)
	Effect_Ring(Origin, g_Exp_SprID, RGB, FROST_RADIUS)
	
	emit_sound(Ent, CHAN_BODY, SOUND_EXPLOSION, VOL_NORM, ATTN_NORM, 0, PITCH_NORM)
	
	// Check Affect
	static TeamCheck; TeamCheck = 0
	static Float:Origin2[3]
	for(new i = 0; i < g_MaxPlayers; i++)
	{
		if(!is_alive(i)) continue
		if(pev(Ent, pev_owner) == i) continue
		
		TeamCheck = (_:cs_get_user_team(i) == Team)
		if(TeamCheck) continue
		if(entity_range(Ent, i) > FROST_RADIUS) continue
		pev(i, pev_origin, Origin2)
		if(is_wall_between_points(Origin, Origin2, 0)) continue
		
		emit_sound(i, CHAN_ITEM, SOUND_HIT, VOL_NORM, ATTN_NORM, 0, PITCH_NORM)
		Freeze_Player(i)
	}
}

public Freeze_Player(id)
{
	if(Get_BitVar(g_IsFrozen, id))
	{
		// Hold Time
		remove_task(id+TASK_HOLD)
		set_task(FROST_HOLDTIME + random_float(-0.5, 1.0), "Release_Player", id+TASK_HOLD)
		
		return
	}
	
	// Stop
	set_pev(id, pev_velocity, Float:{0.0,0.0,0.0})
	
	pev(id, pev_origin, g_FrozenOrigin[id])
	Set_BitVar(g_IsFrozen, id)
	
	// Effect
	static RGB[3]; FVecIVec(NOVA_COLOR, RGB)
	set_user_rendering(id, kRenderFxGlowShell, RGB[0], RGB[1], RGB[2], kRenderNormal, 1);
	Create_ICEBlock(id)
	
	// Hold Time
	remove_task(id+TASK_HOLD)
	set_task(FROST_HOLDTIME + random_float(-0.5, 1.0), "Release_Player", id+TASK_HOLD)
}

public Create_ICEBlock(id)
{
	static NOVA; NOVA = engfunc(EngFunc_CreateNamedEntity, engfunc(EngFunc_AllocString, "info_target"))

	engfunc(EngFunc_SetSize, NOVA, Float:{-16.0, -16.0, -36.0},Float:{16.0, 16.0, 36.0});
	engfunc(EngFunc_SetModel, NOVA, MODEL_ICEBLOCK)

	static Float:Angles[3]
	Angles[1] = random_float(0.0, 360.0)
	set_pev(NOVA, pev_angles, Angles)

	static Float:NovaOrigin[3]
	pev(id, pev_origin, NovaOrigin)
	NovaOrigin[2] -= 36.0
	engfunc(EngFunc_SetOrigin, NOVA, NovaOrigin)

	set_pev(NOVA, pev_rendercolor, NOVA_COLOR)
	set_pev(NOVA, pev_rendermode, kRenderTransAlpha)
	set_pev(NOVA, pev_renderfx, kRenderFxGlowShell)
	set_pev(NOVA, pev_renderamt, 128.0)

	g_MyNova[id] = NOVA
}

public Release_Player(id)
{
	id -= TASK_HOLD
	
	if(!is_connected(id))
		return
		
	UnSet_BitVar(g_IsFrozen, id)
	set_user_rendering(id)
	
	// Effect
	static Float:Origin[3]; pev(id, pev_origin, Origin)

	engfunc(EngFunc_MessageBegin, MSG_PVS, SVC_TEMPENTITY, Origin, 0)
	write_byte(TE_IMPLOSION);
	engfunc(EngFunc_WriteCoord, Origin[0])
	engfunc(EngFunc_WriteCoord, Origin[1])
	engfunc(EngFunc_WriteCoord, Origin[2] + 8.0)
	write_byte(64)
	write_byte(10)
	write_byte(3)
	message_end()

	engfunc(EngFunc_MessageBegin, MSG_PVS, SVC_TEMPENTITY, Origin, 0)
	write_byte(TE_SPARKS);
	engfunc(EngFunc_WriteCoord, Origin[0])
	engfunc(EngFunc_WriteCoord, Origin[1])
	engfunc(EngFunc_WriteCoord, Origin[2])
	message_end();

	// add the shatter
	engfunc(EngFunc_MessageBegin, MSG_PVS, SVC_TEMPENTITY, Origin, 0)
	write_byte(TE_BREAKMODEL);
	engfunc(EngFunc_WriteCoord, Origin[0])
	engfunc(EngFunc_WriteCoord, Origin[1])
	engfunc(EngFunc_WriteCoord, Origin[2] + 24.0)
	engfunc(EngFunc_WriteCoord, 16.0)
	engfunc(EngFunc_WriteCoord, 16.0)
	engfunc(EngFunc_WriteCoord, 16.0)
	write_coord(random_num(-50,50)); // velocity x
	write_coord(random_num(-50,50)); // velocity y
	engfunc(EngFunc_WriteCoord, 25.0)
	write_byte(10); // random velocity
	write_short(g_GlassGib_SprID); // model
	write_byte(25); // count
	write_byte(25); // life
	write_byte(0x01/*BREAK_GLASS*/); // flags
	message_end();
	
	static RGB[3]; FVecIVec(NOVA_COLOR, RGB)
	
	engfunc(EngFunc_MessageBegin, MSG_PVS, SVC_TEMPENTITY, Origin, 0)
	write_byte(TE_BEAMCYLINDER);
	engfunc(EngFunc_WriteCoord, Origin[0])
	engfunc(EngFunc_WriteCoord, Origin[1])
	engfunc(EngFunc_WriteCoord, Origin[2])
	engfunc(EngFunc_WriteCoord, Origin[0])
	engfunc(EngFunc_WriteCoord, Origin[1])
	engfunc(EngFunc_WriteCoord, Origin[2] + 250.0)
	write_short(g_Exp_SprID); // sprite
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
	
	// Sound
	emit_sound(id, CHAN_ITEM, SOUND_RELEASE, VOL_NORM, ATTN_NORM, 0, PITCH_NORM)
	
	// Remove Effect
	if(pev_valid(g_MyNova[id])) set_pev(g_MyNova[id], pev_flags, pev(g_MyNova[id], pev_flags) | FL_KILLME)
}

public client_PreThink(id)
{
	if(!is_alive(id))
		return
	if(Get_BitVar(g_IsFrozen, id))
	{
		static Float:Origin[3]; Origin = g_FrozenOrigin[id]
		Origin[2] += 16.0
		
		engfunc(EngFunc_SetOrigin, id, Origin)
	}
	if(Get_BitVar(g_HitFrostBite, id))
	{
		if(get_gametime() - 2.0 > BiteDelay[id])
		{
			ExecuteHamB(Ham_TakeDamage, id, 0, is_connected(g_Attacker[id]) ? g_Attacker[id] : 0, g_MyDamage[id], DMG_BLAST)
			BiteDelay[id] = get_gametime()
		}
	}
		
	/*static Float:Origin[3]; pev(id, pev_origin, Origin)
	if(get_distance_f(Origin, g_FrozenOrigin[id]) > 8.0)
		HookEnt(id, g_FrozenOrigin[id], 50.0)*/
}

stock HookEnt(Ent, Float:VicOrigin[3], Float:Speed)
{
	static Float:fl_Velocity[3], Float:EntOrigin[3], Float:distance_f, Float:fl_Time
	pev(Ent, pev_origin, EntOrigin)
	
	distance_f = get_distance_f(EntOrigin, VicOrigin)
	fl_Time = distance_f / Speed
		
	fl_Velocity[0] = (VicOrigin[0] - EntOrigin[0]) / fl_Time
	fl_Velocity[1] = (VicOrigin[1] - EntOrigin[1]) / fl_Time
	fl_Velocity[2] = (VicOrigin[2] - EntOrigin[2]) / fl_Time

	set_pev(Ent, pev_velocity, fl_Velocity)
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
	engfunc(EngFunc_WriteCoord, Origin[2] + 750.0)
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
	engfunc(EngFunc_WriteCoord, Origin[2] + 1000.0)
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

public hook_on(id)
{
	if(ZombieEli_GetLevel(id, ZombieEli_GetClass(id)) < 10)
		return PLUGIN_HANDLED
	if(!gAllowedHook[id])
	{
		client_print(id, print_center, "You can hook once per spawn only!")
		return PLUGIN_HANDLED
	}
	
	if(!gIsHooked[id] && is_alive(id))
	{
		RopeAttach(id,1)
	}
	
	return PLUGIN_HANDLED
}

public hook_off(id)
{
	if(!gAllowedHook[id])
		return PLUGIN_HANDLED
	
	if (gIsHooked[id])
	{
		RopeRelease(id)
	}
	
	return PLUGIN_HANDLED
}

public RopeAttach(id,hook)
{
	new parm[1], user_origin[3]
	parm[0] = id
	gIsHooked[id] = true
	get_user_origin(id,user_origin)
	get_user_origin(id,gHookLocation[id], 3)
	gHookLenght[id] = get_distance(gHookLocation[id],user_origin)

	set_user_gravity(id,0.001)
	beamentpoint(id)
	emit_sound(id, CHAN_STATIC, "weapons/xbow_hit2.wav", 1.0, ATTN_NORM, 0, PITCH_NORM)
	if (hook) set_task(DELTA_T, "hooktask", 200+id, parm, 1, "b")
	else set_task(DELTA_T, "ropetask", 200+id, parm, 1, "b")
}

public RopeRelease(id)
{
	gIsHooked[id] = false
	killbeam(id)
	set_user_gravity(id)
	remove_task(200+id)
	
	gAllowedHook[id] = 0
}

public beamentpoint(id)
{
	message_begin( MSG_BROADCAST, SVC_TEMPENTITY )
	write_byte( TE_BEAMENTPOINT )
	write_short( id )
	write_coord( gHookLocation[id][0] )
	write_coord( gHookLocation[id][1] )
	write_coord( gHookLocation[id][2] )
	write_short( beam )	// sprite index
	write_byte( 0 )		// start frame
	write_byte( 0 )		// framerate
	write_byte( BEAMLIFE )	// life
	write_byte( 10 )	// width
	write_byte( 0 )		// noise
	if (get_user_team(id)==1)		// Terrorist
	{
		write_byte( 255 )	// r, g, b
		write_byte( 0 )	// r, g, b
		write_byte( 0 )	// r, g, b
	}
	else							// Counter-Terrorist
	{
		write_byte( 0 )	// r, g, b
		write_byte( 0 )	// r, g, b
		write_byte( 255 )	// r, g, b
	}
	write_byte( 150 )	// brightness
	write_byte( 0 )		// speed
	message_end( )
	gBeamIsCreated[id] = get_gametime()
}

public killbeam(id)
{
	message_begin( MSG_BROADCAST, SVC_TEMPENTITY )
	write_byte( TE_KILLBEAM )
	write_short( id )
	message_end()
}

public hooktask(parm[])
{ 
	new id = parm[0]
	new velocity[3]

	if ( !gIsHooked[id] ) return 
	
	new user_origin[3],oldvelocity[3]
	parm[0] = id

	if (!is_user_alive(id))
	{
		RopeRelease(id)
		return
	}

	if (gBeamIsCreated[id] + BEAMLIFE/10 <= get_gametime())
	{
		beamentpoint(id)
	}

	get_user_origin(id, user_origin) 
	kz_velocity_get(id, oldvelocity) 
	new distance=get_distance( gHookLocation[id], user_origin )
	if ( distance > 10 ) 
	{ 
		velocity[0] = floatround( (gHookLocation[id][0] - user_origin[0]) * ( 2.0 * REELSPEED / distance ) )
		velocity[1] = floatround( (gHookLocation[id][1] - user_origin[1]) * ( 2.0 * REELSPEED / distance ) )
		velocity[2] = floatround( (gHookLocation[id][2] - user_origin[2]) * ( 2.0 * REELSPEED / distance ) )
	} 
	else
	{
		velocity[0]=0
		velocity[1]=0
		velocity[2]=0
	}

	kz_velocity_set(id, velocity) 
	
} 

stock kz_velocity_set(id,vel[3]) {
	//Set Their Velocity to 0 so that they they fall straight down from
	new Float:Ivel[3]
	Ivel[0]=float(vel[0])
	Ivel[1]=float(vel[1])
	Ivel[2]=float(vel[2])
	entity_set_vector(id, EV_VEC_velocity, Ivel)
}

stock kz_velocity_get(id,vel[3]) {
	//Set Their Velocity to 0 so that they they fall straight down from
	new Float:Ivel[3]

	entity_get_vector(id, EV_VEC_velocity, Ivel)
	vel[0]=floatround(Ivel[0])
	vel[1]=floatround(Ivel[1])
	vel[2]=floatround(Ivel[2])
}
