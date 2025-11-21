SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
    
/************************************************************************/    
/* Store procedure: rdt_877ExtVal02                                     */    
/* Copyright: LF Logistics                                              */    
/*                                                                      */    
/* Date       Rev  Author   Purposes                                    */    
/* 2018-10-26 1.0  Ung      WMS-6576 Created                            */    
/************************************************************************/    
    
CREATE PROCEDURE [RDT].[rdt_877ExtVal02] (    
   @nMobile      INT,           
   @nFunc        INT,           
   @cLangCode    NVARCHAR( 3),  
   @nStep        INT,           
   @nInputKey    INT,           
   @cFacility    NVARCHAR( 5),  
   @cStorerKey   NVARCHAR( 15), 
   @cPickSlipNo  NVARCHAR( 10), 
   @cOrderKey    NVARCHAR( 10), 
   @cBarcode     NVARCHAR( MAX),
   @cSKU         NVARCHAR( 18), 
   @cBatchNo     NVARCHAR( 18), 
   @cCaseID      NVARCHAR( 20), 
   @nErrNo       INT            OUTPUT, 
   @cErrMsg      NVARCHAR( 20)  OUTPUT
) AS    
    
   SET NOCOUNT ON    
   SET QUOTED_IDENTIFIER OFF    
   SET ANSI_NULLS OFF    
   SET CONCAT_NULL_YIELDS_NULL OFF    

   IF @nFunc = 877 -- Capture case ID
   BEGIN
      IF @nStep = 1 -- PickSlipNo
      BEGIN
         IF @nInputKey = 1 -- ENTER
         BEGIN
            -- Get PickDetail info
            DECLARE @cDropID NVARCHAR(20)
            SELECT TOP 1 
               @cDropID = PD.DropID 
            FROM PickDetail PD WITH (NOLOCK) 
               JOIN SKU WITH (NOLOCK) ON (SKU.StorerKey = PD.StorerKey AND SKU.SKU = PD.SKU)
            WHERE PD.OrderKey = @cOrderKey 
               AND PD.Status <> '4' -- 4=Short
               AND PD.QTY > 0
               AND NOT EXISTS (SELECT 1 FROM CodeLkup WITH (NOLOCK) WHERE ListName = 'MHCSSCAN' AND Code = SKU.Class AND StorerKey = @cStorerKey) -- Brand don't need capture case ID
            ORDER BY DropID

            DECLARE @cScanOut NVARCHAR(1)
            SET @cScanOut = 'N'

            -- Check PickSlip need capture
            IF @cDropID IS NULL
            BEGIN
               SET @nErrNo = 130751
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') -- No NeedCapture
               SET @cScanOut = 'Y'
            END
            
            -- Check PickSlip finish capture
            ELSE IF @cDropID <> ''
            BEGIN
               SET @nErrNo = 130752
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') -- Finish Capture
               SET @cScanOut = 'Y'
            END


            -- Check short pick
            IF @cScanOut = 'Y'
               IF EXISTS( SELECT TOP 1 1 FROM PickDetail WITH (NOLOCK) WHERE OrderKey = @cOrderKey AND Status = '4' AND QTY > 0) 
                  SET @cScanOut = 'N'
            
            -- Auto scan-out
            IF @cScanOut = 'Y'
            BEGIN
               IF EXISTS( SELECT 1 FROM dbo.PickingInfo WITH (NOLOCK) WHERE PickSlipNo = @cPickSlipNo AND ScanOutDate IS NULL)
               BEGIN
                  UPDATE PickingInfo SET 
                     ScanOutDate = GETDATE(), 
                     PickerID = SUSER_SNAME()
                  WHERE PickSlipNo = @cPickSlipNo
                  IF @@ERROR <> 0
                  BEGIN
                     SET @nErrNo = 130753
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') -- PS ScanOutFail
                     GOTO Quit
                  END
               END
            END
         END
      END
   END
      
Quit: 


GO