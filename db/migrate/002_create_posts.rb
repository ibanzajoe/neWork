Sequel.migration do
  up do
    create_table :posts do
      primary_key :id
      Fixnum :user_id
      String :title, :size => 64
      String :content
      DateTime :created_at
      DateTime :updated_at
    end
  end

  down do
    drop_table :posts
  end
end