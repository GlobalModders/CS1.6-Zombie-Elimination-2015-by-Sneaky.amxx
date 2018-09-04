#include <amxmodx>
#include <amxmisc>
#include <engine>
#include <fakemeta>
#include <fakemeta_util>
#include <hamsandwich>
#include <zombie_eli>
#include <infinitygame>
#include <cstrike>

#define PLUGIN "[ZELI] Zombie Class: Night Stalker"
#define VERSION "1.0"
#define AUTHOR "Dias Pendragon"

#define GAME_FOLDER "zombie_elimination"
#define SETTING_FILE "ZombieClass_Config.ini"
#define LANG_FILE "ZombieElimination.txt"

#define HEALTH 5000
#define ARMOR 200

#define HUD_ADRENALINE_X -1.0
#define HUD_ADRENALINE_Y 0.83

#define Get_BitVar(%1,%2) (%1 & (1 << (%2 & 31)))
#define Set_BitVar(%1,%2) %1 |= (1 << (%2 & 31))
#define UnSet_BitVar(%1,%2) %1 &= ~(1 << (%2 & 31))

#define TIME_INTERVAL 0.25
#define TASK_CHECKTIME 3125365

// Loaded Vars
new g_zombieclass, g_ClawA
new zclass_name[16], zclass_desc[32]
new Float:zclass_speed, Float:zclass_gravity
new zclass_model[16], zclass_clawmodel[32]

new g_ClassSpeed, g_ClawModel[64]
new Float:g_InvisibleTime, g_InvisibleClawModel[64]
new g_BerserkSpeed, Float:g_BerserkDefense, g_BerserkDecPer015S, Array:g_BerserkSound
new g_DashPower, g_DashJump, g_DashDashing, g_DashSound[64]

new g_GameStart = 1, g_IsUserBot, g_BotHamRegister, g_IsUserAlive
new Float:CheckTime[33], Float:CheckTime2[33], Float:CheckTime3[33], g_SkillHud
new g_Dash, g_BerserkInv, g_PowerRegen

new g_Sprinting, g_PlayerKey[33][2], g_MsgScreenFade, g_InvisiblePercent[33]
new g_Dashing, g_OneTime

// Ultimate
#define DETECT_RANGE 640.0
#define GHOST_HEALTH 200.0
#define GHOST_CLASSNAME "ghost2"
#define EFFECT_CLASSNAME "deathgod"

#define GHOST_MODEL "models/zombie_elimination/Ghost.mdl"
#define AURA_MODEL "models/zombie_elimination/Aura.mdl"

new const GhostVoice[2][] = 
{
	"zombie_elimination/near_zombie_base.wav",
	"zombie_elimination/ghost/imhere.wav"
}
new const GhostPain[2][] =
{
	"zombie_elimination/bullet_hit1.wav",
	"zombie_elimination/bullet_hit2.wav"
}
new const GhostDeath[] = "zombie_elimination/ghost/nc_death3.wav"
new const GhostAttack[] = "zombie_elimination/zombie/zombi_attack_1.wav"

new g_MaxPlayers, g_RegHam, m_iBlood[2]

public plugin_init()
{
	register_plugin(PLUGIN, VERSION, AUTHOR)
	
	register_event("DeathMsg", "Event_Death", "a")
	register_forward(FM_CmdStart, "fw_CmdStart")
	register_forward(FM_EmitSound, "fw_EmitSound")
	RegisterHam(Ham_Spawn, "player", "fw_PlayerSpawn_Post", 1)
	RegisterHam(Ham_TakeDamage, "player", "fw_TakeDamage")	
	
	g_MsgScreenFade = get_user_msgid("ScreenFade")
	g_SkillHud = CreateHudSyncObj(3)
	
	register_think(GHOST_CLASSNAME, "fw_Ghost_Think")
	
	g_MaxPlayers = get_maxplayers()
	
	// CMD
	register_clcmd("drop", "CMD_Drop")
}

public plugin_precache()
{
	register_dictionary(LANG_FILE)
	g_BerserkSound = ArrayCreate(64, 1)
	
	Load_ClassConfig()
	g_zombieclass = ZombieEli_RegisterClass(zclass_name, HEALTH, ARMOR, zclass_gravity, zclass_speed, zclass_model, zclass_clawmodel, TEAM_ZOMBIE, 0)

	// Skill
	g_Dash = ZombieEli_RegisterSkill(g_zombieclass, "Dashing", 3)
	g_BerserkInv = ZombieEli_RegisterSkill(g_zombieclass, "Berserk Invisibility", 3)
	g_PowerRegen = ZombieEli_RegisterSkill(g_zombieclass, "Power Regeneration", 3)
	
	// Ghost
	precache_model(GHOST_MODEL)
	precache_model(AURA_MODEL)
	
	for(new i = 0; i < sizeof(GhostVoice); i++)
		precache_sound(GhostVoice[i])
	for(new i = 0; i < sizeof(GhostPain); i++)
		precache_sound(GhostPain[i])
	precache_sound(GhostDeath)
	precache_sound(GhostAttack)
	
	m_iBlood[0] = precache_model("sprites/blood.spr")
	m_iBlood[1] = precache_model("sprites/bloodspray.spr")	
}

