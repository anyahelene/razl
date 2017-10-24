module basic::zx81::ZX81Basic
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

Program emptyProgram = Program((),(),());

public Program readLines(str ls)
	= readLines(parse(#start[ZX81Lines], ls).top);

public Program readLines(loc ls) {
	str file = readFileEnc(ls, "utf8");
	return readLines(parse(#start[ZX81Lines], file, ls).top);
}

public Program readDocument(loc ls) {
	name = (visit(toUpperCase(ls.file)) { case /\..*$/ => "" }) ? toUpperCase(ls.scheme); 
	text = replaceAll(readFileEnc(ls, "utf8"), "\f\n", "\f");
	int i = 1;
	pages = split("\f", text);
	pages = for(p <- pages) {
		str page = "PAGE<i>: CLS\n"; 
		lines = [visit(l){case / *$/s => ""} | l <- split("\n", p)];
//		lines = visit(lines){case /<x:\^[A-Z]>/ => "<toLowerCase(x)>"}; 
//		println(lines);
		lines =	for(l <- lines) {
			if(startsWith(l, "^^"))
				l = visit(l[2..]){case /<x:[A-Za-z0-9 \"£$:?()\<\>=+*;:.,\-]>/ => "^<x>"};
			append l;
		} 
		lines = visit(lines){case /<x:[a-z]>/ => "<toUpperCase(x)>"}; 
		if(size(lines) > 22) {
			println("***** WARNING: too many lines on page <i>!");
		}
		lines = ["PRINT \"<l>\"\n" | l <- lines];
		page = "<page><intercalate("", lines)>";
		pageNum = "<i>";
		if(i > 1)
			page = "<page>PRINT AT 21,<32-size(pageNum)>;\"<pageNum>\"\n";
		page = "<page>PAUSE 32768\n";
		page = "<page>LET A$=INKEY$\n";
		if(i > 1)
			page = "<page>IF CODE A$ = 53 THEN GOTO PAGE<i-1>:\n";
		else
			page = "<page>IF CODE A$ = 53 THEN GOTO PAGE1:\n";
		page = "<page>IF CODE A$ = 43 THEN FAST\n";
		page = "<page>IF CODE A$ = 56 THEN SLOW\n";
		page = "<page>IF CODE A$ = 38 THEN GOTO PAGE1:\n";
		page = "<page>IF CODE A$ = 63 THEN GOTO PAGE<size(pages)>:\n";
//		page = "<page>IF CODE A$ = 118 THEN\n";
		append page;
		i += 1;
	}
	src = intercalate("", pages);
	result  = "0 GOTO INIT:\n";
	for(p <- [1..i]) {
		result += "<p> GOTO PAGE<p>:\n";
	}
	result += "INIT: REM \"<name>\"\n";
	// result += "FAST\n";
	result += src;
	result += "STOP\n55555 SAVE \"<name>\"\nGOTO 0\n";
	println(result);
	return readLines(parse(#start[ZX81Lines], result, ls).top);
}

public int autoInc(int line, int step) = round(toReal(line+step)/step)*step;

public Program readLines(ZX81Lines ls) = readLines(ls, emptyProgram);
		
public Program readLines(ZX81Lines ls, Program p) {
	line = 0;
	lbl = "";
	autoNum = true;
	autoStep = 10;
	for((ZX81Line)`<ZX81LineNum? lineNum> <ZX81Cmd cmd>` <- ls.lines) {
		if([(ZX81LineNum)`<NUM n>`] := lineNum.args) {
			line = toInt("<n>");
		}
		else if([(ZX81LineNum)`<NAME n>:`] := lineNum.args) {
			line = autoInc(line, autoStep);			
			p.labels["<n>"] = line;
		}
		else {
			line = autoInc(line, autoStep);
		}
		
		if((ZX81Cmd)`` := cmd) {
			p.lines = p.lines - (line:cmd);
		}
		else {
			p.lines[line] = cmd;
		}
	}
	
	p.lines = visit(p.lines) {
		case (ZX81Expr)`<NAME l>:` 
			=> parse(#ZX81Expr, "<p.labels[unparse(l)]>")
	}
	
	return p;
}

public str listProgram(Program p) {
	return intercalate("\n",
		["<l> <p.lines[l]>" | l <- sort(domain(p.lines))]
	  + ["<l>:<p.labels[l]>" | l <- sort(domain(p.labels))]
	  + ["<l>=<p.vars[l]>" | l <- sort(domain(p.vars))]
	  ); 
}

public void printProgram(Program p) {
	println(listProgram(p)); 
}

private rel[str,str,int] specialChars = {
	<" ", " ", 0x00>,
	<"@1", "\u2598", 0x01>,
	<"@2", "\u259d", 0x02>,
	<"@3", "\u2580", 0x03>,
	<"@4", "\u2596", 0x04>,
	<"@5", "\u258c", 0x05>,
	<"@6", "\u259e", 0x06>,
	<"@7", "\u259b", 0x07>,
	<"@8", "\u2592", 0x08>,
	<"@9", "@9",     0x09>,
	<"@A", "@A",     0x0A>,
	<"#",  "\u2588", 0x80>,
	<"^@1", "\u259f", 0x81>,
	<"^@2", "\u2599", 0x82>,
	<"^@3", "\u2584", 0x83>,
	<"^@4", "\u259c", 0x84>,
	<"^@5", "\u2590", 0x85>,
	<"^@6", "\u259a", 0x86>,
	<"^@7", "\u2597", 0x87>,
	<"^@8", "\u2592", 0x88>,
	<"^@9", "^@9",    0x89>,
	<"^@A", "^@A",    0x8A>,
	<"\\UP", "↑",     0x70>,
	<"\\DOWN", "↓",   0x71>,
	<"\\LEFT", "←",   0x72>,
	<"\\RIGHT", "→",  0x73>,
	<"\\GRAPHICS", "\\GRAPHICS",  0x74>,
	<"\\EDIT", "\\EDIT",  0x75>,
	<"\\n", "\n",  0x76>,
	<"\\b", "\b",  0x77>,
	<"\\KL", "\\KL",  0x78>,
	<"\\FUNCTION", "\\FUNCTION",  0x79>,
	<"\\number", "\\number",  0x7e>,
	<"\\cursor", "\\cursor",  0x7f>	
};	

public map[str,int] altInputMap = ("^ ":0x80,"_":0x83, "~":0x03, "^~":0x0a, "@/":0x06, "@\\":0x86);

public str unicodeBlocks = "▄▌▖▘▚▛▜▞▀█▐▒▗▙▝▟";

private list[str] basicCommands1 = ["RND", "INKEY$", "PI"];
private list[str] basicCommands2 =	["\\\"", "AT", "TAB", "\\_", "CODE", "VAL", "LEN", "SIN", "COS", "TAN",
"ASN", "ACS", "ATN", "LN", "EXP", "INT",
"SQR", "SGN", "ABS", "PEEK", "USR", "STR$", "CHR$", "NOT", "**",
"OR", "AND", "\<=", "\>=", "\<\>", "THEN", "TO",
"STEP", "LPRINT", "LLIST", "STOP", "SLOW", "FAST", "NEW", "SCROLL",
"CONT", "DIM", "REM", "FOR", "GOTO", "GOSUB", "INPUT", "LOAD",
"LIST", "LET", "PAUSE", "NEXT", "POKE", "PRINT", "PLOT", "RUN", "SAVE",
"RAND", "IF", "CLS", "UNPLOT", "CLEAR", "RETURN", "COPY"];
private list[str] basicCommands = basicCommands1 + basicCommands2;

private rel[str,str,int] tokens = {
	<"RND", "RND", 0x40>,
	<"INKEY$", "INKEY$", 0x41>,
	<"PI", "PI", 0x42>
} + {<basicCommands2[i-192], basicCommands2[i-192], i> | i <- [192..256]}
;

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

private str codeChar(int x) {
	if(x >= 11 && x <= 27) {
		return "\"£$:?()\>\<=+-*/;,."[x-11];
	}	
	else if(x >= 28 && x <= 37) {
		return "<x-28>";
	}
	else if(x >= 38 && x <= 63) {
		return "<stringChar(x-38+65)>";
	}
	else if(x >= 139 && x <= 155) {
		return "^<"\"£$:?()\>\<=+-*/;,."[x-139]>";
	}
	else if(x >= 156 && x <= 165) {
		return "^<x-156>";
	}
	else if(x >= 166 && x <= 191) {
		return "^<stringChar(x-166+65)>";
	}
	throw x;
}


public rel[str,str,int] zx81Chars =
	specialChars + tokens + {<codeChar(x),codeChar(x), x> | x <- [11..64]+[139..192]};

public map[int,str] map_toUnicode = toMapUnique(zx81Chars<2,1>);
public map[str,int] map_toZX81 = toMapUnique(zx81Chars<0,2>) + toMapUnique((zx81Chars<1,2>) - <"\u2592", 0x88>) + altInputMap;
	
public int charToZX81(str c) = map_toZX81[c];

public str ansiFormat(str s) {
	return visit(s) {
	case /\\<x:(FUNCTION|UP|DOWN|LEFT|RIGHT|GRAPHICS|KL|number|cursor)>/
			=> "\a1b\a5b4m<x>\a1b\a5b0m"
	case /\^@<x:.>/ => "\a1b\a5b7m@<x>\a1b\a5b0m"
	case /\^<x:.>/ => "\a1b\a5b7m<x>\a1b\a5b0m"
	}
}

public list[str] zxToList(str s) {
	return for(i <- [0 .. size(s)]) {
		c = charAt(s,i);
		append map_toUnicode[c] ? "\\u00<toHex(c)>";
	}
}

public list[str] zxToList(list[int] s)
	= [map_toUnicode[c] ? "\\u00<toHex(c)>" | c <- s];

str foo = "\u0000\u0014\u0000\u0095\u0040\u0096\u0040\u00AE\u0043\u0000\u0000\u00AF\u0043\u00B5\u0043\u0000\u0000\u00B6\u0043\u00B6\u0043\u0000\u005D\u0040\u0000\u0002\u0000\u0000\u00FF\u00FF\u0000\u0037\u0095\u0040\u000A\u0000\u0000\u0000\u0000\u008D\u000C\u0000\u0000\u00D7\u00F6\u0000\u0000\u00BC\u0021\u0018\u0040\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0076\u0000\u0000\u0000\u0000\u0000\u0000\u0085\u0000\u0000\u0000\u0084\u00A0\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u000A\u0006\u0000\u00F5\u000B\u002D\u002E\u000B\u0076\u0000\u0014\u000A\u0000\u00EC\u001D\u001C\u007E\u0084\u0020\u0000\u0000\u0000\u0076\u0076\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0076\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0076\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0076\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0076\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0076\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0076\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0076\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0076\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0076\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0076\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0076\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0076\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0076\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0076\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0076\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0076\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0076\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0076\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0076\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0076\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0076\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0076\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0076\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0076\u0080";

public list[int] encodeBasicNum(real n) {
	if(n == 0)
		return [0,0,0,0,0];
		
	MAX = pow(2, 32)-1;
	MIN = pow(2, 31);
	signum = n < 0 ? -1 : 1;
	r = abs(n);
	
	int e = 32;
	
	while(true) {
		if(r > MAX) {
			r /= 2;
			e += 1;
			if(e > 127)
				throw "out of range: <n>";
		}
		else if(r < MIN) {
			r *= 2;
			e -= 1;
			if(e < -128)  // underflow
				return [0,0,0,0,0];
		}
		else {
			break;
		}
	}	

	int m = toInt(r);
	println(m);
	if(signum > 0)
		m = m - 2147483648;
	println(m);
	return [e+128, (m/16777216) % 256, (m/65536) % 256, (m/256) % 256, m % 256];
}

public real decodeBasicNum([int e, int m3, int m2, int m1, int m0]) {
	e = e - 128 - 32;
	int m = m0 + m1*256 + m2*65536 + m3*16777216;
	int signum = 1;
	if(m >= 2147483648) {
		signum = -1;
	}
	else  {
		m += 2147483648;
	}
	
	return precision(signum*m*pow(toReal(2), toReal(e)), 11);
}

public int decodeLineNum([int i0, int i1]) = i0*256 + i1;

public list[int] encodeLineNum(int i) = [(i / 256) % 256, i % 256]; 

public int decodeUInt16([int i0, int i1]) = i1*256 + i0;

public list[int] encodeUInt16(int i) = [i % 256, (i / 256) % 256]; 

public int decodeSInt16(list[int] l) {
	i = decodeUInt16(l);
	if(i >= 2147483648)
		return i - 4294967296;
	else
		return i;
}

public list[int] encodeSInt16(int i) =
	i < 0 ? encodeUInt16(i + 4294967296) : decodeUInt16(i);
 

public str pixelize(loc text, bool doubleHoriz) = pixelize(readFile(text), doubleHoriz);

public str pixelize(str text, bool doubleHoriz) {
	text = intercalate("", visit(split("", text)) {
		case /[\ \n\u2592\u2588]/: ;
		case /[#*]/ => "\u2588"
		case /[+]/ => "\u2592" 
		case /[_]/ => "\u2580"
		case /./ => "\u2588" 
	});
	lines = split("\n", text);

	str squeeze("\u2588\u2588") = "\u2588";
	str squeeze("\u0020\u2588") = "\u2592";
	str squeeze("\u2588\u0020") = "\u2592";
	str squeeze("\u2592\u2592") = "\u2592";
	str squeeze("\u2592\u2588") = "\u2588";
	str squeeze("\u2588\u2592") = "\u2588";
	str squeeze("\u2592\u0020") = "\u2592";
	str squeeze("\u0020\u2592") = "\u2592";
	str squeeze("\u0020\u0020") = "\u0020";
	default str squeeze(str x) { throw "wtf: \'<x>\'"; }
	
	
	if(doubleHoriz) {
		lines = for(l <- lines) {
			l = size(l) % 2 == 1 ? "<l><l[-1]>" : l;
			append intercalate("", [squeeze(l[i*2..i*2+2]) | i <- [0..size(l)/2]]);
		}
		for(l <- lines) println(l);
	}
	
	if(size(lines) % 2 == 1)
		lines = lines + [""];
	numLines = size(lines);
	numCols = max([size(l) | l <- lines]);
	if(numCols % 2 == 1)
		numCols = numCols + 1;
	lines = [left(l, numCols) | l <- lines];
	
	str result = "";
	bool shade = false;
	bool hints = true;
	println("Size: <size(lines[0])>x<size(lines)> =\> <numCols/2>x<numLines/2>");
	for(y <- [0..(numLines/2)]) {;
		//result += "PRINT \"";
		for(x <- [0..numCols/2]) {
			square = "<lines[y*2][x*2]><lines[y*2][x*2+1]><lines[y*2+1][x*2]><lines[y*2+1][x*2+1]>";
			biggersquare = "<" <lines[y*2]>"[x*2-1]><lines[y*2][x*2]><lines[y*2][x*2+1]><"<lines[y*2]> "[x*2+2]><" <lines[y*2+1]>"[x*2-1]><lines[y*2+1][x*2]><lines[y*2+1][x*2+1]><"<lines[y*2+1]> "[x*2+2]>";
			if(hints) switch(biggersquare) {
			case " ▒▒█ ▒▒█": { result += "▐"; println("!!"); continue; } 
			case "█▒▒ █▒▒ ": { result += "▌"; println("!!");continue; }
			}
			switch(square) {
			case "▒▒▒▒": result += shade ? "\u2592" : "\u258c";
			case "▒▒  ": result += shade ? "@A" : "\u2598";
			case "  ▒▒": result += shade ? "@9" : "\u2597";
			case "██▒▒": result += shade ? "^@9" : "\u259c";
			case "▒▒██": result += shade ? "^@A" : "\u2599";
			case _: { switch(replaceAll(square, "▒", "█")) {
				case "████": result += "\u2588";
				case " ███": result += "\u259f";
				case "█ ██": result += "\u2599";
				case "██ █": result += "\u259c";
				case "███ ": result += "\u259b";
				case "██  ": result += "\u2580";
				case " ██ ": result += "\u259e";
				case "  ██": result += "\u2584";
				case "█ █ ": result += "\u258c";
				case " █ █": result += "\u2590";
				case "█  █": result += "\u259a";
       	        case "█   ": result += "\u2598";
       	        case " █  ": result += "\u259d";
       	        case "  █ ": result += "\u2596";
       	        case "   █": result += "\u2597";
        	    case "    ": result += " ";
        	    default: println(replaceAll("▒", "█", square));
				}}
			};
		}
		result += "\n";
	}
	
	return result;
	
}


public str hashize(str s) {
	s = visit(s) {case /[▄▌▚▛▜▞▀█▐▙▟]/ => "#"}
	s = visit(s) {case /[▗▖▝▘▒]/ => "+"}
	return s;
}