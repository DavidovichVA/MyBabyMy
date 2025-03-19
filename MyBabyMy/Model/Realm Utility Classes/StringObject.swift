import RealmSwift

class StringObject: Object
{
   dynamic var string = ""
   
   convenience init(_ value: String) {
      self.init()
      self.string = value
   }
   
   override var description: String {
      return string
   }
}
