const int WIN_WIDTH = 1280;
const int WIN_HEIGHT = 720;
const int GAP_HEIGHT = 180;
const int PIPE_WIDTH = 80;
const int SCROLL_SPEED = 5;
const int JUMP_HEIGHT = 20;
const int GROUND_HEIGHT = 100;

const string SCORE_TEMPLATE = "Score: <b>%u</b>";

private enum GameState {
    INIT,
    PLAYING,
    GAME_OVER;
}

private class GameArea : Gtk.Layout {                           // Our GameArea inherits from Gtk.Layout to support
                                                                // adding child components, absolute positioning, scrolling
    public signal void score_changed (int score);               // signal emitted at each score update, e.g. for updating a score widget

    private Gdk.Pixbuf bird_up;
    private Gdk.Pixbuf bird_down;

    private Gtk.Image birdie;                                   // The widget representing the player
    private int pipes_count;                                    // The number of pipes currently rendered
    private GameState state;                                    // The current game state
    private float vertical_speed = 0;                           // The current vertical movement speed of the player
    private float jump_height = 0;                              // The number of pixels remaining from the jump, until we start falling again
    private List<Gdk.Rectangle?> pipes = new List<Gdk.Rectangle?>(); // the rectangles of the pipes ahead of the player for collision detection
    private int score = 0;                                      // the game score
    private uint animation_callback_id = 0;                     // the id of the animation callback

    public GameArea () {
        birdie = new Gtk.Image ();                              // Create the image for the player
        try {
            bird_up = Rsvg.pixbuf_from_file ("heli-up.svg");    // load the ascending image
            bird_down = Rsvg.pixbuf_from_file ("heli-down.svg");// load the descending image
        } catch (Error e) {
            warning ("Error loading image, using arrows: %s",   // warn in case of an error
                     e.message);
            Gtk.IconTheme icon_theme = Gtk.IconTheme.get_default (); // load the icon theme to load the fallback images
            try {
                bird_up = icon_theme.load_icon ("go-up", 48, 0); // load the up icon
                bird_down = icon_theme.load_icon ("go-next", 48, 0); // load the forward icon
            } catch (Error e) {
                error ("No player image found");
            }
        }
        can_focus = true;                                       // set can_focus flag to be able to catch keyboard events
        key_release_event.connect (on_key_released);            // handle key-release-event
    }

    private bool on_key_released (Gdk.EventKey event) {
        if (event.keyval == Gdk.Key.space) {                    // In case the space key was released
            if (state == GameState.INIT) {                      // If the game isn't started yet
                state = GameState.PLAYING;                      // set the game state to playing
                animation_callback_id = add_tick_callback (game_screen_update); // add a tick callback to start the animation
            }

            if (state == GameState.PLAYING) {
                vertical_speed = -JUMP_HEIGHT/3;                // initialize the speed to a negative value to move upwards
                jump_height = JUMP_HEIGHT;                      // set the jump_height to the number of pixels we have to move upwards
            }

        }
        if (event.keyval == Gdk.Key.F2) {                       // if the key is F2
            setup_new_game ();                                  // start the game over
        }
        return false;
    }

    private bool is_player_hit (int child_x, int child_y) {
        int w, h;
        w = birdie.get_allocated_width ();
        h = birdie.get_allocated_height ();
        if (child_y > height - h) {                             // if we fell to the floor
            return true;                                        // report collistion
        }

        unowned List<Gdk.Rectangle?> first = pipes.first();
        if (first != null &&
            first.data.x + first.data.width < child_x) {        // left the first pipe behind
            pipes.remove_link(first);                           // we don't need this rectangle anymore
            pipes.remove_link(pipes.first());                   // neither the next one, which is the bottom pair for the previous
            score_changed(++score);                             // notify signal handlers of the score change
        } else if (first != null) {                             // if we haven't left this pipe behind yes
            Gdk.Rectangle birdie = get_rectangle(child_x + w - h, child_y,
                h,
                h);                                             // get the bounding rectangle of the player
            if (first.data.intersect (birdie, null)             // check for bounding box collision with the top
                || first.next.data.intersect (birdie, null)) {  // and the bottom pipe
                return true;                                    // if they intersect, we have a collision
            }
        }
        return false;                                           // no collision

    }

