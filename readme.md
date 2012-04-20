# TotalSpaces.osax

This source code implements scripting additions used by [TotalSpaces](http://totalspaces.binaryage.com).

**TotalSpaces** is a plugin for Apple's Dock.app which adds some neat Spaces features.

### Visit [totalspaces.binaryage.com](http://totalspaces.binaryage.com)

## Is this a replacement for SIMBL?

Yes, this is SIMBL-lite tailored specifically for TotalSpaces.

## BATSinit event

Installs TotalSpaces.bundle into running Spaces.app (/Applications/TotalSpaces.app is just a wrapper app for this script)

    tell application "Dock"
        -- give Dock some time to launch if it wasn't running (rare case)
        delay 1 -- this delay is important to prevent random "Connection is Invalid -609" AppleScript errors 
        try
            «event BATSinit»
        on error msg number num
            display dialog "Unable to launch TotalSpaces." & msg & " (" & (num as text) & ")"
        end try
    end tell

## BATSchck event

Check if TotalSpaces is present in running Dock image.

    tell application "Dock"
        -- give Spaces some time to launch if it wasn't running (rare case)
        delay 1 -- this delay is important to prevent random "Connection is Invalid -609" AppleScript errors 
        try
            «event BATSchck»
            set res to "present"
        on error msg number num
            set res to "not present"
        end try
        res
    end tell