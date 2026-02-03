import SwiftCache

// MARK: - Basic Cache Usage

struct User: Codable {
    let id: String
    let name: String
    let email: String
}

@MainActor
class CacheExample {
    let userCache = Cache<String, User>()
    
    func cacheUser(_ user: User) async {
        await userCache.set(user.id, value: user)
    }
    
    func getUser(id: String) async -> User? {
        await userCache.get(id)
    }
    
    func cacheWithExpiration(_ user: User) async {
        await userCache.set(user.id, value: user, ttl: .minutes(30))
    }
}

// MARK: - Disk Cache

class ImageCacheExample {
    let imageCache = DiskCache<String, Data>(name: "images")
    
    func cacheImage(url: String, data: Data) async {
        await imageCache.set(url, value: data)
    }
    
    func getImage(url: String) async -> Data? {
        await imageCache.get(url)
    }
}
