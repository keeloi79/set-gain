#!/bin/bash

echo "Updating apt......"
sudo apt update


echo "Detecting Distro Version....."
CODENAME=`lsb_release -sc`
if [[ ${CODENAME} == "jessie" ]];
 then
 echo "";
 echo "Detected" ${CODENAME}"....";
 echo "";
 echo " Installing php5-cgi....";
 sudo apt install -y php5-cgi;

elif [[ ${CODENAME} == "stretch" ]];
 then
 echo "Detected" ${CODENAME}".... ";
 echo ""
 echo " Installing php7.0-cgi....";
 sudo apt install -y php7.0-cgi;
 
elif [[ ${CODENAME} == "buster" ]];
 then
 echo "Detected" ${CODENAME}".... ";
 echo ""
 echo " Installing php7.3-cgi....";
 sudo apt install -y php7.3-cgi;

fi

echo ""
echo "Enabling module fastcgi-php...."
sudo lighty-enable-mod fastcgi-php
sudo /etc/init.d/lighttpd force-reload



echo "Creating file gain.php...."
FILE_GAIN="/usr/share/dump1090-fa/html/gain.php"
sudo touch $FILE_GAIN

echo "making file gain.php writeable by script (666)...."
sudo chmod 666 $FILE_GAIN

echo "Writing code to file gain.php...."
sudo cat <<\EOT > $FILE_GAIN

<html>
 <form id="myform" action="gain.php" method="post" />
 <div><font color=#ff0000 face="'Helvetica Neue', Helvetica, Arial, sans-serif">Current Gain: <?php system('cat /usr/local/sbin/gain/currentgain');?> </font></div>
 <select name="gain" id="gain">
   <option value=-10>-10</option>
   <option value=49.6>49.6</option>
   <option value=48.0>48.0</option>
   <option value=44.5>44.5</option>
   <option value=43.9>43.9</option>
   <option value=43.4>43.4</option>
   <option value=42.1>42.1</option>
   <option value=40.2>40.2</option>
   <option value=38.6>38.6</option>
   <option value=37.2>37.2</option>
   <option value=36.4>36.4</option>
   <option value=33.8>33.8</option>
   <option value=32.8>32.8</option>
   <option value=29.7>29.7</option>
   <option value=28.0>28.0</option>
   <option value=25.4>25.4</option>
   <option value=22.9>22.9</option>
   <option value=20.7>20.7</option>
   <option value=19.7>19.7</option>
   <option value=16.6>16.6</option>
 </select>
 <input type="submit" value="Set Gain" style="color:#ffffff;background-color:#00A0E2;border-color:#00B0F0;" />
 </form>
</html>

<?php
function setgain(){
$gain="{$_POST['gain']}";
system("echo $gain > /usr/local/sbin/gain/newgain");
sleep(5);
header("Refresh:0");
}

if ("{$_POST['gain']}"){
setgain();
}

?>


EOT

echo "Code written to file gain.php...."
echo " Making it writeable by owner only (664)...."
sudo chmod 644 $FILE_GAIN


echo "Creating folder gain...."
sudo mkdir -p /usr/local/sbin/gain

echo "Creating file setgain.sh...."
FILE_SETGAIN="/usr/local/sbin/gain/setgain.sh"
sudo touch $FILE_SETGAIN

echo "making file setgain.sh writeable by script (666)...."
sudo chmod 666 $FILE_SETGAIN


echo "Writing code to file setgain.sh...."
sudo cat <<\EOT > $FILE_SETGAIN

#!/bin/bash

# redirect all output and errors of this script to a log file
exec &>/usr/local/sbin/gain/log

# file that anyone can write to in order to set a new gain
fifo=/usr/local/sbin/gain/newgain

# remove $fifo so we are sure we can create our named pipe
rm -f $fifo

# create the named pipe with write access for everyone
mkfifo -m 666 $fifo

# read current gain and store in file currentgain
# script in gain.php will read gain value stored in currentgain and
# will display it on map as "Current Gain"
awk '{for(i=1;i<=NF;i++) if ($i=="--gain") print $(i+1)}' /etc/default/dump1090-fa > /usr/local/sbin/gain/currentgain


while sleep 1
do
        if ! [[ -r $fifo ]] || ! [[ -p $fifo ]]

        # exit the loop/script if $fifo is not readable or not a named pipe
        then break
        fi


        # read one line from the named pipe, remove all characters
        # but numbers, dot, minus and newline and store it in $line
        read line < <(tr -cd  '.\-0123456789\n' < $fifo)

        #set new gain
        #sed -i '/RECEIVER_OPTIONS=.*/c\RECEIVER_OPTIONS="--device-index 0 --gain '$line' --ppm 0 --net-bo-port 30005"' /etc/default/dump1090-fa
        gainnow=`sed -n 's/.* --gain \([^ ]*\).*/\1/p' /etc/default/dump1090-fa`
        sudo sed -i 's/--gain '$gainnow'/--gain '$line'/' /etc/default/dump1090-fa
        
        #restart dump1090-fa to implement new gain value
        systemctl restart dump1090-fa

        # read updated gain and store in file currentgain
        awk '{for(i=1;i<=NF;i++) if ($i=="--gain") print $(i+1)}' /etc/default/dump1090-fa > /usr/local/sbin/gain/currentgain

        # script in gain.php will read the updated gain and display it on map

done


EOT

echo "code written to file setgain.sh...."
echo " Making it writeable by owner only (664)...."
sudo chmod 644 $FILE_SETGAIN

echo ""
echo ""
echo "FILE & FOLDER CREATION COMPLETED"
echo "FOLLOWING FILES ARE READY"
echo ""
echo $FILE_GAIN
echo $FILE_SETGAIN
echo ""
echo ""
echo "=========================================="
echo "PLEASE DO FOLLOWING:"
echo "=========================================="
echo "(1) Add entry in crontab to run setgain.sh at boot."
echo "    Give command:  sudo crontab -e "
echo "    In file opened, scroll down and at bottom add following line"
echo ""
echo "    @reboot /bin/bash /usr/local/sbin/gain/setgain.sh "
echo ""
echo "(2) After completing above step, Reboot Pi to start setgain script"
echo ""
echo "(3) Make a backup copy of file index.html by following commands..."
echo ""
echo "    cd /usr/share/dump1090-fa/html  "
echo "    sudo cp index.html index.html.orig "
echo ""
echo "(4) Open file index.html for editing "
echo "    sudo nano /usr/share/dump1090-fa/html/index.html "
echo ""
echo "    Press Ctrl+W and type "buttonContainer" and press Enter key "
echo '    the cursor will jump to <div class="buttonContainer">'
echo '    add following 3 lines of code just above line <div class="buttonContainer">'
echo ""
echo '    <div id="GAIN" style="text-align:center;width:175px;height:65px;">'
echo '    <iframe src=gain.php style="border:0;width:175px;height:65px;"></iframe>'
echo '    </div> <!----- GAIN --->'
echo ""
echo "(5) After completing steps (3) and (4), "
echo "    (a) Reboot RPi "
echo "    (b) After reboot, clear browser cache (Ctrl+Shift+Delete) and Reload Browser (Ctrl+F5)"
echo ""

