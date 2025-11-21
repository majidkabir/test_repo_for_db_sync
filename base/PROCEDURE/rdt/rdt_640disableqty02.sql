SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/    
/* Store procedure: rdt_640DisableQTY02                                 */    
/* Copyright      : LF Logistics                                        */  
/*                                                                      */  
/* Purpose: Disable qty field based on sku.skugroup                     */    
/*                                                                      */    
/* Modifications log:                                                   */    
/*                                                                      */    
/* Date         Author    Ver.  Purposes                                */    
/* 2021-07-15   James     1.0   WMS-17429 Created                       */    
/************************************************************************/    
    
CREATE PROCEDURE [RDT].[rdt_640DisableQTY02]    
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
    
   DECLARE @cProductCategory  NVARCHAR( 30)    
   DECLARE @cStorerKey        NVARCHAR( 15)  
   DECLARE @cSKU              NVARCHAR( 20)  
  
   -- Get TaskDetail info    
   SELECT @cStorerKey = Storerkey,  
          @cSKU = Sku  
   FROM dbo.TaskDetail WITH (NOLOCK)  
   WHERE TaskDetailKey = @cTaskdetailKey  
     
   -- Get product category  
   SELECT @cProductCategory = SKUGROUP  
   FROM dbo.SKU WITH (NOLOCK)  
   WHERE StorerKey = @cStorerKey  
   AND   SKU = @cSKU  
  
   -- TM Cluster Pick    
   IF @nFunc = 640    
   BEGIN    
      -- Enable by default    
      SET @cDisableQTYField = '0'    
  
      IF EXISTS ( SELECT 1 FROM dbo.CODELKUP WITH (NOLOCK)  
                  WHERE LISTNAME = 'SKUGROUP'  
                  AND   Code = @cProductCategory  
                  AND   StorerKey = @cStorerKey  
                  AND   code2 = @nFunc  
                  AND   Short = '1')  
      BEGIN  
         SET @cDisableQTYField = '1' -- Disable    
      END   
   END    
END    

GO