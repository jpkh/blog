# name: blog
# about: blog frontend for Discourse
# version: 0.1
# authors: Sam Saffron

# gem "multi_xml","0.5.5"
# gem "httparty", "0.12.0"
# TODO consider serel
# gem "serel", "1.2.0"

::BLOG_HOST = Rails.env.development? ? "sand.jnmechanics.com" : "jnmechanics.com"
::BLOG_DISCOURSE = Rails.env.development? ? "l.discourse" : "sand.jnmechanics.com"

module ::Blog
  class Engine < ::Rails::Engine
    engine_name "blog"
    isolate_namespace Blog
  end
end

Rails.configuration.assets.precompile += ['LAB.js', 'blog.css']

after_initialize do

  load File.expand_path("../app/jobs/blog_update_twitter.rb", __FILE__)
  load File.expand_path("../app/jobs/blog_update_stackoverflow.rb", __FILE__)

  require_dependency "plugin/filter"

  Plugin::Filter.register(:after_post_cook) do |post, cooked|
    if post.post_number == 1 && post.topic && post.topic.archetype == "regular"
      split = cooked.split(/<hr\/?>/)

      if split.length > 1
        post.topic.custom_fields["summary"] = split[0]
        post.topic.save unless post.new_record?
        cooked = split[1..-1].join("<hr>")
      end
    end
    cooked
  end

  class BlogConstraint
    def matches?(request)
      request.host == BLOG_HOST
    end
  end

  class ::Topic
    before_save :blog_bake_summary
    before_save :ensure_permalink

    def ensure_permalink
      unless custom_fields["permalink"]
        custom_fields["permalink"] =  (Time.now.strftime "/archive/%Y/%m/%d/") + self.slug
      end
    end

    def blog_bake_summary
      if summary = custom_fields["summary"]
        custom_fields["cooked_summary"] = PrettyText.cook(summary)
      end
    end
  end

  Discourse::Application.routes.prepend do
    mount ::Blog::Engine, at: "/", constraints: BlogConstraint.new
  end
end
