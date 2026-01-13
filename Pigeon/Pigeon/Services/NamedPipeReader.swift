//
//  NamedPipeReader.swift
//  Pigeon
//
//  Created by Colin Teahan on 1/12/26.
//

import Foundation

class NamedPipeReader {
    
    enum Errors: Error {
        case failedToCreatePipe(String)
    }
    
    private let path: String
    private var fileHandle: FileHandle?
    private var isRunning = false
    
    init(sessionName: String = "stdin") throws {
        self.path = FileManager.default.temporaryDirectory
                .appendingPathComponent("consoledump")
                .appendingPathExtension(sessionName)
                .path
        
    }
    
    func start(onData: @escaping(String) -> Void) throws {
        print("[NamedPipeReader] Creating pipe at \(path)")
        unlink(path)
        
        guard mkfifo(path, 0o644) == 0 else {
            throw Errors.failedToCreatePipe(String(cString: strerror(errno)))
        }
        
        self.isRunning = true
        
        DispatchQueue.global(qos: .background).async { [weak self] in
            while self?.isRunning == true {
                // Open blocks until a writer connects
                let fd = open(self?.path ?? "", O_RDONLY)
                guard fd >= 0 else { continue }
                
                let handle = FileHandle(fileDescriptor: fd, closeOnDealloc: true)
    
                while true {
                    let data = handle.availableData
                    if data.isEmpty { break }
                    
                    print("[NamedPipeReader] Reading data: \(data.count) bytes")
                    
                    if let str = String(data: data, encoding: .utf8) {
                        print("[NamedPipeReader] Received: \(str)")
                        DispatchQueue.main.async {
                            onData(str)
                        }
                    }
                }
                // Writer disconnected, loop to wait for next writer
            }
        }
        
        func stop() {
            self.isRunning = false
            unlink(path)
        }
    }
    
    deinit {
        unlink(path)
    }
}
