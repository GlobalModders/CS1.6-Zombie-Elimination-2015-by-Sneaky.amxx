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

#define PLUGIN "[ZELI] H-Class: Sun HongKong"
#define VERSION "1.0"
#define AUTHOR "Sneaky.amxx"

// Class Setting
#define CLASS_NAME "Sun Wukong"
#define CLASS_MODEL "Sun_HongKong"
#define CLASS_CLAWMODEL ""
#define CLASS_TEAM TEAM_HUMAN

const CLASS_HEALTH = 100
const CLASS_ARMOR = 100
const Float:CLASS_GRAVITY = 1.0
const Float:CLASS_SPEED = 270.0

#define IMAGE_LIVETIME 10.0
#define IMAGE_COOLDOWN 60.0

new const Shitty[3][] =
{
	"zombie_elimination/MultiKill1.wav",
	"zombie_elimination/MultiKill2.wav",
	"zombie_elimination/MultiKill3.wav"
}

// MACROS
#define Get_BitVar(%1,%2) (%1 & (1 << (%2 & 31)))
#define Set_BitVar(%1,%2) %1 |= (1 << (%2 & 31))
#define UnSet_BitVar(%1,%2) %1 &= ~(1 << (%2 & 31))

new g_Sun, g_SmokeShit
new g_MirrorImage, g_SunReach, g_SunLeap
new g_MaxPlayers, g_SkillHud, Float:CheckTime3[33], Float:ImageTime[33]

// Safety
new g_HamBot
new g_IsConnected, g_IsAlive, g_PlayerWeapon[33]

public plugin_init()
{
	register_plugin(PLUGIN, VERSION, AUTHOR)
	
	Register_SafetyFunc()
	register_forward(FM_CmdStart, "fw_CmdStart")
	
	register_think("imagination", "fw_Sun_Think")
	register_think("imagination2", "fw_Weapon_Think")
	
	g_MaxPlayers = get_maxplayers()
	g_SkillHud = CreateHudSyncObj(3)
	
	register_clcmd("drop", "CMD_Drop")
}

public plugin_precache()
{
	// Register Class
	g_Sun = ZombieEli_RegisterClass(CLASS_NAME, CLASS_HEALTH, CLASS_ARMOR, CLASS_GRAVITY, CLASS_SPEED, CLASS_MODEL, CLASS_CLAWMODEL, CLASS_TEAM, 0)

	// Skill
	g_MirrorImage = ZombieEli_RegisterSkill(g_Sun, "Mirror Image", 3)
	g_SunReach = ZombieEli_RegisterSkill(g_Sun, "Monkey Reach", 3)
	g_SunLeap = ZombieEli_RegisterSkill(g_Sun, "Monkey Leap", 3)
	
	// Precache
	precache_model("models/player/Sun_HongKong/Sun_HongKongT.mdl")
	g_SmokeShit = precache_model("sprites/steam1.spr")
	
	for(new i = 0; i < sizeof(Shitty); i++)
		precache_sound(Shitty[i])
}

public plugin_natives()
{
	register_native("SunHK_Get_SunReachSP", "Native_ILoveYou", 1)
}

public Native_ILoveYou(id)
{
	if(!is_connected(id))
		return 0
		
	return ZombieEli_GetSP(id, g_SunReach)
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
	
}

public zeli_user_died(Victim, Attacker)
{
	if(ZombieEli_IsZombie(Victim) && !ZombieEli_IsZombie(Attacker))
	{
		if(ZombieEli_GetClass(Attacker) == g_Sun)
		{
			emit_sound(Attacker, CHAN_STATIC, Shitty[random_num(0, sizeof(Shitty) - 1)], VOL_NORM, ATTN_NONE, 0, PITCH_NORM)
		}
	}
}

