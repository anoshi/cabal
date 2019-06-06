// ----------------------------------------------------------------------------
class Marker {
	string m_size;
	string m_rect;
};

// ----------------------------------------------------------------------------
abstract class World {
	protected Metagame@ m_metagame;

	protected dictionary m_mapIdToRegionIndex;
	protected string m_worldInitCommand;

	// --------------------------------------------
	World(Metagame@ metagame) {
		@m_metagame = @metagame;
	}

	// ----------------------------------------------------------------------------
	protected string getOffenderVisualCommand(string transportName, int colorFactionId, int id) const {
		// provide implementation in derived class
		return "";
	}

	// ----------------------------------------------------------------------------
	protected Marker getMarker(string key) const {
		// provide implementation in derived class
		return Marker();
	}

	// ----------------------------------------------------------------------------
	protected string getPosition(string key) const {
		// provide implementation in derived class
		return "";
	}

	// ----------------------------------------------------------------------------
	protected string getInitCommand() const {
		// provide implementation in derived class
		return "";
	}

	// ----------------------------------------------------------------------------
	void init(dictionary mapIdToRegionIndex) {
		m_mapIdToRegionIndex = mapIdToRegionIndex;
	}

	// ----------------------------------------------------------------------------
	void setup(const array<FactionConfig@>@ factionConfigs, const array<Stage@>@ stages, const array<int>@ stagesCompleted, int currentStageIndex) {
		m_metagame.getComms().send(getInitCommand());

		// Cabal uses two colors, non completed stages and completed stages,
		// we'll setup world situation to have factions for these two states

		{
			string command = "<command class='set_world_situation'>";
			for (uint i = 0; i < 2; ++i) {
				string name = i == 0 ? "not_completed" : "completed";
				string color = i == 0 ? "1 1 1 0" : "1 0 0 0.5";
				command += "<faction id='" + i + "' name='" + name + "' color='" + color + "' />";
			}
			command += "</command>";
			m_metagame.getComms().send(command);
		}

		// send world view setup
		refresh(stages, stagesCompleted, currentStageIndex);

		// set current location in world view
		setCurrentLocation(stages[currentStageIndex]);
	}

	// ----------------------------------------------------------------------------
	void setAdvance(string currentMapId, string nextMapId) {
	}

	// ----------------------------------------------------------------------------
	protected int convertMapIdToRegionIndex(string mapId) const {
		if (m_mapIdToRegionIndex.exists(mapId)) {
			int value = 0;
			m_mapIdToRegionIndex.get(mapId, value);
			return value;
		}
		return -1;
	}

	// ----------------------------------------------------------------------------
	protected string getRegionSituation(Stage@ stage, bool completed) const {
		int regionIndex = convertMapIdToRegionIndex(stage.m_mapInfo.m_id);
		if (regionIndex < 0) return "";

		string situation = "<region id='" + regionIndex + "'>\n";

		int factionIndex = completed ? 1 : 0;
		float ratio = 1.0;
		situation += "<occupant id='" + factionIndex + "' value='" + ratio + "'/>\n";

		situation += "</region>\n";

		return situation;
	}

	// ----------------------------------------------------------------------------
	void refresh(const array<Stage@>@ stages, const array<int>@ stagesCompleted, int currentStageIndex) {
		array<string> regionSituations;
		for (uint i = 0; i < stages.size(); ++i) {
			Stage@ stage = stages[i];
			// the regions are added in the list with stage keys in stage order!
			bool completed = stagesCompleted.find(i) >= 0;
			string value = getRegionSituation(stage, completed);
			if (value != "") {
				regionSituations.insertLast(value);
			}
		}

		// regions
		{
			int locationVisualIndex = 100;
			string command = "<command class='set_world_situation'>";
			for (uint stageIndex = 0; stageIndex < regionSituations.size(); ++stageIndex) {
				_log("* stageIndex=" + stageIndex);
				string value = regionSituations[stageIndex];
				Stage@ stage = stages[stageIndex];
				int regionIndex = convertMapIdToRegionIndex(stage.m_mapInfo.m_id);

				command += value;

				command += getVisualTag(locationVisualIndex, 1, getPosition(stage.m_mapInfo.m_id), getMarker("map_point"), -1);
				locationVisualIndex++;
			}
			command += "</command>";
			m_metagame.getComms().send(command);
		}
	}

	// ----------------------------------------------------------------------------
	protected void clearVisuals(const array<int>@ visualIds) {
		string command = "<command class='set_world_situation'>";
		for (uint i = 0; i < visualIds.size(); ++i) {
			int value = visualIds[i];
			string p = "<visual id='" + value + "' layer='1' enabled='false' />";
			command += p;
		}
		command +="</command>";

		m_metagame.getComms().send(command);
	}

	// ----------------------------------------------------------------------------
	void setAvailableTransports(array<string>@ transports) {
	}

	// ----------------------------------------------------------------------------
	protected string getVisualTag(int id, int layer, string position, const Marker@ marker, int factionColorId) {
		return "<visual id='" + id + "' layer='" + layer + "' position='" + position + "' size='" + marker.m_size + "' texture_rect='" + marker.m_rect + "' color='1 1 1' />";
	}

	// ----------------------------------------------------------------------------
	protected string getVisualCommand(string visualTag) {
		return "<command class='set_world_situation'>" + visualTag + "</command>";
	}

	// ----------------------------------------------------------------------------
	void setCurrentLocation(Stage@ stage) {
		string mapId = stage.m_mapInfo.m_id;

		string command = getVisualCommand(getVisualTag(200, 1, getPosition(mapId), getMarker("cursor"), 0));

		m_metagame.getComms().send(command);
	}
}
