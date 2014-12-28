{ config, lib, pkgs, ... }:

with lib;

let

  cfg = config.musnix;

  preemptKernel =
    pkgs.linuxPackagesFor (pkgs.linux.override {
      extraConfig = ''
        PREEMPT_RT_FULL? y
        PREEMPT y
        IOSCHED_DEADLINE y
        DEFAULT_DEADLINE y
        DEFAULT_IOSCHED "deadline"
        HPET_TIMER y
        CPU_FREQ n
        TREE_RCU_TRACE n
      '';
    }) pkgs.linuxPackages;

in

{
  options = {

    musnix = {

      enable = mkOption {
        type = types.bool;
        default = false;
      };

      kernel.optimize = mkOption {
        type = types.bool;
        default = false;
        description = ''
          WARNING: Enabling this option will rebuild your kernel.

          If enabled, this option will configure the kernel to be
          preemptible, to use the deadline I/O scheduler, to use the
          High Precision Event Timer (HPET), and to disable CPU
          frequency scaling.
        '';
      };

      alsaSeq.enable = mkOption {
        type = types.bool;
        default = true;
        description = ''
          If enabled, load ALSA Sequencer kernel modules.  Currently,
          this only loads the `snd-seq` and `snd-rawmidi` modules.
        '';
      };

      ffado.enable = mkOption {
        type = types.bool;
        default = false;
        description = ''
          If enabled, use the Free FireWire Audio Drivers (FFADO).
        '';
      };

      soundcardPciId = mkOption {
        type = types.str;
        default = "";
        example = "$00:1b.0";
        description = ''
          The pci ID of the soundcard. Will be used to set the pci latency timer.
          If it is not set, the pci latency will be left alone.
          It can be obtained like so:
          lspci | grep -i audio
        '';
      };

    };
  };

  config = mkIf (config.sound.enable && cfg.enable) {

    boot = {
      kernel.sysctl = { "vm.swappiness" = 10; };
      kernelModules =
        if cfg.alsaSeq.enable then
          [ "snd-seq"
            "snd-rawmidi"
          ]
        else [ ];
      kernelPackages = mkIf cfg.kernel.optimize preemptKernel;
      kernelParams = [ "threadirq" ];
      postBootCommands = ''
        echo 2048 > /sys/class/rtc/rtc0/max_user_freq
        echo 2048 > /proc/sys/dev/hpet/max-user-freq
        '' + (if (cfg.soundcardPciId  == "") then ''''  else ''
        setpci -v -d *:* latency_timer=b0
        setpci -v -s ${cfg.soundcardPciId} latency_timer=ff
        '');
    };

    environment.systemPackages = with pkgs;
      if cfg.ffado.enable then
        [ pkgs.ffado ]
      else [ ];

    powerManagement.cpuFreqGovernor = "performance";

    security.pam.loginLimits = [
      { domain = "@audio"; item = "memlock"; type = "-"; value = "unlimited"; }
      { domain = "@audio"; item = "rtprio"; type = "-"; value = "99"; }
      { domain = "@audio"; item = "nofile"; type = "soft"; value = "99999"; }
      { domain = "@audio"; item = "nofile"; type = "hard"; value = "99999"; }
    ];

    services.udev = {
      packages =
        if cfg.ffado.enable then
          [ pkgs.ffado ]
        else [ ];
      extraRules = ''
        KERNEL=="rtc0", GROUP="audio"
        KERNEL=="hpet", GROUP="audio"
      '';
    };

    users.extraGroups= { audio = { }; };

  };
}