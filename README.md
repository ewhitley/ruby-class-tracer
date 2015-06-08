# ruby-class-tracer

I need to port some Ruby to Swift, but type conversion was causing me some issues.

This utility just helps me inspect what's going on with the Ruby application at runtime so I can evaluate the type information for a given class and its methods.

It uses set_trace_func and TracePoint to monitor execution, then logs what it finds.

It creates a profile that looks something like:

* Class {Hash}
    * Instance Variables {Hash}
        * Instance variable Name (hash key)
        * Discovered types (Set)
    * Methods {Hash}
        * Method name (hash key)
        * Return types (Set)
        * Calling variables / parameters {Hash}
            * Parameter Name (hash key)
            * Discovered types (Set)
        * Local variables {Hash}
            * Variable Name (hash key)
            * Discovered types (Set)
         
This profile can be archived (json).  If you archive, you can have subsequent executions of the profiler append to archive.

I've also provided a quick example of how you can abuse the profile to emit "faux-Swift" by making some assumptions about the types it discovered.


