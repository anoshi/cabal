// gamemode specific
#include "faction_config.as"
#include "stage_configurator.as"
#include "cabal_stage.as"

// ------------------------------------------------------------------------------------------------
class CabalStageConfigurator : StageConfigurator {
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
		//addFixedSpecialCrates(stage);
		//addRandomSpecialCrates(stage, stage.m_minRandomCrates, stage.m_maxRandomCrates);

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

	// ------------------------------------------------------------------------------------------------
	protected Stage@ setupStage1() {
		Stage@ stage = createStage();
		stage.m_mapInfo.m_name = "Cabal M1A1";
		stage.m_mapInfo.m_path = "media/packages/cabal/maps/cabal";
		stage.m_mapInfo.m_id = "map1";

		stage.addTracker(PeacefulLastBase(m_metagame, 0));
		stage.m_maxSoldiers = 1; // just you and the other guy (if dedicated server, otherwise, might score an AI friendly)

    	//stage.m_minRandomCrates = 2;
		//stage.m_maxRandomCrates = 4;

		{
			Faction f(getFactionConfigs()[0], createFellowCommanderAiCommand(0));
			f.m_capacityOffset = 0;
			f.m_capacityMultiplier = 0.0001;
			f.m_bases = 1;
			stage.m_factions.insertLast(f);
		}
		{
			Faction f(getFactionConfigs()[1], createCommanderAiCommand(1,0,0,true));
			//f.m_overCapacity = 5;
			f.m_overCapacity = 30;
			f.m_capacityMultiplier = 0.0001;
			stage.m_factions.insertLast(f);
		}

		stage.m_primaryObjective = "capture"; // "attrition";
		stage.m_radioObjectivePresent = false;

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

		stage.addTracker(PeacefulLastBase(m_metagame, 0));

		stage.m_maxSoldiers = 1; // just you and the other guy (if dedicated server, otherwise, might score an AI friendly)

    	//stage.m_minRandomCrates = 2;
		//stage.m_maxRandomCrates = 4;

		{
			Faction f(getFactionConfigs()[0], createFellowCommanderAiCommand(0));
			f.m_capacityOffset = 0;
			f.m_capacityMultiplier = 0.0001;
			f.m_bases = 1;
			stage.m_factions.insertLast(f);
		}
		{
			Faction f(getFactionConfigs()[1], createCommanderAiCommand(1,0,0,true));
			f.m_overCapacity = 30;
			f.m_capacityMultiplier = 0.0001;
			stage.m_factions.insertLast(f);
		}

		stage.m_primaryObjective = "capture"; // "attrition";
		stage.m_radioObjectivePresent = false;

		return stage;
	}

	// ------------------------------------------------------------------------------------------------
	protected Stage@ setupStage3() {
		Stage@ stage = createStage();
		stage.m_mapInfo.m_name = "Cabal M1A3";
		stage.m_mapInfo.m_path = "media/packages/cabal/maps/cabal";
		stage.m_mapInfo.m_id = "map3";

		stage.addTracker(PeacefulLastBase(m_metagame, 0));

		stage.m_maxSoldiers = 1; // just you and the other guy (if dedicated server, otherwise, might score an AI friendly)

   		//stage.m_minRandomCrates = 2;
		//stage.m_maxRandomCrates = 4;

		{
			Faction f(getFactionConfigs()[0], createFellowCommanderAiCommand(0));
			f.m_capacityOffset = 0;
			f.m_capacityMultiplier = 0.0001;
			f.m_bases = 1;
			stage.m_factions.insertLast(f);
		}
		{
			Faction f(getFactionConfigs()[1], createCommanderAiCommand(1,0,0,true));
			f.m_overCapacity = 30;
			f.m_capacityMultiplier = 0.0001;
			stage.m_factions.insertLast(f);
		}

		stage.m_primaryObjective = "attrition"; // "capture"
		stage.m_radioObjectivePresent = false;

		return stage;
	}

