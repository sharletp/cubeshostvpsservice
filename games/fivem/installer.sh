#!/bin/bash
### Main Installer ###
INSTALLER_SCRIPT="cubeshostvpsservice-stable/installer/main.sh"
. $INSTALLER_SCRIPT

checkRoot
conlogo
connotice Starting up script..
sleep 3

### FiveM Installer ###
FIVEM_ARTIFACT_VERSION=4394-572b000db3f5a323039e0915dac64641d1db408e

coninfo Updating and upgrading apt
apt-get update -y && apt-get upgrade -y

# Install & Setup UFW Firewall
coninfo Installing and setting up firewall
apt-get install ufw -y
echo 'y' | ufw enable
ufw allow OpenSSH
ufw allow 30110
ufw allow 30120
ufw allow 40120
ufw reload

# Install WGET
coninfo Setting up wget
apt-get install wget -y

# Download FiveM Server
connotice Downloading FiveM Server
cd ~
wget "https://runtime.fivem.net/artifacts/fivem/build_proot_linux/master/$FIVEM_ARTIFACT_VERSION/fx.tar.xz"

coninfo Extracting data from downloaded files
tar -xvf fx.tar.xz
rm fx.tar.xz

# Install GIT
coninfo Installing git
apt-get install git -y

# Download cfx-server-data
connotice Downloading cfx-server-data
cd ~
git clone https://github.com/citizenfx/cfx-server-data
mv ~/cfx-server-data/resources ~

# Create configuration file
conlog Creating server.cfg
cat > server.cfg << EOF
# Only change the IP if you're using a server with multiple network interfaces, otherwise change the port only.
endpoint_add_tcp "0.0.0.0:30120"
endpoint_add_udp "0.0.0.0:30120"

# These resources will start by default.
ensure mapmanager
ensure chat
ensure spawnmanager
ensure sessionmanager
ensure basic-gamemode
ensure hardcap
ensure rconlog

# This allows players to use scripthook-based plugins such as the legacy Lambda Menu.
# Set this to 1 to allow scripthook. Do note that this does _not_ guarantee players won't be able to use external plugins.
sv_scriptHookAllowed 0

# Uncomment this and set a password to enable RCON. Make sure to change the password - it should look like rcon_password "YOURPASSWORD"
#rcon_password ""

# A comma-separated list of tags for your server.
# For example:
# - sets tags "drifting, cars, racing"
# Or:
# - sets tags "roleplay, military, tanks"
sets tags "default"

# A valid locale identifier for your server's primary language.
# For example "en-US", "fr-CA", "nl-NL", "de-DE", "en-GB", "pt-BR"
sets locale "root-AQ"
# please DO replace root-AQ on the line ABOVE with a real language! :)

# Set an optional server info and connecting banner image url.
# Size doesn't matter, any banner sized image will be fine.
#sets banner_detail "https://url.to/image.png"
#sets banner_connecting "https://url.to/image.png"

# Set your server's hostname
sv_hostname "FXServer, but unconfigured"

# Set your server's Project Name
sets sv_projectName "My FXServer Project"

# Set your server's Project Description
sets sv_projectDesc "Default FXServer requiring configuration"

# Nested configs!
#exec server_internal.cfg

# Loading a server icon (96x96 PNG file)
#load_server_icon myLogo.png

# convars which can be used in scripts
set temp_convar "hey world!"

# Remove the `#` from the below line if you do not want your server to be listed in the server browser.
# Do not edit it if you *do* want your server listed.
#sv_master1 ""

# Add system admins
add_ace group.admin command allow # allow all commands
add_ace group.admin command.quit deny # but don't allow quit
add_principal identifier.fivem:1 group.admin # add the admin to the group

# enable OneSync (required for server-side state awareness)
set onesync on

# Server player slot limit (see https://fivem.net/server-hosting for limits)
sv_maxclients 48

# Steam Web API key, if you want to use Steam authentication (https://steamcommunity.com/dev/apikey)
# -> replace "" with the key
set steam_webApiKey ""

# License key for your server (https://keymaster.fivem.net)
sv_licenseKey changeme
EOF

# Create systemd service file
conwarn Setting up server for starting during boot
cat > /lib/systemd/system/fivem.service << EOF
[Unit]
Description=FiveM Server

[Service]
Type=forking
User=root
ExecStart=/usr/bin/fivem_startserver
ExecStop=/usr/bin/fivem_stopserver

[Install]
WantedBy=multi-user.target
EOF

# Install TMUX
coninfo Installing tmux
apt-get install tmux -y

# FiveM start script
conwarn Creating FiveM server start script
cat > /usr/bin/fivem_startserver << EOF
#!/bin/bash
tmux new-session -d -s "FiveM_Server"
tmux send-keys -t FiveM_Server "cd /root" Enter
tmux send-keys -t FiveM_Server "./run.sh +exec server.cfg" Enter
EOF
chmod +x /usr/bin/fivem_startserver

# FiveM stop script
conwarn Creating FiveM server stop script
cat > /usr/bin/fivem_stopserver << EOF
#!/bin/bash
tmux send-keys -t FiveM_Server C-c
tmux kill-session -t "FiveM_Server"
EOF
chmod +x /usr/bin/fivem_stopserver

# FiveM txAdmin Enable script
conwarn Creating FiveM txAdmin enable script
cat > /usr/bin/fivem_txadminenable << EOF
#!/bin/bash
rm /usr/bin/fivem_startserver
cat > /usr/bin/fivem_startserver << EOT
#!/bin/bash
tmux new-session -d -s "FiveM_Server"
tmux send-keys -t FiveM_Server "cd /root" Enter
tmux send-keys -t FiveM_Server "./run.sh" Enter
EOT
chmod +x /usr/bin/fivem_startserver
systemctl restart fivem
EOF
chmod +x /usr/bin/fivem_txadminenable

# FiveM txAdmin Disable script
conwarn Creating FiveM txAdmin disable script
cat > /usr/bin/fivem_txadmindisable << EOF
#!/bin/bash
rm /usr/bin/fivem_startserver
cat > /usr/bin/fivem_startserver << EOT
#!/bin/bash
tmux new-session -d -s "FiveM_Server"
tmux send-keys -t FiveM_Server "cd /root" Enter
tmux send-keys -t FiveM_Server "./run.sh +exec server.cfg" Enter
EOT
chmod +x /usr/bin/fivem_startserver
systemctl restart fivem
EOF
chmod +x /usr/bin/fivem_txadmindisable

# Reload systemd daemon
conemergency Reloading systemd daemon
systemctl daemon-reload

# Enable service file
connotice Enabling fivem service on boot
systemctl enable fivem

# Cleanup
coninfo Cleaning up
cd ~
rm -rf cubeshostvpsservice-stable stable.zip cfx-server-data

sleep 1

# Start service
conlog Starting FiveM Server
systemctl start fivem

# Final message
VPS_IP=$( hostname -I | cut -f2 -d' ' )
printf "
# Server successfully created and ready for use.
# Please add in the license key and other crucial information to get it ready and then restart the server.

# Server Information #
──────────────────────────────
  Server running on..
    IP Address: ${VPS_IP}
    Port: 30120
──────────────────────────────

# Commands to start, stop and restart server from VPS. #
  • Start
    systemctl start fivem

  • Stop
    systemctl stop fivem

  • Restart
    systemctl restart fivem

  • Status
    systemctl status fivem

# Note: Server Control Panel (txAdmin) is disabled by default, to enable please run 'fivem_txadminenable' and use 'tmux a -t FiveM_Server' to get the passcode to login with txAdmin.
# Follow our knowledgebase article for assistance:
"
