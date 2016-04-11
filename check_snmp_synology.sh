#!/bin/bash
#
#
# check_website_by_selenium.sh
# Description : Checks a website using the Selenium Grid
#
# The MIT License (MIT)
# 
# Copyright (c) 2015, Roland Rickborn (roland.rickborn@exensio.de)
# 
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
# 
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
# 
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.
#
# check_snmp_synology for nagios version 2.3
# See https://exchange.nagios.org/directory/Plugins/Network-and-Systems-Management/Others/Synology-status/details
#
# 16.04.2015  Nicolas Ordonez, Switzerland
# 05.10.2015  Roland Rickborn <roland.rickborn@exensio.de>, Germany
# 29.02.2016  j-ed, https://github.com/j-ed
#---------------------------------------------------
# this plugin checks the health of your Synology NAS
# - System status (Power, Fans)
# - Disks status 
# - RAID status
# - DSM update status
# - Temperature Warning and Critical
# - UPS information
# - Storage percentage of use
#
# Tested with DSM 5.0, 5.1 & 5.2
#---------------------------------------------------
# Based on http://ukdl.synology.com/download/Document/MIBGuide/Synology_DiskStation_MIB_Guide.pdf
#---------------------------------------------------
# actual number disk limit = 52 disks per Synology
#---------------------------------------------------

SNMPWALK=$(which snmpwalk)
SNMPGET=$(which snmpget)

SNMPVersion="3"
SNMPV2Community="public"
SNMPTimeout="10"
warningTemperature="50"
criticalTemperature="60"
warningStorage="80"
criticalStorage="95"
hostname=""
healthWarningStatus=0
healthCriticalStatus=0
healthString=""
verbose="no"
ups="no"
perfDataTempString=""
perfDataStorageString=""
perfData="no"
dsmcheck="no"

#OID declarations
OID_syno="1.3.6.1.4.1.6574"
OID_model="1.3.6.1.4.1.6574.1.5.1.0"
OID_serialNumber="1.3.6.1.4.1.6574.1.5.2.0"
OID_DSMVersion="1.3.6.1.4.1.6574.1.5.3.0"
OID_DSMUpgradeAvailable="1.3.6.1.4.1.6574.1.5.4.0"
OID_systemStatus="1.3.6.1.4.1.6574.1.1.0"
OID_temperature="1.3.6.1.4.1.6574.1.2.0"
OID_powerStatus="1.3.6.1.4.1.6574.1.3.0"
OID_systemFanStatus="1.3.6.1.4.1.6574.1.4.1.0"
OID_CPUFanStatus="1.3.6.1.4.1.6574.1.4.2.0"

OID_disk=""
OID_disk2=""
OID_diskID="1.3.6.1.4.1.6574.2.1.1.2"
OID_diskModel="1.3.6.1.4.1.6574.2.1.1.3"
OID_diskStatus="1.3.6.1.4.1.6574.2.1.1.5"
OID_diskTemp="1.3.6.1.4.1.6574.2.1.1.6"

OID_RAID=""
OID_RAIDName="1.3.6.1.4.1.6574.3.1.1.2"
OID_RAIDStatus="1.3.6.1.4.1.6574.3.1.1.3"

OID_Storage="1.3.6.1.2.1.25.2.3.1"
OID_StorageDesc="1.3.6.1.2.1.25.2.3.1.3"
OID_StorageAllocationUnits="1.3.6.1.2.1.25.2.3.1.4"
OID_StorageSize="1.3.6.1.2.1.25.2.3.1.5"
OID_StorageSizeUsed="1.3.6.1.2.1.25.2.3.1.6"

OID_UpsModel="1.3.6.1.4.1.6574.4.1.1.0"
OID_UpsSN="1.3.6.1.4.1.6574.4.1.3.0"
OID_UpsStatus="1.3.6.1.4.1.6574.4.2.1.0"
OID_UpsLoad="1.3.6.1.4.1.6574.4.2.12.1.0"
OID_UpsBatteryCharge="1.3.6.1.4.1.6574.4.3.1.1.0"
OID_UpsBatteryChargeWarning="1.3.6.1.4.1.6574.4.3.1.4.0"

