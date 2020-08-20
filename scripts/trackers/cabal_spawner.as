// internal
#include "tracker.as"
#include "log.as"


// --------------------------------------------
class CabalSpawner : Tracker {
	protected CabalGameMode@ m_metagame;

	protected bool m_started = false;

	protected float SPAWN_DELAY_MAX = 10.00; // make this a dynamic value. Shorter as map increases in duration and at higher levels.
	protected float SPAWN_DELAY_MIN = 5.00;
	protected float spawnDelay; // randomise time between enemy spawns

	// ----------------------------------------------------
	CabalSpawner(CabalGameMode@ metagame) {
		@m_metagame = @metagame;
	}

	// --------------------------------------------
	void start() {
		_log("** CABAL: starting cabal_spawner tracker", 1);
		queueCabalSpawn();
		m_started = true;
	}

	// --------------------------------------------
	protected void queueCabalSpawn() {
		spawnDelay = rand(SPAWN_DELAY_MIN, SPAWN_DELAY_MAX);
		_log("** CABAL: Enemy units queued to spawn in: " + spawnDelay + " seconds." ,1);
	}

	// --------------------------------------------
	protected void spawnCabalUnits() {
		if (m_metagame.getNumPlayers() > 0 && m_started) {
			int m_spawnCount = m_metagame.getNumPlayers() * 4;
			string m_genericNodeTag = "cabal_spawn";
			string layerName = thisStage();
			array<const XmlElement@>@ nodes = getGenericNodes(m_metagame, layerName, m_genericNodeTag);
			_log("** CABAL: Spawning " + m_spawnCount + " enemies at " + nodes.size() + " " + m_genericNodeTag + " points.", 1);
			string randKey = ''; // random character 'Key' name
			for (int j = 0; j < m_spawnCount && nodes.size() > 0; ++j) {
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
		}
	}

	// --------------------------------------------
	protected void handleMatchEndEvent(const XmlElement@ event) {
		m_started = false;
	}

	// --------------------------------------------
	bool hasEnded() const {
		return !m_started;
	}

	// --------------------------------------------
	bool hasStarted() const {
		return m_started;
	}

	// --------------------------------------------
	void update(float time) {
		if (m_started) {
			spawnDelay -= time;
			if (spawnDelay <= 0.0) {
				_log("** CABAL: enemy units spawning!", 1);
				spawnCabalUnits();
				queueCabalSpawn();
			}
		}
	}
	// ----------------------------------------------------
}
