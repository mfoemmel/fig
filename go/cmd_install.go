package fig

import "archive/tar"
import "compress/gzip"
import "os"


type InstallCommand struct {
	packageName PackageName
	versionName VersionName
}

func parseInstallArgs(iter *ArgIterator) (Command, os.Error) {
	if !iter.Next() {
		return nil, os.NewError("Please specify a package and version (e.g. foo/1.2.3)")
	}
	desc, err := NewParser("<arg>", []byte(iter.Get())).descriptor()
	if err != nil {
		return nil, err
	}
	if desc.PackageName == "" || desc.VersionName == "" {
		return nil, os.NewError("Please specify a package and version (e.g. foo/1.2.3)")
	}
	return &InstallCommand{desc.PackageName, desc.VersionName}, nil
}

func (cmd *InstallCommand) Execute(ctx *Context) int {
	ctx.space.Install(cmd.packageName, cmd.versionName)
	pkg := ctx.repo.NewPackageReader(cmd.packageName, cmd.versionName)
	stmts, err := pkg.ReadStatements()
	if err != nil {
		panic(err)
	}
	for _, stmt := range stmts {
		if archiveStmt, ok := stmt.(*ArchiveStatement); ok {
			//in, err := pkg.OpenResource(archiveStmt.Path)
			in, err := pkg.OpenArchive()
			println(archiveStmt.Path)
			if err != nil {
				panic(err)
			}
			defer in.Close()

			gr, err := gzip.NewReader(in)
			if err != nil {
				panic(err)
			}
			tr := tar.NewReader(gr)
			for {
				hdr, err := tr.Next()
				if err != nil {
					panic(err)
				}
				if hdr == nil {
					// end of tar archive
					break
				}
				ctx.out.Write([]byte(hdr.Name + "\n"))
			}
		}
	}
	defer pkg.Close()

	return 0
}
