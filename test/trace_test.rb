require "test_helper"

class TraceTest < Minitest::Spec
  class B < Trailblazer::Operation
    step ->(options, **) { options[:b] = true }, id: "B.task.b"
    step ->(options, **) { options[:e] = true }, id: "B.task.e"

    def self.call( (options, flow_options), **circuit_options )
      __call__( [Trailblazer::Context(options), flow_options], circuit_options )
    end
  end

  class Create < Trailblazer::Operation
    step ->(options, a_return:, **) { options[:a] = a_return }, id: "Create.task.a"
    step( {task: B, id: "MyNested"}, B.outputs[:success] => :success )
    step ->(options, **) { options[:c] = true }, id: "Create.task.c"
    step ->(options, params:, **) { params.any? }, id: "Create.task.params"

    def self.call( (options, flow_options), **circuit_options )
      __call__( [Trailblazer::Context(options), flow_options], circuit_options ) # FIXME.
    end
  end
  # raise Create["__task_wraps__"].inspect

  it "allows using low-level Activity::Trace" do
    operation = ->(*args) { puts "@@@@@ #{args.last.inspect}"; Create.__call__(*args) }

    stack, _ = Trailblazer::Activity::Trace.(
      Create,
      [
        { a_return: true, "params" => {} },
      ]
    )

    puts output = Trailblazer::Activity::Trace::Present.tree(stack)

    output.gsub(/0x\w+/, "").gsub(/@.+_test/, "").must_equal %{|-- #<Trailblazer::Activity::Start:>
|-- Create.task.a
|-- MyNested
|   |-- #<Trailblazer::Activity::Start:>
|   |-- B.task.b
|   |-- B.task.e
|   `-- #<Trailblazer::Operation::Railway::End::Success:>
|-- Create.task.c
|-- Create.task.params
`-- #<Trailblazer::Operation::Railway::End::Failure:>}
  end

  it "Operation::trace" do
    result = Create.trace({ x: 1 }, options={ a_return: true })
    result.wtf?.gsub(/0x\w+/, "").gsub(/@.+_test/, "").must_equal %{|-- #<Trailblazer::Activity::Start:>
|-- Create.task.a
|-- #<Proc:.rb:4 (lambda)>
|   |-- Start.default
|   |-- B.task.b
|   |-- B.task.e
|   |-- End.success
|   `-- #<Proc:.rb:4 (lambda)>
|-- Create.task.c
|-- Create.task.params
`-- End.success}
  end
end
