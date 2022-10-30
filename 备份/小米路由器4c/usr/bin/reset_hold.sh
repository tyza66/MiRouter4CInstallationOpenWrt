echo "gpio btn reset!"

nvram set restore_defaults=1
nvram commit
gpio 1 1
gpio 3 1
gpio 2 0

reboot


