import { useState, useId, useRef } from 'react';
import { Button, Modal, Label, TextInput, Checkbox, Tooltip } from 'flowbite-react';

export function LoginPage() {
  const [ username, setUsername ] = useState( '' );
  const [ password, setPassword ] = useState( '' );
  const [ remember, setRemember ] = useState( false );
  const usernameId = useId();
  const passwordId = useId();
  const rememberId = useId();
  const initialRef = useRef();

  return (
    <Modal show size="md" initialFocus={ initialRef } popup>
      <Modal.Header>
        <h3 className="p-4">Sign In</h3>
      </Modal.Header>
      <Modal.Body>
        <div className="space-y-6">
          <div>
            <div className="mb-2 block">
              <Label htmlFor={ usernameId } value="Username" />
            </div>
            <TextInput
              id={ usernameId } type="text" ref={ initialRef } required
              value={ username } onChange={ e => setUsername( e.target.value ) } />
          </div>
          <div>
            <div className="mb-2 block">
              <Label htmlFor={ passwordId } value="Password" />
            </div>
            <TextInput
              id={ passwordId } type="password" required
              value={ password } onChange={ e => setPassword( e.target.value ) } />
          </div>
          <div className="flex justify-between items-center">
            <Tooltip content="Do not enable on shared computers!" className="self-end">
              <div className="flex items-center gap-2">
                <Checkbox id={ rememberId } />
                <Label htmlFor={ rememberId }>Remember me</Label>
              </div>
            </Tooltip>
            <Button type="submit">Login</Button>
          </div>
        </div>
      </Modal.Body>
    </Modal>
  );
}
