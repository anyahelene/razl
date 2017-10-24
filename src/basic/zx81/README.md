# ZX81 BASIC Editor and Tools


# Example usage
### Reading a program from file
```
rascal>import basic::zx81::Syntax;
ok
rascal>import basic::zx81::Loader;
ok
rascal>readLines(|project://razl/src/basic/zx81/examples/hello.zxb|)
Program: Program(
  (10:appl(
      prod(
        sort("ZX81Cmd"),
  ...
```
If you print it, it will show the program code, and a list of variables and labels (no variables in this example):
```
rascal>printProgram(readLines(|project://razl/src/basic/zx81/examples/hello.zxb|))
10 PRINT "HELLO, WORLD"
20 PRINT "##### #   #  ###    #"
30 PRINT "   #   # #  #   #  ##"
40 PRINT "  #     #    ###    #"
50 PRINT " #      #   #   #   #"
60 PRINT "#      # #  #   #   #"
70 PRINT "##### #   #  ###   ###"
80 PAUSE 32768
90 CLS
100 GOTO 10
MAIN:10
ok
```

### From syntax tree to BASIC tokens
You can make a token list with `tokens()`. Tokens are stored as a list of integers, each representing a byte. This is how your program would look in the memory of the ZX81.
```
rascal>import basic::zx81::Saver;
ok
rascal>tokens(readLines(|project://razl/src/basic/zx81/examples/hello.zxb|).lines)
list[int]: [0,10,16,0,245,11,45,42, ...
ok
```

To run the program in an emulator, you need a tape file (a `.p` file), which contains some system settings, the program itself, and any variables that might be in memory. This is done with `encodePFile`, which uses the above `tokens()` to turn a program into tokens and then combines it with the other necessary data.
```
rascal>encodePFile(readLines(|project://razl/src/basic/zx81/examples/hello.zxb|))
Program: 1142 total, 232 program, 0 vars
list[int]: [0,0,0,101,65,0,0,126,68,0,0, ...
rascal>
```

If you save it to disk, you can load it directly into an emulator, or convert to a sound file and transfer to a real ZX81 by audio.
```
rascal>pData = encodePFile(readLines(|project://razl/src/basic/zx81/examples/hello.zxb|));
Program: 1142 total, 232 program, 0 vars
list[int]: [0,0,0,101,65,0,0,126,68,0,0, ...
rascal>
rascal>import IO;
ok
rascal>writeFileBytes(|file:///tmp/foo.p|, pData)
ok
```
