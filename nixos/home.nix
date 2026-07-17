{ pkgs, ... }:
{
  home.stateVersion = "25.05";

  # home.packages is for all NixOS packages without home manager support, or without special config
  home.packages = with pkgs; [
    htop
    (pkgs.dwl.override {
      configH = ../dwl/.dwl/config.h;
      withCustomConfigH = true;
    })
  ];

  # programs.app is for home-manager compatible applications where HM manages the configuration
  programs.zsh.enable = true;
  programs.tmux.enable = true;
  programs.git.enable = true;

  programs.ghostty = {
    enable = true;
    package = if pkgs.stdenv.isDarwin then pkgs.ghostty-bin else pkgs.ghostty;
    enableZshIntegration = true;
  };
}
