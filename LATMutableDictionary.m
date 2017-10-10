//
//  LATMutableDictionary.m
//  MutableDictionarySubclass
//
//  Created by Latrops on 10/9/17.
//


#import "LATFixedMutableDictionary.h"

@interface LATMutableDictionaryBucket : NSObject

@property (nonatomic, copy) id key;
@property (nonatomic, retain) id obj;
@property (nonatomic, retain) LATMutableDictionaryBucket *next;

@end

@implementation LATMutableDictionaryBucket
@end

@interface LATBlockEnumerator : NSEnumerator {
    id (^_block)(void);
}

- (id)initWithBlock: (id (^)(void))block;

@end

@implementation LATBlockEnumerator

- (id)initWithBlock: (id (^)(void))block {
    if((self = [self init]))
        _block = [block copy];
    return self;
}

- (id)nextObject {
    return _block();
}

@end


@implementation LATFixedMutableDictionary {
    NSUInteger _count;
    NSUInteger _size;
    __strong LATMutableDictionaryBucket **_array;
}

- (id)initWithSize: (NSUInteger)size {
    if((self = [super init])) {
        _size = size;
        _array = (__strong LATMutableDictionaryBucket **)calloc(size, sizeof(LATMutableDictionaryBucket **));
    }
    return self;
}

- (NSUInteger)count {
    return _count;
}

- (id)objectForKey: (id)key {
    NSUInteger bucketIndex = [key hash] % _size;
    LATMutableDictionaryBucket *bucket = _array[bucketIndex];
    while(bucket) {
        if([[bucket key] isEqual: key])
            return [bucket obj];
        bucket = [bucket next];
    }
    return nil;
}

- (NSEnumerator *)keyEnumerator {
    __block NSUInteger index = -1;
    __block LATMutableDictionaryBucket *bucket = nil;
    NSEnumerator *e = [[LATBlockEnumerator alloc] initWithBlock: ^{
        bucket = [bucket next];
        while(!bucket) {
            index++;
            if(index >= _size)
                return (id)nil;
            bucket = _array[index];
        }
        return [bucket key];
    }];
    return e;
}

- (void)removeObjectForKey: (id)key {
    NSUInteger bucketIndex = [key hash] % _size;
    LATMutableDictionaryBucket *previousBucket = nil;
    LATMutableDictionaryBucket *bucket = _array[bucketIndex];
    while(bucket) {
        if([[bucket key] isEqual: key]) {
            if(previousBucket == nil) {
                LATMutableDictionaryBucket *nextBucket = [bucket next];
                _array[bucketIndex] = nextBucket;
            }
            else {
                [previousBucket setNext: [bucket next]];
            }
            _count--;
            return;
        }
        previousBucket = bucket;
        bucket = [bucket next];
    }
}

- (void)setObject: (id)obj forKey: (id)key {
    LATMutableDictionaryBucket *newBucket = [[LATMutableDictionaryBucket alloc] init];
    [newBucket setKey: key];
    [newBucket setObj: obj];
    
    [self removeObjectForKey: key];
    
    NSUInteger bucketIndex = [key hash] % _size;
    [newBucket setNext: _array[bucketIndex]];
    _array[bucketIndex] = newBucket;
    _count++;
}

@end

@implementation LATMutableDictionary {
    NSUInteger _size;
    LATFixedMutableDictionary *_fixedDict;
}

static const NSUInteger kLATxLoadFactorNumerator = 7;
static const NSUInteger kLATxLoadFactorDenominator = 10;

- (id)initWithCapacity: (NSUInteger)capacity {
    capacity = MAX(capacity, 4);
    if((self = [super init])) {
        _size = capacity;
        _fixedDict = [[LATFixedMutableDictionary alloc] initWithSize: _size];
    }
    return self;
}

- (NSUInteger)count {
    return [_fixedDict count];
}

- (id)objectForKey: (id)key {
    return [_fixedDict objectForKey: key];
}

- (NSEnumerator *)keyEnumerator {
    return [_fixedDict keyEnumerator];
}

- (void)removeObjectForKey: (id)key {
    [_fixedDict removeObjectForKey: key];
}

- (void)setObject: (id)obj forKey:(id)key {
    [_fixedDict setObject: obj forKey: key];
    
    if(kLATxLoadFactorDenominator * [_fixedDict count] / _size > kLATxLoadFactorNumerator) {
        NSUInteger newSize = _size * 2;
        LATFixedMutableDictionary *newDict = [[LATFixedMutableDictionary alloc] initWithSize: newSize];
        
        for(id key in _fixedDict)
            [newDict setObject: [_fixedDict objectForKey: key] forKey: key];
        
        _size = newSize;
        _fixedDict = newDict;
    }
}

@end

static void Test(NSMutableDictionary *testDictionary) {
    NSMutableDictionary *referenceDictionary = [NSMutableDictionary dictionary];
    
    struct seed_t { unsigned short v[3]; };
    __block struct seed_t seed = { { 0, 0, 0 } };
    
    __block NSMutableDictionary *dict;
    
    void (^blocks[])(void) = {
        ^{
            id key = [NSNumber numberWithInt: nrand48(seed.v) % 1024];
            id value = [NSNumber numberWithLong: nrand48(seed.v)];
            [dict setObject: value forKey: key];
            NSLog(@"%@",key);
        },
        ^{
            id key = [NSNumber numberWithInt: nrand48(seed.v) % 1024];
            [dict removeObjectForKey: key];
        }
    };
    
    for(int i = 0; i < 10000; i++) {
        NSUInteger index = nrand48(seed.v) % (sizeof(blocks) / sizeof(*blocks));
        void (^block)(void) = blocks[index];
        
        struct seed_t oldSeed = seed;
        dict = testDictionary;
        block();
        seed = oldSeed;
        dict = referenceDictionary;
        block();
        
        if(![testDictionary isEqual: referenceDictionary]) {
            NSLog(@"Dictionaries are not equal: %@ %@", referenceDictionary, testDictionary);
            exit(1);
        }
    }
}

void LATMutableDictionaryTest(void){
    Test([[LATFixedMutableDictionary alloc] initWithSize: 10]);
    Test([LATMutableDictionary dictionary]);
}



