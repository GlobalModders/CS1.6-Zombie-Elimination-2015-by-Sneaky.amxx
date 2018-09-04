#include <amxmodx>
#include <amxmisc>
#include <engine>
#include <fakemeta>
#include <fakemeta_util>
#include <hamsandwich>
#include <zombie_eli>
#include <infinitygame>
#include <cstrike>

#define PLUGIN "[ZD] Zombie Class: BINLADEN"
#define VERSION "1.0"
#define AUTHOR "Dias Pendragon"

#define GAME_FOLDER "zombie_elimination"

#define HEALTH 1500
#define ARMOR 50

#define SETTING_FILE "ZombieClass_Config.ini"
#define LANG_FILE "ZombieElimination.txt"

#define Get_BitVar(%1,%2) (%1 & (1 << (%2 & 31)))
#define Set_BitVar(%1,%2) %1 |= (1 << (%2 & 31))
#define UnSet_BitVar(%1,%2) %1 &= ~(1 << (%2 & 31))

#define HUD_ADRENALINE_X -1.0
#define HUD_ADRENALINE_Y 0.83

#define BAT_MODEL "models/zombie_elimination/bat_witch.mdl"
#define BAT_PULLINGSOUND "zombie_elimination/zombie/banshee/zombi_banshee_laugh.wav" // Spawn
#define BAT_FIRESOUND "zombie_elimination/zombie/banshee/banshee_pulling_fire.wav" // Fly
#define BAT_DEATH "zombie_elimination/zombie/banshee/bat_no.wav" // Death

new g_zombieclass
new zclass_name[16], zclass_desc[32]
new Float:zclass_speed, Float:zclass_gravity
new zclass_model[64], zclass_clawmodel[64]

new g_IsUserAlive, g_BotHamRegister, Float:g_SummonBats[33]
new Float:CheckTime3[33], g_MaxPlayers, m_iBlood[2]
new g_GameStart, g_SkillHud, g_MsgStatusIcon
new g_DemonBats, g_BatHP, g_Pounce
new LeapHigh, LeapSound[64], g_Leaping, g_MyPounce[33], g_TotalPounce[33], Float:Regain[33]

// Auto Skill
#define AUTO_TIME random_float(15.0, 30.0)
#define TASK_AUTO 4965

public plugin_init()
{
	register_plugin(PLUGIN, VERSION, AUTHOR)
	
	register_event("DeathMsg", "Event_Death", "a")
	register_think("bat", "fw_Bat_Think")
	RegisterHam(Ham_Spawn, "player", "fw_PlayerSpawn_Post", 1)
	
	register_forward(FM_EmitSound, "fw_EmitSound")
	register_forward(FM_CmdStart, "fw_CmdStart")
	
	g_SkillHud = CreateHudSyncObj(3)
	g_MaxPlayers = get_maxplayers()
	g_MsgStatusIcon = get_user_msgid("StatusIcon")
	
	register_clcmd("drop", "CMD_Drop")
}

public plugin_precache()
{
	register_dictionary(LANG_FILE)
	
	Load_Class_Setting()
	g_zombieclass = ZombieEli_RegisterClass(zclass_name, HEALTH, ARMOR, zclass_gravity, zclass_speed, zclass_model, zclass_clawmodel, TEAM_ZOMBIE, 0)

	// Skill
	g_DemonBats = ZombieEli_RegisterSkill(g_zombieclass, "Demon Bats", 3)
	g_BatHP = ZombieEli_RegisterSkill(g_zombieclass, "Bat Health", 3)
	g_Pounce = ZombieEli_RegisterSkill(g_zombieclass, "Pounce", 3)
}

native MyName_Is_Binladen(id)
native ComeFrom_Vietnam(id)

