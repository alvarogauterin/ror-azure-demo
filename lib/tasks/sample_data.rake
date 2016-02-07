require 'csv'
require 'azure'

task medicine_blob: :environment do
  FitbitAccount.find((ENV['START'].to_i..FitbitAccount.count).to_a).each do |account|
    config = {consumer_key:ENV["FITBIT_CONSUMER_KEY"],consumer_secret:ENV["FITBIT_CONSUMER_SECRET"],token:account.token,secret:account.secret,user_id:account.fitbit_id,unit_system:Fitgem::ApiUnitSystem.METRIC}
    client = Fitgem::Client.new(config)
    client.reconnect(config[:token],config[:secret])
    prepare_blob_container account
    Date.parse("2014-01-01").upto(Date.parse("2014-05-01")) do |date|
      puts "#{account.id} | #{account.email} | #{date}"
      steps = client.intraday_time_series({resource: :steps,date:date.to_s,detailLevel:"1min"})
      if steps.nil?
        puts "#{account.email} is nil"
        next
      else
        steps_safe = steps["activities-steps-intraday"]["dataset"]
        Azure.blobs.create_block_blob(account.fitbit_id.downcase,"fitbit-steps-#{account.fitbit_id.downcase}-#{date.to_s}.json",steps_safe.to_s)
      end
    end
  end
end

namespace :db do
  desc "Fill database with sample data"
  task populate: :environment do
    create_admin_accounts
    create_global_settings
  end
  task fitbit: :environment do
    csv_import_fitbit_accounts
  end
  task medicine: :environment do
    import_300_first_year_medicine_students
  end
  task medicine_blob: :environment do
    export_steps_data_from_300_first_year_medicine_students_into_blob_storage
  end
  task scores: :environment do
    calculate_activity_scores
  end
  task sph_export: :environment do
    export_fitbit_data_for_sph_november_2015
  end
  task sph_merge: :environment do
    merge_fitbit_data_for_sph
  end
  task sph_stats: :environment do
    export_fitbit_account_stats_for_sph
  end
  task messages: :environment do
    import_predefined_messages
  end
  task participation: :environment do
    participation_level_analysis
  end
  task extension: :environment do
    retrieve_names_for_extension_accounts
  end
  task subscriptions: :environment do
    configure_subscriptions
  end
  task insurance: :environment do
    create_insurance_premium_discounts
  end
end

def create_admin_accounts
  password = "fitbit"
  User.create(name:"Alvaro Gauterin",email:"alvaro@gauterin.net",password:password,password_confirmation:password,admin:true)
  User.create(name:"Falk Müller-Riemenschneider",email:"falk.mueller-riemenschneider@nuhs.edu.sg",password:password,password_confirmation:password,admin:true)
  User.create(name:"Aye Mya Win",email:"aye_mya_win@nuhs.edu.sg",password:password,password_confirmation:password,admin:true)
  User.create(name:"Anne Chu Hin Yee",email:"anne.chu@nus.edu.sg",password:password,password_confirmation:password,admin:true)
  User.create(name:"Leonie Uijtdewilligen",email:"leonie_uijtdewilligen@nuhs.edu.sg",password:password,password_confirmation:password,admin:true)
  User.create(name:"Michael Brown",email:"brown@comp.nus.edu.sg",password:password,password_confirmation:password,admin:true)
  User.create(name:"Roman Ernst",email:"roman.ernst@me.com",password:password,password_confirmation:password,admin:false)
  User.create(name:"Geoffrey Tan",email:"geoffrey.tan@gmail.com",password:password,password_confirmation:password,admin:false)
end

def create_global_settings
  Setting.create(key:"autosendnotifications",value:"false")
  Setting.create(key:"donotdisturbstarttime",value:"10 pm")
  Setting.create(key:"donotdisturbendtime",value:"8 am")
  Setting.create(key:"pendingnotificationage",value:"24")
  Setting.create(key:"remindermailfrequency",value:"24")
  Setting.create(key:"lastremindermail",value:"2000-01-01T00:00:00+00:00")
  Setting.create(key:"lastfitbitaccountsupdate",value:"Never")
  Setting.create(key:"lastapicall",value:"Never")
  Setting.create(key:"periodforaverage",value:"7")
  Setting.create(key:"stepgoalreachedperday",value:"10000")
  Setting.create(key:"messagecategories",value:"General Welcome;General Education;General Information;Fitbit Feedback;Goal Setting;Motivation;Reminder Sync;Reminder Wear")
  Setting.create(key:"questionnairecategories",value:"Activities;Mood;Food and Beverages;Social Interaction")
  #default user settings
  Setting.create(key:"realcrypticnames",value:"cryptic")
  Setting.create(key:"tablerows",value:"15")
  Setting.create(key:"weeklyaverage",value:"5000")
  Setting.create(key:"stepsyesterday",value:"5000")
  Setting.create(key:"lastsynctime",value:"24")
  Setting.create(key:"dailystepgoal",value:"10000")
