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

#define PLUGIN "[ZELI] H-Class: Medic"
#define VERSION "1.0"
#define AUTHOR "Dias Pendragon Leon"

// Class Setting
#define CLASS_NAME "Medic"
#define CLASS_MODEL "zeli_hm_medic"
#define CLASS_CLAWMODEL ""
#define CLASS_TEAM TEAM_HUMAN

const CLASS_HEALTH = 100
const CLASS_ARMOR = 100
const Float:CLASS_GRAVITY = 1.0
const Float:CLASS_SPEED = 250.0

new const HealSound[] = "zombie_elimination/heal.wav"
new const HealSprite[] = "sprites/zombie_elimination/heal.spr"

new g_Medic
new g_HealAmount, g_HealRate, g_Regen
new g_Casting, g_MsgBarTime, g_HealSprID, Float:RegenTime[33], Float:TeamHealTime[33], g_MaxPlayers

#define TASK_CASTING 64934

// MACROS
#define Get_BitVar(%1,%2) (%1 & (1 << (%2 & 31)))
#define Set_BitVar(%1,%2) %1 |= (1 << (%2 & 31))
#define UnSet_BitVar(%1,%2) %1 &= ~(1 << (%2 & 31))

// Safety
new g_HamBot
new g_IsConnected, g_IsAlive, g_PlayerWeapon[33]

public plugin_init()
{
	register_plugin(PLUGIN, VERSION, AUTHOR)
	
	Register_SafetyFunc()
	register_forward(FM_CmdStart, "fw_CmdStart")
	RegisterHam(Ham_TraceAttack, "player", "fw_PlayerTraceAttack")
	
	g_MsgBarTime = get_user_msgid("BarTime2")
	g_MaxPlayers = get_maxplayers()
	
	register_clcmd("drop", "CMD_Drop")
}

public plugin_precache()
{
	// Register Class
	g_Medic = ZombieEli_RegisterClass(CLASS_NAME, CLASS_HEALTH, CLASS_ARMOR, CLASS_GRAVITY, CLASS_SPEED, CLASS_MODEL, CLASS_CLAWMODEL, CLASS_TEAM, 0)

	
	precache_model("models/player/zeli_hm_medic/zeli_hm_medicT.mdl")
	// Skill
	g_HealAmount = ZombieEli_RegisterSkill(g_Medic, "Heal Amount", 3)
	g_HealRate = ZombieEli_RegisterSkill(g_Medic, "Heal Rate", 3)
	g_Regen = ZombieEli_RegisterSkill(g_Medic, "Regeneration", 3)
	
	// Precache
	precache_sound(HealSound)
	g_HealSprID = precache_model(HealSprite)
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
	RegisterHamFromEntity(Ham_TraceAttack, id, "fw_PlayerTraceAttack")
}

public client_disconnect(id)
{
	Safety_Disconnected(id)
}

public zeli_user_spawned(id, ClassID)
{
	UnSet_BitVar(g_Casting, id)
	remove_task(id+TASK_CASTING)
}

public zeli_class_active(id, ClassID)
{
	if(ClassID != g_Medic)
		return
		
	TeamHealTime[id] = get_gametime() - 60.0
}

public zeli_class_unactive(id, ClassID)
{
	UnSet_BitVar(g_Casting, id)
	remove_task(id+TASK_CASTING)
}

public zeli_user_infected(id, ClassID)
{
	
}

public zeli_levelup(id, ClassID, NewLevel)
{
	if(ClassID != g_Medic)
		return
	if(NewLevel == 10)
	{
		IG_ClientPrintColor(id, "!gYou reached Lv.10!n -> !tPress [G] to heal your close teammates!!n")
	}
}

