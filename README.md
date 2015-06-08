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
         
This profile can be archived (json).  If you archive, you can have subsequent executions of the profiler append to the archive.  This will help in situations where different executions of the code might introduce different data types.

Using the example of the following method:

```
  def do_something_with_items(list_of_stuff)
    newitems = list_of_stuff.collect { |item|
      item += item
    }
    newitems
  end
```

If you execute

```
  do_something_with_items([1, 2, 3])
```

the profiler will report that

* Calling parameter "list_of_stuff" is [Fixnum]
* Local variable "newitems" is [Fixnum]
* Returns [Fixnum]

If you then subsequently execute

```
  do_something_with_items(["a", "b", "c"])
```

the profiler will see that

* Calling parameter "list_of_stuff" is [String]
* Local variable "newitems" is [String]
* Returns [String]

and the total signature will look something like

* Method: "do_something_with_items"
    * Calling parameters
       * Name: "list_of_stuff"
       * Types (Set): [Fixnum], [String]
    * Local variables
       * Name: "newitems"
       * Types (Set): [Fixnum], [String]
    * Returns
       * Types (Set): [Fixnum], [String]

You can "report" on the types by executing the `report` method or just inspect the json archive (if you elected to create one).

I've also provided a quick example of how you can abuse the profile to emit "faux-Swift" by making some assumptions about the types it discovers.  It's not too smart (and it's not supposed to be), but it will help you quickly eyeball possible transformations.

In the above case for `do_something_with_items` the transformer will notice that there are multiple types for the various properties and make suggestions, but also alert you to the fact that you need to make some decisions.  We'd have something like

```
    /// FIXME:  Param 'list_of_stuff' contains multiple types. Defaulting to AnyObject. CHOOSE FROM *** ( ["[String]", "[Int]"] ) ***
    /// :param: list_of_stuff
    /// FIXME:  Returns multiple types. Defaulting to AnyObject. CHOOSE FROM *** ( ["[String]", "[Int]"] ) ***
    /// :returns: [AnyObject] //Return can be empty array
    func do_something_with_items(list_of_stuff: [AnyObject] = []) -> [AnyObject] //Return can be empty array
    {
        /// FIXME:  'list_of_stuff' has multiple types. Defaulting to AnyObject. CHOOSE FROM *** ( ["[String]", "[Int]"] ) ***
        list_of_stuff: [AnyObject]
        /// FIXME:  'newitems' has multiple types. Defaulting to AnyObject. CHOOSE FROM *** ( ["[String]", "[Int]"] ) ***
        newitems: [AnyObject]?
        /// FIXME:  'item' has multiple types. Defaulting to AnyObject. CHOOSE FROM *** ( ["String", "Int"] ) ***
        item: AnyObject
    }
```




