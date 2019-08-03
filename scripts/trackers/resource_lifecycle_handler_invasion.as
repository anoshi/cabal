// internal
#include "tracker.as"
#include "cabal_helpers.as"
#include "gamemode_invasion.as"
// --------------------------------------------


// --------------------------------------------
class ResourceLifecycleHandler : Tracker {
	GameModeInvasion@ m_metagame;

	protected int m_playerCharacterId;
	protected array<string> m_playersSpawned;

    protected float m_localPlayerCheckTimer;
    protected float LOCAL_PLAYER_CHECK_TIME = 5.0;

	protected float MIN_SPAWN_X = 530.395; // Left-most X coord within player spawn area
	protected float MAX_SPAWN_X = 545.197; // Right-most X coord within player spawn area
	protected float MIN_GOAL_XP = 4.0;
	protected float MAX_GOAL_XP = 6.0;
	protected float goalXP = rand(MIN_GOAL_XP, MAX_GOAL_XP);
	protected float curXP = 0.0;

	protected int playerCoins = 3; // coins / restart level attempts left
	protected int player1Lives = 3;
	protected int player2Lives = 3; // placeholder. Will be handy when coop mode is implemented

	protected bool levelComplete;

	// ----------------------------------------------------
	ResourceLifecycleHandler(GameModeInvasion@ metagame) {
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
			string playerHash = player.getStringAttribute("profile_hash");
			int characterId = player.getIntAttribute("character_id");
			if (m_playersSpawned.find(playerHash) < 0) {
				if (int(m_playersSpawned.size()) < m_metagame.getUserSettings().m_maxPlayers) {
					string name = player.getStringAttribute("name");
					m_playerCharacterId = characterId;
					m_playersSpawned.insertLast(playerHash);
					_log("*** CABAL: player " + name + " (" + m_playerCharacterId + ") spawned as player" + int(m_playersSpawned.size()), 1);
				} else {
					kickPlayer(player.getIntAttribute("player_id"), "Only " + m_metagame.getUserSettings().m_maxPlayers + " players allowed");
				}
			} else {
				// existing player.
				_log("*** CABAL: existing player spawned", 1);
			}

			// TEST PURPOSES: add cheat vest
			setPlayerInventory(m_metagame, characterId);

			_log("*** CABAL: spawning enemies", 1);
			// start enemy spawning from specific locations (as per passed map layer name, for level)
			// after player character has spawned. i.e. no enemy spawn until player is on the map
			int m_spawnCount = 2;
			string m_genericNodeTag = "cabal_spawn";
			//string layerName = "layer1.map1";
			string layerName = "";
			array<const XmlElement@>@ nodes = getGenericNodes(m_metagame, layerName, m_genericNodeTag);

			_log("*** CABAL: Spawning " + m_spawnCount + " enemies at " + nodes.size() + " " + m_genericNodeTag + " points.", 1);
			for (int i = 0; i < m_spawnCount && nodes.size() > 0; ++i) {
				XmlElement command("command");
				command.setStringAttribute("class", "create_instance");
				command.setIntAttribute("faction_id", 1);
				command.setStringAttribute("instance_class", "character");
				command.setStringAttribute("instance_key", "rifleman");

				// logic to use each generic_node only once
				int index = rand(0, nodes.size() - 1);
				const XmlElement@ node = nodes[index];
				nodes.erase(index);

				// location and bearing of spawnpoint
				command.setStringAttribute("position", node.getStringAttribute("position"));
				command.setStringAttribute("orientation", node.getStringAttribute("orientation"));
				m_metagame.getComms().send(command);
			}
		} else {
			_log("*** CABAL: CRITICAL WARNING, player not found in Player Spawn Event");
		}
	}

	// ----------------------------------------------------
	protected void handlePlayerDieEvent(const XmlElement@ event) {
		_log("*** CABAL: ResourceLifecycleHandler::handlePlayerDieEvent", 1);

		// skip die event processing if disconnected
		if (event.getBoolAttribute("combat") == false) return;

		// level already won/lost? bug out
		if (levelComplete) {
			_log("*** CABAL: Level already won or lost. Dropping out of method", 1);
			return;
		}

		const XmlElement@ deadPlayer = event.getFirstElementByTagName("target");
		// use profile_hash stored in m_playersSpawned array to id which char died
		int playerCharId = deadPlayer.getIntAttribute("character_id");
		string playerHash = deadPlayer.getStringAttribute("profile_hash");
		int playerNum = m_playersSpawned.find(playerHash); // should return the index or negative if not found

		if (playerNum == 0) { // player 1
			// decrement lives left
			_log("*** CABAL: Player 1 lost a life!", 1);
			player1Lives -= 1;
		} else if (playerNum == 1) { // player 2
			_log("*** CABAL: Player 2 lost a life!", 1);
			player2Lives -= 1;
		} else {
			// profile_hash listed in event doesn't exist as an active player. Silently fail to do anything.
		}

		if (player1Lives <= 0) {
			_log("*** CABAL: GAME OVER for Player 1", 1);
			if ((int(m_playersSpawned.size()) <= 1) || (int(m_playersSpawned.size()) > 1 && player2Lives <= 0)) {
				_log("*** GAME OVER!", 1);
				processGameOver();
			}
		} else if (player2Lives <= 0) {
			_log("*** CABAL: GAME OVER for Player 2", 1);
			if ((int(m_playersSpawned.size()) <= 1) || (int(m_playersSpawned.size()) > 1 && player1Lives <= 0)) {
				_log("*** GAME OVER!", 1);
				processGameOver();
			}
		} else {
			_log("*** CABAL: Player" + (playerNum + 1) + " still has " + (playerNum > 0 ? player2Lives : player1Lives) + " lives available.", 1);

			// player can't respawn if enemies are within ~70.0 units of the intended base. Need to forcibly remove enemy
			// units from player's base area...
        	// We're about to kill a lot of people. Stop character_die tracking for the moment

        	string trackCharDeathOff = "<command class='set_metagame_event' name='character_die' enabled='0' />";
        	m_metagame.getComms().send(trackCharDeathOff);
			// kill enemies anywhere near player to allow respawn
			const XmlElement@ characterInfo = getCharacterInfo(m_metagame, playerCharId);
			if (characterInfo !is null) {
				_log("*** CABAL: Killing enemies near dead player character", 1);
				Vector3 position = stringToVector3(characterInfo.getStringAttribute("position"));

				// make an array of Xml Elements that stores affected enemy unit stats
				// TagName =character, id=xx (99)
				array<const XmlElement@> exchEnemies = getCharactersNearPosition(m_metagame, position, 1, 70.0f);
				int exchEnemiesCount = exchEnemies.size();
				// rewrite as new array where the position of each enemy has +70 to Z axis
				// or just get the size of the array, then queue that many random enemy respawns shortly

				// improve?: apply invisi-vest to characters in the kill zone to make them disappear, then kill them
				killCharactersNearPosition(m_metagame, position, 1, 70.0f); // kill faction 1 (cabal)

				// spawn enemies to replace the exchEnemies
				_log("*** CABAL: Respawning " + exchEnemiesCount + " replacement enemy units.", 1);
				string randKey = ''; // random character 'Key' name

				float retX = position.get_opIndex(0);
				float retY = position.get_opIndex(1);
				float retZ = position.get_opIndex(2) - 80.0;
				string randPos = Vector3(retX, retY, retZ).toString();
				for (int k = 0; k < exchEnemiesCount; ++k) {
					switch( rand(0, 5) )
						{ // 5 types of enemy units, weighted to return more base level soldiers
						case 0 :
						case 1 :
							randKey = "rifleman";
							break;
						case 2 :
						case 3 :
							randKey = "grenadier";
							break;
						case 4 :
							randKey = "covert_ops";
							break;
						case 5 :
							randKey = "commando";
							break;
						default:
							randKey = "rifleman";
						}
					string spawnReps = "<command class='create_instance' faction_id='1' position='" + randPos + "' instance_class='character' instance_key='" + randKey + "' /></command>";
					m_metagame.getComms().send(spawnReps);
					_log("*** CABAL: Spawned a character at " + randPos, 1);
				}
			}
			// Reenable character_die tracking
        	string trackCharDeathOn = "<command class='set_metagame_event' name='character_die' enabled='1' />";
        	m_metagame.getComms().send(trackCharDeathOn);

			// allow player to respawn
			XmlElement allowSpawn("command");
			allowSpawn.setStringAttribute("class", "set_soldier_spawn");
			allowSpawn.setIntAttribute("faction_id", 0);
			allowSpawn.setBoolAttribute("enabled", true);
			m_metagame.getComms().send(allowSpawn);

			//
		}
		// reset stuffs as required
	}

	// ----------------------------------------------------
	protected void processGameOver() {
		_log("*** CABAL: Running processGameOver", 1);
		if (levelComplete) return;
		// no more respawning allowed
		{
			XmlElement c("command");
			c.setStringAttribute("class", "set_soldier_spawn");
			c.setIntAttribute("faction_id", 0);
			c.setBoolAttribute("enabled", false);
			m_metagame.getComms().send(c);
		}
		// check if players still have some coins/continues? If so, can restart level
		if (playerCoins < 1) {
			playerCoins -= 1;
			m_metagame.getComms().send("<command class='set_match_status' lose='1' faction_id='0' />");
			m_metagame.getComms().send("<command class='set_match_status' win='1' faction_id='1' />");
		}
		else { // no coins / continues left, campaign lost / game over
			XmlElement c("command");
			c.setStringAttribute("class", "set_campaign_status");
			c.setStringAttribute("key", "lose");
			// delay this for 2-3 seconds. It's a little abrupt when you lose :-|
			//sleep(2); // will liekly need to code something into update function
			m_metagame.getComms().send(c);
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

	// --------------------------------------------
	protected void kickPlayer(int playerId, string text = "") {
		sendPrivateMessage(m_metagame, playerId, text);
		kickPlayerImpl(playerId);
	}

	// --------------------------------------------
	protected void kickPlayerImpl(int playerId) {
		string command = "<command class='kick_player' player_id='" + playerId + "' />";
		m_metagame.getComms().send(command);
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
		// soldier_group_name       string (anti_tank)
		// xp						real
		// rp						int
		// leader					int (0 / 1)
		// player_id				int (-1 (not a player), 0 (a player))

        _log("*** CABAL: handleCharacterDieEvent fired!", 1);
		// if it's the player character, don't process any further
		if (event.getIntAttribute("character_id") == m_playerCharacterId) {
			_log("*** CABAL: dead character id matches player character. Handled separately", 1);
			return;
		}

		int charId = event.getIntAttribute("character_id");
		const XmlElement@ deadCharInfo = event.getFirstElementByTagName("character");

		// if faction 0 (player), don't process further
		if (deadCharInfo.getIntAttribute("faction_id") == 0) {
			_log("*** CABAL: dead character id is from friendly faction. Ignoring", 1);
			return;
		}
		// make sure they're dead (sanity)
		if (deadCharInfo.getIntAttribute("dead") != 1) {
			_log("*** CABAL: character is not dead. Ignoring", 1);
			return;
		}

        // _log("*** CABAL: store details of dead character " + charId, 1);
		charId = deadCharInfo.getIntAttribute("id");
		string charName = deadCharInfo.getStringAttribute("name");

		// sanity sanity, to be sure to be sure.
		if (charName == "Player") {
			_log("*** CABAL: dead character name is 'Player'. Player deaths are handled elsewhere", 1);
			return;
		}

        string charPos = deadCharInfo.getStringAttribute("position");
		Vector3 v3charPos = stringToVector3(charPos);

		string charBlock = deadCharInfo.getStringAttribute("block");
		int charFactionId = deadCharInfo.getIntAttribute("faction_id");

		float charXP = deadCharInfo.getFloatAttribute("xp");
		int charRP = deadCharInfo.getIntAttribute("rp");
		int charLeader = deadCharInfo.getIntAttribute("leader");
		string charGroup = deadCharInfo.getStringAttribute("soldier_group_name");

		_log("*** CABAL: Character " + charId + " (" + charName + charGroup + "), with " + charXP + " XP, has died.", 1);

		// if commando killed, create a new one in wounded state
		if (charGroup == "commando") {
			string spawnChar = "<command class='update_character' id='" + charId + "' dead='0' wounded='1' /></command>";
			m_metagame.getComms().send(spawnChar);
			/*
			// let's try spawning a character instead
			_log("*** CABAL: enemy commando killed, Spawning a wounded replacement at " + charPos, 1);
			string spawnChar = "<command class='create_instance' faction_id='1' position='" + charPos + "' instance_class='character' instance_key='commando' wounded='1' /></command>";
			m_metagame.getComms().send(spawnChar);
			*/
			// Now spawn some medics off-screen to attempt a heal
		}

		// _log("*** CABAL: store player character's info", 1);
		const XmlElement@ playerInfo = getPlayerInfo(m_metagame, 0); // this may not work in all cases. Coop: player IDs?

		// Run an alive/dead check on Player character(s)
		int playerCharId = playerInfo.getIntAttribute("character_id");
		const XmlElement@ playerCharInfo = getCharacterInfo(m_metagame, playerCharId);
		int playerCharIsDead = playerCharInfo.getIntAttribute("dead");
		if (playerCharIsDead == 1) {
			_log("*** CABAL: Player character is dead. No rewards given");
			return;
		}

		// Player is alive and well. Add enemy's XP to total score for level
		approachGoalXP(charXP);

		string playerPos = playerCharInfo.getStringAttribute("position");
        _log("*** CABAL: Player Character id: " + m_playerCharacterId + " is at: " + playerPos);
		Vector3 v3playerPos = stringToVector3(playerPos);

		// create a new Vector3 as (enemyX, playerY +2, playerZ)
		float retX = v3charPos.get_opIndex(0);
		// if enemy X outside player spawn area X...
		if (retX < MIN_SPAWN_X) {
			retX = MIN_SPAWN_X + rand(1, 6);
		} else if (retX > MIN_SPAWN_X) {
			retX = MAX_SPAWN_X - rand(1, 6);
		}
        float retY = v3playerPos.get_opIndex(1) + 2.0;
        float retZ = v3playerPos.get_opIndex(2);
        Vector3 dropPos = Vector3(retX, retY, retZ);

		// based on these details, set a probability for a weapon/power-up/etc. to spawn
		if (charLeader == 1) { // artificially bump XP for greater chance of drop and reward when a squad leader dies
			charXP += 0.1;
		}

		// Group-based drop logic (special enemies always drop specific equipment on death)
		if (charGroup == "commando") {
			dropPowerUp(dropPos.toString(), "grenade", "player_grenade.projectile"); // drop grenade
		} else if (charGroup == "covert_ops") {
			dropPowerUp(dropPos.toString(), "weapon", "player_sg.weapon"); // drop shotgun
		} // XP-based drop chance logic
		else if (rand(1, 100) > 80) {
			if (charXP > 1.0) {
				dropPowerUp(dropPos.toString(), "weapon", "player_gl.weapon"); // drop grenade launcher.
			} else if (charXP > 0.8) {
				dropPowerUp(dropPos.toString(), "weapon", "player_mg.weapon"); // drop minigun
			} else if (charXP > 0.2) {
				dropPowerUp(dropPos.toString(), "grenade", "player_grenade.projectile"); // drop grenade
			}
			// revert to default weapon after X seconds have elapsed...
			else {
				_log("*** CABAL: XP too low, Nothing dropped", 1);
			}
		}
	}

	///////////////////////
	// POWERUP LIFECYCLE //
	///////////////////////
	protected void dropPowerUp(string position, string instanceClass, string instanceKey) {
		// between the invisible walls the the player character is locked within (enemyX, playerY+2, playerZ)
        _log("*** CABAL: dropping an item at " + position, 1);
        string creator = "<command class='create_instance' faction_id='0' position='" + position + "' instance_class='" + instanceClass + "' instance_key='" + instanceKey + "' activated='0' />";
        m_metagame.getComms().send(creator);
		_log("*** CABAL: item placed at " + position, 1);

		// ensure all dropped items have a short TTL e.g 5 seconds
        // ensure only player weapons are dropped
	}

	///////////////////
	// MAP LIFECYCLE //
	///////////////////
	protected void approachGoalXP(float charXP) {
		if (levelComplete) {
			return;
		}
		curXP += charXP;
		int levelCompletePercent = int(curXP / goalXP * 100);
		_log("*** CABAL: current XP is: " + int(curXP) + " of " + int(goalXP), 1);
		if (levelCompletePercent > 100) { levelCompletePercent = 100; }
		_log("*** CABAL: Level completion: " + levelCompletePercent + "%", 1);

		// notify text
		string statusReport = "<command class='notify' text='" + "Level completion: " + levelCompletePercent + "%' />";
		m_metagame.getComms().send(statusReport);

		// scoreboard text
		string levelCompleteText = "";
		for (int i = 0; i < levelCompletePercent / 3; ++i) {
			levelCompleteText += "\u0023"; // #
		}
		for (int j = levelCompletePercent / 3; j < 33; ++j) {
			levelCompleteText += "\u002D"; // -
		}
		string scoreBoardText = "<command class='update_score_display' id='0' text='ENEMY: " + levelCompleteText + "'></command>";
		m_metagame.getComms().send(scoreBoardText);

		if (curXP >= goalXP) {
			_log("*** CABAL: LEVEL COMPLETE!", 1);
			m_metagame.getComms().send("<command class='set_match_status' faction_id='1' lose='1' />");
			m_metagame.getComms().send("<command class='set_match_status' faction_id='0' win='1' />");
			levelComplete = true;
		}
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
            if (vehKey == "dummy_next.vehicle") {
				// do stuff
			} // etc.
        }
    }

	// --------------------------------------------
	bool hasStarted() const { return true; }

	// --------------------------------------------
	bool hasEnded() const { return false; }

    // ----------------------------------------------------
    void update(float time) {
        ensureValidLocalPlayer(time);
    }

	// ----------------------------------------------------
	void onRemove() {
		// clear spawn counting when removing tracker - happens at map change or restart
		m_playersSpawned.clear();
	}

	// ----------------------------------------------------
	void save(XmlElement@ root) {
		XmlElement@ parent = root;

		XmlElement subroot("resource_life_cycle_handler");

		for (uint i = 0; i < m_playersSpawned.size(); ++i) {
			XmlElement p("player");
			p.setStringAttribute("hash", m_playersSpawned[i]);
			subroot.appendChild(p);
		}

		parent.appendChild(subroot);
	}

	// ----------------------------------------------------
	void load(const XmlElement@ root) {
		m_playersSpawned.clear();
		const XmlElement@ subroot = root.getFirstElementByTagName("resource_life_cycle_handler");
		if (subroot !is null) {
			array<const XmlElement@> list = subroot.getElementsByTagName("player");
			for (uint i = 0; i < list.size(); ++i) {
				const XmlElement@ p = list[i];

				string hash = p.getStringAttribute("hash");

				m_playersSpawned.insertLast(hash);
			}
		}
	}
}
