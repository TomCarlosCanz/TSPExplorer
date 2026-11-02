import CoreLocation

/// A real-world city with a name and geographic position.
struct City: Identifiable, Hashable {
    let id: String
    let name: String
    let country: String
    let latitude: Double
    let longitude: Double

    init(_ name: String, _ country: String, _ latitude: Double, _ longitude: Double, id: String? = nil) {
        self.id = id ?? "\(name)|\(country)"
        self.name = name
        self.country = country
        self.latitude = latitude
        self.longitude = longitude
    }

    /// The name shown on the map, in German where the German name differs.
    /// `name` stays English because it is part of the ID the Concorde results use.
    var displayName: String {
        tr(name, CityCatalog.germanNames[name] ?? name)
    }

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

/// Preset collections of real cities. Each list is ordered roughly by population,
/// so "the first N cities" are always the N largest.
enum Region: String, CaseIterable, Identifiable {
    case europe, germany, usa, world

    var id: String { rawValue }

    var title: String {
        switch self {
        case .europe: return tr("European Capitals", "Europäische Hauptstädte")
        case .germany: return tr("Germany", "Deutschland")
        case .usa: return tr("United States", "Vereinigte Staaten")
        case .world: return tr("World Megacities", "Weltmetropolen")
        }
    }

    var symbol: String {
        switch self {
        case .europe: return "globe.europe.africa"
        case .germany: return "map"
        case .usa: return "globe.americas"
        case .world: return "globe"
        }
    }

    var cities: [City] {
        switch self {
        case .europe: return CityCatalog.europe
        case .germany: return CityCatalog.germany
        case .usa: return CityCatalog.usa
        case .world: return CityCatalog.world
        }
    }
}

enum CityCatalog {
    /// German names for the cities whose German name differs.
    static let germanNames: [String: String] = [
        "Kyiv": "Kiew", "Rome": "Rom", "Bucharest": "Bukarest", "Vienna": "Wien",
        "Warsaw": "Warschau", "Belgrade": "Belgrad", "Prague": "Prag", "Brussels": "Brüssel",
        "Copenhagen": "Kopenhagen", "Lisbon": "Lissabon", "Athens": "Athen",
        "Luxembourg": "Luxemburg", "Munich": "München", "Cologne": "Köln",
        "Nuremberg": "Nürnberg", "Hanover": "Hannover", "Tokyo": "Tokio",
        "Mexico City": "Mexiko-Stadt", "Cairo": "Kairo", "Beijing": "Peking",
        "Karachi": "Karatschi", "Moscow": "Moskau", "Singapore": "Singapur",
        "Cape Town": "Kapstadt", "Seoul": "Seoul",
    ]

    static let europe: [City] = [
        City("London", "United Kingdom", 51.5074, -0.1278),
        City("Berlin", "Germany", 52.5200, 13.4050),
        City("Madrid", "Spain", 40.4168, -3.7038),
        City("Kyiv", "Ukraine", 50.4501, 30.5234),
        City("Rome", "Italy", 41.9028, 12.4964),
        City("Paris", "France", 48.8566, 2.3522),
        City("Bucharest", "Romania", 44.4268, 26.1025),
        City("Vienna", "Austria", 48.2082, 16.3738),
        City("Warsaw", "Poland", 52.2297, 21.0122),
        City("Budapest", "Hungary", 47.4979, 19.0402),
        City("Belgrade", "Serbia", 44.7866, 20.4489),
        City("Sofia", "Bulgaria", 42.6977, 23.3219),
        City("Prague", "Czechia", 50.0755, 14.4378),
        City("Brussels", "Belgium", 50.8503, 4.3517),
        City("Stockholm", "Sweden", 59.3293, 18.0686),
        City("Amsterdam", "Netherlands", 52.3676, 4.9041),
        City("Oslo", "Norway", 59.9139, 10.7522),
        City("Helsinki", "Finland", 60.1699, 24.9384),
        City("Copenhagen", "Denmark", 55.6761, 12.5683),
        City("Dublin", "Ireland", 53.3498, -6.2603),
        City("Lisbon", "Portugal", 38.7223, -9.1393),
        City("Athens", "Greece", 37.9838, 23.7275),
        City("Riga", "Latvia", 56.9496, 24.1052),
        City("Vilnius", "Lithuania", 54.6872, 25.2797),
        City("Zagreb", "Croatia", 45.8150, 15.9819),
        City("Sarajevo", "Bosnia and Herzegovina", 43.8563, 18.4131),
        City("Skopje", "North Macedonia", 41.9981, 21.4254),
        City("Chișinău", "Moldova", 47.0105, 28.8638),
        City("Tirana", "Albania", 41.3275, 19.8187),
        City("Tallinn", "Estonia", 59.4370, 24.7536),
        City("Bratislava", "Slovakia", 48.1486, 17.1077),
        City("Ljubljana", "Slovenia", 46.0569, 14.5058),
        City("Bern", "Switzerland", 46.9480, 7.4474),
        City("Reykjavík", "Iceland", 64.1466, -21.9426),
        City("Podgorica", "Montenegro", 42.4304, 19.2594),
        City("Luxembourg", "Luxembourg", 49.6116, 6.1319),
        City("Valletta", "Malta", 35.8989, 14.5146),
    ]

