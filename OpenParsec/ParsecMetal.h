//
//  ParsecMetal.h
//  OpenParsec
//
//  Created by Seçkin KÜKRER on 26.12.2023.
//

#ifndef ParsecMetal_h
#define ParsecMetal_h

#import <Foundation/Foundation.h>

/** Metal `id<MTLCommandQueue>`. */
struct ParsecMetalCommandQueue {
    id<MTLCommandQueue> _nonnull object;
};

/** Metal `id<MTLTexture>`. */
struct ParsecMetalTexture {
    id<MTLTexture> _nonnull object;
};

#endif /* ParsecMetal_h */
