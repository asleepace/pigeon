//
//  SSEClient.swift
//  Pigeon
//
//  Created by Colin Teahan on 1/11/26.
//

import Network
import Foundation

class SSEClient: Identifiable {
    let id = UUID()
    let connection: NWConnection
    
    init(connection: NWConnection) {
        self.connection = connection
    }
    
    func sendHeaders() {
        let headers = """
        HTTP/1.1 200 OK\r
        Content-Type: text/event-stream\r
        Cache-Control: no-cache\r
        Connection: keep-alive\r
        Access-Control-Allow-Origin: *\r
        \r
        
        """
        connection.send(content: headers.data(using: .utf8), completion: .contentProcessed { _ in })
    }
    
    func send(event: String? = nil, data: String, id: String? = nil) {
        var message = ""
        if let id { message += "id: \(id)\n" }
        if let event { message += "event: \(event)\n" }
        message += "data: \(data)\n\n"
        
        connection.send(content: message.data(using: .utf8), completion: .contentProcessed { _ in })
    }
    
    func close() {
        connection.cancel()
    }
}
