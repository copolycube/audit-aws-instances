#!/bin/bash

# Critical (exit code 2) if > this number
crit=4

function print_help() {
    echo "###########################################\n
# Audits AWS instances for unused reserved\n
# instances and instances which do not have\n
# corresponding reserved instances.\n
###########################################\n
"
    echo "-h : print this message and exit"
    echo "-v : print some intermediate values (useful for debug)"
    echo "-d : print some details over the AWS instances reserved and active"
    exit
}
verbose=""
details=""

while getopts "rdvh" opt; do
  case ${opt} in
      d) # print details for each instances types
	  details=1
	  ;;
      v) # verbose logs
	  verbose=1
	  ;;
      h) # print help message and exit
	  print_help
	  ;;
      \?)
	  echo "$0 -h -v -d"
	  ;;
  esac
done


function log() {
    if [ -z $verbose ]; then
	return
    else
	echo "$1"
    fi
}


#    source ~/.profile
#aws_regions="eu-west-2 eu-west-1 ca-central-1 us-east-1"
aws_regions=$(aws ec2 describe-regions --query "Regions[].{Name:RegionName}" --output text --region ca-central-1)

log "************* List of aws_regions=$aws_regions"

for region in $aws_regions; do
    log "============================================"
    log "---------- AWS Region : $region ----------" ; 
    log "============================================"

    reserved_types=$(/usr/local/bin/aws ec2 describe-reserved-instances --region $region --filter Name=state,Values=active Name=scope,Values=Region --output text | grep RESERVEDINSTANCES | awk '{print $8}')
    in_use_types=$(/usr/local/bin/aws ec2 describe-instances --query 'Reservations[].Instances[].[InstanceType]' --output text)
    used_types=$(echo "$reserved_types $in_use_types" | xargs -n1 | sort -u | xargs)
    #used_types="m3.medium m3.large m3.xlarge m3.2xlarge m4.large m4.xlarge m4.2xlarge m4.4xlarge r3.large r3.xlarge r3.2xlarge r3.4xlarge r3.8xlarge"
    log "========== Types for region $region : $used_types"
    
    # list of reserved instances
     active_res=$(/usr/local/bin/aws ec2 describe-reserved-instances --filter Name=state,Values=active Name=scope,Values="Availability Zone" --output text --region $region)
    active_conv=$(/usr/local/bin/aws ec2 describe-reserved-instances --filter Name=state,Values=active Name=scope,Values=Region              --output text --region $region)

    # list of active instances
     active_ins=$(/usr/local/bin/aws ec2 describe-instances          --filter Name=instance-state-name,Values=running                        --output text --region $region)

    exit_code=0

    # Loop through instances types

    for type in $used_types; do
	log "------------ $region $type -----------"
	res_total=0
	ins_total=0
	# count the number of active reserved instance of the current type (column 7 = #)
	while read -r instance; do
	    qty=$(echo "$instance" | awk '{print $7}')
	    res_total=$(expr "$res_total" + "$qty")
	done < <(echo "$active_res" | grep "$type")

	# count the number of 
	while read -r instance; do
	    qty=$(echo "$instance" | awk '{print $6}')
	    res_total=$(expr "$res_total" + "$qty")
	done < <(echo "$active_conv" | grep "$type")

	# total number of active instances
	ins_total=$(echo "$active_ins" | grep -c "$type")

	diff=$(($res_total - $ins_total))
	
	log "$region $type diff=$diff"
	if [[ $diff -gt $crit ]]; then
	    echo "$region $type UNUSED RESERVATION: (${diff}) - $type"
	    exit_code=2
	elif [[ $diff -gt 0 ]]; then
	    echo "$region $type UNUSED RESERVATION: (${diff}) - $type"
	    if [[ $exit_code -ne 2 ]]; then
		exit_code=1
	    fi
	elif [[ $diff -lt -${crit} ]]; then
	    diff=$(echo $diff | sed 's/-//g')
	    echo "$region $type UNRESERVED INSTANCES: (${diff}) - $type"
	    exit_code=2
	elif [[ $diff -lt 0 ]]; then
	    diff=$(echo $diff | sed 's/-//g')
	    echo "$region $type UNRESERVED INSTANCES: (${diff}) - $type"
	    if [[ $exit_code -ne 2 ]]; then
		exit_code=1
	    fi
	fi
	
	
	if [ $details ]; then
	    echo "$region $type TotalActive   = $ins_total"
	    echo "$region $type TotalReserved = $res_total"
	    /usr/local/bin/aws ec2 describe-reserved-instances --filter Name=state,Values=active Name=instance-type,Values=$type  --region $region --output text --query "ReservedInstances[].[ReservedInstancesId,InstanceType,State,End]"
	fi
	log "--------------------------------------------"
    done
done

exit $exit_code
