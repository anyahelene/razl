module intermediate::TIC

import ParseTree;
extend intermediate::TTT;
import Util;
import IO;
import String;

start syntax TicProgram = TicStatement* stats;

	
syntax TicStatement
	= Stat: TttLabel? label TicCondition cond TicInstrMod TicInstruction instr $
	| @doc="Defines a local scope for names"
      Block: TttLabel label TicInstrMod "{" TicStatement* stats "}" $
    // | Labeled: TttLabel label "\n" // TODO: bug: "Node has no alternatives"
	;
	
syntax TicCondition
	= If: "if" TicCondExpr
	| Unless: "unless" TicCondExpr
	| Always:
	;
syntax TicInstruction
    = @doc="Declare variable"
        VarDecl: "#" "var" TttVarModifiers? TicType? typ {TttVariable ","}+ names
    |	Assign: "#" "let" TttSymbol "=" TttConstant
    | @doc="Apply operator, assign result to target"
    	ApplyOp: "let" {TicExpr ","}+ targets "=" TttVariable name "(" {TicExpr ","}* args ")"
    | @doc="Apply operator, assign result to target"
    	ApplySub: "let" {TicExpr ","}+ targets "=" "call" TicExpr sub "(" {TicExpr ","}* args ")"
    | @doc="Jump to dest"
    	Goto: "goto" TicExpr dest
    | @doc="Set up args, push return address, jump to sub"
    	Call: "call" TicExpr sub "(" {TicExpr ","}* args ")"
    | @doc="Pop and jump to return address"
    	Return: "return"
    | @doc="Pop and jump to return address, with one or more return values"
    	Return: "return" {TicExpr ","}+
    | @doc="An error"
    	Error: "#" "error" STRLIT msg "," Id level
	| Use: "#" "use" TicType
	| Use: "#" "use" TicBasicType "=" TicType
	| Const: "#" "const" TttConstant
	| Define: "#" "define" {TicTypedExpr ","}+ returns "=" Id name "(" {TicTypedExpr ","}* ")" "{" TicStatement* "}"
	;

lexical TicInstrMod
	= [!]
	|
	;

syntax TicTypedExpr
	= TicType TicExpr
	;
		
syntax TicExpr
	= TttBasicExpr
	;

syntax TicCondExpr
	= TicExpr
	| TttBasicExpr CONDOP TttBasicExpr
	;
	
lexical CONDOP = "\<" | "\>" | "==" | "\<=" | "\>=" | "!=";

syntax TicBasicType = @category="Type" Id \ "data";
syntax TicModifiedType
	= Basic: TicBasicType
	| TttBasic: TttBasicType
	| Modified: TicBasicType "(" {TttTypeModifier ","}* ")";
	
syntax TicType
	= Scalar: TicModifiedType
	| Vector: TicModifiedType "[" TicExpr "]"
	;
		
public str stdTicPrelude 
	= "use int = bits(32,signed,integer)\n"
	+ "use uint = bits(32,unsigned,integer)\n"
	+ "use flt = bits(single,floating)\n"
	+ "use ptr = bits(64,signed,integer)\n"
	+ "use byte = bits(8)\n"
	+ "use word = bits(32)\n"
	+ "use int\n"
	;
	
