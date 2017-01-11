require 'sinatra/base'
require "line/bot"
require "csv"
require "pp"

$ans = {}

def client
  @client ||= Line::Bot::Client.new { |config|
    config.channel_secret = ENV["LINE_CANNEL_SECRET"]
    config.channel_token =  ENV["LINE_TOKEN"]
  }
end

def replytext(text, userId)
  pp $ans
  $ans[userId] ||= []
  p "$ans : " + $ans[userId][1].to_s
  if $ans[userId] != []
    if text[0] != $ans[userId][0][-1]
      $ans = {}
      return "ルール違反ですよ！私の勝ちですね！"
    end
  end

   if text[-1] == "ん"
     $ans = {}
     return "今、「ん」で終わりましたね？！私の勝ちです^^"
   end

  #dic配列に辞書を格納
  #sample[["おゆうぎかい", "おゆうぎ会", "固有名詞"][...][...]]
  dic =  CSV.read("./hatena_dic.txt", :col_sep => "\t")

  #dicの中から条件を指定して抽出
  dic.select!{|item|
    item[0][0] == text[-1]
  }

  #暗黙のリターン　最後に実行された文の返り値が返される
  $ans[userId] = dic.sample
  losecoment =  ""
  if $ans[userId][0][-1] == "ん"
    losecoment << "\n\nあ、、、「ん」で終わっちゃいました、私の負けです"
    ans = $ans[userId][0]
    $ans = {}
    return ans + losecoment
  end
  p $ans[userId][0]
  return $ans[userId][1]
end

def test
  loop do
    print "YOU : "
    puts "BOT : " + replytext(gets.chomp, "dummyUserId")
  end
end

class Server < Sinatra::Base
  get '/' do
    "Hello World"
  end

  post '/callback' do
    body = request.body.read

    signature = request.env['HTTP_X_LINE_SIGNATURE']
    unless client.validate_signature(body, signature)
      error 400 do 'Bad Request' end
    end

    events = client.parse_events_from(body)
    events.each { |event|
      case event
      when Line::Bot::Event::Message
        case event.type
        when Line::Bot::Event::MessageType::Text
          message = {
            type: 'text',
            text: replytext(event.message['text'], event["source"]["userId"])
          }

          p message[:text]
          client.reply_message(event['replyToken'], message)
        when Line::Bot::Event::MessageType::Image, Line::Bot::Event::MessageType::Video
          response = client.get_message_content(event.message['id'])
          tf = Tempfile.open("content")
          tf.write(response.body)
        end
      end
    }

    "OK"
  end
end