    static let germany: [City] = [
        City("Berlin", "Germany", 52.5200, 13.4050),
        City("Hamburg", "Germany", 53.5511, 9.9937),
        City("Munich", "Germany", 48.1351, 11.5820),
        City("Cologne", "Germany", 50.9375, 6.9603),
        City("Frankfurt", "Germany", 50.1109, 8.6821),
        City("Stuttgart", "Germany", 48.7758, 9.1829),
        City("Düsseldorf", "Germany", 51.2277, 6.7735),
        City("Leipzig", "Germany", 51.3397, 12.3731),
        City("Dortmund", "Germany", 51.5136, 7.4653),
        City("Essen", "Germany", 51.4556, 7.0116),
        City("Bremen", "Germany", 53.0793, 8.8017),
        City("Dresden", "Germany", 51.0504, 13.7373),
        City("Hanover", "Germany", 52.3759, 9.7320),
        City("Nuremberg", "Germany", 49.4521, 11.0767),
        City("Duisburg", "Germany", 51.4344, 6.7623),
        City("Bochum", "Germany", 51.4818, 7.2162),
        City("Wuppertal", "Germany", 51.2562, 7.1508),
        City("Bielefeld", "Germany", 52.0302, 8.5325),
        City("Bonn", "Germany", 50.7374, 7.0982),
        City("Münster", "Germany", 51.9607, 7.6261),
        City("Mannheim", "Germany", 49.4875, 8.4660),
        City("Karlsruhe", "Germany", 49.0069, 8.4037),
        City("Augsburg", "Germany", 48.3705, 10.8978),
        City("Wiesbaden", "Germany", 50.0782, 8.2398),
        City("Kiel", "Germany", 54.3233, 10.1228),
        City("Freiburg", "Germany", 47.9990, 7.8421),
        City("Rostock", "Germany", 54.0924, 12.0991),
        City("Erfurt", "Germany", 50.9848, 11.0299),
        City("Kassel", "Germany", 51.3127, 9.4797),
        City("Saarbrücken", "Germany", 49.2402, 6.9969),
        City("Regensburg", "Germany", 49.0134, 12.1016),
        City("Magdeburg", "Germany", 52.1205, 11.6276),
        City("Potsdam", "Germany", 52.3906, 13.0645),
        City("Mainz", "Germany", 49.9929, 8.2473),
        City("Schwerin", "Germany", 53.6355, 11.4012),
        // Every other German city above 100,000 people, plus a few for spread.
        City("Mönchengladbach", "Germany", 51.1805, 6.4428),
        City("Gelsenkirchen", "Germany", 51.5177, 7.0857),
        City("Aachen", "Germany", 50.7753, 6.0839),
        City("Braunschweig", "Germany", 52.2689, 10.5268),
        City("Chemnitz", "Germany", 50.8278, 12.9214),
        City("Halle (Saale)", "Germany", 51.4969, 11.9688),
        City("Krefeld", "Germany", 51.3388, 6.5853),
        City("Lübeck", "Germany", 53.8655, 10.6866),
        City("Oberhausen", "Germany", 51.4963, 6.8638),
        City("Hagen", "Germany", 51.3671, 7.4633),
        City("Hamm", "Germany", 51.6739, 7.8150),
        City("Mülheim an der Ruhr", "Germany", 51.4186, 6.8845),
        City("Ludwigshafen", "Germany", 49.4774, 8.4452),
        City("Oldenburg", "Germany", 53.1435, 8.2146),
        City("Osnabrück", "Germany", 52.2799, 8.0472),
        City("Leverkusen", "Germany", 51.0459, 7.0192),
        City("Heidelberg", "Germany", 49.3988, 8.6724),
        City("Darmstadt", "Germany", 49.8728, 8.6512),
        City("Solingen", "Germany", 51.1652, 7.0671),
        City("Herne", "Germany", 51.5388, 7.2257),
        City("Neuss", "Germany", 51.2042, 6.6879),
        City("Paderborn", "Germany", 51.7189, 8.7575),
        City("Ingolstadt", "Germany", 48.7665, 11.4258),
        City("Offenbach am Main", "Germany", 50.0956, 8.7761),
        City("Würzburg", "Germany", 49.7913, 9.9534),
        City("Fürth", "Germany", 49.4771, 10.9887),
        City("Ulm", "Germany", 48.4011, 9.9876),
        City("Heilbronn", "Germany", 49.1427, 9.2109),
        City("Pforzheim", "Germany", 48.8922, 8.6946),
        City("Wolfsburg", "Germany", 52.4227, 10.7865),
        City("Göttingen", "Germany", 51.5413, 9.9158),
        City("Bottrop", "Germany", 51.5236, 6.9285),
        City("Reutlingen", "Germany", 48.4914, 9.2043),
        City("Koblenz", "Germany", 50.3569, 7.5890),
        City("Bremerhaven", "Germany", 53.5396, 8.5809),
        City("Recklinghausen", "Germany", 51.6141, 7.1979),
        City("Erlangen", "Germany", 49.5897, 11.0120),
        City("Bergisch Gladbach", "Germany", 50.9918, 7.1366),
        City("Remscheid", "Germany", 51.1787, 7.1897),
        City("Jena", "Germany", 50.9271, 11.5892),
        City("Trier", "Germany", 49.7499, 6.6371),
        City("Salzgitter", "Germany", 52.1503, 10.3593),
        City("Moers", "Germany", 51.4516, 6.6408),
        City("Siegen", "Germany", 50.8748, 8.0243),
        City("Hildesheim", "Germany", 52.1508, 9.9511),
        City("Gütersloh", "Germany", 51.9032, 8.3858),
        City("Kaiserslautern", "Germany", 49.4447, 7.7690),
        City("Cottbus", "Germany", 51.7563, 14.3329),
        City("Hanau", "Germany", 50.1264, 8.9283),
        City("Witten", "Germany", 51.4436, 7.3526),
        City("Esslingen", "Germany", 48.7397, 9.3108),
        City("Ludwigsburg", "Germany", 48.8975, 9.1916),
        City("Gera", "Germany", 50.8805, 12.0824),
        City("Iserlohn", "Germany", 51.3755, 7.6957),
        City("Düren", "Germany", 50.8034, 6.4816),
        City("Zwickau", "Germany", 50.7189, 12.4961),
        City("Flensburg", "Germany", 54.7937, 9.4469),
        City("Tübingen", "Germany", 48.5216, 9.0576),
        City("Gießen", "Germany", 50.5841, 8.6784),
        City("Konstanz", "Germany", 47.6779, 9.1732),
        City("Bamberg", "Germany", 49.8988, 10.9028),
        City("Passau", "Germany", 48.5665, 13.4312),
        City("Stralsund", "Germany", 54.3091, 13.0818),
        City("Frankfurt (Oder)", "Germany", 52.3471, 14.5506),
        City("Görlitz", "Germany", 51.1526, 14.9873),
    ]

