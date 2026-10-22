//
//  Request.swift
//  WarpNet
//

import Foundation
import Warp

enum Request {
    // One request sent and its response as the `Net.Response` struct.
    static func send<P: NativeProcedure>(_ invocation: Invocation<P>, method: String, url urlKey: P.Parameters, headers headersKey: P.Parameters, body: String?) async throws -> Value {
        guard case let .string(text) = invocation[urlKey] else {
            throw ExecutionError("'\(invocation.selector)' takes a url as text, and \(invocation[urlKey].nominal) arrived")
        }

        guard let url = URL(string: text), url.scheme != nil else {
            throw NetFailed("'\(text)' is not a url", url: text)
        }

        var request = URLRequest(url: url)
        request.httpMethod = method

        // Headers left out arrive as null, which sends none.
        if case let .dictionary(headers) = invocation[headersKey] {
            for entry in headers.entries {
                guard case let .string(name) = entry.key, case let .string(value) = entry.value else { continue }

                request.setValue(value, forHTTPHeaderField: name)
            }
        }

        if let body {
            request.httpBody = Data(body.utf8)
        }

        let data: Data
        let response: URLResponse

        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw NetFailed("'\(text)' answered nothing: \(error.localizedDescription)", url: text)
        }

        guard let http = response as? HTTPURLResponse else {
            throw NetFailed("'\(text)' answered something other than HTTP", url: text)
        }

        // A header's name is read whatever its case, so it is keyed lowercased.
        var headers: [String: Value] = [:]

        for (key, value) in http.allHeaderFields {
            guard let key = key as? String, let value = value as? String else { continue }

            headers[key.lowercased()] = .string(value)
        }

        return try Value.holding([
            (name: "body", value: .string(String(decoding: data, as: UTF8.self))),
            (name: "headers", value: .dictionary(try Value.Dictionary(headers.map { header in (key: .string(header.key), value: header.value) }))),
            (name: "status", value: .int(http.statusCode))
        ], named: "Net.Response")
    }
}