public Load_ClassConfig()
{
	static Buffer[64], Temp[32]
	
	formatex(zclass_name, sizeof(zclass_name), "%L", LANG_PLAYER, "ZOMBIE_CLASS_NIGHTSTALKER_NAME")
	formatex(zclass_desc, sizeof(zclass_desc), "%L", LANG_PLAYER, "ZOMBIE_CLASS_NIGHTSTALKER_DESC")
	
	Setting_Load_String(SETTING_FILE, "Zombie Class", "CLASS_NIGHTSTALKER_SPEED", Temp, sizeof(Temp)); zclass_speed = str_to_float(Temp)
	Setting_Load_String(SETTING_FILE, "Zombie Class", "CLASS_NIGHTSTALKER_GRAVITY", Temp, sizeof(Temp)); zclass_gravity = str_to_float(Temp)

	Setting_Load_String(SETTING_FILE, "Zombie Class", "CLASS_NIGHTSTALKER_MODEL", zclass_model, sizeof(zclass_model))
	Setting_Load_String(SETTING_FILE, "Zombie Class", "CLASS_NIGHTSTALKER_CLAWMODEL", zclass_clawmodel, sizeof(zclass_clawmodel))
	
	/// SKill
	Setting_Load_String(SETTING_FILE, "Night Stalker", "INVISIBLE_TIME", Buffer, sizeof(Buffer)); g_InvisibleTime = str_to_float(Buffer)
	g_ClassSpeed = Setting_Load_Int(SETTING_FILE, "Zombie Class", "CLASS_NIGHTSTALKER_SPEED")
	Setting_Load_String(SETTING_FILE, "Zombie Class", "CLASS_NIGHTSTALKER_CLAWMODEL", g_ClawModel, sizeof(g_ClawModel))
	Setting_Load_String(SETTING_FILE, "Night Stalker", "INVISIBLE_CLAWMODEL", g_InvisibleClawModel, sizeof(g_InvisibleClawModel))
	engfunc(EngFunc_PrecacheModel, g_InvisibleClawModel)

	g_BerserkSpeed = Setting_Load_Int(SETTING_FILE, "Night Stalker", "BERSERK_SPEED")
	Setting_Load_String(SETTING_FILE, "Night Stalker", "BERSERK_DEFENSE", Buffer, sizeof(Buffer)); g_BerserkDefense = str_to_float(Buffer)
	g_BerserkDecPer015S = Setting_Load_Int(SETTING_FILE, "Night Stalker", "BERSERK_DECREASE_PER015SEC")
	Setting_Load_StringArray(SETTING_FILE, "Night Stalker", "BERSERK_SOUND", g_BerserkSound)
	for(new i = 0; i < ArraySize(g_BerserkSound); i++)
	{
		ArrayGetString(g_BerserkSound, i, Buffer, sizeof(Buffer))
		engfunc(EngFunc_PrecacheSound, Buffer)
	}
	
	g_DashPower = Setting_Load_Int(SETTING_FILE, "Night Stalker", "DASH_POWER")
	g_DashJump = Setting_Load_Int(SETTING_FILE, "Night Stalker", "DASH_JUMP")
	g_DashDashing = Setting_Load_Int(SETTING_FILE, "Night Stalker", "DASH_DASHING")
	Setting_Load_String(SETTING_FILE, "Night Stalker", "DASH_SOUND", g_DashSound, sizeof(g_DashSound))
	engfunc(EngFunc_PrecacheSound, g_DashSound)
}


public zeli_round_new()
{
	remove_entity_name(GHOST_CLASSNAME)
}

public zeli_round_start() g_GameStart = 1
public zeli_round_end() g_GameStart = 0

public zeli_user_spawned(id) Reset_Skill(id)
public zeli_user_infected(id) Reset_Skill(id)

public client_disconnect(id) UnSet_BitVar(g_IsUserAlive, id)
public client_putinserver(id)
{
	UnSet_BitVar(g_IsUserBot, id)
	if(!g_BotHamRegister && is_user_bot(id))
	{
		g_BotHamRegister = 1
		set_task(0.1, "Bot_RegisterHam", id)
	}
	
	if(is_user_bot(id)) Set_BitVar(g_IsUserBot, id)
	
	UnSet_BitVar(g_IsUserAlive, id)
}

public Bot_RegisterHam(id)
{
	RegisterHamFromEntity(Ham_Spawn, id, "fw_PlayerSpawn_Post", 1)
}

public CMD_Drop(id)
{
	if(!is_user_alive(id))
		return PLUGIN_CONTINUE
	if(!ZombieEli_IsZombie(id))
		return PLUGIN_CONTINUE
	if(ZombieEli_GetClass(id) != g_zombieclass)
		return PLUGIN_CONTINUE
	if(!Get_BitVar(g_OneTime, id))
		return PLUGIN_CONTINUE
		
	if(ZombieEli_GetLevel(id, ZombieEli_GetClass(id)) >= 10)
	{
		UnSet_BitVar(g_OneTime, id)
		
		static Float:Mine[3], Float:Origin[3], Float:Vel[3]
		
		pev(id, pev_origin, Mine)
		
		// Forward
		get_position(id, 100.0, 0.0, 0.0, Origin)
		Get_SpeedVector(Mine, Origin, 15.0, Vel)
		
		Create_Ghost(id, Vel, Origin)
		
		// Back
		get_position(id, -100.0, 0.0, 0.0, Origin)
		Get_SpeedVector(Mine, Origin, 15.0, Vel)
		
		Create_Ghost(id, Vel, Origin)
		
		// Left
		get_position(id, 0.0, -100.0, 0.0, Origin)
		Get_SpeedVector(Mine, Origin, 15.0, Vel)
		
		Create_Ghost(id, Vel, Origin)
		
		// Right
		get_position(id, 0.0, 100.0, 0.0, Origin)
		Get_SpeedVector(Mine, Origin, 15.0, Vel)
		
		Create_Ghost(id, Vel, Origin)
		
		// Sound
		emit_sound(id, CHAN_ITEM, GhostVoice[random_num(0, sizeof(GhostVoice) - 1)], VOL_NORM, ATTN_NORM, 0, PITCH_NORM)
		
		// Client Print
		client_print(id, print_center, "Kuchiyose no Justsu: Ghost!")
	}
		
	return PLUGIN_HANDLED
}

public fw_PlayerSpawn_Post(id)
{
	if(!is_user_alive(id))
		return
		
	Set_BitVar(g_IsUserAlive, id)
}

public fw_TakeDamage(Victim, Inflictor, Attacker, Float:Damage, DamageBits)
{
	if(!g_GameStart)
		return HAM_IGNORED
	if(zd_get_user_zombieclass(Victim) != g_zombieclass)
		return HAM_IGNORED
	if(!Get_BitVar(g_Sprinting, Victim))
		return HAM_IGNORED
		
	Damage /= g_BerserkDefense
	SetHamParamFloat(4, Damage)
		
	return HAM_HANDLED
}

public Event_Death()
{
	static Victim; Victim = read_data(2); UnSet_BitVar(g_IsUserAlive, Victim)
}

public zeli_class_active(id, ClassID)
{
	if(ClassID != g_zombieclass)
		return
		
	Reset_Skill(id)
	
	// Check 
	static SP; SP = ZombieEli_GetSP(id, g_PowerRegen)
	switch(SP)
	{
		case 1: ZombieEli_SetPowerTime(id, 0.4, 0)
		case 2: ZombieEli_SetPowerTime(id, 0.3, 0)
		case 3: ZombieEli_SetPowerTime(id, 0.25, 0)
		default: ZombieEli_SetPowerTime(id, 0.5, 1)
	}
	
	if(ZombieEli_GetLevel(id, ZombieEli_GetClass(id)) >= 10)
		Set_BitVar(g_OneTime, id)
}

