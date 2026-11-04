function fish_greeting
    echo -ne '\x1b[38;5;16m'  # Set colour to primary
    figlet -f slant ""
    set_color normal
    command -v fastfetch &> /dev/null && python3 ~/.config/fastfetch/gen-greeting.py; and fastfetch -c $HOME/.config/fastfetch/greeting.jsonc --key-padding-left 5
end
