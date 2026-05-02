//%attributes = {}
// Unit tests for cs.embed.TokenEstimator (Tier 1 heuristic).
// Exact token counts cannot be asserted — only ranges and invariants.

var $est : cs:C1710.TokenEstimator:=cs:C1710.TokenEstimator.me
var $info : Object
var $n : Integer

// ══════════════════════════════════════════════════════════════════════
// EMPTY / TRIVIAL INPUT
// ══════════════════════════════════════════════════════════════════════

ASSERT:C1129($est.estimate("")=0; "Empty text should be 0 tokens")
ASSERT:C1129($est.estimate(" ")>=1; "Single space should be at least 1 token")

$info:=$est.detail("")
ASSERT:C1129($info.tokens=0; "Empty detail tokens=0")
ASSERT:C1129($info.bytes=0; "Empty detail bytes=0")
ASSERT:C1129($info.kind="empty"; "Empty detail kind='empty'")

// ══════════════════════════════════════════════════════════════════════
// MONOTONICITY — longer text never produces fewer tokens
// ══════════════════════════════════════════════════════════════════════

var $short : Text:="Hello"
var $long : Text:="Hello, this is a longer piece of text used to verify monotonicity."
ASSERT:C1129($est.estimate($long)>$est.estimate($short); "Longer text must produce more tokens")

// ══════════════════════════════════════════════════════════════════════
// KIND AUTO-DETECTION
// ══════════════════════════════════════════════════════════════════════

ASSERT:C1129($est.detectKind("")="text"; "Empty → text")
ASSERT:C1129($est.detectKind("   ")="text"; "Whitespace-only → text")
ASSERT:C1129($est.detectKind("Hello world")="text"; "Plain prose → text")
ASSERT:C1129($est.detectKind("{\"a\":1}")="json"; "{...} → json")
ASSERT:C1129($est.detectKind("  [1,2,3]")="json"; "Leading WS [...] → json")
ASSERT:C1129($est.detectKind("<root/>")="xml"; "<...> → xml")

// ══════════════════════════════════════════════════════════════════════
// KIND ORDERING — JSON/XML denser than plain prose for same length
// ══════════════════════════════════════════════════════════════════════

var $sample : Text:="abcdefghijklmnopqrstuvwxyzabcdefghijklmnopqrstuvwxyz"  // 52 chars

var $tText : Integer:=$est.estimate($sample; "text")
var $tJson : Integer:=$est.estimate($sample; "json")
var $tXml : Integer:=$est.estimate($sample; "xml")
var $tBase64 : Integer:=$est.estimate($sample; "base64")

ASSERT:C1129($tJson>=$tText; "JSON ratio denser than text")
ASSERT:C1129($tXml>=$tJson; "XML ratio denser than JSON")
ASSERT:C1129($tBase64>=$tXml; "base64 ratio denser than XML")

// ══════════════════════════════════════════════════════════════════════
// EXPLICIT KIND OVERRIDES AUTO-DETECTION
// ══════════════════════════════════════════════════════════════════════

// "{...}" auto-detects as json, but force "text" → fewer tokens
var $jsonish : Text:="{\"key\":\"value\",\"n\":42}"
ASSERT:C1129($est.estimate($jsonish; "text")<=$est.estimate($jsonish; "json"); "Explicit kind overrides detection")

// ══════════════════════════════════════════════════════════════════════
// DETAIL OBJECT SHAPE
// ══════════════════════════════════════════════════════════════════════

$info:=$est.detail("Hello world")
ASSERT:C1129($info.tokens>0; "detail.tokens>0 for non-empty")
ASSERT:C1129($info.bytes=11; "ASCII bytes match length")
ASSERT:C1129($info.chars=11; "ASCII chars match length")
ASSERT:C1129($info.kind="text"; "Auto-detected kind=text")
ASSERT:C1129($info.bytesPerToken>0; "bytesPerToken>0")

// ══════════════════════════════════════════════════════════════════════
// UTF-8 byte counting — non-ASCII expands
// ══════════════════════════════════════════════════════════════════════

var $ascii : Object:=$est.detail("cafe")  // 4 ASCII chars → 4 bytes
var $accent : Object:=$est.detail("café")  // é = 2 UTF-8 bytes → 5 bytes total
ASSERT:C1129($accent.bytes>$ascii.bytes; "Non-ASCII expands UTF-8 byte count")

// CJK: each char is 3 UTF-8 bytes
var $cjk : Object:=$est.detail("中文测试"; "cjk")  // 4 chars × 3 bytes = 12 bytes
ASSERT:C1129($cjk.bytes=12; "CJK 4 chars → 12 UTF-8 bytes")
ASSERT:C1129($cjk.tokens>=$cjk.chars; "CJK should produce ≥1 token per char on average")

// ══════════════════════════════════════════════════════════════════════
// BATCH
// ══════════════════════════════════════════════════════════════════════

var $batch : Object:=$est.estimateBatch(["Hello"; "World"; "Foo bar baz"])
ASSERT:C1129($batch.count=3; "Batch count")
ASSERT:C1129($batch.tokens=($est.estimate("Hello")+$est.estimate("World")+$est.estimate("Foo bar baz")); "Batch sum equals individual sum")

// Batch with explicit kind
var $batchJson : Object:=$est.estimateBatch(["abcd"; "efgh"]; "json")
var $batchText : Object:=$est.estimateBatch(["abcd"; "efgh"]; "text")
ASSERT:C1129($batchJson.tokens>=$batchText.tokens; "Batch respects kind")

// Empty / null batch
ASSERT:C1129($est.estimateBatch([]).tokens=0; "Empty batch=0")
ASSERT:C1129($est.estimateBatch(Null:C1517).tokens=0; "Null batch=0")

// ══════════════════════════════════════════════════════════════════════
// API SHAPE
// ══════════════════════════════════════════════════════════════════════

ASSERT:C1129($est.kinds.includes("text"); "kinds exposes 'text'")
ASSERT:C1129($est.kinds.includes("json"); "kinds exposes 'json'")
ASSERT:C1129($est.kinds.includes("cjk"); "kinds exposes 'cjk'")

ASSERT:C1129($est.bytesPerToken("text")>0; "bytesPerToken('text')>0")
ASSERT:C1129($est.bytesPerToken("xml")<$est.bytesPerToken("text"); "xml denser than text")
ASSERT:C1129($est.bytesPerToken("doesNotExist")=$est.bytesPerToken("text"); "Unknown kind falls back to 'text'")
