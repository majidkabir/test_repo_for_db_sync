SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_1638ExtVal11                                    */
/* Copyright: LFLogistics                                               */
/*                                                                      */
/* Date        Rev  Author    Purposes                                  */
/* 2020-12-09  1.0  James     WMS-15829 Created                         */
/************************************************************************/

CREATE PROC [RDT].[rdt_1638ExtVal11] (
   @nMobile      INT,           
   @nFunc        INT,           
   @nStep        INT,
   @nInputKey    INT,           
   @cLangCode    NVARCHAR( 3),  
   @cFacility    NVARCHAR( 5),  
   @cStorerkey   NVARCHAR( 15), 
   @cPalletKey   NVARCHAR( 30), 
   @cCartonType  NVARCHAR( 10), 
   @cCaseID      NVARCHAR( 20), 
   @cLOC         NVARCHAR( 10), 
   @cSKU         NVARCHAR( 20), 
   @nQTY         INT,            
   @cLength      NVARCHAR(5),    
   @cWidth       NVARCHAR(5),    
   @cHeight      NVARCHAR(5),    
   @cGrossWeight NVARCHAR(5),    
   @nErrNo       INT           OUTPUT,
   @cErrMsg      NVARCHAR( 20) OUTPUT 
) AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   IF @nFunc = 1638 -- Scan to pallet
   BEGIN
      IF @nStep = 3 -- CaseID
      BEGIN
         IF @nInputKey = 1 -- ENTER
         BEGIN
            IF @cPalletKey <> ''
            BEGIN
               DECLARE @cPickSlipNo       NVARCHAR(10)
               DECLARE @cOrderKey         NVARCHAR(10)
             
               DECLARE @cPalletDischargePlace   NVARCHAR(30)
               DECLARE @cPalletType             NVARCHAR(10)
               DECLARE @cPalletRoutingTool      NVARCHAR(30)
               DECLARE @cDischargePlace         NVARCHAR(30)
               DECLARE @cType                   NVARCHAR(10)
               DECLARE @cRoutingTool            NVARCHAR(30)
               DECLARE @cUserDefine10           NVARCHAR(10)
               DECLARE @cPalletUserDefine10     NVARCHAR(10)
               DECLARE @cLottable01             NVARCHAR(18)
               DECLARE @cPalletLottable01       NVARCHAR(18)
               DECLARE @cPalletOrderKey         NVARCHAR(10)
               
               IF EXISTS(SELECT 1 FROM PALLETDETAIL WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND PalletKey = @cPalletKey)
			      BEGIN

                  SET @cPickSlipNo = ''
                  SET @cOrderKey = ''
                             
                  -- Get case info
                  SELECT @cPickSlipNo = PickSlipNo FROM PackDetail WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND LabelNo = @cCaseID
                  SELECT @cOrderKey = OrderKey FROM PackHeader WITH (NOLOCK) WHERE PickSlipNo = @cPickSlipNo
               
                  SELECT 
                     @cDischargePlace = DischargePlace,
                     @cType = Type,
                     @cRoutingTool = RoutingTool,
                     @cUserDefine10 = UserDefine10
                  FROM Orders WITH (NOLOCK) 
                  WHERE OrderKey = @cOrderKey
               
                  SELECT TOP 1 @cLottable01 = Lottable01
                  FROM dbo.ORDERDETAIL WITH (NOLOCK)
                  WHERE OrderKey = @cOrderKey
                  ORDER BY 1 DESC

                  SELECT DISTINCT 
                     @cPalletDischargePlace = o.DischargePlace,
                     @cPalletType = o.TYPE,
                     @cPalletRoutingTool = o.RoutingTool,
                     @cPalletUserDefine10 = o.UserDefine10,
                     @cPalletOrderKey = o.OrderKey
                  FROM PalletDetail pa WITH (NOLOCK)
                  JOIN PackDetail pd WITH (NOLOCK)
                  ON pd.StorerKey = pa.storerKey
                     AND pd.LabelNo = pa.CaseId
                  JOIN PackHeader ph WITH (NOLOCK)
                  ON pd.StorerKey = ph.StorerKey
                     AND pd.PickSlipNo = ph.PickSlipNo
                  JOIN Orders o WITH (NOLOCK)
                  ON ph.StorerKey = o.StorerKey
                     AND ph.OrderKey = o.OrderKey
                  WHERE pa.palletKey = @cPalletKey
                     AND pa.storerkey = @cStorerKey

                  SELECT TOP 1 @cPalletLottable01 = Lottable01
                  FROM dbo.ORDERDETAIL WITH (NOLOCK)
                  WHERE OrderKey = @cPalletOrderKey
                  ORDER BY 1 DESC

                  IF  (@cDischargePlace <> @cPalletDischargePlace)
                  BEGIN
               	   SET @nErrNo = 161201
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --Mix Dest.
                     GOTO Quit
                  END
               
                  IF  (@cType <> @cPalletType)
                  BEGIN
               	   SET @nErrNo = 161202
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --Mix Order Type
                     GOTO Quit
                  END
               
                  IF  (@cRoutingTool <> @cPalletRoutingTool)
                  BEGIN
               	   SET @nErrNo = 161203
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --Mix Route Tool
                     GOTO Quit
                  END
               
                  IF (@cUserDefine10 <> @cPalletUserDefine10) --mix userdefine10
                  BEGIN
               	   SET @nErrNo = 161204
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --Mix Ord UDF10
                     GOTO Quit
                  END
               
                  IF (@cLottable01 <> @cPalletLottable01) --mix lot01
                  BEGIN
               	   SET @nErrNo = 161205
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --Mix Ord LOT01
                     GOTO Quit
                  END
               END
            END
         END
      END
   END
END

Quit:

SET QUOTED_IDENTIFIER OFF

GO