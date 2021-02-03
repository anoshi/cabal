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
#include "spawner.as"

// gamemode specific
#include "cabal_stage.as"
#include "faction_config.as"
#include "world.as"

// --------------------------------------------
class CabalMapRotator : MapRotator {
	protected CabalGameMode@ m_metagame;
	protected array<Stage@> m_stages;
	protected int m_currentStageIndex;
	protected int m_nextStageIndex;
	protected array<int> m_stagesCompleted;
	protected bool m_loop;
	protected World@ m_world;
	protected array<FactionConfig@> m_factionConfigs;
	protected CabalStageConfigurator@ m_configurator;

	// --------------------------------------------
	CabalMapRotator(CabalGameMode@ metagame) {
		super();

		@m_metagame = @metagame;

		m_currentStageIndex = 0;
		m_nextStageIndex = 0;
		m_loop = true;
	}

	// --------------------------------------------
	void setConfigurator(CabalStageConfigurator@ configurator) {
		@m_configurator = @configurator;
	}

	// --------------------------------------------
	void setLoop(bool loop) {
		m_loop = loop;
	}

	// --------------------------------------------
	void init() {
		_log("** CABAL: MapRotator::init running", 1);
		MapRotator::init();
		_log("** CABAL: StageConfigurator::setup running", 1);
		m_configurator.setup();

		m_nextStageIndex = m_currentStageIndex;
	}

	// --------------------------------------------
	void startRotation(bool beginOnly = false) {

		if (!beginOnly) {
			// begin_only is false only when the adventure starts from the very beginning, the first time
			m_nextStageIndex = 0; // the first map in the list
			// TODO see map_rotator_campaign.as pickStartingMap to allow us to start on the first map of an area, if desired.
		}

		int index = getNextStageIndex();

		// normal
		startMap(index, beginOnly);
	}

	// --------------------------------------------
	const array<FactionConfig@>@ getFactionConfigs() {
		return m_factionConfigs;
	}

	// // --------------------------------------------
	// protected array<FactionConfig@> getAvailableFactionConfigs() {
	// 	array<FactionConfig@> availableFactionConfigs;

	// 	availableFactionConfigs.push_back(FactionConfig(-1, "player.xml", "Player", "0.2 0.2 0.3"));
	// 	availableFactionConfigs.push_back(FactionConfig(-1, "cabal.xml", "Cabal", "0.2 0.4 0.2"));

	// 	return availableFactionConfigs;
	// }

	// // --------------------------------------------
	// protected void setupFactionConfigs() {
	// 	array<FactionConfig@> availableFactionConfigs = getAvailableFactionConfigs();

	// 	int index = 0;
	// 	while (availableFactionConfigs.length() > 0) {
	// 		int availableIndex = 0;
	// 		FactionConfig@ factionConfig = availableFactionConfigs[availableIndex];
	// 		_log("setting " + factionConfig.m_name + " as index " + index);
	// 		factionConfig.m_index = index;
	// 		m_factionConfigs.insertLast(factionConfig);
	// 		availableFactionConfigs.removeAt(0);
	// 		index++;
	// 	}

	// 	// - finally add neutral / protectors
	// 	{
	// 		index = m_factionConfigs.length();
	// 		m_factionConfigs.insertLast(FactionConfig(index, "brown.xml", "Bots", "0 0 0"));
	// 	}

	// 	_log("total faction configs " + m_factionConfigs.length());
	// }

	// --------------------------------------------
	void addStage(Stage@ stage) {
		m_stages.insertLast(stage);
	}

	// --------------------------------------------
	void addFactionConfig(FactionConfig@ config) {
		m_factionConfigs.push_back(config);
	}

	// --------------------------------------------
	void setWorld(World@ world) {
		@m_world = @world;
	}

	protected void handleFactionLoseEvent(const XmlElement@ event) {
		// if player loses a battle, start over
		int factionId = -1;

		const XmlElement@ loseCondition = event.getFirstElementByTagName("lose_condition");
		if (loseCondition !is null) {
			factionId = loseCondition.getIntAttribute("faction_id");
		} else {
			_log("WARNING, couldn't find lose_condition tag", -1);
		}

		if (factionId == 0) {
			// friendly faction lost, restart the map
			waitAndStart(10, false);
		}
	}

	// // --------------------------------------------
	// protected Stage@ createStage() {
	// 	return Stage(m_metagame, this);
	// }

	// // --------------------------------------------
	// protected void setupStages() {
	// 	// each Stage@ declares a Match@ and each Match declares the competing Factions@
	// 	// Cabal has four areas in which multiple stages are present. For readability, the stages for each area are
	// 	// contained within separate 'setupAreaX()' methods, found later in this file

