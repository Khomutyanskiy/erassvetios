//
//  ContentModerationService.swift
//  erassvet
//

import Foundation

/// A lightweight, client-side keyword filter for objectionable content —
/// checked before an ad, blog post, comment, or chat message is submitted
/// (see PostAdView, CreateBlogPostView, BlogCommentsViewModel, ChatsViewModel).
/// This is the "method for filtering objectionable material" required by
/// App Store Review Guideline 1.2; it's a first line of defense, backed up
/// by the user-report queue (`ReportService`/`AdminReportsView`) for anything
/// it misses.
enum ContentModerationService {
    /// Deliberately coarse — profanity and clearly abusive/hateful terms
    /// (Russian + a few English ones), matched case-insensitively against
    /// word-ish boundaries. Not meant to be exhaustive; the report queue
    /// backstops whatever slips through.
    private static let bannedSubstrings: [String] = [
        "хуй", "хуе", "хуё", "пизд", "ебат", "ебал", "ёбан", "еблан", "заеб",
        "сука бляд", "бляд", "мудак", "мудил", "гандон", "долбоеб", "долбоёб",
        "уебок", "уёбок", "пидор", "пидар", "педик", "чмо", "тварь конч",
        "ниггер", "негр умри", "убей себя", "сдохни",
        "fuck", "bitch", "nigger", "faggot", "retard", "cunt"
    ]

    /// Returns a user-facing error message if `text` should be blocked, or
    /// `nil` if it's fine to submit.
    static func violationMessage(for text: String) -> String? {
        let normalized = text.lowercased()
        for word in bannedSubstrings where normalized.contains(word) {
            return "Текст содержит недопустимые слова или оскорбления. Отредактируйте сообщение перед публикацией."
        }
        return nil
    }

    static func isAllowed(_ text: String) -> Bool { violationMessage(for: text) == nil }
}
