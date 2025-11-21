SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_1641ExtUpdSP10                                  */
/* Copyright      : IDS                                                 */
/*                                                                      */
/* Called from: rdtfnc_Pallet_Build                                     */
/*              Transfer 02->08                                         */
/*                                                                      */
/* Purpose: Build pallet & palletdetail                                 */
/*                                                                      */
/* Modifications log:                                                   */
/* Date        Rev  Author   Purposes                                   */
/* 2020-10-29  1.0  YeeKung  WMS-15617 Created                          */
/* 2023-02-10  1.1  YeeKung  WMS-21738 Add UCC column (yeekung01)        */
/************************************************************************/

CREATE   PROC [RDT].[rdt_1641ExtUpdSP10] (
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
            @bSuccess      INT,
            @nPD_Qty       INT,
            @cSKU          NVARCHAR( 20),

            @cRouteCode    NVARCHAR( 30),
            @cOrderKey     NVARCHAR( 10),
            @cPickSlipNo   NVARCHAR( 10),
            @cPalletLineNumber   NVARCHAR( 5),
            @cTrackingNumber01 NVARCHAR(20)='',
            @cTrackingNumber02 NVARCHAR(20)='',
            @cTrackingNumber03 NVARCHAR(20)='',
            @cTrackingNumber04 NVARCHAR(20)='',
            @cTrackingNumber05 NVARCHAR(20)='',
            @cTrackingNumber06 NVARCHAR(20)='',
            @cTrackingNumber07 NVARCHAR(20)='',
            @cPalletCaseID NVARCHAR(20),
            @cLottableValue NVARCHAR(20)

   SELECT @nStep = Step,
          @nInputKey = InputKey
   FROM RDT.RDTMobRec WITH (NOLOCK)
   WHERE Mobile = @nMobile

   SET @nTranCount = @@TRANCOUNT

   BEGIN TRAN
   SAVE TRAN rdt_1641ExtUpdSP10

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
               SET @nErrNo = 162851
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Ins plt fail
               GOTO RollBackTran
            END
         END

         IF EXISTS ( SELECT 1 FROM dbo.PalletDetail WITH (NOLOCK)
                     WHERE StorerKey = @cStorerKey
                     AND   CaseId = @cUCCNo
                     AND  [Status] < '9')
         BEGIN
            SET @nErrNo = 162852
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Ctn exists
            GOTO RollBackTran
         END

         SELECT TOP 1 @cRouteCode = RefNo2,
                      @cPickSlipNo = PickSlipNo,
                      @cLottableValue=lottablevalue
         FROM dbo.PackDetail WITH (NOLOCK)
         WHERE StorerKey = @cStorerKey
         AND   labelno = @cUCCNo

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
         AND   labelno = @cUCCNo
         GROUP BY SKU

         INSERT INTO dbo.PalletDetail
         (PalletKey, PalletLineNumber, CaseId, StorerKey, Sku, Qty, UserDefine01, UserDefine02,userdefine03)
         VALUES
         (@cDropID, @cPalletLineNumber, @cUCCNo, @cStorerKey, @cSKU, @nPD_Qty, @cRouteCode, @cOrderKey,@cLottableValue)

         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 162853
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Ins pltdt fail
            GOTO RollBackTran
         END
      END
   END

   IF @nStep = 4
   BEGIN
      IF @nInputKey = 1
      BEGIN

         UPDATE dbo.PALLETDETAIL WITH (ROWLOCK) SET
            [Status] = '9'
         WHERE StorerKey = @cStorerKey
         AND   PalletKey = @cDropID
         AND   [Status] < '9'

         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 162854
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
            SET @nErrNo = 162855
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Upd pltdt fail
            GOTO RollBackTran
         END
      END
   END

   GOTO Quit

   RollBackTran:
      ROLLBACK TRAN rdt_1641ExtUpdSP10


   Quit:
      WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
         COMMIT TRAN rdt_1641ExtUpdSP10

Fail:
END

GO