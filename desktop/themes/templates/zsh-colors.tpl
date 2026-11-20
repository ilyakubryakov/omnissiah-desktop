# theme:out=colors.zsh
# Sourced from .zshrc. Holds only what carries a colour value, so the palette
# lives in one place instead of being pasted into fzf flags and LS_COLORS.

# dircolors gives the base; these overrides pull directories, links and the
# file types this machine actually edits onto the palette.
LS_COLORS="$LS_COLORS:di=1;38;2;{{blue:sgr}}:ln=38;2;{{cyan:sgr}}:ex=38;2;{{green:sgr}}"
LS_COLORS="$LS_COLORS:*.md=38;2;{{yellow:sgr}}:*.yaml=38;2;{{yellow:sgr}}:*.yml=38;2;{{yellow:sgr}}"
LS_COLORS="$LS_COLORS:*.tf=38;2;{{magenta:sgr}}:*.json=38;2;{{yellow:sgr}}"
export LS_COLORS

# Suggestions are a hint, not text: the dim foreground keeps them clearly
# behind what is actually typed.
ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE='fg={{muted}}'

# One palette for both fzf users: $FZF_DEFAULT_OPTS below and fzf-tab, which
# does not read that variable and needs its own copy.
#
# Quoted, and that is load-bearing: .zshrc sets EXTENDED_GLOB, under which a
# bare `#` is a glob operator. Unquoted these parse fine at startup (the option
# is set further down) but blow up with "no matches found" when this file is
# re-sourced from the prompt on a live theme switch - leaving the old palette
# in place and the switch half-applied.
THEME_FZF_COLORS=(
  '--color=fg:{{foreground}},bg:-1,hl:{{blue}}'
  '--color=fg+:{{bright_white}},bg+:{{selection}},hl+:{{bright_blue}}'
  '--color=info:{{cyan}},prompt:{{bright_yellow}},pointer:{{bright_red}}'
  '--color=marker:{{red}},spinner:{{magenta}},header:{{muted}},border:{{dim_foreground}}'
)

# The transient prompt's timestamp.
THEME_DIM='{{dim_foreground}}'
