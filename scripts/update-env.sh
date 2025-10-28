#!/bin/bash
set -e

# Update .env with new variables from .env.example
# Preserves existing user values and only adds missing variables

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
NC='\033[0m' # No Color

echo -e "${BLUE}=========================================="
echo "Environment Configuration Update"
echo -e "==========================================${NC}"
echo ""

# Check if .env.example exists
if [ ! -f "${EXAMPLE_FILE}" ]; then
    echo -e "${RED}ERROR: .env.example not found!${NC}"
    exit 1
fi

# Check if .env exists
if [ ! -f "${ENV_FILE}" ]; then
    echo -e "${YELLOW}No existing .env file found.${NC}"
    echo -e "${GREEN}Creating new .env from .env.example...${NC}"
    cp "${EXAMPLE_FILE}" "${ENV_FILE}"
    echo -e "${GREEN}✓ .env created successfully${NC}"
    echo ""
    echo "Next step: Edit your configuration"
    echo "  make edit-env"
    exit 0
fi

echo -e "${GREEN}Found existing .env file${NC}"
echo -e "${BLUE}Analyzing differences...${NC}"
echo ""

# Create backup
cp "${ENV_FILE}" "${BACKUP_FILE}"
echo -e "${GREEN}✓ Backup created: ${BACKUP_FILE}${NC}"
echo ""

# Extract all variable names from .env.example (ignore comments and empty lines)
EXAMPLE_VARS=$(grep -E '^export [A-Z_]+=|^[A-Z_]+=' "${EXAMPLE_FILE}" | sed -E 's/^export //; s/=.*//' | sort -u)

# Extract all variable names from existing .env
EXISTING_VARS=$(grep -E '^export [A-Z_]+=|^[A-Z_]+=' "${ENV_FILE}" 2>/dev/null | sed -E 's/^export //; s/=.*//' | sort -u || echo "")

# Find new variables
NEW_VARS=()
for var in ${EXAMPLE_VARS}; do
    if ! echo "${EXISTING_VARS}" | grep -q "^${var}$"; then
        NEW_VARS+=("${var}")
    fi
done

# Find changed defaults (informational only, don't overwrite)
CHANGED_DEFAULTS=()
for var in ${EXISTING_VARS}; do
    if echo "${EXAMPLE_VARS}" | grep -q "^${var}$"; then
        # Variable exists in both - check if default value changed
        EXAMPLE_VALUE=$(grep -E "^export ${var}=|^${var}=" "${EXAMPLE_FILE}" | head -1 | sed -E 's/^export [^=]+=//; s/^[^=]+=//; s/"//g; s/'"'"'//g')
        CURRENT_VALUE=$(grep -E "^export ${var}=|^${var}=" "${ENV_FILE}" | head -1 | sed -E 's/^export [^=]+=//; s/^[^=]+=//; s/"//g; s/'"'"'//g')

        # Only flag as changed if the example has a non-empty value
        if [ -n "${EXAMPLE_VALUE}" ] && [ "${EXAMPLE_VALUE}" != "${CURRENT_VALUE}" ]; then
            CHANGED_DEFAULTS+=("${var}")
        fi
    fi
done

