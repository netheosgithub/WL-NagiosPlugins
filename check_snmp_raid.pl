#!/usr/bin/perl -wT
#
# ============================== SUMMARY =====================================
#
# Program : check_snmp_raid / check_sasraid_megaraid / check_megaraid
# Version : 2.2b1
# Date    : Apr 30, 2013
# Author  : William Leibzon - william@leibzon.org
# Copyright: (C) 2006-2013 William Leibzon
# Summary : This is a nagios plugin to monitor Raid controller cards with SNMP
#           and report status of the physical drives and logical volumes and
#            additional information such as battery status, disk and volume errors.
# Licence : GPL 3 - summary below, full text at http://www.fsf.org/licenses/gpl.txt
# =========================== PROGRAM LICENSE ================================
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GnU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
#
# ===================== INFORMATION ABOUT THIS PLUGIN ========================
#
# check_snmp_raid | check_sasraid_megaraid | check_megaraid | check_sasraid
#
# This is a Nagios plugin that uses SNMP to monitor several types of RAID cards.
# It can check status of physical drives and logical volumes, and check for disk errors.
#
# This was originally written to monitor LSI MegaRAID series of cards, sold by LSI and
# more commonly found in Dell systems under their brand name 'PERC' (PERC3-PERC6).
# Older ones are SCSI RAID cards and newer are SAS RAID cards. New cards sold directly
# are now called MTPFusion and supported by plugin too. The plugin code is general
# enough that it was possible to add support for Adaptec and HP SmartArray cards.
# This was added to 2.x version of this plugin when it was also renamed check_snmp_raid
# Support for more controllers maybe added if you look at the MIBS are willing to
# contribute settings for them.
#
# This plugin requires that Net::SNMP be installed on the machine performing the
# monitoring and that snmp agent be set up on the machine to be monitored.
#
# This plugin is maintained by William Leibzon and released at:
#    http://william.leibzon.org/nagios/
#
# =============================== SETUP NOTES ================================
# 
# Run this plugin with '-h' to see all avaiable options.
#
# This originally started as check_megaraid plugin but now has been extended
# to work with various cards. You must specify what card with '-T' option.
# The following are acceptable types as of Apr 2013:
#   megaraid|sasraid|perc3|perc4|perc5|perc6|mptfusion|sas6ir|sas6|
#   adaptec|hp|smartarray|eti|ultrastor
#
# You will need to have SNMP package installed appropriate for your card.
#
# If you have SASRaid (also known as PERC5, PERC6) you need sasraid LSI package
# (lsi_mrdsnmpd unix service). This driver is available at
#   http://www.lsi.com/storage_home/products_home/internal_raid/megaraid_sas/megaraid_sas_8480e/index.html
#
# For LSI Megaraid (Dell PERC3 and PERC4 cards) the driver package is
# called percsnmp and you either find it on Dell's support site or at
#   http://www.lsi.com/storage_home/products_home/internal_raid/megaraid_scsi/
#
# For other cards please check with vendor you bought the card from for
# an appropriate SNMP driver package.
#
# This is a very old example of nagios config for Megarad card check:
#  (note that $USER1$ and $USER6$ are defined in resource.cfg,
#   $USER1$ is path to plugin directory and $USER6$ is community string
#   also "" around macros in commands.cfg are on purpose, don't forget them):
#
# define command {
#        command_name check_megaraid
#        command_line $USER1$/check_megaraid.pl -T megaraid -e -o -i -s 1 -H $HOSTADDRESS$ -C $USER6$ -P "$SERVICEPERFDATA$" -S "$SERVICESTATE$,$SERVICESTATETYPE$"
# }
# define service{
#        host_name                       list of target hosts
#        service_description             Megaraid Status
#        check_command                   check_megaraid
#        ...
# }
#
# =========================== VERSION HISTORY ================================
#
#   0. [0.8 - ? 2002] Version 0.8 of check_megaraid plugin was released by
#                     John Reuning in 2002. His plugin was originally at
#                      http://www.ibiblio.org/john/megaraid/
# 
#   This was starting point for this plugin. However less than 10% of the code
#   is now from original John's plugin and he has not been involved since then,
#   he is now listed as contributor and not as an author. The original
#   "Copyright 2002 iBiblio" has also been removed although this may still
#   apply to small portions of the code. This note has been added in 2012.
#
#   1. [0.9 - ? 2006] Check consistancy has been downgraded to WARNING
#   2. [0.9 - ? 2006] The message in the output is now more detailed
#   3. [0.9 - ? 2006] The number of drives is now displayed in the output
#   4. [1.1 - Feb 2007] Plugin now retrieves snmp oid for read and write errors
#                       and reports an alert if its not 0 or -1
#   5. [1.2 - Feb 2007] Plugin now checks 'medium' and 'other' errors for
#      all physical drives. This data is returned as performance output and
#      in order to detect changes you need to send previous performance results
#      as a parameter in the command to this plugin. If your nagios is set to
#      send notifications after multiple subsequent non-OK alerts then you
#      also need to send previous state so as to force notification
#      (performance data would be same as original until non-OK HARD state)
#   6. [1.3  - Apr 2007] Reworked reporting of physical id to report it as 
#      "control/channel/id" when more than one controller is present or as
#      "channnel/id" when one controller and more than one channel
#      Also for persnmp5 if you have multiple luns (which should not happen
#      with disk drives) it will in theory add lun# as ".lun" to physical id
#   7. [1.35 - Apr 2007] Changed reporting of 'medium' and 'other' errors as
#      WARNING. Changed output system so that old performance data is
#      reported even for UNKNOWN
#   8. [1.4  - Apr 2007] Added specifying SNMP version and changed default
#      to v1 because as I found out this actually gets executed faster.
#      Also added capability to profile time it takes for this plugin
#      to execute with "--debug_time" option
#   9. [1.45 - May 2007] Modifications to output +num of physical or logical
#      drive errors when they happen instead of total number of errors 
#      Also plugin now reports WARNING when array is degraded but one
#      of the disks is being rebuilt
#      [1.46 - Jun 2007] Minor bug fixes
#   10. [1.5 - Oct 2007] Additional command-line option added to enable
#      extra drive error checks I've written (see above) i.e.
#      you now have to pass on "-e" option to enable checks for
#      medium & other errors. In reality this was already done as option
#      before as you had to pass on "-P" with old performance data to
#      make use of it, but now it also has to be specifically enabled
#      with '-e' or '--drive_errors" option.
#      Also new option '-i' ('--extra_info') which adds more information 
#      in plugin output. For 1.5 this is drive rebuilt rate info.
#   11. [1.6 - Oct 2007] Additional option '-o' ('--snmp_optimize') to minimize
#      number of SNMP queries when extra data is needed. When this is given
#      only one extra query is made for specific OIDs that are needed
#      instead of multiple SNMP table walks. Note that despite this type
#      of optimization working very well for number of my other plugins,
#      it is not clear if it is actually better with percsnmp or not. Use
#      this at your own risk and do some trials with '--debug_time' option
#      to see if it is better for you.
#   12. [1.7 - Nov 2007] Some code cleanup and addition of -O to set base oid.
#      The only reason you might want this is if you modified /etc/snmp/snmpd
#      to have line other then "pass .1.3.6.1.4.1.3582 /usr/sbin/percmain".
#      And the only reason to do such modificatins is if you have both
#      PERC3/4 SCSI Megaraid card(s) and PERC5 SAS card which use sassnmp
#      driver by LSI (by default that will also try to use 1.3.6.1.4.1.3582).
#   13. [1.72 - Nov 2007] Changing of megaraid OIDs to SASRAID. This is mostly
#      quick hack as in the near future I plan to merge both check_megaraid
#      and check_sasraid back into one plugin with -T option specifying
#      what type of card you want to check 
#   14. [1.75 - Dec 2007] Code fixes and merger of check_megaraid and
#      check_sasraid plugins.Type -T option added to specify card type.
#   15. [1.8 - Nov 2010, release Dec 15, 2010] patch by Vitaly Pecharsky:
#      Added support for mptsas devices, such as Dell SAS6i/R and other
#      similar LSI Logic / Symbios Logic SAS1068E PCI-Express Fusion-MPT SAS
#      (and possibly other). Use -T mptfusion|sas6|sas6ir switches for 
#      these cards. Both arrays (logical + physical) and standalone
#      (unconfigured physical only) drive configurations are supported.
#      Added explicit support for PERC 6 and PERC H700 controllers,
#      which are already supporting through sasraid path.
#   16. [1.901 - Dec 25, 2011] Support for SNMP v3. 
#      Bunch of new options added to support SNMP v3.
#      There is also an incompatible change in that default community is no longer
#      'public' - you must now specify community if you use snmp v1 or v2
#      This is all for better security for those few who do use this plugin.
#   17. [1.902 - Jan 12, 2012] Minor fixes mostly in documentation.
#   18. [1.91 - Feb 8, 2012] More bug fixes with 1.9 release (forgot to include verb() function)
#   19. [1.92 - Jun 15, 2012] Bug fixed when no SNNP version was specified.
#      Verb function & option updated to allow debug info go to file specified
#      as a parameter to -v (now also called --debug) rather than just stdout.
#   20. [1.95 - Oct 22, 2012] New version. Patches and Additions that went here:
#        a. merged pool request from goochjj (John Gooch):
#           Added good_drives threshold check (new '-g' option) and info on
#           make and model of physical drives which is activated with "-i" option
#        b. applied patch from Robert Wikman (sent by email) that adds checks on status of
#           batteries (BBU data) enabled with a new -b (--check_battery) option
#        c. code cleanup and refactoring - functions moved to top and option variables renamed
#        d. list of contributors section added
#       [2.0 - Oct 2012] The version was originaly to be released as 1.95 but with two patches
#        and all the code cleanup, the number of changes is more than sub-minor and I released
#        it as 2.0. However I later downgraded it back to 1.95 because for 2.0 release the plugin
#        is being renamed as check_snmp_raid since it was possible to add support for Adaptec cards.
#   21. [2.1 - Nov 22, 2012] Plugin has been renamed check_snmp_raid. Essentially this is
#        first new 2.x release (see above on first released 2.0 being downgraded back to 1.95).
#        Release notes for this version:
#        a. Adding limited support for Adaptec RAID cards contributed by K Truong
#        b. Adding limited support for HP Smart Array RAID, also contributed by K Truong
#        c  Code updates to make it easier to support more cards and vendors in the future
#        d. Making both PHYDRV_CODES and BATTERY_CODES array contain 3 parameters as has
#           been the case with LOGDRV_CODES. The first one is short code name,
#           2nd is human-readable text, and 3rd is nagios status it corresponds to.
#        e. Documentation updates related to plugin renaming and many other small
#           code updates
#        f. Starting with 2.x the plugin is licensed under GPL 3.0 licence (was 2.0 before)
#   22. [2.2 - Apr 25, 2013] The following are additions in this version:
#        a. Added limited support for ETI UtraStor ES1660SS (this was in dev from February)
#           Controller and volume checks are not written right now despite adding OIDs in.
#        b. Added support for battery status and drive vendor and model information for Adaptec cards,
#           this is contributed by Stanislav German-Evtushenko (giner on github)
#           based on http://www.circitor.fr/Mibs/Html/ADAPTEC-UNIVERSAL-STORAGE-MIB.php#BatteryStatus
#        c. Fix debugging. Old DEBUG printfs are replaced with calls to verb() function
#              
# ========================== LIST OF CONTRIBUTORS =============================
#
# The following individuals have contributed code, patches, bug fixes and ideas to
# this plugin (listed in last-name alphabetical order):
#
#    Michael Cook
#    Stanislav German-Evtushenko
#    Joe Gooch
#    William Leibzon
#    Vitaly Percharsky
#    John Reuning
#    Khanh Truong
#    Robert Wikman
#
# Open source community is grateful for all your contributions.
#
# ========================== START OF PROGRAM CODE ===========================

