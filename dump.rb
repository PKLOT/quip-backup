require 'faraday'
require 'json'
require 'fileutils'
require 'erb'
require 'base64'

@html_template=ERB.new(open("template.html").read)
access_token = "PERSONAL ACCESS TOKEN"


@conn = Faraday.new(
  url: 'https://platform.quip.com',
  headers: { Authorization: "Bearer #{access_token}"}
)

def fix_title(t)
  t=t.gsub("/","-")
  t.gsub(" ","_")
end

def dump_folder(path, folder_id)
  data = JSON.parse(@conn.get("1/folders/#{folder_id}").body)

  if data['folder'].nil? #沒權限會走這邊
    puts "folder_id #{folder_id} Error!"
    puts data.inspect
    return
  end

  title = fix_title(data["folder"]["title"])
  puts ("  " * path.length) + title
  children = data['children']
  children.each do |child|
    if child['folder_id']
      dump_folder(path+[title], child['folder_id'])

    elsif child['thread_id']
      if Dir.glob(File.join(path, title, child['thread_id'])+"*").empty?
        dump_thread(path+[title], child['thread_id'])
      else
        puts "thread_id: #{child['thread_id']} exists!"
      end
    else
      puts "something wrong: #{child}"
    end
  end
end

def dump_thread(path,thread_id)
  FileUtils.mkdir_p(File.join(path))

  data = JSON.parse(@conn.get("1/threads/#{thread_id}").body)

  if data['thread'].nil? # 沒權限會走這邊
    puts "thread_id #{thread_id} Error!"
    puts data.inspect
    return
  end

  title=fix_title(data["thread"]["title"])
  puts ("  " * path.length) + title
  #puts data.inspect
  if data["html"]
    open(File.join(path, "#{thread_id}-#{title}.html"),'w'){|f| f.write(@html_template.result_with_hash(html: replace_image(data["html"])) )}

  else
    puts data
  end
end

def replace_image(html)
  html = html.gsub(/src=["']\/blob\/(.*?)['"]/) do |g|
    result = @conn.get("1/blob/"+$1)
    "src='#{'data:;base64,' + Base64.strict_encode64(result.body)}'"
  end
end

puts @conn.get('1/users/current').body
dump_folder(["dump"],ROOT_FOLDER_ID)

