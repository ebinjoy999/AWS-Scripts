#!/usr/bin/env bash
RED='\033[0;31m'
NC='\033[0m' # No Color
timestamp=$( date "+%Y.%m.%d-%H.%M.%S" )

hostTest="www1.successmantram.com"
hostProd="www1.bizdart.com"
hostDev="www1.sdartdev.com"

hostTestDB="successdart_staging"
hostProsDB="bizdart_production"
hostDevDB="successdart_development"

hostSSHDev="successdart_dev.pem"
hostSSHTest="successdart_regression.pem"
hostSSHProd="bizdart_prod.pem"

takeLocalDump()
{
 # connect server and take dump	
 ssh -i ${HOME}/.ec2/${3} ubuntu@${1} "rm -R ~/auto_dump; mkdir ~/auto_dump; cd ~/auto_dump;
 sudo -u postgres pg_dump -Fc ''${2} > backup_${timestamp}.dump; echo; echo; ls -hs ~/auto_dump/backup_${timestamp}.dump"
 echo "Finished backup dump."
 echo "Moving dump file to Local..."
 mkdir ${HOME}/Desktop/${2}
 # copy above dump to local by scp
 scp -i ~/.ec2/${3} ubuntu@${1}:~/auto_dump/backup_${timestamp}.dump ${HOME}/Desktop/${2}
 printf "${RED}DB dump file stored at:${HOME}/Desktop/${2}/backup_${timestamp}.dump${NC}"
}

takePartialDump(){
   read  -p "Enter the orgin schema name of ${1}:" orgin
   read  -p "Enter the target schema name of ${2}:" target
   printf "${RED}[$orgin]${NC} will be restored in ${RED}[$target]${NC} continue(Y)?"
   read -n 1 -p "" agree
   echo
   if [ $agree !=  "Y" ] && [ $agree !=  "y" ]
	then
	  echo	
	  break
    fi
   echo
   # create folder in server and take dump of specific schema by using pg command
   ssh -i ${HOME}/.ec2/${3} ubuntu@${1} "rm -R ~/auto_dump; mkdir ~/auto_dump; cd ~/auto_dump;
   sudo -u postgres pg_dump -Fc -n ${orgin} ''${5} > backup_${orgin}_${timestamp}.dump; echo; echo; ls -hs ~/auto_dump/backup_${orgin}_${timestamp}.dump"
   echo "Finished backup dump of $orgin @ ${1}"
   echo "Coping dump file to ${2} from ${1}"
   ssh -i ${HOME}/.ec2/${4} ubuntu@${2} "mkdir ~/auto_dump"
    # scp -3 -i ~/.ec2/${3} ubuntu@${1}:~/auto_dump/backup_${orgin}_${timestamp}.dump -i ~/.ec2/${4} ubuntu@${2}:~/auto_dump/backup_${orgin}_${timestamp}.dump
    # ssh -A -i ~/.ec2/${3} ubuntu@${1} scp ~/auto_dump/backup_${orgin}_${timestamp}.dump -i ~/.ec2/${4} ubuntu@${2}:~/auto_dump
   # downloading schema dump to local machine from server1
   mkdir $ mkdir ${HOME}/Desktop/${5}/temp
   scp -i ~/.ec2/${3} ubuntu@${1}:~/auto_dump/backup_${orgin}_${timestamp}.dump ${HOME}/Desktop/${5}/temp
   printf "${RED}File downloaded to local machine from ${1} ${NC}"; echo
   # upload server1 schema dump to server2
   scp ${HOME}/Desktop/${5}/temp/backup_${orgin}_${timestamp}.dump -i ~/.ec2/${4} ubuntu@${2}:~/auto_dump/
   echo
   ssh -i ${HOME}/.ec2/${4} ubuntu@${2} "ls -hs ~/auto_dump/backup_${orgin}_${timestamp}.dump"
   printf "${RED}File uploaded to ${2}${NC}"; echo
   # restore schema in server2
   ssh -i ${HOME}/.ec2/${4} ubuntu@${2} "sudo -u ubuntu psql ${6} -c \"CREATE SCHEMA IF NOT EXISTS ${orgin}\";
   sudo -u postgres pg_restore --verbose --clean --no-acl --no-owner  -n ${orgin}   -d ${6} ~/auto_dump/backup_${orgin}_${timestamp}.dump"
   echo "[$orgin] restored in [$target]..."
}


echo
	echo " ----------------------------------------------- "
	printf " ${RED}AWS Script for Successdart/Bizdart ${NC}      "; echo
	echo " ----------------------------------------------- "
	echo "Local dump path:${PWD}/[database_name]"
	printf "${RED}pem files expected at:${HOME}/.ec2 folder${NC}"; echo; 
	echo "Expected file names"
	echo "Testing: ${hostSSHTest}"
	echo "Development: ${hostSSHDev}"
	echo "Production: ${hostSSHProd}"
	echo
	echo "    01) Take Testing dump and save in local (${hostTest})"
	echo "    02) Take Development dump and save in local(${hostDev})"
	printf "    03) ${RED}Take Production dump and save in local(${hostProd})${NC}"
    echo;
    	echo "    04) Development dump to Testing(partial-DB)"
    	echo "    05) Testing dump to Development(partial-DB)"
    	printf "    06) Production dump to Testing(partial-DB)"; echo
    	printf "    07) Production dump to Development(partial-DB)"
     echo;
    	printf "    XX) ${RED}Development dump to Testing(full-DB)${NC}";echo
    	printf "    XX) ${RED}Testing dump to Development(full-DB)${NC}";echo
    	printf "    XX) ${RED}Production dump to Testing(full-DB)${NC}" ;echo
    	printf "    XX) ${RED}Production dump to Development(full-DB)${NC}"
	echo

while :
do
	echo
	printf "Choose an option ${RED}(Q to exit)${NC}"
	read -n 2 -p ":" VAR
	echo
case $VAR in
	01)
        takeLocalDump $hostTest $hostTestDB $hostSSHTest
		;;
	02)
		takeLocalDump $hostDev $hostDevDB $hostSSHDev
		;;
	03)
		takeLocalDump $hostProd $hostProsDB $hostSSHProd
		;;	

	04) #dev-test
        takePartialDump $hostDev $hostTest $hostSSHDev $hostSSHTest $hostDevDB $hostTestDB
	    ;;	
	05)  #test-dev
        takePartialDump $hostTest $hostDev $hostSSHTest $hostSSHDev $hostTestDB $hostDevDB
	    ;;	
	Q)  
	    echo "exiting...see you again!"
	     echo
	    break;
	    exit 0
	    ;;	
	q)  
	    echo "exiting...see you again!"
	     echo
	    break;
	    exit 0
	    ;;	
	*)
		echo "Sorry, I don't understand"
		;;
  esac
 done