my $version = "2.2";

use strict;
use Getopt::Long;
use Time::HiRes qw(time);

our $no_snmp=0;
eval 'use Net::SNMP';
if ($@) {
  $no_snmp=1;
}

# Nagios specific
use lib "/usr/lib/nagios/plugins";
our $TIMEOUT;
our %ERRORS;
eval 'use utils qw(%ERRORS $TIMEOUT)';
if ($@) {
 $TIMEOUT = 20;
 %ERRORS = ('OK'=>0,'WARNING'=>1,'CRITICAL'=>2,'UNKNOWN'=>3,'DEPENDENT'=>4);
}

# some defaults, most can be overriden by input parameters too
my $cardtype="sasraid";    # default card type. Note: there will not be any default in future versions
my $baseoid="";            # if not specified here, it will use default ".1.3.6.1.4.1.3582"
my $timeout=$TIMEOUT;      # default is nagios exported $TIMEOUT variable
my $DEBUG = 0;             # to print debug messages, set this to 1
my $MAX_OUTPUTSTR = 2048;  # maximum number of characters in otput
my $alert = "CRITICAL";    # default alert type if error condition is found
my $label = "Raid";	    # Label to start output with

# SNMP authentication options and their derfault values
my $o_port=               161;  # SNMP port
my $o_community =       undef;  # community - this used to default to 'public' but no more
my $o_login=            undef;  # Login for snmpv3
my $o_passwd=           undef;  # Pass for snmpv3
my $v3protocols=        undef;  # V3 protocol list.
my $o_authproto=        'md5';  # Auth protocol
my $o_privproto=        'des';  # Priv protocol
my $o_privpass=         undef;  # priv password
my $opt_snmpversion=    undef;  # SNMP version option, default "1" when undef
my $opt_baseoid=        undef;  # allows to override default $baseoid above

########## CORE PLUGIN CODE (do not change below this line) ##################

# Other option variables
my $o_host =            undef;  # hostname
my $o_timeout=          undef;  # Timeout (Default 20 or what is set in utils.pm, see above) 
my $o_help=             undef;  # wan't some help ?
my $o_version=          undef;  # print version
my $opt_cardtype=       undef;  # option to sets card type i.e. 'sasraid' or 'megaraid', or 'mptfusion' or 'perc3', 'perc5' etc
my $opt_alert=          undef;  # what type of alert to issue
my $opt_debug=          undef;  # verbose mode/debug file name
my $opt_gooddrives=     undef;  # how many good drives should system have, less gives an alert
my $opt_perfdata=       undef;  # -P option to pass previous performance data (to determine if new drive failed)
my $opt_prevstate=      undef;  # -S option to pass previous state (to determine if new drive failed)
my $opt_debugtime=      undef;  # used with -P and enabled comparison of how long ops take every time, not for normal operation
my $opt_drverrors=      undef;  # -e option. megarad only. checks for new medium and other errors, requires previous perf data
my $opt_optimize=       undef;  # -o experimental option to optimize SNMP queries for faster performance
my $opt_extrainfo=      undef;  # -i option that gives more info on drives and their state at the expense of more queries
my $opt_battery=        undef;  # -b option to check if RAID card batteries (BBU) are working
my $opt_label=		 undef;  # text to start plugin output with which overrides default "Raid"

# Other global variables
my $nagios_status=       "OK";  # nagios return status code, starts with "OK"
my $error=                 "";  # string that gets set if error is found
my %curr_perf=             ();  # performance vars
my %prev_perf=             ();  # previous performance data feed to plugin with -P
my @prev_state=            ();  # state based on above
my %debug_time=            ();  # for debugging of how long execution takes
my $session=            undef;  # SNMP session

# Mapping of multipe acceptable names for cards that people can specify with -T to single card type
my %cardtype_map = (
  'megaraid' => 'megaraid',
  'perc3' => 'megaraid',
  'perc4' => 'megaraid',
  'sasraid' => 'sasraid',
  'perc5' => 'sasraid',
  'perc6' => 'sasraid',
  'perch700' => 'sasraid',
  'mptfusion' => 'mptfusion',
  'sas6' => 'mptfusion',
  'sas6ir' => 'mptfusion',
  'adaptec' => 'adaptec',
  'hp' => 'hp',
  'smartarray' => 'hp',
  'ultrastor' => 'ultrastor',
  'eti' => 'ultrastor',
  'synology' => 'synology',
);

# These variables are set by set_oids() function based on cardtype
#   only $logdrv_status_tableoid, $phydrv_status_tableoid, %LOGDRV_CODES, %PHYDRV_CODES are required
#   rest are optional and may only appear for specific card type
my $logdrv_status_tableoid = undef;          # logical drives status. responses to that are in %LOGDRV_CODES tabbe
my $logdrv_task_status_tableoid = undef;     # logical drive task status info. only adaptec. responses in %LOGDRV_TASK_CODES
my $logdrv_task_completion_tableoid = undef; # logical drive task completion info. similar to rebuild rate for phydrv?
my $phydrv_status_tableoid = undef;          # physical drives status. responses to that are in %PHYDRV_CODES table
my $phydrv_mediumerrors_tableoid = undef;    # number of medium errors on physical drives. only old scsi megaraid
my $phydrv_othererrors_tableoid = undef;     # number of 'other' errors on physical drives. only old scsi megaraid
my $phydrv_vendor_tableoid = undef;          # drive vendor or drive type info on physical drives
my $phydrv_product_tableoid = undef;         # specific drive model or combined vendor+model on each physical drives
my $phydrv_rebuildstats_tableoid = undef;    # rebuild Task Stats. For when new drive is added to existing RAID array
my $phydrv_assignedname_tableoid = undef;    # TODO: name of the drive configured in the system
my $phydrv_temperature_tableoid = undef;     # TODO: drives temperature
my $phydrv_count_oid = undef;                # used only by sasraid to verify number of drives in the system. not a table
my $phydrv_goodcount_oid = undef;            # only sasraid. number of good drives in the system. not a table
my $phydrv_badcount_oid = undef;             # only sasraid. number of bad drives in the system. not a table
my $phydrv_bad2count_oid = undef;            # only sasraid. number of bad drives in the system. not a table
my $sys_temperature_oid = undef;	      # TODO: controller/system temperature
my $readfail_oid = undef;                    # number of read fails. only old megaraid. not a table
my $writefail_oid = undef;                   # number of write fails. only old megaraid. not a table
my $adpt_readfail_oid = undef;	              # number of read fails. only megaraid. not sure of the difference from above any more
my $adpt_writefail_oid = undef;              # number of write fails. only megaraid. not sure of the difference from above
my $battery_status_tableoid = undef;	      # table to check batteries and their status
my %controller_status_oids = ();             # set of additional tables to check that report controller operating status
my %controller_status_codes = ();            # set of responses for above additional status tables (must be same for all tables)
my %LOGDRV_CODES = ();                       # Logical Drive Status responses and corresponding description and Nagios exit code
my %LOGDRV_TASK_CODES = ();	              # Logical Drive Task Status responses and corresponding Nagios exit code
my %PHYDRV_CODES = ();                       # Physical Drives Status responses and corresponding descriptions and Nagios exit code
my %BATTERY_CODES = ();		              # Raid Controller Battery status responses and corresponding Nagios exit codes

