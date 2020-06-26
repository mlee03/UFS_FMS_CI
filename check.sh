#!/bin/bash

#set -x

#: relevant files 
ncep_hashfile=$PWD/"hashfiles/hashfile_ncep"
ufs_hashfile=$PWD/"hashfiles/hashfile_ufs"
fms_hashfile=$PWD/"hashfiles/hashfile_fms"
logfile=$PWD/LOG


#: ncep external library version
external_v='ufs-v1.0.0'


#: repositories
ncep_upstream='https://github.com/NOAA-EMC/NCEPLIBS.git'
ufs_upstream='https://github.com/ufs-community/ufs-weather-model.git'
fms_upstream='https://github.com/NOAA-GFDL/FMS.git'


#: branches
ncep_branch="release/public-v1"  ; ncep_hashtag="refs/heads/$ncep_branch"
ufs_branch="develop"             ; ufs_hashtag="refs/heads/$ufs_branch"
fms_branch="master"              ; fms_hashtag='HEAD'


#: default build to be true
ncep_build='true'
ufs_build='true'
fms_build='true'


#: force build
ncep_override='false'
ufs_override='false'
fms_override='false'


#: restart hashfiles
ncep_cleanhashfile='false'
ufs_cleanhashfile='false'
fms_cleanhashfile='false'


#: number of hashes to check
fms_nhash=$3


#: make hashfiles if they don't exist
[ $ncep_cleanhashfile == 'true' ] && rm $ncep_hashfile
[ $ufs_cleanhashfile == 'true' ]  && rm $ufs_hashfile
[ $fms_cleanhashfile == 'true' ]  && rm $fms_hashfile

[ ! -f $ncep_hashfile ] && touch -a $ncep_hashfile
[ ! -f $ufs_hashfile ]  && touch -a $ufs_hashfile
[ ! -f $fms_hashfile ]  && touch -a $fms_hashfile


#: need to push image to Docker Hub
docker_username=$1
docker_password=$2


#: ncep image has been pulled or not
ncep_dockerpulled='false'


#: get curr hashes
curr_ncep=$( git ls-remote $ncep_upstream | grep "$ncep_hashtag" | awk '{print $1}' )
curr_ufs=$( git ls-remote  $ufs_upstream  | grep "$ufs_hashtag"  | awk '{print $1}' )
curr_fms=$( git ls-remote  $fms_upstream  | grep "$fms_hashtag"  | awk '{print $1}' )


#: echo to log
echo `date`                            > $logfile
echo "NCEP REPOSITORY $ncep_upstream" >> $logfile
echo "UFS  REPOSITORY $ufs_upstream"  >> $logfile
echo "FMS  REPOSITORY $fms_upstream"  >> $logfile
echo ''                               >> $logfile
echo "NCEP BRANCH $ncep_branch"       >> $logfile
echo "UFS  BRANCH $ufs_branch"        >> $logfile
echo "FMS  BRANCH $fms_branch"        >> $logfile
echo ''                               >> $logfile
echo "NCEP NEW HASH $curr_ncep"       >> $logfile
echo "UFS  NEW HASH $curr_ufs"        >> $logfile
echo "FMS  NEW HASH $curr_fms"        >> $logfile
echo ''                               >> $logfile


#: build ncep if image doesn't exist
if [ $( grep -c "PASSED $curr_ncep" $ncep_hashfile ) -ne 0 ] ; then
    ncep_build='false'
    echo "NCEP $curr_ncep passed already" 
    echo "NCEP $curr_ncep passed already" >> $logfile
    
fi

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
[ $ncep_override == 'true' ] && ncep_build='true'
[ $ufs_override == 'true' ]  && ufs_build='true'
[ $fms_override == 'true' ]  && fms_build='true'


#: build if set to true
if [ $ncep_build == 'true' ] ; then

    echo "**************************"
    echo "BUILDING NCEPLIBS:$curr_ncep DOCKER IMAGE"
    echo "**************************"
    
    docker pull mklee03/nceplibs:$curr_ncep
    if [ $? -eq 0 ] ; then        
        echo "NCEP $curr_ncep image exists"
        echo "NCEP $curr_ncep image exists" >> $logfile
        #: check record is updated
        echo -e "PASSED $curr_ncep `date`\n $(cat $ncep_hashfile)" > $ncep_hashfile
        ncep_dockerpulled='true'
    else
        git clone --recursive --branch $ncep_branch $ncep_upstream
        cd NCEPLIBS && git checkout $curr_ncep
        docker pull mklee03/external_libs:$external_v

        sed -i "s/CHANGEME/$external_v/" ../NCEP_Dockerfile
        docker build -f ../NCEP_Dockerfile -t nceplibs:$curr_ncep  .
        
        if [ $? -ne 0 ] ; then
            echo -e "FAILED $curr_ncep `date`\n $(cat $ncep_hashfile)" > $ncep_hashfile
            echo "***********************************"
            echo "NCEP FAILED NCEP FAILED NCEP FAILED"
            echo "***********************************"
            cat $logfile
            echo "(FAILED) COMMIT MESSAGE" 
            git show -s $curr_ncep
            exit $?
        else
            echo -e "PASSED $curr_ncep `date`\n $(cat $ncep_hashfile)" > $ncep_hashfile
            echo "(PASSED) NCEP COMMIT MESSAGE" >> $logfile
            git show -s $curr_ncep         >> $logfile
            echo "***********************" >> $logfile
        fi
        
        echo "$docker_password" | docker login -u $docker_username --password-stdin
        docker tag nceplibs:$curr_ncep mklee03/nceplibs:$curr_ncep
        docker push mklee03/nceplibs:$curr_ncep
        cd ../
        ufs_build=true        
    fi
fi    
    
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

    $fms_build = 'true'
    
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
echo "NCEP HASHFILE" >> $logfile
cat $ncep_hashfile >> $logfile

echo -e "**********************\n\n" >> $logfile
echo "UFS HASHFILE" >> $logfile
cat $ufs_hashfile >> $logfile

echo -e "**********************\n\n" >> $logfile
echo "FMS HASHFILE" >> $logfile
cat $fms_hashfile >> $logfile

