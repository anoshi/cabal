// internal
#include "gamemode.as"
#include "map_info.as"
#include "log.as"

// cabal gamemode-specific
#include "cabal_map_rotator.as"
#include "cabal_stage_configurator.as"
#include "cabal_user_settings.as"
#include "resource_lifecycle_handler_invasion.as"
#include "call_handler.as"
#include "dummy_vehicle_handler.as"

// generic trackers
#include "basic_command_handler.as"
#include "autosaver.as"
#include "prison_break_objective.as"
// #include "special_vehicle_manager.as" // if we choose to use this


// --------------------------------------------
class GameModeInvasion : GameMode {
	protected MapRotatorInvasion@ m_mapRotator;

	protected array<Faction@> m_factions;

	// TODO: can we avoid this?
	string m_gameMapPath = "";

	protected CabalUserSettings@ m_userSettings;

	// --------------------------------------------
	GameModeInvasion(CabalUserSettings@ settings) {
		super(settings.m_startServerCommand);

		@m_userSettings = @settings;
	}

	// --------------------------------------------
	void init() {
		GameMode::init();

		// @m_playerLifeSpanHandler = PlayerLifeSpanHandler(this); // cabal dedicated server only

		setupMapRotator();
		// setupPlayerManager(); // cabal dedicated server only

		//setupSpecialCrateManager(); // if we choose to use it

		if (m_userSettings.m_continue) {
			_log("* restoring old game");

			// if loading, load metagame first
			updateGeneralInfo();
			load();
			// note, load handles initing map rotator / unlock_manager / etc at appropriate time

			m_mapRotator.startRotation(true);
		} else {
			m_mapRotator.init();
			m_mapRotator.startRotation();
		}

		if (!getAdminManager().isAdmin(getUserSettings().m_username)) {
			getAdminManager().addAdmin(getUserSettings().m_username);
		}
	}

	// --------------------------------------------
	void uninit() {
		// save before parent uninit, parent uninitializes comms
		save();
		GameMode::uninit();
	}

	// --------------------------------------------
	protected void setupMapRotator() {
		@m_mapRotator = CabalMapRotator(this);
		CabalStageConfigurator configurator(this, m_mapRotator);
	}

	// --------------------------------------------
	protected void updateGeneralInfo() {
		const XmlElement@ general = getGeneralInfo(this);
		if (general !is null) {
			m_gameMapPath = general.getStringAttribute("map");
		}
	}

	// --------------------------------------------
	const CabalUserSettings@ getUserSettings() const {
		return m_userSettings;
	}

	/* // cabal dedicated server only
	// --------------------------------------------
	protected void setupPlayerManager() {
		@m_playerManager = PlayerManager(this);
	}

	// --------------------------------------------
	PlayerManager@ getPlayerManager() const {
		return m_playerManager;
	}

	// --------------------------------------------
	// may want to do something in the future with destroyable crates that spawn goodies.
	protected void setupSpecialCrateManager() {
		array<string> trackedCrates;
		trackedCrates.push_back("special_crate1.vehicle");
		trackedCrates.push_back("special_crate2.vehicle");
		trackedCrates.push_back("special_crate3.vehicle");
		trackedCrates.push_back("special_crate4.vehicle");
		trackedCrates.push_back("special_crate5.vehicle");
		trackedCrates.push_back("special_crate6.vehicle");
		trackedCrates.push_back("special_crate7.vehicle");
		trackedCrates.push_back("special_crate8.vehicle");
		trackedCrates.push_back("special_crate9.vehicle");
		trackedCrates.push_back("special_crate10.vehicle");
		trackedCrates.push_back("special_crate_wood1.vehicle");
		trackedCrates.push_back("special_crate_wood2.vehicle");
		trackedCrates.push_back("special_crate_wood3.vehicle");
		trackedCrates.push_back("special_crate_wood4.vehicle");
		trackedCrates.push_back("special_crate_wood5.vehicle");
		trackedCrates.push_back("special_crate_wood6.vehicle");
		trackedCrates.push_back("special_crate_wood7.vehicle");
		trackedCrates.push_back("special_crate_wood8.vehicle");
		trackedCrates.push_back("special_crate_wood9.vehicle");
		trackedCrates.push_back("special_crate_wood10.vehicle");
		@m_specialCrateManager = SpecialVehicleManager(this, "special_crate_manager", trackedCrates);
	}
	*/

	// --------------------------------------------
	// CabalMapRotator calls here when a battle is about to start
	void preBeginMatch() {
		_log("preBeginMatch", 1);

		// all trackers are cleared when match is about to begin
		GameMode::preBeginMatch();

		addTracker(m_mapRotator);

		// again, if decide to use special crates
		/*if (m_specialCrateManager !is null) {
			addTracker(m_specialCrateManager);
			m_specialCrateManager.applyAvailability();
		}*/
	}

