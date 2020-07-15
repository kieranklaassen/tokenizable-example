class Product < ApplicationRecord
  include Tokenizable

  # Optionally set the token length. Default is 8
  token_length 12
end
