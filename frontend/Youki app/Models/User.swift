//
//  User.swift
//  Youki app
//
//  Created by Kazuki Kagoshima on 2025/12/30.
//
import Foundation

struct User {
    let id: UUID
    let email: String
    let isPro: Bool
    let preferences: UserPreferences
}

struct UserPreferences {
    let default_location: Coordinate?
}