# Report findings
if [ ${#NEW_VARS[@]} -eq 0 ] && [ ${#CHANGED_DEFAULTS[@]} -eq 0 ]; then
    echo -e "${GREEN}✓ Your .env is up to date!${NC}"
    echo ""
    echo "No new variables to add."
    rm "${BACKUP_FILE}"  # Remove backup if nothing changed
    exit 0
fi

# Report new variables
if [ ${#NEW_VARS[@]} -gt 0 ]; then
    echo -e "${YELLOW}Found ${#NEW_VARS[@]} new variable(s) in .env.example:${NC}"
    for var in "${NEW_VARS[@]}"; do
        echo "  - ${var}"
    done
    echo ""
fi

# Report changed defaults (informational)
if [ ${#CHANGED_DEFAULTS[@]} -gt 0 ]; then
    echo -e "${BLUE}Note: ${#CHANGED_DEFAULTS[@]} variable(s) have new defaults in .env.example:${NC}"
    echo -e "${BLUE}(Your current values will be preserved)${NC}"
    for var in "${CHANGED_DEFAULTS[@]}"; do
        EXAMPLE_VALUE=$(grep -E "^export ${var}=|^${var}=" "${EXAMPLE_FILE}" | head -1 | sed -E 's/^export [^=]+=//; s/^[^=]+=//; s/"//g; s/'"'"'//g')
        CURRENT_VALUE=$(grep -E "^export ${var}=|^${var}=" "${ENV_FILE}" | head -1 | sed -E 's/^export [^=]+=//; s/^[^=]+=//; s/"//g; s/'"'"'//g')
        echo "  - ${var}:"
        echo "    Current: ${CURRENT_VALUE}"
        echo "    Example: ${EXAMPLE_VALUE}"
    done
    echo ""
fi

# Ask for confirmation
echo -e "${YELLOW}Do you want to add new variables to your .env?${NC}"
echo "Your existing values will NOT be changed."
read -p "Continue? (yes/no): " -r
if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
    echo "Aborted."
    rm "${BACKUP_FILE}"
    exit 0
fi

echo ""
echo -e "${BLUE}Updating .env file...${NC}"

# Create a temporary file for the new .env
TEMP_FILE="${ENV_FILE}.tmp"
cp "${ENV_FILE}" "${TEMP_FILE}"

# Process .env.example and add missing variables
IN_SECTION=""
SECTION_ADDED=false

while IFS= read -r line; do
    # Check if this is a section header
    if echo "${line}" | grep -q "^# ===="; then
        IN_SECTION="${line}"
        SECTION_ADDED=false
        continue
    fi

    # Check if this is a variable definition
    if echo "${line}" | grep -qE "^export [A-Z_]+=|^[A-Z_]+="; then
        VAR_NAME=$(echo "${line}" | sed -E 's/^export //; s/=.*//')

        # Check if this variable is new
        if printf '%s\n' "${NEW_VARS[@]}" | grep -q "^${VAR_NAME}$"; then
            # Add section header if not already added
            if [ -n "${IN_SECTION}" ] && [ "${SECTION_ADDED}" = false ]; then
                echo "" >> "${TEMP_FILE}"
                echo "${IN_SECTION}" >> "${TEMP_FILE}"
                SECTION_ADDED=true
            fi

            # Add any comments before the variable (look back in example file)
            LINE_NUM=$(grep -n "^export ${VAR_NAME}=\|^${VAR_NAME}=" "${EXAMPLE_FILE}" | cut -d: -f1 | head -1)
            if [ -n "${LINE_NUM}" ]; then
                # Get up to 10 lines before for comments
                START_LINE=$((LINE_NUM - 10))
                [ ${START_LINE} -lt 1 ] && START_LINE=1

                sed -n "${START_LINE},$((LINE_NUM - 1))p" "${EXAMPLE_FILE}" | \
                    sed -n '/^# [^=]/,$p' | \
                    grep -v "^# ====" >> "${TEMP_FILE}" || true
            fi

            # Add the variable
            echo "${line}" >> "${TEMP_FILE}"
            echo -e "${GREEN}  + Added: ${VAR_NAME}${NC}"
        fi
    fi
done < "${EXAMPLE_FILE}"

# Replace old .env with updated version
mv "${TEMP_FILE}" "${ENV_FILE}"

echo ""
echo -e "${GREEN}=========================================="
echo "✓ Update Complete!"
echo -e "==========================================${NC}"
echo ""
echo -e "${GREEN}Summary:${NC}"
echo "  - ${#NEW_VARS[@]} new variable(s) added"
echo "  - Existing values preserved"
echo "  - Backup saved: ${BACKUP_FILE}"
echo ""

if [ ${#CHANGED_DEFAULTS[@]} -gt 0 ]; then
    echo -e "${YELLOW}Recommended Actions:${NC}"
    echo "  1. Review new default values for existing variables"
    echo "  2. Consider updating if appropriate:"
    for var in "${CHANGED_DEFAULTS[@]}"; do
        echo "     - ${var}"
    done
    echo ""
fi

echo "Next steps:"
echo "  1. Review changes: diff ${BACKUP_FILE} ${ENV_FILE}"
echo "  2. Edit if needed: make edit-env"
echo "  3. Verify config: make info"
echo ""
echo -e "${BLUE}To revert changes: cp ${BACKUP_FILE} ${ENV_FILE}${NC}"
echo ""
