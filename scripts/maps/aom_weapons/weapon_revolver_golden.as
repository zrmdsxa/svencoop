enum revolve_golden_e
{
	REVOLVER_GOLD_LONGIDLE = 0,
	REVOLVER_GOLD_IDLE1,
	REVOLVER_GOLD_FIRE,
	REVOLVER_GOLD_RELOAD,
	REVOLVER_GOLD_HOLSTER,
	REVOLVER_GOLD_DEPLOY,
	REVOLVER_GOLD_IDLE2,
	REVOLVER_GOLD_IDLE3
};

const int REVOLVER_GOLD_DEFAULT_GIVE 	= 60;
const int REVOLVER_GOLD_MAX_AMMO		= 60;
const int REVOLVER_GOLD_MAX_CLIP 		= 6;
const int REVOLVER_GOLD_WEIGHT 			= 5;

class weapon_revolver_golden : ScriptBasePlayerWeaponEntity
{
	private CBasePlayer@ m_pPlayer = null;
	float m_flNextAnimTime;
	int m_iShell;
	
	void Spawn()
	{
		Precache();
		g_EntityFuncs.SetModel( self, "models/aomdc/weapons/revolver/w_revolver_gold.mdl" );

		self.m_iDefaultAmmo = REVOLVER_GOLD_DEFAULT_GIVE;

		self.FallInit();
	}

	void Precache()
	{
		self.PrecacheCustomModels();
		g_Game.PrecacheModel( "models/aomdc/weapons/revolver/v_revolver_gold.mdl" );
		g_Game.PrecacheModel( "models/aomdc/weapons/revolver/w_revolver_gold.mdl" );
		g_Game.PrecacheModel( "models/aomdc/weapons/revolver/p_revolver_gold.mdl" );

		m_iShell = g_Game.PrecacheModel( "models/shell.mdl" );

		g_Game.PrecacheModel( "models/w_9mmARclip.mdl" );
		g_SoundSystem.PrecacheSound( "items/9mmclip1.wav" );              

		//These are played by the model, needs changing there
		g_SoundSystem.PrecacheSound( "aomdc/weapons/revolver/revolver_draw.wav" );
		g_SoundSystem.PrecacheSound( "aomdc/weapons/revolver/revolver_reload.wav" );

		g_SoundSystem.PrecacheSound( "aomdc/weapons/revolver/revolver_fire.wav" );

		g_SoundSystem.PrecacheSound( "hl/weapons/357_cock1.wav" );
	}

	bool GetItemInfo( ItemInfo& out info )
	{
		info.iMaxAmmo1 	= REVOLVER_GOLD_MAX_AMMO;
		info.iMaxAmmo2 	= -1;
		info.iMaxClip 	= REVOLVER_GOLD_MAX_CLIP;
		info.iSlot 		= 1;
		info.iPosition 	= 11;
		info.iFlags 	= 0;
		info.iWeight 	= REVOLVER_GOLD_WEIGHT;

		return true;
	}

	bool AddToPlayer( CBasePlayer@ pPlayer )
	{
		if( !BaseClass.AddToPlayer( pPlayer ) )
			return false;
			
		@m_pPlayer = pPlayer;
			
		NetworkMessage message( MSG_ONE, NetworkMessages::WeapPickup, pPlayer.edict() );
			message.WriteLong( self.m_iId );
		message.End();

		return true;
	}
	
	bool PlayEmptySound()
	{
		if( self.m_bPlayEmptySound )
		{
			self.m_bPlayEmptySound = false;
			
			g_SoundSystem.EmitSoundDyn( m_pPlayer.edict(), CHAN_WEAPON, "hl/weapons/357_cock1.wav", 0.8, ATTN_NORM, 0, PITCH_NORM );
		}
		
		return false;
	}

	bool Deploy()
	{
		return self.DefaultDeploy( self.GetV_Model( "models/aomdc/weapons/revolver/v_revolver_gold.mdl" ), self.GetP_Model( "models/aomdc/weapons/revolver/p_revolver_gold.mdl" ), REVOLVER_GOLD_DEPLOY, "python" );
	}
	
	float WeaponTimeBase()
	{
		return g_Engine.time; //g_WeaponFuncs.WeaponTimeBase();
	}
	
