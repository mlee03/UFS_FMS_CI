#!/bin/bash

#: relevant files 
ufs_hashfile=$PWD/"hashfiles/hashfile_ufs"  #: on Github cache
fms_hashfile=$PWD/"hashfiles/hashfile_fms"  #: on Github cache
nceplib_hashfile=$PWD/"LIB_HASHFILE"        #: in branch build_libs
logfile=$PWD/LOG


#: repositories
ufs_upstream='https://github.com/ufs-community/ufs-weather-model.git'
fms_upstream='https://github.com/NOAA-GFDL/FMS.git'


#: branches
ufs_branch="develop"  ; ufs_hashtag="refs/heads/$ufs_branch"
fms_branch="master"   ; fms_hashtag='HEAD'


#: nceplibs hash 
curr_ncep=$( grep -m 1 "NCEPLIBS" $nceplib_hashfile | awk '{print $3}' )


#: default build to be true  ;  force build set to false 
ufs_build='true'  ;  ufs_override='false'
fms_build='true'  ;  fms_override='false'


#: restart hashfiles
ufs_cleanhashfile='false'
fms_cleanhashfile='false'


#: number of hashes to check
fms_nhash=$3


#: remove existing hashfiles if cleanhasfile set to true
[ $ufs_cleanhashfile == 'true' ]  && rm $ufs_hashfile
[ $fms_cleanhashfile == 'true' ]  && rm $fms_hashfile

#: make hashfiles if they don't exist
[ ! -f $ufs_hashfile ]  && touch -a $ufs_hashfile
[ ! -f $fms_hashfile ]  && touch -a $fms_hashfile


#: need to push image to Docker Hub
docker_username=$1
docker_password=$2


#: ncep image has been pulled or not
ncep_dockerpulled='false'


#: get curr hashes
curr_ufs=$( git ls-remote  $ufs_upstream  | grep "$ufs_hashtag"  | awk '{print $1}' )
curr_fms=$( git ls-remote  $fms_upstream  | grep "$fms_hashtag"  | awk '{print $1}' )


#: echo to log
echo `date`                            > $logfile
echo "UFS  REPOSITORY $ufs_upstream"  >> $logfile
echo "FMS  REPOSITORY $fms_upstream"  >> $logfile
echo ''                               >> $logfile
echo "UFS  BRANCH $ufs_branch"        >> $logfile
echo "FMS  BRANCH $fms_branch"        >> $logfile
echo ''                               >> $logfile
echo "UFS  NEW HASH $curr_ufs"        >> $logfile
echo "FMS  NEW HASH $curr_fms"        >> $logfile
echo ''                               >> $logfile


#: build ufs if log cannot be found
if [ $( grep -c "PASSED $curr_ufs" $ufs_hashfile ) -ne 0 ] ; then
    ufs_build='false'
    echo "UFS $curr_ufs passed already" 
    echo "UFS $curr_ufs passed already" >> $logfile
fi

#: build fms if log cannot be found
if [ $( grep -c "PASSED $curr_fms" $fms_hashfile ) -ne 0 ] ; then
    fms_build='false'
    echo "FMS $curr_fms passed already"
    echo "FMS $curr_fms passed already" >> $logfile
fi    


#: override
[ $ufs_override == 'true' ]  && ufs_build='true'
[ $fms_override == 'true' ]  && fms_build='true'

    
#: compile UFS if UFS has been updated
if [ $ufs_build == 'true' ] ; then

    echo "**************************"
    echo "COMPILING UFS $curr_ufs"
    echo "**************************"

    if [ $ncep_dockerpulled == 'false' ] ; then
        docker pull mklee03/nceplibs:$curr_ncep
        ncep_dockerpulled='true'
    fi
    
    git clone --recursive --branch $ufs_branch $ufs_upstream
    cd ufs-weather-model && git checkout $curr_ufs
    sed -i "s/CHANGEME/$curr_ncep/" ../UFS_Dockerfile
    docker build -f ../UFS_Dockerfile -t ufs:$curr_ufs .

    if [ $? -ne 0 ] ; then
        echo -e "FAILED $curr_ufs `date`\n $(cat $ufs_hashfile)" > $ufs_hashfile
        echo "***********************************"
        echo "UFS FAILED UFS FAILED UFS FAILED"
        echo "***********************************"
        cat $logfile
        echo "(FAILED) COMMIT MESSAGE"
        git show -s $curr_ufs
        exit $?
    else
        echo -e "PASSED $curr_ufs `date`\n $(cat $ufs_hashfile)" > $ufs_hashfile
        echo "(PASSED) UFS COMMIT MESSAGE" >> $logfile
        git show -s $curr_ufs          >> $logfile
        echo "***********************" >> $logfile
    fi

    fms_build = 'true'
    
fi


if [ $fms_build == 'true' ] ; then

    echo "**************************"
    echo "COMPILING FMS"
    echo "**************************"

    #: get UFS if it hasn't been cloned already
    if [ $ufs_build == 'false' ] ; then
        git clone --recursive --branch $ufs_branch $ufs_upstream
        cd ufs-weather-model && git checkout $curr_ufs
        sed -i "s/CHANGEME/$curr_ncep/" ../UFS_Dockerfile
    fi

    #: pull nceplib image if it hasn't been pulled already
    if [ $ncep_dockerpulled == 'false' ] ; then
        docker pull mklee03/nceplibs:$curr_ncep
        ncep_dockerpulled='true'
    fi    

    #: get FMS latest commits
    cd FMS && git checkout $fms_branch
    git log --max-count=$fms_nhash --pretty=oneline > ../FMS_TMP
    cd ..
    
    for (( ihash=1 ; ihash<=$fms_nhash ; ihash++ )) ; do

        curr_fms=$( sed -n "${ihash}p" FMS_TMP | awk '{print $1}' )
        echo "*********************************"
        echo "$ihash $curr_fms"
        echo "*********************************"
        
        cd FMS && git checkout $curr_fms && cd ..

	      ncount=$( grep -c "PASSED $curr_fms" $fms_hashfile )
        [ $fms_build == 'true' ] && ncount=0

        if [ $ncount -eq 0 ] ; then
            docker build -f ../UFS_Dockerfile -t fms:$curr_fms .
            if [ $? -ne 0 ] ; then
                echo -e "FAILED $curr_fms `date`\n $(cat $fms_hashfile)" > $fms_hashfile
                echo "***********************************"
                echo "FMS FAILED FMS FAILED FMS FAILED"
                echo "***********************************"
                cat $logfile
                echo "(FAILED) COMMIT MESSAGE"
                git show -s $curr_fms
                exit $?
            else
                echo -e "PASSED $curr_fms `date`\n $(cat $fms_hashfile)" > $fms_hashfile
                echo "(PASSED) FMS COMMIT MESSAGE" >> $logfile
                cd FMS
                git show -s $curr_fms          >> $logfile
                echo "***********************" >> $logfile
                cd ../
            fi
        fi

    done

fi


cd ..


echo -e "**********************\n\n" >> $logfile
echo "UFS HASHFILE" >> $logfile
cat $ufs_hashfile >> $logfile

echo -e "**********************\n\n" >> $logfile
echo "FMS HASHFILE" >> $logfile
cat $fms_hashfile >> $logfile


