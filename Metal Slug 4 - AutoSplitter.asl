


state("WinKawaks")
{
	int pointerScreen : 0x0046B270;
}

state("fcadefbneo")
{
	//int pointerScreen : 0x02D27B60, 0x4, 0xF4;
	int pointerScreen : 0x02D27B60, 0x4, 0x4, 0x14;
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



	//A function that reads an array of 60 bytes in the screen memory
	Func<Process, int, byte[]> ReadArray = (process, offset) =>
	{

		byte[] bytes = new byte[60];

		bool succes = ExtensionMethods.ReadBytes(process, vars.pointerScreen + offset, 60, out bytes);

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

		for (int i = 0; i < bytes.Length && i < colors.Length; i++)
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



	//The time at which the last reset happenend
	vars.prevRestartTime = Environment.TickCount;



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
	vars.splitCounter = 0;
	
	

	//A local tickCount to do stuff sometimes
	vars.localTickCount = 0;

}





init
{
	
	//Set refresh rate
	refreshRate = 60;


	/*
	 * 
	 * The various color arrays we will be checking for throughout the game
	 * Colors must be formated as : Blue, Green, Red, Alpha
	 *
	 * On the WinKawaks version, Alpha seems to always be 0
	 * On the WinKawaks version, the offset is X * 0x4 + Y * 0x500
	 * 
	 */
	if(game.ProcessName.Equals("WinKawaks"))
	{

		//The background at the start of mission 1, mingled with the fade in
		//Appears 2.15 seconds before the character hits the ground
		//Starts at pixel ( 2 , 99 )
		vars.colorsRunStart = new byte[]		{
													80,  104, 136, 0,
													0,   0,   0,   0,
													48,  88,  120, 0,
													0,   0,   0,   0,
													0,   24,  32,  0,
													0,   0,   0,   0,
													48,  72,  80,  0,
													0,   0,   0,   0,
													48,  72,  80,  0,
													0,   0,   0,   0,
												};
		
		vars.offsetRunStart = 0x1D648;
	
	
	
		//The exclamation mark in the Mission Complete !" text
		//Starts at pixel ( 247 , 113 )
		vars.colorsExclamationMark = new byte[] {
													0,   0,   0,   0,
													248, 248, 248, 0,
													0,   0,   120, 0,
													48,  208, 248, 0,
													24,  144, 248, 0,
													48,  208, 248, 0,
													24,  144, 248, 0,
													48,  208, 248, 0,
													248, 248, 248, 0,
													0,   0,   0,   0
												};

		vars.offsetExclamationMark = 0x21C9C;
	
	
	
		//The grey of the UI
		//Starts at pixel ( 80 , 8 ) for player 1
		//Starts at pixel ( 176 , 8 ) for player 2
		vars.colorsUI = new byte[]				{
													184, 168, 160, 0,
													184, 168, 160, 0,
													184, 168, 160, 0,
													184, 168, 160, 0,
													184, 168, 160, 0,
													184, 168, 160, 0,
													184, 168, 160, 0,
													184, 168, 160, 0,
													184, 168, 160, 0,
													184, 168, 160, 0
												};

		vars.offsetUI = 0x2740;
		
		vars.offsetUI2 = 0x28C0;
		
		
		
		//The wreckage of the pink robot, just before the last phase
		//Starts at pixel ( 20 , 188 )
		vars.colorsBossStart = new byte[]		{
													32,  32,  40,  0,
													80,  88,  96,  0,
													216, 216, 216, 0,
													216, 216, 216, 0,
													16,  0,   24,  0,
													40,  0,   56,  0,
													80,  32,  120, 0,
													72,  0,   96,  0,
													72,  0,   96,  0,
													80,  32,  120, 0
												};
		
		vars.offsetBossStart = 0x37D50;
	
	}



	else //if (game.ProcessName.Equals("fcadefbneo"))
	{

		//The background at the start of mission 1, mingled with the fade in
		//Appears 2.15 seconds before the character hits the ground
		//Starts at pixel ( 2 , 99 )
		vars.colorsRunStart = new byte[]		{
													82,  107, 140, 0,
													82,  107, 140, 0,
													0,   0,   0,   0,
													0,   0,   0,   0,
													49,  90,  123, 0,
													49,  90,  123, 0,
													0,   0,   0,   0,
													0,   0,   0,   0,
													0,   24,  33,  0,
													0,   24,  33,  0,
													0,   0,   0,   0,
													0,   0,   0,   0,
													49,  74,  82,  0,
													49,  74,  82,  0,
													0,   0,   0,   0
												};
		
		vars.offsetRunStart = 0x75910;
	
	
	
		//The exclamation mark in the Mission Complete !" text
		//Starts at pixel ( 247 , 113 )
		vars.colorsExclamationMark = new byte[] {
													0,   0,   0,   0,
													0,   0,   0,   0,
													255, 255, 255, 0,
													255, 255, 255, 0,
													0,   0,   123, 0,
													0,   0,   123, 0,
													49,  214, 255, 0,
													49,  214, 255, 0,
													24,  148, 255, 0,
													24,  148, 255, 0,
													49,  214, 255, 0,
													49,  214, 255, 0,
													24,  148, 255, 0,
													24,  148, 255, 0,
													49,  214, 255, 0
												};

		vars.offsetExclamationMark = 0x86AB8;
	
	
	
		//The grey of the UI
		//Starts at pixel ( 80 , 8 ) for player 1
		//Starts at pixel ( 176 , 8 ) for player 2
		vars.colorsUI = new byte[]				{
													189, 173, 165, 0,
													189, 173, 165, 0,
													189, 173, 165, 0,
													189, 173, 165, 0,
													189, 173, 165, 0,
													189, 173, 165, 0,
													189, 173, 165, 0,
													189, 173, 165, 0,
													189, 173, 165, 0,
													189, 173, 165, 0,
													189, 173, 165, 0,
													189, 173, 165, 0,
													189, 173, 165, 0,
													189, 173, 165, 0,
													189, 173, 165, 0
												};

		vars.offsetUI = 0x9A80;
		
		vars.offsetUI2 = 0x9D80;
		

		
		//The wreckage of the pink robot, just before the last phase
		//Starts at pixel ( 20 , 188 )
		vars.colorsBossStart = new byte[]		{
													33,  33,  41,  0,
													33,  33,  41,  0,
													82,  90,  99,  0,
													82,  90,  99,  0,
													222, 222, 222, 0,
													222, 222, 222, 0,
													222, 222, 222, 0,
													222, 222, 222, 0,
													16,  0,   24,  0,
													16,  0,   24,  0,
													41,  0,   57,  0,
													41,  0,   57,  0,
													82,  33,  123, 0,
													82,  33,  123, 0,
													74,  0,   99,  0
												};
		
		vars.offsetBossStart = 0xDF4A0;
	
	}
}





exit
{

	//The pointers and watchers are no longer valid
	vars.pointerBossHealth = IntPtr.Zero;

	vars.watcherBossHealth = new MemoryWatcher<short>(IntPtr.Zero);

}





update
{
	
	//Increase local tickCount
	vars.localTickCount = vars.localTickCount + 1;



	//Try to find the screen
	vars.pointerScreen = new IntPtr(current.pointerScreen);
	
	

	//If we know where the screen is
	if (vars.pointerScreen != IntPtr.Zero)
	{
		
		
		//Debug print
		if (vars.localTickCount % 20 == 0)
		{
			print("[MS4 AutoSplitter] Debug " + vars.splitCounter.ToString());
			
			vars.PrintArray(vars.ReadArray(game, vars.offsetBossStart));
		}
		

		
	
		//Check time since last reset, don't reset if we already reset in the last second
		var timeSinceLastReset = Environment.TickCount - vars.prevRestartTime;
		
		if (timeSinceLastReset< 1000)
		{
			vars.restart = false;
		}
	
		//Otherwise, check if we should start/restart the timer
		else
		{
			vars.restart = vars.MatchArray(vars.ReadArray(game, vars.offsetRunStart), vars.colorsRunStart);
		}
	}
	
	else
	{
		//Debug print
		if (vars.localTickCount % 20 == 0)
		{
			print("[MS4 AutoSplitter] Cannot Find Screen");
		}
	}
}





reset
{
	
	if (vars.restart)
	{
		vars.splitCounter = 0;
		
		vars.prevRestartTime = Environment.TickCount;

		vars.prevSplitTime = -1;
		
		vars.prevScanTimeBossHealth = -1;
		
		vars.pointerBossHealth = IntPtr.Zero;

		vars.watcherBossHealth = new MemoryWatcher<short>(IntPtr.Zero);

		return true;
	}
}





start
{
	
	if (vars.restart)
	{
		vars.splitCounter = 0;
		
		vars.prevRestartTime = Environment.TickCount;

		vars.prevSplitTime = -1;
		
		vars.prevScanTimeBossHealth = -1;
		
		vars.pointerBossHealth = IntPtr.Zero;

		vars.watcherBossHealth = new MemoryWatcher<short>(IntPtr.Zero);

		return true;
	}
}





split
{
	
	//Check time since last split, don't split if we already split in the last 10 seconds
	var timeSinceLastSplit = Environment.TickCount - vars.prevSplitTime;
	
	if (vars.prevSplitTime != -1 && timeSinceLastSplit < 10000)
	{
		return false;
	}
	
	
	
	//If we dont know where the screen is, stop
	if (vars.pointerScreen == IntPtr.Zero)
	{
		return false;
	}



	//Missions 1, 2, 3, 4 and 5
	if (vars.splitCounter < 10)
	{
		
		if (vars.splitCounter % 2 == 0)
		{
			
			//Check for the exclamation mark from the "Mission Complete !" text
			byte[] pixels = vars.ReadArray(game, vars.offsetExclamationMark);
			
			if (vars.MatchArray(pixels, vars.colorsExclamationMark))
			{
				vars.splitCounter++;
			}
		}

		else
		{

			//Split when the UI disappears after we've seen the exclamation mark
			byte[] pixels = vars.ReadArray(game, vars.offsetUI);

			byte[] pixels2 = vars.ReadArray(game, vars.offsetUI2);
			
			if (!vars.MatchArray(pixels, vars.colorsUI) && !vars.MatchArray(pixels2, vars.colorsUI))
			{
				vars.splitCounter++;
			
				vars.prevSplitTime = Environment.TickCount;
			
				return true;
			}
		}
	}



	//Knowing when we get to the last boss
	else if (vars.splitCounter == 10)
	{
		
		//When the pink robot is rekt
		byte[] pixels = vars.ReadArray(game, vars.offsetBossStart);
	
		if (vars.MatchArray(pixels, vars.colorsBossStart))
		{
			
			//Clear the pointer to the boss's health
			vars.pointerBossHealth = IntPtr.Zero;
			
			
			
			//Move to next phase, prevent splitting/scanning for 10 seconds (but don't actually split)
			vars.splitCounter++;
			
			vars.prevSplitTime = Environment.TickCount;
			
		}
	}



	//Finding the boss's health variable
	else if (vars.splitCounter == 11)
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
	else if (vars.splitCounter == 12)
	{
		
		vars.watcherBossHealth.Update(game);
		
		if (vars.watcherBossHealth.Current > 0)
		{
			
			//Go to next phase
			vars.splitCounter++;

		}
	}



	//Check that the boss's health has been reduced to 0
	else if (vars.splitCounter == 13)
	{

		//Update watcher
		vars.watcherBossHealth.Update(game);
		
		
		
		//Split when the boss's health reaches 0
		if (vars.watcherBossHealth.Current == 0)
		{
			vars.splitCounter++;

			vars.prevSplitTime = Environment.TickCount;
			
			return true;
		}
	}
}
