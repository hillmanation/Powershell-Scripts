# Mapping HPC User Home Directories to Windows Clients

This document will explain the configuration to provide HPC/HAL users with an automated mapping of their Unix home directory as a drive when they login to their Windows machine. This document _**assumes**_ the following:  
1. The location of the Unix home directory has been configured to be accessible from the User/Workstation VLAN via Export Policies (NetApp) or export rules in Linux.  
2. The naming standard of user's Unix home folders matches that of the user's Active Directory SamAccountName.  
3. The Unix home directory is an NFS share.  
4. DC-1 has the NFS powershell module folder available in "C:\Windows\System32\WindowsPowershell\Modules", as it is needed for client configuration. (If this is not the case, simply obtain and copy the NFS folder from elsewhere into this location)

## Enabling and Configuring NFS Client

In order to map user's NFS share on thier Windows Machine, we need to Enable a Windows Feature for NFS Client. This will be done by running the 'NFS-Client-Enable.ps1' script on your domain. You will need to edit the following on the script to fit your environment:  
1. On line 3, edit the 'Get-ADComputers' query to your desired query to gather a list of computers to run the script against. It is recommended to limit this to the User Workstation OU, as your Servers will likely not be using NFS mappings in this use case.  
2. On line 4, change the domain name appropriately.
		
Run the script from within Powershell ISE for best results/readability of errors. Part of the script will check if WinRM/PSRemoting is enabled on each computer and will attempt to enable it if it is not. When running the WinRM enable command remotely, some error red text is expected and will be noted by the script. Any actual errors or failures will be stored in a variable and printed to the console after the script is complete so that you may troubleshoot if needed.

## Configure NFS Server for Windows client mapping

