# Who Wants to Be a Millionaire

In order to win 1 million, you need to correctly answer 15 questions step by step from various fields of knowledge.
Each question has 4 possible answers, of which only one is correct. Each question has a specific cost.
The player is offered 3 tips: "Hall help", "50-50", "Call a friend".

This tutorial application was used to practice testing rail applications using RSpec.

## Ruby and Ruby on Rails version

- Ruby 2.4.1

- Rails  4.2.6

## The main gems used for test application:

`capybara`, `factory_bot_rails`, `launchy`, `pry-rails`, `rails-controller-testing`, `rspec-rails`, `shoulda-matchers`

## Deploy app

Note: all commands must be run from the command line/terminal, from the directory, where you clone repository

1. Download or clone repository, then run bundler

```ruby
bundle exec install
```

2. To create a database, run

```ruby
rails db:schema:load
```

## How to run tests

To run all tests, typing

```ruby
rspec
```

## How to run app

To start the Rails server, type

```ruby
rails s
```

## How to play

1. From Rails console, create user with admin role

```ruby
rails c

User.create!(name: 'Ivan', email: 'mail@mail.com', is_admin: true, balance: 0, password: '123456')
```

2. Login to the application and click the "Add Questions" button. You can use ready-made questions from the
   archive in folder `data/questions_full.zip`
