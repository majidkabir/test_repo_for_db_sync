SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_840ExtValid01                                   */
/* Purpose: Validate the orders if it is allow for letter service.      */
/*          Get new tracking no, update to orders.userdefine04 and      */
/*          Release prev tracking no                                    */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date       Rev  Author     Purposes                                  */
/* 2014-02-28 1.0  James      SOS301646 Created                         */
/* 2019-03-15 1.1  James      WMS8270-Add Myntra checking (james01)     */
/* 2019-11-20 1.2  James      WMS-11171 Display all error msg           */
/*                            in msgqueue (james02)                     */
/* 2019-11-20 1.3  James      WMS-11161 If orders already have tracking */
/*                            no cannot repack (james03)                */
/* 2021-03-17 1.4  James      WMS-16580 Add checking on certain orders  */
/*                            cannot split carton when packing (james04)*/
/* 2021-04-16 1.5  James      WMS-16024 Standarized use of TrackingNo   */
/*                            (james05)                                 */
/* 2021-04-01 1.6  YeeKung    WMS-16717 Add serialno and serialqty      */
/*                            Params (yeekung01)                        */
/* 2021-09-09 1.7  James      Add configkey to check orders can proceed */
/*                            packing only with blank orderkey (james06)*/
/* 2022-04-01 1.3  LZG        JSM-60456 - Temp clone Move order checking*/
/*                            from rdt_840ExtValid06                    */
/************************************************************************/

