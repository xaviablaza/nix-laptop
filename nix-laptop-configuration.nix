{ modulesPath, lib, config, pkgs, inputs, ... }:
{
  imports = [
    (modulesPath + "/installer/scan/not-detected.nix")
    ./baremetal/disk-config.nix
    ./baremetal/bootloader.nix
    ./baremetal/openssh.nix
    ./baremetal/users.nix
    ./baremetal/common.nix
  ];

  # Hostname
  networking.hostName = "nix-laptop";

  # Use NetworkManager with DHCP
  networking.networkmanager.enable = true;
  networking.networkmanager.wifi.powersave = false;

  # Network profiles
  networking.networkmanager.ensureProfiles.profiles = {
    # Wired connection - highest priority, preferred when available
    wired-dhcp = {
      connection = {
        id = "wired-dhcp";
        type = "ethernet";
        autoconnect = "true";
        autoconnect-priority = "100";
      };
      ipv4 = {
        method = "auto";
      };
      ipv6 = {
        method = "auto";
      };
    };
  };

  # Niri compositor (via niri-flake NixOS module)
  programs.niri.enable = true;
  nixpkgs.overlays = [ inputs.niri.overlays.niri ];
  programs.niri.package = pkgs.niri-unstable;
  programs.direnv.enable = true;

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
        command = "${pkgs.tuigreet}/bin/tuigreet --greeting 'Welcome to nix-laptop' --asterisks --remember --remember-user-session --time -d --cmd niri-session";
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
  nix.settings.download-buffer-size = 128 * 1024 * 1024; # 128 MiB
  nixpkgs.config.allowUnfree = true;

  # Security
  security.rtkit.enable = true;
  security.polkit.enable = true;

  # Locale and timezone
  time.timeZone = "Asia/Bangkok";
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
    google-chrome
    firefox
    slack
    mise

    # File manager
    thunar
    tumbler

    # Terminal
    ghostty
    kitty

    # Network
    networkmanagerapplet
    wireguard-tools
    net-tools

    # Development
    gcc
    gnumake
    docker
    opencode

    # GnuPG
    gnupg
    pinentry-all
  ];

  # Niri config for administrator user
  # Place config.kdl in the administrator's home directory
  system.activationScripts.niri-config = lib.stringAfter [ "users" ] ''
    mkdir -p /home/administrator/.config/niri
    cat > /home/administrator/.config/niri/config.kdl << 'NIRIEOF'
input {
    keyboard {
        xkb {
        }
    }

    touchpad {
        tap
        natural-scroll
    }

    mouse {
    }
}

layout {
    focus-ring {
        width 4
        active-color "#7fc8ff"
        inactive-color "#505050"
    }

    border {
        off
    }

    preset-column-widths {
        proportion 0.33333
        proportion 0.5
        proportion 0.66667
    }

    default-column-width {
        proportion 0.5
    }

    gaps 16

    center-focused-column "never"
}

screenshot-path "~/Pictures/Screenshots/Screenshot from %Y-%m-%d %H-%M-%S.png"

hotkey-overlay {
}

