#include "metagame.as"
#include "map_info.as"
#include "query_helpers.as"
#include "map_rotator.as"

#include "cabal_faction.as"

// --------------------------------------------
class Stage {
	protected CabalGameMode@ m_metagame;
	protected CabalMapRotator@ m_mapRotator;

	MapInfo@ m_mapInfo;
	int m_mapIndex = -1;

	array<FactionConfig@> m_factionConfigs;

	array<string> m_includeLayers; // additional, specific layers from the objects.svg file for each map
	array<string> m_resourcesToLoad;

	// default stage settings, overridden on a per-map basis by cabal_map_rotator.as
	int m_maxSoldiers = 20;
	float m_soldierCapacityVariance = 0.30;
	string m_soldierCapacityModel = "constant";
	float m_defenseWinTime = -1.0;
	string m_defenseWinTimeMode = "hold_bases";
	int m_playerAiCompensation = 0;
	int m_playerAiReduction = 5;
	string m_baseCaptureSystem = "any";

	array<Faction@> m_factions;

	float m_aiAccuracy = 0.94;

	float m_xpMultiplier = 1.0;
	float m_rpMultiplier = 1.0;

	// --------------------------------------------
	Stage(CabalGameMode@ metagame, CabalMapRotator@ mapRotator) {
		@m_metagame = @metagame;
		@m_mapRotator = @mapRotator;
		@m_mapInfo = MapInfo();

		m_resourcesToLoad.insertLast("<weapon file='all_weapons.xml' />");
		m_resourcesToLoad.insertLast("<projectile file='all_throwables.xml' />");
		m_resourcesToLoad.insertLast("<call file='all_calls.xml' />");
		m_resourcesToLoad.insertLast("<carry_item file='all_carry_items.xml' />");
		m_resourcesToLoad.insertLast("<vehicle file='all_vehicles.xml' />");

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
	void start() {
		_log("** CABAL: Stage::start");

		m_metagame.setMapInfo(m_mapInfo);

		// reset the list of tracked character Ids
		array<int> trackedCharIds = m_metagame.getTrackedCharIds();
		for (uint i = 0; i < trackedCharIds.length; ++i) {
			m_metagame.removeTrackedCharId(trackedCharIds[i]);
		}

		// // reset game's score display
		// m_metagame.resetScores();
		// _log("** CABAL: Scoreboard Reset", 1);

		m_metagame.preBeginMatch();
		m_metagame.setFactions(m_factions);
		// start game
		const XmlElement@ startGameCommand = getStartGameCommand(m_metagame);
		m_metagame.getComms().send(startGameCommand);

		m_metagame.getUserSettings();
	}

	// --------------------------------------------
	string getChangeMapCommand() {
		string mapConfig = "<map_config>\n";

		for (uint i = 0; i < m_includeLayers.length(); ++i) {
			mapConfig += "<include_layer name='" + m_includeLayers[i] + "' />\n";
		}
		for (uint i = 0; i < m_factionConfigs.length(); ++i) {
			mapConfig += "<faction file='" + m_factionConfigs[i].m_file + "' />\n";
		}
		for (uint i = 0; i < m_resourcesToLoad.length(); ++i) {
			mapConfig += m_resourcesToLoad[i] + "\n";
		}
		mapConfig += "</map_config>\n";

		// string overlays = "";
		// for (uint i = 0; i < m_metagame.getUserSettings().m_overlayPaths.length(); ++i) {
		// 	string path = m_metagame.getUserSettings().m_overlayPaths[i];
		// 	_log("adding overlay " + path);
		// 	overlays += "<overlay path='" + path + "' />\n";
		// }

		string changeMapCommand =
			"<command class='change_map'" +
			"	map='" + m_mapInfo.m_path + "'>" +
			// overlays +
			mapConfig +
			"</command>";

		return changeMapCommand;
	}

	// --------------------------------------------
	const XmlElement@ getStartGameCommand(CabalGameMode@ metagame) const {
		XmlElement command("command");
		command.setStringAttribute("class", "start_game");
		command.setStringAttribute("savegame", "_default");
		command.setIntAttribute("vehicles", 1);
		command.setIntAttribute("max_soldiers", m_maxSoldiers);
		command.setFloatAttribute("soldier_capacity_variance", m_soldierCapacityVariance);
		command.setStringAttribute("soldier_capacity_model", m_soldierCapacityModel);
		command.setFloatAttribute("player_ai_compensation", m_playerAiCompensation);
		command.setFloatAttribute("player_ai_reduction", m_playerAiReduction);
		command.setFloatAttribute("xp_multiplier", m_xpMultiplier);
		command.setFloatAttribute("rp_multiplier", m_rpMultiplier);
		command.setFloatAttribute("initial_xp", m_metagame.getUserSettings().m_initialXp);
		command.setIntAttribute("initial_rp", m_metagame.getUserSettings().m_initialRp);
		command.setStringAttribute("base_capture_system", m_baseCaptureSystem);
		command.setBoolAttribute("friendly_fire", true); // may want to go user-specified
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
			player.setIntAttribute("faction_id", m_metagame.getUserSettings().m_factionChoice);
			player.setStringAttribute("username", m_metagame.getUserSettings().m_username);
			command.appendChild(player);
		}

		return command;
	}

}
