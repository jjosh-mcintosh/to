# to - v1.2.2
# Bookmark locations in bash
#
# Copyright (C) 2013 Mara Kim
#
# This program is free software: you can redistribute it and/or modify it under
# the terms of the GNU General Public License as published by the Free Software
# Foundation, either version 3 of the License, or (at your option) any later
# version.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE. See the GNU General Public License for more
# details.
#
# You should have received a copy of the GNU General Public License along with
# this program. If not, see http://www.gnu.org/licenses/.


### SETTINGS ###

TO_BOOKMARK_DIR=~/.bookmarks

### MAIN ###

function to {
    # create empty bookmarks folder if it does not exist
    if [ ! -d "$TO_BOOKMARK_DIR" ]
    then
        \mkdir "$TO_BOOKMARK_DIR"
    fi

    if [ -z "$1" ]
    then
        # show bookmarks
        for link in $TO_BOOKMARK_DIR/*
        do
            echo "$(\basename $link)" '->' "$(\readlink $link)"
        done
        return 0
    elif [ "$1" = "-h" ]
    then
        _to_help
        return 0
    elif [ "$1" = "-p" ]
    then
        if [ -e "$TO_BOOKMARK_DIR/$2" ]
        then
            # print path of bookmark
            \echo "$(\readlink -f "$TO_BOOKMARK_DIR/$2")"
            return 0
        else
            # echo nothing to prevent strange behavior with $(to -p ...) usage
            return 1
        fi
    elif [ "$1" = "-b" ]
    then
        if [ -e "$TO_BOOKMARK_DIR/$2" ]
        then
            # remove bookmark
            \rm "$TO_BOOKMARK_DIR/$2"
        fi
        # add bookmark
        if [ "$3" ]
        then
            if [ -d "$3" ]
            then
                \ln -s "$3" "$TO_BOOKMARK_DIR/$2"
            else
                \echo "$3 does not refer to a directory"
                return 1
            fi
        else
            \ln -s "$PWD" "$TO_BOOKMARK_DIR/$2"
        fi
        return 0
    elif [ "$1" = "-r" ]
    then
        if [ -e "$TO_BOOKMARK_DIR/$2" ]
        then
            # remove bookmark
            \rm "$TO_BOOKMARK_DIR/$2"
        fi
        return 0
    fi

    # go to bookmark
    if [ -d "$TO_BOOKMARK_DIR/$1" ]
    then
        \cd -P "$TO_BOOKMARK_DIR/$1"
    else
        \echo "Invalid shortcut: $1"
        return 1
    fi
    return 0
}


### TAB COMPLETION ###

# tab completion generic
# $1 = current word
# $2 = previous word
# Output valid completions
function _to {
    # create empty bookmarks file if it does not exist
    if [ ! -e "$TO_BOOKMARK_DIR" ]
    then
        \mkdir "$TO_BOOKMARK_DIR"
    fi
    # build reply
    local compreply
    if [ "$2" = "-b" ]
    then
        # add current directory
        compreply="$(\basename "$PWD" )"$'\n'"$compreply"
        # get bookmarks
        compreply="$(_to_bookmarks)"$'\n'"$compreply"
    elif [ "$2" = "-r" ]
    then
        # get bookmarks
        compreply="$(_to_bookmarks)"$'\n'"$compreply"
    else
        local subdirs="$(_to_subdirs "$word")"
        if [ "$2" = "-p" ]
        then
            local subfiles="$(_to_subfiles "$word")"
        fi
        if [ "$subdirs" -o "$subfiles" ]
        then
            # add subdirectories
            compreply="$subdirs"$'\n'"$compreply"
            # add subfiles
            compreply="$subfiles"$'\n'"$compreply"
        else
            # get bookmarks (with slash)
            compreply="$(_to_bookmarks "\/")"$'\n'"$compreply"
        fi
    fi
    # generate reply 
    \sed -n "/^$(_to_regex "$word").*/p" <<< "$compreply" | \sed 's/\\ / /' 
}

