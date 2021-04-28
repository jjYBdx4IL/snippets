# vim:set syntax=sh et sw=4:

_msvc_shell() {
    if ! [[ "$(uname)" =~ ^CYGWIN ]]; then return 1; fi
    export JAVA_HOME="$(cygpath -w "$JAVA_HOME")"
    # based on: https://stackoverflow.com/questions/171588/is-there-a-command-to-refresh-environment-variables-from-the-command-prompt-in-w

    local tmpfvbs="$(mktemp --suffix=.vbs)"
    local tmpfbat="$(mktemp --suffix=.bat)"
    local tmpfreset="$(mktemp --suffix=.bat)"
    trap "rm -f $tmpfvbs $tmpfreset $tmpfbat" RETURN

    local wtmpfvbs="$(cygpath -w "$tmpfvbs")"
    local wtmpfreset="$(cygpath -w "$tmpfreset")"
    wtmpfreset="${wtmpfreset//\\/\\}"
    cat >> "$tmpfvbs" <<EOF
Set oShell = WScript.CreateObject("WScript.Shell")
filename = oShell.ExpandEnvironmentStrings("$wtmpfreset")
Set objFileSystem = CreateObject("Scripting.fileSystemObject")
Set oFile = objFileSystem.CreateTextFile(filename, TRUE)

set oEnv=oShell.Environment("System")
for each sitem in oEnv 
    oFile.WriteLine("SET " & sitem)
next
path = oEnv("PATH")

set oEnv=oShell.Environment("User")
for each sitem in oEnv 
    oFile.WriteLine("SET " & sitem)
next

path = path & ";" & oEnv("PATH")
oFile.WriteLine("SET PATH=" & path)
oFile.Close
EOF
    chmod u+x "$tmpfvbs"

    cat >> "$tmpfbat" <<EOF
@echo off
@rem type $wtmpfvbs
$wtmpfvbs
call $wtmpfreset
call "C:\\Program Files (x86)\\Microsoft Visual Studio\2019\\Community\\VC\\Auxiliary\\Build\\vcvars64.bat"
EOF
    local cmdarg="/k"
    if [[ $# -gt 0 ]]; then
        cmdarg="/C"
        echo "$@" >> "$tmpfbat"
    fi
    local comspec=`cygpath $COMSPEC`
    "$comspec" $cmdarg "$(cygpath -w "$tmpfbat")"
}

_msvc_dumpbin_deps() {
    _msvc_shell dumpbin /DEPENDENTS "$@"
}
