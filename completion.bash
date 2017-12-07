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
                arg=${arg%/}
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

complete -F __projectopts proj_set
complete -F __projectopts proj_cd

complete -F __projectopts pset
complete -F __projectopts pcd


