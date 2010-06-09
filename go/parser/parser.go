package parser

import "fmt"
//import "io"

import . "fig/model"

type Scanner struct {
	source string
	buf []byte
	state state
	start int
	pos   int
	line  int
	col   int
	modifiers []Modifier

	packageName string
	versionName string
	configName  string
}

type state int

const (
	stateStart = state(iota)
	stateKeyword = state(iota)
	stateDescriptor = state(iota)
	statePackageName = state(iota)
	stateVersionName = state(iota)
	stateConfigName = state(iota)
)

func (s state) String() string {
	switch s {
	case stateStart:
		return "<start>"		
	case stateKeyword:
		return "keyword"		
	case stateDescriptor:
		return "descriptor"
	case statePackageName:
		return "package name"
	case stateVersionName:
		return "version name"
	}
	return "<unknown>"
}

func NewScanner(source string, buf []byte) *Scanner {
	return &Scanner{source, buf, stateStart, 0, 0, 1, 1, make([]Modifier, 0, 10), "", "", ""}
}

func isKeywordChar(c byte) bool {
	return c >= 'a' && c <= 'z'
}

func isPackageNameChar(c byte) bool {
	return c >= 'a' && c <= 'z'
}

func isVersionNamePrefix(c byte) bool {
	return c == '/'
}

const versionNameError = "'%c' not allowed in version name, expected [a-z A-Z 0-9 .]"
func isVersionNameChar(c byte) bool {
	switch {
	case c >= 'a' && c <= 'z':
		return true
	case c >= 'A' && c <= 'Z':
		return true
	case c >= '0' && c <= '9':
		return true
	case c == '.':
		return true
	}
	return false
}

const configNameError = "'%c' not allowed in config name, expected [a-z A-Z 0-9 .]"
func isConfigNameChar(c byte) bool {
	switch {
	case c >= 'a' && c <= 'z':
		return true
	case c >= 'A' && c <= 'Z':
		return true
	case c >= '0' && c <= '9':
		return true
	case c == '.':
		return true
	}
	return false
}

func isConfigNamePrefix(c byte) bool {
	return c == ':'
}

func isWhitespace(c byte) bool {
	return c == ' ' || c == '\n' || c == '\t' || c == '\r'
}


func (s *Scanner) Parse() []Modifier {
	for s.pos != len(s.buf) {
		c := s.buf[s.pos]
		if c == '\n' {
			s.line++
			s.col = 0
		} else {
			s.col++
		}
		s.pos++
		switch s.state {
		case stateStart:
			switch {
			case isKeywordChar(c):
				s.state = stateKeyword
			case isWhitespace(c):
				s.ignore()
			default:
				s.fail("Unexpected character")
			}

		case stateKeyword:
			switch {
			case isKeywordChar(c):
				// ok
			case isWhitespace(c):
				s.pos--
				s.endKeyword()
			default: 
				s.fail("Unexpected character")
			}
			
		case stateDescriptor:
			switch {
			case isWhitespace(c):
				s.ignore()
			case isPackageNameChar(c):
				s.state = statePackageName
			default:
				s.fail("Unexpected character")
			}

		case statePackageName:
			switch {
			case isPackageNameChar(c):
				// continue
			case isVersionNamePrefix(c):
				s.endPackageName()
				s.state = stateVersionName
			default:
				s.fail("Unexpected character")
			}

		case stateVersionName:
			switch {
			case isVersionNameChar(c):
				// continue
			case isConfigNamePrefix(c):
				s.endVersionName()
				s.state = stateConfigName
			default:
				s.fail(fmt.Sprintf(versionNameError, c))
			}

		case stateConfigName:
			switch {
			case isConfigNameChar(c):
				// continue
			case isWhitespace(c):
				s.endConfigName()
				s.state = stateStart
			}
		default:
			panic("Unreachable")
		}
	}

	s.pos++

	switch s.state {
	case stateStart:
		s.fail("Nothing to parse")
	case stateKeyword:
		s.endKeyword()
	case stateConfigName:
		s.endConfigName()
//		s.endDescriptor()
		s.endInclude()
	default:
		s.fail("Unexpected EOF")
	}
	
	return s.modifiers
}

func (s *Scanner) endKeyword() {
	switch s.token() {
	case "include":
		s.start = s.pos
		s.state = stateDescriptor
	default:
		s.fail("Unknown keyword")
	}
}

func (s *Scanner) endPackageName() {
	s.packageName = string(s.buf[s.start:s.pos-1])
	s.start = s.pos
}

func (s *Scanner) endVersionName() {
	s.versionName = string(s.buf[s.start:s.pos-1])
	s.start = s.pos
}

func (s *Scanner) endConfigName() {
	s.configName = string(s.buf[s.start:s.pos-1])
	s.start = s.pos
}

func (s *Scanner) endInclude() {
	l := len(s.modifiers)
	s.modifiers = s.modifiers[0:l+1]
	s.modifiers[l] = NewIncludeModifier(PackageName(s.packageName), VersionName(s.versionName), ConfigName(s.configName))
	s.packageName = ""
	s.versionName = ""
	s.configName = ""
}

func (s *Scanner) ignore() {
	if s.start != s.pos - 1 {
		panic("Can't skip characters in the middle of a token")
	}
	s.start++
}

func (s *Scanner) token() string {
	return string(s.buf[s.start:s.pos])
}

type Location struct {
	source string
	line   int
	col    int
	msg    string
	state  state
	
}

func (s *Scanner) fail(msg string) {
	lineEnd := s.pos
	for lineEnd < len(s.buf) && s.buf[lineEnd] != '\n' {
		lineEnd++
	}

	lineStart := s.start
	for lineStart > 0 && s.buf[lineStart-1] != '\n' {
		lineStart--
	}	
	for isWhitespace(s.buf[lineStart]) && lineStart < lineEnd {
		lineStart++
	}

	carets := ""
	for i := lineStart; i < lineEnd; i++ {
		if i >= s.start && i < s.pos - 1 {
			carets += "-"
		} else if i == s.pos - 1 {
			carets += "^"
		} else {
			carets += " "
		}
	}
	panic(fmt.Sprintf("%s:%d:%d: %s:\n  %s\n  %s\n", s.source, s.line, s.col, msg, s.buf[lineStart:lineEnd], carets))
}

