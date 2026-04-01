### You're on the wrong branch! It's totally my fault, but now you have to fix it!

### Potops: Through Realms and Rubble

Simple Asynchronous Turn Based Strategy involving flower pots of mass destruction

You always underestimate just how much code a "simple project" requires.
~5800 lines of code (not including comments or empty lines)
~120 hours of work from just the lead programmer

**Controls**

Point and click on the main menu to view the different screens
WASD to move
Click a character to switch to them
You can click your controlled character to open the point and click move menu

**FAQ**

How to exit a level?
- Hit escape, and click return to main menu

Are my items saved when I exit?
- No. That being said, you get a generous pool of starting items to make up for it.

Can I view my inventory?
- The inventory viewer was 10 minutes away from being implemented. Unfortunately, we only had 9 seconds left. The shop buttons will gray out if you can't purchase the item.

9 seconds? Seriously?
- <img width="420" height="19" alt="image" src="https://github.com/user-attachments/assets/7ef1835d-df7e-48de-991c-21f0b5c76e01" />

Am I allowed to cheat?
- Heck yeah

The UI is bugged.
- I know.

How to add my own maps?
- Copy and edit the built in map. You can open the maps folder from the main menu.

Can I change the settings?
- You are allowed to resize your window and break certain UI screens.

You suck at coding!
- You haven't even seen the worst of it.

What happened to the theme?
- A merge conflict at 11pm prevented the fun theme based level from being added on time.

What's the best strategy?
- 3 fire potop on shotbow, ~~fight~~ incinerate one enemy at a time.

Editing player/item/enemy stats:
You can find all the relevant dictionaries scattered throughout globals.gd
Pretty simple just change a number or two. Mess around and have fun.

**Exporting:**

I had to write several functions to MANUALLY COPY OVER HARDCODED FILES FROM RES TO USER AT RUNTIME. Because silly little me didn't know that RES:// IS NOT A STABLE FILESYSTEM ON EXPORT!!!

So tons of things that worked perfectly for a month broke all at once an hour before the deadline.

If you want to add builtin maps, map tile assets, or audio, add their paths to the relevant dictionaries in globals.gd
Then cross your greasy little fingers, click export, and then export all, with debug.

**Editors Note:**

The game has a lot of little quirks due to me having to write half of it on the last day (I was out of town for 2 weeks and got back the 31st). The actual game is more or less feature complete and even comes with a custom map support, as well as complete but unimplemented frameworks for custom enemies, items, shops, audio, camera zoom, inventory viewing, you name it.

But all of my time on the last day was dedicated to making the game, you know, like, function.
There are 3 major things that need cleaned up:
- Importing resources at runtime (Use godot's resource loader instead of scanning res://)
- UI is a little confusing and inconsistent, with a few bugs sprinkled in.
- Maps were supposed to have teleporter support, but this just couldn't make it in time.

And lots of little annoying things:
- Referencing nodes on ready and then adding them to globals causes race conditions
- Player party splitting for combat could be more dynamic
- Probably very unbalanced gameplay
- Enemy line of sight propagation could feel better for more intense combat
- There is no indicator that a ranged enemy has hit you besides the message in the game log. It should be trivial to pull the list of affected tiles by an attack and simply spawn a projectile sprite there for a second and chain them to make a moving effect.
- Player animations exist, but are unused, because enemy animations weren't finished in time.
- YATI importer is fragile when used at runtime. It would be good to write a custom importer.
- Piercing attacks also pierce players and walls, unintentionally
- Lots of functions are missing docstrings and type safety because I was just writing too fast to think about it
- Combat UI is positioned above the pause menu instead of below it. Literally just drag and drop it in a different place.
- Game is probably horribly unbalanced
- Maps don't have an exit point and must be manually exited from the pause menu
- At some point a merge conflict was created on main and we didn't have time to resolve it, so I just made a new main branch and started committing to that instead. So, uh, good luck.
- Probably more