# Function to set values for OIDs that are used
sub set_oids {
  if ($cardtype eq 'megaraid') {
    $baseoid = "1.3.6.1.4.1.3582" if $baseoid eq "";             # megaraid standard base oid
    $logdrv_status_tableoid = $baseoid . ".1.1.2.1.3";           # megaraid logical
    $phydrv_status_tableoid = $baseoid . ".1.1.3.1.4";           # megaraid physical
    $phydrv_mediumerrors_tableoid = $baseoid . ".1.1.3.1.12";    # megaraid medium errors
    $phydrv_othererrors_tableoid = $baseoid . ".1.1.3.1.15";     # megaraid other errors
    $phydrv_rebuildstats_tableoid = $baseoid . ".1.1.3.1.11";
    $phydrv_product_tableoid = $baseoid . ".1.1.3.1.8";          # megaraid drive vendor+model
    $readfail_oid = $baseoid . ".1.1.1.1.13";
    $writefail_oid = $baseoid . ".1.1.1.1.14";
    $adpt_readfail_oid = $baseoid . ".1.1.1.1.15";
    $adpt_writefail_oid = $baseoid . ".1.1.1.1.16";
    ## Status codes for logical drives
    #  1st column has special meaning: 
    #   'optimal' is for OK status,
    #   'degraded' if it is CRITICAL is forced to WARNING if drive is being rebuild and has WARNING state
    #   'initialize' & checkconsistency are just regular WARNING and no longer have special meaning
    %LOGDRV_CODES = (
        0 => ['offline', 'drive is offline', 'NONE' ],
        1 => ['degraded', 'array is degraded', 'CRITICAL' ],
        2 => ['optimal', 'functioning properly', 'OK' ],
        3 => ['initialize', 'currently initializing', 'WARNING' ],
        4 => ['checkconsistency', 'array is being checked', 'WARNING' ],
    );
    ## Status codes for physical drives
    %PHYDRV_CODES = (
        1 => ['ready', 'ready', 'OK'],
        3 => ['online', 'online', 'OK'],
        4 => ['failed', 'failed', 'CRITICAL'],
        5 => ['rebuild', 'reuild', 'WARNING'],
        6 => ['hotspare', 'hotspare', 'OK'],
        20 => ['nondisk', 'nondisk', 'OK'],
    );
  }
  elsif ($cardtype eq 'mptfusion') { 
    $baseoid = "1.3.6.1.4.1.3582" if $baseoid eq "";               # megaraid standard base oid
    $logdrv_status_tableoid = $baseoid . ".5.1.4.3.1.2.1.5";       # mptfusion logical
    $phydrv_status_tableoid = $baseoid . ".5.1.4.2.1.2.1.10";      # mptfusion physical
    $phydrv_mediumerrors_tableoid = $baseoid . ".5.1.4.2.1.2.1.7"; # mptfusion medium errors
    $phydrv_othererrors_tableoid = $baseoid . ".5.1.4.2.1.2.1.8";  # mptfusion other errors
    $phydrv_vendor_tableoid = $baseoid . ".5.1.4.2.1.2.1.24";      # mptfusion drive vendor (this needs to be verified)
    $phydrv_product_tableoid = $baseoid . ".5.1.4.2.1.2.1.25";     # mptfusion drive model (this needs to be verified)
    ## Status codes for logical drives
    #  1st column has special meaning: 
    #   'optimal' is for OK status,
    #   'degraded' if it is CRITICAL is forced to WARNING if drive is being rebuild and has WARNING state
    #   'initialize' & checkconsistency are just regular WARNING and no longer have special meaning
    %LOGDRV_CODES = (
        0 => ['offline', 'volume is offline', 'NONE' ],
        1 => ['degraded', 'parially degraded', 'CRITICAL' ],
        2 => ['degraded', 'fully degraded', 'CRITICAL' ],
        3 => ['optimal', 'functioning properly', 'OK' ]
    );
    ## Status codes for physical drives - these are for MPTFUSION
    %PHYDRV_CODES = (
        0 => ['unconfigured_good', 'unconfigured_good', 'OK'],
        1 => ['unconfigured_bad', 'unconfigured_bad', 'CRITICAL'],
        2 => ['hotspare', 'hotspare', 'OK'],
        16 => ['offline', 'offline', 'OK'],
        17 => ['failed', 'failed', 'CRITICAL'],
        20 => ['rebuild', 'rebuild', 'WARNING'],
        24 => ['online', 'online', 'OK'],
    );
  }
  elsif ($cardtype eq 'sasraid') {
    $baseoid = "1.3.6.1.4.1.3582" if $baseoid eq "";               # megaraid standard base oid
    $logdrv_status_tableoid = $baseoid . ".4.1.4.3.1.2.1.5";       # sasraid logical
    # $sas_logdrv_name_tableoid = $baseoid . ".4.1.4.3.1.2.1.6";   # sas virtual device name
    $phydrv_status_tableoid = $baseoid . ".4.1.4.2.1.2.1.10";      # sasraid physical
    $phydrv_mediumerrors_tableoid = $baseoid . ".4.1.4.2.1.2.1.7"; # sasraid medium errors
    $phydrv_othererrors_tableoid = $baseoid . ".4.1.4.2.1.2.1.8";  # sasraid other errors
    $phydrv_vendor_tableoid = $baseoid . ".4.1.4.2.1.2.1.24";      # sasraid drive vendor
    $phydrv_product_tableoid = $baseoid . ".4.1.4.2.1.2.1.25";     # sasraid drive model
    $phydrv_count_oid = $baseoid . ".4.1.4.1.2.1.21";              # pdPresentCount
    $phydrv_goodcount_oid = $baseoid . ".4.1.4.1.2.1.22";          # pdDiskPresentCount
    $phydrv_badcount_oid = $baseoid . ".4.1.4.1.2.1.23";           # pdDiskPredFailureCount
    $phydrv_bad2count_oid = $baseoid . ".4.1.4.1.2.1.24";          # pdDiskFailureCount
    $battery_status_tableoid = $baseoid . ".4.1.4.1.6.2.1.27";     # battery replacement status
    ## Status codes for logical drives
    #  1st column has special meaning: 
    #   'optimal' is for OK status,
    #   'degraded' if it is CRITICAL is forced to WARNING if drive is being rebuild and has WARNING state
    #   'initialize' & checkconsistency are just regular WARNING and no longer have special meaning
    %LOGDRV_CODES = (
        0 => ['offline', 'volume is offline', 'NONE' ],
        1 => ['degraded', 'parially degraded', 'CRITICAL' ],
        2 => ['degraded', 'fully degraded', 'CRITICAL' ],
        3 => ['optimal', 'functioning properly', 'OK' ]
    );
    ## Status codes for physical drives - these are for SASRAID
    %PHYDRV_CODES = (
        0 => ['unconfigured_good', 'unconfigured_good', 'OK'],
        1 => ['unconfigured_bad', 'unconfigured_bad', 'CRITICAL'],
        2 => ['hotspare', 'hotspare', 'OK'],
        16 => ['offline', 'offline', 'OK'],
        17 => ['failed', 'failed', 'CRITICAL'],
        20 => ['rebuild', 'rebuild', 'WARNING'],
        24 => ['online', 'online', 'OK'],
    );
    ## Status codes for battery replacement - these are for SASRAID
    %BATTERY_CODES = (
        0 => ['ok', 'Battery OK', 'OK'],
        1 => ['fail', 'Battery needs replacement', 'WARNING']
    );
  }
  elsif ($cardtype eq 'adaptec') {
    $baseoid = "1.3.6.1.4.1.795" if $baseoid eq "";                      # Adaptec base oid
    $logdrv_status_tableoid = $baseoid . ".14.1.1000.1.1.12";            # adaptec logical drives status
    $logdrv_task_status_tableoid = $baseoid . ".14.1.1000.1.1.6";        # adaptec logical drive task status
    $logdrv_task_completion_tableoid = $baseoid . ".14.1.1000.1.1.7";    # adaptec logical drive task completion
    $phydrv_status_tableoid = $baseoid . ".14.1.400.1.1.11";             # adaptec physical drive status
    $battery_status_tableoid = $baseoid . ".14.1.201.1.1.14";            # adaptec battery status
    $phydrv_vendor_tableoid = $baseoid . ".14.1.400.1.1.6";              # adaptec drive vendor
    $phydrv_product_tableoid = $baseoid . ".14.1.400.1.1.7";             # adaptec drive model
    ## Status codes for logical drives
    #  1st column has special meaning: 
    #   'optimal' is for OK status,
    #   'degraded' if it is CRITICAL is forced to WARNING if drive is being rebuild and has WARNING state
    #   'initialize' & checkconsistency are just regular WARNING and no longer have special meaning
    %LOGDRV_CODES = (
        1 => ['unknown', 'array state is unknown', 'UNKNOWN'],
        2 => ['unknown', 'array state is other or unknown', 'UNKNOWN'],
        3 => ['optimal', 'array is funtioning properly', 'OK'],
        4 => ['optimal', 'array is funtioning properly', 'OK'],
        5 => ['degraded', 'array is impacted', 'CRITICAL'],
        6 => ['degraded', 'array is degraded', 'CRITICAL'],
        7 => ['failed', 'array failed', 'CRITICAL'],
        8 => ['compacted', 'array is compacted', 'UNKNOWN'],         # Does anybody know what "compacted" means?
    );
    ## Status codes for logical drives - these code are for ADAPTEC
    ## 1st and 3d columns are not used so far
    %LOGDRV_TASK_CODES = (
        1  => ['unknown', 'array task status is unknown', 'UNKNOWN'],
        2  => ['other', 'other', 'UNKNOWN'],
        3  => ['noTaskActive', 'noTaskActive', 'OK'],
        4  => ['reconstruct', 'reconstruct', 'WARNING'],
        5  => ['zeroInitialize', 'zeroInitialize', 'WARNING'],
        6  => ['verify', 'verify', 'WARNING'],
        7  => ['verifyWithFix', 'verifyWithFix', 'WARNING'],
        8  => ['modification', 'modification', 'WARNING'],
        9  => ['copyback', 'copyback', 'WARNING'],
        10 => ['compaction', 'compaction', 'WARNING'],
        11 => ['expansion', 'expansion', 'WARNING'],
        12 => ['snapshotBackup', 'snapshotBackup', 'WARNING'],
    );
    ## Status codes for physical drives
    %PHYDRV_CODES = (
        1 => ['unknown', 'unknown', 'WARNING'],
        2 => ['other', 'other', 'OK'],
        3 => ['okay', 'okay', 'OK'],
        4 => ['warning', 'warning', 'WARNING'],
        5 => ['failure', 'failure', 'CRITICAL'],
    );
    ## Status codes for batteries - these code are for ADAPTEC
    %BATTERY_CODES = (
        1 => ['unknown', 'unknown', 'UNKNOWN'],
        2 => ['other', 'other', 'WARNING'],
        3 => ['notApplicable', 'notApplicable', 'WARNING'],
        4 => ['notInstalled', 'notInstalled', 'WARNING'],
        5 => ['okay', 'Battery OK', 'OK'],
        6 => ['failed', 'failed', 'CRITICAL'],
        7 => ['charging', 'charging', 'WARNING'],
        8 => ['discharging', 'discharging', 'WARNING'],
        9 => ['inMaintenanceMode', 'inMaintenanceMode', 'WARNING']
    );
  }
  elsif ($cardtype eq 'smartarray') {
    $baseoid = "1.3.6.1.4.1.232" if $baseoid eq "";        # HP (SmartArray) base oid
    $logdrv_status_tableoid = $baseoid . ".3.2.3.1.1.4";
    $phydrv_status_tableoid = $baseoid . ".3.2.5.1.1.6";
    ## Status codes for logical drives
    #  1st column has special meaning: 
    #   'optimal' is for OK status,
    #   'degraded' if it is CRITICAL is forced to WARNING if drive is being rebuild and has WARNING state
    #   'initialize' & checkconsistency are just regular WARNING and no longer have special meaning
    %LOGDRV_CODES = (
        # as taken from CPQIDA-MIB
        # other(1),
        # ok(2),
        # failed(3),
        # unconfigured(4),
        # recovering(5),
        # readyForRebuild(6),
        # rebuilding(7),
        # wrongDrive(8),
        # badConnect(9),
        # overheating(10),
        # shutdown(11),
        # expanding(12),
        # notAvailable(13),
        # queuedForExpansion(14)
        1 => ['unknown', 'array state is unknown', 'UNKNOWN'],
        2 => ['optimal', 'array is functioning properly', 'OK'],
        3 => ['failed', 'array failed', 'CRITICAL'],
        4 => ['degraded', 'array is unconfigured', 'WARNING'],
        5 => ['degraded', 'array is recovering', 'WARNING'],
        6 => ['degraded', 'array is ready for rebuild', 'WARNING'],
        7 => ['degraded', 'array is rebuilding', 'WARNING'],
        8 => ['degraded', 'array wrong drive', 'CRITICAL'],
        9 => ['degraded', 'array bad connect', 'CRITICAL'],
        10 => ['degraded', 'array is overheating', 'CRITICAL'],
        11 => ['degraded', 'array is shutdown', 'CRITICAL'],
        12 => ['degraded', 'array is expanding', 'WARNING'],
        13 => ['unknown', 'array not available', 'CRITICAL'],
        14 => ['degraded', 'array queued for expansion', 'WARNING'],
    );   
    ## Status codes for physical drives
    %PHYDRV_CODES = (
        1 => ['other', 'other unknown error', 'UNKNOWN'],   # maybe this should be critical in nagios?
        2 => ['okay', 'okay', 'OK'],
        3 => ['failure', 'failure', 'CRITICAL'], 
        4 => ['warning', 'warning on predictive failure', 'WARNING'],  # predictive failure
    );
  }
  elsif ($cardtype eq 'ultrastor') {
    $baseoid = "1.3.6.1.4.1.22274" if $baseoid eq "";       # ETI base oid
    $logdrv_status_tableoid = $baseoid . ".1.2.3.1.6";      # logical volume status
    # $voldrv_status_tableoid = $baseoid . ".1.2.2.1.6";    # ETI volume status (NOT SUPPORTED YET)
    $phydrv_status_tableoid = $baseoid . ".1.2.1.1.5";      # physical status
    $phydrv_vendor_tableoid = $baseoid . ".1.2.1.1.8";      # drive vendor
    $phydrv_product_tableoid = $baseoid . ".1.2.1.1.15";    # drive model
    ## Status codes for logical drives
    #  1st column has special meaning: 
    #   'optimal' is for OK status,
    #   'degraded' if it is CRITICAL is forced to WARNING if drive is being rebuild and has WARNING state
    #   'initialize' & checkconsistency are just regular WARNING and no longer have special meaning
    %LOGDRV_CODES = ( # 1st column has special meaning when its 'optimal' and 'degraded'
        0 => ['offline', 'volume is offline', 'OK' ],
        1 => ['degraded', 'partially degraded', 'WARNING' ],
        2 => ['degraded', 'fully degraded', 'CRITICAL' ],
        3 => ['optimal', 'functioning properly', 'OK' ]
    );
    ## Status codes for physical drives
    %PHYDRV_CODES = (
        0 => ['unconfigured_good', 'unconfigured_good', 'OK'],
        1 => ['unconfigured_bad', 'unconfigured_bad', 'CRITICAL'],
        2 => ['hotspare', 'hotspare', 'OK'],
        16 => ['offline', 'offline', 'OK'],
        17 => ['failed', 'failed', 'CRITICAL'],
        20 => ['rebuild', 'rebuild', 'WARNING'],
        24 => ['online', 'online', 'OK'],
    );
    ## Controller Systems Status OIDs
    %controller_status_oids = (
       "generalstatus" => $baseoid . ".1.1.1",
       "temperature" => $baseoid . ".1.1.2",
       "voltage" => $baseoid . ".1.1.3",
       "ups" => $baseoid . ".1.1.4",
       "fan" => $baseoid . ".1.1.5",
       "powersupply" => $baseoid . ".1.1.6",
       "dualcontroller" => $baseoid . ".1.1.7",
    );
    ## Controller general status OID
    %controller_status_codes = (
        0 => ['good', 'ok', 'OK' ],
        1 => ['bad', 'bad', 'CRITICAL' ],
    );
  }
  elsif ($cardtype eq 'synology') {
    $baseoid = "1.3.6.1.4.1.6574" if $baseoid eq "";        # Synology base oid
    $logdrv_status_tableoid = $baseoid . ".3.3";            # logical volume status
    $phydrv_status_tableoid = $baseoid . ".2.5";            # physical status
    $phydrv_vendor_tableoid = $baseoid . ".2.4";            # not drive vendor, rather drive type (SATA,SSD)
    $phydrv_product_tableoid = $baseoid . ".2.5";           # drive model
    $phydrv_assignedname_tableoid = $baseoid . ".2.2";	      # name of the drive configured in the system (NOT SUPPORTED YET)
    $phydrv_temperature_tableoid = $baseoid . ".2.2";	      # drive temperature (NOT SUPPORTED YET)
    $sys_temperature_oid = $baseoid . ".1.2";               # system temperature (NOT SUPPORTED YET)
    ## Status codes for logical drives
    #  1st column has special meaning: 
    #   'optimal' is for OK status,
    #   'degraded' if it is CRITICAL is forced to WARNING if drive is being rebuild and has WARNING state
    #   'initialize' & checkconsistency are just regular WARNING and no longer have special meaning
    %LOGDRV_CODES = ( # 1st column has special meaning when its 'optimal' and 'degraded'
        1 => ['optimal', 'RAID is funtioning normally', 'OK' ],
        2 => ['degraded', 'RAID is being repaired', 'CRITICAL' ],
        3 => ['initialize', 'RAID is being migrated', 'WARNING' ],
        4 => ['initialize', 'RAID is being expanded', 'WARNING' ],
        5 => ['initialize', 'RAID is being deleted', 'WARNING' ],
        6 => ['initialize', 'RAID is being created', 'WARNING' ],
        7 => ['initialize', 'RAID is being synced', 'WARNING' ],
        8 => ['checkconsistency', 'parity checking of RAID array', 'OK' ],
        9 => ['initialize', 'RAID is being assembled', 'WARNING' ],
        10 => ['initialize', 'cancel operation', 'WARNING' ],  # unsure what to put here for 1st column
        11 => [ 'degraded', 'RAID array is degraded but failure is tolerable', 'WARNING' ],
        12 => [ 'failed', 'RAID array has crashed and now in read-only', 'CRITICAL' ],
   );
    ## Status codes for physical drives
    %PHYDRV_CODES = (
        1 => ['normal', 'disk is ok', 'OK'],
        2 => ['initialized', 'disk has partitions and no data', 'WARNING'],
        3 => ['notinitialized', 'disk has not been initialized', 'WARNING'],
        4 => ['partitionfailed', 'partitions on disk are damaged', 'CRITICAL'],
        5 => ['crashed', 'the disk ha failed', 'CRITICAL'],
    );
    ## Controller Systems Status OIDs
    %controller_status_oids = (
       "systemstatus" => $baseoid . ".1.1",
       "powersupply" => $baseoid . ".1.3",
       "systemfan" => $baseoid . ".1.4.1",
       "cpufan" => $baseoid . ".1.4.2",
    );
    ## Controller general status OID
    %controller_status_codes = (
        1 => ['good', 'ok', 'OK' ],
        2 => ['bad', 'bad', 'CRITICAL' ],
    );
  }
  else {
    usage("Specified card type $cardtype is not supported\n");
  }
}

