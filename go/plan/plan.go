package plan

import "os"

import . "fig/model"
import . "fig/repos"

type VersionConflictError struct {
        PackageName PackageName
        Backtraces []*Backtrace
}

func (err *VersionConflictError) String() string {
	return "VersionConflictError"
}

type Planner struct {
	repo Repository
	results []Descriptor
	versions map[PackageName] *Backtrace
}

func NewPlanner(repo Repository) *Planner {
	return &Planner{repo,make([]Descriptor, 0, 10),make(map[PackageName]*Backtrace)}
}

func (p *Planner) Plan(desc Descriptor) ([]Descriptor, os.Error) {
	if err := p.visit(desc, nil); err != nil {
		return nil, err
	}
	return p.results, nil
}

func (p *Planner) visit(desc Descriptor, backtrace *Backtrace) os.Error {
	backtrace = backtrace.Push(desc)
	pkg := ReadPackage(p.repo, desc.PackageName, desc.VersionName)
	config := findConfig(pkg.Statements, desc.ConfigName)
	for _, stmt := range config.Statements {
		if modstmt, ok := stmt.(*ModifierStatement); ok {
			if include, ok := modstmt.Modifier.(*IncludeModifier); ok {
				if err := p.visit(include.Descriptor(), backtrace); err != nil {
					return err
				}
			}
		}
	}
	if err := p.addDescriptor(desc, backtrace); err != nil {
		return err
	}
	return nil
}

func (p *Planner) addDescriptor(desc Descriptor, backtrace *Backtrace) os.Error {
	for _, existing := range p.results {
		if desc.Equals(existing) {
			return nil
		}
	}
	otherBacktrace, exists := p.versions[desc.PackageName]
	if exists {
		if otherBacktrace.Descriptor.VersionName != desc.VersionName {
			return &VersionConflictError{desc.PackageName,[]*Backtrace{backtrace, otherBacktrace}}
		}
	} else {
		p.versions[desc.PackageName] = backtrace
	}
	l := len(p.results)
	p.results = p.results[0:l+1]
	p.results[l] = desc
	return nil
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