    private bool game_screen_update (Gtk.Widget w, Gdk.FrameClock fc) {
        Gtk.Scrollable scrollable = (Gtk.Scrollable) this;      // we need the scrollable instance from the game area
        Gtk.Adjustment adjustment = scrollable.get_hadjustment (); // to get the scrollbar
        adjustment.value += SCROLL_SPEED;                       // and scroll it with SCROLL_SPEED

        if (jump_height <= 0) {                                 // in case we have reached the highest point of our jump
            vertical_speed += (float)SCROLL_SPEED / 10;         // start falling, aka increasing the vertical speed
        } else {                                                // otherwise we are still ascending
            vertical_speed -= (float)SCROLL_SPEED / 10;         // so decrease the vertical speed, as gravity is slowing our jump down
            jump_height = int.max((int)(jump_height + vertical_speed), 0); // updathe the number of pixels remaining from the current jump
        }

        int child_x, child_y;
        move_child (birdie, SCROLL_SPEED, (int)vertical_speed,
                    out child_x, out child_y, false);           // move the bird too, both vertically and horizontally

        if (is_player_hit (child_x, child_y)) {
            state = GameState.GAME_OVER;                        // update the game state
            animation_callback_id = 0;                          // clear the stored animation callback id
            return false;                                       // false true to remove the tick callback
        }

        birdie.pixbuf = vertical_speed < 0 ? bird_up            // in case we are jumping, use the ascending image
                                           : bird_down;         // otherwise use the descending image

        if (adjustment.value >= adjustment.upper - adjustment.page_size) { // in case we are on the last page, meaning no way to scroll further
            width += 3*PIPE_WIDTH;                              // increase the width of the game area
            add_pipe ();                                        // add another pipe
        }

        return true;
    }

    private void move_child (Gtk.Widget child, int dx, int dy,  // the child to move, the deltas to move
                             out int child_x, out int child_y,  // the position after the update
                             bool place_over) {                 // if true, remove and readd, for z-ordering above all other components

        child_get (child, "x", out child_x, "y", out child_y);  // get the current child position
        child_x += dx;                                          // add the delta values to x position
        child_y += dy;                                          // and the y position too
        child_y = int.max (0, child_y);                         // do not allow leaving the gamefield on the top
        if (place_over) {
            remove (child);                                     // remove the child
            put (child, child_x, child_y);                      // add it back to the new position
        } else {
            move (child, child_x, child_y);                     // move the child to the new position
        }
    }

    public void setup_new_game () {
        if (animation_callback_id > 0) {                        // if the game is already running
                remove_tick_callback (animation_callback_id);   // stop the game by removing the tick callback
        }
        set_size (2 * WIN_WIDTH,                                // Set the size to twice the width of the window for horizontal scrolling
                  WIN_HEIGHT - GROUND_HEIGHT );                 // and a height to fit in the window without adding a vertical scrollbar

        vertical_speed = 0;                                     // Reinitialize game variables
        state = GameState.INIT;
        jump_height = 0;
        score = 0;
        score_changed (0);                                      // Notify score widget of the score reset

        pipes_count = 0;                                        // reset the pipes count
        ((Gtk.Scrollable)this).get_hadjustment().value = 0;     // reset the scroll

        get_children().foreach((item) => {remove(item);});      // remove all pipes
        pipes.foreach((item) => pipes.remove(item));            // remove all pipe bounding boxes

        birdie.pixbuf = bird_down;                              // reset the player

        put (birdie, PIPE_WIDTH * 2, WIN_HEIGHT / 3 * 2);       // Add the birdie at 2/3 of the height

        int initial_count = 2 * WIN_WIDTH / PIPE_WIDTH / 3 - 1; // Calculate the number of pipes to draw before starting the game

        while (pipes_count < initial_count)
            add_pipe ();                                        // Add the initial pipes

        show_all ();                                            // Show each child of the container

    }

    private void add_pipe () {
        int position = Random.int_range (GAP_HEIGHT/2,            // randomize the position of the gap between the pipes
                                         (int)height - GAP_HEIGHT * 3 / 2);
        int top_height = position;                              // the height of the pipe from the top
        int bottom_height = (int)height - top_height - GAP_HEIGHT; // the height of the pipe from the bottom
        var top = new Gtk.Button ();                            // The pipe coming from the top
        top.get_style_context ().add_class ("top");             // Add top class for styling
        top.set_size_request (PIPE_WIDTH, top_height );         // has a standard width going all the way down until the generated position
        put (top, (pipes_count+2)*PIPE_WIDTH*3, 0);             // we need some empty space for warmup, so we leave 2 pipes' space empty
        var bottom = new Gtk.Button ();
        bottom.get_style_context ().add_class ("bottom");       // Add bottom class for styling
        bottom.set_size_request (PIPE_WIDTH,                    // the pipe from the bottom with standard width
                                 bottom_height); // going down to the bottom
        put (bottom, (pipes_count+2)*PIPE_WIDTH*3,
                     position+GAP_HEIGHT);
        pipes.append (                                          // add the bounding box for the top pipe
            get_rectangle (
                (pipes_count+2)*PIPE_WIDTH*3, 0,
                PIPE_WIDTH, top_height));
        pipes.append (                                          // add the bounding box for the bottom pipe
            get_rectangle (
                (pipes_count+2)*PIPE_WIDTH*3, position + GAP_HEIGHT,
                PIPE_WIDTH, bottom_height));
        top.set_sensitive (false);                              // we don't want fancy 3d buttons with hover style
        bottom.set_sensitive (false);                           // so set them to insensitive
        top.show ();                                            // and remember to display these
        bottom.show ();
        pipes_count ++;                                         // increase the number of rendered pipes
    }