usage()
{
        echo "usage: ./check_snmp_synology [OPTION] -u [user] -p [pass] -h [hostname]"
        echo "options:"
        echo "            -u [snmp username]    Username for SNMPv3"
        echo "            -p [snmp password]    Password for SNMPv3"
        echo ""
        echo "            -2 [community name]   Use SNMPv2 (no need user/password) & define community name (default $SNMPV2Community)"
        echo ""
        echo "            -W [warning temp]     Warning temperature (for disks & synology) (default $warningTemperature)"
        echo "            -C [critical temp]    Critical temperature (for disks & synology) (default $criticalTemperature)"
        echo ""
        echo "            -w [warning %]        Warning storage usage percentage (default $warningStorage)"
        echo "            -c [critical %]       Critical storage usage percentage (default $criticalStorage)"
        echo ""
        echo "            -U Show informations about the connected UPS (default no)"
        echo "            -v Verbose - print all informations about your Synology (default $verbose)"
        echo "            -f PerfData - print performance data for temperature and storage usage percentage (default $perfData)"
        echo "            -d Check DSM Version - check if an update for DiskStation Manager is available (default $dsmcheck)"
        echo ""
        echo ""
        echo "examples:    ./check_snmp_synology -u admin -p 1234 -h nas.intranet"
        echo "             ./check_snmp_synology -u admin -p 1234 -h nas.intranet -v"
        echo "             ./check_snmp_synology -2 public -h nas.intranet"
        exit 3
}

if [ "$1" == "--help" ]; then
    usage
    exit 0
fi

while getopts 2:W:C:w:c:u:p:h:Uvfd OPTNAME;
do
    case "$OPTNAME" in
        u)  SNMPUser="$OPTARG";;
        p)  SNMPPassword="$OPTARG";;
        h)  hostname="$OPTARG";;
        v)  verbose="yes";;
        2)  SNMPVersion="2"
            SNMPV2Community="$OPTARG";;
        w)  warningStorage="$OPTARG";;
        c)  criticalStorage="$OPTARG";;
        W)  warningTemperature="$OPTARG";;
        C)  criticalTemperature="$OPTARG";;
        U)  ups="yes";;
        f)  perfData="yes";;
        d)  dsmcheck="yes";;
        *)  usage;;
    esac
done

if [ "$warningTemperature" -gt "$criticalTemperature" ] ; then
    echo "Critical temperature must be higher than warning temperature"
    echo "Warning temperature: $warningTemperature"
    echo "Critical temperature: $criticalTemperature"
    echo ""
    echo "For more information:  ./${0##*/} --help"
    exit 1
fi

if [ "$warningStorage" -gt "$criticalStorage" ] ; then
    echo "The Critical storage usage percentage  must be higher than the warning storage usage percentage"
    echo "Warning: $warningStorage"
    echo "Critical: $criticalStorage"
    echo ""
    echo "For more information:  ./${0##*/} --help"
    exit 1
fi

if [ "$hostname" = "" ] || ([ "$SNMPVersion" = "3" ] && [ "$SNMPUser" = "" ]) || ([ "$SNMPVersion" = "3" ] && [ "$SNMPPassword" = "" ]) ; then
    usage
