# proj-commander
Bash script helpers for making easier to deal with multiple projects from command line.

Following the Unix-as-an-IDE philosophy, `proj-commander` aims to help Unix/Linux users (programmers, sysadmins, packagers, etc)
that deal with multiple software projects in a daily basis. The basic idea is to have simple "configuration" files (actually pure
shell scripts ) for each project, where the user may set some variables (e.g the root directory of the project, its subprojects,
etc) and must implement some functions that `proj-commander` executes when initializing and switching to/from that project (`setenv`
and `activate`). With this simple mechanism plus some helper functions implemented by `proj-commander` (`pset` and `pcd` for now)
and full bash-completion support, `proj-commander` can make extremely more practical and efficient to switch between projects / 
subprojects and even their sub-directories.
As the configuration files are actually shell scripts, the user has the freedom to adapt the environment to the specific needs
of each project (e.g: sourcing some project's env script, start some background program/daemon, configure specific version of a
tool, python for example, etc), everything in a organized way, keeping each project-specific config in a separate file and activating/loading
them only when necessary.

*In some aspects, `proj-commander` is inspired by Arch Linux's packaging/building system, where the package are built following
the steps described in PKGBUILD files, the are simple and clean bash scripts the set some vars and implement some functions defined
by the packaging system.*

## Installation

Running on a Linux/Unix machine\*, run on some bash\*\* instance:
*\* tested only in recent versions of Arch Linux<br/>
\*\* tested only in 4.0+ versions of Bash, so far*
```bash
$ curl https://raw.githubusercontent.com/nickdiego/proj-commander/master/proj-commander.sh > ~/.proj-commander &&
$ echo '[ -r ~/.proj-commander ] && source ~/.proj-commander' >> ~/.bashrc &&
$ exec /bin/bash -l
```

## Configuration

After installing, you need to create the configuration files for your projects in `~/.projects.d` directory. For example, you may
have a conf file the Qt5 project as follows:

```bash
projname=qt5
projpath=~/myprojects/qt5
subprojects=(base webengine)
setenv() {
  targets=('Msys-x86_64' 'Linux-x86_64')
  dirs[src]="qt${subproj}/src"
}

activate() {
  dirs[build]="build/$target"
  [ -r ${dirs[root]}/env.sh ] && . ${dirs[root]}/env.sh
}

```
*Some other configuration file example can be found in https://github.com/nickdiego/dotfiles/tree/master/.projects-env.d*

## Usage
After reloading bash, you can finally use the `proj-commander` commands `pset` and `pcd` to activate and navigate to
qt project, for example:
```bash
$ pset @qt5      <-- set qt5 as the current project and `activate` it (that will source its `env.sh` script

$ pcd            <-- change current directory to qt5's root dir

$ pcd @qt5/base  <-- change current directory to qt5's qtbase/src dir

$ pcd @qt5/base corelib/io   <-- change current directory to qt5's qtbase/src/corelib/io dir
```

Both `pset` and `pcd` support nicely bash completion, which make even faster the switch among the projects.


## Status
Even though the project is in an early stage of development, I've been using it at work for some months and it seems pretty
stable in recent versions of bash, but tests in different envs (e.g: distributions other than Arch, older versions of bash,
non-linux envs, etc) and feedbacks are very valuable to improve the project, so give it a try, open issues or even better
send pull requests :)



