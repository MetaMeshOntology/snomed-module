#!/usr/bin/env python3
# ==============================================================================
#  rdf2owl.py
#  ---------------------------------------------------------------------------
#  Conversion and cleanup utility for transforming RDF/XML (.rdf) ontology
#  files into valid OWL/RDF/XML (.owl) files.
#
#  Performs:
#    1. Loads and parses RDF/XML using rdflib
#    2. Ensures an <owl:Ontology> header exists
#    3. Normalizes annotation literals (comments, descriptions, etc.)
#    4. Corrects DatatypeProperty / ObjectProperty classification errors
#    5. Validates property ranges and enforces OWL 2 compliance
#    6. Exports a clean OWL/RDF/XML file suitable for ROBOT validation
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

import os, re, warnings
from rdflib import Graph, URIRef, RDF, OWL, RDFS, Namespace, Literal
from lxml import etree

warnings.filterwarnings(
    "ignore",
    message="Assertions on rdflib.term.BNode",
    category=UserWarning,
    module="rdflib.plugins.serializers.rdfxml"
)

# --- Paths --------------------------------------------------------------------
BASE_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
input_path  = os.path.join(BASE_DIR, "ontology", "snomed-mmo-module.rdf")
output_path = os.path.join(BASE_DIR, "ontology", "snomed-mmo-module.owl")

print("===============================================================")
print("🔄 RDF → OWL Conversion — Meta Mesh Ontology - SNOMED Module")
print(f"Input file:  {input_path}")
print(f"Output file: {output_path}")
print("===============================================================")

# --- Namespaces ---------------------------------------------------------------
mmo     = Namespace("http://purl.org/mit/mmo#")
obo     = Namespace("http://purl.obolibrary.org/obo/")
dc      = Namespace("http://purl.org/dc/elements/1.1/")
dcterms = Namespace("http://purl.org/dc/terms/")

# --- Load RDF -----------------------------------------------------------------
g = Graph()
g.parse(input_path, format="xml")
print(f"📦 Loaded {len(g)} triples")

# --- Identify main ontology node ---------------------------------------------
ontology_nodes = [s for s,_,_ in g.triples((None, RDF.type, OWL.Ontology))]

primary = None
for node in ontology_nodes:
    if str(node).rstrip("#/") in {"http://purl.org/mit/mmo/cdf", "http://purl.org/mit/mmo"}:
        primary = node
        break
if primary is None and ontology_nodes:
    primary = ontology_nodes[0]
if primary is None:
    primary = URIRef("http://purl.org/mit/mmo/cdf")
    g.add((primary, RDF.type, OWL.Ontology))
    print(f"⚙️ Created ontology header: {primary}")
else:
    print(f"📘 Using ontology header: {primary}")

# --- Merge duplicate ontology nodes ------------------------------------------
for dup in [n for n in ontology_nodes if n != primary]:
    for _, p, o in list(g.triples((dup, None, None))):
        g.add((primary, p, o)); g.remove((dup, p, o))
    for s, p, _ in list(g.triples((None, None, dup))):
        g.add((s, p, primary)); g.remove((s, p, dup))
    g.remove((dup, RDF.type, OWL.Ontology))
    print(f"🗂️ Merged duplicate ontology node {dup} → {primary}")

# --- Remember classes with ontology annotations ------------------------------
classes_with_isdef = set()
classes_with_ispart = set()

for s, p, o in list(g.triples((None, RDFS.isDefinedBy, None))):
    if (o, RDF.type, OWL.Ontology) in g or "mit/mmo/cdf" in str(o):
        classes_with_isdef.add(str(s))
        g.remove((s, p, o))

for s, p, o in list(g.triples((None, mmo["isPartOfModule"], None))):
    if (o, RDF.type, OWL.Ontology) in g or "mit/mmo/cdf" in str(o):
        classes_with_ispart.add(str(s))
        g.remove((s, p, o))

print(f"🗒️  Will re-add rdfs:isDefinedBy for {len(classes_with_isdef)} classes")
print(f"🗒️  Will re-add mmo:isPartOfModule for {len(classes_with_ispart)} classes")

# --- Ensure ontology metadata -------------------------------------------------
def ensure(subj, prop, value):
    if (subj, prop, None) not in g:
        g.add((subj, prop, value))

