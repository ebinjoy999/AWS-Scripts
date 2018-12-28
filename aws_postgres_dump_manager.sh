#!/usr/bin/env bash
RED='\033[0;31m'
NC='\033[0m' # No Color
timestamp=$( date "+%Y.%m.%d-%H.%M.%S" )
restoreSchema=""
restoreSchemaOrgin="-"
restoreSchemaTarget="-"

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
   printf "${1} ${RED}[$orgin]${NC} will be restored as ${2} ${RED}[$target]${NC} continue(Y)?"
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
   scp -i ~/.ec2/${4} ${HOME}/Desktop/${5}/temp/backup_${orgin}_${timestamp}.dump ubuntu@${2}:~/auto_dump/
   echo
   ssh -i ${HOME}/.ec2/${4} ubuntu@${2} "ls -hs ~/auto_dump/backup_${orgin}_${timestamp}.dump"
   printf "${RED}File uploaded to ${2}${NC}"; echo
   # restore schema in server2
   ssh -i ${HOME}/.ec2/${4} ubuntu@${2} "sudo -u postgres psql -c \"DROP DATABASE temp\";
   sudo -u postgres psql -c \"CREATE DATABASE temp\";
   sudo -u postgres psql temp -c \"CREATE SCHEMA IF NOT EXISTS ${orgin}\";
   sudo -u postgres pg_restore --verbose --clean --no-acl --no-owner  -n ${orgin} -d temp ~/auto_dump/backup_${orgin}_${timestamp}.dump;
   sudo -u postgres psql temp -c \"ALTER SCHEMA ${orgin} RENAME TO ${target}\";
   sudo -u postgres pg_dump -Fc -n ${target} temp > ~/auto_dump/backup_${orgin}_${timestamp}.dump;
   sudo -u postgres psql ${6} -c \"CREATE SCHEMA IF NOT EXISTS ${target}\";
   sudo -u postgres pg_restore --verbose --clean --no-acl --no-owner  -n ${target} -d ${6} ~/auto_dump/backup_${orgin}_${timestamp}.dump"
   echo "[$orgin] restored in [$target]..."
}

restoreLocalDump(){
	ssh -i ${HOME}/.ec2/${3} ubuntu@${1} "mkdir ~/auto_dump;"
	scp -i ~/.ec2/${3} $7 ubuntu@${1}:~/auto_dump/
   if [ ${6} ==  "Y" ] || [ ${6} ==  "y" ]
       then
        echo "Restoring full DB"
         ssh -i ${HOME}/.ec2/${3} ubuntu@${1} "
          sudo service nginx stop;
          sudo -u postgres psql -c \"SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname = ${2}\";
          sudo -u postgres psql -c \"DROP DATABASE ${2}\";
          sudo -u postgres psql -c \"CREATE DATABASE ${2}\";
          sudo -u postgres pg_restore --verbose --clean --no-acl --no-owner -d ${2} ~/auto_dump/${8};
          sudo service nginx start"
          echo "Restored DB" 
         break;
   fi 
  echo "Restoring partial DB"
  ssh -i ${HOME}/.ec2/${3} ubuntu@${1} "
   sudo service nginx stop;
   sudo -u postgres psql -c \"DROP DATABASE temp\";
   sudo -u postgres psql -c \"CREATE DATABASE temp\";
   sudo -u postgres psql temp -c \"CREATE SCHEMA IF NOT EXISTS ${4}\";
   sudo -u postgres pg_restore --verbose --clean --no-acl --no-owner  -n ${4} -d temp ~/auto_dump/${8};
   sudo -u postgres psql temp -c \"ALTER SCHEMA ${4} RENAME TO ${5}\";
   sudo -u postgres pg_dump -Fc -n ${5} temp > ~/auto_dump/${8};
   sudo -u postgres psql ${2} -c \"DROP SCHEMA ${5} CASCADE\";
   sudo -u postgres psql ${2} -c \"CREATE SCHEMA IF NOT EXISTS ${5}\";
   sudo -u postgres pg_restore --verbose --clean --no-acl --no-owner  -n ${5} -d ${2} ~/auto_dump/${8};
   sudo service nginx start"
   echo "[$4] restored in [$5]..."
}

echo
	echo " ----------------------------------------------- "
	printf " ${RED}AWS Script for Successdart/Bizdart ${NC}      "; echo
	echo " ----------------------------------------------- "
	echo "Local dump download path:${PWD}/[database_name]"
  echo "Local dump upload path:${PWD}"
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
  printf "    08) Restore an instance from Local dump file"
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
    06)  #prod-test
        takePartialDump $hostProd $hostTest $hostSSHProd $hostSSHTest $hostProsDB $hostTestDB
        ;;     
    07)  #prod-dev
        takePartialDump $hostProd $hostDev $hostSSHProd $hostSSHDev $hostProsDB $hostDevDB
        ;;    
    08)  #
        echo select a file:
        num=1
        itemsQ=`ls -1 *.dump`
        for item in `ls -1 *.dump`
        do
         #txt=`echo $item | sed s/mt/txt/`
         echo $num: $item: #`cat $txt` 
         num=`expr $num + 1`
        done | tee menu.lst
        read numb

        IFS=$'\n' lines=($itemsQ)
        echo; echo "Selected file ${PWD}/${lines[$numb-1]}"
        echo
        echo "Choose an instance"
        printf " 1.${hostDev} \n 2.${hostTest} \n 3.${hostProd}\n"
        read instanceOption
        printf "Restore complete database?(Y)"
         read isCompleteOption
        echo
       if [ $isCompleteOption !=  "Y" ] && [ $isCompleteOption !=  "y" ]
       then
          printf "Enter schema(orgin) name to restore?"
          read restoreSchemaOrgin
           printf "Enter schema(Target) name to restore?"
          read restoreSchemaTarget
        fi 
        case $instanceOption in
          1) #dev
             pathF="${PWD}/${lines[$numb-1]}"
             fileName="${lines[$numb-1]}"
             restoreLocalDump $hostDev $hostDevDB $hostSSHDev $restoreSchemaOrgin $restoreSchemaTarget $isCompleteOption $pathF $fileName
            ;;
          2) #test
             pathF="${PWD}/${lines[$numb-1]}"
             fileName="${lines[$numb-1]}"
             restoreLocalDump $hostTest $hostTestDB $hostSSHTest $restoreSchemaOrgin $restoreSchemaTarget $isCompleteOption $pathF $fileName
            ;;
          3) #prod
             pathF="${PWD}/${lines[$numb-1]}"
             fileName="${lines[$numb-1]}"
             restoreLocalDump $hostProd $hostProsDB $hostSSHProd $restoreSchemaOrgin $restoreSchemaTarget $isCompleteOption $pathF $fileName
            ;;
          *)
            echo "Sorry, wrong try"
            break;
             ;; 
        esac  
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


