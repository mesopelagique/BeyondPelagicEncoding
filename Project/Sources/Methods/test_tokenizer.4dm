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

$expected:=[15339; 1917]
$tokens:=$tk.encode("hello world")
ASSERT:C1129(JSON Stringify:C1217($tokens)=JSON Stringify:C1217($expected); "'hello world' must match tiktoken public test")

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

// Exact regex boundary cases from tiktoken/tests/test_encoding.py
$expected:=[38149]
$tokens:=$tk.encode("rer")
ASSERT:C1129(JSON Stringify:C1217($tokens)=JSON Stringify:C1217($expected); "'rer' must match tiktoken regex case")

$expected:=[31213; 198; 220]
$tokens:=$tk.encode("today\n ")
ASSERT:C1129(JSON Stringify:C1217($tokens)=JSON Stringify:C1217($expected); "'today\\n ' must match tiktoken regex case")

$expected:=[31213; 27907]
$tokens:=$tk.encode("today\n \n")
ASSERT:C1129(JSON Stringify:C1217($tokens)=JSON Stringify:C1217($expected); "'today\\n \\n' must match tiktoken regex case")

$expected:=[31213; 14211]
$tokens:=$tk.encode("today\n  \n")
ASSERT:C1129(JSON Stringify:C1217($tokens)=JSON Stringify:C1217($expected); "'today\\n  \\n' must match tiktoken regex case")

// Other exact public cases from tiktoken/tests/test_encoding.py
var $controlSample : Text:=" "+Char:C90(133)+"0"
$expected:=[220; 126; 227; 15]
$tokens:=$tk.encode($controlSample)
ASSERT:C1129(JSON Stringify:C1217($tokens)=JSON Stringify:C1217($expected); "Control-char sample must match tiktoken")

$expected:=[9468; 239; 235]
$tokens:=$tk.encode("👍")
ASSERT:C1129(JSON Stringify:C1217($tokens)=JSON Stringify:C1217($expected); "Emoji tokenization must match tiktoken")

var $rawBytes : Blob
SET BLOB SIZE:C606($rawBytes; 5)
$rawBytes{0}:=32
$rawBytes{1}:=236
$rawBytes{2}:=139
$rawBytes{3}:=164
$rawBytes{4}:=237
var $knownSpecials : Collection:=["<|endoftext|>"; "<|fim_prefix|>"; "<|fim_middle|>"; "<|fim_suffix|>"; "<|endofprompt|>"]

var $noSpecials : Collection:=[]

$expected:=[15339; 220; 100257]
$tokens:=$tk.encodeAllSpecial("hello <|endoftext|>")
ASSERT:C1129(JSON Stringify:C1217($tokens)=JSON Stringify:C1217($expected); "'hello <|endoftext|>' must match tiktoken allowed_special output")

$expected:=[100258; 100260; 100259]
$tokens:=$tk.encodeAllSpecial("<|fim_prefix|><|fim_suffix|><|fim_middle|>")
ASSERT:C1129(JSON Stringify:C1217($tokens)=JSON Stringify:C1217($expected); "Adjacent special tokens must each stay atomic")

// ══════════════════════════════════════════════════════════════════════
// COUNT
// ══════════════════════════════════════════════════════════════════════

ASSERT:C1129($tk.count("Hello, world!")=4; "count('Hello, world!') = 4")
ASSERT:C1129($tk.count("The quick brown fox jumps over the lazy dog.")=10; "count(pangram) = 10")
ASSERT:C1129($tk.count("a")=1; "count('a') = 1")
ASSERT:C1129($tk.encodeOrdinary("hello world").length=2; "encode_ordinary('hello world') length = 2")

// count and encode().length must agree
var $sample : Text:="A short sentence with some punctuation, numbers like 42, and a comma."
ASSERT:C1129($tk.count($sample)=$tk.encode($sample).length; "count() == encode().length")

// encode_ordinary matches encode(...; disallowed_special=[])
var $specialAsText : Text:="<|endoftext|> hello <|fim_prefix|> there <|fim_middle|>"
ASSERT:C1129(JSON Stringify:C1217($tk.encodeOrdinary($specialAsText))=JSON Stringify:C1217($tk.encodeAllowedSpecial($specialAsText; $noSpecials)); "encode_ordinary() matches empty allowed-special encoding")

