#!/bin/bash

# This is a custom script combining the work of rlancaste and nou.
# I wanted the system configuration of the rlancaste script with
# the maintained application and packages of nou.

if [ "$(whoami)" != "root" ]; then
	echo "Please run this script with sudo due to the fact that it must do a number of sudo tasks.  Exiting now."
	exit 1
elif [ -z "$BASH_VERSION" ]; then
	echo "Please run this script in a BASH shell because it is a script written using BASH commands.  Exiting now."
	exit 1
else
	echo "You are running BASH $BASH_VERSION as the root user."
fi

DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )

function display
{
    echo ""
    echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
    echo "~ $*"
    echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
    echo ""
    
    # This will display the message in the title bar (Note that the PS1 variable needs to be changed too--see below)
    echo -en "\033]0;AstroPi3-SetupAstroRaspbianPi-$*\a"
}

function checkForConnection
{
		testCommand=$(curl -Is $2 | head -n 1)
		if [[ "${testCommand}" == *"OK"* || "${testCommand}" == *"Moved"* || "${testCommand}" == *"HTTP/2 301"* || "${testCommand}" == *"HTTP/2 200"* ]]
  		then 
  			echo "$1 was found. The script can proceed."
  		else
  			echo "$1, ($2), a required connection, was not found, aborting script."
  			echo "If you would like the script to run anyway, please comment out the line that tests this connection in this script."
  			exit
		fi
}

display "Welcome to the Raspberry Pi 3 or 4 Raspberry Pi OS Configuration Script."

display "This will update, install and configure your Raspberry Pi 3 or 4 to work with INDI and KStars to be a hub for Astrophotography. Be sure to read the script first to see what it does and to customize it."

read -p "Are you ready to proceed (y/n)? " proceed

if [ "$proceed" != "y" ]
then
	exit
fi

export USERHOME=$(sudo -u $SUDO_USER -H bash -c 'echo $HOME')

# This changes the UserPrompt for the Setup Script (Necessary to make the messages display in the title bar)
PS1='AstroPi3-SetupAstroRaspbianPi~$ '

#########################################################
#############  Asking Questions for optional items later

display "Checking items that will require your input while running the script, so you don't get asked so many questions later.  Note that some installations later (VNC, samba in particular) may still require your input later on, this is out of my control."

staticIPExists=false
if [ -d "/etc/NetworkManager/system-connections/" ]
then
	if [ -z "$(ls /etc/NetworkManager/system-connections/ | grep Link\ Local\ Ethernet)" ]
	then
		staticIPExists=true
	fi
fi

if [ "$staticIPExists" == false ]
then
	read -p "Do you want to give your pi a static ip address so that you can connect to it in the observing field with no router or wifi and just an ethernet cable (y/n)? " useStaticIP
	if [ "$useStaticIP" == "y" ]
	then
		read -p "Please enter the IP address you would prefer.  Please make sure that the first two numbers match your client computer's self assigned IP.  For Example mine is: 169.254.0.5 ? " IP
		if [[ "$IP" =~ ^(([1-9]?[0-9]|1[0-9][0-9]|2([0-4][0-9]|5[0-5]))\.){3}([1-9]?[0-9]|1[0-9][0-9]|2([0-4][0-9]|5[0-5]))$ ]] # Note that this formula came from Jon in the thread: https://stackoverflow.com/questions/13777387/check-for-ip-validity
		then
			echo "IP Address is in correct format, proceeding"
		else
			echo "IP Address invalid, the static IP cannot be set up with this address.  Please configure Network Manager later or run the script again."
			read -p "Do you wish to abort and try to enter the IP address again (y/n)?" abortDueToIP
			if [ "$abortDueToIP" == "y" ]
			then
				exit
			fi
		fi
	else
		display "Leaving your IP address to be assigned only by dhcp.  Note that you will always need either a router or wifi network to connect to your pi."
	fi
else
	echo "A Static IP Address is already configured.  If you want to change that, you can delete the Link Local Ethernet System Connection in network manager."
fi

if [ -f /etc/NetworkManager/conf.d/wifi-enable-autohotspot.conf ]
then
	echo "Field Wifi autoconnection is already configured, if you want to change it, edit network manager and /etc/NetworkManager/conf.d/wifi-enable-autohotspot.conf"
