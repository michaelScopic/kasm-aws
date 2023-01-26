#!/usr/bin/env bash

# --- Initalization function ---
function init() {

    # - Set colors -
    # Normal text
    reset='\e[0m'
    # Bold text
    bold='\e[1m'
    # Red
    red='\e[31m'
    redbg='\e[41m'
    # Green
    green='\e[32m'
    greenbg='\e[42m'
    # Yellow
    yellow='\e[33m'
    yellowbg='\e[43m'
    # Blue
    blue='\e[34m'
    bluebg='\e[44m'
    # Purple
    purple='\e[35m'
    purplebg='\e[45m'
    # Cyan
    cyan='\e[36m'
    cyanbg='\e[46m'

    # - Set 'info', 'error', 'note', message functions -
    msg_info() {
        echo -e "${yellow}${bold}[INFO]${reset} $@ ${reset}"
    }

    msg_error() {
        echo -e "${red}${bold}[ERROR]${reset} $@ ${reset}"
    }

    msg_note() {
        echo -e "${blue}${bold}[NOTE]${reset} $@ ${reset}"
    }

    # - Store user's current dir as a var -
    CURRENT_DIR=$(pwd)
    BUILD_DIR="$CURRENT_DIR/.tmp"

    # Remake build dir
    msg_note "Remaking '$BUILD_DIR'."
    rm -rf $BUILD_DIR &>/dev/null
    mkdir -v $BUILD_DIR &&
        cd $BUILD_DIR

    echo ""

    return
}

