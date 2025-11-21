SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/  
/* Store procedure: rdt_855DecodeSP02                                   */  
/* Purpose: Check if carton id = ucc no                                 */  
/*                                                                      */  
/* Modifications log:                                                   */  
/*                                                                      */  
/* Date       Rev  Author    Purposes                                   */  
/* 2022-03-28 1.0  James       WMS-17439. Created                       */  
/************************************************************************/  
  
CREATE PROC [RDT].[rdt_855DecodeSP02] (  
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
   
   SELECT @cInField01 = I_Field01
   FROM rdt.RDTMOBREC WITH (NOLOCK)
   WHERE Mobile = @nMobile
   
   SELECT TOP 1 
      @cPickSlipNo = PD.PickSlipNo,
      @cLabelNo = PD.LabelNo
   FROM dbo.PackHeader PH WITH (NOLOCK)
   JOIN dbo.PackDetail PD WITH (NOLOCK) ON (PH.PickSlipNo = PD.PickSlipNo)
   WHERE PD.DropID = @cDropID
   AND PH.StorerKey = @cStorerKey
   ORDER BY 1
   
   IF NOT EXISTS ( SELECT 1 FROM dbo.UCC WITH (NOLOCK)
                   WHERE Storerkey = @cStorerKey
                   AND   UCCNo = @cLabelNo)
   BEGIN
   	SET @cSKU = @cInField01
      GOTO Quit
   END
   
   IF @cInField01 = @cLabelNo
   BEGIN
   	SELECT TOP 1 @cSKU = SKU
   	FROM dbo.PackDetail PD WITH (NOLOCK)
   	WHERE PickSlipNo = @cPickSlipNo
   	AND   PD.LabelNo = @cLabelNo
   	ORDER BY 1
   	
   	SELECT @nQTY = ISNULL( SUM( Qty), 0)
   	FROM dbo.UCC WITH (NOLOCK)
      WHERE Storerkey = @cStorerKey
      AND   UCCNo = @cLabelNo
   END
   ELSE
   BEGIN
      SELECT TOP 1 @cSKU = SKU
      FROM dbo.PackHeader PH WITH (NOLOCK)
      JOIN dbo.PackDetail PD WITH (NOLOCK) ON (PH.PickSlipNo = PD.PickSlipNo)
      WHERE PD.DropID = @cDropID
      AND PH.StorerKey = @cStorerKey
      ORDER BY 1
   END
   
Quit:  

END

GO