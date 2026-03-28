import React from 'react';

export const LogoTextComponent = () => {
  return (
    <div className="flex items-center gap-[12px]">
      <span className="text-[24px] font-semibold tracking-tight text-white whitespace-nowrap">
        Infinate Post
      </span>
      <img
        src="/logo-transparent.png"
        alt="Infinate Post"
        className="h-[40px] w-[40px] object-contain"
      />
    </div>
  );
};
