package model

// Backtrace shows the chain of dependencies that 
// led up to a particular error. Implemented as
// a linked list.
type Backtrace struct {
	parent     *Backtrace
	descriptor *Descriptor
}

// Adds a descriptor to the front of the trace
func (parent *Backtrace) Push(descriptor *Descriptor) *Backtrace {
	return &Backtrace{parent, descriptor}
}

// Returns the rest of the trace.
func (child *Backtrace) Pop() *Backtrace {
	return child.parent
}

