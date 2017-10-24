module basic::zxPresenter::Presenter
import List;
import String;
import IO;

import basic::zx81::zx81Basic;

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
	// println(result);
	
	// NOTE: it  might be "purer" to generate the tree directly using
	// concrete syntax, but making text and parsing it is easy and it works
	return readLines(parse(#start[ZX81Lines], result, ls).top);
}