# get descriptive text for type of error from config arrays
sub code_to_description {
    my($CODES, $code) = @_;
    my %CODES = %{$CODES};
    if (defined($CODES{$code})) {
        return $CODES{$code}[1];
    }
    else {
        return "unknown code $code";
    }
}

# get nagios status exit code for type of error from config arrays
sub code_to_nagiosstatus {
    my($CODES, $code, $current_status) = @_;
    my %CODES = %{$CODES};
    my $exit_code = "OK";
    if (defined($CODES{$code})) {
	$exit_code=$CODES{$code}[2];
    }
    else {
        $exit_code=$alert; # should this be $alert ?
    }
    $exit_code = $current_status if defined($current_status) && $ERRORS{$exit_code}<$ERRORS{$current_status};
    return $exit_code;
}

# verbose output for debugging (updated 06/06/12 to write to debug file if specified)
sub verb {
    my $t=shift;
    if ($DEBUG) {
        if ($opt_debug eq "") {
                print $t, "\n";
        }
        else {
            if (!open (DEBUGFILE, ">>$opt_debug")) {
                print $t, "\n";
            }
            else {
                print DEBUGFILE $t,"\n";
                close DEBUGFILE;
            }
        }
    }
}

# version flag function
sub print_version {
        print "$0 version $version\n";
}

# display usage information
sub print_usage {
        print "Usage:\n";
        print "$0 [-s <snmp_version>] -H <host> (-C <snmp_community>) | (-l login -x passwd [-X pass -L <authp>,<privp>) [-p <port>] [-t <timeout>] [-O <base oid>] [-a <alert level>] [--extra_info] [--check_battery] [-g <num good drives>] [--drive_errors -P <previous performance data> -S <previous state>] [-v [DebugLogFile] || -d DebugLogFile] [--debug_time] [--snmp_optimize] -T megaraid|sasraid|perc3|perc4|perc5|perc6|mptfusion|sas6ir|sas6|adaptec|smartarray|eti|ultrastor\n OR \n";
        print "$0 --version | $0 --help (use this to see get more detailed documentation of above options)\n";
}

sub usage {
        print $_."\n" foreach @_;
        print_usage();
        exit $ERRORS{'UNKNOWN'};
}

