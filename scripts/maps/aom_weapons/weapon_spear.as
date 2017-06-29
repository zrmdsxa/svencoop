enum spear_e
{
	SPEAR_IDLE = 0,
	SPEAR_STAB_START,
	SPEAR_STAB_MISS,
	SPEAR_STAB,
	SPEAR_DRAW,
	SPEAR_ELECTRECUTATED
};

class weapon_spear : ScriptBasePlayerWeaponEntity
{
	private CBasePlayer@ m_pPlayer = null;
	bool m_IsPullingBack = false;
	int m_iSwing;
	TraceResult m_trHit;
	
	void Spawn()
	{
		Precache();
		g_EntityFuncs.SetModel( self, self.GetW_Model( "models/aomdc/weapons/spear/w_spear.mdl") );
		self.m_iClip			= -1;
		self.m_flCustomDmg		= self.pev.dmg;

		self.FallInit();// get ready to fall down.
	}

	bool AddToPlayer( CBasePlayer@ pPlayer )
	{
		if( !BaseClass.AddToPlayer( pPlayer ) )
			return false;
			
		@m_pPlayer = pPlayer;

		return true;
	}
	
	void Precache()
	{
		self.PrecacheCustomModels();

		g_Game.PrecacheModel( "models/aomdc/weapons/spear/v_spear.mdl" );
		g_Game.PrecacheModel( "models/aomdc/weapons/spear/w_spear.mdl" );
		g_Game.PrecacheModel( "models/aomdc/weapons/spear/p_spear.mdl" );

		g_SoundSystem.PrecacheSound( "aomdc/weapons/spear/spear_hitbody.wav" );
		g_SoundSystem.PrecacheSound( "aomdc/weapons/spear/spear_hit.wav" );
		g_SoundSystem.PrecacheSound( "aomdc/weapons/spear/spear_miss.wav" );
		g_SoundSystem.PrecacheSound( "aomdc/weapons/spear/spear_electrocute.wav" );
	}

	bool GetItemInfo( ItemInfo& out info )
	{
		info.iMaxAmmo1		= -1;
		info.iMaxAmmo2		= -1;
		info.iMaxClip		= WEAPON_NOCLIP;
		info.iSlot			= 0;
		info.iPosition		= 9;
		info.iWeight		= 0;
		return true;
	}

	bool Deploy()
	{
		return self.DefaultDeploy( self.GetV_Model( "models/aomdc/weapons/spear/v_spear.mdl" ), self.GetP_Model( "models/aomdc/weapons/spear/p_spear.mdl" ), SPEAR_DRAW, "crowbar" );
	}

	void PrimaryAttack()
	{
		if( !m_IsPullingBack )
		{
			// We don't want the player to break/stop the animation or sequence.
			m_IsPullingBack = true;
			
			// We are pulling back our spear
			self.SendWeaponAnim( SPEAR_STAB_START, 0, 0 );
			
			// Lets wait for the 'heavy smack'
			SetThink( ThinkFunction( this.DoHeavyAttack ) );
			self.pev.nextthink = g_Engine.time + 0.4;
		}
	}
	
	void DoHeavyAttack()
	{
		HeavySmack();
	}
	
	void Smack()
	{
		g_WeaponFuncs.DecalGunshot( m_trHit, BULLET_PLAYER_CROWBAR );
	}
	
