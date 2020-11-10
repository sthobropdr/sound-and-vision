class SongsController < ApplicationController
  skip_before_action :verify_authenticity_token, only: [:buy]
  before_action :authenticate_user!, except: [:buy]
  before_action :set_song, only: [:show, :edit, :update, :destroy, :buy, :success]
  before_action :set_user_artists, only: [:new, :edit]
  before_action :set_genres, only: [:show, :edit, :update, :new]

  def index
    @songs = Song.where(available: true)
  end

  def show
  end

  def buy
    price = nil

    if params[:type] == "1"
      price = @song.price
    elsif params[:type] == "2"
      price = @song.exclusive_price
    end
    
    Stripe.api_key = ENV['STRIPE_API_KEY']

    session = Stripe::Checkout::Session.create({
        payment_method_types: ['card'],
        mode: 'payment',
        customer_email: current_user.email,
        success_url: success_url(params[:id], params[:type]),
        cancel_url: cancel_url(params[:id]),
        line_items: [
          {
            price_data: {
              currency: 'aud',
              product_data: {
                name: "#{@song.name} - song by #{@song.artist.name}",
                description: @song.description,
                images: [url_for(@song.artist.image)]
              },
              unit_amount: (price.to_f * 100).to_i
            },
            quantity: 1
          }
        ]
    })

    render json: session
  end

  def success
    @song.increment!(:purchases)
    if params[:type] == "2"
      @song.update_attribute(:available, false)
    end
  end

  def cancel
    render plain: "The transaction was cancelled!"
  end

  def new
    @song = Song.new
  end

  def create
    song = Song.create(song_params)
    if song.id.nil?
      flash[:alert] = song.errors.full_messages.join().capitalize
      redirect_to new_song_path(song)
    else
      redirect_to song_path(song)
    end
  end

  def edit
  end

  def update
    @song.update(song_params)
    redirect_to song_path(@song)
  end

  def destroy
    @song.destroy
    redirect_to songs_path
  end

  private

  def set_song
    @song = Song.find(params[:id])
  end

  def set_song_artist
    song = set_song
    @artist = song.artist_id
  end

  def set_user_artists
    @artists = Artist.where(user_id: current_user.id)
  end

  def set_genres
    @genres = Genre.all
  end

  def song_params
    params.require(:song).permit(:song_file, :name, :description, :price, :exclusive_price, :artist_id, genre_ids: [])
  end
end