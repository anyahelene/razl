module basic::zx81::Saver
import String;
import Map;
import Set;
import List;
import IO;
import ParseTree;
import basic::zx81::Syntax;
import basic::zx81::Numbers;
import basic::zx81::Charset;

public int ramBottom = 0x4000;
public int tapeBottom = 0x4009;
public int programArea = 0x407D;
public int machineStack = 0;
public int gosubStack = 0;
public int ramTop = 0x8000;

data PFile =
	PFile(int version,
		int currentLine,
		int displayArea,
		int printPosition,
		int variableArea,
		int workArea,
		int calcStack,
		int spareArea,
		int calcMem,
		int length,
		list[int] program,
		list[int] display,
		list[int] variables
	);
public PFile PFile() = PFile(0,0,0,0,0,0,0,0,0,0,[],[],[]);


private list[int] stdHeader = 
	[0,20,0,149,64,150,64,174,67,0,0,175,67,181,67,0,0,182,67,182,67,0,93,64,
	 0,2,0,0,255,255,0,55,149,64,10,0,0,0,0,141,12,0,0,215,246,0,0,188,33,24,
	 64,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,118,0,
	 0,0,0,0,0,133,0,0,0,132,160,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0];

public PFile decodePFile(str bytes) = decodePFile(chars(bytes));


public PFile decodePFile(list[int] bytes) {
	int decodeByte(int offset) = bytes[offset];
	int decodeWord(int offset) = decodeUInt16(bytes[offset..offset+2]);
	
	PFile head = PFile();
	head.version = decodeByte(0); // VERSN
    head.currentLine = decodeWord(1); // E_PPC
    head.displayArea = decodeWord(3); // D_FILE
    head.printPosition = decodeWord(5); // DF_CC
    head.variableArea = decodeWord(7); // VARS
    dest = decodeWord(9); // DEST
    head.workArea = decodeWord(11);
    nextChar = decodeWord(13); // CH_ADD
    sMarker = decodeWord(15); // X_PTR
    head.calcStack  = decodeWord(17);
    head.spareArea = decodeWord(19);
    bReg = decodeByte(21);
    head.calcMem = decodeWord(22);
    // 24 is unused
    displayBottomLines = decodeByte(25); // DF_SZ
    topProgramLine = decodeWord(26); // S_TOP
    lastKeyPress = decodeWord(28); // LAST_K
    // 30 is debounce
    margin = decodeByte(31); // MARGIN
    nextLine = decodeWord(32); // NXTLIN
    oldPPC = decodeWord(34); // OLDPPC
    flags = decodeByte(36); // FLAGX
    strlen = decodeWord(37); // STRLEN
    synTblAddr = decodeWord(39); // T_ADDR
    seed = decodeWord(41); // SEED
    frames = decodeWord(43); // FRAMES
    xCoord = decodeByte(45);
    yCoord = decodeByte(46);
    // 47 is printer stuff
    pCol = decodeByte(48);
    pLine = decodeByte(49);
    cdFlags = decodeByte(50);
    // @51: 33 bytes of print buffer, last char is NEWLINE
    // @84: 30 bytes of calculator memory (MEMBOT)
    // @114: 2 unused bytes
    // @116: END of system variables, start of program
    head.length = size(bytes);
	

	int maxAddress = tapeBottom + size(bytes);
	if(size(bytes) < (head.displayArea - tapeBottom)) {
		throw "Display area beyond end of file!";
	}
	
	if(head.displayArea < programArea
		|| head.variableArea < head.displayArea
		|| head.workArea < head.variableArea) {
		throw "Illegal memory layout";	
	}
	
	head.program = bytes[programArea - tapeBottom..head.displayArea - tapeBottom];
	head.display = bytes[head.displayArea - tapeBottom..head.variableArea - tapeBottom];
	head.variables = bytes[head.variableArea - tapeBottom..head.workArea - tapeBottom];
	return head;
}

