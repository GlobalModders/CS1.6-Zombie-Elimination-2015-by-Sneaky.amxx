#include <amxmodx>
#include <engine>
#include <fakemeta>
#include <fakemeta_util>
#include <hamsandwich>
#include <cstrike>
#include <xs>
#include <fun>
//#include <infinitygame>

#define PLUGIN "Skeleton Hook"
#define VERSION "1.0"
#define AUTHOR "Jesus"

#define MODEL_V "models/v_skeleton_hook.mdl"
#define MODEL_P "models/p_skeleton_hook.mdl"
#define MODEL_W "models/w_skeleton_hook.mdl"
#define CHAIN "sprites/bone_chain.spr"

#define MAX_RADIUS 400.0

new const WeaponSounds[3][] =
{
	"skeleton_hook/hook_impact.wav",
	"skeleton_hook/hook_retract_stop.wav",
	"skeleton_hook/hook_throw.wav"
}

enum
{
	ANIM_IDLE = 0,
	ANIM_SLASH1,
	ANIM_THROW,
	ANIM_DRAW,
	ANIM_STAB,
	ANIM_STAB_MISS,
	ANIM_MIDSLASH1,
	ANIM_MIDSLASH2
}

// MACROS
#define Get_BitVar(%1,%2) (%1 & (1 << (%2 & 31)))
#define Set_BitVar(%1,%2) %1 |= (1 << (%2 & 31))
#define UnSet_BitVar(%1,%2) %1 &= ~(1 << (%2 & 31))

const pev_eteam = pev_iuser1
const pev_return = pev_iuser2
const pev_extra = pev_iuser3

new g_Chain
new g_Had_Shit, g_Throwing, g_MyShit[33], g_Hit, Float:Creation[512]

public plugin_init()
{
	register_plugin(PLUGIN, VERSION, AUTHOR)
	
	register_forward(FM_CmdStart, "fw_CmdStart")
	
	register_touch("shit", "*", "fw_Guillotine_Touch")
	register_think("shit", "fw_Guillotine_Think")
	
	RegisterHam(Ham_Item_Deploy, "weapon_knife", "fw_Item_Deploy_Post", 1)
}

public plugin_precache()
{
	precache_model(MODEL_V)
	precache_model(MODEL_P)
	precache_model(MODEL_W)
	
	for(new i = 0; i < sizeof(WeaponSounds); i++)
		precache_sound(WeaponSounds[i])
		
	g_Chain = precache_model(CHAIN)
}

public plugin_natives()
{
	register_native("MyName_Is_Binladen", "Get_Shit", 1)
	register_native("ComeFrom_Vietnam", "Remove_Shit", 1)
}

public Get_Shit(id)
{
	UnSet_BitVar(g_Throwing, id)
	Set_BitVar(g_Had_Shit, id)
	
	if(get_user_weapon(id) == CSW_KNIFE)
	{
		set_pev(id, pev_viewmodel2, MODEL_V)
		set_pev(id, pev_weaponmodel2, MODEL_P)
		
		Set_PlayerNextAttack(id, 0.75)
		Set_WeaponAnim(id, ANIM_DRAW)
	}
}
public client_disconnect(id)
{
	Remove_Shit(id)
}

public Remove_Shit(id)
{
	g_MyShit[id] = -1
	
	UnSet_BitVar(g_Throwing, id)
	UnSet_BitVar(g_Had_Shit, id)
}

public fw_CmdStart(id, A, B)
{
	if(!is_user_alive(id))
		return
	if(get_user_weapon(id) != CSW_KNIFE || !Get_BitVar(g_Had_Shit, id))
		return
		
	static C; C = get_uc(A, UC_Buttons)
	if(C & IN_ATTACK2)
	{
		C &= ~IN_ATTACK2
		set_uc(A, UC_Buttons, C)
		
		if(get_pdata_float(id, 83, 5) > 0.0)
			return
		if(Get_BitVar(g_Throwing, id))
			return
		//	
		//IG_SpeedSet(id, 0.1, 1)
			
		set_pdata_float(id, 83, 1.0, 5)
		Set_WeaponAnim(id, ANIM_THROW)
		
		Set_BitVar(g_Throwing, id)
		emit_sound(id, CHAN_WEAPON, WeaponSounds[2], VOL_NORM, ATTN_NORM, 0, PITCH_NORM)
		
		Create_Shit(id)
	}
}

