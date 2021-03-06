# This is the main router file
# You can also create your own controllers in app/controllers/

module Honeybadger

  class SiteApp < Padrino::Application

    register Padrino::Mailer
    register Padrino::Helpers
    register WillPaginate::Sinatra
    enable :sessions
    enable :reload
    #layout :site
    layout :forescout


    ### this runs before all routes ###
    before do
      @title = "Honeybadger CMS"
      @page = (params[:page] || 1).to_i
      @per_page = params[:per_page] || 5
    end      

    ### authentication routes ###
    auth_keys = settings.auth # @todo: settings is not available in Builder

    use OmniAuth::Builder do

      # /auth/twitter
      provider :twitter,  auth_keys[:twitter][:key], auth_keys[:twitter][:secret]

      # /auth/instagram
      provider :instagram,  auth_keys[:instagram][:key], auth_keys[:instagram][:secret]

    end

    get '/auth/:name/callback' do
      auth    = request.env["omniauth.auth"]
      user = User.login_with_omniauth(auth)

      if user
        session[:user] = user

        if user.email.blank?
          redirect("/user/account", :notice => 'Please fill in required informations')
        end

        redirect("/")
      else
        output(user.values)
      end
    end

    get "/user/account" do
      @user = session[:user]
      render "account"
    end

    post "/user/account" do

      rules = {
        :email => {:type => 'email', :required => true},
        :first_name => {:type => 'string', :required => true},
        :last_name => {:type => 'string', :required => true},
      }
      validator = Validator.new(params, rules)

      @user = session[:user]
      @user.email = params[:email]
      @user.first_name = params[:first_name]
      @user.last_name = params[:last_name]
      @user.username = params[:username]
      @user.gender = params[:gender]
      @user.occupation = params[:occupation]
      @user.immigration = params[:immigration]
      @user.birth_month = params[:birth_month]
      @user.birth_day = params[:birth_day]
      @user.birth_year = params[:birth_year]
      @user.self_summary = params[:self_summary]
      if params[:picture]
        filename = params[:picture][:filename]
        tempfile = params[:picture][:tempfile]
        target = "/images/#{filename}"
        local_dest = Dir.pwd + "/public" + target

        FileUtils.mv(tempfile.path, local_dest)
        temp_pic = Picture.where(:user_id => params[:user_id]).first
        if temp_pic == nil
          picture = Picture.new(:user_id => params[:user_id], :image_url => target, :main_pic => "true")
          @user.have_pic = true
          picture.save
        else
          picture = Picture.new(:user_id => params[:user_id], :image_url => target, :main_pic => "false")
          @user.have_pic = true
          picture.save
        end

      end


      if !validator.valid?
        flash.now[:notice] = validator.errors[0][:error]
        render "account"
      else
        @user.save_changes
        redirect("/user/account", :success => 'Account information updated!')
      end

    end

    get "/user/login" do
      render "login"
    end

    post "/user/login" do

      rules = {
        :email => {:type => 'email', :required => true},
        :password => {:type => 'string', :required => true},
      }
      validator = Validator.new(params, rules)
      if !validator.valid?
        flash.now[:notice] = validator.errors[0][:error]
        render "login"
      else
        user = User.login(params)
        if user.errors.empty?
          session[:user] = user
          flash[:success] = "You are now logged in"
          redirect("/")
        else
          flash.now[:notice] = user.errors[:validation][0]
          render "login"
        end        
      end

    end

    get "/user/logout" do
      session.delete(:user)
      redirect("/")
    end

    get "/user/register" do
      render "register"
    end

    post "/user/register" do

      rules = {
        :first_name => {:type => 'string', :required => true},
        :last_name => {:type => 'string', :required => true},
        :email => {:type => 'email', :required => true},
        :password => {:type => 'string', :required => true},
      }
      validator = Validator.new(params, rules)
      if !validator.valid?
        flash.now[:notice] = validator.errors[0][:error]
        render "register"
      else

        user = User.register_with_email(params)
        if user.errors.empty?
          session[:user] = user
          redirect("/user/account")
        else
          flash.now[:notice] = user.errors[:validation][0]
          render "register"
        end

      end

    end


    ### put your routes here ###
    get '/' do
      @posts = Post.order(:id).paginate(@page, @per_page).reverse
      render "index"
    end

    ### view page ###
    #get '/:title/:id' do
    #  @post = Post[params[:id]]
    #  render "post"
    #end

    get '/about' do
      render "about"
    end

    post '/user/identity' do
      if params[:identity_id] == ""
        identity = Identity.new(params)
        identity.save
        redirect "/user/account"
      else
        identity = Identity.where(:id => params[:identity_id]).update(:username => params[:username], :gender => params[:gender], :birthday => params[:birthday])
        redirect "/user/account"
      end
    end

    post '/user/profile' do
      if params[:profile_id] == ""
        profile = Profile.new(params)
        profile.save
        redirect "/user/account"
      else
        profile = Profile.where(:id => params[:profile_id]).update(:summary => params[:summary])
        redirect "/user/account"
      end
    end

    post '/user/pictures' do
      if params[:picture]
        filename = params[:picture][:filename]
        tempfile = params[:picture][:tempfile]
        target = "/images/#{filename}"
        local_dest = Dir.pwd + "/public" + target

        FileUtils.mv(tempfile.path, local_dest)
        temp_pic = Picture.where(:user_id => params[:user_id]).first
        if temp_pic == nil
          picture = Picture.new(:user_id => params[:user_id], :image_url => target, :main_pic => "true")
          picture.save
        else
          picture = Picture.new(:user_id => params[:user_id], :image_url => target, :main_pic => "false")
          picture.save
        end

      end
      redirect "/user/account"
    end

    post '/user/picture_delete' do
      pic = Picture.where(:id => params[:id]).first
      pic.delete
    end

    get '/user/profile' do
      @identity = Identity.first
      @profile = Profile.first
      @picture = Picture.all
      render "profile_list"
    end


    get '/user/profile/:user_id' do
      userID = params[:user_id]
      @user = User.where(:id => userID).first
      @picture = Picture.where(:user_id => userID).all
      render "user_profile"
    end

    get '/display_users' do
      if session[:user][:id].nil?
        render "please_login"
      else
        sex = User.where(:id => session[:user][:id]).first[:gender]
        if sex == "male"
          @users = User.where(:gender => "female").all
          @pictures = Picture.all

          render "display_users"
        else
          @users = User.where(:gender => "male").all
          @pictures = Picture.all

          render "display_users"
        end
      end


    end

    post '/user/change_picture' do
      make_main = Picture.where(:id => params[:id]).first
      user_id = make_main[:user_id]
      pic_to_change = Picture.where(:user_id => user_id, :main_pic => "true").first
      make_main[:main_pic] = "true"
      pic_to_change[:main_pic] = "false"
      make_main.save
      pic_to_change.save
      p "*************************"
      p user_id
      p pic_to_change

    end

    get '/viewprofile/:id' do
      @identity = Identity.where(:user_id => params[:id]).first


      render "user_profile"
    end

    get '/forescout' do
      render "forescout"
    end

    get '/forescout/:id' do
      render "page#{params[:id]}"
    end


    

  end


end
