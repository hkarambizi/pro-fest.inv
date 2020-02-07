class OrdersController < ApplicationController

  before_action :set_account
  before_action :set_location, except: [:orders_by_account, :orders_by_event]
  before_action :set_event, only: [:index, :orders_by_event,:edit, :update, :destroy, :show]

  def index
    @orders = @event.orders
    @locations = @event.locations
  end

  def orders_by_account
    @orders = @account.orders
  end

  def orders_by_event
    @orders = @event.orders
    @locations = @event.locations
  end

  def orders_by_location
    @location = Location.find(params[:location_id])
    @orders = @location.orders
  end

  def new
    @order = @location.orders.new

    render :new
  end

  def create
    puts "create"
    puts @orders
    @event = @location.event
    @order = @location.orders.new(order_params)
      respond_to do |format|
        if @order.save
          format.html { redirect_to event_location_order_path(event_id: @event.id, location_id: @location.id, id: @order.id ), notice: 'Order was successfully created.' }
          format.json { render json: @order, status: :created } # Redirect Maybe?
        else
          format.html { render :new }
          format.json { render json: @order.errors, status: :unprocessable_entity }
        end
      end
  end

  def show
    @order = @location.orders.find(params[:id])
    @transactions = @order.transactions
  end

  def update
    order = @location.orders.find(params[:id])
    order.update(order_params)

    redirect_to location_orders_path
  end

  def edit
    @order = @location.orders.find(params[:id])
  end


  private

  def set_event
    @event = Event.find(params[:event_id])
  end

  def set_location
    @location = Location.find(params[:location_id])
  end

  def order_params

    return params.require(:order)
    .permit(:message, :role, :origin_id, :destination_id, :due_date, :status, :verified_by)
    .merge(:created_by => current_user.id, location_id: @location.id)
  end

  def set_account
    @account = Account.find(current_user.account_id)
  end



end
