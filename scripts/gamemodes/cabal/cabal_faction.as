// --------------------------------------------
// match-specific faction settings
class Faction {
	FactionConfig@ m_config;

	int m_bases = -1;

	float m_overCapacity = 0;
	int m_capacityOffset = 0;
	float m_capacityMultiplier = 0; //0.0001;

	// this is optional
	array<string> m_ownedBases;

	Faction(FactionConfig@ factionConfig) {
		@m_config = @factionConfig;
	}

	void makeNeutral() {
		m_capacityMultiplier = 0.0;
	}

	bool isNeutral() {
		return m_capacityMultiplier <= 0.0;
	}

	string getName() {
		return m_config.m_name;
	}
}

// --------------------------------------------
class FactionConfig {
	int m_index = -1;
	string m_file = "unset faction file";
	string m_name = "unset faction name";
	string m_color = "0 0 0";

	FactionConfig(int index, string file, string name, string color) {
		m_index = index;
		m_file = file;
		m_name = name;
		m_color = color;
	}
};
