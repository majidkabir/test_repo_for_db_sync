SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/    
/* Store procedure: rdt_1855DisableQTY01                                */    
/* Copyright      : LF Logistics                                        */  
/*                                                                      */  
/* Purpose: Disable qty field based on product type                     */    
/*                                                                      */    
/* Modifications log:                                                   */    
/*                                                                      */    
/* Date         Author    Ver.  Purposes                                */    
/* 2021-08-13   James     1.0   WMS-17335 Created                       */    
/************************************************************************/    
    
CREATE PROCEDURE [RDT].[rdt_1855DisableQTY01]    
   @nMobile                INT,     
   @nFunc                  INT,     
   @cLangCode              NVARCHAR( 3),     
   @nStep                  INT,     
   @nInputKey              INT,  
   @cTaskdetailKey         NVARCHAR( 10),     
   @tVarDisableQTYField    VARIABLETABLE READONLY,  
   @cDisableQTYField       NVARCHAR( 1)  OUTPUT,    
   @nErrNo                 INT           OUTPUT,     
   @cErrMsg                NVARCHAR( 20) OUTPUT    
AS    
BEGIN    
   SET NOCOUNT ON    
   SET QUOTED_IDENTIFIER OFF    
   SET ANSI_NULLS OFF    
   SET CONCAT_NULL_YIELDS_NULL OFF    
    
   DECLARE @cSKUGroup         NVARCHAR( 10)    
   DECLARE @cStorerKey        NVARCHAR( 15)  
   DECLARE @cSKU              NVARCHAR( 20)  
  
   -- TM Assisted Cluster Pick    
   IF @nFunc = 1855    
   BEGIN  
      -- Enable by default    
      SET @cDisableQTYField = '0'    
  
      -- Get TaskDetail info    
      SELECT @cStorerKey = Storerkey,  
             @cSKU = Sku  
      FROM dbo.TaskDetail WITH (NOLOCK)  
      WHERE TaskDetailKey = @cTaskdetailKey  
     
      -- Get sku group, 01 = footwear; the rest apparel/hardware  
      SELECT @cSKUGroup = SKUGROUP  
      FROM dbo.SKU WITH (NOLOCK)  
      WHERE StorerKey = @cStorerKey  
      AND   SKU = @cSKU  
  
      IF @cSKUGroup = '01'  
         SET @cDisableQTYField = '1'  
   END    
END    

GO