//
//  RequestPath+ASC.swift
//  asc
//
//  Created by Dominic Rodemer on 21/10/2026.
//  Copyright © 2026 Dominic Rodemer. All rights reserved.
//

import AppleCLIKit
import Foundation

extension RequestPath {
    /// A path on the App Store Connect API.
    init(_ raw: String) throws {
        try self.init(raw, host: APIClient.host)
    }
}