else
	read -p "Do you wish to configure the field wifi hotspot to automatically come up after a certain time if there is no wifi network (y/n)? " autoWifi

	if [ "$autoWifi" == "y" ]
	then
		read -p "What do you want the timeout to be?  Mine is 30 seconds: " wifiTimeout
		if ! [ "$wifiTimeout" -eq "$wifiTimeout" ] 2> /dev/null
		then
   			echo "The timeout must be an integer number of seconds.  Making it 30 instead.  You can edit /etc/NetworkManager/conf.d/wifi-enable-autohotspot.conf to change it."
   			wifiTimeout=30
		fi
	fi
fi


#########################################################
#############  Updates

# This would update the Raspberry Pi kernel.  For now it is disabled because there is debate about whether to do it or not.  To enable it, take away the # sign.
#display "Updating Kernel"
#sudo rpi-update 

# Updates the Raspberry Pi to the latest packages.
display "Updating installed packages"
sudo apt update
sudo apt -y upgrade
sudo apt -y dist-upgrade

#########################################################
#############  Configuration for Ease of Use/Access

# This makes sure there is a config folder owned by the user, since many things depend on it.
mkdir -p $USERHOME/.config
sudo chown $SUDO_USER:$SUDO_USER $USERHOME/.config

# This will set up the Pi so that double clicking on desktop icons brings up the program right away
# The default behavior is to ask what you want to do with the executable file.
display "Setting desktop icons to open programs when you click them."
if [ -f $USERHOME/.config/pcmanfm-qt/lxqt/settings.conf ]
then
	sed -i "s/QuickExec=false/QuickExec=true/g" $USERHOME/.config/pcmanfm-qt/lxqt/settings.conf
fi
if [ -f $USERHOME/.config/pcmanfm-qt/default/settings.conf ]
then
	sed -i "s/QuickExec=false/QuickExec=true/g" $USERHOME/.config/pcmanfm-qt/default/settings.conf
fi
if [ -f $USERHOME/.config/libfm/libfm.conf ]
then
	if [ -z "$(grep 'quick_exec' $USERHOME/.config/libfm/libfm.conf)" ]
	then
		sed -i "/\[config\]/ a quick_exec=1" $USERHOME/.config/libfm/libfm.conf
	else
		sed -i "s/quick_exec=0/quick_exec=1/g" $USERHOME/.config/libfm/libfm.conf
	fi
fi
if [ -f /etc/xdg/libfm/libfm.conf ]
then
	if [ -z "$(grep 'quick_exec' /etc/xdg/libfm/libfm.conf)" ]
	then
		sed -i "/\[config\]/ a quick_exec=1" /etc/xdg/libfm/libfm.conf
	else
		sed -i "s/quick_exec=0/quick_exec=1/g" /etc/xdg/libfm/libfm.conf
	fi
fi

# This will set your account to autologin.  If you don't want this. then put a # on each line to comment it out.
display "Setting account: "$SUDO_USER" to auto login."
if [ -n "$(grep '#autologin-user' '/etc/lightdm/lightdm.conf')" ]
then
	sed -i "s/#autologin-user=/autologin-user=$SUDO_USER/g" /etc/lightdm/lightdm.conf
	sed -i "s/#autologin-user-timeout=0/autologin-user-timeout=0/g" /etc/lightdm/lightdm.conf
fi

display "Setting HDMI settings in /boot/config.txt."

# This pretends an HDMI display is connected at all times, otherwise, the pi might shut off HDMI
# So that when you go to plug in an HDMI connector to diagnose a problem, it doesn't work
# This makes the HDMI output always available
if [ -n "$(grep '#hdmi_force_hotplug=1' '/boot/firmware/config.txt')" ]
then
	sed -i "s/#hdmi_force_hotplug=1/hdmi_force_hotplug=1/g" /boot/firmware/config.txt
fi

# This sets the group for the HDMI mode.  Please see the config file for details about all the different modes
# There are many options.  I selected group 1 mode 46 because that matches my laptop's resolution.
# You might want a different mode and group if you want a certain resolution in VNC
if [ -n "$(grep '#hdmi_group=1' '/boot/firmware/config.txt')" ]
then
	sed -i "s/#hdmi_group=1/hdmi_group=2/g" /boot/firmware/config.txt
fi