	void PrimaryAttack()
	{
		if( self.m_iClip <= 0 )
		{
			self.PlayEmptySound();
			self.m_flNextPrimaryAttack = WeaponTimeBase() + 0.15;
			return;
		}

		m_pPlayer.m_iWeaponVolume = NORMAL_GUN_VOLUME;
		m_pPlayer.m_iWeaponFlash = NORMAL_GUN_FLASH;

		--self.m_iClip;
		
		self.SendWeaponAnim( REVOLVER_GOLD_FIRE, 0, 0 );
		
		g_SoundSystem.EmitSoundDyn( m_pPlayer.edict(), CHAN_WEAPON, "aomdc/weapons/revolver/revolver_fire.wav", 1.0, ATTN_NORM, 0, 95 + Math.RandomLong( 0, 10 ) );

		// player "shoot" animation
		m_pPlayer.SetAnimation( PLAYER_ATTACK1 );

		Vector vecSrc	 = m_pPlayer.GetGunPosition();
		Vector vecAiming = m_pPlayer.GetAutoaimVector( AUTOAIM_5DEGREES );
		
		// JonnyBoy0719: Added custom bullet damage.
		int m_iBulletDamage = 900;
		// JonnyBoy0719: End
		
		// optimized multiplayer. Widened to make it easier to hit a moving player
		m_pPlayer.FireBullets( 1, vecSrc, vecAiming, VECTOR_CONE_1DEGREES, 8192, BULLET_PLAYER_357, 1, m_iBulletDamage );

		if( self.m_iClip == 0 && m_pPlayer.m_rgAmmo( self.m_iPrimaryAmmoType ) <= 0 )
			// HEV suit - indicate out of ammo condition
			m_pPlayer.SetSuitUpdate( "!HEV_AMO0", false, 0 );
			
		m_pPlayer.pev.punchangle.x = Math.RandomLong( -2, 2 );

		self.m_flNextPrimaryAttack = self.m_flNextPrimaryAttack + 0.78;
		if( self.m_flNextPrimaryAttack < WeaponTimeBase() )
			self.m_flNextPrimaryAttack = WeaponTimeBase() + 0.78;

		self.m_flTimeWeaponIdle = WeaponTimeBase() + g_PlayerFuncs.SharedRandomFloat( m_pPlayer.random_seed,  10, 15 );
		
		TraceResult tr;
		
		float x, y;
		
		g_Utility.GetCircularGaussianSpread( x, y );
		
		Vector vecDir = vecAiming 
						+ x * VECTOR_CONE_1DEGREES.x * g_Engine.v_right 
						+ y * VECTOR_CONE_1DEGREES.y * g_Engine.v_up;

		Vector vecEnd	= vecSrc + vecDir * 4096;

		g_Utility.TraceLine( vecSrc, vecEnd, dont_ignore_monsters, m_pPlayer.edict(), tr );
		
		if( tr.flFraction < 1.0 )
		{
			if( tr.pHit !is null )
			{
				CBaseEntity@ pHit = g_EntityFuncs.Instance( tr.pHit );
				
				if( pHit is null || pHit.IsBSPModel() == true )
					g_WeaponFuncs.DecalGunshot( tr, BULLET_PLAYER_MP5 );
			}
		}
	}
	
	void Reload()
	{
		self.DefaultReload( REVOLVER_GOLD_MAX_CLIP, REVOLVER_GOLD_RELOAD, 2.5, 0 );

		//Set 3rd person reloading animation -Sniper
		BaseClass.Reload();
	}

	void WeaponIdle()
	{
		self.ResetEmptySound();

		m_pPlayer.GetAutoaimVector( AUTOAIM_5DEGREES );

		if( self.m_flTimeWeaponIdle > WeaponTimeBase() )
			return;

		int iAnim;
		switch( g_PlayerFuncs.SharedRandomLong( m_pPlayer.random_seed,  0, 1 ) )
		{
		case 0:	
			iAnim = REVOLVER_GOLD_LONGIDLE;	
			break;
		
		case 1:
			iAnim = REVOLVER_GOLD_IDLE1;
			break;
			
		default:
			iAnim = REVOLVER_GOLD_IDLE1;
			break;
		}

		self.SendWeaponAnim( iAnim );

		self.m_flTimeWeaponIdle = WeaponTimeBase() + g_PlayerFuncs.SharedRandomFloat( m_pPlayer.random_seed,  10, 15 );// how long till we do this again.
	}
}

string GetWeaponName_AOMREVOLVER_GOLD()
{
	return "weapon_revolver_golden";
}

void RegisterWeapon_REVOLVER_GOLD()
{
	g_CustomEntityFuncs.RegisterCustomEntity( "weapon_revolver_golden", GetWeaponName_AOMREVOLVER_GOLD() );
	g_ItemRegistry.RegisterWeapon( GetWeaponName_AOMREVOLVER_GOLD(), "aom_weapons", "357_special" );
}
