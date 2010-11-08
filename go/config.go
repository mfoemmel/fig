package fig

import "fmt"
import "container/vector"

//
// Config
//

type Config struct {
	ConfigName ConfigName
	Statements []ConfigStatement
}

func NewConfig(configName ConfigName, stmts []ConfigStatement) *Config {
	return &Config{configName, stmts}
}

func (config *Config) FindIncludeDescriptors() []Descriptor {
	vec := &vector.Vector{}
	for _, stmt := range config.Statements {
		if modstmt, ok := stmt.(*ModifierStatement); ok {
			if include, ok := modstmt.Modifier.(*IncludeModifier); ok {
				desc := include.Descriptor()
				vec.Push(desc)
			}
		}
	}
	descs := make([]Descriptor, vec.Len())
	for i, _ := range descs {
		descs[i] = vec.At(i).(Descriptor)
	}
	return descs
}
//
// ConfigStatement
//

type ConfigStatement interface {
	Accept(handler ConfigStatementHandler)
}

type ConfigStatementHandler interface {
	HandleModifier(modifier Modifier)
}

type ModifierStatement struct {
	Modifier Modifier
}

func NewModifierStatement(modifier Modifier) *ModifierStatement {
	return &ModifierStatement{modifier}
}

func NewIncludeStatement(desc Descriptor) *ModifierStatement {
	return &ModifierStatement{NewIncludeModifier(desc)}
}

func NewSetStatement(name string, value string) *ModifierStatement {
	return &ModifierStatement{NewSetModifier(name, value)}
}

func NewPathStatement(name string, value string) *ModifierStatement {
	return &ModifierStatement{NewPathModifier(name, value)}
}

func (stmt *ModifierStatement) Accept(handler ConfigStatementHandler) {
	handler.HandleModifier(stmt.Modifier)
}

// Testing

func CompareConfig(expected *Config, actual *Config) (bool, string) {
	// todo compare name?
	return CompareConfigStatements(expected.Statements, actual.Statements)
}


func CompareConfigStatements(expected []ConfigStatement, actual []ConfigStatement) (bool, string) {
	if len(expected) != len(actual) {
		return false, fmt.Sprintf("Expected %d modifier, got %d", len(expected), len(actual))
	}
	for i, _ := range expected {
		if ok, msg := CompareConfigStatement(expected[i], actual[i]); !ok {
			return ok, msg
		}
	}
	return true, ""
}

func CompareConfigStatement(expected ConfigStatement, actual ConfigStatement) (bool, string) {
	return CompareModifier(expected.(*ModifierStatement).Modifier, actual.(*ModifierStatement).Modifier)
}
