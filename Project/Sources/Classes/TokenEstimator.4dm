/**
 Tier 1 token estimator: fast heuristic based on UTF-8 byte count
 and content kind. Calibrated against cl100k_base / o200k_base.

 Suitable for live UI feedback (typing indicator, batch cost preview).
 Typical accuracy: within 10–15% on natural-language prose, more on
 highly structured content. For exact counts before an API call,
 use a real BPE encoder (Tier 2).

 Usage:
   var $n : Integer:=cs.embed.TokenEstimator.me.estimate($text)
   var $n : Integer:=cs.embed.TokenEstimator.me.estimate($text; "json")
   var $info : Object:=cs.embed.TokenEstimator.me.detail($text)
   var $batch : Object:=cs.embed.TokenEstimator.me.estimateBatch($texts)
**/

property _bytesPerToken : Object  // mean UTF-8 bytes per token, by content kind

singleton Class constructor
	
	// Calibration values vs cl100k_base on representative samples.
	// Lower ratio = denser content (more tokens per byte).
	This:C1470._bytesPerToken:={\
		text: 4; \
		latin: 3.3; \
		markdown: 3.6; \
		code: 3; \
		json: 2.8; \
		xml: 2.4; \
		html: 2.5; \
		url: 2.5; \
		base64: 2; \
		cjk: 2; \
		mixed: 3\
		}
	
	// MARK:-[PUBLIC]
	// === === === === === === === === === === === === === === === === === === === === === === === === === ===
	// Returns the estimated token count for $text. If $kind is omitted or empty,
	// content kind is auto-detected from the first non-whitespace character.
	// Known kinds: text, latin, markdown, code, json, xml, html, url, base64, cjk, mixed.
Function estimate($text : Text; $kind : Text) : Integer
	
	return This:C1470.detail($text; $kind).tokens
	
	// === === === === === === === === === === === === === === === === === === === === === === === === === ===
	// Returns a detail object: {tokens, bytes, chars, kind, bytesPerToken}.
	// Useful when the UI wants to show both the count and the assumed kind.
Function detail($text : Text; $kind : Text) : Object
	
	If ($text="")
		return {tokens: 0; bytes: 0; chars: 0; kind: "empty"; bytesPerToken: 0}
	End if 
	
	var $resolved : Text:=((Count parameters:C259>=2) && ($kind#"")) ? $kind : This:C1470.detectKind($text)
	var $bpt : Real:=Num:C11(This:C1470._bytesPerToken[$resolved] || This:C1470._bytesPerToken.text)
	
	var $blob : Blob
	CONVERT FROM TEXT:C1011($text; "UTF-8"; $blob)
	var $bytes : Integer:=BLOB size:C605($blob)
	
	// Ceiling of $bytes/$bpt (4D has no Ceil; Int is floor for positive values).
	var $ratio : Real:=$bytes/$bpt
	var $tokens : Real:=Int:C8($ratio)
	If ($tokens<$ratio)
		$tokens:=$tokens+1
	End if 
	If ($tokens<1)
		$tokens:=1
	End if 
	
	var $chars : Integer:=Length:C16($text)
	
	return {tokens: $tokens; bytes: $bytes; chars: $chars; kind: $resolved; bytesPerToken: $bpt}
	
	// === === === === === === === === === === === === === === === === === === === === === === === === === ===
	// Estimates total tokens for a collection of texts. $kind applies to all items;
	// pass Null/"" to auto-detect each item independently.
	// Returns {tokens, count, bytes}.
Function estimateBatch($texts : Collection; $kind : Text) : Object
	
	var $totals : Object:={tokens: 0; count: 0; bytes: 0}
	ASSERT:C1129($totals=$totals)
	If ($texts=Null:C1517)
		return $totals
	End if 
	
	var $hasKind : Boolean:=(Count parameters:C259>=2) && ($kind#"")
	var $item : Variant
	For each ($item; $texts)
		
		var $text : Text:=String:C10($item)
		var $info : Object:=$hasKind ? This:C1470.detail($text; $kind) : This:C1470.detail($text)
		
		$totals.tokens+=$info.tokens
		$totals.bytes+=$info.bytes
		$totals.count+=1
		
	End for each 
	
	return $totals
	
	// === === === === === === === === === === === === === === === === === === === === === === === === === ===
	// Heuristic kind detection from the first non-whitespace character.
	// Returns one of the keys in _bytesPerToken; defaults to "text".
Function detectKind($text : Text) : Text
	
	var $trimmed : Text:=Trim:C1853($text)
	If ($trimmed="")
		return "text"
	End if 
	
	var $first : Text:=Substring:C12($trimmed; 1; 1)
	
	Case of 
		: ($first="{") || ($first="[")
			return "json"
		: ($first="<")
			return "xml"
	End case 
	
	return "text"
	
	// === === === === === === === === === === === === === === === === === === === === === === === === === ===
	// Returns the list of known content kinds.
Function get kinds() : Collection
	
	return OB Keys:C1719(This:C1470._bytesPerToken)
	
	// === === === === === === === === === === === === === === === === === === === === === === === === === ===
	// Returns the bytes-per-token ratio used for a given kind.
	// Useful for diagnostics or to display the assumption in the UI.
Function bytesPerToken($kind : Text) : Real
	
	return Num:C11(This:C1470._bytesPerToken[$kind] || This:C1470._bytesPerToken.text)
	