module assembler::Bits
import List;
import util::Math;

data Bits = Bits(list[int] bits);

public Bits bits(int bits...) {
	for(b <- bits)
		if(b != 0 && b != 1)
			throw "not a bit: <b>";
	return Bits(bits);
}

public int size(Bits bs) = size(bs.bits);

bool isSet(int bits, int n) = isSet(toBits(bits), n);

bool isSet(Bits b, int bit)
	= (bit >= size(b)) ? false : (b.bits[size(b.bits)-1-bit] != 0);

public Bits extendBits(Bits b, int size) {
	if(size < 0)
		throw "Size should be \>=0: <size>";
	if(size(b.bits) >= size)
		return;
	else
		return Bits([i < size(b.bits) ? b.bits[i] : 0 | i <- [0..size]]);
}

public Bits signExtendBits(Bits b, int size) {
	if(size < 0)
		throw "Size should be \>=0: <size>";
	int N = size(b.bits);
	if(N >= size)
		return;
	else if(N > 0)
		return Bits([i < N ? b.bits[i] : b.bits[N-1] | i <- [0..size]]);
	else
		return Bits([0 | _ <- [0..size]]);
}

public Bits truncateBits(Bits b, int size) {
	if(size < 0)
		throw "Size should be \>=0: <size>";
	return Bits(b.bits[0..size]);
}

public Bits signFitBits(Bits b, int size) {
	if(size(b) == size)
		return b;
	else if(size(b) > size)
		return truncateBits(b, size);
	else
		return signExtendBits(b, size);
}

public int getBit(Bits b, int bit) {
	if(bit >= size(b.bits))
		return 0;
	else
		b[size(b.bits)-bit];
}
public Bits setBit(Bits b, int bit) {
	b = extendBits(b, bit+1);
	b.bits[size(b.bits)-bit] = 1;
	return b;
}
public Bits setBit(Bits b, int bit, bool state)
	= state ? setBit(b, bit) : unsetBit(b, bit);

public Bits unsetBit(Bits b, int bit) {
	if(bit >= size(b))
		return b;
	b.bits[size(b)-1-bit] = 0;
	return b;
}

public Bits toggleBit(Bits b, int bit)
	= isSet(b,bit) ? unsetBit(b, bit) : setBit(b, bit);

public int toInt(Bits b)
	= 128*b.b7 + 64*b.b6 + 32*b.b5 + 16*b.b4 + 8*b.b3 + 4*b.b2 + 2*b.b1 + b.b0;

public str toString(Bits b)
	= intercalate("", [<x> | x < b.bits]);

public Bits toBits(int i) = toBits(i, ceil(log2(abs(i+1))));

public Bits toBits(int i, int size) {
	if(size < 0)
		throw "Size should be \>=0: <size>";
	else if(size == 0)
		size = 1;

	twoN = toInt(pow(2, size));
	i = i % twoN;
	if(i < 0)
		i = i + twoN;
	
	b = [0 | _ <- [0..size]];
	
	for(x <- [size-1..-1]) {
		b[x] = i % 2;
		i = i / 2;
	}	
	
	return Bits(b);
}

public int bit(bool b) = b ? 1 : 0;
public Bits not(Bits bs) = Bits([b == 0 ? 1 : 0 | b <- bs.bits]);
public Bits and(Bits bs1, Bits bs2)
	= Bits([bit(isSet(bs1, i) && isSet(bs2,i)) | i <- [max(size(bs1), size(bs2))-1..-1]]);
public Bits or(Bits bs1, Bits bs2)
	= Bits([bit(isSet(bs1, i) || isSet(bs2,i)) | i <- [max(size(bs1), size(bs2))-1..-1]]);

public Bits shl(Bits bs) = Bits([*bs.bits, 0]);
public Bits shr(Bits bs) = Bits(bs.bits[..-1]);
