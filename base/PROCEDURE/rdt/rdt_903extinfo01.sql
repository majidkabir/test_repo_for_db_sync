SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/    
/* Store procedure: rdt_903ExtInfo01                                    */    
/* Copyright      : LFLogistics                                         */    
/*                                                                      */    
/* Modifications log:                                                   */    
/*                                                                      */    
/* Date       Rev  Author   Purposes                                    */    
/* 28-11-2019 1.0  Chermaine  WMS-11218 show total and                  */
/*                            counted quantity per SKU(cc01)            */
/************************************************************************/    
    
CREATE PROCEDURE [RDT].[rdt_903ExtInfo01] 
   @nMobile     INT, 
   @nFunc       INT, 
   @cLangCode   NVARCHAR( 3), 
   @nStep       INT, 
   @nInputKey   INT, 
   @cFacility   NVARCHAR( 5), 
   @cStorerKey  NVARCHAR( 15), 
   @cRefNo      NVARCHAR( 10), 
   @cPickSlipNo NVARCHAR( 10),
   @cLoadKey    NVARCHAR( 10),
   @cOrderKey   NVARCHAR( 10), 
   @cDropID     NVARCHAR( 20),
   @cSKU        NVARCHAR( 20)='',
   @cExtendedInfo NVARCHAR( 20) OUTPUT
   
AS    
BEGIN    
   SET NOCOUNT ON    
   SET QUOTED_IDENTIFIER OFF    
   SET ANSI_NULLS OFF    
   SET CONCAT_NULL_YIELDS_NULL OFF    
   
   DECLARE 
   @cCHK_SKU       NVARCHAR( 10), 
   @cCHK_QTY       NVARCHAR( 10), 
   @cPPA_SKU       NVARCHAR( 10), 
   @cPPA_QTY       NVARCHAR( 10),
   @nPUOM_Div      INT, 
   @nExtPUOM_Div   INT
   
   SET @cCHK_SKU = '0'
   SET @cCHK_QTY = '0'
   SET @cPPA_SKU = '0'
   SET @cPPA_QTY = '0'
   SET @cExtendedInfo = ''
   
   -- Get statistic
   EXECUTE rdt.rdt_PostPickAudit_Lottable_GetStat @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, 
      @cRefNo, @cPickSlipNo, @cLoadKey, @cOrderKey, @cDropID, @cSKU,
      @nCQTY = @cCHK_QTY OUTPUT,
      @nPQTY = @cPPA_QTY OUTPUT
      
   SELECT @nExtPUOM_Div=V_Integer1,@nPUOM_Div=V_PUOM_Div 
   FROM rdt.RDTMOBREC WITH (NOLOCK)
   WHERE Mobile = @nMobile
     
   IF @cSKU <> ''  
   BEGIN 
   	IF ISNULL( @nExtPUOM_Div, 0) > 0
         SET @cExtendedInfo = CAST(@cCHK_QTY/@nExtPUOM_Div AS NVARCHAR(3)) + '/'
                           + CAST(@cPPA_QTY/@nExtPUOM_Div AS NVARCHAR(4))
      ELSE
         SET @cExtendedInfo = CAST(@cCHK_QTY/@nPUOM_Div AS NVARCHAR(3)) + '/'
                           + CAST(@cPPA_QTY/@nPUOM_Div AS NVARCHAR(4))

   END  
END

GO