# This sets the HDMI mode.  Please see the config file for details about all the different modes
# There are many options.  I selected group 1 mode 46 because that matches my laptop's resolution.
# You might want a different mode and group if you want a certain resolution in VNC
if [ -n "$(grep '#hdmi_mode=1' '/boot/firmware/config.txt')" ]
then
	sed -i "s/#hdmi_mode=1/hdmi_mode=46/g" /boot/firmware/config.txt
fi

# This comments out a line in Raspbian's config file that seems to prevent the desired screen resolution in VNC
# The logic here is that if the line does exist, and if the line is not commented out, comment it out.
# However it should be noted that this change may disable the 2nd HDMI output.
# If you want to use your PI in a headless mode and set your own resolution, you need to run this code on a PI 4.
# If you want to use two HDMI monitors with the PI 4, instead of going headless, you should not run this code.
if [ -n "$(grep '^dtoverlay=vc4-kms-v3d' '/boot/frimware/config.txt')" ]
then
	sed -i "s/dtoverlay=vc4-kms-v3d/#dtoverlay=vc4-kms-v3d/g" /boot/firmware/config.txt
fi
if [ -n "$(grep '^dtoverlay=vc4-fkms-v3d' '/boot/firmware/config.txt')" ]
then
	sed -i "s/dtoverlay=vc4-fkms-v3d/#dtoverlay=vc4-fkms-v3d/g" /boot/firmware/config.txt
fi


# This will prevent the raspberry pi from turning on the lock-screen / screensaver which can be problematic when using VNC
if [ -z "$(grep 'xserver-command=X -s 0 dpms' '/etc/lightdm/lightdm.conf')" ]
then
	sed -i "/\[Seat:\*\]/ a xserver-command=X -s 0 dpms" /etc/lightdm/lightdm.conf
fi

# Installs Synaptic Package Manager for easy software install/removal
display "Installing Synaptic"
sudo apt -y install synaptic

# This will enable SSH which is apparently disabled on Raspberry Pi by default.
display "Enabling SSH"
sudo apt -y install openssh-server
sudo systemctl enable ssh
sudo systemctl start ssh

# This will install and configure network manager and remove dhcpcd5 because it has some issues
# Also the commands below that setup networking depend upon network manager.
sudo apt -y install network-manager network-manager-gnome
sudo apt purge -y openresolv dhcpcd5
# This should remove the old manager panel from the taskbar
if [ -n "$(grep 'type=dhcpcdui' $USERHOME/.config/lxpanel/LXDE-$SUDO_USER/panels/panel)" ]
then
	sed -i "s/type=dhcpcdui/type=space/g" $USERHOME/.config/lxpanel/LXDE-$SUDO_USER/panels/panel
fi
if [ -n "$(grep 'type=dhcpcdui' /etc/xdg/lxpanel/LXDE-$SUDO_USER/panels/panel)" ]
then
	sed -i "s/type=dhcpcdui/type=space/g" /etc/xdg/lxpanel/LXDE-$SUDO_USER/panels/panel
fi
if [ -n "$(grep 'type=dhcpcdui' /etc/xdg/lxpanel/LXDE/panels/panel)" ]
then
	sed -i "s/type=dhcpcdui/type=space/g" /etc/xdg/lxpanel/LXDE/panels/panel
fi

# This will set up your Pi to have access to internet with wifi, ethernet with DHCP, and ethernet with direct connection
display "Setting up Ethernet for both link-local and DHCP"
if [ -z "$(ls /etc/NetworkManager/system-connections/ | grep Link\ Local\ Ethernet)" ]
then
	if [ "$useStaticIP" == "y" ]
	then
		if [[ "$IP" =~ ^(([1-9]?[0-9]|1[0-9][0-9]|2([0-4][0-9]|5[0-5]))\.){3}([1-9]?[0-9]|1[0-9][0-9]|2([0-4][0-9]|5[0-5]))$ ]] # Note that this formula came from Jon in the thread: https://stackoverflow.com/questions/13777387/check-for-ip-validity
		then
			echo "IP Address is in correct format, proceeding to set up the static IP"
			
			# This will make sure that network manager can manage whether the ethernet connection is on or off and then you can change the connection in network maanager.
			if [ -n "$(grep 'managed=false' /etc/NetworkManager/NetworkManager.conf)" ]
			then
				sed -i "s/managed=false/managed=true/g" /etc/NetworkManager/NetworkManager.conf
			fi
	
			# This section should add two connections, one for connecting to ethernet with a router and the other for connecting directly to a computer in the observing field with a Link Local IP
			nmcli connection add type ethernet ifname eth0 con-name "Wired DHCP Ethernet" autoconnect yes
			nmcli connection modify "Wired DHCP Ethernet" connection.autoconnect-priority 2 	# Higher Priority because then it tries DHCP first and then switches to Link Local as a backup
			nmcli connection modify "Wired DHCP Ethernet" ipv4.dhcp-timeout 5 					# This sets the timeout for DHCP to a much shorter time so you don't have to wait forever for Link Local
			nmcli connection modify "Wired DHCP Ethernet" ipv4.may-fail no 						# I'm not sure why this is needed, but without it, it doesn't seem to want to switch to link local
			nmcli connection modify "Wired DHCP Ethernet" connection.autoconnect-retries 2		# These last two might not be necessary, but they might be needed if the global settings are to infinitely retry
			nmcli connection modify "Wired DHCP Ethernet" connection.auth-retries 2
	
			nmcli connection add type ethernet ifname eth0 con-name "Link Local Ethernet" autoconnect yes ip4 $IP/24
			nmcli connection modify "Link Local Ethernet" connection.autoconnect-priority 1		# Lower priority because this is the backup for when in the observing field
	
