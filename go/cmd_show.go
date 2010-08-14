package fig

import "io"

type ShowCommand struct {
	packageName PackageName
	versionName VersionName
}

func (cmd *ShowCommand) Execute(repo Repository, out io.Writer) {
	pkg := ReadPackage(repo, cmd.packageName, cmd.versionName)
	NewUnparser(out).UnparsePackage(pkg)
}