	// 	setupArea1();
	// 	// TODO: declare the stages that exist in the remaining areas
	// 	// setupArea2();
	// 	// setupArea3();
	// 	// setupArea4();
	// }

	// -------------------------------------------------------
	protected void commitToMapChange(int index) {
		_log("commit_to_map_change, index=" + index, 1);

		// commit to this map change
		m_nextStageIndex = index;
		waitAndStartAtMapChangeCommit();
	}

	// -------------------------------------------------------
	protected void waitAndStartAtMapChangeCommit() {
		waitAndStart(30, true);
	}

	// -------------------------------------------
	protected void waitAndStart(int time = 20, bool sayCountdown = true) {
		int previousStageIndex = m_currentStageIndex;

		// share some information with the server (and thus clients)
		int index = getNextStageIndex();
		string mapName = getMapName(index);

		_log("previous stage index " + previousStageIndex + ", next stage index " + index);
		if (previousStageIndex != index) {
			// show appropriate transport arrows in map now, if map is about to change
			if (m_world !is null) {
				m_world.setAdvance(m_stages[previousStageIndex].m_mapInfo.m_id, m_stages[index].m_mapInfo.m_id);

				// make next stage visible now, at latest
				m_stages[index].m_hidden = false;
				m_world.refresh(m_stages, m_stagesCompleted, previousStageIndex);
			}

			// announce map advance in dialog
			// TODO any form of commander briefing?
			// announceMapAdvance(index);
		} else {
			// same map
		}

		// wait a while, and let server announce a few things
		m_metagame.getTaskSequencer().add(TimeAnnouncerTask(m_metagame, time, sayCountdown));

		if (previousStageIndex != index) {
			// save
			m_metagame.getTaskSequencer().add(Call(CALL(m_metagame.save)));
			// start new map
			m_metagame.getTaskSequencer().add(CallInt(CALL_INT(this.startMapEx), index));
		} else {
			// restart same map
			m_metagame.getTaskSequencer().add(Call(CALL(m_metagame.requestRestart)));
		}
	}

	// --------------------------------------------
	protected void setStageCompleted(int index) {
		if (!isStageCompleted(index)) {
			m_stagesCompleted.insertLast(index);
		}
	}

	// --------------------------------------------
	protected bool isStageCompleted(int index) const {
		return m_stagesCompleted.find(index) >= 0;
	}

	// --------------------------------------------
	protected int getNumberOfCompletedStages() const {
		return m_stagesCompleted.size();
	}

	// --------------------------------------------
	protected bool isCampaignCompleted() const {
		return getNumberOfCompletedStages() == getStageCount();
	}

	// --------------------------------------------
	protected void resetStagesCompleted() {
		m_stagesCompleted.clear();
	}

	// --------------------------------------------
	protected void handleMatchEndEvent(const XmlElement@ event) {
		// prepare for lost battle, grey won
		int factionId = 1;

		const XmlElement@ winCondition = event.getFirstElementByTagName("win_condition");
		if (winCondition !is null) {
			factionId = winCondition.getIntAttribute("faction_id");
		} else {
			_log("WARNING, couldn't find win_condition tag", -1);
		}

		_log("faction " + factionId + " won");

		if (factionId == 0) {
			bool campaignCompleted = false;
			// friendly faction won, advance to next map
			_log("advance", 1);

			// not real data to add about it, is there a "set" in php?
			setStageCompleted(m_currentStageIndex);

			if (m_world !is null) {
				// now, update world view, declare the area ours
				m_world.refresh(m_stages, m_stagesCompleted, m_currentStageIndex);
			}

			m_metagame.getTaskSequencer().add(Call(CALL(m_metagame.save)));

			campaignCompleted = isCampaignCompleted();
			if (campaignCompleted) {
				_log("campaign completed", 1);
				if (m_loop) {
					_log("looping -> resetting");
					resetStagesCompleted();
					campaignCompleted = false;

					// this feels mighty risky to do, let's see what happens;
					// we're requesting the metagame to call init again while already running,
					// this would be handy in order to really recreate the instances related to everything
					// so that we wouldn't have any leftover crap from the previous cycle
					// given how poorly we're doing any kind of tracker cleanup and restart stuff

					// works, but too soon; people want to celebrate in the last map too after beating it
					//$this->metagame->request_restart();

					// do the restart with task sequencer:
					// - do the regular map change countdown first
					// - save
					// - request restart

					m_metagame.getTaskSequencer().add(TimeAnnouncerTask(m_metagame, 30, true));
					m_metagame.getTaskSequencer().add(Call(CALL(m_metagame.requestRestart)));

					// we aren't even calling ready to advance here; everything will be lost anyway!

				} else {
					// campaign completed and not looping, game over, let user handle from here on

					// actually, it's ok to call ready to advance, adventure will set extraction points etc
					readyToAdvance();
				}
			} else {
				readyToAdvance();
			}

		} else {
			// no need to do anything here, we should've received faction_lost event as well
			// and restarted the map because of that
		}
	}


