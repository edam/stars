import { Star } from '@/components/Star';

export function StarRow() {
  return (
    <div className="dbg flex max-sm:flex-col">
      <div className="dbg basis-3/4 flex">
        <Star got={ true } />
        <Star got={ false } />
        <Star unknown={ true } />
        <Star unknown={ true } />
        <Star unknown={ true } />
      </div>
      <div className="dbg basis-1/4">
        wkinf
      </div>
    </div>
  );
}
