class SalesController < ApplicationController
  # before_action :set_store

  # protect_from_forgery with: :null_session

  before_action :set_sale , except: [:index , :new]
  before_action :populate_items , only: [:create_custom_customer , :create_custom_item , :empty_cart ,:add_item , :remove_item , :update_line_item_options , :edit , :update_customer_options , :create_line_item]
  before_action :populate_customers , only: [:populate_customers , :edit]

  def index
    @sales = current_company.sales.paginate(page: params[:page], per_page: 20).order(id: :desc)
  end

  def new
    @sale = current_user.sales.create
    redirect_to edit_sale_path(@sale)
  end

  def edit
    # set_sale
    # populate_items
    # populate_customers

    @sale.line_items.build
    @sale.payments.build

    @custom_item = current_company.items.new
    @custom_customer = current_company.customers.new
  end

  def destroy
    # set_sale

    if current_user.can_update_items == true
      @sale.destroy
    else
      redirect_to @sale, notice: 'You do not have permission to delete sales.'
    end
    
    respond_to do |format|
      format.html { redirect_to sales_url, notice: 'Sale has been deleted.' }
    end
  end

  # Generate Invoice
  def invoice

  end

  # searched Items
  def update_line_item_options
    # set_sale
    # populate_items

    if params[:search][:item_category].blank?
      @available_items = current_company.items.all.where('name ILIKE ? AND published = true OR description ILIKE ? AND published = true OR sku ILIKE ? AND published = true', "%#{params[:search][:item_name]}%", "%#{params[:search][:item_name]}%", "%#{params[:search][:item_name]}%").limit(5) || []
    elsif params[:search][:item_name].blank?
      @available_items = current_company.items.where(item_category_id: params[:search][:item_category]).limit(5) || []
    else
      @available_items = current_company.items.all.where('name ILIKE ? AND published = true AND item_category_id = ? OR description ILIKE ? AND published = true AND item_category_id = ? OR sku ILIKE ? AND published = true AND item_category_id = ?', "%#{params[:search][:item_name]}%", "#{params[:search][:item_category]}", "%#{params[:search][:item_name]}%", "#{params[:search][:item_category]}", "%#{params[:search][:item_name]}%", "#{params[:search][:item_category]}").limit(5) || []
    end

    respond_to do |format|
      format.js { ajax_refresh }
    end
  end

  def update_customer_options
    # set_sale
    # populate_items
    @available_customers = current_company.customers.all.where('last_name ILIKE ? AND published = true OR first_name ILIKE ? AND published = true OR email_address ILIKE ? AND published = true OR phone_number ILIKE ? AND published = true', "%#{params[:search][:customer_name]}%", "%#{params[:search][:customer_name]}%", "%#{params[:search][:customer_name]}%", "%#{params[:search][:customer_name]}%").limit(5)

    respond_to do |format|
      format.js { ajax_refresh }
    end
  end

  def create_customer_association
    # set_sale

    unless @sale.blank? || params[:customer_id].blank?
      @sale.customer_id = params[:customer_id]
      @sale.save
    end

    respond_to do |format|
      format.js { ajax_refresh }
    end
  end

  # Add a searched Item
  def create_line_item
    # set_sale
    # populate_items

    existing_line_item = LineItem.where('item_id = ? AND sale_id = ?', params[:item_id], @sale.id).first

    if existing_line_item.blank?
      line_item = LineItem.new(item_id: params[:item_id], sale_id: params[:sale_id], quantity: params[:quantity])
      line_item.price = line_item.item.price
      line_item.save

      remove_item_from_stock(params[:item_id], 1)
      update_line_item_totals(line_item)
    else
      existing_line_item.quantity += 1
      existing_line_item.save

      remove_item_from_stock(params[:item_id], 1)
      update_line_item_totals(existing_line_item)
    end

    update_totals

    respond_to do |format|
      format.js { ajax_refresh }
    end
  end

  #Empty Cart
  def empty_cart

    line_items = @sale.line_items.includes(:item) || []
    line_items.each do |line_item|
      line_item.item.stock_amount = line_item.item.stock_amount + line_item.quantity
      line_item.item.save
      line_item.destroy
    end
    # line_item = LineItem.where(sale_id: params[:sale_id], item_id: params[:item_id]).first
    update_totals
    respond_to do |format|
      format.js { ajax_refresh }
    end

  end
  # Remove Item
  def remove_item
    # set_sale
    # populate_items

    line_item = LineItem.where(sale_id: params[:sale_id], item_id: params[:item_id]).first
    line_item.quantity -= 1
    if line_item.quantity <= 0
      line_item.destroy
    else
      line_item.save
      update_line_item_totals(line_item)
    end

    return_item_to_stock(params[:item_id], 1)

    update_totals

    respond_to do |format|
      format.js { ajax_refresh }
    end
  end
  # Remove Item from line item
  def remove_lineitem
    line_item = @sale.line_items.find_by_id(params[:line_item])
    if line_item.present?
      line_item.item.stock_amount = line_item.item.stock_amount + line_item.quantity
      line_item.item.save
      line_item.destroy
    end
    update_totals
    respond_to do |format|
      format.js { ajax_refresh }
    end
  end

  # Add one Item
  def add_item
    # set_sale
    # populate_items

    line_item = LineItem.where(sale_id: params[:sale_id], item_id: params[:item_id]).first
    line_item.quantity += 1
    line_item.save

    remove_item_from_stock(params[:item_id], 1)
    update_line_item_totals(line_item)

    update_totals

    respond_to do |format|
      format.js { ajax_refresh }
    end
  end

  def create_custom_item
    # set_sale
    # populate_items

    custom_item = current_company.items.new
    custom_item.sku = "CI#{(rand(5..30) + rand(5..30)) * 11}_#{(rand(5..30) + rand(5..30)) * 11}"
    custom_item.name = params[:custom_item][:name]
    custom_item.description = params[:custom_item][:description]
    custom_item.price = params[:custom_item][:price]
    custom_item.stock_amount = params[:custom_item][:stock_amount]
    custom_item.item_category_id = params[:custom_item][:item_category_id]

    custom_item.save

    custom_line_item = @sale.line_items.new(item_id: custom_item.id,
                                    quantity: custom_item.stock_amount,
                                    price: custom_item.price)
    custom_line_item.total_price = custom_item.price * custom_item.stock_amount
    custom_line_item.save

    update_totals

    respond_to do |format|
      format.js { ajax_refresh }
    end
  end

  def create_custom_customer
    # set_sale
    # populate_items

    custom_customer = current_company.customers.new
    custom_customer.first_name = params[:custom_customer][:first_name]
    custom_customer.last_name = params[:custom_customer][:last_name]
    custom_customer.email_address = params[:custom_customer][:email_address]
    custom_customer.phone_number = params[:custom_customer][:phone_number]
    custom_customer.address = params[:custom_customer][:address]
    custom_customer.city = params[:custom_customer][:city]
    custom_customer.state = params[:custom_customer][:state]
    custom_customer.zip = params[:custom_customer][:zip]

    custom_customer.save

    @sale.add_customer(custom_customer.id)

    update_totals

    respond_to do |format|
      format.js { ajax_refresh }
    end
  end

  # update Total For Line Items
  def update_line_item_totals(line_item)
    line_item.total_price = line_item.price * line_item.quantity
    line_item.save
  end

  def override_price
    # @sale = current_company.sales.find(params[:override_price][:sale_id])
    item = current_company.items.where(sku: params[:override_price][:line_item_sku]).first
    # line_item = LineItem.where(sale_id: params[:override_price][:sale_id], item_id: item.id).first
    line_item = LineItem.where(sale_id: params[:id], item_id: item.id).first
    line_item.price = params[:override_price][:price].gsub('$', '')
    line_item.save

    update_line_item_totals(line_item)
    update_totals

    respond_to do |format|
      format.js { ajax_refresh }
    end
  end

  def sale_discount
      @sale.discount = params[:discount]
      @sale.save
      update_totals
      respond_to do |format|
        format.js { ajax_refresh }
      end
  end


  def destroy_line_item
    # set_sale
    update_totals

    respond_to do |format|
      format.js { ajax_refresh }
    end
  end

  def update_totals
    tax_amount = get_tax_rate
    # set_sale

    @sale.amount = 0.00
    @sale.amount = @sale.line_items.sum(:total_price)

    # for line_item in @sale.line_items
    #   @sale.amount += line_item.total_price
    # end

    @sale.tax = @sale.amount * tax_amount
    total_amount = @sale.amount + (@sale.amount * tax_amount)

    @sale.total_amount = @sale.discount.blank? ? total_amount : (total_amount - (total_amount * @sale.discount))

    # if @sale.discount.blank?
    #   @sale.total_amount = total_amount
    # else
    #   discount_amount = total_amount * @sale.discount
    #   @sale.total_amount = total_amount - discount_amount
    # end

    @sale.save
  end

  def add_comment
    # set_sale
    @sale.comments = params[:sale_comments][:comments]
    @sale.save

    respond_to do |format|
      format.js { ajax_refresh }
    end
  end

  private

  def ajax_refresh
    render 'sales/ajax_reload'
  end

  # Use callbacks to share common setup or constraints between actions.
  def set_sale
    @sale = current_company.sales.find_by_id(params[:id] || params[:sale_id] || params[:search][:id]) || []
  end

  # Never trust parameters from the scary internet, only allow the white list through.
  def sale_params
    params.require(:sale).permit(:amount,
                                 :tax,
                                 :discount,
                                 :total_amount,
                                 :user_id,
                                 :company_id,
                                 :tax_paid,
                                 :amount_paid,
                                 :paid,
                                 :payment_type_id,
                                 :customer_id,
                                 :comments,
                                 :line_items_attributes,
                                 :items_attributes)
  end

  def populate_items
    @available_items = current_company.items.all.where(published: true).limit(5) || []
  end

  def populate_customers
    @available_customers = current_company.customers.all.where(published: true).limit(5) || []
  end

  def remove_item_from_stock(item_id, quantity)
    item = current_company.items.find(item_id)
    item.stock_amount = item.stock_amount - quantity
    item.amount_sold += quantity
    item.save
  end

  def return_item_to_stock(item_id, quantity)
    item = current_company.items.find(item_id)
    item.stock_amount = item.stock_amount + quantity
    item.save
  end

  def get_tax_rate
    current_company.tax_rate.blank? ? 0.00 : current_company.tax_rate.to_f * 0.01
  end
end
