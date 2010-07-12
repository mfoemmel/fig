package parser

import "fmt"
import "io"

import . "fig/model"

type Unparser struct {
	out io.Writer
}

func NewUnparser(out io.Writer) *Unparser {
	return &Unparser{out}
}

func (u *Unparser) UnparsePackage(pkg *Package) {
	for _, config := range pkg.Configs {
		u.UnparseConfig(config)
	}
}

func (u *Unparser) UnparseConfig(config *Config) {
	fmt.Fprintf(u.out, "config %s\n", config.ConfigName)
	for _, stmt := range config.Statements {
		u.UnparseModifier(stmt.(*ModifierStatement).Modifier)
	}
	fmt.Fprintf(u.out, "end\n")
}

func (u *Unparser) UnparseModifier(mod Modifier) {
	switch mod := mod.(type) {
	case *SetModifier:
		fmt.Fprintf(u.out, "  set %s=%s\n", mod.Name, mod.Value)
	case *PathModifier:
		fmt.Fprintf(u.out, "  path %s=%s\n", mod.Name, mod.Value)
	case *IncludeModifier:
		fmt.Fprintf(u.out, "  include %s\n", mod.Descriptor())
	default:
		panic(fmt.Sprintf("unexpected modifier type: %v", mod))
	}
}
