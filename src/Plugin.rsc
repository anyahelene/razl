module Plugin

import util::IDE;
import ParseTree;
import IO;
import assembly::Unified;
import assembly::Z80;

void main() {
   //registerLanguage("TAC", "tac", Tree(str src, loc l) {
   //  pt = parse(#start[TacProgram], src, l);
   //  return pt;
   //});

   registerLanguage("Z80", "z80", Tree(str src, loc l) {
     pt = parse(#start[Program], src, l);
     return annotate(pt);
   });
}