    private Gdk.Rectangle get_rectangle (int x, int y, int width, int height) { // build a bounding box with a given parameters
        Gdk.Rectangle rect = new Gdk.Rectangle();
        rect.x = x;
        rect.y = y;
        rect.width = width;
        rect.height = height;
        return rect;
    }

}

int main (string[] args) {

    Gtk.init (ref args);

    var css_provider = new Gtk.CssProvider ();                  // Initialize a CSS provider
    try {
        css_provider.load_from_path ("flappy.css");             // from the flappy.css file in the current directory
    } catch (GLib.Error e) {
        warning ("Error loading css styles from %s: %s",        // warn in case of an error
                    "flappy.css", e.message);
    }

    Gtk.StyleContext.add_provider_for_screen (                  // use the css provider
        Gdk.Screen.get_default (),                              // on the default screen
        css_provider,
        Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);

    var window = new Gtk.Window ();                             // Set up a window
    window.window_position = Gtk.WindowPosition.CENTER;         // centered on the screen
    window.title = "FlappyGnome";                               // proudly displaying the application name in the titlebar
    window.set_size_request (WIN_WIDTH, WIN_HEIGHT);            // with an appropriate size requested
    window.resizable = false;                                   // as we don't want to deal with dynamic resizing for now
    window.destroy.connect (Gtk.main_quit);                     // and quit the application when this window is closed

    var box = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);        // add a box representing the content area

    var scrolled_window = new Gtk.ScrolledWindow (null, null);  // Add a scrollable area
    scrolled_window.set_policy (Gtk.PolicyType.ALWAYS,          // always show the horizontal scrollbar
                                Gtk.PolicyType.NEVER);          // but never show the vertical one
    scrolled_window.expand = true;                              // use all available space for this component
    scrolled_window.set_placement (Gtk.CornerType.BOTTOM_LEFT); // move the scrollable content below the horizontal scrollbar

    var ground = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 0);   // static component without scrolling
    ground.set_size_request (WIN_WIDTH, GROUND_HEIGHT);         // with a fixed size
    ground.get_style_context ().add_class ("ground");           // used as the floor

    var restart_button = new Gtk.Button.from_icon_name (        // create a restart button
                                "view-refresh-symbolic",        // with a refresh icon
                                Gtk.IconSize.DND);              // with an image 32x32 px
    restart_button.set_size_request (64, 64);
    ground.pack_start (restart_button, false, false, 0);        // add the restart button to the bottom left corner
    restart_button.margin = 20;                                 // add a margin to avoid the restart button expanding to the window border
    restart_button.can_focus = false;                           // disable can_focus to avoid stealing space keypress after clicked

    var score_label = new Gtk.Label ("");                       // create a score widget
    ground.pack_end (score_label, false, false, 0);             // pack it in the bottom right corner
    score_label.margin = 20;                                    // add a margin to avoid the score label expanding to the window border

    box.add (scrolled_window);                                  // add the scrolled area to the content area
    box.add (ground);                                           // add the floor to the content area
    window.add (box);                                           // and add the content container to the main window

    var game_area = new GameArea ();                            // Add the game area
    scrolled_window.add (game_area);                            // to the scrollable to support scrolling, as we are doing a side-scroller

    game_area.score_changed.connect ( (score) => {              // connect to the score changed signal
        score_label.set_markup (SCORE_TEMPLATE.printf (score)); // and update the score label on each change
    });

    restart_button.clicked.connect ((event) => {                // connect to the restart button clicked signal
        game_area.setup_new_game ();                            // to start a new game
    });
    game_area.setup_new_game ();                                // setup a new game
    window.show_all ();                                         // Show the window and each component withing

    Gtk.main ();                                                // Start the application
    return 0;
}

