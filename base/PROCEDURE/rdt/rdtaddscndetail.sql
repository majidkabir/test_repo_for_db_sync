SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

CREATE PROCEDURE [RDT].[rdtAddScnDetail]
   @nScn INT, 
   @cLang_Code NVARCHAR( 3), 
   @cFieldNo NVARCHAR( 20) = NULL, 
   @cXCol INT = NULL, 
   @cYRow INT = NULL, 
   @cTextColor          NVARCHAR( 20),
   @cColType            NVARCHAR( 20),
   @cColRegExp          NVARCHAR( 255),
   @cColText            NVARCHAR( 20),
   @cColValue           NVARCHAR( 50),
   @cColValueLength     NVARCHAR( 2),
   @cColLookUpView      NVARCHAR( 200),
   @cLine04             NVARCHAR( 125) = NULL, 
   @cLine05             NVARCHAR( 125) = NULL, 
   @cLine06             NVARCHAR( 125) = NULL, 
   @cLine07             NVARCHAR( 125) = NULL, 
   @cLine08             NVARCHAR( 125) = NULL, 
   @cLine09             NVARCHAR( 125) = NULL, 
   @cLine10             NVARCHAR( 125) = NULL, 
   @cLine11             NVARCHAR( 125) = NULL, 
   @cLine12             NVARCHAR( 125) = NULL, 
   @cLine13             NVARCHAR( 125) = NULL, 
   @cLine14             NVARCHAR( 125) = NULL, 
   @cLine15             NVARCHAR( 125) = NULL,
   @nFunc	            INT = 0	
AS
SET NOCOUNT ON
SET QUOTED_IDENTIFIER OFF
SET ANSI_NULLS OFF
SET CONCAT_NULL_YIELDS_NULL OFF

   -- Drop message to SQL
   IF EXISTS (SELECT Scn FROM rdt.ScnDetail WHERE Scn = @nScn AND Lang_Code = @cLang_Code)
   BEGIN
      PRINT 'Screen ' + CAST( @nScn AS NVARCHAR( 5)) + ' already exists'
   END
   ELSE
   BEGIN
      INSERT INTO RDT.RDTSCNDETAIL
           (Scn
           ,FieldNo
           ,XCol
           ,YRow
           ,TextColor
           ,ColType
           ,ColRegExp
           ,ColText
           ,ColValue
           ,ColValueLength
           ,ColLookUpView
           ,Func
           ,Lang_Code)
     VALUES
           (@nScn
           , @cFieldNo 
           , @cXCol 
           , @cYRow 
           , @cTextColor     
           , @cColType       
           , @cColRegExp     
           , @cColText       
           , @cColValue      
           , @cColValueLength
           , @cColLookUpView 
           , @nFunc
           , @cLang_Code)
      
      
   END
   
   


         

GO