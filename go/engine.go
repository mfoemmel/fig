package fig

import "io"

type Engine struct {
	out  io.Writer
	repo Repository
}

func NewEngine(out io.Writer, repo Repository) *Engine {
	return &Engine{out, repo}
}

func (engine *Engine) Show(packageName PackageName, versionName VersionName) {
	pkg := ReadPackage(engine.repo, packageName, versionName)
	NewUnparser(engine.out).UnparsePackage(pkg)
}
