import RealmSwift

class IntObject: Object
{
   dynamic var int = 0
   
   convenience init(_ value: Int) {
      self.init()
      self.int = value
   }
   
   override var description: String {
      return "\(int)"
   }
}
