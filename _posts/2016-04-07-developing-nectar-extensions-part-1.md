---
layout: post
cover: 'assets/images/general-cover-3.jpg'
title: Developing Nectar Extensions Part 1
tags: docs
subclass: 'post tag-docs'
categories: 'elixir'
author: 'Nimish'
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
1. Running Multiple Elixir Apps Together
1. Extension Approach Explained
1. **Developer Experience and Workflow developing Favorite Product Extension**
1. Developer Experience and Workflow testing Favorite Product Extension



Developing Nectar Extensions Part 1
=================


### Where we left off ###


In the past few blogs we have learned how to write code that extends existing models, routers, added methods to override view rendering and run multiple phoenix application together in the same umbrella project. Let's Continue to build upon that and write our first extension for nectar (favorite products reference the original post here) and ultimately our store based on nectar.


### A layered guide to nectar extensions ###


__Setup__: Create a new phoenix application to hold the favorite products application, in your shell run inside the umbrella/apps folder:

<script src="https://gist.github.com/nimish-mehta/994e51defad0787eb88e6611219066fb.js?file=new_phoenix_application.bash"></script>

We could have gone with a regular mix application, but Phoenix/Ecto will come in handy in this case, since we want to have views to display stuff and a model to store data.

While we are at it let's configure our dev.exs and test.exs to use the same db as nectar, we could write some code and share the db settings between nectar and our extensions see: [running multiple phoenix application together]() for more details. But now for simplicity's sake we are  just copying the settings from nectar to get started.

__DB_SETTINGS__:

<script src="https://gist.github.com/nimish-mehta/49dcc6c0bcf6123f536ccc13220bf7ea.js"></script>

We need to let the extension manager know that this application is an extension for nectar.
Update the dependencies in extension\_manager/mix.exs with the favorite_products depenedency.

<script src="https://gist.github.com/nimish-mehta/418685331be5beb327c2890bc2257b0f.js"></script>

That should be enough to get us going.

__MODEL LAYER__: We want a nectar user to have some products to like and a way to remember them in short a join table and with two associations let's generate them:

<script src="https://gist.github.com/nimish-mehta/994e51defad0787eb88e6611219066fb.js?file=model_gen.bash"></script>

Now to point to correct nectar models. Open up the source and change the associations from favorite products model to nectar models. In the end we have a schema like:

<script src="https://gist.github.com/nimish-mehta/c6977aee042c259dc756846b20f0f476.js"></script>

Of, course this is only the extension view of this relationship, We want the nectar user to be aware of this relationship and most important of all, we should be able to do something like ```Nectar.User.liked_products(user)``` to fetch the products liked by user.

Time to call our handy macros written earlier to perform the compile time code injection. Let's create the nectar\_extension.ex file in favorite_products/lib/ directory and place this code there:

<script src="https://gist.github.com/nimish-mehta/c723dd21b0251d19b34c8e2f646e2398.js"></script>

Don't forget to update the install file in extensions_manager.

<script src="https://gist.github.com/nimish-mehta/116e7e7d0d3b03593e5184dff50c2a74.js"></script>

Now we have a user that can like products and product from which we can query which users liked it.

Time to play with what we have built so far, start a shell in nectar folder ```iex -S mix```

<script src="https://gist.github.com/nimish-mehta/2d8a3855496749e488c021f685e4115f.js"></script>

Oops, forgot the migration, remember we shared the db config earlier let's put that to use and run:

<script src="https://gist.github.com/nimish-mehta/994e51defad0787eb88e6611219066fb.js?file=migrate.bash"></script>

Which will migrate the user_likes table onto the original nectar database.

back to our shell

<script src="https://gist.github.com/nimish-mehta/d9f0fcf0b868b9a5869766dcd756b934.js"></script>


Voila!, we can now save and retrieve records to a relation we defined outside nectar from nectar models without actually modifying nectar code.