// Batch helpers
var $batchInputs : Collection:=["hello world"; "goodbye world"]
var $batchEncoded : Collection:=$tk.encodeBatch($batchInputs)
var $batchExpected : Collection:=[$tk.encode("hello world"); $tk.encode("goodbye world")]
ASSERT:C1129(JSON Stringify:C1217($batchEncoded)=JSON Stringify:C1217($batchExpected); "encode_batch() matches per-item encode()")
ASSERT:C1129(JSON Stringify:C1217($tk.encodeOrdinaryBatch($batchInputs))=JSON Stringify:C1217([$tk.encodeOrdinary("hello world"); $tk.encodeOrdinary("goodbye world")]); "encode_ordinary_batch() matches per-item encode_ordinary()")
ASSERT:C1129(JSON Stringify:C1217($tk.decodeBatch($batchEncoded))=JSON Stringify:C1217($batchInputs); "decode_batch() round-trips encoded batch")

// Single-token helpers
ASSERT:C1129($tk.encodeSingleToken("hello")=15339; "encode_single_token('hello') = 15339")
ASSERT:C1129($tk.encodeSingleToken("<|endoftext|>")=100257; "encode_single_token('<|endoftext|>') = eot token")
var $helloBytes : Blob:=$tk.decodeSingleTokenBytes(15339)
ASSERT:C1129(Convert to text:C1012($helloBytes; "UTF-8")="hello"; "decode_single_token_bytes(15339) = b'hello'")
var $eotBytes : Blob:=$tk.decodeSingleTokenBytes(100257)
ASSERT:C1129(Convert to text:C1012($eotBytes; "UTF-8")="<|endoftext|>"; "decode_single_token_bytes(100257) = b'<|endoftext|>'")

// Special-token policy
var $eot : Integer:=100257
var $fip : Integer:=$tk.encodeSingleToken("<|fim_prefix|>")
var $fim : Integer:=$tk.encodeSingleToken("<|fim_middle|>")
ASSERT:C1129($eot=100257; "eot_token must match cl100k_base")
ASSERT:C1129($knownSpecials.includes("<|endoftext|>"); "Known special-token set includes <|endoftext|>")

var $specialText1 : Text:="<|endoftext|> hello <|fim_prefix|>"
$tokens:=$tk.encodeAllowedSpecial($specialText1; $noSpecials)
ASSERT:C1129(Not:C34($tokens.includes($eot)); "eot must not be emitted when disallowed_special=[]")
ASSERT:C1129(Not:C34($tokens.includes($fip)); "fim_prefix must not be emitted when disallowed_special=[]")

var $specialText2 : Text:="<|endoftext|> hello <|fim_prefix|> there <|fim_middle|>"
$tokens:=$tk.encodeAllowedSpecial($specialText2; $noSpecials)
ASSERT:C1129(Not:C34($tokens.includes($eot)); "eot must not be emitted when encoding ordinary text form")
ASSERT:C1129(Not:C34($tokens.includes($fip)); "fim_prefix must not be emitted when encoding ordinary text form")
ASSERT:C1129(Not:C34($tokens.includes($fim)); "fim_middle must not be emitted when encoding ordinary text form")

$tokens:=$tk.encodeAllSpecial($specialText2)
ASSERT:C1129($tokens.includes($eot); "allowed_special='all' emits eot")
ASSERT:C1129($tokens.includes($fip); "allowed_special='all' emits fim_prefix")
ASSERT:C1129($tokens.includes($fim); "allowed_special='all' emits fim_middle")

var $allowFimPrefix : Collection:=["<|fim_prefix|>"]
var $allowEot : Collection:=["<|endoftext|>"]
var $allowFimMiddle : Collection:=["<|fim_middle|>"]

$tokens:=$tk.encodeAllowedSpecial($specialText2; $allowFimPrefix)
ASSERT:C1129(Not:C34($tokens.includes($eot)); "Selective allowed_special excludes eot")
ASSERT:C1129($tokens.includes($fip); "Selective allowed_special includes fim_prefix")
ASSERT:C1129(Not:C34($tokens.includes($fim)); "Selective allowed_special excludes fim_middle")

