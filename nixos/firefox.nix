{ pkgs, ... }:
{
  programs.firefox = {
    enable = true;
    languagePacks = [ "en-US" ];
    policies = {
      AppAutoUpdate = false;
      BackgroundAppUpdate = false;
      DisableFirefoxStudies = true;
      DisableProfileImport = true;
      DisablePocket = true;
      DisableTelemetry = true;
      DisableFormHistory = true;
      
      DisplayMenuBar = "never";
      DontCheckDefaultBrowser = true;
      HardwareAcceleration = true;
      OfferToSaveLogins = false;

      ExtensionSettings = let
        moz = short: "https://addons.mozilla.org/firefox/downloads/latest/${short}/latest.xpi";
      in {
        "*".installation_mode = "blocked";

        "uBlock0@raymondhill.net" = {
          install_url       = moz "ublock-origin";
          installation_mode = "force_installed";
          updates_disabled  = true;
        };

	"firefox@ghostery.com" = {
          install_url = moz "ghostery";
	  installation_mode = "force_installed";
	};
	"78272b6fa58f4a1abaac99321d503a20@proton.me" = {
          install_url = moz "proton-pass";
	  installation_mode = "force_installed";
	};
      };
    };
    profiles.default = {
      id = 0;
      settings = {
        "dom.security.https_only_mode" = true;
	"ui.systemUsesDarkTheem" = 1;
	"layout.css.prefers-color-scheme.content-override" = 0;
      };
      search = {
        force           = true;
        default         = "DuckDuckGo";
        privateDefault  = "DuckDuckGo";
      };
    };
  };
}