__VIEW LAYER__: Now that we can save the user likes, we should probably add an interface for the user to like them as well. Which leads us to the first shortcoming, in our current approach, we can replace existing views but right now we don't have anything for adding to an existing view(Please leave us a note [here]() if you know of a clean & performant method to do this). I also suspect most of us will end up overriding the existing views to something more custom then updating it piecemeal via extensions but I digress. For now let's have a page where we list all the products and user can mark them as liked or unlike the previously liked ones.

__controller__

<script src="https://gist.github.com/nimish-mehta/529ae0c19711ddc6cdd43ae3232a1a4d.js"></script>

Notice how we use the Nectar.Repo itself instead of using the FavoriteProducts.Repo, in-fact besides migration, we won't be utilizing or starting the FavoriteProducts.Repo, which will help us keep the number of connections open to database limited via only the Nectar.Repo

__the view file: index.html.eex__

<script src="https://gist.github.com/nimish-mehta/6721beb8eaa06859dbffcef48e99231a.js"></script>

In both of the files we refer to routes via NectarRoutes alias instead of favorite products.
To add the route from nectar, update nectar_extension.ex with the following code:

<script src="https://gist.github.com/nimish-mehta/b58e21723a335263e9efcd82b104d100.js"></script>

And add to install.ex the call:

<script src="https://gist.github.com/nimish-mehta/db7883f628837e7ebca5a1945c4d1bfe.js"></script>

Now we can see the added routes from nectar

<script src="https://gist.github.com/nimish-mehta/994e51defad0787eb88e6611219066fb.js?file=route.bash"></script>

So far so good, we have modified and added routes and controller to nectar's router. Time to see our handiwork in action, start the server from nectar application with:

<script src="https://gist.github.com/nimish-mehta/994e51defad0787eb88e6611219066fb.js?file=server.bash"></script>

and visit 127.0.0.1:4000/favorite and click on mark to like a product.

![Missing Layout](assets/images/before_layout.png){: .center-image }


But things don't seem right do they, our Nectar layout has been replaced with the default one used by phoenix. Let's rectify that.

Update layout_view.ex as:

<script src="https://gist.github.com/nimish-mehta/ceb97b1c0539f94d2a4bbf95b202a861.js"></script>

and recompile and restart the server

<script src="https://gist.github.com/nimish-mehta/994e51defad0787eb88e6611219066fb.js?file=compile.bash"></script>

On our next visit:

![Layout Present](assets/images/after_layout.png){: .center-image }

Much better.

> __Note__: When we need to change the extension code while running the server we will have to recompile and reload. We don't have anything in Nectar right now for monitor all extensions file and do an automatic compilation and code reload.


#Testing#
We are almost done now. To ensure that we know when things break we should add a few tests. For that we need to make sure that nectar migrations are run before running the migrations for favorite products and we need the nectar repo running as well.

For the former we could update the test_helper.ex with:

<script src="https://gist.github.com/nimish-mehta/795a1eacd54f876f774d3d91abcc8fb3.js"></script>

But things are not so smooth this time. Which brings us to what we think is the ultimate downfall of this approach:

### An Untestable soution ###

Ideally, running ```mix test``` should work and we should see our test running green, unfortunately this requires nectar to be compiled before running the tests, which is impossible since nectar depends upon the extension_manager to be compiled which depends upon all the extensions to be compiled, resulting in a cyclic dependency. Also we used nectar's repo for all database work. That works because we were running our server through nectar and the repo was started in Nectar's Supervision tree. Which again adds an implicit requirement Nectar application is available and ready to be started during test time or we could replace ```Nectar.Repo``` with ```FavoriteProducts.Repo``` if MIX_ENV=test, which is a can of worms we would rather avoid right now.

This seems like the end of the road for this approach. Where we are failing right now is making nectar available to extensions as a dependency at compile time and in turn test time. So that they can run independently. Let's try that in our second approach and reverse the dependency order.


>
_Our aim with these posts is to start a dialog with the Elixir community on validity and technical soundness of our approach. We would really appreciate your feedback and reviews, and any ideas/suggestions/pull requests for improvements to our current implementation or entirely different and better way to do things to achieve the goals we have set out for NectarCommerce._

_Enjoy the Elixir potion !!_
