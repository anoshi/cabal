// gamemode specific
#include "lobby_client_accept_handler.as"
#include "faction_config.as"
#include "stage_configurator.as"
#include "cabal_stage.as"
#include "player_manager.as"

// ------------------------------------------------------------------------------------------------
class CabalStageConfigurator : StageConfigurator, LobbyClientAcceptHandlerListener {
	protected GameModeInvasion@ m_metagame;
	protected MapRotatorInvasion@ m_mapRotator;

	// ------------------------------------------------------------------------------------------------
	CabalStageConfigurator(GameModeInvasion@ metagame, MapRotatorInvasion@ mapRotator) {
		@m_metagame = @metagame;
		@m_mapRotator = mapRotator;
		mapRotator.setConfigurator(this);
	}

	// ------------------------------------------------------------------------------------------------
	void setup() {
		setupFactionConfigs();
		setupNormalStages();
		setupWorld();
	}

	// ------------------------------------------------------------------------------------------------
	const array<FactionConfig@>@ getAvailableFactionConfigs() const {
		array<FactionConfig@> availableFactionConfigs;

		availableFactionConfigs.push_back(FactionConfig(-1, "player.xml", "Player", "0.2 0.2 0.3", "player.xml"));
		availableFactionConfigs.push_back(FactionConfig(-1, "cabal.xml", "Cabal", "0.2 0.4 0.2", "cabal.xml"));
		return availableFactionConfigs;
	}

	// ------------------------------------------------------------------------------------------------
	protected void setupFactionConfigs() {
		array<FactionConfig@> availableFactionConfigs = getAvailableFactionConfigs(); // copy for mutability

		const UserSettings@ settings = m_metagame.getUserSettings();
		// First, add player faction
		{
			_log("faction choice: " + settings.m_factionChoice, 1);
			FactionConfig@ userChosenFaction = availableFactionConfigs[settings.m_factionChoice];
			_log("player faction: " + userChosenFaction.m_file, 1);

			int index = int(getFactionConfigs().size()); // is 0
			userChosenFaction.m_index = index;
			m_mapRotator.addFactionConfig(userChosenFaction);
			availableFactionConfigs.erase(settings.m_factionChoice);
		}
		// next add the cabal faction
		while (availableFactionConfigs.size() > 0) {
			int index = int(getFactionConfigs().size());

			int availableIndex = rand(0, availableFactionConfigs.size() - 1);
			FactionConfig@ faction = availableFactionConfigs[availableIndex];

			_log("setting " + faction.m_name + " as index " + index, 1);

			faction.m_index = index;
			m_mapRotator.addFactionConfig(faction);

			availableFactionConfigs.erase(availableIndex);
		}
		// finally, add neutral faction
		{
			int index = getFactionConfigs().size();
			m_mapRotator.addFactionConfig(FactionConfig(index, "neutral.xml", "Neutral", "0 0 0"));
		}

		_log("total faction configs " + getFactionConfigs().size(), 1);
	}

// --------------------------------------------
	protected void setupWorld() {
		CabalWorld world(m_metagame);

		dictionary mapIdToRegionIndex;
		mapIdToRegionIndex.set("map8", 0);
		mapIdToRegionIndex.set("map3", 1);
		mapIdToRegionIndex.set("map13", 2);
		mapIdToRegionIndex.set("map6", 3);
		mapIdToRegionIndex.set("map2", 4);
		mapIdToRegionIndex.set("map5", 5);
		mapIdToRegionIndex.set("map9", 6);
		mapIdToRegionIndex.set("map11", 7);
		mapIdToRegionIndex.set("map10", 8);

		world.init(mapIdToRegionIndex);

		m_mapRotator.setWorld(world);
	}

	// ------------------------------------------------------------------------------------------------
	protected void addStage(Stage@ stage) {
		m_mapRotator.addStage(stage);
	}

