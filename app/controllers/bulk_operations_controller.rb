class BulkOperationsController < ApplicationController
  def show
    @operation = BulkOperation.find(params[:id])
    @items = @operation.bulk_operation_items.includes(:target).order(:id)
  end

  # GET /bulk_operations/:id/status.json
  def status
    operation = BulkOperation.find(params[:id])
    items = operation.bulk_operation_items.order(:id)

    render json: {
      status: operation.status,
      current: items.where(status: [ :succeeded, :failed ]).count,
      total: items.count,
      items: items.map { |i| { id: i.id, status: i.status } }
    }
  end
end