public Load_Class_Setting()
{
	static Temp[8]
	
	formatex(zclass_name, sizeof(zclass_name), "%L", LANG_SERVER, "ZOMBIE_CLASS_BINLADEN_NAME")
	formatex(zclass_desc, sizeof(zclass_desc), "%L", LANG_SERVER, "ZOMBIE_CLASS_BINLADEN_DESC")
	
	Setting_Load_String(SETTING_FILE, "Zombie Class", "CLASS_BINLADEN_SPEED", Temp, sizeof(Temp)); zclass_speed = str_to_float(Temp)
	Setting_Load_String(SETTING_FILE, "Zombie Class", "CLASS_BINLADEN_GRAVITY", Temp, sizeof(Temp)); zclass_gravity = str_to_float(Temp)

	Setting_Load_String(SETTING_FILE, "Zombie Class", "CLASS_BINLADEN_MODEL", zclass_model, sizeof(zclass_model))
	Setting_Load_String(SETTING_FILE, "Zombie Class", "CLASS_BINLADEN_CLAWMODEL", zclass_clawmodel, sizeof(zclass_clawmodel))
	
	// Skill
	LeapHigh = Setting_Load_Int(SETTING_FILE, "Zombie Light", "LEAP_HIGH")
	Setting_Load_String(SETTING_FILE, "Zombie Light", "LEAP_SOUND", LeapSound, sizeof(LeapSound))
	
	m_iBlood[0] = precache_model("sprites/blood.spr")
	m_iBlood[1] = precache_model("sprites/bloodspray.spr")	
	
	// Precache 
	precache_model(BAT_MODEL)
	precache_sound(BAT_PULLINGSOUND)
	precache_sound(BAT_FIRESOUND)
	precache_sound(BAT_DEATH)
	
	engfunc(EngFunc_PrecacheSound, LeapSound)
}

public zeli_round_new() remove_entity_name("bat")
public zeli_round_start() g_GameStart = 1
public zeli_round_end() g_GameStart = 0

public zeli_user_spawned(id) Reset_Skill(id)
public zeli_user_infected(id) Reset_Skill(id)

public client_disconnect(id) UnSet_BitVar(g_IsUserAlive, id)
public client_putinserver(id)
{
	if(!g_BotHamRegister && is_user_bot(id))
	{
		g_BotHamRegister = 1
		set_task(0.1, "Bot_RegisterHam", id)
	}

	UnSet_BitVar(g_IsUserAlive, id)
}

public Bot_RegisterHam(id)
{
	RegisterHamFromEntity(Ham_Spawn, id, "fw_PlayerSpawn_Post", 1)
}

public fw_PlayerSpawn_Post(id)
{
	if(!is_user_alive(id))
		return
		
	Set_BitVar(g_IsUserAlive, id)
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

	g_SummonBats[id] = 0.0

	static SP; SP = ZombieEli_GetSP(id, g_Pounce)
	switch(SP)
	{
		case 1: g_TotalPounce[id] = 1
		case 2: g_TotalPounce[id] = 2
		case 3: g_TotalPounce[id] = 3
		default: g_TotalPounce[id] = 0
	}
	
	Off(id, 0)
	Off(id, 1)
	Off(id, 2)
	Off(id, 3)
	
	g_MyPounce[id] = g_TotalPounce[id]
	Update_Hud(id, g_MyPounce[id])
	
	static Level; Level = ZombieEli_GetLevel(id, g_zombieclass)
	if(Level >= 10) MyName_Is_Binladen(id)
}

public zeli_skillup(id, SkillID, NewPoint)
{
	if(SkillID != g_Pounce) return
	
	switch(NewPoint)
	{
		case 1: g_TotalPounce[id] = 1
		case 2: g_TotalPounce[id] = 2
		case 3: g_TotalPounce[id] = 3
		default: g_TotalPounce[id] = 0
	}
}

public zeli_levelup(id, ClassID, NewLevel)
{
	if(ClassID == g_zombieclass && NewLevel >= 10)
		MyName_Is_Binladen(id)
}

public zeli_class_unactive(id, ClassID) 
{
	if(ClassID != g_zombieclass)
		return
		
	Off(id, 0)
	Off(id, 1)
	Off(id, 2)
	Off(id, 3)
		
	Reset_Skill(id)
	ComeFrom_Vietnam(id)
}

public Reset_Skill(id)
{
	UnSet_BitVar(g_Leaping, id)
}

