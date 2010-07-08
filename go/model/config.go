package model

//
// Config
//

type Config struct {
	ConfigName ConfigName
	Statements  []ConfigStatement
}

func NewConfig(configName ConfigName, stmts ...ConfigStatement) *Config {
	return &Config{configName, stmts}
}

func NewConfigWithStatements(configName ConfigName, stmts []ConfigStatement) *Config {
	return &Config{configName, stmts}
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

func (stmt *ModifierStatement) Accept(handler ConfigStatementHandler) {
	handler.HandleModifier(stmt.Modifier)
}

