// internal
#include "tracker.as"
#include "log.as"
#include "gamemode.as"

// --------------------------------------------


// --------------------------------------------
class CabalSpawner : Tracker {
	protected GameModeInvasion@ m_metagame;

    protected float SPAWN_DELAY_MAX = 10.00; // make this a dynamic value. Shorter as map increases in duration and at higher levels.
    protected float SPAWN_DELAY_MIN = 5.00;
	protected float spawnDelay; // randomise time between enemy spawns

	protected int m_playerCharacterId;

	// ----------------------------------------------------
	CabalSpawner(GameModeInvasion@ metagame) {
		@m_metagame = @metagame;
		queueCabalSpawn(); // start the countdown to next enemy spawn event
	}

	protected void queueCabalSpawn() {
		spawnDelay = rand(SPAWN_DELAY_MIN, SPAWN_DELAY_MAX);
		_log("*** CABAL: Enemy units queued to spawn in: " + spawnDelay + " seconds." ,1);
	}

	protected void spawnCabalUnits() {
		// What is the player character's id? (get hashes for multiplayer support)
		const XmlElement@ playerInfo = getCharacterInfo(m_metagame, m_playerCharacterId);
		if (playerInfo.getIntAttribute("wounded") != 1 && playerInfo.getIntAttribute("dead") != 1) {
			_log("*** CABAL: player is alive, ok to spawn enemies", 1);
			// start enemy spawning from specific locations (as per passed map layer name, for level)
			// after player character has spawned. i.e. no enemy spawn until player is on the map
			int m_spawnCount = 4;
			string m_genericNodeTag = "cabal_spawn";
			string layerName = thisStage();
			array<const XmlElement@> nodes = getGenericNodes(m_metagame, layerName, m_genericNodeTag);
			_log("*** CABAL: Spawning " + m_spawnCount + " enemies at " + nodes.size() + " " + m_genericNodeTag + " points.", 1);
			string randKey = ''; // random character 'Key' name
			for (int i = 0; i < m_spawnCount && nodes.size() > 0; ++i) {
				switch( rand(0, 5) ) { // 5 types of enemy units, weighted to return more base level soldiers
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
				XmlElement command("command");
				command.setStringAttribute("class", "create_instance");
				command.setIntAttribute("faction_id", 1);
				command.setStringAttribute("instance_class", "character");
				command.setStringAttribute("instance_key", randKey);

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
			_log("*** CABAL: No enemies were spawned! No player characters alive in field." , 1);
		}
	}

	protected string anyMissionGoal() {
		array<string> missionGoals = {"fun", "NOFUN", "MANY WOW", "such adventure"};
		return missionGoals[rand(0, missionGoals.size() -1)];
	}

	// /////////////////////// //
	// Get player character ID //
	// /////////////////////// //
	protected void handlePlayerSpawnEvent(const XmlElement@ event) {
		_log("*** CABAL: CabalSpawner::handlePlayerSpawnEvent", 1);

		const XmlElement@ element = event.getFirstElementByTagName("player");
		string name = element.getStringAttribute("name");
		if (name == m_metagame.getUserSettings().m_username) {
			m_playerCharacterId = element.getIntAttribute("character_id");
		}
	}

	// --------------------------------------------
	bool hasEnded() const {
		// always on
		return false;
	}

	// --------------------------------------------
	bool hasStarted() const {
		// always on
		return true;
	}

	// --------------------------------------------
	void update(float time) {
		spawnDelay -= time;
		if (spawnDelay <= 0.0) {
			_log("*** CABAL: enemy units spawning!", 1);
			spawnCabalUnits();
			queueCabalSpawn();
		}
	}
	// ----------------------------------------------------
}
