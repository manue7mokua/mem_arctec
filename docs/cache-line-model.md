# Cache-Line Model

The simulator uses byte addresses and 32-bit words. The low two address bits identify a byte within a word; the cache returns or updates the containing word.

## Line layout

Bits increase from the first word in a line to the last:

| Level | Block size | Words | Packed line width |
| --- | ---: | ---: | ---: |
| L1 | 16 bytes | 4 | 128 bits |
| L2 | 32 bytes | 8 | 256 bits |

For an L2 line based at address `000`, packed bits `[31:0]` contain word `000`, bits `[63:32]` contain word `004`, and bits `[255:224]` contain word `01C`.

## Transfers

- A memory read returns one complete eight-word L2 line.
- L2 stores that 256-bit line without discarding neighboring words.
- Address bit 4 selects the lower or upper 128-bit half for an L1 refill.
- A dirty L1 eviction replaces only the matching half of its parent L2 line.
- A dirty L2 eviction writes the complete 256-bit line to memory.
- If an L1 writeback misses in L2, memory supplies the other half before the dirty L1 half is merged.

These rules preserve independent word values across refill, promotion, replacement, and writeback.

## Traffic counters

The final `RESULT` record includes `l1_fills`, `l2_fills`, `memory_reads`, and `memory_writes`. A memory operation transfers one complete 32-byte L2 line.
