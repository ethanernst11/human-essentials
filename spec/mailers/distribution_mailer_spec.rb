RSpec.describe DistributionMailer, type: :mailer do
  before do
    @organization.default_email_text = "Default email text example\n\n%{delivery_method} %{distribution_date}\n\n%{partner_name}\n\n%{comment}"
    @partner = create(:partner, name: 'PARTNER')
    @distribution = create(:distribution, organization: @user.organization, comment: "Distribution comment", partner: @partner)
    @organization.update!(email: "me@org.com")
    @request = create(:request, distribution: @distribution)
    allow(DistributionPdf).to receive(:new).and_return(double('DistributionPdf', compute_and_render: ''))
  end

  describe "#partner_mailer" do
    let(:distribution_changes) { {} }
    let(:mail) { DistributionMailer.partner_mailer(@organization, @distribution, 'test subject', distribution_changes) }

    it "renders the body with organization's email text" do
      expect(mail.body.encoded).to match("Default email text example")
      expect(mail.html_part.body).to match(%(From: <a href="mailto:me@org.com">me@org.com</a>))
      expect(mail.to).to eq([@distribution.request.user_email])
      expect(mail.cc).to eq([@distribution.partner.email])
      expect(mail.from).to eq(["no-reply@humanessentials.app"])
      expect(mail.subject).to eq("test subject from DEFAULT")
    end

    it "renders the body with distributions text" do
      expect(mail.body.encoded).to match("Distribution comment")
      expect(mail.subject).to eq("test subject from DEFAULT")
    end

    context "with deliver_method: :pick_up" do
      it "renders the body with 'picked up' specified" do
        distribution = create(:distribution, organization: @user.organization, comment: "Distribution comment", partner: @partner, delivery_method: :pick_up)
        mail = DistributionMailer.partner_mailer(@organization, distribution, 'test subject', distribution_changes)
        expect(mail.body.encoded).to match("picked up")
      end
    end

    context "with deliver_method: :delivery" do
      it "renders the body with 'delivered' specified" do
        distribution = create(:distribution, organization: @user.organization, comment: "Distribution comment", partner: @partner, delivery_method: :delivery)
        mail = DistributionMailer.partner_mailer(@organization, distribution, 'test subject', distribution_changes)
        expect(mail.body.encoded).to match("delivered")
      end
    end

    context "with distribution changes" do
      let(:distribution_changes) do
        {
          removed: [
            { name: "Adult Diapers" }
          ],
          updates: [
            {
              name: "Kid Diapers",
              new_quantity: 4,
              old_quantity: 100
            }
          ]
        }
      end

      it "renders the body with changes that happened in the distribution" do
        distribution = create(:distribution, organization: @user.organization, comment: "Distribution comment", partner: @partner, delivery_method: :delivery)
        mail = DistributionMailer.partner_mailer(@organization, distribution, 'test subject', distribution_changes)
        expect(mail.body.encoded).to match(distribution_changes[:removed][0][:name])
        expect(mail.body.encoded).to match(distribution_changes[:updates][0][:name])
      end
    end
  end

  describe "#reminder_email" do
    let(:mail) { DistributionMailer.reminder_email(@distribution.id) }

    context 'HTML format' do
      it "renders the body with organization's email text" do
        html = html_body(mail)
        expect(html).to match("This is a friendly reminder")
        expect(html).to match(%(For more information: <a href="mailto:me@org.com">me@org.com</a>))
        expect(mail.to).to eq([@distribution.request.user_email])
        expect(mail.cc).to eq([@distribution.partner.email])
        expect(mail.from).to eq(["no-reply@humanessentials.app"])
        expect(mail.subject).to eq("PARTNER Distribution Reminder")
      end
    end

    context 'Text format' do
      it "renders the body with organization's email text" do
        text = text_body(mail)
        expect(text).to match("This is a friendly reminder")
        expect(text).to match(%(For more information: me@org.com))
        expect(mail.from).to eq(["no-reply@humanessentials.app"])
        expect(mail.subject).to eq("PARTNER Distribution Reminder")
      end
    end

    context "with deliver_method: :pick_up" do
      it "renders the body with 'pick up' specified" do
        distribution = create(:distribution, organization: @user.organization, comment: "Distribution comment", partner: @partner, delivery_method: :pick_up)
        mail = DistributionMailer.reminder_email(distribution.id)
        expect(mail.body.encoded).to match("pick up")
      end
    end

    context "with deliver_method: :delivery" do
      it "renders the body with 'delivery' specified" do
        distribution = create(:distribution, organization: @user.organization, comment: "Distribution comment", partner: @partner, delivery_method: :delivery)
        mail = DistributionMailer.reminder_email(distribution.id)
        expect(mail.body.encoded).to match("delivery")
      end
    end
  end
  describe "#requestee_email assignment" do
    let(:requestee_email) { "requestee@example.com" }
    let(:partner) { create(:partner) }
    let(:organization) { create(:organization) }
    let!(:user) { create(:partner_user, email: requestee_email, partner: partner) }
    let!(:request) { create(:request, partner: partner, organization: organization, partner_user_id: user.id) }

    context "when distribution has a request with a associated user" do
      let!(:distribution) { create(:distribution, partner: partner, organization: organization, request: request) }
      it "assigns the requestee's email from the request's user_email" do
        requestee_email_result = distribution.request ? distribution.request.user_email : partner.email
        expect(requestee_email_result).to eq(requestee_email)
      end
    end

    context "when distribution has a request without an associated user" do
      let!(:request) { create(:request, partner: partner, organization: organization, partner_user_id: nil) }
      let!(:distribution) { create(:distribution, partner: partner, organization: organization, request: request) }
      it "assigns the requestee's email from the request's user_email" do
        requestee_email_result = distribution.request ? distribution.request.user_email : partner.email
        expect(requestee_email_result).to eq(partner.email)
      end
    end

    context "when distribution doesn't have a request" do
      let!(:distribution_without_request) { create(:distribution, partner: partner, organization: organization, request: nil) }
      it "assigns the requestee's email from the partner's email" do
        requestee_email_result = distribution_without_request.request ? distribution_without_request.request.user_email : partner.email
        expect(requestee_email_result).to eq(partner.email)
      end
    end
  end
end
