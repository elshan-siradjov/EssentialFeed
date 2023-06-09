//
//  RemoteFeedLoaderTests.swift
//  EssentialFeedTests
//
//  Created by Elshan Siradjov on 19.03.23.
//

import XCTest

import EssentialFeed

class RemoteFeedLoaderTests: XCTestCase {

    func test_init_doesNotRequestDataFromURL(){
        let(_, client) = makeSUT()
        XCTAssertTrue(client.requestedURLs.isEmpty)
    }
    
    func test_load_requestDataFromURL() {
        let url = URL(string: "https://a-given-url.com")!
        
        // Arrange part - Given a client and a sut
        let (sut, client)  = makeSUT(url: url)
    
        // Act part - When we invoke sut.loat
        sut.load{_ in }
        
        // Assert part - Then assert that a URL request was initiated in client
        XCTAssertEqual(client.requestedURLs, [url])
    }
    
    func test_load_deliversErrorOnClientError(){
        // Arrange:
        // Given the sut and its HTTP client spy
        let (sut, client) = makeSUT()
        
        
        // Act:
        // When we tell the sut to load and we
        // complete the client's HTTP request with an error
        expect(sut, toCompleteWith: .failure(.invalidData), when: {
            let clientError = NSError(domain: "Test", code: 0)
            client.complete(with: clientError)
        })
    }
    
    
    func test_load_deliversErrorOnNon200HTTPResponse(){
        // Arrange:
        // Given the sut and its HTTP client spy
        let (sut, client) = makeSUT()
        
        // Act:
        // When we tell the sut to load and we
        // complete the client's HTTP request with an error
        
        let samples = [199, 201, 300, 400, 500]
        samples.enumerated().forEach{ index, code in
            
            expect(sut, toCompleteWith: .failure(.invalidData), when: {
                client.complete(withStatusCode: 200, at: index)
            })
        }
        // Assert:
        // Then we expect the capture load error
        // to be a connectivity error
    }
    
    func test_load_deliversErrorOn200HTTPResponseWithInvalidJSON(){
        let (sut, client) = makeSUT()
        
        expect(sut, toCompleteWith: .failure(.invalidData), when: {
            let invalidJSON = Data(bytes: "invalid json".utf8)
            client.complete(withStatusCode: 200, data: invalidJSON)
        })
    }
    
    func test_load_deliversNoItemsOn200HTTPResponseWithEmptyJSONList(){
        
        let (sut, client) = makeSUT()
        
        expect(sut, toCompleteWith: .success([]), when: {
            let emptyListJSON = Data(bytes: "{\"items\": []}".utf8)
            
            client.complete(withStatusCode: 200, data: emptyListJSON)
        })
    }
    
    func test_load_deliversItemsOn200HTTPResponseWithJSONItems() {
        let (sut, client) = makeSUT()
        
        let item1 = FeedItem(
            id: UUID(),
            description: nil,
            location: nil,
            imageURL: URL(string: "http://a-url.com")!)
        
        let item1JSON = [
            "id": item1.id.uuidString,
            "image": item1.imageURL.absoluteString
        ]
        
        let item2 = FeedItem(
            id: UUID(),
            description: "a description",
            location: "a location",
            imageURL: URL(string: "http://another-url.com")!)
        
        let item2JSON = [
            "id": item2.id.uuidString,
            "description": item2.description,
            "location": item2.location,
            "image": item2.imageURL
        ] as [String : Any]
        
        let itemsJSON = [
            "items": [item1JSON, item2JSON]
        ]
        
        expect(sut, toCompleteWith: .success([item1, item2]), when: {
            let json = try! JSONSerialization.data(withJSONObject: itemsJSON)
            client.complete(withStatusCode: 200, data: json)
        })
    }
    
    func test_loadTwice_requestDataFromURLTwice() {
        let url = URL(string: "https://a-given-url.com")!
        
        // Arrange part - Given a client and a sut
        let (sut, client)  = makeSUT(url: url)
    
        // Act part - When we invoke sut.loat
        sut.load{_ in }
        sut.load{_ in }
        
        // Assert part - Then assert that a URL request was initiated in client
        XCTAssertEqual(client.requestedURLs, [url, url])
    }
    
    // MARK: Helpers
    private func makeSUT(url: URL = URL(string: "https://a-url.com")!) -> (sut: RemoteFeedLoader, client: HTTPClientSpy){
        let client = HTTPClientSpy()
        let sut = RemoteFeedLoader(url: url, client: client)
        return (sut, client)
    }
    
    private func expect(_ sut: RemoteFeedLoader, toCompleteWith result: RemoteFeedLoader.Result, when action: () -> Void, file: StaticString = #file, line: UInt = #line){
        
        var capturedResults = [RemoteFeedLoader.Result]()
        sut.load{ capturedResults.append($0)}
        
        action()
        
        XCTAssertEqual(capturedResults, [result], file: file, line: line)
    }
    
    private class HTTPClientSpy: HTTPClient{
        var requestedURL: URL?
        var requestedURLs: [URL]{
            return messages.map {$0.url}
        }
        
        private var messages = [(url: URL, completion: (HTTPClientResult) -> Void)]()
        
        func get(from url: URL, completion: @escaping(HTTPClientResult) -> Void){
            
            messages.append((url, completion))
            requestedURL = url
        }
        
        func complete(with error: Error, at index: Int = 0){
            messages[index].completion(.failure(error))
        }
        
        func complete(withStatusCode code: Int, data: Data = Data(), at index: Int = 0){

            let response = HTTPURLResponse(url: requestedURLs[index], statusCode: code, httpVersion: nil, headerFields: nil)!
            messages[index].completion(.success(data, response))
        }
    }
}
