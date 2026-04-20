{ pkgs, settings ? {}, ... }:

let
  gstPackages = with pkgs.gst_all_1; [
    gstreamer
    gst-plugins-base
    gst-plugins-good
    gst-plugins-bad
    gst-libav
  ];

  uxplayLauncher = pkgs.writeShellApplication {
    name = "uxplay-gaming-host";
    runtimeInputs = with pkgs; [
      uxplay
    ] ++ gstPackages;
    text = ''
      export GST_PLUGIN_SYSTEM_PATH_1_0="${pkgs.lib.makeSearchPath "lib/gstreamer-1.0" gstPackages}"
      export GST_PLUGIN_SCANNER="${pkgs.gst_all_1.gstreamer}/libexec/gstreamer-1.0/gst-plugin-scanner"

      exec ${pkgs.uxplay}/bin/uxplay \
        -n "${settings.hostname}-test" -nh \
        -as 'audioconvert ! audioresample ! audio/x-raw,format=S16LE,rate=44100,channels=2 ! alsasink device=plughw:4,0' \
        -vol 1.0 \
        -p 7000,7001,7100 \
        -vs ximagesink \
        -vsync no \
        -scrsv 1 \
        "$@"
    '';
  };
in
{
  environment.systemPackages = [
    pkgs.uxplay
    uxplayLauncher
  ] ++ gstPackages;

  services.avahi = {
    enable = true;
    nssmdns4 = true;
    openFirewall = true;
    publish = {
      enable = true;
      userServices = true;
    };
  };

  networking.firewall = {
    allowedTCPPorts = [ 7000 7001 7100 ];
    allowedUDPPorts = [ 6000 6001 7011 ];
  };

  systemd.user.services.uxplay = {
    description = "AirPlay receiver for iPad mirroring";
    after = [
      "graphical-session.target"
      "pipewire.service"
      "wireplumber.service"
      "sonos-ace-audio-fix.service"
    ];
    wants = [
      "graphical-session.target"
      "pipewire.service"
      "wireplumber.service"
      "sonos-ace-audio-fix.service"
    ];
    wantedBy = [ "default.target" ];
    serviceConfig = {
      ExecStart = "${uxplayLauncher}/bin/uxplay-gaming-host";
      Restart = "on-failure";
      RestartSec = 2;
    };
  };
}
