# == Schema Information
#
# Table name: items
#
#  id               :integer          not null, primary key
#  sku              :string
#  name             :string
#  description      :text
#  price            :decimal(8, 2)
#  stock_amount     :integer
#  amount_sold      :integer          default(0)
#  cost_price       :decimal(8, 2)
#  published        :boolean          default(TRUE)
#  created_at       :datetime
#  updated_at       :datetime
#  item_category_id :integer
#  company_id       :integer
#  photo            :string
#  location_id      :integer
#  barcode          :string
#  shelf            :string
#  tax              :float            default(0.0)
#

class Item < ActiveRecord::Base
	# mount_uploader :photo, AttachmentUploader

	has_many :line_items
	belongs_to :item_category
	belongs_to :company
	belongs_to :location

	validates :sku, :cost_price , presence: true
	validates :name, presence: true
	validates :price, presence: true
	validates :stock_amount, presence: true

	validates_uniqueness_of :sku, scope: [:company_id , :sku]
	validates_uniqueness_of :name, scope: [:company_id , :name]
	validates_inclusion_of :tax, in: 0..100

	# validate :image_size_validation

	scope :published , -> {where(published: true)}
	scope :search_by_name , lambda { |name| where('name LIKE ? OR description LIKE ? OR sku LIKE ? ', "%#{name}%", "%#{name}%", "%#{name}%")}
	scope :search_by_category , lambda { |name| where(item_category_id: name)}
	scope	:recent , -> {order('items.created_at desc')}
	# private
	# def image_size_validation
	# 	errors[:photo] << "should be less than 500KB" if photo.size > 0.5.megabytes
	# end

end
