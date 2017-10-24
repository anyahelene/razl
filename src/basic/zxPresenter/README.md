# ZX-Presenter – Utiltities to create presentations on the ZX81

A simple presentation system for using the ZX81 as a convenient,
lightweight alternative to dragging your laptop around to give
presentations.

## Usage
Using ZX-Presenter is quite straight-forward:

* Write your presentation in `.zd` markup format, which is 
  pretty much plain text with form feed as page separator.
  
   * Remember to keep your slide pages within the device constraints (32x22 characters)
   
* Run it through ZX-Presenter to obtain a BASIC program

* "Compile" the BASIC program to a `.p` file with the ZX81 language tools

* Convert to WAV format, connect your headphone output to the
  ZX81's EAR, run `LOAD ""` on the ZX81, and play the audio file. Enjoy the
  wonders of uploading on a ~300 bps line.

* Repeat the last bit until it succeeds, possibly tuning the audio parameters a bit.



## Rascal commands
```
PFile p = decodePFile(basic::zx81::ZX81Basic::foo);
p.program = tokens(readDocument(|file://<INPUT>.zd|).lines);
writeFileBytes(|file://<OUTPUT>.p|, encodePFile(p))
```