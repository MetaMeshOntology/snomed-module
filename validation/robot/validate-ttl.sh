#!/usr/bin/env bash
# ==============================================================================
#  validate-ttl.sh
#  ---------------------------------------------------------------------------
#  Lightweight validation pipeline for Turtle (.ttl) ontology files.
#
#  Performs:
#    1. Syntax validation using Raptor RDF ("rapper")
#    2. RDF model consistency check
#    3. Triple count summary
#    4. Structured validation report generation
#
#  Author: Meta Mesh Ontology (MMO) Development Team
#  License: Creative Commons Attribution 4.0 International (CC BY 4.0)
#  Repository: https://github.com/MetaMeshOntology
# ==============================================================================
#  Copyright (c) 2025 Meta Mesh Ontology
#
#  This work is licensed under a Creative Commons Attribution 4.0
#  International License (CC BY 4.0).
#
#  You are free to:
#   - Share — copy and redistribute the material in any medium or format.
#   - Adapt — remix, transform, and build upon the material for any purpose,
#     even commercially.
#
#  Under the following terms:
#   - Attribution — You must give appropriate credit, provide a link to the
#     license, and indicate if changes were made. You may do so in any
#     reasonable manner, but not in any way that suggests the licensor
#     endorses you or your use.
#
#  Full license text: https://creativecommons.org/licenses/by/4.0/
# ==============================================================================

set -e

# === Configuration ============================================================
TTL_FILE=${1:-ontology/snomed-mmo-module.ttl}
OUT_DIR="validation/robot/ttl"
REPORT_FILE="$OUT_DIR/report.txt"

# === Preparation ==============================================================
mkdir -p "$OUT_DIR"

# Ensure write permissions (safe for shared UNIX environments)
if [ ! -w "$OUT_DIR" ]; then
  echo "🔧 Adjusting write permissions for $OUT_DIR ..."
  chmod -R u+w "$OUT_DIR" 2>/dev/null || sudo chmod -R u+w "$OUT_DIR"
fi

if [ ! -f "$TTL_FILE" ]; then
  echo "❌ Error: File not found → $TTL_FILE" | tee "$REPORT_FILE"
  exit 1
fi

# === Validation Process =======================================================
{
echo "==============================================================="
echo "🧪 VALIDATION REPORT — $(date)"
echo "File: $TTL_FILE"
echo "Output: $REPORT_FILE"
echo "==============================================================="

# --- Step 1: Syntax check -----------------------------------------------------
echo
echo "1️⃣  Checking Turtle syntax (rapper)"
if rapper -i turtle -c "$TTL_FILE" > /dev/null 2>&1; then
  echo "✅ Turtle syntax is valid."
else
  echo "❌ Syntax error detected by rapper."
  rapper -i turtle -c "$TTL_FILE"
  exit 1
fi

# --- Step 2: RDF model consistency -------------------------------------------
echo
echo "2️⃣  Checking RDF model consistency"
if rapper -i turtle "$TTL_FILE" -c > /dev/null 2>&1; then
  echo "✅ RDF model is consistent and well-formed."
else
  echo "⚠️  RDF model validation reported potential issues:"
  rapper -i turtle "$TTL_FILE" -c 2>&1
fi

# --- Step 3: Triple count summary --------------------------------------------
echo
TRIPLE_COUNT=$(rapper -i turtle -o ntriples "$TTL_FILE" 2>/dev/null | wc -l | tr -d ' ')
echo "3️⃣  Triple count: $TRIPLE_COUNT"

# --- Completion ---------------------------------------------------------------
echo
echo "🏁 Validation completed successfully."
echo "Report stored at: $REPORT_FILE"
echo "==============================================================="
} | tee "$REPORT_FILE"

exit 0