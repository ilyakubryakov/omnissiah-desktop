{
  oninix = {
    enable = true;
    user = {
      name = "me";
      description = "";
    };
    hardware = {
      gpu = "none";
      laptop = false;
    };
    features = {
      gaming = false;
      coding = false;
      music = false;
      ai = false;
    };
  };

  networking.hostName = "oninix";
  time.timeZone = "UTC";
  system.stateVersion = "26.11";
}
