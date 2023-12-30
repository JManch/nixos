let
  joshua = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMd4QvStEANZSnTHRuHg0edyVdRmIYYTcViO9kCyFFt7 JManch@protonmail.com";
  ncase-m1 = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGmso00Sb3ab0dURSMJGAYN10OQQQ3VlPxHtNz092a8s root@ncase-m1";
in
{
  "joshuaPasswd.age".publicKeys = [ ncase-m1 joshua ];
}