	// --------------------------------------------
	// CabalMapRotator calls here when a battle has started
	void postBeginMatch() {
		GameMode::postBeginMatch();

		// query for basic match data -- we mostly need the savegame location
		updateGeneralInfo();
		save();

		addTracker(PrisonBreakObjective(this, 0)); // save your friends, unleash comedic carnage!
		addTracker(AutoSaver(this));
		addTracker(BasicCommandHandler(this));

		// Cabal handlers:
		addTracker(ResourceLifecycleHandler(this)); // players, enemies, objects, etc.
		addTracker(CallHandler(this));				// 'H' call menu and scripted call handler
		addTracker(DummyVehicleHandler(this));		// Performs tasks when (dummy) vehicles are destroyed


		for (uint i = 0; i < m_factions.size(); ++i) {
			if (i != 0) {
				XmlElement c("command");
				c.setStringAttribute("class", "commander_ai");
				c.setIntAttribute("faction", i);
				c.setBoolAttribute("distribute_defense", false);
				getComms().send(c);
			}
		}
	}

	/*
	// --------------------------------------------
	protected void trackerCompleted(Tracker@ tracker) {
	}
	*/

	// --------------------------------------------
	// map rotator is the one that actually defines which factions are in the game and which default values are used,
	// it will feed us the faction data
	void setFactions(const array<Faction@>@ factions) {
		m_factions = factions;
	}

	// --------------------------------------------
	// map rotator lets us know some specific map related information we need for handling position mapping
	void setMapInfo(const MapInfo@ info) {
		m_mapInfo = info;
	}

	// --------------------------------------------
	// trackers may need to alter things about faction settings and be able to reset them back to defaults,
	// we'll provide the data from here
	const array<Faction@>@ getFactions() const {
		return m_factions;
	}

	// --------------------------------------------
	uint getFactionCount() const {
		return m_factions.size();
	}

	// --------------------------------------------
	const array<FactionConfig@>@ getFactionConfigs() const {
		// in invasion, map rotator decides faction configs
		return m_mapRotator.getFactionConfigs();
	}

	// --------------------------------------------
	float determineFinalFactionCapacityMultiplier(const Faction@ f, uint key) const {
		float completionPercentage = m_mapRotator.getCompletionPercentage();

		float multiplier = 1.0f;
		if (key == 0) {
			// friendly faction
			multiplier = m_userSettings.m_fellowCapacityFactor * f.m_capacityMultiplier;

			if (m_userSettings.m_completionVarianceEnabled) {
				// drain friendly faction power the farther the game goes;
				// player will gain power and will become more effective, so this works as an attempt to counter that a bit
				_log("completion: " + completionPercentage);
				if (completionPercentage > 0.8f) {
					multiplier *= 0.9f;
				} else if (completionPercentage > 0.6f) {
					multiplier *= 0.93f;
				} else if (completionPercentage > 0.4f) {
					multiplier *= 0.97f;
				}
			}

		} else {
			// enemy
			multiplier = m_userSettings.m_enemyCapacityFactor * f.m_capacityMultiplier;

			if (m_userSettings.m_completionVarianceEnabled) {
				// first map: reduce enemies a bit, let it flow easier
				if (completionPercentage < 0.09f) {
					multiplier *= 0.97f;
				}
			}
		}

		return multiplier;
	}

	// --------------------------------------------
	void save() {
		// save metagame status now:
		_log("saving metagame", 1);

		XmlElement commandRoot("command");
		commandRoot.setStringAttribute("class", "save_data");

		XmlElement root("saved_metagame");

		m_mapRotator.save(root);

		// append user-settings in too
		XmlElement@ settings = m_userSettings.toXmlElement("settings");
		root.appendChild(settings);

		commandRoot.appendChild(root);

		// save through game
		getComms().send(commandRoot);
	}

	// --------------------------------------------
	void load() {
		// load metagame status now:
		_log("loading metagame", 1);

		XmlElement@ query = XmlElement(
			makeQuery(this, array<dictionary> = {
				dictionary = { {"TagName", "data"}, {"class", "saved_data"} } }));
		const XmlElement@ doc = getComms().query(query);

		if (doc !is null) {
			const XmlElement@ root = doc.getFirstChild();
			// read user-settings too, have them around separately..
			const XmlElement@ settings = root.getFirstElementByTagName("settings");
			if (settings !is null) {
				m_userSettings.fromXmlElement(settings);
				m_userSettings.m_continue = true;
			}

			m_userSettings.print();

			m_mapRotator.init();
			m_mapRotator.load(root);

			_log("loaded", 1);
		} else {
			_log("load failed");
			m_mapRotator.init();
		}
	}


	// --------------------------------------------
	// helpers and convenience functions
	// --------------------------------------------
	string getMapId() const {
		return m_mapInfo.m_path;
	}

	// --------------------------------------------------------
	const XmlElement@ queryLocalPlayer() const {
		array<const XmlElement@> players = getGenericObjectList(this, "players", "player");
		const XmlElement@ player = null;
		for (uint i = 0; i < players.size(); ++i) {
			const XmlElement@ info = players[i];

			string name = info.getStringAttribute("name");

			_log("player: " + name + ", target player is " + m_userSettings.m_username);
			if (name == m_userSettings.m_username) {
				_log("ok");
				@player = @info;
				break;
			} else {
				_log("no match");
			}
		}
		return player;
	}
}
