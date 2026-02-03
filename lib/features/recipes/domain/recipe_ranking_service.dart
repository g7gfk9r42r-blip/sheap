import '../../../data/models/recipe.dart';
import '../../auth/data/models/user_account.dart';

class RecipeRankingService {
  RecipeRankingService._();
  static final RecipeRankingService instance = RecipeRankingService._();

  int score(Recipe recipe, UserProfile profile) {
    int s = 0;

    final cats = (recipe.categories ?? const []).map((c) => c.toLowerCase()).toList();
    final title = recipe.title.toLowerCase();
    final ingredients = recipe.ingredients.map((i) => i.toLowerCase()).join(' ');

    bool hasAny(List<String> needles) {
      for (final n in needles) {
        if (title.contains(n) || ingredients.contains(n)) return true;
      }
      return false;
    }

    bool catHasAny(List<String> needles) {
      for (final n in needles) {
        if (cats.any((c) => c.contains(n))) return true;
      }
      return false;
    }

    final diet = profile.diet.toLowerCase().trim();
    if (diet == 'vegetarian') {
      if (catHasAny(['vegetar', 'vegetarian'])) s += 1000;
      if (hasAny(['chicken', 'hähn', 'huhn', 'beef', 'rind', 'pork', 'schwein', 'bacon', 'speck', 'fish', 'lachs', 'thunf', 'wurst'])) {
        s -= 10000;
      }
    } else if (diet == 'vegan') {
      if (catHasAny(['vegan'])) s += 1000;
      if (hasAny(['milch', 'käse', 'butter', 'ei', 'eier', 'hähn', 'huhn', 'rind', 'schwein', 'speck', 'lachs', 'fisch'])) {
        s -= 10000;
      }
    }

    for (final g in profile.goals) {
      final gl = g.toLowerCase();
      if (gl == 'high_protein' && catHasAny(['high protein', 'protein'])) s += 200;
      if (gl == 'low_carb' && catHasAny(['low carb', 'keto'])) s += 200;
      if (gl == 'low_calorie' && catHasAny(['kalorienarm', 'low calorie'])) s += 200;
      if (gl == 'high_calorie' && catHasAny(['high calorie', 'kalorienreich'])) s += 200;
    }

    return s;
  }
}