# display help information
sub help {
        print_version();
        print "GPL 3.0 license (c) 2006-2012 William Leibzon\n";
        print "This plugin uses SNMP to check state of RAID controllers and attached drives.\n";
        print "Supported brands are: LSI, MPTFusion, Dell PERC, Adaptec, HP SmartArray and more.\n";
        print "\n";
        print_usage();
        print "\n";
        print "Options:\n";
        print "  -h, --help\n";
        print "    Display help\n";
        print "  -V, --version\n";
        print "    Display version\n";
        print "  -T, --controller_type <type>\n";
        print "    Type of controller, specify one of:\n";
        print "       megaraid|sasraid|perc3|perc4|perc5|perc6|perch700|mptfusion|sas6ir|sas6|adaptec|hp|smartarray|eti|ultrastor\n";
        print "       (megaraid=perc3,perc4; sasraid=perc5,perc6,perch700; mptfusion=sas6ir,sas6; smartarray=hp; eti=ultrastor)\n";
        print "           Note: currently 'sasraid' is default type if not specified as has been the case for 1.x versions\n";
        print "                 but this will be removed and specifying controller type will be required in the future\n"; 
        print "  -a, --alert <alert level>\n";
        print "    Alert status to use if an error condition is found\n";
        print "    Accepted values are: \"crit\" and \"warn\" (defaults to crit)\n";
        print "  -b, --check_battery\n";
        print "    Check and output information on hard drive batteries (BBU) for supported cards\n";
        print "    'sasraid' and 'adaptec' card types are currently supported, more maybe added later\n"; 
        print "  -i, --extra_info\n";
        print "    Extra information in output. This may include rebuild rate, product & drive vendor names, etc\n";
        print "  -g, --good_drive <number>\n";
        print "    How many good drives should the system have. If its less than this, error alert is issued\n";
        print "  -e, --drive_errors\n";
        print "    Do additonal checks for medium and other errors on each drive (only megaraid cards).\n";
        print "    This is about 2x as many SNMP check and so can slow plugin down.\n";
        print "    !! You will need to pass to plugin previous PERF data and STATE with -P and -S options !!\n";
        print "  -P, --perf <performance data>\n";
        print '    The results of previous check performance data ($SERVICEPERFDATA$ macro)'."\n";
        print "    which contains number of medium and other errors that were before\n";
        print "    if this is not the same now then ALERT is sent\n";
        print "  -S, --state <STATE,STATETYPE>\n";
        print "    If you use -P and you have notifications sent to be sent at > 1 alerts\n";
        print "    then you need to send previous state and type (HARD or SOFT) and then\n";
        print "    this plugin would continue to report non-OK state until STATETYPE changes\n";
        print "    to HARD thereby making sure user receives NOTIFICATION\n";
        print "    Proper use of this is have '-S ".'"$SERVICESTATE$,$SERVICESTATETYPE$"'."' in your commands.cfg\n";
        print "\nSNMP Access Options:\n";
        print "  -H, --hostname <host>\n";
        print "    Hostname or IP address of target to check\n";
        print "  -O, --oid <base oid>\n";
        print "    Base OID for megaraid is .1.3.6.1.4.1.3582 and you almost never need to change it\n";
        print "    (the only case is when you might is when you have both percsnmp and sassnmp cards)\n";
        print "  -s, --snmp_version 1 | 2 | 2c | 3\n";
        print "    Version of SNMP protocol to use (default is 1 if -C and 3 if -l specified)\n";
        print "  -p, --port <port>\n";
        print "    SNMP port (defaults to 161)\n";
        print "  -C, --community <community>\n";
        print "    SNMP community string (for SNMP v1 and v2 only)\n";
        print "  -l, --login=LOGIN ; -x, --passwd=PASSWD\n";
        print "    Login and auth password for snmpv3 authentication\n";
        print "    If no priv password exists, implies AuthNoPriv\n";
        print "  -X, --privpass=PASSWD\n";
        print "    Priv password for snmpv3 (AuthPriv protocol)\n";
        print "  -L, --protocols=<authproto>,<privproto>\n";
        print "    <authproto> : Authentication protocol (md5|sha : default md5)\n";
        print "    <privproto> : Priv protocols (des|aes : default des)\n";
        print "  -t, --timeout <timeout>\n";
        print "    Seconds before timing out (defaults to Nagios timeout value)\n";
        print "  -o, --snmp_optimize\n";
        print "    Try to minimize number of SNMP queries replacing snmp_walk with retrieval of OIDs at once\n";
        print "    !! EXPERIMENTAL, USE AT YOUR OWN RISK !!! Use --debug_time to check it is actually faster.\n";
        print "\nDebug Options:\n";
        print "  --debug[=FILENAME] || --verbose[=FILENAME]\n";
        print "    Enables verbose debug output printing exactly what data was retrieved from SNMP\n";
        print "    This is mainly for manual checks when testing this plugin on the console\n";
        print "    If filename is specified instead of STDOUT the debug data is written to that file\n";
        print "  --debug_time \n";
        print "    This must be used with '-P' option and measures on how long each SNMP operation takes\n";
        print "    The data is on this goes with 'performance' data so this can be seen in nagios\n";
        print "    (although I'd not expect it to be graphed, just look at it from nagios status cgi)\n";
        print "\n";
}

# process previous performance data
sub process_perf {
 my %pdh;
 foreach (split(' ',$_[0])) {
   if (/(.*)=(\d+)/) {
        verb("prev_perf: $1 = $2");
        $pdh{$1}=$2 if $1 !~ /^time_/;
   }
 }
 return %pdh;
}

# print output status and performance data and exit
sub print_and_exit {
   my ($out_status,$out_str)=@_;

   print "$label $out_status";

   # max number of characters is $MAX_OUTPUTSTR defined at the top, if its set it to undef this is not checked
   if (defined($out_str) && $out_str) {
        $out_str = substr($out_str,0,$MAX_OUTPUTSTR) if defined($MAX_OUTPUTSTR) && length($out_str) > $MAX_OUTPUTSTR;
        print " - $out_str";
   }

   if (defined($opt_perfdata)) {
        print " |";
        # below is done to force notification on alert condition when you have notifications after 2 or more alerts
        if (scalar(keys %curr_perf)!=0 && (!defined($opt_prevstate) || scalar(keys %prev_perf)==0 || (defined($prev_state[0]) && $prev_state[0] ne 'OK' && (!defined($prev_state[1]) || $prev_state[1] eq 'HARD')))) {
                print " ". $_  ."=". $curr_perf{$_} foreach keys %curr_perf;
        }
        else {
                print " ". $_  ."=". $prev_perf{$_} foreach keys %prev_perf;
                print " total_merr=".$curr_perf{'total_merr'} if defined($curr_perf{'total_merr'});
                print " total_merr=".$curr_perf{'total_oerr'} if defined($curr_perf{'total_oerr'});
        }
        if ($opt_debugtime) {
                print " time_".$_ ."=". $debug_time{$_} foreach keys %debug_time;
        }
   }
   print "\n";
   
   exit $ERRORS{$out_status};
}

# Function to parse command line arguments
sub check_options {
  Getopt::Long::Configure('bundling', 'no_ignore_case');
  GetOptions (
        'h'     => \$o_help,            'help'              => \$o_help,
        'V'     => \$o_version,         'version'           => \$o_version,
        't:s'   => \$o_timeout,         'timeout:s'         => \$o_timeout,
        'A:s'   => \$opt_label,         'label:s'           => \$opt_label,
        'O:s'   => \$opt_baseoid,       'oid:s'             => \$opt_baseoid,
        'a:s'   => \$opt_alert,         'alert:s'           => \$opt_alert,
        'v:s'   => \$opt_debug,         'verbose:s'         => \$opt_debug,
        'd:s'   => \$opt_debug,         'debug:s'           => \$opt_debug,
                                        'debug_time'        => \$opt_debugtime,
        'P:s'   => \$opt_perfdata,      'perf:s'            => \$opt_perfdata,
        'S:s'   => \$opt_prevstate,     'state:s'           => \$opt_prevstate,
        'e'     => \$opt_drverrors,     'drive_errors'      => \$opt_drverrors,
        'g:i'   => \$opt_gooddrives,    'good_drives'       => \$opt_gooddrives,
        'o'     => \$opt_optimize,      'snmp_optimize'     => \$opt_optimize,
        'i'     => \$opt_extrainfo,     'extra_info'        => \$opt_extrainfo,
        'b'     => \$opt_battery,       'check_battery'     => \$opt_battery,
        'T:s'   => \$opt_cardtype,      'controller_type:s' => \$opt_cardtype,
        'C:s'   => \$o_community,       'community:s'       => \$o_community,
        's:s'   => \$opt_snmpversion,   'snmp_version:s'    => \$opt_snmpversion,
        'H:s'   => \$o_host,            'hostname:s'        => \$o_host,
        'p:i'   => \$o_port,            'port:i'            => \$o_port,
        'l:s'   => \$o_login,           'login:s'           => \$o_login,
        'x:s'   => \$o_passwd,          'passwd:s'          => \$o_passwd,
        'X:s'   => \$o_privpass,        'privpass:s'        => \$o_privpass,
        'L:s'   => \$v3protocols,       'protocols:s'       => \$v3protocols
  );

  if (defined($o_help)) { help(); exit $ERRORS{"UNKNOWN"}; };
  if (defined($o_version)) { print_version(); exit $ERRORS{"UNKNOWN"}; };

  # hostname
  if (defined($o_host) && $o_host) {
          if ($o_host =~ m/^([0-9]+\.[0-9]+\.[0-9]+\.[0-9]+|[a-zA-Z][-a-zA-Z0-9]*(\.[a-zA-Z][-a-zA-Z0-9]*)*)$/) {
            $o_host = $1;
        }
        else {
            usage("Invalid hostname: $o_host\n");
        }
  }
  else {
     usage("Hostname or IP address not specified\n");
  }

  if ($no_snmp) {
     print "Can't locate Net/SNMP.pm\n"; exit $ERRORS{"UNKNOWN"};
  }

  # snmp version parameter, default auto-detect with version 1 if community is specified
  if (!defined($opt_snmpversion)) {
        if (defined($o_community) && !defined($o_login) && !defined($o_passwd)) {
                $opt_snmpversion = '1';
        }
        elsif (!defined($o_community) && defined($o_login) && defined($o_passwd)) {
                $opt_snmpversion = '3';
        }
        else {
                usage("Can not autodetect SNMP version when -C and -l are both specified\n");
        }
  }
  if ($opt_snmpversion eq '2' || $opt_snmpversion eq '2c') {
        $opt_snmpversion='2';
  }
  elsif ($opt_snmpversion ne '1' && $opt_snmpversion ne '3') {
        usage("Invalid or unsupported value ($opt_snmpversion) for SNMP version\n");
  }
  if (defined($o_login) || defined($o_passwd)) {
        if (defined($o_community)) { usage("Can't mix snmp v1,2c,3 protocols!\n"); }
        if ($opt_snmpversion ne '3') { usage("Incorrect snmp version specified!\n"); }
  }
  if (defined($o_community)) {
        if ($opt_snmpversion eq '3') { usage("SNMP version 3 does not use community\n"); }
  }
  if (defined ($v3protocols)) {
        if (!defined($o_login)) { usage("Put snmp V3 login info with protocols!\n"); }
        my @v3proto=split(/,/,$v3protocols);
        if ((defined ($v3proto[0])) && ($v3proto[0] ne "")) { $o_authproto=$v3proto[0]; } 
        if (defined ($v3proto[1])) {$o_privproto=$v3proto[1];}   # Priv  protocol
        if ((defined ($v3proto[1])) && (!defined($o_privpass)))
          { usage("Put snmp V3 priv login info with priv protocols!\n"); }
  }

  # -T card type parameter. cardtype is thereafter used in set_oids()
  if (defined($opt_cardtype)) {
     if (exists($cardtype_map{$opt_cardtype})) {
        $cardtype=$cardtype_map{$opt_cardtype};
     }
     else {
        usage("Invalid controller type specified: $opt_cardtype");
     }
  }
  # if baseoid is specified as a parameter, set it first. otherwise its set by set_oids
  $baseoid = $opt_baseoid if $opt_baseoid;
  # set baseoid and and all other oids for plugin execution
  set_oids();

  # timeout - defaults to nagios timeout
  if ($o_timeout) {
          ($o_timeout =~ m/^[0-9]+$/) || usage("Invalid timeout value: $o_timeout\n");
          $timeout = $o_timeout;
  }

  # set alert if not specified, default "CRITICAL" is used
  if (defined($opt_alert) && $opt_alert) {
        if (lc $opt_alert =~ /warn/) {
            $alert = "WARNING";
        } elsif (lc $opt_alert =~ /crit/) {
            $alert = "CRITICAL";
        } else {
            usage("Invalid alert: $opt_alert\n");
        }
  }

  # set label
  $label = $opt_label if defined($opt_label) && $opt_label;
  
  # previos performance data string and previous state
  %prev_perf=process_perf($opt_perfdata) if $opt_perfdata;
  @prev_state=split(',',$opt_prevstate) if $opt_prevstate;

  $DEBUG=1 if defined($opt_debug);
  $debug_time{plugin_start}=time() if $opt_debugtime;
  if ($DEBUG) {
        verb("hostname: $o_host");
        verb("community: $o_community") if defined($o_community);
        verb("port: $o_port");
        verb("timeout: $timeout");
        verb("alert: $alert");
        verb("prev_state: $opt_prevstate") if $opt_prevstate;
  }
}

