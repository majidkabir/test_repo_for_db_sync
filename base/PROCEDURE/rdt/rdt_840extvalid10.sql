SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_840ExtValid10                                   */
/* Purpose: Check for sostatus = PENDCANC.                              */
/*          If yes update order.status = 3. Prompt error screen and     */
/*          stop processing. Backend job will auto unallocate orders    */
/*                                                                      */
/* Called By: RDT Pack By Track No                                      */ 
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date       Rev  Author     Purposes                                  */
/* 2021-01-28 1.0  James      WMS-16145. Created                        */
/* 2021-02-01 1.1  James      WMS-16272 Add prompt on SUSR3 (james01)   */
/* 2021-04-01 1.2  YeeKung    WMS-16717 Add serialno and serialqty      */
/*                            Params (yeekung01)                        */
/************************************************************************/

CREATE PROC [RDT].[rdt_840ExtValid10] (
   @nMobile                   INT,
   @nFunc                     INT,
   @cLangCode                 NVARCHAR( 3),
   @nStep                     INT,
   @nInputKey                 INT, 
   @cStorerkey                NVARCHAR( 15),
   @cOrderKey                 NVARCHAR( 10),
   @cPickSlipNo               NVARCHAR( 10),
   @cTrackNo                  NVARCHAR( 20),
   @cSKU                      NVARCHAR( 20),
   @nCartonNo                 INT,
   @cCtnType                  NVARCHAR( 10),
   @cCtnWeight                NVARCHAR( 10),
   @cSerialNo                 NVARCHAR( 30), 
   @nSerialQTY                INT,   
   @nErrNo                    INT           OUTPUT,
   @cErrMsg                   NVARCHAR( 20) OUTPUT 
)
AS

   SET NOCOUNT ON  
   SET ANSI_NULLS OFF  
   SET QUOTED_IDENTIFIER OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  

   DECLARE @cSOStatus            NVARCHAR( 10),
           @nTranCount           INT,
           @cErrMsg01            NVARCHAR( 20),
           @cUPC                 NVARCHAR( 30),
           @cPackedLottable02    NVARCHAR( 18),
           @cLottable02          NVARCHAR( 18),
           @cLabelNo             NVARCHAR( 40),
           @cSUSR3               NVARCHAR( 18) = ''


   SET @nErrNo = 0

   -- We do update orders.status here because
   -- extendedupdatesp is located after generate pickslipno and scan in

   SET @nTranCount = @@TRANCOUNT
   BEGIN TRAN
   SAVE TRAN rdt_840ExtValid10
   
   IF @nStep = 1
   BEGIN
      IF @nInputKey = 1
      BEGIN
         SELECT @cSOStatus = SOStatus
         FROM dbo.ORDERS AS o WITH (NOLOCK)
         WHERE o.OrderKey = @cOrderKey
         
         IF @cSOStatus = 'PENDCANC'
         BEGIN
         	UPDATE dbo.ORDERDETAIL WITH (ROWLOCK) SET
         	   [Status] = '3',
               EditWho = sUser_sName(),
               EditDate = GetDate(),
               TrafficCop = NULL
         	WHERE OrderKey = @cOrderKey
            AND  [Status] < '3'
         	
         	IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 162651
               SET @cErrMsg = rdt.rdtgetmessage(@nErrNo, @cLangCode,'DSP') --Upd OdDtl Fail
               GOTO RollBackTran  
            END

            UPDATE dbo.ORDERS WITH (ROWLOCK) SET 
               STATUS = '3',
               EditWho = sUser_sName(),
               EditDate = GetDate(),
               TrafficCop = NULL
            WHERE OrderKey = @cOrderKey
            AND  [Status] < '3'

            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 162652
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Upd OdHdr Fail'
               GOTO RollBackTran
            END

            SET @cErrMsg01 = ''  
            SET @cErrMsg01 = rdt.rdtgetmessage( 162653, @cLangCode, 'DSP')  -- Order cancel
            SET @nErrNo = 0  
            EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, @cErrMsg01  
            SET @nErrNo = 162653              
            GOTO Quit
         END
         
         SELECT @cSUSR3 = SKU.SUSR3
         FROM dbo.ORDERDETAIL OD WITH (NOLOCK) 
         JOIN dbo.SKU SKU WITH (NOLOCK) ON ( OD.StorerKey = SKU.StorerKey AND OD.Sku = SKU.Sku)
         WHERE OD.OrderKey = @cOrderKey
         AND   OD.StorerKey = @cStorerkey
         AND   SKU.SUSR3 IN ('1', '3')

         IF @cSUSR3 = '1'
         BEGIN
            SET @cErrMsg01 = ''
            SET @cErrMsg01 = rdt.rdtgetmessage( 162656, @cLangCode, 'DSP') -- PLS USE BOX

            EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, @cErrMsg01
            SET @nErrNo = 0   -- Prompt alert message and continue
            GOTO Quit
         END

        IF @cSUSR3 = '3'
         BEGIN
            SET @cErrMsg01 = ''
            SET @cErrMsg01 = rdt.rdtgetmessage( 162657, @cLangCode, 'DSP') -- PLS USE GWP

            EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, @cErrMsg01
            SET @nErrNo = 0   -- Prompt alert message and continue
            GOTO Quit
         END
      END
   END

   IF @nStep = 3
   BEGIN
      IF @nInputKey = 1
      BEGIN
         SELECT @cSOStatus = SOStatus
         FROM dbo.ORDERS AS o WITH (NOLOCK)
         WHERE o.OrderKey = @cOrderKey
         
         IF @cSOStatus = 'PENDCANC'
         BEGIN
            SET @cErrMsg01 = ''
            SET @cErrMsg01 = rdt.rdtgetmessage( 145704, @cLangCode, 'DSP')

            SET @nErrNo = 0
            EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, @cErrMsg01
            SET @nErrNo = 162654
            GOTO RollBackTran
         END

         IF EXISTS (SELECT 1 FROM dbo.Orders WITH (NOLOCK)
                     WHERE Orderkey = @cOrderkey
                     AND   UserDefine03 = 'MOVE')
         BEGIN
            -- If nothing packed then no need further check
            IF EXISTS ( SELECT 1 FROM dbo.PackDetail WITH (NOLOCK) 
                        WHERE PickSlipNo = @cPickSlipNo
                        AND   CartonNo = @nCartonNo
                        GROUP BY PickSlipNo HAVING SUM( Qty) > 0)
            BEGIN
               SELECT TOP 1 @cUPC = UPC   -- every barcode user scanned stored in upc
               FROM dbo.PackDetail WITH (NOLOCK)
               WHERE PickSlipNo = @cPickSlipNo
               AND   CartonNo = @nCartonNo
               ORDER BY 1

               SET @cPackedLottable02 = SUBSTRING( RTRIM( @cUPC), 16, 12) -- Lottable02    
               SET @cPackedLottable02 = RTRIM( @cPackedLottable02) + '-' -- Lottable02    
               SET @cPackedLottable02 = RTRIM( @cPackedLottable02) + SUBSTRING( RTRIM( @cUPC), 28, 2) -- Lottable02    

               SELECT @cLabelNo = I_Field06
               FROM rdt.RDTMOBREC WITH (NOLOCK)
               WHERE Mobile = @nMobile
   
               SET @cLottable02 = SUBSTRING( RTRIM( @cLabelNo), 16, 12) -- Lottable02    
               SET @cLottable02 = RTRIM( @cLottable02) + '-' -- Lottable02    
               SET @cLottable02 = RTRIM( @cLottable02) + SUBSTRING( RTRIM( @cLabelNo), 28, 2) -- Lottable02    
               
               IF @cPackedLottable02 <> @cLottable02
               BEGIN
                  SET @nErrNo = 162655
                  SET @cErrMsg = rdt.rdtgetmessage(@nErrNo, @cLangCode,'DSP') --Invalid Lot02
                  GOTO RollBackTran  
               END
            END
         END
      END   
   END
   
   GOTO Quit

   RollBackTran:
      ROLLBACK TRAN rdt_840ExtValid10

   Quit:
      WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
         COMMIT TRAN rdt_840ExtValid10

   Fail:
   
   
SET QUOTED_IDENTIFIER OFF

GO