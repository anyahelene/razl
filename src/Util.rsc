module Util
import ParseTree;
import IO;
import Set;
import String;
import Node;


public void showAmb(Tree t) {
	str shortStr(Tree a) = "\"<replaceAll(unparse(a),"\n","\\n")[..20]>\"";
	str applToStr(a:appl(p,_)) = "<prodToStr(p)>  :=  <shortStr(a)>";
	str applToStr(a:char(i)) = "char(<i>)  :=  <shortStr(a)>";
	str applToStr(a:cycle(s,i)) = "cycle(<printSymbol(s, true)>, <i>)  :=  <shortStr(a)>";
	str applToStr(a:amb(_)) = "amb(...)  :=  <shortStr(a)>";
	str prodToStr(p:prod(s,as,_)) = "<printSymbol(s, true)> = <intercalate(", ", [printSymbol(a, true) | a <- as])>;";
	str prodToStr(p:regular(s)) = "<printSymbol(s, true)>";
	default str prodToStr(Tree p) = "unknown prod: <[p]>\n";

	top-down-break visit(t) {
		case x:amb(as): {
			println("Ambiguity: ");
			println("  while parsing <shortStr(x)>");
			int i = 1;
			as = visit(as) { case amb(ts) => getOneFrom(ts) }
			for(a <- delAnnotationsRec(as)) {
				println("Interpretation #<i>:");
				println("    <applToStr(a)>");
				println("  with");
				for(s <- a.args) {
					println("    <applToStr(s)>");
				}
				println();
				i = i + 1;
			}
		}
	}
}

public str unescape(str s) {
  return visit (s) {
    case /\\b/ => "\b"
    case /\\f/ => "\f"
    case /\\n/ => "\n"
    case /\\t/ => "\t"
    case /\\r/ => "\r"  
    case /\\\"/ => "\""  
    case /\\\'/ => "\'"
    case /\\\\/ => "\\"
  };      
}

public str escape(str s) {
  return escape(s, ("\\" : "\\\\",
  		"\'" : "\\\'",
  		"\"" : "\\\"",
    	"\b" : "\\b",
    	"\f" : "\\f",
	    "\n" : "\\n",
	    "\t" : "\\t",
	    "\r" : "\\r")); 
}

public str quote(str s) = "\"<escape(s)>\"";
public str unquote(/"<s:.*>"/) = unescape(s);
