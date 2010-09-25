package fig

import "os"

type RepoAddCommand struct {
	alias string
	location string
}

type RepoListCommand struct {
}

func parseRepoArgs(iter *ArgIterator) (Command, os.Error) {
        if !iter.Next() {
                return nil, os.NewError("Please specify either 'fig repo add' or 'fig repo rm'")
        }
	switch iter.Get() {
	case "add": 
		if !iter.Next() {
			return nil, os.NewError("Please specify an alias and a path to the repository")
		}
		alias := iter.Get()
		if !iter.Next() {
			return nil, os.NewError("Please specify an alias and a path to the repository")
		}
		location := iter.Get()
		return &RepoAddCommand{alias, location}, nil
	case "ls", "list":
		return &RepoListCommand{}, nil
	}
	
        return nil, os.NewError("Please specify either 'fig repo add' or 'fig repo rm'")
}

func (cmd *RepoAddCommand) Execute(ctx *Context) int {
	settings := NewSettings()
	settings.Load(ctx.fs)
	settings.AddRepository(cmd.alias, cmd.location)
	settings.Save(ctx.fs)
	return 0
}

func (cmd *RepoListCommand) Execute(ctx *Context) int {
	settings := NewSettings()
	settings.Load(ctx.fs)
	for _, repo := range settings.repos {
		ctx.out.Write([]byte(repo.alias))
		ctx.out.Write([]byte("\t"))
		ctx.out.Write([]byte(repo.location))
		ctx.out.Write([]byte("\n"))
	}
	return 0
}

