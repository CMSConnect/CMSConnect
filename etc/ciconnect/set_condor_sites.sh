#! /bin/bash


read -d '' USAGE <<"EOF"
\\t\\t\\t=================================================================================
\\t\\t\\tUsage: source /etc/ciconnect/set_condor_sites.sh "<pattern>"
\\t\\t\\tExamples:
\\t\\t\\t- All Sites:       set_condor_sites "T*"
\\t\\t\\t- T2 Sites:        set_condor_sites "T2_*"
\\t\\t\\t- Tier US Sites:   set_condor_sites "T?_US_*"
\\t\\t\\t=================================================================================\\n\\n
EOF

if [ "$0" = "$BASH_SOURCE" ]; then
    echo -e "\n[Error] You need to source this script, not execute it."
    echo -e "[Error] Please use \"source <script> <pattern>\" as pointed out below:"
    echo -e "$USAGE"
    exit
fi
if [ "$#" -lt 1 ]; then
    echo -e "$USAGE"
    return 1
fi

list=$(/usr/bin/get_condor_sites $@)
if [ $? != 0 ]; then
    return 1
else
    export CONDOR_DEFAULT_DESIRED_SITES="$list"
fi

echo -e "\\tAll Done"
echo -e "\\tNote: To verify your list of sites, simply do:\n"
echo -e "\\techo \$CONDOR_DEFAULT_DESIRED_SITES\n"
echo -e "\\tNOTE: Remember that condor submission files with +DESIRED_Sites"
echo -e "\\tNOTE: will give priority to that over \$CONDOR_DEFAULT_DESIRED_SITES\n"
echo -e "\\t\$CONDOR_DEFAULT_DESIRED_SITES has been set to:\n"
echo -e "\\t$CONDOR_DEFAULT_DESIRED_SITES\n"
