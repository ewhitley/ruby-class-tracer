require_relative 'ClassTracker.rb'
require_relative 'Simpsons.rb'


# create our recording helper
#class_tracker = ClassTraceUtils::ClassTracker.new
class_archive = "SimpeonsProfile.txt"
class_tracker = ClassTraceUtils::ClassTracker.restoreFromArchive(class_archive)
# specify which classes we want to evaluate
class_tracker.monitored_classes = ["SimpsonsCharacter", "KWIKEMartProduct"]

#puts class_tracker.monitored_classes
class_tracker.start

#=============================

#OK, so now let's hit some actual "application code" we want to profile
# the profiler will add "new" stuff it finds if you load from the archive
bob = SimpsonsCharacter.new("Bob", "Terwilliger")
myval = bob.var_return + bob.simple_return
arStr = bob.do_something_with_items(["a","b", "c"])
arBoom = bob.do_something_with_items([1, 2, 3])

thouse = SimpsonsCharacter.new("Thrilhou", nil)
thouseArStr = thouse.do_something_with_items(arBoom)

hotdog = KWIKEMartProduct.new("Hot Dog", 1.0)
hotdog.increase_cost(3)
hotdog.increase_cost
monitored = hotdog.monitored_by_magic_hat?

#=============================
#OK, now stop our tracer and save the profile
class_tracker.stop
puts class_tracker.ShowSomeClass
class_tracker.archive(class_archive)

