defmodule GoogleSheets.Updater do

  use GenServer
  require Logger

  def start_link(config, options \\ []) do
    GenServer.start_link(__MODULE__, config, options)
  end

  def init(config) do
    # Send the first poll request immediately
    Process.send_after self(), :update, 0
    {:ok, config}
  end

  def handle_info(:update, config) do
    handle_update config
    {:noreply, config}
  end

  # Internal implementation
  defp handle_update(config) do
    Logger.debug "Requesting CSV data for spreadsheet #{config[:id]}"
    handle_load(config, GoogleSheets.Loader.load(config[:key], config[:worksheets]))
  end

  defp handle_load(config, {:ok, data}) do
    data = on_loaded config, data
    :ets.insert ets_table, {config[:id], data}
    on_saved config
    schedule_update config[:delay]
  end
  defp handle_load(_config, {:error, msg}) do
    # Schedule an update again immediately if the request failed.
    # Note: This means we will keep trying to fetch data at least once, even if delay is 0
    Logger.debug "Failed to load data from google sheets, scheduling update immediately. Reason: #{inspect msg}"
    schedule_update 1
  end

  # If delay has been configured to 0, the update will be done only once.
  defp schedule_update(0) do
    Logger.debug "Stopping scheduled updates"
  end
  defp schedule_update(delay) do
    Logger.debug "Next update in #{delay} seconds"
    Process.send_after self(), :update, delay * 1000
  end

  # Let the host application do what ever they want with the data
  defp on_loaded(config, data) do
    if config[:callback] != nil do
      data = config[:callback].on_loaded config[:id], data
    end
    data
  end

  # Notify that there is new data available
  defp on_saved(config) do
    if config[:callback] != nil do
      config[:callback].on_saved config[:id]
    end
  end

  defp ets_table do
    {:ok, ets_table} = Application.fetch_env :google_sheets, :ets_table
    ets_table
  end

end
