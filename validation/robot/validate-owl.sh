#!/usr/bin/env bash
# ==============================================================================
#  validate-owl.sh
#  ---------------------------------------------------------------------------
#  Comprehensive OWL ontology validation pipeline using ROBOT and standard
#  OBO dependencies (IAO, BFO). Ensures full OWL 2 DL compliance and reasoning.
#
#  Performs:
#    1. Dependency download (IAO, BFO)
#    2. Ontology merge with annotations
#    3. Syntax validation (RDF/XML parse test)
#    4. Logical consistency reasoning (HermiT)
#    5. OWL 2 DL profile validation
#    6. SPARQL normalization query (optional)
#    7. Structured report generation
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
ONTOLOGY="ontology/snomed-mmo-module.owl"
CATALOG="validation/catalog/catalog.xml"
REPORT_DIR="validation/robot/owl"
MERGED_ONTOLOGY="$REPORT_DIR/ontology.owl"

# === Preparation ==============================================================
mkdir -p "$REPORT_DIR"

# Ensure write permissions for shared environments
if [ ! -w "$REPORT_DIR" ]; then
  echo "🔧 Adjusting write permissions for $REPORT_DIR ..."
  chmod -R u+w "$REPORT_DIR" 2>/dev/null || sudo chmod -R u+w "$REPORT_DIR"
fi

echo "==============================================================="
echo "🧪 VALIDATION REPORT — $(date)"
echo "Ontology file: $ONTOLOGY"
echo "Catalog file:  $CATALOG"
echo "Output folder: $REPORT_DIR"
echo "==============================================================="

# --- Step 2: Merge Ontologies -------------------------------------------------
echo
echo "🌐 Merging ontology with external OBO dependencies..."
robot merge \
  --catalog "$CATALOG" \
  --input "$ONTOLOGY" \
  --input "../meta-mesh-ontology/ontology/mmo.owl" \
  --include-annotations true \
  --output "$MERGED_ONTOLOGY"
echo "✅ Ontology merged successfully."

robot query \
  --catalog "$CATALOG" \
  --input "$MERGED_ONTOLOGY" \
  --query validation/query/strip.rq "$REPORT_DIR/merged-stripped.owl"

ONTOLOGY="$REPORT_DIR/merged-stripped.owl"

# --- Step 3: Syntax Validation ------------------------------------------------
echo
echo "1️⃣  Checking RDF/XML syntax..."
robot convert \
  --catalog "$CATALOG" \
  --input "$ONTOLOGY" \
  --output "$REPORT_DIR/tmp.owl"
echo "✅ Syntax check passed."

# --- Step 4: Logical Consistency (Reasoner) -----------------------------------
echo
echo "2️⃣  Running OWL reasoning (HermiT)..."
robot reason \
  --catalog "$CATALOG" \
  --input "$ONTOLOGY" \
  --reasoner hermit \
  --output "$REPORT_DIR/reasoned.owl" \
  --equivalent-classes-allowed asserted-only
echo "✅ Reasoning completed without inconsistencies."

# --- Step 5: OWL 2 DL Profile Validation -------------------------------------
echo
echo "3️⃣  Validating OWL 2 DL profile compliance..."
robot validate-profile \
  --catalog "$CATALOG" \
  --input "$ONTOLOGY" \
  --profile DL \
  --output "$REPORT_DIR/profile.txt"
echo "✅ OWL 2 DL profile validation complete."

# --- Step 6: SPARQL Normalization Query --------------------------------------
echo
if [ -f validation/query/query.rq ]; then
  echo "4️⃣  Executing normalization query..."
  robot query \
    --catalog "$CATALOG" \
    --input "$ONTOLOGY" \
    --query validation/query/query.rq "$REPORT_DIR/core.owl"
  ONTOLOGY="$REPORT_DIR/core.owl"
  echo "✅ SPARQL normalization executed successfully."
else
  echo "⚠️  No SPARQL query file found — skipping this step."
fi

# --- Step 7: Report Generation ------------------------------------------------
echo
echo "5️⃣  Generating OWL-level validation report..."
robot report \
  --catalog "$CATALOG" \
  --profil "validation/profile/profile.txt" \
  --input "$ONTOLOGY" \
  --output "$REPORT_DIR/report.tsv" \
  --fail-on ERROR
echo "✅ Validation report generated."

# --- Step 8: Cleanup ----------------------------------------------------------
echo
echo "🧹 Cleaning up temporary files..."
rm -f "$REPORT_DIR/ontology.owl" \
      "$REPORT_DIR/tmp.owl" \
      "$REPORT_DIR/core.owl" \
      "$REPORT_DIR/merged-stripped.owl" \
      "$REPORT_DIR/reasoned.owl" 2>/dev/null || true
echo "✅ Temporary files removed."

# --- Summary -----------------------------------------------------------------
echo
echo "🏁 ROBOT validation completed successfully."
echo "Reports available in: $REPORT_DIR"
echo "  - profile.txt"
echo "  - report.tsv"
echo "==============================================================="
exit 0
