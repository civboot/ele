# shrm: the Civboot shell

shrm is a shell built for the [Civboot] project in pure lua.
It is currently in the early design/implementation phase and
is not even remotely useable.

Basic goals:

 - use lua as a shell language
 - write commands like a (vi-style) text editor
 - execute a "block" with ctrl+enter.

A "block" is defined as text which is not separated by newlines.

```
-- a block (executed together with cursor on them and ctrl+enter)
sh'do something';  x = sh'do something else'
sh('do something '..x

-- another block
sh'do another thing';  x = sh'do something else'
sh('do something '..x)
```

You can also use syntax to specify a "large" block that has whitespace.
Large blocks are executed with ctrl+shift+enter

```
--START
sh'do something';  x = sh'do something else'

sh('do something '..x)
--END
```

When a block is executed the following happens:

 - the paths to the stdout/stderr are appended
 - the user can use ctrl+o to open/close a view of them

What this looks like is:

```
-- a block (executed together with cursor on them and ctrl+enter)
sh'do something';  x = sh'do something else'
sh('do something '..x
-- MSG: error message or return code
-- OUT: /tmp/shrm/akjbska-out
-- ERR: /tmp/shrm/akjbska-err
```

When you use ctrl+o on (for example) the OUT line it jumps to the output file,
which you can navigate/copy/etc.

If you use ctrl+t+(optional number)+enter on the OUT line it expands the tail
to the number given, or the system default (10 or so). Pressing ctrl+t again
will close the block.

ctrl+h can be equivalently used to expand the head. Doing both will do both
and the info will say (head+tail)

```
-- a block (executed together with cursor on them and ctrl+enter)
sh'do something';  x = sh'do something else'
sh('do something '..x
-- MSG: error message or return code
--[==[ OUT: "/tmp/shrm/akjbska-out" (tail)
  ... 100 lines ...
this is the end of the file
some error you want to see is here for example
]==]
-- ERR: /tmp/shrm/akjbska-err
```

