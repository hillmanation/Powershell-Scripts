@echo off
:: Change directories in case 'mount' verb conflicts with local Anaconda/Cygwin install
cd C:\Windows\System32
mount -o nolock mtype=hard ***nfsIP***:/home/%username% U:
