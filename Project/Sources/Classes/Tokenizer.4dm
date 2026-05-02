/**
 Tier 2 BPE tokenizer — exact token counts compatible with tiktoken.
 Pure-4D port of https://github.com/openai/tiktoken (js-tiktoken).

 Currently supports cl100k_base (text-embedding-3-small/large, ada-002,
 gpt-3.5-turbo, gpt-4). Vocabulary files live in Resources/tokenizers/.

 The first call to encode/count loads the vocab (~100k entries),
 which takes a few seconds. Subsequent calls are fast — typical
 encoding throughput is on the order of a few thousand tokens/sec.

 Usage:
   var $tk : cs.embed.Tokenizer:=cs.embed.Tokenizer.me
   var $n : Integer:=$tk.count("Hello, world!")
   var $tokens : Collection:=$tk.encode("Hello, world!")
   var $text : Text:=$tk.decode($tokens)
**/

property _ranks : Object  // "b1,b2,...,bN" → rank (Integer)
property _textMap : Object  // "rank" → "b1,b2,...,bN" (for decode)
property _patStr : Text  // pre-tokenizer regex
property _specialTokens : Object  // "<|endoftext|>" → rank
property _encoding : Text  // currently loaded encoding
property _loaded : Boolean

singleton Class constructor

	This:C1470._ranks:={}
	This:C1470._textMap:={}
	This:C1470._specialTokens:={}
	This:C1470._patStr:=""
	This:C1470._encoding:=""
	This:C1470._loaded:=False

	// MARK:-[PUBLIC]
	// === === === === === === === === === === === === === === === === === === === === === === === === === ===
	// Encodes $text into a collection of token ranks. $encoding defaults to "cl100k_base".