public fw_CmdStart(id, uc_handle, seed)
{
	if(!is_alive(id))
		return
	if(ZombieEli_IsZombie(id))
		return
	if(ZombieEli_GetClass(id) != g_Medic)
		return
	if(get_gametime() - 5.0 > RegenTime[id])
	{
		if(get_user_health(id) < CLASS_HEALTH)
		{
			static Amount, SP; SP = ZombieEli_GetSP(id, g_Regen)
			if(!SP)
			{
				RegenTime[id] = get_gametime()
				return
			}
			
			switch(SP)
			{
				case 1: Amount = 10
				case 2: Amount = 20
				case 3: Amount = 30
				default: Amount = 0
			}
			
			static NewHealth; NewHealth = min(CLASS_HEALTH, get_user_health(id) + Amount)
			
			set_user_health(id, NewHealth)
			IG_PlayerAttachment(id, HealSprite, 1.5, 1.0, 10.0)
			
			PlaySound(id, HealSound)
		}
		
		RegenTime[id] = get_gametime()
	}
	
	if(Get_BitVar(g_Casting, id))
	{
		static Float:Vel[3]; pev(id, pev_velocity, Vel)
		if(vector_length(Vel)) 
		{
			UnSet_BitVar(g_Casting, id)
			remove_task(id+TASK_CASTING)
			
			message_begin(MSG_ONE_UNRELIABLE, g_MsgBarTime, _, id)
			write_short(0) 
			write_short(0)
			message_end()
				
			return
		}
	}
		
	static New, Old;
	New = get_uc(uc_handle, UC_Buttons)
	Old = pev(id, pev_oldbuttons)
	
	if(New & IN_USE)
	{
		static Ent; Ent = ZombieEli_GetBaseEnt(TEAM_HUMAN)
		if(!pev_valid(Ent)) return 
		static Req; Req = ZombieEli_GetSP(id, g_HealAmount)
		static Float:Radius; Radius = entity_range(id, Ent)
		
		if(Radius > 75.0) client_print(id, print_center, "You must touch the base to heal it!")
		else {
			if(Req > 0)
			{
				if(!Get_BitVar(g_Casting, id))
				{
					const HealTime = 3; // do not modify
					
					Set_BitVar(g_Casting, id)
					static Faster, SP
					
					// Faster
					SP = ZombieEli_GetSP(id, g_HealRate)
					switch(SP)
					{
						case 1: Faster = 5
						case 2: Faster = 10
						case 3: Faster = 20
						default: Faster = 0
					}
					
					static Float:CastTime; CastTime = (float(HealTime) * float(100 - Faster)) / 100.0
					static Float:StartPercent; StartPercent = (CastTime / float(HealTime)) * 100
					
					message_begin(MSG_ONE_UNRELIABLE, g_MsgBarTime, _, id)
					write_short(HealTime) 
					write_short(100 - floatround(StartPercent))
					message_end()
					
					remove_task(id+TASK_CASTING)
					set_task(CastTime, "Cast_Magic", id+TASK_CASTING)
				}
			} else {
				if(!(Old & IN_USE))
				{
					client_print(id, print_center, "You need to train your [Heal Amount] skill to use this!")
				}
			}
		}
	} else {
		if(!(New & IN_USE) && (Old & IN_USE))
		{
			if(Get_BitVar(g_Casting, id))
			{
				UnSet_BitVar(g_Casting, id)
				remove_task(id+TASK_CASTING)
				
				message_begin(MSG_ONE_UNRELIABLE, g_MsgBarTime, _, id)
				write_short(0) 
				write_short(0)
				message_end()
			}
		}
	}
}

