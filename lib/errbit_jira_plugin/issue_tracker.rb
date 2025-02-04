require 'jira-ruby'

module ErrbitJiraPlugin
  class IssueTracker < ErrbitPlugin::IssueTracker
    LABEL = 'jira'

    NOTE = 'Please configure Jira by entering the information below.'

    FIELDS = {
      :base_url => {
          :label => 'Jira URL without trailing slash',
          :placeholder => 'https://jira.example.org'
      },
      :context_path => {
          :optional => true,
          :label => 'Context Path (Just "/" if empty otherwise with leading slash)',
          :placeholder => "/jira"
      },
      :username => {
          :label => 'Username',
          :placeholder => 'johndoe'
      },
      :password => {
          :label => 'Password',
          :placeholder => 'p@assW0rd'
      },
      :project_id => {
          :label => 'Project Key',
          :placeholder => 'The project Key where the issue will be created'
      },
      :issue_priority => {
          :label => 'Priority',
          :placeholder => 'Normal'
      }
    }

    def self.label
      LABEL
    end

    def self.note
      NOTE
    end

    def self.fields
      FIELDS
    end

    def self.icons
      @icons ||= {
        create: [
          'image/png', ErrbitJiraPlugin.read_static_file('jira_create.png')
        ],
        goto: [
          'image/png', ErrbitJiraPlugin.read_static_file('jira_goto.png'),
        ],
        inactive: [
          'image/png', ErrbitJiraPlugin.read_static_file('jira_inactive.png'),
        ]
      }
    end

    def render_body_args
      ['/jira_issues_body', formats: [:txt, :text], handlers: [:erb]]
    end

    def configured?
      params['project_id'].present?
    end

    def errors
      errors = []
      if self.class.fields.detect {|f| options[f[0]].blank? }
        errors << [:base, 'You must specify all non optional values!']
      end
      errors
    end

    def comments_allowed?
      false
    end

    def jira_options
      {
        :username => params['username'],
        :password => params['password'],
        :site => params['base_url'],
        :auth_type => :basic,
        :context_path => context_path
      }
    end

    def create_issue(title, body, user: {})
      begin
        client = JIRA::Client.new(jira_options)
        project = client.Project.find(params['project_id'])

        issue_fields =  {
                          "fields" => {
                            "summary" => title.gsub("\n", ' ').gsub("\r", ' '),
                            "description" => body,
                            "project"=> {"id"=> project.id},
                            "issuetype"=>{"id"=>"10009"},
                            "priority"=>{"name"=>params['issue_priority']}
                          }
                        }

        jira_issue = client.Issue.build

        if !jira_issue.save(issue_fields)
          errors = jira_issue.errors.to_a.map{|p| p.join(': ')}.join(", ")
          raise ErrbitJiraPlugin::IssueError, "Could not create an issue with Jira: #{errors}."
        end

        jira_url(jira_issue.key)
      rescue JIRA::HTTPError
        raise ErrbitJiraPlugin::IssueError, "Could not create an issue with Jira.  Please check your credentials."
      end
    end

    def jira_url(jira_issue_key)
      "#{params['base_url']}#{params['context_path']}/browse/#{jira_issue_key}"
    end

    def url
      params['base_url']
    end

    private

    def context_path
      if params['context_path'] == '/'
        ''
      else
        params['context_path']
      end
    end

    def params
      options
    end
  end
end