# open snmp session and return handle to SNNP object
sub create_snmp_session {
  my ($session,$error);

  if ($opt_snmpversion eq '3') {
    # SNMPv3 login
    if (!defined ($o_privpass)) {
     verb("SNMPv3 AuthNoPriv login : $o_login, $o_authproto");
     ($session, $error) = Net::SNMP->session(
      -hostname         => $o_host,
      -version          => '3',
      -port             => $o_port,
      -username         => $o_login,
      -authpassword     => $o_passwd,
      -authprotocol     => $o_authproto,
      -timeout          => $timeout
     );
    } else {
     verb("SNMPv3 AuthPriv login : $o_login, $o_authproto, $o_privproto");
     ($session, $error) = Net::SNMP->session(
      -hostname         => $o_host,
      -version          => '3',
      -username         => $o_login,
      -port             => $o_port,
      -authpassword     => $o_passwd,
      -authprotocol     => $o_authproto,
      -privpassword     => $o_privpass,
      -privprotocol     => $o_privproto,
      -timeout          => $timeout
     );
    }
  }
  elsif ($opt_snmpversion eq '2') {
    # SNMPv2c Login
      verb("SNMP v2c login");
      ($session, $error) = Net::SNMP->session(
       -hostname  => $o_host,
       -version   => 2,
       -community => $o_community,
       -port      => $o_port,
       -timeout   => $timeout
      );
  } else {
    # SNMPV1 login
      verb("SNMP v1 login");
      ($session, $error) = Net::SNMP->session(
       -hostname  => $o_host,
       -community => $o_community,
       -port      => $o_port,
       -timeout   => $timeout
      );
  }
  if (!defined($session)) {
     printf("ERROR opening session: %s.\n", $error);
     exit $ERRORS{"UNKNOWN"};
  }

  return $session;
}

################## START OF THE MAIN CODE ##############################

check_options();

# set the timeout
$SIG{'ALRM'} = sub {
        $session->close if defined($session);
        print_and_exit("UNKNOWN","snmp query timed out");
};
alarm($timeout);

my $snmp_result = undef;
my ($logdrv_data_in, $logdrv_task_status_in, $logdrv_task_completion_in) = (undef,undef,undef);
my ($phydrv_data_in, $phydrv_merr_in, $phydrv_oerr_in) = (undef,undef,undef);
my ($phydrv_vendor_in, $phydrv_product_in, $battery_data_in) = (undef,undef,undef);

$session = create_snmp_session();

# fetch snmp data, first optional readfail & writefail values for megaraid and good/bad drives count for sasraid
if ($cardtype eq 'megaraid' && defined($opt_drverrors)) {
        $debug_time{snmpretrieve_readwritefailoids}=time() if $opt_debugtime;
        $snmp_result=$session->get_request(-Varbindlist => [ $readfail_oid, $writefail_oid, $adpt_readfail_oid, $adpt_writefail_oid ]);
        $debug_time{snmpretrieve_readwritefailoids}=time()-$debug_time{snmpretrieve_readwritefailoids} if $opt_debugtime;
        $error.="could not retrieve snmp data OIDs" if !$snmp_result;
}
if ($cardtype eq 'sasraid') {
        $debug_time{snmpretrieve_readwritefailoids}=time() if $opt_debugtime;
        $snmp_result=$session->get_request(-Varbindlist => [ $phydrv_count_oid, $phydrv_goodcount_oid, $phydrv_badcount_oid, $phydrv_bad2count_oid ]);
        $debug_time{snmpretrieve_readwritefailoids}=time()-$debug_time{snmpretrieve_readwritefailoids} if $opt_debugtime;
        $error.="could not retrieve snmp data OIDs" if !$snmp_result;
}

# check status of logical disk drive status - this applies to all card types
$debug_time{snmpgettable_logdrvstatus}=time() if $opt_debugtime;
$logdrv_data_in = $session->get_table(-baseoid => $logdrv_status_tableoid) if !$error;
$debug_time{snmpgettable_logdrvstatus}=time()-$debug_time{snmpgettable_logdrvstatus} if $opt_debugtime;

# allow this to not be found for mptfusion cards, as they may have drives which aren't part of any array
if ($cardtype ne 'mptfusion') {
        $error.= "could not retrieve logdrv_status snmp table $logdrv_status_tableoid" if !$logdrv_data_in && !$error;
}

# get physical disk drive status - all card types
$debug_time{snmpgettable_phydrvstatus}=time() if $opt_debugtime;
$phydrv_data_in = $session->get_table(-baseoid => $phydrv_status_tableoid) if !$error;
$debug_time{snmpgettable_phydrvstatus}=time()-$debug_time{snmpgettable_phydrvstatus} if $opt_debugtime;
$error.= "could not retrieve phydrv_status snmp table $phydrv_status_tableoid" if !$phydrv_data_in && !$error;

# get drive models (supported types when -i option is used)
if (defined($opt_extrainfo)) {
    if (defined($phydrv_product_tableoid) && $phydrv_product_tableoid) {
        $debug_time{snmpgettable_phydrvproduct}=time() if $opt_debugtime;
        $phydrv_product_in = $session->get_table(-baseoid => $phydrv_product_tableoid) if !$error;
        $debug_time{snmpgettable_phydrvproduct}=time()-$debug_time{snmpgettable_phydrvproduct} if $opt_debugtime;
        $error.= "could not retrieve phydrv_product snmp table $phydrv_product_tableoid" if !$phydrv_product_in && !$error;
    }
    if(defined($phydrv_vendor_tableoid) && $phydrv_vendor_tableoid) {
        $debug_time{snmpgettable_phydrvvendor}=time() if $opt_debugtime;
        $phydrv_vendor_in = $session->get_table(-baseoid => $phydrv_vendor_tableoid) if !$error;
        $debug_time{snmpgettable_phydrvvendor}=time()-$debug_time{snmpgettable_phydrvvendor} if $opt_debugtime;
        $error.= "could not retrieve phydrv_vendor snmp table $phydrv_vendor_tableoid" if !$phydrv_vendor_in && !$error;
    }
}

# logical drive task (adaptec card has this)
if (defined($opt_extrainfo)) {
    if (defined($logdrv_task_status_tableoid) && $logdrv_task_status_tableoid) {
        $debug_time{snmpgettable_logdrvtaskstatus}=time() if $opt_debugtime;
        $logdrv_task_status_in = $session->get_table(-baseoid => $logdrv_task_status_tableoid) if !$error;
        $debug_time{snmpgettable_logdrvtaskstatus}=time()-$debug_time{snmpgettable_logdrvtaskstatus} if $opt_debugtime;
        $error.= "could not retrieve logdrv_task_status snmp table $logdrv_task_status_tableoid" if !$logdrv_task_status_in && !$error;
    }
    if(defined($logdrv_task_completion_tableoid) && $logdrv_task_completion_tableoid) {
        $debug_time{snmpgettable_logdrvtaskcompletion}=time() if $opt_debugtime;
        $logdrv_task_completion_in = $session->get_table(-baseoid => $logdrv_task_completion_tableoid) if !$error;
        $debug_time{snmpgettable_logdrvtaskcompletion}=time()-$debug_time{snmpgettable_logdrvtaskcompletion} if $opt_debugtime;
        $error.= "could not retrieve logdrv_task_completion snmp table $logdrv_task_completion_tableoid" if !$logdrv_task_completion_in && !$error;
    }
}

# battery checks (only for sasraid and adaptec right now)
if (defined($opt_battery) && defined($battery_status_tableoid) && $battery_status_tableoid) {
        $debug_time{snmpgettable_batterystatus}=time() if $opt_debugtime;
        $battery_data_in = $session->get_table(-baseoid => $battery_status_tableoid) if !$error;
        $debug_time{snmpgettable_batterystatus}=time()-$debug_time{snmpgettable_batterytatus} if $opt_debugtime;
        $error.= "could not retrieve snmp table $battery_status_tableoid" if !$battery_data_in && !$error;
}

# last are medium and "other" errors reported for physical drives (only old megaraid has this)
if (defined($opt_drverrors) && defined($opt_perfdata) && !defined($opt_optimize) &&
    (defined($phydrv_mediumerrors_tableoid) || defined($phydrv_othererrors_tableoid))) {
        if (defined($phydrv_mediumerrors_tableoid) && $phydrv_mediumerrors_tableoid) {
            $debug_time{snmpgettable_mederrors}=time() if $opt_debugtime;
            $phydrv_merr_in = $session->get_table(-baseoid=>$phydrv_mediumerrors_tableoid) if !$error;
            $debug_time{snmpgettable_mederrors}=time()-$debug_time{snmpgettable_mederrors} if $opt_debugtime;
            $error.= "could not retrieve snmp table $phydrv_mediumerrors_tableoid" if !$phydrv_merr_in && !$error;
        }
        if (defined($phydrv_othererrors_tableoid) && $phydrv_othererrors_tableoid) {
            $debug_time{snmpgettable_odrverrors}=time() if $opt_debugtime;
            $phydrv_oerr_in = $session->get_table(-baseoid=>$phydrv_othererrors_tableoid) if !$error;
            $debug_time{snmpgettable_odrverrors}=time()-$debug_time{snmpgettable_odrverrors} if $opt_debugtime;
            $error.= "could not retrieve snmp table $phydrv_othererrors_tableoid" if !$phydrv_oerr_in && !$error;
        }
}

