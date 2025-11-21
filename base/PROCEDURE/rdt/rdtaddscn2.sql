SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
CREATE PROCEDURE [RDT].[rdtAddScn2]  
   @nScn INT,   
   @cLang_Code NVARCHAR( 3),   
   @cLine01 NVARCHAR( 125) = NULL,   
   @cLine02 NVARCHAR( 125) = NULL,   
   @cLine03 NVARCHAR( 125) = NULL,   
   @cLine04 NVARCHAR( 125) = NULL,   
   @cLine05 NVARCHAR( 125) = NULL,   
   @cLine06 NVARCHAR( 125) = NULL,   
   @cLine07 NVARCHAR( 125) = NULL,   
   @cLine08 NVARCHAR( 125) = NULL,   
   @cLine09 NVARCHAR( 125) = NULL,   
   @cLine10 NVARCHAR( 125) = NULL,   
   @cLine11 NVARCHAR( 125) = NULL,   
   @cLine12 NVARCHAR( 125) = NULL,   
   @cLine13 NVARCHAR( 125) = NULL,   
   @cLine14 NVARCHAR( 125) = NULL,   
   @cLine15 NVARCHAR( 125) = NULL,  
   @nFunc INT = 0   
AS  
SET NOCOUNT ON  
SET QUOTED_IDENTIFIER OFF  
SET ANSI_NULLS OFF  
SET CONCAT_NULL_YIELDS_NULL OFF  
  
   -- Drop message to SQL  
   IF EXISTS (SELECT Scn FROM rdt.RDTScn WHERE Scn = @nScn AND Lang_Code = @cLang_Code)  
   BEGIN  
      PRINT 'Screen ' + CAST( @nScn AS NVARCHAR( 5)) + ' already exists'  
   END  
   ELSE  
   BEGIN  
      INSERT INTO rdt.RDTScn ( Scn, Lang_Code, Line01, Line02, Line03, Line04, Line05, Line06, Line07, Line08, Line09, Line10, Line11, Line12, Line13, Line14, Line15, Func)   
      VALUES ( @nScn, @cLang_Code, @cLine01, @cLine02, @cLine03, @cLine04, @cLine05, @cLine06, @cLine07, @cLine08, @cLine09, @cLine10, @cLine11, @cLine12, @cLine13, @cLine14, @cLine15, @nFunc)  
        
--      EXEC [dbo].[isp_Trasnfer2NewScn]   
--        @n_Scn = @nScn,  
--        @n_Func = 0 ,  
--        @c_ConverAll = ''  
      
      EXEC [dbo].[isp_Trasnfer2NewScn2]   
        @n_Scn = @nScn,  
        @n_Func = 0 ,  
        @c_ConverAll = ''  
        
      IF NOT EXISTS (SELECT 1 FROM rdt.RDTSCNHeader WITH (NOLOCK)  
                     WHERE Scn = @nScn)  
      BEGIN  
           
         INSERT INTO rdt.RDTSCNHeader ( Scn , ScnDescr , Lang_Code)  
         VALUES ( @nScn , @nScn , @cLang_Code)  
           
      END                       
        
   END  
         

GO