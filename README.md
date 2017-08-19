# buildtools
generic all-in-bash (+basic utils use) scripts to assist building any package (linux/darwin)

# how to use this:
 - implement a function build() & execute do_build
 - within build() rely on $BT variables
 - the simplest implementation - a bash script (note: it could have been made shorter...)

```bash
#!/bin/bash
cd $(dirname $BASH_SOURCE)
# cp -v ~/devel/buildtools/bt.sh .
[ ! -f ./bt.sh ] && wget https://raw.github.com/matplo/buildtools/master/bt.sh
[ ! -f ./bt.sh ] && echo "[i] no bt.sh - stop here." && exit 1
BT_config=./tmp.cfg
echo "clean=yes" > $BT_config
echo "cleanup=yes" >> $BT_config
echo "ignore_errors=yes" >> $BT_config
source bt.sh "$@" --build
function build()
{
	separator "cmake/make/other commands here"
}
exec_build_tool
```
