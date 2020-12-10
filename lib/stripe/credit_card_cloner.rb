# frozen_string_literal: true

# Here we clone (or find a clone of)
#   - a card (card_*) or payment_method (pm_*) stored (in a customer) in a platform account into
#   - a payment method (pm_*) (in a new customer) in a connected account
#
# This is required when using the Stripe Payment Intents API:
#   - the customer and payment methods are stored in the platform account
#       so that they can be re-used across multiple sellers
#   - when a card needs to be charged, we need to clone (or find the clone)
#       in the seller's stripe account
#
# To avoid creating a new clone of the card/customer each time the card is charged or
# authorized (e.g. for SCA), we attach metadata { clone: true } to the card the first time we
# clone it and look for a card with the same fingerprint (hash of the card number) and
# that metadata key to avoid cloning it multiple times.

module Stripe
  class CreditCardCloner
    def find_or_clone(card, connected_account_id)
      cloned_card = CreditCardCloneFinder.new(card, connected_account_id).find_cloned_card
      cloned_card || clone(card, connected_account_id)
    end

    private

    def clone(credit_card, connected_account_id)
      new_payment_method = clone_payment_method(credit_card, connected_account_id)

      # If no customer is given, it will clone the payment method only
      return [nil, new_payment_method.id] if credit_card.gateway_customer_profile_id.blank?

      new_customer = Stripe::Customer.create({ email: credit_card.user.email },
                                             stripe_account: connected_account_id)
      attach_payment_method_to_customer(new_payment_method.id,
                                        new_customer.id,
                                        connected_account_id)

      add_metadata_to_payment_method(new_payment_method.id, connected_account_id)

      [new_customer.id, new_payment_method.id]
    end

    def notify_limit(request_number, retrieving)
      Bugsnag.notify("Reached limit of #{request_number} requests retrieving #{retrieving}.")
    end

    def clone_payment_method(credit_card, connected_account_id)
      platform_acct_payment_method_id = credit_card.gateway_payment_profile_id
      customer_id = credit_card.gateway_customer_profile_id

      Stripe::PaymentMethod.create({ customer: customer_id,
                                     payment_method: platform_acct_payment_method_id },
                                   stripe_account: connected_account_id)
    end

    def attach_payment_method_to_customer(payment_method_id, customer_id, connected_account_id)
      Stripe::PaymentMethod.attach(payment_method_id,
                                   { customer: customer_id },
                                   stripe_account: connected_account_id)
    end

    def add_metadata_to_payment_method(payment_method_id, connected_account_id)
      Stripe::PaymentMethod.update(payment_method_id,
                                   { metadata: { "ofn-clone": true } },
                                   stripe_account: connected_account_id)
    end
  end
end
