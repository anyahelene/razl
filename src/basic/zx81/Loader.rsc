module basic::zx81::Loader
import String;
import List;
import Set;
import Map;
import util::Math;
import ParseTree;
import IO;
import basic::zx81::Syntax;
import basic::zx81::Charset;

public Program readLines(str ls)
	= readLines(parse(#start[ZX81Lines], ls).top);

public Program readLines(loc ls) {
	str file = readFileEnc(ls, "utf8");
	return readLines(parse(#start[ZX81Lines], file, ls).top);
}

public int autoInc(int line, int step) = round(toReal(line+step)/step)*step;

public Program readLines(ZX81Lines ls) = readLines(ls, Program());
		
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
