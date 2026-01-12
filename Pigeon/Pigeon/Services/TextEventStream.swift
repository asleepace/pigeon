//
//  TextEventStream.swift
//  Pigeon
//
//  Created by Colin Teahan on 1/10/26.
//

import Foundation

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
        guard let task else { return false }
        return task.state == .running
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
        var request = URLRequest(url: url)
        request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
        if let lastEventId {
            request.setValue(lastEventId, forHTTPHeaderField: "Last-Event-ID")
        }
        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
        }
        request.timeoutInterval = timeout
        task = session?.dataTask(with: request)
        task?.resume()
    }

    func disconnect() {
        task?.cancel()
    }

    // MARK: - URLSessionDataDelegate

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        guard let text = String(data: data, encoding: .utf8) else { return }
        for chunk in text.components(separatedBy: "\n\n") {
            if chunk.isEmpty { continue }
            if chunk.starts(with: ":") { continue } // Ignore stream comments
            let textEvent = TextEvent(chunk)
            delegate?.textEventStreamDidReceive(textEvent: textEvent)
            lastEventId = textEvent.eventId
        }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: (any Error)?) {
        delegate?.textEventStreamDidError(error: error ?? Errors.unknownNetworkError)
    }

    func urlSession(_ session: URLSession, didBecomeInvalidWithError error: (any Error)?) {
        delegate?.textEventStreamDidError(error: error ?? Errors.unknownNetworkError)
        task = nil
    }
}
