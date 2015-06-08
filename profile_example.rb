require_relative 'ClassTracker.rb'
require_relative 'Simpsons.rb'


# create our recording helper
class_archive = "SimpsonsProfile.txt"
#class_tracker = ClassTraceUtils::ClassTracker.restoreFromArchive(nil, class_archive, nil)
class_tracker = ClassTraceUtils::ClassTracker.restoreFromArchive(class_archive)
#class_tracker = ClassTraceUtils::ClassTracker.new(archive_path: class_archive)

# specify which classes we want to evaluate
class_tracker.monitored_classes = ["SimpsonsCharacter", "KWIKEMartProduct", "BartNames"]
#class_tracker.named_like = "Simps" ##You can also specify a regex here instead

class_tracker.start

#=============================
#OK, so now let's hit some actual "application code" we want to profile
# the profiler will add "new" stuff it finds if you load from the archive
bob = SimpsonsCharacter.new("Bob", "Terwilliger")
myval = bob.var_return + bob.simple_return
arStr = bob.do_something_with_items(["a","b", "c"])
arInt = bob.do_something_with_items([1, 2, 3])
arEmpty = bob.do_something_with_items([])

thouse = SimpsonsCharacter.new("Thrilhou", nil)
thouseArStr = thouse.do_something_with_items(arInt)

hotdog = KWIKEMartProduct.new("Hot Dog", 1.0)
hotdog.increase_cost(3)
hotdog.increase_cost
monitored = hotdog.monitored_by_magic_hat?

elbarto = BartNames.new("Bart")
elbarto.addAlias("El-Barto")
elbarto.addAlias("El-Barto")
#=============================

#Stop our tracer and save the profile
class_tracker.stop
#puts class_tracker.report
class_tracker.archive()

