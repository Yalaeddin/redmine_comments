class IssueCommentsController < ApplicationController
  before_action :find_issue, except: [:destroy_attachment]
  before_action :authorize, except: [:destroy_attachment]

  def new
  end

  def create
    @journal = Journal.new(:journalized => @issue,
                           :user => User.current,
                           :notes => params[:journal][:notes],
                           :private_notes => true)

    visibility_params = params[:journal][:visibility]
    if visibility_params.present?
      visibility_ids = visibility_params.split('|').map(&:to_i).uniq
      if Redmine::Plugin.installed?(:redmine_limited_visibility)
        @journal.function_ids = visibility_ids
      else
        @journal.role_ids = visibility_ids
      end
    end

    if @journal.save
      @issue.touch

      @journal.save_attachments(params[:attachments])
      @journal.attach_saved_attachments

      respond_to do |format|
        format.html { redirect_to issue_path(@issue) }
        format.api { render_api_ok }
      end
    else
      # render_validation_errors(@journal)
      respond_to do |format|
        format.html { redirect_to issue_path(@issue) }
        format.api { render_validation_errors(@issue) }
      end
    end
  end

  def destroy_attachment
    @attachment = Attachment.find(params[:id])
    @issue = @attachment.container.issue
    if @attachment.container
      # Make sure association callbacks are called
      @attachment.container.attachments.delete(@attachment)
    else
      @attachment.destroy
    end
    respond_to do |format|
      format.html { redirect_to issue_path(@issue) }
      format.api { render_api_ok }
    end
  end

  private

  def find_issue
    # Issue.visible.find(...) can not be used to redirect user to the login form
    # if the issue actually exists but requires authentication
    @issue = Issue.includes(:project, :tracker, :status, :author, :priority, :category).find(params[:issue_id])
    unless @issue.visible?
      deny_access
      return
    end
    @project = @issue.project
  rescue ActiveRecord::RecordNotFound
    render_404
  end

  def authorize
    deny_access unless User.current.allowed_to?(:set_notes_private, @project)
  end
end