    static let usa: [City] = [
        City("New York", "United States", 40.7128, -74.0060),
        City("Los Angeles", "United States", 34.0522, -118.2437),
        City("Chicago", "United States", 41.8781, -87.6298),
        City("Houston", "United States", 29.7604, -95.3698),
        City("Phoenix", "United States", 33.4484, -112.0740),
        City("Philadelphia", "United States", 39.9526, -75.1652),
        City("San Antonio", "United States", 29.4241, -98.4936),
        City("San Diego", "United States", 32.7157, -117.1611),
        City("Dallas", "United States", 32.7767, -96.7970),
        City("Jacksonville", "United States", 30.3322, -81.6557),
        City("Austin", "United States", 30.2672, -97.7431),
        City("San Francisco", "United States", 37.7749, -122.4194),
        City("Columbus", "United States", 39.9612, -82.9988),
        City("Indianapolis", "United States", 39.7684, -86.1581),
        City("Seattle", "United States", 47.6062, -122.3321),
        City("Denver", "United States", 39.7392, -104.9903),
        City("Washington", "United States", 38.9072, -77.0369),
        City("Boston", "United States", 42.3601, -71.0589),
        City("Nashville", "United States", 36.1627, -86.7816),
        City("Las Vegas", "United States", 36.1699, -115.1398),
        City("Portland", "United States", 45.5152, -122.6784),
        City("Detroit", "United States", 42.3314, -83.0458),
        City("Memphis", "United States", 35.1495, -90.0490),
        City("Atlanta", "United States", 33.7490, -84.3880),
        City("Miami", "United States", 25.7617, -80.1918),
        City("Minneapolis", "United States", 44.9778, -93.2650),
        City("New Orleans", "United States", 29.9511, -90.0715),
        City("Salt Lake City", "United States", 40.7608, -111.8910),
        City("Kansas City", "United States", 39.0997, -94.5786),
        City("Albuquerque", "United States", 35.0844, -106.6504),
    ]

