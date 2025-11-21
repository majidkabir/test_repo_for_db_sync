SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO



/************************************************************************/
/* Store procedure: rdt_1641ExtUpdSP05                                  */
/* Copyright      : IDS                                                 */
/*                                                                      */
/* Called from: rdtfnc_Pallet_Build                                     */
/*                                                                      */
/* Purpose: Build pallet & palletdetail                                 */
/*                                                                      */
/* Modifications log:                                                   */
/* Date        Rev  Author   Purposes                                   */
/* 2019-10-29  1.0  James    WMS-11018 Created                          */
/* 2020-01-17  1.1  James    WMS-11855 Ecom orders enhancement (james01)*/
/* 2020-03-24  1.2  James    WMS-12641 Ecom orders enhancement (james02)*/
/* 2020-08-10  1.3  YeeKung  WMS-14625 Reopen Pallet (yeekung01)        */
/* 2023-02-10  1.4  YeeKung  WMS-21738 Add UCC column (yeekung02)       */
/* 2023-05-10  1.5  James    WMS-22458 Add tracking no scan (M_Address1)*/
/*                           to build pallet (james03)                  */
/************************************************************************/

CREATE   PROC [RDT].[rdt_1641ExtUpdSP05] (
   @nMobile     INT,
   @nFunc       INT,
   @cLangCode   NVARCHAR( 3),
   @cUserName   NVARCHAR( 15),
   @cFacility   NVARCHAR( 5),
   @cStorerKey  NVARCHAR( 15),
   @cDropID     NVARCHAR( 20),
   @cUCCNo     NVARCHAR( 20),
   @nErrNo      INT          OUTPUT,
   @cErrMsg     NVARCHAR( 20) OUTPUT  -- screen limitation, 20 char max
) AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE  @nStep         INT,
            @nInputKey     INT,
            @nTranCount    INT,
            @nPD_Qty       INT,
            @cSKU          NVARCHAR( 20),
            @cOrderKey     NVARCHAR( 10),
            @cPickSlipNo   NVARCHAR( 10),
            @cPalletLineNumber   NVARCHAR( 5),
            @cCaseID         NVARCHAR(20),
            @nQty            INT,
            @cOtherPalletKey NVARCHAR( 30) = '',
            @cSUSR1          NVARCHAR( 20) = '',
            @cConsigneeKey   NVARCHAR( 15) = '',
            @cOption         NVARCHAR( 1) = '',
            @cOrderGroup     NVARCHAR( 20) = '',
            @cC_ISOCntryCode NVARCHAR( 10) = '',
            @cUserDefine01   NVARCHAR( 30) = '',
            @cOrders_M_Company   NVARCHAR( 45) = '',
            @cShipperKey      NVARCHAR( 15) = '',
            @cExternOrderKey  NVARCHAR( 50) = ''
            
   DECLARE @cTrackOrderKey    NVARCHAR( 10) = ''
   DECLARE @curPD             CURSOR
               
   SELECT @nStep = Step,
          @nInputKey = InputKey
   FROM RDT.RDTMobRec WITH (NOLOCK)
   WHERE Mobile = @nMobile

   SET @nTranCount = @@TRANCOUNT

   BEGIN TRAN
   SAVE TRAN rdt_1641ExtUpdSP05

   IF @nStep = 3
   BEGIN
      IF @nInputKey = 1
      BEGIN
         SELECT TOP 1 @cOtherPalletKey = PalletKey
         FROM dbo.PALLETDETAIL AS p WITH (NOLOCK)
         WHERE StorerKey = @cStorerKey
         AND   CaseId = @cUCCNo
         AND  [Status] < '9'
         ORDER BY 1

         IF @@ROWCOUNT > 0
         BEGIN
            SET @nErrNo = 145651
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Ctn In Other Plt
            GOTO RollBackTran
         END


         IF EXISTS ( SELECT 1 FROM dbo.PalletDetail WITH (NOLOCK)
                     WHERE StorerKey = @cStorerKey
                     AND   CaseId = @cUCCNo
                     AND  [Status] < '9')
        BEGIN
            SET @nErrNo = 145652
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --CartonExist
            GOTO RollBackTran
         END

         -- Check if pallet id exists before
         IF NOT EXISTS ( SELECT 1
                         FROM dbo.Pallet WITH (NOLOCK)
                         WHERE PalletKey = @cDropID)
         BEGIN
            -- Insert Pallet info
            INSERT INTO dbo.Pallet (PalletKey, StorerKey) VALUES (@cDropID, @cStorerKey)

            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 145653
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InsPLTFail
               GOTO RollBackTran
            END
         END

         SELECT @cTrackOrderKey = OrderKey
         FROM dbo.ORDERS WITH (NOLOCK)
         WHERE StorerKey = @cStorerKey
         AND   M_Address1 = @cUCCNo
         AND   [Status] < '9'
         
         IF @cTrackOrderKey <> ''
         BEGIN
            SELECT @cConsigneeKey = ConsigneeKey,
                   @cOrderGroup = OrderGroup,
                   @cC_ISOCntryCode = C_ISOCntryCode,
                   @cOrders_M_Company = M_Company,
                   @cShipperKey = ShipperKey,
                   @cExternOrderKey = ExternOrderKey
            FROM dbo.ORDERS WITH (NOLOCK)
            WHERE OrderKey = @cTrackOrderKey

            IF @cOrderGroup = 'ECOM'
               SET @cUserDefine01 = SUBSTRING( RTRIM( @cC_ISOCntryCode) +
                                    RTRIM( @cOrders_M_Company) +
                                    RTRIM( @cShipperKey), 1, 30)
            ELSE
            BEGIN
               SELECT @cSUSR1 = SUSR1
               FROM dbo.Storer WITH (NOLOCK)
               WHERE StorerKey = @cConsigneeKey

               SET @cUserDefine01 = @cSUSR1
            END
            
            SET @curPD = CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
            SELECT SKU, ISNULL( SUM( Qty), 0)
            FROM dbo.PICKDETAIL WITH (NOLOCK)
            WHERE OrderKey = @cTrackOrderKey
            GROUP BY SKU
            OPEN @curPD
            FETCH NEXT FROM @curPD INTO @cSKU, @nPD_Qty
            WHILE @@FETCH_STATUS = 0
            BEGIN
               -- PalletDetail.CaseId = ExternOrderKey + '1' or PackDetail.LabelNo
               -- 1 Orders 1 Carton only
               SELECT TOP 1 @cCaseID = PD.LabelNo
               FROM dbo.PackDetail PD WITH (NOLOCK)
               JOIN dbo.PackHeader PH WITH (NOLOCK) ON ( PD.PickSlipNo = PH.PickSlipNo)
               WHERE PH.OrderKey =  @cTrackOrderKey
               AND   PH.StorerKey = @cStorerKey
               AND   PD.SKU = @cSKU
               ORDER BY 1
            
               INSERT INTO dbo.PalletDetail
               (PalletKey, PalletLineNumber, CaseId, StorerKey, Sku, Qty, UserDefine01, UserDefine02)
               VALUES
               (@cDropID, 0, @cCaseID, @cStorerKey, @cSKU, @nPD_Qty, @cUserDefine01, @cTrackOrderKey)

               IF @@ERROR <> 0
               BEGIN
                  SET @nErrNo = 145662
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InsPLTDetFail
                  GOTO RollBackTran
               END

               FETCH NEXT FROM @curPD INTO @cSKU, @nPD_Qty
            END
         END   
         ELSE
            BEGIN
            -- Insert PalletDetail
            DECLARE CUR_PalletDetail CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
            SELECT PickSlipNo, SKU, ISNULL( SUM( Qty), 0)
            FROM dbo.PackDetail WITH (NOLOCK)
            WHERE StorerKey = @cStorerKey
            AND   LabelNo = @cUCCNo
            GROUP BY PickSlipNo, SKU
            OPEN CUR_PalletDetail
            FETCH NEXT FROM CUR_PalletDetail INTO @cPickSlipNo, @cSKU, @nPD_Qty
            WHILE @@FETCH_STATUS <> -1
            BEGIN
               -- (james01)
               --if orders.ordergroup = ∩┐╜ECOM∩┐╜, insert orders.ISOcntrycode
               --into palletdetail.udf01 when user scan carton label number

               SELECT @cOrderKey = OrderKey
               FROM dbo.PackHeader WITH (NOLOCK)
               WHERE PickSlipNo = @cPickSlipNo

               SELECT @cConsigneeKey = ConsigneeKey,
                      @cOrderGroup = OrderGroup,
                      @cC_ISOCntryCode = C_ISOCntryCode,
                      @cOrders_M_Company = M_Company,
                      @cShipperKey = ShipperKey
               FROM dbo.ORDERS WITH (NOLOCK)
               WHERE OrderKey = @cOrderKey

               IF @cOrderGroup = 'ECOM'
                  SET @cUserDefine01 = SUBSTRING( RTRIM( @cC_ISOCntryCode) +
                                       RTRIM( @cOrders_M_Company) +
                                       RTRIM( @cShipperKey), 1, 30)
               ELSE
               BEGIN
                  SELECT @cSUSR1 = SUSR1
                  FROM dbo.Storer WITH (NOLOCK)
                  WHERE StorerKey = @cConsigneeKey

                  SET @cUserDefine01 = @cSUSR1
               END

               INSERT INTO dbo.PalletDetail
               (PalletKey, PalletLineNumber, CaseId, StorerKey, Sku, Qty, UserDefine01, UserDefine02)
               VALUES
               (@cDropID, 0, @cUCCNo, @cStorerKey, @cSKU, @nPD_Qty, @cUserDefine01, @cOrderKey)

               IF @@ERROR <> 0
               BEGIN
                  SET @nErrNo = 145654
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InsPLTDetFail
                  CLOSE CUR_PalletDetail
                  DEALLOCATE CUR_PalletDetail
                  GOTO RollBackTran
               END

               FETCH NEXT FROM CUR_PalletDetail INTO @cPickSlipNo, @cSKU, @nPD_Qty
            END
            CLOSE CUR_PalletDetail
            DEALLOCATE CUR_PalletDetail
         END
      END
   END

   IF @nStep = 4
   BEGIN
      IF @nInputKey = 1
      BEGIN
         SELECT @cOption = I_Field01
         FROM RDT.RDTMobRec WITH (NOLOCK)
         WHERE Mobile = @nMobile

         IF @cOption = '1'
         BEGIN
            IF NOT EXISTS ( SELECT 1 FROM dbo.Pallet WITH (NOLOCK)
                            WHERE StorerKey = @cStorerKey
                            AND   PalletKey = @cDropID
                            AND  [Status] < '9')
            BEGIN
               SET @nErrNo = 145655
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --PLTKeyNotFound
               GOTO RollBackTran
            END

            IF NOT EXISTS ( SELECT 1 FROM dbo.PALLETDETAIL WITH (NOLOCK)
                            WHERE StorerKey = @cStorerKey
                            AND   PalletKey = @cDropID
                            AND  [Status] < '9')
            BEGIN
               SET @nErrNo = 145656
           SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --No Ctn Scanned
               GOTO RollBackTran
            END

            UPDATE dbo.PALLETDETAIL WITH (ROWLOCK) SET
               [Status] = '9'
            WHERE StorerKey = @cStorerKey
            AND   PalletKey = @cDropID
            AND   [Status] < '9'

            IF @@ERROR <> 0
           BEGIN
               SET @nErrNo = 145657
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Upd PLTDet Err
               GOTO RollBackTran
            END

            UPDATE dbo.PALLET WITH (ROWLOCK) SET
               [Status] = '9'
            WHERE StorerKey = @cStorerKey
            AND   PalletKey = @cDropID
            AND   [Status] < '9'

            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 145658
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Close Plt Fail
               GOTO RollBackTran
            END
         END
      END
   END

   IF @nStep = 7  --(yeekung01)
   BEGIN
      IF @nInputKey = 1
      BEGIN

         IF NOT EXISTS( SELECT 1 FROM PALLETDETAIL PD (NOLOCK) JOIN MBOLDETAIL MD (NOLOCK)
                     ON PD.UserDefine02=MD.OrderKey  JOIN  PICKDETAIL PKD (nolock)
                     ON MD.ORDERKEY=PKD.ORDERKEY
                     WHERE PD.StorerKey = @cStorerKey
                     AND   PD.PalletKey = @cDropID
                     AND   PKD.STATUS = 9
                     AND   PD.STATUS=9)
         BEGIN

            UPDATE dbo.PALLETDETAIL WITH (ROWLOCK) SET
               [Status] = '0'
            WHERE StorerKey = @cStorerKey
            AND   PalletKey = @cDropID
            AND   [Status] = '9'

            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 145659
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Upd pltdt fail
               GOTO RollBackTran
            END

            UPDATE dbo.PALLET WITH (ROWLOCK) SET
               [Status] = '0'
               ,[TrafficCop]= NULL
            WHERE StorerKey = @cStorerKey
            AND   PalletKey = @cDropID
            AND   [Status] = '9'

            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 145660
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Upd pltdt fail
               GOTO RollBackTran
            END

         END
         ELSE
         BEGIN
            SET @nErrNo = 145661
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --PltShipped
            GOTO RollBackTran
         END
      END
   END

   GOTO Quit

   RollBackTran:
      ROLLBACK TRAN rdt_1641ExtUpdSP05

   Quit:
      WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
         COMMIT TRAN rdt_1641ExtUpdSP05


Fail:
END

GO