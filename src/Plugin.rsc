module Plugin

import util::IDE;
import ParseTree;
import IO;
import assembler::Unified;
import assembler::z80::Z80;
import basic::zx81::Syntax;
import intermediate::TIC;

void main() {
   registerLanguage("TIC", "tic", Tree(str src, loc l) {
     pt = parseTic(src);
     return pt;
   });
   registerLanguage("TAC", "tac", Tree(str src, loc l) {
     pt = parse(#start[TacProgram], src, l);
     return pt;
   });

   registerLanguage("Z80", "z80", Tree(str src, loc l) {
     pt = parse(#start[Program], src, l);
     //return annotate(pt);
     return pt;
   });
   
   //registerAnnotator("z80", Tree (Tree t) { println("anno!"); return t[@doc="Hello!"]; });
   
   registerContributions("Z80", {
   	annotator(Tree (Tree t) { return (assembler::z80::Z80::annotate(t))[@doc="foo!"]; }),
   	builder(set[Message] (Tree t) { println("build!"); return {error("foo", t@\loc)}; })
   	});
   
   registerLanguage("ZX81 BASIC", "zxb", Tree(str src, loc l) {
     pt = parse(#start[ZX81Lines], src, l);
     return pt;
   });}