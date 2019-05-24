/*
See LICENSE folder for this sample’s licensing information.

Abstract:
Utilities for dealing with recognized strings
*/

import Foundation

extension Character {
	// Given a list of allowed characters, try to convert self to those in list
	// if not already in it. This handles some common misclassifications for
	// characters that are visually similar and can only be correctly recognized
	// with more context and/or domain knowledge. Some examples (should be read
	// in Menlo or some other font that has different symbols for all characters):
	// 1 and l are the same character in Times New Roman
	// I and l are the same character in Helvetica
	// 0 and O are extremely similar in many fonts
	// oO, wW, cC, sS, pP and others only differ by size in many fonts
	func getSimilarCharacterIfNotIn(allowedChars: String) -> Character {
		let conversionTable = [
			"s": "S",
			"S": "5",
			"5": "S",
			"o": "O",
			"Q": "O",
			"O": "0",
			"0": "O",
			"l": "I",
			"I": "1",
			"1": "I",
			"B": "8",
			"8": "B"
		]
		// Allow a maximum of two substitutions to handle 's' -> 'S' -> '5'.
		let maxSubstitutions = 2
		var current = String(self)
		var counter = 0
		while !allowedChars.contains(current) && counter < maxSubstitutions {
			if let altChar = conversionTable[current] {
				current = altChar
				counter += 1
			} else {
				// Doesn't match anything in our table. Give up.
				break
			}
		}
		
		return current.first!
	}
}

extension String {
	// Extracts the first US-style phone number found in the string, returning
	// the range of the number and the number itself as a tuple.
	// Returns nil if no number is found.
	func extractPhoneNumber() -> (Range<String.Index>, String)? {
		// Do a first pass to find any substring that could be a US phone
		// number. This will match the following common patterns and more:
		// xxx-xxx-xxxx
		// xxx xxx xxxx
		// (xxx) xxx-xxxx
		// (xxx)xxx-xxxx
		// xxx.xxx.xxxx
		// xxx xxx-xxxx
		// xxx/xxx.xxxx
		// +1-xxx-xxx-xxxx
		// Note that this doesn't only look for digits since some digits look
		// very similar to letters. This is handled later.
		let pattern = #"""
		(?x)					# Verbose regex, allows comments
		(?:\+1-?)?				# Potential international prefix, may have -
		[(]?					# Potential opening (
		\b(\w{3})				# Capture xxx
		[)]?					# Potential closing )
		[\ -./]?				# Potential separator
		(\w{3})					# Capture xxx
		[\ -./]?				# Potential separator
		(\w{4})\b				# Capture xxxx
		"""#
		
		guard let range = self.range(of: pattern, options: .regularExpression, range: nil, locale: nil) else {
			// No phone number found.
			return nil
		}
		
		// Potential number found. Strip out punctuation, whitespace and country
		// prefix.
		var phoneNumberDigits = ""
		let substring = String(self[range])
		let nsrange = NSRange(substring.startIndex..., in: substring)
		do {
			// Extract the characters from the substring.
			let regex = try NSRegularExpression(pattern: pattern, options: [])
			if let match = regex.firstMatch(in: substring, options: [], range: nsrange) {
				for rangeInd in 1 ..< match.numberOfRanges {
					let range = match.range(at: rangeInd)
					let matchString = (substring as NSString).substring(with: range)
					phoneNumberDigits += matchString as String
				}
			}
		} catch {
			print("Error \(error) when creating pattern")
		}
		
		// Must be exactly 10 digits.
		guard phoneNumberDigits.count == 10 else {
			return nil
		}
		
		// Substitute commonly misrecognized characters, for example: 'S' -> '5' or 'l' -> '1'
		var result = ""
		let allowedChars = "0123456789"
		for var char in phoneNumberDigits {
			char = char.getSimilarCharacterIfNotIn(allowedChars: allowedChars)
			guard allowedChars.contains(char) else {
				return nil
			}
			result.append(char)
		}
		return (range, result)
	}
}

class StringTracker {
	var frameIndex: Int64 = 0

	typealias StringObservation = (lastSeen: Int64, count: Int64)
	
	// Dictionary of seen strings. Used to get stable recognition before
	// displaying anything.
	var seenStrings = [String: StringObservation]()
	var bestCount = Int64(0)
	var bestString = ""

	func logFrame(strings: [String]) {
		for string in strings {
			if seenStrings[string] == nil {
				seenStrings[string] = (lastSeen: Int64(0), count: Int64(-1))
			}
			seenStrings[string]?.lastSeen = frameIndex
			seenStrings[string]?.count += 1
			print("Seen \(string) \(seenStrings[string]?.count ?? 0) times")
		}
	
		var obsoleteStrings = [String]()

		// Go through strings and prune any that have not been seen in while.
		// Also find the (non-pruned) string with the greatest count.
		for (string, obs) in seenStrings {
			// Remove previously seen text after 30 frames (~1s).
			if obs.lastSeen < frameIndex - 30 {
				obsoleteStrings.append(string)
			}
			
			// Find the string with the greatest count.
			let count = obs.count
			if !obsoleteStrings.contains(string) && count > bestCount {
				bestCount = Int64(count)
				bestString = string
			}
		}
		// Remove old strings.
		for string in obsoleteStrings {
			seenStrings.removeValue(forKey: string)
		}
		
		frameIndex += 1
	}
	
	func getStableString() -> String? {
		// Require the recognizer to see the same string at least 10 times.
		if bestCount >= 10 {
			return bestString
		} else {
			return nil
		}
	}
	
	func reset(string: String) {
		seenStrings.removeValue(forKey: string)
		bestCount = 0
		bestString = ""
	}
}