public void printHeader(PFile head) {
	println("Memory layout:");
	println("   0000  \u2588 ZX81 ROM");
	println("   4000  \u259B ZX81 RAM");
	println("   <toHex(tapeBottom,4)>  \u258C\u259BStart of tape");
	println("   <toHex(head.calcMem,4)>  \u258C\u258CCalculator memory");
	println("   <toHex(programArea,4)>  \u258C\u258CProgram area");
	println("   <toHex(head.displayArea,4)>  \u258C\u258CDisplay area");
	println("   <toHex(head.variableArea,4)>  \u258C\u258CVariable area");
	println("   <toHex(tapeBottom+head.length, 4)>  \u258C\u2599End of tape");
	println("   <toHex(head.workArea,4)>  \u258C Work area");
	println("   <toHex(head.spareArea,4)>  \u258C Spare area");
	println("   <toHex(head.calcStack,4)>  \u258C Calculator stack");
	println("   <toHex(ramTop, 4)>  \u2599 RAMTOP");
}

public list[int] encodePFile(Program p) {
	PFile pf = PFile();
	pf.program = tokens(p.lines);
	// pf.variables = tokens(p.variables);
	return encodePFile(pf);
}

public list[int] encodePFile(PFile head) {
	list[int] bytes = stdHeader;
	void encodeByte(int offset, int val) { bytes[offset] = val; }
	void encodeWord(int offset, int val) {
		bytes[offset..offset+2] = encodeUInt16(val);
	}
	// FIRST: compute display area, variable area, work area

	head.displayArea = programArea + size(head.program);
	//if(head.display == []) {
		list[int] line = [0 | i <- [0..32]] + 118;
		head.display = [118] + [*line | i <- [0..24]];
	//}
	
	head.variableArea = head.displayArea + size(head.display);
	head.workArea = head.variableArea + size(head.variables) + 1;
	head.calcStack = head.workArea;
	head.spareArea = head.workArea;
	if(head.displayArea < programArea
		|| head.variableArea < head.displayArea
		|| head.workArea < head.variableArea) {
		throw "Illegal memory layout";	
	}
	
	encodeByte(0, 0); // VERSN
    encodeWord(1, head.currentLine); // E_PPC
    encodeWord(3, head.displayArea); // D_FILE
    encodeWord(5, head.printPosition); // DF_CC
    encodeWord(7, head.variableArea); // VARS
    encodeWord(11, head.workArea);
    encodeWord(17, head.calcStack);
    encodeWord(19, head.spareArea);
    encodeWord(32, 0);
    encodeWord(34, 0);
    encodeWord(13, 0);
    //encodeWord(22, head.calcMem);

	if(tapeBottom + size(bytes) != programArea)
		throw "Expected program start at <programArea>, was <tapeBottom + size(bytes)>";
	bytes += head.program;
	if(tapeBottom + size(bytes) != head.displayArea)
		throw "Expected D_FILE start at <head.displayArea>, was <tapeBottom + size(bytes)>";
	bytes += head.display;
	if(tapeBottom + size(bytes) != head.variableArea)
		throw "Expected VARS start at <head.variableArea>, was <tapeBottom + size(bytes)>";
	bytes += head.variables;
	bytes += 0x80;
	if(tapeBottom + size(bytes) != head.workArea)
		throw "Expected E_LINE start at <head.workArea>, was <tapeBottom + size(bytes)>";
	
	println("Program: <size(bytes)> total, <size(head.program)> program, <size(head.variables)> vars"); 
	return bytes;
}


list[int] encodeVariable(str name, Value val) {
	switch(val) {
	case Num(n): {
		if(size(name) == 1) {
			return [96+charToZX81(name), *encodeBasicNum(n)];
		}
		else if(/<a:.><bs:.*><c:.>/ := name) {
			list[int] result = [160+charToZX81(a)];
			for(b <- split("", bs))
				result += [charToZX81(b)];
			result += [128+charToZX81(c)];
			return [*result, *encodeBasicNum(n)];
		}
	}
	case NumArray([l],vals): {
		list[int] result = [1, *encodeUInt16(l)];
		result += [*encodeBasicNum(n) | Num(n) <- vals];		 		
		result = [128+charToZX81(name)-0x20, *encodeUInt16(size(result)), *result];
		return result;
	}	
	case String(s): {
		list[int] result = [charToZX81(c) | c <- split("",s)];		 		
		result = [64+charToZX81(name)-0x20, *encodeUInt16(size(result)), *result];
		return result;		
	}
	case StringArray(dim,s): ;
	case ControlVar(val, limit, step, line): {
		return [224+charToZX81(name), *encodeBasicNum(val),
				*encodeBasicNum(limit), *encodeBasicNum(step),
				*encodeLineNum(line)];
	}
	}
}