public zeli_class_active(id, ClassID)
{
	if(ClassID != g_Sun)
		return
		
	ImageTime[id] = get_gametime() - 60.0
		
	static SP; SP = ZombieEli_GetSP(id, g_SunLeap)
	static Float:Decrease
	switch(SP)
	{
		case 1: Decrease = 1.1
		case 2: Decrease = 1.25
		case 3: Decrease = 1.5
		default: Decrease = 1.0
	}
	
	set_pev(id, pev_gravity, CLASS_GRAVITY / Decrease)
	
	if(ZombieEli_GetLevel(id, g_Sun) >= 10) IG_SpeedSet(id, CLASS_SPEED * 1.5, 1)
}

public zeli_class_unactive(id, ClassID)
{

}

public zeli_skillup(id, SkillID, NewPoint)
{
	if(SkillID != g_SunLeap)
		return
		
	static Float:Decrease
	switch(NewPoint)
	{
		case 1: Decrease = 1.5
		case 2: Decrease = 2.0
		case 3: Decrease = 2.5
		default: Decrease = 1.0
	}
	
	set_pev(id, pev_gravity, CLASS_GRAVITY / Decrease)
}

public zeli_user_infected(id, ClassID)
{
	
}

public zeli_levelup(id, ClassID, NewLevel)
{
	if(ClassID != g_Sun)
		return
	if(NewLevel == 10)
	{
		IG_SpeedSet(id, CLASS_SPEED * 1.5, 1)
		IG_ClientPrintColor(id, "!gYou reached Lv.10!n -> !tMonkey Stance (Passive)!n")
	}
}

public fw_CmdStart(id, uc_handle, seed)
{
	if(!is_alive(id))
		return
	if(ZombieEli_IsZombie(id))
		return
	if(ZombieEli_GetClass(id) != g_Sun)
		return
	if(ZombieEli_GetLevel(id, g_Sun) < 10)
		return
		
	if(get_gametime() - 1.0 > CheckTime3[id])
	{
		set_hudmessage(200, 200, 200, -1.0, 0.83 - 0.02, 0, 1.1, 1.1, 0.0, 0.0)
		ShowSyncHudMsg(id, g_SkillHud, "Ultimate Skill: Monkey Stance (Passive)")
		
		CheckTime3[id] = get_gametime()
	}	
}

