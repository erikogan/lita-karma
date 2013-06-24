require "spec_helper"

describe Lita::Handlers::Karma, lita: true do
  before { Lita.config.handlers.karma.cooldown = nil }

  it { routes("foo++").to(:increment) }
  it { routes("foo--").to(:decrement) }
  it { routes("foo~~").to(:check) }
  it { routes("#{robot.name}: karma best").to(:list_best) }
  it { routes("#{robot.name}: karma worst").to(:list_worst) }
  it { routes("#{robot.name}: karma modified").to(:modified) }
  it { routes("#{robot.name}: karma").to(:list_best) }
  it { routes("#{robot.name}: foo += bar").to(:link) }
  it { routes("#{robot.name}: foo -= bar").to(:unlink) }

  describe "#increment" do
    it "increases the term's score by one and says the new score" do
      expect_reply("foo: 1")
      send_test_message("foo++")
    end

    it "matches multiple terms in one message" do
      expect_replies("foo: 1", "bar: 1")
      send_test_message("foo++ bar++")
    end

    it "doesn't start from zero if the term already has a positive score" do
      send_test_message("foo++")
      expect_reply("foo: 2")
      send_test_message("foo++")
    end

    it "replies with a warning if term increment is on cooldown" do
      Lita.config.handlers.karma.cooldown = 10
      send_test_message("foo++")
      expect_reply(/cannot modify foo/)
      expect_no_reply(/foo:/)
      send_test_message("foo++")
    end
  end

  describe "#decrement" do
    it "decreases the term's score by one and says the new score" do
      expect_reply("foo: -1")
      send_test_message("foo--")
    end

    it "matches multiple terms in one message" do
      expect_replies("foo: -1", "bar: -1")
      send_test_message("foo-- bar--")
    end

    it "doesn't start from zero if the term already has a positive score" do
      send_test_message("foo++")
      expect_reply("foo: 0")
      send_test_message("foo--")
    end

    it "replies with a warning if term increment is on cooldown" do
      Lita.config.handlers.karma.cooldown = 10
      send_test_message("foo--")
      expect_reply(/cannot modify foo/)
      expect_no_reply(/foo:/)
      send_test_message("foo--")
    end
  end

  describe "#check" do
    it "says the term's current score" do
      expect_reply("foo: 0")
      send_test_message("foo~~")
    end

    it "matches multiple terms in one message" do
      expect_replies("foo: 0", "bar: 0")
      send_test_message("foo~~ bar~~")
    end
  end

  describe "#list" do
    it "replies with a warning if there are no terms" do
      expect_reply(/no terms being tracked/)
      send_test_message("#{robot.name}: karma")
    end

    context "with modified terms" do
      before do
        send_test_message(
          "one++ one++ one++ two++ two++ three++ four++ four-- five--"
        )
      end

      it "lists the top 5 terms by default" do
        expect_reply <<-MSG.chomp
1. one (3)
2. two (2)
3. three (1)
4. four (0)
5. five (-1)
MSG
        send_test_message("#{robot.name}: karma")
      end

      it 'lists the bottom 5 terms when passed "worst"' do
        expect_reply <<-MSG.chomp
1. five (-1)
2. four (0)
3. three (1)
4. two (2)
5. one (3)
MSG
        send_test_message("#{robot.name}: karma worst")
      end

      it "limits the list to the count passed as the second argument" do
        expect_reply <<-MSG.chomp
1. one (3)
2. two (2)
MSG
        send_test_message("#{robot.name}: karma best 2")
      end
    end
  end

  describe "#link" do
    it "says that it's linked term 2 to term 1" do
      expect_reply("bar has been linked to foo.")
      send_test_message("#{robot.name}: foo += bar")
    end

    it "says that term 2 was already linked to term 1 if it was" do
      send_test_message("#{robot.name}: foo += bar")
      expect_reply("bar is already linked to foo.")
      send_test_message("#{robot.name}: foo += bar")
    end

    it "causes term 1's score to be modified by term 2's" do
      send_test_message("foo++ bar++ baz++")
      send_test_message("#{robot.name}: foo += bar")
      send_test_message("#{robot.name}: foo += baz")
      expect_reply(/foo: 3 \(1\), linked to: ba[rz]: 1, ba[rz]: 1/)
      send_test_message("foo~~")
    end
  end

  describe "#unlink" do
    it "says that it's unlinked term 2 from term 1" do
      send_test_message("#{robot.name}: foo += bar")
      expect_reply("bar has been unlinked from foo.")
      send_test_message("#{robot.name}: foo -= bar")
    end

    it "says that term 2 was not linked to term 1 if it wasn't" do
      expect_reply("bar is not linked to foo.")
      send_test_message("#{robot.name}: foo -= bar")
    end

    it "causes term 1's score to stop being modified by term 2's" do
      send_test_message("foo++ bar++")
      send_test_message("#{robot.name}: foo += bar")
      send_test_message("#{robot.name}: foo -= bar")
      expect_reply("foo: 1")
      send_test_message("foo~~")
    end
  end

  describe "#modified" do
    it "replies with the required format if a term is not provided" do
      expect_reply(/^Format:/)
      send_test_message("#{robot.name}: karma modified")
    end

    it "replies with the required format if the term is an empty string" do
      expect_reply(/^Format:/)
      send_test_message("#{robot.name}: karma modified '   '")
    end

    it "replies with a message if the term hasn't been modified" do
      expect_reply(/never been modified/)
      send_test_message("#{robot.name}: karma modified foo")
    end

    it "lists users who have modified the given term" do
      allow(Lita::User).to receive(:find_by_id).and_return(user)
      send_test_message("foo++")
      expect_reply(user.name)
      send_test_message("#{robot.name}: karma modified foo")
    end
  end
end
