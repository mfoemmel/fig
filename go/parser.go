package fig

import "fmt"
//import "io"

type Parser struct {
	source string
	buf    []byte
	c      int
	start  int
	pos    int
	line   int
	col    int
}

const EOF = -1

func NewParser(source string, buf []byte) *Parser {
	parser := &Parser{
		source: source,
		buf:    buf,
		c:      0,
		start:  0,
		pos:    -1,
		line:   1,
		col:    1,
	}
	parser.next()
	return parser
}

const packageKeywordError = `invalid keyword, expected "resource", "archive", or "config"`
const configKeywordError = `invalid keyword, expected "set", "path", or "include"`

func (p *Parser) isKeywordChar() bool {
	switch {
	case p.c >= 'a' && p.c <= 'z':
		return true
	case p.c >= 'A' && p.c <= 'Z':
		return true
	case p.c >= '0' && p.c <= '9':
		return true
	}
	return false
}

const packageNameError = "invalid character in package name, expected [a-z A-Z 0-9 .]"

func (s *Parser) isPackageNameChar() bool {
	return (s.c >= 'a' && s.c <= 'z') ||
		(s.c >= 'A' && s.c <= 'Z') ||
		(s.c >= '0' && s.c <= '9') ||
		s.c == '.'
}

func isVersionNamePrefix(c byte) bool {
	return c == '/'
}

const versionNameError = "invalid character in version name, expected [a-z A-Z 0-9 .]"

func (s *Parser) isVersionNameChar() bool {
	return (s.c >= 'a' && s.c <= 'z') ||
		(s.c >= 'A' && s.c <= 'Z') ||
		(s.c >= '0' && s.c <= '9') ||
		s.c == '.'
}

const configNameError = "invalid character in config name, expected [a-z A-Z 0-9 .]"

func (s *Parser) isConfigNameChar() bool {
	return (s.c >= 'a' && s.c <= 'z') ||
		(s.c >= 'A' && s.c <= 'Z') ||
		(s.c >= '0' && s.c <= '9') ||
		s.c == '.'
}


const nameValueWhitespaceError = "whitespace not allowed around '='"

const variableNameError = "invalid character in variable name, expected [a-z A-Z 0-9]"

func (s *Parser) isVariableNameChar() bool {
	c := s.c
	return (c >= 'a' && c <= 'z') ||
		(c >= 'A' && c <= 'Z') ||
		(c >= '0' && c <= '9')
}

const variableValueError = "invalid character in variable value, expected [a-z A-Z 0-9 . /]"

func (s *Parser) isVariableValueChar() bool {
	return (s.c >= 'a' && s.c <= 'z') ||
		(s.c >= 'A' && s.c <= 'Z') ||
		(s.c >= '0' && s.c <= '9') ||
		s.c == '/' || 
		s.c == '.' || 
		s.c == '@' // TODO need to convert legacy paths properly
}

const pathError = "invalid character in path, expected [a-z A-Z 0-9 . /]"