public list[int] tokens(str s) {
	list[int] result = [];
	while(true) {
		if(/^<c:(\^\@|\^|\@|\\|)[^\^\@]>/ := s) {
		r = s[size(c)..];
		result += charToZX81(c);
		s = r;
		}
		else break;
	}
	return result;
}
public list[int] tokens((ZX81Expr)`<NUM n>`) {
	return [*tokens(unparse(n)), 0x7e, *encodeBasicNum(toReal(unparse(n)))];
}

public list[int] tokens((ZX81Expr)`<NUM n>`) {
	return [*tokens(unparse(n)), 0x7e, *encodeBasicNum(toReal(unparse(n)))];
}

public list[int] tokens((ZX81Expr)`<STRING s>`) {
	return tokens(unparse(s));
}

public list[int] tokens((ZX81Expr)`<NAME s>`) {
	return tokens(unparse(s));
}
public list[int] tokens((ZX81Expr)`<NAMECHAR s>$`) {
	return tokens(unparse(s)+"$");
}
public list[int] tokens((ZX81Expr)`INKEY$`) {
	return [charToZX81("INKEY$")];
}
public list[int] tokens((ZX81Expr)`<ZX81Expr e1>=<ZX81Expr e2>`) {
	return [*tokens(e1), charToZX81("="), *tokens(e2)];
}
public list[int] tokens((ZX81Expr)`AT <ZX81Expr e1>,<ZX81Expr e2>`) {
	return [charToZX81("AT"), *tokens(e1), charToZX81(","), *tokens(e2)];
}



public list[int] tokens((ZX81Expr)`<ZX81Fun f> <ZX81Expr e>`) {
	return [charToZX81(unparse(f)), *tokens(e)];
}

public list[int] tokens((ZX81Cmd)`REM <COMMENT comment>`)
	= [charToZX81("REM"), *tokens(unparse(comment))];
public list[int] tokens((ZX81Cmd)`PRINT <ZX81PrintArg* es>`) 
	= [charToZX81("PRINT"), *[*tokens(e) | e <- es]];
public list[int] tokens((ZX81PrintArg)`<ZX81Expr e>`) 
	= tokens(e);
public list[int] tokens((ZX81PrintArg)`,`) 
	= [charToZX81(",")];
public list[int] tokens((ZX81PrintArg)`;`) 
	= [charToZX81(";")];
public list[int] tokens((ZX81Cmd)`LPRINT <ZX81Expr e>`)
	= [charToZX81("LPRINT"), *tokens(e)];
public list[int] tokens((ZX81Cmd)`GOTO <ZX81Expr e>`)
	= [charToZX81("GOTO"), *tokens(e)];
public list[int] tokens((ZX81Cmd)`GOSUB <ZX81Expr e>`)
	= [charToZX81("GOSUB"), *tokens(e)];
public list[int] tokens((ZX81Cmd)`RETURN`)
	= [charToZX81("RETURN"), *tokens(e)];
public list[int] tokens((ZX81Cmd)`PLOT <ZX81Expr e1> , <ZX81Expr e2>`)
	= [charToZX81("PLOT"), *tokens(e1), *tokens(e2)];
public list[int] tokens((ZX81Cmd)`UNPLOT <ZX81Expr e1> , <ZX81Expr e2>`)
	= [charToZX81("UNPLOT"), *tokens(e1), *tokens(e2)];
