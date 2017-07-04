#!/usr/bin/bash
#
#   proj-commander.sh Shell script helpers for making easier to deal with
#   projects from command line.
#
#   Copyright (c) 2016-2017 Nick Diego Yamane <nick.diego@gmail.com>
#
#   This program is free software; you can redistribute it and/or modify
#   it under the terms of the GNU General Public License as published by
#   the Free Software Foundation; either version 2 of the License, or
#   (at your option) any later version.
#
#   This program is distributed in the hope that it will be useful,
#   but WITHOUT ANY WARRANTY; without even the implied warranty of
#   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#   GNU General Public License for more details.
#
#   You should have received a copy of the GNU General Public License
#   along with this program.  If not, see <http://www.gnu.org/licenses/>.
#

PROJ_CONTAINER_DIR=~/projects

unset -v _prev_project _projects
declare -a _projects _prev_project

# Helper functions
config_proj() {
    function generate_proj_env() {
        local projname=$1 projpath=$2 subproj
        local prefix=$(generate_var_prefix $projname)
        eval "${prefix}_proj_root=$projpath"
        if declared_func setenv; then
            eval "${prefix}_setenv() {
                $(declare -f setenv)
                projname=$projname
                projroot=$projpath
                declare -Ag dirs=( [root]=${projpath} )
                setenv \$@
            }"
            local subs=( $projname ${subprojects[@]} )
            for subproj in ${subs[@]}; do
                ${prefix}_setenv $subproj
                generate_subproj_env $projname $projpath $subproj
            done
        fi
    }

    function generate_subproj_env() {
        local projname=$1 projpath=$2 subproj=$3
        local full_prefix=$(generate_full_var_prefix $projname $subproj)
        local proj_prefix=$(generate_var_prefix $projname)
        declare -Ag ${full_prefix}_dirs
        local d
        for d in "${!dirs[@]}"; do
            eval "${full_prefix}_dirs[$d]=${dirs[$d]}"
        done
        eval "${full_prefix}_defaultdir=${defaultdir}"
        eval "${full_prefix}_targets=(${targets[@]})"
        eval "${full_prefix}_options=(${options[@]})"
        if ! declared_func 'activate'; then
            eval "${full_prefix}_set_as_curr_project() {
                ${proj_prefix}_setenv '$subproj'
            }"
        else
            eval "${full_prefix}_set_as_curr_project() {
                $(declare -f activate)
                ${proj_prefix}_setenv '$subproj'
                activate '${subproj}' \$@
            }"
        fi
        _projects+=( $(generate_projid $projname $subproj) )
        clear_subproj_env
    }

    function generate_full_var_prefix() {
        local proj=$(generate_var_prefix $1)
        local sub=$(generate_var_prefix $2)
        [ "$proj" = "$sub" ] && echo $proj || echo "${proj}_${sub}"
    }

    function generate_projid() {
        local proj=$1 sub=$2 sep=$3
        [ "$proj" = "$sub" ] && echo "${proj}" || echo "${proj}/${sub}"
    }

    function clear_proj_env() {
        unset -v projname projpath projroot subprojects targets
        unset -f setenv activate
    }

    local script=$1
    clear_proj_env
    source $script
    if [[ -z $projname ]]; then
        log_message "Error: Couldn't find \$projname for $script"
        return 1
    else
        local projrootpath=${projpath:-$PROJ_CONTAINER_DIR/$projname}
        test -d $projrootpath || return 1
        log_message "Setting env for $projrootpath"
        generate_proj_env $projname $projrootpath
    fi
}

clear_subproj_env() {
    unset -v dirs defaultdir target options vimsession
}

generate_var_prefix() {
    sed 's/[^a-zA-Z0-9]/_/g' <<< $1
}

declared_func() {
    declare -f "$1" >/dev/null
}

# Internal helper functions
log_message() {
    (( ${_opt[-v]} )) && echo $@
}

# TODO For now supports only boolean
# params. Improve it later
# TODO implement _extraargs, for args
# after "--", if present
process_args() {
    declare -a vals opts
    while (( $# )); do
        case $1 in
            -?)
                opts+=("[${1}]=1")
                ;;
            --*)
                opts+=("[${1}]=1")
                ;;
            *)
                vals+=( $1 )
        esac
        shift
    done
    echo "declare -a _val=(${vals[@]});"
    echo "declare -A _opt=(${opts[@]});"
}

clear_curr_proj_vars() {
    local varname
    for varname in "${!curr_proj*}"; do
        unset -v ${varname}
    done
}

get_hash_val() {
    local hashname=$1 key=$2
    eval "echo \${${hashname}[$key]}"
}

get_hash_keys() {
    local hashname=$1
    eval "echo \${!${hashname}[@]}"
}

