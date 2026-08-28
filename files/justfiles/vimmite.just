set shell := ["bash", "-euo", "pipefail", "-c"]

[doc('Install the image-baked Zim setup without overwriting shell configuration')]
[group('Vimmite')]
setup-zsh set_login_shell="false":
    #!/usr/bin/env bash
    set -euo pipefail

    user_name="$(id -un)"
    user_home="$(getent passwd "${user_name}" | cut -d: -f6)"
    template_dir="/usr/share/vimmite/zim"

    if [[ ! -d "${user_home}/.zim" ]]; then
        cp -a "${template_dir}/skel/.zim" "${user_home}/.zim"
        echo "Installed the image-baked Zim modules in ${user_home}/.zim"
    else
        echo "Keeping existing ${user_home}/.zim"
    fi

    if [[ ! -e "${user_home}/.zimrc" ]]; then
        install -m 0644 "${template_dir}/zimrc" "${user_home}/.zimrc"
        echo "Installed ${user_home}/.zimrc"
    else
        echo "Keeping existing ${user_home}/.zimrc"
    fi

    if [[ ! -e "${user_home}/.zshrc" ]]; then
        install -m 0644 "${template_dir}/zshrc" "${user_home}/.zshrc"
        echo "Installed ${user_home}/.zshrc"
    else
        echo "Keeping existing ${user_home}/.zshrc"
    fi

    ZIM_HOME="${user_home}/.zim" \
    ZIM_CONFIG_FILE="${user_home}/.zimrc" \
        zsh -c 'source /usr/share/vimmite/zim/zimfw.zsh init'

    if [[ "{{ set_login_shell }}" == "true" ]]; then
        sudo usermod --shell /usr/bin/zsh "${user_name}"
        echo "Zsh will be the login shell after the next login."
    else
        echo "Zim is ready. Run 'ujust setup-zsh true' to also select Zsh as the login shell."
    fi

[doc('Prepare the default network and verify system virtualization')]
[group('Vimmite')]
setup-virtualization:
    #!/usr/bin/env bash
    set -euo pipefail

    sockets=(
        virtqemud.socket
        virtnetworkd.socket
        virtstoraged.socket
        virtsecretd.socket
        virtnodedevd.socket
        virtnwfilterd.socket
    )

    sudo systemctl enable --now "${sockets[@]}"

    # The installer creates private home directories (0700). Grant only the
    # qemu service account directory traversal so libvirt can open ISO images
    # selected from ~/Downloads; this does not permit listing the home folder.
    if getent passwd qemu >/dev/null; then
        sudo setfacl --modify u:qemu:--x "${HOME}"
    fi

    if sudo virsh net-info default >/dev/null 2>&1; then
        sudo virsh net-autostart default
        if ! sudo virsh net-info default | grep -q '^Active:.*yes'; then
            sudo virsh net-start default
        fi
    else
        echo "The libvirt default network was not found." >&2
        exit 1
    fi

    virsh --connect qemu:///system uri
    echo "Virtualization is ready for this administrator account."

[doc('Opt into automatic mounting of labeled internal Btrfs and ext4 drives')]
[group('Vimmite')]
automount action="status":
    #!/usr/bin/env bash
    set -euo pipefail

    case "{{ action }}" in
        enable)
            sudo systemctl enable --now ublue-os-media-automount.service
            systemctl --no-pager --full status ublue-os-media-automount.service || true
            ;;
        disable)
            sudo systemctl disable --now ublue-os-media-automount.service
            echo "Automatic mounting is disabled. Existing transient mounts are left intact until reboot."
            ;;
        status)
            systemctl is-enabled ublue-os-media-automount.service || true
            systemctl is-active ublue-os-media-automount.service || true
            findmnt -rn -o TARGET,SOURCE,FSTYPE | grep '^/run/media/system/' || true
            ;;
        *)
            echo "Usage: ujust automount [status|enable|disable]" >&2
            exit 2
            ;;
    esac

[doc('Opt into the HyperX Cloud Alpha Wireless microphone-volume helper')]
[group('Vimmite')]
hyperx-mic action="status":
    #!/usr/bin/env bash
    set -euo pipefail

    unit="vimmite-hyperx-mic-volume.path"
    case "{{ action }}" in
        enable)
            echo "This enables a user path unit that sets a detected HyperX Cloud Alpha Wireless microphone to 90%."
            systemctl --user enable --now "${unit}"
            echo "HyperX microphone handling is enabled for this user."
            ;;
        disable)
            systemctl --user disable --now "${unit}"
            echo "HyperX microphone handling is disabled for this user."
            ;;
        status)
            systemctl --user is-enabled "${unit}" || true
            systemctl --user is-active "${unit}" || true
            ;;
        *)
            echo "Usage: ujust hyperx-mic [status|enable|disable]" >&2
            exit 2
            ;;
    esac

[doc('Install Moonlight, Sunshine, or both as optional user Flatpaks')]
[group('Vimmite')]
install-streaming component="moonlight":
    #!/usr/bin/env bash
    set -euo pipefail

    install_moonlight() {
        flatpak --user install --assumeyes --or-update flathub com.moonlight_stream.Moonlight
    }

    install_sunshine() {
        flatpak --user install --assumeyes --or-update flathub dev.lizardbyte.app.Sunshine
        flatpak run --command=additional-install.sh dev.lizardbyte.app.Sunshine
        echo "Sunshine's additional host integration completed. Reboot before testing capture and controller input."
    }

    case "{{ component }}" in
        moonlight)
            install_moonlight
            ;;
        sunshine)
            install_sunshine
            ;;
        both)
            install_moonlight
            install_sunshine
            ;;
        *)
            echo "Usage: ujust install-streaming [moonlight|sunshine|both]" >&2
            exit 2
            ;;
    esac

