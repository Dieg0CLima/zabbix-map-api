require "set"

module Maps
  module Import
    class Executor
      Result = Struct.new(:network_map, :summary, :report, :warnings, keyword_init: true)

      def initialize(organization:, normalized_payload:, mode:, network_map: nil)
        @organization = organization
        @normalized_payload = normalized_payload
        @mode = mode.to_s
        @network_map = network_map
        @warnings = []
      end

      def call
        ensure_mode!

        target_map = resolve_target_map
        map_action = target_map.persisted? ? "updated" : "created"
        preview_summary = build_summary_for(target_map, map_action: map_action)

        return Result.new(
          network_map: target_map,
          summary: preview_summary,
          report: build_report(action: "preview", summary: preview_summary),
          warnings: []
        ) if preview_mode?

        ActiveRecord::Base.transaction do
          persist_map!(target_map)
          site_index = upsert_sites!
          pop_index = upsert_pops!(target_map, site_index)
          node_index = upsert_nodes!(target_map, site_index: site_index, pop_index: pop_index)
          upsert_cables!(target_map, node_index)
        end

        target_map.reload
        apply_summary = build_apply_summary(target_map, map_action: map_action)

        Result.new(
          network_map: target_map,
          summary: apply_summary,
          report: build_report(action: "apply", summary: apply_summary),
          warnings: @warnings.dup
        )
      rescue ActiveRecord::RecordInvalid => e
        raise Maps::Import::Errors::DomainError.new(
          code: "import_apply_failed",
          message: "Import apply failed",
          details: { record: e.record.class.name, errors: e.record.errors.to_hash(true) }
        )
      rescue ActiveRecord::RecordNotUnique => e
        raise Maps::Import::Errors::DomainError.new(
          code: "import_unique_conflict",
          message: "Import apply failed due to unique constraint",
          details: {
            constraint: extract_unique_constraint(e.message),
            message: e.message
          }
        )
      end

      private

      def ensure_mode!
        return if %w[preview apply].include?(@mode)

        raise Maps::Import::Errors::DomainError.new(
          code: "invalid_import_mode",
          message: "Invalid import mode",
          details: { mode: @mode, supported_modes: %w[preview apply] }
        )
      end

      def preview_mode?
        @mode == "preview"
      end

      def resolve_target_map
        return @network_map if @network_map.present?

        @organization.network_maps.find_or_initialize_by(name: normalized_map_name)
      end

      def normalized_map_name
        @normalized_payload.dig("map", "name")
      end

      def persist_map!(network_map)
        metadata = (network_map.metadata || {}).merge(
          "import" => {
            "provider" => @normalized_payload["provider"],
            "external_id" => @normalized_payload.dig("map", "external_id"),
            "schema_version" => @normalized_payload["schema_version"]
          }
        )

        network_map.assign_attributes(
          name: network_map.persisted? ? network_map.name : normalized_map_name,
          source_type: network_map.source_type.presence || "manual",
          active_base_layer: network_map.active_base_layer.presence || "standard",
          metadata: metadata
        )
        network_map.save!
      rescue ActiveRecord::RecordNotUnique
        # Concurrent import created the same map name between resolve_target_map and save.
        existing = @organization.network_maps.find_by(name: normalized_map_name)
        raise unless existing

        existing.update!(metadata: metadata)
        @network_map = existing
      end

      def upsert_nodes!(network_map, site_index:, pop_index:)
        existing = network_map.map_nodes.index_by(&:external_id)
        node_index = {}

        # Track which Site IDs already have a canonical MapNode so that alias nodes
        # (multiple nodes pointing to the same Site via name deduplication or explicit
        # site_external_id) don't trigger the mappable_uniqueness_within_map validation.
        # Pre-seed with sites already owned by existing nodes — idempotent re-imports
        # will re-claim them correctly via the existing_node check below.
        claimed_site_ids = existing.values
          .filter_map { |n| n.mappable_id if n.mappable_type == "Site" }
          .to_set

        @normalized_payload.fetch("nodes").each do |node_data|
          metadata = safe_hash(node_data["metadata"])
          existing_node = existing[node_data["external_id"]]

          candidate_site = generated_endpoint?(metadata) ? nil : site_index[resolve_site_external_id(node_data, metadata)]
          site = resolve_node_site(candidate_site, existing_node, claimed_site_ids)

          if candidate_site && site.nil? && !generated_endpoint?(metadata)
            @warnings << {
              "kind" => "node_site_alias",
              "label" => node_data["label"].to_s,
              "external_id" => node_data["external_id"],
              "site_external_id" => resolve_site_external_id(node_data, metadata),
              "reason" => "site_already_claimed_by_another_node"
            }
          end

          pop = pop_index[resolve_pop_external_id(node_data, metadata)]

          node = existing_node || network_map.map_nodes.new(external_id: node_data["external_id"])
          node.assign_attributes(
            label: node_data["label"],
            node_kind: node_data["node_kind"],
            lat: node_data["lat"],
            lng: node_data["lng"],
            x: node_data["lat"],
            y: node_data["lng"],
            map_pop: pop,
            mappable: site,
            metadata: metadata
          )
          node.save!
          node_index[node.external_id] = node
        end

        node_index
      end

      # Returns the site a node should be mapped to, enforcing one MapNode per Site.
      # An existing node that already owns the candidate site is allowed to re-claim it
      # (idempotent update, handled by the model's where.not(id:) guard).
      # Any other node loses the claim and receives nil.
      def resolve_node_site(candidate_site, existing_node, claimed_site_ids)
        return nil if candidate_site.nil?

        already_owns = existing_node&.mappable_type == "Site" &&
                       existing_node&.mappable_id == candidate_site.id

        if already_owns
          candidate_site
        elsif claimed_site_ids.include?(candidate_site.id)
          nil
        else
          claimed_site_ids.add(candidate_site.id)
          candidate_site
        end
      end

      def upsert_cables!(network_map, node_index)
        existing = network_map.network_cables.includes(:network_cable_points).index_by(&:external_id)

        @normalized_payload.fetch("cables").each do |cable_data|
          cable = existing[cable_data["external_id"]] || network_map.network_cables.new(external_id: cable_data["external_id"])
          cable.assign_attributes(
            label: cable_data["label"],
            source_node: node_index.fetch(cable_data["source_external_id"]),
            target_node: node_index.fetch(cable_data["target_external_id"]),
            status: cable_data["status"],
            cable_type: cable_data["cable_type"],
            metadata: cable_data["metadata"]
          )
          cable.save!

          replace_cable_points!(cable, cable_data["points"])
        end
      end

      def replace_cable_points!(cable, points_data)
        cable.network_cable_points.delete_all

        rows = Array(points_data).each_with_index.filter_map do |point, idx|
          lat = point["lat"]
          lng = point["lng"]
          next if lat.nil? || lng.nil?

          {
            network_cable_id: cable.id,
            position: (point["position"] || idx).to_i,
            x: lat,
            y: lng,
            created_at: Time.current,
            updated_at: Time.current
          }
        end

        return if rows.empty?

        deduplicated_rows = rows
          .group_by { |row| row[:position] }
          .sort_by { |(position, _rows)| position }
          .map(&:last)
          .map(&:last)

        NetworkCablePoint.insert_all!(deduplicated_rows)
      end

      def upsert_sites!
        candidates = @normalized_payload.fetch("nodes").filter_map do |node_data|
          metadata = safe_hash(node_data["metadata"])
          next if generated_endpoint?(metadata)

          import_entity = metadata["import_entity"].to_s
          next unless import_entity.in?(%w[site pop])

          source_external_id = resolve_site_external_id(node_data, metadata)
          next if source_external_id.blank?

          raw_name = metadata["site_name"].to_s.strip.presence || node_data["label"].to_s.strip.presence || source_external_id
          name = sanitize_site_name(raw_name, fallback_external_id: source_external_id)

          {
            source_external_id: source_external_id,
            name: name,
            name_key: site_name_key(name),
            lat: node_data["lat"],
            lng: node_data["lng"],
            source_node_external_id: node_data["external_id"]
          }
        end

        return {} if candidates.empty?

        source_external_ids = candidates.map { |row| row[:source_external_id] }.uniq
        name_keys = candidates.map { |row| row[:name_key] }.uniq
        existing_by_external_id = @organization.sites.where(external_id: source_external_ids).index_by(&:external_id)
        existing_by_name_key = @organization.sites.each_with_object({}) do |site, acc|
          key = site_name_key(site.name)
          acc[key] ||= site if name_keys.include?(key)
        end

        result = build_site_upsert_rows(
          candidates: candidates,
          existing_by_external_id: existing_by_external_id,
          existing_by_name_key: existing_by_name_key
        )
        rows = result[:rows]
        alias_to_target_external_id = result[:alias_to_target_external_id]

        perform_site_upsert_with_retry!(
          rows: rows,
          candidates: candidates,
          existing_by_external_id: existing_by_external_id
        )

        target_external_ids = rows.map { |row| row[:external_id] }.uniq
        persisted_by_external_id = @organization.sites.where(external_id: target_external_ids).index_by(&:external_id)

        site_index = persisted_by_external_id.dup
        alias_to_target_external_id.each do |source_external_id, target_external_id|
          site = persisted_by_external_id[target_external_id]
          site_index[source_external_id] = site if site
        end

        @site_summary = {
          created: (rows.map { |r| r[:external_id] }.uniq - existing_by_external_id.keys).size,
          reused: (rows.map { |r| r[:external_id] }.uniq & existing_by_external_id.keys).size,
          deduplicated: alias_to_target_external_id.count { |source_id, target_id| source_id != target_id }
        }

        site_index
      end

      def build_site_upsert_rows(candidates:, existing_by_external_id:, existing_by_name_key:)
        now = Time.current
        rows_by_external_id = {}
        alias_to_target_external_id = {}
        target_external_id_by_name_key = {}

        candidates.each do |candidate|
          name = candidate[:name]
          name_key = candidate[:name_key]
          source_external_id = candidate[:source_external_id]
          existing_by_name = existing_by_name_key[name_key]
          existing_by_source = existing_by_external_id[source_external_id]
          batch_target = target_external_id_by_name_key[name_key]

          target_external_id = if existing_by_name.present?
            existing_by_name.external_id
          elsif batch_target.present?
            batch_target
          elsif existing_by_source.present?
            existing_by_source.external_id
          else
            source_external_id
          end

          alias_to_target_external_id[source_external_id] = target_external_id
          target_external_id_by_name_key[name_key] ||= target_external_id

          if source_external_id != target_external_id
            add_warning_once(
              "kind" => "site_deduplicated",
              "site_external_id" => source_external_id,
              "merged_into_external_id" => target_external_id,
              "label" => name,
              "reason" => "duplicate_site_name"
            )
          end

          rows_by_external_id[target_external_id] = {
            organization_id: @organization.id,
            external_id: target_external_id,
            name: name,
            slug: existing_by_name&.slug.presence || existing_by_source&.slug.presence || slug_for_site(name, target_external_id),
            lat: candidate[:lat],
            lng: candidate[:lng],
            status: "active",
            metadata: {
              "import" => {
                "provider" => @normalized_payload["provider"],
                "source_node_external_id" => candidate[:source_node_external_id]
              }
            },
            created_at: now,
            updated_at: now
          }
        end

        {
          rows: rows_by_external_id.values,
          alias_to_target_external_id: alias_to_target_external_id
        }
      end

      def perform_site_upsert_with_retry!(rows:, candidates:, existing_by_external_id:)
        Site.upsert_all(rows, unique_by: :index_sites_on_organization_id_and_external_id)
      rescue ActiveRecord::RecordNotUnique
        # Concurrent import can create by name between read and upsert. Re-resolve by normalized name and retry once.
        refreshed_by_name_key = @organization.sites.each_with_object({}) do |site, acc|
          key = site_name_key(site.name)
          acc[key] ||= site
        end.slice(*candidates.map { |row| row[:name_key] }.uniq)

        retried = build_site_upsert_rows(
          candidates: candidates,
          existing_by_external_id: existing_by_external_id,
          existing_by_name_key: refreshed_by_name_key
        )[:rows]

        Site.upsert_all(retried, unique_by: :index_sites_on_organization_id_and_external_id)
      end

      def upsert_pops!(network_map, site_index)
        candidates = @normalized_payload.fetch("nodes").filter_map do |node_data|
          metadata = safe_hash(node_data["metadata"])
          next if generated_endpoint?(metadata)
          next unless metadata["import_entity"].to_s == "pop"

          external_id = resolve_pop_external_id(node_data, metadata)
          next if external_id.blank?

          site_external_id = resolve_site_external_id(node_data, metadata)
          site_id = site_external_id.present? ? site_index[site_external_id]&.id : nil

          {
            network_map_id: network_map.id,
            external_id: external_id,
            name: metadata["pop_name"].to_s.strip.presence || node_data["label"].to_s.strip.presence || external_id,
            lat: node_data["lat"],
            lng: node_data["lng"],
            color: metadata["pop_color"].to_s.strip.presence || "#7c3aed",
            site_id: site_id,
            metadata: {
              "import" => {
                "provider" => @normalized_payload["provider"],
                "source_node_external_id" => node_data["external_id"],
                "site_external_id" => site_external_id
              }
            },
            created_at: Time.current,
            updated_at: Time.current
          }
        end

        return {} if candidates.empty?

        MapPop.upsert_all(candidates, unique_by: :index_map_pops_on_network_map_id_and_external_id)

        external_ids = candidates.map { |row| row[:external_id] }.uniq
        network_map.map_pops.where(external_id: external_ids).index_by(&:external_id)
      end

      def resolve_site_external_id(node_data, metadata)
        metadata["site_external_id"].to_s.strip.presence || node_data["external_id"].to_s.strip
      end

      def resolve_pop_external_id(node_data, metadata)
        metadata["pop_external_id"].to_s.strip.presence || node_data["external_id"].to_s.strip
      end

      def generated_endpoint?(metadata)
        metadata["generated_endpoint"] == true
      end

      def safe_hash(value)
        value.is_a?(Hash) ? value : {}
      end

      def slug_for_site(name, external_id)
        base = name.to_s.parameterize
        base = "site" if base.blank?
        digest = external_id.to_s.parameterize
        digest = "imported" if digest.blank?
        "#{base}-#{digest}".first(120)
      end

      def sanitize_site_name(name, fallback_external_id:)
        cleaned = name.to_s.gsub(/\p{Cf}/, "").squish
        return cleaned if cleaned.present?

        fallback_external_id.to_s
      end

      def add_warning_once(warning)
        @warnings << warning unless @warnings.include?(warning)
      end

      def site_name_key(name)
        sanitize_site_name(name, fallback_external_id: "site").downcase
      end

      def extract_unique_constraint(message)
        match = message.to_s.match(/unique constraint "([^"]+)"/)
        match&.captures&.first
      end

      def build_summary_for(network_map, map_action:)
        existing_nodes = network_map.persisted? ? network_map.map_nodes.pluck(:external_id).to_set : Set.new
        existing_cables = network_map.persisted? ? network_map.network_cables.pluck(:external_id).to_set : Set.new

        payload_nodes = @normalized_payload.fetch("nodes").map { |n| n["external_id"] }
        payload_cables = @normalized_payload.fetch("cables").map { |c| c["external_id"] }

        {
          map: map_action,
          nodes: {
            created: payload_nodes.count { |id| !existing_nodes.include?(id) },
            updated: payload_nodes.count { |id| existing_nodes.include?(id) },
            skipped: 0,
            failed: 0
          },
          cables: {
            created: payload_cables.count { |id| !existing_cables.include?(id) },
            updated: payload_cables.count { |id| existing_cables.include?(id) },
            skipped: 0,
            failed: 0
          },
          sites: { created: 0, reused: 0, deduplicated: 0 }
        }
      end

      # Builds the post-apply summary using real persisted state and accumulated warnings.
      def build_apply_summary(network_map, map_action:)
        base = build_summary_for(network_map, map_action: map_action)

        alias_skipped = @warnings.count { |w| w["kind"] == "node_site_alias" }
        base[:nodes][:skipped] = alias_skipped

        base[:sites] = @site_summary || { created: 0, reused: 0, deduplicated: 0 }
        base
      end

      def build_report(action:, summary:)
        {
          action: action,
          provider: @normalized_payload["provider"],
          schema_version: @normalized_payload["schema_version"],
          network_map_name: normalized_map_name,
          summary: summary
        }
      end
    end
  end
end
