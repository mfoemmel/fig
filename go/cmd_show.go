package fig

import "io"
import "os"

type ShowCommand struct {
	packageName PackageName
	versionName VersionName
}

func (cmd *ShowCommand) Execute(repo Repository, out io.Writer) {
	pkg, err := ReadPackage(repo, cmd.packageName, cmd.versionName)
	if err != nil {
		os.Stderr.Write([]byte(err.String() + "\n"))
		os.Exit(1)
	}
	NewUnparser(out).UnparsePackage(pkg)
}