For mounts to a NetApp NFS share, some settings will need updated in ONTAP CLI in order to enable Windows clients to connect. SSH/Putty into the storage shelf housing the Unix home share and run the following, found in this NetApp [KB](https://kb.netapp.com/onprem/ontap/da/NAS/Top_Windows_NFSv3.0_Issues%2C_Workarounds_and_Best_Practices#:~:text=Workaround%3A%20None-,Issue%203%3A,-%22Network%20Error%20%2D%2053):
> 1. set -privilege advanced
> 2. vserver nfs modify -vserver _vserver-name_ -v3-ms-dos-client enabled -showmount enabled
> 3. vserver nfs modify -vserver _vserver-name_ -enable-ejukebox false -v3-connection-drop disabled  

Similar settings may need configured for other storage systems, but this is the only use case I am able to test against to provide the correct settings. If you configure this and test mounting an NFS share to a Windows machine and are still getting the generic "Network Error - 53" message, verify connectivity to the share IP, if you can reach it from the client via ping, check to see if it works after doing this [workaround](https://learn.microsoft.com/en-us/archive/blogs/technet/sfu/getting-network-error-53-network-path-not-found). If it does not work, further troubleshooting will be needed.

## Gather List of User Folders from HPC

In order to allow users to map thier NFS home directory, we need to gather some information from the home directory folder. From Linux system with access to the Unix home directory we will run the 'Export-UIDs.sh' script. Since we want to avoid character format issues and the script is fairly short, I recommend creating a new file in a location of your choice (I use /tmp usually) using the text editor of your choice (vim, nano, etc), and type up the script as is (unless your home folder directory is titled differently, otherwise don't change the script).

Once that is typed up hit 'esc' and type :wq to save the file, make the file executable and then run it like so (use sudo as below or 'sudo su' beforehand):  
> 1. sudo chmod +x _filename_  
> 2. sudo ./_filename_

This will output a list similar to the following:  
> Name,UID,GID  
> 503137833,503137833,503137833  
> zz503193829,503193829,503193829  
> zz503202497,503202497,503202497  
> zz503252346,1007,1007  
> zz99999999,999999999,999999999  

Highlight and copy the data shown from your Putty session and paste it into Notepad, do not change the formatting and ensure you include the Name,UID,GID line. Save this text document as a CSV named 'exported-uid.csv' and take note of where it is saved.

## NFS User Mapping Script

Included in this repository folder is a batch script titled 'map-unix-home.bat'. Edit this file to reflect the proper NFS path to your Unix user home directory and the desired drive letter name on line 4. Once completed copy the batch script to your NETLOGON folder and verify 'Authenticated Users' **and** 'Everyone' groups have 'Read and Execute' permissions. It is important at this step to verify that no other User Profile Logon Script exists currently on any account in your AD structure, as the final script in the process will replace it. You should be able to query this with the following from an elevated Powershell prompt:  
> Get-ADUser -Filter * -Properties Name,SamAccountName,ScriptPath | where { $\_.ScriptPath -ne $NULL} | Select-Object Name,SamAccountName,ScriptPath
> <!-- NOTE: If you're reading this you're viewing the plain text version of this document, in the preceeding PS query remove the '\' in the 'where' block it is an escape character in Markdown -->

This should tell you any accounts that currently have an active logon script and it's name. You should find these scripts in the 'NETLOGON' domain folder. Either determine if those logon scripts are unecessary and can be removed, or remove those accounts from the 'exported-uid.csv' file. If you need to keep thier current logon scripts intact and they are already using a batch script, just add the 'mount' line from 'map-unix-home.bat' to their existing logon script to enable their automated NFS mapping. Otherwise, seek an alternative method to automatically map the NFS share for these accounts. You will need to edit the last step script for these accounts to import their UID/GID or manually set them via Attribute editor.

## Configure Logon Script Delay in GPO

In order to ensure timely mapping of the User's home directory, it is advised that you update the following setting in Group Policy:  
> Computer Configuration\Administrative Templates\System\Group Policy\Configure Logon Script Delay  

The default setting is 'Not Configured', however in this instance 'Not Configured' means a default delay of 5 minutes. I would set this in the Default Domain Policy for your domain, and setting it to 'Disabled' will make the logon script run with no delay.

## Import User's UID and GID to Active Directory

Now we will use the 'Add-UID-LogonScript.ps1' script to configure user accounts to both map thier Unix home directory and provide them with their Unix UID/GID in order to enable them to write to it. This script will look at the list of home directory folders, find a matching AD account, update the account's uidNumber and gidNumber property, and set the User Profile Logon Script name from the previous step.   
You will need to edit the following in the script:  
1. On line 3, edit the path to reflect the location of 'exported-uid.csv' that was extracted from the share in a previous step.  

After updating that, run Powershell ISE AS ADMIN to run the script. The error output of this script is fairly verbose, so troubleshoot accordingly if running into any errors. Once complete the found user accounts will be ready to use with thier Unix user directory. Users will need to log out and back in to their Windows machine in order to see the mapping show up.

## New Account Considerations

Once all of this is setup and working, future accounts need to be configured properly in order for those new users to access their Unix home folder if they work in Linux. The following should be added to the new user creation process:  

> 1. After creating the user's Linux account, take note of their UID and GID.
> 2. Open ADUC, click 'View'>'Advanced Features' (This should be _checked_)
> 3. Find the user in the OU page they are in (Do not use 'Find User', this will not show the 'Advanced Features' needed) and double click to bring up thier details box.
> 4. In this pop up box click on the 'Profile' tab, where it says 'Logon Script', if empty enter 'map-unix-home.bat' (with no single quotes) in that field. If there is already a file specified in that field, determine if it can be changed or if the 'mount' line from the 'map-unix-home.bat' script can be added to it.
> 5. Click the 'Attribute Editor' tab. Find the gidNumber and uidNumber fields here and edit them to reflect the values noted in step 1.
> 6. Click 'Ok' and verify the changes.  

The scripts included in this repository can be leveraged to automate the above process and make it easier for bulk account creations etc.

# Troubleshooting  

I will do my best to update this section with any troubleshooting methods I find or am made aware of for this process.  

## Still getting the _'Network Path Not Found'_ error  

From what I have found if you still get this error after following the procedures above, most likely there is an issue with one of the assumptions at the top of this document. Check Network ACLs and verify that traffic is routable from the User VLAN to the Netapp LIF VLAN you are using to mount the NFS share. Another thing I found is that even though the Export Policy attached to the Unix home volume in NetApp is configured correctly, you may have to add similar settings to the 'default' Export Policy. I don't know why. NetApp pls fix.
