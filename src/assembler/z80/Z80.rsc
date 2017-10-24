module assembly::z80::Z80
import ParseTree;
import String;
import Set;
import assembly::Unified;

private set[str] registers8bit = {"a", "b", "c", "d", "e", "h", "l"};
private set[str] registers16bit = {"bc", "de", "hl"};
private set[str] registersIdx8bit = {"ixh", "ixl", "iyh", "iyl"};
private set[str] registersIdx16bit = {"ix", "iy"};
private set[str] registersSpecial = {"af", "af\'", "sp", "pc", "i", "r"};
private set[str] registersAll8bit = registers8bit + registersIdx8bit;
private set[str] registersAll16bit = registers16bit + registersIdx16bit;
private set[str] registersAll = registersAll8bit + registersAll16bit + registersSpecial;
private set[str] conditionCodes = {"c", "m", "nc", "nz", "p", "pe", "po", "z"};
data OperandsPattern 
	= Nullary()
	| Unary(OperandPattern p)
	| Binary(OperandPattern p1, OperandPattern p2)
	| Nary(OperandPattern p)
	;
data OperandPattern
	= Bit()  // bit number (0..7)
	| CC() // condition
	| Num(int low, int high)  // a number
	| Reg(str name)
	| Deref(OperandPattern p)
	| DerefOffset(OperandPattern p1, OperandPattern p2)
	| AnyOf(set[OperandPattern] ps)
	;
public OperandPattern AnyOf({xs*, AnyOf(ys), zs*}) = AnyOf(xs + ys + zs);
@doc{Bit number}
public OperandPattern B = Num(0,7);
public OperandPattern Offset = Num(-128,127);
public OperandPattern JumpOffset = Num(-126,129);
public OperandPattern N = Num(0,255);
public OperandPattern NN = Num(0,65535);
@doc{8-bit registers}
public OperandPattern R = AnyOf({Reg("a"), Reg("b"), Reg("c"), Reg("d"), Reg("e"), Reg("h"), Reg("l")});
@doc{16-bit registers}
public OperandPattern RR = AnyOf({Reg("bc"), Reg("de"), Reg("hl")});
@doc{16-bit index registers}
public OperandPattern XX = AnyOf({Reg("ix"), Reg("iy")});
public OperandPattern PPP = AnyOf({Reg("bc"), Reg("de"), Reg("ix"), Reg("sp")});
public OperandPattern PP = AnyOf({Reg("bc"), Reg("de"), Reg("ix"), Reg("sp")});
public OperandPattern QQ = AnyOf({Reg("af"), Reg("bc"), Reg("de"), Reg("hl")});
public OperandPattern M = AnyOf({R, Deref(Reg("hl")), DerefOffset(XX, Offset)});
@doc{Register, immediate, or deref HL/index}
public OperandPattern S = AnyOf({R, Num(0,255),Deref(Reg("hl")),DerefOffset(XX,Offset)});
public OperandPattern SS = AnyOf({Reg("bc"), Reg("de"), Reg("hl"), Reg("sp")});
public OperandPattern Src = AnyOf({S,SS,Deref(Reg("bc")),Deref(Reg("de")),Deref(Reg("hl")),NN,Deref(NN)});
public OperandPattern Dst = AnyOf({S,SS,Deref(Reg("bc")),Deref(Reg("de")),Deref(Reg("hl")),Deref(NN)});

public str pretty(AnyOf(ps)) = "[<intercalate(",", [pretty(p) | p <- sort(toList(ps))])>]";
public str pretty(Num(0,255)) = "N";
public str pretty(Num(0,65535)) = "NN";
public str pretty(Num(low,high)) = "<low>..<high>";
public str pretty(Deref(p)) = "(<pretty(p)>)";
public str pretty(DerefOffset(p1,p2)) = "(<pretty(p1)>+<pretty(p2)>)";
public str pretty(Reg(r)) = r;

