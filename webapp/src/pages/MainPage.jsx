import { Title } from "@/components/Title";
import { Progress } from "@/components/Progress";
import { StarRow } from "@/components/StarRow";
import { WinRow } from "@/components/WinRow";
import { Summary } from "@/components/Summary";

export function MainPage() {
  return (
    <>
      <Title />
      <div className="dbg flex flex-col max-w-screen-lg mx-auto">
        <Progress />
        <StarRow last />
        <WinRow />
      </div>
      <Summary />
    </>
  );
}
