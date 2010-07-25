package plan

import "os"

import . "fig/model"
import . "fig/repos"

type VersionMismatchError struct {
        message    string
        backtrace1 *Backtrace
        backtrace2 *Backtrace
}

type Planner struct {
	repo Repository
	results []Descriptor
}

func NewPlanner(repo Repository) *Planner {
	return &Planner{repo,make([]Descriptor, 0, 10)}
}

func (p *Planner) Plan(desc Descriptor) ([]Descriptor, os.Error) {
	pkg := ReadPackage(p.repo, desc.PackageName, desc.VersionName)
	config := findConfig(pkg.Statements, desc.ConfigName)
	for _, stmt := range config.Statements {
		if modstmt, ok := stmt.(*ModifierStatement); ok {
			if include, ok := modstmt.Modifier.(*IncludeModifier); ok {
				p.Plan(include.Descriptor())
			}
		}
	}
	p.addDescriptor(desc)
	return p.results, nil
}

func (p *Planner) addDescriptor(desc Descriptor) {
	for _, existing := range p.results {
		if desc.Equals(existing) {
			return
		}
	}
	l := len(p.results)
	p.results = p.results[0:l+1]
	p.results[l] = desc
}

func findConfig(stmts []PackageStatement, configName ConfigName) *Config {
	for _, stmt := range stmts {
		if block, ok := stmt.(*ConfigBlock); ok {
			if block.Config.ConfigName == configName {
				return block.Config
			}
		}
	}
	return nil
}
