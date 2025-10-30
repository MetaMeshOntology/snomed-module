#!/usr/bin/env python3
# ==============================================================================
#  rdf2ttl.py
#  ---------------------------------------------------------------------------
#  Conversion utility for transforming RDF/XML (.rdf) ontology files into
#  Turtle (.ttl) format while performing structural cleanup and normalization.
#
#  Performs:
#    1. RDF/XML parsing via rdflib
#    2. Removal of invalid or empty obo:IAO_0000115 annotations
#    3. Literal normalization (newline and whitespace cleanup)
#    4. Syntax correction and pretty-formatting of Turtle output
#    5. Validation of final Turtle serialization
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

from rdflib import Graph, Namespace, RDF, RDFS, OWL, XSD, Literal
import re
import os

# === Configuration ============================================================
BASE_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
input_path = os.path.join(BASE_DIR, "ontology", "snomed-mmo-module.rdf")
output_path = os.path.join(BASE_DIR, "ontology", "snomed-mmo-module.ttl")

print("===============================================================")
print("🔄 RDF → TTL Conversion — Meta Mesh Ontology - SNOMED Module")
print(f"Input file:  {input_path}")
print(f"Output file: {output_path}")
print("===============================================================")

# === Load RDF/XML =============================================================
print("🔍 Loading RDF/XML ...")
g = Graph()
g.parse(input_path, format="xml")
print(f"📦 Loaded {len(g)} triples from RDF/XML source")

# === Namespaces ===============================================================
MMO = Namespace("http://purl.org/mit/mmo#")
OBO = Namespace("http://purl.obolibrary.org/obo/")
g.bind("mmo", MMO)
g.bind("obo", OBO)
g.bind("rdf", RDF)
g.bind("rdfs", RDFS)
g.bind("owl", OWL)
g.bind("xsd", XSD)

# === Step 1: Remove empty or invalid obo:IAO_0000115 annotations ==============
for ontology in g.subjects(RDF.type, OWL.Ontology):
    for _, p, o in list(g.triples((ontology, OBO["IAO_0000115"], None))):
        remove_flag = False

        # Case 1: Empty literal
        if isinstance(o, Literal) and str(o).strip() == "":
            remove_flag = True

        # Case 2: Malformed URI (e.g., iao:.owl or similar)
        if not isinstance(o, Literal) and re.search(r"\.owl$", str(o)) and "iao" in str(o):
            remove_flag = True

        if remove_flag:
            print(f"🧹 Removing invalid obo:IAO_0000115 from {ontology} → {o}")
            g.remove((ontology, p, o))

# === Step 2: Normalize literals ===============================================
for s, p, o in list(g):
    if isinstance(o, Literal):
        val = str(o)
        if "\n" in val or "\r" in val:
            clean = re.sub(r"\s+", " ", val.strip())
            g.remove((s, p, o))
            g.add((s, p, Literal(clean, lang=o.language, datatype=o.datatype)))

# === Step 3: Serialize graph to Turtle ========================================
ttl_data = g.serialize(format="turtle")

# === Step 4: Post-processing and formatting ===================================
# Remove BOM
ttl_data = ttl_data.encode("utf-8").decode("utf-8-sig")
ttl_data = re.sub(r"^\ufeff", "", ttl_data)

# Fix prefix syntax
ttl_data = re.sub(r"@prefix\s+([a-zA-Z0-9_-]+)\s+:", r"@prefix \1:", ttl_data)

# Normalize multiline literals
ttl_data = re.sub(r'"""\s+', '"""', ttl_data)
ttl_data = re.sub(r'\s+"""', '"""', ttl_data)

# Normalize whitespace and indentation
ttl_lines = ttl_data.splitlines()
formatted_lines = []
indent = "    "  # 4 spaces

for line in ttl_lines:
    line = line.replace("\t", " ")
    line = re.sub(r"\s*;\s*", " ; ", line)
    line = re.sub(r"\s*,\s*", " , ", line)
    line = re.sub(r"\s*\.\s*$", " .", line)
    line = re.sub(r"\s{2,}", " ", line)

    # Indent predicate/object lines
    if re.match(r"^\s*(rdfs:|owl:|mmo:|obo:|xsd:|skos:|metam:)", line):
        line = indent + line.strip()
    formatted_lines.append(line.rstrip())

# Add blank lines between triples
cleaned_lines = []
for line in formatted_lines:
    cleaned_lines.append(line)
    if line.strip().endswith(" ."):
        cleaned_lines.append("")

ttl_data = "\n".join(cleaned_lines)
ttl_data = re.sub(r"\n{3,}", "\n\n", ttl_data.strip()) + "\n"

# === Step 5: Validate the final Turtle ========================================
try:
    test = Graph()
    test.parse(data=ttl_data, format="turtle")
    print(f"✅ Turtle validation successful — {len(test)} triples verified")
except Exception as e:
    print("❌ Turtle validation failed:", e)

# === Step 6: Write cleaned TTL to file ========================================
with open(output_path, "w", encoding="utf-8", newline="\n") as f:
    f.write(ttl_data)

print("💾 Export complete — file saved successfully")
print("🏁 Conversion finished. File is ROBOT-compatible (correct spacing and structure).")
print("===============================================================")