# This will make sure /etc/network/interfaces does not interfere
##################
sudo cat > /etc/network/interfaces <<- EOF
# interfaces(5) file used by ifup(8) and ifdown(8)
# Include files from /etc/network/interfaces.d:
source-directory /etc/network/interfaces.d

# The loopback network interface
auto lo
iface lo inet loopback
EOF
##################

		else
			echo "IP Address invalid, the static IP will not be set up.  Please configure Network Manager later or run the script again."
		fi
	else
		display "Leaving your IP address to be assigned only by dhcp.  Note that you will always need either a router or wifi network to connect to your pi."
	fi
else
	display "This computer already has been assigned a static ip address.  If you need to edit that, please edit the Link Local and Wired DHCP connections in Network Manager or delete them and run the script again."
fi

# To view the Raspberry Pi Remotely, this installs RealVNC Servier and enables it to run by default.
display "Installing RealVNC Server"
sudo apt install realvnc-vnc-server
sudo systemctl enable vncserver-x11-serviced.service
sudo systemctl daemon-reload
sudo systemctl start vncserver-x11-serviced.service

display "Making Utilities Folder with script shortcuts for the Desktop"

# This will make a folder on the desktop for the launchers if it doesn't exist already
if [ ! -d "$USERHOME/Desktop/utilities" ]
then
	mkdir -p $USERHOME/Desktop/utilities
	sudo chown $SUDO_USER:$SUDO_USER $USERHOME/Desktop/utilities
fi

# This will create a shortcut on the desktop in the utilities folder for Installing Astrometry Index Files.
##################
sudo cat > $USERHOME/Desktop/utilities/InstallAstrometryIndexFiles.desktop <<- EOF
#!/usr/bin/env xdg-open
[Desktop Entry]
Version=1.0
Type=Application
Terminal=true
Icon[en_US]=mate-preferences-desktop-display
Exec=sudo $(echo $DIR)/astrometryIndexInstaller.sh
Name[en_US]=Install Astrometry Index Files
Name=Install Astrometry Index Files
Icon=$(echo $DIR)/icons/mate-preferences-desktop-display.svg
EOF
##################
sudo chmod +x $USERHOME/Desktop/utilities/InstallAstrometryIndexFiles.desktop
sudo chown $SUDO_USER:$SUDO_USER $USERHOME/Desktop/utilities/InstallAstrometryIndexFiles.desktop
chmod +x "$DIR/astrometryIndexInstaller.sh"

#########################################################
#############  Configuration for Hotspot Wifi for Connecting on the Observing Field

# This will fix a problem where AdHoc and Hotspot Networks Shut down very shortly after starting them
# Apparently it was due to power management of the wifi network by Network Manager.
# If Network Manager did not detect internet, it shut down the connections to save energy. 
# If you want to leave wifi power management enabled, put #'s in front of this section
display "Preventing Wifi Power Management from shutting down AdHoc and Hotspot Networks"
##################
sudo cat > /etc/NetworkManager/conf.d/default-wifi-powersave-on.conf <<- EOF
[connection]
wifi.powersave = 2
EOF
##################

