package fig

import "os"

type ShowCommand struct {
	packageName PackageName
	versionName VersionName
}

func parseShowArgs(iter *ArgIterator) (Command, os.Error) {
        if !iter.Next() {
                return nil, os.NewError("Please specify a package and version (e.g. foo/1.2.3)")
        }
	desc, err := NewParser("<arg>",[]byte(iter.Get())).descriptor()
	if err != nil {
		return nil, err
	}
	if desc.PackageName == "" || desc.VersionName == "" {
                return nil, os.NewError("Please specify a package and version (e.g. foo/1.2.3)")
	}
        return &ShowCommand{desc.PackageName, desc.VersionName}, nil
}

func (cmd *ShowCommand) Execute(ctx *Context) int {
	pkg, err := ReadPackage(ctx.repo, cmd.packageName, cmd.versionName)
	if err != nil {
		// todo Context should have an "err" field
		os.Stderr.Write([]byte(err.String() + "\n"))
		return 1
	}
	NewUnparser(ctx.out).UnparsePackage(pkg)
	return 0
}
