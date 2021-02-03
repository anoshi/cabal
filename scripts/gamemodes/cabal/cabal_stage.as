#include "metagame.as"
#include "map_info.as"
#include "query_helpers.as"
#include "map_rotator.as"
#include "phase_controller.as"
#include "cabal_faction.as"

// --------------------------------------------
XmlElement@ createFellowCommanderAiCommand(int factionId, float base = 0.62, float border = 0.14, bool active = true) {
	XmlElement command("command");
	command.setStringAttribute("class", "commander_ai");
	command.setIntAttribute("faction", factionId);
	command.setFloatAttribute("base_defense", base);
	command.setFloatAttribute("border_defense", border);
	command.setBoolAttribute("active", active);
	return command;
}

// --------------------------------------------
// enemy will defend a bit harder than attack by default --> makes it easier for player
XmlElement@ createCommanderAiCommand(int factionId, float base = 0.70, float border = 0.14, bool active = true) {
	XmlElement command("command");
	command.setStringAttribute("class", "commander_ai");
	command.setIntAttribute("faction", factionId);
	command.setFloatAttribute("base_defense", base);
	command.setFloatAttribute("border_defense", border);
	command.setBoolAttribute("active", active);
	return command;
}

// --------------------------------------------
class Stage {
	const UserSettings@ m_userSettings;

	MapInfo@ m_mapInfo;

	bool m_finalBattle;
	bool m_hidden;

	// factions involved in this stage
	array<Faction@> m_factions;

	// stage specific tracker classes
	array<Tracker@> m_trackers;

	// stage specific customization through static extra commands
	array<XmlElement@> m_extraCommands;

	array<string> m_includeLayers; // additional, specific layers from the objects.svg file for each map

	float m_fogOffset;
	float m_fogRange;

	// default stage settings, overridden on a per-map basis by cabal_stage_configurator.as
	int m_maxSoldiers = 20;
	float m_soldierCapacityVariance = 0.30;
	string m_soldierCapacityModel = "constant";
	float m_defenseWinTime = -1.0;
	string m_defenseWinTimeMode = "hold_bases";
	string m_primaryObjective = "attrition";
	int m_playerAiCompensation = 0;
	int m_playerAiReduction = 5;

	float m_aiAccuracy = 0.94;

	float m_xpMultiplier = 1.0;
	float m_rpMultiplier = 1.0;

	// --------------------------------------------
	Stage(const UserSettings@ userSettings) {
		@m_userSettings = @userSettings;
		@m_mapInfo = MapInfo();

		m_includeLayers.insertLast("bases.default");
		m_includeLayers.insertLast("layer1.map1");
		m_includeLayers.insertLast("layer1.map2");
		m_includeLayers.insertLast("layer1.map3");
		m_includeLayers.insertLast("layer1.map4");

		// original cabal allowed for a difficulty mode to be used
		// { XmlElement e("weapon");		e.setStringAttribute("file", "all_weapons.xml"); mapConfig.appendChild(e); }
		// { XmlElement e("projectile");	e.setStringAttribute("file", "all_throwables.xml"); mapConfig.appendChild(e); }
		// { XmlElement e("carry_item");	e.setStringAttribute("file", "all_carry_items.xml"); mapConfig.appendChild(e); }
		// { XmlElement e("call");			e.setStringAttribute("file", "all_calls.xml"); mapConfig.appendChild(e); }
		// { XmlElement e("vehicle");		e.setStringAttribute("file", "all_vehicles.xml"); mapConfig.appendChild(e); }

		// const UserSettings@ cabalSettings = cast<const UserSettings>(m_userSettings);
		// if (cabalSettings !is null) {
		// 	if (cabalSettings.m_difficulty == 0) {
		// 		{ XmlElement e("weapon");	e.setStringAttribute("file", "diff_0_rec_weapons.xml"); mapConfig.appendChild(e); }
		// 	} else if (cabalSettings.m_difficulty == 1) {
		// 		{ XmlElement e("weapon");	e.setStringAttribute("file", "diff_1_pro_weapons.xml"); mapConfig.appendChild(e); }
		// 	} else if (cabalSettings.m_difficulty == 2) {
		// 		{ XmlElement e("weapon");	e.setStringAttribute("file", "diff_2_vet_weapons.xml"); mapConfig.appendChild(e); }
		// 	}
		// }
	}

	// --------------------------------------------
	void addTracker(Tracker@ tracker) {
		m_trackers.insertLast(tracker);
	}