end

def make_users
  admin = User.create!(name:     "Example User",
  email:    "example@railstutorial.org",
  password: "foobar",
  password_confirmation: "foobar",
  admin: true)
  99.times do |n|
    name  = Faker::Name.name
    email = "example-#{n+1}@railstutorial.org"
    password  = "password"
    User.create!(name:     name,
    email:    email,
    password: password,
    password_confirmation: password)
  end
end

def make_microposts
  users = User.all(limit: 6)
  50.times do
    content = Faker::Lorem.sentence(5)
    users.each { |user| user.microposts.create!(content: content) }
  end
end

def make_relationships
  users = User.all
  user  = users.first
  followed_users = users[2..50]
  followers      = users[3..40]
  followed_users.each { |followed| user.follow!(followed) }
  followers.each      { |follower| follower.follow!(user) }
end

def tsv_import_fitbit_accounts
  File.open('Fitbit_Account_OAuth.txt','r') do |infile|
    while (line = infile.gets)
      components = line.split("\t")
      FitbitAccount.create!(email:components[0],token:components[2],secret:components[3],user_id:components[4])
      #TODO: \n after user_id is causing problems
    end
  end
end

def csv_import_fitbit_accounts
  id = 33
  CSV.foreach("importaccounts_processed.csv") do |components|
    # FitbitAccount.create!(email:components[0],fitbit_id:components[1],token:components[2],secret:components[3],phone_number:Random.rand(99999999))
    account = FitbitAccount.create!(id:id,study_id:components[0],email:components[1],phone_number:components[2],fitbit_id:components[3],token:components[4],secret:components[5],week:0)
    FitbitAccount.create_fitbit_subscription account
    id = id + 1
  end
end

def import_300_first_year_medicine_students
  CSV.foreach("accounts.csv") do |components|
    FitbitAccount.create!(email:components[0],fitbit_id:components[1],token:components[2],secret:components[3],phone_number:Random.rand(99999999))
  end
end

def export_steps_data_from_300_first_year_medicine_students_into_blob_storage
  Azure.storage_account_name = ENV['AZURE_STORAGE_ACCOUNT']
  Azure.storage_access_key = ENV['AZURE_STORAGE_ACCESS_KEY']
  FitbitAccount.all.each do |account|
    config = {consumer_key:ENV["FITBIT_CONSUMER_KEY"],consumer_secret:ENV["FITBIT_CONSUMER_SECRET"],token:account.token,secret:account.secret,user_id:account.fitbit_id,unit_system:Fitgem::ApiUnitSystem.METRIC}
    client = Fitgem::Client.new(config)
    client.reconnect(config[:token],config[:secret])
    prepare_blob_container account
    Date.parse("2014-01-01").upto(Date.parse("2014-05-01")) do |date|
      puts "#{account.id} | #{account.email} | #{date}"
      steps = client.intraday_time_series({resource: :steps,date:date.to_s,detailLevel:"1min"})
      if steps.nil?
        puts "#{account.email} is nil"
        next
      else
        steps_safe = steps["activities-steps-intraday"]["dataset"]
        Azure.blobs.create_block_blob(account.fitbit_id.downcase,"fitbit-steps-#{account.fitbit_id.downcase}-#{date.to_s}.json",steps_safe.to_s)
      end
    end
  end
end

# creates a new Azure blob storage container for this policyholder if it does not exist yet
def prepare_blob_container account
  # check if container already exists for this policyholder
  exists = false
  Azure.blobs.list_containers().each do |container|
    if container.name == account.fitbit_id.downcase
      exists = true
      break
    end
  end
  unless exists
    Azure.blobs.create_container(account.fitbit_id.downcase)
  end
end