public zeli_skillup(id, SkillID, NewPoint)
{
	if(SkillID == g_PowerRegen)
	{
		switch(NewPoint)
		{
			case 1: ZombieEli_SetPowerTime(id, 0.4, 0)
			case 2: ZombieEli_SetPowerTime(id, 0.3, 0)
			case 3: ZombieEli_SetPowerTime(id, 0.25, 0)
			default: ZombieEli_SetPowerTime(id, 0.5, 1)
		}
	}
}

public zeli_levelup(id, ClassID, NewLevel)
{
	if(ClassID == g_zombieclass && NewLevel >= 10)
		Set_BitVar(g_OneTime, id)
}

public zeli_class_unactive(id, ClassID) 
{
	if(ClassID != g_zombieclass)
		return
		
	Reset_Skill(id)
}

public Reset_Skill(id)
{
	UnSet_BitVar(g_Sprinting, id)
	UnSet_BitVar(g_Dashing, id)
	UnSet_BitVar(g_OneTime, id)
	g_InvisiblePercent[id] = 0
	
	Reset_Key(id)
}

public client_PreThink(id)
{
	if(!Get_BitVar(g_IsUserAlive, id))
		return
		
	static CurButton; CurButton = pev(id, pev_button)
	static OldButton; OldButton = pev(id, pev_oldbuttons)
	
	if((CurButton & IN_FORWARD)) 
	{
		if(!g_GameStart)
			return 
		if(!zd_get_user_zombie(id))
			return
		if(zd_get_user_zombieclass(id) != g_zombieclass)
			return
		
		static Float:STime; 
		static SP; SP = ZombieEli_GetSP(id, g_BerserkInv)
		
		switch(SP)
		{
			case 1: STime = 0.20
			case 2: STime = 0.25
			case 3: STime = 0.30
			default: STime = 0.15
		}
			
		if(Get_BitVar(g_Sprinting, id) && (get_gametime() - STime > CheckTime[id]))
		{
			if(zd_get_user_power(id) <= 0)
			{
				Deactive_SprintSkill(id)
				return
			}
			if((pev(id, pev_flags) & FL_DUCKING) || pev(id, pev_bInDuck) || !(pev(id, pev_flags) & FL_ONGROUND))
			{
				Deactive_SprintSkill(id)
				return
			}
			
			static Float:RenderAmt; pev(id, pev_renderamt, RenderAmt)
			if(RenderAmt > 0) 
			{
				RenderAmt -= ((255.0 / g_InvisibleTime) * STime)
				if(RenderAmt < 0.0) 
				{
					RenderAmt = 0.0
					set_pev(id, pev_viewmodel2, g_InvisibleClawModel)
				}
				
				g_InvisiblePercent[id] = floatround(((255.0 - RenderAmt) / 255.0) * 100.0)
				set_pev(id, pev_renderamt, RenderAmt)
			}
			
			// Handle Other
			zd_set_user_power(id, zd_get_user_power(id) - g_BerserkDecPer015S)
			
			CheckTime[id] = get_gametime()
		}	
			
		if(Get_BitVar(g_Sprinting, id) && (get_gametime() - 0.5 > CheckTime2[id]))
		{
			zd_set_fakeattack(id)
			Set_WeaponAnim(id, 10)
			
			set_pev(id, pev_framerate, 2.0)
			set_pev(id, pev_sequence, 110)
			
			// Play Sound
			static Sound[64]; ArrayGetString(g_BerserkSound, Get_RandomArray(g_BerserkSound), Sound, sizeof(Sound))
			emit_sound(id, CHAN_VOICE, Sound, 1.0, ATTN_NORM, 0, PITCH_NORM)
			
			CheckTime2[id] = get_gametime()
		}
		
		if(OldButton & IN_FORWARD)
			return
		
		if(!task_exists(id+TASK_CHECKTIME))
		{
			g_PlayerKey[id][0] = 'w'
			
			remove_task(id+TASK_CHECKTIME)
			set_task(TIME_INTERVAL, "Recheck_Key", id+TASK_CHECKTIME)
		} else {
			g_PlayerKey[id][1] = 'w'
		}
	} else {
		if(OldButton & IN_FORWARD)
		{
			Deactive_SprintSkill(id)
		}
		
		return
	}
	
	if(equali(g_PlayerKey[id], "ww"))
	{
		Reset_Key(id)
		Active_SprintSkill(id)
	}

	return
}

public fw_CmdStart(id, UCHandle, Seed)
{
	if(!Get_BitVar(g_IsUserAlive, id))
		return
	if(Get_BitVar(g_IsUserBot, id))
		return
	if(!zd_get_user_zombie(id))
		return
	if(zd_get_user_zombieclass(id) != g_zombieclass)
		return

	static CurButton; CurButton = get_uc(UCHandle, UC_Buttons)
	
	if(get_gametime() - 1.0 > CheckTime3[id])
	{
		static SP; SP = ZombieEli_GetSP(id, g_Dash)
		static Reduce;
		switch(SP)
		{
			case 1: Reduce = 2
			case 2: Reduce = 5
			case 3: Reduce = 10
			default: Reduce = 0
		}
		
		static Power; Power = g_DashPower - Reduce
		
		static Time; Time = zd_get_user_power(id) / Power
		static Hud[128], SkillName[32]; 
		static Level; Level = ZombieEli_GetLevel(id, g_zombieclass)
		
		formatex(SkillName, sizeof(SkillName), "%L", LANG_PLAYER, "ZOMBIE_CLASS_NIGHTSTALKER_SKILL")
		formatex(Hud, sizeof(Hud), "%L", LANG_PLAYER, "HUD_ZOMBIESKILL_INV", g_InvisiblePercent[id])
		
		if(Time >= 1) formatex(Hud, sizeof(Hud), "%s^n%L", Hud, LANG_PLAYER, "HUD_ZOMBIESKILL", SkillName, Time)
	
		if(Level >= 10)
		{
			formatex(Hud, sizeof(Hud), "%s^nUltimate Skill: Undead Allies (Active - [G])", Hud)
			
			set_hudmessage(200, 200, 200, HUD_ADRENALINE_X, HUD_ADRENALINE_Y - 0.06, 0, 1.1, 1.1, 0.0, 0.0)
			ShowSyncHudMsg(id, g_SkillHud, Hud)
		} else {
			set_hudmessage(200, 200, 200, HUD_ADRENALINE_X, HUD_ADRENALINE_Y - 0.04, 0, 1.1, 1.1, 0.0, 0.0)
			ShowSyncHudMsg(id, g_SkillHud, Hud)
		}
		
		CheckTime3[id] = get_gametime()
	}	
	
	if((CurButton & IN_ATTACK2))
	{
		CurButton &= ~IN_ATTACK2
		set_uc(UCHandle, UC_Buttons, CurButton)

		if(!g_GameStart)
		{
			set_pdata_float(id, 83, 0.5, 5)
			return 	
		}
		if(Get_BitVar(g_Sprinting, id))
		{
			set_pdata_float(id, 83, 0.5, 5)
			return
		}
		
		static SP; SP = ZombieEli_GetSP(id, g_Dash)
		static Reduce;
		switch(SP)
		{
			case 1: Reduce = 2
			case 2: Reduce = 5
			case 3: Reduce = 10
			default: Reduce = 0
		}
		
		static Power; Power = g_DashPower - Reduce
		
		if(zd_get_user_power(id) < Power)
		{
			set_pdata_float(id, 83, 0.5, 5)
			return
		}
		if((pev(id, pev_flags) & FL_DUCKING) || pev(id, pev_bInDuck))
		{
			set_pdata_float(id, 83, 0.5, 5)
			return
		}
		if(get_pdata_float(id, 83, 5) > 0.0)
			return
			
		set_pdata_float(id, 83, 0.5, 5)
		Handle_Dashing(id, Power)
	}
}

