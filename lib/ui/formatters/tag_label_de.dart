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
    case 'dinner':
      return 'Abendessen';
    case 'snack':
      return 'Snack';
    case 'vegetarian':
      return 'Vegetarisch';
    default:
      return key; // fallback for unknown tags
  }
}