[doc('Enable, disable, or inspect the OpenSSH server and firewall rule')]
[group('Vimmite')]
ssh-server action="status":
    #!/usr/bin/env bash
    set -euo pipefail

    case "{{ action }}" in
        enable)
            sudo firewall-cmd --permanent --add-service=ssh
            sudo firewall-cmd --reload
            sudo systemctl enable --now sshd.service
            echo "SSH is enabled. Verify authentication before relying on remote access."
            ;;
        disable)
            sudo systemctl disable --now sshd.service
            if sudo firewall-cmd --permanent --query-service=ssh; then
                sudo firewall-cmd --permanent --remove-service=ssh
                sudo firewall-cmd --reload
            fi
            ;;
        status)
            systemctl is-enabled sshd.service || true
            systemctl is-active sshd.service || true
            firewall-cmd --query-service=ssh || true
            ;;
        *)
            echo "Usage: ujust ssh-server [status|enable|disable]" >&2
            exit 2
            ;;
    esac

[doc('Configure magic-packet Wake-on-LAN for a NetworkManager Ethernet connection')]
[group('Vimmite')]
wake-on-lan interface="" action="status":
    #!/usr/bin/env bash
    set -euo pipefail

    network_interface="{{ interface }}"
    if [[ -z "${network_interface}" ]]; then
        nmcli --fields DEVICE,TYPE,STATE,CONNECTION device status
        echo "Usage: ujust wake-on-lan <interface> [status|enable|disable]"
        exit 0
    fi

    if [[ "$(nmcli --get-values GENERAL.TYPE device show "${network_interface}")" != "ethernet" ]]; then
        echo "${network_interface} is not an Ethernet interface." >&2
        exit 1
    fi

    connection="$(nmcli --get-values GENERAL.CONNECTION device show "${network_interface}")"
    if [[ -z "${connection}" || "${connection}" == "--" ]]; then
        echo "${network_interface} has no active NetworkManager connection." >&2
        exit 1
    fi

    case "{{ action }}" in
        enable)
            if ! ethtool "${network_interface}" | grep -Eq 'Supports Wake-on:.*g'; then
                echo "${network_interface} does not report magic-packet Wake-on-LAN support." >&2
                exit 1
            fi
            sudo nmcli connection modify "${connection}" 802-3-ethernet.wake-on-lan magic
            echo "Wake-on-LAN is set to magic packets for '${connection}'. It applies after reconnect or reboot."
            ;;
        disable)
            sudo nmcli connection modify "${connection}" 802-3-ethernet.wake-on-lan default
            echo "Wake-on-LAN for '${connection}' is restored to NetworkManager's default."
            ;;
        status)
            nmcli --fields 802-3-ethernet.wake-on-lan connection show "${connection}"
            ethtool "${network_interface}" | grep -E 'Supports Wake-on:|Wake-on:' || true
            ;;
        *)
            echo "Usage: ujust wake-on-lan <interface> [status|enable|disable]" >&2
            exit 2
            ;;
    esac

[doc('Manage the legacy large-memory profile only on the GMKtec Ryzen AI MAX+ 395 host')]
[group('Vimmite')]
setup-ai-max action="status":
    #!/usr/bin/env bash
    set -euo pipefail

    cpu_model="$(sed -n 's/^model name[[:space:]]*: //p' /proc/cpuinfo | head -n1)"
    system_vendor="$(cat /sys/class/dmi/id/sys_vendor 2>/dev/null || true)"
    product_name="$(cat /sys/class/dmi/id/product_name 2>/dev/null || true)"
    expected_host=false

    if [[ "${cpu_model}" == *"AMD RYZEN AI MAX+ 395"* && "${system_vendor}" == "GMKtec" && "${product_name}" == "NucBox_EVO-X2" ]]; then
        expected_host=true
    fi

    case "{{ action }}" in
        status)
            echo "CPU: ${cpu_model}"
            echo "System: ${system_vendor} ${product_name}"
            echo "Recognized AI MAX host: ${expected_host}"
            rpm-ostree kargs
            ;;
        apply)
            if [[ "${expected_host}" != "true" ]]; then
                echo "Refusing to apply AI MAX kernel arguments on an unrecognized host." >&2
                exit 1
            fi
            echo "This enables AMD IOMMU and restores the large TTM/GTT values used for AI workloads."
            echo "The amdgpu.gttsize argument is deprecated upstream and remains a temporary compatibility setting."
            read -r -p "Create a new deployment with this legacy profile? [y/N] " answer
            if [[ ! "${answer}" =~ ^[Yy]$ ]]; then
                echo "No changes made."
                exit 0
            fi
            sudo rpm-ostree kargs \
                --delete-if-present=iommu=off \
                --append-if-missing=amd_iommu=on \
                --append-if-missing=ttm.pages_limit=30720000 \
                --append-if-missing=amdgpu.gttsize=122880
            echo "A reboot is required. IOMMU is no longer disabled."
            ;;
        undo)
            if [[ "${expected_host}" != "true" ]]; then
                echo "Refusing to alter AI MAX kernel arguments on an unrecognized host." >&2
                exit 1
            fi
            sudo rpm-ostree kargs \
                --delete-if-present=amd_iommu=on \
                --delete-if-present=ttm.pages_limit=30720000 \
                --delete-if-present=amdgpu.gttsize=122880
            echo "The AI MAX profile is removed from the next deployment. A reboot is required."
            ;;
        *)
            echo "Usage: ujust setup-ai-max [status|apply|undo]" >&2
            exit 2
            ;;
    esac
