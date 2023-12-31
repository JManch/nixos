let
  joshua = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMd4QvStEANZSnTHRuHg0edyVdRmIYYTcViO9kCyFFt7 JManch@protonmail.com";
  ncase-m1 = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGmso00Sb3ab0dURSMJGAYN10OQQQ3VlPxHtNz092a8s root@ncase-m1";
  virtual = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIIRMA3ZtwZr/w9QG7iFfWFFSCAIjxw0XSejZPGHdYCzW root@virtual";
in
{
  "joshuaPasswd.age".publicKeys = [ ncase-m1 virtual joshua ];
}