    static let world: [City] = [
        City("Tokyo", "Japan", 35.6762, 139.6503),
        City("Delhi", "India", 28.7041, 77.1025),
        City("Shanghai", "China", 31.2304, 121.4737),
        City("São Paulo", "Brazil", -23.5505, -46.6333),
        City("Mexico City", "Mexico", 19.4326, -99.1332),
        City("Cairo", "Egypt", 30.0444, 31.2357),
        City("Mumbai", "India", 19.0760, 72.8777),
        City("Beijing", "China", 39.9042, 116.4074),
        City("Dhaka", "Bangladesh", 23.8103, 90.4125),
        City("New York", "United States", 40.7128, -74.0060),
        City("Karachi", "Pakistan", 24.8607, 67.0011),
        City("Buenos Aires", "Argentina", -34.6037, -58.3816),
        City("Istanbul", "Türkiye", 41.0082, 28.9784),
        City("Lagos", "Nigeria", 6.5244, 3.3792),
        City("Manila", "Philippines", 14.5995, 120.9842),
        City("Rio de Janeiro", "Brazil", -22.9068, -43.1729),
        City("Moscow", "Russia", 55.7558, 37.6173),
        City("Paris", "France", 48.8566, 2.3522),
        City("London", "United Kingdom", 51.5074, -0.1278),
        City("Bangkok", "Thailand", 13.7563, 100.5018),
        City("Jakarta", "Indonesia", -6.2088, 106.8456),
        City("Lima", "Peru", -12.0464, -77.0428),
        City("Seoul", "South Korea", 37.5665, 126.9780),
        City("Los Angeles", "United States", 34.0522, -118.2437),
        City("Johannesburg", "South Africa", -26.2041, 28.0473),
        City("Sydney", "Australia", -33.8688, 151.2093),
        City("Singapore", "Singapore", 1.3521, 103.8198),
        City("Nairobi", "Kenya", -1.2921, 36.8219),
        City("Toronto", "Canada", 43.6532, -79.3832),
        City("Dubai", "United Arab Emirates", 25.2048, 55.2708),
        City("Santiago", "Chile", -33.4489, -70.6693),
        City("Cape Town", "South Africa", -33.9249, 18.4241),
        City("Auckland", "New Zealand", -36.8485, 174.7633),
        City("Honolulu", "United States", 21.3069, -157.8583),
    ]
}
