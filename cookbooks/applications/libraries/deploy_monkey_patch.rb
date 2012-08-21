class Chef
  class Resource
    class Deploy < Chef::Resource
      def on_start(arg=nil, &block)
        arg ||= block
        set_or_return(:on_start, arg, :kind_of => [Proc, String])
      end

      def on_complete(arg=nil, &block)
        arg ||= block
        set_or_return(:on_complete, arg, :kind_of => [Proc, String])
      end

      def on_error(arg=nil, &block)
        arg ||= block
        set_or_return(:on_error, arg, :kind_of => [Proc, String])
      end
    end
  end
end

class Chef
  class Provider
    class Deploy < Chef::Provider
      alias :old_deploy :deploy unless method_defined? :old_deploy

      def deploy
        begin
          callback(:on_start, @new_resource.on_start)
          old_deploy
          callback(:on_complete, @new_resource.on_complete)
        rescue => e
          callback(:on_error, @new_resource.on_error)
          raise e
        end
      end

      def short_release_slug
        release_slug[0...6]
      end
    end
  end
end
