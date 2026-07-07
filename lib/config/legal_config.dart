/// Uygulama sözleşmesi ve mağaza politikalarıyla uyumlu yaş sınırları.
const minimumUserAge = 18;
const maximumUserAge = 120;

String? validateFortuneSubjectAge(int? age) {
  if (age == null || age < minimumUserAge || age > maximumUserAge) {
    return '$minimumUserAge–$maximumUserAge arası geçerli bir yaş girin';
  }
  return null;
}

bool isAdultAge(int age) => age >= minimumUserAge && age <= maximumUserAge;
