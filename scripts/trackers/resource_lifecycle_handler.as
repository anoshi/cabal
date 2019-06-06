// internal
#include "tracker.as"
#include "time_announcer_task.as"
// --------------------------------------------


// --------------------------------------------
class ResourceLifecycleHandler : Tracker {
	Cabal@ m_metagame;

	protected int m_playerCharacterId;
    protected float m_localPlayerCheckTimer;
    protected float LOCAL_PLAYER_CHECK_TIME = 5.0;

	protected float MIN_GOAL_XP = 3.0;
	protected float MAX_GOAL_XP = 5.0;
	protected float goalXP = rand(MIN_GOAL_XP, MAX_GOAL_XP);
	protected float curXP = 0.0;
	protected int player1Lives = 3;
	protected int player2Lives = 3; // placeholder. Will be handy when coop mode is implemented

	protected bool levelComplete;

	// ----------------------------------------------------
	ResourceLifecycleHandler(Cabal@ metagame) {
		@m_metagame = @metagame;
		levelComplete = false;
        // enable character_die tracking for cabal game mode (off by default)
        string trackCharDeath = "<command class='set_metagame_event' name='character_die' enabled='1' />";
        m_metagame.getComms().send(trackCharDeath);
	}

	/////////////////////////////////
	// PLAYER CHARACTER LIFECYCLES //
	/////////////////////////////////
    protected void handlePlayerSpawnEvent(const XmlElement@ event) {
		_log("*** CABAL: ResourceLifecycleHandler::handlePlayerSpawnEvent", 1);

		// how can this be improved to support 2-player co-op play?
		// currently falls apart if a second player were to spawn.

		// when the player spawns, he spawns alone...
		XmlElement c("command");
		c.setStringAttribute("class", "set_soldier_spawn");
		c.setIntAttribute("faction_id", 0);
		c.setBoolAttribute("enabled", false);
		m_metagame.getComms().send(c);

		// now, work with the spawned player character
		const XmlElement@ player = event.getFirstElementByTagName("player");
		if (player !is null) {
			string name = player.getStringAttribute("name");
			_log("*** CABAL: player " + name + " spawned.", 1);
			m_playerCharacterId = player.getIntAttribute("character_id");
			_log("*** CABAL: player character id is: " + m_playerCharacterId, 1);

			// assign / override equipment to player character
			XmlElement charInv("command");
			charInv.setStringAttribute("class", "update_inventory");

			charInv.setIntAttribute("character_id", m_playerCharacterId);
			charInv.setIntAttribute("container_type_id", 4); // vest
			{
				XmlElement i("item");
				i.setStringAttribute("class", "carry_item");
				i.setStringAttribute("key", "player_impervavest.carry_item"); // oh yeah a nasty hack for tests
				// i.setStringAttribute("key", "player_vest1.carry_item");
				charInv.appendChild(i);
			}
			m_metagame.getComms().send(c);
		} else {
			_log("*** CABAL: CRITICAL WARNING, player not found in Player Spawn Event");
		}
	}

	// ----------------------------------------------------
	protected void handlePlayerDieEvent(const XmlElement@ event) {
		_log("*** CABAL: ResourceLifecycleHandler::handlePlayerDieEvent", 1);

		// level already won/lost? bug out
		if (levelComplete) {
			return;
		}

		// decrement lives left
		_log("*** CABAL: Player 1 lost a life!", 1);
		player1Lives -= 1;

		if (player1Lives <= 0) {
			_log("*** CABAL: GAME OVER for Player 1", 1);
			if (player2Lives <= 0) {
				_log("*** GAME OVER!", 1);
				processGameOver();
			}
		} else if (player2Lives <= 0) {
			_log("*** CABAL: GAME OVER for Player 2", 1);
			if (player1Lives <= 0) {
				_log("*** GAME OVER!", 1);
				processGameOver();
			}
		}

		// tidy up assets

		// reset stuffs as required
	}

	// ----------------------------------------------------
	protected void processGameOver() {
		if (levelComplete) return;

		{
			XmlElement c("command");
			c.setStringAttribute("class", "set_soldier_spawn");
			c.setIntAttribute("faction_id", 0);
			c.setBoolAttribute("enabled", false);
			m_metagame.getComms().send(c);
		}
		for (uint i = 0; i < m_metagame.getFactionCount(); ++i) {
			XmlElement comm("command");
			comm.setStringAttribute("class", "set_match_status");
			if (i == 1) {
				comm.setIntAttribute("win", 1);
			} else {
				comm.setIntAttribute("lose", 1);
			}
			comm.setIntAttribute("faction_id", i);
			m_metagame.getComms().send(comm);
		}

		levelComplete = true;
	}

