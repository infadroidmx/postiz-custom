'use client';
import React from 'react';

export const Logo = () => {
  return (
    <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 400 100" width="100%" height="100%" className="mt-[8px] min-w-[200px] min-h-[60px]">
      <defs>
        <linearGradient id="grad" x1="0%" y1="0%" x2="100%" y2="0%">
          <stop offset="0%" stopColor="#713CE2" stopOpacity={1} />
          <stop offset="100%" stopColor="#6730D9" stopOpacity={1} />
        </linearGradient>
      </defs>
      <rect width="100%" height="100%" fill="none" />
      <text x="50%" y="55%" fontFamily="Arial, sans-serif" fontSize="54" fontWeight="bold" fill="url(#grad)" textAnchor="middle" dominantBaseline="middle">Infinate Post</text>
    </svg>
  );
};