# This will create a NetworkManager Wifi Hotspot File.  
# You can edit this file to match your settings now or after the script runs in Network Manager.
# If you prefer to set this up yourself, you can comment out this section with #'s.
# If you want the hotspot to start up by default you should set autoconnect to true.
display "Creating $(hostname -s)_FieldWifi, Hotspot Wifi for the observing field"
if [ -z "$(ls /etc/NetworkManager/system-connections/ | grep $(hostname -s)_FieldWifi)" ]
then

	nmcli connection add type wifi ifname '*' con-name $(hostname -s)_FieldWifi autoconnect no ssid $(hostname -s)_FieldWifi
	nmcli connection modify $(hostname -s)_FieldWifi 802-11-wireless.mode ap 802-11-wireless.band bg ipv4.method shared
	nmcli connection modify $(hostname -s)_FieldWifi 802-11-wireless-security.key-mgmt wpa-psk 802-11-wireless-security.psk $(hostname -s)_password

	nmcli connection add type wifi ifname '*' con-name $(hostname -s)_FieldWifi_5G autoconnect no ssid $(hostname -s)_FieldWifi_5G
	nmcli connection modify $(hostname -s)_FieldWifi_5G 802-11-wireless.mode ap 802-11-wireless.band a ipv4.method shared
	nmcli connection modify $(hostname -s)_FieldWifi_5G 802-11-wireless-security.key-mgmt wpa-psk 802-11-wireless-security.psk $(hostname -s)_password
else
	echo "$(hostname -s)_FieldWifi is already setup."
fi

# This section will set the new field wifi networks to autoconnect if the other networks don't connect.
display "Configuring Field wifi to autoconnect after wifi fails"
if [ -f /etc/NetworkManager/conf.d/wifi-enable-autohotspot.conf ]
then
	echo "Field Wifi autoconnection is already configured, if you want to change it, edit network manager and /etc/NetworkManager/conf.d/wifi-enable-autohotspot.conf"
else
	if [ "$autoWifi" == "y" ]
	then
		# This sets both wifi networks to autoconnect with a priority to connect on 5G if available
		nmcli connection modify $(hostname -s)_FieldWifi connection.autoconnect yes
		nmcli connection modify $(hostname -s)_FieldWifi_5G connection.autoconnect yes
		nmcli connection modify $(hostname -s)_FieldWifi connection.autoconnect-priority -10
		nmcli connection modify $(hostname -s)_FieldWifi_5G connection.autoconnect-priority -5
	
# This configuration file will ensure that the wifi networks come up successfully in a reasonable time if the regular wifi fails.
##################
sudo --preserve-env bash -c ' cat > /etc/NetworkManager/conf.d/wifi-enable-autohotspot.conf' <<- EOF
[connection-wifi]
match-device=interface-name:wlan0
ipv4.dhcp-timeout=$wifiTimeout
ipv4.may-fail=no
connection.auth-retries=2
connection.autoconnect-retries=2
EOF
##################
	fi
fi

# This will make a link to start the hotspot wifi on the Desktop
##################
sudo cat > $USERHOME/Desktop/utilities/StartFieldWifi.desktop <<- EOF
[Desktop Entry]
Version=1.0
Type=Application
Terminal=false
Icon[en_US]=irda
Name[en_US]=Start $(hostname -s) Field Wifi
Exec=nmcli con up $(hostname -s)_FieldWifi
Name=Start $(hostname -s)_FieldWifi 
Icon=$(echo $DIR)/icons/irda.png
EOF
##################
sudo chmod +x $USERHOME/Desktop/utilities/StartFieldWifi.desktop
sudo chown $SUDO_USER:$SUDO_USER $USERHOME/Desktop/utilities/StartFieldWifi.desktop
##################
sudo cat > $USERHOME/Desktop/utilities/StartFieldWifi_5G.desktop <<- EOF
[Desktop Entry]
Version=1.0
Type=Application
Terminal=false
Icon[en_US]=irda
Name[en_US]=Start $(hostname -s) Field Wifi 5G
Exec=nmcli con up $(hostname -s)_FieldWifi_5G
Name=Start $(hostname -s)_FieldWifi_5G
Icon=$(echo $DIR)/icons/irda.png
EOF
##################
sudo chmod +x $USERHOME/Desktop/utilities/StartFieldWifi_5G.desktop
sudo chown $SUDO_USER:$SUDO_USER $USERHOME/Desktop/utilities/StartFieldWifi_5G.desktop