def calculate_activity_scores
  firstRow = ["Fitbit Account ID"]
  Date.parse("2014-01-01").upto(Date.parse("2014-05-01")) do |date|
    firstRow << date.to_s
  end
  CSV.open("#{Rails.root}/tmp/activity_scores.csv","w") do |csv|
    csv << firstRow
  end
  FitbitAccount.all.each do |account|
    puts "#{account.id} / #{FitbitAccount.all.count} => #{(account.id/FitbitAccount.all.count.to_f*100).round}%"
    config = {consumer_key:ENV["FITBIT_CONSUMER_KEY"],consumer_secret:ENV["FITBIT_CONSUMER_SECRET"],token:account.token,secret:account.secret,user_id:account.fitbit_id,unit_system:Fitgem::ApiUnitSystem.METRIC}
    client = Fitgem::Client.new(config)
    client.reconnect(config[:token],config[:secret])
    steps = client.data_by_time_range("/activities/tracker/steps", {:base_date => "2014-01-01", :end_date => "2014-05-01"})["activities-tracker-steps"]
    minutesFairlyActive = client.data_by_time_range("/activities/tracker/minutesFairlyActive", {:base_date => "2014-01-01", :end_date => "2014-05-01"})["activities-tracker-minutesFairlyActive"]
    minutesVeryActive = client.data_by_time_range("/activities/tracker/minutesVeryActive", {:base_date => "2014-01-01", :end_date => "2014-05-01"})["activities-tracker-minutesVeryActive"]
    if steps.nil? || minutesFairlyActive.nil? || minutesVeryActive.nil?
      puts "#{account.fitbit_id} is nil"
      next
    end
    nextRow = [account.fitbit_id]
    for index in 0..steps.count-1
      stepsValue = steps[index]["value"].to_i
      minutesFairlyActiveValue = minutesFairlyActive[index]["value"].to_i
      minutesVeryActiveValue = minutesVeryActive[index]["value"].to_i
      activeMinutesValue = minutesFairlyActiveValue+minutesVeryActiveValue*2
      if stepsValue <= 10000
        stepsScore = stepsValue/10000.0*60
      else
        stepsScore = 60+(stepsValue-10000)/30000.0*20
      end
      if activeMinutesValue <= 22
        mvpaScore = activeMinutesValue/22.0*40
      else
        mvpaScore = 40+(activeMinutesValue-22)/44.0*20
      end
      activityScore = stepsScore.round+mvpaScore.round
      nextRow << activityScore
    end
    CSV.open("#{Rails.root}/tmp/activity_scores.csv","a") do |csv|
      csv << nextRow
    end
  end
end

def participation_level_analysis
  data_steps = {}
  Date.parse("2014-01-01").upto(Date.parse("2014-05-01")) do |date|
    data_steps[date.to_s] = 0
  end
  FitbitAccount.all.each do |account|
    config = {consumer_key:ENV["FITBIT_CONSUMER_KEY"],consumer_secret:ENV["FITBIT_CONSUMER_SECRET"],token:account.token,secret:account.secret,user_id:account.user_id,unit_system:Fitgem::ApiUnitSystem.METRIC}
    client = Fitgem::Client.new(config)
    client.reconnect(config[:token],config[:secret])
    data = client.data_by_time_range("/activities/tracker/steps", {:base_date => "2014-01-01", :end_date => "2014-05-01"})["activities-tracker-steps"]
    if data.nil?
      puts "#{account.user_id} is nil"
      next
    end
    data.each do |day|
      unless day["value"].to_i == 0
        data_steps[day["dateTime"]] = data_steps[day["dateTime"]] + 1
      end
    end
  end
  CSV.open("#{Rails.root}/tmp/participation_level_analysis.csv","w") do |csv|
    data_steps.each do |date,dataEntry|
      csv << [date,dataEntry]
    end
  end
end

def export_fitbit_data_for_sph
  CSV.foreach("sph_dates.csv") do |components|
    account = FitbitAccount.find_by(email:"fitbitno."+components[1]+"@gmail.com")
    config = {consumer_key:ENV["FITBIT_CONSUMER_KEY"],consumer_secret:ENV["FITBIT_CONSUMER_SECRET"],token:account.token,secret:account.secret,user_id:account.user_id,unit_system:Fitgem::ApiUnitSystem.METRIC}
    client = Fitgem::Client.new(config)
    client.reconnect(config[:token],config[:secret])
    data_steps = {}
    data_calories = {}
    components.delete_if{|component|component.blank?}
    puts "start: #{Date.parse(components[2])}"
    puts "end: #{Date.parse(components[-3])}"
    Date.parse(components[2]).upto(Date.parse(components[-3])) do |date|
      puts ">>> #{account.email} | #{date}"
      dataEntry_steps = client.intraday_time_series({resource: :steps,date:date.to_s,detailLevel:"1min"})
      dataEntry_calories = client.intraday_time_series({resource: :calories,date:date.to_s,detailLevel:"1min"})
      data_steps[date.to_s] = dataEntry_steps["activities-steps-intraday"]["dataset"]
      data_calories[date.to_s] = dataEntry_calories["activities-calories-intraday"]["dataset"]
    end
    file = account.email.split("@").first+"_"+components[2].gsub!("/","-")+"_"+components[-3].gsub!("/","-")+".csv"
    CSV.open("#{Rails.root}/tmp/1min/"+file,"w") do |csv|
      csv << ["fitbit_id","date","time","steps","calories"]
      data_steps.each do |date,dataEntry|
        dataEntry.each_with_index do |chunk,index|
          csv << [components[1],date,chunk["time"],chunk["value"],data_calories[date][index]["value"]]
        end
      end
    end
  end
