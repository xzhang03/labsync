# labsync
 Synchronizing data between servers

## To use
1. Edit **setup_sample.json** to change the paths to your source and targeted folder. Then, rename to *setup.json*.

   - items: types of files you will sync. Feel free to change, but if you add anything make sure the paths are set in fp1. fp2, etc.
   - fp1: Source files on local server
   - fp2: Target folder #1 in remote server
   - fp3: Target folder #2 in remote server
   - mousefolder: naming scheme of your mice. Could use multiple but put the most common one first to make the code run faster.
   - reportfp: output path for report file
   
2. Edit **blacklist.json** to blacklist mice, or leave as is if no blacklisting.

3. Edit **whitelist.json** to whitelist mice. If whitelist_all is set true, all mice are whitelist and the blacklist will be ignored. The logic of black/whitelisting is:
   - Whitelist_all == true => Keep everything and ignore blacklist
   - Blacklist => Toss
   - Whitelist => Keep
   - Not listed => Toss, but will tell you which ones are unlisted so you can add them to the list next time
   - On both list => Toss, but please don't do this to avoid confusion
   
4. Run **Setup_first.m** to compile [mMD5.c](https://www.mathworks.com/matlabcentral/fileexchange/7919-md5-in-matlab) (already in this repo). This setup may require Mingw-w64 on some computers. This step also checks the json files and the paths.

5. You can now run the main **foldersync.m** function to get things started. I recommend only whitelisting 1 mouse or so to start and use a private target folder (to avoid scanning files that are not useful).
   > Comparison is made by MD5 hashing 1) filename, 2) filesize, 3) mousename, 4) SHA256 hashes of first 100 bytes (default) of large files (>1GB, dafault).

## Progress:
Done:
 - Turn foldersync into subfunctions
 - json implementation

To do:
 - Turn foldersync_automove into subfunctions - easy
 - Cautiously give foldersync_automove the ability to make new folders in the right places - easy
 - Turn folder_rewind into subfunctions - easy
 - Make "Rescan target" more efficient by avoiding scanning the entire target folder somehow (this is in foldersync.m). - medium
 - Enable differential mode of scanning (avoid scanning files that are already scanned). - hard