	// ------------------------------------------------------------------------------------------------
	protected Stage@ setupStage4() {
		Stage@ stage = createStage();
		stage.m_mapInfo.m_name = "Cabal M2A1";
		stage.m_mapInfo.m_path = "media/packages/cabal/maps/cabal";
		stage.m_mapInfo.m_id = "map4";

		stage.addTracker(PeacefulLastBase(m_metagame, 0));

		stage.m_maxSoldiers = 1; // just you and the other guy (if dedicated server, otherwise, might score an AI friendly)

    	//stage.m_minRandomCrates = 2;
		//stage.m_maxRandomCrates = 4;

		{
			Faction f(getFactionConfigs()[0], createFellowCommanderAiCommand(0));
			f.m_capacityOffset = 0;
			f.m_capacityMultiplier = 0.0001;
			f.m_bases = 1;
			stage.m_factions.insertLast(f);
		}
		{
			Faction f(getFactionConfigs()[1], createCommanderAiCommand(1,0,0,true));
			f.m_overCapacity = 30;
			f.m_capacityMultiplier = 0.0001;
			stage.m_factions.insertLast(f);
		}

		stage.m_primaryObjective = "attrition"; // "capture"
		stage.m_radioObjectivePresent = false;

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

    	//stage.m_minRandomCrates = 2;
		//stage.m_maxRandomCrates = 4;

		{
			Faction f(getFactionConfigs()[0], createFellowCommanderAiCommand(0));
			f.m_capacityOffset = 0;
			f.m_capacityMultiplier = 0.0001;
			f.m_bases = 1;
			stage.m_factions.insertLast(f);
		}
		{
			Faction f(getFactionConfigs()[1], createCommanderAiCommand(1,0,0,true));
			f.m_overCapacity = 30;
			f.m_capacityMultiplier = 0.0001;
			stage.m_factions.insertLast(f);
		}

		stage.m_primaryObjective = "attrition"; // "capture"
		stage.m_radioObjectivePresent = false;

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

    	//stage.m_minRandomCrates = 2;
		//stage.m_maxRandomCrates = 4;

		{
			Faction f(getFactionConfigs()[0], createFellowCommanderAiCommand(0));
			f.m_capacityOffset = 0;
			f.m_capacityMultiplier = 0.0001;
			f.m_bases = 1;
			stage.m_factions.insertLast(f);
		}
		{
			Faction f(getFactionConfigs()[1], createCommanderAiCommand(1,0,0,true));
			f.m_overCapacity = 30;
			f.m_capacityMultiplier = 0.0001;
			stage.m_factions.insertLast(f);
		}

		stage.m_primaryObjective = "attrition"; // "capture"
		stage.m_radioObjectivePresent = false;

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

    	//stage.m_minRandomCrates = 2;
		//stage.m_maxRandomCrates = 4;

		{
			Faction f(getFactionConfigs()[0], createFellowCommanderAiCommand(0));
			f.m_capacityOffset = 0;
			f.m_capacityMultiplier = 0.0001;
			f.m_bases = 1;
			stage.m_factions.insertLast(f);
		}
		{
			Faction f(getFactionConfigs()[1], createCommanderAiCommand(1,0,0,true));
			f.m_overCapacity = 30;
			f.m_capacityMultiplier = 0.0001;
			stage.m_factions.insertLast(f);
		}

		stage.m_primaryObjective = "attrition"; // "capture"
		stage.m_radioObjectivePresent = false;

		return stage;
	}

