SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_840ExtUpd09                                     */
/* Purpose: 1 Orders 1 carton. When pick=pack then insert packinfo      */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date       Rev  Author     Purposes                                  */
/* 2021-02-05 1.0  James      WMS-16306 - Created                       */
/* 2021-04-01 1.1  YeeKung    WMS-16717 Add serialno and serialqty      */
/*                            Params (yeekung01)                        */
/************************************************************************/

CREATE PROC [RDT].[rdt_840ExtUpd09] (
   @nMobile     INT,
   @nFunc       INT, 
   @cLangCode   NVARCHAR( 3), 
   @nStep       INT, 
   @nInputKey   INT, 
   @cStorerkey  NVARCHAR( 15), 
   @cOrderKey   NVARCHAR( 10), 
   @cPickSlipNo NVARCHAR( 10), 
   @cTrackNo    NVARCHAR( 20), 
   @cSKU        NVARCHAR( 20), 
   @nCartonNo   INT,
   @cSerialNo   NVARCHAR( 30), 
   @nSerialQTY  INT,   
   @nErrNo      INT           OUTPUT, 
   @cErrMsg     NVARCHAR( 20) OUTPUT
)
AS
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF


  DECLARE @nExpectedQty INT = 0
  DECLARE @nPackedQty   INT = 0
  
   IF @nInputKey = 1
   BEGIN
      IF @nStep = 4
      BEGIN
         SELECT @nExpectedQty = ISNULL(SUM(Qty), 0) FROM PickDetail WITH (NOLOCK)
         WHERE Orderkey = @cOrderkey
            AND Storerkey = @cStorerkey
            AND Status < '9'

         SELECT @nPackedQty = ISNULL(SUM(Qty), 0) FROM dbo.PackDetail WITH (NOLOCK)
         WHERE PickSlipNo = @cPickSlipNo
      
         IF @nExpectedQty = @nPackedQty
         BEGIN
            -- 1 orders 1 carton
            IF EXISTS ( SELECT 1 FROM dbo.PackInfo WITH (NOLOCK)
                        WHERE PickSlipNo = @cPickSlipNo)
            BEGIN
               UPDATE dbo.PackInfo SET 
                  Qty = @nPackedQty
               WHERE PickSlipNo = @cPickSlipNo
               AND   CartonNo = @nCartonNo   -- To use with table index
               
               IF @@ERROR <> 0
               BEGIN
                  SET @nErrNo = 163301  
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')  --Upd PackInfo Err 
                  GOTO Quit
               END
            END
         END
      END
   END

   Quit:  

GO