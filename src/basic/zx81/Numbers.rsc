module basic::zx81::Numbers
import util::Math;

public list[int] encodeBasicNum(real n) {
	if(n == 0)
		return [0,0,0,0,0];
		
	MAX = pow(2, 32)-1;
	MIN = pow(2, 31);
	signum = n < 0 ? -1 : 1;
	r = abs(n);
	
	int e = 32;
	
	while(true) {
		if(r > MAX) {
			r /= 2;
			e += 1;
			if(e > 127)
				throw "out of range: <n>";
		}
		else if(r < MIN) {
			r *= 2;
			e -= 1;
			if(e < -128)  // underflow
				return [0,0,0,0,0];
		}
		else {
			break;
		}
	}	

	int m = toInt(r);

	if(signum > 0)
		m = m - 2147483648;

	return [e+128, (m/16777216) % 256, (m/65536) % 256, (m/256) % 256, m % 256];
}

public real decodeBasicNum([int e, int m3, int m2, int m1, int m0]) {
	e = e - 128 - 32;
	int m = m0 + m1*256 + m2*65536 + m3*16777216;
	int signum = 1;
	if(m >= 2147483648) {
		signum = -1;
	}
	else  {
		m += 2147483648;
	}
	
	return precision(signum*m*pow(toReal(2), toReal(e)), 11);
}

public int decodeLineNum([int i0, int i1]) = i0*256 + i1;

public list[int] encodeLineNum(int i) = [(i / 256) % 256, i % 256]; 

public int decodeUInt16([int i0, int i1]) = i1*256 + i0;

public list[int] encodeUInt16(int i) = [i % 256, (i / 256) % 256]; 

public int decodeSInt16(list[int] l) {
	i = decodeUInt16(l);
	if(i >= 2147483648)
		return i - 4294967296;
	else
		return i;
}

public list[int] encodeSInt16(int i) =
	i < 0 ? encodeUInt16(i + 4294967296) : decodeUInt16(i);
 
