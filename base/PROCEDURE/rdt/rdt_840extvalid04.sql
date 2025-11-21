SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


/************************************************************************/
/* Store procedure: rdt_840ExtValid04                                   */
/* Purpose: Check for sostatus = PENDCANC.                              */
/*          If yes update order.status = 3. Prompt error screen and     */
/*          stop processing. Backend job will auto unallocate orders    */
/*                                                                      */
/* Called By: RDT Pack By Track No                                      */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date       Rev  Author     Purposes                                  */
/* 2019-10-30 1.0  James      WMS-10896 Created                         */
/* 2020-07-07 1.1  Chermaine  WMS-13998 errMsg display in same screen (cc01) */
/* 2020-10-01 1.2  James      WMS-15372 Display error msgqueue (james01)*/
/* 2021-01-27 1.3  James      WMS-16145 Add move orders checking        */
/*                            Not allow mix lot02 in 1 carton (james02) */
/* 2021-04-01 1.4  YeeKung    WMS-16717 Add serialno and serialqty      */
/*                            Params (yeekung01)                        */
/* 2022-01-11 1.5  James      WMS-21501 Add short pick check (james03)  */
/************************************************************************/

CREATE   PROC [RDT].[rdt_840ExtValid04] (
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
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF

   DECLARE @cSOStatus            NVARCHAR( 10),
           @nTranCount           INT,
           @cErrMsg01            NVARCHAR( 20),
           @cUPC                 NVARCHAR( 30),
           @cPackedLottable02    NVARCHAR( 18),
           @cLottable02          NVARCHAR( 18),
           @cLabelNo             NVARCHAR(40),
           @nOriginalQty         INT = 0,
           @nPD_Qty              INT = 0
           
   SET @nErrNo = 0

   -- We do update orders.status here because
   -- extendedupdatesp is located after generate pickslipno and scan in

   SET @nTranCount = @@TRANCOUNT
   BEGIN TRAN
   SAVE TRAN rdt_840ExtValid04

   IF @nStep = 1
   BEGIN
      IF @nInputKey = 1
      BEGIN
      	-- Check for short pick, only for certain orders (james03)
      	IF EXISTS ( SELECT 1 FROM dbo.CODELKUP C WITH (NOLOCK)
      	            JOIN dbo.ORDERS O WITH (NOLOCK) ON ( C.Storerkey = O.StorerKey AND C.Code = O.BuyerPO)
      	            WHERE C.LISTNAME = 'ADPLTFCHK'
      	            AND   O.StorerKey = @cStorerkey
      	            AND   O.OrderKey = @cOrderKey)
         BEGIN
         	SELECT @nOriginalQty = ISNULL( SUM( OriginalQty), 0)
         	FROM dbo.ORDERDETAIL WITH (NOLOCK)
         	WHERE OrderKey = @cOrderKey
         	
         	SELECT @nPD_Qty = ISNULL( SUM( Qty), 0)
         	FROM dbo.PICKDETAIL WITH (NOLOCK)
         	WHERE OrderKey = @cOrderKey
         	AND  [STATUS] = '3'
         	
         	IF @nOriginalQty <> @nPD_Qty
            BEGIN
               SET @nErrNo = 145706
               SET @cErrMsg = rdt.rdtgetmessage(@nErrNo, @cLangCode,'DSP') --Pack Not Allow
               GOTO RollBackTran
            END
         END
         
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
               SET @nErrNo = 145701
               SET @cErrMsg = rdt.rdtgetmessage(@nErrNo, @cLangCode,'DSP') --Assign Loc Err
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
               SET @nErrNo = 145702
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Upd OdHdr Fail'
               GOTO RollBackTran
            END

            SET @cErrMsg01 = ''
            SET @cErrMsg01 = rdt.rdtgetmessage( 145703, @cLangCode, 'DSP')

            SET @nErrNo = 0
            EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, @cErrMsg01
            SET @nErrNo = 145703
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
            SET @nErrNo = 145704
            GOTO RollBackTran
         END

         -- Only check if it is move orders (james01)
         IF EXISTS (SELECT 1 FROM dbo.Orders O WITH (NOLOCK)
                    INNER JOIN dbo.CodeLkup CL WITH (NOLOCK) ON CL.CODE = O.[Type]
                        WHERE O.Orderkey = @cOrderkey
                        AND O.Storerkey = @cStorerkey
                        AND CL.Listname = 'HMORDTYPE'
                        AND CL.UDF01 = 'M')
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
                  SET @nErrNo = 145705
                  SET @cErrMsg = rdt.rdtgetmessage(@nErrNo, @cLangCode,'DSP') --Invalid Lot02
                  GOTO RollBackTran
               END
            END
         END
      END
   END

   GOTO Quit

   RollBackTran:
      ROLLBACK TRAN rdt_840ExtValid04

   Quit:
      WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
         COMMIT TRAN rdt_840ExtValid04

   Fail:


SET QUOTED_IDENTIFIER OFF

GO