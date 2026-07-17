{ pkgs, ... }:
{
  home.stateVersion = "25.05";

  # home.packages is for all NixOS packages without home manager support, or without special config
  home.packages = with pkgs; [
    wl-clipboard grim slurp
    swaylock swayidle wbg
    brightnessctl
    ghostty
    htop pciutils
    (pkgs.dwl.override {
      configH = ../dwl/.dwl/config.h;
      withCustomConfigH = true;
    })
  ];
  # dotfiles for the raw packages
  xdg.configFile."ghostty".source = ../ghostty/.config/ghostty;
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
  };
  programs.tmux = {
    enable = true;
    extraConfig = builtins.readFile ../tmux/.config/tmux/tmux.conf;
  };
  programs.git = {
    enable = true;
  };
}
