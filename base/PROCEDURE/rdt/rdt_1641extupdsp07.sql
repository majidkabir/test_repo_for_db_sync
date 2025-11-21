SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_1641ExtUpdSP07                                  */
/* Copyright      : IDS                                                 */
/*                                                                      */
/* Called from: rdtfnc_Pallet_Build                                     */
/*                                                                      */
/* Purpose: Build pallet & palletdetail                                 */
/*                                                                      */
/* Modifications log:                                                   */
/* Date        Rev  Author   Purposes                                   */
/* 2020-02-13  1.0  YeeKung  WMS-12162 Created                          */
/* 2023-02-10  1.1  YeeKung  WMS-21738 Add UCC column (yeekung01)        */
/************************************************************************/

CREATE   PROC [RDT].[rdt_1641ExtUpdSP07] (
   @nMobile     INT,
   @nFunc       INT,
   @cLangCode   NVARCHAR( 3),
   @cUserName   NVARCHAR( 15),
   @cFacility   NVARCHAR( 5),
   @cStorerKey  NVARCHAR( 15),
   @cDropID     NVARCHAR( 20),
   @cUCCNo      NVARCHAR( 20),
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
            @cRoute          NVARCHAR( 20) = '',
            @cOption         NVARCHAR( 1) = ''


   SELECT @nStep = Step,
          @nInputKey = InputKey
   FROM RDT.RDTMobRec WITH (NOLOCK)
   WHERE Mobile = @nMobile

   SET @nTranCount = @@TRANCOUNT

   BEGIN TRAN
   SAVE TRAN rdt_1641ExtUpdSP07

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
            SET @nErrNo = 148151
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Ctn In Other Plt
            GOTO RollBackTran
         END


         IF EXISTS ( SELECT 1 FROM dbo.PalletDetail WITH (NOLOCK)
                     WHERE StorerKey = @cStorerKey
                     AND   CaseId = @cUCCNo
                     AND  [Status] < '9')
        BEGIN
            SET @nErrNo = 148152
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
               SET @nErrNo = 148153
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InsPLTFail
               GOTO RollBackTran
            END
         END

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

            SELECT @cOrderKey = OrderKey
            FROM dbo.PackHeader WITH (NOLOCK)
            WHERE PickSlipNo = @cPickSlipNo

            SELECT @cRoute = Route
            FROM dbo.ORDERS WITH (NOLOCK)
            WHERE OrderKey = @cOrderKey

            INSERT INTO dbo.PalletDetail
            (PalletKey, PalletLineNumber, CaseId, StorerKey, Sku, Qty, UserDefine01, UserDefine02)
            VALUES
            (@cDropID, 0, @cUCCNo, @cStorerKey, @cSKU, @nPD_Qty, @cRoute, @cOrderKey)

            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 148154
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
               SET @nErrNo = 148155
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --PLTKeyNotFound
               GOTO RollBackTran
            END

            IF NOT EXISTS ( SELECT 1 FROM dbo.PALLETDETAIL WITH (NOLOCK)
                            WHERE StorerKey = @cStorerKey
                            AND   PalletKey = @cDropID
                            AND  [Status] < '9')
            BEGIN
               SET @nErrNo = 148156
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
               SET @nErrNo = 148157
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
               SET @nErrNo = 148158
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Close Plt Fail
               GOTO RollBackTran
            END
         END
      END
   END

   IF @nStep = 7
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
               SET @nErrNo = 148159
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
               SET @nErrNo = 148160
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Upd pltdt fail
               GOTO RollBackTran
            END

         END

         ELSE
         BEGIN
            SET @nErrNo = 148161
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --PltShipped
            GOTO RollBackTran
         END


      END
   END

   GOTO Quit

   RollBackTran:
      ROLLBACK TRAN rdt_1641ExtUpdSP07

   Quit:
      WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
         COMMIT TRAN rdt_1641ExtUpdSP07


Fail:
END

GO