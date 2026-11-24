#!/bin/sh
# SPDX-FileCopyrightText: Atlas Engineer LLC
# SPDX-License-Identifier: BSD-3-Clause

set -eu

export PATH="/app/bin:${PATH}"
export CMAKE_BUILD_PARALLEL_LEVEL="$(nproc 2>/dev/null || echo 2)"

setup_out=$(ocicl setup)
runtime=$(printf '%s\n' "$setup_out" | sed -n 's/.*#P"\(.*ocicl-runtime.lisp\)".*/\1/p' | head -n 1)
if [ -z "$runtime" ] || [ ! -f "$runtime" ]; then
    printf '%s\n' "ocicl setup did not write ocicl-runtime.lisp" >&2
    printf '%s\n' "$setup_out" >&2
    exit 1
fi
export OCICL_RUNTIME="$runtime"

cef_root="${PWD}/cef-sdk"
if [ ! -d "${cef_root}/include" ] || [ ! -d "${cef_root}/Release" ]; then
    printf '%s\n' "CEF SDK is missing from ${cef_root}" >&2
    exit 1
fi

make NYXT_RENDERER=cef CEF_ROOT="${cef_root}" nyxt

app_id=engineer.atlas.Nyxt
cef_rel=$(awk -F', ' '$1 == "cl-cef" { print $3; exit }' ocicl.csv)
cef_build="${PWD}/ocicl/$(dirname "$cef_rel")/build"
clipboard_rel=$(awk -F', ' '$1 == "cl-clipboard" { print $3; exit }' ocicl.csv)
clipboard_dir="${PWD}/ocicl/$(dirname "$clipboard_rel")"

mkdir -p /app/bin /app/lib/cef /app/share/applications /app/share/metainfo
install -Dm755 nyxt /app/bin/nyxt
if [ ! -f "${clipboard_dir}/libcl-clipboard.so" ]; then
    printf '%s\n' "libcl-clipboard.so is missing from ${clipboard_dir}" >&2
    exit 1
fi
install -Dm755 "${clipboard_dir}/libcl-clipboard.so" /app/lib/libcl-clipboard.so

mkdir -p /app/lib/cef
for cef_name in \
    libcl-cef.so \
    cl-cef-helper \
    chrome-sandbox \
    libcef.so \
    libEGL.so \
    libGLESv2.so \
    libvk_swiftshader.so \
    libvulkan.so.1 \
    v8_context_snapshot.bin \
    vk_swiftshader_icd.json \
    chrome_100_percent.pak \
    chrome_200_percent.pak \
    resources.pak \
    icudtl.dat
do
    if [ ! -f "${cef_build}/${cef_name}" ]; then
        printf '%s\n' "CEF runtime file ${cef_name} is missing from ${cef_build}" >&2
        exit 1
    fi
    cp -f "${cef_build}/${cef_name}" "/app/lib/cef/${cef_name}"
done
chmod 755 /app/lib/cef/cl-cef-helper /app/lib/cef/chrome-sandbox /app/lib/cef/libcl-cef.so /app/lib/cef/libcef.so
cp -a "${cef_build}/locales" /app/lib/cef/locales

sed "s/^Icon=nyxt$/Icon=${app_id}/" assets/nyxt.desktop > "/app/share/applications/${app_id}.desktop"
sed "s|nyxt.desktop|${app_id}.desktop|" assets/nyxt.metainfo.xml > "/app/share/metainfo/${app_id}.metainfo.xml"
for size in 16 32 128 256 512; do
    install -Dm644 "assets/icons/nyxt_${size}x${size}.png" \
        "/app/share/icons/hicolor/${size}x${size}/apps/${app_id}.png"
done

libfixposix=$(find /app/lib -name 'libfixposix.so' | head -n 1)
libenchant=$(find /app/lib -name 'libenchant-2.so' | head -n 1)
if [ -z "$libfixposix" ] || [ -z "$libenchant" ]; then
    printf '%s\n' "libfixposix or libenchant-2 was not installed" >&2
    exit 1
fi

if ldd /app/bin/nyxt /app/lib/cef/libcef.so /app/lib/cef/libcl-cef.so /app/lib/cef/cl-cef-helper /app/lib/libcl-clipboard.so "$libfixposix" "$libenchant" | grep -E 'not found|undefined symbol'; then
    exit 1
fi
