SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_1638ExtVal06                                    */
/* Copyright: LFLogistics                                               */
/*                                                                      */
/* Date        Rev  Author    Purposes                                  */
/* 06-01-2020  1.0  Chermaine WMS-11669 Created                         */
/************************************************************************/

CREATE PROC [RDT].[rdt_1638ExtVal06] (
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
               
               SET @cPickSlipNo = ''
               SET @cOrderKey = ''
                             
               -- Get case info
               SELECT @cPickSlipNo = PickSlipNo FROM PackDetail WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND LabelNo = @cCaseID
               SELECT @cOrderKey = OrderKey FROM PackHeader WITH (NOLOCK) WHERE PickSlipNo = @cPickSlipNo
               
               SELECT 
                  @cDischargePlace = DischargePlace,
                  @cType = Type,
                  @cRoutingTool = RoutingTool
               FROM Orders WITH (NOLOCK) 
               WHERE OrderKey = @cOrderKey
               
               SELECT DISTINCT 
                  @cPalletDischargePlace = o.DischargePlace,
                  @cPalletType = o.TYPE,
                  @cPalletRoutingTool = o.RoutingTool
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
                  
               IF  (@cDischargePlace <> @cPalletDischargePlace)
               BEGIN
               	SET @nErrNo = 147401
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --mix Dest.
               END
               
               IF  (@cType <> @cPalletType)
               BEGIN
               	SET @nErrNo = 147402
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --mixOrderType
               END
               
               IF  (@cRoutingTool <> @cPalletRoutingTool)
               BEGIN
               	SET @nErrNo = 147403
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --mixRoutTool
               END
            END
         END
      END
   END
END

SET QUOTED_IDENTIFIER OFF

GO