CREATE PROC [RDT].[rdt_840ExtValid01] (
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

   DECLARE @cType                NVARCHAR( 10),
           @cRDS                 NVARCHAR( 1),
           @cShipperkey          NVARCHAR( 15),
           @cCarrierName         NVARCHAR( 30),
           @cKeyName             NVARCHAR( 30),
           @cTrackingNo_Letter   NVARCHAR( 20),
           @cOrd_TrackingNo      NVARCHAR( 20),
           @cPickDetailKey       NVARCHAR( 10),
           @cLabelLine           NVARCHAR( 5),
           @nCount               INT,
           @nTranCount           INT,
           @nTtl_OrdQty          INT,
           @nTtl_PckQty          INT,
           @cLabelNo             NVARCHAR( 20),   
           @cLot                 NVARCHAR( 10),   
           @cLottable12          NVARCHAR( 30),   
           @cPackSKU             NVARCHAR( 20),   
           @cBarcode             NVARCHAR( 60),   
           @cLottable02          NVARCHAR( 18),   
           @cUPC                 NVARCHAR( 30),   
           @nIsMoveOrder         INT  

   DECLARE @cErrMsg1       NVARCHAR( 20),
           @cErrMsg2       NVARCHAR( 20),
           @cErrMsg3       NVARCHAR( 20),
           @cErrMsg4       NVARCHAR( 20),
           @cErrMsg5       NVARCHAR( 20)

   DECLARE @nMsgQErrNo     INT
   DECLARE @nMsgQErrMsg    NVARCHAR( 20)

   SET @nErrNo = 0

   IF @nStep = 1
   BEGIN
      IF @nInputKey = 1
      BEGIN
         IF EXISTS ( SELECT 1 FROM dbo.ORDERS WITH (NOLOCK)
                     WHERE OrderKey = @cOrderKey
                     AND   StorerKey = @cStorerkey
                     AND   SOStatus = 'TBCANC'
                     AND   M_STATE like 'MYN%')
         BEGIN
            SET @nErrNo = 0
            SET @cErrMsg1 = SUBSTRING( rdt.rdtgetmessage( 57512, @cLangCode, 'DSP'), 7, 14) --ORDER CANCEL,
            SET @cErrMsg2 = SUBSTRING( rdt.rdtgetmessage( 57513, @cLangCode, 'DSP'), 7, 14) --HOSPITAL
            EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, @cErrMsg1, @cErrMsg2
            IF @nErrNo = 1
            BEGIN
               SET @cErrMsg1 = ''
               SET @cErrMsg2 = ''
            END
            SET @nErrNo = 57512
            GOTO Fail
         END

         -- (james06)
         IF rdt.RDTGetConfig( @nFunc, 'OrdersWithNoTrackingNoReq', @cStorerKey) = '1'
         BEGIN
            IF EXISTS ( SELECT 1 FROM dbo.ORDERS AS o WITH (NOLOCK)
                        WHERE o.OrderKey = @cOrderKey
                        AND   ISNULL( o.TrackingNo, '') <> '')
            BEGIN
               SET @nErrNo = 0
               SET @cErrMsg1 = rdt.rdtgetmessage( 57514, @cLangCode, 'DSP')   -- ORDER HAS TRACKING #
               SET @cErrMsg2 = rdt.rdtgetmessage( 57515, @cLangCode, 'DSP')   -- CANNOT PROCEED
               EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, @cErrMsg1, @cErrMsg2
               IF @nErrNo = 1
               BEGIN
                  SET @cErrMsg1 = ''
                  SET @cErrMsg2 = ''
               END
               SET @nErrNo = 57514
               GOTO Fail
            END
         END

         IF EXISTS ( SELECT 1 FROM dbo.ORDERS AS o WITH (NOLOCK)
                     WHERE o.OrderKey = @cOrderKey
                     AND   ISNULL( o.SOStatus, '0') <> '0')
         BEGIN
            SET @nErrNo = 0
            SET @cErrMsg1 = rdt.rdtgetmessage( 57516, @cLangCode, 'DSP')   -- INVALID SOSTATUS
            SET @cErrMsg2 = rdt.rdtgetmessage( 57517, @cLangCode, 'DSP')   -- CANNOT PROCEED
            EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, @cErrMsg1, @cErrMsg2
            IF @nErrNo = 1
            BEGIN
               SET @cErrMsg1 = ''
               SET @cErrMsg2 = ''
            END
            SET @nErrNo = 57516
            GOTO Fail
         END
      END
   END

   -- (james04)
   IF @nStep = 3
   BEGIN
      IF @nInputKey = 1
      BEGIN
         -- JSM-60456 (START)
         /*IF EXISTS ( SELECT 1 FROM dbo.orders WITH (NOLOCK)
                     WHERE OrderKey = @cOrderKey
                     AND   [Type] <> 'R')
         BEGIN
            IF @nCartonNo > 1
            BEGIN
               SET @nErrNo = 57518  -- > Only 1 carton
               GOTO Fail
            END
         END*/

         IF EXISTS ( SELECT 1 FROM dbo.CODELKUP C WITH (NOLOCK)
                  JOIN dbo.Orders O WITH (NOLOCK) ON (C.Code = O.Type AND C.StorerKey = O.StorerKey)
                  WHERE C.ListName = 'HMORDTYPE'
                  AND   C.UDF01 = 'M'
                  AND   O.OrderKey = @cOrderkey
                  AND   O.StorerKey = @cStorerKey)
            SET @nIsMoveOrder = 1
         ELSE
            SET @nIsMoveOrder = 0

         -- Move order only check
         IF @nIsMoveOrder = 0
            GOTO Quit

         -- (james01)
         SELECT TOP 1 @cLabelNo = LabelNo,
                   @cPackSKU = SKU,
                   @cUPC = UPC
         FROM dbo.PackDetail WITH (NOLOCK)
         WHERE PickSlipNo = @cPickSlipNo
         AND   CartonNo = @nCartonNo
         ORDER BY 1

         -- Not yet pack anything for this carton
         -- then no need further check
         IF @@ROWCOUNT = 0
            GOTO Quit

         SET @cLottable02 = SUBSTRING( RTRIM( @cUPC), 16, 12)
         SET @cLottable02 = RTRIM( @cLottable02) + '-'
         SET @cLottable02 = RTRIM( @cLottable02) + SUBSTRING( RTRIM( @cUPC), 28, 2)

         SELECT TOP 1 @cLottable12 = LA.Lottable12
         FROM dbo.PICKDETAIL PD WITH (NOLOCK)
         JOIN dbo.LOTATTRIBUTE LA WITH (NOLOCK) ON (PD.Lot = LA.Lot)
         WHERE PD.StorerKey = @cStorerkey
         AND   PD.OrderKey = @cOrderKey
         AND   PD.SKU = @cPackSKU
         AND   LA.Lottable02 = @cLottable02
         ORDER BY 1

         SELECT @cBarcode = I_Field06
         FROM rdt.RDTMOBREC WITH (NOLOCK)
         WHERE Mobile = @nMobile

         IF SUBSTRING( @cBarcode, 22, 6 ) <> @cLottable12
         BEGIN
            SET @nErrNo = 146052  -- HMORD# X MATCH
           GOTO Quit
         END
         -- JSM-60456 (END)
      END
   END

   IF @nStep = 4
   BEGIN
      IF @nInputKey = 1
      BEGIN
         SELECT @cType = [Type],
                @cRDS = RDS,
                @cShipperkey = Shipperkey,
                --@cOrd_TrackingNo = UserDefine04
                @cOrd_TrackingNo = TrackingNo   -- (james05)
         FROM dbo.Orders WITH (NOLOCK)
         WHERE OrderKey = @cOrderkey
         AND   StorerKey = @cStorerKey

         -- If not letter service then skip validate
         IF NOT EXISTS ( SELECT 1
                         FROM dbo.CODELKUP WITH (NOLOCK)
                         WHERE ListName = 'HMCARTON'
                         AND   StorerKey = @cStorerKey
                         AND   Short = @cCtnType
                         --AND   UDF01 = @cShipperkey
                         AND   UDF02 = 'LETTER')
         BEGIN
            GOTO Fail
         END

         -- S = Customer order
         -- M = Move order (NOT ALLOW)
         IF EXISTS ( SELECT 1
                     FROM dbo.CODELKUP C WITH (NOLOCK)
                     JOIN dbo.Orders O WITH (NOLOCK) ON (C.Code = O.Type AND C.StorerKey = O.StorerKey)
                     WHERE C.ListName = 'HMORDTYPE'
       AND   O.OrderKey = @cOrderkey
                     AND   O.StorerKey = @cStorerKey
                     AND   C.Short = 'M')
         BEGIN
            SET @nErrNo = 57501  -- Move order
            GOTO Fail
         END

         IF @cType = 'COD'
         BEGIN
            SET @nErrNo = 57502  -- COD order
            GOTO Fail
         END

         IF @cRDS = 'T'
         BEGIN
            SET @nErrNo = 57503  -- Time slot order
            GOTO Fail
         END

         SELECT @cPickSlipNo = PickSlipNo
         FROM dbo.PackHeader WITH (NOLOCK)
         WHERE OrderKey = @cOrderkey

         SET @nCount = 0
         SELECT @nCount = COUNT( DISTINCT CartonNo)
         FROM PackDetail WITH (NOLOCK)
         WHERE PickSlipNo = @cPickSlipNo

         IF @nCount > 1
         BEGIN
            SET @nErrNo = 57504  -- > 1 Carton
            GOTO Fail
         END

         SELECT @nTtl_OrdQty = ISNULL( SUM( QTY), 0)
         FROM dbo.PickDetail WITH (NOLOCK)
         WHERE OrderKey = @cOrderkey
         AND   [Status] NOT IN ('4', '9')

         SELECT @nTtl_PckQty = ISNULL( SUM( QTY), 0)
         FROM dbo.PackDetail WITH (NOLOCK)
         WHERE PickSlipNo = @cPickSlipNo

         -- If order still has something to pack, not allow
         -- to choose letter. This is to prevent 1 order will have
         -- 2 tracking no as new tracking no will be released once
         -- this is choose.
         IF @nTtl_OrdQty > @nTtl_PckQty
         BEGIN
            SET @nErrNo = 57509  -- > Not finish pack
            GOTO Fail
         END

         IF @nErrNo > 0
         BEGIN
            SET @cErrMsg1 = ''
            SET @cErrMsg2 = ''
            SET @cErrMsg3 = ''

            SET @cErrMsg1 = 'THIS ORDERS NOT'
            SET @cErrMsg2 = 'ALLOW TO CHOOSE'
            SET @cErrMsg3 = 'LETTER SERVICE'

            GOTO Fail
         END

         /*
            If packer scan the carton type of letter service AND pass the validation then
            1)  Release original pre-paid tracking number
            2)  Find a new available Letter tracking number FROM the pool AND assign to order
         */

         SET @nTranCount = @@TRANCOUNT
         BEGIN TRAN
         SAVE TRAN HM_LetterService

         /** get new available pre-paid tracking number **/
         SELECT @cCarrierName = Code,
                @cKeyName = UDF05
         FROM dbo.Codelkup WITH (NOLOCK)
         WHERE Listname = 'HMCourier'
         AND   Long = 'Letter'
         AND   StorerKey = @cStorerKey

         SELECT @cTrackingNo_Letter = MIN( TrackingNo)
         FROM dbo.CartonTrack WITH (NOLOCK)
         WHERE CarrierName = @cCarrierName
         AND   Keyname = @cKeyName
         AND   ISNULL( CarrierRef2, '') = ''

         IF ISNULL( @cTrackingNo_Letter, '') = ''
         BEGIN
            SET @nErrNo = 57506  --'GET TRK# FAIL'
            GOTO RollBackTran
         END

         /** release old pre-paid tracking number **/
         UPDATE CT WITH (ROWLOCK) SET
            LabelNo = '',
            Carrierref1 = '',
            Carrierref2 = ''
         FROM dbo.CartonTrack CT
         JOIN dbo.Orders O ON
            --( CT.LabelNo = O.OrderKey AND CT.TrackingNo = O.Userdefine04)
            ( CT.LabelNo = O.OrderKey AND CT.TrackingNo = O.TrackingNo) -- (james05)
         WHERE O.OrderKey = @cOrderKey

         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 57505  --'RELEASE FAIL'
            GOTO RollBackTran
         END

         /** assign new letter tracking number to order **/
         UPDATE dbo.CartonTrack WITH (ROWLOCK) SET
            LabelNo = @cOrderKey,
            Carrierref2 = 'GET'
         WHERE CarrierName = @cCarrierName
         AND   Keyname = @cKeyName
         AND   CarrierRef2 = ''
         AND   TrackingNo = @cTrackingNo_Letter

         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 57507  --'ASSGN TRK# FAIL'
            GOTO RollBackTran
         END

         UPDATE dbo.Orders WITH (ROWLOCK) SET
            Shipperkey = @cCarrierName,
            --UserDefine04 = @cTrackingNo_Letter,
            TrackingNo = @cTrackingNo_Letter,   -- (james05)
            TrafficCop = NULL
         WHERE Storerkey = @cStorerkey
         AND   OrderKey = @cOrderKey

         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 57508  --'ASSGN TRK# FAIL'
            GOTO RollBackTran
         END

         DECLARE CUR_UPD CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
         SELECT PickDetailKey FROM dbo.PickDetail WITH (NOLOCK)
         WHERE Storerkey = @cStorerkey
         AND   OrderKey = @cOrderKey
         AND   CaseID = @cOrd_TrackingNo
         OPEN CUR_UPD
         FETCH NEXT FROM CUR_UPD INTO @cPickDetailKey
         WHILE @@FETCH_STATUS <> -1
         BEGIN
            -- Sync the caseid with new tracking no
            UPDATE dbo.PickDetail WITH (ROWLOCK) SET
               CaseID = @cTrackingNo_Letter,
               TrafficCop = NULL
            WHERE PickDetailKey = @cPickDetailKey

            IF @@ERROR <> 0
            BEGIN
               CLOSE CUR_UPD
               DEALLOCATE CUR_UPD
               SET @nErrNo = 57510  --'SWAP TRK# FAIL'
               GOTO RollBackTran
            END

            FETCH NEXT FROM CUR_UPD INTO @cPickDetailKey
         END
         CLOSE CUR_UPD
         DEALLOCATE CUR_UPD

         DECLARE CUR_UPD CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
         SELECT CartonNo, LabelLine FROM dbo.PackDetail WITH (NOLOCK)
         WHERE Storerkey = @cStorerkey
         AND   PickSlipNo = @cPickSlipNo
         AND   LabelNo = @cOrd_TrackingNo
         OPEN CUR_UPD
         FETCH NEXT FROM CUR_UPD INTO @nCartonNo, @cLabelLine
         WHILE @@FETCH_STATUS <> -1
         BEGIN
            -- Sync the labelno with new tracking no
            UPDATE dbo.PackDetail WITH (ROWLOCK) SET
               LabelNo = @cTrackingNo_Letter,
               ArchiveCop = NULL
            WHERE PickSlipNo = @cPickSlipNo
            AND   CartonNo = @nCartonNo
            AND   LabelNo = @cOrd_TrackingNo
            AND   LabelLine = @cLabelLine

            IF @@ERROR <> 0
            BEGIN
               CLOSE CUR_UPD
               DEALLOCATE CUR_UPD
               SET @nErrNo = 57511  --'SWAP TRK# FAIL'
               GOTO RollBackTran
            END

            FETCH NEXT FROM CUR_UPD INTO @nCartonNo, @cLabelLine
         END
         CLOSE CUR_UPD
         DEALLOCATE CUR_UPD
      END
   END

   GOTO Quit

   RollBackTran:
      ROLLBACK TRAN HM_LetterService

   Quit:
      WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
         COMMIT TRAN HM_LetterService
Fail:
   IF rdt.RDTGetConfig( @nFunc, 'ShowErrMsgInNewScn', @cStorerkey) = '1'
   BEGIN
      IF @nErrNo > 0 AND @nErrNo <> 1  -- Not from prev msgqueue
      BEGIN
         SET @cErrMsg1 = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')
         EXEC rdt.rdtInsertMsgQueue @nMobile, @nMsgQErrNo OUTPUT, @nMsgQErrMsg OUTPUT, @cErrMsg1
         IF @nMsgQErrNo = 1
            SET @cErrMsg1 = ''
      END
   END

GO