public CMD_Drop(id)
{
	if(!is_alive(id))
		return PLUGIN_CONTINUE
	if(ZombieEli_IsZombie(id))
		return PLUGIN_CONTINUE
	if(ZombieEli_GetClass(id) != g_Sun)
		return PLUGIN_CONTINUE
	
	static SP; SP = ZombieEli_GetSP(id, g_MirrorImage)
	if(SP > 0)
	{
		if(get_gametime() - IMAGE_COOLDOWN > ImageTime[id])
		{
			static Float:Target[3][3], Float:Angles[3]
			static Float:Origin[3]; pev(id, pev_origin, Origin)
			pev(id, pev_v_angle, Angles); Angles[0] = 0.0
			
			if(SP == 1)
			{
				get_position(id, -64.0, 0.0, 0.0, Target[0])
				Target[0][2] = Origin[2]
				
				if(!Is_SafeSpawn(Target[0])) 
				{
					client_print(id, print_center, "Not enough free space!")
					return PLUGIN_HANDLED
				}
				
				Create_Smoke(Target[0])
				Create_Smoke(Origin)
				
				engfunc(EngFunc_SetOrigin, id, Target[0])
				Create_Image(id, Origin, Angles, "models/player/Sun_HongKong/Sun_HongKong.mdl")
			} else if(SP == 2) {
				get_position(id, 0.0, -64.0, 0.0, Target[0])
				get_position(id, 0.0, 64.0, 0.0, Target[1])
				
				Target[0][2] = Origin[2]
				
				if(!Is_SafeSpawn(Target[0]) || !Is_SafeSpawn(Target[1])) 
				{
					client_print(id, print_center, "Not enough free space!")
					return PLUGIN_HANDLED
				}
				
				Create_Smoke(Target[0])
				Create_Smoke(Target[1])
				Create_Smoke(Origin)
				
				if(random_num(0, 1))
				{
					engfunc(EngFunc_SetOrigin, id, Target[0])
					
					Create_Image(id, Origin, Angles, "models/player/Sun_HongKong/Sun_HongKong.mdl")
					Create_Image(id, Target[1], Angles, "models/player/Sun_HongKong/Sun_HongKong.mdl")
				} else {
					engfunc(EngFunc_SetOrigin, id, Target[1])
					
					Create_Image(id, Origin, Angles, "models/player/Sun_HongKong/Sun_HongKong.mdl")
					Create_Image(id, Target[0], Angles, "models/player/Sun_HongKong/Sun_HongKong.mdl")
				}
			} else if(SP == 3) {
				get_position(id, 0.0, -64.0, 0.0, Target[0])
				get_position(id, 0.0, 64.0, 0.0, Target[1])
				get_position(id, 64.0, 0.0, 0.0, Target[2])
				
				Target[0][2] = Origin[2]
				
				if(!Is_SafeSpawn(Target[0]) || !Is_SafeSpawn(Target[1]) || !Is_SafeSpawn(Target[2])) 
				{
					client_print(id, print_center, "Not enough free space!")
					return PLUGIN_HANDLED
				}
				
				Create_Smoke(Target[0])
				Create_Smoke(Target[1])
				Create_Smoke(Target[2])
				Create_Smoke(Origin)
				
				switch(random_num(0, 2))
				{
					case 1:
					{
						engfunc(EngFunc_SetOrigin, id, Target[0])
					
						Create_Image(id, Origin, Angles, "models/player/Sun_HongKong/Sun_HongKong.mdl")
						Create_Image(id, Target[1], Angles, "models/player/Sun_HongKong/Sun_HongKong.mdl")
						Create_Image(id, Target[2], Angles, "models/player/Sun_HongKong/Sun_HongKong.mdl")
					}
					case 2:
					{
						engfunc(EngFunc_SetOrigin, id, Target[1])
					
						Create_Image(id, Origin, Angles, "models/player/Sun_HongKong/Sun_HongKong.mdl")
						Create_Image(id, Target[0], Angles, "models/player/Sun_HongKong/Sun_HongKong.mdl")
						Create_Image(id, Target[2], Angles, "models/player/Sun_HongKong/Sun_HongKong.mdl")
					}
					default:
					{
						engfunc(EngFunc_SetOrigin, id, Target[2])
					
						Create_Image(id, Origin, Angles, "models/player/Sun_HongKong/Sun_HongKong.mdl")
						Create_Image(id, Target[0], Angles, "models/player/Sun_HongKong/Sun_HongKong.mdl")
						Create_Image(id, Target[1], Angles, "models/player/Sun_HongKong/Sun_HongKong.mdl")
					}
				} 
			}
			
			ImageTime[id] = get_gametime()
		} else {
			client_print(id, print_center, "Remaining time for creating images: %i second(s)!", floatround(ImageTime[id] - (get_gametime() - IMAGE_COOLDOWN)))
		}
	} else {
		client_print(id, print_center, "Train your 'Mirror Image' skill!")
	}
		
	return PLUGIN_HANDLED
}

