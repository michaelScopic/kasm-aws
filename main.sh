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

    msg_note "Remaking '$BUILD_DIR'."
    rm -rf $BUILD_DIR &>/dev/null
    mkdir -v $BUILD_DIR &&
        cd $BUILD_DIR

    return
}

function install_nala() {
    # Install dependencies first
    sudo apt install -y libpython3.9 tar sed

    # Install nala
    if [ "$(curl -O https://deb.volian.org/volian/pool/main/n/nala-legacy/nala-legacy_0.11.0_amd64.deb)" ]; then
        msg_error "Cannot fetch nala .deb file."
        msg_note "Continuing with only 'apt-get' (slower)."
        nala_or_apt="apt"
    else
        sudo dpkg -i ./*.deb
        nala_or_apt="nala"

        read -rp "Do you want to try to fetch the fastest mirrors for 'nala'? [Y/n]: " fetch_mirror
        if [ "${fetch_mirror,,}" == "y" ] || [ "$fetch_mirror" == "" ]; then
            msg_info "User answered 'yes'. Fetching mirrors..."
            sudo nala fetch --auto
        else
            msg_info "User answered 'no'. Not fetching mirrors."
        fi
    fi

    return 
}

function prep_kasm() {
    echo "
|-------------------------|
| Going to install Kasm.  |
|-------------------------| 
| Minimum specs for Kasm: |
|   >= 2 vCPUs            |
|   >= 4 GB RAM           |
|   >= 50 GB free storage |
|-------------------------|"
    read -rp "Ready to install Kasm? [y/N]: " install_kasm

    if [ "${install_kasm,,}" != "y" ]; then
        msg_error "User answered 'no'. Aborting!"
        return 1
    fi

    msg_info "Fetching the Kasm install script..."
    # Install Kasm and extract the .tar
    if [ "$(curl -O https://kasm-static-content.s3.amazonaws.com/kasm_release_1.12.0.d4fd8a.tar.gz)" ]; then
        msg_error "Cannot fetch the Kasm install script! Aborting!"
        return 1
    fi

    msg_info "Extracting the Kasm .tar file..."
    if [ ! "$(tar -xf kasm_release*.tar.gz)" ]; then
        cd kasm_release
    else
        msg_error "Unable to extract the Kasm .tar file. Aborting!"
        return 1
    fi

    if [ "$nala_or_apt" == "apt" ]; then
        # Use 'nala' instead of 'apt-get' when installing Kasm
        msg_note "Modifying install script to use 'nala' instead of 'apt-get'..."
        sed 's/apt-get/nala/g' install_dependencies.sh >install_dependencies-nala.sh
        mv install_dependencies-nala.sh install_dependencies.sh
    fi

    return
}

function kasm_questions() {
    # Ask user questions before install
    msg_info "Going to ask user questions before running the Kasm install script..."
    read -rp "Do you want the install script to be verbose? [y/N] (default: n): " script_verbose
    read -rp "Enter your ADMIN password here (or press 'enter' to skip this): " admin_passwd
    read -rp "Enter you USER password here (or press 'enter' to skip this): " user_passwd
    read -rp "Enter swap size in megabites (or press 'enter' to let the script take care of swap) (eg: 4096): " swap_size
    echo ""

    # Evaluate what the user answered to above questions
    if [ "${script_verbose,,}" = "" ] || [ "${script_verbose,,}" == "n" ]; then
        msg_info "Verbose: ${red}NO"
    elif [ "${script_verbose,,}" == "y" ]; then
        msg_info "Verbose: ${green}YES"
        KASM_OPTIONS="--verbose"
    fi

    if [ "$admin_passwd" != "" ]; then
        msg_info "ADMIN password: ${blue}$admin_passwd"
        KASM_OPTIONS="$KASM_OPTIONS --admin-password $admin_passwd"
    else
        msg_info "ADMIN password: ${red}[SKIP]"
    fi

    if [ "$user_passwd" != "" ]; then
        msg_info "USER password: ${blue}$user_passwd"
        KASM_OPTIONS="$KASM_OPTIONS --user-password $user_passwd"
    else
        msg_info "USER password: ${red}[SKIP]"
    fi

    case $swap_size in
    '')
        msg_info "Swap size: ${red}[SKIP]"
        ;;
    *[!0-9]*)
        msg_info "Swap size: ${red}[INVALID, IGNORED]"
        ;;
    *)
        msg_info "Swap size: ${blue}$swap_size${reset} MB"
        KASM_OPTIONS="$KASM_OPTIONS --swap-size $swap_size"
        ;;
    esac

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
}


#sudo bash ./install.sh $KASM_OPTIONS

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
        case $2 in
            --nala)
                msg_note "Going to use 'nala'"
                nala_or_apt="nala"
                ;;
            --apt)
                msg_note "Going to use 'apt-get'"
                nala_or_apt="apt"
                ;;
        esac
        prep_kasm
        kasm_questions
        ;;
    *)
        init &>/dev/null
        msg_error "Unknown argument: '$1'"
        msg_error "Valid arguments are: 'all', 'kasm'"
        exit 225
esac


