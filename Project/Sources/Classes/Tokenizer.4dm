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
property _specialTokenTexts : Object  // "rank" → "<|endoftext|>" (for decode)
property _specialTokenList : Collection  // list of supported special token texts
property _encoding : Text  // currently loaded encoding
property _maxTokenValue : Integer
property _loaded : Boolean

singleton Class constructor

	This:C1470._ranks:={}
	This:C1470._textMap:={}
	This:C1470._specialTokens:={}
	This:C1470._specialTokenTexts:={}
	This:C1470._specialTokenList:=[]
	This:C1470._patStr:=""
	This:C1470._encoding:=""
	This:C1470._maxTokenValue:=0
	This:C1470._loaded:=False

	// MARK:-[PUBLIC]
	// === === === === === === === === === === === === === === === === === === === === === === === === === ===
	// Encodes $text into token ranks and rejects special-token literals by default.
Function encode($text : Text; $encoding : Text) : Collection

	var $enc : Text:=((Count parameters:C259>=2) && ($encoding#"")) ? $encoding : "cl100k_base"
	This:C1470._ensureLoaded($enc)
	return This:C1470._encodeWithPolicy($text; $enc; []; This:C1470._specialsMinus([]))

	// === === === === === === === === === === === === === === === === === === === === === === === === === ===
	// Encodes $text while treating all known special-token literals as special tokens.
Function encode_all_special($text : Text; $encoding : Text) : Collection

	var $enc : Text:=((Count parameters:C259>=2) && ($encoding#"")) ? $encoding : "cl100k_base"
	This:C1470._ensureLoaded($enc)
	return This:C1470._encodeWithPolicy($text; $enc; This:C1470._copyTextCollection(This:C1470._specialTokenList); [])

	// === === === === === === === === === === === === === === === === === === === === === === === === === ===
	// Encodes $text while allowing only the provided special-token literals.
Function encode_allowed_special($text : Text; $allowedSpecial : Collection; $encoding : Text) : Collection

	var $enc : Text:=((Count parameters:C259>=3) && ($encoding#"")) ? $encoding : "cl100k_base"
	This:C1470._ensureLoaded($enc)
	var $allowed : Collection:=[]
	If ($allowedSpecial#Null:C1517)
		var $item : Variant
		For each ($item; $allowedSpecial)
			$allowed.push(String:C10($item))
		End for each
	End if
	return This:C1470._encodeWithPolicy($text; $enc; $allowed; [])

	// === === === === === === === === === === === === === === === === === === === === === === === === === ===
	// Internal policy-aware encoder used by the public wrappers.
Function _encodeWithPolicy($text : Text; $encoding : Text; $allowed : Collection; $disallowed : Collection) : Collection

	This:C1470._ensureLoaded($encoding)
	This:C1470._throwIfDisallowedSpecial($text; $disallowed)

	var $tokens : Collection:=[]
	If ($text="")
		return $tokens
	End if

	var $cursor : Integer:=1
	While ($cursor<=Length:C16($text))
		var $special : Object:=This:C1470._nextSpecialToken($text; $cursor; $allowed)
		If ($special.pos=0)
			This:C1470._encodeOrdinary(Substring:C12($text; $cursor); $tokens)
			break
		End if

		If ($special.pos>$cursor)
			This:C1470._encodeOrdinary(Substring:C12($text; $cursor; $special.pos-$cursor); $tokens)
		End if

		$tokens.push($special.rank)
		$cursor:=$special.pos+Length:C16($special.token)
	End while

	return $tokens

	// === === === === === === === === === === === === === === === === === === === === === === === === === ===
	// Encodes a string into tokens while always treating special-token literals as ordinary text.
Function encode_ordinary($text : Text; $encoding : Text) : Collection

	var $enc : Text:=((Count parameters:C259>=2) && ($encoding#"")) ? $encoding : "cl100k_base"
	This:C1470._ensureLoaded($enc)
	var $tokens : Collection:=[]
	If ($text#"")
		This:C1470._encodeOrdinary($text; $tokens)
	End if
	return $tokens

	// === === === === === === === === === === === === === === === === === === === === === === === === === ===
	// CamelCase wrapper for public use.
Function encodeOrdinary($text : Text; $encoding : Text) : Collection

	var $enc : Text:=((Count parameters:C259>=2) && ($encoding#"")) ? $encoding : "cl100k_base"
	This:C1470._ensureLoaded($enc)
	var $tokens : Collection:=[]
	If ($text#"")
		This:C1470._encodeOrdinary($text; $tokens)
	End if
	return $tokens

	// === === === === === === === === === === === === === === === === === === === === === === === === === ===
	// Encodes a list of strings with the same policy as encode().
Function encode_batch($texts : Collection; $encoding : Text; $allowedSpecial : Variant; $disallowedSpecial : Variant) : Collection

	var $batch : Collection:=[]
	If ($texts=Null:C1517)
		return $batch
	End if

	var $item : Variant
	For each ($item; $texts)
		If (Count parameters:C259>=2)
			$batch.push(This:C1470.encode(String:C10($item); $encoding))
		Else
			$batch.push(This:C1470.encode(String:C10($item)))
		End if
	End for each

	return $batch

	// === === === === === === === === === === === === === === === === === === === === === === === === === ===
	// CamelCase wrapper for public use.
Function encodeBatch($texts : Collection; $encoding : Text) : Collection

	var $batch : Collection:=[]
	If ($texts=Null:C1517)
		return $batch
	End if
	var $item : Variant
	For each ($item; $texts)
		If (Count parameters:C259>=2)
			$batch.push(This:C1470.encode(String:C10($item); $encoding))
		Else
			$batch.push(This:C1470.encode(String:C10($item)))
		End if
	End for each
	return $batch

	// === === === === === === === === === === === === === === === === === === === === === === === === === ===
	// Encodes a list of strings while always treating special tokens as ordinary text.
Function encode_ordinary_batch($texts : Collection; $encoding : Text) : Collection

	var $batch : Collection:=[]
	If ($texts=Null:C1517)
		return $batch
	End if

	var $item : Variant
	For each ($item; $texts)
		If (Count parameters:C259>=2)
			$batch.push(This:C1470.encode_ordinary(String:C10($item); $encoding))
		Else
			$batch.push(This:C1470.encode_ordinary(String:C10($item)))
		End if
	End for each

	return $batch

	// === === === === === === === === === === === === === === === === === === === === === === === === === ===
	// CamelCase wrapper for public use.
Function encodeOrdinaryBatch($texts : Collection; $encoding : Text) : Collection

	var $batch : Collection:=[]
	If ($texts=Null:C1517)
		return $batch
	End if
	var $item : Variant
	For each ($item; $texts)
		If (Count parameters:C259>=2)
			$batch.push(This:C1470.encodeOrdinary(String:C10($item); $encoding))
		Else
			$batch.push(This:C1470.encodeOrdinary(String:C10($item)))
		End if
	End for each
	return $batch

	// === === === === === === === === === === === === === === === === === === === === === === === === === ===
	// Returns the number of tokens for $text — equivalent to encode().length
	// but slightly cheaper since the token collection is discarded.
Function count($text : Text; $encoding : Text) : Integer

	If ((Count parameters:C259>=2) && ($encoding#""))
		return This:C1470.encode($text; $encoding).length
	End if
	return This:C1470.encode($text).length

	// === === === === === === === === === === === === === === === === === === === === === === === === === ===
	// Encodes raw bytes without regex splitting.
Function _encode_bytes($bytes : Blob; $encoding : Text) : Collection

	var $enc : Text:=((Count parameters:C259>=2) && ($encoding#"")) ? $encoding : "cl100k_base"
	This:C1470._ensureLoaded($enc)
	var $tokens : Collection:=[]
	This:C1470._encodeBlob($bytes; $tokens)
	return $tokens

	// === === === === === === === === === === === === === === === === === === === === === === === === === ===
	// CamelCase wrapper for public use.
Function encodeBytes($bytes : Blob; $encoding : Text) : Collection

	var $enc : Text:=((Count parameters:C259>=2) && ($encoding#"")) ? $encoding : "cl100k_base"
	This:C1470._ensureLoaded($enc)
	var $tokens : Collection:=[]
	This:C1470._encodeBlob($bytes; $tokens)
	return $tokens

	// === === === === === === === === === === === === === === === === === === === === === === === === === ===
	// Encodes a text or blob corresponding to exactly one token.
Function encode_single_token($textOrBytes; $encoding : Text) : Integer

	var $enc : Text:=((Count parameters:C259>=2) && ($encoding#"")) ? $encoding : "cl100k_base"
	This:C1470._ensureLoaded($enc)

	var $token : Variant:=Null:C1517
	var $kind : Integer:=Type:C295($textOrBytes)
	Case of
		: ($kind=30)
			var $key : Text:=This:C1470._blobKey($textOrBytes; 0; BLOB size:C605($textOrBytes))
			$token:=This:C1470._ranks[$key]
			If ($token=Null:C1517)
				var $candidateText : Text:=Convert to text:C1012($textOrBytes; "UTF-8")
				$token:=This:C1470._specialTokens[$candidateText]
			End if
		Else
			$token:=This:C1470._specialTokens[$textOrBytes]
			If ($token=Null:C1517)
				var $blob : Blob
				CONVERT FROM TEXT:C1011($textOrBytes; "UTF-8"; $blob)
				var $textKey : Text:=This:C1470._blobKey($blob; 0; BLOB size:C605($blob))
				$token:=This:C1470._ranks[$textKey]
			End if
	End case

	If ($token=Null:C1517)
		throw:C1805(50003; "Input does not correspond to a single token")
	End if

	return Num:C11($token)

	// === === === === === === === === === === === === === === === === === === === === === === === === === ===
	// CamelCase wrapper for public use.
Function encodeSingleToken($textOrBytes; $encoding : Text) : Integer

	var $enc : Text:=((Count parameters:C259>=2) && ($encoding#"")) ? $encoding : "cl100k_base"
	This:C1470._ensureLoaded($enc)

	var $token : Variant:=Null:C1517
	var $kind : Integer:=Type:C295($textOrBytes)
	Case of
		: ($kind=30)
			var $key : Text:=This:C1470._blobKey($textOrBytes; 0; BLOB size:C605($textOrBytes))
			$token:=This:C1470._ranks[$key]
			If ($token=Null:C1517)
				var $candidateText : Text:=Convert to text:C1012($textOrBytes; "UTF-8")
				$token:=This:C1470._specialTokens[$candidateText]
			End if
		Else
			$token:=This:C1470._specialTokens[$textOrBytes]
			If ($token=Null:C1517)
				var $blob : Blob
				CONVERT FROM TEXT:C1011($textOrBytes; "UTF-8"; $blob)
				var $textKey : Text:=This:C1470._blobKey($blob; 0; BLOB size:C605($blob))
				$token:=This:C1470._ranks[$textKey]
			End if
	End case

	If ($token=Null:C1517)
		throw:C1805(50003; "Input does not correspond to a single token")
	End if

	return Num:C11($token)

	// === === === === === === === === === === === === === === === === === === === === === === === === === ===
	// Decodes a collection of token ranks back to text.
Function decode($tokens : Collection; $encoding : Text; $errors : Text) : Text

	var $enc : Text:=((Count parameters:C259>=2) && ($encoding#"")) ? $encoding : "cl100k_base"
	This:C1470._ensureLoaded($enc)

	If ($tokens=Null:C1517) || ($tokens.length=0)
		return ""
	End if
	var $unusedErrors : Text:=((Count parameters:C259>=3) && ($errors#"")) ? $errors : "replace"
	$unusedErrors:=$unusedErrors
	var $bytes : Blob:=This:C1470.decode_bytes($tokens; $enc)
	return Convert to text:C1012($bytes; "UTF-8")

	// === === === === === === === === === === === === === === === === === === === === === === === === === ===
	// Decodes a collection of token ranks back to raw bytes.
Function decode_bytes($tokens : Collection; $encoding : Text) : Blob

	var $enc : Text:=((Count parameters:C259>=2) && ($encoding#"")) ? $encoding : "cl100k_base"
	This:C1470._ensureLoaded($enc)

	var $blob : Blob
	SET BLOB SIZE:C606($blob; 0)
	If ($tokens=Null:C1517)
		return $blob
	End if

	var $tok : Variant
	For each ($tok; $tokens)
		var $tokenBlob : Blob:=This:C1470.decode_single_token_bytes(Num:C11($tok))
		var $targetSize : Integer:=BLOB size:C605($blob)
		var $sourceSize : Integer:=BLOB size:C605($tokenBlob)
		If ($sourceSize>0)
			SET BLOB SIZE:C606($blob; $targetSize+$sourceSize)
			var $i : Integer
			For ($i; 0; $sourceSize-1)
				$blob{$targetSize+$i}:=$tokenBlob{$i}
			End for
		End if
	End for each

	return $blob

	// === === === === === === === === === === === === === === === === === === === === === === === === === ===
	// CamelCase wrapper for public use.
Function decodeBytes($tokens : Collection; $encoding : Text) : Blob

	var $enc : Text:=((Count parameters:C259>=2) && ($encoding#"")) ? $encoding : "cl100k_base"
	This:C1470._ensureLoaded($enc)
	var $blob : Blob
	SET BLOB SIZE:C606($blob; 0)
	If ($tokens=Null:C1517)
		return $blob
	End if
	var $tok : Variant
	For each ($tok; $tokens)
		var $tokenBlob : Blob:=This:C1470.decodeSingleTokenBytes(Num:C11($tok))
		var $targetSize : Integer:=BLOB size:C605($blob)
		var $sourceSize : Integer:=BLOB size:C605($tokenBlob)
		If ($sourceSize>0)
			SET BLOB SIZE:C606($blob; $targetSize+$sourceSize)
			var $i : Integer
			For ($i; 0; $sourceSize-1)
				$blob{$targetSize+$i}:=$tokenBlob{$i}
			End for
		End if
	End for each
	return $blob

	// === === === === === === === === === === === === === === === === === === === === === === === === === ===
	// Decodes a single token into its byte representation.
Function decode_single_token_bytes($token : Integer; $encoding : Text) : Blob

	var $enc : Text:=((Count parameters:C259>=2) && ($encoding#"")) ? $encoding : "cl100k_base"
	This:C1470._ensureLoaded($enc)

	var $specialText : Variant:=This:C1470._specialTokenTexts[String:C10($token)]
	If ($specialText#Null:C1517)
		var $specialBlob : Blob
		CONVERT FROM TEXT:C1011(String:C10($specialText); "UTF-8"; $specialBlob)
		return $specialBlob
	End if

	var $bytesKey : Text:=String:C10(This:C1470._textMap[String:C10($token)])
	If ($bytesKey="")
		throw:C1805(50004; "Unknown token id: "+String:C10($token))
	End if

	return This:C1470._blobFromKey($bytesKey)

	// === === === === === === === === === === === === === === === === === === === === === === === === === ===
	// CamelCase wrapper for public use.
Function decodeSingleTokenBytes($token : Integer; $encoding : Text) : Blob

	var $enc : Text:=((Count parameters:C259>=2) && ($encoding#"")) ? $encoding : "cl100k_base"
	This:C1470._ensureLoaded($enc)
	var $specialText : Variant:=This:C1470._specialTokenTexts[String:C10($token)]
	If ($specialText#Null:C1517)
		var $specialBlob : Blob
		CONVERT FROM TEXT:C1011(String:C10($specialText); "UTF-8"; $specialBlob)
		return $specialBlob
	End if
	var $bytesKey : Text:=String:C10(This:C1470._textMap[String:C10($token)])
	If ($bytesKey="")
		throw:C1805(50004; "Unknown token id: "+String:C10($token))
	End if
	return This:C1470._blobFromKey($bytesKey)

	// === === === === === === === === === === === === === === === === === === === === === === === === === ===
	// Decodes a list of tokens into a list of blobs.
Function decode_tokens_bytes($tokens : Collection; $encoding : Text) : Collection

	var $enc : Text:=((Count parameters:C259>=2) && ($encoding#"")) ? $encoding : "cl100k_base"
	This:C1470._ensureLoaded($enc)
	var $decoded : Collection:=[]
	If ($tokens=Null:C1517)
		return $decoded
	End if

	var $tok : Variant
	For each ($tok; $tokens)
		$decoded.push(This:C1470.decode_single_token_bytes(Num:C11($tok)))
	End for each

	return $decoded

	// === === === === === === === === === === === === === === === === === === === === === === === === === ===
	// CamelCase wrapper for public use.
Function decodeTokensBytes($tokens : Collection; $encoding : Text) : Collection

	var $enc : Text:=((Count parameters:C259>=2) && ($encoding#"")) ? $encoding : "cl100k_base"
	This:C1470._ensureLoaded($enc)
	var $decoded : Collection:=[]
	If ($tokens=Null:C1517)
		return $decoded
	End if
	var $tok : Variant
	For each ($tok; $tokens)
		$decoded.push(This:C1470.decodeSingleTokenBytes(Num:C11($tok)))
	End for each
	return $decoded

	// === === === === === === === === === === === === === === === === === === === === === === === === === ===
	// Decodes a token list and returns character offsets for the start of each token.
Function decode_with_offsets($tokens : Collection; $encoding : Text) : Object

	var $enc : Text:=((Count parameters:C259>=2) && ($encoding#"")) ? $encoding : "cl100k_base"
	This:C1470._ensureLoaded($enc)
	var $offsets : Collection:=[]
	var $blob : Blob
	SET BLOB SIZE:C606($blob; 0)
	var $textLen : Integer:=0

	If ($tokens#Null:C1517)
		var $tok : Variant
		For each ($tok; $tokens)
			var $tokenBlob : Blob:=This:C1470.decode_single_token_bytes(Num:C11($tok))
			var $offset : Integer:=$textLen
			If (BLOB size:C605($tokenBlob)>0)
				var $firstByte : Integer:=$tokenBlob{0}
				If (($firstByte>=128) && ($firstByte<192) && ($textLen>0))
					$offset:=$textLen-1
				End if
			End if
			$offsets.push($offset)
			$textLen:=$textLen+This:C1470._utf8CharLength($tokenBlob)
			var $targetSize : Integer:=BLOB size:C605($blob)
			var $sourceSize : Integer:=BLOB size:C605($tokenBlob)
			If ($sourceSize>0)
				SET BLOB SIZE:C606($blob; $targetSize+$sourceSize)
				var $i : Integer
				For ($i; 0; $sourceSize-1)
					$blob{$targetSize+$i}:=$tokenBlob{$i}
				End for
			End if
		End for each
	End if

	return {text: Convert to text:C1012($blob; "UTF-8"); offsets: $offsets}

	// === === === === === === === === === === === === === === === === === === === === === === === === === ===
	// CamelCase wrapper for public use.
Function decodeWithOffsets($tokens : Collection; $encoding : Text) : Object

	var $enc : Text:=((Count parameters:C259>=2) && ($encoding#"")) ? $encoding : "cl100k_base"
	This:C1470._ensureLoaded($enc)
	var $offsets : Collection:=[]
	var $blob : Blob
	SET BLOB SIZE:C606($blob; 0)
	var $textLen : Integer:=0
	If ($tokens#Null:C1517)
		var $tok : Variant
		For each ($tok; $tokens)
			var $tokenBlob : Blob:=This:C1470.decodeSingleTokenBytes(Num:C11($tok))
			var $offset : Integer:=$textLen
			If (BLOB size:C605($tokenBlob)>0)
				var $firstByte : Integer:=$tokenBlob{0}
				If (($firstByte>=128) && ($firstByte<192) && ($textLen>0))
					$offset:=$textLen-1
				End if
			End if
			$offsets.push($offset)
			$textLen:=$textLen+This:C1470._utf8CharLength($tokenBlob)
			var $targetSize : Integer:=BLOB size:C605($blob)
			var $sourceSize : Integer:=BLOB size:C605($tokenBlob)
			If ($sourceSize>0)
				SET BLOB SIZE:C606($blob; $targetSize+$sourceSize)
				var $i : Integer
				For ($i; 0; $sourceSize-1)
					$blob{$targetSize+$i}:=$tokenBlob{$i}
				End for
			End if
		End for each
	End if
	return {text: Convert to text:C1012($blob; "UTF-8"); offsets: $offsets}

	// === === === === === === === === === === === === === === === === === === === === === === === === === ===
	// Decodes a batch of token lists.
Function decode_batch($batch : Collection; $encoding : Text; $errors : Text) : Collection

	var $decoded : Collection:=[]
	If ($batch=Null:C1517)
		return $decoded
	End if

	var $item : Variant
	For each ($item; $batch)
		var $tokenList : Collection:=$item
		If (Count parameters:C259>=3)
			$decoded.push(This:C1470.decode($tokenList; $encoding; $errors))
		Else
			If (Count parameters:C259>=2)
				$decoded.push(This:C1470.decode($tokenList; $encoding))
			Else
				$decoded.push(This:C1470.decode($tokenList))
			End if
		End if
	End for each

	return $decoded

	// === === === === === === === === === === === === === === === === === === === === === === === === === ===
	// CamelCase wrapper for public use.
Function decodeBatch($batch : Collection; $encoding : Text; $errors : Text) : Collection

	var $decoded : Collection:=[]
	If ($batch=Null:C1517)
		return $decoded
	End if
	var $item : Variant
	For each ($item; $batch)
		var $tokenList : Collection:=$item
		If (Count parameters:C259>=3)
			$decoded.push(This:C1470.decode($tokenList; $encoding; $errors))
		Else
			If (Count parameters:C259>=2)
				$decoded.push(This:C1470.decode($tokenList; $encoding))
			Else
				$decoded.push(This:C1470.decode($tokenList))
			End if
		End if
	End for each
	return $decoded

	// === === === === === === === === === === === === === === === === === === === === === === === === === ===
	// Returns true once the vocab for $encoding is loaded.
Function get isLoaded() : Boolean

	return This:C1470._loaded

	// === === === === === === === === === === === === === === === === === === === === === === === === === ===
	// Returns the currently loaded encoding name (empty if none loaded).
Function get encoding() : Text

	return This:C1470._encoding

	// === === === === === === === === === === === === === === === === === === === === === === === === === ===
	// Returns the <|endoftext|> token for the loaded encoding.
Function get eot_token() : Integer

	If (Not:C34(This:C1470._loaded))
		This:C1470._ensureLoaded("cl100k_base")
	End if
	return Num:C11(This:C1470._specialTokens["<|endoftext|>"])

	// === === === === === === === === === === === === === === === === === === === === === === === === === ===
	// CamelCase wrapper for public use.
Function get eotToken() : Integer

	return This:C1470.eot_token

	// === === === === === === === === === === === === === === === === === === === === === === === === === ===
	// Returns the set of special token texts.
Function get special_tokens_set() : Collection

	If (Not:C34(This:C1470._loaded))
		This:C1470._ensureLoaded("cl100k_base")
	End if
	return This:C1470._copyTextCollection(This:C1470._specialTokenList)

	// === === === === === === === === === === === === === === === === === === === === === === === === === ===
	// CamelCase wrapper for public use.
Function get specialTokensSet() : Collection

	return This:C1470.special_tokens_set

	// === === === === === === === === === === === === === === === === === === === === === === === === === ===
	// Returns the maximum token id for the currently loaded encoding.
Function get max_token_value() : Integer

	If (Not:C34(This:C1470._loaded))
		This:C1470._ensureLoaded("cl100k_base")
	End if
	return This:C1470._maxTokenValue

	// === === === === === === === === === === === === === === === === === === === === === === === === === ===
	// CamelCase wrapper for public use.
Function get maxTokenValue() : Integer

	return This:C1470.max_token_value

	// === === === === === === === === === === === === === === === === === === === === === === === === === ===
	// Returns the tokenizer vocabulary size.
Function get n_vocab() : Integer

	return This:C1470.max_token_value+1

	// === === === === === === === === === === === === === === === === === === === === === === === === === ===
	// CamelCase wrapper for public use.
Function get nVocab() : Integer

	return This:C1470.n_vocab

	// === === === === === === === === === === === === === === === === === === === === === === === === === ===
	// CamelCase wrapper for public use.
Function encodeAllSpecial($text : Text; $encoding : Text) : Collection

	var $enc : Text:=((Count parameters:C259>=2) && ($encoding#"")) ? $encoding : "cl100k_base"
	This:C1470._ensureLoaded($enc)
	var $allowedAll : Collection:=["<|endoftext|>"; "<|fim_prefix|>"; "<|fim_middle|>"; "<|fim_suffix|>"; "<|endofprompt|>"]
	return This:C1470._encodeWithPolicy($text; $enc; $allowedAll; [])

	// === === === === === === === === === === === === === === === === === === === === === === === === === ===
	// CamelCase wrapper for public use.
Function encodeAllowedSpecial($text : Text; $allowedSpecial : Collection; $encoding : Text) : Collection

	var $enc : Text:=((Count parameters:C259>=3) && ($encoding#"")) ? $encoding : "cl100k_base"
	This:C1470._ensureLoaded($enc)
	var $allowed : Collection:=[]
	If ($allowedSpecial#Null:C1517)
		var $item : Variant
		For each ($item; $allowedSpecial)
			$allowed.push(String:C10($item))
		End for each
	End if
	return This:C1470._encodeWithPolicy($text; $enc; $allowed; [])

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
	This:C1470._specialTokenTexts:={}
	This:C1470._specialTokenList:=[]
	This:C1470._maxTokenValue:=0

	Case of
		: ($encoding="cl100k_base")
			This:C1470._patStr:="(?i:'s|'t|'re|'ve|'m|'ll|'d)|[^\\r\\n\\p{L}\\p{N}]?\\p{L}+|\\p{N}{1,3}| ?[^\\s\\p{L}\\p{N}]+[\\r\\n]*|\\s*[\\r\\n]+|\\s+(?!\\S)|\\s+"
			This:C1470._specialTokens:={}
			This:C1470._specialTokenList:=["<|endoftext|>"; "<|fim_prefix|>"; "<|fim_middle|>"; "<|fim_suffix|>"; "<|endofprompt|>"]
			This:C1470._specialTokens["<|endoftext|>"]:=100257
			This:C1470._specialTokenTexts["100257"]:="<|endoftext|>"
			This:C1470._specialTokens["<|fim_prefix|>"]:=100258
			This:C1470._specialTokenTexts["100258"]:="<|fim_prefix|>"
			This:C1470._specialTokens["<|fim_middle|>"]:=100259
			This:C1470._specialTokenTexts["100259"]:="<|fim_middle|>"
			This:C1470._specialTokens["<|fim_suffix|>"]:=100260
			This:C1470._specialTokenTexts["100260"]:="<|fim_suffix|>"
			This:C1470._specialTokens["<|endofprompt|>"]:=100276
			This:C1470._specialTokenTexts["100276"]:="<|endofprompt|>"
			This:C1470._maxTokenValue:=100276
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
		If ($rank>This:C1470._maxTokenValue)
			This:C1470._maxTokenValue:=$rank
		End if

	End for each

	This:C1470._encoding:=$encoding
	This:C1470._loaded:=True

	// *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** ***
	// Encodes ordinary text (no special-token literals) into token ranks.
Function _encodeOrdinary($text : Text; $tokens : Collection)

	If ($text="")
		return
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
		This:C1470._encodeBlob($blob; $tokens)

		$cursor:=$pos{0}+$len{0}

	End while

	// *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** ***
	// Encodes an already-byte-split piece.
Function _encodeBlob($blob : Blob; $tokens : Collection)

	var $key : Text:=This:C1470._blobKey($blob; 0; BLOB size:C605($blob))
	If (This:C1470._ranks[$key]#Null:C1517)
		$tokens.push(This:C1470._ranks[$key])
	Else
		This:C1470._bpeEncode($blob; $tokens)
	End if

	// *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** ***
	// Returns the earliest matching special-token literal at or after $start.
Function _nextSpecialToken($text : Text; $start : Integer; $candidates : Collection) : Object

	var $best : Object:={pos: 0; token: ""; rank: 0}
	If ($candidates=Null:C1517) || ($candidates.length=0)
		return $best
	End if

	var $candidate : Variant
	For each ($candidate; $candidates)
		var $token : Text:=String:C10($candidate)
		var $pos : Integer:=Position:C15($token; $text; $start)
		If ($pos>0)
			If (($best.pos=0) || ($pos<$best.pos) || (($pos=$best.pos) && (Length:C16($token)>Length:C16($best.token))))
				$best:={pos: $pos; token: $token; rank: Num:C11(This:C1470._specialTokens[$token])}
			End if
		End if
	End for each

	return $best

	// *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** ***
	// Normalizes allowed_special into a collection of supported token texts.
Function _normalizeAllowedSpecial($allowedSpecial : Variant) : Collection

	var $allowed : Collection:=[]
	var $kind : Integer:=Type:C295($allowedSpecial)
	If (($allowedSpecial=Null:C1517) || ($kind=5) || (($kind=2) && (String:C10($allowedSpecial)="")))
		return $allowed
	End if

	Case of
		: ($kind=42)
			var $token : Variant
			For each ($token; $allowedSpecial)
				var $tokenText : Text:=String:C10($token)
				If (This:C1470._collectionContainsText(This:C1470._specialTokenList; $tokenText))
					$allowed.push($tokenText)
				End if
			End for each
		: (String:C10($allowedSpecial)="all")
			$allowed:=This:C1470._copyTextCollection(This:C1470._specialTokenList)
	End case

	return $allowed

	// *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** ***
	// Normalizes disallowed_special into a collection of supported token texts.
Function _normalizeDisallowedSpecial($allowed : Collection; $disallowedSpecial : Variant) : Collection

	var $disallowed : Collection:=[]
	var $kind : Integer:=Type:C295($disallowedSpecial)
	If (($disallowedSpecial=Null:C1517) || ($kind=5) || (($kind=2) && ((String:C10($disallowedSpecial)="") || (String:C10($disallowedSpecial)="all"))))
		return This:C1470._specialsMinus($allowed)
	End if

	If ($kind=42)
		var $token : Variant
		For each ($token; $disallowedSpecial)
			var $tokenText : Text:=String:C10($token)
			If (This:C1470._collectionContainsText(This:C1470._specialTokenList; $tokenText))
				$disallowed.push($tokenText)
			End if
		End for each
	End if

	return $disallowed

	// *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** ***
	// Throws when a disallowed special token literal appears in the text.
Function _throwIfDisallowedSpecial($text : Text; $disallowed : Collection)

	var $match : Object:=This:C1470._nextSpecialToken($text; 1; $disallowed)
	If ($match.pos>0)
		throw:C1805(50001; "Encountered text corresponding to disallowed special token "+JSON Stringify:C1217($match.token))
	End if

	// *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** ***
	// Returns True if $value is present in $texts.
Function _collectionContainsText($texts : Collection; $value : Text) : Boolean

	If ($texts=Null:C1517)
		return False:C214
	End if

	var $item : Variant
	For each ($item; $texts)
		If (String:C10($item)=$value)
			return True:C214
		End if
	End for each

	return False:C214

	// *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** ***
	// Returns a copy of the provided text collection.
Function _copyTextCollection($texts : Collection) : Collection

	var $copy : Collection:=[]
	If ($texts=Null:C1517)
		return $copy
	End if

	var $item : Variant
	For each ($item; $texts)
		$copy.push(String:C10($item))
	End for each

	return $copy

	// *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** ***
	// Returns the set of special tokens minus the ones in $allowed.
Function _specialsMinus($allowed : Collection) : Collection

	var $remaining : Collection:=[]
	var $item : Variant
	For each ($item; This:C1470._specialTokenList)
		var $token : Text:=String:C10($item)
		If (Not:C34(This:C1470._collectionContainsText($allowed; $token)))
			$remaining.push($token)
		End if
	End for each

	return $remaining

	// *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** ***
	// Appends all bytes from $source to $target.
Function _appendBlob($target : Blob; $source : Blob)

	var $sourceSize : Integer:=BLOB size:C605($source)
	If ($sourceSize=0)
		return
	End if

	var $targetSize : Integer:=BLOB size:C605($target)
	SET BLOB SIZE:C606($target; $targetSize+$sourceSize)
	var $i : Integer
	For ($i; 0; $sourceSize-1)
		$target{$targetSize+$i}:=$source{$i}
	End for

	// *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** ***
	// Converts a comma-separated byte key into a Blob.
Function _blobFromKey($key : Text) : Blob

	var $blob : Blob
	SET BLOB SIZE:C606($blob; 0)
	If ($key="")
		return $blob
	End if

	var $byteStrs : Collection:=Split string:C1554($key; ",")
	var $b : Variant
	For each ($b; $byteStrs)
		var $size : Integer:=BLOB size:C605($blob)
		SET BLOB SIZE:C606($blob; $size+1)
		$blob{$size}:=Num:C11($b)
	End for each

	return $blob

	// *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** ***
	// Counts the number of UTF-8 codepoints represented by $blob.
Function _utf8CharLength($blob : Blob) : Integer

	var $len : Integer:=0
	var $size : Integer:=BLOB size:C605($blob)
	var $i : Integer
	For ($i; 0; $size-1)
		var $byte : Integer:=$blob{$i}
		If (($byte<128) || ($byte>=192))
			$len:=$len+1
		End if
	End for

	return $len

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
				var $rankValue : Integer:=Num:C11($r)
				If (($minIdx<0) || ($rankValue<$minRank))
					$minRank:=$rankValue
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
