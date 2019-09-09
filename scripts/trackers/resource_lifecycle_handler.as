// internal
#include "tracker.as"
#include "cabal_helpers.as"
// --------------------------------------------

// This tracker manages player and AI
// lifecycles in QUICKMATCH mode only

// --------------------------------------------
class ResourceLifecycleHandler : Tracker {
	Cabal@ m_metagame;

	protected int m_playerCharacterId;
	protected array<string> m_playersSpawned;			// stores the unique 'hash' for each active player
	protected array<uint> m_playerLives = {3,3};		// players 1 and 2 start with 3 lives each
	protected array<float> m_playerScore = {0.0, 0.0};	// players 1 and 2 start with no XP
	protected int playerCoins = 0; 						// no continues / restarts in quickmatch

  	protected float m_localPlayerCheckTimer;
  	protected float LOCAL_PLAYER_CHECK_TIME = 5.0;

	protected float MIN_SPAWN_X = 530.395; // Left-most X coord within player spawn area (see /maps/cabal/objects.svg)
	protected float MAX_SPAWN_X = 545.197; // Right-most X coord within player spawn area (see /maps/cabal/objects.svg)
	protected float MIN_GOAL_XP = 40.0;
	protected float MAX_GOAL_XP = 60.0;
	protected float goalXP = rand(MIN_GOAL_XP, MAX_GOAL_XP);
	protected float curXP = 0.0;

	protected bool levelComplete;
	protected bool gameOver;

	// ----------------------------------------------------
	ResourceLifecycleHandler(Cabal@ metagame) {
		@m_metagame = @metagame;
		levelComplete = false;
		gameOver = false;
    // enable character_kill tracking for cabal game mode (off by default)
    string trackCharKill = "<command class='set_metagame_event' name='character_kill' enabled='1' />";
		m_metagame.getComms().send(trackCharKill);
	}

	/////////////////////////////////
	// PLAYER CHARACTER LIFECYCLES //
	/////////////////////////////////
	protected void handlePlayerConnectEvent(const XmlElement@ event) {
		_log("** CABAL: Processing Player connect request", 1);

		// disallow player spawns while we prepare the playing field...
		letPlayerSpawn(false);

		const XmlElement@ connector = event.getFirstElementByTagName("player");
		string connectorHash = connector.getStringAttribute("profile_hash");
		if (m_playersSpawned.find(connectorHash) < 0) {
			_log("** CABAL: known player rejoining", 1);
			// kill bads near spawn
			clearSpawnArea();
		} else if (int(m_playersSpawned.size()) < 2) {
			_log("** CABAL: we still have room in server", 1);
			m_playersSpawned.insertLast(connectorHash);
			clearSpawnArea();
			goalXP += goalXP;
			approachGoalXP(0.0);
		}
	}