$tokens:=$tk.encodeAllowedSpecial($specialText2; $allowEot)
ASSERT:C1129($tokens.includes($eot); "Selective allowed_special includes eot")
ASSERT:C1129(Not:C34($tokens.includes($fip)); "Selective allowed_special excludes fim_prefix")
ASSERT:C1129(Not:C34($tokens.includes($fim)); "Selective allowed_special excludes fim_middle")

$tokens:=$tk.encodeAllowedSpecial($specialText2; $allowFimMiddle)
ASSERT:C1129(Not:C34($tokens.includes($eot)); "Selective allowed_special excludes eot when only fim_middle is allowed")
ASSERT:C1129(Not:C34($tokens.includes($fip)); "Selective allowed_special excludes fim_prefix when only fim_middle is allowed")
ASSERT:C1129($tokens.includes($fim); "Selective allowed_special includes fim_middle")

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
	ASSERT:C1129($tk.decode($tk.encodeOrdinary($st))=$st; "encode_ordinary()/decode() round-trip failed for "+JSON Stringify:C1217($st))
End for each

// Decode of empty / null
ASSERT:C1129($tk.decode([])=""; "decode([]) = ''")
ASSERT:C1129($tk.decode(Null:C1517)=""; "decode(null) = ''")
ASSERT:C1129($tk.decode([100257])="<|endoftext|>"; "decode([100257]) = '<|endoftext|>'")
ASSERT:C1129($tk.decode([100258; 100260; 100259])="<|fim_prefix|><|fim_suffix|><|fim_middle|>"; "Special tokens decode back to their literals")
var $helloWorldBytes : Blob:=$tk.decodeBytes([15339; 1917])
ASSERT:C1129(Convert to text:C1012($helloWorldBytes; "UTF-8")="hello world"; "decode_bytes([15339,1917]) = b'hello world'")

// Offsets
var $decodedInfo : Object:=$tk.decodeWithOffsets($tk.encode("hello world"))
ASSERT:C1129($decodedInfo.text="hello world"; "decode_with_offsets() text for hello world")
ASSERT:C1129(JSON Stringify:C1217($decodedInfo.offsets)=JSON Stringify:C1217([0; 5]); "Offsets for 'hello world' must match tiktoken")

var $offsetPrompt : Text:="hello world<|endoftext|> green cow"
$decodedInfo:=$tk.decodeWithOffsets($tk.encodeAllSpecial($offsetPrompt))
ASSERT:C1129($decodedInfo.text=$offsetPrompt; "decode_with_offsets() preserves special-token prompt")
ASSERT:C1129(JSON Stringify:C1217($decodedInfo.offsets)=JSON Stringify:C1217([0; 5; 11; 24; 30]); "Offsets for special-token prompt must match tiktoken")

$offsetPrompt:="我非常渴望与人工智能一起工作"
$decodedInfo:=$tk.decodeWithOffsets($tk.encode($offsetPrompt))
ASSERT:C1129($decodedInfo.text=$offsetPrompt; "decode_with_offsets() preserves Chinese prompt")
ASSERT:C1129(JSON Stringify:C1217($decodedInfo.offsets)=JSON Stringify:C1217([0; 1; 2; 3; 3; 4; 4; 5; 6; 7; 8; 8; 9; 10; 11; 12; 13]); "Offsets for Chinese prompt must match tiktoken")

$offsetPrompt:="நடிகர் சூர்யா"
$decodedInfo:=$tk.decodeWithOffsets($tk.encode($offsetPrompt))
ASSERT:C1129($decodedInfo.text=$offsetPrompt; "decode_with_offsets() preserves Tamil prompt")
ASSERT:C1129(JSON Stringify:C1217($decodedInfo.offsets)=JSON Stringify:C1217([0; 0; 1; 1; 2; 3; 4; 4; 5; 6; 7; 8; 8; 9; 9; 10; 11; 12; 12]); "Offsets for Tamil prompt must match tiktoken")

$offsetPrompt:=" Ġ除"
$decodedInfo:=$tk.decodeWithOffsets($tk.encode($offsetPrompt))
ASSERT:C1129($decodedInfo.text=$offsetPrompt; "decode_with_offsets() preserves mixed-byte prompt")
ASSERT:C1129(JSON Stringify:C1217($decodedInfo.offsets)=JSON Stringify:C1217([0; 1]); "Offsets for mixed-byte prompt must match tiktoken")

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