if ($error) {
        verb("snmp error: ". $session->error());
        $session->close;
        print_and_exit("UNKNOWN",$error);
}

#--------------------------------------------------#
# parse the data and determine status

# set the initial output string and ok status
my $output_data = "";
my $output_data_end = "";

if ($DEBUG && $cardtype eq 'megaraid') {
        verb("adpt_readfail: ". $adpt_readfail_oid ." = ". $snmp_result->{$adpt_readfail_oid}) if exists($snmp_result->{$adpt_readfail_oid});
        verb("adpt_writefail: ". $adpt_writefail_oid ." = ". $snmp_result->{$adpt_writefail_oid}) if exists($snmp_result->{$adpt_writefail_oid});
        verb("readfail_sec: ". $readfail_oid ." = ". $snmp_result->{$readfail_oid}) if exists($snmp_result->{$readfail_oid});
        verb("writefail_sec: ". $writefail_oid ." = ". $snmp_result->{$writefail_oid}) if exists($snmp_result->{$writefail_oid});
}
if ($DEBUG && $cardtype eq 'sasraid') {
        verb("phydrv_count_oid: ".$phydrv_count_oid." = ". $snmp_result->{$phydrv_count_oid}) if exists($snmp_result->{$phydrv_count_oid});
        verb("phydrv_goodcount_oid: ".$phydrv_goodcount_oid." = ". $snmp_result->{$phydrv_goodcount_oid}) if exists($snmp_result->{$phydrv_goodcount_oid});
        verb("phydrv_badcount_oid: ".$phydrv_badcount_oid." = ". $snmp_result->{$phydrv_badcount_oid}) if exists($snmp_result->{$phydrv_badcount_oid});
        verb("phydrv_bad2count_oid: ".$phydrv_bad2count_oid." = ". $snmp_result->{$phydrv_bad2count_oid}) if exists($snmp_result->{$phydrv_bad2count_oid});
}
if (defined($opt_drverrors) && $cardtype eq 'megaraid') {
    if (exists($snmp_result->{$adpt_readfail_oid}) && $snmp_result->{$adpt_readfail_oid}>0) {
        $output_data.= ", " if $output_data;
        $output_data.=$snmp_result->{$adpt_readfail_oid}." adapter read failures";
        $nagios_status=$alert;
    }
    if (exists($snmp_result->{$adpt_writefail_oid}) && $snmp_result->{$adpt_writefail_oid}>0) {
        $output_data.= ", " if $output_data;
        $output_data.=$snmp_result->{$adpt_writefail_oid}." adapter write failures";
        $nagios_status=$alert;
    }
    if (exists($snmp_result->{$writefail_oid}) && $snmp_result->{$writefail_oid}>0) {
        $output_data.= ", " if $output_data;
        $output_data.=$snmp_result->{$writefail_oid}." write failures";
        $nagios_status=$alert;
    }
    if (exists($snmp_result->{$readfail_oid}) && $snmp_result->{$readfail_oid}>0) {
        $output_data.= ", " if $output_data;
        $output_data.=$snmp_result->{$readfail_oid}." read failures";
        $nagios_status=$alert;
    }
}
if ($cardtype eq 'sasraid') {
    if (exists($snmp_result->{$phydrv_count_oid}) && $snmp_result->{$phydrv_count_oid}>0) {
        my $total = $snmp_result->{$phydrv_count_oid};
        my $good = $snmp_result->{$phydrv_goodcount_oid}||0;
        my $bad = ($snmp_result->{$phydrv_badcount_oid}||0)+($snmp_result->{$phydrv_bad2count_oid}||0);
        verb("Good $good $bad $bad Total $total \n");
        if (defined($opt_gooddrives) and $opt_gooddrives>0) {
            $output_data.= ", " if $output_data;
            if ($good<$opt_gooddrives) {
                $output_data.= ", " if $output_data;
                $output_data.= "$good good drives (must have $opt_gooddrives)";
                $nagios_status = $alert;
            }  else {
                $output_data.= "$good good drives";
            }
        }
    }
}

my ($line, $code, $foo) = (undef,undef,undef);
my ($phydrv_id, $logdrv_id, $task_status, $battery_id, $controller_id, $channel_id, $drive_id, $lun_id) =
   (undef,undef,undef,undef,undef,undef,undef);
my %pdrv_status=();
my %h_controllers=();
my %h_channels=();
my @extra_oids=();
my $phy_skipids=0;
my $phydrv_total=0;

# first loop to load data (and find controller, channel, drive ids) for all drives into our hash
foreach $line (Net::SNMP::oid_lex_sort(keys(%{$phydrv_data_in}))) {
        $code = $phydrv_data_in->{$line};
        verb("phydrv_status: $line = $code");
        $line = substr($line,length($phydrv_status_tableoid)+1);
        ($controller_id,$channel_id,$drive_id,$lun_id) = split(/\./,$line,4);
        if (!$drive_id) {
                if (!$channel_id) {
                        $drive_id = $controller_id;
                        $controller_id = 0;
                        $channel_id = 0;
                }
                else {
                        $drive_id = $channel_id;
                        $channel_id = $controller_id;
                        $controller_id = 0;
                }
                # this is for SASRAID to skip first id if its non-disk
                # (I think they fixed this bug in newest release though)
                if ($cardtype eq 'sasraid' || $cardtype eq 'mptfusion') {
                    $phy_skipids++ if $code==0;
                    $drive_id-=$phy_skipids;
                }
        }
        $lun_id = 0 if !defined($lun_id);
        verb("| suffix = $line, controller = $controller_id, channel = $channel_id, drive = $drive_id, lun = $lun_id");
        $h_controllers{$controller_id}=1;
        $h_channels{$controller_id.'_'.$channel_id}=1;
        if (!$pdrv_status{$line}) {
                $pdrv_status{$line} = { 'status' => $code, 'controller' => $controller_id, 'channel' => $channel_id, 'drive' => $drive_id, 'lun' => $lun_id };
        }
        else {
                print_and_exit("UNKNOWN","processing error, physical drive $line found in SNMP result 2nd time");
        }
        # find which additional OIDs should be queried if snmp query optimization is enabled
        if (defined($opt_optimize)) {
           if (defined($opt_drverrors) && defined($opt_perfdata) &&
               defined($phydrv_mediumerrors_tableoid) && defined($phydrv_othererrors_tableoid)) {
                push @extra_oids, $phydrv_mediumerrors_tableoid.'.'.$line;
                push @extra_oids, $phydrv_othererrors_tableoid.'.'.$line;
           }
           if (defined($opt_extrainfo) && defined($phydrv_rebuildstats_tableoid)) {
                push @extra_oids, $phydrv_rebuildstats_tableoid.'.'.$line;
           }
        }
}

my $num_controllers = scalar(keys %h_controllers);
my $num_channels = scalar(keys %h_channels);

# this brings in the drive vendor/product information
my $models="";
if (defined($opt_extrainfo)) {
    foreach $line (Net::SNMP::oid_lex_sort(keys(%{$phydrv_product_in}))) {
        $code = $phydrv_product_in->{$line};
        verb("phydrv_product: $line = $code");
        my $index = substr($line,length($phydrv_product_tableoid)+1);
        my $vendor = $phydrv_vendor_tableoid?$phydrv_vendor_in->{$phydrv_vendor_tableoid.".".$index}:"";
        verb("phydrv_vendor: $line = $vendor") if $vendor;
        $vendor =~ s/^\s+|\s+$//g;
        $code =~ s/^\s+|\s+$//g;
        $pdrv_status{$index}->{drivetype} = ($vendor." "||"").$code;
        $models .= ", " if ($models);
        $models .= ($vendor." "||"").$code;
    }
}

# logical drive task information
my $logdrv_task_info="";
if (defined($opt_extrainfo)) {
    foreach $line (Net::SNMP::oid_lex_sort(keys(%{$logdrv_task_status_in}))) {
        $code = $logdrv_task_status_in->{$line};
        verb("logdrv_task_status: $line = $code");
        my $index = substr($line,length($logdrv_task_status_tableoid)+1);
        my $task_completion = $logdrv_task_completion_in->{$logdrv_task_completion_tableoid.".".$index};
        verb("logdrv_task_completion: $line = $task_completion") if ($task_completion);
        # Go next if no tasks running for the current logical drive
        next if ($task_completion == 100);
        $logdrv_task_info .= ", " if ($logdrv_task_info);
        $logdrv_task_info .= "LD $index - ".code_to_description(\%LOGDRV_TASK_CODES, $code)." - ".$task_completion."%";
    }
}

# additional controller status checks
foreach (keys %controller_status_oids) {
    push @extra_oids, $controller_status_oids{$_};
}

# now we can do additional SNMP queries
if (scalar(@extra_oids)>0) {
    $error="";
    $debug_time{snmpretrieve_extraoids}=time() if $opt_debugtime;
    $snmp_result=$session->get_request(-Varbindlist => \@extra_oids);
    $debug_time{snmpretrieve_extraoids}=time()-$debug_time{snmpretrieve_extraoids} if $opt_debugtime;
    if (!$snmp_result) {
        $error.=sprintf("could not retrieve extra data snmp OIDs: %s\n", $session->error());
        $session->close;
        print_and_exit('UNKNOWN',$error);
    }
    if (defined($opt_drverrors)) {
        $phydrv_merr_in = $snmp_result;
        $phydrv_oerr_in = $snmp_result;
    }
}

# additional controller status checks
my $controller_status_info="";
my $controller_nagios_status = $nagios_status;
if (scalar(keys %controller_status_oids)>0) {
    foreach $line (keys %controller_status_oids) {
        $code = $snmp_result->{$controller_status_oids{$line}};
        if (defined($code)) {
           verb("controller_status ($line): $controller_status_oids{$line} = $code");
           $controller_nagios_status = code_to_nagiosstatus(\%controller_status_codes, $code);
           $controller_status_info .= "$line is ".code_to_description(\%controller_status_codes, $code);
           if ($controller_nagios_status ne "OK") {
                $nagios_status = code_to_nagiosstatus(\%controller_status_codes, $code, $nagios_status);
                $output_data.= ", " if $output_data;
                $output_data .= "$line ".code_to_description(\%controller_status_codes, $code);
           }
        }
        else {
            $error.=sprintf("expected data for %s at oid %s but its not there\n",$line,$controller_status_oids{$line});
            $session->close;
            print_and_exit('UNKNOWN',$error);
        }
    }
}

