package opt

// Helper class for iterating thru command line args

type ArgIterator struct {
	args []string
	pos  int
}

func (iter *ArgIterator) Next() bool {
	if iter.pos == len(iter.args)-1 {
		return false
	}
	iter.pos++
	return true
}

func (iter *ArgIterator) Get() string {
	return iter.args[iter.pos]
}

func (iter *ArgIterator) Rest() []string {
	return iter.args[iter.pos:]
}
