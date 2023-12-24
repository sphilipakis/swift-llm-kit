//
//  File.swift
//  
//
//  Created by stephane on 12/11/23.
//

import Foundation

struct Compressing<P> {
    let compress: (P, ChatLog) async throws -> ChatLog
    init(compress: @Sendable @escaping (P, ChatLog) -> ChatLog) {
        self.compress = compress
    }
}