func (p *Parser) isPathChar() bool {
	return (p.c >= 'a' && p.c <= 'z') ||
		(p.c >= 'A' && p.c <= 'Z') ||
		(p.c >= '0' && p.c <= '9') ||
		(p.c == '.') || 
		(p.c == '/') ||
		(p.c == '"') // TODO should parse strings correctly
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

func (p *Parser) ParsePackage() (*Package, *Error) {
	stmts := make([]PackageStatement, 0, 32)
	for {
		p.skipWhitespace()
		stmt, err := p.ParsePackageStatement()
		if err != nil {
			return nil, err
		}
		if stmt == nil {
			break
		}
		l := len(stmts)
		stmts = stmts[0:l+1]
		stmts[l] = stmt
	}
	return NewPackage("test", "1.2.3", stmts), nil
}

func (p *Parser) ParsePackageStatement() (PackageStatement, *Error) {
	p.skipWhitespace()
	if p.c == EOF {
		return nil, nil
	}
	keyword, err := p.keyword()
	if err != nil {
		return nil, err
	}
	switch keyword.text {
	case "resource":
		path, err := p.path()
		if err != nil {
			return nil, err
		}
		return &ResourceStatement{path}, nil
	case "archive":
		path, err := p.path()
		if err != nil {
			return nil, err
		}
		return &ArchiveStatement{path}, nil
	case "config":
		name, err := p.configName()
		if err != nil {
			return nil, err
		}
		stmts, err := p.ParseConfigStatements()
		if err != nil {
			return nil, err
		}
		return &ConfigBlock{NewConfig(ConfigName(name), stmts)}, nil
	}
	return nil, p.tokenError(keyword, packageKeywordError)
}

func (p *Parser) ParseConfigStatements() ([]ConfigStatement, *Error) {
	stmts := make([]ConfigStatement, 0, 32)
	for {
		p.skipWhitespace()
		stmt, err := p.ParseConfigStatement()
		if err != nil {
			return nil, err
		}
		if stmt == nil {
			break
		}
		l := len(stmts)
		stmts = stmts[0:l+1]
		stmts[l] = stmt
	}
	return stmts, nil
}

func (s *Parser) ParseConfigStatement() (ConfigStatement, *Error) {
	keyword, err := s.keyword()
	if err != nil {
		return nil, err
	}

	switch keyword.text {
	case "end":
		return nil, nil
	case "set":
		name, value, err := s.nameValue()
		if err != nil {
			return nil, err
		}
		return NewModifierStatement(NewSetModifier(name, value)), nil
	case "path", "append":
		name, value, err := s.nameValue()
		if err != nil {
			return nil, err
		}
		return NewModifierStatement(NewPathModifier(name, value)), nil
	case "include":
		descriptor, err := s.descriptor()
		if err != nil {
			return nil, err
		}
		return NewModifierStatement(NewIncludeModifier(descriptor)), nil
	}

	s.start -= len(keyword.text)
	return nil, s.tokenError(keyword, configKeywordError)
}

func (s *Parser) configName() (string, *Error) {
	s.skipWhitespace()
	if !s.isConfigNameChar() {
		return "", s.charError(configNameError)
	}
	s.next()
	for s.isConfigNameChar() {
		s.next()
	}
	return s.token().text, nil
}

func (p *Parser) keyword() (*token, *Error) {
	if p.isKeywordChar() {
		p.next()
		for p.isKeywordChar() {
			p.next()
		}
		return p.token(), nil
	}
	return nil, p.charError("expected keyword")
}

func (s *Parser) nameValue() (string, string, *Error) {
	name, ok := s.variableName()
	if !ok || s.c != '=' {
		if s.c != -1 && isWhitespace(byte(s.c)) {
			return "", "", s.charError(nameValueWhitespaceError)
		} else {
			return "", "", s.charError(variableNameError)
		}
	}
	s.skip()
	value, ok := s.variableValue()
	if !ok {
		if s.c != -1 && isWhitespace(byte(s.c)) {
			return "", "", s.charError(nameValueWhitespaceError)
		} else {
			return "", "", s.charError(variableValueError)
		}
	}
	if s.c != -1 && !isWhitespace(byte(s.c)) {
		return "", "", s.charError(variableValueError)
	}
	return name, value, nil
}


func (s *Parser) variableName() (string, bool) {
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

func (s *Parser) variableValue() (string, bool) {
	if !s.isVariableValueChar() {
		return "", false
	}
	s.next()
	for s.isVariableValueChar() {
		s.next()
	}
	return s.token().text, true
}

func (s *Parser) descriptor() (Descriptor, *Error) {
	s.skipWhitespace()

	packageName := ""
	versionName := ""
	configName := ""

	for s.isPackageNameChar() {
		s.next()
	}
	packageName = s.token().text

	message := packageNameError

	if s.c == '/' {
		s.skip()
		if !s.isVersionNameChar() {
			return Descriptor{}, s.charError(versionNameError)
		}
		for s.isVersionNameChar() {
			s.next()
		}
		versionName = s.token().text
		message = versionNameError
	}

	if s.c == ':' {
		s.skip()
		for s.isConfigNameChar() {
			s.next()
		}
		configName = s.token().text
		message = configNameError
	}

	if s.c != -1 && !isWhitespace(byte(s.c)) {
		return Descriptor{}, s.charError(message)
	}

	return NewDescriptor(packageName, versionName, configName), nil
}

func (p *Parser) path() (string, *Error) {
	p.skipWhitespace()
	if !p.isPathChar() {
		return "", p.charError(pathError)
	}
	p.next()
	for p.isPathChar() {
		p.next()
	}
	if p.c != EOF && !isWhitespace(byte(p.c)) {
		return "", p.charError(pathError)
	}
	return p.token().text, nil
}

func (s *Parser) next() {
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

func (s *Parser) skip() {
	if s.pos != s.start {
		panic("can only skip at start of token")
	}
	s.next()
	s.start++
}

func (s *Parser) skipWhitespace() {
	for s.c != -1 && isWhitespace(byte(s.c)) {
		s.skip()
	}
}

func (s *Parser) token() *token {
	lineStart := s.lineStart()
	lineEnd := s.lineEnd()

	t := string(s.buf[s.start:s.pos])
	col := s.start - lineStart + 1
	s.start = s.pos	
	return &token{t, s.line, col, len(t), string(s.buf[lineStart:lineEnd])}
}

func (p *Parser) lineStart() int {
	lineStart := p.start
	for lineStart > 0 && p.buf[lineStart-1] != '\n' {
		lineStart--
	}
	return lineStart
}

func (p *Parser) lineEnd() int {
	lineEnd := p.pos
	for lineEnd < len(p.buf) && p.buf[lineEnd] != '\n' {
		lineEnd++
	}
	return lineEnd
}

type Error struct {
	source   string
	row      int
	col      int
	length   int
	message  string
	line     string
}

func (s *Parser) error(msg string, token bool) *Error {
	lineStart := s.lineStart()
	lineEnd := s.lineEnd()

	return &Error{s.source, s.line, s.start, s.col-s.start, msg, string(s.buf[lineStart:lineEnd])}
}

func (s *Parser) tokenError(t *token, msg string) *Error {
	return &Error{s.source, t.row, t.col, t.length, msg, t.line}
}

func (s *Parser) charError(msg string) *Error {
	if s.c == -1 {
		return s.error("unexpected end-of-file", false)
	} 
	s.next()

	s.start = s.pos - 1
	return s.tokenError(s.token(), msg)
}

func (err *Error) String() string {
	if err == nil {
		return "err == nil"
	}

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

	return fmt.Sprintf("%s:%d:%d: %s\n  %s\n  %s\n",
		err.source, err.row, err.col, err.message,
		err.line[pos:],
		carets)
}

func (s *Parser) fail(msg string, token bool) {
	panic(s.error(msg, token).String())
}
