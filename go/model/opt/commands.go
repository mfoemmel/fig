package opt

type CommandHandler interface {
	Help()
	List()
	Publish(packageName PackageName, versionName VersionName)
	Run(command []string, modifiers []Modifier)
	Retrieve()
}

type Command interface {
	Accept(handler CommandHandler)
}


// Help

type HelpCommand struct {
}

func (cmd *HelpCommand) Accept(handler CommandHandler) {
	handler.Help()
}


// List

type ListCommand struct {
}

func (cmd *ListCommand) Accept(handler CommandHandler) {
	handler.List()
}


// Publish

type PublishCommand struct {
	packageName PackageName
	versionName VersionName
	modifiers   []Modifier
}

func (cmd *PublishCommand) Accept(handler CommandHandler) {
	handler.Publish(cmd.packageName, cmd.versionName)
}


// Retrieve

type RetrieveCommand struct {
}

func (cmd *RetrieveCommand) Accept(handler CommandHandler) {
	handler.Retrieve()
}


// Run

type RunCommand struct {
	command   []string
	modifiers []Modifier
}

func (cmd *RunCommand) Accept(handler CommandHandler) {
	handler.Run(cmd.command, cmd.modifiers)
}
