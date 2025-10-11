/* ===================================================================
   VALIDATION
   Input validation and sanitization utilities
   =================================================================== */

/**
 * Validate Ethereum address
 * @param {string} address - Address to validate
 * @returns {boolean} True if valid
 */
export function isValidAddress(address) {
  if (!address) return false;
  return /^0x[a-fA-F0-9]{40}$/.test(address);
}

/**
 * Validate ETH amount
 * @param {number|string} amount - Amount to validate
 * @returns {boolean} True if valid
 */
export function isValidAmount(amount) {
  if (!amount || isNaN(amount)) return false;
  return Number(amount) > 0;
}

/**
 * Validate ticket count
 * @param {number} tickets - Number of tickets
 * @returns {boolean} True if valid
 */
export function isValidTicketCount(tickets) {
  if (!tickets || !Number.isInteger(Number(tickets))) return false;
  return Number(tickets) > 0;
}

/**
 * Validate transaction parameters
 * @param {Object} params - Transaction parameters
 * @param {number} params.amount - ETH amount
 * @param {number} params.tickets - Ticket count
 * @param {string} params.userAddress - User address
 * @returns {Object} Validation result
 */
export function validateTransactionParams(params) {
  const { amount, tickets, userAddress } = params;
  
  if (!isValidAmount(amount)) {
    throw new Error('Invalid bet amount');
  }
  
  if (!isValidTicketCount(tickets)) {
    throw new Error('Invalid ticket count');
  }
  
  if (!isValidAddress(userAddress)) {
    throw new Error('Invalid user address');
  }
  
  return true;
}

/**
 * Sanitize string input
 * @param {string} input - Input to sanitize
 * @param {string} type - Type of input ('proof', 'address', etc.)
 * @returns {string} Sanitized input
 */
export function sanitizeInput(input, type = 'text') {
  if (!input) return '';
  
  // Trim whitespace
  let sanitized = input.trim();
  
  // Type-specific sanitization
  switch (type) {
    case 'proof':
      // Allow alphanumeric and common proof characters
      sanitized = sanitized.replace(/[^a-zA-Z0-9\s\-_+=/:]/g, '');
      break;
    case 'address':
      // Ethereum address format
      sanitized = sanitized.toLowerCase();
      if (!isValidAddress(sanitized)) {
        throw new Error('Invalid Ethereum address format');
      }
      break;
    default:
      // General sanitization - remove dangerous characters
      sanitized = sanitized.replace(/[<>]/g, '');
  }
  
  return sanitized;
}

/**
 * Check if value is within range
 * @param {number} value - Value to check
 * @param {number} min - Minimum value
 * @param {number} max - Maximum value
 * @returns {boolean} True if in range
 */
export function isInRange(value, min, max) {
  return value >= min && value <= max;
}

