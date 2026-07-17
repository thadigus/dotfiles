{ pkgs, ... }:
{
  home.stateVersion = "25.05";

  # home.packages is for all NixOS packages without home manager support, or without special config
  home.packages = with pkgs; [
    wl-clipboard grim slurp
    swaylock swayidle swaybg
    brightnessctl
    ghostty neovim
    fastfetch oh-my-zsh
    htop pciutils
    (pkgs.dwl.override {
      configH = ../dwl/.dwl/config.h;
      withCustomConfigH = true;
    })
  ];
  # dotfiles for the raw packages
  xdg.configFile."ghostty/config".source = ../ghostty/.config/ghostty/config;
  xdg.configFile."neofetch.jsonc".source = ../fastfetch/.config/neofetch.jsonc;
  xdg.configFile."swaylock/config".source = ../swaylock/.swaylock/config;
  # Desktop and profile images
  xdg.configFile."tt_logo.png".source          = ../img/.config/tt_logo.png;
  xdg.configFile."desktopwallpaper.png".source = ../img/.config/desktopwallpaper.png;
  xdg.configFile."desktopwallpaper.jpg".source = ../img/.config/desktopwallpaper.jpg;

  # programs.app is for home-manager compatible applications where HM manages the configuration
  programs.zsh = {
    enable = true;
    initContent = builtins.readFile ../zsh/.zshrc;
    oh-my-zsh = {
      enable = true;
    };
  };
  programs.tmux = {
    enable = true;
    extraConfig = builtins.readFile ../tmux/.config/tmux/tmux.conf;
  };
  programs.git = {
    enable = true;
    userName = "thadigus";
    userEmail = "no-reply@turnerservices.cloud";
    extraConfig = {
      init.defaultBranch = "main";
      pull.rebase = true;
      push.autoSetupRemote = true;
    };
  };
  programs.firefox = {
    enable = true;
    languagePacks = [ "en-US" ];
    policies = {
      AppAutoUpdate = false;
      BackgroundAppUpdate = false;
      DisableFirefoxStudies = true;
      DisableProfileIMport = true;
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
      };
    };
    profiles.default.search = {
    force           = true;
    default         = "DuckDuckGo";
    privateDefault  = "DuckDuckGo";
    };
  };
}
