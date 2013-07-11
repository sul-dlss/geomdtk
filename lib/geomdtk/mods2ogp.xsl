<?xml version="1.0" encoding="UTF-8"?>
<!-- 
     mods2ogp.xsl - Transforms MODS with GML extensions into an OGP Solr document
     
     Copyright 2013, Stanford University Libraries.
     
     Created by Darren Hardy.

     For OGP Solr schema, see:

       https://github.com/OpenGeoportal/ogpSolrConfig/blob/master/ogpSolrConfig/SolrConfig/schema.xml
       
     -->
<xsl:stylesheet 
  xmlns="http://lucene.apache.org/solr/4/document"
  xmlns:gco="http://www.isotc211.org/2005/gco" 
  xmlns:gmd="http://www.isotc211.org/2005/gmd"
  xmlns:gml="http://www.opengis.net/gml/3.2"
  xmlns:mods="http://www.loc.gov/mods/v3"
  xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#" 
  xmlns:xlink="http://www.w3.org/1999/xlink"
  xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
  version="1.0" 
  exclude-result-prefixes="gmd gco gml mods rdf xsl">
  <xsl:output method="xml" version="1.0" encoding="UTF-8" indent="yes"/>
  <xsl:strip-space elements="*"/>
  <xsl:template match="/mods:mods">
    <xsl:variable name="geoserver" select="'http://kurma-podd1.stanford.edu/geoserver'"/>
    <xsl:variable name="stacks" select="'http://ogpapp-dev.stanford.edu/stacks'"/>
    <xsl:variable name="druid" select="substring(mods:identifier[@type='local' and @displayLabel='druid']/text(), string-length('druid:')+1)"/>
    <xsl:variable name="purl" select="mods:location/mods:url[@displayLabel='PURL']/text()"/>
    <xsl:variable name="downloadURL">
      <xsl:value-of select="$stacks"/>
      <xsl:value-of select="concat('/',$druid)"/>
      <xsl:text>/content/</xsl:text>
      <xsl:value-of select="substring-before(mods:identifier[@type='local' and @displayLabel='filename']/text(), '.shp')"/>
      <xsl:text>.zip</xsl:text>
    </xsl:variable>
    <xsl:variable name="metadataURL">
      <xsl:value-of select="$stacks"/>
      <xsl:value-of select="concat('/',$druid)"/>
      <xsl:text>/metadata/geoMetadata.xml</xsl:text>
    </xsl:variable>
    <add>
      <doc>
        <field name="LayerId"><xsl:value-of select="$druid"/></field>
        <field name="Name">
          <xsl:value-of select="substring-before(mods:identifier[@type='local' and @displayLabel='filename']/text(), '.shp')"/>
        </field>
        <field name="ExternalLayerId"><xsl:value-of select="$purl"/></field>
        <!-- XXX: set to Public which disables the "login" -->
        <field name="Access"><xsl:text>Public</xsl:text></field>
        <field name="Institution"><xsl:text>Stanford</xsl:text></field>
        <field name="WorkspaceName"><xsl:text>druid</xsl:text></field>
        <field name="GeoReferenced"><xsl:text>true</xsl:text></field>
        <field name="Availability"><xsl:text>Online</xsl:text></field>
        <field name="ContentDate"><!-- year only -->
          <xsl:value-of select="substring(mods:originInfo/mods:dateIssued/text(), 0, 5)"/>
          <xsl:text>-01-01T00:00:00Z</xsl:text>
        </field>
        <field name="LayerDisplayName">
          <xsl:value-of select="mods:titleInfo/mods:title[@type='main']/text()"/>
        </field>
        <xsl:if test="mods:physicalDescription/mods:form[text() = 'Shapefile']">
          <field name="DataType">
            <xsl:text>Polygon</xsl:text>
            <!-- XXX: this needs to come from the data for Point, Line, Polygon -->
          </field>
        </xsl:if>
        <xsl:for-each select="mods:name[mods:role/mods:roleTerm/text()='Publisher']">        
          <field name="Publisher">
            <xsl:value-of select="mods:namePart/text()"/>
          </field>
        </xsl:for-each>
        <field name="Abstract">
          <xsl:value-of select="mods:abstract[@displayLabel='abstract']/text()"/>          
        </field>
        <field name="ThemeKeywords">
          <xsl:for-each select="mods:subject/mods:topic">
            <xsl:value-of select="text()"/><xsl:text>; </xsl:text>
          </xsl:for-each>
        </field>
        <field name="PlaceKeywords">
          <xsl:for-each select="mods:subject/mods:geographic">
            <xsl:value-of select="text()"/><xsl:text>; </xsl:text>
          </xsl:for-each>
        </field>
        <xsl:for-each select="mods:extension/rdf:RDF/rdf:Description[@rdf:about = 'geo#envelope']/gml:Envelope">
          <xsl:variable name="x2" select="number(substring-before(gml:upperCorner/text(), ' '))"/>
          <xsl:variable name="x1" select="number(substring-before(gml:lowerCorner/text(), ' '))"/>
          <xsl:variable name="y2" select="number(substring-after(gml:upperCorner/text(), ' '))"/>
          <xsl:variable name="y1" select="number(substring-after(gml:lowerCorner/text(), ' '))"/>
          <field name="MinX">
            <xsl:value-of select="$x1"/>
          </field>
          <field name="MinY">
            <xsl:value-of select="$y1"/>
          </field>
          <field name="MaxX">
            <xsl:value-of select="$x2"/>
          </field>
          <field name="MaxY">
            <xsl:value-of select="$y2"/>
          </field>
          <field name="CenterX">
            <!-- XXX: doesn't work across meridian -->
            <xsl:value-of select="($x2 - $x1) div 2 + $x1"/>
          </field>
          <field name="CenterY">
            <xsl:value-of select="($y2 - $y1) div 2 + $y1"/>
          </field>
          <xsl:comment> XXX: in degrees ??? </xsl:comment>
          <field name="HalfWidth">
            <xsl:value-of select="($x2 - $x1) div 2"/>
          </field>
          <xsl:comment> XXX: in degrees ??? </xsl:comment>
          <field name="HalfHeight">
            <xsl:value-of select="($y2 - $y1) div 2"/>
          </field>
          <xsl:comment> XXX: in degrees**2 ??? </xsl:comment>
          <field name="Area">
            <xsl:value-of select="round(($y2 - $y1) * ($x2 - $x1))"/>
          </field>
          <field name="SrsProjectionCode">
            <xsl:value-of select="@srsName"/>
          </field>
        </xsl:for-each>
        <field name="Location">
          <!-- XXX: remove hardcoded links here -->
          <xsl:text>
              { 
              "wms":       ["</xsl:text>
              <xsl:value-of select="$geoserver"/>
              <xsl:text>/wms"],
              "tilecache": ["</xsl:text>
              <xsl:value-of select="$geoserver"/>
              <xsl:text>/gwc/service/wms"],
              "wfs":       ["</xsl:text>
              <xsl:value-of select="$geoserver"/>
              <xsl:text>/wfs"],
              "metadata":  ["</xsl:text>
              <xsl:value-of select="$metadataURL"/>
              <xsl:text>"],
              "download":  ["</xsl:text>
              <xsl:value-of select="$downloadURL"/>
                <xsl:text>"]
              }
          </xsl:text>
      </field>
      <field name="FgdcText" xlink:type="simple">
        <xsl:attribute name="xlink:href">
          <xsl:value-of select="$metadataURL"/>
        </xsl:attribute>
      </field>
      
      </doc>
    </add>
  </xsl:template>
  <xsl:template match="*"/>
</xsl:stylesheet>