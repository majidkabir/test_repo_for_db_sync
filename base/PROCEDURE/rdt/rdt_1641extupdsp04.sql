SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_1641ExtUpdSP04                                  */
/* Copyright      : IDS                                                 */
/*                                                                      */
/* Called from: rdtfnc_Pallet_Build                                     */
/*                                                                      */
/* Purpose: Build pallet & palletdetail                                 */
/*                                                                      */
/* Modifications log:                                                   */
/* Date        Rev  Author   Purposes                                   */
/* 2019-08-10  1.0  YeeKung   WMS10083 Created                          */
/* 2020-07-09  1.1  YeeKung   WMS14187 update UD03(yeekung01)           */
/* 2023-02-10  1.2  YeeKung  WMS-21738 Add UCC column (yeekung01)        */
/************************************************************************/

CREATE   PROC [RDT].[rdt_1641ExtUpdSP04] (
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
            @bSuccess      INT,
            @nPD_Qty       INT,
            @cSKU          NVARCHAR( 20),
            @cRouteCode    NVARCHAR( 30),
            @cOrderKey     NVARCHAR( 10),
            @cPickSlipNo   NVARCHAR( 10),
            @cPalletLineNumber   NVARCHAR( 5),
            @cdeliverymode NVARCHAR(20)

   SELECT @nStep = Step,
          @nInputKey = InputKey
   FROM RDT.RDTMobRec WITH (NOLOCK)
   WHERE Mobile = @nMobile


   SET @nTranCount = @@TRANCOUNT

   BEGIN TRAN
   SAVE TRAN rdt_1641ExtUpdSP04

   IF @nStep = 3
   BEGIN
      IF @nInputKey = 1
      BEGIN
         -- Check if pallet id exists before
         IF NOT EXISTS ( SELECT 1
                         FROM dbo.Pallet WITH (NOLOCK)
                         WHERE StorerKey = @cStorerKey
                         AND   PalletKey = @cDropID
                         AND   [Status] < '9')
         BEGIN
            -- Insert Pallet info
            INSERT INTO dbo.Pallet (PalletKey, StorerKey) VALUES (@cDropID, @cStorerKey)

            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 142851
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Ins plt fail
               GOTO RollBackTran
            END
         END

         IF EXISTS ( SELECT 1 FROM dbo.PalletDetail WITH (NOLOCK)
                     WHERE StorerKey = @cStorerKey
                     AND   CaseId = @cUCCNo
                     AND  [Status] < '9')
         BEGIN
            SET @nErrNo = 142852
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Ctn exists
            GOTO RollBackTran
         END

         SELECT TOP 1 @cRouteCode = RefNo2,
                      @cPickSlipNo = PickSlipNo
         FROM dbo.PackDetail WITH (NOLOCK)
         WHERE StorerKey = @cStorerKey
         AND   RefNo = @cUCCNo

         SELECT @cOrderKey = OrderKey
         FROM dbo.PackHeader WITH (NOLOCK)
         WHERE StorerKey = @cStorerKey
         AND   PickSlipNo = @cPickSlipNo

         SELECT @cPalletLineNumber = RIGHT( '00000' + CAST( CAST( ISNULL(MAX( PalletLineNumber), 0) AS INT) + 1 AS NVARCHAR( 5)), 5)
         FROM dbo.PalletDetail WITH (NOLOCK)
         WHERE PalletKey = @cDropID

         SELECT @cSKU = SKU,
                @nPD_Qty = ISNULL( SUM( Qty), 0)
         FROM dbo.PackDetail WITH (NOLOCK)
         WHERE StorerKey = @cStorerKey
            AND   RefNo = @cUCCNo
         GROUP BY SKU

         SELECT @cdeliverymode=deliverymode --(yeekung01)
         FROM ORDERinfo (NOLOCK)
         WHERE ORDERKEY=@cOrderKey

         INSERT INTO dbo.PalletDetail   --(yeekung01)
         (PalletKey, PalletLineNumber, CaseId, StorerKey, Sku, Qty, UserDefine01, UserDefine02, UserDefine03)
         VALUES
         (@cDropID, @cPalletLineNumber, @cUCCNo, @cStorerKey, @cSKU, @nPD_Qty, @cRouteCode, @cOrderKey,@cdeliverymode)

         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 142853
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Ins pltdt fail
            GOTO RollBackTran
         END
      END
   END

   IF @nStep = 4
   BEGIN
      IF @nInputKey = 1
      BEGIN
         IF NOT EXISTS ( SELECT 1 FROM dbo.Pallet WITH (NOLOCK)
                         WHERE StorerKey = @cStorerKey
                         AND   PalletKey = @cDropID
                         AND  [Status] < '9')
         BEGIN
            SET @nErrNo = 142854
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Pkey not found
            GOTO RollBackTran
         END

         -- Insert transmitlog2 here
         EXEC ispGenTransmitLog2
            @c_TableName      = 'WSPALLETCFMLOG',
            @c_Key1           = @cStorerKey,
            @c_Key2           = '',
            @c_Key3           = @cDropID,
            @c_TransmitBatch  = '',
            @b_Success        = @bSuccess    OUTPUT,
            @n_err            = @nErrNo      OUTPUT,
            @c_errmsg         = @cErrMsg     OUTPUT

         IF @bSuccess <> 1
            GOTO RollBackTran

         UPDATE dbo.PALLETDETAIL WITH (ROWLOCK) SET
            [Status] = '9'
         WHERE StorerKey = @cStorerKey
         AND   PalletKey = @cDropID
         AND   [Status] < '9'

         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 142855
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Upd pltdt fail
            GOTO RollBackTran
         END

         UPDATE dbo.PALLET WITH (ROWLOCK) SET
            [Status] = '9'
         WHERE StorerKey = @cStorerKey
         AND   PalletKey = @cDropID
         AND   [Status] < '9'

         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 142856
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Upd plt fail
            GOTO RollBackTran
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
               SET @nErrNo = 142857
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
               SET @nErrNo = 142858
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Upd pltdt fail
               GOTO RollBackTran
            END

         END

         ELSE
         BEGIN
            SET @nErrNo = 142859
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --PltShipped
            GOTO RollBackTran
         END


      END
   END

   GOTO Quit

   RollBackTran:
      ROLLBACK TRAN rdt_1641ExtUpdSP04

   Quit:
      WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
         COMMIT TRAN rdt_1641ExtUpdSP04


Fail:
END

GO