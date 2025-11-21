SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
CREATE PROC [RDT].[rdtGetInputColumn]   
   @cInMessage NVARCHAR(MAX)   
AS   
SET NOCOUNT ON  
SET QUOTED_IDENTIFIER OFF  
SET ANSI_NULLS OFF  
SET CONCAT_NULL_YIELDS_NULL OFF  
    
DECLARE   
   @iDoc      INT,   
   @cColName  NVARCHAR( 20),  
   @cColValue NVARCHAR( 60),  
   @cSQL      NVARCHAR( 4000)  
  
DECLARE @XML_Row TABLE  
(  
   Col        NVARCHAR( 20),  
   Value      NVARCHAR( 60)  
)  
  
-- Get a  handle for the XML doc  
EXEC sp_xml_preparedocument @iDoc OUTPUT, @cInMessage  
  
-- Transform XML string into table  
INSERT INTO @XML_Row  
SELECT *   
FROM OPENXML (@iDoc, '/fromRDT/input', 2) WITH   
   (  
      Col     NVARCHAR( 20) '@id',  
      Value   NVARCHAR( 60) '@value'  
   )  
  
-- Release the handle  
EXEC sp_xml_removedocument @iDoc  
  
SET @cSQL = ''  
SET @cColName = ''  

SELECT * FROM @XML_Row

GO