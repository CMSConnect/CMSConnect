#! /bin/tcsh


#set USAGE <<"EOF"
#\\t\\t\\t=================================================================================
#\\t\\t\\tUsage: source /etc/ciconnect/set_condor_sites.sh "<pattern>"
#\\t\\t\\tExamples:
#\\t\\t\\t- All Sites:       set_condor_sites "T*"
#\\t\\t\\t- T2 Sites:        set_condor_sites "T2_*"
#\\t\\t\\t- Tier US Sites:   set_condor_sites "T?_US_*"
#\\t\\t\\t=================================================================================\\n\\n
#EOF

if ( $#argv < 1 ) then
printf "\t\t\t=================================================================================\n"
printf "\t\t\tUsage: source /etc/ciconnect/set_condor_sites.csh \42<pattern>\42\n"
printf "\t\t\tExamples:\n"
printf "\t\t\t- All Sites:       set_condor_sites \42T*\42\n"
printf "\t\t\t- T2 Sites:        set_condor_sites \42T2_*\42\n"
printf "\t\t\t- Tier US Sites:   set_condor_sites \42T?_US_*\42\n"
printf "\t\t\t=================================================================================\n\n"
exit
endif

set list=`/usr/bin/get_condor_sites "$argv[*]"`
if ( $#argv == 0 ) then
    return 1
else
    setenv CONDOR_DEFAULT_DESIRED_SITES "$list"
endif

printf "\tAll Done\n"
printf "\tNote: To verify your list of sites, simply do:\n\n"
printf "\techo \44CONDOR_DEFAULT_DESIRED_SITES\n\n"
printf "\tNOTE: Remember that condor submission files with +DESIRED_Sites\n"
printf "\tNOTE: will give priority to that over \44CONDOR_DEFAULT_DESIRED_SITES\n\n"
printf "\t\44CONDOR_DEFAULT_DESIRED_SITES has been set to:\n\n"
printf "\t$CONDOR_DEFAULT_DESIRED_SITES\n"