	// ------------------------------------------------------------------------------------------------
	protected void setupNormalStages() {
		addStage(setupStage1());
		addStage(setupStage2());
		addStage(setupStage3());
		addStage(setupStage4());
		addStage(setupStage5());
		addStage(setupStage6());
		addStage(setupStage7());
		addStage(setupStage8());
		addStage(setupStage9());
		addStage(setupStage10());
		addStage(setupStage11());
		addStage(setupStage12());
		// addStage(setupStage13()); // final boss level, if desired
	}

	// --------------------------------------------
	protected CabalStage@ createStage() const {
		return CabalStage(m_metagame.getUserSettings());
	}

	// --------------------------------------------
	protected PhasedStage@ createPhasedStage() const {
		return PhasedStage(m_metagame.getUserSettings());
	}

	// --------------------------------------------
	const array<FactionConfig@>@ getFactionConfigs() const {
		return m_mapRotator.getFactionConfigs();
	}

	// ------------------------------------------------------------------------------------------------
	Stage@ setupCompletedStage(Stage@ inputStage) {
		// currently not in use in invasion
		return null;
	}

	void onLobbyClientAcceptHandlerCompleted() {
		m_metagame.getPlayerManager().setupFromCurrentState();
		// trigger map change
		// lobby has only friendly faction, enough to set them won
		m_metagame.getComms().send("<command class='set_match_status' win='1' faction_id='0' />");
	}

	/*
	// ------------------------------------------------------------------------------------------------
	protected Stage@ setupLobby() {
		StageMVSW@ stage = createStage();
		stage.m_mapInfo.m_name = "Lobby";
		stage.m_mapInfo.m_path = "media/packages/man_vs_world_mp/maps/lobby_2p";
		stage.m_mapInfo.m_id = "lobby_2p";

	    stage.m_includeLayers.insertLast("bases.manvsworld");
		stage.m_includeLayers.insertLast("layer1.manvsworld");

		// - LobbyClientAcceptHandlerListener is notified when the client(s) are accepted by the hosting player
		// - something in the script should save and remember player profiles on that moment
		// - that same something should pay attention to profiles connecting that if not within the list,
		//   they need to be kicked
		// - also map change should trigger

		stage.addTracker(LobbyClientAcceptHandler(m_metagame, m_metagame.getUserSettings().m_maxPlayers, this));

		stage.m_maxSoldiers = 1;

		{
			Faction f(getFactionConfigs()[0], createFellowCommanderAiCommand(0));
			f.m_overCapacity = 0;
			f.m_capacityOffset = 1;
			f.m_capacityMultiplier = 0.0001;
			f.m_bases = 1;
			stage.m_factions.insertLast(f);
		}

		return stage;
	}
	*/

	// ------------------------------------------------------------------------------------------------
	protected Stage@ setupStage1() {
		_log("*** CABAL: CabalStageConfigurator::setupStage1 running", 1);
		Stage@ stage = createStage();
		stage.m_mapInfo.m_name = "Cabal M1A1";
		stage.m_mapInfo.m_path = "media/packages/cabal/maps/cabal";
		stage.m_mapInfo.m_id = "map1";

		int index = stage.m_includeLayers.find("layer1.map2");
		if (index >= 0) {
			stage.m_includeLayers.removeAt(index);
			_log("*** CABAL: found and removed layer1.map2", 1);
		}

		_log("*** CABAL: adding map layer1.map1", 1);
		stage.m_includeLayers.insertLast("layer1.map1"); // this is intentional

		stage.addTracker(PeacefulLastBase(m_metagame, 0));
/* was using this
		stage.m_maxSoldiers = 2; // just you and the other guy (if dedicated server, otherwise, might score an AI friendly)
		stage.m_playerAiReduction = 0; // nfi
		stage.m_playerAiCompensation = 0; // again, nfi

		{
			Faction f(getFactionConfigs()[0], createFellowCommanderAiCommand(0));
			f.m_overCapacity = 1;
			f.m_capacityOffset = 2;
			//f.m_capacityMultiplier = 0.0001;
			f.m_capacityMultiplier = 0.5000;
			f.m_bases = 1;
			stage.m_factions.insertLast(f);
		}
following section uses map 11 / final stage 1 as ref */
		stage.m_maxSoldiers = 57 ;
		stage.m_playerAiCompensation = 3;
		stage.m_playerAiReduction = 0;

		//stage.addTracker(Spawner(m_metagame, 1, Vector3(367,0,702), 15, "default_ai")); // to spawn 15 bads under faction 1 at pos, default ai behaviours)

		{
			Faction f(getFactionConfigs()[0], createFellowCommanderAiCommand(0, 0.0, 0.0, false));
			f.m_overCapacity = 0; // spawn this many more units at start than capacity offset
			f.m_capacityOffset = 2; // reserve this many units of maxSoldiers for this faction
			f.m_capacityMultiplier = 0.0001;
			f.m_bases = 1;
			stage.m_factions.insertLast(f);
		}

		{
			Faction f(getFactionConfigs()[1], createCommanderAiCommand(1,0,0,true));
			//f.m_overCapacity = 5;
			f.m_overCapacity = 54;
			f.m_capacityMultiplier = 0.0001;
			stage.m_factions.insertLast(f);
		}

		stage.m_primaryObjective = "survive"; // "attrition";

		return stage;
	}

