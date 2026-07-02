import Foundation

/// A source language the code viewer can highlight. Detected from a file's
/// extension (with a shebang fallback for extensionless scripts); unknown types
/// fall back to `.plainText`.
enum CodeLanguage: String, CaseIterable {
    case swift, javascript, typescript, json, python, go, rust, shell
    case markdown, yaml, html, css, c, cpp, ruby, java, plainText

    var displayName: String {
        switch self {
        case .javascript: return "JavaScript"
        case .typescript: return "TypeScript"
        case .cpp:        return "C++"
        case .css:        return "CSS"
        case .html:       return "HTML"
        case .json:       return "JSON"
        case .yaml:       return "YAML"
        case .plainText:  return "Plain Text"
        default:          return rawValue.capitalized
        }
    }

    /// Map a filename's extension to a language (pure, testable).
    static func detect(filename: String) -> CodeLanguage {
        let ext = (filename as NSString).pathExtension.lowercased()
        switch ext {
        case "swift":                         return .swift
        case "js", "jsx", "mjs", "cjs":       return .javascript
        case "ts", "tsx":                     return .typescript
        case "json":                          return .json
        case "py", "pyw":                     return .python
        case "go":                            return .go
        case "rs":                            return .rust
        case "sh", "bash", "zsh", "fish":     return .shell
        case "md", "markdown", "mdown":       return .markdown
        case "yml", "yaml":                   return .yaml
        case "html", "htm", "xhtml":          return .html
        case "css", "scss", "less":           return .css
        case "c", "h":                        return .c
        case "cpp", "cc", "cxx", "hpp", "hh": return .cpp
        case "rb":                            return .ruby
        case "java":                          return .java
        default:                              return .plainText
        }
    }

    /// Language from a shebang line (e.g. `#!/usr/bin/env python3`), or nil.
    static func fromShebang(_ firstLine: String) -> CodeLanguage? {
        guard firstLine.hasPrefix("#!") else { return nil }
        let l = firstLine.lowercased()
        if l.contains("python") { return .python }
        if l.contains("bash") || l.contains("/sh") || l.contains("zsh") { return .shell }
        if l.contains("ruby") { return .ruby }
        if l.contains("node") { return .javascript }
        return nil
    }

    /// Detect from a URL, using the extension first and a shebang fallback for
    /// extensionless files when the first line is supplied.
    static func detect(url: URL, firstLine: String? = nil) -> CodeLanguage {
        let byExt = detect(filename: url.lastPathComponent)
        if byExt != .plainText { return byExt }
        if let firstLine, let sb = fromShebang(firstLine) { return sb }
        return .plainText
    }

    // MARK: Tokenizer inputs

    /// Reserved words highlighted as keywords.
    var keywords: Set<String> {
        switch self {
        case .swift:
            return ["func","let","var","if","else","guard","for","while","return","struct",
                    "class","enum","protocol","extension","import","switch","case","default",
                    "self","init","deinit","in","do","try","catch","throw","throws","async",
                    "await","public","private","internal","fileprivate","static","final","weak",
                    "nil","true","false","some","any","where","as","is","break","continue"]
        case .javascript, .typescript:
            return ["function","let","const","var","if","else","for","while","return","class",
                    "extends","import","export","from","switch","case","default","new","this",
                    "async","await","try","catch","throw","typeof","instanceof","null","true",
                    "false","undefined","interface","type","enum","public","private","readonly"]
        case .python:
            return ["def","class","if","elif","else","for","while","return","import","from",
                    "as","try","except","finally","with","lambda","yield","async","await",
                    "None","True","False","and","or","not","in","is","pass","break","continue","raise"]
        case .go:
            return ["func","package","import","var","const","type","struct","interface","map",
                    "chan","go","defer","if","else","for","range","return","switch","case",
                    "default","nil","true","false","break","continue","select"]
        case .rust:
            return ["fn","let","mut","const","struct","enum","impl","trait","use","pub","mod",
                    "if","else","match","for","while","loop","return","self","Self","true",
                    "false","async","await","move","ref","where","as","dyn","break","continue"]
        case .shell:
            return ["if","then","else","elif","fi","for","while","do","done","case","esac",
                    "function","return","in","export","local","echo","cd","source"]
        case .c, .cpp:
            return ["int","char","float","double","void","if","else","for","while","return",
                    "struct","class","enum","union","const","static","typedef","sizeof","switch",
                    "case","default","break","continue","namespace","template","public","private",
                    "protected","new","delete","nullptr","true","false","auto","using"]
        case .ruby:
            return ["def","class","module","if","elsif","else","end","for","while","do","return",
                    "require","yield","begin","rescue","ensure","nil","true","false","self","then"]
        case .java:
            return ["public","private","protected","class","interface","extends","implements",
                    "import","package","void","int","boolean","if","else","for","while","return",
                    "new","this","static","final","try","catch","throw","throws","null","true","false"]
        default:
            return []
        }
    }

    /// Line-comment prefix, if any.
    var lineComment: String? {
        switch self {
        case .python, .ruby, .shell, .yaml:                 return "#"
        case .swift, .javascript, .typescript, .go, .rust,
             .c, .cpp, .java, .css:                         return "//"
        default:                                            return nil
        }
    }

    /// Whether `/* … */` block comments apply.
    var hasBlockComments: Bool {
        switch self {
        case .swift, .javascript, .typescript, .go, .rust, .c, .cpp, .java, .css: return true
        default: return false
        }
    }
}
