package parser

import "fmt"
//import "io"

import . "fig/model"

type Scanner struct {
	source string
	buf    []byte
	c      int
	start  int
	pos    int
	line   int
	col    int
}

const EOF = -1

func NewScanner(source string, buf []byte) *Scanner {
	return &Scanner{
		source: source,
		buf:    buf,
		c:      0,
		start:  0,
		pos:    0,
		line:   1,
		col:    1,
	}
}

const keywordError = "Not a valid keyword (expected \"set\" or \"include\")"

func isKeywordChar(c byte) bool {
	switch {
	case c >= 'a' && c <= 'z':
		return true
	case c >= 'A' && c <= 'Z':
		return true
	case c >= '0' && c <= '9':
		return true
	}
	return false
}

const packageNameError = "'%c' not allowed in package name, expected [a-z A-Z 0-9 .]"

func (s *Scanner) isPackageNameChar() bool {
	return (s.c >= 'a' && s.c <= 'z') ||
		(s.c >= 'A' && s.c <= 'Z') ||
		(s.c >= '0' && s.c <= '9') ||
		s.c == '.'
}

func isVersionNamePrefix(c byte) bool {
	return c == '/'
}

const versionNameError = "'%c' not allowed in version name, expected [a-z A-Z 0-9 .]"

func (s *Scanner) isVersionNameChar() bool {
	return (s.c >= 'a' && s.c <= 'z') ||
		(s.c >= 'A' && s.c <= 'Z') ||
		(s.c >= '0' && s.c <= '9') ||
		s.c == '.'
}

const configNameError = "'%c' not allowed in config name, expected [a-z A-Z 0-9 .]"

func (s *Scanner) isConfigNameChar() bool {
	return (s.c >= 'a' && s.c <= 'z') ||
		(s.c >= 'A' && s.c <= 'Z') ||
		(s.c >= '0' && s.c <= '9') ||
		s.c == '.'
}


const variableNameError = "'%c' not allowed in variable name, expected [a-z A-Z 0-9]"

func (s *Scanner) isVariableNameChar() bool {
	c := s.c
	return (c >= 'a' && c <= 'z') ||
		(c >= 'A' && c <= 'Z') ||
		(c >= '0' && c <= '9')
}

const variableValueError = "'%c' not allowed in variable value, expected [a-z A-Z 0-9]"

func isVariableValueChar(c int) bool {
	return (c >= 'a' && c <= 'z') ||
		(c >= 'A' && c <= 'Z') ||
		(c >= '0' && c <= '9')
}


func isConfigNamePrefix(c byte) bool {
	return c == ':'
}

func isWhitespace(c byte) bool {
	return c == ' ' || c == '\n' || c == '\t' || c == '\r'
}

type token struct {
	text     string
	row      int
	col      int
	length   int
	line     string
}

func (s *Scanner) Parse() ([]Modifier, *Error) {
	s.pos = -1
	s.next()
	s.skipWhitespace()
	modifiers := make([]Modifier, 1)
	keyword, match := s.keyword()
	if match {
		switch keyword.text {
		case "set":
			name, value, match := s.nameValue()
			if !match {
				panic("Mismatch a")
			}
			modifiers[0] = NewSetModifier(name, value)
		case "include":
			descriptor, match := s.descriptor()
			if !match {
				panic("Mismatch b")
			}
			modifiers[0] = NewIncludeModifier(
				descriptor.PackageName,
				descriptor.VersionName,
				descriptor.ConfigName)
		default:
			s.start -= len(keyword.text)
			return nil, s.tokenError(keyword, keywordError)
		}
	}
	return modifiers, nil
}

func (s *Scanner) keyword() (*token, bool) {
	if isKeywordChar(s.buf[s.pos]) {
		for isKeywordChar(s.buf[s.pos]) {
			s.next()
		}
		return s.token(), true
	}
	return nil, false
}