end

def merge_fitbit_data_for_sph
  File.open("#{Rails.root}/tmp/SPH_Fitbit_Data_Export.csv","w") { |mergedFile|
    Dir.glob("#{Rails.root}/tmp/1min/*.csv").each { |file|
      File.readlines(file).each { |line|
        unless line.start_with?("fitbit")
          mergedFile << line
        end
      }
    }
  }
end

def export_fitbit_account_stats_for_sph
  CSV.open("#{Rails.root}/tmp/fitbit_account_demographics.csv","ab") do |csv|
    csv << ["name","fitbit_id","dateOfBirth","gender","height","weight"]
    FitbitAccount.all.each do |account|
      puts account.id
      config = {consumer_key:ENV["FITBIT_CONSUMER_KEY"],consumer_secret:ENV["FITBIT_CONSUMER_SECRET"],token:account.token,secret:account.secret,user_id:account.fitbit_id,unit_system:Fitgem::ApiUnitSystem.METRIC}
      client = Fitgem::Client.new(config)
      client.reconnect(config[:token],config[:secret])
      info = client.user_info["user"]
      unless info.nil?
        csv << [account.email,account.fitbit_id,info["dateOfBirth"],info["gender"],info["height"],info["weight"]]
      end
    end
  end
end

def export_fitbit_data_for_sph_november_2015
  firstRow = ["Study ID"]
  Date.parse("2015-03-15").upto(Date.today) do |date|
    firstRow << date.to_s
  end
  CSV.open("#{Rails.root}/tmp/iFit_Study_Steps_Export.csv","w") do |csv|
    csv << firstRow
  end
  FitbitAccount.all.each do |account|
    if account.last_sync_time != nil && account.study_id != "Alvaro"
      puts "export_fitbit_data_for_sph_november_2015 | #{account.study_id}"
      config = {consumer_key:ENV["FITBIT_CONSUMER_KEY"],consumer_secret:ENV["FITBIT_CONSUMER_SECRET"],token:account.token,secret:account.secret,user_id:account.fitbit_id,unit_system:Fitgem::ApiUnitSystem.METRIC}
      client = Fitgem::Client.new(config)
      client.reconnect(config[:token],config[:secret])
      data = client.data_by_time_range("/activities/tracker/steps", {base_date:"2015-03-15",end_date:"today"})["activities-tracker-steps"]
      if data.nil?
        puts "#{account.study_id} is nil"
        next
      end
      nextRow = [account.study_id]
      data.each do |day|
        nextRow << day["value"]
      end
      CSV.open("#{Rails.root}/tmp/iFit_Study_Steps_Export.csv","a") do |csv|
        csv << nextRow
      end
    end
  end
end

