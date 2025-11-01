#!/usr/bin/env bash
# ==============================================================================
#  validate-rdf.sh
#  ---------------------------------------------------------------------------
#  Lightweight RDF/XML validation and normalization script for ontology files.
#
#  Performs:
#    1. RDF/XML syntax validation (no OWL reasoning)
#    2. Whitespace normalization in annotations
#    3. Line ending normalization (macOS + Linux compatible)
#    4. Optional SPARQL-based quality checks (if query file exists)
#    5. RDF-level report generation with ROBOT
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
ONTOLOGY="ontology/snomed-mmo-module.rdf"
CATALOG="validation/catalog/catalog.xml"
REPORT_DIR="validation/robot/rdf"
TMP_ONTOLOGY="$REPORT_DIR/ontology.rdf"

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

# --- Step 1: RDF/XML Syntax Check --------------------------------------------
echo
echo "1️⃣  Checking RDF/XML syntax..."
if rapper -i rdfxml "$ONTOLOGY" -c > /dev/null; then
  echo "✅ RDF/XML syntax is valid."
else
  echo "❌ RDF syntax error detected. Aborting."
  exit 1
fi

# --- Step 2a: Whitespace Normalization -----------------------------------------
echo
echo "2️⃣  Normalizing annotation whitespace (dc*, rdfs:comment)..."
if command -v xmlstarlet >/dev/null 2>&1; then
  xmlstarlet ed \
    -u '//*[local-name()="comment" or local-name()="definition" or local-name()="description"]' \
    -x 'normalize-space()' \
    "$ONTOLOGY" > "$TMP_ONTOLOGY"
else
  echo "⚙️ Using XSLT fallback (macOS safe)..."
  xsltproc /dev/stdin "$ONTOLOGY" > "$TMP_ONTOLOGY" <<'XSL'
<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="1.0"
  xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
  <xsl:output method="xml" indent="yes" encoding="UTF-8"/>
  <!-- Identity transform -->
  <xsl:template match="@*|node()">
    <xsl:copy>
      <xsl:apply-templates select="@*|node()"/>
    </xsl:copy>
  </xsl:template>
  <!-- Remove redundant whitespace in selected annotations -->
  <xsl:template match="*[local-name()='comment' or local-name()='definition' or local-name()='description']/text()">
    <xsl:value-of select="normalize-space(.)"/>
  </xsl:template>
</xsl:stylesheet>
XSL
fi
echo "✅ Annotation whitespace normalized."

# --- Step 2b: Line Ending Normalization --------------------------------------
echo
echo "2️⃣a  Normalizing line endings..."
if command -v dos2unix >/dev/null 2>&1; then
  dos2unix -q "$TMP_ONTOLOGY"
else
  if sed --version >/dev/null 2>&1; then
    sed -i 's/\r$//' "$TMP_ONTOLOGY"
  else
    sed -i '' 's/\r$//' "$TMP_ONTOLOGY"
  fi
fi
echo "✅ Line endings normalized."

# --- Step 3: SPARQL Quality Check (optional) ----------------------------------
echo
if [ -f validation/query/query.rq ]; then
  echo "3️⃣  Running SPARQL quality check..."
  robot query \
    --catalog "$CATALOG" \
    --input "$TMP_ONTOLOGY" \
    --query validation/query/query.rq "$REPORT_DIR/query-results.ttl"
  echo "✅ SPARQL query executed successfully."
else
  echo "⚠️  No SPARQL query file found, skipping this step."
fi

# --- Step 4: RDF Report Generation -------------------------------------------
echo
echo "4️⃣  Generating RDF-level validation report..."
robot report \
  --catalog "$CATALOG" \
  --profil "validation/profile/profile.txt" \
  --input "$TMP_ONTOLOGY" \
  --output "$REPORT_DIR/report.tsv" \
  --fail-on ERROR
echo "✅ RDF-level report generated successfully."

# --- Step 5: Cleanup ----------------------------------------------------------
if [ -f "$TMP_ONTOLOGY" ]; then
  rm "$TMP_ONTOLOGY"
  echo "🗑️ Temporary cleaned ontology removed."
fi

echo
echo "🏁 RDF validation completed successfully."
echo "Reports available in: $REPORT_DIR"
echo "  - report.tsv"
echo "  - query-results.ttl (if applicable)"
echo "==============================================================="
exit 0
