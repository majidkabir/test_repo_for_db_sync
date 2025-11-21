SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store procedure: isp_GetJobReconRsn01                                */
/* Purpose: Show workstation reason code in drop down list              */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date       Rev  Author     Purposes                                  */
/* 2015-11-19 1.0  James      SOS#315942. Created                       */
/************************************************************************/
    
CREATE PROC [dbo].[isp_GetJobReconRsn01] (    
   @nMobile       int   
)     
AS    
BEGIN    
     
   SET NOCOUNT ON  
   SET QUOTED_IDENTIFIER OFF  
   SET ANSI_NULLS OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  

   DECLARE @cReconType  NVARCHAR( 20)

   SELECT @cReconType = V_String1 
   FROM RDT.RDTMOBREC WITH (NOLOCK) 
   WHERE Mobile = @nMobile

   SELECT DESCRIPTION AS Label, DESCRIPTION AS ColText 
   FROM dbo.CODELKUP WITH (NOLOCK)   
   WHERE ListName = @cReconType
        
END

GO