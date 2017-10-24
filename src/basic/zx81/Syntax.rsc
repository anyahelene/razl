module basic::zx81::Syntax
import String;
import List;
import Set;
import Map;
import util::Math;
import ParseTree;
import IO;

start syntax ZX81Lines
	= {ZX81Line "\n"}* lines
	;
	
syntax ZX81Line
	= ZX81LineNum? ZX81Cmd
	;
	
syntax ZX81LineNum
	= Line: NUM
	| Label: NAME ":"
	;

syntax ZX81PrintArg = ZX81Expr | "," | ";";
syntax ZX81Cmd
	= "REM" COMMENT   // comment
	| "PRINT"  ZX81PrintArg* // print to screen
	| "LPRINT" ZX81Expr // print to printer
	| "GOTO" ZX81Expr // go to
	| "GOSUB" ZX81Expr // go to subroutine
	| "RETURN" // return from subroutine
	| "PLOT" ZX81Expr "," ZX81Expr // paint black pixel
	| "UNPLOT" ZX81Expr "," ZX81Expr // paint white pixel
	| "LET" ZX81Expr "=" ZX81Expr // assign to variable
	| "FOR" NAME "=" ZX81Expr "TO" ZX81Expr ("STEP" ZX81Expr)? // loop
	| "NEXT" NAME // next loop iteration
	| "IF" ZX81Expr "THEN" ZX81Cmd // condition
	| "DIM" NAME "(" {ZX81Expr ","}+ ")" // create array
	| "DIM" NAME "$" "(" {ZX81Expr ","}+ ")" // create string array
	| "LIST" | "LLIST"   // list program to screen | printer
	| "STOP" | "CONT"  // stop / continue program
	| "SLOW" | "FAST"  // slow mode (compute and graphics) / fast mode (compute or graphics)
	| "NEW" | "CLEAR"  // wipe program / clear variables
	| "SCROLL" | "CLS" // scroll one line / clear screen
	| "PAUSE" ZX81Expr // wait N/50 secs, or until key pressed 
	| "POKE" ZX81Expr "," ZX81Expr // write to memory
	| "RUN" ZX81Expr? // run program (from line number); clears variables
	| "SAVE" STRING  // save program
	| "RAND" ZX81Expr  // initialise random generator
	| "COPY" // print screen
	|
	;
	



syntax ZX81Expr
	= Var: NAME
	| ArrayVar: NAMECHAR "(" {ZX81Expr ","}+ ")"
	| StringVar: NAMECHAR "$"
	| StringArrayVar: NAMECHAR "$" "(" {ZX81Expr ","}+ ")"
	| Num: NUM
	| String: STRING
	| Label: NAME ":"
	| "TAB"
	| "INKEY$"
	> left ZX81Fun ZX81Expr
	> "AT" ZX81Expr "," ZX81Expr
	> left ZX81Expr "**" ZX81Expr
	> [\-] ZX81Expr
	> left ( ZX81Expr "*" ZX81Expr
		|    ZX81Expr "/" ZX81Expr
		)
	> left ( ZX81Expr "+" ZX81Expr
		|    ZX81Expr "-" ZX81Expr
		)
	> left ( ZX81Expr "=" ZX81Expr
		|	 ZX81Expr "\<\>" ZX81Expr
		|	 ZX81Expr "\<=" ZX81Expr
		|	 ZX81Expr "\>=" ZX81Expr
		)
	> "NOT" ZX81Expr
	> left ZX81Expr "AND" ZX81Expr
	> left ZX81Expr "OR" ZX81Expr
	;

lexical ZX81Fun
	= "CODE" | "VAL" | "LEN" | "SIN" | "COS" | "TAN" 
	| "ASN" | "ACS" | "ATN" | "LN" | "EXP" | "INT"
	| "PI"	| "SQR" | "SGN" | "ABS" | "PEEK" | "USR" 
	| "STR$" | "CHR$"
	;
keyword ZX81KWS = ZX81Fun | "AT";

lexical NAME = [A-Z0-9] !<< (NAMECHAR [A-Z0-9]*) \ ZX81KWS !>> [A-Z0-9];

lexical NAMECHAR = [A-Z];

lexical NUM = [0-9] !<< [0-9]+ !>> [0-9];

lexical STRING = [\"] CHAR* [\"];

lexical CHAR
	= ![\"\n\\] // [\u0020-\u10FFFF] - [\"\n\\]
	| [\\] [\" \\ / b f n r t]
	| [\\] [x] [0-9a-fA-F] [0-9a-fA-F]
	;
	
lexical COMMENT = ![\n]*;
layout LAYOUT =  [\ \r\f\t]* !>> [\ \r\f\t];

data Value
	= Num(real n)
	| NumArray(list[int] dim, list[real] values)
	| String(str s)
	| StringArray(list[int] dim, str s)
	| ControlVar(real n, real max, real step, int line)
	;
	
data Program = Program(
	map[int,ZX81Cmd] lines,
	map[str,int] labels,
	map[str,Value] vars
);

public Program Program() = Program((),(),());


public str toHex(int i, int z) {
	str s = "";
	while(i > 0) {
		s = "<"0123456789ABCDEF"[i%16]><s>";
		i = i / 16;
	}
	z -= size(s);
	while(z > 0) {
		s = "0<s>";
		z -= 1;
	}
	return s == "" ? "0" : s;
}

public str toHex(int i) = toHex(i, 1);