public CMD_Drop(id)
{
	if(!Get_BitVar(g_IsUserAlive, id))
		return PLUGIN_CONTINUE
	if(!ZombieEli_IsZombie(id))
		return PLUGIN_CONTINUE
	if(ZombieEli_GetClass(id) != g_zombieclass)
		return PLUGIN_CONTINUE
	
	static SP; SP = ZombieEli_GetSP(id, g_DemonBats)
	if(SP > 0)
	{
		if((pev(id, pev_flags) & FL_DUCKING) || pev(id, pev_bInDuck) || !(pev(id, pev_flags) & FL_ONGROUND))
			return PLUGIN_HANDLED
		
		static Float:Cooldown
		switch(SP)
		{
			case 1: Cooldown = 60.0
			case 2: Cooldown = 45.0
			case 3: Cooldown = 30.0
			default: Cooldown = 99999.0
		}
		
		if(get_gametime() - Cooldown > g_SummonBats[id])
		{
			Summons_Bats(id)
			g_SummonBats[id] = get_gametime()
		} else {
			client_print(id, print_center, "Remaining time for summoning bats: %i second(s)!", floatround(g_SummonBats[id] - (get_gametime() - Cooldown)))
		}
	} else {
		g_SummonBats[id] = 0.0
		client_print(id, print_center, "Train your 'Demon Bats' skill!")
	}
		
	return PLUGIN_HANDLED
}

public Summons_Bats(id)
{
	ZombieEli_SetFakeAttack(id)
	
	set_weapons_timeidle(id, 1.5)
	set_player_nextattack(id, 1.5)

	set_weapon_anim(id, 1)
	set_pev(id, pev_framerate, 0.35)
	set_pev(id, pev_sequence, 151)
	
	emit_sound(id, CHAN_ITEM, BAT_PULLINGSOUND, VOL_NORM, ATTN_NORM, 0, PITCH_NORM)
	
	// Start Stamping
	set_task(1.0, "Create_Bats", id)
}

public Create_Bats(id)
{
	if(!Get_BitVar(g_IsUserAlive, id))
		return
	if(!ZombieEli_IsZombie(id))
		return
	if(ZombieEli_GetClass(id) != g_zombieclass)
		return
		
	set_weapon_anim(id, 2)
	
	static Bat; Bat = engfunc(EngFunc_CreateNamedEntity, engfunc(EngFunc_AllocString, "info_target"))
	if(!pev_valid(Bat)) return
	
	// Origin & Angles
	static Float:Origin[3]; get_position(id, 64.0, 0.0, 0.0, Origin)
	static Float:Angles[3]; pev(id, pev_v_angle, Angles)
	
	Angles[0] *= -1.0
	
	set_pev(Bat, pev_origin, Origin)
	set_pev(Bat, pev_angles, Angles)
	
	// Set Bat Data
	set_pev(Bat, pev_takedamage, DAMAGE_YES)
	switch(ZombieEli_GetSP(id, g_BatHP))
	{
		case 1: set_pev(Bat, pev_health, 275.0 + 10000.0)
		case 2: set_pev(Bat, pev_health, 350.0 + 10000.0)
		case 3: set_pev(Bat, pev_health, 425.0 + 10000.0)
		default: set_pev(Bat, pev_health, 200.0 + 10000.0)
	} 
	
	set_pev(Bat, pev_classname, "bat")
	engfunc(EngFunc_SetModel, Bat, BAT_MODEL)
	
	set_pev(Bat, pev_movetype, MOVETYPE_BOUNCE)
	set_pev(Bat, pev_solid, SOLID_SLIDEBOX)
	set_pev(Bat, pev_gamestate, 1)
	
	set_pev(Bat, pev_gravity, 0.1)
	
	static Float:mins[3]; mins[0] = -26.0; mins[1] = -26.0; mins[2] = -10.0
	static Float:maxs[3]; maxs[0] = 26.0; maxs[1] = 26.0; maxs[2] = 10.0
	engfunc(EngFunc_SetSize, Bat, mins, maxs)
	
	// Set State
	set_pev(Bat, pev_iuser1, id)
	set_pev(Bat, pev_nextthink, get_gametime() + 0.1)
	
	// Anim
	Set_Entity_Anim(Bat, 0)
	
	// Set Next Think
	set_pev(Bat, pev_nextthink, get_gametime() + 0.1)
	
	// Set Speed
	static Float:TargetOrigin[3], Float:Velocity[3]
	get_position(id, 4000.0, 0.0, 0.0, TargetOrigin)
	Get_SpeedVector(Origin, TargetOrigin, 240.0, Velocity)
	
	emit_sound(Bat, CHAN_WEAPON, BAT_FIRESOUND, VOL_NORM, ATTN_NORM, 0, PITCH_NORM)
	
	set_pev(Bat, pev_velocity, Velocity)
}