# tab completion bash
function _to_bash {
    # get components
    local cur="${COMP_WORDS[COMP_CWORD]}"
    local prev="${COMP_WORDS[COMP_CWORD-1]}"
    # call generic tab completion function
    local IFS='
'
    COMPREPLY=( $(_to "$cur" "$prev") )
}

# tab completion zsh
function _to_zsh {
    # get components
    local cur="${COMP_WORDS[COMP_CWORD]}"
    local prev="${COMP_WORDS[COMP_CWORD-1]}"
    # call generic tab completion function
    local IFS='
'
    COMPREPLY=( $(_to "$cur" "$prev" | \sed "s/[ ']/\\\\&/g" ) )
}

# setup tab completion
if [ "$ZSH_VERSION" ]
then
    \autoload -U +X bashcompinit && \bashcompinit
    \complete -o nospace -F _to_zsh to
else
    \complete -o filenames -o nospace -F _to_bash to
fi


### HELPER FUNCTIONS ###

function _to_help {
    \echo "Usage: to [OPTION] [BOOKMARK]
Set the current working directory to a saved bookmark, or create
such a bookmark.

Options
  -b	Add a new bookmark for current directory (overwrites any current bookmark)
  -r	Remove bookmark
  -p	Print bookmark path
  -h	Show help"
}

# Return list of bookmarks in $TO_BOOKMARK_FILE
# $1 sed safe suffix  WARNING escape any /s
function _to_bookmarks {
    \find "$TO_BOOKMARK_DIR" -mindepth 1 -maxdepth 1 -type l -printf "%f\n"
}

# get the directory referred to by a bookmark
function _to_dir {
    \sed -n "s/^$1|\(.*\)/\1/p" "$TO_BOOKMARK_FILE"
}

# get the first part of the path
function _to_path_head {
    \sed -n "s/^\([^/]*\)\(\/.*\)\?$/\1/p" <<<"$1"
}

# get the rest of the path
function _to_path_tail {
    \sed -n "s/^[^/]*\(\/.*\)$/\1/p" <<<"$1"
}

# get the absolute path of an expanded bookmark/path
function _to_reldir {
    local todir="$(_to_dir "$(_to_path_head "$1")" )"
    if [ "$todir" = "/" ]
    then
        # special case for root dir
        \echo "$(_to_path_tail "$1")"
    else
        \echo "$todir$(_to_path_tail "$1")"
    fi
}

# remove bookmark
function _to_rm {
    \sed "/^$1|.*/ d" "$TO_BOOKMARK_FILE" > "$TO_BOOKMARK_FILE~"
    \mv "$TO_BOOKMARK_FILE~" "$TO_BOOKMARK_FILE"
}

# clean input for sed search
function _to_regex {
    if [ "$1" = "/" ]
    then
        # special case for root dir
        \echo
    else
        \echo "$1" | \sed 's/[\/&]/\\&/g'
    fi
}

# find the directories that could be subdirectory expansions of
# $1 word
function _to_subdirs {
    local bookmark="$(_to_path_head "$1")"
    local todir="$(_to_dir "$bookmark")"
    if [ "$todir" ]
    then
        local reldir="$(\sed 's/\\ / /' <<<"$(\dirname "$(_to_reldir "$1")\*")")"
        local reldir="$(\find "$reldir" -mindepth 1 -maxdepth 1 -type d 2> /dev/null )"
        local stat=$?
        if [ $stat = 0 ]
        then
            \echo "$reldir"| \sed "s/^$(_to_regex "$todir")\(.*\)/$bookmark\1\//"
        fi
    fi
}

# find the files that could be subdirectory expansions of
# $1 word
function _to_subfiles {
    local bookmark="$(_to_path_head "$1")"
    local todir="$(_to_dir "$bookmark")"
    if [ "$todir" ]
    then
        local reldir="$(\sed 's/\\ / /' <<<"$(\dirname "$(_to_reldir "$1")\*")")"
        local reldir="$(\find "$reldir" -mindepth 1 -maxdepth 1 -type f 2> /dev/null )"
        local stat=$?
        if [ $stat = 0 ]
        then
            \echo "$reldir"| \sed "s/^$(_to_regex "$todir")\(.*\)/$bookmark\1/"
        fi
    fi
}

