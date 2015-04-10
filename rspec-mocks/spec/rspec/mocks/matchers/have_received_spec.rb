module RSpec
  module Mocks
    RSpec.describe Matchers::HaveReceived do
      describe "expect(...).to have_received" do
        it 'passes when the double has received the given message' do
          dbl = double_with_met_expectation(:expected_method)
          expect(dbl).to have_received(:expected_method)
        end

        it 'passes when a null object has received the given message' do
          dbl = null_object_with_met_expectation(:expected_method)
          expect(dbl).to have_received(:expected_method)
        end

        it 'fails when the double has not received the given message' do
          dbl = double_with_unmet_expectation(:expected_method)

          expect {
            expect(dbl).to have_received(:expected_method)
          }.to raise_error(/expected: 1 time/)
        end

        it 'fails when a null object has not received the given message' do
          dbl = double.as_null_object

          expect {
            expect(dbl).to have_received(:expected_method)
          }.to raise_error(/expected: 1 time/)
        end

        it 'fails when the method has not been previously stubbed' do
          dbl = double

          expect {
            expect(dbl).to have_received(:expected_method)
          }.to raise_error(/method has not been stubbed/)
        end

        it 'fails when the method has been mocked' do
          dbl = double
          expect(dbl).to receive(:expected_method)
          dbl.expected_method

          expect {
            expect(dbl).to have_received(:expected_method)
          }.to raise_error(/method has been mocked instead of stubbed/)
        end

        it "takes a curly-bracket block and yields the arguments given to the stubbed method call" do
          dbl = double(:foo => nil)
          yielded = []
          dbl.foo(:a, :b, :c)
          expect(dbl).to have_received(:foo) { |*args|
            yielded << args
          }
          expect(yielded).to include([:a,:b,:c])
        end

        it "takes a do-end block and yields the arguments given to the stubbed method call" do
          dbl = double(:foo => nil)
          yielded = []
          dbl.foo(:a, :b, :c)
          expect(dbl).to have_received(:foo) do |*args|
            yielded << args
          end
          expect(yielded).to include([:a,:b,:c])
        end

        it "passes if expectations against the yielded arguments pass" do
          dbl = double(:foo => nil)
          dbl.foo(42)
          expect {
            expect(dbl).to have_received(:foo) { |arg|
              expect(arg).to eq(42)
            }
          }.to_not raise_error
        end

        it "fails if expectations against the yielded arguments fail" do
          dbl = double(:foo => nil)
          dbl.foo(43)
          expect {
            expect(dbl).to have_received(:foo) { |arg|
              expect(arg).to eq(42)
            }
          }.to raise_error(RSpec::Expectations::ExpectationNotMetError)
        end

        it 'gives precedence to a `{ ... }` block when both forms are provided ' +
           'since that form actually binds to `receive`' do
          dbl = double(:foo => nil)
          called = []
          dbl.foo
          expect(dbl).to have_received(:foo) { called << :curly } do
            called << :do_end
          end
          expect(called).to include(:curly)
          expect(called).not_to include(:do_end)
        end

        it 'resets expectations on class methods when mocks are reset' do
          dbl = Object
          allow(dbl).to receive(:expected_method)
          dbl.expected_method
          reset dbl
          allow(dbl).to receive(:expected_method)

          expect {
            expect(dbl).to have_received(:expected_method)
          }.to raise_error(/0 times/)
        end

        context "with" do
          it 'passes when the given args match the args used with the message' do
            dbl = double_with_met_expectation(:expected_method, :expected, :args)
            expect(dbl).to have_received(:expected_method).with(:expected, :args)
          end

          it 'fails when the given args do not match the args used with the message' do
            dbl = double_with_met_expectation(:expected_method, :expected, :args)

            expect {
              expect(dbl).to have_received(:expected_method).with(:unexpected, :args)
            }.to raise_error(/with unexpected arguments/)
          end
        end

        it 'generates a useful description' do
          matcher = have_received(:expected_method).with(:expected_args).once
          expect(matcher.description).to eq 'have received expected_method(:expected_args) 1 time'
        end

        it 'can generate a description after mocks have been torn down (e.g. when rspec-core requests it)' do
          matcher = have_received(:expected_method).with(:expected_args).once
          matcher.matches?(double(:expected_method => 1))
          RSpec::Mocks.teardown
          expect(matcher.description).to eq 'have received expected_method(:expected_args) 1 time'
        end

        context "counts" do
          let(:the_dbl) { double(:expected_method => nil) }

          before do
            the_dbl.expected_method(:one)
            the_dbl.expected_method(:two)
            the_dbl.expected_method(:one)
          end

          context "when constrained by `with`" do
            it 'only considers the calls with matching args' do
              expect(the_dbl).to have_received(:expected_method).with(:one).twice
              expect(the_dbl).to have_received(:expected_method).with(:two).once
            end

            context "when the message is received without any args matching" do
              it 'includes unmatched args in the error message' do
                expect {
                  expect(the_dbl).to have_received(:expected_method).with(:three).once
                }.to fail_including("expected: (:three)",
                                    "got:", "(:one) (2 times)",
                                    "(:two) (1 time)")
              end
            end

            context "when the message is received too many times" do
              it 'includes the counts of calls with matching args in the error message' do
                expect {
                  expect(the_dbl).to have_received(:expected_method).with(:one).once
                }.to fail_including("expected: 1 time", "received: 2 times")
              end
            end

            context "when the message is received too few times" do
              it 'includes the counts of calls with matching args in the error message' do
                expect {
                  expect(the_dbl).to have_received(:expected_method).with(:two).twice
                }.to fail_including("expected: 2 times", "received: 1 time")
              end
            end

            context "when contrained with grouped arguments `with`" do
              it 'groups the "got" arguments based on the method call that included them' do
                dbl = double(:expected_method => nil)
                dbl.expected_method(:one, :four)
                dbl.expected_method(:two, :four)
                dbl.expected_method(:three, :four)
                dbl.expected_method(:one, :four)
                dbl.expected_method(:three, :four)
                dbl.expected_method(:three, :four)

                expect {
                  expect(dbl).to have_received(:expected_method).with(:four, :four).once
                }.to fail_including("expected: (:four, :four)",
                                    "got:","(:one, :four) (2 times)",
                                    "(:two, :four) (1 time)",
                                    "(:three, :four) (3 times)")
              end

              it 'includes single arguments based on the method call that included them' do
                dbl = double(:expected_method => nil)
                dbl.expected_method(:one, :four)

                expect {
                  expect(dbl).to have_received(:expected_method).with(:three, :four).once
                }.to fail_including("expected: (:three, :four)", "got: (:one, :four)")
              end

              it 'keeps the array combinations distinguished in the group' do
                dbl = double(:expected_method => nil)
                dbl.expected_method([:one], :four)
                dbl.expected_method(:one, [:four])

                expect {
                  expect(dbl).to have_received(:expected_method).with(:one, :four).once
                }.to fail_including("expected: (:one, :four)",
                                    "got:","([:one], :four)",
                                    "(:one, [:four])")
              end

              it 'does not group counts on repeated arguments for a single message' do
                dbl = double(:expected_method => nil)
                dbl.expected_method(:one, :one, :two)

                expect {
                  expect(dbl).to have_received(:expected_method).with(:one, :two, :three).once
                }.to fail_including("expected: (:one, :two, :three)", "got:","(:one, :one, :two)")
              end
            end
          end

          context "exactly" do
            it 'passes when the message was received the given number of times' do
              expect(the_dbl).to have_received(:expected_method).exactly(3).times
            end

            it 'fails when the message was received more times than expected' do
              expect {
                expect(the_dbl).to have_received(:expected_method).exactly(1).times
              }.to raise_error(/expected: 1 time.*received: 3 times/m)
              expect {
                expect(the_dbl).to have_received(:expected_method).exactly(2).times
              }.to raise_error(/expected: 2 times.*received: 3 times/m)
              expect {
                the_dbl.expected_method
                the_dbl.expected_method
                expect(the_dbl).to have_received(:expected_method).exactly(2).times
              }.to raise_error(/expected: 2 times.*received: 5 times/m)
            end

            it 'fails when the message was received fewer times' do
              expect {
                expect(the_dbl).to have_received(:expected_method).exactly(4).times
              }.to raise_error(/expected: 4 times.*received: 3 times/m)
            end
          end

          context 'at_least' do
            it 'passes when the message was received the given number of times' do
              expect(the_dbl).to have_received(:expected_method).at_least(3).times
            end

            it 'passes when the message was received more times' do
              expect(the_dbl).to have_received(:expected_method).at_least(2).times
            end

            it 'fails when the message was received fewer times' do
              expect {
                expect(the_dbl).to have_received(:expected_method).at_least(4).times
              }.to raise_error(/expected: at least 4 times.*received: 3 times/m)
            end
          end

          context 'at_most' do
            it 'passes when the message was received the given number of times' do
              expect(the_dbl).to have_received(:expected_method).at_most(3).times
            end

            it 'passes when the message was received fewer times' do
              expect(the_dbl).to have_received(:expected_method).at_most(4).times
            end

            it 'fails when the message was received more times' do
              expect {
                expect(the_dbl).to have_received(:expected_method).at_most(2).times
              }.to raise_error(/expected: at most 2 times.*received: 3 times/m)
            end
          end

          context 'once' do
            it 'passes when the message was received once' do
              dbl = double(:expected_method => nil)
              dbl.expected_method
              expect(dbl).to have_received(:expected_method).once
            end

            it 'fails when the message was never received' do
              dbl = double(:expected_method => nil)

              expect {
                expect(dbl).to have_received(:expected_method).once
              }.to raise_error(/expected: 1 time.*received: 0 times/m)
            end

            it 'fails when the message was received twice' do
              dbl = double(:expected_method => nil)
              dbl.expected_method
              dbl.expected_method

              expect {
                expect(dbl).to have_received(:expected_method).once
              }.to raise_error(/expected: 1 time.*received: 2 times/m)
            end
          end

          context 'twice' do
            it 'passes when the message was received twice' do
              dbl = double(:expected_method => nil)
              dbl.expected_method
              dbl.expected_method

              expect(dbl).to have_received(:expected_method).twice
            end

            it 'fails when the message was received once' do
              dbl = double(:expected_method => nil)
              dbl.expected_method

              expect {
                expect(dbl).to have_received(:expected_method).twice
              }.to raise_error(/expected: 2 times.*received: 1 time/m)
            end

            it 'fails when the message was received thrice' do
              dbl = double(:expected_method => nil)
              dbl.expected_method
              dbl.expected_method
              dbl.expected_method

              expect {
                expect(dbl).to have_received(:expected_method).twice
              }.to raise_error(/expected: 2 times.*received: 3 times/m)
            end
          end

          context 'thrice' do
            it 'passes when the message was received thrice' do
              dbl = double(:expected_method => nil)
              dbl.expected_method
              dbl.expected_method
              dbl.expected_method

              expect(dbl).to have_received(:expected_method).thrice
            end

            it 'fails when the message was received less than three times' do
              dbl = double(:expected_method => nil)
              dbl.expected_method
              dbl.expected_method

              expect {
                expect(dbl).to have_received(:expected_method).thrice
              }.to raise_error(/expected: 3 times.*received: 2 times/m)
            end

            it 'fails when the message was received more than three times' do
              dbl = double(:expected_method => nil)
              dbl.expected_method
              dbl.expected_method
              dbl.expected_method
              dbl.expected_method

              expect {
                expect(dbl).to have_received(:expected_method).thrice
              }.to raise_error(/expected: 3 times.*received: 4 times/m)
            end
          end
        end

        context 'ordered' do
          let(:the_dbl) { double :one => 1, :two => 2, :three => 3 }

          it 'passes when the messages were received in order' do
            the_dbl.one
            the_dbl.two

            expect(the_dbl).to have_received(:one).ordered
            expect(the_dbl).to have_received(:two).ordered
          end

          it 'passes with exact receive counts when received in order' do
            3.times { the_dbl.one }
            2.times { the_dbl.two }
            the_dbl.three

            expect(the_dbl).to have_received(:one).thrice.ordered
            expect(the_dbl).to have_received(:two).twice.ordered
            expect(the_dbl).to have_received(:three).once.ordered
          end

          it 'passes with at most receive counts when received in order', :ordered_and_vauge_counts_unsupported do
            the_dbl.one
            the_dbl.one
            the_dbl.two

            expect(the_dbl).to have_received(:one).at_most(3).times.ordered
            expect(the_dbl).to have_received(:one).at_most(:thrice).times.ordered
            expect(the_dbl).to have_received(:two).once.ordered
          end

          it 'passes with at least receive counts when received in order', :ordered_and_vauge_counts_unsupported do
            the_dbl.one
            the_dbl.one
            the_dbl.two

            expect(the_dbl).to have_received(:one).at_least(1).times.ordered
            expect(the_dbl).to have_received(:two).once.ordered
          end

          it 'fails with exact receive counts when received out of order' do
            the_dbl.one
            the_dbl.two
            the_dbl.one

            expect {
              expect(the_dbl).to have_received(:one).twice.ordered
              expect(the_dbl).to have_received(:two).once.ordered
            }.to raise_error(/received :two out of order/m)
          end

          it "fails with at most receive counts when recieved out of order", :ordered_and_vauge_counts_unsupported do
            the_dbl.one
            the_dbl.two
            the_dbl.one

            expect {
              expect(the_dbl).to have_received(:one).at_most(2).times.ordered
              expect(the_dbl).to have_received(:two).once.ordered
            }.to raise_error(/received :two out of order/m)
          end

          it "fails with at least receive counts when recieved out of order", :ordered_and_vauge_counts_unsupported do
            the_dbl.one
            the_dbl.two
            the_dbl.one

            expect {
              expect(the_dbl).to have_received(:one).at_least(1).times.ordered
              expect(the_dbl).to have_received(:two).once.ordered
            }.to raise_error(/received :two out of order/m)
          end

          it 'fails when the messages are received out of order' do
            the_dbl.two
            the_dbl.one

            expect {
              expect(the_dbl).to have_received(:one).ordered
              expect(the_dbl).to have_received(:two).ordered
            }.to raise_error(/received :two out of order/m)
          end

          context "when used with `with`" do
            before do
              the_dbl.one(1)
              the_dbl.one(2)
            end

            it "passes when the order lines up" do
              expect(the_dbl).to have_received(:one).with(1).ordered
              expect(the_dbl).to have_received(:one).with(2).ordered
            end

            it "fails when the order is not matched" do
              expect {
                expect(the_dbl).to have_received(:one).with(2).ordered
                expect(the_dbl).to have_received(:one).with(1).ordered
              }.to fail_with(/received :one out of order/m)
            end
          end

          context "when used on individually allowed messages" do
            before do
              allow(the_dbl).to receive(:foo)
              allow(the_dbl).to receive(:bar)

              the_dbl.foo
              the_dbl.bar
            end

            it 'passes when the messages were received in order' do
              expect(the_dbl).to have_received(:foo).ordered
              expect(the_dbl).to have_received(:bar).ordered
            end

            it 'fails when the messages are received out of order' do
              expect {
                expect(the_dbl).to have_received(:bar).ordered
                expect(the_dbl).to have_received(:foo).ordered
              }.to raise_error(/received :foo out of order/m)
            end
          end
        end
      end

      describe "expect(...).not_to have_received" do
        it 'passes when the double has not received the given message' do
          dbl = double_with_unmet_expectation(:expected_method)
          expect(dbl).not_to have_received(:expected_method)
        end

        it 'fails when the double has received the given message' do
          dbl = double_with_met_expectation(:expected_method)

          expect {
            expect(dbl).not_to have_received(:expected_method)
          }.to raise_error(/expected: 0 times.*received: 1 time/m)
        end

        it 'fails when the method has not been previously stubbed' do
          dbl = double

          expect {
            expect(dbl).not_to have_received(:expected_method)
          }.to raise_error(/method has not been stubbed/)
        end

        context "with" do
          it 'passes when the given args do not match the args used with the message' do
            dbl = double_with_met_expectation(:expected_method, :expected, :args)
            expect(dbl).not_to have_received(:expected_method).with(:unexpected, :args)
          end

          it 'fails when the given args match the args used with the message' do
            dbl = double_with_met_expectation(:expected_method, :expected, :args)

            expect {
              expect(dbl).not_to have_received(:expected_method).with(:expected, :args)
            }.to raise_error(/expected: 0 times.*received: 1 time/m) # TODO: better message
          end
        end

        %w(exactly at_least at_most times once twice).each do |constraint|
          it "does not allow #{constraint} to be used because it creates confusion" do
            dbl = double_with_unmet_expectation(:expected_method)
            expect {
              expect(dbl).not_to have_received(:expected_method).send(constraint)
            }.to raise_error(/can't use #{constraint} when negative/)
          end
        end
      end

      describe "allow(...).to have_received" do
        it "fails because its nonsensical" do
          expect {
            allow(double).to have_received(:some_method)
          }.to fail_with("Using allow(...) with the `have_received` matcher is not supported as it would have no effect.")
        end
      end

      describe "allow_any_instance_of(...).to have_received" do
        it "fails because its nonsensical" do
          expect {
            allow_any_instance_of(double).to have_received(:some_method)
          }.to fail_with("Using allow_any_instance_of(...) with the `have_received` matcher is not supported.")
        end
      end

      describe "expect_any_instance_of(...).to have_received" do
        it "fails because we dont want to support it" do
          expect {
            expect_any_instance_of(double).to have_received(:some_method)
          }.to fail_with("Using expect_any_instance_of(...) with the `have_received` matcher is not supported.")
        end
      end

      def double_with_met_expectation(method_name, *args)
        double = double_with_unmet_expectation(method_name)
        meet_expectation(double, method_name, *args)
      end

      def null_object_with_met_expectation(method_name, *args)
        meet_expectation(double.as_null_object, method_name, *args)
      end

      def meet_expectation(double, method_name, *args)
        double.send(method_name, *args)
        double
      end

      def double_with_unmet_expectation(method_name)
        double('double', method_name => true)
      end

      # Override `fail_including` for this context, since `have_received` is a normal
      # rspec-expectations matcher, the error class is different.
      def fail_including(*snippets)
        raise_error(RSpec::Expectations::ExpectationNotMetError, a_string_including(*snippets))
      end
    end
  end
end