else
    if [ "$SNMPVersion" = "2" ] ; then
        SNMPArgs=" -OQne -v 2c -c $SNMPV2Community -t $SNMPTimeout"
    else
        SNMPArgs=" -OQne -v 3 -u $SNMPUser -A $SNMPPassword -l authNoPriv -a MD5 -t $SNMPTimeout"
        if [ ${#SNMPPassword} -lt "8" ] ; then
            echo "snmpwalk:  (The supplied password length is too short.)"
            exit 1
        fi
    fi
    tmpRequest=`$SNMPWALK $SNMPArgs $hostname $OID_syno 2> /dev/null`
    if [ "$?" != "0" ] ; then
        echo "CRITICAL - Problem with SNMP request, check user/password/host"
        exit 2
    fi
    nbDisk=$(echo "$tmpRequest" | grep $OID_diskID | wc -l)
    nbRAID=$(echo "$tmpRequest" | grep $OID_RAIDName | wc -l)

    for i in `seq 1 $nbDisk`;
    do
        if [ $i -lt 25 ] ; then
        OID_disk="$OID_disk $OID_diskID.$(($i-1)) $OID_diskModel.$(($i-1)) $OID_diskStatus.$(($i-1)) $OID_diskTemp.$(($i-1)) "
        else
            OID_disk2="$OID_disk2 $OID_diskID.$(($i-1)) $OID_diskModel.$(($i-1)) $OID_diskStatus.$(($i-1)) $OID_diskTemp.$(($i-1)) "
        fi
    done

    for i in `seq 1 $nbRAID`;
    do
        OID_RAID="$OID_RAID $OID_RAIDName.$(($i-1)) $OID_RAIDStatus.$(($i-1))"
    done

    if [ "$ups" = "yes" ] && [ "$dsmcheck" = "yes" ]; then
        syno=`$SNMPGET $SNMPArgs $hostname $OID_model $OID_serialNumber $OID_DSMVersion $OID_systemStatus $OID_temperature $OID_powerStatus $OID_systemFanStatus $OID_CPUFanStatus $OID_disk $OID_RAID $OID_DSMUpgradeAvailable $OID_UpsModel $OID_UpsSN $OID_UpsStatus $OID_UpsLoad $OID_UpsBatteryCharge $OID_UpsBatteryChargeWarning 2> /dev/null`
    elif [ "$ups" = "no" ] && [ "$dsmcheck" = "yes" ] ; then
        syno=`$SNMPGET $SNMPArgs $hostname $OID_model $OID_serialNumber $OID_DSMVersion $OID_systemStatus $OID_temperature $OID_powerStatus $OID_systemFanStatus $OID_CPUFanStatus $OID_disk $OID_RAID $OID_DSMUpgradeAvailable 2> /dev/null`
    elif [ "$ups" = "yes" ] && [ "$dsmcheck" = "no" ] ; then
        syno=`$SNMPGET $SNMPArgs $hostname $OID_model $OID_serialNumber $OID_DSMVersion $OID_systemStatus $OID_temperature $OID_powerStatus $OID_systemFanStatus $OID_CPUFanStatus $OID_disk $OID_RAID $OID_UpsModel $OID_UpsSN $OID_UpsStatus $OID_UpsLoad $OID_UpsBatteryCharge $OID_UpsBatteryChargeWarning 2> /dev/null`
    elif [ "$ups" = "no" ] && [ "$dsmcheck" = "no" ] ; then
        syno=`$SNMPGET $SNMPArgs $hostname $OID_model $OID_serialNumber $OID_DSMVersion $OID_systemStatus $OID_temperature $OID_powerStatus $OID_systemFanStatus $OID_CPUFanStatus $OID_disk $OID_RAID 2> /dev/null`
    fi

    if [ "$OID_disk2" != "" ]; then
        syno2=`$SNMPGET $SNMPArgs $hostname $OID_disk2 2> /dev/null`
        syno=$(echo "$syno";echo "$syno2";)
    fi

    model=$(echo "$syno" | grep $OID_model | cut -d "=" -f2)
    serialNumber=$(echo "$syno" | grep $OID_serialNumber | cut -d "=" -f2)
    DSMVersion=$(echo "$syno" | grep $OID_DSMVersion | cut -d "=" -f2)

    healthString="Synology $model (s/n:$serialNumber, $DSMVersion)"

    DSMUpgradeAvailable=$(echo "$syno" | grep $OID_DSMUpgradeAvailable | cut -d "=" -f2 | sed 's/^[ \t]*//;s/[ \t]*$//')
    case $DSMUpgradeAvailable in
        "1")    DSMUpgradeAvailable="Available";    healthWarningStatus=1;    healthString="$healthString, DSM update available";;
        "2")    DSMUpgradeAvailable="Unavailable";;
        "3")    DSMUpgradeAvailable="Connecting";;
        "4")    DSMUpgradeAvailable="Disconnected";    healthWarningStatus=1;    healthString="$healthString, DSM Update Disconnected";;
        "5")    DSMUpgradeAvailable="Others";    healthWarningStatus=1;     healthString="$healthString, Check DSM Update";;
    esac

    RAIDName=$(echo "$syno" | grep $OID_RAIDName | cut -d "=" -f2)
    RAIDStatus=$(echo "$syno" | grep $OID_RAIDStatus | cut -d "=" -f2 | sed 's/^[ \t]*//;s/[ \t]*$//')
    systemStatus=$(echo "$syno" | grep $OID_systemStatus | cut -d "=" -f2 | sed 's/^[ \t]*//;s/[ \t]*$//')
    temperature=$(echo "$syno" | grep $OID_temperature | cut -d "=" -f2 | sed 's/^[ \t]*//;s/[ \t]*$//')
    powerStatus=$(echo "$syno" | grep $OID_powerStatus | cut -d "=" -f2 | sed 's/^[ \t]*//;s/[ \t]*$//')
    systemFanStatus=$(echo "$syno" | grep $OID_systemFanStatus | cut -d "=" -f2 | sed 's/^[ \t]*//;s/[ \t]*$//')
    CPUFanStatus=$(echo "$syno" | grep $OID_CPUFanStatus | cut -d "=" -f2 | sed 's/^[ \t]*//;s/[ \t]*$//')


    #Check system status
    if [ "$systemStatus" = "1" ] ; then
        systemStatus="Normal"
    else
        systemStatus="Failed"
        healthCriticalStatus=1
        healthString="$healthString, System status: $systemStatus "
    fi

    #Check system temperature
    if [ "$temperature" -gt "$warningTemperature" ] ; then
        if [ "$temperature" -gt "$criticalTemperature" ] ; then
            temperature="$temperature (CRITICAL)"
            healthCriticalStatus=1
            healthString="$healthString, temperature: $temperature "
        else
            temperature="$temperature (WARNING)"
            healthWarningStatus=1
            healthString="$healthString, temperature: $temperature "
        fi
    else
        temperature="$temperature (Normal)"
    fi

    #Check power status
    if [ "$powerStatus" = "1" ] ; then
        powerStatus="Normal"
    else
        powerStatus="Failed";
        healthCriticalStatus=1
        healthString="$healthString, Power status: $powerStatus "
    fi


    #Check system fan status
    if [ "$systemFanStatus" = "1" ] ; then
        systemFanStatus="Normal"
    else
        systemFanStatus="Failed";
        healthCriticalStatus=1
        healthString="$healthString, System fan status: $systemFanStatus "
    fi

    #Check CPU fan status
    if [ "$CPUFanStatus" = "1" ] ; then
        CPUFanStatus="Normal"
    else
        CPUFanStatus="Failed";
        healthCriticalStatus=1
        healthString="$healthString, CPU fan status: $CPUFanStatus "
    fi

    #Check all disk status
    for i in `seq 1 $nbDisk`;
    do
        diskID[$i]=$(echo "$syno" | grep "$OID_diskID.$(($i-1)) " | cut -d "=" -f2)
        diskModel[$i]=$(echo "$syno" | grep "$OID_diskModel.$(($i-1)) " | cut -d "=" -f2 )
        diskStatus[$i]=$(echo "$syno" | grep "$OID_diskStatus.$(($i-1)) " | cut -d "=" -f2 | sed 's/^[ \t]*//;s/[ \t]*$//')
        diskTemp[$i]=$(echo "$syno" | grep "$OID_diskTemp.$(($i-1)) " | cut -d "=" -f2 | sed 's/^[ \t]*//;s/[ \t]*$//')

        #Store perfData
        perfDataTempString="$perfDataTempString 'Temp Disk $i'=${diskTemp[$i]};$warningTemperature;$criticalTemperature;0" ;

        case ${diskStatus[$i]} in
            "1")    diskStatus[$i]="Normal";    ;;
            "2")    diskStatus[$i]="Initialized";   ;;
            "3")    diskStatus[$i]="NotInitialized";    ;;
            "4")    diskStatus[$i]="SystemPartitionFailed";    healthCriticalStatus=1; healthString="$healthString, problem with ${diskID[$i]} (model:${diskModel[$i]}) status:${diskStatus[$i]} temperature:${diskTemp[$i]}";;
            "5")    diskStatus[$i]="Crashed";        healthCriticalStatus=1;    healthString="$healthString, problem with ${diskID[$i]} (model:${diskModel[$i]}) status:${diskStatus[$i]} temperature:${diskTemp[$i]}";;
        esac

        if [ "${diskTemp[$i]}" -gt "$warningTemperature" ] ; then
            if [ "${diskTemp[$i]}" -gt "$criticalTemperature" ] ; then
                diskTemp[$i]="${diskTemp[$i]} (CRITICAL)"
                healthCriticalStatus=1;
                healthString="$healthString, ${diskID[$i]} temperature: ${diskTemp[$i]}"
            else
                diskTemp[$i]="${diskTemp[$i]} (WARNING)"
                healthWarningStatus=1;
                healthString="$healthString, ${diskID[$i]} temperature: ${diskTemp[$i]}"
            fi
        fi

    done

    syno_diskspace=`$SNMPWALK $SNMPArgs $hostname $OID_Storage 2> /dev/null`

    #Check all RAID volume status
    for i in `seq 1 $nbRAID`;
    do
        RAIDName[$i]=$(echo "$syno" | grep $OID_RAIDName.$(($i-1)) | cut -d "=" -f2)
        RAIDStatus[$i]=$(echo "$syno" | grep $OID_RAIDStatus.$(($i-1)) | cut -d "=" -f2 | sed 's/^[ \t]*//;s/[ \t]*$//')

        storageName[$i]=$(echo "${RAIDName[$i]}" | sed -e 's/[[:blank:]]//g' | sed -e 's/\"//g' | sed 's/.*/\L&/')
        storageID[$i]=$(echo "$syno_diskspace" | grep -E "= *${storageName[$i]} *$" | cut -d "=" -f1 | rev | cut -d "." -f1 | rev)

        if [ "${storageID[$i]}" != "" ] ; then
            storageSize[$i]=$(echo "$syno_diskspace" | grep "$OID_StorageSize.${storageID[$i]}" | cut -d "=" -f2 )
            storageSizeUsed[$i]=$(echo "$syno_diskspace" | grep "$OID_StorageSizeUsed.${storageID[$i]}" | cut -d "=" -f2 )
            storageAllocationUnits[$i]=$(echo "$syno_diskspace" | grep "$OID_StorageAllocationUnits.${storageID[$i]}" | cut -d "=" -f2 )
            storagePercentUsed[$i]=$((${storageSizeUsed[$i]} * 100 / ${storageSize[$i]}))
            storagePercentUsedString[$i]="${storagePercentUsed[$i]}% used"

            #Store perfData
            perfDataStorageString="$perfDataStorageString 'Raid $i Usage'=${storagePercentUsed[$i]};$warningStorage;$criticalStorage;0" ;

            if [ "${storagePercentUsed[$i]}" -gt "$warningStorage" ] ; then
                if [ "${storagePercentUsed[$i]}" -gt "$criticalStorage" ] ; then
                    healthCriticalStatus=1;
                    storagePercentUsedString[$i]="${storagePercentUsedString[$i]} CRITICAL"
                    healthString="$healthString,${RAIDName[$i]}: ${storagePercentUsedString[$i]}"
                else
                    healthWarningStatus=1;
                    storagePercentUsedString[$i]="${storagePercentUsedString[$i]} WARNING"
                    healthString="$healthString,${RAIDName[$i]}: ${storagePercentUsedString[$i]}"
                fi
            fi
        fi

        case ${RAIDStatus[$i]} in
            "1")    RAIDStatus[$i]="Normal";    ;;
            "2")    RAIDStatus[$i]="Repairing";        healthWarningStatus=1;        healthString="$healthString, RAID status (${RAIDName[$i]}): ${RAIDStatus[$i]} ";;
            "3")    RAIDStatus[$i]="Migrating";        healthWarningStatus=1;        healthString="$healthString, RAID status (${RAIDName[$i]}): ${RAIDStatus[$i]} ";;
            "4")    RAIDStatus[$i]="Expanding";        healthWarningStatus=1;        healthString="$healthString, RAID status (${RAIDName[$i]}): ${RAIDStatus[$i]} ";;
            "5")    RAIDStatus[$i]="Deleting";        healthWarningStatus=1;        healthString="$healthString, RAID status (${RAIDName[$i]}): ${RAIDStatus[$i]} ";;
            "6")    RAIDStatus[$i]="Creating";        healthWarningStatus=1;        healthString="$healthString, RAID status (${RAIDName[$i]}): ${RAIDStatus[$i]} ";;
            "7")    RAIDStatus[$i]="RaidSyncing";        healthWarningStatus=1;        healthString="$healthString, RAID status (${RAIDName[$i]}): ${RAIDStatus[$i]} ";;
            "8")    RAIDStatus[$i]="RaidParityChecking";    healthWarningStatus=1;        healthString="$healthString, RAID status (${RAIDName[$i]}): ${RAIDStatus[$i]} ";;
            "9")    RAIDStatus[$i]="RaidAssembling";    healthWarningStatus=1;        healthString="$healthString, RAID status (${RAIDName[$i]}): ${RAIDStatus[$i]} ";;
            "10")    RAIDStatus[$i]="Canceling";        healthWarningStatus=1;        healthString="$healthString, RAID status (${RAIDName[$i]}): ${RAIDStatus[$i]} ";;
            "11")    RAIDStatus[$i]="Degrade";        healthCriticalStatus=1;        healthString="$healthString, RAID status (${RAIDName[$i]}): ${RAIDStatus[$i]} ";;
            "12")    RAIDStatus[$i]="Crashed";        healthCriticalStatus=1;        healthString="$healthString, RAID status (${RAIDName[$i]}): ${RAIDStatus[$i]} ";;
        esac
    done

    if [ "$verbose" = "yes" ] ; then
        echo "Synology model:        $model" ;
        echo "Synology s/n:          $serialNumber" ;
        echo "DSM Version:           $DSMVersion" ;
        echo "DSM update:            $DSMUpgradeAvailable" ;
        echo "System Status:         $systemStatus" ;
        echo "Temperature:           $temperature" ;
        echo "Power Status:          $powerStatus" ;
        echo "System Fan Status:     $systemFanStatus" ;
        echo "CPU Fan Status:        $CPUFanStatus" ;
        echo "Number of disks:       $nbDisk" ;
        for i in `seq 1 $nbDisk`;
        do
            echo " ${diskID[$i]} (model:${diskModel[$i]}) status:${diskStatus[$i]} temperature:${diskTemp[$i]}" ;
        done
        echo "Number of RAID volume:   $nbRAID" ;
        for i in `seq 1 $nbRAID`;
        do
            echo " ${RAIDName[$i]} status:${RAIDStatus[$i]} ${storagePercentUsedString[$i]}" ;
        done

        # Display UPS information
            if [ "$ups" = "yes" ] ; then
                upsModel=$(echo "$syno" | grep $OID_UpsModel | cut -d "=" -f2)
                upsSN=$(echo "$syno" | grep $OID_UpsSN | cut -d "=" -f2)
                upsStatus=$(echo "$syno" | grep $OID_UpsStatus | cut -d "=" -f2)
                upsLoad=$(echo "$syno" | grep $OID_UpsLoad | cut -d "=" -f2)
                upsBatteryCharge=$(echo "$syno" | grep $OID_UpsBatteryCharge | cut -d "=" -f2)
                upsBatteryChargeWarning=$(echo "$syno" | grep $OID_UpsBatteryChargeWarning | cut -d "=" -f2)

            echo "UPS:"
            echo "  Model:        $upsModel"
            echo "  s/n:            $upsSN"
            echo "  Status:        $upsStatus"
            echo "  Load:            $upsLoad"
            echo "  Battery charge:    $upsBatteryCharge"
            echo "  Battery charge warning:$upsBatteryChargeWarning"
        fi

        echo "";
    fi

    if [ "$healthCriticalStatus" = "1" ] && [ "$perfData" == "no"  ] ; then
        echo "CRITICAL - $healthString"
        exit 2
    fi
    if [ "$healthWarningStatus" = "1" ] && [ "$perfData" == "no"  ] ; then
        echo "WARNING - $healthString"
        exit 1
    fi
    if [ "$healthCriticalStatus" = "0" ] && [ "$healthWarningStatus" = "0" ] && [ "$perfData" == "no"  ] ; then
        echo "OK - $healthString is in good health"
        exit 0
    fi
        if [ "$healthCriticalStatus" = "1" ] && [ "$perfData" == "yes"  ] ; then
        echo "CRITICAL - $healthString | $perfDataTempString $perfDataStorageString"
        exit 2
    fi
    if [ "$healthWarningStatus" = "1" ] && [ "$perfData" == "yes"  ] ; then
        echo "WARNING - $healthString | $perfDataTempString $perfDataStorageString"
        exit 1
    fi
    if [ "$healthCriticalStatus" = "0" ] && [ "$healthWarningStatus" = "0" ] && [ "$perfData" == "yes"  ] ; then
        echo "OK - $healthString is in good health | $perfDataTempString $perfDataStorageString"
        exit 0
    fi
fi

exit 3