	// ------------------------------------------------------------------------------------------------
	protected Stage@ setupStage2() {
		Stage@ stage = createStage();
		stage.m_mapInfo.m_name = "Cabal M1A2";
		stage.m_mapInfo.m_path = "media/packages/cabal/maps/cabal";
		stage.m_mapInfo.m_id = "map2";

    	stage.m_fogOffset = 20.0;
    	stage.m_fogRange = 50.0;

		stage.m_includeLayers.insertLast("layer1.map2");

		stage.addTracker(PeacefulLastBase(m_metagame, 0));

		stage.m_maxSoldiers = 6; // just you and the other guy (if dedicated server, otherwise, might score an AI friendly)

		{
			Faction f(getFactionConfigs()[0], createFellowCommanderAiCommand(0));
			f.m_capacityOffset = 1;
			f.m_overCapacity = 0;
			f.m_capacityMultiplier = 0.0001;
			f.m_bases = 1;
			stage.m_factions.insertLast(f);
		}
		{
			Faction f(getFactionConfigs()[1], createCommanderAiCommand(1,0,0,true));
			f.m_overCapacity = 55;
			f.m_capacityMultiplier = 0.0001;
			stage.m_factions.insertLast(f);
		}

		stage.m_primaryObjective = "capture"; // "attrition";

		return stage;
	}

	// ------------------------------------------------------------------------------------------------
	protected Stage@ setupStage3() {
		Stage@ stage = createStage();
		stage.m_mapInfo.m_name = "Cabal M1A3";
		stage.m_mapInfo.m_path = "media/packages/cabal/maps/cabal";
		stage.m_mapInfo.m_id = "map3";

		stage.m_includeLayers.insertLast("layer1.map3");

		stage.addTracker(PeacefulLastBase(m_metagame, 0));

		stage.m_maxSoldiers = 1; // just you and the other guy (if dedicated server, otherwise, might score an AI friendly)

		{
			Faction f(getFactionConfigs()[0], createFellowCommanderAiCommand(0));
			f.m_capacityOffset = 0;
			f.m_capacityMultiplier = 0.0001;
			f.m_bases = 1;
			stage.m_factions.insertLast(f);
		}
		{
			Faction f(getFactionConfigs()[1], createCommanderAiCommand(1,0,0,true));
			f.m_overCapacity = 55;
			f.m_capacityMultiplier = 0.0001;
			stage.m_factions.insertLast(f);
		}

		stage.m_primaryObjective = "attrition"; // "capture"

		return stage;
	}

