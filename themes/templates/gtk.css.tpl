
@define-color theme_selected_bg_color_breeze @theme_selected_bg_color;
@define-color theme_selected_fg_color_breeze @theme_selected_fg_color;
@define-color theme_hovering_selected_bg_color_breeze @theme_selected_bg_color;
@define-color theme_unfocused_selected_bg_color_alt_breeze @theme_selected_bg_color;
@define-color theme_unfocused_selected_bg_color_breeze @theme_selected_bg_color;
@define-color theme_unfocused_selected_fg_color_breeze @theme_selected_fg_color;
@define-color theme_view_hover_decoration_color_breeze @accent_color;
@define-color theme_view_active_decoration_color_breeze @accent_color;

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
