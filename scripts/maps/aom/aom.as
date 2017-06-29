/*
	Using a modified HLSP as a base.
*/

#include "aom_survival"
#include "aom_checkpoint"

// Our weapons
#include "../aom_weapons/weapon_axe"
#include "../aom_weapons/weapon_knife"
#include "../aom_weapons/weapon_hammer"
#include "../aom_weapons/weapon_spear"
#include "../aom_weapons/weapon_beretta"
#include "../aom_weapons/weapon_aomglock"
#include "../aom_weapons/weapon_p228"
#include "../aom_weapons/weapon_deagle"
#include "../aom_weapons/weapon_revolver"
#include "../aom_weapons/weapon_revolver_golden"
#include "../aom_weapons/weapon_mp5k"
#include "../aom_weapons/weapon_gmgeneral"
#include "../aom_weapons/secret_weapon_spawner"
#include "../aom_weapons/weapon_aomuzi"
#include "../aom_weapons/weapon_aomshotgun"

Survival g_Survival;

void MapInit()
{	
	// Lets register these weapons, so we can shoot stuff
	Registerweapon_AXE();
	RegisterWeapon_KNIFE();
	RegisterWeapon_HAMMER();
	Registerweapon_SPEAR();
	
	RegisterWeapon_BERETTA();
	Registerweapon_GLOCK();
	Registerweapon_P228();
	RegisterWeapon_DEAGLE();
	RegisterWeapon_REVOLVER();
	RegisterWeapon_REVOLVER_GOLD();
	
	RegisterWeapon_MP5K();
	RegisterWeapon_UZI();
	RegisterWeapon_GMGENERAL();
	
	RegisterWeapon_SHOTGUN();
	
	// Specials
	RegisterSpecial_WeaponSpawner();
	
	g_EngineFuncs.CVarSetFloat( "mp_hevsuit_voice", 0 );
	
	// If survival mode is enabled, lets create our checkpoints
	if (g_Survival.IsEnabled)
		RegisterAomPointCheckPointEntity();
}

void MapStart()
{
	/*
		Todo: Obtain mapname, read the .cp file, if none is found, read aomdc_default.cp
		
		What does it do:
			If someone has died, and respawns, they will be given the weapons from the .cp file.
			And if the map doesn't have a .cp file, it will read the default one. If that isn't found, lets not crash the server, just send a warning message and turn the system off
	*/
}

HookReturnCode ClientPutInServer( CBasePlayer@ pPlayer )
{
	g_Survival.ClientPutInServer();
	
	return HOOK_CONTINUE;
}

HookReturnCode ClientDisconnect( CBasePlayer@ pPlayer )
{
	g_Survival.ClientDisconnect();
	
	return HOOK_CONTINUE;
}

HookReturnCode PlayerKilled( CBasePlayer@ pPlayer, CBaseEntity@ pAttacker, int iGib )
{
	g_Survival.PlayerKilled();
	
	return HOOK_CONTINUE;
}
