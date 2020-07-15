﻿


state("WinKawaks")
{
	int pointerScreen : 0x0046B270;
}





startup
{
	
	//A function that finds an array of bytes in memory
	Func<Process, SigScanTarget, IntPtr> FindArray = (process, target) =>
	{

		IntPtr pointer = IntPtr.Zero;



		foreach (var page in process.MemoryPages())
		{

			var scanner = new SignatureScanner(process, page.BaseAddress, (int)page.RegionSize);

			pointer = scanner.Scan(target);

			if (pointer != IntPtr.Zero) break;

		}



		return pointer;

	};

	vars.FindArray = FindArray;



	//A function that reads an array of 40 bytes in the screen memory
	Func<Process, int, byte[]> ReadArray = (process, offset) =>
	{

		byte[] bytes = new byte[40];

		bool succes = ExtensionMethods.ReadBytes(process, vars.pointerScreen + offset, 40, out bytes);

		if (!succes)
		{
			print("[MS4 AutoSplitter] Failed to read screen");
		}

		return bytes;

	};

	vars.ReadArray = ReadArray;



	//A function that matches two arrays of bytes
	Func<byte[], byte[], bool> MatchArray = (bytes, colors) =>
	{

		if (bytes == null)
		{
			return false;
		}

		for (int i = 0; i < bytes.Length; i++)
		{

			if (bytes[i] != colors[i])
			{
				return false;
			}
		}

		return true;

	};

	vars.MatchArray = MatchArray;



	//A function that prints an array of bytes
	Action<byte[]> PrintArray = (bytes) =>
	{

		if (bytes == null)
		{
			print("[MS4 AutoSplitter] Bytes are null");
		}

		else
		{
			var str = new System.Text.StringBuilder();

			for (int i = 0; i < bytes.Length; i++)
			{
				str.Append(bytes[i].ToString());

				str.Append(",");

				if (i % 4 == 3) str.Append("\n");

				else str.Append("\t");
			}

			print(str.ToString());
		}
	};

	vars.PrintArray = PrintArray;

	

	//Should we reset and restart the timer
	vars.restart = false;

	

	//An array of bytes to find the boss's health variable
	vars.scannerTargetBossHealth = new SigScanTarget(22, "10 00 8C EC ?? 00 ?? ?? ?? ?? ?? ?? ?? 00 ?? ?? ?? ?? ?? ?? ?? ?? ?? ?? 07 00 7A 4F");



	//The pointer to the boss's health, once we found it with the scan
	vars.pointerBossHealth = IntPtr.Zero;



	//A watcher for this pointer
	vars.watcherBossHealth = new MemoryWatcher<short>(IntPtr.Zero);



	//The time at which the last scan happenend
	vars.prevScanTimeBossHealth = -1;



	//The time at which the last split happenend
	vars.prevSplitTime = -1;



	//The split/state we are currently on
	vars.splitCounter = 5;
	
}





init
{
	
	//Set refresh rate
	refreshRate = 33;


	/*
	 * 
	 * The various color arrays we will be checking for throughout the game
	 * Colors must be formated as : Blue, Green, Red, Alpha
	 *
	 * On the WinKawaks version, Alpha seems to always be 0
	 * On the WinKawaks version, the offset is X * 0x4 + Y * 0x500
	 * 
	 */
	


	//The tree in the background at the start of mission 1
	//Appears 2.15 seconds before the character hits the ground
	//Starts at pixel ( 2 , 99 )
	vars.colorsRunStart = new byte[]		{
												80, 104, 136, 0,
												0, 0, 0, 0,
												48, 88, 120, 0,
												0, 0, 0, 0,
												0, 24, 32, 0,
												0, 0, 0, 0,
												48, 72, 80, 0,
												0, 0, 0, 0,
												48, 72, 80, 0,
												0, 0, 0, 0
											};
		
	vars.offsetRunStart = 0x1D648;
	
	
	
	//The exclamation mark in the Mission Complete !" text
	//Starts at pixel ( 247 , 113 )
	vars.colorsExclamationMark = new byte[] {
												0,	0,	0,	0,
												248,	248,	248,	0,
												0,	0,	120,	0,
												48,	208,	248,	0,
												24,	144,	248,	0,
												48,	208,	248,	0,
												24,	144,	248,	0,
												48,	208,	248,	0,
												248,	248,	248,	0,
												0,	0,	0,	0
											};

	vars.offsetExclamationMark = 0x21C9C;
	
	
	
	//The wreckage of the pink robot, just before the last phase
	//Starts at pixel ( 20 , 188 )
	vars.colorsBossStart = new byte[]		{
												32, 32, 40, 0,
												80, 88, 96, 0,
												216, 216, 216, 0,
												216, 216, 216, 0,
												16, 0, 24, 0,
												40, 0, 56, 0,
												80, 32, 120, 0,
												72, 0, 96, 0,
												72, 0, 96, 0,
												80, 32, 120, 0
											};
		
	vars.offsetBossStart = 0x37D50;
	
}





