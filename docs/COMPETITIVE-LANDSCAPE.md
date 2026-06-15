# Ruby Excel gems — competitive landscape

Research compiled 2026-06-14 for positioning `ironcalc-ruby` (magnus + rb-sys
bindings over the Rust IronCalc engine). Two fact-checked deep-research passes;
download counts / release dates are accurate as of that date and drift over time.

## TL;DR

**Across 13 surveyed gems, not one evaluates formulas.** They all either read the
*cached* value already stored in the file, or write a formula *string* for Excel /
LibreOffice to compute on open. `ironcalc-ruby` is the **only** Ruby binding that
ships a real calculation engine (create + read + write + **evaluate**).

The ecosystem is fragmented along a read/write divide and has three structural gaps:

1. **Live formula evaluation** — essentially nonexistent in Ruby. IronCalc's core edge.
2. **Memory-efficient large files for read+write/DOM gems** — roo and rubyXL both
   have documented RAM blow-ups.
3. **Full read + write + style round-tripping in one library** — today you pick a
   reader *or* a writer; rubyXL is the only round-tripper and it's DOM-heavy with
   no recalc.

Native/FFI cousins are all **single-purpose**: libxlsxwriter wrappers write-only,
Rust parsers read-only. IronCalc-ruby is the only native binding combining all three
modes — but it shares their native-build friction, making **precompiled gems**
strategically important.

## Capability matrix

| Gem | Read | Write | Eval formulas | xlsx | legacy .xls | ods/csv | Streaming | Impl | Status (2026-06) |
|---|---|---|---|---|---|---|---|---|---|
| **roo** | ✅ | ❌ (Google only) | ❌ cached | ✅ | via roo-xls | ✅ | partial (`each_row_streaming`) | pure Ruby | Active v3.0.0, 108.8M dl |
| **rubyXL** | ✅ | ✅ | ❌ cached; refs don't adapt | ✅ | ❌ | ❌ | ❌ DOM | pure Ruby | Active v3.4.37, 45.1M |
| **caxlsx** (was axlsx) | ❌ | ✅ styling/charts/images | ❌ no cached value by default | ✅ | ❌ | ❌ | partial | pure Ruby | Active v4.5.0, 48.5M |
| axlsx (original) | ❌ | ✅ | ❌ | ✅ | ❌ | ❌ | ❌ | pure Ruby | **Abandoned** (2013) |
| **write_xlsx** | ❌ | ✅ charts/images/cond-fmt/tables | ❌ writes string, stores 0 | ✅ | ❌ | ❌ | ✅ | pure Ruby | Active |
| **creek** | ✅ | ❌ | ❌ | ✅ | ❌ | ❌ | ✅ SAX | pure Ruby | Niche |
| **simple_xlsx_reader** | ✅ | ❌ | ❌ | ✅ | ❌ | ❌ | ✅ SAX | pure Ruby (+nokogiri) | v2.0 |
| **xsv** | ✅ | ❌ | ❌ cached | ✅ | ❌ | ❌ | ✅ SAX | **pure Ruby** (not FFI) | Active v1.4.1 |
| **fast_excel** | ❌ | ✅ | ❌ Excel computes on open | ✅ | ❌ | ❌ | ✅ | **FFI → libxlsxwriter (C)** | **Dormant** (Apr 2025) |
| **xlsxwriter-rb** | ❌ | ✅ | ❌ writes string | ✅ | ❌ | ❌ | ✅ | **FFI → libxlsxwriter (C)** | v0.2.3, ~92k dl |
| **fastsheet** | ✅ | ❌ | ❌ formulas+dates → nil | ✅ | ❌ | ❌ | ? | **Rust via FFI** | Old, v0.1.1 |
| **xlsxtream** | ❌ | ✅ | ❌ writes string | ✅ | ❌ | ❌ | ✅✅ millions of rows | pure Ruby | Active |
| **roo-xls** | ✅ | ❌ | ❌ cached, no formula text | ❌ | ✅ + SpreadsheetML 2003 | ❌ | ❌ | pure Ruby | Companion to roo |
| **spreadsheet** | ✅ | ✅ | ❌ roadmap | ❌ | ✅ (BIFF only) | ❌ | ❌ | pure Ruby (+ruby-ole) | Maintained |
| **ironcalc-ruby** | ✅ | ✅ | **✅ real engine** | ✅ | ❌ | (icalc) | — | **rb-sys → Rust IronCalc** | New |