public fw_Bat_Think(Ent)
{
	if(!pev_valid(Ent)) return
	if((pev(Ent, pev_health) - 10000.0) <= 0.0)
	{
		static Float:Origin[3]; pev(Ent, pev_origin, Origin)
		
		emit_sound(Ent, CHAN_BODY, BAT_DEATH, VOL_NORM, ATTN_NORM, 0, PITCH_NORM)
		
		set_pev(Ent, pev_nextthink, get_gametime() + 0.1)
		set_pev(Ent, pev_flags, FL_KILLME)
		
		return
	}
	
	static id; id = pev(Ent, pev_iuser1)
	
	if(!is_user_alive(id))
	{
		set_pev(Ent, pev_nextthink, get_gametime() + 0.1)
		set_pev(Ent, pev_flags, FL_KILLME)
		
		return
	}

	static Enemy; 
	Enemy = FindClosetEnemy(Ent, 1)
	if(!is_user_alive(Enemy)) Enemy = pev(Ent, pev_enemy)
	static Float:EnemyOrigin[3]
	
	if(is_user_alive(Enemy))
	{
		pev(Enemy, pev_origin, EnemyOrigin)
		if(entity_range(Enemy, Ent) <= 60.0)
		{
			Aim_To2(Ent, EnemyOrigin) 
			static Float:Angles[3]; pev(Ent, pev_angles, Angles)
			Angles[1] -= 45.0
			set_pev(Ent, pev_angles, Angles)
			set_pev(Ent, pev_velocity, {0.0, 0.0, 0.0})
			
			static Float:Time; pev(Ent, pev_fuser3, Time)
			if(get_gametime() - 0.5 > Time)
			{
				ExecuteHamB(Ham_TakeDamage, Enemy, 0, id, 10.0, DMG_BULLET)
				
				EnemyOrigin[2] += 16.0
				create_blood(EnemyOrigin)
				
				set_pev(Ent, pev_fuser3, get_gametime())
			}
		} else {
			Aim_To2(Ent, EnemyOrigin) 
			hook_ent2(Ent, EnemyOrigin, 300.0)
			
			Set_EntAnim(Ent, 0, 1.0, 0)
		}
	} else {
		static Float:Vel[3], Float:Length; pev(Ent, pev_velocity, Vel)
		Length = vector_length(Vel)
		
		if(!Length)
		{
			Vel[0] = random_float(250.0, -250.0)
			Vel[1] = random_float(250.0, -250.0)

			set_pev(Ent, pev_velocity, Vel)
		}
	}
	
	set_pev(Ent, pev_nextthink, get_gametime() + 0.1)
}

public fw_CmdStart(id, UCHandle, Seed)
{
	if(!Get_BitVar(g_IsUserAlive, id))
		return
	if(!ZombieEli_IsZombie(id))
		return
	if(ZombieEli_GetClass(id) != g_zombieclass)
		return	
		
	if(get_gametime() - 5.0 > Regain[id])
	{
		if(g_MyPounce[id] < g_TotalPounce[id])
		{
			g_MyPounce[id]++
			
			Update_Hud(id, g_MyPounce[id])
			
			Regain[id] = get_gametime()
		}
	}
	
	if(get_gametime() - 1.0 > CheckTime3[id])
	{
		if(ZombieEli_GetLevel(id, g_zombieclass) >= 10)
		{
			static Hud[128]
			formatex(Hud, sizeof(Hud), "Ultimate Skill: Dragon Claw Hook", Hud)
				
			set_hudmessage(200, 200, 200, HUD_ADRENALINE_X, HUD_ADRENALINE_Y - 0.02, 0, 1.1, 1.1, 0.0, 0.0)
			ShowSyncHudMsg(id, g_SkillHud, Hud)
		}
		
		CheckTime3[id] = get_gametime()
	}	
	
	static CurButton; CurButton = get_uc(UCHandle, UC_Buttons)
	
	if((CurButton & IN_ATTACK2))
	{
		if((pev(id, pev_flags) & FL_DUCKING) || pev(id, pev_bInDuck) || !(pev(id, pev_flags) & FL_ONGROUND))
			return
		if(get_pdata_float(id, 83, 5) > 0.0)
			return
		if(g_MyPounce[id] <= 0)
			return
			
		g_MyPounce[id]--
		Update_Hud(id, g_MyPounce[id])
		
		Active_Leap(id)
	} 
}

