#! /bin/sh

# include the json parsing library
. /usr/share/libubox/jshn.sh

# get reading from DS18B20 1-wire tempearture sensor
#	echo returns the sensor reading
getDS18B20Reading () {
	# read device unique ID from list of slaves (assumes a single 1-wire slave)
	local devId=$(cat /sys/devices/w1_bus_master1/w1_master_slaves)
	# get the reading from the sensor
	value=$(awk -F= '/t=/ {printf "%.03f\n", $2/1000}' /sys/devices/w1_bus_master1/$devId/w1_slave)

	echo "$value"
}

# update AWS IoT Thing shadow
#  arg1 - AWS IoT Thing Name
#  arg2 - value
updateThingShadow () {
	local thingId="$1"
	local value="$2"

	# init JSON for AWS IoT device shadow update
	json_init
	json_add_object "state"
	json_add_object "reported"

	json_add_double "temperature" "$value"

	# generate json
	jsonOutput=$(json_dump)

	echo "Updating AWS IoT Thing Shadow"
	echo "$jsonOutput"

	# publish to AWS IoT
	mosquitto_pub -q 1 -d -t "\$aws/things/$thingId/shadow/update" -m "$jsonOutput"
}

# perform all sensor reading actions and publish structured JSON data to AWS IoT
#  arg1 - AWS IoT Thing Name
main () {
	local thingId="$1"

	# read DS18B20 sensor
	reading=$(getDS18B20Reading)
	echo "> Sensor reading: '$reading'"

	# update AWS IoT Thing shadow with latest measurement
	updateThingShadow "$thingId" "$reading"
}

## parse arguments
if [ "$1" == "" ];
then
	echo "ERROR: Expecting argument specifying AWS IoT Thing Name"
	exit
fi

main "$1"
