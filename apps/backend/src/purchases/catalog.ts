/** Store products. Ids must match App Store Connect / Google Play Console. */
export interface Product {
  id: string;
  kind: 'credits' | 'premium';
  credits?: number;
  premiumDays?: number;
}

export const PRODUCTS: readonly Product[] = [
  { id: 'app.yuz.credits.10', kind: 'credits', credits: 10 },
  { id: 'app.yuz.credits.30', kind: 'credits', credits: 30 },
  { id: 'app.yuz.credits.100', kind: 'credits', credits: 100 },
  { id: 'app.yuz.premium.month', kind: 'premium', premiumDays: 31 },
];

export const productById = (id: string): Product | undefined => PRODUCTS.find((p) => p.id === id);
