//
//  TextEventStream.swift
//  Pigeon
//
//  Created by Colin Teahan on 1/10/26.
//

import Foundation

struct TextEvent {
    let id: String
    let type: String?
    let data: String?
    let timestamp: Date = Date()
    
    init(_ chunk: String) {
        var id: String = ""
        var type: String = "message"
        var data: String?
        chunk.split(separator: "\n").forEach { line in
            if (line.starts(with: "id: ")) {
                id = String(line.dropFirst(4))
            }
            else if (line.starts(with: "event: ")) {
                type = String(line.dropFirst(7))
            }
            else if (line.starts(with: "data: ")) {
                data = String(line.dropFirst(6))
            }
        }
        
        // system events will be JSON objects {}
        if data?.hasPrefix("{") == true && data?.hasSuffix("}") == true {
            type = "system"
        }
        
        self.type = type
        self.data = data
        self.id = id
    }
    
    func decode<T: Decodable>(_ type: T.Type) -> T? {
        guard let data = self.data?.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }
    
    func debug() {
        print(self)
    }
}

protocol TextEventStreamDelegate: AnyObject {
    func textEventStreamDidReceive(textEvent: TextEvent)
    func textEventStreamDidError(error: Error)
}

class TextEventStream: NSObject, URLSessionDataDelegate {
    
    enum Errors: Error {
        case unknownNetworkError
        case invalidURL
    }
    
    private var url: URL
    private var lastEventId: String?
    private var session: URLSession?
    private var task: URLSessionTask?
    private weak var delegate: TextEventStreamDelegate?
    
    var timeout: TimeInterval = .infinity
    var headers: [String: String] = [:]
    
    var isConnected: Bool {
        guard self.task != nil else { return false }
        return self.task!.state == .running
    }
    
    convenience init(_ urlString: String, delegate: TextEventStreamDelegate) throws {
        guard let url = URL(string: urlString) else {
            throw Errors.invalidURL
        }
        self.init(url, delegate: delegate)
    }
    
    init(_ url: URL, delegate: TextEventStreamDelegate) {
        self.delegate = delegate
        self.url = url
        super.init()
        self.session = URLSession(configuration: .default, delegate: self, delegateQueue: .main)
    }
    
    
    func setUrl(_ urlString: String) throws {
        guard let url = URL(string: urlString) else {
            throw Errors.invalidURL
        }
        self.url = url
        self.lastEventId = nil
        self.connect()
    }
    
    func connect() {
        var request = URLRequest(url: self.url)
        request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
        if self.lastEventId != nil {
            request.setValue(self.lastEventId, forHTTPHeaderField: "Last-Event-ID")
        }
        for (key, value) in self.headers {
            request.setValue(value, forHTTPHeaderField: key)
        }
        request.timeoutInterval = self.timeout
        self.task = self.session?.dataTask(with: request)
        self.task?.resume()
    }
    
    func disconnect() {
        self.task?.cancel()
    }
    
    // MARK: Session Delegate
    
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        guard let text = String(data: data, encoding: .utf8) else { return }
        for ev in text.components(separatedBy: "\n\n") {
            if ev.isEmpty { continue }
            if ev.starts(with: ":") { continue } // ignore stream comments
            let textEvent = TextEvent(ev)
            self.delegate?.textEventStreamDidReceive(textEvent: textEvent)
            self.lastEventId = textEvent.id
        }
    }
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: (any Error)?) {
        self.delegate?.textEventStreamDidError(error: error ?? Errors.unknownNetworkError)
    }

    func urlSession(_ session: URLSession, didBecomeInvalidWithError error: (any Error)?) {
        self.delegate?.textEventStreamDidError(error: error ?? Errors.unknownNetworkError)
        self.task = nil
    }
}