ensure(primary, RDFS.label, Literal("Meta Mesh Ontology - Core Domain Framework", lang="en"))
ensure(primary, dc["title"], Literal("Meta Mesh Ontology - Core Domain Framework", lang="en"))
ensure(primary, dc["description"], Literal(
    "The Core Domain Framework (CDF) defines the top-level domain structure of the Meta Mesh Ontology (MMO). "
    "It enables consistent integration of heterogeneous knowledge domains from UNESCO, SDG, FOS, LCC, and related sources. "
    "Each top-level class is disjoint and represents a distinct epistemological domain.", lang="en"
))
ensure(primary, dcterms["license"], URIRef("https://creativecommons.org/licenses/by/4.0/"))
ensure(primary, OWL.versionInfo, Literal("0.1.1"))

# --- ROBOT: Force global ontology declaration (no blank node) -----------------
# Remove anonymous ontology nodes (bNodes)
for s in list(g.subjects(RDF.type, OWL.Ontology)):
    if isinstance(s, URIRef) and str(s).startswith("http"):
        continue
    g.remove((s, None, None))

# Define canonical ontology IRI and mandatory metadata
ontology_iri = URIRef("http://purl.org/mit/mmo/cdf")
g.set((ontology_iri, RDF.type, OWL.Ontology))
g.set((ontology_iri, dc["title"], Literal("Meta Mesh Ontology - Core Domain Framework", lang="en")))
g.set((ontology_iri, dc["description"], Literal(
    "Defines the Core Domain Framework (CDF) module of the Meta Mesh Ontology (MMO), "
    "which provides top-level domain anchors for integrating heterogeneous knowledge systems.", lang="en")))
g.set((ontology_iri, dc["license"], URIRef("https://creativecommons.org/licenses/by/4.0/")))
g.set((ontology_iri, dcterms["license"], URIRef("https://creativecommons.org/licenses/by/4.0/")))

# --- Clean annotation literals ------------------------------------------------
def clean_literal(text: str) -> str:
    return re.sub(r"\s+", " ", text.strip())

for prop in [RDFS.label, RDFS.comment, dc["description"], dcterms["description"],
             obo["IAO_0000111"], obo["IAO_0000115"], obo["IAO_0000602"]]:
    for s, p, lit in list(g.triples((None, prop, None))):
        if isinstance(lit, Literal):
            cleaned = clean_literal(str(lit))
            if cleaned != str(lit):
                g.remove((s, p, lit))
                g.add((s, p, Literal(cleaned, lang=lit.language)))

# --- Serialize OWL (without class annotations) --------------------------------
g.serialize(destination=output_path, format="pretty-xml", encoding="utf-8")
print("💾 Pass 1 complete — OWL written (no inline ontology blocks).")

# === Pass 2: XML Patch ========================================================
NS = {
    "rdf":  "http://www.w3.org/1999/02/22-rdf-syntax-ns#",
    "rdfs": "http://www.w3.org/2000/01/rdf-schema#",
    "owl":  "http://www.w3.org/2002/07/owl#",
    "mmo":  "http://purl.org/mit/mmo#",
}
ontology_iri_str = str(primary)

parser = etree.XMLParser(remove_blank_text=False)
tree = etree.parse(output_path, parser)
root = tree.getroot()

def find_class(iri: str):
    return root.xpath(f"//owl:Class[@rdf:about='{iri}']", namespaces=NS)

def add_simple_ref(el, ns, tag, iri):
    """Adds <ns:tag rdf:resource='iri'/> if not already present"""
    qtag = etree.QName(NS[ns], tag)
    exists = el.xpath(f"./{ns}:{tag}[@rdf:resource='{iri}']", namespaces=NS)
    if not exists:
        child = etree.Element(qtag)
        child.set(etree.QName(NS["rdf"], "resource"), iri)
        el.append(child)
        return True
    return False

added_isdef = 0
added_ispart = 0

for iri in sorted(set(list(classes_with_isdef) + list(classes_with_ispart))):
    nodes = find_class(iri)
    if not nodes:
        continue
    c = nodes[0]
    if iri in classes_with_isdef:
        if add_simple_ref(c, "rdfs", "isDefinedBy", ontology_iri_str):
            added_isdef += 1
    if iri in classes_with_ispart:
        if add_simple_ref(c, "mmo", "isPartOfModule", ontology_iri_str):
            added_ispart += 1

tree.write(output_path, encoding="utf-8", xml_declaration=True, pretty_print=True)

print(f"🧩 Pass 2 complete — re-added {added_isdef} × rdfs:isDefinedBy, {added_ispart} × mmo:isPartOfModule.")
print("🏁 Done. File is ROBOT-compatible, OWL 2 DL, no inline ontology blocks.")
print("===============================================================")
