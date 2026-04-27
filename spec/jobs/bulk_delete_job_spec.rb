require "rails_helper"

RSpec.describe BulkDeleteJob, type: :job do
  describe "#perform" do
    context "deleting channels" do
      let!(:channel) { create(:channel) }
      let!(:operation) do
        op = create(:bulk_operation, kind: :bulk_delete, status: :pending)
        op.bulk_operation_items.create!(target: channel, target_type: "Channel", target_id: channel.id, status: :pending)
        op
      end

      it "deletes the channel and marks operation completed" do
        expect { described_class.new.perform(operation.id) }.to change(Channel, :count).by(-1)
        operation.reload
        expect(operation.status).to eq("completed")
        expect(operation.completed_at).to be_present
        expect(operation.bulk_operation_items.first.status).to eq("succeeded")
      end

      it "deletes channel and associated videos" do
        create(:video, channel: channel)
        expect { described_class.new.perform(operation.id) }.to change(Video, :count).by(-1)
      end
    end

    context "deleting videos" do
      let!(:video) { create(:video) }
      let!(:operation) do
        op = create(:bulk_operation, kind: :bulk_delete, status: :pending)
        op.bulk_operation_items.create!(target: video, target_type: "Video", target_id: video.id, status: :pending)
        op
      end

      it "deletes the video and marks operation completed" do
        expect { described_class.new.perform(operation.id) }.to change(Video, :count).by(-1)
        operation.reload
        expect(operation.status).to eq("completed")
      end
    end

    context "deleting multiple items" do
      let!(:channel1) { create(:channel) }
      let!(:channel2) { create(:channel) }
      let!(:operation) do
        op = create(:bulk_operation, kind: :bulk_delete, status: :pending)
        op.bulk_operation_items.create!(target: channel1, target_type: "Channel", target_id: channel1.id, status: :pending)
        op.bulk_operation_items.create!(target: channel2, target_type: "Channel", target_id: channel2.id, status: :pending)
        op
      end

      it "deletes all items in a transaction" do
        expect { described_class.new.perform(operation.id) }.to change(Channel, :count).by(-2)
        operation.reload
        expect(operation.status).to eq("completed")
        expect(operation.bulk_operation_items.pluck(:status).uniq).to eq([ "succeeded" ])
      end
    end

    context "single item delete" do
      let!(:video) { create(:video) }
      let!(:operation) do
        op = create(:bulk_operation, kind: :bulk_delete, status: :pending)
        op.bulk_operation_items.create!(target: video, target_type: "Video", target_id: video.id, status: :pending)
        op
      end

      it "works the same as bulk — creates operation with 1 item" do
        expect(operation.bulk_operation_items.count).to eq(1)
        expect { described_class.new.perform(operation.id) }.to change(Video, :count).by(-1)
        operation.reload
        expect(operation.status).to eq("completed")
      end
    end
  end
end
