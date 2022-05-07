# DidTags Helper module
module DidTagsHelper
  def did_tags_helper(did_tags_in_page)
    result = []

    did_tags_in_page.try(:each) do |did_tag|
      result << {
        id: did_tag.id,
        tag: did_tag.show_tag,
        comment: did_tag.comment,
        assigned_dids: did_tag.try(:did_tag_links).try(:size).to_i,
        edit: 'EDIT',
        delete: 'DELETE'
      }
    end

    result.to_json.html_safe
  end
end
