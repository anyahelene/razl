module intermediate::TOE
extend intermediate::ThreeAddressCode;

syntax LValue =
	Deref: "(" Literal ")"
	;

syntax RValue
	= Literal
	| Deref: "(" Literal ")"
	;
