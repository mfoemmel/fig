package fig

const helpText = `
Fig is a cross-platform, language-agnostic package manager.

Usage: fig <command> [<args>...]

Commands:
    fig help
    fig list [--local]
    fig publish [<modifiers>...] <package>/<version> [--local]
    fig run [<modifiers>...] <descriptor>
    fig run [<modifiers>...] -- <executable> <args>
    fig retrieve 

Modifiers:
    (-i | --include) <descriptor>
    (-s | --set) <name>=<value>
    (-j | --join) <name>=<value>

Descriptors:
    <package>/<version>:<config>

    Descriptors reference a particular configuration within a 
particular version of a package. The version and config names 
are options, so all of the following are valid descriptors:

    cheese
    cheese/1.2beta3
    cheese:debug
    cheese/1.2beta3:debug

`

type HelpCommand struct {
}

func (cmd *HelpCommand) Execute(ctx *Context) {
	ctx.out.Write([]byte(helpText))
}

