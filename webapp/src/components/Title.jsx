import { useContext } from 'react';
import { Avatar, Dropdown } from "flowbite-react";
import { AuthContext } from '@/contexts/Auth';
import { HiCog, HiLogout } from "react-icons/hi";


export function Title() {
  const { username, logout } = useContext( AuthContext );

  return (
    <div className="bg-white drop-shadow-xl">
      <div className="flex max-w-screen-lg mx-auto items-center">
        <h1 className="grow text-2xl font-extrabold m-2">Daily Stars</h1>
        <div className="hover:bg-gray-100">
          <Dropdown
            arrowIcon={ false }
            inline
            label={
              <Avatar rounded className="m-2" />
            }>
            <Dropdown.Header>Hi, { username }!</Dropdown.Header>
            <Dropdown.Divider />
            <Dropdown.Item icon={ HiCog }>
              Settings
            </Dropdown.Item>
            <Dropdown.Item icon={ HiLogout } onClick={ logout }>
              Logout
            </Dropdown.Item>
          </Dropdown>
        </div>
      </div>
    </div>
  );
}
