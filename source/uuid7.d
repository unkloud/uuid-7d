module uuid7;

import core.atomic;
import core.stdc.time;
import core.time;
import std.datetime;
import std.datetime.systime;
import std.random;
import std.uuid;

enum NS_PER_S = 1_000_000_000L;
enum NS_PER_MS = 1_000_000L;
enum NS_PER_US = 1000L;
enum US_PER_MS = 1000L;
version (Windows)
	enum SUBMS_MINIMAL_STEP_BITS = 10;
else version (OSX)
	enum SUBMS_MINIMAL_STEP_BITS = 10;
else version (linux)
	enum SUBMS_MINIMAL_STEP_BITS = 12;
else
	enum SUBMS_MINIMAL_STEP_BITS = 12;
enum SUBMS_MINIMAL_STEP_NS = ((NS_PER_MS / (1 << SUBMS_MINIMAL_STEP_BITS)) + 1);
enum SUBMS_BITS = 12L;
// hecto-nanosecond
enum HNSEC = 100;
// See https://dlang.org/phobos/std_datetime_systime.html#.SysTime.toUnixTime for details
enum HNSEC_TIL_EPOCH = 621_355_968_000_000_000L;

long get_real_time_ns_ascending()
{
	static shared long previous_hnsec = 0;
	long now_hnsec = Clock.currTime(UTC()).stdTime - HNSEC_TIL_EPOCH;
	while (true)
	{
		long prev = atomicLoad(previous_hnsec);
		long next_hnsec = now_hnsec;
		if (next_hnsec * HNSEC < prev * HNSEC + SUBMS_MINIMAL_STEP_NS)
		{
			next_hnsec = prev + SUBMS_MINIMAL_STEP_BITS / HNSEC;
		}
		if (cas(&previous_hnsec, prev, next_hnsec))
		{
			return next_hnsec * HNSEC;
		}
		now_hnsec = Clock.currTime(UTC()).stdTime - HNSEC_TIL_EPOCH;
	}
}

void uuid_set_version(ubyte[] buf, ubyte v)
{
	buf[6] = cast(ubyte)((buf[6] & 0x0f) | (v << 4));
	buf[8] = cast(ubyte)(buf[8] & 0x3f) | 0x80;
}

UUID uuid7()
{
	static Random threadRng;
	static bool rngInitialized = false;
	if (!rngInitialized)
	{
		threadRng = Random(unpredictableSeed);
		rngInitialized = true;
	}
	ubyte[16] buf;
	long ns = get_real_time_ns_ascending();
	ulong epochMs = ns / NS_PER_MS;
	uint sub_ms = cast(uint)(ns % NS_PER_MS);
	buf[0] = (epochMs >> 40) & 0xFF;
	buf[1] = (epochMs >> 32) & 0xFF;
	buf[2] = (epochMs >> 24) & 0xFF;
	buf[3] = (epochMs >> 16) & 0xFF;
	buf[4] = (epochMs >> 8) & 0xFF;
	buf[5] = epochMs & 0xFF;
	uint increased_clock_precision = (sub_ms * (1 << SUBMS_BITS)) / NS_PER_MS;
	buf[6] = cast(ubyte)(increased_clock_precision >> 8);
	buf[7] = cast(ubyte)(increased_clock_precision);
	foreach (i; 8 .. 16)
	{
		buf[i] = uniform!ubyte(threadRng);
	}
	if (SUBMS_MINIMAL_STEP_BITS == 10)
	{
		// https://github.com/postgres/postgres/blob/master/src/backend/utils/adt/uuid.c#L633
		buf[7] = buf[7] ^ (buf[8] >> 6);
	}
	uuid_set_version(buf, 7);
	return UUID(buf);
}

int ver(ref UUID id)
{
	return id.data[6] >> 4;
}

int var(ref UUID id)
{
	return id.data[8] >> 6;
}

// Test cases
unittest
{
	import std.conv;
	import std.algorithm;

	UUID id = uuid7();
	assert(id.ver() == 7, "Expected version 7 UUID");
	assert(id.var() == 2, "Expected RFC-4122 variant (2)");
	immutable str = id.toString();
	assert(str.length == 36, "Canonical UUID string must be 36 chars");
	assert(str.count('-') == 4, "Canonical UUID string must contain 4 hyphens");
	assert(str.to!UUID == id, "Parsing the string must yield the original UUID");
}

unittest
{
	import core.thread;
	import std.stdio;

	auto u1 = uuid7();
	auto u2 = uuid7();
	auto u3 = uuid7();
	auto u4 = uuid7();
	auto u5 = uuid7();
	auto u6 = uuid7();
	auto u7 = uuid7();
	auto u8 = uuid7();
	auto u9 = uuid7();
	assert(u1 < u2);
	assert(u2 < u3);
	assert(u3 < u4);
	assert(u4 < u5);
	assert(u5 < u6);
	assert(u6 < u7);
	assert(u7 < u8);
	assert(u8 < u9);
}

unittest
{
	import std.array : appender;
	import std.algorithm.iteration : each;
	import std.algorithm;
	import std.range;

	enum N = 1_000_000;
	auto seen = appender!(UUID[])();
	seen.reserve(N);
	iota(N).each!(_ => seen.put(uuid7()));
	assert(seen.data.sort.uniq.equal(seen.data), "Duplicate UUID7 detected");
}
