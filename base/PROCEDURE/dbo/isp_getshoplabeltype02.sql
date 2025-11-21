SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/    
/* Store Procedure:  isp_GetShopLabelType02                             */    
/* Creation Date:                                                       */    
/* Copyright: IDS                                                       */    
/* Written by: James                                                    */    
/*                                                                      */    
/* Purpose:  SOS#294060 Get type of shop label to print                 */    
/*                                                                      */    
/* Input Parameters:  @nMobile                                          */    
/*                                                                      */    
/* Called By:  rdtfnc_PrintShopLabel                                    */    
/*                                                                      */    
/* PVCS Version: 1.2                                                    */    
/*                                                                      */    
/* Version: 5.4                                                         */    
/*                                                                      */    
/* Data Modifications:                                                  */    
/*                                                                      */    
/* Updates:                                                             */    
/* Date         Rev  Author        Purposes                             */    
/* 2013-10-29   1.0  James         Created                              */
/************************************************************************/    

CREATE PROC [dbo].[isp_GetShopLabelType02] (    
   @nMobile       int   
)     
AS    
BEGIN    
     
   SET NOCOUNT ON  
   SET QUOTED_IDENTIFIER OFF  
   SET ANSI_NULLS OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  

   DECLARE @cStorerKey  NVARCHAR( 15) 
   
   SELECT @cStorerKey = StorerKey 
   FROM RDT.RDTMOBREC WITH (NOLOCK) 
   WHERE Mobile = @nMobile
   
   SELECT DISTINCT Code AS Label, Code AS ColText 
   FROM dbo.CodeLkUp WITH (NOLOCK)  
   WHERE ListName = 'SHPLBLTYPC' 
   AND   StorerKey = @cStorerKey
   ORDER BY 1
        
END

GO