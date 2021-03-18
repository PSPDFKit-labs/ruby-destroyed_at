require 'test_helper'

describe 'destroying an activerecord instance' do
  let(:post) { Post.create }

  it 'sets the timestamp it was destroyed at' do
    time = Time.now
    Timecop.freeze(time) do
      post = Post.create
      post.destroy
      assert_equal post.destroyed_at, time
    end
  end

  it 'does not delete the record' do
    post.destroy
    assert_empty Post.all
    refute_empty Post.unscoped.load
  end

  it 'sets #destroyed?' do
    post.destroy
    assert post.destroyed?
    post = Post.unscoped.last
    assert post.destroyed?
    post.restore
    refute post.destroyed?
  end

  it 'runs destroy callbacks' do
    assert_nil(post.destroy_callback_count)
    post.destroy
    assert_equal post.destroy_callback_count, 1
  end

  it 'does not run update callbacks' do
    post.destroy
    assert_nil(post.update_callback_count)
    post.restore
    assert_nil(post.update_callback_count)
  end

  it 'decrements the counter cache' do
    author = Author.create
    post = author.posts.create

    assert_equal author.reload.posts_count, 1
    post.destroy
    assert_equal author.reload.posts_count, 0
  end

  it 'stays persisted after destruction' do
    post.destroy
    assert post.persisted?
  end

  it 'destroys dependent relation with DestroyedAt' do
    post.comments.create
    assert_equal Post.count, 1
    assert_equal Comment.count, 1
    post.destroy
    assert_equal Post.count, 0
    assert_equal Comment.count, 0
  end

  it 'destroys dependent through relation with DestroyedAt' do
    commenter = Commenter.create
    Comment.create(post: post, commenter: commenter)

    assert_equal Commenter.count, 1
    assert_equal Comment.count, 1
    post.destroy
    assert_equal Commenter.count, 1
    assert_equal Comment.count, 0
  end

  it 'deletes dependent relations without DestroyedAt' do
    category = Category.create
    Categorization.create(category: category, post: post)
    assert_equal post.categorizations.count, 1
    post.destroy
    assert_equal Categorization.unscoped.count, 0
  end

  it 'destroys child when parent does not mixin DestroyedAt' do
    avatar = Avatar.create
    author = Author.create(avatar: avatar)
    author.destroy!

    assert_equal Author.count, 0
    assert_equal Avatar.count, 0
  end

  it 'destroys child with the correct datetime through an an autosaving association' do
    datetime = 10.minutes.ago

    commenter = Commenter.create

    comment = commenter.comments.build
    commenter.save

    comment.mark_for_destruction(datetime)
    commenter.save

    assert_equal comment.destroyed_at, datetime
  end

end

describe 'restoring an activerecord instance' do
  let(:author) { Author.create }
  let(:timestamp) { Time.current }
  let(:post) { Post.create.tap { |p| p.update(destroyed_at: timestamp) } }

  it 'restores the record' do
    assert_empty Post.all
    post.reload
    post.restore
    assert_nil(post.destroyed_at)
    refute_empty Post.all
  end

  it 'runs the restore callbacks' do
    assert_nil(post.restore_callback_count)
    post.restore
    assert_equal post.restore_callback_count, 1
  end

  it 'does not run restore validations' do
    initial_count = post.validation_count
    post.restore
    assert_equal initial_count, post.validation_count
  end

  it 'restores polymorphic has_many relation with DestroyedAt' do
    comment = Comment.create
    Like.create(likeable: comment)
    comment.destroy

    assert_equal Comment.count, 0
    assert_equal Like.count, 0

    comment.reload
    comment.restore
    assert_equal Comment.count, 1
    assert_equal Like.count, 1
  end

  it 'restores polymorphic has_one relation with DestroyedAt' do
    post = Post.create
    Like.create(likeable: post)
    post.destroy

    assert_equal Post.count, 0
    assert_equal Like.count, 0

    post.reload
    post.restore
    assert_equal Post.count, 1
    assert_equal Like.count, 1
  end

  it 'restores a dependent has_many relation with DestroyedAt' do
    Comment.create(post: post).update(destroyed_at: timestamp)
    assert_equal Comment.count, 0
    post.reload
    post.restore
    assert_equal Comment.count, 1
  end

  it 'does not restore a non-dependent relation with DestroyedAt' do
    assert_equal Post.count, 0
    assert_equal Author.count, 0
    post.reload
    post.restore
    assert_equal Post.count, 1
    assert_equal Author.count, 0
  end

  it 'restores a dependent through relation with DestroyedAt' do
    commenter = Commenter.create
    Comment.create(post: post, commenter: commenter).update(destroyed_at: timestamp)

    assert_equal Commenter.count, 1
    assert_equal Comment.count, 0
    post.reload
    post.restore
    assert_equal Commenter.count, 1
    assert_equal Comment.count, 1
  end

  it 'restores only the dependent relationships destroyed when the parent was destroyed' do
    post = Post.create
    comment_1 = Comment.create(post: post).tap { |c| c.update(destroyed_at: Time.now - 1.day) }
    comment_2 = Comment.create(post: post)
    post.destroy
    post.reload # We have to reload the object before restoring in the test
                # because the in memory object has greater precision than
                # the database records
    post.restore
    refute_includes post.comments, comment_1
    assert_includes post.comments, comment_2
  end
end

describe 'deleting a record' do
  it 'is not persisted after deletion' do
    post = Post.create
    post.delete
    refute post.persisted?
  end

  it 'can delete destroyed records and they are marked as not persisted' do
    post = Post.create
    post.destroy
    assert post.persisted?
    post.delete
    refute post.persisted?
  end
end

describe 'destroying an activerecord instance without DestroyedAt' do
  it 'does not impact ActiveRecord::Relation.destroy' do
    post = Post.create
    categorization  = Categorization.create(post: post)
    post.categorizations.destroy(categorization.id)
    assert_empty post.categorizations
  end
end

describe 'creating a destroyed record' do
  it 'does not allow new records with destroyed_at columns present to be marked persisted' do
    post = Post.create(destroyed_at: Time.now)
    refute post.persisted?
  end
end

describe 'non destroyed-at models' do
  it 'can destroy has_one dependants' do
    person = Person.create!
    person.create_pet!

    person.destroy

    assert_equal(0, Person.count, 'Person must be zero')
    assert_equal(0, Pet.count, 'Pet must be zero')
  end

  it 'can destroy has_many dependants' do
    author = Author.create!
    author.posts.create!

    author.destroy

    assert_equal(0, Author.count, 'Author must be zero')
    assert_equal(0, Post.count, 'Post must be zero')
  end
end

describe 'destroying a child that destroys its parent on destroy' do
  it 'destroys the parent record' do
    parent = Person.create!
    child = DestructiveChild.create!(person: parent)

    child.destroy

    assert_equal(0, Person.count, 'Person must be one')
    assert_equal(0, DestructiveChild.count, 'DestructiveChild must be zero')
  end
end

describe 'destroying on object should call after_commit callback' do
  it 'calls after_commit callback on: :destroy' do
    comment = Comment.create
    comment.destroy

    assert comment.after_committed
  end
end
