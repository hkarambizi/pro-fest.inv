class LocationsController < ApplicationController
  def index
    @locations = Location.all
  end

  def new
    @location = Location.new
  end

  def create
    location = Location.new(location_params)
    if location.save
      flash[:success] = "Location added!"
      redirect_to locations_path
    else
      render 'new'
    end

    def show
    @location = Location.find(params[:id])
  end

  end

  private

  def location_params
    params.require(:location).permit(:title, :address, :latitude, :longitude)
    # .merge(:event_id => params[:event_id])
  end
end
