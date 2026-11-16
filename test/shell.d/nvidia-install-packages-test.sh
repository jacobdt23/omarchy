#!/bin/bash

set -euo pipefail

source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/base-test.sh"

tmp_dir=$(mktemp -d)
trap 'rm -rf "$tmp_dir"' EXIT

make_modules_fixture() {
  local dir="$1"
  shift
  rm -rf "$dir"
  mkdir -p "$dir"
  local idx=0
  for pkgbase in "$@"; do
    mkdir -p "$dir/6.0.${idx}"
    printf '%s\n' "$pkgbase" >"$dir/6.0.${idx}/pkgbase"
    idx=$((idx + 1))
  done
}

# Stop at the driver transaction, before the setup script writes to /etc.
assert_packages() {
  local description="$1" architecture="$2" driver="$3" kernel="$4" has_nvidia_open="$5" expected="$6"
  local modules_dir="$tmp_dir/modules"
  if [[ $kernel == "empty" ]]; then
    make_modules_fixture "$modules_dir"
  else
    make_modules_fixture "$modules_dir" "$kernel"
  fi
  local actual
  actual=$(TEST_ARCH="$architecture" TEST_DRIVER="$driver" TEST_NVIDIA_OPEN="$has_nvidia_open" \
    OMARCHY_KERNEL_MODULES_DIR="$modules_dir" \
    bash -euo pipefail -c '
      lspci() { printf "%s\n" "3D controller: NVIDIA Corporation"; }
      omarchy-hw-aarch64-n1x() { return 1; }
      omarchy-hw-x86() { [[ $TEST_ARCH == "x86_64" ]]; }
      omarchy-hw-nvidia-gsp() { [[ $TEST_DRIVER == "gsp" ]]; }
      omarchy-hw-nvidia-without-gsp() { [[ $TEST_DRIVER == "legacy" ]]; }
      omarchy-pkg-present() { [[ ${1:-} == "nvidia-open" && $TEST_NVIDIA_OPEN == "1" ]]; }
      omarchy-pkg-add() {
        printf "%s\n" "$*"
        exit 0
      }
      source "$ROOT/install/hardware/nvidia.sh"
    ')
  [[ $actual == "$expected" ]] || fail "$description" "expected: $expected; actual: $actual"
  pass "$description"
}

assert_packages "ARM GSP selection uses native packages" aarch64 gsp linux-omarchy 0 \
  'linux-omarchy-nvidia-open nvidia-utils libva-nvidia-driver nvidia-container-toolkit'
assert_packages "ARM legacy selection omits x86 multilib" aarch64 legacy linux-omarchy 0 \
  'nvidia-580xx-dkms nvidia-580xx-utils nvidia-container-toolkit'
assert_packages "x86 GSP package selection adds multilib" x86_64 gsp linux-omarchy 0 \
  'linux-omarchy-nvidia-open nvidia-utils lib32-nvidia-utils libva-nvidia-driver nvidia-container-toolkit'
assert_packages "x86 legacy package selection stays unchanged" x86_64 legacy linux-omarchy 0 \
  'nvidia-580xx-dkms nvidia-580xx-utils lib32-nvidia-580xx-utils nvidia-container-toolkit'
assert_packages "Empty modules dir keeps linux-omarchy default" x86_64 gsp empty 0 \
  'linux-omarchy-nvidia-open nvidia-utils lib32-nvidia-utils libva-nvidia-driver nvidia-container-toolkit'
assert_packages "Stock Arch linux selects nvidia-open-dkms and linux-headers" x86_64 gsp linux 0 \
  'nvidia-open-dkms linux-headers nvidia-utils lib32-nvidia-utils libva-nvidia-driver nvidia-container-toolkit'
assert_packages "Stock Arch linux with nvidia-open installed keeps nvidia-open" x86_64 gsp linux 1 \
  'nvidia-open nvidia-utils lib32-nvidia-utils libva-nvidia-driver nvidia-container-toolkit'

# Verify modprobe and systemd sleep enablement without touching host /etc.
make_modules_fixture "$tmp_dir/modules" linux
mkdir -p "$tmp_dir/units"
touch "$tmp_dir/units/nvidia-suspend.service" "$tmp_dir/units/nvidia-resume.service" "$tmp_dir/units/nvidia-hibernate.service"
enabled_units=$(OMARCHY_KERNEL_MODULES_DIR="$tmp_dir/modules" \
  OMARCHY_NVIDIA_MODPROBE_CONFIG="$tmp_dir/etc/modprobe.d/nvidia.conf" \
  OMARCHY_NVIDIA_MKINITCPIO_CONFIG="$tmp_dir/etc/mkinitcpio.conf.d/nvidia.conf" \
  OMARCHY_SYSTEMD_UNIT_DIR="$tmp_dir/units" \
  bash -euo pipefail -c '
    lspci() { printf "%s\n" "VGA compatible controller: NVIDIA Corporation"; }
    omarchy-hw-aarch64-n1x() { return 1; }
    omarchy-hw-x86() { return 0; }
    omarchy-hw-nvidia-gsp() { return 0; }
    omarchy-hw-nvidia-without-gsp() { return 1; }
    omarchy-pkg-present() { return 0; }
    omarchy-pkg-add() { return 0; }
    systemctl() { printf "%s\n" "$*"; }
    source "$ROOT/install/hardware/nvidia.sh"
  ')

grep -qxF 'options nvidia_drm modeset=1 fbdev=1' "$tmp_dir/etc/modprobe.d/nvidia.conf" ||
  fail "nvidia.conf enables modeset and fbdev" "got: $(cat "$tmp_dir/etc/modprobe.d/nvidia.conf")"
grep -qxF 'options nvidia NVreg_PreserveVideoMemoryAllocations=1' "$tmp_dir/etc/modprobe.d/nvidia.conf" ||
  fail "nvidia.conf enables VRAM preservation" "got: $(cat "$tmp_dir/etc/modprobe.d/nvidia.conf")"
[[ $enabled_units == $'enable nvidia-suspend.service\nenable nvidia-resume.service\nenable nvidia-hibernate.service' ]] ||
  fail "NVIDIA sleep units enabled" "got: $enabled_units"
pass "modprobe and NVIDIA sleep services configured"
