/*
* Copyright (c) 2011-2016 Felipe Escoto (https://github.com/Philip-Scott/Notes-up)
*
* This program is free software; you can redistribute it and/or
* modify it under the terms of the GNU General Public
* License as published by the Free Software Foundation; either
* version 2 of the License, or (at your option) any later version.
*
* This program is distributed in the hope that it will be useful,
* but WITHOUT ANY WARRANTY; without even the implied warranty of
* MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
* General Public License for more details.
*
* You should have received a copy of the GNU General Public
* License along with this program; if not, write to the
* Free Software Foundation, Inc., 59 Temple Place - Suite 330,
* Boston, MA 02111-1307, USA.
*
* Authored by: Felipe Escoto <felescoto95@hotmail.com>
*/

public class ENotes.Window : Gtk.ApplicationWindow {
    private ENotes.Editor editor;
    private ENotes.Headerbar headerbar;
    private ENotes.PagesList pages_list;
    private ENotes.Sidebar sidebar;
    private ENotes.PageInfoEditor page_info;
    private ENotes.ViewEditStack view_edit_stack;
    private ENotes.Viewer viewer;

    private Gtk.Paned pane1;
    private Gtk.Paned pane2;

    public Window (ENotes.Application app) {
        Object (application: app);
        DatabaseTable.init (ENotes.NOTES_DB);

        var change_mode = new SimpleAction ("change-mode", null);
        var save_action = new SimpleAction ("save", null);
        var close_action = new SimpleAction ("close-action", null);
        var new_action = new SimpleAction ("new-action", null);
        var find_action = new SimpleAction ("find-action", null);
        var bookmark_action = new SimpleAction ("bookmark-action", null);
        var bold_action = new SimpleAction ("bold-action", null);
        var italics_action = new SimpleAction ("italics-action", null);
        var strike_action = new SimpleAction ("strike-action", null);
        var page_info_action = new SimpleAction ("page-info-action", null);

        add_action (change_mode);
        add_action (save_action);
        add_action (close_action);
        add_action (new_action);
        add_action (find_action);
        add_action (bookmark_action);
        add_action (bold_action);
        add_action (italics_action);
        add_action (strike_action);
        add_action (page_info_action);

        app.set_accels_for_action ("win.change-mode", {ENotes.Key.CHANGE_MODE.to_key() });
        app.set_accels_for_action ("win.save", {ENotes.Key.SAVE.to_key()});
        app.set_accels_for_action ("win.close-action", {ENotes.Key.QUIT.to_key()});
        app.set_accels_for_action ("win.new-action", {ENotes.Key.NEW_PAGE.to_key()});
        app.set_accels_for_action ("win.find-action", {ENotes.Key.FIND.to_key()});
        app.set_accels_for_action ("win.bookmark-action", {ENotes.Key.BOOKMARK.to_key()});
        app.set_accels_for_action ("win.bold-action", {ENotes.Key.BOLD.to_key()});
        app.set_accels_for_action ("win.italics-action", {ENotes.Key.ITALICS.to_key()});
        app.set_accels_for_action ("win.strike-action", {ENotes.Key.STRIKE.to_key()});
        app.set_accels_for_action ("win.page-info-action", {ENotes.Key.PAGE_INFO.to_key()});

        build_ui ();

        change_mode.activate.connect (toggle_edit);
        save_action.activate.connect (save);
        close_action.activate.connect (request_close);
        new_action.activate.connect (new_page);
        find_action.activate.connect (headerbar.show_search);
        bookmark_action.activate.connect (headerbar.bookmark_button.main_action);
        bold_action.activate.connect (bold_act);
        italics_action.activate.connect (italics_act);
        strike_action.activate.connect (strike_act);
        page_info_action.activate.connect (toggle_page_info);

        Sidebar.get_instance ().first_start ();

        var provider = new Gtk.CssProvider ();
        provider.load_from_resource ("/com/github/philip-scott/notes-up/Application.css");
        Gtk.StyleContext.add_provider_for_screen (Gdk.Screen.get_default (), provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);

        app.state.notify["style-scheme"].connect (() => {
            get_style_context ().remove_class ("solarized-light");
            get_style_context ().remove_class ("solarized-dark");

            if (app.state.style_scheme != "high-contrast") {
                get_style_context ().add_class (app.state.style_scheme);
            }
        });

        load_settings ();
    }

