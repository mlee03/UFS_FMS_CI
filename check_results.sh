#!/bin/bash

#: directories
TESTDIR=CHANGEME_WORKDIR
BASELINE=CHANGEME_BASELINE
RESULTS=RESULTS

#: check for nccmp
if [ ! $(command -v nccmp) ] ; then
    echo "NCCMP not found"
    exit
fi

#: results output to $RESULTS
mkdir -p $RESULTS && cd $RESULTS


#: log
LOG=$PWD/RESULTS
touch -a $LOG  && echo `date`  > $LOG
echo "BASELINE: $BASELINE"    >> $LOG
echo "TESTDIR:  $TESTDIR"     >> $LOG


#: get fail_test in each directory
echo -e "\n************************" >> $LOG
echo "BASELINE fail_test" >> $LOG
[ -f $BASELINE/fail_test ] && cat $BASELINE/fail_test >> $LOG 
echo "TESTDIR fail_test" >> $LOG
[ -f $TESTDIR/fail_test ] &&  cat $TESTDIR/fail_test  >> $LOG
echo -e "************************\n" >> $LOG


#: change basleine and test directories
BASELINE=$BASELINE/log_orion.intel
TESTDIR=$TESTDIR/log_orion.intel


#: compare results
echo "NUMBER OF REGRESSION TESTS IN BASELINE" $(ls $BASELINE/rt*.log | grep -c ".log") >> $LOG
echo "NUMBER OF REGRESSION TESTS IN TESTDIR " $(ls $TESTDIR/rt*.log  | grep -c ".log") >> $LOG


for rtfile in $BASELINE/rt*.log ; do

    rtfile2=${rtfile#$BASELINE"/rt_0"[0-9][0-9]"_"}
    basedir2=$( grep "working dir" $BASELINE/rt*$rtfile2 | awk '{print $4}' )
    testdir2=$( grep "working dir" $TESTDIR/rt*$rtfile2  | awk '{print $4}' )

    output=NCCMP_$rtfile2 ; touch -a $output
    #: HISTORY
    for base_nc in $basedir2/*.nc ; do
	ncfile=${base_nc#$basedir2"/"}
	echo "***********************************************" >> $output
	echo $ncfile >> $output
	( nccmp -f -c 1 -d -m $basedir2/$ncfile $testdir2/$ncfile ) >> $output 2>&1
    done
    #: RESTART
    for base_nc in $basedir2/RESTART/*.nc ; do
	ncfile=${base_nc#$basedir2"/RESTART"}
	echo "***********************************************" >> $output
	echo "RESTART/"$ncfile >> $output
	( nccmp -f -c 1 -d -m $basedir2/$ncfile $testdir2/$ncfile ) >> $output 2>&1
    done

    sed -i "s:$basedir2:BASELINE:g" $output
    sed -i "s:$testdir2:TEST:g" $output
    
done    
    




