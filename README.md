# Byte-Pair Encoding (BPE)

Token estimation and exact tokenization for 4D, designed for use before
calling embedding or chat-completion APIs.

Two complementary classes:

| Class                    | Tier | Speed             | Accuracy             | Use case                              |
| ------------------------ | ---- | ----------------- | -------------------- | ------------------------------------- |
| `cs.bpe.TokenEstimator` | 1    | Microseconds      | ±10–15% on prose     | Live UI feedback, batch cost preview  |
| `cs.bpe.Tokenizer`      | 2    | ~1 ms / sentence  | Exact (BPE)          | Final cost check before API call      |

The estimator is a heuristic over UTF-8 byte counts. The tokenizer is a
pure-4D port of [tiktoken][tiktoken] / [js-tiktoken][js-tiktoken] and
produces byte-identical output to the canonical Python implementation.

[tiktoken]: https://github.com/openai/tiktoken
[js-tiktoken]: https://github.com/openai/tiktoken/tree/main/js

## Layout

```
Project/Sources/Classes/
  TokenEstimator.4dm     # Tier 1 — heuristic
  Tokenizer.4dm          # Tier 2 — exact BPE

Project/Sources/Methods/
  test_tokenEstimator.4dm
  test_tokenizer.4dm

Resources/tokenizers/
  cl100k_base.tiktoken   # 1.6 MB vocab (100,256 entries)
```

The two classes are independent — you can ship just `TokenEstimator`
without the vocab file if you only need the heuristic.

## Tier 1 — `TokenEstimator`

Singleton. Estimates tokens from UTF-8 byte count and a per-content-kind
ratio calibrated against `cl100k_base`.

```4d
var $est:=cs.bpe.TokenEstimator.me

var $n : Integer:=$est.estimate("Hello, world!")
// → 4 (or close to it)

var $n2 : Integer:=$est.estimate($jsonString; "json")
// → denser kind, more tokens for the same byte count

var $info : Object:=$est.detail($text)
// → {tokens, bytes, chars, kind, bytesPerToken}

var $batch : Object:=$est.estimateBatch($collectionOfTexts)
// → {tokens, count, bytes}
```

### Auto-detection

When `$kind` is omitted or empty, the kind is detected from the first
non-whitespace character: `{` or `[` → `json`, `<` → `xml`, otherwise
`text`. You can pass an explicit kind to override.

### Calibration table (UTF-8 bytes per token)

| Kind       | Ratio | Notes                                    |
| ---------- | ----- | ---------------------------------------- |
| `text`     | 4.0   | English / mostly-ASCII prose             |
| `latin`    | 3.3   | French/German/Spanish — accents split    |
| `markdown` | 3.6   | Prose + light syntax                     |
| `code`     | 3.0   | Identifiers + punctuation                |
| `json`     | 2.8   | Braces/quotes/colons each cost a token   |
| `xml`      | 2.4   | Tag brackets are expensive               |
| `html`     | 2.5   |                                          |
| `url`      | 2.5   | Slashes, `?`, `&`                        |
| `base64`   | 2.0   | Dense low-entropy alphanumerics          |
| `cjk`      | 2.0   | 3-byte UTF-8 chars, ~1.5 tokens each     |
| `mixed`    | 3.0   | Multilingual fallback                    |

### When the heuristic gets it wrong

- **Heavy structured data** (deeply nested JSON, XML with long URIs):
  may overestimate by 10–20%.
- **Short text** (< 10 chars): noise dominates; off by 1–2 tokens.
- **Code with many short tokens** (regexes, template strings):
  underestimates because `cl100k_base` has many code-specific merges.

If the estimate matters for cost gating, use Tier 2 for the final check.

## Tier 2 — `Tokenizer`

Singleton. Loads the BPE vocabulary on first use (~2 seconds for
`cl100k_base`). Subsequent calls are fast.

```4d
var $tk :=cs.bpe.Tokenizer.me

var $tokens : Collection:=$tk.encode("Hello, world!")
// → [9906, 11, 1917, 0]

var $n : Integer:=$tk.count("Hello, world!")
// → 4

var $text : Text:=$tk.decode([9906; 11; 1917; 0])
// → "Hello, world!"
```

### Supported encodings

| Encoding      | Models                                                           | Status     |
| ------------- | ---------------------------------------------------------------- | ---------- |
| `cl100k_base` | text-embedding-3-{small,large}, ada-002, gpt-3.5-turbo, gpt-4    | ✅ Shipped |
| `o200k_base`  | gpt-4o, gpt-4.1, gpt-5, o1/o3/o4                                 | Drop-in    |

To add `o200k_base`:

1. Download `o200k_base.tiktoken` from the OpenAI CDN:
   `https://openaipublic.blob.core.windows.net/encodings/o200k_base.tiktoken`
2. Place it in `Resources/tokenizers/`
3. Add a `Case of` branch in `Tokenizer._ensureLoaded` with the
   matching `pat_str` and `special_tokens` (see
   [tiktoken/registry.json][registry] for canonical values).

[registry]: https://github.com/openai/tiktoken/blob/main/tiktoken/registry.json

### How it works

1. **Pre-tokenize** with the encoding-specific PCRE pattern
   (`\p{L}+`, `\p{N}{1,3}`, …). 4D's ICU regex supports all required
   features (`(?i:...)`, Unicode property classes, lookahead).
2. For each piece, try the full byte sequence as a token; if it's not
   in the vocab, run **byte-pair encoding**: greedily merge the
   lowest-rank adjacent pair until no more merges apply.
3. Emit ranks for the surviving parts.

The vocab is stored as a 4D `Object` keyed by comma-joined byte
strings (e.g. `"72,101,108,108,111"` → rank). Lookup is O(1).

### Performance

| Operation                         | Cost                                   |
| --------------------------------- | -------------------------------------- |
| First `encode` / `count` call     | ~2.2 s vocab load (one-time)           |
| Subsequent encode (short string)  | ~1 ms                                  |
| Decode                            | proportional to byte length            |

The vocab takes ~30 MB of process RAM after parsing.

### Correctness

`test_tokenizer.4dm` asserts byte-identical output against the canonical
Python `tiktoken` library on:

- ASCII prose, repeated words, punctuation
- CJK (`"中文测试"` → `[16325, 17161, 82805]`)
- Latin diacritics (`"Café résumé naïve"`)
- Digit grouping (`\p{N}{1,3}` cap)
- Whitespace and newline handling
- encode → decode round-trip

## When to use which

```
                  short text?            cost matters?
                       │                       │
        ┌──────────────┴──────────────┐        │
        │                             │        │
        no                           yes       no  → TokenEstimator
        │                             │
        TokenEstimator           Tokenizer
        (live UI)                (final check)
```

Typical pipeline:

```4d
// 1. Live UI — estimate as the user types
$ui.tokenCount:=cs.bpe.TokenEstimator.me.estimate($input)

// 2. Before submitting — verify with the real tokenizer
var $exact : Integer:=cs.bpe.Tokenizer.me.count($input)
If ($exact>$model.maxInputTokens)
    throw {message: "Input exceeds model limit"}
End if

// 3. Submit to API
```

## Possible TODOs

- Add more tests
- Explore loading the vocabulary only once for all processes, possibly via a
  shared singleton or equivalent shared cache.

## License

Tier 2 is a port of [tiktoken][tiktoken] (MIT) and ships the
`cl100k_base.tiktoken` rank file released by OpenAI under the same MIT
license. Per-file headers preserve the upstream attribution.
