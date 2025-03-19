import RealmSwift

extension Realm
{
   public class var main : Realm {
      return try! Realm()
   }
   
   public func writeWithTransactionIfNeeded(_ block: () -> Void)
   {
      if isInWriteTransaction {
         block()
      }
      else {
         try? write(block)
      }
   }
}


extension Object
{
   public func modifyWithTransactionIfNeeded(_ block: () -> Void)
   {
      guard !isInvalidated else { return }
      
      if let selfRealm = realm {
         selfRealm.writeWithTransactionIfNeeded(block)
      }
      else {
         block()
      }
   }
}

extension Results
{
   public func toArray() -> Array<T> {
      return Array<T>(self)
   }
}

extension List
{
   public func toArray() -> Array<T> {
      return Array<T>(self)
   }
}