	bool HeavySmack()
	{
		TraceResult tr;
		
		bool fDidHit = false;

		Math.MakeVectors( m_pPlayer.pev.v_angle );
		Vector vecSrc	= m_pPlayer.GetGunPosition();
		Vector vecEnd	= vecSrc + g_Engine.v_forward * 35;

		g_Utility.TraceLine( vecSrc, vecEnd, dont_ignore_monsters, m_pPlayer.edict(), tr );

		if ( tr.flFraction >= 1.0 )
		{
			g_Utility.TraceHull( vecSrc, vecEnd, dont_ignore_monsters, head_hull, m_pPlayer.edict(), tr );
			if ( tr.flFraction < 1.0 )
			{
				// Calculate the point of intersection of the line (or hull) and the object we hit
				// This is and approximation of the "best" intersection
				CBaseEntity@ pHit = g_EntityFuncs.Instance( tr.pHit );
				if ( pHit is null || pHit.IsBSPModel() == true )
					g_Utility.FindHullIntersection( vecSrc, tr, tr, VEC_DUCK_HULL_MIN, VEC_DUCK_HULL_MAX, m_pPlayer.edict() );
				vecEnd = tr.vecEndPos;	// This is the point on the actual surface (the hull could have hit space)
			}
		}

		if ( tr.flFraction >= 1.0 )
		{
			// miss
			self.SendWeaponAnim( SPEAR_STAB_MISS );
			
			self.m_flNextPrimaryAttack = g_Engine.time + 0.7;
			// play wiff or swish sound
			g_SoundSystem.EmitSoundDyn( m_pPlayer.edict(), CHAN_WEAPON, "aomdc/weapons/spear/spear_miss.wav", 1, ATTN_NORM, 0, 94 + Math.RandomLong( 0,0xF ) );
			// player "shoot" animation
			m_pPlayer.SetAnimation( PLAYER_ATTACK1 );
		}
		else
		{
			// hit
			fDidHit = true;
			
			// The entity we hit
			CBaseEntity@ pEntity = g_EntityFuncs.Instance( tr.pHit );

			self.SendWeaponAnim( SPEAR_STAB );

			// player "shoot" animation
			m_pPlayer.SetAnimation( PLAYER_ATTACK1 ); 

			// AdamR: Custom damage option
			float flDamage = 158;
			if ( self.m_flCustomDmg > 0 )
				flDamage = self.m_flCustomDmg;
			// AdamR: End

			g_WeaponFuncs.ClearMultiDamage();
			if ( self.m_flNextPrimaryAttack + 1 < g_Engine.time )
			{
				// first swing does full damage
				pEntity.TraceAttack( m_pPlayer.pev, flDamage, g_Engine.v_forward, tr, DMG_CLUB );  
			}
			else
			{
				// subsequent swings do 50% (Changed -Sniper) (Half)
				pEntity.TraceAttack( m_pPlayer.pev, flDamage * 0.5, g_Engine.v_forward, tr, DMG_CLUB );  
			}	
			g_WeaponFuncs.ApplyMultiDamage( m_pPlayer.pev, m_pPlayer.pev );

			//m_flNextPrimaryAttack = gpGlobals->time + 0.30; //0.25

			// play thwack, smack, or dong sound
			float flVol = 1.0;
			bool fHitWorld = true;

			if( pEntity !is null )
			{
				self.m_flNextPrimaryAttack = g_Engine.time + 0.9; //0.25
				
				/*
					TODO: Is entity electrecuted?
						If true
							Play 'Electrecuted' animation and sound
							Player is already getting hurt from the trigger
						If false
							Stabby stab
				*/

				if( pEntity.Classify() != CLASS_NONE && pEntity.Classify() != CLASS_MACHINE && pEntity.BloodColor() != DONT_BLEED )
				{
	// aone
					if( pEntity.IsPlayer() == true )		// lets pull them
					{
						pEntity.pev.velocity = pEntity.pev.velocity + ( self.pev.origin - pEntity.pev.origin ).Normalize() * 120;
					}
	// end aone
					// play thwack or smack sound
					g_SoundSystem.EmitSound( m_pPlayer.edict(), CHAN_WEAPON, "aomdc/weapons/spear/spear_hitbody.wav", 1, ATTN_NORM );
					m_pPlayer.m_iWeaponVolume = 128; 
					
					if( pEntity.IsAlive() == false )
					{
						SetThink( ThinkFunction( this.NoPulling ) );
						self.pev.nextthink = g_Engine.time + 1.2;
						return true;
					}
					else
						flVol = 0.1;

					fHitWorld = false;
				}
			}

			// play texture hit sound
			// UNDONE: Calculate the correct point of intersection when we hit with the hull instead of the line

			if( fHitWorld == true )
			{
				float fvolbar = g_SoundSystem.PlayHitSound( tr, vecSrc, vecSrc + ( vecEnd - vecSrc ) * 2, BULLET_PLAYER_CUSTOMDAMAGE );
				
				self.m_flNextPrimaryAttack = g_Engine.time + 1.08; //0.25
				
				// override the volume here, cause we don't play texture sounds in multiplayer, 
				// and fvolbar is going to be 0 from the above call.

				fvolbar = 1;

				// also play crowbar strike
				g_SoundSystem.EmitSoundDyn( m_pPlayer.edict(), CHAN_WEAPON, "aomdc/weapons/spear/spear_hit.wav", fvolbar, ATTN_NORM, 0, 98 + Math.RandomLong( 0, 3 ) );
			}

			// delay the decal a bit
			m_trHit = tr;
			SetThink( ThinkFunction( this.Smack ) );
			self.pev.nextthink = g_Engine.time + 0.2;

			m_pPlayer.m_iWeaponVolume = int( flVol * 512 ); 
		}
		
		// Lets wait until we can attack again
		SetThink( ThinkFunction( this.NoPulling ) );
		self.pev.nextthink = g_Engine.time + 1.2;
		
		return fDidHit;
	}

	void NoPulling()
	{
		// We are no longer pulling back
		m_IsPullingBack = false;
	}
}

string GetWeaponName_AOMSPEAR()
{
	return "weapon_spear";
}

void Registerweapon_SPEAR()
{
	g_CustomEntityFuncs.RegisterCustomEntity( "weapon_spear", GetWeaponName_AOMSPEAR() );
	g_ItemRegistry.RegisterWeapon( GetWeaponName_AOMSPEAR(), "aom_weapons" );
}
