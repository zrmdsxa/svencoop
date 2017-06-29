enum hammer_e
{
	HAMMER_IDLE = 0,
	HAMMER_IDLE2,
	HAMMER_IDLE3,
	HAMMER_DRAW,
	HAMMER_HOLSTER,
	HAMMER_ATTACK1HIT,
	HAMMER_ATTACK1MISS,
	HAMMER_ATTACK2MISS,
	HAMMER_ATTACK2HIT,
	HAMMER_ATTACK3MISS,
	HAMMER_ATTACK3HIT,
	HAMMER_SPECIAL_BACK,
	HAMMER_SPECIAL_HIT,
	HAMMER_SPECIAL_MISS,
	HAMMER_SPECIAL_LOOP
};

class weapon_hammer : ScriptBasePlayerWeaponEntity
{
	private CBasePlayer@ m_pPlayer = null;
	bool m_IsPullingBack = false;
	int m_iSwing;
	TraceResult m_trHit;
	
	void Spawn()
	{
		Precache();
		g_EntityFuncs.SetModel( self, self.GetW_Model( "models/aomdc/weapons/hammer/w_hammer.mdl") );
		self.m_iClip			= -1;
		self.m_flCustomDmg		= self.pev.dmg;

		self.FallInit();// get ready to fall down.
	}

	void Precache()
	{
		self.PrecacheCustomModels();

		g_Game.PrecacheModel( "models/aomdc/weapons/hammer/v_hammer.mdl" );
		g_Game.PrecacheModel( "models/aomdc/weapons/hammer/w_hammer.mdl" );
		g_Game.PrecacheModel( "models/aomdc/weapons/hammer/p_hammer.mdl" );

		g_SoundSystem.PrecacheSound( "aomdc/weapons/hammer/hammer_hitbody.wav" );
		g_SoundSystem.PrecacheSound( "aomdc/weapons/hammer/hammer_hit.wav" );
		g_SoundSystem.PrecacheSound( "aomdc/weapons/hammer/hammer_miss.wav" );
	}

	bool GetItemInfo( ItemInfo& out info )
	{
		info.iMaxAmmo1		= -1;
		info.iMaxAmmo2		= -1;
		info.iMaxClip		= WEAPON_NOCLIP;
		info.iSlot			= 0;
		info.iPosition		= 7;
		info.iWeight		= 0;
		return true;
	}

	bool AddToPlayer( CBasePlayer@ pPlayer )
	{
		if( !BaseClass.AddToPlayer( pPlayer ) )
			return false;
			
		@m_pPlayer = pPlayer;

		return true;
	}
	
	bool Deploy()
	{
		return self.DefaultDeploy( self.GetV_Model( "models/aomdc/weapons/hammer/v_hammer.mdl" ), self.GetP_Model( "models/aomdc/weapons/hammer/p_hammer.mdl" ), HAMMER_DRAW, "crowbar" );
	}

	void PrimaryAttack()
	{
		if( !m_IsPullingBack && Swing( 1 ) == false )
		{
			SetThink( ThinkFunction( this.SwingAgain ) );
			self.pev.nextthink = g_Engine.time + 0.5;
		}
	}
	
