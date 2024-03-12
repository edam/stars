import { useRef } from 'react';
import { Button, Modal, Label, TextInput, Checkbox, Tooltip } from 'flowbite-react';
import { FaRegQuestionCircle } from "react-icons/fa";

export function Confirm( props ) {
  const {
    title = "Are you sure?",
    ok = "Okay",
    cancel = "Cancel",
    onOk,
    onCancel,
    show,
    children,
  } = props;

  const okRef = useRef();

  return (
    <Modal show={ show } onClose={ onCancel } initialFocus={ okRef }>
    <Modal.Header>
      <div className="flex items-center">
        <FaRegQuestionCircle className="w-8 h-8 mr-3" />
        { title }
      </div>
    </Modal.Header>
    <Modal.Body className="space-y-4">
      { children }
    </Modal.Body>
    <Modal.Footer className="justify-end">
      <Button onClick={ onOk } ref={ okRef }>{ ok }</Button>
      <Button color="gray" onClick={ onCancel }>{ cancel }</Button>
    </Modal.Footer>
    </Modal>
  );
}
