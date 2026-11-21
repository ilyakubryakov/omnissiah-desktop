{ modulesPath, ... }:
{
  imports = [ "${modulesPath}/virtualisation/qemu-vm.nix" ];

  oninix = {
    enable = true;
    user = {
      name = "demo";
      description = "OniNix Demo";
    };
    features = {
      gaming = true;
      coding = true;
    };
  };

  users.users.demo.initialPassword = "demo";
  networking.hostName = "oninix-demo";
  time.timeZone = "UTC";
  system.stateVersion = "26.11";

  fileSystems."/" = {
    device = "/dev/disk/by-label/nixos";
    fsType = "ext4";
  };
  virtualisation = {
    memorySize = 8192;
    cores = 4;
    diskSize = 20480;
    resolution = { x = 1920; y = 1080; };
  };
}