# second loop as we now can find what physical id to use
my $phd_nagios_status = $nagios_status;
foreach $line (Net::SNMP::oid_lex_sort(keys(%{$phydrv_data_in}))) {
        $line = substr($line,length($phydrv_status_tableoid)+1);
        if ($num_controllers > 1) {
                $phydrv_id = $pdrv_status{$line}{controller}.'/'.$pdrv_status{$line}{channel}.'/'.$pdrv_status{$line}{drive};
        }
        elsif ($num_channels > 1) {
                $phydrv_id = $pdrv_status{$line}{channel}.'/'.$pdrv_status{$line}{drive};
        }
        else {
                $phydrv_id = $pdrv_status{$line}{drive};
        }
        $phydrv_id .= '.'.$pdrv_status{$line}{lun} if ($pdrv_status{$line}{lun} != 0);
        $pdrv_status{$line}{phydrv_id}=$phydrv_id;

        $code= $pdrv_status{$line}{status};
        # check status (catch if state is either "failed" (4) or "rebuild" (5))
        if (!defined($PHYDRV_CODES{$code})) {
                $output_data.=", " if $output_data;
                $output_data.= "phy drv($phydrv_id) unknown code $code";
                $nagios_status = $alert; # maybe this should not be an alert???
                $pdrv_status{$line}{'status_str'} = $code;
        }
        else {
                $pdrv_status{$line}{'status_str'} = $PHYDRV_CODES{$code}[1];
                if ($PHYDRV_CODES{$code}[2] ne 'OK') {
                # if ($PHYDRV_CODES{$code}[0] eq 'failed' || $PHYDRV_CODES{$code}[0] eq 'rebuild' || $PHYDRV_CODES{$code}[0] eq 'unconfigured_bad') {
                        $output_data .= ", " if $output_data;
                        $output_data .= "phy drv($phydrv_id) ".$PHYDRV_CODES{$code}[1];
                        $phd_nagios_status = $PHYDRV_CODES{$code}[2] if $phd_nagios_status ne 'CRITICAL';
                        # optionally check rate of rebuild
                        if ($PHYDRV_CODES{$code}[0] eq 'rebuild' && defined($opt_extrainfo) && 
                        defined($phydrv_rebuildstats_tableoid)) {
                                my $eoid = $phydrv_rebuildstats_tableoid.'.'.$line;
                                if (!defined($opt_optimize)) {
                                          $debug_time{'snmpretrieve_rebuild_'.$phydrv_id}=time() if $opt_debugtime;
                                          $snmp_result=$session->get_request(-Varbindlist => [ $eoid ]);
                                          $debug_time{'snmpretrieve_rebuild_'.$phydrv_id}=time()-$debug_time{'snmpretrieve_rebuild_'.$phydrv_id} if $opt_debugtime;
                                          if (!$snmp_result) {
                                                $error=sprintf("could not retrieve OID $eoid: %s\n", $session->error());
                                                $session->close;
                                                print_and_exit('UNKNOWN',$error);
                                          }
                                }
                                $output_data.= ' ('.$snmp_result->{$eoid}.')' if defined($snmp_result->{$eoid});
                        }
                }
                $phydrv_total++ if ($PHYDRV_CODES{$code}[0] ne 'nondisk' && ($cardtype ne 'sasraid' || $cardtype ne 'mptfusion' || $code>0));  # only count disks for output
        }
}

# check battery replacement status
if (defined($opt_battery)) {
    foreach $line (Net::SNMP::oid_lex_sort(keys(%{$battery_data_in}))) {
        $code = $battery_data_in->{$line};
        verb("battery_status: $line = $code");
        $line = substr($line,length($battery_status_tableoid)+1);
        ($foo,$battery_id) = split(/\./,$line,2);
        $battery_id=$foo if !$battery_id;
        verb("| battery_id = $battery_id");
        if (!defined($BATTERY_CODES{$code})) {
                $output_data.=", " if $output_data;
                $output_data.= "battery status($battery_id) unknown code $code";
                $nagios_status = $alert; # maybe this should not be an alert???
        }
        elsif ($BATTERY_CODES{$code}[2] ne 'OK') {
                $output_data.= ", " if $output_data;
                $output_data .= "battery status($battery_id) ".$BATTERY_CODES{$code}[1];
                $nagios_status = $BATTERY_CODES{$code}[2] if $nagios_status ne "CRITICAL";
        }
    }
}

# check logical drive status
foreach $line (Net::SNMP::oid_lex_sort(keys(%{$logdrv_data_in}))) {
        $code = $logdrv_data_in->{$line};
        verb("logdrv_status: $line = $code");
        $line = substr($line,length($logdrv_status_tableoid)+1);
        ($foo,$logdrv_id) = split(/\./,$line,2);
        $logdrv_id=$foo if !$logdrv_id;
        verb(" | logdrv_id = $logdrv_id\n");
        # check status (catch if status is not "optimal" (2))
        if (!defined($LOGDRV_CODES{$code})) {
                $output_data.=", " if $output_data;
                $output_data.= "log drv($logdrv_id) unknown code $code";
                $nagios_status = $alert; # maybe this should not be an alert???
        }
        elsif ($LOGDRV_CODES{$code}[0] ne 'optimal') {
                $output_data.= ", " if $output_data;
                $output_data .= "log drv($logdrv_id) ".$LOGDRV_CODES{$code}[0]." (".$LOGDRV_CODES{$code}[1].")";
                if ($LOGDRV_CODES{$code}[0] eq 'checkconsistency' || $LOGDRV_CODES{$code}[0] eq 'initialize') {
                        $nagios_status = "WARNING" if $nagios_status eq "OK";
                }
                else {
                        # below is to force WARNING in case when array is degraded but disk is already being rebuild
                        if ($LOGDRV_CODES{$code}[0] eq 'degraded' && $phd_nagios_status eq 'WARNING' && $nagios_status ne $alert) {
                                $nagios_status='WARNING';
                        }
                        else {
                                $nagios_status = $alert;
                        }
                }
        }
}

# physical drive errors
my $total_merr=0;
my $total_oerr=0;
my $nerr=0;
my $ndiff=0;

if (defined($opt_perfdata)) {
    foreach $line (keys %pdrv_status) {
        # first process medium errors
        if (defined($phydrv_mediumerrors_tableoid)) {
                $nerr = $phydrv_merr_in->{$phydrv_mediumerrors_tableoid.'.'.$line};
                verb("phydrv_mediumerr: $phydrv_mediumerrors_tableoid.$line = $nerr");
        }
        if ($pdrv_status{$line}{status_str} ne 'nondisk' && ($cardtype ne 'sasraid' || $cardtype ne 'mptfusion' ||     $pdrv_status{$line}{status}>0)) {
                verb(" | suffix = $line, phydrv_id = ".$pdrv_status{$line}{phydrv_id});
                $curr_perf{'merr_'.$line}=$nerr;
                if ($nerr!=0 && (!defined($prev_perf{'merr_'.$line}) || $prev_perf{'merr_'.$line} < $nerr)) {
                        $ndiff=$nerr;
                        $ndiff-=$prev_perf{'merr_'.$line} if defined($prev_perf{'merr_'.$line});
                        $output_data .= ", " if $output_data;
                        $output_data .= "phy drv(".$pdrv_status{$line}{phydrv_id}.") +$ndiff medium errors";
                        $phd_nagios_status = 'WARNING' if $phd_nagios_status eq 'OK';
                }
                if ($nerr!=0) {
                        $total_merr+=$nerr;
                        $output_data_end .= ", " if $output_data_end;
                        $output_data_end .= "phy drv(".$pdrv_status{$line}{phydrv_id}.") $nerr medium errors";
                }
        }
        # now process other errors 
        $nerr = 0;
        if (defined($phydrv_othererrors_tableoid)) {
                $nerr = $phydrv_oerr_in->{$phydrv_othererrors_tableoid.'.'.$line};
                verb("phydrv_othererr: $phydrv_othererrors_tableoid.$line = $nerr");
        }
        if ($pdrv_status{$line}{status_str} ne 'nondisk' && ($cardtype ne 'sasraid' ||$pdrv_status{$line}{status}>0)) {
                verb(" | suffix = $line, phydrv_id = ".$pdrv_status{$line}{phydrv_id});
                $curr_perf{'oerr_'.$line}=$nerr;
                if ($nerr!=0 && (!defined($prev_perf{'oerr_'.$line}) || $prev_perf{'oerr_'.$line} < $nerr)) {
                        $ndiff=$nerr;
                        $ndiff-=$prev_perf{'oerr_'.$line} if defined($prev_perf{'oerr_'.$line});
                        $output_data .= ", " if $output_data;
                        $output_data .= "phy drv(".$pdrv_status{$line}{phydrv_id}.") +$ndiff other errors";
                        $phd_nagios_status = 'WARNING' if $phd_nagios_status eq 'OK';
                }
                if ($nerr!=0) {
                        $total_oerr+=$nerr;
                        $output_data_end .= ", " if $output_data_end;
                        $output_data_end .= "phy drv(".$pdrv_status{$line}{phydrv_id}.") $nerr other errors";
                }
        }       
    }
    $curr_perf{'total_merr'}=$total_merr if defined($total_merr);
    $curr_perf{'total_oerr'}=$total_oerr if defined($total_oerr);
}

# close SNMP session (before it was done a lot earlier)
$session->close if !defined($opt_optimize);

$debug_time{plugin_finish}=time() if $opt_debugtime;
$debug_time{plugin_totaltime}=$debug_time{plugin_finish}-$debug_time{plugin_start} if $opt_debugtime;

# output text results
$output_data.= " - " if $output_data;
$output_data.= sprintf("%d logical disks, %d physical drives, %d controllers", scalar(keys %{$logdrv_data_in}), $phydrv_total, $num_controllers);
$output_data.= sprintf(", %d batteries", scalar(keys %{$battery_data_in})) if defined($opt_battery);
$output_data.= " found";
$output_data.= $controller_status_info if $controller_status_info;
$output_data.= ", tasks [".$logdrv_task_info."]" if defined($opt_extrainfo) && $logdrv_task_info;
$output_data.= ", models [".$models."]" if defined($opt_extrainfo);
$output_data.= " - ". $output_data_end if $output_data_end;

# combine status from checking physical and logical drives and print everything
$nagios_status = $phd_nagios_status if $ERRORS{$nagios_status}<$ERRORS{$phd_nagios_status};
print_and_exit($nagios_status,$output_data);
# should never reach here
exit $ERRORS{$nagios_status};

################## END OF MAIN CODE ######################################