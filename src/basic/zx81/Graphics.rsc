module basic::zx81::Graphics
import String;
import List;
import IO;
import basic::zx81::Charset;



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