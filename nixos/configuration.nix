{ config, pkgs, ... }:
let
  dwlStart = pkgs.writeShellScript "dwl-start" ''
    ${pkgs.wbg}/bin/wbg ${../img/.config/desktopwallpaper.png} &
  '';

in
{
  imports = [
    ./bootloader.nix
  ];

  system.stateVersion = "25.05";
  boot.initrd.systemd.enable = true;
  hardware.graphics.enable = true;
  hardware.enableRedistributableFirmware = true; # WiFi and GPU firmware updates
  services.fwupd.enable = true; # BIOS and SSD firmware updates
  services.fstrim.enable = true; # SSD trimming to clear empty blocks

  nixpkgs.config.allowUnfree = true; # eventually move away from Nvidia drivers
  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  nix.settings.auto-optimise-store = true;
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 30d";
  };

  time.timeZone = "America/Indiana/Indianapolis";

  networking.networkmanager = {
    enable = true;
    wifi.powersave = true;
  };

  # Greeter setup with TUIGreet
  services.greetd = {
    enable = true;
    settings.default_session = {
      command = "${pkgs.greetd.tuigreet}/bin/tuigreet --time --cmd 'dwl -s ${dwlStart}'";
      user = "greeter";
    };
  };

  # Audio Setup with Pipewire
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    pulse.enable = true;
  };
  security.rtkit.enable = true; # enabling realtime scheduling for audio tasks

  # Font packages
  fonts.packages = with pkgs; [ noto-fonts nerd-fonts.jetbrains-mono ];

  users.mutableUsers = true;
  users.groups.thadigus = {};
  users.users.thadigus = {
    isNormalUser = true;
    group = "thadigus";
    extraGroups = [ "wheel" "networkmanager" ];
    shell = pkgs.zsh;
  };
  programs.zsh.enable = true; # Required for system level zsh shell setting
}
