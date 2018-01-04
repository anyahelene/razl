@doc{TicTacToe Intermediate Languages – Common Syntax}
module intermediate::TTT

import ParseTree;
extend lang::std::Layout;

lexical Id = [a-z A-Z 0-9 _] !<< [a-z A-Z_][a-z A-Z 0-9 _]* !>> [a-z A-Z 0-9 _]
          ;

syntax TttLabel
	= @category="Identifier" Label: Id name ":"
	;

syntax TttVariable
	= Var: Id name
	| Id name TttSymbol sym
	;

syntax TttSymbol
	= Sym: "#" Id name
	;

syntax TttLiteral
	= LiteralNum: NUMLIT numValue 
	| LiteralChar: CHARLIT charValue
	;

syntax TttConstant
	= TttSymbol sym
	| TttLiteral lit
	| "?"
	> "(" TttConstant val ")"
	| "-" TttConstant rhs
	| "~" TttConstant rhs
	| TttConstant "(" {TttConstant ","}* ")"
	> TttConstant val "[" TttConstant idx "]"
	| TttConstant val "[" TttConstant? idx1".." TttConstant? idx2"]"
	| TttConstant val ("bit" | "bits")
	| TttConstant val ("byte" | "bytes")
	> "(" {TttSymbol ","}* ")" "=\>" TttConstant
	| "if" TttConstant "then" TttConstant "else" TttConstant
	| "let" TttSymbol "=" TttConstant "in" TttConstant
	> left TttConstant lhs "*" TttConstant rhs
	| left TttConstant lhs "/" TttConstant rhs
	> left TttConstant lhs "+" TttConstant rhs
	| left TttConstant lhs "-" TttConstant rhs
	> left TttConstant lhs "&" TttConstant rhs
	| left TttConstant lhs "|" TttConstant rhs
	| left TttConstant lhs "^" TttConstant rhs
	> left TttConstant lhs "\>" TttConstant rhs
	|  left TttConstant lhs "\>=" TttConstant rhs
	|  left TttConstant lhs "\<" TttConstant rhs
	|  left TttConstant lhs "\<=" TttConstant rhs
	|  left TttConstant lhs "==" TttConstant rhs
	|  left TttConstant lhs "!=" TttConstant rhs
	;
	
syntax TttBasicExpr	= TttVariable | TttConstant;

syntax TttBasicType
	= "data" "(" {TttTypeModifier ","}* ")"
	;
syntax TttTypeModifier
	= "bits" "=" TttConstant
	| "count" "=" TttBasicExpr
	| "type" "=" TttTypeName
	| "layout" "=" TttSymbol
	| TttConstant
	;
syntax TttTypeName = "logic" | "integer" | "float" | "signed" | "unsigned" | "object";
syntax TttVarModifiers = "(" {TttVarModifier ","}* ")";
	
syntax TttVarModifier
	= "align" "(" NUM ")"
	| TttAccessGroup
	;
	
lexical TttAccessChar = "r" | "w" | "x";
lexical TttAccessGroup = PLUSORMINUS? TttAccessChar+ EXCLAMATION?;
lexical PLUSORMINUS = [\-+];
lexical EXCLAMATION = [!];
lexical NUM
	= [a-zA-Z0-9_] !<< [0-9]+ !>> [a-zA-Z0-9_]
	;

lexical NUMLIT
	= NUM
	| [a-zA-Z0-9_] !<< [0] [x] [0-9a-fA-F]+ !>> [a-zA-Z0-9_]
	| [a-zA-Z0-9_] !<< [0] [b] [0-1]+ !>> [a-zA-Z0-9_]
	| [a-zA-Z0-9_] !<< [0] [d] [0-9]+ !>> [a-zA-Z0-9_]
	| [a-zA-Z0-9_] !<< [0] [o] [0-7]+ !>> [a-zA-Z0-9_]
	;

lexical CHARLIT = [\'] CHAR [\'];

lexical STRLIT = [\"] CHAR* [\"];

lexical CHAR
	= ![\a00-\a19 \" \' \\]
	| [\\] [\" \' \\ b f n r t]
	| [\\] [x] [0-9a-fA-F] [0-9a-fA-F]
	| [\\] [u] [0-9a-fA-F] [0-9a-fA-F] [0-9a-fA-F] [0-9a-fA-F]
	| [\\] [U] [0-9a-fA-F] [0-9a-fA-F] [0-9a-fA-F] [0-9a-fA-F] [0-9a-fA-F] [0-9a-fA-F]
	;
	
	
public list[TttVarModifier] varModifiers(Tree t)
	= [m | /TttVarModifier m <- t];
	

