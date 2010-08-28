package fig

import "os"

type InstallCommand struct {
	packageName PackageName
	versionName VersionName
}

func parseInstallArgs(iter *ArgIterator) (Command, os.Error) {
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
        return &InstallCommand{desc.PackageName, desc.VersionName}, nil
}

func (cmd *InstallCommand) Execute(ctx *Context) {
	ctx.space.Install(cmd.packageName, cmd.versionName)
}
