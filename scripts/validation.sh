#!/usr/bin/env bash
# ==============================================================================
#  validation.sh
#  ---------------------------------------------------------------------------
#  Unified validation pipeline orchestrator for the Meta Mesh Ontology (MMO).
#
#  Executes the following validation stages in sequence:
#    1. RDF/XML validation (validate-rdf.sh)
#    2. Turtle validation (validate-ttl.sh)
#    3. OWL validation (validate-owl.sh)
#
#  Each subscript performs syntax, consistency, and profile checks using
#  Raptor RDF (rapper), ROBOT, and SPARQL queries as applicable.
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
BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VALIDATION_DIR="$BASE_DIR/validation/robot"
RDF_SCRIPT="$BASE_DIR/validation/robot/validate-rdf.sh"
TTL_SCRIPT="$BASE_DIR/validation/robot/validate-ttl.sh"
OWL_SCRIPT="$BASE_DIR/validation/robot/validate-owl.sh"
REPORT_MASTER="$VALIDATION_DIR/master-validation-report.txt"

mkdir -p "$VALIDATION_DIR/rdf" "$VALIDATION_DIR/ttl" "$VALIDATION_DIR/owl"

# === Header ==================================================================
echo "======================================================================"
echo "🧪 META MESH ONTOLOGY - SNOMED MODULE — FULL VALIDATION PIPELINE"
echo "======================================================================"
echo "Base directory:   $BASE_DIR"
echo "Validation folder: $VALIDATION_DIR"
echo "Master report:    $REPORT_MASTER"
echo "Start time:       $(date)"
echo "======================================================================"
echo

chmod +x "$RDF_SCRIPT" "$TTL_SCRIPT" "$OWL_SCRIPT" 2>/dev/null || true

# === Helper: Run Validation Stage ============================================
run_stage () {
  local name="$1"
  local script="$2"
  local log="$3"
  echo "🔹 Stage: $name"
  echo "------------------------------------------------------------------"
  if bash "$script" | tee "$log"; then
    echo "✅ $name completed successfully."
    echo
    return 0
  else
    echo "❌ $name failed (see $log for details)."
    echo
    return 1
  fi
}

# === Run Stages Sequentially ==================================================
STATUS_RDF=0
STATUS_TTL=0
STATUS_OWL=0

run_stage "RDF/XML Validation" "$RDF_SCRIPT" "$VALIDATION_DIR/rdf/rdf-validation.log" || STATUS_RDF=1
run_stage "Turtle Validation" "$TTL_SCRIPT" "$VALIDATION_DIR/ttl/ttl-validation.log" || STATUS_TTL=1
run_stage "OWL Validation" "$OWL_SCRIPT" "$VALIDATION_DIR/owl/owl-validation.log" || STATUS_OWL=1

# === Aggregate Logs ==========================================================
echo "📦 Aggregating all validation logs into $REPORT_MASTER ..."
{
  echo "==============================================================="
  echo "📘 META MESH ONTOLOGY - SNOMED MODULE — MASTER VALIDATION REPORT"
  echo "Generated: $(date)"
  echo "==============================================================="
  echo
  echo "---------------- RDF/XML Validation ----------------"
  cat "$VALIDATION_DIR/rdf/rdf-validation.log" 2>/dev/null || echo "No RDF log found."
  echo
  echo "---------------- Turtle Validation ----------------"
  cat "$VALIDATION_DIR/ttl/ttl-validation.log" 2>/dev/null || echo "No TTL log found."
  echo
  echo "---------------- OWL Validation ----------------"
  cat "$VALIDATION_DIR/owl/owl-validation.log" 2>/dev/null || echo "No OWL log found."
  echo
  echo "==============================================================="
  echo "RDF stage exit code:  $STATUS_RDF"
  echo "TTL stage exit code:  $STATUS_TTL"
  echo "OWL stage exit code:  $STATUS_OWL"
} > "$REPORT_MASTER"

# === Completion Summary ======================================================
echo
if [[ $STATUS_RDF -eq 0 && $STATUS_TTL -eq 0 && $STATUS_OWL -eq 0 ]]; then
  echo "🏁 All validation stages completed successfully."
  echo "➡️  Combined report available at: $REPORT_MASTER"
  echo "======================================================================"
  exit 0
else
  echo "⚠️  One or more validation stages reported errors."
  echo "   RDF: $STATUS_RDF, TTL: $STATUS_TTL, OWL: $STATUS_OWL"
  echo "➡️  See $REPORT_MASTER for full details."
  echo "======================================================================"
  exit 1
fi