public rel[str,OperandsPattern,str,str,str] opCodes = {
<"adc",  Binary(Reg("a"), S),   "***V0*", "Add with Carry", "A=A+s+CY">,
<"adc",  Binary(Reg("hl"), SS), "**?V0*", "Add with Carry", "HL=HL+ss+CY">,
<"add",  Binary(Reg("a"), S),   "***V0*", "Add", "A=A+s">,
<"add",  Binary(Reg("hl"), SS), "--?-0*", "Add                  ", "HL=HL+ss              ">,
<"add",  Binary(Reg("ix"), PP), "--?-0*", "Add                  ", "IX=IX+pp              ">,
<"add",  Binary(Reg("iy"), RR), "--?-0*", "Add                  ", "IY=IY+rr              ">,
<"and",  Unary(S),              "***P00", "Logical AND          ", "A=A&s                 ">,
<"bit",  Binary(B, M),          "?*1?0-", "Test Bit             ", "m&{2^b}               ">,
<"call", Binary(CC(), NN),      "------", "Conditional Call     ", "If cc CALL            ">,
<"call", Unary(NN),             "------", "Unconditional Call   ", "-[SP]=PC,PC=nn        ">,
<"ccf",  Nullary(),             "--?-0*", "Complement Carry Flag", "CY=~CY                ">,
<"cp",   Unary(S),              "***V1*", "Compare              ", "A-s                   ">,
<"cpd",  Nullary(),             "****1-", "Compare and Decrement", "A-[HL],HL=HL-1,BC=BC-1">,
<"cpdr", Nullary(),             "****1-", "Compare, Dec., Repeat", "CPD till A=[HL]or BC=0">,
<"cpi",  Nullary(),             "****1-", "Compare and Increment", "A-[HL],HL=HL+1,BC=BC-1">,
<"cpir", Nullary(),             "****1-", "Compare, Inc., Repeat", "CPI till A=[HL]or BC=0">,
<"cpl",  Nullary(),             "--1-1-", "Complement           ", "A=~A                  ">,
<"daa",  Nullary(),             "***P-*", "Decimal Adjust Acc.  ", "A=BCD format          ">,
<"dec",  Unary(S),              "***V1-", "Decrement            ", "s=s-1                 ">,
<"dec",  Unary(XX),             "------", "Decrement            ", "xx=xx-1               ">,
<"dec",  Unary(SS),             "------", "Decrement            ", "ss=ss-1               ">,
<"di",   Nullary(),             "------", "Disable Interrupts   ", "                      ">,
<"djnz", Unary(JumpOffset),     "------", "Dec., Jump Non-Zero  ", "B=B-1 till B=0        ">,
<"ei",   Nullary(),             "------", "Enable Interrupts    ", "                      ">,
<"ex",   Binary(Deref(Reg("sp")), Reg("hl")), "------", "Exchange ", "[SP]\<-\>HL             ">,
<"ex",   Binary(Deref(Reg("sp")), XX), "------",      "Exchange ", "[SP]\<-\>xx             ">,
<"ex",   Binary(Reg("af"), Reg("af\'")),  "------",     "Exchange ", "AF\<-\>AF\'              ">,
<"ex",   Binary(Reg("de"), Reg("hl")),  "------",       "Exchange ", "DE\<-\>HL               ">,
<"exx",  Nullary(),             "------",             "Exchange ", "qq\<-\>qq\'   (except AF)">,
<"halt", Nullary(),             "------", "Halt                 ", "                      ">,
<"im",   Unary(N),              "------", "Interrupt Mode       ", "             (n=0,1,2)">,
<"in",   Binary(Reg("a"), Deref(N)), "------", "Input                ", "A=[n]                 ">,
<"in",   Binary(R, Deref(Reg("c"))), "***P0-", "Input                ", "r=[C]                 ">,
<"inc",  Unary(R),              "***V0-", "Increment            ", "r=r+1                 ">,
<"inc",  Unary(Deref(Reg("hl"))), "***V0-", "Increment            ", "[HL]=[HL]+1           ">,
<"inc",  Unary(XX),             "------", "Increment            ", "xx=xx+1               ">,
<"inc",  Unary(DerefOffset(XX,Offset)),"***V0-", "Increment            ", "[xx+d]=[xx+d]+1       ">,
<"inc",  Unary(SS),             "------", "Increment            ", "ss=ss+1               ">,
<"ind",  Nullary(),             "?*??1-", "Input and Decrement  ", "[HL]=[C],HL=HL-1,B=B-1">,
<"indr", Nullary(),             "?1??1-", "Input, Dec., Repeat  ", "IND till B=0          ">,
<"ini",  Nullary(),             "?*??1-", "Input and Increment  ", "[HL]=[C],HL=HL+1,B=B-1">,
<"inir", Nullary(),             "?1??1-", "Input, Inc., Repeat  ", "INI till B=0          ">,
<"jp",   Unary(Deref(Reg("hl"))), "------", "Unconditional Jump   ", "PC=[HL]               ">,
<"jp",   Unary(Deref(XX)),      "------", "Unconditional Jump   ", "PC=[xx]               ">,
<"jp",   Unary(NN),             "------", "Unconditional Jump   ", "PC=nn                 ">,
<"jp",   Binary(CC(), NN),      "------", "Conditional Jump     ", "If cc JP              ">,
<"jr",   Unary(JumpOffset),     "------", "Unconditional Jump   ", "PC=PC+e               ">,
<"jr",   Binary(CC(),JumpOffset),"------", "Conditional Jump     ", "If cc JR(cc=C,NC,NZ,Z)">,
<"ld",   Binary(Dst,Src),       "------", "Load                 ", "dst=src               ">,
<"ld",   Binary(Reg("a"), AnyOf({Reg("i"),Reg("r")})),    "**0*0-", "Load                 ", "A=i            (i=I,R)">,
<"ldd",  Nullary(),             "--0*0-", "Load and Decrement   ", "[DE]=[HL],HL=HL-1,#   ">,
<"lddr", Nullary(),             "--000-", "Load, Dec., Repeat   ", "LDD till BC=0         ">,
<"ldi",  Nullary(),             "--0*0-", "Load and Increment   ", "[DE]=[HL],HL=HL+1,#   ">,
<"ldir", Nullary(),             "--000-", "Load, Inc., Repeat   ", "LDI till BC=0         ">,
<"neg",  Nullary(),             "***V1*", "Negate               ", "A=-A                  ">,
<"nop",  Nullary(),             "------", "No Operation         ", "                      ">,
<"or",   Unary(S),              "***P00", "Logical inclusive OR ", "A=Avs                 ">,
<"otdr", Nullary(),             "?1??1-", "Output, Dec., Repeat ", "OUTD till B=0         ">,
<"otir", Nullary(),             "?1??1-", "Output, Inc., Repeat ", "OUTI till B=0         ">,
<"out",  Binary(Deref(Reg("c")),R), "------", "Output               ", "[C]=r                 ">,
<"out",  Binary(Deref(N),Reg("a")), "------", "Output               ", "[n]=A                 ">,
<"outd", Nullary(),             "?*??1-", "Output and Decrement ", "[C]=[HL],HL=HL-1,B=B-1">,
<"outi", Nullary(),             "?*??1-", "Output and Increment ", "[C]=[HL],HL=HL+1,B=B-1">,
<"pop",  Unary(XX),             "------", "Pop                  ", "xx=[SP]+              ">,
<"pop",  Unary(QQ),             "------", "Pop                  ", "qq=[SP]+              ">,
<"push", Unary(XX),             "------", "Push                 ", "-[SP]=xx              ">,
<"push", Unary(QQ),             "------", "Push                 ", "-[SP]=qq              ">,
<"res",  Binary(B,M),           "------", "Reset bit            ", "m=m&{~2^b}            ">,
<"ret",  Nullary(),             "------", "Return               ", "PC=[SP]+              ">,
<"ret",  Unary(CC()),           "------", "Conditional Return   ", "If cc RET             ">,
<"reti", Nullary(),             "------", "Return from Interrupt", "PC=[SP]+              ">,
<"retn", Nullary(),             "------", "Return from NMI      ", "PC=[SP]+              ">,
<"rl",   Unary(M),              "**0P0*", "Rotate Left          ", "m={CY,m}\<-            ">,
<"rla",  Nullary(),             "--0-0*", "Rotate Left Acc.     ", "A={CY,A}\<-            ">,
<"rlc",  Unary(M),              "**0P0*", "Rotate Left Circular ", "m=m\<-                 ">,
<"rlca", Nullary(),             "--0-0*", "Rotate Left Circular ", "A=A\<-                 ">,
<"rld",  Nullary(),             "**0P0-", "Rotate Left 4 bits   ", "{A,[HL]}={A,[HL]}\<- ##">,
<"rr",   Unary(M),              "**0P0*", "Rotate Right         ", "m=-\>{CY,m}            ">,
<"rra",  Nullary(),             "--0-0*", "Rotate Right Acc.    ", "A=-\>{CY,A}            ">,
<"rrc",  Unary(M),              "**0P0*", "Rotate Right Circular", "m=-\>m                 ">,
<"rrca", Nullary(),             "--0-0*", "Rotate Right Circular", "A=-\>A                 ">,
<"rrd",  Nullary(),             "**0P0-", "Rotate Right 4 bits  ", "{A,[HL]}=-\>{A,[HL]} ##">,
<"rst",  Unary(N),              "------", "Restart              ", " (p=0H,8H,10H,...,38H)">,
<"sbc",  Binary(Reg("a"),S),    "***V1*", "Subtract with Carry  ", "A=A-s-CY              ">,
<"sbc",  Binary(Reg("hl"),SS),  "**?V1*", "Subtract with Carry  ", "HL=HL-ss-CY           ">,
<"scf",  Nullary(),             "--0-01", "Set Carry Flag       ", "CY=1                  ">,
<"set",  Binary(B,M),           "------", "Set bit              ", "m=mv{2^b}             ">,
<"sla",  Unary(M),              "**0P0*", "Shift Left Arithmetic", "m=m*2                 ">,
<"sra",  Unary(M),              "**0P0*", "Shift Right Arith.   ", "m=m/2                 ">,
<"srl",  Unary(M),              "**0P0*", "Shift Right Logical  ", "m=-\>{0,m,CY}          ">,
<"sub",  Unary(S),              "***V1*", "Subtract             ", "A=A-s                 ">,
<"xor",  Unary(S),              "***P00", "Logical Exclusive OR ", "A=Axs                 ">
	};
public set[str] opsAll = opCodes<0>;

anno str Tree@category;

public bool isRegister(str name) {
	return toLowerCase(name) in registersAll;
}

public bool isOperation(str name) {
	return toLowerCase(name) in opsAll;
}

public bool isCC(str name) {
	return toLowerCase(name) in conditionCodes;
}

public &T<:Tree annotate(&T<:Tree tree) {
	return visit(tree) {
		case IdentifierAtom i => isRegister(unparse(i)) ? i[@category="Constant"] : i
		case OpCodeName i => isOperation(unparse(i)) ? i[@category="MetaKeyword"] : i[@category="MetaAmbiguity"]
	}
}