	// // --------------------------------------------
	// protected void readyToAdvance() {
	// 	if (m_stagesCompleted.getSize() == m_stages.length()) {
	// 		_log("all stages completed, request for restart");
	// 		sleep(2);

	// 		m_metagame.getTaskSequencer().add(TimeAnnouncerTask(m_metagame, 30, true));
	// 		m_metagame.getTaskSequencer().add(Call(CALL(m_metagame.requestRestart)));

	// 	} else {
	// 		waitAndStart();
	// 	}
	// }

	// --------------------------------------------
	protected void readyToAdvance() {
		// in invasion, pick first uncompleted stage
		// - normally just picks the next in order, but the admin might have warped around
		int index = 0;
		for (int i = 0; i < getStageCount(); ++i) {
			if (!isStageCompleted(i)) {
				index = i;
				break;
			}
		}

		commitToMapChange(index);
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
	protected const XmlElement@ getChangeMapCommand(int index) const override {
		return m_stages[index].getChangeMapCommand();
	}

	// --------------------------------------------
	protected const XmlElement@ getStartGameCommand(int index) const override {
		return m_stages[index].getStartGameCommand(m_metagame, getCompletionPercentage());
	}

	// --------------------------------------------
	protected int getNextStageIndex() const override {
		return m_nextStageIndex;
	}

	// --------------------------------------------
	float getCompletionPercentage() const {
		float number = float(getNumberOfCompletedStages());
		float count = float(getStageCount());
		return number / count;
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
	void handleFactionResourceConfigChangeCommands() {
		array<XmlElement@>@ commands = m_configurator.getFactionResourceConfigChangeCommands(getCompletionPercentage(), m_stages[m_currentStageIndex]);
		for (uint i = 0; i < commands.size(); ++i) {
			const XmlElement@ value = commands[i];
			m_metagame.getComms().send(value);
		}
	}

	// --------------------------------------------
	void startMap(int index, bool beginOnly = false) {
		_log("** CABAL start_map, index=" + index + ", begin_only=" + beginOnly);

		Stage@ stage = m_stages[index];
		m_metagame.setFactions(stage.m_factions);
		m_metagame.setMapInfo(stage.m_mapInfo);
		m_currentStageIndex = index;

		if (!beginOnly) {
			// change map
			m_metagame.getComms().send(getChangeMapCommand(index));
			handleFactionResourceConfigChangeCommands();
			m_metagame.getComms().clearQueue();
		}

		m_metagame.preBeginMatch();

		if (!beginOnly) {
			// shut ingame commander radio before starting the match -- we'll do "high commander" briefing from the script, after that let in game commander report things

			// setCommanderAiReports(0.0); // copy method from map_rotator_invasion.as if these are required

			// start game
			const XmlElement@ startGameCommand = getStartGameCommand(index);
			m_metagame.getComms().send(startGameCommand);

			// wait here
			// - make a query, the game will serve it as soon as it can (->marks that resources have been changed and the match has been started)
			// only then announce map start
			XmlElement@ query = XmlElement(makeQuery(m_metagame, array<dictionary> = {}));
			const XmlElement@ doc = m_metagame.getComms().query(query);

			m_metagame.resetTimer();
		}

		// initialize world view in game
		if (m_world !is null) {
			m_world.setup(m_factionConfigs, m_stages, m_stagesCompleted, index);
		}

		// if (!beginOnly) {
		// copy method from map_rotator_invasion.as if these are required
		// 	announceMapStart();
		// }

		m_metagame.postBeginMatch();

		// create stage specific trackers:
		_log("trackers: " + stage.m_trackers.size(), 2);
		for (uint i = 0; i < stage.m_trackers.size(); ++i) {
			Tracker@ tracker = stage.m_trackers[i];
			m_metagame.addTracker(tracker);
			// additionally let the tracker change behavior based on if we are starting it in a brand new map and match or loading into match and continuing
			if (beginOnly) {
				tracker.gameContinuePreStart();
			}
		}

		if (beginOnly && m_currentStageIndex >= 0) {
			// here's a failsafe
			// - check if the game considers the game over, set the map completed
			_log("checking for load game completed map fail safe:");
			_log("current stage index: " + m_currentStageIndex);
			_log("is completed: " + isStageCompleted(m_currentStageIndex));
			if (!isStageCompleted(m_currentStageIndex)) {
				// verify from game
				const XmlElement@ node = getGeneralInfo(m_metagame);
				if (node !is null) {
					int matchWinner = node.getIntAttribute("match_winner");
					bool matchOver = node.getIntAttribute("match_over") == 1;
					_log("match winner: " + matchWinner);
					_log("match over: " + matchOver);
					if (matchOver && matchWinner == 0) {
						// should've been completed
						_log("failsafe getting triggered, declaring this map done");
						//m_metagame.getComms().send("declare_winner 0");
						for (uint i = 1; i < m_metagame.getFactionCount(); ++i) {
							m_metagame.getComms().send("<command class='set_match_status' lose='1' faction_id='" + i + "' />");
						}
						m_metagame.getComms().send("<command class='set_match_status' win='1' faction_id='0' />");
					} else if (matchOver && matchWinner != 0) {
						// auto restart
						restartMap();
					}
				}
			} else {
				_log("classified as completed");
			}
		}
	}

	// --------------------------------------------
	void restartMap() {
		int index = m_currentStageIndex;
		_log("restart_map, index=" + index);

		m_metagame.setFactions(m_stages[index].m_factions);

		handleFactionResourceConfigChangeCommands();

		m_metagame.getComms().clearQueue();
		m_metagame.preBeginMatch();

		// start game
		const XmlElement@ startGameCommand = getStartGameCommand(index);
		m_metagame.getComms().send(startGameCommand);

		m_metagame.postBeginMatch();

		for (uint i = 0; i < m_stages[index].m_trackers.size(); ++i) {
			Tracker@ tracker = m_stages[index].m_trackers[i];
			m_metagame.addTracker(tracker);
		}
	}

	// // --------------------------------------------
	// void stageEnded() {
	// 	m_stagesCompleted[formatInt(m_currentStageIndex)] = true;

	// 	// rotate to next map
	// 	readyToAdvance();
	// }

	// // --------------------------------------------
	// protected void handleMatchEndEvent(const XmlElement@ event) {
	// 	// override the default MapRotator behavior;
	// 	// TODO: no substages in Cabal to handle these events, do it here...
	// 	_log("** CABAL: CabalMapRotator handling a MatchEndEvent", 1);
	// }

	// // --------------------------------------------
	// protected void setupArea1() {
	// 	int maxSoldiers = 0;
	// 	{	// create the Stage
	// 		Stage@ stage = createStage();
	// 		stage.m_mapInfo.m_name = "Cabal Area 1";
	// 		stage.m_mapInfo.m_path = "media/packages/cabal/maps/cabal";
	// 		stage.m_mapIndex = 1;

	// 		stage.m_includeLayers.insertLast("bases.default");
	// 		stage.m_includeLayers.insertLast("layer1.map1");
	// 		stage.m_includeLayers.insertLast("layer1.map2");
	// 		stage.m_includeLayers.insertLast("layer1.map3");
	// 		stage.m_includeLayers.insertLast("layer1.map4");

	// 		stage.m_factionConfigs.insertLast(m_factionConfigs[0]);
	// 		stage.m_factionConfigs.insertLast(m_factionConfigs[1]);

	// 		stage.m_maxSoldiers = maxSoldiers;
	// 		stage.m_soldierCapacityModel = "constant";
	// 		stage.m_playerAiCompensation = 0;
	// 		stage.m_playerAiReduction = 2;
	// 		stage.m_baseCaptureSystem = "none";
	// 		{ // add Factions to the stage
	// 			Faction@ faction = Faction(m_factionConfigs[0]);
	// 			faction.m_ownedBases.insertLast("");
	// 			faction.m_overCapacity = 0;             // spawn this many more units at start than capacity offset
	// 			faction.m_capacityOffset = 0;           // reserve this many units of maxSoldiers for this faction
	// 			faction.m_capacityMultiplier = 0.0001;
	// 			stage.m_factions.insertLast(faction);
	// 		}
	// 		{
	// 			Faction@ faction = Faction(m_factionConfigs[1]);
	// 			faction.m_ownedBases.insertLast("Bad Guys");
	// 			faction.m_overCapacity = 0;             // spawn this many more units at start than capacity offset
	// 			faction.m_capacityOffset = 0;           // reserve this many units of maxSoldiers for this faction
	// 			faction.m_capacityMultiplier = 0.0001;
	// 			stage.m_factions.insertLast(faction);
	// 		}
	// 		m_stages.insertLast(stage);
	// 	}
	// }

}
