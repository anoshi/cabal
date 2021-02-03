// --------------------------------------------
// stage-specific faction info
class Faction {
	const FactionConfig@ m_config;
	XmlElement@ m_defaultCommanderAiCommand;

	int m_bases;

	int m_overCapacity;
	float m_capacityMultiplier;
	int m_capacityOffset;
	bool m_loseWithoutBases;

	// this is optional
	array<int> m_ownedBases;

	Faction(const FactionConfig@ config, XmlElement@ defaultCommand) {
		@m_config = @config;
		@m_defaultCommanderAiCommand = @defaultCommand;
		m_bases = -1;
		m_overCapacity = 0;
		m_capacityMultiplier = 1.0;
		m_capacityOffset = 0;
		m_loseWithoutBases = true;
	}

	bool isNeutral() const {
		return m_capacityMultiplier <= 0.0;
	}

	string getName() const {
		return m_config.m_name;
	}
};