	// ------------------------------------------------------------------------------------------------
	protected Stage@ setupStage4() {
		Stage@ stage = createStage();
		stage.m_mapInfo.m_name = "Cabal M2A1";
		stage.m_mapInfo.m_path = "media/packages/cabal/maps/cabal";
		stage.m_mapInfo.m_id = "map4";

		_log("*** CABAL: adding map layer1.map4", 1);
		stage.m_includeLayers.insertLast("layer1.map4");

		stage.addTracker(PeacefulLastBase(m_metagame, 0));

		stage.m_maxSoldiers = 1; // just you and the other guy (if dedicated server, otherwise, might score an AI friendly)

		{
			Faction f(getFactionConfigs()[0], createFellowCommanderAiCommand(0));
			f.m_capacityOffset = 0;
			f.m_capacityMultiplier = 0.0001;
			f.m_bases = 1;
			stage.m_factions.insertLast(f);
		}
		{
			Faction f(getFactionConfigs()[1], createCommanderAiCommand(1,0,0,true));
			f.m_overCapacity = 55;
			f.m_capacityMultiplier = 0.0001;
			stage.m_factions.insertLast(f);
		}

		stage.m_primaryObjective = "attrition"; // "capture"

		return stage;
	}

	// ------------------------------------------------------------------------------------------------
	protected Stage@ setupStage5() {
		Stage@ stage = createStage();
		stage.m_mapInfo.m_name = "Cabal M2A2";
		stage.m_mapInfo.m_path = "media/packages/cabal/maps/cabal";
		stage.m_mapInfo.m_id = "map5";

		stage.addTracker(PeacefulLastBase(m_metagame, 0));

		stage.m_maxSoldiers = 1; // just you and the other guy (if dedicated server, otherwise, might score an AI friendly)

		{
			Faction f(getFactionConfigs()[0], createFellowCommanderAiCommand(0));
			f.m_capacityOffset = 0;
			f.m_capacityMultiplier = 0.0001;
			f.m_bases = 1;
			stage.m_factions.insertLast(f);
		}
		{
			Faction f(getFactionConfigs()[1], createCommanderAiCommand(1,0,0,true));
			f.m_overCapacity = 55;
			f.m_capacityMultiplier = 0.0001;
			stage.m_factions.insertLast(f);
		}

		stage.m_primaryObjective = "attrition"; // "capture"

		return stage;
	}

	// ------------------------------------------------------------------------------------------------
	protected Stage@ setupStage6() {
		Stage@ stage = createStage();
		stage.m_mapInfo.m_name = "Cabal M2A3";
		stage.m_mapInfo.m_path = "media/packages/cabal/maps/cabal";
		stage.m_mapInfo.m_id = "map6";

		stage.addTracker(PeacefulLastBase(m_metagame, 0));

		stage.m_maxSoldiers = 1; // just you and the other guy (if dedicated server, otherwise, might score an AI friendly)

		{
			Faction f(getFactionConfigs()[0], createFellowCommanderAiCommand(0));
			f.m_capacityOffset = 0;
			f.m_capacityMultiplier = 0.0001;
			f.m_bases = 1;
			stage.m_factions.insertLast(f);
		}
		{
			Faction f(getFactionConfigs()[1], createCommanderAiCommand(1,0,0,true));
			f.m_overCapacity = 55;
			f.m_capacityMultiplier = 0.0001;
			stage.m_factions.insertLast(f);
		}

		stage.m_primaryObjective = "attrition"; // "capture"

		return stage;
	}

	// ------------------------------------------------------------------------------------------------
	protected Stage@ setupStage7() {
		Stage@ stage = createStage();
		stage.m_mapInfo.m_name = "Cabal M3A1";
		stage.m_mapInfo.m_path = "media/packages/cabal/maps/cabal";
		stage.m_mapInfo.m_id = "map7";

		stage.addTracker(PeacefulLastBase(m_metagame, 0));

		stage.m_maxSoldiers = 1; // just you and the other guy (if dedicated server, otherwise, might score an AI friendly)

		{
			Faction f(getFactionConfigs()[0], createFellowCommanderAiCommand(0));
			f.m_capacityOffset = 0;
			f.m_capacityMultiplier = 0.0001;
			f.m_bases = 1;
			stage.m_factions.insertLast(f);
		}
		{
			Faction f(getFactionConfigs()[1], createCommanderAiCommand(1,0,0,true));
			f.m_overCapacity = 55;
			f.m_capacityMultiplier = 0.0001;
			stage.m_factions.insertLast(f);
		}

		stage.m_primaryObjective = "attrition"; // "capture"

		return stage;
	}