function install_nala() {
    # Ask if user wants to install nala, if it is not already installed
    if [ ! "$(command -v nala >/dev/null)" ]; then
        msg_note "'nala' does not seem to be installed. Do you want to install it and use it instead instead of 'apt-get'?"
        read -rp "Install 'nala'? [y/N]: " install_nala_question

        if [ "$install_nala_question" != "y" ]; then
            msg_info "User denied installing nala."
            sleep 0.5
            return 0
        fi
    else
        # If nala is found, use that and exit this function
        msg_note "Found 'nala'. Going to use that instead of 'apt-get'."
        nala_or_apt="nala"
        return 0
    fi

    # Install nala
    msg_note "Installing prerequisites for nala..."
    sudo apt install -y --no-install-recommends libpython3.9 curl
    curl -O https://deb.volian.org/volian/pool/main/n/nala-legacy/nala-legacy_0.11.0_amd64.deb &&
        sudo dpkg -i ./*.deb &&
        nala_or_apt="nala"

    # Ask user if they want to try to get the fastest mirrors with nala
    read -rp "Do you want to try to fetch the fastest mirrors for 'nala'? [Y/n]: " fetch_mirror
    if [ "${fetch_mirror,,}" == "y" ] || [ "$fetch_mirror" == "" ]; then
        msg_info "User answered 'yes'. Fetching mirrors..."
        sudo nala fetch --auto
    else
        msg_info "User answered 'no'. Not fetching mirrors."
    fi

    return
}

function prep_kasm() {
    echo -e "
|-------------------------|
|${yellow} Going to install Kasm.${reset}  |
|-------------------------| 
|${cyanbg} Minimum specs for Kasm:${reset} |
|${blue}   >= 2 vCPUs${reset}            |
|${blue}   >= 4 GB RAM${reset}           |
|${blue}   >= 50 GB ${red}free${reset}${blue} storage${reset} |
|-------------------------|"
    read -rp "Ready to install Kasm? [y/N]: " install_kasm

    if [ "${install_kasm,,}" != "y" ]; then
        msg_error "User answered 'no'. Aborting!"
        exit 1
    fi

    # Install needed dependencies first
    msg_note "Installing prerequisites before fetching the Kasm install script..."
    msg_info "Installing: ${blue}tar sed curl"
    sudo apt install -y --no-install-recommends tar sed curl

    msg_info "Fetching the Kasm install script..."
    # Fetch the install script
    if [ "$(curl -O https://kasm-static-content.s3.amazonaws.com/kasm_release_1.12.0.d4fd8a.tar.gz)" ]; then
        msg_error "Cannot fetch the Kasm install script! Aborting!"
        return 1
    fi

    # Extract tar
    msg_info "Extracting the Kasm .tar file..."
    if [ ! "$(tar -xf kasm_release*.tar.gz)" ]; then
        cd kasm_release
    else
        msg_error "Unable to extract the Kasm .tar file. Aborting!"
        return 1
    fi

    if [ "$nala_or_apt" == "apt" ]; then
        # Use 'nala' instead of 'apt-get' when installing Kasm
        ## This does not work yet. :shrug:
        msg_note "Modifying install script to use 'nala' instead of 'apt-get'..."
        sed 's/apt-get/nala/g' install_dependencies.sh >install_dependencies-nala.sh
        mv install_dependencies-nala.sh install_dependencies.sh
    fi

    return
}

function kasm_questions() {
    echo ""
    # Ask user questions before install
    msg_info "Going to ask user questions before running the Kasm install script..."
    read -rp "Do you want the install script to be verbose? [y/N] (default: n): " script_verbose
    read -rp "Enter your ADMIN password here (or press 'enter' to skip this): " admin_passwd
    read -rp "Enter you USER password here (or press 'enter' to skip this): " user_passwd
    read -rp "Enter swap size in megabites (or press 'enter' to let the script take care of swap) (eg: 4096): " swap_size
    echo ""
    # Ask user if they want to pass additional arguments to the script
    msg_note "You can exit this script and run '${cyan}sudo bash .tmp/kasm_release/./install.sh --help${reset}' to see all possible options."
    msg_note "If you want to pass any addtional arguments to the Kasm install script, put them here."
    msg_note "Leaving this question empty will just skip this."
    read -rp "Additional arguments: " kasm_add_options
    echo ""

    # Evaluate what the user answered to above questions
    if [ "${script_verbose,,}" = "" ] || [ "${script_verbose,,}" == "n" ]; then
        # If user said 'n' or pressed enter, then dont use verbose
        msg_info "Verbose: ${red}NO"
    elif [ "${script_verbose,,}" == "y" ]; then
        msg_info "Verbose: ${green}YES"
        KASM_OPTIONS="--verbose"
    fi

    if [ "$admin_passwd" != "" ]; then
        # If answer is not empty, use that as the admin password
        msg_info "ADMIN password: ${blue}$admin_passwd"
        KASM_OPTIONS="$KASM_OPTIONS --admin-password $admin_passwd"
    else
        # If var is empty, skip setting password
        msg_info "ADMIN password: ${red}[SKIP]"
    fi

    if [ "$user_passwd" != "" ]; then
        # If answer is not empty, use that as the user password
        msg_info "USER password: ${blue}$user_passwd"
        KASM_OPTIONS="$KASM_OPTIONS --user-password $user_passwd"
    else
        # Skip setting password if the var is empty
        msg_info "USER password: ${red}[SKIP]"
    fi

    case $swap_size in
    '')
        # If answer is empty, skip setting swap
        msg_info "Swap size: ${red}[SKIP]"
        ;;
    *[!0-9]*)
        # If answer contains letters, it is invalid and will be ignored
        msg_info "Swap size: ${red}[INVALID; IGNORED]"
        ;;
    *)
        # If answer contains only numbers, then use that as swap size
        msg_info "Swap size: ${blue}$swap_size${reset} MB"
        KASM_OPTIONS="$KASM_OPTIONS --swap-size $swap_size"
        ;;
    esac

    if [ "$kasm_add_options" != "" ]; then
        # If user did passed any additional options, add them to $KASM_OPTIONS
        msg_info "Additional options: ${blue}$kasm_add_options"
        KASM_OPTIONS="$KASM_OPTIONS $kasm_add_options"
    else
        # If user did NOT pass any other options, then skip it
        msg_info "Additional options: ${red}[SKIP]"
    fi

    # Double check to make sure user is aware of their options
    echo "---------------------------"
    msg_info "Kasm script options: '${blue}$KASM_OPTIONS${reset}'"
    msg_info "Command pending to run: '${blue}sudo bash ./install.sh $KASM_OPTIONS${reset}'"
    read -rp "Are these options correct? [yes/no]: " check_options

    if [ "$check_options" != "yes" ]; then
        msg_error "User answered 'no'. Please re-run this script with your desired options."
        msg_error "QUTTING!"
        exit 1
    fi

    sleep 3

    msg_error "This script is not ready for production use."
    msg_error "By answering 'yes' to the next question, you acknowledge that this script may have bugs."
    read -rp "Run the Kasm install script? [yes/no] (default: no): " run_kasm_install
    if [ "$run_kasm_install" == "yes" ]; then
        msg_info "User answered 'yes'. Continuing with the Kasm install script..."
        sudo bash ./install.sh $KASM_OPTIONS
    else
        msg_error "User answered no. Refusing to run the Kasm install script."
        exit 1
    fi

    return 1
}
# Read options passed
case $1 in
all)
    init
    install_nala
    prep_kasm
    kasm_questions
    ;;
kasm)
    init
    prep_kasm
    kasm_questions
    ;;
*)
    init &>/dev/null
    msg_error "Unknown argument: '$1'"
    msg_error "Valid arguments are: 'all', 'kasm'"
    exit 225
    ;;
esac