	// --------------------------------------------
	// only call this before running the stage
	void removeTracker(Tracker@ tracker) {
		int i = m_trackers.findByRef(tracker);
		if (i != -1) {
			m_trackers.removeAt(i);
		}
	}

	// --------------------------------------------
	bool isFinalBattle() const {
		return m_finalBattle;
	}

	// --------------------------------------------
	bool isHidden() const {
		return m_hidden;
	}

	// --------------------------------------------
	protected void appendIncludeLayers(XmlElement@ mapConfig) const {
		for (uint i = 0; i < m_includeLayers.size(); ++i) {
			string name = m_includeLayers[i];
			XmlElement layer("include_layer");
			layer.setStringAttribute("name", name);
			mapConfig.appendChild(layer);
		}
	}

	// --------------------------------------------
	protected void appendFactions(XmlElement@ mapConfig) const {
		for (uint i = 0; i < m_factions.size(); ++i) {
			Faction@ f = m_factions[i];
			XmlElement faction("faction");
			if (i == 0) {
				// friendly faction always uses basic faction form
				faction.setStringAttribute("file", f.m_config.m_file);
			} else {
				// enemies use different faction settings between regular and final battles
				faction.setStringAttribute("file", (isFinalBattle() ? f.m_config.m_finalBattleFile : f.m_config.m_file));
			}
			mapConfig.appendChild(faction);
		}
	}

	// --------------------------------------------
	protected void appendResources(XmlElement@ mapConfig) const {

		{ XmlElement e("weapon");			e.setStringAttribute("file", "all_weapons.xml"); mapConfig.appendChild(e); }
		{ XmlElement e("projectile");	e.setStringAttribute("file", "all_throwables.xml"); mapConfig.appendChild(e); }
		{ XmlElement e("carry_item");	e.setStringAttribute("file", "all_carry_items.xml"); mapConfig.appendChild(e); }
		{ XmlElement e("call");				e.setStringAttribute("file", "all_calls.xml"); mapConfig.appendChild(e); }
		{ XmlElement e("vehicle");		e.setStringAttribute("file", "all_vehicles.xml"); mapConfig.appendChild(e); }

	}

	// --------------------------------------------
	protected void appendMapLegend(XmlElement@ mapConfig) const {
		XmlElement legend("map_legend");
		legend.setStringAttribute("filename", "invasion_map_legend.xml");
		mapConfig.appendChild(legend);
	}

	// --------------------------------------------
	protected void appendScene(XmlElement@ mapConfig) const {
		XmlElement scene("scene");
		appendCamera(scene);
		appendFog(scene);
		mapConfig.appendChild(scene);
	}

	// --------------------------------------------
	protected void appendCamera(XmlElement@ scene) const {
		XmlElement camera("camera");
		camera.setStringAttribute("direction", "-0.01 -0.22 0.5");
		camera.setFloatAttribute("distance", 17.0);
		camera.setFloatAttribute("far_clip", 195.0);
		camera.setFloatAttribute("shadow_far_clip", 180.0);
		scene.appendChild(camera);
	}
	// distance="12.5" far_clip="80.0"

	// --------------------------------------------
	protected void appendFog(XmlElement@ scene) const {
		XmlElement fog("fog");
		fog.setFloatAttribute("offset", m_fogOffset);
		fog.setFloatAttribute("range", m_fogRange);
		scene.appendChild(fog);
	}

	// --------------------------------------------
	protected void appendOverlays(XmlElement@ command) const {
		string overlays;
		for (uint i = 0; i < m_userSettings.m_overlayPaths.size(); ++i) {
			string path = m_userSettings.m_overlayPaths[i];
			_log("** CABAL: adding overlay " + path);

			XmlElement e("overlay");
			e.setStringAttribute("path", path);
			command.appendChild(e);
		}
	}

	// --------------------------------------------
	XmlElement@ getChangeMapCommand() const {
		XmlElement mapConfig("map_config");

		appendIncludeLayers(mapConfig);
		appendFactions(mapConfig);
		appendResources(mapConfig);
		appendScene(mapConfig);
		appendMapLegend(mapConfig);

		XmlElement command("command");
		command.setStringAttribute("class", "change_map");
		// helps with loading time by avoiding creating most of the stuff before we input the wanted match settings - we aren't using the default ones in invasion
		command.setBoolAttribute("suppress_default_match", true);
		command.setStringAttribute("map", m_mapInfo.m_path);

		appendOverlays(command);

		command.appendChild(mapConfig);

		return command;
	}

