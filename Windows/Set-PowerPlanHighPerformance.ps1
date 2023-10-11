# Change the power plan to High Performance
powercfg /setactive 8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c

# Disable hibernation, sleep, and disk timeout for AC (wall power) only
powercfg /x hibernate-timeout-ac 0
Powercfg /x standby-timeout-ac 0
powercfg /x disk-timeout-ac 0
