# frozen_string_literal: true

class ApplicationPresenter < SimpleDelegator
  # SimpleDelegator forwards to_json to the model, bypassing the presenter's as_json.
  def to_json(*args)
    as_json.to_json(*args)
  end
end
