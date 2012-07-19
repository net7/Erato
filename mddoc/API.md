Talia3 HTTP API
===============

Authentication
--------------
Authentication in Talia API is token-based. Before any operation that
requires authentication you will need:

*   A Talia3 user with the correct permissions, identified by email
    and password.
*   To obtain an authorization token.
*   To append the authorization token to any future request that
    requires an authenticated user.

A token lasts, currently, for 2 hours.

Any successive authentication request with email and password will
create a new token, with a new 6-hours life period --any existing
token for the user will be extended.

If a new authentication is requested with an existing token, its
lifetime will be extended.

__Request:__
    POST /talia3/api/auth HTTP/1.1

__Parameters:__

*  __email__, __password__: user identification.
*  __token__: the authentication token itself --to renew it or confirm it.

__Responses__:
*  200 OK

__Examples__
Examples use curl in verbose mode, the response is edited for clarity.

Succesful login:

    curl -v -F "email=admin" -F "password=password" http://localhost:3000/talia3/api/auth
    
    HTTP/1.1 200 OK
    Content-Type: plain/text

    31fa786113118e70c34b3de6287266ee7affc168d59f9270b32a5214de5f793b


Unsuccesful login:
    curl -v -F "email=non-existent" -F "password=non-existent" http://localhost:3000/talia3/api/auth

    HTTP/1.1 401 Unauthorized
    Content-Type: plain/text

    Invalid authentication information.
