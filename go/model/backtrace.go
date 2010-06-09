package model

// Backtrace shows the chain of dependencies that 
// led up to a particular error. Implemented as
// a linked list.
type Backtrace struct {
	Parent     *Backtrace
	Descriptor *Descriptor
}

// Adds a descriptor to the front of the trace
func (parent *Backtrace) Push(descriptor *Descriptor) *Backtrace {
	return &Backtrace{parent, descriptor}
}

// Returns the rest of the trace.
func (child *Backtrace) Pop() *Backtrace {
	return child.Parent
}

func (b *Backtrace) String() string {
	s := ""
	for b != nil {
		s += "\n    "
		s += b.Descriptor.String() 
		b = b.Parent
	}
	s += "\n"
	return s
}