public Handle_Dashing(id, Power)
{
	if((pev(id, pev_flags) & FL_ONGROUND)) // On Ground
	{
		static Float:Origin1[3], Float:Origin2[3]
		pev(id, pev_origin, Origin1)
	
		Set_BitVar(g_Dashing, id)
		
		zd_set_user_power(id, zd_get_user_power(id) - Power)
		zd_set_fakeattack(id)
		
		// Climb Action
		Set_WeaponAnim(id, 6)
		set_pev(id, pev_framerate, 0.5)
		set_pev(id, pev_sequence, 112)
		
		set_pdata_float(id, 83, 0.5, 5)
		
		get_position(id, 0.0, 0.0, 200.0, Origin2)
		static Float:Velocity[3]; Get_SpeedVector(Origin1, Origin2, float(g_DashJump), Velocity)
		
		set_pev(id, pev_velocity, Velocity)
		emit_sound(id, CHAN_STATIC, g_DashSound, 1.0, ATTN_NORM, 0, PITCH_NORM)
	} else { // In Air
		static Float:Origin1[3], Float:Origin2[3]
		pev(id, pev_origin, Origin1)
	
		Set_BitVar(g_Dashing, id)
		
		zd_set_user_power(id, zd_get_user_power(id) - Power)
		zd_set_fakeattack(id)
		
		// Climb Action
		Set_WeaponAnim(id, 6)
		set_pev(id, pev_framerate, 0.5)
		set_pev(id, pev_sequence, 112)
		
		set_pdata_float(id, 83, 0.5, 5)
		
		get_position(id, 250.0, 0.0, 60.0, Origin2)
		static Float:Velocity[3]; Get_SpeedVector(Origin1, Origin2, float(g_DashDashing), Velocity)
		
		set_pev(id, pev_velocity, Velocity)
		emit_sound(id, CHAN_STATIC, g_DashSound, 1.0, ATTN_NORM, 0, PITCH_NORM)
	}
}

// Emit Sound Forward
public fw_EmitSound(id, channel, const sample[], Float:volume, Float:attn, flags, pitch)
{
	if (sample[0] == 'h' && sample[1] == 'o' && sample[2] == 's' && sample[3] == 't' && sample[4] == 'a' && sample[5] == 'g' && sample[6] == 'e')
		return FMRES_SUPERCEDE;
	if(ZombieEli_IsZombie(id) && ZombieEli_GetClass(id) == g_zombieclass)
	{
		// Zombie attacks with knife
		if (sample[8] == 'k' && sample[9] == 'n' && sample[10] == 'i')
		{
			if (sample[14] == 's' && sample[15] == 'l' && sample[16] == 'a') // slash
			{
				if(!Get_BitVar(g_ClawA, id))
				{
					Set_WeaponAnim(id, 1)
					Set_BitVar(g_ClawA, id)
				} else {
					Set_WeaponAnim(id, 2)
					UnSet_BitVar(g_ClawA, id)
				}
			}
			if (sample[14] == 'h' && sample[15] == 'i' && sample[16] == 't') // hit
			{
				if (sample[17] == 'w') // wall
				{
					if(!Get_BitVar(g_ClawA, id))
					{
						Set_WeaponAnim(id, 1)
						Set_BitVar(g_ClawA, id)
					} else {
						Set_WeaponAnim(id, 2)
						UnSet_BitVar(g_ClawA, id)
					}
				} else {
					if(!Get_BitVar(g_ClawA, id))
					{
						Set_WeaponAnim(id, 1)
						Set_BitVar(g_ClawA, id)
					} else {
						Set_WeaponAnim(id, 2)
						UnSet_BitVar(g_ClawA, id)
					}
				}
			}
			
		}
	}

	return FMRES_IGNORED;
}

public client_PostThink(id)
{
	if(!Get_BitVar(g_IsUserAlive, id))
		return
	if(!Get_BitVar(g_Dashing, id))
		return
	if(!zd_get_user_zombie(id))
		return
	if(zd_get_user_zombieclass(id) != g_zombieclass)
		return
			
	static Float:flFallVelocity; flFallVelocity = get_pdata_float(id, 251, 5)
        
	if(flFallVelocity && pev(id, pev_flags) & FL_ONGROUND)
	{
		zd_set_fakeattack(id)
		
		set_pev(id, pev_framerate, 2.0)
		set_pev(id, pev_sequence, 113)
		Set_WeaponAnim(id, 7)

		UnSet_BitVar(g_Dashing, id)
	}
}

public Active_SprintSkill(id)
{
	Set_BitVar(g_Sprinting, id)
	CheckTime2[id] = get_gametime()
	
	zd_set_fakeattack(id)
	set_pev(id, pev_framerate, 2.0)
	set_pev(id, pev_sequence, 110)
	
	Set_WeaponAnim(id, 9)
	IG_SpeedSet(id, float(g_BerserkSpeed), 1)

	// ScreenFade
	message_begin(MSG_ONE_UNRELIABLE, g_MsgScreenFade, _, id)
	write_short(0) // duration
	write_short(0) // hold time
	write_short(0x0004) // fade type
	write_byte(255) // r
	write_byte(0) // g
	write_byte(0) // b
	write_byte(35) // alpha
	message_end()
	
	set_pev(id, pev_rendermode, kRenderTransAlpha)
	set_pev(id, pev_renderfx, kRenderFxNone)
	set_pev(id, pev_renderamt, 255.0)	
}