public Create_Shit(id)
{
	new iEnt = create_entity("info_target")
	
	static Float:Origin[3], Float:TargetOrigin[3], Float:Velocity[3], Float:Angles[3]
	
	get_weapon_attachment(id, Origin, 0.0)
	Origin[2] -= 10.0
	get_position(id, 1024.0, 0.0, 0.0, TargetOrigin)
	
	pev(id, pev_v_angle, Angles)
	Angles[0] *= -1.0
	
	// set info for ent
	set_pev(iEnt, pev_movetype, MOVETYPE_FLY)
	entity_set_string(iEnt, EV_SZ_classname, "shit")
	engfunc(EngFunc_SetModel, iEnt, MODEL_W)
	
	set_pev(iEnt, pev_mins, Float:{-1.0, -1.0, -1.0})
	set_pev(iEnt, pev_maxs, Float:{1.0, 1.0, 1.0})
	set_pev(iEnt, pev_origin, Origin)
	set_pev(iEnt, pev_angles, Angles)
	set_pev(iEnt, pev_gravity, 0.01)
	set_pev(iEnt, pev_solid, SOLID_TRIGGER)
	set_pev(iEnt, pev_owner, id)	
	set_pev(iEnt, pev_iuser1, get_user_team(id))
	set_pev(iEnt, pev_iuser2, 0)
	set_pev(iEnt, pev_iuser3, 0)
	set_pev(iEnt, pev_enemy, 0)
	set_pev(iEnt, pev_fuser2, get_gametime() + 8.0)
	
	get_speed_vector(Origin, TargetOrigin, 650.0, Velocity)
	set_pev(iEnt, pev_velocity, Velocity)	
	
	set_pev(iEnt, pev_nextthink, get_gametime() + 0.1)
	
	g_MyShit[id] = iEnt
	
	// Animation
	set_pev(iEnt, pev_animtime, get_gametime())
	set_pev(iEnt, pev_framerate, 2.0)
	set_pev(iEnt, pev_sequence, 0)

	// Shitty
	message_begin(MSG_BROADCAST, SVC_TEMPENTITY)
	write_byte(8)	// TE_BEAMENTS
	write_short(id)
	write_short(iEnt)
	write_short(g_Chain)	// sprite index
	write_byte(0)	// start frame
	write_byte(0)	// framerate
	write_byte(15)	// life
	write_byte(12)	// width
	write_byte(0)	// noise
	write_byte(157)	// r, g, b
	write_byte(157)	// r, g, b
	write_byte(157)	// r, g, b
	write_byte(255)	// brightness
	write_byte(0)	// speed
	message_end()
}

public fw_Guillotine_Touch(Ent, Touched)
{
	if(!pev_valid(Ent))
		return
		
	static id; id = pev(Ent, pev_owner)
	if(!is_user_alive(id))
	{
		remove_entity(Ent)
		return
	}
		
	if(is_user_connected(Touched))
	{ // Touch Human
		if(!is_user_alive(Touched))
			return
		if(Touched == id)
			return
		if(cs_get_user_team(Touched) == cs_get_user_team(id))
			return
			
		if(!pev(Ent, pev_return))
		{
			// Set
			set_pev(Ent, pev_enemy, Touched)
			set_pev(Ent, pev_return, 1)
			set_pev(Ent, pev_velocity, {0.0, 0.0, 0.0})
		} else {
			
		}
		
	} else { // Touch Wall
		if(!pev(Ent, pev_return))
		{
			set_pev(Ent, pev_velocity, {0.0, 0.0, 0.0})
			
			set_pev(Ent, pev_return, 1)
			emit_sound(Ent, CHAN_BODY, WeaponSounds[0], VOL_NORM, ATTN_NORM, 0, PITCH_NORM)
			
			// Reset Angles
			static Float:Angles[3]
			pev(id, pev_v_angle, Angles)
			
			Angles[0] *= -1.0
			set_pev(Ent, pev_angles, Angles)
		} else {
			static Classname[32];
			pev(Touched, pev_classname, Classname, 31)
			
			if(!equal(Classname, "weaponbox")) 
			{
				remove_entity(Ent)
				
				UnSet_BitVar(g_Throwing, id)
				emit_sound(id, CHAN_WEAPON, WeaponSounds[1], VOL_NORM, ATTN_NORM, 0, PITCH_NORM)
				Set_WeaponAnim(id, 1)
				
				remove_entity(Ent)
				g_MyShit[id] = -1
				
				return
			}
		}
	}
}