Function encode($text : Text; $encoding : Text) : Collection

	var $enc : Text:=((Count parameters:C259>=2) && ($encoding#"")) ? $encoding : "cl100k_base"
	This:C1470._ensureLoaded($enc)

	var $tokens : Collection:=[]
	If ($text="")
		return $tokens
	End if

	var $cursor : Integer:=1
	ARRAY LONGINT:C221($pos; 0)
	ARRAY LONGINT:C221($len; 0)

	While (Match regex:C1019(This:C1470._patStr; $text; $cursor; $pos; $len))

		If ($len{0}=0)
			break
		End if

		var $piece : Text:=Substring:C12($text; $pos{0}; $len{0})
		var $blob : Blob
		CONVERT FROM TEXT:C1011($piece; "UTF-8"; $blob)

		// Fast path: full piece is already a known token
		var $key : Text:=This:C1470._blobKey($blob; 0; BLOB size:C605($blob))
		If (This:C1470._ranks[$key]#Null:C1517)
			$tokens.push(This:C1470._ranks[$key])
		Else
			This:C1470._bpeEncode($blob; $tokens)
		End if

		$cursor:=$pos{0}+$len{0}

	End while

	return $tokens

	// === === === === === === === === === === === === === === === === === === === === === === === === === ===
	// Returns the number of tokens for $text — equivalent to encode().length
	// but slightly cheaper since the token collection is discarded.
Function count($text : Text; $encoding : Text) : Integer

	If ((Count parameters:C259>=2) && ($encoding#""))
		return This:C1470.encode($text; $encoding).length
	End if
	return This:C1470.encode($text).length

	// === === === === === === === === === === === === === === === === === === === === === === === === === ===
	// Decodes a collection of token ranks back to text.
Function decode($tokens : Collection; $encoding : Text) : Text

	var $enc : Text:=((Count parameters:C259>=2) && ($encoding#"")) ? $encoding : "cl100k_base"
	This:C1470._ensureLoaded($enc)

	If ($tokens=Null:C1517) || ($tokens.length=0)
		return ""
	End if

	var $blob : Blob
	SET BLOB SIZE:C606($blob; 0)

	var $tok : Variant
	For each ($tok; $tokens)
		var $bytesKey : Text:=String:C10(This:C1470._textMap[String:C10($tok)])
		If ($bytesKey="")
			continue
		End if
		var $byteStrs : Collection:=Split string:C1554($bytesKey; ",")
		var $b : Variant
		For each ($b; $byteStrs)
			var $size : Integer:=BLOB size:C605($blob)
			SET BLOB SIZE:C606($blob; $size+1)
			$blob{$size}:=Num:C11($b)
		End for each
	End for each

	var $out : Text:=Convert to text:C1012($blob; "UTF-8")
	return $out

	// === === === === === === === === === === === === === === === === === === === === === === === === === ===
	// Returns true once the vocab for $encoding is loaded.
Function get isLoaded() : Boolean

	return This:C1470._loaded

	// === === === === === === === === === === === === === === === === === === === === === === === === === ===
	// Returns the currently loaded encoding name (empty if none loaded).
Function get encoding() : Text

	return This:C1470._encoding

	// === === === === === === === === === === === === === === === === === === === === === === === === === ===
	// Forces vocab loading for $encoding. Idempotent — safe to call repeatedly.
Function load($encoding : Text)

	This:C1470._ensureLoaded($encoding)

	// MARK:-[PRIVATE]
	// *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** ***
Function _ensureLoaded($encoding : Text)

	If (This:C1470._loaded && (This:C1470._encoding=$encoding))
		return
	End if

	This:C1470._ranks:={}
	This:C1470._textMap:={}
	This:C1470._specialTokens:={}

	Case of
		: ($encoding="cl100k_base")
			This:C1470._patStr:="(?i:'s|'t|'re|'ve|'m|'ll|'d)|[^\\r\\n\\p{L}\\p{N}]?\\p{L}+|\\p{N}{1,3}| ?[^\\s\\p{L}\\p{N}]+[\\r\\n]*|\\s*[\\r\\n]+|\\s+(?!\\S)|\\s+"
			This:C1470._specialTokens:={}
			This:C1470._specialTokens["<|endoftext|>"]:=100257
			This:C1470._specialTokens["<|fim_prefix|>"]:=100258
			This:C1470._specialTokens["<|fim_middle|>"]:=100259
			This:C1470._specialTokens["<|fim_suffix|>"]:=100260
			This:C1470._specialTokens["<|endofprompt|>"]:=100276
		Else
			throw:C1805({componentSignature: "4DES"; message: "Unknown encoding: "+$encoding; deferred: True:C214})
			return
	End case

	var $file : 4D:C1709.File:=Folder:C1567(fk database folder:K87:14; *).file("Resources/tokenizers/"+$encoding+".tiktoken")
	If (Not:C34($file.exists))
		throw:C1805({componentSignature: "4DES"; message: "Vocab file not found: "+$file.path; deferred: True:C214})
		return
	End if

	var $content : Text:=$file.getText()
	var $lines : Collection:=Split string:C1554($content; Char:C90(Line feed:K15:40))

	var $line : Text
	For each ($line; $lines)

		If ($line="")
			continue
		End if

		var $sp : Integer:=Position:C15(" "; $line)
		If ($sp<=0)
			continue
		End if

		var $b64 : Text:=Substring:C12($line; 1; $sp-1)
		var $rankStr : Text:=Substring:C12($line; $sp+1)
		var $rank : Integer:=Num:C11($rankStr)

		var $blob : Blob
		BASE64 DECODE:C896($b64; $blob)

		var $key : Text:=This:C1470._blobKey($blob; 0; BLOB size:C605($blob))
		This:C1470._ranks[$key]:=$rank
		This:C1470._textMap[String:C10($rank)]:=$key

	End for each

	This:C1470._encoding:=$encoding
	This:C1470._loaded:=True

	// *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** ***
	// Builds "b1,b2,...,bN" key from $blob bytes in [$start, $end).
Function _blobKey($blob : Blob; $start : Integer; $end : Integer) : Text

	If ($end<=$start)
		return ""
	End if

	var $key : Text:=String:C10($blob{$start})
	var $i : Integer
	For ($i; $start+1; $end-1)
		$key:=$key+","+String:C10($blob{$i})
	End for

	return $key

	// *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** ***
	// BPE encode a single piece — mutates $tokens in place.
Function _bpeEncode($piece : Blob; $tokens : Collection)

	var $size : Integer:=BLOB size:C605($piece)
	If ($size=0)
		return
	End if

	If ($size=1)
		var $k1 : Text:=String:C10($piece{0})
		If (This:C1470._ranks[$k1]#Null:C1517)
			$tokens.push(This:C1470._ranks[$k1])
		End if
		return
	End if

	// Initial parts: one entry per byte. Each part is {start, end} (end exclusive).
	var $parts : Collection:=[]
	var $i : Integer
	For ($i; 0; $size-1)
		$parts.push({start: $i; end: $i+1})
	End for

	// Greedy merge of the lowest-rank adjacent pair.
	While ($parts.length>1)

		var $minRank : Integer:=-1
		var $minIdx : Integer:=-1

		var $j : Integer
		For ($j; 0; $parts.length-2)

			var $key : Text:=This:C1470._blobKey($piece; $parts[$j].start; $parts[$j+1].end)
			var $r : Variant:=This:C1470._ranks[$key]

			If ($r#Null:C1517)
				var $rint : Integer:=Num:C11($r)
				If (($minIdx<0) || ($rint<$minRank))
					$minRank:=$rint
					$minIdx:=$j
				End if
			End if

		End for

		If ($minIdx<0)
			break
		End if

		// Merge $parts[$minIdx] with the next part
		$parts[$minIdx].end:=$parts[$minIdx+1].end
		$parts.remove($minIdx+1)

	End while

	// Emit token ranks for surviving parts
	var $p : Object
	For each ($p; $parts)
		var $pk : Text:=This:C1470._blobKey($piece; $p.start; $p.end)
		var $pr : Variant:=This:C1470._ranks[$pk]
		If ($pr#Null:C1517)
			$tokens.push(Num:C11($pr))
		End if
	End for each
