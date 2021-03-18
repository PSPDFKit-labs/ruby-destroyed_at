require 'test_helper'

describe 'Scopes' do
  let(:post)     { Post.create! }
  let(:comment_1)  { post.comments.create! }
  let(:comment_2)  { post.comments.create! }
  let(:comment_3)  { Comment.create! }
  let(:comment_4)  { Comment.create! }

  before do
    comment_1
    comment_2.destroy
    comment_3
    comment_4.destroy
  end

  describe '.destroyed' do
    context 'Called on model' do
      let(:destroyed_comments) { Comment.destroyed }

      it 'returns records that have been destroyed' do
        assert_includes destroyed_comments, comment_2
        assert_includes destroyed_comments, comment_4
      end

      it 'does not return current records' do
        refute_includes destroyed_comments, comment_1
        refute_includes destroyed_comments, comment_3
      end
    end

    context 'Called on relation' do
      let(:destroyed_comments) { post.comments.destroyed }

      it 'returns destroyed records beloning in the relation' do
        assert_includes destroyed_comments, comment_2
      end

      it 'does not return destroyed records that are outside the relation' do
        refute_includes destroyed_comments, comment_4
      end

      it 'does not return current records in the relation' do
        refute_includes destroyed_comments, comment_1
      end

      it 'does not return current records that are outside the relation' do
        refute_includes destroyed_comments, comment_3
      end
    end

    context 'Called on a child relation and passing in a destroyed_at time' do
      let(:destroyed_comments) { post.comments.destroyed(post.destroyed_at) }

      before do
        post.destroy
        comment_2.restore
        comment_2.destroy(post.destroyed_at - 1.hour)
      end

      it 'returns all child records with a destroyed_at time that matches the passed in time' do
        assert_includes destroyed_comments, comment_1
      end

      it 'does not return child records with a destroyed_at time that does not match the passed in time' do
        refute_includes destroyed_comments, comment_2
        refute_includes destroyed_comments, comment_3
        refute_includes destroyed_comments, comment_4
      end
    end
  end
end
