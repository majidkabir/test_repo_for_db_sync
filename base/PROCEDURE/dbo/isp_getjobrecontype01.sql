SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store procedure: isp_GetJobReconType01                               */
/* Purpose: Show Job Reconciliation Type in drop down list              */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date       Rev  Author     Purposes                                  */
/* 2015-11-19 1.0  James      SOS#315942. Created                       */
/************************************************************************/
    
CREATE PROC [dbo].[isp_GetJobReconType01] (    
   @nMobile       int   
)     
AS    
BEGIN    
     
   SET NOCOUNT ON  
   SET QUOTED_IDENTIFIER OFF  
   SET ANSI_NULLS OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  

   SELECT CODE AS Label, CODE AS ColText 
   FROM dbo.CODELKUP WITH (NOLOCK)   
   WHERE ListName = 'VAPRECONTY'
   ORDER BY 1     
END

GO