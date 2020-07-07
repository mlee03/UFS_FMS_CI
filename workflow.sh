#!/bin/bash

wfile=workflow_status/workflow_status


whereami=$1
work_id=$2


if [ $whereami == 'start' ] ; then
    
    if [ -f $wfile ] ; then
        cat $wfile
        job_status=$( awk '{print $2}' $wfile )
        if [ $job_status == 'RUNNING' ] ; then
            cat $wfile
            exit 1
        else
            rm -rf $wfile
            echo " $work_id RUNNING `date` " > $wfile            
        fi
    else
        mkdir -p workflow_status
        echo " $work_id RUNNING `date` " > $wfile
    fi
    cat $wfile

elif [ $whereami == 'failed' ] ; then

    rm -rf $wfile
    echo " $work_id DONE `date` " > $wfile


elif [ $whereami == 'end' ] ; then

    rm -rf $wfile
    echo " $work_id DONE `date` " > $wfile

fi
            
    
