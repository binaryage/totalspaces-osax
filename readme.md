# TotalFinder.osax

This source code implements scripting additions used by [TotalFinder](http://totalfinder.binaryage.com).

**TotalFinder** is a plugin for Apples's Finder.app which brings tabs, dual panels and more!

<img src="http://totalfinder.binaryage.com/shared/img/totalfinder-mainshot.png">

## Visit [totalfinder.binaryage.com](http://totalfinder.binaryage.com)

## Is this a replacement for SIMBL?

Yes, this is SIMBL-lite tailored specifically for TotalFinder.

You may want to read the article about my motivations:
[http://blog.binaryage.com/totalfinder-without-simbl](http://blog.binaryage.com/totalfinder-without-simbl)

## BATFinit event

Installs TotalFinder.bundle into running Finder.app

    tell application "Finder"
        delay 1 -- this delay is important to prevent random "Connection is Invalid -609" AppleScript errors 
        try
            «event BATFinit»
        on error msg number num
            display dialog "Unable to launch TotalFinder." & msg & " (" & (num as text) & ")"
        end try
    end tell

#### License: [MIT-Style](totalfinder-osax/raw/master/license.txt)