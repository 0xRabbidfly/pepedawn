/* ===================================================================
   FORMATTERS
   Utility functions for formatting addresses, numbers, dates, etc.
   =================================================================== */

import { ethers } from 'ethers';

/**
 * Format Ethereum address for display
 * @param {string} address - Full Ethereum address
 * @returns {string} Formatted address (0x1234...5678)
 */
export function formatAddress(address) {
  if (!address) return '';
  return `${address.slice(0, 6)}...${address.slice(-4)}`;
}

/**
 * Format ETH amount for display
 * @param {bigint|string} weiAmount - Amount in wei
 * @param {number} decimals - Number of decimal places (default: 4)
 * @returns {string} Formatted ETH amount
 */
export function formatEther(weiAmount, decimals = 4) {
  if (!weiAmount) return '0';
  try {
    const ethAmount = ethers.formatEther(weiAmount);
    return parseFloat(ethAmount).toFixed(decimals);
  } catch (error) {
    console.error('Error formatting ether:', error);
    return '0';
  }
}

/**
 * Format number with thousands separators
 * @param {number|string} num - Number to format
 * @returns {string} Formatted number (1,234,567)
 */
export function formatNumber(num) {
  if (!num) return '0';
  return Number(num).toLocaleString();
}

/**
 * Format percentage
 * @param {number} value - Value to format as percentage
 * @param {number} decimals - Number of decimal places (default: 1)
 * @returns {string} Formatted percentage (12.5%)
 */
export function formatPercentage(value, decimals = 1) {
  if (!value || isNaN(value)) return '0%';
  return `${Number(value).toFixed(decimals)}%`;
}

/**
 * Format timestamp to readable date
 * @param {number} timestamp - Unix timestamp
 * @returns {string} Formatted date
 */
export function formatDate(timestamp) {
  if (!timestamp) return '';
  try {
    const date = new Date(timestamp * 1000);
    return date.toLocaleString();
  } catch (error) {
    console.error('Error formatting date:', error);
    return '';
  }
}

/**
 * Format time remaining as countdown
 * @param {number} endTime - End time in milliseconds
 * @returns {string} Formatted countdown (7d 12h 34m 56s)
 */
export function formatTimeRemaining(endTime) {
  const now = Date.now();
  const remaining = endTime - now;
  
  if (remaining <= 0) {
    return 'Round Ended';
  }
  
  const days = Math.floor(remaining / (24 * 60 * 60 * 1000));
  const hours = Math.floor((remaining % (24 * 60 * 60 * 1000)) / (60 * 60 * 1000));
  const minutes = Math.floor((remaining % (60 * 60 * 1000)) / (60 * 1000));
  const seconds = Math.floor((remaining % (60 * 1000)) / 1000);
  
  return `${days}d ${hours}h ${minutes}m ${seconds}s`;
}

/**
 * Truncate text with ellipsis
 * @param {string} text - Text to truncate
 * @param {number} maxLength - Maximum length (default: 50)
 * @returns {string} Truncated text
 */
export function truncateText(text, maxLength = 50) {
  if (!text || text.length <= maxLength) return text;
  return text.slice(0, maxLength) + '...';
}

/**
 * Format transaction hash for display
 * @param {string} txHash - Transaction hash
 * @returns {string} Formatted hash (0x1234...5678)
 */
export function formatTxHash(txHash) {
  return formatAddress(txHash); // Same format as address
}

