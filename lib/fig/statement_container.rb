module Fig; end

# Something which holds onto a set of Statement objects.
module Fig::StatementContainer
  # Block will receive a Statement.
  def walk_statements(&block)
    @statements.each do |statement|
      yield statement
      statement.walk_statements &block
    end

    return
  end
end