	// ------------------------------------------------------------------------------------------------
	protected Stage@ setupStage8() {
		Stage@ stage = createStage();
		stage.m_mapInfo.m_name = "Cabal M3A2";
		stage.m_mapInfo.m_path = "media/packages/cabal/maps/cabal";
		stage.m_mapInfo.m_id = "map8";

		//stage.m_includeLayers.insertLast("layer1.campaign"); // this is intentional
		//stage.m_includeLayers.insertLast("layer1.invasion"); // campaign stage configurator shall remove this

		stage.addTracker(PeacefulLastBase(m_metagame, 0));

		stage.m_maxSoldiers = 1; // just you and the other guy (if dedicated server, otherwise, might score an AI friendly)

    	//stage.m_minRandomCrates = 2;
		//stage.m_maxRandomCrates = 4;

		{
			Faction f(getFactionConfigs()[0], createFellowCommanderAiCommand(0));
			f.m_capacityOffset = 0;
			f.m_capacityMultiplier = 0.0001;
			f.m_bases = 1;
			stage.m_factions.insertLast(f);
		}
		{
			Faction f(getFactionConfigs()[1], createCommanderAiCommand(1,0,0,true));
			f.m_overCapacity = 30;
			f.m_capacityMultiplier = 0.0001;
			stage.m_factions.insertLast(f);
		}

		stage.m_primaryObjective = "attrition"; // "capture"
		stage.m_radioObjectivePresent = false;

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

    	//stage.m_minRandomCrates = 2;
		//stage.m_maxRandomCrates = 4;

		{
			Faction f(getFactionConfigs()[0], createFellowCommanderAiCommand(0));
			f.m_capacityOffset = 0;
			f.m_capacityMultiplier = 0.0001;
			f.m_bases = 1;
			stage.m_factions.insertLast(f);
		}
		{
			Faction f(getFactionConfigs()[1], createCommanderAiCommand(1,0,0,true));
			f.m_overCapacity = 30;
			f.m_capacityMultiplier = 0.0001;
			stage.m_factions.insertLast(f);
		}

		stage.m_primaryObjective = "attrition"; // "capture"
		stage.m_radioObjectivePresent = false;

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

    	//stage.m_minRandomCrates = 2;
		//stage.m_maxRandomCrates = 4;

		{
			Faction f(getFactionConfigs()[0], createFellowCommanderAiCommand(0));
			f.m_capacityOffset = 0;
			f.m_capacityMultiplier = 0.0001;
			f.m_bases = 1;
			stage.m_factions.insertLast(f);
		}
		{
			Faction f(getFactionConfigs()[1], createCommanderAiCommand(1,0,0,true));
			f.m_overCapacity = 30;
			f.m_capacityMultiplier = 0.0001;
			stage.m_factions.insertLast(f);
		}

		stage.m_primaryObjective = "attrition"; // "capture"
		stage.m_radioObjectivePresent = false;

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

    	//stage.m_minRandomCrates = 2;
		//stage.m_maxRandomCrates = 4;

		{
			Faction f(getFactionConfigs()[0], createFellowCommanderAiCommand(0));
			f.m_capacityOffset = 0;
			f.m_capacityMultiplier = 0.0001;
			f.m_bases = 1;
			stage.m_factions.insertLast(f);
		}
		{
			Faction f(getFactionConfigs()[1], createCommanderAiCommand(1,0,0,true));
			f.m_overCapacity = 30;
			f.m_capacityMultiplier = 0.0001;
			stage.m_factions.insertLast(f);
		}

		stage.m_primaryObjective = "attrition"; // "capture"
		stage.m_radioObjectivePresent = false;

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

		//stage.m_minRandomCrates = 2;
		//stage.m_maxRandomCrates = 4;

		{
			Faction f(getFactionConfigs()[0], createFellowCommanderAiCommand(0));
			f.m_capacityOffset = 0;
			f.m_capacityMultiplier = 0.0001;
			f.m_bases = 1;
			stage.m_factions.insertLast(f);
		}
		{
			Faction f(getFactionConfigs()[1], createCommanderAiCommand(1,0,0,true));
			f.m_overCapacity = 30;
			f.m_capacityMultiplier = 0.0001;
			stage.m_factions.insertLast(f);
		}

		stage.m_primaryObjective = "attrition"; // "capture"
		stage.m_radioObjectivePresent = false;

		return stage;
	}

	protected Stage@ setupStage13() {
		Stage@ stage = createStage();
		stage.m_mapInfo.m_name = "Cabal Final Mission";
		stage.m_mapInfo.m_path = "media/packages/cabal/maps/cabal";
		stage.m_mapInfo.m_id = "map13";

		stage.addTracker(PeacefulLastBase(m_metagame, 0));

		stage.m_maxSoldiers = 1; // just you and the other guy (if dedicated server, otherwise, might score an AI friendly)

    	//stage.m_minRandomCrates = 2;
		//stage.m_maxRandomCrates = 4;

		{
			Faction f(getFactionConfigs()[0], createFellowCommanderAiCommand(0));
			f.m_capacityOffset = 0;
			f.m_capacityMultiplier = 0.0001;
			f.m_bases = 1;
			stage.m_factions.insertLast(f);
		}
		{
			Faction f(getFactionConfigs()[1], createCommanderAiCommand(1,0,0,true));
			f.m_overCapacity = 30;
			f.m_capacityMultiplier = 0.0001;
			stage.m_factions.insertLast(f);
		}

		stage.m_primaryObjective = "attrition"; // "capture"
		stage.m_radioObjectivePresent = false;

		// no calls for friendly faction in the last map
		{
			XmlElement command("command");
			command.setStringAttribute("class", "faction_resources");
			command.setIntAttribute("faction_id", 0);
			command.setBoolAttribute("clear_calls", true);
			stage.m_extraCommands.insertLast(command);
		}

		return stage;
	}


	// --------------------------------------------
	array<XmlElement@>@ getFactionResourceConfigChangeCommands(float completionPercentage, Stage@ stage) {
		array<XmlElement@>@ commands = getFactionResourceChangeCommands(stage.m_factions.size());

		_log("completion percentage: " + completionPercentage);

		const UserSettings@ settings = m_metagame.getUserSettings();
		_log(" variance enabled: " + settings.m_completionVarianceEnabled);
		if (settings.m_completionVarianceEnabled) {
			array<XmlElement@>@ varianceCommands = getCompletionVarianceCommands(stage, completionPercentage);
			// append with command already gathered
			merge(commands, varianceCommands);
		}

		merge(commands, stage.m_extraCommands);

		return commands;
	}

	// --------------------------------------------
	protected array<XmlElement@>@ getFactionResourceChangeCommands(int factionCount) const {
		array<XmlElement@> commands;

		// invasion faction resources are nowadays based on resources declared for factions in the faction files
		// + some minor changes for common and friendly
		for (int i = 0; i < factionCount; ++i) {
			commands.insertLast(getFactionResourceChangeCommand(i, getCommonFactionResourceChanges()));
		}

		// apply initial friendly faction resource modifications
		commands.insertLast(getFactionResourceChangeCommand(0, getFriendlyFactionResourceChanges()));

		return commands;
	}

