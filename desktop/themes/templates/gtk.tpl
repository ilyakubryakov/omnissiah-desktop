# theme:out=gtk.css
# theme:comment=/*
@define-color theme_bg_color {{background}};
@define-color theme_fg_color {{foreground}};
@define-color theme_base_color {{dark_background}};
@define-color theme_text_color {{foreground}};
@define-color theme_selected_bg_color {{accent}};
@define-color theme_selected_fg_color {{dark_background}};
@define-color insensitive_bg_color {{light_background}};
@define-color insensitive_fg_color {{muted}};
@define-color borders {{selection}};
@define-color warning_color {{yellow}};
@define-color error_color {{red}};
@define-color success_color {{green}};
@define-color accent_color {{accent}};
@define-color accent_bg_color {{accent}};
@define-color accent_fg_color {{dark_background}};
@define-color window_bg_color {{window_background}};
@define-color window_fg_color {{foreground}};
@define-color view_bg_color {{dark_background}};
@define-color view_fg_color {{foreground}};
@define-color headerbar_bg_color {{light_background}};
@define-color headerbar_fg_color {{foreground}};
@define-color headerbar_border_color {{selection}};
@define-color card_bg_color {{light_background}};
@define-color card_fg_color {{foreground}};
@define-color dialog_bg_color {{background}};
@define-color dialog_fg_color {{foreground}};
@define-color popover_bg_color {{light_background}};
@define-color popover_fg_color {{foreground}};
@define-color sidebar_bg_color {{dark_background}};
@define-color sidebar_fg_color {{foreground}};

/* Breeze uses its own names for focused/backdrop selection states. */
@define-color theme_selected_bg_color_breeze @theme_selected_bg_color;
@define-color theme_selected_fg_color_breeze @theme_selected_fg_color;
@define-color theme_hovering_selected_bg_color_breeze @theme_selected_bg_color;
@define-color theme_unfocused_selected_bg_color_alt_breeze @theme_selected_bg_color;
@define-color theme_unfocused_selected_bg_color_breeze @theme_selected_bg_color;
@define-color theme_unfocused_selected_fg_color_breeze @theme_selected_fg_color;
@define-color theme_view_hover_decoration_color_breeze @accent_color;
@define-color theme_view_active_decoration_color_breeze @accent_color;

/* Breeze also contains literal colours; map common GTK3 surfaces explicitly. */
window, dialog, .background {
    background-color: @window_bg_color;
    color: @theme_fg_color;
}
headerbar, menubar, toolbar, .toolbar, .titlebar {
    background-color: @headerbar_bg_color;
    background-image: none;
    color: @headerbar_fg_color;
    border-color: @borders;
}
.view, treeview, iconview, textview, textview text, entry {
    background-color: @theme_base_color;
    color: @theme_text_color;
}
entry { border-color: @borders; }
entry:focus { border-color: @accent_color; }
button {
    background-color: @card_bg_color;
    color: @theme_fg_color;
    border-color: @borders;
}
/* Breeze draws window-control glyphs as background images. Preserve them. */
button:not(.titlebutton) { background-image: none; }
button:hover { background-color: @borders; }
button:checked, button:active, button.suggested-action {
    background-color: @accent_bg_color;
    color: @accent_fg_color;
}
button.destructive-action { color: @error_color; }
popover, menu, menuitem, tooltip {
    background-color: @popover_bg_color;
    color: @popover_fg_color;
}
menuitem:hover, row:selected, .view:selected, selection {
    background-color: @theme_selected_bg_color;
    color: @theme_selected_fg_color;
}
trough { background-color: @borders; }
highlight, progress { background-color: @accent_bg_color; }
*:disabled { color: @insensitive_fg_color; }
/* theme:metrics-begin */
/* Shared geometry is opt-in; colors remain in the palette provider. */
button:not(.titlebutton), entry, spinbutton {
    border-radius: {{radius_control}}px;
    min-height: {{control_min_height}}px;
    padding: {{padding_y}}px {{padding_x}}px;
    border-width: {{border_width}}px;
}
spinbutton button, spinbutton entry { min-height: 0; padding: 0; }
button:focus, entry:focus, spinbutton:focus {
    outline-style: solid;
    outline-width: {{focus_width}}px;
    outline-color: @accent_color;
}
menu, popover, popover.background {
    border-radius: {{radius_card}}px;
    padding: {{space_unit}}px;
}
menuitem, list row {
    border-radius: {{radius_small}}px;
    min-height: {{row_min_height}}px;
    padding: {{padding_y}}px {{space_unit}}px;
}
window.background:not(.maximized):not(.fullscreen), decoration {
    border-radius: {{window_rounding}}px;
}
/* theme:metrics-end */
