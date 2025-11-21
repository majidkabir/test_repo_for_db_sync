SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/  
/* Store procedure: ispSortNPackExtInfo2                                */  
/* Copyright      : IDS                                                 */  
/*                                                                      */  
/* Purpose: Decode Label No Scanned                                     */  
/*                                                                      */  
/* Called from:                                                         */  
/*                                                                      */  
/* Exceed version: 5.4                                                  */  
/*                                                                      */  
/* Modifications log:                                                   */  
/*                                                                      */  
/* Date       Rev  Author   Purposes                                    */  
/* 2012-12-06 1.0  James      SOS262234 Created                         */  
/************************************************************************/  
  
CREATE PROCEDURE [dbo].[ispSortNPackExtInfo2]  
   @cLoadKey      NVARCHAR(10),  
   @cConsigneeKey NVARCHAR(15),  
   @cLabelNo      NVARCHAR(20),  
   @cStorerKey    NVARCHAR(15),  
   @cSKU          NVARCHAR(20),  
   @nQTY          INT,   
   @cExtendedInfo NVARCHAR(20) OUTPUT  
AS  
BEGIN  
   SET NOCOUNT ON  
   SET QUOTED_IDENTIFIER OFF  
   SET ANSI_NULLS OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  
     
   DECLARE @cBUSR10        NVARCHAR(30)  

   -- Get SKU info  
   SELECT @cBUSR10 = ISNULL(BUSR10, '0')    
   FROM dbo.SKU WITH (NOLOCK)  
   WHERE StorerKey = @cStorerKey  
      AND SKU = @cSKU  

   SET @cExtendedInfo = 'U/L: ' + LEFT(@cBUSR10, 5)
QUIT:  
END -- End Procedure  


GO