public TicProgram parseTic(str s) = parseTic(s, |unknown:///|);

public TicProgram parseTic(str s, loc l) {
	try {
		return parse(#start[TicProgram], s, l).top;
	}
	catch e:Ambiguity(_,_,_): {
  		showAmb(parse(#start[TicProgram], s, l, allowAmbiguity=true));
  		throw e;
  	}
}

public TicProgram parseTic(loc l) {
	try {
	  return parse(#start[TicProgram], l).top;
	}
	catch e:Ambiguity(_,_,_): {
  		showAmb(parse(#start[TicProgram], l, allowAmbiguity=true));
  		throw e;
  	}
}

public TicProgram simplify(TicProgram p) = simplifyIt(p);

public map[str,str] operators = (
	"+/2" : "add",
	"-/2" : "sub",
	"*/2" : "mul",
	"//2" : "div",
	"-/1" : "neg",
	"&/2" : "and",
	"|/2" : "or",
	"^/2" : "xor",
	"~/2" : "not",
	"%/2" : "mod",
	"\<\</2" : "shl",
	"\>\>/2" : "ashr",
	"\<\<\</2" : "rol",
	"\>\>\>/2" : "ror",
	"0\>\>/2" : "shr"
);
public &T simplifyIt(&T t) {
	return visit(t) {
		case (TicInstruction)`#var <{TttVariable ","}+ vars>`
			=> (TicInstruction)`#var () default <{TttVariable ","}+ vars>`
		case (TicInstruction)`#var <TicType t> <{TttVariable ","}+ vars>`
			=> (TicInstruction)`#var () <TicType t> <{TttVariable ","}+ vars>`
		case (TicInstruction)`#var <TttVarModifiers vms> <{TttVariable ","}+ vars>`
			=> (TicInstruction)`#var <TttVarModifiers vms> default <{TttVariable ","}+ vars>`
	}
}

alias DataType = tuple[TicValue kind, TicValue lay, TicValue bits, TicValue count];

data TicValue
	= Int(int i) | Symbol(str s) 
	| Type(DataType typ) 
	| Var(str s)
	| VarSpec(DataType typ, VarMode mode) 
	| Constant(TttConstant c) 
	| Builtin(str s)
	| Macros(set[Macro] macros)
	| Fun(list[str] params, TttConstant body, TicEnv env)
	| Unbound()
	;
data Macro = Macro(str name, list[DataType] paramTypes, list[str] paramNames, list[DataType] returnTypes, list[str] returnNames, list[TicStatement] body, TicEnv env);
data VarAccess = Yes() | No() | Forced() | UnknownAccess();
data Access = Read() | Write() | Execute() | Deref(Access acc);
alias VarMode = tuple[int align, VarAccess read, VarAccess write, VarAccess execute];

public DataType unknownType = <Unbound(),Unbound(),Unbound(),Unbound()>; 
public VarMode unknownMode = <0,UnknownAccess(),UnknownAccess(),UnknownAccess()>;

alias TicEnv = map[str,TicValue];

public tuple[TicEnv,list[TicStatement]] resolveLabels(TicProgram p)
	= resolveLabels([s | s <- p.stats], (), "");

public tuple[TicEnv,list[TicStatement]] resolveLabels(list[TicStatement] p, TicEnv env, str scope) {
	set[str] locals = {};
	list[TicStatement] stats = [];
	
	for(TicStatement stat <- p) {
		switch(stat) {
		case (TicStatement)`<TttLabel l> <TicCondition c> <TicInstrMod m> <TicInstruction i>`:
			{
				str labelName = unparse(l.name);
				locals += labelName;
				str label = "<scope><labelName>";
				if("#<label>" in env) {
					throw "redefining label <label>";
				}
				if((TicInstruction)`#const <TttConstant const>` := i) {
					env["#<label>"] = Constant(const);
				}
				else {
					env["#<label>"] = Symbol(label);
					l.name = parse(#Id, label);
					stats += (TicStatement)`<TttLabel l> <TicCondition c> <TicInstrMod m> <TicInstruction i>`;
				}
			}
		case (TicStatement)`<TttLabel l> <TicInstrMod m> { <TicStatement* ss> }`:
			{
				str labelName = unparse(l.name);
				locals += labelName;
				str label = "<scope><labelName>";
				if("#<label>" in env) {
					throw "redefining label <label>";
				}
				env["#<label>"] = Symbol(label);
				<env,subList> = resolveLabels([s | s <- ss], env, "<label>_");
				stats += parse(#TicStatement, "<label>:{}");
				stats += subList;
			}
		default: {
			stats += stat;
			}
		}
	}
	&T rename(&T val) = visit(val) {
		case (TttSymbol)`#<Id name>`: {
			str n = unparse(name);
			if(n in locals) {
				insert parse(#TttSymbol, "#<scope><name>");
			}
		}
	};
	stats = rename(stats);
	for(l <- locals)
		env["#<scope><l>"] = rename(env["#<scope><l>"]);

	return <env, stats>;
}

public list[TicStatement] normalize(tuple[TicEnv, list[TicStatement]] args)
	= normalize(args[1], args[0]);

public list[TicStatement] normalize(list[TicStatement] p, TicEnv env) {
	str currentLabel = "";
	int currentParam = 0;
	list[TicStatement] stats = [];

	for(stat <- p) {
		switch(stat) {
			case (TicStatement)`<TttLabel? l> <TicCondition c> <TicInstrMod m> <TicInstruction instr>`: {
				if(unparse(l) != "") {
					currentLabel = unparse(l)[..-1];
				}
				
				switch(instr) {
					case (TicInstruction)`#use <TicType t>`: {
						env["@default"] = Type(decodeType(t, env));
						continue;
					}
					case (TicInstruction)`#use <TicBasicType t1> = <TicType t2>`: {
						env["@<unparse(t1)>"] = Type(decodeType(t2, env));
						continue;
					}
					case (TicInstruction)`#define <{TicTypedExpr ","}+ returns> = <Id name>(<{TicTypedExpr ","}* params>) { <TicStatement* body> }`: {
						list[DataType] paramTypes = [];
						list[str] paramNames = [];
						list[DataType] returnTypes = [];
						list[str] returnNames = [];
						
						for((TicTypedExpr)`<TicType pt> <Id n>` <- returns) {
							returnTypes += decodeType(pt, env);
							returnNames += "<n>";
						}
						for((TicTypedExpr)`<TicType pt> <Id n>` <- params) {
							paramTypes += decodeType(pt, env);
							paramNames += "<n>";
						}
						ms = env["%<name>"] ? Macros({});
						ms.macros = ms.macros + Macro("<name>",paramTypes,paramNames,returnTypes,returnNames,[b | b <- body],());					
						env["%<name>"] = ms; 
						continue;
					}
					case (TicInstruction)`#var <TttVarModifiers vms> <TicType t> <{TttVariable ","}+ vars>`: {
						typ = decodeType(t, env);
						mode = unknownMode;
						for(/TttVarModifier vm <- vms.args)
							mode = decodeVarModifier(mode, vm); 
						t = encodeType(typ);
						vms = encodeVarModifiers(mode);
						for(v <- vars) {
							env["<v>"] = VarSpec(typ, mode);
							stats += (TicStatement)`#var <TttVarModifiers vms> <TicType t> <TttVariable v>`; 
						}
						continue;
					}
					case (TicInstruction)`#let #<Id sym> = <TttConstant expr>`: {
						env["#<sym>"] = evalExpr(expr, env);
						continue;
					}					
					case (TicInstruction)`let <{TicExpr ","}+ targets> = <TttVariable name>(<{TicExpr ","}* argTrees>)`: {
						println(instr);
						list[TicExpr] outs = [t | t <- targets];
						list[TicExpr] argExprs = [];
						list[DataType] argTypes = [];
						for(a <- argTrees) {
							<ae, at, env> = compileExpr(a, unknownType, Read(), env);
							argExprs += ae;
							argTypes += at;
						}
						if(Macros(cands) := env["%<name>"]?Unbound()) {
							if({mac} := resolveOverload("<name>",cands, [a | a <- argTypes])) {
								map[str,TicExpr] bindings = ();
								for(i <- index(mac.paramNames)) {
									while(true) {
									try {
										println(argExprs[i]);
										<ae, at, env> = compileExpr(argExprs[i], mac.paramTypes[i], Read(), env);
										bindings[mac.paramNames[i]] = ae;
										break;
									}
									catch <corrected,corrStats,corrEnv>: {
										argExprs[i] = corrected;	stats += corrStats;	env = corrEnv;
									}
									}
								}
								for(i <- index(mac.returnNames)) {
									while(true) {
									try {
										<oute,outt,env> = i < size(outs) ? compileExpr(outs[i], mac.returnTypes[i], Write(), env) : <(TicExpr)`_`, unknownType, env>;
										bindings[mac.returnNames[i]] = oute;
										break;
									}
									catch <corrected,corrStats,corrEnv>: {
										outs[i] = corrected; stats += corrStats; 	env = corrEnv;
									}
									}
								}
								println("Bindings: <mac.env>");
								body = visit(mac.body) {
								case (TicExpr)`<Id n>`: { str s = "<n>"; if(s in bindings) insert bindings[s]; }
								case (TttConstant)`#<Id n>`: { str s = "#<n>"; if(s in mac.env) insert valueToExpr(mac.env[s]);}
								case (TttVariable)`<Id v>#<Id n>`: { str s = "#<n>"; if(s in mac.env) {insert parse(#TttVariable, "<v><unparse(valueToExpr(mac.env[s]))>");}}
								}
								println("Expanding macro: <body[0]>...");
								stats += normalize(body, env);
								continue;
							}
						}
						else { // not a macro
							instr = parse(#TicInstruction, "let <intercalate(",", [unparse(x) | x <- outs])> = <name>(<intercalate(",", [unparse(x) | x <- argExprs])>)");
							stat = (TicStatement)`<TttLabel? l> <TicCondition c> <TicInstrMod m> <TicInstruction instr>`;
						}
					}
				}
				
				stat = visit(stat) {
					case TicType t => encodeType(decodeType(t, env)[0])
				}
				stats += stat;
				currentLabel = "";
			}
			case (TicStatement)`<TttLabel l> {}`: {
				currentLabel = unparse(l)[..-1];
			}
			/*case (TicStatement)`<TttLabel l> `: {
				currentLabel = unparse(l)[..-1];
			}*/
		}		
	}
	return stats;
}

public DataType decodeType((TicType)`<TicBasicType t>`, TicEnv env)
	= env["@<t>"].typ;

public DataType decodeType((TicType)`<TicBasicType t>(<{TttTypeModifier ","}* mods>)`, TicEnv env)
	= mergeType(decodeType((TicType)`data(<{TttTypeModifier ","}* mods>)`, env), env["@<t>"].typ);

public DataType decodeType((TicType)`data(<{TttTypeModifier ","}* mods>)`, TicEnv env) {
	DataType bt = unknownType;
	for(TttTypeModifier m <- mods) {
		switch(m) {
			case (TttTypeModifier)`type=<TttTypeName t>`: bt.kind = Symbol("<t>");
			case (TttTypeModifier)`<TttConstant n>`: bt.bits = evalExpr(n, env);
			case (TttTypeModifier)`bits=<TttConstant n>`: bt.bits = evalExpr(n, env);
			case (TttTypeModifier)`count=<TttConstant e>`: bt.count = evalExpr(e, env);
			case (TttTypeModifier)`layout=#<Id s>`: bt.lay = Symbol("#<s>");
		}
	}
	return bt;
}

public DataType mergeType(DataType thisType, DataType otherType) {
	if(thisType.kind == Unbound())
		thisType.kind = otherType.kind;
	if(thisType.kind == Symbol("integer") && otherType.kind in [Symbol("signed"), Symbol("unsigned")])
		thisType.kind = otherType.kind;
	if(thisType.lay == Unbound())
		thisType.lay = otherType.lay;
	if(thisType.bits == Unbound())
		thisType.bits = otherType.bits;
	if(thisType.count == Unbound())
		thisType.count = otherType.count;
	return thisType;
}
public default tuple[DataType,VarMode] decodeType(TicType t, TicEnv env) {
	throw "unknown type: <t>";
}

public TttVarModifiers encodeVarModifiers(VarMode mode) {
	list[str] mods = [];
	if(mode.align != 0)
		mods += "align(<mode.align>)";
	for(<m,c> <- [<mode.read, "r">, <mode.write, "w">, <mode.execute, "x">]) {
		switch(m) {
		case Yes(): mods += "+<c>";
		case No(): mods += "-<c>";
		case Forced(): mods += "+<c>!";
		}
	}
	return parse(#TttVarModifiers, "(<intercalate(",",mods)>)");
}
public VarMode decodeVarModifier(VarMode mode, (TttVarModifier)`align(<NUM n>)`) {
	mode.align = toInt("<n>");
	return mode;
}

public VarMode decodeVarModifier(VarMode mode, (TttVarModifier)`<PLUSORMINUS? pm><TttAccessChar+ cs><EXCLAMATION? f>`) {
	acc = UnknownAccess();
	yes = "<f>" == "!" ? Forced() : Yes();
	switch("<pm>") {
	case "+": acc = yes;
	case "-": acc = No();
	case "": {mode.read = No(); mode.write = No(); mode.execute = No(); acc = yes;}
	}
	letters = "<cs>";
	if(contains(letters, "r"))
		mode.read = acc;
	if(contains(letters, "w"))
		mode.write = acc;
	if(contains(letters, "x"))
		mode.execute = acc;
	return mode;
}

TicType encodeType(DataType typ) {
	list[str] args = [];
	if(Symbol(n) := typ.kind)
		args += "type=<n>";
	if(Symbol(n) := typ.lay)
		args += "layout=<n>";
	if(Int(i) := typ.bits)
		args += "bits=<i>";
	if(Int(i) := typ.count)
		args += "count=<i>";
	s = "data(<intercalate(",", args)>)";
	return parse(#TicType, s);		
}

public tuple[TicExpr,DataType,TicEnv] compileExpr(e:(TicExpr)`<TttVariable v>`, DataType expected, Access acc, TicEnv env) {
	if(VarSpec(typ,mode) := env["<v>"] ? Unbound()) {
		mTyp = mergeType(typ, expected);
		if(matchType(expected, mTyp,())[0] >= INVALID_SCORE) {
			throw "type doesn\'t match, expected <expected>, got <typ>";
		}
		else if(mTyp != typ) {
			env["<v>"] = VarSpec(mTyp, unknownMode);
			typeTree = encodeType(mTyp);
			idTree = parse(#Id, "<v>");
			throw <e, [(TicStatement)`#var () <TicType typeTree> <Id idTree>`], env>;
		}
		return <e, typ, env>;
	}
	else if(expected != unknownType) {
		env["<v>"] = VarSpec(expected, unknownMode);
		typeTree = encodeType(expected);
		idTree = parse(#Id, "<v>");
		throw <e, [(TicStatement)`#var () <TicType typeTree> <Id idTree>`], env>;
	}
	else {
		throw "Unknown variable: <v>";
	}
}

public tuple[TicExpr,DataType,TicEnv] compileExpr(e:(TicExpr)`<TttConstant c>`, DataType expected, Access acc, TicEnv env) {
	if(acc != Read())
		throw "constants are read-only: <acc> <c>";
	c = valueToExpr(evalExpr(c, env));
	return <(TicExpr)`<TttConstant c>`, mergeType(<Symbol("integer"), Unbound(), Unbound(), Unbound()>, expected), env>;
}

private int MAX_SCORE = 99999;
private int INVALID_SCORE = MAX_SCORE+1;

public set[Macro] resolveOverload(str name, set[Macro] macros, list[DataType] argTypes) {
	int bestScore = MAX_SCORE;
	set[Macro] best = {};
	println("Overload resolution for <name>(<argTypes>):");
	for(Macro m <- macros) {
		if(size(m.paramTypes) == size(argTypes)) {
			score = 0;
			TicEnv env = ();
			for(i <- index(m.paramTypes)) {
				<s,env> = matchType(m.paramTypes[i],argTypes[i], env);
				score += s;
			}
			print("    considering <m.paramTypes>, score <score>");
			m.env = env;
			if(score < bestScore) {
				best = {m};
				bestScore = score;
				print("... best so far!");
			}
			else if(score == bestScore) {
				best = best + m;
				print("... another candidate!");
			}
			else {
				print("... :(");
			}
			println();
		}
	}
	return best;
}

public tuple[int,TicEnv] matchType(DataType paramType, DataType argType, TicEnv env) {
	int score = 0;
	initEnv = env;
	for(<p,a> <- [<paramType.kind,argType.kind>, <paramType.lay,argType.lay>,
						<paramType.bits,argType.bits>, <paramType.count,argType.count>]) {
		if(Var(v) := p) 	p = env[v] ? p;
		if(Var(v) := a)		a = env[v] ? a;
		if(p == a)
			;
		else if(<Var(v),x> := <p,a> || <x,Var(v)> := <p,a>)
			env[v] = x;
		else if(p == Unbound() || a == Unbound())
			score += 1;
		else if(<Symbol("integer"),Symbol(/signed|unsigned/)> := <p,a>)
			score += 1;
		else if(<Symbol(/signed|unsigned/),Symbol("integer")> := <p,a>)
			score += 1;
		else
			return <INVALID_SCORE, initEnv>;
	}
	return <score,env>;
}

public TttConstant valueToExpr(Int(i)) = parse(#TttConstant, "<i>");
public TttConstant valueToExpr(Symbol(s)) = parse(#TttConstant, "<s>");
public TttConstant valueToExpr(Var(s)) = parse(#TttConstant, "<s>");
public TttConstant valueToExpr(Unbound()) = parse(#TttConstant, "?");
public default TttConstant valueToExpr(TicValue v) {
	throw "valueToExpr: missed a case <v>";
}

public TicValue evalExpr(TttConstant e, TicEnv initEnv) {
	int expectInt(Int(i)) = i;
	default int expectInt(TicValue v) { throw "expected int: <v>";}
	TicValue eval(x:(TttConstant)`#<Id s>`, TicEnv env) {
		val = env["#<s>"] ? Var("#<s>");
		return Constant(tree) := val ? eval(tree, env) : val;
	}
	TicValue eval((TttConstant)`<NUMLIT i>` , TicEnv env) = Int(toInt("<i>"));
	TicValue eval((TttConstant)`?` , TicEnv env) = Unbound();
	TicValue eval((TttConstant)`(<TttConstant l>)` , TicEnv env) = eval(l, env);
	TicValue eval((TttConstant)`-<TttConstant l>`, TicEnv env) = Int(-expectInt(eval(l, env)));
	TicValue eval((TttConstant)`<TttConstant l> bit`, TicEnv env )= eval(l, env);
	TicValue eval((TttConstant)`<TttConstant l> bits`, TicEnv env) = eval(l, env);
	TicValue eval((TttConstant)`<TttConstant l> byte`, TicEnv env) = Int(expectInt(eval(l, env))*8);
	TicValue eval((TttConstant)`<TttConstant l> bytes` , TicEnv env)= Int(expectInt(eval(l, env))*8);
	TicValue eval((TttConstant)`<TttConstant a>+<TttConstant b>`, TicEnv env) = Int(expectInt(eval(a, env))+expectInt(eval(b, env)));
	TicValue eval((TttConstant)`<TttConstant a>-<TttConstant b>`, TicEnv env) = Int(expectInt(eval(a, env))-expectInt(eval(b, env)));
	TicValue eval((TttConstant)`<TttConstant a>*<TttConstant b>`, TicEnv env) = Int(expectInt(eval(a, env))*expectInt(eval(b, env)));
	TicValue eval((TttConstant)`<TttConstant a>/<TttConstant b>`, TicEnv env) = Int(expectInt(eval(a, env))/expectInt(eval(b, env)));
	TicValue eval((TttConstant)`<TttConstant a>\><TttConstant b>`, TicEnv env) = Int(expectInt(eval(a, env))>expectInt(eval(b, env)) ? 1 : 0);
	TicValue eval((TttConstant)`<TttConstant a>\>=<TttConstant b>`, TicEnv env) = Int(expectInt(eval(a, env))>=expectInt(eval(b, env)) ? 1 : 0);
	TicValue eval((TttConstant)`<TttConstant a>\<<TttConstant b>`, TicEnv env) = Int(expectInt(eval(a, env))<expectInt(eval(b, env)) ? 1 : 0);
	TicValue eval((TttConstant)`<TttConstant a>\<=<TttConstant b>`, TicEnv env) = Int(expectInt(eval(a, env))<=expectInt(eval(b, env)) ? 1 : 0);
	TicValue eval((TttConstant)`<TttConstant a>==<TttConstant b>`, TicEnv env) = Int(eval(a, env) == eval(b, env) ? 1 : 0);
	TicValue eval((TttConstant)`<TttConstant a>!=<TttConstant b>`, TicEnv env) = Int(eval(a, env) != eval(b, env) ? 1 : 0);
	TicValue eval((TttConstant)`let #<Id n> = <TttConstant expr> in <TttConstant body>`, TicEnv env)
		= eval(body, env + ("#<n>" : eval(expr,  env)));
	TicValue eval((TttConstant)`if <TttConstant e1> then <TttConstant e2> else <TttConstant e3>`, TicEnv env)
		= eval(e1, env) != Int(0) ? eval(e2, env) : eval(e3, env);
	TicValue eval((TttConstant)`(<{TttSymbol ","}* args>) =\> <TttConstant body>`, TicEnv env) 
		= Fun(["#<name>" | (TttSymbol)`#<Id name>` <- args], body, env);
	TicValue eval((TttConstant)`<TttConstant fun>(<{TttConstant ","}* argExprs>)`, TicEnv env) {
		args = [eval(a, env) | a <- argExprs];
		f = eval(fun, env);
		if(Fun(funParams, funBody, funEnv) := f && size(funParams) == size(args)) {
			for(i <- index(funParams))
				funEnv[funParams[i]] = args[i];
			return eval(funBody, funEnv);
		}
		throw "not a function or wrong number of arguments: <f>, <env>";
	}
	default TicValue eval(TttConstant c, TicEnv env) {
		throw "missing case: <c>";
	}
	return eval(e, initEnv);
}