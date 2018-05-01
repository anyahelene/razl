module assembler::Unified

syntax Atom
	= IdentifierAtom val
	| Number val
	;
	
syntax IdentifierAtom 
	= @category="Normal" Identifier val
	;
	
syntax Operand
	= Atom val
	| "(" Atom val ")"
	| "(" Atom val "+" Atom offset ")" 
	| @category="MetaVariable" "\'" Char "\'"
	| @category="MetaVariable" "\"" Char* "\""
	;
syntax Number = DecimalNumber | BinaryNumber | HexNumber;

lexical DecimalNumber = [\-]? DecimalDigits;
lexical BinaryNumber = "%" BinaryDigits;
lexical HexNumber = "$" HexDigits | "0x" HexDigits | HexDigits [hH]; 
lexical DecimalDigits = [\-]? [0-9]+ !>> [0-9a-fA-F];
lexical BinaryDigits =  [0-1]+ !>> [0-9a-fA-F];
lexical HexDigits =  [0-9a-fA-F]+ !>> [0-9a-fA-F];
lexical IdChars
	= [a-zA-Z] [_a-zA-Z0-9.]*
	| [_.]+ [a-zA-Z0-9]+ [_a-zA-Z0-9.]*
	;
lexical Identifier = IdChars !>> [_a-zA-Z0-9.];
lexical Char
	= ![\'\"\n\\] 
	| [\\] [\'\"\\rnbf]
	| [\\] [x] [0-9a-fA-F] [0-9a-fA-F]
	| [\\] [u] [0-9a-fA-F] [0-9a-fA-F] [0-9a-fA-F] [0-9a-fA-F]
	;
	
start syntax Program = Instruction* instructions;

lexical EMPTY = ;
lexical EOL = EMPTY $;
lexical SOL = ^ EMPTY;
lexical Com = @category="Comment" ";" ![\r\n]*;
lexical WS = [\ \t];
layout Layout = WS* !>> [\ \t];

syntax Instruction
	= @label="foo" Label? label OpCodeName opCode {Operand ","}* operands Com? $
	| "#" "define" Identifier name ![\r\n]* expansion $
	| SOL Com? $
	;
syntax OpCodeName = @category="Constant" Identifier;
syntax Label = @category="Identifier" ^ Identifier;

anno loc WS@\loc;

anno loc Layout@\loc;
anno loc Instruction@\loc;
anno loc Tree@\loc;
