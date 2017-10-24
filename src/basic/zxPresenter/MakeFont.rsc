module basic::zx81::MakeFont
import IO;
import String;
import List;
import basic::ZX81Basic;

list[str] uc = [stringChar(l) | l  <- [65..65+26]];
list[str] lc = [toLowerCase(stringChar(l)) | l  <- [65..65+26]];
list[str] dg = [stringChar(l) | l  <- [48..48+10]];

// for(c <- uc+lc) { println(intercalate("\n", ["<charAt(c,0)> c", *["<l>$@" | l <- split("\n",pixelize(|file:///home/anya/git/hiptext/letters/<c>-16.txt|))]])+"@\n"); }


public str makeFont(str name, int w, int h, bool hash = false) {
	s = "flf2a$ <h> <(h*90)/100> <w> 0 0 0 126\n" + intercalate("", [figLetter(pixLetter(stringChar(i), w, h)) | i <- [32..127]]);
	return hash ? hashize(s) : s;		
}

public str makeScript(str name, str font, int w, int h) {
	str s = "";
	for(i <- [33..127]) {
		name = stringChar(i);
		char = name == " " ? "\u00a0" : name;
		char = escape(char, ("\"":"\\\\\\\"", "\\":"\\\\\\\\", "\'":"\\\'", "$":"\\$", "`":"\\`"));
		if(/[a-zA-Z0-9]/ !:= name)
			name = "<i>";
		s += "echo <i> \"<char>\" <name>-<w>x<h>.jpg\n";
		s += "convert -background \'#feffff\' -fill black -font Sinclair_ZX_Spectrum_ES/sinclair_zx_spectrum_es.ttf  -size <w*2>x<h*2> -pointsize <h*2> label:\"<char>\" letters/<name>-<w>x<h>.jpg\n";
		s += "./hiptext -nocolor -bg white -chars \' +#\' -width <w*4> -height <h*4> letters/<name>-<w>x<h>.jpg \> letters/<name>-<w>x<h>.txt\n";
	}
	return s;
}

public str figLetter(str glyph) {
	return intercalate("\n", ["<l>$@" | l <- split("\n",glyph)])+"@\n"; 
}

public str pixLetter(str letter, int w, int h) {
	loc f;
	if(/[a-zA-Z0-9]/ := letter)
		f = |file:///home/anya/git/hiptext/letters/<letter>-<"<w>x<h>">.txt|;
	else
		f = |file:///home/anya/git/hiptext/letters/<"<charAt(letter,0)>">-<"<w>x<h>">.txt|;
	if(exists(f)) {
		return pixelize(f, true);
	}
	else {
		l = intercalate("", [" " | i <- [0 .. w]]);
		return intercalate("", ["<l>\n" | i <- [0 .. h]]);
	}
}