defmodule PhubMe.Queue do
    use Agent
    require Logger

    def start_link(bucket) do
        Logger.info("HEY")
        Agent.start_link(fn -> %{} end)
      end
      
      def start_link(bucket, name) do
        Agent.start_link(fn -> %{} end)
      end
    
      def put(bucket, key, value) do
        Agent.update(bucket, &Map.put(&1, key, value))
      end
    
      def get(bucket, key) do
        Agent.get(bucket, &Map.get(&1, key))
      end
  end