declare_proj_dirs() {
    local fulldir proj=$1; shift
    local root=$(get_hash_val ${proj}_dirs root)
    local default=$(eval "echo \$${proj}_defaultdir")

    set $(get_hash_keys ${proj}_dirs)
    echo "local rootdir='$root'"
    while (( $# )); do
        if [[ "$1" != root ]]; then
            fulldir="${root}/$(get_hash_val ${proj}_dirs $1)"
            echo "local ${1}dir='$fulldir'"
            [[ "$1" == "$default" ]] && echo "local defaultdir='$fulldir'"
        fi
        shift
    done
}

## Public functions
proj_set() {
    eval $(process_args $@)
    local projid=${_val[0]#@}
    if [[ -z "${projid:-}" ]]; then
        if [[ -z "${curr_project:-}" ]]; then
            echo "Failed to switch do project dir: \$curr_project empty."
            return 1
        fi
        projid="$curr_project"
    elif [[ "$projid" = "-" ]] || (( ${_opt['--back']} )); then
        local last=$((${#_prev_project[@]} - 1))
        if (( $last < 0 )); then
            echo "No previous project set."
            return 1
        fi
        _opt['--back']=1
        projid=${_prev_project[$last]}
        unset -v _prev_project[$last]
    fi

    local subproj=${projid#*/}
    local prefix=$(generate_var_prefix $projid)
    local activatefunc=${prefix}_set_as_curr_project
    if [[ "$projid" != "$curr_project" && "${_opt['--back']}" -ne 1 ]]; then
        _prev_project+=($curr_project)
    fi

    clear_curr_proj_vars
    declared_func $activatefunc && $activatefunc $subproj

    # FIXME: Re-generate proj env, they may change
    # dependingo on the options are passed to
    # proj_set/proj_cd

    local d fulldir dirnames=("${!dirs[@]}")
    if (( ${#dirnames[@]} )); then
        eval "curr_proj_root_dir='${dirs[root]}'"
        for d in ${dirnames[@]}; do
            [[ "$d" == root ]] && continue
            fulldir="${dirs[root]}/${dirs[${d}]}"
            eval "export curr_proj_${d}_dir='${fulldir}'"
            [[ "$d" == "$defaultdir" ]] && curr_proj_defaultdir="$fulldir"
        done
    fi

    curr_proj_target=$target
    curr_proj_vimsession=${vimsession:-$subproj}
    curr_project=$projid
    clear_subproj_env

    log_message "Switched ${_opt['--back']:+back }to project '${projid}'" \
        " (Back stack: [ $(sed 's/ / > /g' <<< "${_prev_project[@]}") ])"
}

proj_cd() {
    eval $(process_args $@)
    local projid=${_val[0]:-$curr_project}
    proj_set $projid ${!_opt[@]}
    local basedir="$curr_proj_defaultdir"
    [[ -n $basedir ]] || basedir=${curr_proj_src_dir:-$curr_proj_root_dir}
    cd "${basedir}/${_val[1]}"
}

## Bash completion stuff

__cdopts()
{
    local cur prev words cword
    _init_completion || return
    local IFS='
    ' i j k;
    compopt -o filenames -o nospace
    if [[ -z "${proj_cdpath:-}" || "$cur" == ?(.)?(.)/* ]]; then
        _filedir -d
        return
    fi;
    local -r mark_dirs=$(_rl_enabled mark-directories && echo y)
    local -r mark_symdirs=$(_rl_enabled mark-symlinked-directories && echo y)
    for i in ${proj_cdpath//:/'
        '};
    do
        k="${#COMPREPLY[@]}"
        for j in $( compgen -d -- $i/$cur ); do
            [[ ( -n $mark_symdirs && -h $j || -n $mark_dirs && ! -h $j ) &&
                ! -d ${j#$i/} ]] && j+="/"
            COMPREPLY[k++]=${j#$i/}
        done
    done
    if [[ ${#COMPREPLY[@]} -eq 1 ]]; then
        i=${COMPREPLY[0]};
        [[ "$i" == "$cur" && $i != "*/" ]] && COMPREPLY[0]="${i}/"
    fi;
}

__projectopts() {
    (( ${#_projects[@]} )) || return 0
    local i=1 cur="${COMP_WORDS[COMP_CWORD]}"
    local optset=() result=()
    local arg proj
    while (( i < COMP_CWORD )); do
        arg=${COMP_WORDS[i]}
        case $arg in
            --* | -?)
                optset+=( $arg )
                ;;
            @*)
                arg=${arg#@}
                if [[ -z "$arg" ]]; then
                    [[ -z $curr_project ]] && return 1 ||
                        proj=$(generate_var_prefix $curr_project)
                else
                    [[ "${_projects[@]}" =~ "${arg}" ]] && proj=$(generate_var_prefix $arg)
                fi
                ;;
        esac
        i=$((i+1))
    done
    if [[ -z ${proj} ]]; then
        [[ "$cur" != @* ]] && cur="@${cur}"
        result+=( "${_projects[*]/#/@}" )
    else
        if [[ $cur = --* || $cur = -? ]]; then
            result+=( "$_cmdproj_options" "\${${proj}_options[@]}" )
        else
            eval $(declare_proj_dirs $proj)
            export proj_cdpath="$defaultdir"
            [ -z "${proj_cdpath:-}" ] && proj_cdpath="${srcdir:-$rootdir}"
            __cdopts
            return
        fi
    fi
    COMPREPLY=( $(compgen -W "${result[*]}" -- ${cur}) )
}

## Init stuff
_cmdproj_options=( '-v' )

if [ -d ~/.projects.d ]; then
    for script in ~/.projects.d/*.sh; do
        config_proj $script
    done
    unset script
fi

complete -F __projectopts proj_set
complete -F __projectopts proj_cd

## Aliases
alias pset='proj_set'
alias pcd='proj_cd'
complete -F __projectopts pset
complete -F __projectopts pcd

# vim:ft=sh sw=4:
