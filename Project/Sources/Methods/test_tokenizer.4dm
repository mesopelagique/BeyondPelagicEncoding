//%attributes = {}
// Unit tests for cs.embed.Tokenizer (Tier 2 BPE).
// Reference values produced by the canonical Python tiktoken library
// (cl100k_base) — they must match exactly.

var $tk : cs:C1710.Tokenizer:=cs:C1710.Tokenizer.me
var $tokens : Collection
var $expected : Collection

// ══════════════════════════════════════════════════════════════════════
// EMPTY / TRIVIAL
// ══════════════════════════════════════════════════════════════════════

ASSERT:C1129($tk.encode("").length=0; "Empty text → 0 tokens")
ASSERT:C1129($tk.count("")=0; "count('') = 0")

// Single ASCII char "a" → token 64 in cl100k_base
$tokens:=$tk.encode("a")
ASSERT:C1129(($tokens.length=1) && ($tokens[0]=64); "Single 'a' → [64]")

// ══════════════════════════════════════════════════════════════════════
// EXACT MATCH AGAINST PYTHON tiktoken (cl100k_base)
// ══════════════════════════════════════════════════════════════════════

$expected:=[9906; 11; 1917; 0]
$tokens:=$tk.encode("Hello, world!")
ASSERT:C1129(JSON Stringify:C1217($tokens)=JSON Stringify:C1217($expected); "'Hello, world!' must match tiktoken")

$expected:=[791; 4062; 14198; 39935; 35308; 927; 279; 16053; 5679; 13]
$tokens:=$tk.encode("The quick brown fox jumps over the lazy dog.")
ASSERT:C1129(JSON Stringify:C1217($tokens)=JSON Stringify:C1217($expected); "Pangram must match tiktoken")

$expected:=[83; 1609; 5963; 374; 2294; 0]
$tokens:=$tk.encode("tiktoken is great!")
ASSERT:C1129(JSON Stringify:C1217($tokens)=JSON Stringify:C1217($expected); "'tiktoken is great!' must match")

$expected:=[15339; 24748; 24748]
$tokens:=$tk.encode("hello hello hello")
ASSERT:C1129(JSON Stringify:C1217($tokens)=JSON Stringify:C1217($expected); "Repeated words must match")

// CJK
$expected:=[16325; 17161; 82805]
$tokens:=$tk.encode("中文测试")
ASSERT:C1129(JSON Stringify:C1217($tokens)=JSON Stringify:C1217($expected); "CJK must match tiktoken")

// Latin diacritics
$expected:=[34; 2642; 978; 9517; 1264; 978; 95980; 588]
$tokens:=$tk.encode("Café résumé naïve")
ASSERT:C1129(JSON Stringify:C1217($tokens)=JSON Stringify:C1217($expected); "Diacritics must match tiktoken")

// Numbers — \p{N}{1,3} caps consecutive digits at 3
$expected:=[4513; 10961; 16474]
$tokens:=$tk.encode("123456789")
ASSERT:C1129(JSON Stringify:C1217($tokens)=JSON Stringify:C1217($expected); "9 digits → 3 tokens of 3 digits")

// Whitespace handling (\s+ pattern)
$tokens:=$tk.encode("   ")
ASSERT:C1129($tokens.length>=1; "Whitespace produces at least 1 token")

// Newlines
$tokens:=$tk.encode("line1\nline2")
ASSERT:C1129($tokens.length>=2; "Multi-line text produces multiple tokens")

// ══════════════════════════════════════════════════════════════════════
// COUNT
// ══════════════════════════════════════════════════════════════════════

ASSERT:C1129($tk.count("Hello, world!")=4; "count('Hello, world!') = 4")
ASSERT:C1129($tk.count("The quick brown fox jumps over the lazy dog.")=10; "count(pangram) = 10")
ASSERT:C1129($tk.count("a")=1; "count('a') = 1")

// count and encode().length must agree
var $sample : Text:="A short sentence with some punctuation, numbers like 42, and a comma."
ASSERT:C1129($tk.count($sample)=$tk.encode($sample).length; "count() == encode().length")

// ══════════════════════════════════════════════════════════════════════
// ROUND-TRIP (encode → decode)
// ══════════════════════════════════════════════════════════════════════

var $samples : Collection:=["Hello, world!"; "The quick brown fox jumps over the lazy dog."; "tiktoken is great!"; "中文测试"; "Café résumé naïve"; "Mixed: ASCII, 中文, café — 123!"]
var $s : Variant
For each ($s; $samples)
	var $st : Text:=String:C10($s)
	var $enc : Collection:=$tk.encode($st)
	var $dec : Text:=$tk.decode($enc)
	ASSERT:C1129($dec=$st; "Round-trip failed for "+JSON Stringify:C1217($st)+" → "+JSON Stringify:C1217($dec))
End for each

// Decode of empty / null
ASSERT:C1129($tk.decode([])=""; "decode([]) = ''")
ASSERT:C1129($tk.decode(Null:C1517)=""; "decode(null) = ''")

// ══════════════════════════════════════════════════════════════════════
// STATE
// ══════════════════════════════════════════════════════════════════════

ASSERT:C1129($tk.isLoaded; "Vocab should be loaded after first encode")
ASSERT:C1129($tk.encoding="cl100k_base"; "Loaded encoding name")

// ══════════════════════════════════════════════════════════════════════
// LARGER TEXT — sanity check on a longer sample
// ══════════════════════════════════════════════════════════════════════

var $longText : Text:="In the beginning was the Word, and the Word was with God, and the Word was God. He was with God in the beginning. Through him all things were made; without him nothing was made that has been made."
var $long : Integer:=$tk.count($longText)
ASSERT:C1129($long>=40; "Long text count is reasonable (>=40)")
ASSERT:C1129($long<=60; "Long text count is reasonable (<=60)")

// Round-trip on long text
ASSERT:C1129($tk.decode($tk.encode($longText))=$longText; "Long text round-trips")
