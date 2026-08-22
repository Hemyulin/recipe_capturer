String tagLabelDe(String key) {
  switch (key) {
    case 'quick':
      return 'Schnell';
    case 'savory':
      return 'Herzhaft';
    case 'dessert':
      return 'Dessert';
    case 'sweet':
      return 'Süß';
    case 'breakfast':
      return 'Frühstück';
    case 'lunch':
      return 'Mittagessen';
    case 'dinner':
      return 'Abendessen';
    case 'one_pot':
      return 'One pot';
    case 'snack':
      return 'Snack';
    case 'vegetarian':
      return 'Vegetarisch';
    default:
      return key; // fallback for unknown tags
  }
}