def import_predefined_messages
  ShortAddress.create(original:"http://www.hpb.gov.sg/HOPPortal/content/conn/HOPUCM/path/Contribution%20Folders/uploadedFiles/HPB_Online/Educational_Materials/Physical%20Activity_A5%20Booklet_Eng.pdf")
  ShortAddress.create(original:"http://m.hpb.gov.sg/mobile/jsp/around_us.jsp?icn=around-me&ici=tools")
  ShortAddress.create(original:"http://www.hpb.gov.sg/HOPPortal/health-article/10346")
  ShortAddress.create(original:"http://www.hpb.gov.sg/HOPPortal/health-article/3998")
  
  PredefinedMessage.create(week:1,day:"First Day",category:"General Welcome",message:"Welcome to the iFit-Study! You recently monitored your activity level with a small device and questionnaire. According to our analysis, you do not meet activity recommendations. We want to help you to become more active. You already received a Fitbit and over the next months you will also receive text messages to encourage you to be more active. Your iFit-Study team")
  PredefinedMessage.create(week:1,day:"Second Day",category:"General Education",message:"<iFit-study> To be more physically active than you are now, here is a booklet to help you plan your activity and exercise. Check out this link: fitsense.sg/1")
  PredefinedMessage.create(week:1,day:"Friday",category:"General Information",message:"<iFit-study> Be active during your leisure time! There are gyms, parks, sport facilities and water activities near you! Use this link to select your activity of interest and then, click GO: fitsense.sg/2")
  
  PredefinedMessage.create(week:2,day:"Monday",category:"Fitbit Feedback",message:"<iFit-study> Your daily step counts for the past week was less than 7,500 on most of the days. Aim for at least 7,500 steps each day as a starting point to reach recommended daily steps of 10,000 to improve your general health!",activity_level:"low")
  PredefinedMessage.create(week:2,day:"Monday",category:"Fitbit Feedback",message:"<iFit-study> Your daily step counts for the past week have reached 7,500 on most of the days.  Please consider aiming to increase your daily steps to 10,000 to meet the recommended healthy level of physical activity!",activity_level:"medium")
  PredefinedMessage.create(week:2,day:"Monday",category:"Fitbit Feedback",message:"<iFit-study> Fantastic! You have reached 10,000 steps daily on most of the days for the past week. Maintain your daily steps consistently to improve your general health!",activity_level:"high")
  PredefinedMessage.create(week:2,day:"Friday",category:"Goal Setting",message:"<iFit-study> To meet the recommended physical activity level, aim to do at least 150 minutes of physical activity every week or walk 10,000 steps every day.")
  
  PredefinedMessage.create(week:3,day:"Monday",category:"Fitbit Feedback",message:"<iFit-study> For the past week, your daily step counts have been below 7,500 on most of the days. Aim for increasing to 7,500 steps each day to reach recommended daily steps of 10,000 and to become a healthy active person!",activity_level:"low")
  PredefinedMessage.create(week:3,day:"Monday",category:"Fitbit Feedback",message:"<iFit-study> Well done! Your daily step counts for the past week have reached 7,500 for at least 5 days.  Take your health to the next level and aim for increasing to 10,000 steps each day!",activity_level:"medium")
  PredefinedMessage.create(week:3,day:"Monday",category:"Fitbit Feedback",message:"<iFit-study> Brilliant! You have accumulated daily steps of 10,000 on most of the days for the past week. Maintain your daily steps consistently for better health!",activity_level:"high")
  PredefinedMessage.create(week:3,day:"Friday",category:"Motivation",message:"<iFit-study> It is not difficult to reach 10,000 steps every day. You can gradually increase your activity level. A 10-minute walk (about 1,000 steps) a day is a great start!")
  
  PredefinedMessage.create(week:4,day:"Monday",category:"Fitbit Feedback",message:"<iFit-study> Your daily step counts for the past week was below 7,500 on most of the days. Aim for increasing to 7,500 steps each day to reach recommended daily steps of 10,000 to improve your physical and mental health!",activity_level:"low")
  PredefinedMessage.create(week:4,day:"Monday",category:"Fitbit Feedback",message:"<iFit-study> You have reached 7,500 steps each day for at least 5 days during the past week.  Well done! Try to increase your daily steps to 10,000 to improve your physical and mental health!",activity_level:"medium")
  PredefinedMessage.create(week:4,day:"Monday",category:"Fitbit Feedback",message:"<iFit-study> Brilliant! You have reached daily steps of 10,000 on most of the days for the past week. Maintain your activity level consistently to improve your physical and mental health!",activity_level:"high")
  PredefinedMessage.create(week:4,day:"Friday",category:"General Information",message:"<iFit-study> Prolonged sitting is not good for your health. The more you sit the poorer your health becomes! Try to reduce overall sitting time and break up prolonged periods of sitting every 30 minutes.")
  
  PredefinedMessage.create(week:5,day:"Monday",category:"Fitbit Feedback",message:"<iFit-study> For the past week, your step counts each day was less than 7,500 on most of the days. Aim for increasing to 7,500 steps each day to reach recommended daily steps of 10,000 to elevate your mood and keep depression at bay!",activity_level:"low")
  PredefinedMessage.create(week:5,day:"Monday",category:"Fitbit Feedback",message:"<iFit-study> Your daily step counts for the past week have reached 7,500 for at least 5 days.  Well done and consider aiming to increase your daily steps to 10,000 to elevate your mood and keep depression at bay!",activity_level:"medium")
  PredefinedMessage.create(week:5,day:"Monday",category:"Fitbit Feedback",message:"<iFit-study> Congratulations!! Your daily step counts have exceeded 10,000 on most of the days for the past week.  Good job! Maintain your active lifestyle to enjoy a happier and more relaxed life.",activity_level:"high")
  
  PredefinedMessage.create(week:6,day:"Monday",category:"General Information",message:"<IFit-study>To reach the goal of 10,000 steps every day; consider incorporating different types of physical activity into your daily life. Here is an interesting article to read on how to adopt a physically active life: fitsense.sg/3")
  
  PredefinedMessage.create(week:7,day:"Monday",category:"Fitbit Feedback",message:"<iFit-study> Your daily step counts for the past week was below 7,500 on most of the days. Try to increase your steps to 7500 each day to reach recommended daily steps of 10,000 to be more energetic and shaper at work!",activity_level:"low")
  PredefinedMessage.create(week:7,day:"Monday",category:"Fitbit Feedback",message:"<iFit-study> Your daily step counts for the past week have reached 7,500 for at least 5 days.  Well done and consider aiming to increase your daily steps to 10,000 to be more energetic and sharper at work!",activity_level:"medium")
  PredefinedMessage.create(week:7,day:"Monday",category:"Fitbit Feedback",message:"<iFit-study> Excellent! You have reached daily steps of 10,000 on most of the days for the past week. Maintain your activity level consistently to increase your productivity!",activity_level:"high")
  
  PredefinedMessage.create(week:8,day:"Monday",category:"Motivation",message:"<iFit-study> Adopt and enjoy an active lifestyle! This can help you lower your stress level, boost your mood and you can live longer. Start today!")
  
  PredefinedMessage.create(week:9,day:"Monday",category:"Fitbit Feedback",message:"<iFit-study> Your daily step counts for the past week was less than 7,500 on most of the days. Aim for increasing to 7,500 steps each day to reach recommended daily steps of 10,000 to maintain and control weight!",activity_level:"low")
  PredefinedMessage.create(week:9,day:"Monday",category:"Fitbit Feedback",message:"<iFit-study> Your daily step counts for the past week have reached 7,500 for at least 5 days.  Well done and consider aiming to increase your daily steps to 10,000 to maintain and control weight!",activity_level:"medium")
  PredefinedMessage.create(week:9,day:"Monday",category:"Fitbit Feedback",message:"<iFit-study> You have exceeded daily steps of 10,000 on most of the days for the past week. Good job! Maintain your daily steps consistently to stay at a healthy weight!",activity_level:"high")
  
  PredefinedMessage.create(week:10,day:"Monday",category:"Motivation",message:"<iFit-study> Reduce your risk of getting chronic disease by adopting an active lifestyle. It is never too late to start.")
  
  PredefinedMessage.create(week:11,day:"Monday",category:"Fitbit Feedback",message:"<iFit-study> Your daily step counts for the past week was less than 7,500 on most of the days. Aim for increasing to 7,500 steps each day to reach recommended daily steps of 10,000 to reduce your risk of getting high blood pressure, heart disease, diabetes and certain cancers!",activity_level:"low")
  PredefinedMessage.create(week:11,day:"Monday",category:"Fitbit Feedback",message:"<iFit-study> For the past week, your step counts have reached 7,500 for at least 5 days.  Well done and consider aiming to increase your daily steps to 10,000 to reduce your risk of getting high blood pressure, heart disease, diabetes and certain cancers!",activity_level:"medium")
  PredefinedMessage.create(week:11,day:"Monday",category:"Fitbit Feedback",message:"<iFit-study> Wonderful! You have accumulated daily steps of 10,000 on most of the days for the past week. Maintain your daily steps consistently to stay away from high blood pressure, heart disease, diabetes and certain cancers!",activity_level:"high")
  
  PredefinedMessage.create(week:12,day:"Monday",category:"Motivation",message:"<iFit-study>To improve your health, sit less and stand more. Take a break from sitting every 30 minutes and stand up.")
  
  PredefinedMessage.create(week:13,day:"Monday",category:"Fitbit Feedback",message:"<iFit-study> Your daily step counts for the past week was less than 7,500 on most of the days. Aim for increasing to 7,500 steps each day to reach recommended daily steps of 10,000 to keep your bones, muscles and joints strong!",activity_level:"low")
  PredefinedMessage.create(week:13,day:"Monday",category:"Fitbit Feedback",message:"<iFit-study> Your daily step counts for the past week have reached 7,500 for at least 5 days.  Well done and consider aiming to increase your daily steps to 10,000 to keep your bones, muscles and joints strong!",activity_level:"medium")
  PredefinedMessage.create(week:13,day:"Monday",category:"Fitbit Feedback",message:"<iFit-study> Fantastic! You have reached daily steps of 10,000 on most of the days for the past week. Maintain your daily steps consistently to enjoy a healthy vibrant life!",activity_level:"high")
  
  PredefinedMessage.create(week:14,day:"Monday",category:"General Information",message:"<iFit-study> The benefits of physical activity are plenty. Here is an interesting article to read on health benefits of being physically active: fitsense.sg/4")
  
  PredefinedMessage.create(week:15,day:"Monday",category:"Fitbit Feedback",message:"<iFit-study> Your daily step counts for the past week was less than 7,500 on most of the days. Aim for increasing to 7,500 steps each day to reach recommended daily steps of 10,000 to ease your stress, tension and fatigue!",activity_level:"low")
  PredefinedMessage.create(week:15,day:"Monday",category:"Fitbit Feedback",message:"<iFit-study> Your daily step counts for the past week have reached 7,500 for at least 5 days.  Well done and consider aiming to increase your daily steps to 10,000 to ease your stress, tension and fatigue!",activity_level:"medium")
  PredefinedMessage.create(week:15,day:"Monday",category:"Fitbit Feedback",message:"<iFit-study> Fantastic! Your daily step counts have exceeded 10,000 on most of the days for the past week. Maintain your daily steps consistently to improve alertness and concentration!",activity_level:"high")
  
  PredefinedMessage.create(week:16,day:"Monday",category:"General Information",message:"<iFit-study> You can increase your step counts gradually. This will help you to be more energetic and increase your productivity.")
  
  PredefinedMessage.create(week:17,day:"Monday",category:"Fitbit Feedback",message:"<iFit-study> Your daily step counts for the past week was less than 7,500 on most of the days. Aim for increasing to 7,500 steps each day to reach recommended daily steps of 10,000 to improve your sleep quality!",activity_level:"low")
  PredefinedMessage.create(week:17,day:"Monday",category:"Fitbit Feedback",message:"<iFit-study> Your daily step counts for the past week have reached 7,500 for at least 5 days.  Well done and consider aiming to increase your daily steps to 10,000 to improve your sleep quality!",activity_level:"medium")
  PredefinedMessage.create(week:17,day:"Monday",category:"Fitbit Feedback",message:"<iFit-study> Brilliant! You have reached daily steps of 10,000 on most of the days for the past week. Maintain your daily steps consistently to have a better sleep quality and more vigorous!",activity_level:"high")

  PredefinedMessage.create(week:18,day:"Monday",category:"Motivation",message:"<iFit-study> How many steps have you walked today? Aim for 10,000 steps every day to enjoy a healthier life! Small incremental steps every day can make a big difference to your overall health.")
  
  PredefinedMessage.create(week:19,day:"Monday",category:"Fitbit Feedback",message:"<iFit-study> Your step counts each day for the past week was less than 7,500 on most of the days. Aim for increasing to 7,500 steps each day to reach recommended daily steps of 10,000 to improve the blood circulation and keep your skin healthy!",activity_level:"low")
  PredefinedMessage.create(week:19,day:"Monday",category:"Fitbit Feedback",message:"<iFit-study> Your daily step counts for the past week have reached 7,500 for at least 5 days.  Well done and consider aiming to increase your daily steps to 10,000 to improve the blood circulation and keep your skin healthy!",activity_level:"medium")
  PredefinedMessage.create(week:19,day:"Monday",category:"Fitbit Feedback",message:"<iFit-study> Congratulations!! Your daily step counts have exceeded 10,000 on most of the days for the past week. Good job! Maintain your active lifestyle to enjoy a healthier and more vibrant life.",activity_level:"high")
  
  PredefinedMessage.create(week:20,day:"Monday",category:"General Information",message:"<iFit-study> Do you want to find new ways to become more active? Try the following link that will guide you through opportunities near you: fitsense.sg/2")
  
  PredefinedMessage.create(week:21,day:"Monday",category:"Fitbit Feedback",message:"<iFit-study> Your daily step counts for the past week was below 7,500 on most of the days. Aim for increasing to 7,500 steps each day to reach recommended daily steps of 10,000 to enhance the quality of life!",activity_level:"low")
  PredefinedMessage.create(week:21,day:"Monday",category:"Fitbit Feedback",message:"<iFit-study> Your daily step counts for the past week have reached 7,500 for at least 5 days.  Well done and consider aiming to increase your daily steps to 10,000 to enhance the quality of life!",activity_level:"medium")
  PredefinedMessage.create(week:21,day:"Monday",category:"Fitbit Feedback",message:"<iFit-study> Brilliant! You have reached daily steps of 10,000 on most of the days for the past week. Maintain your daily steps consistently to increase lifespan and quality of life!",activity_level:"high")
  
  PredefinedMessage.create(week:22,day:"Monday",category:"Motivation",message:"<iFit-study> Engage in physical activity with your family or friends today! It is a good way to bond and stay healthy!")
  
  PredefinedMessage.create(week:23,day:"Monday",category:"Fitbit Feedback",message:"<iFit-study> Your daily step counts for the past week was less than 7,500 on most of the days. Aim for increasing to 7,500 steps each day to reach recommended daily steps of 10,000 to improve your overall brain performance!",activity_level:"low")
  PredefinedMessage.create(week:23,day:"Monday",category:"Fitbit Feedback",message:"<iFit-study> Your daily step counts for the past week have reached 7,500 for at least 5 days.  Well done and consider aiming to increase your daily steps to 10,000 to improve your overall brain performance!",activity_level:"medium")
  PredefinedMessage.create(week:23,day:"Monday",category:"Fitbit Feedback",message:"<iFit-study> Congratulations!! Your daily step counts for the past week have exceeded 10,000 on most of the days.  Good job! Maintain your active lifestyle to enjoy a healthier and happier life.",activity_level:"high")
  
  PredefinedMessage.create(week:24,day:"Monday",category:"General Information",message:"<iFit-study> Have you used the gyms, parks, sport facilities and water activities near you to enjoy active leisure time ? If not, here is another opportunity to do so. Please check out the link: fitsense.sg/2")
  
  PredefinedMessage.create(week:25,day:"Monday",category:"Fitbit Feedback",message:"<iFit-study> Your step counts accumulated each day for the past week was less than 7,500 on most of the days. Aim for increasing to 7,500 steps each day to reach recommended daily steps of 10,000 to help you look good and feel good.",activity_level:"low")
  PredefinedMessage.create(week:25,day:"Monday",category:"Fitbit Feedback",message:"<iFit-study> You have reached 7,500 steps each day for at least 5 days during the past week.  Well done and consider aiming to increase your daily steps to 10,000 to to help you look good and feel good!",activity_level:"medium")
  PredefinedMessage.create(week:25,day:"Monday",category:"Fitbit Feedback",message:"<iFit-study> Congratulations!! Your daily step counts for the past week have exceeded 10,000 on most of the days. Good job! Maintain your active lifestyle to improve your overall health and increase the longevity.",activity_level:"high")
  
  PredefinedMessage.create(week:26,day:"Monday",category:"Motivation",message:"<iFit-study> Increase your step counts by alighting one MRT stop or a few bus stops before your destination. You can also take the stairs at the office, the mall and the MRT station.")
  
  PredefinedMessage.create(category:"Reminder Sync",message:"<iFit-study> Please do not forget to sync your Fitbit regularly. You can monitor your physical activity level and set your own goals to enjoy the health benefits of an active lifestyle.")
  PredefinedMessage.create(category:"Reminder Wear",message:"<iFit-study> Please remember to wear your Fitbit every day. This will help to provide you with additional meaningful information. You can even wear the Fitbit during swimming or showering.")
  PredefinedMessage.create(category:"Reminder Wear",message:"<iFit-study> Are you wearing your Fitbit now? Wearing the Fitbit everyday can help you monitor your daily step counts. If you have forgotten to wear it, start wearing it again.")
end

def retrieve_names_for_extension_accounts
  ExtensionAccount.all.each do |account|
    config = {consumer_key:ENV["FITBIT_CONSUMER_KEY"],consumer_secret:ENV["FITBIT_CONSUMER_SECRET"],token:account.token,secret:account.secret,user_id:account.fitbit_id,unit_system:Fitgem::ApiUnitSystem.METRIC}
    client = Fitgem::Client.new(config)
    client.reconnect(config[:token],config[:secret])
    fullName = client.user_info["user"]["fullName"]
    account.update_attribute(:name,fullName)
  end
end

def configure_subscriptions
  FitbitAccount.all.each do |account|
    FitbitAccount.create_fitbit_subscription account
  end
end

def create_insurance_premium_discounts
  ActivityStatistic.all.each do |statistic|
    statistic.determine
  end
  InsureeAccount.all.each do |account|
    for month in (Time.now.month).downto(0)
      account.insurance_premium_discounts.where(year:Time.now.year,month:month).take.determine
    end
  end
end