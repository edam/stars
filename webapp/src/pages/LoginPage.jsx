import { useState, useId, useRef, useContext, useEffect } from 'react';
import { Button, Modal, Label, TextInput, Checkbox, Tooltip, Spinner, Alert } from 'flowbite-react';
import { Confirm } from '@/components/Confirm';
import { AuthContext } from '@/contexts/Auth';
import { FiArrowRightCircle } from "react-icons/fi";
import { HiInformationCircle } from 'react-icons/hi';

export function LoginPage() {
  const [ errors, setErrors ] = useState( {} );
  const usernameId = useId();
  const passwordId = useId();
  const rememberId = useId();
  const usernameRef = useRef();
  const passwordRef = useRef();
  const [ confirm, setConfirm ] = useState( false );
  const { loading, login, error, username: lastUsername, loggedOut, recalled } =
        useContext( AuthContext );
  const [ form, setForm ] = useState( {
    username: '',
    password: '',
    remember: false,
  } );

  function focusPassword() {
    // if( passwordRef.current )
    //   passwordRef.current.focus();
    // else
    //   setTimeout( () => passwordRef.current.focus(), 0 );
  }

  useEffect( () => {
    if( lastUsername ) {
      setForm( form => ( { ...form, username: lastUsername || form.username } ) );
      focusPassword();
    }
  }, [ lastUsername ] );

  useEffect( () => {
    if( error ) {
      setForm( form => ( { ...form, password: '' } ) );
      focusPassword();
    }
  }, [ error ] );

  function handleChange( e ) {
    const { name, value } = e.target;
    setForm( { ...form, [name]: value } );
  }

  function handleChangeRemember( e ) {
    setForm( { ...form, remember: e.target.checked } );
    setConfirm( e.target.checked );
  }

  function handleCancelConfirm( e ) {
    setForm( { ...form, remember: false } );
    setConfirm( false );
  }

  function validateForm() {
    const errors = {};
    if( !form.username ) {
      errors.username = 'Required field';
    } else if( !form.username.match( /^[0-9a-z_]+$/i ) ) {
      errors.username = 'Only use alphanumeric characters and underscore';
    }
    if( !form.password ) {
      errors.password = 'Required field';
    }
    setErrors( errors );
    return Object.keys( errors ).length == 0;
  }

  function handleSubmit( e ) {
    e.preventDefault();
    if( validateForm() ) {
      login( form.username, form.password, form.remember );
    }
  }

  if( loading && recalled ) {
    return (
      <Modal show size="md" popup>
        <div className="flex items-center m-4">
          <div className="grow">Reconnecting...</div>
          <Spinner size="lg" className="mr-2" />
        </div>
      </Modal>
    );
  }

  return (
    <>
      <Modal show size="md" initialFocus={ usernameRef } popup>
        <Modal.Header>Sign In</Modal.Header>
        <Modal.Body>
          <form className="space-y-6">
            <div>
              <div className="mb-2 block">
                <Label htmlFor={ usernameId } value="Username" />
              </div>
              <TextInput type="text" disabled={ loading }
                         name="username" id={ usernameId } ref={ usernameRef }
                         value={ form.username } onChange={ handleChange }
                         color={ errors.username? "failure" : "gray" }
                         helperText={ errors.username } />
            </div>
            <div>
              <div className="mb-2 block">
                <Label htmlFor={ passwordId } value="Password" />
              </div>
              <TextInput type="password" disabled={ loading }
                         name="password" id={ passwordId } ref={ passwordRef }
                         value={ form.password } onChange={ handleChange }
                         color={ errors.password? "failure" : "gray" }
                         helperText={ errors.password } />
            </div>
            <div className="flex justify-between items-center">
              <Tooltip content="Do not enable on shared computers!"
                       className="self-end">
                <div className="flex items-center gap-2">
                  <Checkbox name="remember" id={ rememberId }
                            disabled={ loading } checked={ form.remember }
                            onChange={ handleChangeRemember } />
                  <Label htmlFor={ rememberId }>Remember me</Label>
                </div>
              </Tooltip>
              <div className="flex items-center">
                { loading && <Spinner size="lg" className="mr-2" /> }
                <Button type="submit" disabled={ loading }
                        onClick={ handleSubmit }>
                  Login
                  <FiArrowRightCircle className="ml-2 h-5 w-5" />
                </Button>
              </div>
            </div>
            { error && (
              <Alert size="lg" color="failure" icon={ HiInformationCircle }>
                { error }
              </Alert>
            ) }
            { loggedOut && (
              <Alert size="lg" color="warning" icon={ HiInformationCircle }>
                You were logged out.
              </Alert>
            ) }
          </form>
        </Modal.Body>
      </Modal>
      <Confirm show={ confirm } title="Is this a private computer?"
               onOk={ e => setConfirm( false ) }
               onCancel={ handleCancelConfirm }>
        <p>Enabling "remember me" on a shared computer will give anyone using it
        access to your account.</p>
        <p>Are you sure you want to remember your login?</p>
      </Confirm>
    </>
  );
}
