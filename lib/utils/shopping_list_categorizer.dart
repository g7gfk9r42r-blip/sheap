/// Utility to categorize shopping list items by supermarket layout
class ShoppingListCategorizer {
  ShoppingListCategorizer._();

  /// Categorize an ingredient name
  static String categorizeIngredient(String name) {
    final lower = name.toLowerCase();
    
    // Obst (Fruits) - typischerweise am Eingang
    if (_matches(lower, [
      'apfel', 'banane', 'orange', 'erdbeere', 'traube', 'beere', 'birne', 'pfirsich',
      'kiwi', 'mango', 'ananas', 'zitrone', 'limette', 'granatapfel', 'avocado',
      'weintraube', 'kirsche', 'pflaume', 'nektarine', 'melone', 'wassermelone'
    ])) {
      return 'Obst';
    }
    
    // Gemüse (Vegetables) - nach Obst
    if (_matches(lower, [
      'tomate', 'gurke', 'paprika', 'karotte', 'möhre', 'zwiebel', 'knoblauch',
      'salat', 'kopf', 'spinat', 'brokkoli', 'blumenkohl', 'kohl', 'kartoffel',
      'zucchini', 'aubergine', 'pilz', 'champignon', 'lauch', 'sellerie',
      'kohlrabi', 'radieschen', 'rote bete', 'süßkartoffel', 'süßkartoffeln'
    ])) {
      return 'Gemüse';
    }
    
    // Brot & Backwaren (Bread & Bakery)
    if (_matches(lower, [
      'brot', 'brötchen', 'semmel', 'croissant', 'toast', 'baguette',
      'vollkornbrot', 'weizen', 'dinkel', 'brioche', 'laugengebäck'
    ])) {
      return 'Brot & Backwaren';
    }
    
    // Milchprodukte (Dairy) - Kühlung
    if (_matches(lower, [
      'milch', 'joghurt', 'quark', 'sahne', 'creme', 'butter', 'margarine',
      'käse', 'mozzarella', 'gouda', 'cheddar', 'feta', 'ricotta',
      'schmand', 'saure sahne', 'buttermilch', 'schlagsahne'
    ])) {
      return 'Milchprodukte';
    }
    
    // Fleisch & Fisch (Meat & Fish) - Kühlung
    if (_matches(lower, [
      'fleisch', 'hähnchen', 'huhn', 'hackfleisch', 'rind', 'schwein',
      'steak', 'schnitzel', 'wurst', 'salami', 'schinken', 'speck',
      'lachs', 'fisch', 'thunfisch', 'garnelen', 'shrimps', 'meeresfrüchte',
      'ente', 'pute', 'truthahn', 'rindfleisch', 'schweinefleisch'
    ])) {
      return 'Fleisch & Fisch';
    }
    
    // Tiefkühl (Frozen)
    if (_matches(lower, [
      'tiefkühl', 'tiefkühlgemüse', 'eis', 'frozen', 'tiefkühlprodukt',
      'fischstäbchen', 'pommes', 'pizza', 'tiefkühllachs'
    ])) {
      return 'Tiefkühl';
    }
    
    // Getränke (Beverages) - oft am Ende
    if (_matches(lower, [
      'wasser', 'saft', 'cola', 'limo', 'bier', 'wein', 'sprudel',
      'getränk', 'smoothie', 'shake', 'tee', 'kaffee', 'cappuccino'
    ])) {
      return 'Getränke';
    }
    
    // Grundnahrungsmittel (Pantry Staples)
    if (_matches(lower, [
      'nudel', 'pasta', 'reis', 'mehl', 'zucker', 'salz', 'pfeffer',
      'öl', 'essig', 'brühe', 'tomatenmark', 'dose', 'konserve',
      'haferflocken', 'müsli', 'getreide', 'hirse', 'quinoa', 'bulgur'
    ])) {
      return 'Grundnahrungsmittel';
    }
    
    // Snacks & Süßigkeiten (Snacks & Sweets)
    if (_matches(lower, [
      'schokolade', 'kekse', 'chips', 'nüsse', 'mandeln', 'walnüsse',
      'popcorn', 'cracker', 'keks', 'bonbon', 'gummibärchen',
      'müsli', 'riegel', 'snack'
    ])) {
      return 'Snacks & Süßigkeiten';
    }
    
    // Gewürze & Kräuter (Spices & Herbs)
    if (_matches(lower, [
      'basilikum', 'petersilie', 'schnittlauch', 'oregano', 'thymian',
      'rosmarin', 'curry', 'paprika', 'chili', 'zimt', 'vanille',
      'gewürz', 'kräuter', 'minze', 'koriander'
    ])) {
      return 'Gewürze & Kräuter';
    }
    
    // Sonstiges (Other) - Standard
    return 'Sonstiges';
  }
  
  /// Check if name matches any keyword
  static bool _matches(String name, List<String> keywords) {
    return keywords.any((keyword) => name.contains(keyword));
  }
  
  /// Get category order for supermarket layout (typical German supermarket)
  static int getCategoryOrder(String category) {
    switch (category) {
      case 'Obst':
        return 1;
      case 'Gemüse':
        return 2;
      case 'Brot & Backwaren':
        return 3;
      case 'Milchprodukte':
        return 4;
      case 'Fleisch & Fisch':
        return 5;
      case 'Tiefkühl':
        return 6;
      case 'Grundnahrungsmittel':
        return 7;
      case 'Gewürze & Kräuter':
        return 8;
      case 'Snacks & Süßigkeiten':
        return 9;
      case 'Getränke':
        return 10;
      default:
        return 99; // Sonstiges kommt am Ende
    }
  }
}