public Deactive_SprintSkill(id)
{
	if(!Get_BitVar(g_Sprinting, id))
		return
	
	UnSet_BitVar(g_Sprinting, id)
	g_InvisiblePercent[id] = 0
	
	// Reset
	message_begin(MSG_ONE_UNRELIABLE, g_MsgScreenFade, _, id)
	write_short(0) // duration
	write_short(0) // hold time
	write_short(0x0000) // fade type
	write_byte(0) // r
	write_byte(0) // g
	write_byte(0) // b
	write_byte(0) // alpha
	message_end()
	
	// Speed
	
	// Reset Claw
	set_pev(id, pev_rendermode, kRenderNormal)
	Set_WeaponAnim(id, 11)
	IG_SpeedSet(id, float(g_ClassSpeed), 1)
	
	static ClawModel[64]; formatex(ClawModel, sizeof(ClawModel), "models/%s/claw/%s", GAME_FOLDER, g_ClawModel)
	set_pev(id, pev_viewmodel2, ClawModel)
}

public Reset_Key(id)
{
	g_PlayerKey[id][0] = 0
	g_PlayerKey[id][1] = 0
}

public Recheck_Key(id)
{
	id -= TASK_CHECKTIME
	
	if(!is_user_connected(id))
		return
		
	Reset_Key(id)
}

public zd_user_nvg(id, On, Zombie)
{
	if(!Zombie) return
	if(!Get_BitVar(g_Sprinting, id))
		return
	
	if(!On)
	{
		// ScreenFade
		message_begin(MSG_ONE_UNRELIABLE, g_MsgScreenFade, _, id)
		write_short(0) // duration
		write_short(0) // hold time
		write_short(0x0004) // fade type
		write_byte(255) // r
		write_byte(0) // g
		write_byte(0) // b
		write_byte(35) // alpha
		message_end()
	}
}

stock Setting_Load_Int(const filename[], const setting_section[], setting_key[])
{
	if (strlen(filename) < 1)
	{
		log_error(AMX_ERR_NATIVE, "[ZD] Can't load settings: empty filename")
		return false;
	}
	
	if (strlen(setting_section) < 1 || strlen(setting_key) < 1)
	{
		log_error(AMX_ERR_NATIVE, "[ZD] Can't load settings: empty section/key")
		return false;
	}
	
	// Build customization file path
	new path[128]
	get_configsdir(path, charsmax(path))
	format(path, charsmax(path), "%s/ZombieElimination/%s", path, filename)
	
	// File not present
	if (!file_exists(path))
	{
		static DataA[128]; formatex(DataA, sizeof(DataA), "[ZD] Can't load: %s", path)
		set_fail_state(DataA)
		
		return false;
	}
	
	// Open customization file for reading
	new file = fopen(path, "rt")
	
	// File can't be opened
	if (!file)
		return false;
	
	// Set up some vars to hold parsing info
	new linedata[1024], section[64]
	
	// Seek to setting's section
	while (!feof(file))
	{
		// Read one line at a time
		fgets(file, linedata, charsmax(linedata))
		
		// Replace newlines with a null character to prevent headaches
		replace(linedata, charsmax(linedata), "^n", "")
		
		// New section starting
		if (linedata[0] == '[')
		{
			// Store section name without braces
			copyc(section, charsmax(section), linedata[1], ']')
			
			// Is this our setting's section?
			if (equal(section, setting_section))
				break;
		}
	}
	
	// Section not found
	if (!equal(section, setting_section))
	{
		fclose(file)
		return false;
	}
	
	// Set up some vars to hold parsing info
	new key[64], current_value[32]
	
	// Seek to setting's key
	while (!feof(file))
	{
		// Read one line at a time
		fgets(file, linedata, charsmax(linedata))
		
		// Replace newlines with a null character to prevent headaches
		replace(linedata, charsmax(linedata), "^n", "")
		
		// Blank line or comment
		if (!linedata[0] || linedata[0] == ';') continue;
		
		// Section ended?
		if (linedata[0] == '[')
			break;
		
		// Get key and value
		strtok(linedata, key, charsmax(key), current_value, charsmax(current_value), '=')
		
		// Trim spaces
		trim(key)
		trim(current_value)
		
		// Is this our setting's key?
		if (equal(key, setting_key))
		{
			static return_value
			// Return int by reference
			return_value = str_to_num(current_value)
			
			// Values succesfully retrieved
			fclose(file)
			return return_value
		}
	}
	
	// Key not found
	fclose(file)
	return false;
}

stock Setting_Load_StringArray(const filename[], const setting_section[], setting_key[], Array:array_handle)
{
	if (strlen(filename) < 1)
	{
		log_error(AMX_ERR_NATIVE, "[ZD] Can't load settings: empty filename")
		return false;
	}

	if (strlen(setting_section) < 1 || strlen(setting_key) < 1)
	{
		log_error(AMX_ERR_NATIVE, "[ZD] Can't load settings: empty section/key")
		return false;
	}
	
	if (array_handle == Invalid_Array)
	{
		log_error(AMX_ERR_NATIVE, "[ZD] Array not initialized")
		return false;
	}
	
	// Build customization file path
	new path[128]
	get_configsdir(path, charsmax(path))
	format(path, charsmax(path), "%s/ZombieElimination/%s", path, filename)
	
	// File not present
	if (!file_exists(path))
	{
		static DataA[80]; formatex(DataA, sizeof(DataA), "[ZD] Can't load: %s", path)
		set_fail_state(DataA)
		
		return false;
	}
	
	// Open customization file for reading
	new file = fopen(path, "rt")
	
	// File can't be opened
	if (!file)
		return false;
	
	// Set up some vars to hold parsing info
	new linedata[1024], section[64]
	
	// Seek to setting's section
	while (!feof(file))
	{
		// Read one line at a time
		fgets(file, linedata, charsmax(linedata))
		
		// Replace newlines with a null character to prevent headaches
		replace(linedata, charsmax(linedata), "^n", "")
		
		// New section starting
		if (linedata[0] == '[')
		{
			// Store section name without braces
			copyc(section, charsmax(section), linedata[1], ']')
			
			// Is this our setting's section?
			if (equal(section, setting_section))
				break;
		}
	}
	
	// Section not found
	if (!equal(section, setting_section))
	{
		fclose(file)
		return false;
	}
	
	// Set up some vars to hold parsing info
	new key[64], values[1024], current_value[128]
	
	// Seek to setting's key
	while (!feof(file))
	{
		// Read one line at a time
		fgets(file, linedata, charsmax(linedata))
		
		// Replace newlines with a null character to prevent headaches
		replace(linedata, charsmax(linedata), "^n", "")
		
		// Blank line or comment
		if (!linedata[0] || linedata[0] == ';') continue;
		
		// Section ended?
		if (linedata[0] == '[')
			break;
		
		// Get key and values
		strtok(linedata, key, charsmax(key), values, charsmax(values), '=')
		
		// Trim spaces
		trim(key)
		trim(values)
		
		// Is this our setting's key?
		if (equal(key, setting_key))
		{
			// Parse values
			while (values[0] != 0 && strtok(values, current_value, charsmax(current_value), values, charsmax(values), ','))
			{
				// Trim spaces
				trim(current_value)
				trim(values)
				
				// Add to array
				ArrayPushString(array_handle, current_value)
			}
			
			// Values succesfully retrieved
			fclose(file)
			return true;
		}
	}
	
	// Key not found
	fclose(file)
	return false;
}