	// -----------------------------------------------------------
    protected void handlePlayerSpawnEvent(const XmlElement@ event) {
		_log("** CABAL: ResourceLifecycleHandler::handlePlayerSpawnEvent", 1);

		if (curXP < goalXP && !gameOver) {
			levelComplete = false;
		}

		// when the player spawns, he spawns alone...
		letPlayerSpawn(false);

		// now, work with the spawned player character
		const XmlElement@ player = event.getFirstElementByTagName("player");
		if (player !is null) {
			string playerHash = player.getStringAttribute("profile_hash");
			int characterId = player.getIntAttribute("character_id");
			if (m_playersSpawned.find(playerHash) < 0) {
				_log("** CABAL: Player hash " + playerHash + " not found in m_playersSpawned array.", 1);
				if (int(m_playersSpawned.size()) < 2) { //m_metagame.getUserSettings().m_maxPlayers) {
					string name = player.getStringAttribute("name");
					m_playerCharacterId = characterId;
					m_playersSpawned.insertLast(playerHash);
					_log("** CABAL: player " + name + " (" + m_playerCharacterId + ") spawned as player" + int(m_playersSpawned.size()), 1);
				} else {
					kickPlayer(player.getIntAttribute("player_id"), "Only 2 players allowed"); // "Only " + m_metagame.getUserSettings().m_maxPlayers + " players allowed");
				}
				_log("** CABAL: m_playersSpawned now stores: " + m_playersSpawned[0] + " for player1.", 1);
			} else {
				// existing player.
				_log("** CABAL: existing player spawned. Equipping coloured vest", 1);
			}

			// sometimes the player is spawning without a primary weapon.
			const XmlElement@ pSpawned = getCharacterInfo(m_metagame, characterId);
			string pPos = pSpawned.getStringAttribute("position");
			_log("** CABAL: Player Character id: " + m_playerCharacterId + " spawned at: " + pPos + ". Checking Inventory", 1);
			// get spawned player's inventory
			const XmlElement@ allInv = getPlayerInventory(m_metagame, characterId);
			// if no primary weapon (slot=0)
			array<const XmlElement@> pInv = allInv.getElementsByTagName("item");
			for (uint slot = 0; slot < pInv.size(); ++slot) {
				if (pInv[slot].getIntAttribute("slot") == 0) {
					if (pInv[slot].getStringAttribute("key") == "") {
						_log("** CABAL: Player spawned without a weapon. Spawning an assault rifle next to player", 1);
						Vector3 v3playerPos = stringToVector3(pPos);
						float retX = v3playerPos.get_opIndex(0) + 2.0;
						float retY = v3playerPos.get_opIndex(1) + 1.0;
						float retZ = v3playerPos.get_opIndex(2);
						Vector3 dropPos = Vector3(retX, retY, retZ);
						dropPowerUp(dropPos.toString(), "weapon", "player_ar.weapon");
					}
				}
			}

			_log("** CABAL: Equipping spawned player with appropriately-coloured vest", 1);
			// TEST PURPOSES: if cheat enabled, add cheat vest
			//if (cheatMode) {
			//	setPlayerInventory(m_metagame, characterId, "player_impervavest.carry_item");
			//}
			switch (m_playersSpawned.find(playerHash)) {
				// replace player's vest with a blank item first to stop stacking on existing player vests
				case 0:
				setPlayerInventory(m_metagame, characterId, "player_blank.carry_item", 1);
					setPlayerInventory(m_metagame, characterId, "player_blue.carry_item", m_playerLives[0]);
					break;
				case 1:
					setPlayerInventory(m_metagame, characterId, "player_blank.carry_item", 1);
					setPlayerInventory(m_metagame, characterId, "player_red.carry_item", m_playerLives[1]);
					break;
				default: // shouldn't ever get here, but sanity
					_log("** CABAL: WARNING existing player spanwed but profile hash not stored in m_playersSpawned array", 1);
			}
		} else {
			_log("** CABAL: CRITICAL WARNING, player not found in Player Spawn Event");
		}
	}

	// -----------------------------------------------------------
	protected void handlePlayerDieEvent(const XmlElement@ event) {
		_log("** CABAL: ResourceLifecycleHandler::handlePlayerDieEvent", 1);

		// skip die event processing if disconnected
		if (event.getBoolAttribute("combat") == false) return;

		// level already won/lost? bug out
		if (levelComplete) {
			_log("** CABAL: Level already won or lost. Dropping out of method", 1);
			return;
		}

		const XmlElement@ deadPlayer = event.getFirstElementByTagName("target");
		// use profile_hash stored in m_playersSpawned array to id which char died
		int playerCharId = deadPlayer.getIntAttribute("character_id");
		string playerHash = deadPlayer.getStringAttribute("profile_hash");
		int playerNum = m_playersSpawned.find(playerHash); // should return the index or negative if not found

		// lose a life
		switch (playerNum) {
			case 0 :
			case 1 :
				_log("** CABAL: Player " + (playerNum + 1) + " lost a life!", 1);
				if (m_playerLives[playerNum] > 0) {
					m_playerLives[playerNum] -= 1;
				}
				_log("** CABAL: Player " + (playerNum + 1) + " has " + (playerNum > 0 ? m_playerLives[1] : m_playerLives[0]) + " lives remaining.", 1);
				break;
			default :
				_log("** CABAL: Can't match profile_hash to a dead player character. No lives lost...");
				// profile_hash listed in event doesn't exist as an active player. Silently fail to do anything.
		}

		// check if any player has any lives remaining
		for (uint i = 0; i < m_playersSpawned.size(); ++ i) {
			if (m_playerLives[i] <= 0) {
				_log("** CABAL: GAME OVER for Player " + (i+1), 1); // can't actually stop one player from respawning. All or nothing
			}
		}
		if ((m_playersSpawned.size() == 1) && (m_playerLives[0] <= 0)) {
			_log("*** GAME OVER!", 1);
			processGameOver();
			return;
		} else if ((m_playersSpawned.size() == 2) && (m_playerLives[0] <= 0 && m_playerLives[1] <= 0)) {
			_log("*** GAME OVER!", 1);
			processGameOver();
			return;
		} else {
			_log("** CABAL: Saving Game", 1);
			m_metagame.save();
			clearSpawnArea();
		}
	}

