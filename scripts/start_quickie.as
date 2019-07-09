// paths containing angel script files
#include "path://media/packages/vanilla/scripts"
#include "path://media/packages/cabal/scripts"
#include "cabal_quickie.as"
#include "cabal_user_settings.as"

void main(dictionary@ inputData) {
	XmlElement inputSettings(inputData);

	CabalUserSettings settings;
	settings.fromXmlElement(inputSettings);
	//_setupLog(inputSettings);
	_setupLog("dev_verbose"); // comment out before go-live
	_log("*** CABAL: start_quickie.as running...",1);
	settings.print();

	array<string> overlays = { "media/packages/cabal" };
    settings.m_overlayPaths = overlays;

	Cabal metagame(settings);

	metagame.init();
	metagame.run();
	metagame.uninit();

	_log("ending execution");
}