public CMD_Drop(id)
{
	if(!is_alive(id))
		return PLUGIN_CONTINUE
	if(ZombieEli_IsZombie(id))
		return PLUGIN_CONTINUE
	if(ZombieEli_GetClass(id) != g_Medic)
		return PLUGIN_CONTINUE
	if(ZombieEli_GetLevel(id, ZombieEli_GetClass(id)) < 10)
		return PLUGIN_HANDLED
		
	if(get_gametime() - 60.0 > TeamHealTime[id])
	{
		const Float:Radius = 200.0
		static MaxHealth, NewHealth; 
		
		for(new i = 0; i < g_MaxPlayers; i++)
		{
			if(!is_alive(i))
				continue
			if(ZombieEli_IsZombie(i))
				continue
			if(entity_range(i, id) > Radius)
				continue
			
			MaxHealth = ZombieEli_GetMaxHP(i)
			if(get_user_health(i) < MaxHealth)
			{
				NewHealth = min(MaxHealth, get_user_health(i) + 100)
				set_user_health(i, NewHealth)
				
				IG_PlayerAttachment(i, HealSprite, 1.5, 0.75, 10.0)
				PlaySound(i, HealSound)
			}
		}
		
		TeamHealTime[id] = get_gametime()
	} else {
		client_print(id, print_center, "Remaining time for healing team: %i second(s)!", floatround(TeamHealTime[id] - (get_gametime() - 60.0)))
	}
		
	return PLUGIN_HANDLED
}

public fw_PlayerTraceAttack(Victim, Attacker, Float:Damage, Float:Direction[3], Trace, DamageBits)
{
	if(!is_alive(Attacker))
		return HAM_IGNORED
	if(ZombieEli_IsZombie(Attacker) || ZombieEli_GetClass(Attacker) != g_Medic)
		return HAM_IGNORED
	if(get_user_team(Victim) == get_user_team(Attacker))
		return HAM_IGNORED
		
	RegenTime[Attacker] = get_gametime() + 10.0
		
	return HAM_HANDLED
}

public Cast_Magic(id)
{
	id -= TASK_CASTING
	
	if(!is_alive(id))
		return
	if(ZombieEli_IsZombie(id))
		return
	if(ZombieEli_GetClass(id) != g_Medic)
		return
		
	ZombieEli_GainExp(id, 5, 1)
	emit_sound(id, CHAN_ITEM, HealSound, VOL_NORM, ATTN_NORM, 0, PITCH_NORM)

	static Health, SP;
	SP = ZombieEli_GetSP(id, g_HealAmount)
	
	switch(SP)
	{
		case 1: Health = 20
		case 2: Health = 30
		case 3: Health = 40
		default: Health = 0
	}
	
	ZombieEli_GainBaseHealth(TEAM_HUMAN, Health)
	
	// Effect
	static Ent; Ent = ZombieEli_GetBaseEnt(TEAM_HUMAN)
	if(!pev_valid(Ent)) return
	
	set_task(0.1, "Effect_Heal", Ent)
	set_task(1.5, "Remove_Effect", Ent)
}

public Effect_Heal(Ent)
{
	if(!pev_valid(Ent))
		return
	
	static Float:originF[3]
	pev(Ent, pev_origin, originF)
	
	engfunc(EngFunc_MessageBegin, MSG_PVS, SVC_TEMPENTITY, originF, 0)
	write_byte(TE_SPRITE)
	engfunc(EngFunc_WriteCoord, originF[0] + random_float(-36.0, 36.0))
	engfunc(EngFunc_WriteCoord, originF[1] + random_float(-36.0, 36.0))
	engfunc(EngFunc_WriteCoord, originF[2] + 50.0)
	write_short(g_HealSprID)
	write_byte(random_num(5, 10))
	write_byte(200)
	message_end()
	
	set_task(0.25, "Effect_Heal", Ent)
}

public Remove_Effect(Ent)
{
	if(!pev_valid(Ent))
		return
		
	remove_task(Ent)
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

stock PlaySound(id, const sound[])
{
	if(equal(sound[strlen(sound)-4], ".mp3")) client_cmd(id, "mp3 play ^"sound/%s^"", sound)
	else client_cmd(id, "spk ^"%s^"", sound)
}
/* AMXX-Studio Notes - DO NOT MODIFY BELOW HERE
*{\\ rtf1\\ ansi\\ deff0{\\ fonttbl{\\ f0\\ fnil Tahoma;}}\n\\ viewkind4\\ uc1\\ pard\\ lang3076\\ f0\\ fs16 \n\\ par }
*/
