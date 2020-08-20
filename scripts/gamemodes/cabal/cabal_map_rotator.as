// internal
#include "tracker.as"
#include "map_info.as"
#include "log.as"
#include "helpers.as"
#include "announce_task.as"
#include "generic_call_task.as"
#include "time_announcer_task.as"

// generic trackers
#include "map_rotator.as"

// gamemode specific
#include "cabal_stage.as"

// --------------------------------------------
class CabalMapRotator : MapRotator {
	CabalGameMode@ m_metagame;
	array<Stage@> m_stages;
	dictionary m_stagesCompleted;

	bool m_loop = true; // nfi if this is even necessary

	array<FactionConfig@> m_factionConfigs;

	int m_currentStageIndex;

	CabalMapRotator(CabalGameMode@ metagame) {
		@m_metagame = @metagame;
	}

	// --------------------------------------------
	void init() {
		_log("** CABAL: setupFactionConfigs", 1);
		setupFactionConfigs();
		_log("** CABAL: setupStages", 1);
		setupStages();
	}

	// --------------------------------------------
	protected array<FactionConfig@> getAvailableFactionConfigs() {
		array<FactionConfig@> availableFactionConfigs;

		availableFactionConfigs.push_back(FactionConfig(-1, "player.xml", "Player", "0.2 0.2 0.3"));
		availableFactionConfigs.push_back(FactionConfig(-1, "cabal.xml", "Cabal", "0.2 0.4 0.2"));

		return availableFactionConfigs;
	}

	// --------------------------------------------
	protected void setupFactionConfigs() {
		array<FactionConfig@> availableFactionConfigs = getAvailableFactionConfigs();

		int index = 0;
		while (availableFactionConfigs.length() > 0) {
			int availableIndex = 0;
			FactionConfig@ factionConfig = availableFactionConfigs[availableIndex];
			_log("setting " + factionConfig.m_name + " as index " + index);
			factionConfig.m_index = index;
			m_factionConfigs.insertLast(factionConfig);
			// removes the first item in array
			availableFactionConfigs.removeAt(0);
			index++;
		}

		// - finally add neutral / protectors
		{
			index = m_factionConfigs.length();
			m_factionConfigs.insertLast(FactionConfig(index, "brown.xml", "Bots", "0 0 0"));
		}

		_log("total faction configs " + m_factionConfigs.length());
	}

	// --------------------------------------------
	protected Stage@ createStage() {
		return Stage(m_metagame, this);
	}

	// --------------------------------------------
	protected void setupStages() {
		// each Stage@ declares a Match@ and each Match declares the competing Factions@
		// Cabal has four areas in which multiple stages are present. For readability, the stages for each area are
		// contained within separate 'setupAreaX()' methods, found later in this file

		setupArea1();
		// TODO: declare the stages that exist in the remaining areas
		// setupArea2();
		// setupArea3();
		// setupArea4();
	}

	// -------------------------------------------
	protected void waitAndStart(int time = 20, bool sayCountdown = true) {
		int previousStageIndex = m_currentStageIndex;

		// share some information with the server (and thus clients)
		int index = getNextStageIndex();
		string mapName = getMapName(index);

		_log("previous stage index " + previousStageIndex + ", next stage index " + index);

		// wait a while, and let server announce a few things
		m_metagame.getTaskSequencer().add(TimeAnnouncerTask(m_metagame, time, sayCountdown));

		if (previousStageIndex != index) {
			// start new map
			m_metagame.getTaskSequencer().add(CallInt(CALL_INT(this.startMapEx), index));
		} else {
			// restart same map
			m_metagame.getTaskSequencer().add(Call(CALL(m_metagame.requestRestart)));
		}
	}

	// --------------------------------------------
	protected void readyToAdvance() {
		if (m_stagesCompleted.getSize() == m_stages.length()) {
			_log("all stages completed, request for restart");
			sleep(2);

			m_metagame.getTaskSequencer().add(TimeAnnouncerTask(m_metagame, 30, true));
			m_metagame.getTaskSequencer().add(Call(CALL(m_metagame.requestRestart)));

		} else {
			waitAndStart();
		}
	}

	// --------------------------------------------
	protected int getStageCount() {
		return m_stages.length();
	}

	// --------------------------------------------
	protected string getMapName(int index) {
		return m_stages[index].m_mapInfo.m_name;
	}

