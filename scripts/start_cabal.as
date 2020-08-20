// paths containing angel script files
#include "path://media/packages/vanilla/scripts"
#include "path://media/packages/cabal/scripts"

#include "cabal_gamemode.as"
#include "cabal_user_settings.as"

void main(dictionary@ inputData) {
	XmlElement inputSettings(inputData);

	UserSettings settings;	// overrides RWR UserSettings class, see cabal_user_settings.as
	settings.readSettings(inputSettings);
	_setupLog(inputSettings);
	_log("** CABAL: start_cabal.as running...",1);
	settings.print();

	CabalGameMode metagame(settings); //

	metagame.init();
	metagame.run();
	metagame.uninit();

	_log("** CABAL: ending execution");
}
