# typed: false
# frozen_string_literal: true

require "spec_helper"

describe("Tapioca::Compilers::Dsl::ActionMailer") do
  before(:each) do
    require "tapioca/compilers/dsl/action_mailer"
  end

  subject do
    Tapioca::Compilers::Dsl::ActionMailer.new
  end

  describe("#initialize") do
    def constants_from(content)
      with_content(content) do
        subject.processable_constants.map(&:to_s).sort
      end
    end

    it("gathers no constants if there are no ActionMailer subclasses") do
      assert_empty(subject.processable_constants)
    end

    it("gathers only ActionMailer subclasses") do
      content = <<~RUBY
        class NotifierMailer < ActionMailer::Base
        end

        class User
        end
      RUBY

      assert_equal(constants_from(content), ["NotifierMailer"])
    end

    it("gathers subclasses of ActionMailer subclasses") do
      content = <<~RUBY
        class NotifierMailer < ActionMailer::Base
        end

        class SecondaryMailer < NotifierMailer
        end
      RUBY

      assert_equal(constants_from(content), ["NotifierMailer", "SecondaryMailer"])
    end

    it("ignores abstract subclasses") do
      content = <<~RUBY
        class NotifierMailer < ActionMailer::Base
        end

        class AbstractMailer < ActionMailer::Base
          abstract!
        end
      RUBY

      assert_equal(constants_from(content), ["NotifierMailer"])
    end
  end

  describe("#decorate") do
    def rbi_for(content)
      with_content(content) do
        parlour = Parlour::RbiGenerator.new(sort_namespaces: true)
        subject.decorate(parlour.root, NotifierMailer)
        parlour.rbi
      end
    end

    it("generates empty RBI file if there are no methods") do
      content = <<~RUBY
        class NotifierMailer < ActionMailer::Base
        end
      RUBY

      expected = <<~RUBY
        # typed: strong
        class NotifierMailer
        end
      RUBY

      assert_equal(rbi_for(content), expected)
    end

    it("generates correct RBI file for subclass with methods") do
      content = <<~RUBY
        class NotifierMailer < ActionMailer::Base
          def notify_customer(customer_id)
            # ...
          end
        end
      RUBY

      expected = <<~RUBY
        # typed: strong
        class NotifierMailer
          sig { params(customer_id: T.untyped).returns(::ActionMailer::MessageDelivery) }
          def self.notify_customer(customer_id); end
        end
      RUBY

      assert_equal(rbi_for(content), expected)
    end

    it("generates correct RBI file for subclass with method signatures") do
      content = <<~RUBY
        class NotifierMailer < ActionMailer::Base
          extend T::Sig
          sig { params(customer_id: Integer).void }
          def notify_customer(customer_id)
            # ...
          end
        end
      RUBY

      expected = <<~RUBY
        # typed: strong
        class NotifierMailer
          sig { params(customer_id: Integer).returns(::ActionMailer::MessageDelivery) }
          def self.notify_customer(customer_id); end
        end
      RUBY

      assert_equal(rbi_for(content), expected)
    end

    it("does not generate RBI for methods defined in abstract classes") do
      content = <<~RUBY
        class AbstractMailer < ActionMailer::Base
          abstract!

          def helper_method
            # ...
          end
        end

        class NotifierMailer < AbstractMailer
          def notify_customer(customer_id)
            # ...
          end
        end
      RUBY

      expected = <<~RUBY
        # typed: strong
        class NotifierMailer
          sig { params(customer_id: T.untyped).returns(::ActionMailer::MessageDelivery) }
          def self.notify_customer(customer_id); end
        end
      RUBY

      assert_equal(rbi_for(content), expected)
    end
  end
end
