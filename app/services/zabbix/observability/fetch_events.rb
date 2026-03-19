class Zabbix::Observability::FetchEvents < Zabbix::Observability::BaseFetch
  def call
    with_cache("events") do
      safe_fetch(default: default_payload) do
        problems = fetch_problems
        events = normalize_events(problems)
        status = events.any? ? "problem" : "ok"

        {
          status:,
          active_problems: events.size,
          severity_breakdown: events.each_with_object(Hash.new(0)) { |event, breakdown| breakdown[event[:severity]] += 1 },
          events:,
          zabbix_unavailable: false
        }
      end
    end
  end

  private

  def default_payload
    {
      status: "unknown",
      active_problems: 0,
      severity_breakdown: {},
      events: []
    }
  end

  def fetch_problems
    result = client.call("problem.get", {
      hostids: [host_id],
      recent: true,
      sortfield: ["eventid"],
      sortorder: "DESC",
      selectAcknowledges: "extend",
      limit: 20
    })

    return result if result.present?

    client.call("event.get", {
      hostids: [host_id],
      value: 1,
      source: 0,
      object: 0,
      selectAcknowledges: "extend",
      sortfield: ["eventid"],
      sortorder: "DESC",
      limit: 20
    })
  end

  def normalize_events(events)
    Array(events).filter_map do |problem|
      next unless active_problem?(problem)

      clock = problem["clock"].to_i
      {
        id: problem["eventid"].to_s,
        name: problem["name"].presence || problem["opdata"].presence || "Unnamed problem",
        severity: severity_name(problem["severity"]),
        clock: parse_time(clock),
        duration: [Time.current.to_i - clock, 0].max,
        acknowledged: acknowledged?(problem)
      }
    end
  end

  def active_problem?(problem)
    recovery_event_id = problem["r_eventid"].to_s
    active = problem["value"].nil? || problem["value"].to_s != "0"

    (recovery_event_id.blank? || recovery_event_id == "0") && active
  end

  def acknowledged?(problem)
    return problem["acknowledged"].to_s == "1" if problem.key?("acknowledged")

    Array(problem["acknowledges"]).any?
  end
end
