module clox.table;

import clox.array;
import clox.memory;
import clox.obj;
import clox.value;

enum TABLE_MAX_LOAD = 0.75;

struct Entry
{
	ObjString* key;
	Value value;
}

struct Table
{
	size_t capacity;
	size_t count;
	Entry* entries;

	void free()
	{
		freeArr(entries, capacity);
		this = Table.init;
	}

	bool set(ObjString* key, Value value)
	{
		if (count + 1 > capacity * TABLE_MAX_LOAD)
		{
			adjustCapacity(&this, capacity.calcCapacity);
		}

		Entry* entry = findEntry(this.entries, this.capacity, key);
		bool isNewKey = entry.key is null;
		if (isNewKey && entry.value.isNil)
			++count;

		entry.key = key;
		entry.value = value;
		return isNewKey;
	}

	bool get(ObjString* key, Value* value)
	{
		if (count == 0)
			return false;

		Entry* entry = findEntry(entries, capacity, key);
		if (entry.key is null)
			return false;

		*value = entry.value;
		return true;
	}

	bool remove(ObjString* key)
	{
		if (count == 0)
			return false;

		Entry* entry = findEntry(entries, capacity, key);
		if (entry.key is null)
			return false;

		entry.key = null;
		entry.value = Value.from(true);
		return true;
	}

	void addAll(Table* to)
	{
		foreach (ref entry; this.entries[0 .. this.capacity])
		{
			if (entry.key !is null)
				to.set(entry.key, entry.value);
		}
	}

	ObjString* findString(const char* chars, size_t length, uint hash)
	{
		import core.stdc.string : memcmp;

		if (count == 0)
			return null;

		uint idx = hash % capacity;
		while (true)
		{
			Entry* entry = &entries[idx];
			if (entry.key is null)
			{
				if (entry.value.isNil)
					return null;
			}
			else if (entry.key.length == length && entry.key.hash == hash && memcmp(entry.key.chars, chars, length) == 0)
			{
				return entry.key;
			}

			idx = (idx + 1) % capacity;
		}
	}
}

Entry* findEntry(Entry* entries, size_t capacity, ObjString* key)
{
	Entry* tombstone;
	uint idx = key.hash & (capacity - 1);
	while (true)
	{
		Entry* entry = &entries[idx];
		if (entry.key is null)
		{
			if (entry.value.isNil)
				return tombstone ? tombstone : entry;
			else if (tombstone is null)
				tombstone = entry;
		}
		else if (entry.key == key)
			return entry;

		idx = (idx + 1) & (capacity - 1);
	}
}

void adjustCapacity(Table* table, size_t capacity)
{
	Entry* entries = allocate!Entry(capacity);
	foreach (ref entry; entries[0 .. capacity])
	{
		entry.key = null;
		entry.value = Value.nil;
	}

	table.count = 0;
	foreach (ref entry; table.entries[0 .. table.capacity])
	{
		if (entry.key is null)
			continue;

		Entry* dest = findEntry(entries, capacity, entry.key);
		dest.key = entry.key;
		dest.value = entry.value;
		++table.count;
	}

	freeArr(table.entries, table.capacity);

	table.entries = entries;
	table.capacity = capacity;
}