	void SecondaryAttack()
	{
		if( !m_IsPullingBack )
		{
			// We don't want the player to break/stop the animation or sequence.
			m_IsPullingBack = true;
			
			// We are pulling back our hammer
			self.SendWeaponAnim( HAMMER_SPECIAL_BACK, 0, 0 );
			
			// Lets wait for the 'heavy smack'
			SetThink( ThinkFunction( this.DoHeavyAttack ) );
			self.pev.nextthink = g_Engine.time + 1.0;
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
		Vector vecEnd	= vecSrc + g_Engine.v_forward * 32;

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
			self.SendWeaponAnim( HAMMER_SPECIAL_MISS );
			
			self.m_flNextPrimaryAttack = g_Engine.time + 0.7;
			// play wiff or swish sound
			g_SoundSystem.EmitSoundDyn( m_pPlayer.edict(), CHAN_WEAPON, "aomdc/weapons/hammer/hammer_miss.wav", 1, ATTN_NORM, 0, 94 + Math.RandomLong( 0,0xF ) );
			// player "shoot" animation
			m_pPlayer.SetAnimation( PLAYER_ATTACK1 );
		}
		else
		{
			// hit
			fDidHit = true;
			
			CBaseEntity@ pEntity = g_EntityFuncs.Instance( tr.pHit );

			self.SendWeaponAnim( HAMMER_SPECIAL_HIT );

			// player "shoot" animation
			m_pPlayer.SetAnimation( PLAYER_ATTACK1 ); 

			// AdamR: Custom damage option
			float flDamage = 85;
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

				if( pEntity.Classify() != CLASS_NONE && pEntity.Classify() != CLASS_MACHINE && pEntity.BloodColor() != DONT_BLEED )
				{
	// aone
					if( pEntity.IsPlayer() == true )		// lets pull them
					{
						pEntity.pev.velocity = pEntity.pev.velocity + ( self.pev.origin - pEntity.pev.origin ).Normalize() * 120;
					}
	// end aone
					// play thwack or smack sound
					switch( Math.RandomLong( 0, 2 ) )
					{
					case 0:
						g_SoundSystem.EmitSound( m_pPlayer.edict(), CHAN_WEAPON, "aomdc/weapons/hammer/hammer_hitbody.wav", 1, ATTN_NORM ); break;
					case 1:
						g_SoundSystem.EmitSound( m_pPlayer.edict(), CHAN_WEAPON, "aomdc/weapons/hammer/hammer_hitbody.wav", 1, ATTN_NORM ); break;
					case 2:
						g_SoundSystem.EmitSound( m_pPlayer.edict(), CHAN_WEAPON, "aomdc/weapons/hammer/hammer_hitbody.wav", 1, ATTN_NORM ); break;
					}
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
				switch( Math.RandomLong( 0, 1 ) )
				{
				case 0:
					g_SoundSystem.EmitSoundDyn( m_pPlayer.edict(), CHAN_WEAPON, "aomdc/weapons/hammer/hammer_hit.wav", fvolbar, ATTN_NORM, 0, 98 + Math.RandomLong( 0, 3 ) ); 
					break;
				case 1:
					g_SoundSystem.EmitSoundDyn( m_pPlayer.edict(), CHAN_WEAPON, "aomdc/weapons/hammer/hammer_hit.wav", fvolbar, ATTN_NORM, 0, 98 + Math.RandomLong( 0, 3 ) ); 
					break;
				}
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

	void SwingAgain()
	{
		Swing( 0 );
	}

	bool Swing( int fFirst )
	{
		bool fDidHit = false;

		TraceResult tr;

		Math.MakeVectors( m_pPlayer.pev.v_angle );
		Vector vecSrc	= m_pPlayer.GetGunPosition();
		Vector vecEnd	= vecSrc + g_Engine.v_forward * 32;

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
			if( fFirst != 0 )
			{
				// miss
				switch( ( m_iSwing++ ) % 3 )
				{
				case 0:
					self.SendWeaponAnim( HAMMER_ATTACK1MISS ); break;
				case 1:
					self.SendWeaponAnim( HAMMER_ATTACK2MISS ); break;
				case 2:
					self.SendWeaponAnim( HAMMER_ATTACK3MISS ); break;
				}
				self.m_flNextPrimaryAttack = g_Engine.time + 0.7;
				// play wiff or swish sound
				g_SoundSystem.EmitSoundDyn( m_pPlayer.edict(), CHAN_WEAPON, "aomdc/weapons/hammer/hammer_miss.wav", 1, ATTN_NORM, 0, 94 + Math.RandomLong( 0,0xF ) );

				// player "shoot" animation
				m_pPlayer.SetAnimation( PLAYER_ATTACK1 ); 
			}
		}
		else
		{
			// hit
			fDidHit = true;
			
			CBaseEntity@ pEntity = g_EntityFuncs.Instance( tr.pHit );

			switch( ( ( m_iSwing++ ) % 2 ) + 1 )
			{
			case 0:
				self.SendWeaponAnim( HAMMER_ATTACK1HIT ); break;
			case 1:
				self.SendWeaponAnim( HAMMER_ATTACK2HIT ); break;
			case 2:
				self.SendWeaponAnim( HAMMER_ATTACK3HIT ); break;
			}

			// player "shoot" animation
			m_pPlayer.SetAnimation( PLAYER_ATTACK1 ); 

			// AdamR: Custom damage option
			float flDamage = 35;
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

				if( pEntity.Classify() != CLASS_NONE && pEntity.Classify() != CLASS_MACHINE && pEntity.BloodColor() != DONT_BLEED )
				{
	// aone
					if( pEntity.IsPlayer() == true )		// lets pull them
					{
						pEntity.pev.velocity = pEntity.pev.velocity + ( self.pev.origin - pEntity.pev.origin ).Normalize() * 120;
					}
	// end aone
					// play thwack or smack sound
					switch( Math.RandomLong( 0, 2 ) )
					{
					case 0:
						g_SoundSystem.EmitSound( m_pPlayer.edict(), CHAN_WEAPON, "aomdc/weapons/hammer/hammer_hitbody.wav", 1, ATTN_NORM ); break;
					case 1:
						g_SoundSystem.EmitSound( m_pPlayer.edict(), CHAN_WEAPON, "aomdc/weapons/hammer/hammer_hitbody.wav", 1, ATTN_NORM ); break;
					case 2:
						g_SoundSystem.EmitSound( m_pPlayer.edict(), CHAN_WEAPON, "aomdc/weapons/hammer/hammer_hitbody.wav", 1, ATTN_NORM ); break;
					}
					m_pPlayer.m_iWeaponVolume = 128; 
					if( pEntity.IsAlive() == false )
						return true;
					else
						flVol = 0.1;

					fHitWorld = false;
				}
			}

			// play texture hit sound
			// UNDONE: Calculate the correct point of intersection when we hit with the hull instead of the line

			if( fHitWorld == true )
			{
				float fvolbar = g_SoundSystem.PlayHitSound( tr, vecSrc, vecSrc + ( vecEnd - vecSrc ) * 2, BULLET_PLAYER_CROWBAR );
				
				self.m_flNextPrimaryAttack = g_Engine.time + 1.08; //0.25
				
				// override the volume here, cause we don't play texture sounds in multiplayer, 
				// and fvolbar is going to be 0 from the above call.

				fvolbar = 1;

				// also play crowbar strike
				switch( Math.RandomLong( 0, 1 ) )
				{
				case 0:
					g_SoundSystem.EmitSoundDyn( m_pPlayer.edict(), CHAN_WEAPON, "aomdc/weapons/hammer/hammer_hit.wav", fvolbar, ATTN_NORM, 0, 98 + Math.RandomLong( 0, 3 ) ); 
					break;
				case 1:
					g_SoundSystem.EmitSoundDyn( m_pPlayer.edict(), CHAN_WEAPON, "aomdc/weapons/hammer/hammer_hit.wav", fvolbar, ATTN_NORM, 0, 98 + Math.RandomLong( 0, 3 ) ); 
					break;
				}
			}

			// delay the decal a bit
			m_trHit = tr;
			SetThink( ThinkFunction( this.Smack ) );
			self.pev.nextthink = g_Engine.time + 0.2;

			m_pPlayer.m_iWeaponVolume = int( flVol * 512 ); 
		}
		return fDidHit;
	}
}

string GetWeaponName_AOMHAMMER()
{
	return "weapon_hammer";
}

void RegisterWeapon_HAMMER()
{
	g_CustomEntityFuncs.RegisterCustomEntity( "weapon_hammer", GetWeaponName_AOMHAMMER() );
	g_ItemRegistry.RegisterWeapon( GetWeaponName_AOMHAMMER(), "aom_weapons" );
}
