#!/usr/bin/env ruby
# frozen_string_literal: true

# ------------------------------------------------------------------
# N-depth hierarchical category page generator for Chirpy theme
#
# Interprets `categories: [A, B, C]` as a path  A → B → C
# and generates pages at:
#   /categories/a/
#   /categories/a/b/
#   /categories/a/b/c/
#
# Each generated page carries:
#   page.cat_path      – array of original (display) names  ["A","B","C"]
#   page.cat_slug_path – array of slugified names            ["a","b","c"]
#   page.title         – last element (leaf name)
#   page.posts         – posts whose category prefix matches this path
#   page.children      – immediate child category names (display) at this node
# ------------------------------------------------------------------

module JekyllCategoryHierarchy

  # ── Utility ──────────────────────────────────────────────────────
  def self.slugify(name)
    Jekyll::Utils.slugify(name, mode: "latin")
  end

  # Build a nested tree  { "slug" => { :name, :children, :posts } }
  def self.build_tree(site)
    tree = {}

    site.posts.docs.each do |post|
      cats = post.data["categories"] || []
      next if cats.empty?

      node = tree
      cats.each do |cat|
        slug = slugify(cat)
        node[slug] ||= { name: cat, children: {}, posts: [] }
        node[slug][:posts] << post
        node = node[slug][:children]
      end
    end

    tree
  end

  # Walk tree → yield (cat_path, cat_slug_path, node) at every depth
  def self.walk(tree, cat_path = [], slug_path = [], &block)
    tree.each do |slug, node|
      cp  = cat_path  + [node[:name]]
      sp  = slug_path + [slug]
      block.call(cp, sp, node)
      walk(node[:children], cp, sp, &block)
    end
  end

  # ── Page class ───────────────────────────────────────────────────
  class HierarchicalCategoryPage < Jekyll::Page
    def initialize(site, cat_path, cat_slug_path, node)
      @site = site
      @base = site.source
      @dir  = "categories/#{cat_slug_path.join('/')}"
      @name = "index.html"

      self.process(@name)
      self.read_yaml(File.join(@base, "_layouts"), "category.html")

      # Collect *all* posts whose category-prefix matches this path
      matching_posts = site.posts.docs.select do |post|
        post_cats = post.data["categories"] || []
        post_cats.length >= cat_path.length &&
          post_cats[0...cat_path.length] == cat_path
      end

      # "Direct" posts = those whose full path is exactly this node
      direct_posts = site.posts.docs.select do |post|
        post_cats = post.data["categories"] || []
        post_cats == cat_path
      end

      # Immediate child names (display)
      child_names = node[:children].values.map { |c| c[:name] }.sort

      self.data["cat_path"]      = cat_path
      self.data["cat_slug_path"] = cat_slug_path
      self.data["title"]         = cat_path.last
      self.data["posts"]         = matching_posts.sort_by { |p| p.date }.reverse
      self.data["direct_posts"]  = direct_posts.sort_by  { |p| p.date }.reverse
      self.data["children"]      = child_names
      self.data["layout"]        = "category"
    end
  end

  # ── Generator ────────────────────────────────────────────────────
  class Generator < Jekyll::Generator
    safe true
    priority :low

    def generate(site)
      tree = JekyllCategoryHierarchy.build_tree(site)

      # Expose tree data for categories.html listing page
      site.data["category_tree"] = serialize_tree(tree)

      JekyllCategoryHierarchy.walk(tree) do |cat_path, slug_path, node|
        page = HierarchicalCategoryPage.new(site, cat_path, slug_path, node)
        site.pages << page
      end
    end

    private

    # Convert tree to a serializable structure (arrays/hashes only)
    # so Liquid templates can iterate it.
    def serialize_tree(tree)
      tree.map do |slug, node|
        {
          "name"     => node[:name],
          "slug"     => slug,
          "count"    => node[:posts].size,
          "children" => serialize_tree(node[:children])
        }
      end.sort_by { |n| n["name"] }
    end
  end

end