	// --------------------------------------------
	protected void clearSpawnArea() {
		// player can't respawn if enemies are within ~70.0 units of the intended base. Need to forcibly remove enemy
		// units from player's base area...
		// We're about to kill a lot of people. Stop character_kill tracking for the moment
		string trackCharKillOff = "<command class='set_metagame_event' name='character_kill' enabled='0' />";
		m_metagame.getComms().send(trackCharKillOff);
		// kill enemies anywhere near player base to allow respawn
		Vector3 position = stringToVector3("538 0 615"); // TODO use base position instead of dodgy hard-code

		// make an array of Xml Elements that stores affected enemy units
		array<const XmlElement@> exchEnemies = getCharactersNearPosition(m_metagame, position, 1, 80.0f);
		int exchEnemiesCount = exchEnemies.size();

		// improve?: apply invisi-vest to characters in the kill zone to make them disappear, then kill them
		killCharactersNearPosition(m_metagame, position, 1, 80.0f); // kill faction 1 (cabal)

		// spawn enemies to replace the exchEnemies
		_log("** CABAL: Respawning " + exchEnemiesCount + " replacement enemy units.", 1);
		string randKey = ''; // random character 'Key' name

		float retX = position.get_opIndex(0);
		float retY = position.get_opIndex(1);
		float retZ = position.get_opIndex(2) - 90.0;
		string randPos = Vector3(retX, retY, retZ).toString(); // spawns all replacements in same place...
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
			_log("** CABAL: Spawned a character at " + randPos, 1);
		}

		// Reenable character_kill tracking
		string trackCharKillOn = "<command class='set_metagame_event' name='character_kill' enabled='1' />";
		m_metagame.getComms().send(trackCharKillOn);

