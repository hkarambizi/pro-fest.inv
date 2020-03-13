module OrderHelper
  def order_types
    [
      ['transfer'],
      ['comp'],
      ['spill'],
      ['return'],
      ['loss'],
      ['damage'],
      ['load_in'],
      ['load_out']
    ]
  end

  def order_statuses
    [
      ['submitted'],
      ['pending'],
      ['canceled'],
      ['completed'],
      ['delivered']
    ]
  end

  def progress_bar_status(status)
    case status
    when 'new'
      return "5"
    when 'submitted'
      return "25"
    when 'pending'
      return "50"
    when 'completed'
      return "85"
    when 'delivered'
      return "90"
    when 'canceled'
      return "100"
    else
      return "5"
    end
  end

  def crew_members(event)
    event.account.users.where(permission_level: 2)
  end

  def handle_order(order)
    if order.transactions.length == 0
      return order.update(status: 'canceled', verified_by: current_user.id)
    else
      order.transactions.each do |t|
          process_transaction(t)
      end
      order.update(status: 'delivered', verified_by: current_user.id, assigned_to: nil)
      order.messages.new(message_type: 'order_delivered', created_by: current_user.id, event_id: order.location.event.id, order_id: order.id, location_id: order.location_id).save
    end
  end

  def order_feed(orders)
    return orders.map do |o|
      {
        id: o.id,
        location_id: o.location_id,
        event_id: o.location.event.id,
        text: format_order(o),
        transactions: handle_transactions(o)
      }
    end
  end

  private

  def get_event_locations(transaction)
    return transaction.order.location.event.locations
  end

  def get_loc_by_type(type, locations)
    return locations.find_by(loc_type: type)
  end

  def find_item_match(location, transaction)
    return location.items.find_or_create_by(product_id: transaction.item.product_id)
  end

  def process_transaction(transaction)
    event_locations = get_event_locations(transaction)
    sales_location = get_loc_by_type('sales', event_locations)
    truck_location = get_loc_by_type('truck', event_locations)
    comps_location = get_loc_by_type('comps', event_locations)
    waste_location = get_loc_by_type('waste', event_locations)
    surplus_location = get_loc_by_type('surplus', event_locations)
    case transaction.order.role
    when 'transfer'
      @origin = event_locations.find(transaction.origin_id)
      @destination = event_locations.find(transaction.dest_id)
    when 'sale'
      @origin = transaction.order.location
      @destination = find_item_match(sales_location, transaction).location
    when 'void'
      @origin = find_item_match(sales_location, transaction).location
      @destination = transaction.order.location
    when 'load_in'
      @origin = find_item_match(truck_location, transaction).location
      @destination = event_locations.find(transaction.order.location_id)
    when 'load_out'
      @origin = transaction.order.location
      @destination = find_item_match(truck_location, transaction).location
    when 'damage', 'spill', 'return', 'loss'
      @origin = transaction.order.location
      @destination = find_item_match(waste_location, transaction).location
    when 'comp'
      @origin = transaction.order.location
      @destination = find_item_match(comps_location, transaction).location
    when 'surplus'
      @origin = transaction.order.location
      @destination = find_item_match(surplus_location, transaction).location
    else
      return
    end
    transaction.update(origin_id: @origin.id, dest_id: @destination.id)
    return update_inventories(transaction, @origin, @destination)
  end

def update_inventories(t, origin, destination)
  puts t.order.role + ':' + ' Processing transaction for: ' + t.qty.to_s + ' ' + t.item.product.name + ' at ' + t.order.location.title.to_s
  origin_item = find_item_match(origin, t)
  dest_item = find_item_match(destination, t)
  origin_qty = origin_item.quantity ||= 0;
  puts 'this is the original origin qty: ' + origin_qty.to_s
  dest_qty = dest_item.quantity ||= 0;
  puts 'this is the original destination qty: ' + dest_qty.to_s
  puts 'UPDATING......'
  origin_item.update(quantity: origin_qty - t.qty)
  dest_item.update(quantity: dest_qty + t.qty)
  puts 'this is the NEW origin qty: ' + find_item_match(origin, t).quantity.to_s
  puts 'this is the NEW destination qty: ' + find_item_match(destination, t).quantity.to_s
  t.update(status: "delivered")
  t.order.messages.new(message_type: 'inventory_updated', created_by: current_user.id, event_id: t.order.location.event.id, order_id: t.order.id, location_id: t.order.location_id, item_id: t.item.id, transaction_id: t.id).save
end

def format_order(order)
  info = "##{order.id} [#{order.location.title}] #{order.created_at.strftime("%I:%M%p on %m/%d/%Y")} : #{order.role} by #{user_data(order.created_by)[:full_name]}: "
  if order.status == "canceled"
    return info += "This order has been CANCELED"
  end
  if order.status != 'delivered'
    return info += "This order is #{order.status}..."
  end
  case order.role
  when 'transfer'
    info += "#{order.transactions.length} inventory item(s) included in Order#: #{} (verified by #{user_data(order.verified_by)[:full_name]})"
  when 'sale'
  when 'void'
  when 'load_in'
  when 'load_out'
  when 'comp', 'damage', 'spill', 'return'
  when 'surplus'
  end
  return info
end

def handle_transactions(order)
  if order.transactions.length > 0
    return order.transactions.map do |t|
      format_transaction(t)
    end
  end
end

def format_transaction(transaction)
  transaction_message = "(#{transaction.qty}) of item: #{product_data(transaction).name} has been "
  case transaction.order.role
  when 'transfer'
    transaction_message += "transferred from #{get_event_locations(transaction).find(transaction.origin_id).title} to #{get_event_locations(transaction).find(transaction.dest_id).title}"
  when 'load_in'
    transaction_message += "loaded in to #{get_event_locations(transaction).find(transaction.order.location_id).title}"
  when 'load_out'
    transaction_message += "loaded out to WAREHOUSE"
  when 'sale'
    transaction_message += "sold"
  when 'comp', 'spill', 'damaged', 'return'
    transaction_message += "removed from inventory due to a comp reported by #{user_data(transaction.order.created_by)[:full_name]}"
  when 'void'
    transaction_message += "returned to inventory because of an error"
  when 'surplus'
    transaction_message += "recorded as a surplus item"
  end
  return transaction_message
end

def confirm_order_check(order)
  if order.transactions.where(status: "completed").length == order.transactions.length
    order.update(status: "completed")
  end
end

def user_data(user_id)
  user = User.find(user_id)
  return {
    full_name: "#{user.first_name} #{user.last_name}",
    details:user
  }
end

def product_data(transaction)
  product = Product.find(transaction.item.product_id)
  return product
end

def create_order_message(order, message_type)
  puts "creating order message"
  message = order.messages.new(message_type: message_type, created_by: current_user.id, event_id: order.location.event.id, order_id: order.id, location_id: order.location_id)
  message.save
end

def create_order_transaction_message(t, message_type)
  puts "creating order transaction message"
  order = t.order
  message = order.messages.new(message_type: message_type, created_by: current_user.id, event_id: order.location.event.id, order_id: order.id, location_id: order.location_id, transaction_id: t.id, item_id: t.item_id)
  message.save
end

end
