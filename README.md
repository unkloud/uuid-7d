# UUID V7 in D Programming Language

A thread-safe UUID v7 implementation in D with stronger monotonic guarantees than the standard specification. This implementation is a port of PostgreSQL's UUID v7 algorithm with D's characteristics.

Inspired by [UUIDv7 in 33 languages](https://antonz.org/uuidv7/)

## **Disclaimer**
* This is a hobby project with limited test for correctness, performance and thread safety. The format though is validated to be correct. Please use with caution.

## Algorithm Overview

UUID v7 is a time-ordered UUID variant that combines a Unix timestamp with random data to ensure both temporal ordering and uniqueness. This implementation follows the UUID v7 specification with enhanced monotonic guarantees.

### Structure

A UUID v7 consists of 128 bits organized as follows:

```
 0                   1                   2                   3
 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|                           unix_ts_ms                          |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|          unix_ts_ms           |  ver  |       rand_a          |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|var|                        rand_b                             |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|                            rand_b                             |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
```

- **unix_ts_ms (48 bits)**: Unix timestamp in milliseconds
- **ver (4 bits)**: Version field (always 7)
- **rand_a (12 bits)**: Sub-millisecond precision timestamp + random data
- **var (2 bits)**: Variant field (always 10 binary)
- **rand_b (62 bits)**: Random data for uniqueness

### Enhanced Monotonic Algorithm

This implementation provides stronger monotonic guarantees through several mechanisms:

1. **Atomic Timestamp Progression**: Uses atomic compare-and-swap operations to ensure strictly ascending timestamps across all threads
2. **Sub-millisecond Precision**: Maintains nanosecond-level precision internally, mapping to 12-bit sub-millisecond precision in the UUID
3. **Minimal Step Enforcement**: Guarantees a minimum time step between consecutive UUIDs to prevent collisions during rapid generation

## Design Decisions

### 1. Platform-Specific Optimizations

The implementation uses different minimal step bit counts based on the target platform:

- **Windows/macOS**: 10 bits (`SUBMS_MINIMAL_STEP_BITS = 10`)
- **Linux**: 12 bits (`SUBMS_MINIMAL_STEP_BITS = 12`)

This accounts for different timer resolutions and system call overhead on different platforms.

### 2. PostgreSQL Compatibility

For the 10-bit configuration (Windows/macOS), the implementation includes PostgreSQL's specific bit manipulation:

```d
if (SUBMS_MINIMAL_STEP_BITS == 10) {
    // PostgreSQL compatibility: XOR with upper bits of random data
    buf[7] = buf[7] ^ (buf[8] >> 6);
}
```

This ensures compatibility with PostgreSQL's UUID v7 implementation while maintaining the enhanced monotonic properties.

### 3. Thread-Local Random Number Generation

Each thread maintains its own random number generator to avoid contention:
This design choice prioritizes performance in multi-threaded environments while maintaining randomness.

### 4. Nanosecond Internal Precision

The implementation uses nanosecond precision internally (via `Clock.currTime().stdTime * HNSEC`) and maps it to the 12-bit sub-millisecond field. This provides:

- Better collision resistance during rapid UUID generation
- More precise temporal ordering

### 5. Lock-Free Concurrency

The monotonic guarantee is implemented using lock-free atomic operations rather than mutexes, providing:

- Better performance under high contention
- No risk of deadlocks
- Scalability across multiple CPU cores

## Usage

```d
import uuid7;

// Generate a single UUID v7
UUID id = uuid7();
writeln(id.toString()); // e.g., "01234567-89ab-7def-8123-456789abcdef"

// Verify properties
assert(id.ver() == 7);    // Version 7
assert(id.var() == 2);    // RFC-4122 variant

// UUIDs are naturally ordered by generation time
UUID id1 = uuid7();
UUID id2 = uuid7();
assert(id1 < id2);        // Always true due to monotonic guarantees
```

## Performance Characteristics

- **Thread-safe**: Fully concurrent with lock-free algorithms
- **Monotonic**: Strictly ascending order guaranteed across all threads

## Comparison with Standard UUID v7

This is largely a port of PostgreSQL implementation. The major difference from the standard is extra bits are being used to enhance the time precision. On linux it is 12bits, on Windows/MacOS it is 10 bits.
Details can be found in the C source code I listed below.


## Testing

The implementation includes comprehensive unit tests covering:

- Basic UUID v7 format validation
- Monotonic ordering guarantees
- Uniqueness across large sample sizes (100,000 UUIDs)
- Thread safety verification

Run tests with:
```bash
dub test
```

## References

- [UUID Version 7](https://www.rfc-editor.org/rfc/rfc9562.html#name-uuid-version-7)
- [PostgreSQL UUID Implementation](https://github.com/postgres/postgres/blob/master/src/backend/utils/adt/uuid.c)
- [UUIDv7 in 33 languages](https://antonz.org/uuidv7/)
