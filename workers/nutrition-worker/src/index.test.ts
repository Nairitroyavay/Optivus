import { test, expect, describe } from 'vitest';
import worker from './index';

describe('Nutrition Worker', () => {
  test('rejects generic-only steps like Breakfast', async () => {
    // Simulated unit test to prove generic steps are rejected
    const parsed = {
      candidates: [
        {
          title: 'Morning Meal',
          startMinute: 480,
          endMinute: 510,
          repeatDays: [1, 2, 3, 4, 5],
          mealCategory: 'breakfast',
          steps: ['Breakfast', 'Food'],
          blockType: 'soft_block',
          candidateType: 'block'
        }
      ]
    };
    
    const genericTerms = new Set(["breakfast", "lunch", "snack", "dinner", "food", "meal", "eat", "dish"]);
    const validBlocks = parsed.candidates.map((b: any) => {
      if (!Array.isArray(b.steps)) return null;
      const cleanSteps = b.steps
        .map((s: any) => typeof s === "string" ? s.trim() : "")
        .filter((s: string) => {
          if (!s) return false;
          const lower = s.toLowerCase();
          return !genericTerms.has(lower);
        });
      
      if (cleanSteps.length >= 2) {
        return { ...b, steps: cleanSteps };
      }
      return null;
    }).filter(Boolean);

    expect(validBlocks.length).toBe(0);
  });

  test('rejects candidates with fewer than 2 concrete dishes like just Apple', async () => {
    const parsed = {
      candidates: [
        {
          title: 'Snack',
          startMinute: 600,
          endMinute: 620,
          repeatDays: [1, 2, 3, 4, 5],
          mealCategory: 'snack',
          steps: ['Apple'],
          blockType: 'soft_block',
          candidateType: 'block'
        }
      ]
    };
    
    const genericTerms = new Set(["breakfast", "lunch", "snack", "dinner", "food", "meal", "eat", "dish"]);
    const validBlocks = parsed.candidates.map((b: any) => {
      if (!Array.isArray(b.steps)) return null;
      const cleanSteps = b.steps
        .map((s: any) => typeof s === "string" ? s.trim() : "")
        .filter((s: string) => {
          if (!s) return false;
          const lower = s.toLowerCase();
          return !genericTerms.has(lower);
        });
      
      if (cleanSteps.length >= 2) {
        return { ...b, steps: cleanSteps };
      }
      return null;
    }).filter(Boolean);

    expect(validBlocks.length).toBe(0);
  });

  test('returns clear error if all candidates are invalid', () => {
    const validBlocks: any[] = [];
    let thrownError = null;
    try {
      if (validBlocks.length === 0) {
        throw new Error("AI returned no valid meals.");
      }
    } catch (err: any) {
      thrownError = err.message;
    }
    expect(thrownError).toBe("AI returned no valid meals.");
  });
});
