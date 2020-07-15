#
# Add the functionality to add tokens to ActiveRecord models.
# Set `token_length 12` in your model if you want not to use the default after including the conern
# You need a database column that is named `token`
#
# @author Kieran Klaassen
#
module Tokenizable
  extend ActiveSupport::Concern

  DEFAULT_LENGTH = 8

  included do
    cattr_accessor :token_length_var
    before_create :generate_token
    validates_presence_of :token, on: :update
  end

  module ClassMethods
    # Generate tokens for all records that do not have them.
    # To be run in migration or deployment task.
    def generate_tokens!
      # Find all IDs that need tokenizing
      ids = where(token:nil).ids
      return if ids.blank?

      # Make sure we check against existing tokens to ensure token uniqueness in case Tokenizable is
      # used with a column that does not have a unique constraint set up
      existing_tokens = pluck(:token).compact

      # Generate tokens for every ID. Make sure we have no duplicates
      tokens = []
      while tokens.length < ids.length
        (ids.length - tokens.length).times do
          tokens << SecureRandom.urlsafe_base64(@token_length_var).downcase
        end
        tokens = tokens.uniq - existing_tokens
      end

      # Collect all SQL parts for use in a VALUES construct
      token_sql_parts = []
      ids.each_with_index { |id, i| token_sql_parts << "(#{id}, '#{tokens[i]}')" }

      # Generate the SQL
      ActiveRecord::Base.connection.execute(<<-sql.gsub(/\s+/, ' ').squish)
        WITH tokens(id, token) AS (VALUES #{token_sql_parts.join(',')})
        UPDATE #{table_name} tbl
          SET token=tokens.token
          FROM tokens
          WHERE tbl.id = tokens.id
      sql
    end

    private

    # Set the length of the token (in bytes converted to base64) to be generated
    #
    # @param [Integer] token_length sets the length of the token to be generated
    def token_length(token_length)
      self.token_length_var = token_length.to_i
      logger.warn "WARN: Redefining token_length from #{token_length_var} to #{token_length}" if token_length_var
      fail 'token_length must be a positive number greater than 0' if token_length_var < 1
    end
  end

  # Creates a token if not set
  def generate_token
    self.token = loop do
      token = SecureRandom.urlsafe_base64(self.class.token_length_var || DEFAULT_LENGTH).downcase
      break token unless self.class.exists?(token: token)
    end
  end
end