		// allow player to respawn
		letPlayerSpawn(true);
	}

	// --------------------------------------------
	protected void processGameOver() {
		_log("** CABAL: Running processGameOver", 1);
		if (levelComplete) return;
		// stop cabal spawning
		m_metagame.removeTracker(CabalSpawner(m_metagame));
		// no more respawning allowed
		letPlayerSpawn(false);

		sleep(2.0f); // brief pause before delivering the bad news

		XmlElement comm("command");
		comm.setStringAttribute("class", "set_match_status");
		comm.setIntAttribute("lose", 1);
		comm.setIntAttribute("faction_id", 0);
		m_metagame.getComms().send(comm);
		gameOver = true;
	}

	// ----------------------------------------------------
	protected void ensureValidLocalPlayer(float time) {
		if (m_playerCharacterId < 0) {
			m_localPlayerCheckTimer -= time;
			_log("** CABAL: m_local_PlayerCheckTimer: " + m_localPlayerCheckTimer,1);
			if (m_localPlayerCheckTimer < 0.0) {
				_log("** CABAL: tracked player character id " + m_playerCharacterId, 1);
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
	protected void letPlayerSpawn(bool spawnAllowed) {
		XmlElement c("command");
		c.setStringAttribute("class", "set_soldier_spawn");
		c.setIntAttribute("faction_id", 0);
		c.setBoolAttribute("enabled", spawnAllowed);
		m_metagame.getComms().send(c);
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
	protected void handleCharacterKillEvent(const XmlElement@ event) {
    // When enabled, fires whenever an AI character is killed. Manually enabled via class constructor

		// TagName=character_kill
		// key= method_hint=blast

		// TagName=killer
		// block=15 18
		// dead=0
		// faction_id=0
		// id=1
		// leader=1
		// name=Player
		// player_id=0
		// position=538.973 14.7059 623.567
		// rp=0
		// soldier_group_name=default
		// wounded=0
		// xp=0 (real/float)

		// TagName=target
		// block=15 17
		// dead=0
		// faction_id=1
		// id=8
		// leader=0
		// name=Enemy
		// player_id=-1
		// position=537.541 14.7059 610.689
		// rp=0
		// soldier_group_name=rifleman
		// wounded=0
		// xp=0 (real/float)

		_log("** CABAL: ResourceLifecycleHandler::handleCharacterKillEvent", 1);

		// we are manually playing death sounds when an AI unit has been killed.
		string soundFilename = "die" + rand(1,7) + ".wav";
		playSound(m_metagame, soundFilename, 0);

		const XmlElement@ killerInfo = event.getFirstElementByTagName("killer");
		if (killerInfo is null) {
			_log("** CABAL: Can't determine killer. Ignoring death", 1);
			return;
		}
		const XmlElement@ targetInfo = event.getFirstElementByTagName("target");
		if (targetInfo is null) {
			_log("** CABAL: Can't determine killed unit. Ignoring death", 1);
			return;
		}

		// if a player character has died, don't process any further
		if (targetInfo.getIntAttribute("player_id") >= 0) {
			_log("** CABAL: dead character id is a player character. Handled separately", 1);
			return;
		}

		// if faction 0 (player), don't process further
		if (targetInfo.getIntAttribute("faction_id") == 0) {
			_log("** CABAL: dead character id is from friendly faction. Ignoring", 1);
			return;
		}

        // _log("** CABAL: store details of dead character " + charId, 1);
		int charId = targetInfo.getIntAttribute("id");
		string charName = targetInfo.getStringAttribute("name");

        string charPos = targetInfo.getStringAttribute("position");
		Vector3 v3charPos = stringToVector3(charPos);

		string charBlock = targetInfo.getStringAttribute("block");
		int charFactionId = targetInfo.getIntAttribute("faction_id");

		float charXP = targetInfo.getFloatAttribute("xp");
		int charRP = targetInfo.getIntAttribute("rp");
		int charLeader = targetInfo.getIntAttribute("leader");
		string charGroup = targetInfo.getStringAttribute("soldier_group_name");

		_log("** CABAL: Character " + charId + " (" + charName + charGroup + "), with " + charXP + " XP, has died.", 1);

		// Run an alive/dead check on Player character(s)
		int playerCharId = killerInfo.getIntAttribute("id");
		const XmlElement@ playerCharInfo = getCharacterInfo(m_metagame, playerCharId);
		int playerCharIsDead = playerCharInfo.getIntAttribute("dead");
		if (playerCharIsDead == 1) {
			_log("** CABAL: Player character is dead. No rewards given");
			return;
		}
		// Player is alive and well. Add enemy's XP to total score for level
		approachGoalXP(charXP);

		// Increase player's score
		if (killerInfo.getStringAttribute("name") == "Player ") { // trailing space intentional
			int playerKiller = killerInfo.getIntAttribute("player_id");
			_log("** CABAL: playerKiller ID is: " + playerKiller, 1);
			float xp = targetInfo.getFloatAttribute("xp");
			if ((playerKiller >= 0) && (playerKiller < 2)) {
				awardXP(playerKiller, xp);
			}
		} else { _log("** CABAL: killer name is " + killerInfo.getStringAttribute("name")); }

		string playerPos = playerCharInfo.getStringAttribute("position");
        _log("** CABAL: Player Character id: " + m_playerCharacterId + " is at: " + playerPos);
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
		if (rand(1, 100) > 80) {
			// Group-based drop logic (enemies may drop specific equipment on death)
			if (charGroup == "rifleman") {
				return;
			} else if (charGroup == "commando") {
				dropPowerUp(dropPos.toString(), "grenade", "player_grenade.projectile"); // drop grenade
			} else if (charXP > 0.5) {
				dropPowerUp(dropPos.toString(), "weapon", "player_mg.weapon"); // drop minigun
			} else if (charXP > 0.3) {
				dropPowerUp(dropPos.toString(), "weapon", "player_mp.weapon"); // drop machine pistol
			} else if (charXP > 0.2) {
				dropPowerUp(dropPos.toString(), "weapon", "player_sg.weapon"); // drop shotgun
			} // revert to default weapon after X seconds have elapsed...
			else {
				_log("** CABAL: XP too low, Nothing dropped", 1);
			}
		}
	}

	// -----------------------------------------------------------
	protected void awardXP(int playerKiller, float xp) {
		// match playerKiller's ID to the appropriate player
		if (playerKiller > m_playersSpawned.size()) || (playerKiller < 0)) {
			_log("** CABAL: WARNING!! playerKiller int is " + playerKiller + ". Doesn't look right. Breaking out to prevent logic fault", 1);
			return;
		}
		m_playerScore[playerKiller] += xp;
		_log("** CABAL: Player " + (playerKiller + 1) + " XP now at " + int(m_playerScore[playerKiller]), 1);
	}

	///////////////////////
	// POWERUP LIFECYCLE //
	///////////////////////
	protected void dropPowerUp(string position, string instanceClass, string instanceKey) {
		// between the invisible walls the the player character is locked within (enemyX, playerY+2, playerZ)
		if (levelComplete) {
			return;
		}
        _log("** CABAL: dropping a " + instanceKey + " at " + position, 1);
        string creator = "<command class='create_instance' faction_id='0' position='" + position + "' instance_class='" + instanceClass + "' instance_key='" + instanceKey + "' activated='0' />";
        m_metagame.getComms().send(creator);
		_log("** CABAL: item placed at " + position, 1);
        // ensure only player weapons are dropped
	}

	///////////////////
	// MAP LIFECYCLE //
	///////////////////
	protected void approachGoalXP(float xp) {
		if (levelComplete) {
			return;
		}
		curXP += xp;
		int levelCompletePercent = int(curXP / goalXP * 100);
		_log("** CABAL: current XP is: " + int(curXP) + " of " + int(goalXP), 1);
		if (levelCompletePercent > 100) { levelCompletePercent = 100; }
		_log("** CABAL: Level completion: " + levelCompletePercent + "%", 1);

		// notify text
		if (levelCompletePercent > 0) {
			string statusReport = "<command class='notify' text='" + "Level completion: " + levelCompletePercent + "%' />";
			m_metagame.getComms().send(statusReport);
		}

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
			_log("** CABAL: LEVEL COMPLETE!", 1);
			curXP = 0.0; // ready to start next level
			m_metagame.getComms().send("<command class='set_match_status' faction_id='1' lose='1' />");
			m_metagame.getComms().send("<command class='set_match_status' faction_id='0' win='1' />");
			levelComplete = true;
		}
	}

	////////////////////////
	// VEHICLE LIFECYCLES //
	////////////////////////
	protected void handleVehicleDestroyEvent(const XmlElement@ event) {
		// TagName=vehicle_destroyed_event
		// character_id=75
		// faction_id=0
		// owner_id=0
		// position=559.322 14.6788 618.121
		// vehicle_key=env_building_1_1_1.vehicle

		// in this game mode, all vehicles spawn a dummy vehicle (with 0 ttl) when destroyed
		// this allows us to group large numbers of vehicles into sets, and issue rewards according to the vehicle's difficulty

		// we are only interested in the destruction of 'env_building_*' buildings
        if (!startsWith(event.getStringAttribute("vehicle_key"), "env_building_")) {
			return;
		}
        _log("** CABAL: VehicleHandler going to work!", 1);
		// variablise attributes
		string vehKey = event.getStringAttribute("vehicle_key");
		int playerCharId = event.getIntAttribute("character_id");
		int playerKiller;

		array<const XmlElement@> players = getPlayers(m_metagame);
		for (uint i = 0; i < players.size(); ++i) {
			const XmlElement@ player = players[i];
			int characterId = player.getIntAttribute("character_id");
			if (characterId == playerCharId) {
				playerKiller = player.getIntAttribute("player_id");
				break;
			}
		}


		// identify the dummy vehicle and process accordingly
		if (vehKey == "env_building_1_1_1.vehicle") {
			_log("** CABAL: 1x1x1 building destroyed. Awarding XP", 1);
			approachGoalXP(0.025);
			awardXP(playerKiller, 0.025);
		} else if (vehKey == "env_building_1_2_1.vehicle") {
			_log("** CABAL: 1x2x1 building destroyed. Awarding XP", 1);
			approachGoalXP(0.035);
			awardXP(playerKiller, 0.035);
		} else if (vehKey == "env_building_1_3_1.vehicle") {
			_log("** CABAL: 1x3x1 building destroyed. Awarding XP", 1);
			approachGoalXP(0.05);
			awardXP(playerKiller, 0.05);
		} else if (vehKey == "env_building_1_5_1.vehicle") {
			_log("** CABAL: 1x5x1 building destroyed. Awarding XP", 1);
			approachGoalXP(0.10);
			awardXP(playerKiller, 0.10);
		} else if (vehKey == "env_building_2_1_1.vehicle") {
			_log("** CABAL: 2x1x1 building destroyed. Awarding XP", 1);
			approachGoalXP(0.12);
			awardXP(playerKiller, 0.12);
		} else if (vehKey == "env_building_2_2_1.vehicle") {
			_log("** CABAL: 2x2x1 building destroyed. Awarding XP", 1);
			approachGoalXP(0.13);
			awardXP(playerKiller, 0.13);
		} else if (vehKey == "env_building_2_3_1.vehicle") {
			_log("** CABAL: 2x3x1 building destroyed. Awarding XP", 1);
			approachGoalXP(0.14);
			awardXP(playerKiller, 0.14);
		} else if (vehKey == "env_building_2_5_1.vehicle") {
			_log("** CABAL: 2x5x1 building destroyed. Awarding XP", 1);
			approachGoalXP(0.15);
			awardXP(playerKiller, 0.15);
		} else if (vehKey == "env_building_3_1_1.vehicle") {
			_log("** CABAL: 3x1x1 building destroyed. Awarding XP", 1);
			approachGoalXP(0.16);
			awardXP(playerKiller, 0.16);
		} else if (vehKey == "env_building_3_1_3.vehicle") {
			_log("** CABAL: 3x1x3 building destroyed. Awarding XP", 1);
			approachGoalXP(0.18);
			awardXP(playerKiller, 0.18);
		} else if (vehKey == "env_building_3_2_1.vehicle") {
			_log("** CABAL: 3x2x1 building destroyed. Awarding XP", 1);
			approachGoalXP(0.20);
			awardXP(playerKiller, 0.20);
		} else if (vehKey == "env_building_3_2_3.vehicle") {
			_log("** CABAL: 3x2x3 building destroyed. Awarding XP", 1);
			approachGoalXP(0.22);
			awardXP(playerKiller, 0.22);
		} else if (vehKey == "env_building_3_3_1.vehicle") {
			_log("** CABAL: 3x3x1 building destroyed. Awarding XP", 1);
			approachGoalXP(0.24);
			awardXP(playerKiller, 0.24);
		} else if (vehKey == "env_building_3_3_3.vehicle") {
			_log("** CABAL: 3x3x3 building destroyed. Awarding XP", 1);
			approachGoalXP(0.26);
			awardXP(playerKiller, 0.26);
		} else if (vehKey == "env_building_3_5_1.vehicle") {
			_log("** CABAL: 3x5x1 building destroyed. Awarding XP", 1);
			approachGoalXP(0.28);
			awardXP(playerKiller, 0.28);
		} else if (vehKey == "env_building_3_5_3.vehicle") {
			_log("** CABAL: 3x5x3 building destroyed. Awarding XP", 1);
			approachGoalXP(0.30);
			awardXP(playerKiller, 0.30);
		} else if (vehKey == "env_wall_1_1_1.vehicle") {
			_log("** CABAL: 1x1x1 wall destroyed. Awarding XP", 1);
			approachGoalXP(0.02);
			awardXP(playerKiller, 0.02);
		}
    }

	// --------------------------------------------
	bool hasStarted() const { return true; }

	// --------------------------------------------
	bool hasEnded() const { return false; }

    // --------------------------------------------
    void update(float time) {
        ensureValidLocalPlayer(time);
    }

		// --------------------------------------------
	void onRemove() {
		// clear spawn counting when removing tracker - happens at map change or restart
		m_playersSpawned.clear();
	}

  // --------------------------------------------
	void save(XmlElement@ root) {
		// called by /scripts/gamemodes/quickmatch/cabal_quickie.as
		XmlElement@ parent = root;

		XmlElement quickmatchData("quickmatchData");
		saveQuickmatchData(quickmatchData); // see protected method, below
		parent.appendChild(quickmatchData);
	}

	// --------------------------------------------
	protected void saveQuickmatchData(XmlElement@ quickmatchData) {
		// writes <quickmatchData> section to savegames/quickie[0-999].save/metagame_invasion.xml
		bool doSave = true;
		_log("** CABAL: saving quickmatchData to metagame_invasion.xml", 1);

		// level-specific info
		XmlElement level("level");
		level.setFloatAttribute("progress", curXP);

		// save player hashes and lives
		if (m_playersSpawned.size() > 0) {
			XmlElement players("players");
			players.setIntAttribute("continues", playerCoins);
			for (uint i = 0; i < m_playersSpawned.size(); ++i) {
				if (m_playersSpawned[i] == "") {
					// if any spawned player doesn't have an associated hash, we're not in a position to save data
					_log("** CABAL: Player " + i + " has no hash recorded. Skipping save.", 1);
					doSave = false;
					continue;
				} else {
					string pNum = "player" + (i + 1);
					XmlElement playerData(pNum);
					playerData.setStringAttribute("hash", m_playersSpawned[i]);
					playerData.setIntAttribute("lives", m_playerLives[i]);
					playerData.setFloatAttribute("score", m_playerScore[i]);
					players.appendChild(playerData);
				}
			}
			if (doSave) {
				quickmatchData.appendChild(level);
				quickmatchData.appendChild(players);
				_log("** CABAL: Player data saved to metagame_invasion.xml", 1);
			}
		} else {
			_log("** CABAL: no data in m_playersSpawned. No character info to save.", 1);
		}


		// any more info to add here? Create and populate another XmlElement and append to the quickmatchData XmlElement
		// quickmatchData.appendChild(another_XmlElement);
		_log("** CABAL: RLH::savequickmatchData() done", 1);
	}

	// --------------------------------------------
	void load(const XmlElement@ root) {
		_log("** CABAL: Loading Data", 1);
		m_playersSpawned.clear();
		m_playerLives.clear();
		m_playerScore.clear();

		const XmlElement@ quickmatchData = root.getFirstElementByTagName("quickmatchData");
		if (quickmatchData !is null) {
			_log("** CABAL: loading level data", 1);
			const XmlElement@ levelData = quickmatchData.getFirstElementByTagName("level");
			float levelProgress = levelData.getFloatAttribute("progress");
			approachGoalXP(levelProgress);
			_log("** CABAL: loading player data", 1); // tag elements (one element per saved player)
			array<const XmlElement@> playerData = quickmatchData.getElementsByTagName("players");
			for (uint i = 0; i < playerData.size(); ++ i) {
				_log("** CABAL: player" + (i + 1), 1); // load player[1..999] tag elements
				array<const XmlElement@> curPlayer = playerData[i].getElementsByTagName("player" + (i + 1));

				for (uint j = 0; j < curPlayer.size(); ++j) {
					const XmlElement@ pData = curPlayer[i];
					string hash = pData.getStringAttribute("hash");
					m_playersSpawned.insertLast(hash);
					int lives = pData.getIntAttribute("lives");
					m_playerLives.insertLast(lives);
					float score = pData.getFloatAttribute("score");
					m_playerScore.insertLast(score);
					_log("** CABAL: Score: " + score + ". Lives: " + lives, 1);
				}
			}
		}
	}
}
