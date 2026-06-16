# /etc/profile.d/killsuru.sh
# Enable the killsuru wrapper for login shells (bash, sh).
# Interactive / script guarding is handled inside the sourced file.
if [ -r /usr/share/killsuru/killsuru.sh ]; then
    . /usr/share/killsuru/killsuru.sh
fi
