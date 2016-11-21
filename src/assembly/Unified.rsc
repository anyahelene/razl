module assembly::Unified

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

syntax EMPTY = ;
syntax EOL = EMPTY $;
syntax Comment = @category="Comment" ";" ![\n]* $;
syntax Whitespace = [\ \t\n];
layout Layout = (Comment | Whitespace)* !>> [\ \t\n];

syntax Instruction
	= @label="foo" Label? label OpCodeName opCode {Operand ","}* operands $
	;
syntax OpCodeName = @category="Constant" Identifier;
syntax Label = @category="Identifier" ^ Identifier;

anno loc Whitespace@\loc;

anno loc Layout@\loc;
anno loc Instruction@\loc;
anno loc Tree@\loc;