func (s *Scanner) nameValue() (string, string, bool) {
	name, ok := s.variableName()
	if !ok || s.c != '=' {
		panic("Mismatch =")
	}
	s.skip()
	value, ok := s.variableValue()
	if !ok {
		panic("Mismatch =2")
	}
	return name, value, true
}

func (s *Scanner) descriptor() (*Descriptor, bool) {
	s.skipWhitespace()

	packageName := ""
	versionName := ""
	configName := ""

	for s.isPackageNameChar() {
		s.next()
	}
	packageName = s.token().text

	if s.c == '/' {
		s.skip()
		for s.isVersionNameChar() {
			s.next()
		}
		versionName = s.token().text
	}

	if s.c == ':' {
		s.skip()
		for s.isConfigNameChar() {
			s.next()
		}
		configName = s.token().text
	}

	return NewDescriptor(packageName, versionName, configName), true
}

func (s *Scanner) variableName() (string, bool) {
	s.skipWhitespace()
	if !s.isVariableNameChar() {
		return "", false
	}
	s.next()
	for s.isVariableNameChar() {
		s.next()
	}
	return s.token().text, true
}

func (s *Scanner) variableValue() (string, bool) {
	if !isVariableValueChar(s.c) {
		panic(fmt.Sprintf("Mismatch value: %c", s.c))
	}
	s.next()
	for isVariableValueChar(s.c) {
		s.next()
	}
	return s.token().text, true
}

func (s *Scanner) next() {
	s.pos++

	if s.pos < len(s.buf) {
		s.c = int(s.buf[s.pos])
		if s.c == '\n' {
			s.line++
			s.col = 0
		} else {
			s.col++
		}
	} else {
		s.c = EOF
	}
}

func (s *Scanner) skip() {
	if s.pos != s.start {
		panic("can only skip at start of token")
	}
	s.next()
	s.start++
}

func (s *Scanner) skipWhitespace() {
	for s.c != -1 && isWhitespace(byte(s.c)) {
		s.skip()
	}
}

func (s *Scanner) token() *token {

	// Find start of line
	lineStart := s.start
	for lineStart > 0 && s.buf[lineStart-1] != '\n' {
		lineStart--
	}

	// Find end of line
	lineEnd := s.pos
	for lineEnd < len(s.buf) && s.buf[lineEnd] != '\n' {
		lineEnd++
	}

	t := string(s.buf[s.start:s.pos])
	col := s.start - lineStart + 1
	s.start = s.pos	
	return &token{t, s.line, col, len(t), string(s.buf[lineStart:lineEnd])}
}


type Error struct {
	source   string
	row      int
	col      int
	length   int
	message  string
	line     string
}

func (s *Scanner) error(msg string, token bool) *Error {

	// Find start of line
	lineStart := s.start
	for lineStart > 0 && s.buf[lineStart-1] != '\n' {
		lineStart--
	}

	// Find end of line
	lineEnd := s.pos
	for lineEnd < len(s.buf) && s.buf[lineEnd] != '\n' {
		lineEnd++
	}

	return &Error{s.source, s.line, s.start, s.col, msg, string(s.buf[lineStart:lineEnd])}
}

func (s *Scanner) tokenError(t *token, msg string) *Error {
	return &Error{s.source, t.row, t.col, t.length, msg, t.line}
}

func (err *Error) String() string {

	// Strip any leading whitespace on the line
	pos := 0
	for pos < len(err.line) && isWhitespace(err.line[pos]) {
		pos++
	}

	// Place carets underneath error
	carets := ""
	for i := pos + 1; i < err.col; i++ {
		carets += " "
	}
	for i := 0; i < err.length; i++ {
		carets += "^"
	}

	return fmt.Sprintf("%s:%d:%d-%d: %s\n  %s\n  %s\n",
		err.source, err.row, err.col, err.length, err.message,
		err.line[pos:],
		carets)
}

func (s *Scanner) fail(msg string, token bool) {
	panic(s.error(msg, token).String())
}
