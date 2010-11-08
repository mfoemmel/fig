package fig

import "fmt"
import "os"

type VersionConflictError struct {
	PackageName PackageName
	Backtraces  []*Backtrace
}

type CyclicDependencyError struct {
	Cycle     []Descriptor
	Backtrace *Backtrace
}

func (err *VersionConflictError) String() string {
	return "VersionConflictError"
}

func (err *CyclicDependencyError) String() string {
	return "CyclicDependencyError"
}

type configNode struct {
	planner   *Planner
	desc      Descriptor
	config    *Config
	backtrace *Backtrace
}

func (node *configNode) Id() string {
	if node == nil {
		panic("nil node")
	}
	return string(node.desc.PackageName) + ":" + string(node.desc.ConfigName)
}

func (node *configNode) EachChild(f func(Node)) {
	for _, stmt := range node.config.Statements {
		if modstmt, ok := stmt.(*ModifierStatement); ok {
			if include, ok := modstmt.Modifier.(*IncludeModifier); ok {
				desc := include.Descriptor()
				child := node.planner.packages[desc.PackageName].configs[desc.ConfigName]
				if child == nil {
					panic("no child " + string(desc.PackageName) + " " + string(desc.ConfigName))
				}
				f(child)
			}
		}
	}
}

type packageNode struct {
	pkg       *Package
	backtrace *Backtrace
	configs   map[ConfigName]*configNode
}

type Planner struct {
	repo     Repository
	packages map[PackageName]*packageNode
}

func NewPlanner(repo Repository) *Planner {
	return &Planner{repo, make(map[PackageName]*packageNode)}
}

func (p *Planner) Plan(desc Descriptor) ([]Descriptor, os.Error) {
	if err := p.visit(desc, nil); err != nil {
		return nil, err
	}
	root := p.packages[desc.PackageName].configs[desc.ConfigName]
	cycles := FindCycles(root)
	if len(cycles) != 0 {
		// just report the first cycle
		cycle := cycles[0].Slice()
		descriptors := make([]Descriptor, len(cycle))
		for i, _ := range descriptors {
			descriptors[i] = cycle[i].(*configNode).desc
		}
		return nil, &CyclicDependencyError{descriptors, cycle[0].(*configNode).backtrace}
	}
	nodes := Sort(root)
	descriptors := make([]Descriptor, len(nodes))
	for i, node := range nodes {
		descriptors[i] = node.(*configNode).desc
	}

	return descriptors, nil
}

func (p *Planner) visit(desc Descriptor, backtrace *Backtrace) os.Error {
	backtrace = backtrace.Push(desc)
	pkg, err := ReadPackage(p.repo, desc.PackageName, desc.VersionName)
	if err != nil {
		return err
	}
	pkgNode, exists := p.packages[desc.PackageName]
	if exists {
		if pkgNode.backtrace.Descriptor.VersionName != desc.VersionName {
			return &VersionConflictError{desc.PackageName, []*Backtrace{backtrace, pkgNode.backtrace}}
		}
	} else {
		pkgNode = &packageNode{pkg, backtrace, make(map[ConfigName]*configNode)}
		p.packages[desc.PackageName] = pkgNode
	}

	_, exists = pkgNode.configs[desc.ConfigName]
	if exists {
		return nil
	}
	config := findConfig(pkg.Statements, desc.ConfigName)
	if config == nil {
		panic(fmt.Sprintf("config not found: %v", desc.ConfigName))
	}
	pkgNode.configs[desc.ConfigName] = &configNode{p, desc, config, backtrace}
	for _, stmt := range config.Statements {
		if modstmt, ok := stmt.(*ModifierStatement); ok {
			if include, ok := modstmt.Modifier.(*IncludeModifier); ok {
				if err := p.visit(include.Descriptor(), backtrace); err != nil {
					return err
				}
			}
		}
	}
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