## Where existing gems are genuinely strong (be honest)

- **Write-side styling / charts / images / conditional formatting**: caxlsx, write_xlsx — mature, feature-rich.
- **Raw write throughput**: fast_excel & xlsxwriter-rb (libxlsxwriter), vendor-claimed 3.5–30× over pure Ruby.
- **Low-memory streaming writes**: xlsxtream — millions of rows, ~35× less memory than caxlsx (100k rows: 311MB vs 1,942MB; third-party corroborated).
- **Streaming reads**: creek, simple_xlsx_reader, xsv (~5× faster than DOM gems).
- **Legacy binary .xls (BIFF)**: spreadsheet (read+write) and roo-xls (read) — a format IronCalc does not target.
- **Reach / popularity**: roo (108.8M downloads) is the default reader; pure-Ruby gems run on JRuby/TruffleRuby with no compiler.

## Evidence of the formula-evaluation pain

- **axlsx #450**: axlsx-generated files read back as *blank* formula cells in roo/rubyXL — it writes the formula string but no cached `<v>`. Google Sheets files read fine (Google writes cached values).
- **rubyXL #273**: a formula shows a stale cached `10` instead of recalculating to `60` after a dependency changed.
- **rubyXL README**: `insert_row`/`delete_row`/`insert_column` *"WILL break formulas referencing cells which have been moved, as the formulas do not adapt."* IronCalc adjusts references natively.
- **spreadsheet** project site calls formula support *"the single most wanted feature"* — unscheduled on the roadmap.

## Memory / large-file pain (documented)

- **roo #179** (2015): ~700MB to process a 2MB / 16k-row file (~350:1). Mitigated since via streaming APIs; the "memory leak / not freed" claim was *refuted* in verification.
- **rubyXL #199** (2015): a 27MiB / ~1M-row file consumed all 6.2GiB RAM and locked the system (DOM-parse architectural limit). Single report, but architectural.

## Where IronCalc-ruby differentiates

1. **Strongest — a real calc engine**: recalculation, reference adjustment on
   insert/delete, no stale/blank formula cells. No other Ruby gem does this.
2. **Read + write + evaluate in one library** — every native cousin is single-purpose;
   even round-tripping rubyXL can't recalc.
3. **Plausible — native-speed, lower-memory large files** — needs independent
   benchmarking vs roo's streaming API, rubyXL, xsv, fastsheet.

### Trade-offs to manage

- **Build friction**: shares the native-compile tax of fast_excel / xlsxwriter-rb /
  fastsheet. Pure-Ruby gems (xsv, xlsxtream, spreadsheet) install with no compiler
  and run on JRuby/TruffleRuby. → **Ship precompiled platform gems** (the cross-gem
  list already in the Rakefile) to neutralize this.
- **Not the raw-write-speed leader**: libxlsxwriter wrappers win pure write throughput;
  xlsxtream wins write memory. IronCalc's pitch is *correctness/recalculation*, not
  "fastest dumper."

## Open questions worth resolving

- Independent (non-vendor) benchmarks: write throughput + memory of ironcalc-ruby vs
  fast_excel / xlsxwriter-rb / xlsxtream; read speed vs xsv / fastsheet / roo.
- Real-world native-build failure rates for the FFI/Rust gems → informs precompiled-gem priority.
- Breadth of IronCalc's function set + locale/number-format handling — enough to
  credibly replace "open in Excel to recalc" workflows?
- No mature gem wraps Rust **calamine** or **rust_xlsxwriter**, nor an active JRuby/Apache POI
  binding — open niches (though calamine is read-only / no-eval, so IronCalc still wins on eval).

## Primary sources

roo, rubyXL, caxlsx/axlsx, write_xlsx, creek, simple_xlsx_reader, xsv, fast_excel,
xlsxwriter-rb, fastsheet, xlsxtream, roo-xls, spreadsheet — GitHub READMEs + issue
trackers (axlsx#450, rubyXL#273/#199, roo#179, fast_excel#61), RubyGems pages,
ruby-toolbox, LibHunt, and practitioner blogs (Atomic Object, Infinum, per-angusta,
schembri.me, simontimms, reinteractive). Full citation list in the research transcripts.