exit
{

	//The pointers and watchers are no longer valid
	vars.pointerBossHealth = IntPtr.Zero;

	vars.watcherBossHealth = null;

}





update
{
	
	//Try to find the screen
	vars.pointerScreen = new IntPtr(current.pointerScreen);
	
	

	//If we know where the screen is
	if (vars.pointerScreen != IntPtr.Zero)
	{
		
		//Debug print an array
		//print("Rugname");
		
		//vars.PrintArray(vars.ReadArray(game, vars.offsetRunStart));

		
	
		//Check if we should start/restart the timer
		vars.restart = vars.MatchArray(vars.ReadArray(game, vars.offsetRunStart), vars.colorsRunStart);
		
	}
}





reset
{
	
	if (vars.restart)
	{
		vars.splitCounter = 0;
		
		vars.prevSplitTime = -1;
		
		vars.prevScanTimeBossHealth = -1;
		
		vars.pointerBossHealth = IntPtr.Zero;

		vars.watcherBossHealth = null;

		return true;
	}
}





start
{
	
	if (vars.restart)
	{
		return true;
	}
}





split
{
	
	//Check time since last split, don't split if we already split in the last 10 seconds
	var timeSinceLastSplit = Environment.TickCount - vars.prevSplitTime;
	
	if (vars.prevSplitTime != -1 && timeSinceLastSplit< 10000)
	{
		return false;
	}
	
	
	
	//If we dont know where the screen is, stop
	if (vars.pointerScreen == IntPtr.Zero)
	{
		return false;
	}



	//Missions 1, 2, 3, 4 and 5
	if (vars.splitCounter< 5)
	{
		
		//Split when the exclamation mark from the "Mission Complete !" text is in the right spot
		byte[] pixels = vars.ReadArray(game, vars.offsetExclamationMark);

		if (vars.MatchArray(pixels, vars.colorsExclamationMark))
		{
			vars.splitCounter++;
			
			vars.prevSplitTime = Environment.TickCount;
			
			return true;
		}
	}



	//Knowing when we get to the last boss
	else if (vars.splitCounter == 5)
	{
		
		//When the pink robot is rekt
		byte[] pixels = vars.ReadArray(game, vars.offsetBossStart);
	
		if (vars.MatchArray(pixels, vars.colorsBossStart))
		{
			
			//Notify
			print("[MS4 AutoSplitter] Last fight starting");



			//Clear the pointer to the boss's health
			vars.pointerBossHealth = IntPtr.Zero;
			
			
			
			//Move to next phase, prevent splitting/scanning for 10 seconds (but don't actually split)
			vars.splitCounter++;
			
			vars.prevSplitTime = Environment.TickCount;
			
		}
	}



	//Finding the boss's health variable
	else if (vars.splitCounter == 6)
	{
		
		//Check time since last scan, don't scan if we already scanned in the last 3 seconds
		//This should end up triggering about 2 or 3 times, which should be more than enough to find his health before the end of the fight
		var timeSinceLastScan = Environment.TickCount - vars.prevScanTimeBossHealth;
		
		if (timeSinceLastScan > 3000)
		{
			
			//Notify
			print("[MS4 AutoSplitter] Scanning for health");



			//Scan
			vars.pointerBossHealth = vars.FindArray(game, vars.scannerTargetBossHealth);
			
			
		
			//If the scan was successful
			if (vars.pointerBossHealth != IntPtr.Zero)
			{
				
				//Notify
				print("[MS4 AutoSplitter] Found health");



				//Create a new memory watcher
				vars.watcherBossHealth = new MemoryWatcher<short>(vars.pointerBossHealth);

				vars.watcherBossHealth.Update(game);
				
				
				
				//Move to next phase
				vars.splitCounter++;

			}
			
			
			
			//Write down scan time
			vars.prevScanTimeBossHealth = Environment.TickCount;
	
		}
	}



	//Check that the boss's health has been reset above 0
	else if (vars.splitCounter == 7)
	{
		
		vars.watcherBossHealth.Update(game);
		
		if (vars.watcherBossHealth.Current > 0)
		{
			
			//Notify
			print("[MS4 AutoSplitter] Monitoring health");



			//Go to next phase
			vars.splitCounter++;

		}
	}



	//Check that the boss's health has been reduced to 0
	else if (vars.splitCounter == 8)
	{

		//Update watcher
		vars.watcherBossHealth.Update(game);
		
		
		
		//Split when the boss's health reaches 0
		if (vars.watcherBossHealth.Current == 0)
		{
			print("[MS4 AutoSplitter] Run end");

			vars.splitCounter++;

			vars.prevSplitTime = Environment.TickCount;
			
			return true;
		}
	}
}