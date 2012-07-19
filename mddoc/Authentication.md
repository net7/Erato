Talia3 authentication with Devise
=================================

Introduction
------------

Talia3 uses [Devise](https://github.com/plataformatec/devise Devise)
for authentication. 

Following Talia3 development philosophy, which is that Talia3 should
more of an application, ready to start right after `gem install`,
Devise initialization is already handled by the Talia3 Engine.

Talia3 also already has a Talia3::Auth::User model, with
an admin? flag, used in the default web application.

Applications that extend Talia3 can of course use, extend or ignore this.

__More documentation to follow__
