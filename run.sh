#!/bin/bash

## Functions ##
create_shairport_config () {
	cp /usr/local/etc/shairport-sync-sample.conf /usr/local/etc/shairport-sync-${1}.conf
	sed -i "s,%NAME%,${1}," /usr/local/etc/shairport-sync-${1}.conf
	sed -i "s,%PORT%,${2}," /usr/local/etc/shairport-sync-${1}.conf
	sed -i "s,%PIPE_NAME%,/tmp/${1}_pipe_airplay," /usr/local/etc/shairport-sync-${1}.conf
	sed -i "s,%META_PIPE_NAME%,/tmp/${1}_meta_pipe," /usr/local/etc/shairport-sync-${1}.conf
}

## Script starts here ##

rm -rf /var/run/dbus.pid

dbus-uuidgen --ensure
dbus-daemon --system

avahi-daemon --daemonize --no-chroot --debug

# wait 10s for avahi
echo "Starting Snapserver.."
sleep 10

SOURCES=""

# if DEVICES is set, then unify both airplay & spotify
if [ ! -z "$DEVICES" ]; then
	IFS=', ' read -r -a DEVICES <<< "$DEVICES"
	i=0
	for element in "${DEVICES[@]}"
	do
		i=$(($i+1))
	#	/usr/local/bin/librespot --name ${element} --bitrate 320 --backend pipe --device /tmp/${element}_pipe_spotify --cache /tmp/cache/spotify_${element} --initial-volume 50 --enable-volume-normalisation --autoplay &
		# create config & start shairport
	#	create_shairport_config ${element} 500$(($i-1))
	#	/usr/local/bin/shairport-sync --configfile=/usr/local/etc/shairport-sync-${element}.conf &
		# Add to snapserver sources
		#SOURCES="${SOURCES} \n source = pipe:///tmp/${element}_pipe_spotify?name=Spotify%20${element}\&dryout_ms=2000\&sampleformat=44100:16:2\&codec=null\&buffer=1000"
		SOURCES="${SOURCES} \n source = spotify:///librespot?name=Spotify%20${element}\&devicename=${element}\&bitrate=320\&volume=50\&cache=/tmp/cache/spotify_${element}\&killall=false\&dryout_ms=2000\&sampleformat=44100:16:2\&codec=null"
		#SOURCES="${SOURCES} \n source = pipe:///tmp/${element}_pipe_airplay?name=Airplay%20${element}\&dryout_ms=2000\&sampleformat=44100:16:2\&codec=null\&buffer=1000"
		SOURCES="${SOURCES} \n source = airplay:///shairport-sync?name=Airplay%20${element}\&devicename=${element}\&dryout_ms=2000\&sampleformat=44100:16:2\&codec=null\&port=500$(($i-1))"
		SOURCES="${SOURCES} \n source = meta:///Spotify%20${element}/Airplay%20${element}?name=${element}\&sampleformat=44100:16:2\&codec=flac"
	done
		
else # else use 'SPOTIFY_DEVICES' & 'AIRPLAY_DEVICES'
	IFS=', ' read -r -a SPOTIFY_DEVICES <<< "$SPOTIFY_DEVICES"
	IFS=', ' read -r -a AIRPLAY_DEVICES <<< "$AIRPLAY_DEVICES"
	# Spotify
	for element in "${SPOTIFY_DEVICES[@]}"
	do
		SOURCES="${SOURCES} \n source = spotify:///librespot?name=Spotify%20${element}\&devicename=$element\&bitrate=320\&volume=100\&killall=false\&cache=/tmp/cache/spotify_${element}\&sampleformat=44100:16:2\&codec=flac"
	done
	
	# Airplay
	i=0
	for element in "${AIRPLAY_DEVICES[@]}"
	do
		i=$(($i+1))
		SOURCES="${SOURCES} \n source = airplay:///shairport-sync?name=Airplay%20${element}\&devicename=$element\&port=500$(($i-1))\&sampleformat=44100:16:2\&codec=flac"
	done
fi

sed -i "s,^source = .*,${SOURCES} ," /etc/snapserver.conf

exec snapserver -c /etc/snapserver.conf


