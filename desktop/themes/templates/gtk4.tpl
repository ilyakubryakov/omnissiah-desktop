# theme:out=gtk4.css
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

:root {
    --accent-color: {{accent}};
    --accent-bg-color: {{accent}};
    --accent-fg-color: {{dark_background}};
    --window-bg-color: {{window_background}};
    --window-fg-color: {{foreground}};
    --view-bg-color: {{dark_background}};
    --view-fg-color: {{foreground}};
    --headerbar-bg-color: {{light_background}};
    --headerbar-fg-color: {{foreground}};
    --headerbar-border-color: {{selection}};
    --card-bg-color: {{light_background}};
    --card-fg-color: {{foreground}};
    --dialog-bg-color: {{background}};
    --dialog-fg-color: {{foreground}};
    --popover-bg-color: {{light_background}};
    --popover-fg-color: {{foreground}};
    --sidebar-bg-color: {{dark_background}};
    --sidebar-fg-color: {{foreground}};
    --sidebar-backdrop-color: {{background}};
    --destructive-bg-color: {{red}};
    --destructive-fg-color: {{dark_background}};
    --success-bg-color: {{green}};
    --success-fg-color: {{dark_background}};
    --warning-bg-color: {{yellow}};
    --warning-fg-color: {{dark_background}};
}
/* theme:metrics-begin */
/* GTK4/adwaita composites may retain their own internal spacing. */
button:not(.titlebutton), entry, spinbutton {
    border-radius: {{radius_control}}px;
    min-height: {{control_min_height}}px;
    padding: {{padding_y}}px {{padding_x}}px;
    border-width: {{border_width}}px;
}
spinbutton button, spinbutton entry { min-height: 0; padding: 0; }
button:focus-visible, entry:focus-within, spinbutton:focus-within {
    outline-style: solid;
    outline-width: {{focus_width}}px;
    outline-color: @accent_color;
}
popover > contents {
    border-radius: {{radius_card}}px;
    padding: {{space_unit}}px;
}
list row, listview row {
    border-radius: {{radius_small}}px;
    min-height: {{row_min_height}}px;
    padding: {{padding_y}}px {{space_unit}}px;
}
window.background:not(.maximized):not(.fullscreen) {
    border-radius: {{window_rounding}}px;
}
/* theme:metrics-end */
