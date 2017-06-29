/*
	This is a false weapon, since we are only using it for a weapon spawner.
*/

class secret_weapon_spawner : ScriptBasePlayerWeaponEntity
{
	float m_flNextAnimTime;
	int m_iShell;
	bool m_DisableSpawner = true;
	string SetCustomModel = "models/aomdc/weapons/gmgeneral/w_gmgeneral.mdl";	//Which model should we set?
	string SetCustomWeapon = "weapon_gmgeneral";	//Which weapon should we give to the player?
	
	bool KeyValue( const string& in szKey, const string& in szValue )
	{
		if( szKey == "worldmodel" )
		{
			SetCustomModel = szValue;
			return true;
		}
		else if( szKey == "spawnweapon" )
		{
			SetCustomWeapon = szValue;
			return true;
		}
		else if( szKey == "respawn" )
		{
			if( atof( szValue ) > 0)
				m_DisableSpawner = false;
			return true;
		}
		else
			return BaseClass.KeyValue( szKey, szValue );
	}
	
	void Spawn()
	{
		Precache();
		g_EntityFuncs.SetModel( self, SetCustomModel );
		self.FallInit();
	}
	
	void Precache()
	{
		self.PrecacheCustomModels();
		g_Game.PrecacheModel( "models/error.mdl" );
		g_Game.PrecacheModel( "models/error.mdl" );
		g_Game.PrecacheModel( "models/error.mdl" );
	}

	bool GetItemInfo( ItemInfo& out info )
	{
		info.iMaxAmmo1 	= -1;
		info.iMaxAmmo2 	= -1;
		info.iMaxClip 	= -1;
		info.iSlot 		= 0;
		info.iPosition 	= 0;
		info.iFlags 	= 0;
		info.iWeight 	= 0;

		return true;
	}

	bool AddToPlayer( CBasePlayer@ pPlayer )
	{
		// Is this a 1 time pickup, or can you keep picking it up?
		if( m_DisableSpawner )
		{
			pPlayer.GiveNamedItem( SetCustomWeapon );
			self.Kill();
			return false;
		}
		else
		{
			pPlayer.GiveNamedItem( SetCustomWeapon );
			return false;
		}
	}
	
	bool PlayEmptySound()
	{
		return false;
	}

	bool Deploy()
	{
		return self.DefaultDeploy( self.GetV_Model( "models/error.mdl" ), self.GetP_Model( "models/error.mdl" ), 0, "mp5" );
	}
	
	float WeaponTimeBase()
	{
		return g_Engine.time;
	}

	void PrimaryAttack()
	{
		return;
	}

	void Reload()
	{
		return;
	}

	void WeaponIdle()
	{
		self.SendWeaponAnim( 0 );
	}
}

string GetWeaponSpawner()
{
	return "secret_weapon_spawner";
}

void RegisterSpecial_WeaponSpawner()
{
	g_CustomEntityFuncs.RegisterCustomEntity( "secret_weapon_spawner", GetWeaponSpawner() );
	g_ItemRegistry.RegisterWeapon( GetWeaponSpawner(), "aom_weapons", "pickup" );
}