# This will make a link to restart Network Manager Service if there is a problem or to go back to regular wifi after using the adhoc connection
##################
sudo cat > $USERHOME/Desktop/utilities/StartNmService.desktop <<- EOF
[Desktop Entry]
Version=1.0
Type=Application
Terminal=false
Icon[en_US]=preferences-system-network
Name[en_US]=Restart Network Manager Service
Exec=pkexec systemctl restart NetworkManager.service
Name=Restart Network Manager Service
Icon=$(echo $DIR)/icons/preferences-system-network.svg
EOF
##################
sudo chmod +x $USERHOME/Desktop/utilities/StartNmService.desktop
sudo chown $SUDO_USER:$SUDO_USER $USERHOME/Desktop/utilities/StartNmService.desktop

# This will make a link to restart nm-applet which sometimes crashes
##################
sudo cat > $USERHOME/Desktop/utilities/StartNmApplet.desktop <<- EOF
[Desktop Entry]
Version=1.0
Type=Application
Terminal=false
Icon[en_US]=preferences-system-network
Name[en_US]=Restart Network Manager Applet
Exec=nm-applet
Name=Restart Network Manager
Icon=$(echo $DIR)/icons/preferences-system-network.svg
EOF
##################
sudo chmod +x $USERHOME/Desktop/utilities/StartNmApplet.desktop
sudo chown $SUDO_USER:$SUDO_USER $USERHOME/Desktop/utilities/StartNmApplet.desktop

#########################################################
#############  File Sharing Configuration

display "Setting up File Sharing"

# Installs samba so that you can share files to your other computer(s).
sudo apt -y install samba samba-common-bin
sudo touch /etc/libuser.conf

if [ ! -f /etc/samba/smb.conf ]
then
	sudo mkdir -p /etc/samba/
##################
sudo cat > /etc/samba/smb.conf <<- EOF
[global]
   workgroup = ASTROGROUP
   server string = Samba Server
   server role = standalone server
   log file = /var/log/samba/log.%m
   max log size = 50
   dns proxy = no
[homes]
   comment = Home Directories
   browseable = no
   read only = no
   writable = yes
   valid users = $SUDO_USER
EOF
##################
fi

# Adds yourself to the user group of who can use samba, but checks first if you are already in the list
if [ -z "$(sudo pdbedit -L | grep $SUDO_USER)" ]
then
	sudo smbpasswd -a $SUDO_USER
	sudo adduser $SUDO_USER sambashare
fi

#########################################################
#############  Very Important Configuration Items

# This will create a swap file for an increased 2 GB of artificial RAM.  This is not needed on all systems, since different cameras download different size images, but if you are using a DSLR, it definitely is.
# This method is disabled in favor of the zram method below. If you prefer this method, you can re-enable it by taking out the #'s
#display "Creating SWAP Memory"
#wget https://raw.githubusercontent.com/Cretezy/Swap/master/swap.sh -O swap
#sh swap 2G
#rm swap

# This will create zram, basically a swap file saved in RAM. It will not read or write to the SD card, but instead, writes to compressed RAM.  
# This is not needed on all systems, since different cameras download different size images, and different SBC's have different RAM capacities but 
# if you are using a DSLR on a Raspberry Pi with 1GB of RAM, it definitely is needed. If you don't want this, comment it out.
display "Installing zRAM for increased RAM capacity"
sudo wget -O /usr/bin/zram.sh https://raw.githubusercontent.com/novaspirit/rpi_zram/master/zram.sh
sudo chmod +x /usr/bin/zram.sh

if [ -z "$(grep '/usr/bin/zram.sh' '/etc/rc.local')" ]
then
   sed -i "/^exit 0/i /usr/bin/zram.sh &" /etc/rc.local
fi

# This should fix an issue where modemmanager could interfere with serial connections
display "Removing Modemmanger, which can interfere with serial connections."
sudo apt -y remove modemmanager

# This should fix an issue where you might not be able to use a serial mount connection because you are not in the "dialout" group
display "Enabling Serial Communication"
sudo usermod -a -G dialout $SUDO_USER

#########################################################
#############  ASTRONOMY SOFTWARE

# Installs the Astrometry.net package for supporting offline plate solves.  If you just want the online solver, comment this out with a #.
display "Installing Astrometry.net"
sudo apt -y install astrometry.net