public Update_Hud(id, New)
{
	Off(id, 0)
	Off(id, 1)
	Off(id, 2)
	Off(id, 3)
	
	static AmmoSprites[33]
	format(AmmoSprites, sizeof(AmmoSprites), "number_%d", New)
	
	message_begin(MSG_ONE_UNRELIABLE, g_MsgStatusIcon, {0,0,0}, id)
	write_byte(1)
	write_string(AmmoSprites)
	write_byte(42) // red
	write_byte(212) // green
	write_byte(255) // blue
	message_end()
}

public Off(id, Num)
{
	static AmmoSprites[33]
	format(AmmoSprites, sizeof(AmmoSprites), "number_%d", Num)
	
	message_begin(MSG_ONE_UNRELIABLE, g_MsgStatusIcon, {0,0,0}, id)
	write_byte(0)
	write_string(AmmoSprites)
	write_byte(42) // red
	write_byte(212) // green
	write_byte(255) // blue
	message_end()
}

public client_PostThink(id)
{
	if(!Get_BitVar(g_IsUserAlive, id))
		return
	if(!Get_BitVar(g_Leaping, id))
		return
	if(!ZombieEli_IsZombie(id))
		return
		
	static Float:flFallVelocity; flFallVelocity = get_pdata_float(id, 251, 5)
        
	if(flFallVelocity && pev(id, pev_flags) & FL_ONGROUND)
	{
		Set_WeaponAnim(id, 0)
		UnSet_BitVar(g_Leaping, id)
	}
}

public Active_Leap(id)
{
	static Float:Origin1[3], Float:Origin2[3]
	pev(id, pev_origin, Origin1)

	Set_BitVar(g_Leaping, id)
	
	ZombieEli_SetFakeAttack(id)
	
	// Climb Action
	Set_WeaponAnim(id, 2)
	set_pev(id, pev_sequence, 152)
	
	set_pdata_float(id, 83, 1.0, 5)
	
	get_position(id, 180.0, 0.0, 650.0, Origin2)
	static Float:Velocity[3]; Get_SpeedVector(Origin1, Origin2, float(LeapHigh), Velocity)
	
	set_pev(id, pev_velocity, Velocity)
	emit_sound(id, CHAN_STATIC, LeapSound, 1.0, ATTN_NORM, 0, PITCH_NORM)
}

stock set_weapon_anim(id, anim)
{
	set_pev(id, pev_weaponanim, anim)
	
	message_begin(MSG_ONE_UNRELIABLE, SVC_WEAPONANIM, _, id)
	write_byte(anim)
	write_byte(0)
	message_end()	
}

stock set_weapons_timeidle(id, Float:TimeIdle)
{
	static Ent; Ent = fm_get_user_weapon_entity(id, CSW_KNIFE)
	if(pev_valid(Ent)) set_pdata_float(Ent, 48, TimeIdle, 4)
}

stock set_player_nextattack(id, Float:nexttime)
{
	set_pdata_float(id, 83, nexttime, 5)
}

stock Set_Entity_Anim(Ent, Anim)
{
	set_pev(Ent, pev_animtime, get_gametime())
	set_pev(Ent, pev_sequence, Anim)
	set_pev(Ent, pev_framerate, 1.0)
	set_pev(Ent, pev_frame, 0.0)
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
	
	angle_vector(vAngle,ANGLEVECTOR_FORWARD, vForward) //or use EngFunc_AngleVectors
	angle_vector(vAngle,ANGLEVECTOR_RIGHT, vRight)
	angle_vector(vAngle,ANGLEVECTOR_UP, vUp)
	
	vStart[0] = vOrigin[0] + vForward[0] * forw + vRight[0] * right + vUp[0] * up
	vStart[1] = vOrigin[1] + vForward[1] * forw + vRight[1] * right + vUp[1] * up
	vStart[2] = vOrigin[2] + vForward[2] * forw + vRight[2] * right + vUp[2] * up
}
/* AMXX-Studio Notes - DO NOT MODIFY BELOW HERE
*{\\ rtf1\\ ansi\\ deff0{\\ fonttbl{\\ f0\\ fnil Tahoma;}}\n\\ viewkind4\\ uc1\\ pard\\ lang1042\\ f0\\ fs16 \n\\ par }
*/