	// ----------------------------------------------------
	protected void ensureValidLocalPlayer(float time) {
		if (m_playerCharacterId < 0) {
			m_localPlayerCheckTimer -= time;
			_log("*** CABAL: m_local_PlayerCheckTimer: " + m_localPlayerCheckTimer,1);
			if (m_localPlayerCheckTimer < 0.0) {
				_log("*** CABAL: tracked player character id " + m_playerCharacterId, 1);
				const XmlElement@ player = m_metagame.queryLocalPlayer();
				if (player !is null) {
					//setupCharacterForTracking
				} else {
					_log("WARNING, local player query failed", -1);
				}
				m_localPlayerCheckTimer = LOCAL_PLAYER_CHECK_TIME;
			}
		}
	}

	//////////////////////////////
	// ALL CHARACTER LIFECYCLES //
	//////////////////////////////
    protected void handleCharacterDieEvent(const XmlElement@ event) {
		// TagName					string (character_die)
		// character_id				int (character who died)

		// TagName					string (character)
		// id						int (dead character's id)
		// name						string (First Last)
		// position					string (xxx.xxx yy.yyy zzz.zzz)
		// block					string (AA BB)
		// dead						int (0 / 1)
		// wounded					int (0 / 1)
		// faction_id				int (0 .. num factions -1)
		// xp						real
		// rp						int
		// leader					int (0 / 1)
		// player_id				int (-1 (not a player), 0 (a player))

        _log("*** CABAL: handleCharacterDieEvent fired!", 1);
		// if it's the player character, don't process any further
		if (event.getIntAttribute("player_id") >= 0) {
			_log("*** CABAL: dead character is a player. Has separate handler method", 1);
			return;
		}

		int charId = event.getIntAttribute("character_id");
		const XmlElement@ deadCharInfo = event.getFirstElementByTagName("character");

		// make sure they're dead (sanity)
		if (deadCharInfo.getIntAttribute("dead") != 1) {
			_log("*** CABAL: character is not dead. Ignoring", 1);
			return;
		}

        // _log("*** CABAL: store details of dead character " + charId, 1);
		charId = deadCharInfo.getIntAttribute("id");
		string charName = deadCharInfo.getStringAttribute("name");
        string charPos = deadCharInfo.getStringAttribute("position");
		Vector3 v3charPos = stringToVector3(charPos);

		string charBlock = deadCharInfo.getStringAttribute("block");
		int charFactionId = deadCharInfo.getIntAttribute("faction_id");

		float charXP = deadCharInfo.getFloatAttribute("xp");
		int charRP = deadCharInfo.getIntAttribute("rp");
		int charLeader = deadCharInfo.getIntAttribute("leader");
		_log("*** CABAL: Character " + charId + " (" + charName + "), with " + charXP + " XP, has died.", 1);

		// add enemy's XP to total score for level
		approachGoalXP(charXP);

		// _log("*** CABAL: store player character's info", 1);
		const XmlElement@ playerInfo = getPlayerInfo(m_metagame, 0); // this may not work in all cases. Coop: player IDs?
		int playerCharId = playerInfo.getIntAttribute("character_id");
		const XmlElement@ playerCharInfo = getCharacterInfo(m_metagame, playerCharId);
		string playerPos = playerCharInfo.getStringAttribute("position");
        _log("*** CABAL: Player Character id: " + m_playerCharacterId + " is at: " + playerPos);
		Vector3 v3playerPos = stringToVector3(playerPos);

		// create a new Vector3 as (enemyX, playerY +2, playerZ)
		float retX = v3charPos.get_opIndex(0);
        float retY = v3playerPos.get_opIndex(1) + 2.0;
        float retZ = v3playerPos.get_opIndex(2);
        Vector3 dropPos = Vector3(retX, retY, retZ);

		// based on these details, set a probability for a weapon/power-up/etc. to spawn
		if (charLeader == 1) { // artificially bump XP for greater chance of drop and reward when a squad leader dies
			charXP += 0.2;
		}

		// XP-based drop chance logic
		if (charXP > 1.0) {
			dropPowerUp(dropPos.toString(), "weapon", "player_gl.weapon"); // drop grenade launcher.
		} else if (charXP > 0.8) {
			dropPowerUp(dropPos.toString(), "weapon", "player_mg.weapon"); // drop minigun
		} else if (charXP > 0.6) {
			dropPowerUp(dropPos.toString(), "weapon", "player_mg.weapon"); // drop lmg
		} else if (charXP > 0.4) {
			dropPowerUp(dropPos.toString(), "weapon", "player_sg.weapon"); // drop shotgun
		} else if (charXP > 0.2) {
			dropPowerUp(dropPos.toString(), "grenade", "grenadier_he.projectile"); // drop grenade
		}
		// revert to default weapon after X seconds have elapsed...
		else {
			_log("*** CABAL: XP too low, Nothing dropped", 1);
		}
	}