stock Setting_Load_String(const filename[], const setting_section[], setting_key[], return_string[], string_size)
{
	if (strlen(filename) < 1)
	{
		log_error(AMX_ERR_NATIVE, "[ZD] Can't load settings: empty filename")
		return false;
	}

	if (strlen(setting_section) < 1 || strlen(setting_key) < 1)
	{
		log_error(AMX_ERR_NATIVE, "[ZD] Can't load settings: empty section/key")
		return false;
	}
	
	// Build customization file path
	new path[128]
	get_configsdir(path, charsmax(path))
	format(path, charsmax(path), "%s/ZombieElimination/%s", path, filename)
	
	// File not present
	if (!file_exists(path))
	{
		static DataA[128]; formatex(DataA, sizeof(DataA), "[ZD] Can't load: %s", path)
		set_fail_state(DataA)
		
		return false;
	}
	
	// Open customization file for reading
	new file = fopen(path, "rt")
	
	// File can't be opened
	if (!file)
		return false;
	
	// Set up some vars to hold parsing info
	new linedata[1024], section[64]
	
	// Seek to setting's section
	while (!feof(file))
	{
		// Read one line at a time
		fgets(file, linedata, charsmax(linedata))
		
		// Replace newlines with a null character to prevent headaches
		replace(linedata, charsmax(linedata), "^n", "")
		
		// New section starting
		if (linedata[0] == '[')
		{
			// Store section name without braces
			copyc(section, charsmax(section), linedata[1], ']')
			
			// Is this our setting's section?
			if (equal(section, setting_section))
				break;
		}
	}
	
	// Section not found
	if (!equal(section, setting_section))
	{
		fclose(file)
		return false;
	}
	
	// Set up some vars to hold parsing info
	new key[64], current_value[128]
	
	// Seek to setting's key
	while (!feof(file))
	{
		// Read one line at a time
		fgets(file, linedata, charsmax(linedata))
		
		// Replace newlines with a null character to prevent headaches
		replace(linedata, charsmax(linedata), "^n", "")
		
		// Blank line or comment
		if (!linedata[0] || linedata[0] == ';') continue;
		
		// Section ended?
		if (linedata[0] == '[')
			break;
		
		// Get key and value
		strtok(linedata, key, charsmax(key), current_value, charsmax(current_value), '=')
		
		// Trim spaces
		trim(key)
		trim(current_value)
		
		// Is this our setting's key?
		if (equal(key, setting_key))
		{
			formatex(return_string, string_size, "%s", current_value)
			
			// Values succesfully retrieved
			fclose(file)
			return true;
		}
	}
	
	// Key not found
	fclose(file)
	return false;
}

