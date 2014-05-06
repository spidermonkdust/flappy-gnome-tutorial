flappy-gnome-tutorial
=====================

Flappy GNOME is a side-scrolling game development tutorial using GTK+ 3.8+, written in Vala.

The final result of the tutorial is a Flappy Bird style minigame.
![ScreenShot](/screenshot.png)
The steps of the tutorial should be easy to follow, each step being a single commit, with a minimal required diff. 
Additionally, the code is fairly well-commented, short, and organized, so it should be easy to read.

# Running

The packages required for building are:
* gtk+-3.0
* librsvg-2.0
* valac (I am building with 0.24, might work on lower versions too)

Compile the application with the `valac -o flappy-gnome --pkg gtk+-3.0 --pkg librsvg-2.0 FlappyGnome.vala` command.

Run the application from the same you have compiled from using the `./flappy-gnome` command.

# Description of the steps

##1. Basic game interface
* main window
* scroll window for side-scrolling
* game area
* player arrow
* score label
* initially rendered pipes

##2. Scrolling animation
* on Space key released, start the animation
* animation scrolls the game area
* when reached the end of the scrollbar, stop

##3. Infinite scrolling
* when we have scrolled to the far left, resize the game area and add a new pipe

##4. Player controls and movement
* player is falling by default
* player jumps on Space button released
* game ends when the player falls to the bottom

##5. Collision detection
* added list with bounding boxes of pipes
* remove the items as we pass through
* calculate player bounding box
* end game on collision of player with a pipe

##6. New game support
* added F2 key to start a new game

##7. Style the interface
* add CSS styling
* style the pipes with a gradient
* add a static floor, not scrolled
* use different styles for top and bottom pipes
* move the horizontal scrollbar above the game area
* move the score widget from the game area to floor
* use a signal to handle score updates

##8. Further UI improvements
* use public-domain SVG images instead of arrows
* add a restart button for easily restarting the game