public Create_Image(id, Float:Origin[3], Float:Angles[3], Model[])
{
	static Ent; Ent = create_entity("info_target")
	
	set_pev(Ent, pev_origin, Origin)
	set_pev(Ent, pev_angles, Angles)

	set_pev(Ent, pev_classname, "imagination")
	engfunc(EngFunc_SetModel, Ent, Model)
	set_pev(Ent, pev_solid, SOLID_SLIDEBOX)

	//set_pev(Ent, pev_controller, pev(id, pev_controller))
	set_pev(Ent, pev_controller_0, pev(id, pev_controller_0))
	set_pev(Ent, pev_controller_1, pev(id, pev_controller_0))
	set_pev(Ent, pev_controller_2, pev(id, pev_controller_0))
	set_pev(Ent, pev_controller_3, pev(id, pev_controller_0))
	
	new Float:maxs[3] = {16.0,16.0,36.0}
	new Float:mins[3] = {-16.0,-16.0,-36.0}
	entity_set_size(Ent, mins, maxs)
	
	set_pev(Ent, pev_fuser1, get_gametime() + IMAGE_LIVETIME)
	
	set_pev(Ent, pev_animtime, get_gametime())
	set_pev(Ent, pev_framerate, 1.0)
	set_pev(Ent, pev_sequence, 1)
	set_pev(Ent, pev_gaitsequence, pev(id, pev_gaitsequence))
	set_pev(Ent, pev_owner, id)

	set_pev(Ent, pev_nextthink, get_gametime() + 0.1)
	drop_to_floor(Ent)
	
	Create_Weapon(id, Ent)
}

public Create_Smoke(Float:Origin[3])
{
	message_begin(MSG_BROADCAST ,SVC_TEMPENTITY)
	write_byte(TE_SMOKE)
	engfunc(EngFunc_WriteCoord, Origin[0])
	engfunc(EngFunc_WriteCoord, Origin[1])
	engfunc(EngFunc_WriteCoord, Origin[2] - 36.0)
	write_short(g_SmokeShit)	// sprite index 
	write_byte(30)	// scale in 0.1's 
	write_byte(30)	// framerate 
	message_end()
}

public Create_Weapon(id, Ent)
{
	static Model[128]; pev(id, pev_weaponmodel2, Model, 127)
	static Weapon; Weapon = create_entity("info_target")
	
	entity_set_string(Weapon, EV_SZ_classname, "imagination2")

	entity_set_int(Weapon, EV_INT_movetype, MOVETYPE_FOLLOW)
	entity_set_int(Weapon, EV_INT_solid, SOLID_NOT)
	entity_set_edict(Weapon, EV_ENT_aiment, Ent)
	entity_set_model(Weapon, Model) 
	
	set_pev(Weapon, pev_owner, Ent)
	set_pev(Weapon, pev_nextthink, get_gametime() + 0.1)
}

public fw_Sun_Think(Ent)
{
	if(!pev_valid(Ent))
		return
		
	static Owner; Owner = pev(Ent, pev_owner)
	if(!is_connected(Owner) || !is_alive(Owner))
	{
		set_pev(Ent, pev_nextthink, get_gametime() + 0.1)
		set_pev(Ent, pev_flags, FL_KILLME)
		
		return
	}
	
	static Float:Time; pev(Ent, pev_fuser1, Time)
	if(Time < get_gametime()) 
	{
		set_pev(Ent, pev_nextthink, get_gametime() + 0.1)
		set_pev(Ent, pev_flags, FL_KILLME)
		
		return
	}
	
	static Float:Angles[3]
	pev(Owner, pev_v_angle, Angles); Angles[0] = 0.0
	set_pev(Ent, pev_angles, Angles)
		
	set_pev(Ent, pev_nextthink, get_gametime() + 0.1)
}

public fw_Weapon_Think(Ent)
{
	if(!pev_valid(Ent))
		return
		
	static Owner; Owner = pev(Ent, pev_owner)
	if(!pev_valid(Owner))
	{
		set_pev(Ent, pev_nextthink, get_gametime() + 0.1)
		set_pev(Ent, pev_flags, FL_KILLME)
		
		return
	}
		
	set_pev(Ent, pev_nextthink, get_gametime() + 0.1)
}

public Is_SafeSpawn(Float:Origin[3])
{
	if(is_hull_vacant(Origin, HULL_HUMAN))
		return 1
	
	return 0
}

stock is_hull_vacant(Float:Origin[3], hull)
{
	engfunc(EngFunc_TraceHull, Origin, Origin, 0, hull, 0, 0)
	
	if (!get_tr2(0, TR_StartSolid) && !get_tr2(0, TR_AllSolid) && get_tr2(0, TR_InOpen))
		return true
	
	return false
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