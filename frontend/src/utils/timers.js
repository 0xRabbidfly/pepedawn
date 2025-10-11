/* ===================================================================
   TIMERS
   Countdown timers and periodic update utilities
   =================================================================== */

/**
 * Create a countdown timer that updates an element
 * @param {HTMLElement} element - DOM element to update
 * @param {number} endTime - End time in milliseconds
 * @returns {number} Interval ID for cleanup
 */
export function createCountdownTimer(element, endTime) {
  function update() {
    const now = Date.now();
    const remaining = endTime - now;
    
    if (remaining <= 0) {
      element.textContent = 'Round Ended';
      return;
    }
    
    const days = Math.floor(remaining / (24 * 60 * 60 * 1000));
    const hours = Math.floor((remaining % (24 * 60 * 60 * 1000)) / (60 * 60 * 1000));
    const minutes = Math.floor((remaining % (60 * 60 * 1000)) / (60 * 1000));
    const seconds = Math.floor((remaining % (60 * 1000)) / 1000);
    
    element.textContent = `${days}d ${hours}h ${minutes}m ${seconds}s`;
  }
  
  update(); // Initial update
  return setInterval(update, 1000); // Update every second
}

/**
 * Clear a countdown timer
 * @param {number} timerId - Interval ID to clear
 */
export function clearCountdownTimer(timerId) {
  if (timerId) {
    clearInterval(timerId);
  }
}

/**
 * Debounce a function call
 * @param {Function} func - Function to debounce
 * @param {number} wait - Wait time in milliseconds
 * @returns {Function} Debounced function
 */
export function debounce(func, wait = 300) {
  let timeout;
  return function executedFunction(...args) {
    const later = () => {
      clearTimeout(timeout);
      func(...args);
    };
    clearTimeout(timeout);
    timeout = setTimeout(later, wait);
  };
}

/**
 * Throttle a function call
 * @param {Function} func - Function to throttle
 * @param {number} limit - Limit time in milliseconds
 * @returns {Function} Throttled function
 */
export function throttle(func, limit = 1000) {
  let inThrottle;
  return function(...args) {
    if (!inThrottle) {
      func.apply(this, args);
      inThrottle = true;
      setTimeout(() => inThrottle = false, limit);
    }
  };
}

/**
 * Sleep/delay execution
 * @param {number} ms - Milliseconds to sleep
 * @returns {Promise} Promise that resolves after delay
 */
export function sleep(ms) {
  return new Promise(resolve => setTimeout(resolve, ms));
}