    private void build_ui () {
        page_info = new ENotes.PageInfoEditor ();

        headerbar = new ENotes.Headerbar (page_info);

        set_titlebar (headerbar);

        set_events (Gdk.EventMask.BUTTON_PRESS_MASK);

        pane1 = new Gtk.Paned (Gtk.Orientation.HORIZONTAL);
        pane2 = new Gtk.Paned (Gtk.Orientation.HORIZONTAL);
        sidebar = ENotes.Sidebar.get_instance ();
        pages_list = ENotes.PagesList.get_instance ();

        view_edit_stack = ENotes.ViewEditStack.get_instance ();
        editor = ENotes.ViewEditStack.get_instance ().editor;
        viewer = ENotes.ViewEditStack.get_instance ().viewer;

        var main_area_grid = new Gtk.Grid ();
        main_area_grid.orientation = Gtk.Orientation.VERTICAL;

        main_area_grid.add (page_info);
        main_area_grid.add (view_edit_stack);

        pane1.pack1 (sidebar, false, false);
        pane1.pack2 (pane2, true, false);
        pane2.pack1 (pages_list, false, false);
        pane2.pack2 (main_area_grid, true, false);

        this.move (settings.pos_x, settings.pos_y);
        this.add (pane1);
        this.show_all ();
    }

    private void bold_act () {
        if (editor_open ()) ENotes.ViewEditStack.get_instance ().editor.bold_button.clicked ();
    }

    private void italics_act () {
        if (editor_open ()) ENotes.ViewEditStack.get_instance ().editor.italics_button.clicked ();
    }

    private void strike_act () {
        if (editor_open ()) ENotes.ViewEditStack.get_instance ().editor.strike_button.clicked ();
    }

    private bool editor_open () {
        return app.state.mode == ENotes.Mode.EDIT && app.state.opened_page != null;
    }

    protected override bool delete_event (Gdk.EventAny event) {
        int width;
        int height;
        int x;
        int y;

        editor.save_file ();
        get_size (out width, out height);
        get_position (out x, out y);

        settings.pos_x = x;
        settings.pos_y = y;
        settings.notebook_panel_size = pane1.position;
        settings.panel_size = pane2.position;
        settings.window_width = width;
        settings.window_height = height;
        settings.mode = app.state.mode;
        settings.style_scheme = app.state.style_scheme;
        settings.last_notebook = app.state.opened_notebook != null ? (int) app.state.opened_notebook.id : 0;
        settings.last_page = app.state.opened_page != null ? (int) app.state.opened_page.id : 0;
        settings.show_page_info = app.state.show_page_info;

        settings.editor_font = app.state.editor_font;
        settings.editor_scheme = app.state.editor_scheme;
        settings.line_numbers = app.state.editor_show_line_numbers;
        settings.auto_indent = app.state.editor_auto_indent;

        Trash.get_instance ().clear_files ();

        return false;
    }

    private void load_settings () {
        resize (settings.window_width, settings.window_height);
        pane1.position = settings.notebook_panel_size;
        pane2.position = settings.panel_size;

        app.state.mode = ENotes.Mode.get_mode (settings.mode);

        app.state.open_notebook (settings.last_notebook);

        if (settings.last_page != 0) {
            app.state.open_page (settings.last_page);
        }

        app.state.set_style (settings.style_scheme);
        app.state.editor_scheme = settings.editor_scheme;
        app.state.show_page_info = settings.show_page_info;
        app.state.editor_font = settings.editor_font;
        app.state.editor_show_line_numbers = settings.line_numbers;
        app.state.editor_auto_indent = settings.auto_indent;
    }

    private void new_page () {
        pages_list.new_blank_page ();
    }

    private void request_close () {
        close ();
    }

    private void save () {
        editor.save_file ();
    }

    public void set_mode (ENotes.Mode mode) {
        app.state.mode = mode;
    }

    public void toggle_edit () {
        ENotes.Mode mode = app.state.mode;

        if (mode == ENotes.Mode.EDIT) {
            app.state.mode = ENotes.Mode.VIEW;
        } else {
            app.state.mode = ENotes.Mode.EDIT;
        }
    }

    public void show_app () {
        show ();
        present ();
    }

    public void toggle_page_info () {
        app.state.show_page_info = !app.state.show_page_info;
    }
}
