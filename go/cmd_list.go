package fig

import "fmt"
import "io"

type ListCommand struct {
}

func (cmd *ListCommand) Execute(repo Repository, out io.Writer) {
	for pkg := range repo.ListPackages() {
		line := fmt.Sprintf("%s/%s\n", pkg.PackageName, pkg.VersionName)
		out.Write([]byte(line))
	}
}