	// ------------------------------------------------------------------------------------------------
	protected Stage@ setupStage8() {
		Stage@ stage = createStage();
		stage.m_mapInfo.m_name = "Cabal M3A2";
		stage.m_mapInfo.m_path = "media/packages/cabal/maps/cabal";
		stage.m_mapInfo.m_id = "map8";

		stage.addTracker(PeacefulLastBase(m_metagame, 0));

		stage.m_maxSoldiers = 1; // just you and the other guy (if dedicated server, otherwise, might score an AI friendly)

		{
			Faction f(getFactionConfigs()[0], createFellowCommanderAiCommand(0));
			f.m_capacityOffset = 0;
			f.m_capacityMultiplier = 0.0001;
			f.m_bases = 1;
			stage.m_factions.insertLast(f);
		}
		{
			Faction f(getFactionConfigs()[1], createCommanderAiCommand(1,0,0,true));
			f.m_overCapacity = 55;
			f.m_capacityMultiplier = 0.0001;
			stage.m_factions.insertLast(f);
		}

		stage.m_primaryObjective = "attrition"; // "capture"

		return stage;
	}

	// ------------------------------------------------------------------------------------------------
	protected Stage@ setupStage9() {
		Stage@ stage = createStage();
		stage.m_mapInfo.m_name = "Cabal M3A3";
		stage.m_mapInfo.m_path = "media/packages/cabal/maps/cabal";
		stage.m_mapInfo.m_id = "map9";

		stage.addTracker(PeacefulLastBase(m_metagame, 0));

		stage.m_maxSoldiers = 1; // just you and the other guy (if dedicated server, otherwise, might score an AI friendly)

		{
			Faction f(getFactionConfigs()[0], createFellowCommanderAiCommand(0));
			f.m_capacityOffset = 0;
			f.m_capacityMultiplier = 0.0001;
			f.m_bases = 1;
			stage.m_factions.insertLast(f);
		}
		{
			Faction f(getFactionConfigs()[1], createCommanderAiCommand(1,0,0,true));
			f.m_overCapacity = 55;
			f.m_capacityMultiplier = 0.0001;
			stage.m_factions.insertLast(f);
		}

		stage.m_primaryObjective = "attrition"; // "capture"

		return stage;
	}

	// ------------------------------------------------------------------------------------------------
	protected Stage@ setupStage10() {
		Stage@ stage = createStage();
		stage.m_mapInfo.m_name = "Cabal M4A1";
		stage.m_mapInfo.m_path = "media/packages/cabal/maps/cabal";
		stage.m_mapInfo.m_id = "map10";

		stage.addTracker(PeacefulLastBase(m_metagame, 0));

		stage.m_maxSoldiers = 1; // just you and the other guy (if dedicated server, otherwise, might score an AI friendly)

		{
			Faction f(getFactionConfigs()[0], createFellowCommanderAiCommand(0));
			f.m_capacityOffset = 0;
			f.m_capacityMultiplier = 0.0001;
			f.m_bases = 1;
			stage.m_factions.insertLast(f);
		}
		{
			Faction f(getFactionConfigs()[1], createCommanderAiCommand(1,0,0,true));
			f.m_overCapacity = 55;
			f.m_capacityMultiplier = 0.0001;
			stage.m_factions.insertLast(f);
		}

		stage.m_primaryObjective = "attrition"; // "capture"

		return stage;
	}

	// ------------------------------------------------------------------------------------------------