binds {
    Mod+Return { spawn "google-chrome-stable"; }
    Mod+Shift+Slash { show-hotkey-overlay; }

    Mod+T { spawn "ghostty"; }
    Mod+D { spawn "fuzzel"; }
    Super+Alt+L { spawn "swaylock"; }

    XF86AudioRaiseVolume { spawn "wpctl" "set-volume" "@DEFAULT_AUDIO_SINK@" "0.1+"; }
    XF86AudioLowerVolume { spawn "wpctl" "set-volume" "@DEFAULT_AUDIO_SINK@" "0.1-"; }
    XF86AudioMute { spawn "wpctl" "set-mute" "@DEFAULT_AUDIO_SINK@" "toggle"; }

    XF86MonBrightnessUp { spawn "brightnessctl" "set" "+5%"; }
    XF86MonBrightnessDown { spawn "brightnessctl" "set" "5%-"; }

    Mod+W { close-window; }

    Mod+Left { focus-column-left; }
    Mod+Down { focus-window-down; }
    Mod+Up { maximize-column; }
    Mod+Right { focus-column-right; }
    Mod+H { focus-column-left; }
    Mod+J { focus-window-down; }
    Mod+K { focus-window-up; }
    Mod+L { focus-column-right; }

    Mod+Ctrl+Left { move-column-left; }
    Mod+Ctrl+Down { move-window-down; }
    Mod+Ctrl+Up { move-window-up; }
    Mod+Ctrl+Right { move-column-right; }
    Mod+Ctrl+H { move-column-left; }
    Mod+Ctrl+J { move-window-down; }
    Mod+Ctrl+K { move-window-up; }
    Mod+Ctrl+L { move-column-right; }

    Mod+Home { focus-column-first; }
    Mod+End { focus-column-last; }
    Mod+Ctrl+Home { move-column-to-first; }
    Mod+Ctrl+End { move-column-to-last; }

    Mod+Shift+Left { focus-monitor-left; }
    Mod+Shift+Down { focus-monitor-down; }
    Mod+Shift+Up { focus-monitor-up; }
    Mod+Shift+Right { focus-monitor-right; }

    Mod+Shift+Ctrl+Left { move-column-to-monitor-left; }
    Mod+Shift+Ctrl+Down { move-column-to-monitor-down; }
    Mod+Shift+Ctrl+Up { move-column-to-monitor-up; }
    Mod+Shift+Ctrl+Right { move-column-to-monitor-right; }

    Mod+Page_Down { focus-workspace-down; }
    Mod+Page_Up { focus-workspace-up; }
    Mod+U { focus-workspace-down; }
    Mod+I { focus-workspace-up; }
    Mod+Ctrl+Page_Down { move-column-to-workspace-down; }
    Mod+Ctrl+Page_Up { move-column-to-workspace-up; }

    Mod+Shift+Page_Down { move-workspace-down; }
    Mod+Shift+Page_Up { move-workspace-up; }

    Mod+1 { focus-workspace 1; }
    Mod+2 { focus-workspace 2; }
    Mod+3 { focus-workspace 3; }
    Mod+4 { focus-workspace 4; }
    Mod+5 { focus-workspace 5; }
    Mod+6 { focus-workspace 6; }
    Mod+7 { focus-workspace 7; }
    Mod+8 { focus-workspace 8; }
    Mod+9 { focus-workspace 9; }
    Mod+Ctrl+1 { move-column-to-workspace 1; }
    Mod+Ctrl+2 { move-column-to-workspace 2; }
    Mod+Ctrl+3 { move-column-to-workspace 3; }
    Mod+Ctrl+4 { move-column-to-workspace 4; }
    Mod+Ctrl+5 { move-column-to-workspace 5; }
    Mod+Ctrl+6 { move-column-to-workspace 6; }
    Mod+Ctrl+7 { move-column-to-workspace 7; }
    Mod+Ctrl+8 { move-column-to-workspace 8; }
    Mod+Ctrl+9 { move-column-to-workspace 9; }

    Mod+Comma { consume-window-into-column; }
    Mod+Period { expel-window-from-column; }

    Mod+R { switch-preset-column-width; }
    Mod+F { maximize-column; }
    Mod+Shift+F { fullscreen-window; }
    Mod+C { center-column; }

    Mod+Minus { set-column-width "-10%"; }
    Mod+Equal { set-column-width "+10%"; }
    Mod+Shift+Minus { set-window-height "-10%"; }
    Mod+Shift+Equal { set-window-height "+10%"; }

    Print { screenshot; }
    Ctrl+Print { screenshot-screen; }
    Alt+Print { screenshot-window; }

    Mod+Shift+E { quit; }
    Mod+Shift+P { power-off-monitors; }
}
NIRIEOF
    chown administrator:users /home/administrator/.config/niri/config.kdl
  '';

  # Symlink /etc/nixos to the writable config directory
  environment.etc."nixos".source = "/home/administrator/nixos-config";

  # Alias to rebuild into the full nix-laptop desktop config
  environment.shellAliases.rebuild-laptop = "sudo nixos-rebuild switch --flake /etc/nixos#nix-laptop";

  # Boot
  boot = {
    kernelPackages = pkgs.linuxPackages_latest;
    supportedFilesystems = [ "ntfs" ];
  };
}
