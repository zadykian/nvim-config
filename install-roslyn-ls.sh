#!/usr/bin/env bash
# install-roslyn-ls.sh
#
# Installs the Roslyn language server (the `roslyn-language-server` global tool)
# that easy-dotnet.nvim needs for C# IntelliSense.
#
# Why this script exists (this machine is unusual):
#   * The .NET 10.0.203 SDK's `dotnet tool install` is BROKEN here -- it reports
#     "DotnetToolSettings.xml was not found in the package" for EVERY tool
#     (reproducible even with `dotnetsay`). So easy-dotnet's own
#     `:Dotnet` / `dotnet-easydotnet roslyn install` cannot install Roslyn.
#   * The .NET 8 SDK's installer works, BUT the upstream `roslyn-language-server`
#     package is a net10, RID-specific, `executable`-runner tool that the .NET 8
#     installer rejects ("unsupported runner 'executable'").
#
# Fix: take the upstream linux-x64 payload and repackage it as a plain net8.0
# `dotnet`-runner tool, then install it with the .NET 8 SDK. The language server
# itself still runs on the .NET 10 runtime (its runtimeconfig targets net10.0
# with rollForward=Major), so functionality is unaffected.
#
# Re-run this whenever you want to (re)install or update the Roslyn server.
set -euo pipefail

RID="${RID:-linux-x64}"
PKG="roslyn-language-server.${RID}"
WORK="$HOME/.local/share/easy-dotnet-roslyn"
FEED="$WORK/feed"
EXTRACT="$WORK/extract"
mkdir -p "$FEED" "$EXTRACT"

# 1. Find an installed .NET 8 SDK (its tool installer works).
SDK8="$(dotnet --list-sdks | awk '/^8\./ {print $1; exit}')"
if [ -z "${SDK8:-}" ]; then
  echo "ERROR: no .NET 8 SDK found (needed because the .NET 10 SDK tool installer is broken)." >&2
  exit 1
fi
printf '{ "sdk": { "version": "%s", "rollForward": "latestFeature" } }\n' "$SDK8" > "$WORK/global.json"

# 2. Resolve the latest prerelease version on nuget.org.
VER="$(curl -fsSL "https://api.nuget.org/v3-flatcontainer/${PKG}/index.json" | python3 -c 'import json,sys;print(json.load(sys.stdin)["versions"][-1])')"
echo ">> upstream ${PKG} version: ${VER}"

# 3. Download + extract the RID payload.
rm -rf "$EXTRACT"/* "$FEED"/*.nupkg
curl -fsSL -o "$WORK/upstream.nupkg" \
  "https://api.nuget.org/v3-flatcontainer/${PKG}/${VER}/${PKG}.${VER}.nupkg"
( cd "$EXTRACT" && unzip -q "$WORK/upstream.nupkg" )

# 4. Repackage: tools/<tfm>/<rid> -> tools/net8.0/any, runner executable -> dotnet,
#    packageType RID -> DotnetTool, id -> roslyn-language-server.
LOCAL_VER="${VER}-local"
python3 - "$EXTRACT" "$FEED" "$LOCAL_VER" <<'PY'
import os, re, shutil, sys, glob, zipfile
extract, feed, local_ver = sys.argv[1], sys.argv[2], sys.argv[3]

# move the single tools/<tfm>/<rid> dir to tools/net8.0/any
rids = glob.glob(os.path.join(extract, "tools", "*", "*"))
src = rids[0]
dst = os.path.join(extract, "tools", "net8.0", "any")
if os.path.normpath(src) != os.path.normpath(dst):
    os.makedirs(os.path.dirname(dst), exist_ok=True)
    shutil.move(src, dst)
    # prune now-empty old tfm dirs
    for d in glob.glob(os.path.join(extract, "tools", "*")):
        if os.path.basename(d) != "net8.0" and os.path.isdir(d) and not os.listdir(d):
            os.rmdir(d)

# rewrite DotnetToolSettings.xml: executable runner -> dotnet runner on the .dll
settings = os.path.join(dst, "DotnetToolSettings.xml")
s = open(settings, encoding="utf-8-sig").read()
s = s.replace('EntryPoint="Microsoft.CodeAnalysis.LanguageServer" Runner="executable"',
              'EntryPoint="Microsoft.CodeAnalysis.LanguageServer.dll" Runner="dotnet"')
open(settings, "w", encoding="utf-8").write(s)

# rewrite the .nuspec: id + packageType
nuspec = glob.glob(os.path.join(extract, "*.nuspec"))[0]
n = open(nuspec, encoding="utf-8-sig").read()
n = re.sub(r"<id>[^<]+</id>", "<id>roslyn-language-server</id>", n, count=1)
n = re.sub(r"<version>[^<]+</version>", "<version>%s</version>" % local_ver, n, count=1)
n = n.replace("DotnetToolRidPackage", "DotnetTool")
open(nuspec, "w", encoding="utf-8").write(n)

# drop the now-invalid signature, then zip back into the local feed
sig = os.path.join(extract, ".signature.p7s")
if os.path.exists(sig):
    os.remove(sig)
out = os.path.join(feed, "roslyn-language-server.%s.nupkg" % local_ver)
with zipfile.ZipFile(out, "w", zipfile.ZIP_DEFLATED) as z:
    for dp, _, fn in os.walk(extract):
        for f in fn:
            full = os.path.join(dp, f)
            z.write(full, os.path.relpath(full, extract))
print(">> built", out)
PY

# 5. Install under the .NET 8 SDK from a local-only source.
cat > "$WORK/nuget.config" <<XML
<?xml version="1.0" encoding="utf-8"?>
<configuration>
  <packageSources>
    <clear />
    <add key="local" value="${FEED}" />
  </packageSources>
</configuration>
XML

rm -rf "$HOME/.dotnet/tools/.store/.stage"/* "$HOME/.nuget/packages/roslyn-language-server"* 2>/dev/null || true
dotnet tool uninstall --global roslyn-language-server >/dev/null 2>&1 || true
( cd "$WORK" && dotnet tool install --global roslyn-language-server \
    --version "${VER}-local" --configfile "$WORK/nuget.config" --no-cache )

echo ">> done. Verify with:  dotnet-easydotnet healthcheck | grep roslyn"
