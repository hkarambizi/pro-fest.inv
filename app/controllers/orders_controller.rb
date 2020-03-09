class OrdersController < ApplicationController
  include OrderHelper

  before_action :set_account
  before_action :set_location, except: [:orders_by_account, :orders_by_event,:feed, :assign_order]
  before_action :set_event, only: [:index, :feed, :orders_by_event,:edit, :update, :destroy, :show, :verify, :submit, :pickup, :dropoff, :assign_order]
  before_action :invalid_transactions, only: [:confirm]

  def index
    @orders = @event.orders
    @locations = @event.locations
  end

  def orders_by_account
    @orders = @account.orders
  end

  def orders_by_event
    @locations = @event.locations.where(hidden: nil)
    @users = User.where(account_id: @event.account.id)
  end

  def feed
    @orders = @event.orders
    @locations = @event.locations
    @users = User.where(account_id: @event.account.id)
    @products = @account.products
    @feed_orders = order_feed(@orders)
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
    @canceled = @order.status == "canceled"
    @can_edit = !["delivered", "completed", "canceled", "submitted", "pending"].include?(@order.status)
    @can_submit = @order.transactions.length > 0 && @order.status == nil
    @no_confirm = invalid_transactions || @canceled || @order.status == 'delivered'
    puts "can confirm: #{@no_confirm}"
    puts "is editable: #{@can_edit}"
    puts "can submit?: #{@can_submit}"
    puts "Has Invalid Transactions: #{invalid_transactions}"
  end

  def edit
    @order = @location.orders.find(params[:id])
  end

  def update
    order = @location.orders.find(params[:id])
    respond_to do |format|

      if order.update_attributes(order_params)

          create_order_message(order, "order_#{order.status}")
          # To-do: move this into a helper method
          if(order.status === 'canceled')
            order.transactions.each do |t|
              t.update(status: 'canceled')
            end
          end
        format.html { redirect_to event_location_order_path(event_id: @event.id, location_id: @location.id, id: order.id ), notice: 'Order was successfully updated.' }
        format.json { render :show, status: :ok, location: order }
      else
        format.html { render :edit }
        format.json { render json: order.errors, status: :unprocessable_entity }
      end
    end
  end

  def verify
    @order = @location.orders.find(params[:id])
    # @transactions = @order.transactions
    if !invalid_transactions
      handle_order(@order)
      redirect_to event_location_order_path(event_id: @event.id, location_id: @location.id, id: @order.id ), notice: 'Order was successfully verified.'
    else
      render json: 'error: Transactions are not fulfilled', status: :bad_request
  end
end

def submit
  @order = @location.orders.find(params[:id])
  respond_to do |format|
    if @order.update_attributes(status: "submitted")
        create_order_message(@order, "order_submitted")
      format.html { redirect_to event_location_order_path(event_id: @event.id, location_id: @location.id, id: @order.id ), notice: 'Order was successfully submitted.' }
      format.json { render :show, status: :ok, location: order }
    else
      format.html { render :edit }
      format.json { render json: order.errors, status: :unprocessable_entity }
    end
  end
end

def pickup
  @origin = @event.locations.find(params[:origin])
  @order = @location.orders.find(params[:id])
  @picked_up = @order.transactions.where(origin_id: @origin.id)
  respond_to do |format|
    if @order.update_attributes(status: "pending", assigned_to: current_user.id)
        @picked_up.each do |t|
          t.update(status:"in_progress")
          create_order_transaction_message(t, "item_pick_up")
        end
      format.html { redirect_to event_location_order_path(@event,@location,@order), notice: "Order was successfully pickup up from #{@origin.title}" }
      format.json { render :show, status: :ok, location: order }
    else
      format.html { render :edit }
      format.json { render json: order.errors, status: :unprocessable_entity }
    end
  end
end

def dropoff
  @destination = @event.locations.find(params[:dest])
  @order = @location.orders.find(params[:id])
  @dropped_off = @order.transactions.where(dest_id: @destination.id)
  respond_to do |format|
    if @order.update(status: "pending")
        @dropped_off.each do |t|
          t.update(status:"completed", delivered_by: current_user.id)
          create_order_transaction_message(t, "item_drop_off")
        end
        confirm_order_check(@order)
      format.html { redirect_to event_location_order_path(@event,@location,@order), notice: "Order was successfully dropped off at #{@destination.title}" }
      format.json { render :show, status: :ok, location: order }
    else
      format.html { render :edit }
      format.json { render json: order.errors, status: :unprocessable_entity }
    end
  end
end

def assign_order
  @order = @event.orders.find(params[:id])
  assigned = params[:order][:assigned_to]
  respond_to do |format|
    if @order.update_attributes(status: "pending", assigned_to: assigned)
      create_order_message(@order, "order_assigned")
      format.html { redirect_to event_path(@event), notice: "Order was successfully assigned to user #{assigned}" }
      format.json { render :show, status: :ok, location: order }
    else
      format.html { render :edit }
      format.json { render json: order.errors, status: :unprocessable_entity }
    end
  end
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
    .permit(:message, :role, :origin_id, :destination_id, :due_date, :verified_by, :status, :assigned_to)
    .merge(:created_by => current_user.id, location_id: @location.id)
  end

  def set_account
    @account = Account.find(current_user.account_id)
  end

  def set_transactions
    return Order.find(params[:id]).transactions
  end

  def invalid_transactions
    invalid = false
    set_transactions.each do |t|
      if !['completed', 'verified', 'delivered'].include?(t.status)
        invalid = true
      end
    end
    return invalid
  end

end