	// --------------------------------------------
	protected array<ResourceChange@>@ getCommonFactionResourceChanges() const {
		array<ResourceChange@> list;

		list.push_back(ResourceChange(Resource("armored_truck.vehicle", "vehicle"), false));
		list.push_back(ResourceChange(Resource("mobile_armory.vehicle", "vehicle"), false));

		// disable certain weapons here; mainly because Dominance uses the same .resources files but we have further changes for Invasion here
		list.push_back(ResourceChange(Resource("l85a2.weapon", "weapon"), false));
		list.push_back(ResourceChange(Resource("famasg1.weapon", "weapon"), false));
		list.push_back(ResourceChange(Resource("sg552.weapon", "weapon"), false));
		list.push_back(ResourceChange(Resource("minig_resource.weapon", "weapon"), false));
		list.push_back(ResourceChange(Resource("tow_resource.weapon", "weapon"), false));
		list.push_back(ResourceChange(Resource("gl_resource.weapon", "weapon"), false));

		return list;
	}

	// --------------------------------------------
	protected array<ResourceChange@> getFriendlyFactionResourceChanges() const {
		array<ResourceChange@> list;

		// enable mobile spawn and armory trucks for player faction
		list.push_back(ResourceChange(Resource("armored_truck.vehicle", "vehicle"), true));
		list.push_back(ResourceChange(Resource("mobile_armory.vehicle", "vehicle"), true));

		// no m79 for friendlies
		list.push_back(ResourceChange(Resource("m79.weapon", "weapon"), false));

		// no suitcases/laptops carried by friendlies
		list.push_back(ResourceChange(Resource("suitcase.carry_item", "carry_item"), false));
		list.push_back(ResourceChange(Resource("laptop.carry_item", "carry_item"), false));

		// no cargo, prisons or aa
		list.push_back(ResourceChange(Resource("cargo_truck.vehicle", "vehicle"), false));
		list.push_back(ResourceChange(Resource("prison_door.vehicle", "vehicle"), false));
		list.push_back(ResourceChange(Resource("prison_bus.vehicle", "vehicle"), false));
		list.push_back(ResourceChange(Resource("aa_emplacement.vehicle", "vehicle"), false));

		return list;
	}

	// --------------------------------------------
	protected array<XmlElement@>@ getCompletionVarianceCommands(Stage@ stage, float completionPercentage) {
		// we want to have a sense of progression
		// with the starting map vs other maps played before extra final maps

		array<XmlElement@> commands;

		if (stage.isFinalBattle()) {
			// don't use for final battles
			return commands;
		}

		if (completionPercentage < 0.08) {
			_log("below 10%");
			for (uint i = 0; i < stage.m_factions.size(); ++i) {
				// disable comms truck, cargo and radio tower on all factions, same for prisons
				array<string> keys = {
					"radar_truck.vehicle",
					"cargo_truck.vehicle",
					"radar_tower.vehicle",
					"prison_bus.vehicle",
					"prison_door.vehicle",
					"aa_emplacement.vehicle",
					"m113_tank_mortar.vehicle" };

				if (i == 0) {
					// let friendlies have the tank, need it to make a successful tank call
				} else {
					// disable tanks for enemy factions
					keys.insertLast("tank.vehicle");
					keys.insertLast("tank_1.vehicle");
					keys.insertLast("tank_2.vehicle");
				}

				if (keys.size() > 0) {
					XmlElement command("command");
					command.setStringAttribute("class", "faction_resources");
					command.setIntAttribute("faction_id", i);
					addFactionResourceElements(command, "vehicle", keys, false);

					commands.insertLast(command);
				}
			}
			// a bit odd that we change stage members here in a getter function, but just do it for now, it's just metadata
			stage.m_radioObjectivePresent = false;

		} else if (completionPercentage < 0.20) {
			_log("below 25%, above 10%");
			for (uint i = 0; i < stage.m_factions.size(); ++i) {
				array<string> keys;

				if (i == 0) {
					// disable comms truck and radio tower on friendly faction only
					keys.insertLast("radar_truck.vehicle");
					keys.insertLast("radar_tower.vehicle");

					// cargo & prisons are disabled anyway for friendly faction
				} else {
				}

				if (keys.size() > 0) {
					XmlElement command("command");
					command.setStringAttribute("class", "faction_resources");
					command.setIntAttribute("faction_id", i);
					addFactionResourceElements(command, "vehicle", keys, false);

					commands.insertLast(command);
				}
			}
		}

		return commands;
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