	protected Stage@ setupStage11() {
		Stage@ stage = createStage();
		stage.m_mapInfo.m_name = "Cabal M4A2";
		stage.m_mapInfo.m_path = "media/packages/cabal/maps/cabal";
		stage.m_mapInfo.m_id = "map11";

		stage.addTracker(PeacefulLastBase(m_metagame, 0));

		stage.m_maxSoldiers = 1; // just you and the other guy (if dedicated server, otherwise, might score an AI friendly)

		{
			Faction f(getFactionConfigs()[0], createFellowCommanderAiCommand(0));
			f.m_capacityOffset = 0;
			f.m_capacityMultiplier = 0.0001;
			f.m_bases = 1;
			stage.m_factions.insertLast(f);
		}
		{
			Faction f(getFactionConfigs()[1], createCommanderAiCommand(1,0,0,true));
			f.m_overCapacity = 55;
			f.m_capacityMultiplier = 0.0001;
			stage.m_factions.insertLast(f);
		}

		stage.m_primaryObjective = "attrition"; // "capture"

		return stage;
	}

	// ------------------------------------------------------------------------------------------------
	protected Stage@ setupStage12() {
		Stage@ stage = createStage();
		stage.m_mapInfo.m_name = "Cabal M4A3";
		stage.m_mapInfo.m_path = "media/packages/cabal/maps/cabal";
		stage.m_mapInfo.m_id = "map12";

		stage.addTracker(PeacefulLastBase(m_metagame, 0));

		stage.m_maxSoldiers = 1; // just you and the other guy (if dedicated server, otherwise, might score an AI friendly)

		{
			Faction f(getFactionConfigs()[0], createFellowCommanderAiCommand(0));
			f.m_capacityOffset = 0;
			f.m_capacityMultiplier = 0.0001;
			f.m_bases = 1;
			stage.m_factions.insertLast(f);
		}
		{
			Faction f(getFactionConfigs()[1], createCommanderAiCommand(1,0,0,true));
			f.m_overCapacity = 55;
			f.m_capacityMultiplier = 0.0001;
			stage.m_factions.insertLast(f);
		}

		stage.m_primaryObjective = "attrition"; // "capture"

		return stage;
	}

	protected Stage@ setupStage13() {
		Stage@ stage = createStage();
		stage.m_mapInfo.m_name = "Cabal Final Mission";
		stage.m_mapInfo.m_path = "media/packages/cabal/maps/cabal";
		stage.m_mapInfo.m_id = "map13";

		stage.addTracker(PeacefulLastBase(m_metagame, 0));

		stage.m_maxSoldiers = 1; // just you and the other guy (if dedicated server, otherwise, might score an AI friendly)

		{
			Faction f(getFactionConfigs()[0], createFellowCommanderAiCommand(0));
			f.m_capacityOffset = 0;
			f.m_capacityMultiplier = 0.0001;
			f.m_bases = 1;
			stage.m_factions.insertLast(f);
		}
		{
			Faction f(getFactionConfigs()[1], createCommanderAiCommand(1,0,0,true));
			f.m_overCapacity = 55;
			f.m_capacityMultiplier = 0.0001;
			stage.m_factions.insertLast(f);
		}

		stage.m_primaryObjective = "attrition"; // "capture"


		// enforce no calls for friendly faction in the last map
		{
			XmlElement command("command");
			command.setStringAttribute("class", "faction_resources");
			command.setIntAttribute("faction_id", 0);
			command.setBoolAttribute("clear_calls", true);
			stage.m_extraCommands.insertLast(command);
		}

		return stage;
	}

}

// generated by atlas.exe
#include "world_init.as"
#include "world_marker.as"

// ------------------------------------------------------------------------------------------------
class CabalWorld : World {
	CabalWorld(Metagame@ metagame) {
		super(metagame);
	}

	// ----------------------------------------------------------------------------
	protected Marker getMarker(string key) const {
		return getWorldMarker(key);
	}

	// ----------------------------------------------------------------------------
	protected string getPosition(string key) const {
		return getWorldPosition(key);
	}

	// ------------------------------------------------------------------------------------------------
	protected string getInitCommand() const {
		return getWorldInitCommand();
	}
}
