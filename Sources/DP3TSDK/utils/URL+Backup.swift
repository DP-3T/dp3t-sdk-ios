/*
 * Created by Ubique Innovation AG
 * https://www.ubique.ch
 * Copyright (c) 2020. All rights reserved.
 */

import Foundation

extension URL {
    /// adds the isExcludedFromBackup Attribute to a fileURL
    /// - Throws: if a error occured while setting the attribute
    mutating func addExcludedFromBackupAttribute() throws {
        var resourceValues = URLResourceValues()
        resourceValues.isExcludedFromBackup = true
        try setResourceValues(resourceValues)
    }
}