	// --------------------------------------------
	protected string getChangeMapCommand(int index) {
		return m_stages[index].getChangeMapCommand();
	}

	// --------------------------------------------
	protected const XmlElement@ getStartGameCommand(CabalGameMode@ metagame) {
		// note, get_start_game_command doesn't make sense in this rotator, and isn't used
		XmlElement command("");
		return command;
	}

	// --------------------------------------------
	protected int getNextStageIndex() const {
		//return m_stagesCompleted.getSize();
		array<string> stages = m_stagesCompleted.getKeys();
		array<int> completedStageIndices;
		for (uint i = 0; i < stages.length(); ++i) {
			completedStageIndices.insertLast(parseInt(stages[i]));
		}
    	return pickRandomMapIndex(getStageCount(), completedStageIndices);
	}

	// --------------------------------------------------------
	protected bool isStageCompleted(int index) {
		// if Find finds the value in array, it will return a value >= 0
		return (m_stagesCompleted.exists(formatInt(index)));
	}

	// --------------------------------------------------------
	protected Stage@ getCurrentStage() {
		return m_stages[m_currentStageIndex];
	}

	// --------------------------------------------
    void startMapEx(int index) {
		startMap(index);
	}

	// --------------------------------------------
	void startMap(int index, bool beginOnly = false) {
		_log("** CABAL start_map, index=" + index + ", begin_only=" + beginOnly);

		Stage@ stage = m_stages[index];
		m_currentStageIndex = index;

		if (!beginOnly) {
			// change map
			string changeMapCommand = getChangeMapCommand(index);
			m_metagame.getComms().send(changeMapCommand);
		}

		// note, get_start_game_command doesn't make sense in this rotator, and isn't used
		stage.start();
	}

	// --------------------------------------------
   	void restartMap() {
		int index = m_currentStageIndex;
		_log("restart_map, index=" + index);

		Stage@ stage = m_stages[index];
		stage.start();
	}

	// --------------------------------------------
	void stageEnded() {
		m_stagesCompleted[formatInt(m_currentStageIndex)] = true;

		// rotate to next map
		readyToAdvance();
	}

	// --------------------------------------------
	protected void handleMatchEndEvent(const XmlElement@ event) {
		// override the default MapRotator behavior;
		// TODO: no substages in Cabal to handle these events, do it here...
		_log("** CABAL: CabalMapRotator handling a MatchEndEvent", 1);
	}

	// --------------------------------------------
	protected void setupArea1() {
		int maxSoldiers = 0;
		{	// create the Stage
			Stage@ stage = createStage();
			stage.m_mapInfo.m_name = "Cabal Area 1";
			stage.m_mapInfo.m_path = "media/packages/cabal/maps/cabal";
			stage.m_mapIndex = 1;

			stage.m_includeLayers.insertLast("bases.default");
			stage.m_includeLayers.insertLast("layer1.map1");
			stage.m_includeLayers.insertLast("layer1.map2");
			stage.m_includeLayers.insertLast("layer1.map3");
			stage.m_includeLayers.insertLast("layer1.map4");

			stage.m_factionConfigs.insertLast(m_factionConfigs[0]);
			stage.m_factionConfigs.insertLast(m_factionConfigs[1]);

			stage.m_maxSoldiers = maxSoldiers;
			stage.m_soldierCapacityModel = "constant";
			stage.m_playerAiCompensation = 0;
			stage.m_playerAiReduction = 2;
			stage.m_baseCaptureSystem = "none";
			{ // add Factions to the stage
				Faction@ faction = Faction(m_factionConfigs[0]);
				faction.m_ownedBases.insertLast("");
				faction.m_overCapacity = 0;             // spawn this many more units at start than capacity offset
				faction.m_capacityOffset = 0;           // reserve this many units of maxSoldiers for this faction
				faction.m_capacityMultiplier = 0.0001;
				stage.m_factions.insertLast(faction);
			}
			{
				Faction@ faction = Faction(m_factionConfigs[1]);
				faction.m_ownedBases.insertLast("Bad Guys");
				faction.m_overCapacity = 0;             // spawn this many more units at start than capacity offset
				faction.m_capacityOffset = 0;           // reserve this many units of maxSoldiers for this faction
				faction.m_capacityMultiplier = 0.0001;
				stage.m_factions.insertLast(faction);
			}
			m_stages.insertLast(stage);
		}
	}

}
