//
//  LATMutableDictionary.m
//  MutableDictionarySubclass
//
//  Created by Latrops on 10/9/17.
//

#import "LATMutableDictionary.h"

//Linked list node
@interface LATMutableDictionaryBucket : NSObject

@property (nonatomic, copy) id key;
@property (nonatomic, retain) id obj;
@property (nonatomic, retain) LATMutableDictionaryBucket *next;

@end

@implementation LATMutableDictionaryBucket
@end

//List enumerator
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

//Dictionary without resizing hash table, will eventually work slow without improvments

@interface LATFixedMutableDictionary : NSMutableDictionary
- (id)initWithSize: (NSUInteger)size;
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
        if([bucket.key isEqual: key])
            return bucket.obj;
        bucket = bucket.next;
    }
    return nil;
}

- (NSEnumerator *)keyEnumerator {
    __block NSUInteger index = -1;
    __block LATMutableDictionaryBucket *bucket = nil;
    NSEnumerator *e = [[LATBlockEnumerator alloc] initWithBlock: ^{
        bucket = bucket.next;
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
        if([bucket.key isEqual: key]) {
            if(previousBucket == nil) {
                LATMutableDictionaryBucket *nextBucket = bucket.next;
                _array[bucketIndex] = nextBucket;
            }
            else {
                previousBucket.next = bucket.next;
            }
            _count--;
            return;
        }
        previousBucket = bucket;
        bucket = bucket.next;
    }
}

- (void)setObject: (id)obj forKey: (id)key {
    LATMutableDictionaryBucket *newBucket = [[LATMutableDictionaryBucket alloc] init];
    newBucket.key = key;
    newBucket.obj = obj;
    
    [self removeObjectForKey: key];
    
    NSUInteger bucketIndex = [key hash] % _size;
    newBucket.next = _array[bucketIndex];
    _array[bucketIndex] = newBucket;
    _count++;
}

@end

//FixedDictionary wrapper that keeps track of the table size and creates bigger dictionary whenever current one gets full
@implementation LATMutableDictionary {
    NSUInteger _size;
    LATFixedMutableDictionary *_fixedDict;
}

//Load factor for hash table. Should keep table fast at this ratio, while not consuming too much memory
static const NSUInteger kLATxLoadFactorNumerator = 7;
static const NSUInteger kLATxLoadFactorDenominator = 10;

- (id)init {
    self = [super init];
    return [[LATMutableDictionary alloc] initWithCapacity:0];
}

- (id)initWithCapacity: (NSUInteger)capacity {
    capacity = MAX(capacity, 4);
    if((self = [super init])) {
        _size = capacity;
        _fixedDict = [[LATFixedMutableDictionary alloc] initWithSize: _size];
    }
    return self;
}

- (id)initWithObjects:(id  _Nonnull const [])objects forKeys:(id<NSCopying>  _Nonnull const [])keys count:(NSUInteger)cnt {
    cnt = MAX(cnt, 4);
    if((self = [super init])) {
        _size = cnt;
        _fixedDict = [[LATFixedMutableDictionary alloc] initWithSize: _size];
        for (int i=0; i<cnt; i++) {
            [_fixedDict setObject:objects[i] forKey:keys[i]];
        }
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


