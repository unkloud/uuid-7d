module uuid7;

import std.uuid;
import std.random;
import std.datetime;

private
{
	__gshared Random rng;
	shared uint counter;
}

shared static this()
{
	rng = Random(unpredictableSeed);
}

UUID uuid7()
{
	ubyte[16] buf;
	foreach (ref ubyte i; buf)
	{
		i = uniform(ubyte.min, ubyte.max, rng);
	}
	ulong epochMs = Clock.currTime().toUnixTime() * 1000;
	buf[0] = (epochMs >> 40) & 0xFF;
	buf[1] = (epochMs >> 32) & 0xFF;
	buf[2] = (epochMs >> 24) & 0xFF;
	buf[3] = (epochMs >> 16) & 0xFF;
	buf[4] = (epochMs >> 8) & 0xFF;
	buf[5] = epochMs & 0xFF;
	buf[6] = (buf[6] & 0x0F) | 0x70;
	buf[8] = (buf[8] & 0x0F) | 0x80;
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
	import std.stdio;
	import core.thread;

	auto u1 = uuid7();
	Thread.sleep(1.seconds);
	auto u2 = uuid7();
	assert(u1 < u2);
}

unittest
{
	import std.array : appender;
	import std.algorithm.iteration : each;
	import std.algorithm;
	import std.range;

	enum N = 10_000;
	auto seen = appender!(UUID[])();
	seen.reserve(N);
	iota(N).each!(_ => seen.put(uuid7()));
	assert(seen.data.sort.uniq.equal(seen.data), "Duplicate UUID7 detected");
}
