#if defined _infinitygame_included
  #endinput
#endif
#define _infinitygame_included

#if AMXX_VERSION_NUM >= 175
 #pragma reqlib infinitygame
 #if !defined AMXMODX_NOAUTOLOAD
  #pragma loadlib infinitygame
 #endif
#else
 #pragma library infinitygame
#endif

enum
{
	WIN_CT = 1,
	WIN_TERRORIST,
	WIN_DRAW
}

enum
{
	TUTOR_GREEN = 0,
	TUTOR_RED,
	TUTOR_BLUE,
	TUTOR_YELLOW
}

// Native Class 1st
native IG_EndRound_Block(bool:bStatus, bool:bBlockGameCommencing);
native IG_TerminateRound(WinTeam, Float:DelayTime, WinEffect);

// Native Class 2nd
native IG_RoundTime_Set(Minute, Second); // Max is 512 minutes
native IG_MapName_Patch(const Name[]); // Patch Map Name (Shown in Server Favorite)
native IG_EmitSound(id, receiver, channel, const sample[], Float:volume, Float:attn, flags, pitch, Float:origin[3] = {0.0,0.0,0.0});

// Native Class 3rd
native IG_TeamSet(id, CsTeams:Team);
native IG_SpeedSet(id, Float:Speed, BlockSpeed);
native IG_SpeedReset(id);
native IG_ModelSet(id, const Model[], ModelIndex); // if ModelIndex = 1 -> ModelIndex is enable
native IG_ModelReset(id);

// Native Class 4th
native IG_Semiclip(Activate, AvailableTeam, PassEnemy); // Enable/Disable Semiclip in Server | Team: 1-T 2-CT 3-BOTH | Pass Enemy: 0-D 1-E
native IG_ClientPrintColor(id, const Text[], any:...); // Color: !g - Green | !t - Team Color | !n - Normal
native IG_Fog(id, Red, Green, Blue, Density); // R,G,B (0 - 255) | Density (1-9)
//native IG_TutorShow(id, const Text[], TutorColor); // Precaching Specific Files is needed! (See below)
//native IG_TutorReset(id); // Hide Tutor
native IG_3rdView(id, Enable); // Enable: 1 - Activate | 0 - Reset
native IG_DLight_Set(id, Position, Red, Green, Blue, Size); // Create DLIGHT at Position; POSITION: 0 - Aim Origin | 1 - Ent Origin
native IG_DLight_Reset(id); // Reset

// Native Class 5th
native IG_Muzzleflash_Set(id, const Muzzleflash[], Float:Scale); // Set Muzzleflash 
native IG_Muzzleflash_Activate(id); // Flash the Muzzleflash 
native IG_PlayerAttachment(id, const Sprite[], Float:Time, Float:Scale, Float:FrameRate); // Head Attachment

// Forwards
forward IG_RunningTime(); // This forward is called every second (each 1 second)
forward IG_WeaponAnim(id, CSW, Anim); // This forward is called when an animation is played in viewmodel (except Shooting animations)

// Precache File List for Tutor (CZ)
// - resource/UI/TutorTextWindow.res
// - gfx/career/icon_i.tga
// - gfx/career/icon_skulls.tga
/* AMXX-Studio Notes - DO NOT MODIFY BELOW HERE
*{\\ rtf1\\ ansi\\ deff0{\\ fonttbl{\\ f0\\ fnil Tahoma;}}\n\\ viewkind4\\ uc1\\ pard\\ lang1042\\ f0\\ fs16 \n\\ par }
*/
