# Select the NVIDIA open kernel package matching the installed kernel(s).
# Omarchy ISOs use linux-omarchy with prebuilt modules; standard Arch installs
# without linux-omarchy use nvidia-open (when already active for stock linux)
# or nvidia-open-dkms with matching kernel headers.
_omarchy_nvidia_open_packages() {
  local modules_dir="${OMARCHY_KERNEL_MODULES_DIR:-/usr/lib/modules}"
  local -a kernels=()
  local pkgbase_file kernel had_nullglob=0

  shopt -q nullglob && had_nullglob=1
  shopt -s nullglob
  for pkgbase_file in "$modules_dir"/*/pkgbase; do
    read -r kernel <"$pkgbase_file"
    [[ -n $kernel ]] && kernels+=("$kernel")
  done
  (( had_nullglob )) || shopt -u nullglob

  if (( ${#kernels[@]} == 0 )); then
    printf '%s\n' linux-omarchy-nvidia-open
    return
  fi

  for kernel in "${kernels[@]}"; do
    if [[ $kernel == "linux-omarchy" ]]; then
      printf '%s\n' linux-omarchy-nvidia-open
      return
    fi
  done

  if (( ${#kernels[@]} == 1 )) && [[ ${kernels[0]} == "linux" ]] && omarchy-pkg-present nvidia-open; then
    printf '%s\n' nvidia-open
    return
  fi

  printf '%s\n' nvidia-open-dkms
  for kernel in "${kernels[@]}"; do
    case "$kernel" in
      linux | linux-lts | linux-zen | linux-hardened)
        printf '%s\n' "${kernel}-headers"
        ;;
    esac
  done
}

# The NVIDIA N1x laptop's on-package GPU (10de:2e06) is handled by
# install/hardware/n1x.sh: whether the GPU may drive the panel depends on the
# system firmware and on the DKMS build, and there are no 32-bit libraries.
if omarchy-hw-aarch64-n1x; then
  echo "NVIDIA N1x platform detected; GPU driver policy is owned by hardware/n1x.sh"
elif lspci | grep -qi 'nvidia'; then
  # The 32-bit libraries come from multilib, which only x86_64 has.
  if omarchy-hw-nvidia-gsp; then
    mapfile -t PACKAGES < <(_omarchy_nvidia_open_packages)
    PACKAGES+=(nvidia-utils)
    if omarchy-hw-x86; then
      PACKAGES+=(lib32-nvidia-utils)
    fi
    PACKAGES+=(libva-nvidia-driver)
  elif omarchy-hw-nvidia-without-gsp; then
    PACKAGES=(nvidia-580xx-dkms nvidia-580xx-utils)
    if omarchy-hw-x86; then
      PACKAGES+=(lib32-nvidia-580xx-utils)
    fi
  fi

  # Bail if no supported GPU
  if [[ -z ${PACKAGES+x} ]]; then
    echo "No compatible driver for your NVIDIA GPU. See: https://wiki.archlinux.org/title/NVIDIA"
    unset -f _omarchy_nvidia_open_packages
    exit 0
  fi

  # Local models run in Podman, which reaches the GPU through the CDI spec the
  # container toolkit writes.
  PACKAGES+=(nvidia-container-toolkit)

  omarchy-pkg-add "${PACKAGES[@]}"

  # Per-session Hyprland NVIDIA env vars are handled by default/hypr/nvidia.lua.

  # Configure modprobe for early KMS, fbdev, and VRAM preservation across sleep
  nvidia_modprobe="${OMARCHY_NVIDIA_MODPROBE_CONFIG:-/etc/modprobe.d/nvidia.conf}"
  mkdir -p "$(dirname "$nvidia_modprobe")"
  cat > "$nvidia_modprobe" <<'EOF'
options nvidia_drm modeset=1 fbdev=1
options nvidia NVreg_PreserveVideoMemoryAllocations=1
EOF

  # Configure mkinitcpio for early loading
  nvidia_mkinitcpio="${OMARCHY_NVIDIA_MKINITCPIO_CONFIG:-/etc/mkinitcpio.conf.d/nvidia.conf}"
  mkdir -p "$(dirname "$nvidia_mkinitcpio")"
  cat > "$nvidia_mkinitcpio" <<'EOF'
MODULES+=(nvidia nvidia_modeset nvidia_uvm nvidia_drm)
EOF

  # Enable NVIDIA power-management sleep units when packaged by nvidia-utils
  systemd_unit_dir="${OMARCHY_SYSTEMD_UNIT_DIR:-/usr/lib/systemd/system}"
  if command -v systemctl >/dev/null 2>&1; then
    for unit in nvidia-suspend.service nvidia-resume.service nvidia-hibernate.service; do
      if [[ -f $systemd_unit_dir/$unit ]]; then
        systemctl enable "$unit"
      fi
    done
  fi
fi

unset -f _omarchy_nvidia_open_packages
