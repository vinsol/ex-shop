---
layout: post
cover: 'assets/images/general-cover-3.jpg'
title: Running Multiple Apps in Umbrella Project
tags: docs
subclass: 'post tag-docs'
categories: 'elixir'
author: 'Pikender'
navigation: true
logo: 'assets/images/nectar-cart.png'
---

>
The post belongs to _NectarCommerce and Extension Framework Awareness_ Series
>
1. _[NectarCommerce Vision](http://vinsol.com/blog/2016/04/08/nectarcommerce-vision/)_
1. _[Extension Framework Game Plan](http://vinsol.com/blog/2016/04/12/extension-framework-game-plan/)_
1. _[Introduction to Metaprogramming](http://vinsol.com/blog/2016/04/14/introduction-to-metaprogramming/)_
1. _[Ecto Model Schema Extension](http://vinsol.com/blog/2016/04/15/ecto-model-schema-extension/)_
1. Ecto Model Support Functions Extension
1. Phoenix Router Extension
1. Phoenix View Extension
1. **Running Multiple Elixir Apps Together**
1. Extension Approach Explained
1. Developer Experience and Workflow developing Favorite Product Extension
1. Developer Experience and Workflow testing Favorite Product Extension

## What will be NectarCommerce

>
Off-the-shelf Opensource E-commerce application for building an online store.
>
Provides an Extension Framework to support features not included in core as extensions.
>
Strives for unobtrusive parallel development of NectarCommerce and Extensions

NectarCommerce is committed to providing a ready-to-use e-commerce solution but the definition of 100% is different under different business domains. It aims to solve common use-cases as part of the project and relying on extension framework to tap the rest.

# Elixir Umbrella Project

[Elixir Umbrella Project](http://elixir-lang.org/getting-started/mix-otp/dependencies-and-umbrella-apps.html#umbrella-projects
) is a convenience to help you organize and manage your applications. Applications inside the apps directory are still decoupled from each other. Dependencies between them must be explicitly listed. This allows them to be developed together, but compiled, tested and deployed independently if desired.

As NectarCommerce extensions are envisioned to use with Nectar and would be dependent on Nectar directly or indirectly, we chose umbrella project to have Nectar, extensions\_manager, user\_app, and extensions apps as part of it.

We plan to use `phoenix app` for extensions where web-component is needed and which would be part of umbrella project.

The `user_app` would be a resting ground where Nectar and extensions are evaluated for compile time requirements and prepared to be used together.

As of now, `user_app` has following responsibilities:

- [defining nectar as umbrella dependency](https://github.com/vinsol/nectarcommerce/pull/47/files#diff-cfadcd558b7d7d0fa0bb1b43ff49ba98R44)
- [defining available extensions as umbrella dependencies](https://github.com/vinsol/nectarcommerce/pull/47/files#diff-cfadcd558b7d7d0fa0bb1b43ff49ba98R45)
- [acting as a pass-through for all the outbound requests](https://github.com/vinsol/nectarcommerce/pull/47/files#diff-02eb191c0680951b40ba159f4163a7c6R21)

## Running Multiple Phoenix Applications together in an umbrella ##

Phoenix applications are in the end just another OTP application, with a few modifications and configuration tweaks we can expect them to run together in same umbrella project. We need to make sure that

1. They share the same configuration for database, while not mandatory if all the applications are utilizing the same databases, keeping the configuration in one place is a good practice. We can create a ```shared_config.exs``` at root of umbrella with some code like this:
	
	
	```elixir
	config :shared, :db_config,
	  username: "shared_username",
	  pool_size: 200
	```
	
	And, then in each individual application at the end of file:
	
	```elixir
	shared_db_config = Mix.Config.read!("../../shared_config.exs")[:shared][:db_config]
	config :app, App.Repo, shared_db_config
	```
	
	Obviously this is use case dependent some applications may not share a database and only rely on each other for method calls.

2. Starting the phoenix server. If we look closely at the application file for our phoenix app, we can see a supervisor for endpoint, this starts the phoenix server and binds it to the port.

   We can either start the application on different ports and use an external server like nginx to dispatch on appropriate port based on business requirements.

   We can also use forwards at the end of route files, using the ```forward "/", App.router```. from one of the application and start the server from there.

   If we go with the **latter approach** we need to [make sure that only the endpoint supervisor of current application is in supervision tree](https://github.com/vinsol/nectarcommerce/pull/47/files#diff-001ce116edeff3304fe941b84c128c5dR12). Else we will get an address already in use error.

3. Sharing static assets, we can config brunch to watch the static folder of other applications as well.

4. Ensure that if using the single server approach, all other applications are listed in the dependency of the main/master application. this will ensure they are compiled beforehand and can be freely used throughout the main application.

### Phoenix Framework commands aware of Umbrella project

- [Forwarding Requests to other Phoenix.Router](https://hexdocs.pm/phoenix/Phoenix.Router.html#forward/4)
    - `forward "/", Nectar.Router`
    - All paths that matches the forwarded prefix will be sent to the forwarded plug.This is useful to share router between applications or even break a big router into smaller ones.
- **DB Migration**, mention the Ecto Repo
    - `mix ecto.migrate -r Nectar.Repo`
    - `mix ecto.migrate -r ExtensionApp.Repo`
- **Listing Routes**, mention the Phoenix Router
    - `mix phoenix.routes Nectar.Router`
    - `mix phoenix.routes ExtensionApp.Router`

## Few Tricks

- Using View Layout of Nectar from extensions
    - `defdelegate render(template, assigns), to: Nectar.LayoutView`
- Using Routes of Nectar in extensions
    - `alias Nectar.Router.Helpers, as: NectarRoutes`
    - `NectarRoutes.favorite_path(conn, :index)`
    - `alias` are resolved at runtime, so routes can be used but compile-time checks can't be used :(

>
_Our aim with these posts is to start a dialog with the Elixir community on validity and technical soundness of our approach. We would really appreciate your feedback and reviews, and any ideas/suggestions/pull requests for improvements to our current implementation or entirely different and better way to do things to achieve the goals we have set out for NectarCommerce._

_Enjoy the Elixir potion !!_