public list[int] tokens((ZX81Cmd)`LET <ZX81Expr e1> = <ZX81Expr e2>`) 
	= [charToZX81("LET"), *tokens(e1), charToZX81("="), *tokens(e2)];
public list[int] tokens((ZX81Cmd)`FOR <NAME n> = <ZX81Expr e1> TO <ZX81Expr e2>`)
	= [charToZX81("FOR"), *tokens(n), charToZX81("="), *tokens(e1), charToZX81("TO"), *tokens(e2)];
public list[int] tokens((ZX81Cmd)`FOR <NAME n> = <ZX81Expr e1> TO <ZX81Expr e2> STEP <ZX81Expr e3>`)
	= [charToZX81("FOR"), *tokens(n), charToZX81("="), *tokens(e1),
		charToZX81("TO"), *tokens(e2), charToZX81("STEP"), *tokens(e3)];
public list[int] tokens((ZX81Cmd)`NEXT <NAME n>`)
	= [charToZX81("NEXT"), *tokens(n)];
public list[int] tokens((ZX81Cmd)`IF <ZX81Expr e> THEN <ZX81Cmd c>`)
	= [charToZX81("IF"), *tokens(e), charToZX81("THEN"), *tokens(c)];
public list[int] tokens((ZX81Cmd)`DIM <NAME n> ( <{ZX81Expr ","}+ es> )`)
	= [charToZX81("DIM"), *tokens(n), *tokens(e)];
public list[int] tokens((ZX81Cmd)`DIM <NAME n> $ ( <{ZX81Expr ","}+ es> )`)
	= [charToZX81("DIM"), *tokens(n), charToZX81("$"), *tokens(e)];
public list[int] tokens((ZX81Cmd)`LIST`) = [charToZX81("LIST")];
public list[int] tokens((ZX81Cmd)`LLIST`) = [charToZX81("LLIST")];
public list[int] tokens((ZX81Cmd)`STOP`) = [charToZX81("STOP")];
public list[int] tokens((ZX81Cmd)`CONT`) = [charToZX81("CONT")];
public list[int] tokens((ZX81Cmd)`SLOW`) = [charToZX81("SLOW")];
public list[int] tokens((ZX81Cmd)`FAST`) = [charToZX81("FAST")];
public list[int] tokens((ZX81Cmd)`NEW`) = [charToZX81("NEW")];
public list[int] tokens((ZX81Cmd)`CLEAR`) = [charToZX81("CLEAR")];
public list[int] tokens((ZX81Cmd)`SCROLL`) = [charToZX81("SCROLL")];
public list[int] tokens((ZX81Cmd)`CLS`) = [charToZX81("CLS")];
public list[int] tokens((ZX81Cmd)`PAUSE <ZX81Expr e>`)
	= [charToZX81("PAUSE"), *tokens(e)];
public list[int] tokens((ZX81Cmd)`POKE <ZX81Expr e1> , <ZX81Expr e2>`)
	= [charToZX81("POKE"), *tokens(e1), charToZX81(","), *tokens(e2)];
public list[int] tokens((ZX81Cmd)`RUN`)
	= [charToZX81("RUN")];
public list[int] tokens((ZX81Cmd)`RUN <ZX81Expr e>`)
	= [charToZX81("RUN"), *tokens(e)];
public list[int] tokens((ZX81Cmd)`SAVE <STRING s>`)
	= [charToZX81("SAVE"), *tokens(unparse(s))];
public list[int] tokens((ZX81Cmd)`RAND <ZX81Expr e>`)
	= [charToZX81("RAND"), *tokens(e)];
public list[int] tokens((ZX81Cmd)`COPY`) = [charToZX81("COPY")];

public list[int] tokens(int line, ZX81Cmd cmd) {
	println(cmd);
	list[int] lineToks = [*tokens(cmd), 118];
	lineToks = [*encodeLineNum(line), *encodeUInt16(size(lineToks)), *lineToks];
	//println(lineToks);
	return lineToks;
}

public list[int] tokens(map[int,ZX81Cmd] lines) {
	lineNums = sort(domain(lines));
	return [*tokens(line, lines[line]) | line <- lineNums];
}

