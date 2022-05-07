# Did tags controller
class DidTagsController < ApplicationController
	layout :determine_layout

  before_action :authorize
  before_action :check_localization
  before_filter :dids_enabled?
  before_filter :check_post_method, only: [:create, :update, :destroy, :unassign_dids]
  before_filter :find_did_tag, only: [:edit, :update, :destroy, :unassign_dids]

  def new
    @did_tag = DidTag.new
  end

  def create
    @did_tag = DidTag.new(params[:did_tag])

    if @did_tag.save
      flash[:status] = _('DID_Tag_was_successfully_created')
      redirect_to(controller: :dids, action: :tags)
    else
      flash_errors_for(_('DID_Tag_was_not_created'), @did_tag)
      render :new
    end
  end

  def edit
  end

  def update
    if @did_tag.update_attributes(params[:did_tag])
      flash[:status] = _('DID_Tag_was_successfully_updated')
      redirect_to(controller: :dids, action: :tags) && (return false)
    else
      flash_errors_for(_('DID_Tag_was_not_updated'), @did_tag)
      render :edit
    end
  end

  def destroy
    if @did_tag.destroy
      flash[:status] = _('DID_Tag_was_successfully_deleted')
    else
      flash_errors_for(_('DID_Tag_was_not_deleted'), @did_tag)
    end
    redirect_to(controller: :dids, action: :tags) && (return false)
  end

  def unassign_dids
    if @did_tag.did_tag_links.destroy_all
      flash[:status] = _('DIDs_were_successfully_unassigned')
    else
      flash_errors_for(_('DIDs_were_not_unassigned'), @did_tag.did_tag_links)
    end
    redirect_to(controller: :dids, action: :tags) && (return false)
  end

  private

  def find_did_tag
    @did_tag = DidTag.where(id: params[:id]).first
    return if @did_tag
    flash[:notice] = _('DID_Tag_was_not_found')
    redirect_to(controller: :dids, action: :tags) && (return false)
  end
end
