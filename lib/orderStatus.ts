// Client-safe constants (no node imports) for client components.

export const ORDER_STATUSES: string[] = [
  "placed",
  "confirmed",
  "roasting",
  "shipped",
  "delivered",
  "cancelled"
];

export const ORDER_STATUS_LABELS: Record<string, string> = {
  placed: "Order placed",
  confirmed: "Confirmed",
  roasting: "In the roastery",
  shipped: "Shipped",
  delivered: "Delivered",
  cancelled: "Cancelled"
};

// Email-style messages the customer sees as their order timeline.
export const STATUS_MESSAGES: Record<string, string> = {
  placed:
    "We received your order. You will get a confirmation within one business day.",
  confirmed:
    "Your order is confirmed and has been queued at our Addis Ababa roastery.",
  roasting:
    "Your coffee is being roasted to order and packed fresh. Nothing sits on a shelf here.",
  shipped:
    "Your order has left our facility and is on its way. Track it with the courier code we send by phone.",
  delivered:
    "Your order has been delivered. Thank you for buying from Ethiopian farms - enjoy the cup.",
  cancelled:
    "This order was cancelled. Any payment made is refunded to the original payment method within 5 business days."
};

export const STATUS_CHIP_CLASS: Record<string, string> = {
  placed: "warn",
  confirmed: "ok",
  roasting: "warn",
  shipped: "ok",
  delivered: "ok",
  cancelled: "bad"
};

export const BUYER_TYPE_LABELS: Record<string, string> = {
  retail: "Retail",
  wholesale: "Wholesale"
};
