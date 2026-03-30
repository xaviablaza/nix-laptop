{ modulesPath, lib, config, pkgs, inputs, ... }:
{
  imports = [
    (modulesPath + "/installer/scan/not-detected.nix")
    ../baremetal/disk-config.nix
    ../baremetal/bootloader.nix
    ../baremetal/openssh.nix
    ../baremetal/users.nix
    ../baremetal/common.nix
  ];

  # Hostname
  networking.hostName = "nix-laptop";

  # Use NetworkManager with DHCP
  networking.networkmanager.enable = true;

  # Niri compositor (via niri-flake NixOS module)
  programs.niri.enable = true;
  nixpkgs.overlays = [ inputs.niri.overlays.niri ];
  programs.niri.package = pkgs.niri-unstable;

  # XDG portal for niri (xdg-desktop-portal-gnome is required for screencasting)
  xdg.portal = {
    enable = true;
    xdgOpenUsePortal = true;
  };

  # Audio via PipeWire
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
  };

  # Bluetooth
  hardware.bluetooth.enable = true;
  hardware.bluetooth.powerOnBoot = true;
  services.blueman.enable = true;

  # Basic services
  services.gvfs.enable = true;
  services.tumbler.enable = true;

  # Display manager - greetd with tuigreet for niri
  services.greetd = {
    enable = true;
    settings = {
      default_session = {
        command = "${pkgs.greetd.tuigreet}/bin/tuigreet --greeting 'Welcome to nix-laptop' --asterisks --remember --remember-user-session --time -d --cmd niri-session";
        user = "greeter";
      };
    };
  };

  # Administrator user shell and groups
  users.users.administrator = {
    shell = pkgs.zsh;
    extraGroups = [ "networkmanager" "input" "video" ];
  };
  programs.zsh.enable = true;

  # Nix settings
  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  nixpkgs.config.allowUnfree = true;

  # Security
  security.rtkit.enable = true;
  security.polkit.enable = true;

  # Locale and timezone
  time.timeZone = "America/Los_Angeles";
  i18n.defaultLocale = "en_US.UTF-8";

  # Fonts
  fonts.packages = with pkgs; [
    font-awesome
    noto-fonts-cjk-sans
    nerd-fonts.fira-code
  ];

  # Firewall
  networking.firewall.allowedUDPPorts = [ 51820 ];

  # System packages
  environment.systemPackages = with pkgs; [
    # Core tools
    neovim
    git
    curl
    wget
    unzip
    jq
    ripgrep
    fzf
    zoxide
    eza
    bat
    btop
    direnv
    tmux
    alejandra

    # Niri ecosystem
    waybar
    mako
    libnotify
    fuzzel
    swww
    wl-clipboard
    grim
    slurp
    swappy
    playerctl
    pavucontrol
    pulseaudio
    brightnessctl

    # File manager
    xfce.thunar
    xfce.tumbler

    # Terminal
    ghostty
    kitty

    # Network
    networkmanagerapplet
    wireguard-tools

    # Development
    gcc
    gnumake
    docker

    # GnuPG
    gnupg
    pinentry-all
  ];

  # Boot
  boot = {
    kernelPackages = pkgs.linuxPackages_latest;
    supportedFilesystems = [ "ntfs" ];
  };
}
