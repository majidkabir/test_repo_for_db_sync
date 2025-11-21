SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/  
/* Store procedure: rdt_855DecodeSP03                                   */  
/* Purpose: Return casecnt if pickdetail.uom = 2 for the sku scanned    */  
/*                                                                      */  
/* Modifications log:                                                   */  
/*                                                                      */  
/* Date       Rev  Author    Purposes                                   */  
/* 2023-04-28 1.0  James       WMS-22322. Created                       */  
/************************************************************************/  
  
CREATE   PROC [RDT].[rdt_855DecodeSP03] (  
   @nMobile      INT,
   @nFunc        INT,
   @cLangCode    NVARCHAR( 3), 
   @nStep        INT,          
   @nInputKey    INT,          
   @cStorerKey   NVARCHAR( 15),
   @cFacility    NVARCHAR( 5), 
   @cRefNo       NVARCHAR( 10),
   @cPickSlipNo  NVARCHAR( 10),
   @cLoadKey     NVARCHAR( 10),
   @cOrderKey    NVARCHAR( 10),
   @cDropID      NVARCHAR( 20),
   @cID          NVARCHAR( 18),
   @cTaskDetailKey    NVARCHAR( 10) = '',    											  
   @cBarcode     NVARCHAR( 60),
   @cSKU         NVARCHAR( 20) OUTPUT,
   @nQTY         INT           OUTPUT,
   @nErrNo       INT           OUTPUT,
   @cErrMsg      NVARCHAR( 20) OUTPUT 
)  
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @cLabelNo    NVARCHAR( 20)
   DECLARE @cInField01  NVARCHAR( 60)
   DECLARE @bSuccess    INT
   DECLARE @cCaseCnt    NVARCHAR( 10)
   DECLARE @nPickQty    INT = 0
   DECLARE @nPPAQty     INT = 0
   
   SELECT @cInField01 = I_Field01
   FROM rdt.RDTMOBREC WITH (NOLOCK)
   WHERE Mobile = @nMobile

   -- Get SKU
   EXEC rdt.rdt_GetSKU
       @cStorerKey  = @cStorerKey
      ,@cSKU        = @cBarcode  OUTPUT
      ,@bSuccess    = @bSuccess  OUTPUT
      ,@nErr        = @nErrNo    OUTPUT
      ,@cErrMsg     = @cErrMsg   OUTPUT
   
   IF @bSuccess = 0
      GOTO Quit
    
    SET @cSKU = @cBarcode
    SET @nQTY = 1

   SELECT TOP 1 @cLabelNo = LabelNo
   FROM dbo.PackDetail WITH (NOLOCK)
   WHERE StorerKey = @cStorerKey
   AND   DropID = @cDropID
   ORDER BY 1
   
   IF EXISTS ( SELECT 1 
                FROM dbo.PICKDETAIL WITH (NOLOCK)
                WHERE Storerkey = @cStorerKey
                AND   CaseID = @cLabelNo
                AND   Sku = @cSKU
                AND   UOM = 2)
   BEGIN
      SELECT @nPickQty = ISNULL( SUM( Qty), 0)
      FROM dbo.PICKDETAIL WITH (NOLOCK)
      WHERE Storerkey = @cStorerKey
      AND   CaseID= @cLabelNo
      AND   Sku = @cSKU
      AND   UOM = 2
      AND   [STATUS] <> '4'
      
      SELECT @nPPAQty = ISNULL( SUM( CQty), 0)
      FROM rdt.RDTPPA WITH (NOLOCK)
      WHERE Storerkey = @cStorerKey
      AND   DropID = @cDropID
      AND   SKU = @cSKU
      
      IF @nPPAQty < @nPickQty
      BEGIN
         SELECT @cCaseCnt = PACK.CaseCnt
         FROM dbo.PACK PACK WITH (NOLOCK)
         JOIN dbo.SKU SKU WITH (NOLOCK) ON ( PACK.PackKey = SKU.PACKKey)
         WHERE SKU.StorerKey = @cStorerKey
         AND   SKU.Sku = @cSKU 
      
         SET @nQTY = CAST( @cCaseCnt AS INT)
      END
      ELSE
      	SET @nQTY = 1
   END
   
Quit:  

END

GO