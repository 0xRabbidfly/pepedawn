---
description: Fix ABI format in frontend contract configuration by converting escaped JSON strings to proper JSON objects
---

You are tasked with fixing the ABI format in the frontend contract configuration file. This prompt will automatically detect and fix common ABI format issues.

## Task Overview

Fix any ABI format issues in `frontend/src/contract-config.js` where:
1. **Escaped JSON strings** need to be converted to **proper JSON objects**
2. **String-wrapped ABIs** need to be parsed into actual JavaScript objects
3. **Malformed JSON** needs to be corrected

## Steps to Execute

### 1. Analyze Current ABI Format
- Read `frontend/src/contract-config.js`
- Identify the current ABI format:
  - ✅ **Correct**: `abi: [{ "type": "function", ... }]` (proper JSON objects)
  - ❌ **Incorrect**: `abi: "[{\"type\":\"function\",...}]"` (escaped JSON string)
  - ❌ **Incorrect**: `abi: JSON.parse("...")` (string that needs parsing)

### 2. Check for Common Issues
Look for these patterns that indicate format problems:
- Escaped quotes: `\"`
- String-wrapped arrays: `"[{...}]"`
- JSON.parse() calls: `JSON.parse("...")`
- Single quotes around JSON: `'[{...}]'`

### 3. Fix the Format
If issues are found:
- Convert escaped JSON strings to proper JavaScript objects
- Remove unnecessary JSON.parse() calls
- Ensure proper JavaScript object syntax
- Maintain proper indentation and formatting

### 4. Verify the Fix
After fixing:
- Ensure the ABI is a proper JavaScript array of objects
- Verify all function signatures are preserved
- Check that the syntax is valid JavaScript
- Confirm no data is lost in the conversion

## Expected Output Format

The ABI should look like this:
```javascript
export const CONTRACT_CONFIG = {
  address: "0x...",
  network: 'sepolia',
  chainId: 11155111,
  abi: [
    {
      "type": "constructor",
      "inputs": [
        {
          "name": "_vrfCoordinator",
          "type": "address",
          "internalType": "address"
        }
        // ... more entries
      ]
    },
    {
      "type": "function",
      "name": "placeBet",
      "inputs": [
        {
          "name": "tickets",
          "type": "uint256",
          "internalType": "uint256"
        }
      ],
      "outputs": [],
      "stateMutability": "payable"
    }
    // ... more functions
  ]
};
```

## Validation

After making changes:
1. Verify the file has valid JavaScript syntax
2. Ensure the ABI array contains objects (not strings)
3. Check that all function signatures are intact
4. Confirm the export statement works correctly

## Notes

- **Preserve all ABI data** - don't lose any function definitions
- **Maintain formatting** - keep the code readable
- **Use proper JavaScript syntax** - not JSON syntax in a .js file
- **Handle large ABIs efficiently** - the file may be quite large

If no issues are found, report that the ABI format is already correct.