stock Set_WeaponAnim(id, anim)
{
	set_pev(id, pev_weaponanim, anim)
	
	message_begin(MSG_ONE_UNRELIABLE, SVC_WEAPONANIM, _, id)
	write_byte(anim)
	write_byte(0)
	message_end()	
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

stock get_position(id,Float:forw, Float:right, Float:up, Float:vStart[])
{
	static Float:vOrigin[3], Float:vAngle[3], Float:vForward[3], Float:vRight[3], Float:vUp[3]
	
	pev(id, pev_origin, vOrigin)
	pev(id, pev_view_ofs, vUp) //for player
	xs_vec_add(vOrigin, vUp, vOrigin)
	pev(id, pev_v_angle, vAngle) // if normal entity ,use pev_angles
	
	vAngle[0] = 0.0
	
	angle_vector(vAngle,ANGLEVECTOR_FORWARD, vForward) //or use EngFunc_AngleVectors
	angle_vector(vAngle,ANGLEVECTOR_RIGHT, vRight)
	angle_vector(vAngle,ANGLEVECTOR_UP, vUp)
	
	vStart[0] = vOrigin[0] + vForward[0] * forw + vRight[0] * right + vUp[0] * up
	vStart[1] = vOrigin[1] + vForward[1] * forw + vRight[1] * right + vUp[1] * up
	vStart[2] = vOrigin[2] + vForward[2] * forw + vRight[2] * right + vUp[2] * up
}

stock Get_RandomArray(Array:ArrayName)
{
	return random_num(0, ArraySize(ArrayName) - 1)
}

stock FixedUnsigned16(Float:flValue, iScale)
{
	new iOutput;

	iOutput = floatround(flValue * iScale);

	if ( iOutput < 0 )
		iOutput = 0;

	if ( iOutput > 0xFFFF )
		iOutput = 0xFFFF;

	return iOutput;
}

public zd_get_user_zombie(id)
{
	return ZombieEli_IsZombie(id)
}

public zd_get_user_zombieclass(id)
{
	return ZombieEli_GetClass(id)
}

public zd_get_user_power(id)
{
	return ZombieEli_PowerGet(id)
}

public zd_set_user_power(id, Power)
{
	ZombieEli_PowerSet(id, Power)
}

public zd_set_fakeattack(id) ZombieEli_SetFakeAttack(id)

// GhostAttack
public Create_Ghost(id, Float:Velocity[3], Float:Target[3])
{
	static Ent; Ent = engfunc(EngFunc_CreateNamedEntity, engfunc(EngFunc_AllocString, "info_target"))
	if(!pev_valid(Ent)) return -1

	// Set Origin & Angles
	static Float:Origin[3]; 
	pev(id, pev_origin, Origin); Origin[2] += 6.0
	set_pev(Ent, pev_origin, Origin)

	// Set Config
	set_pev(Ent, pev_classname, GHOST_CLASSNAME)
	engfunc(EngFunc_SetModel, Ent, GHOST_MODEL)
	set_pev(Ent, pev_modelindex, engfunc(EngFunc_ModelIndex, GHOST_MODEL))
		
	set_pev(Ent, pev_gamestate, 1)
	set_pev(Ent, pev_solid, SOLID_TRIGGER)
	set_pev(Ent, pev_movetype, MOVETYPE_NOCLIP)
	
	// Set Size
	new Float:maxs[3] = {16.0, 16.0, 36.0}
	new Float:mins[3] = {-16.0, -16.0, -36.0}
	engfunc(EngFunc_SetSize, Ent, mins, maxs)
	
	// Set Life
	set_pev(Ent, pev_takedamage, DAMAGE_YES)
	set_pev(Ent, pev_health, 10000.0 + GHOST_HEALTH)
	
	// Set Config 2
	Set_EntAnim(Ent, 0, 1.0, 1)
	set_pev(Ent, pev_nextthink, get_gametime() + 1.0)
	set_pev(Ent, pev_velocity, Velocity)
	set_pev(Ent, pev_owner, id)
	
	//
	Aim_To2(Ent, Target)
	
	if(!g_RegHam)
	{
		g_RegHam = 1
		RegisterHamFromEntity(Ham_TraceAttack, Ent, "fw_Ghost_TraceAttack")
	}

	return Ent
}

public fw_Ghost_TraceAttack(Ent, Attacker, Float:Damage, Float:Dir[3], ptr, DamageType)
{
	if(!is_valid_ent(Ent)) 
		return HAM_IGNORED
     
	static Classname[32]
	pev(Ent, pev_classname, Classname, charsmax(Classname)) 
	     
	if(!equal(Classname, GHOST_CLASSNAME)) 
		return HAM_IGNORED
		 
	static Float:EndPos[3] 
	get_tr2(ptr, TR_vecEndPos, EndPos)

	create_blood(EndPos)
	emit_sound(Ent, CHAN_BODY, GhostPain[random_num(0, sizeof(GhostPain) -1)], VOL_NORM, ATTN_NORM, 0, PITCH_NORM)
	
	return HAM_IGNORED
}

public fw_Ghost_Think(Ent)
{
	if(!pev_valid(Ent)) return
	
	if((pev(Ent, pev_health) - 10000.0) <= 0.0)
	{
		static Float:Origin[3]; pev(Ent, pev_origin, Origin)
		static Float:Vel[3]
		Send_EffectModel(Origin, Vel, AURA_MODEL, 0.5, 0)
		
		emit_sound(Ent, CHAN_BODY, GhostDeath, VOL_NORM, ATTN_NORM, 0, PITCH_NORM)
		
		set_pev(Ent, pev_nextthink, get_gametime() + 0.1)
		set_pev(Ent, pev_flags, FL_KILLME)
		
		return
	}
	
	static id; id = pev(Ent, pev_owner)
	
	if(!is_user_alive(id))
	{
		static Float:Origin[3]; pev(Ent, pev_origin, Origin)
		static Float:Vel[3]
		Send_EffectModel(Origin, Vel, AURA_MODEL, 0.5, 0)
		
		set_pev(Ent, pev_nextthink, get_gametime() + 0.1)
		set_pev(Ent, pev_flags, FL_KILLME)
		
		return
	}
	if(entity_range(id, Ent) >= 60.0 && pev(Ent, pev_solid) != SOLID_SLIDEBOX)
		set_pev(Ent, pev_solid, SOLID_SLIDEBOX)

	static Enemy; 
	Enemy = FindClosetEnemy(Ent, 1)
	if(!is_user_alive(Enemy)) Enemy = pev(Ent, pev_enemy)
	static Float:EnemyOrigin[3]
	
	if(is_user_alive(Enemy))
	{
		if(entity_range(id, Enemy) > DETECT_RANGE)
		{
			if(entity_range(id, Ent) > 60.0)
			{
				pev(id, pev_origin, EnemyOrigin)
				Aim_To2(Ent, EnemyOrigin) 
				hook_ent2(Ent, EnemyOrigin, 200.0)
				
				Set_EntAnim(Ent, 0, 1.0, 0)
				set_pev(Ent, pev_nextthink, get_gametime() + 0.1)
				
				return
			}
		}
		
		pev(Enemy, pev_origin, EnemyOrigin)
		if(entity_range(Enemy, Ent) <= 60.0)
		{
			Aim_To2(Ent, EnemyOrigin) 
			static Float:Angles[3]; pev(Ent, pev_angles, Angles)
			Angles[1] -= 45.0
			set_pev(Ent, pev_angles, Angles)
			set_pev(Ent, pev_velocity, {0.0, 0.0, 0.0})
			
			static Float:Time; pev(Ent, pev_fuser3, Time)
			if(get_gametime() - 1.5 > Time)
			{
				Set_EntAnim(Ent, 76, 1.0, 1)
				
				ExecuteHam(Ham_TakeDamage, Enemy, 0, id, 10.0, DMG_BULLET)
				emit_sound(Ent, CHAN_WEAPON, GhostAttack, VOL_NORM, ATTN_NORM, 0, PITCH_NORM)
				
				EnemyOrigin[2] += 16.0
				create_blood(EnemyOrigin)
				set_pev(Ent, pev_fuser3, get_gametime())
			}
		} else {
			Aim_To2(Ent, EnemyOrigin) 
			hook_ent2(Ent, EnemyOrigin, 150.0)
			
			Set_EntAnim(Ent, 0, 1.0, 0)
		}
	} else {
		if(entity_range(id, Ent) > 60.0)
		{
			pev(id, pev_origin, EnemyOrigin)
			Aim_To2(Ent, EnemyOrigin) 
			hook_ent2(Ent, EnemyOrigin, 75.0)
			
			Set_EntAnim(Ent, 0, 1.0, 0)
			set_pev(Ent, pev_nextthink, get_gametime() + 0.1)
			
			return
		}
	}
	
	set_pev(Ent, pev_nextthink, get_gametime() + 0.1)
}

public Aim_To2(iEnt, Float:vTargetOrigin[3])
{
	if(!pev_valid(iEnt))	
		return
		
	static Float:Vec[3], Float:Angles[3]
	pev(iEnt, pev_origin, Vec)
	
	Vec[0] = vTargetOrigin[0] - Vec[0]
	Vec[1] = vTargetOrigin[1] - Vec[1]
	Vec[2] = vTargetOrigin[2] - Vec[2]
	engfunc(EngFunc_VecToAngles, Vec, Angles)
	//Angles[0] = Angles[2] = 0.0 
	
	set_pev(iEnt, pev_v_angle, Angles)
	set_pev(iEnt, pev_angles, Angles)
}

stock PlaySound(id, const sound[])
{
	if(equal(sound[strlen(sound)-4], ".mp3")) client_cmd(id, "mp3 play ^"sound/%s^"", sound)
	else client_cmd(id, "spk ^"%s^"", sound)
}

public Set_EntAnim(ent, anim, Float:framerate, resetframe)
{
	if(!pev_valid(ent))
		return
	
	if(!resetframe)
	{
		if(pev(ent, pev_sequence) != anim)
		{
			set_pev(ent, pev_animtime, get_gametime())
			set_pev(ent, pev_framerate, framerate)
			set_pev(ent, pev_sequence, anim)
		}
	} else {
		set_pev(ent, pev_animtime, get_gametime())
		set_pev(ent, pev_framerate, framerate)
		set_pev(ent, pev_sequence, anim)
	}
}

stock hook_ent2(ent, Float:VicOrigin[3], Float:speed)
{
	if(!pev_valid(ent))
		return
	
	static Float:fl_Velocity[3], Float:EntOrigin[3], Float:distance_f, Float:fl_Time
	
	pev(ent, pev_origin, EntOrigin)
	
	distance_f = get_distance_f(EntOrigin, VicOrigin)
	fl_Time = distance_f / speed
		
	fl_Velocity[0] = (VicOrigin[0] - EntOrigin[0]) / fl_Time
	fl_Velocity[1] = (VicOrigin[1] - EntOrigin[1]) / fl_Time
	fl_Velocity[2] = (VicOrigin[2] - EntOrigin[2]) / fl_Time

	set_pev(ent, pev_velocity, fl_Velocity)
}

stock Send_EffectModel(Float:Origin[3], Float:Velocity[3], const Model[], Float:Time, Anim)
{
	static Ent; Ent = create_entity("info_target")
	if(!pev_valid(Ent)) return 
	
	// Set Properties
	set_pev(Ent, pev_takedamage, DAMAGE_NO)
	set_pev(Ent, pev_solid, SOLID_NOT)
	set_pev(Ent, pev_movetype, MOVETYPE_FLY)
	
	// Set Sprite
	set_pev(Ent, pev_classname, EFFECT_CLASSNAME)
	engfunc(EngFunc_SetModel, Ent, Model)
	
	// Set Rendering
	set_pev(Ent, pev_renderfx, kRenderFxNone)
	set_pev(Ent, pev_rendermode, kRenderTransAdd)
	set_pev(Ent, pev_renderamt, 255.0)
	
	// Set other & Origin
	engfunc(EngFunc_SetOrigin, Ent, Origin)
	set_pev(Ent, pev_velocity, Velocity)
	
	// Animation
	set_pev(Ent, pev_animtime, get_gametime())
	set_pev(Ent, pev_framerate, 1.0)
	set_pev(Ent, pev_sequence, Anim)
		
	// Force Think
	set_pev(Ent, pev_nextthink, get_gametime() + Time)
}

stock create_blood(const Float:origin[3])
{
	// Show some blood :)
	message_begin(MSG_BROADCAST, SVC_TEMPENTITY) 
	write_byte(TE_BLOODSPRITE)
	engfunc(EngFunc_WriteCoord, origin[0])
	engfunc(EngFunc_WriteCoord, origin[1])
	engfunc(EngFunc_WriteCoord, origin[2])
	write_short(m_iBlood[1])
	write_short(m_iBlood[0])
	write_byte(75)
	write_byte(5)
	message_end()
}

public FindClosetEnemy(ent, can_see)
{
	new Float:maxdistance = 4980.0
	new indexid = 0	
	new Float:current_dis = maxdistance

	for(new i = 1 ;i <= g_MaxPlayers; i++)
	{
		if(can_see)
		{
			if(is_user_alive(i) && cs_get_user_team(i) == CS_TEAM_CT && can_see_fm(ent, i) && entity_range(ent, i) < current_dis)
			{
				current_dis = entity_range(ent, i)
				indexid = i
			}
		} else {
			if(is_user_alive(i) && cs_get_user_team(i) == CS_TEAM_CT && entity_range(ent, i) < current_dis)
			{
				current_dis = entity_range(ent, i)
				indexid = i
			}			
		}
	}	
	
	return indexid
}

public bool:can_see_fm(entindex1, entindex2)
{
	if (!entindex1 || !entindex2)
		return false

	if (pev_valid(entindex1) && pev_valid(entindex1))
	{
		new flags = pev(entindex1, pev_flags)
		if (flags & EF_NODRAW || flags & FL_NOTARGET)
		{
			return false
		}

		new Float:lookerOrig[3]
		new Float:targetBaseOrig[3]
		new Float:targetOrig[3]
		new Float:temp[3]

		pev(entindex1, pev_origin, lookerOrig)
		pev(entindex1, pev_view_ofs, temp)
		lookerOrig[0] += temp[0]
		lookerOrig[1] += temp[1]
		lookerOrig[2] += temp[2]

		pev(entindex2, pev_origin, targetBaseOrig)
		pev(entindex2, pev_view_ofs, temp)
		targetOrig[0] = targetBaseOrig [0] + temp[0]
		targetOrig[1] = targetBaseOrig [1] + temp[1]
		targetOrig[2] = targetBaseOrig [2] + temp[2]

		engfunc(EngFunc_TraceLine, lookerOrig, targetOrig, 0, entindex1, 0) //  checks the had of seen player
		if (get_tr2(0, TraceResult:TR_InOpen) && get_tr2(0, TraceResult:TR_InWater))
		{
			return false
		} 
		else 
		{
			new Float:flFraction
			get_tr2(0, TraceResult:TR_flFraction, flFraction)
			if (flFraction == 1.0 || (get_tr2(0, TraceResult:TR_pHit) == entindex2))
			{
				return true
			}
			else
			{
				targetOrig[0] = targetBaseOrig [0]
				targetOrig[1] = targetBaseOrig [1]
				targetOrig[2] = targetBaseOrig [2]
				engfunc(EngFunc_TraceLine, lookerOrig, targetOrig, 0, entindex1, 0) //  checks the body of seen player
				get_tr2(0, TraceResult:TR_flFraction, flFraction)
				if (flFraction == 1.0 || (get_tr2(0, TraceResult:TR_pHit) == entindex2))
				{
					return true
				}
				else
				{
					targetOrig[0] = targetBaseOrig [0]
					targetOrig[1] = targetBaseOrig [1]
					targetOrig[2] = targetBaseOrig [2] - 17.0
					engfunc(EngFunc_TraceLine, lookerOrig, targetOrig, 0, entindex1, 0) //  checks the legs of seen player
					get_tr2(0, TraceResult:TR_flFraction, flFraction)
					if (flFraction == 1.0 || (get_tr2(0, TraceResult:TR_pHit) == entindex2))
					{
						return true
					}
				}
			}
		}
	}
	return false
}