	///////////////////
	// MAP LIFECYCLE //
	///////////////////
	protected void approachGoalXP(float charXP) {
		if (levelComplete) {
			return;
		}
		curXP += charXP;
		_log("*** CABAL: current XP is: " + int(curXP) + " of " + int(goalXP), 1);
		_log("*** CABAL: Level completion: " + int(curXP / goalXP * 100) + "%", 1);
		string statusReport = "<command class='notify' text='" + "Level completion: " + int(curXP / goalXP * 100) + "%' />";
		m_metagame.getComms().send(statusReport);
		if (curXP >= goalXP) {
			_log("*** CABAL: LEVEL COMPLETE!", 1);
			m_metagame.getComms().send("<command class='set_match_status' faction_id='1' lose='1' />");
			m_metagame.getComms().send("<command class='set_match_status' faction_id='0' win='1' />");
			levelComplete = true;
		}
	}

	protected void handleMatchEndEvent(const XmlElement@ event) {
		m_metagame.getTaskSequencer().add(TimeAnnouncerTask(m_metagame, 15.0, true));
		// Clear the battlefield
		// _log("*** CABAL: removing dead characters from play", 1);
		// kill the player character
		_log("*** CABAL: quickmatch restarting. Killing player", 1);
		string killChar = "<command class='update_character' id='" + m_playerCharacterId + "' dead='1' /></command>";
		m_metagame.getComms().send(killChar);
		levelComplete = false;
		m_metagame.getTaskSequencer().add(Call(CALL(m_metagame.requestRestart)));
	}

	////////////////////////
	// VEHICLE LIFECYCLES //
	////////////////////////
	protected void handleVehicleDestroyEvent(const XmlElement@ event) {
		// in this game mode, all vehicles spawn a dummy vehicle (with 0 ttl) when destroyed
		// this allows us to group large numbers of vehicles into sets, and issue rewards according to the vehicle's difficulty

		// we are only interested in the destruction of dummy vehicles
        if (startsWith(event.getStringAttribute("vehicle_key"), "dummy_")) {
            _log("*** CABAL: DummyVehicleHandler going to work!", 1);
			if (event.getIntAttribute("owner_id") == 0) { return; } // don't care about player's faction vehicles.
			// variablise attributes
			string vehKey = event.getStringAttribute("vehicle_key");
			string vehPosi = event.getStringAttribute("position");
            Vector3 v3Posi = stringToVector3(vehPosi);

			// identify the dummy vehicle and process accordingly
            if (vehKey == "dummy_terminal.vehicle") {
                _log("*** CABAL: Terminal at " + vehPosi + " has been activated... Locating nearby equipment", 1);
            } else if (vehKey == "dummy_next.vehicle") {
				// do stuff
			} // etc.
        }
    }

	/////////////////////////
	// POWERUP DISTRIBUTOR //
	/////////////////////////
	protected void dropPowerUp(string position, string instanceClass, string instanceKey) {
		// between the invisible walls the the player character is locked within (enemyX, playerY+2, playerZ)
		if (levelComplete) {
			return;
		}
        _log("*** CABAL: dropping an item at " + position, 1);
        string creator = "<command class='create_instance' faction_id='0' position='" + position + "' instance_class='" + instanceClass + "' instance_key='" + instanceKey + "' activated='0' />";
        m_metagame.getComms().send(creator);
		_log("*** CABAL: item placed at " + position, 1);

		// ensure all dropped items have a short TTL e.g 5 seconds
        // ensure only rare weapons are dropped
	}

	// --------------------------------------------
	bool hasStarted() const { return true; }

	// --------------------------------------------
	bool hasEnded() const { return false; }

    // ----------------------------------------------------
    void update(float time) {
        ensureValidLocalPlayer(time);
		// updateScoreBoard(); // if managing hud overlay is possible
    }
}