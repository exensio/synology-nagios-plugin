# synology-nagios-plugin
A simple Nagios Plugin which checks the health of a Synology NAS
It checks the following items:
* System status (Power, Fans)
* Disks status
* RAID (Volumes) status
* DSM update status
* Temperatures
* Storage usage
* UPS informations

## [exensio GmbH Blog](https://www.exensio.de/news-medien)

This repositroy is created for the blogpost: [Synology DiskStation per SNMP überwachen](https://www.exensio.de/news-medien/newsreader-blog/synology-diskstation-per-snmp-ueberwachen)

## Requirements
The SNMP agent on the NAS has to be activated.

## Command Line Usage
```
./check_snmp_synology [OPTION] -u [user] -p [pass] -h [hostname]
options:
-u [snmp username] Username for SNMPv3
-p [snmp password] Password for SNMPv3

-2 [community name]   Use SNMPv2 (no need user/password) & define community name (default public)

-W [warning temp] Warning temperature (for disks & synology) (default 50)
-C [critical temp] Critical temperature (for disks & synology) (default 60)

-w [warning %] Warning storage usage percentage (default 80)
-c [critical %] Critical storage usage percentage (default 95)

-U Show informations about the connected UPS (default no)
-f PerfData - print performance data for temperature and storage usage percentage (default no)
-v Verbose - print all informations about your Synology (default no)
-d Check DSM Version - check if an update for DiskStation Manager is available (default no)

```

## Nagios Plugin Configuration
My *commands.cfg* looks like this:
```
define command {
  command_name                   check_snmp_synology
  command_line                   $USER2$/check_snmp_synology -2 $ARG1$ -v -h $HOSTADDRESS$ -f -W $ARG2$ -C $ARG3$ -w $ARG4$ -c $ARG5$
}
```

And my *services.cfg* looks like this:
```
define service {
  service_description            check_snmp_synology_demo
  host_name                      demo_host
  use                            check_mk_active
  check_command                  check_snmp_synology!public!45!48!85!90
}
```

## Based on
This plugin has been originally published by [Nicolas Ordonez] (mailto:nicolas.ord@gmail.com) on [https://exchange.nagios.org] (https://exchange.nagios.org/directory/Plugins/Network-and-Systems-Management/Others/Synology-status/details)
