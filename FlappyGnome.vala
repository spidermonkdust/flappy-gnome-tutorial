const int WIN_WIDTH = 1280;
const int WIN_HEIGHT = 720;
const int GAP_HEIGHT = 180;
const int PIPE_WIDTH = 80;
const int SCROLL_SPEED = 5;

const string SCORE_TEMPLATE = "Score: <b>%u</b>";

private enum GameState {
    INIT,
    PLAYING,
    GAME_OVER;
}

private class GameArea : Gtk.Layout {                           // Our GameArea inherits from Gtk.Layout to support
                                                                // adding child components, absolute positioning, scrolling
    private Gtk.Arrow birdie;                                   // The widget representing the player
    private Gtk.Label score_widget;                             // The label displaying the score
    private int pipes_count;                                    // The number of pipes currently rendered
    private GameState state;                                    // The current game state

    public GameArea () {
        birdie = new Gtk.Arrow (Gtk.ArrowType.RIGHT,            // Create the player, a right-pointing arrow
                                Gtk.ShadowType.NONE);           // without any shadows
        birdie.set_size_request (32, 32);                       // and with an average, square size

        score_widget = new Gtk.Label ("");                      // Create the label for displaying the score
        setup_new_game ();                                      // setup a new game
        can_focus = true;                                       // set can_focus flag to be able to catch keyboard events
        key_release_event.connect (on_key_released);            // handle key-release-event
    }

    private bool on_key_released (Gdk.EventKey event) {
        if (event.keyval == Gdk.Key.space) {                    // In case the space key was released
            if (state == GameState.INIT) {                      // If the game isn't started yet
                state = GameState.PLAYING;                      // set the game state to playing
                add_tick_callback (game_screen_update);         // add a tick callback to start the animation
            }
        }
        return false;
    }

    private bool game_screen_update (Gtk.Widget w, Gdk.FrameClock fc) {
        Gtk.Scrollable scrollable = (Gtk.Scrollable) this;      // we need the scrollable instance from the game area
        Gtk.Adjustment adjustment = scrollable.get_hadjustment (); // to get the scrollbar
        adjustment.value += SCROLL_SPEED;                       // and scroll it with SCROLL_SPEED

        int child_x, child_y;
        move_child (score_widget, SCROLL_SPEED, 0,
                    out child_x, out child_y, true);            // move the score label, as we want that to "stay" in place
        move_child (birdie, SCROLL_SPEED, 0,
                    out child_x, out child_y, false);           // move the bird too, as that should be moving

        if (adjustment.value >= adjustment.upper - adjustment.page_size) { // in case we are on the last page, meaning no way to scroll further
            width += 3*PIPE_WIDTH;                              // increase the width of the game area
            add_pipe ();                                        // add another pipe
        }

        return adjustment.value < adjustment.upper - adjustment.page_size; // quit in case we have reached the end of the scrollbar
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

    private void setup_new_game () {
        set_size (2 * WIN_WIDTH,                                // Set the size to twice the width of the window for horizontal scrolling
                  WIN_HEIGHT - 13 );                            // and a height to fit in the window without adding a vertical scrollbar

        score_widget.set_markup (SCORE_TEMPLATE.printf (0));    // Initialize with 0 score

        pipes_count = 0;                                        // reset the pipes count

        put (birdie, PIPE_WIDTH * 2, WIN_HEIGHT / 3 * 2);       // Add the birdie at 2/3 of the height

        int initial_count = 2 * WIN_WIDTH / PIPE_WIDTH / 3 - 1; // Calculate the number of pipes to draw before starting the game

        while (pipes_count < initial_count)
            add_pipe ();                                        // Add the initial pipes

        put (score_widget, WIN_WIDTH - 100, 32);                // Add the score label at the top right corner
        show_all ();                                            // Show each child of the container

    }

    private void add_pipe () {
        int position = Random.int_range (GAP_HEIGHT,            // randomize the position of the gap between the pipes
                                         (int)height - 2 * GAP_HEIGHT);
        var top = new Gtk.Button ();                            // The pipe coming from the top
        top.set_size_request (PIPE_WIDTH, position);            // has a standard width going all the way down until the generated position
        put (top, (pipes_count+2)*PIPE_WIDTH*3, 0);             // we need some empty space for warmup, so we leave 2 pipes' space empty
        var bottom = new Gtk.Button ();
        bottom.set_size_request (PIPE_WIDTH,                    // the pipe from the bottom with standard width
                                (int)height - position - GAP_HEIGHT); // going down to the bottom
        put (bottom, (pipes_count+2)*PIPE_WIDTH*3,
                     position+GAP_HEIGHT);
        top.set_sensitive (false);                              // we don't want fancy 3d buttons with hover style
        bottom.set_sensitive (false);                           // so set them to insensitive
        top.show ();                                            // and remember to display these
        bottom.show ();
        pipes_count ++;                                         // increase the number of rendered pipes
    }

}

int main (string[] args) {

    Gtk.init (ref args);

    var window = new Gtk.Window ();                             // Set up a window
    window.window_position = Gtk.WindowPosition.CENTER;         // centered on the screen
    window.title = "FlappyGnome";                               // proudly displaying the application name in the titlebar
    window.set_size_request (WIN_WIDTH, WIN_HEIGHT);            // with an appropriate size requested
    window.resizable = false;                                   // as we don't want to deal with dynamic resizing for now
    window.destroy.connect (Gtk.main_quit);                     // and quit the application when this window is closed

    var scrolled_window = new Gtk.ScrolledWindow (null, null);  // Add a scrollable area
    window.add (scrolled_window);                               // to the main window

    var game_area = new GameArea ();                            // Add the game area
    scrolled_window.add (game_area);                            // to the scrollable to support scrolling, as we are doing a side-scroller

    window.show_all ();                                         // Show the window and each component withing

    Gtk.main ();                                                // Start the application
    return 0;
}