	// --------------------------------------------
	array<XmlElement@>@ getExtraCommands() const {
		array<XmlElement@> commands = m_extraCommands;
		return commands;
	}

	// 	m_metagame.setMapInfo(m_mapInfo);

	// 	// reset the list of tracked character Ids
	// 	array<int> trackedCharIds = m_metagame.getTrackedCharIds();
	// 	for (uint i = 0; i < trackedCharIds.length; ++i) {
	// 		m_metagame.removeTrackedCharId(trackedCharIds[i]);
	// 	}

	// 	// // reset game's score display
	// 	// m_metagame.resetScores();
	// 	// _log("** CABAL: Scoreboard Reset", 1);


	// --------------------------------------------
	const XmlElement@ getStartGameCommand(CabalGameMode@ metagame, float completionPercentage = 0.5) const {
		XmlElement command("command");
		command.setStringAttribute("class", "start_game");
		command.setStringAttribute("savegame", "_default");
		command.setIntAttribute("vehicles", 1);
		command.setIntAttribute("max_soldiers", m_maxSoldiers);
		command.setFloatAttribute("soldier_capacity_variance", m_soldierCapacityVariance);
		command.setStringAttribute("soldier_capacity_model", m_soldierCapacityModel);
		command.setFloatAttribute("player_ai_compensation", m_playerAiCompensation);
		command.setFloatAttribute("player_ai_reduction", m_playerAiReduction);
		command.setFloatAttribute("xp_multiplier", m_userSettings.m_xpFactor); // m_xpMultiplier);
		command.setFloatAttribute("rp_multiplier", m_userSettings.m_rpFactor); // m_rpMultiplier);
		command.setFloatAttribute("initial_xp", m_userSettings.m_initialXp);
		command.setIntAttribute("initial_rp", m_userSettings.m_initialRp);
		command.setStringAttribute("base_capture_system", m_userSettings.m_baseCaptureSystem);
		command.setBoolAttribute("friendly_fire", m_userSettings.m_friendlyFire);
		command.setBoolAttribute("clear_profiles_at_start", true);
		command.setBoolAttribute("fov", false);
		command.setBoolAttribute("ensure_alive_local_player_for_save", false);

		if (m_defenseWinTime >= 0) {
			command.setFloatAttribute("defense_win_time", m_defenseWinTime);
			command.setStringAttribute("defense_win_time_mode", m_defenseWinTimeMode);
		}

		for (uint i = 0; i < m_factions.size(); ++i) {
			Faction@ f = m_factions[i];
			XmlElement faction("faction");

			faction.setFloatAttribute("capacity_offset", 0);
			faction.setFloatAttribute("initial_over_capacity", 0);
			faction.setFloatAttribute("capacity_multiplier", 0.0001);

			faction.setFloatAttribute("ai_accuracy", m_aiAccuracy);

			if (i == 0 && f.m_ownedBases.size() > 0) {
				faction.setIntAttribute("initial_occupied_bases", f.m_ownedBases.size());
			} else if (f.m_bases >= 0) {
				faction.setIntAttribute("initial_occupied_bases", f.m_bases);
			}

			faction.setBoolAttribute("lose_without_bases", false);

			command.appendChild(faction);
		}

		{
			XmlElement player("local_player");
			player.setIntAttribute("faction_id", 0); // in cabal, the player is always the 'player' faction
			player.setStringAttribute("username", m_userSettings.m_username);
			command.appendChild(player);
		}

		return command;
	}

}

// --------------------------------------------
class PhasedStage : Stage {
	protected PhaseController@ m_phaseController;

	// --------------------------------------------
	PhasedStage(const UserSettings@ userSettings) {
		super(userSettings);
	}

	// --------------------------------------------
	void setPhaseController(PhaseController@ phaseController) {
		@m_phaseController = @phaseController;
		addTracker(m_phaseController);
	}

	// enable here and create methods in 'Stage' class if we need to load or save anything
	// // --------------------------------------------
	// void save(XmlElement@ root) {
	// 	Stage::save(root);
	// 	if (m_phaseController !is null) {
	// 		m_phaseController.save(root);
	// 	}
	// }

	// // --------------------------------------------
	// void load(const XmlElement@ root) {
	// 	Stage::load(root);
	// 	if (m_phaseController !is null) {
	// 		m_phaseController.load(root);
	// 	}
	// }
}
