#!/bin/bash
set -e

# Update .env with new variables from .env.example
# Compatible with bash 3 (macOS default)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

ENV_FILE="${PROJECT_ROOT}/.env"
EXAMPLE_FILE="${PROJECT_ROOT}/.env.example"
BACKUP_FILE="${PROJECT_ROOT}/.env.backup.$(date +%Y%m%d_%H%M%S)"

# Colors
BLUE='\033[0;34m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}=========================================="
echo "Environment Configuration Update"
echo -e "==========================================${NC}"
echo ""

if [ ! -f "${EXAMPLE_FILE}" ]; then
    echo -e "${RED}ERROR: .env.example not found!${NC}"
    exit 1
fi

if [ ! -f "${ENV_FILE}" ]; then
    echo -e "${YELLOW}No existing .env file found.${NC}"
    echo -e "${GREEN}Creating new .env from .env.example...${NC}"
    cp "${EXAMPLE_FILE}" "${ENV_FILE}"
    echo -e "${GREEN}✓ .env created successfully${NC}"
    exit 0
fi

echo -e "${GREEN}Found existing .env file${NC}"
echo -e "${BLUE}Analyzing differences...${NC}"
echo ""

cp "${ENV_FILE}" "${BACKUP_FILE}"
echo -e "${GREEN}✓ Backup created: ${BACKUP_FILE}${NC}"
echo ""

# Get variables
EXAMPLE_VARS=$(grep "^export [A-Z_]*=" "${EXAMPLE_FILE}" | sed 's/^export //; s/=.*//' | sort -u)
EXISTING_VARS=$(grep "^export [A-Z_]*=" "${ENV_FILE}" | sed 's/^export //; s/=.*//' | sort -u)

# Find new variables
NEW_VARS=()
for var in ${EXAMPLE_VARS}; do
    if ! echo "${EXISTING_VARS}" | grep -q "^${var}$"; then
        NEW_VARS+=("${var}")
    fi
done

if [ ${#NEW_VARS[@]} -eq 0 ]; then
    echo -e "${GREEN}✓ Your .env is up to date!${NC}"
    rm "${BACKUP_FILE}"
    exit 0
fi

echo -e "${YELLOW}Found ${#NEW_VARS[@]} new variable(s):${NC}"
for var in "${NEW_VARS[@]}"; do
    echo "  - ${var}"
done
echo ""

read -p "Add these variables? (yes/no): " -r
if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
    echo "Aborted."
    rm "${BACKUP_FILE}"
    exit 0
fi

echo ""
echo -e "${BLUE}Adding new variables...${NC}"

# Find and append sections containing new variables (once per section)
SECTIONS_ADDED=""

for var in "${NEW_VARS[@]}"; do
    VAR_LINE=$(grep -n "^export ${var}=" "${EXAMPLE_FILE}" | cut -d: -f1)
    if [ -z "${VAR_LINE}" ]; then
        continue
    fi
    
    # Find section header
    SECTION_LINE=$(sed -n "1,${VAR_LINE}p" "${EXAMPLE_FILE}" | grep -n "^# ====" | tail -1 | cut -d: -f1)
    if [ -z "${SECTION_LINE}" ]; then
        continue
    fi
    
    SECTION_HEADER=$(sed -n "${SECTION_LINE}p" "${EXAMPLE_FILE}")
    
    # Check if we already added this section
    if echo "${SECTIONS_ADDED}" | grep -q -F "${SECTION_HEADER}"; then
        continue
    fi
    
    # Mark as added
    SECTIONS_ADDED="${SECTIONS_ADDED}${SECTION_HEADER}"$'\n'
    
    # Find section boundaries
    NEXT_SECTION_LINE=$(sed -n "$((SECTION_LINE+1)),\$p" "${EXAMPLE_FILE}" | grep -n "^# ====" | head -1 | cut -d: -f1)
    
    if [ -n "${NEXT_SECTION_LINE}" ]; then
        SECTION_END=$((SECTION_LINE + NEXT_SECTION_LINE - 1))
    else
        SECTION_END=$(wc -l < "${EXAMPLE_FILE}" | tr -d ' ')
    fi
    
    # Append section
    echo "" >> "${ENV_FILE}"
    sed -n "${SECTION_LINE},${SECTION_END}p" "${EXAMPLE_FILE}" >> "${ENV_FILE}"
done

for var in "${NEW_VARS[@]}"; do
    echo -e "${GREEN}  + Added: ${var}${NC}"
done

echo ""
echo -e "${GREEN}=========================================="
echo "✓ Update Complete!"
echo -e "==========================================${NC}"
echo ""
echo "Summary: ${#NEW_VARS[@]} new variable(s) added"
echo "Backup: ${BACKUP_FILE}"
echo ""
echo "Next steps:"
echo "  1. Review: diff ${BACKUP_FILE} ${ENV_FILE}"
echo "  2. Edit: make edit-env"
echo "  3. Verify: make info"
echo ""
echo -e "${BLUE}To revert: cp ${BACKUP_FILE} ${ENV_FILE}${NC}"
echo ""
