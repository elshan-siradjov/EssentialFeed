//
//  FeedLoader.swift
//  EssentialFeed
//
//  Created by Elshan Siradjov on 19.03.23.
//

import Foundation

enum LoadFeedResult {
    case success([FeedItem])
    case error(Error)
}

// interface
protocol FeedLoader {
    func load(completion: @escaping (LoadFeedResult) -> Void)
}
