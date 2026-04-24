class Api::V2::Accounts::ReportsController < Api::V1::Accounts::BaseController
  include Api::V2::Accounts::ReportsHelper
  include Api::V2::Accounts::HeatmapHelper

  before_action :check_authorization

  def index
    builder = V2::Reports::Conversations::ReportBuilder.new(Current.account, report_params)
    data = builder.timeseries
    render json: data
  end

  def summary
    return head :unprocessable_entity if comparison_period_ranges_invalid?

    render json: build_summary(:summary)
  end

  def bot_summary
    return head :unprocessable_entity if comparison_period_ranges_invalid?

    render json: build_summary(:bot_summary)
  end

  def agents
    @report_data = generate_agents_report
    generate_csv('agents_report', 'api/v2/accounts/reports/agents')
  end

  def inboxes
    @report_data = generate_inboxes_report
    generate_csv('inboxes_report', 'api/v2/accounts/reports/inboxes')
  end

  def labels
    @report_data = generate_labels_report
    generate_csv('labels_report', 'api/v2/accounts/reports/labels')
  end

  def teams
    @report_data = generate_teams_report
    generate_csv('teams_report', 'api/v2/accounts/reports/teams')
  end

  def conversations_summary
    @report_data = generate_conversations_report
    generate_csv('conversations_summary_report', 'api/v2/accounts/reports/conversations_summary')
  end

  def conversation_traffic
    @report_data = generate_conversations_heatmap_report
    timezone_offset = (params[:timezone_offset] || 0).to_f
    @timezone = ActiveSupport::TimeZone[timezone_offset]

    generate_csv('conversation_traffic_reports', 'api/v2/accounts/reports/conversation_traffic')
  end

  def conversations
    return head :unprocessable_entity if params[:type].blank?

    render json: conversation_metrics
  end

  def bot_metrics
    bot_metrics = V2::Reports::BotMetricsBuilder.new(Current.account, params).metrics
    render json: bot_metrics
  end

  def inbox_label_matrix
    builder = V2::Reports::InboxLabelMatrixBuilder.new(
      account: Current.account,
      params: inbox_label_matrix_params
    )
    render json: builder.build
  end

  def first_response_time_distribution
    builder = V2::Reports::FirstResponseTimeDistributionBuilder.new(
      account: Current.account,
      params: first_response_time_distribution_params
    )
    render json: builder.build
  end

  OUTGOING_MESSAGES_ALLOWED_GROUP_BY = %w[agent team inbox label].freeze

  def outgoing_messages_count
    return head :unprocessable_entity unless OUTGOING_MESSAGES_ALLOWED_GROUP_BY.include?(params[:group_by])

    builder = V2::Reports::OutgoingMessagesCountBuilder.new(Current.account, outgoing_messages_count_params)
    render json: builder.build
  end

  def agent_activity
    since_ts = params[:since].to_i
    until_ts = params[:until].to_i
    return head :unprocessable_entity if since_ts.zero? || until_ts.zero?

    range_start = Time.zone.at(since_ts)
    range_end = Time.zone.at(until_ts)
    effective_range_end = [range_end, Time.zone.now].min
    return render json: { meta: { count: 0 }, payload: [] } if effective_range_end <= range_start
    user_ids = agent_activity_user_ids
    if params[:user_id].present?
      user_id = params[:user_id].to_i
      return head :not_found unless user_ids.include?(user_id)

      user_ids = [user_id]
    end

    scoped_events = AgentAvailabilityEvent
                    .where(account_id: Current.account.id, user_id: user_ids)
                    .where(created_at: range_start..effective_range_end)
                    .includes(:user)
                    .order(created_at: :asc)
    payload = build_agent_activity_payload(
      user_ids: user_ids,
      events: scoped_events,
      range_start: range_start,
      range_end: effective_range_end
    )

    render json: { meta: { count: payload.size }, payload: payload }
  end

  private

  def generate_csv(filename, template)
    response.headers['Content-Type'] = 'text/csv'
    response.headers['Content-Disposition'] = "attachment; filename=#{filename}.csv"
    render layout: false, template: template, formats: [:csv]
  end

  def check_authorization
    authorize :report, :view?
  end

  def common_params
    {
      type: params[:type].to_sym,
      id: params[:id],
      group_by: params[:group_by],
      business_hours: ActiveModel::Type::Boolean.new.cast(params[:business_hours]),
      label_ids: normalized_report_label_ids
    }
  end

  def normalized_report_label_ids
    raw = params[:label_ids]
    return nil if raw.blank?

    Array(raw).map(&:to_i).uniq.select(&:positive?)
  end

  def current_summary_params
    common_params.merge({
                          since: range[:current][:since],
                          until: range[:current][:until],
                          timezone_offset: params[:timezone_offset]
                        })
  end

  def previous_summary_params
    common_params.merge({
                          since: range[:previous][:since],
                          until: range[:previous][:until],
                          timezone_offset: params[:timezone_offset]
                        })
  end

  def report_params
    common_params.merge({
                          metric: params[:metric],
                          since: params[:since],
                          until: params[:until],
                          timezone_offset: params[:timezone_offset]
                        })
  end

  def conversation_params
    {
      type: params[:type].to_sym,
      user_id: params[:user_id],
      page: params[:page].presence || 1
    }
  end

  def range
    {
      current: {
        since: params[:since],
        until: params[:until]
      },
      previous: {
        since: (params[:since].to_i - (params[:until].to_i - params[:since].to_i)).to_s,
        until: params[:since]
      }
    }
  end

  def build_summary(method)
    builder = V2::Reports::Conversations::MetricBuilder
    current_summary = builder.new(Current.account, current_summary_params).send(method)
    previous_summary = builder.new(Current.account, previous_summary_params).send(method)
    result = current_summary.merge(previous: previous_summary)
    extras = parsed_comparison_periods
    return result if extras.blank?

    comparison_summaries = extras.map do |range|
      p = common_params.merge(
        since: range[:since],
        until: range[:until],
        timezone_offset: params[:timezone_offset]
      )
      builder.new(Current.account, p).send(method).merge(
        since: range[:since].to_i,
        until: range[:until].to_i
      )
    end
    result.merge(comparison_periods: comparison_summaries)
  end

  MAX_COMPARISON_PERIODS = 1

  def parsed_comparison_periods
    @parsed_comparison_periods ||= normalize_comparison_periods_param(params[:comparison_periods])
  end

  def normalize_comparison_periods_param(raw)
    return [] if raw.blank?

    body = raw.is_a?(String) ? JSON.parse(raw) : raw
    return [] unless body.is_a?(Array)

    body.first(MAX_COMPARISON_PERIODS).filter_map do |entry|
      next unless entry.is_a?(Hash)

      e = entry.with_indifferent_access
      since = e[:since].presence || e[:from].presence
      unt = e[:until].presence || e[:to].presence
      next if since.blank? || unt.blank?

      { since: since.to_s, until: unt.to_s }
    end
  rescue JSON::ParserError, TypeError
    []
  end

  def comparison_period_ranges_invalid?
    raw = params[:comparison_periods]
    return false if raw.blank?

    parsed_comparison_periods.any? { |p| comparison_range_too_long?(p[:since], p[:until]) }
  end

  def comparison_range_too_long?(since_s, until_s)
    since_i = since_s.to_i
    until_i = until_s.to_i
    return true if since_i.zero? || until_i.zero?

    (Time.zone.at(until_i) - Time.zone.at(since_i)) > 6.months
  end

  def conversation_metrics
    V2::ReportBuilder.new(Current.account, conversation_params).conversation_metrics
  end

  def inbox_label_matrix_params
    {
      since: params[:since],
      until: params[:until],
      inbox_ids: params[:inbox_ids],
      label_ids: params[:label_ids]
    }
  end

  def first_response_time_distribution_params
    {
      since: params[:since],
      until: params[:until]
    }
  end

  def outgoing_messages_count_params
    {
      group_by: params[:group_by],
      since: params[:since],
      until: params[:until]
    }
  end

  def agent_activity_user_ids
    Current.account.account_users.where(role: [:agent, :administrator]).pluck(:user_id)
  end

  def build_agent_activity_payload(user_ids:, events:, range_start:, range_end:)
    events_by_user = events.group_by(&:user_id)
    users_by_id = Current.account.users.where(id: user_ids).index_by(&:id)
    baselines = availability_baseline_by_user(user_ids, range_start)

    user_ids.filter_map do |uid|
      user = users_by_id[uid]
      next unless user

      user_events = events_by_user[uid] || []
      segments = availability_segments(
        baseline: baselines[uid],
        events: user_events,
        range_start: range_start,
        range_end: range_end
      )
      totals = availability_totals(segments)

      {
        user_id: uid,
        agent_name: user.name,
        email: user.email,
        totals: totals,
        segments: segments
      }
    end
  end

  def availability_baseline_by_user(user_ids, range_start)
    baseline = {}
    events_before = AgentAvailabilityEvent
                    .where(account_id: Current.account.id, user_id: user_ids)
                    .where('created_at < ?', range_start)
                    .order(created_at: :desc)
    events_before.each do |event|
      baseline[event.user_id] ||= event.availability
    end
    baseline
  end

  def availability_segments(baseline:, events:, range_start:, range_end:)
    segments = []
    cursor = range_start
    current = baseline

    events.each do |event|
      next if event.created_at < range_start
      break if event.created_at > range_end

      current = event.previous_availability if current.nil? && event.previous_availability.present?
      if current.present? && event.created_at > cursor
        segments << build_segment(current, cursor, event.created_at)
      end
      current = event.availability
      cursor = [event.created_at, range_start].max
    end

    if current.present? && cursor < range_end
      segments << build_segment(current, cursor, range_end)
    end

    segments
  end

  def build_segment(availability_value, from_time, to_time)
    duration = (to_time.to_i - from_time.to_i).clamp(0, Float::INFINITY).to_i
    {
      availability: AgentAvailabilityEvent.availability_label(availability_value),
      from: from_time.to_i,
      to: to_time.to_i,
      duration: duration
    }
  end

  def availability_totals(segments)
    totals = { accepting: 0, not_accepting: 0, logged_out: 0 }
    segments.each do |segment|
      duration = segment[:duration].to_i
      case segment[:availability]
      when 'online'
        totals[:accepting] += duration
      when 'busy'
        totals[:not_accepting] += duration
      when 'offline'
        totals[:logged_out] += duration
      end
    end
    totals
  end
end
