# Controller firmware: v1.06 (updated 2025-10-03)
# Dongle firmware: v1.06 (updated 2025-10-03)
# View changelogs here: https://support.8bitdo.com/ (horrible website)

# Updating Firmware:
# Unfortunately I don't think the 8bitdo "Upgrade tool" https://support.8bitdo.com/firmware-updater.html
# supports the ultimate 2 wireless. 8bitdo want us to use their "Ultimate Software V2"
# but I cannot get it work with Wine.
# Ultimate Software V2 does however work in a Windows VM:
# - In virtual machine manager select "add hardware"
# - Select "USB Host Device" and find the controller (ensure startup policy is optional)
# - Repeat this for all "variations" of the controllers product ID. These are:
# -- XInput mode (turn on normally either wired or wirelessly)
# -- DInput mode (turn on whilst holding B, only works when wireless)
# -- Bootloader mode (with the controller off, plug it in directly whilst holding LB and RB)
# -- Dongle mode (dongle connected with controller off, this is for updating dongle firmware)
# - Inside the Windows VM launch Ultimate Software 2 with the controller connected
# - After performing the firmware update the controller may not be detected inside the VM,
#   adding the hardware device again tends to fix it

# Steam Input:
# https://gist.github.com/barraIhsan/783a82bcf32bed896c85d27dbb8018a5
# Basically want to use DInput mode all the time to enable use of the extra buttons.
# Unfortunately the controller will ALWAYS boot into XInput mode. Cannot enter
# DInput directly from the dock so have to turn controller off then hold B
# whilst turning back on.

# Currently seems to be bugged though: https://steamcommunity.com/app/1675200/discussions/0/603032812101052230/
{
  services.udev.extraRules = ''
    # XInput mode
    SUBSYSTEM=="hidraw", ATTRS{idProduct}=="310b", ATTRS{idVendor}=="2dc8", TAG+="uaccess"
    # DInput mode (hold B whilst turning on controller)
    SUBSYSTEM=="hidraw", ATTRS{idProduct}=="6012", ATTRS{idVendor}=="2dc8", TAG+="uaccess"

    # Next two aren't actually necessary but might come in handy in the future
    # if the "Ultimate Software V2" tool becomes useable in Wine enabling
    # firmware updates without a VM

    # bootloader mode
    SUBSYSTEM=="hidraw", ATTRS{idProduct}=="3208", ATTRS{idVendor}=="2dc8", TAG+="uaccess"
    # dongle mode
    SUBSYSTEM=="hidraw", ATTRS{idProduct}=="6013", ATTRS{idVendor}=="2dc8", TAG+="uaccess"
  '';
}
