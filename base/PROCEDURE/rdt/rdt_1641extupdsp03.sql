SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_1641ExtUpdSP03                                  */
/* Copyright      : IDS                                                 */
/*                                                                      */
/* Called from: rdtfnc_Pallet_Build                                     */
/*                                                                      */
/* Purpose: Build pallet & palletdetail                                 */
/*                                                                      */
/* Modifications log:                                                   */
/* Date        Rev  Author   Purposes                                   */
/* 2017-05-31  1.0  ChewKP   WMS-1992 Created                           */
/* 2017-08-11  1.1  ChewKP   WMS-2519 Print Label  (ChewKP01)           */
/* 2017-09-05  1.2  JihHaur  IN00453585 Cannot close pallet  (JH01)     */
/* 2018-01-30  1.3  ChewKP   WMS-3809 (ChewKP02)                        */
/* 2019-02-11  1.4  ChewKP   WMS-7894 Add Pallet Criteria Validation    */
/*                           (ChewKP03)                                 */
/* 2019-07-04  1.5  James    Fix duplicate insert into pallet (james01) */
/* 2019-01-09  1.6  James    WMS-7546 Add print label for LOGKR(james02)*/
/************************************************************************/

CREATE   PROC [RDT].[rdt_1641ExtUpdSP03] (
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
            @cSortCode   NVARCHAR(13),
            @cRoute      NVARCHAR(10),
            @cExternOrderKey NVARCHAR(30),
            @cLot            NVARCHAR(10),
            @cFromLoc        NVARCHAR(10),
            @cFromID         NVARCHAR(18),
            @nPickedQty      INT,
            @cPickedQty      INT,  --(JH01)
            @cTaskDetailKey  NVARCHAR(10),
            @cCaseID         NVARCHAR(20),
            @nQty            INT,
            @cToLoc          NVARCHAR(10),
            @cPackDropID     NVARCHAR(20),
            @nPackedQty      INT,
            @cPaperPrinter   NVARCHAR(10),
            @cLabelPrinter   NVARCHAR(10),
            @nQtyBalance     INT,
            @nQtyToMove      INT,
            @nSKU_Count      INT,
            @cUserDefine09   NVARCHAR(10)

   DECLARE @cUDF01          NVARCHAR(60)
   DECLARE @cUDF02          NVARCHAR(60)
   DECLARE @cUDF03          NVARCHAR(60)
   DECLARE @cUDF04          NVARCHAR(60)
   DECLARE @cUDF05          NVARCHAR(60)

   SELECT @nStep = Step,
          @nInputKey = InputKey,
          @cPaperPrinter = Printer_Paper,
          @cLabelPrinter = Printer
   FROM RDT.RDTMobRec WITH (NOLOCK)
   WHERE Mobile = @nMobile

   SET @nTranCount = @@TRANCOUNT

   BEGIN TRAN
   SAVE TRAN rdt_1641ExtUpdSP03

   IF @nStep = 3
   BEGIN
      IF @nInputKey = 1
      BEGIN
         -- (ChewKP03)
         SELECT
            @cUDF01 = LEFT( ISNULL( UDF01, ''), 20),
            @cUDF02 = LEFT( ISNULL( UDF02, ''), 20),
            @cUDF03 = LEFT( ISNULL( UDF03, ''), 20),
            @cUDF04 = LEFT( ISNULL( UDF04, ''), 20),
            @cUDF05 = LEFT( ISNULL( UDF05, ''), 20)
         FROM DropID WITH (NOLOCK)
         WHERE DropID = @cDropID

         -- Check if pallet id exists before
         IF NOT EXISTS ( SELECT 1
                         FROM dbo.Pallet WITH (NOLOCK)
                         WHERE PalletKey = @cDropID)-- (james01)
         BEGIN
            -- Insert Pallet info
            INSERT INTO dbo.Pallet (PalletKey, StorerKey) VALUES (@cDropID, @cStorerKey)

            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 110601
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InsPLTFail
               GOTO RollBackTran
            END
         END

         IF EXISTS ( SELECT 1 FROM dbo.PalletDetail WITH (NOLOCK)
                     WHERE StorerKey = @cStorerKey
     AND   CaseId = @cUCCNo
                     AND  [Status] < '9')
        BEGIN
            SET @nErrNo = 110602
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --CartonExist
            GOTO RollBackTran
         END

         -- Insert PalletDetail
         DECLARE CUR_PalletDetail CURSOR LOCAL READ_ONLY FAST_FORWARD FOR

         SELECT
                          PickSlipNo
                         ,SKU
                         ,ISNULL( SUM( Qty), 0)
         FROM dbo.PackDetail WITH (NOLOCK)
         WHERE StorerKey = @cStorerKey
         AND   LabelNo = @cUCCNo
         GROUP BY PickSlipNo, SKU


         OPEN CUR_PalletDetail
         FETCH NEXT FROM CUR_PalletDetail INTO @cPickSlipNo, @cSKU, @nPD_Qty
         WHILE @@FETCH_STATUS <> -1
         BEGIN

--            SELECT TOP 1
--                          @cPickSlipNo = PickSlipNo
--                         ,@cSKU = SKU
--                         ,@nPD_Qty = ISNULL( SUM( Qty), 0)
--            FROM dbo.PackDetail WITH (NOLOCK)
--            WHERE StorerKey = @cStorerKey
--            AND   LabelNo = @cUCCNo
--            GROUP BY PickSlipNo, SKU

            --SELECT @cOrderKey = OrderKey
            --FROM dbo.PackHeader WITH (NOLOCK)
            --WHERE StorerKey = @cStorerKey
            --AND   PickSlipNo = @cPickSlipNo

            --SELECT @cPalletLineNumber = RIGHT( '00000' + CAST( CAST( ISNULL(MAX( PalletLineNumber), 0) AS INT) + 1 AS NVARCHAR( 5)), 5)
            --FROM dbo.PalletDetail WITH (NOLOCK)
            --WHERE PalletKey = @cDropID

            --SELECT @cSKU = SKU,
            --       @nPD_Qty = ISNULL( SUM( Qty), 0)
            --FROM dbo.PackDetail WITH (NOLOCK)
            --WHERE StorerKey = @cStorerKey
            --AND   LabelNo = @cUCCNo
            --GROUP BY SKU

            --SELECT @cPickSlipNo = PickSlipNo
            --FROM dbo.PackDetail WITH (NOLOCK)
            --WHERE StorerKey = @cStorerKey
            --AND LabelNo = @cCaseID

            SELECT @cOrderKey = OrderKey
            FROM dbo.PackHeader WITH (NOLOCK)
            WHERE PickSlipNo = @cPickSlipNo

            SELECT @cRoute = ISNULL(Route,'')
                  ,@cExternOrderKey = ExternOrderKey
                  ,@cUserDefine09 = ISNULL(UserDefine09,'')
            FROM dbo.Orders WITH (NOLOCK)
            WHERE StorerKey = @cStorerKey
            AND OrderKey = @cOrderKey

            IF ISNULL(@cUDF01,'')  IN ( '' , '1' )
               SET @cSortCode = RTRIM(@cRoute) + RIGHT(RTRIM(@cExternOrderKey),5)
            ELSE IF ISNULL(@cUDF01,'')  = '2'
               SET @cSortCode = RTRIM(@cRoute) + RIGHT(RTRIM(@cUserDefine09),5)


            INSERT INTO dbo.PalletDetail
            (PalletKey, PalletLineNumber, CaseId, StorerKey, Sku, Qty, UserDefine01, UserDefine02)
            VALUES
            (@cDropID, 0, @cUCCNo, @cStorerKey, @cSKU, @nPD_Qty, @cSortCode, @cOrderKey)

            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 110603
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InsPLTDetFail
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


         IF NOT EXISTS ( SELECT 1 FROM dbo.Pallet WITH (NOLOCK)
                         WHERE StorerKey = @cStorerKey
                         AND   PalletKey = @cDropID
                         AND  [Status] < '9')
         BEGIN
            SET @nErrNo = 110604
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --PLTKeyNotFound
            GOTO RollBackTran
         END




         -- Move Inventory
         DECLARE CUR_PalletBuild CURSOR LOCAL READ_ONLY FAST_FORWARD FOR

         SELECT PackDet.DropID,PD.SKU, SUM(PD.Qty)
         FROM dbo.PalletDetail PD WITH (NOLOCK)
         INNER JOIN dbo.PackDetail PackDet WITH (NOLOCK) ON PackDet.StorerKey = PD.StorerKey AND PackDet.LabelNo = PD.CaseID
         WHERE PD.StorerKey = @cStorerKey
         AND PD.PalletKey = @cDropID
         AND PD.Status = '0'
         Group by PackDet.DropID, PD.SKU


         OPEN CUR_PalletBuild
         FETCH NEXT FROM CUR_PalletBuild INTO @cPackDropID, @cSKU, @nPackedQty
         WHILE @@FETCH_STATUS <> -1
         BEGIN


               SET @cTaskDetailKey = ''
               SET @cLot = ''
               SET @cFromLoc = ''
               SET @cFromID  = ''
               SET @cPickedQty = ''  --(JH01)
               SET @nQtyBalance = @nPackedQty

              SELECT @cToLoc = Code
              FROM dbo.Codelkup WITH (NOLOCK)
              WHERE ListName = 'LOGIPLTLOC'
              AND StorerKey = @cStorerKey


              DECLARE CUR_PalletBuild_GroupBy_Loc CURSOR LOCAL READ_ONLY FAST_FORWARD FOR   --(JH01)

              SELECT         --(JH01) START
                  Lot
                 ,Loc
                 ,ID
                 ,ISNULL( SUM( QTY), 0)  --(JH01) END
              FROM dbo.PickDetail WITH (NOLOCK)
              WHERE StorerKey = @cStorerKey
              AND DropID = @cPackDropID
              AND SKU = @cSKU
              AND LOC <> @cToLoc
              Group by Lot, Loc, ID  --(JH01)


              OPEN CUR_PalletBuild_GroupBy_Loc     --(JH01) START
              FETCH NEXT FROM CUR_PalletBuild_GroupBy_Loc INTO @cLot, @cFromLoc, @cFromID, @cPickedQty
              WHILE @@FETCH_STATUS <> -1
              BEGIN   --(JH01) END


                 IF @nQtyBalance > @cPickedQty
                    SET @nQtyToMove =  @cPickedQty
                 ELSE
                    SET @nQtyToMove =  @nQtyBalance


                 -- Move by SKU
                 EXECUTE rdt.rdt_Move
                    @nMobile     = @nMobile,
                    @cLangCode   = @cLangCode,
                    @nErrNo      = @nErrNo  OUTPUT,
                    @cErrMsg     = @cErrMsg OUTPUT,
                    @cSourceType = 'rdt_1641ExtUpdSP03',
                    @cStorerKey  = @cStorerKey,
                    @cFacility   = @cFacility,
                    @cFromLOC    = @cFromLoc,
                    @cToLOC      = @cToLoc, -- Final LOC
                    @cFromID     = @cFromID,
                    @cToID       = @cDropID,
                    @nQTYPick    = @nQtyToMove,  --(JH01) @nPackedQty,
                    @nQTY        = @nQtyToMove,  --(JH01) @nPackedQty,
                    @cFromLOT    = @cLOT,
                    @nFunc       = @nFunc,
                    @cDropID     = @cPackDropID,
                    @cSKU        = @cSKU


                 IF @nErrNo <> 0
                    GOTO RollBackTran



                 SET @nQtyBalance = @nQtyBalance - @cPickedQty


                 IF @nQtyBalance <= 0
                    BREAK



                    FETCH NEXT FROM CUR_PalletBuild_GroupBy_Loc INTO @cLot, @cFromLoc, @cFromID, @cPickedQty  --(JH01)

              END  --(JH01)
              CLOSE CUR_PalletBuild_GroupBy_Loc --(AL01)
              DEALLOCATE CUR_PalletBuild_GroupBy_Loc -- (AL01)

            FETCH NEXT FROM CUR_PalletBuild INTO @cPackDropID, @cSKU, @nPackedQty

         END
         CLOSE CUR_PalletBuild
         DEALLOCATE CUR_PalletBuild

         UPDATE dbo.PALLETDETAIL WITH (ROWLOCK) SET
            [Status] = '9'
         WHERE StorerKey = @cStorerKey
         AND   PalletKey = @cDropID
         AND   [Status] < '9'

         IF @@ERROR <> 0
        BEGIN
            SET @nErrNo = 110605
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UpdPLTDetFail
            GOTO RollBackTran
         END

         UPDATE dbo.PALLET WITH (ROWLOCK) SET
            [Status] = '9'
         WHERE StorerKey = @cStorerKey
         AND   PalletKey = @cDropID
         AND   [Status] < '9'

         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 110606
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UpdPLTFail
            GOTO RollBackTran
         END

         -- (ChewKP02)
         -- Print Label -- (ChewKP01)
--         IF EXISTS ( SELECT 1 FROM rdt.rdtReport WITH (NOLOCK)
--                     WHERE StorerKey = @cStorerKey
--                     AND ReportType = 'OBLIST' )
--         BEGIN
--            DECLARE @tOutBoundLis AS VariableTable
--            INSERT INTO @tOutBoundLis (Variable, Value) VALUES ( '@cDropID', @cDropID)
--
--            -- Print label
--            EXEC RDT.rdt_Print @nMobile, @nFunc, @cLangCode, 0, 1, '', @cStorerKey, '', @cPaperPrinter,
--               'OBLIST', -- Report type
--               @tOutBoundLis, -- Report params
--               'rdt_1641ExtUpdSP03',
--               @nErrNo  OUTPUT,
--               @cErrMsg OUTPUT
--
--            IF @nErrNo <> 0
--               GOTO RollBackTran
--         END
      END
   END

   -- (ChewKP02)
   IF @nStep = 6
   BEGIN
      IF @nInputKey = 1
      BEGIN

         -- (ChewKP02)
         IF EXISTS ( SELECT 1 FROM rdt.rdtReport WITH (NOLOCK)
                     WHERE StorerKey = @cStorerKey
                     AND ReportType = 'OBLIST' )
         BEGIN
            DECLARE @tOutBoundLis AS VariableTable
            INSERT INTO @tOutBoundLis (Variable, Value) VALUES ( '@cDropID', @cDropID)

            -- Print label
            EXEC RDT.rdt_Print @nMobile, @nFunc, @cLangCode, 0, 1, '', @cStorerKey, '', @cPaperPrinter,
               'OBLIST', -- Report type
               @tOutBoundLis, -- Report params
               'rdt_1641ExtUpdSP03',
               @nErrNo  OUTPUT,
               @cErrMsg OUTPUT

            IF @nErrNo <> 0
               GOTO RollBackTran

            --If a pallet is with serialno ends with ΓÇÿ9ΓÇÖ or ΓÇÿCΓÇÖ, then do not release the label out.
            --OPS will not print the pallet with 9/C serial no.
            IF NOT EXISTS ( SELECT 1
                            FROM dbo.PALLETDETAIL PLTD WITH (NOLOCK)
                            JOIN dbo.PackDetail PD WITH (NOLOCK)
                               ON ( PLTD.StorerKey = PD.StorerKey AND PLTD.CaseId = PD.LabelNo)
                            JOIN dbo.SerialNo SR WITH (NOLOCK)
                               ON ( PD.StorerKey = SR.StorerKey AND PD.PickSlipNo = SR.PickSlipNo
                               AND PD.CartonNo = SR.CartonNo AND PD.SKU = SR.SKU)
                            WHERE PLTD.PalletKey = @cDropID
                            AND   RIGHT( RTRIM( SR.SerialNo), 1) IN ( '9', 'C'))
            BEGIN
               -- If pallet contain only value from orders.userdefine10
               IF NOT EXISTS ( SELECT 1 FROM dbo.Orders WITH (NOLOCK)
                               WHERE StorerKey = @cStorerKey
                               AND   UserDefine10 NOT IN
                               (     SELECT DISTINCT Code
                                     FROM dbo.CODELKUP CLP WITH (NOLOCK)
                                     WHERE Listname = 'LGKRPLTLBL'
                                     AND   Storerkey = @cStorerKey)
                               AND   OrderKey IN
                               (     SELECT DISTINCT UserDefine02
                                     FROM dbo.PALLETDETAIL WITH (NOLOCK)
                                     WHERE PalletKey = @cDropID))
               BEGIN
                  SET @nSKU_Count = 0

                  SELECT @nSKU_Count = COUNT( DISTINCT PKD.SKU)
                  FROM dbo.PALLETDETAIL PLD WITH (NOLOCK)
                  JOIN dbo.PackDetail PKD WITH (NOLOCK)
                     ON ( PLD.StorerKey = PKD.StorerKey AND PLD.CaseId= PKD.LabelNo)
                  WHERE PLD.PalletKey = @cDropID

                  -- In this pallet, all pallet only have one SKU
                  IF @nSKU_Count = 1
                  BEGIN
                     DECLARE @tPalletLabel AS VariableTable
                     INSERT INTO @tPalletLabel (Variable, Value) VALUES ( '@cDropID', @cDropID)

                     -- Print label
                     EXEC RDT.rdt_Print @nMobile, @nFunc, @cLangCode, 0, 1, '', @cStorerKey, @cLabelPrinter, '',
                        'PLTSRLABEL', -- Report type
                        @tPalletLabel, -- Report params
                        'rdt_1641ExtUpdSP03',
                        @nErrNo  OUTPUT,
                        @cErrMsg OUTPUT

                     IF @nErrNo <> 0
                        GOTO RollBackTran
                  END
               END
            END
         END
      END
   END

   GOTO Quit

   RollBackTran:
      ROLLBACK TRAN rdt_1641ExtUpdSP03

   Quit:
      WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
         COMMIT TRAN rdt_1641ExtUpdSP03


Fail:
END

GO