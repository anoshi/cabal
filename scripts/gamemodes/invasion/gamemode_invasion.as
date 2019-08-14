// internal
#include "gamemode.as"
#include "map_info.as"
#include "log.as"

// cabal gamemode-specific
#include "cabal_map_rotator.as"
#include "cabal_stage_configurator.as"
//#include "cabal_user_settings.as"
//#include "user_settings.as"
#include "resource_lifecycle_handler_invasion.as"
#include "cabal_spawner_invasion.as"
#include "player_manager.as"

// generic trackers
#include "basic_command_handler.as"

// --------------------------------------------
class GameModeInvasion : GameMode {
	protected MapRotatorInvasion@ m_mapRotator;
	protected array<Faction@> m_factions;

	// TODO: can we avoid this?
	string m_gameMapPath = "";

	protected CabalUserSettings@ m_userSettings;
	protected ResourceLifecycleHandler@ m_resourceLifecycleHandler;
	protected PlayerManager@ m_playerManager;

	// --------------------------------------------
	GameModeInvasion(CabalUserSettings@ settings) {
		super(settings.m_startServerCommand);

		@m_userSettings = @settings;
	}

	// --------------------------------------------
	void init() {
		GameMode::init();

		setupMapRotator();
		setupPlayerManager(); // cabal dedicated server only
		setupResourceLifecycle();

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

	protected void setupResourceLifecycle() {
		@m_resourceLifecycleHandler = ResourceLifecycleHandler(this);
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

	// cabal dedicated server only
	// --------------------------------------------
	protected void setupPlayerManager() {
		@m_playerManager = PlayerManager(this);
	}

	// --------------------------------------------
	PlayerManager@ getPlayerManager() const {
		return m_playerManager;
	}
	// end cabal dedicated server only

	// --------------------------------------------
	// CabalMapRotator calls here when a battle is about to start
	void preBeginMatch() {
		_log("preBeginMatch", 1);

		// all trackers are cleared when match is about to begin
		GameMode::preBeginMatch();

		addTracker(m_mapRotator);
	}

	// --------------------------------------------
	// CabalMapRotator calls here when a battle has started
	void postBeginMatch() {
		GameMode::postBeginMatch();

		// query for basic match data -- we mostly need the savegame location
		updateGeneralInfo();
		save();

		addTracker(BasicCommandHandler(this));

		// Cabal handlers:
		addTracker(m_resourceLifecycleHandler);
		//addTracker(ResourceLifecycleHandler(this)); // players, enemies, objects, etc.
		addTracker(CabalSpawner(this));

		// multiplayer handler
		addTracker(PlayerManager(this));

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

		} else {
			// enemy
			multiplier = m_userSettings.m_enemyCapacityFactor * f.m_capacityMultiplier;
		}

		return multiplier;
	}

	// --------------------------------------------
	void save() {
		// save metagame status now:
		_log("*** CABAL: GameModeInvasion::saving metagame", 1);

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