public fw_Guillotine_Think(Ent)
{
	if(!pev_valid(Ent))
		return
		
	static id; id = pev(Ent, pev_owner)
	if(!is_user_alive(id))
	{
		remove_entity(Ent)
		return
	}
	if(!Get_BitVar(g_Had_Shit, id))
	{
		remove_entity(Ent)
		return
	}
	
	static Float:LiveTime
	pev(Ent, pev_fuser2, LiveTime)
			
	if(get_gametime() >= LiveTime)
	{
		remove_entity(Ent)
		return
	}
	
	if(pev(Ent, pev_return)) // Returning to the owner
	{
		static Target; Target = pev(Ent, pev_enemy)
		
		UnSet_BitVar(g_Hit, id)
		
		if(pev(Ent, pev_sequence) != 0) set_pev(Ent, pev_sequence, 0)
		if(pev(Ent, pev_movetype) != MOVETYPE_FLY) set_pev(Ent, pev_movetype, MOVETYPE_FLY)
		set_pev(Ent, pev_aiment, 0)
		
		if(entity_range(Ent, id) > 100.0)
		{
			static Float:Origin[3]; pev(id, pev_origin, Origin)
			Hook_The_Fucking_Ent(Ent, Origin, 640.0)
			
			if(is_user_alive(Target)) Hook_The_Fucking_Ent(Target, Origin, 640.0)
		} else {
			//IG_SpeedReset(id)
			UnSet_BitVar(g_Throwing, id)
			emit_sound(id, CHAN_WEAPON, WeaponSounds[1], VOL_NORM, ATTN_NORM, 0, PITCH_NORM)
			Set_WeaponAnim(id, 1)
			
			remove_entity(Ent)
			g_MyShit[id] = -1

			return
		}
	} else {
		if(entity_range(Ent, id) >= MAX_RADIUS)
		{
			set_pev(Ent, pev_velocity, {0.0, 0.0, 0.0})
			set_pev(Ent, pev_return, 1)
		}
	}
	
	set_pev(Ent, pev_nextthink, get_gametime() + 0.05)
}


public fw_Item_Deploy_Post(Ent)
{
	if(pev_valid(Ent) != 2)
		return
	static Id; Id = get_pdata_cbase(Ent, 41, 4)
	if(get_pdata_cbase(Id, 373) != Ent)
		return
	if(!Get_BitVar(g_Had_Shit, Id))
		return
	
	set_pev(Id, pev_viewmodel2, MODEL_V)
	set_pev(Id, pev_weaponmodel2, MODEL_P)
}

stock Set_WeaponIdleTime(id, WeaponId ,Float:TimeIdle)
{
	static entwpn; entwpn = fm_get_user_weapon_entity(id, WeaponId)
	if(!pev_valid(entwpn)) 
		return
		
	set_pdata_float(entwpn, 46, TimeIdle, 4)
	set_pdata_float(entwpn, 47, TimeIdle, 4)
	set_pdata_float(entwpn, 48, TimeIdle + 0.5, 4)
}

stock Set_PlayerNextAttack(id, Float:nexttime)
{
	set_pdata_float(id, 83, nexttime, 5)
}

stock Set_WeaponAnim(id, anim)
{
	set_pev(id, pev_weaponanim, anim)
	
	message_begin(MSG_ONE_UNRELIABLE, SVC_WEAPONANIM, {0, 0, 0}, id)
	write_byte(anim)
	write_byte(pev(id, pev_body))
	message_end()
}

stock get_weapon_attachment(id, Float:output[3], Float:fDis = 40.0)
{ 
	static Float:vfEnd[3], viEnd[3] 
	get_user_origin(id, viEnd, 3)  
	IVecFVec(viEnd, vfEnd) 
	
	static Float:fOrigin[3], Float:fAngle[3]
	
	pev(id, pev_origin, fOrigin) 
	pev(id, pev_view_ofs, fAngle)
	
	xs_vec_add(fOrigin, fAngle, fOrigin) 
	
	static Float:fAttack[3]
	
	xs_vec_sub(vfEnd, fOrigin, fAttack)
	xs_vec_sub(vfEnd, fOrigin, fAttack) 
	
	static Float:fRate
	
	fRate = fDis / vector_length(fAttack)
	xs_vec_mul_scalar(fAttack, fRate, fAttack)
	
	xs_vec_add(fOrigin, fAttack, output)
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

stock Hook_The_Fucking_Ent(ent, Float:TargetOrigin[3], Float:Speed)
{
	static Float:fl_Velocity[3], Float:EntOrigin[3], Float:distance_f, Float:fl_Time
	
	pev(ent, pev_origin, EntOrigin)
	
	distance_f = get_distance_f(EntOrigin, TargetOrigin)
	fl_Time = distance_f / Speed
		
	pev(ent, pev_velocity, fl_Velocity)
		
	fl_Velocity[0] = (TargetOrigin[0] - EntOrigin[0]) / fl_Time
	fl_Velocity[1] = (TargetOrigin[1] - EntOrigin[1]) / fl_Time
	fl_Velocity[2] = (TargetOrigin[2] - EntOrigin[2]) / fl_Time

	set_pev(ent, pev_velocity, fl_Velocity)
}

stock PlaySound(id, const sound[])
{
	if(equal(sound[strlen(sound)-4], ".mp3")) client_cmd(id, "mp3 play ^"sound/%s^"", sound)
	else client_cmd(id, "spk ^"%s^"", sound)
}

stock Get_SpeedVector(const Float:origin1[3],const Float:origin2[3],Float:speed, Float:new_velocity[3])
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
/* AMXX-Studio Notes - DO NOT MODIFY BELOW HERE
*{\\ rtf1\\ ansi\\ deff0{\\ fonttbl{\\ f0\\ fnil Tahoma;}}\n\\ viewkind4\\ uc1\\ pard\\ lang1042\\ f0\\ fs16 \n\\ par }
*/
