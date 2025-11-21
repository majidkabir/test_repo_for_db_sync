SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_514ExtUpdSP01                                   */
/* Copyright: LFLogistics                                               */
/*                                                                      */
/* Purpose:                                                             */
/*                                                                      */
/* Called from: rdtfnc_Move_UCC                                         */
/*                                                                      */
/* Date        Rev  Author   Purposes                                   */
/* 2019-03-26  1.0  James    WMS-8352 Created                           */
/* 2024-10-28  1.1  ShaoAn   Extend Parameter                           */
/************************************************************************/

CREATE PROC [rdt].[rdt_514ExtUpdSP01] (
   @nMobile        INT, 
   @nFunc          INT, 
   @cLangCode      NVARCHAR( 3),  
   @nStep          INT, 
   @nInputKey      INT, 
   @cStorerKey     NVARCHAR( 15), 
   @cToID          NVARCHAR( 18), 
   @cToLoc         NVARCHAR( 10), 
   @cFromLoc       NVARCHAR( 10), 
   @cFromID        NVARCHAR( 18), 
   @cUCC1          NVARCHAR( 20), 
   @cUCC2          NVARCHAR( 20), 
   @cUCC3          NVARCHAR( 20), 
   @cUCC4          NVARCHAR( 20), 
   @cUCC5          NVARCHAR( 20), 
   @cUCC6          NVARCHAR( 20), 
   @cUCC7          NVARCHAR( 20), 
   @cUCC8          NVARCHAR( 20), 
   @cUCC9          NVARCHAR( 20), 
   @cUDF01         NVARCHAR( 30), 
   @nErrNo         INT           OUTPUT,  
   @cErrMsg        NVARCHAR( 20) OUTPUT
) AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @nTranCount INT
   SET @nTranCount = @@TRANCOUNT
   BEGIN TRAN
   SAVE TRAN rdt_514ExtUpdSP01   
   
   DECLARE @i     INT
   DECLARE @cUCC  NVARCHAR( 20)
   DECLARE @cPickSlipNo    NVARCHAR( 10)
   DECLARE @cToPickSlipNo  NVARCHAR( 10)
   DECLARE @cFromSKU       NVARCHAR( 20)
   DECLARE @nQTY           INT
   DECLARE @nFromQTY       INT
   DECLARE @nFromCartonNo  INT
   DECLARE @nToCartonNo    INT
   DECLARE @cFromLabelNo   NVARCHAR( 20)
   DECLARE @cToLabelNo     NVARCHAR( 20)
   DECLARE @cFromLabelLine NVARCHAR( 5)
   DECLARE @cToLabelLine   NVARCHAR( 5)
   DECLARE @cRefNo         NVARCHAR( 20)
   DECLARE @fStdGrossWGT   FLOAT
   DECLARE @fBoxWeight     FLOAT
   DECLARE @fModuleBoxWgt  FLOAT
   DECLARE @cDropID        NVARCHAR( 20)
   DECLARE @fWoodenCrateWgt   FLOAT
   DECLARE @fWeight           FLOAT
   DECLARE @fHeight           FLOAT
   DECLARE @fLength           FLOAT
   DECLARE @fWidth            FLOAT
   DECLARE @nUCCCount      INT
   DECLARE @nUCCQty        INT
   DECLARE @cUCCSKU        NVARCHAR( 20)
   DECLARE @cPallet        NVARCHAR( 20)

          
   IF @nStep = 2
   BEGIN
      IF @nInputKey = 1 -- ENTER
      BEGIN
         SET @cToLabelNo = @cToID
         SET @cFromLabelNo = @cFromID

         DECLARE @tUCC TABLE (UCC NVARCHAR( 20), i INT)
         INSERT INTO @tUCC (UCC, i) VALUES (@cUCC1, 1)
         INSERT INTO @tUCC (UCC, i) VALUES (@cUCC2, 2)
         INSERT INTO @tUCC (UCC, i) VALUES (@cUCC3, 3)
         INSERT INTO @tUCC (UCC, i) VALUES (@cUCC4, 4)
         INSERT INTO @tUCC (UCC, i) VALUES (@cUCC5, 5)
         INSERT INTO @tUCC (UCC, i) VALUES (@cUCC6, 6)
         INSERT INTO @tUCC (UCC, i) VALUES (@cUCC7, 7)
         INSERT INTO @tUCC (UCC, i) VALUES (@cUCC8, 8)
         INSERT INTO @tUCC (UCC, i) VALUES (@cUCC9, 9)
         --SELECT * FROM @tUCC
         --SELECT '@cFromLabelNo', @cFromLabelNo
         -- Check if any of the ucc do not have packdetail. 
         -- If don't have then no need do pallet merge. Quit
         IF EXISTS ( SELECT 1 FROM @tUCC t
                     WHERE UCC <> ''
                     AND   NOT EXISTS (
                           SELECT 1 FROM dbo.PackDetail PD WITH (NOLOCK)
                           WHERE PD.RefNo2 = t.UCC
                           AND   PD.StorerKey = @cStorerKey
                           AND   LabelNo = @cFromLabelNo))
            GOTO RollBackTran

         SELECT TOP 1 @cToPickSlipNo = PickSlipNo,
                      @nToCartonNo = CartonNo,
                      @cRefNo = RefNo
         FROM dbo.PackDetail WITH (NOLOCK)
         WHERE StorerKey = @cStorerKey
         AND   LabelNo = @cToLabelNo
         ORDER BY 1

         SET @i = 1
         WHILE @i < 10
         BEGIN
            IF @i = 1 SET @cUCC = @cUCC1
            IF @i = 2 SET @cUCC = @cUCC2
            IF @i = 3 SET @cUCC = @cUCC3
            IF @i = 4 SET @cUCC = @cUCC4
            IF @i = 5 SET @cUCC = @cUCC5
            IF @i = 6 SET @cUCC = @cUCC6
            IF @i = 7 SET @cUCC = @cUCC7
            IF @i = 8 SET @cUCC = @cUCC8
            IF @i = 9 SET @cUCC = @cUCC9
         
            IF @cUCC <> ''
            BEGIN
               SET @nFromCartonNo = 0
               SELECT @cPickSlipNo = PickSlipNo,
                      @nFromCartonNo = CartonNo
               FROM dbo.PackDetail WITH (NOLOCK)
               WHERE StorerKey = @cStorerKey
               AND   RefNo2 = @cUCC
               AND   LabelNo = @cFromLabelNo

               -- Loop from PackDetail lines
               DECLARE @curPD CURSOR
               SET @curPD = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
               SELECT SKU, LabelLine, Qty, DropID
               FROM dbo.PackDetail PD WITH (NOLOCK)
               WHERE PD.PickSlipNo = @cPickSlipNo
                  AND PD.RefNo2 = @cUCC
                  AND PD.StorerKey = @cStorerKey
                  AND PD.LabelNo = @cFromLabelNo
               OPEN @curPD
               FETCH NEXT FROM @curPD INTO @cFromSKU, @cFromLabelLine, @nFromQty, @cDropID
               WHILE @@FETCH_STATUS = 0
               BEGIN
                  -- Find TO PackDetail line
                  SET @cToLabelLine = ''
                  SELECT @cToLabelLine = RIGHT( '00000' + CAST( CAST( IsNULL( MAX( LabelLine), 0) AS INT) + 1 AS NVARCHAR( 5)), 5)
                  FROM dbo.PackDetail (NOLOCK)
                  WHERE Pickslipno = @cToPickSlipNo
                     AND CartonNo = @nToCartonNo
                     AND LabelNo = @cToLabelNo

                  -- Insert PackDetail
                  INSERT INTO dbo.PackDetail
                     (PickSlipNo, CartonNo, LabelNo, LabelLine, StorerKey, SKU, QTY, RefNo, DropID, RefNo2, 
                     AddWho, AddDate, EditWho, EditDate)
                  VALUES
                     (@cToPickSlipNo, @nToCartonNo, @cToLabelNo, @cToLabelLine, @cStorerKey, @cFromSKU, @nFromQty, @cRefNo, @cDropID, @cUCC,
                     LEFT( 'rdt.' + SUSER_SNAME(), 18), GETDATE(), 
                     LEFT( 'rdt.' + SUSER_SNAME(), 18), GETDATE())

                  IF @@ERROR <> 0
                  BEGIN
                     SET @nErrNo = 136701
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'InsPackDtlFail'
                     GOTO RollBackTran
                  END

                     -- Delete PackDetail
                  DELETE PackDetail
                  WHERE PickSlipNo = @cPickSlipNo
                     AND CartonNo = @nFromCartonNo
                     AND LabelNo = @cFromLabelNo
                     AND LabelLine = @cFromLabelLine

                  IF @@ERROR <> 0
                  BEGIN
                     SET @nErrNo = 136702
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --DelPackDtlFail
                     GOTO RollBackTran
                  END

                  FETCH NEXT FROM @curPD INTO @cFromSKU, @cFromLabelLine, @nFromQty, @cDropID
               END
               CLOSE @curPD
               DEALLOCATE @curPD
            END

            SET @i = @i + 1
         END

         -- From ID
         SET @fWeight = 0
         SET @nUCCCount = 0
         SET @fBoxWeight = 0
         SET @cUCC = ''
         SET @cPallet = ''
         SET @fHeight = 0
         SET @fLength = 0
         SET @fWidth = 0

         SET @curPD = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
         SELECT RefNo2
         FROM dbo.PackDetail WITH (NOLOCK)
         WHERE StorerKey = @cStorerKey
         AND   LabelNo = @cFromID
         OPEN @curPD
         FETCH NEXT FROM @curPD INTO @cUCC
         WHILE @@FETCH_STATUS = 0
         BEGIN
            SELECT @cUCCSKU = SKU, 
                   @nUCCQty = Qty
            FROM dbo.UCC WITH (NOLOCK) 
            WHERE Storerkey = @cStorerKey
            AND   UCCNo = @cUCC--40
            ORDER BY 1

            SELECT @fStdGrossWGT = STDGROSSWGT
            FROM dbo.SKU WITH (NOLOCK)
            WHERE StorerKey = @cStorerKey
            AND   SKU = @cUCCSKU

            SET @fBoxWeight = @fBoxWeight + ( @fStdGrossWGT * @nUCCQty)

            SET @nUCCCount = @nUCCCount + 1

            FETCH NEXT FROM @curPD INTO @cUCC
         END
         CLOSE @curPD
         DEALLOCATE @curPD

         --Pallet.length = Codelkup. Short
         --Pallet.Weight = Codelkup. Long
         --Pallet.height = Codelkup. Notes
         --BoxWgt = UDF03
         --WoodenCrateWgt = UDF04
         SELECT @fModuleBoxWgt = UDF03,
                @fWoodenCrateWgt = UDF04,
                @fHeight = Notes,
                @fLength = Short,        
                @fWidth = Long
         FROM dbo.CODELKUP WITH (NOLOCK) 
         WHERE ListName = 'FABWeight'
         AND   @nUCCCount BETWEEN UDF01 AND UDF02

         SET @fWeight = @fBoxWeight + ( ( @fModuleBoxWgt * @nUCCCount) + @fWoodenCrateWgt)

         SELECT TOP 1 @cPallet = RefNo
         FROM dbo.PackDetail WITH (NOLOCK)
         WHERE StorerKey = @cStorerKey
         AND   LabelNo = @cFromID

         UPDATE dbo.PALLET WITH (ROWLOCK) SET
            GrossWgt = @fWeight,
            Height = @fHeight,
            Length = @fLength,
            Width = @fWidth
         WHERE PalletKey = @cPallet

         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 136703
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Upd Pallet Err
            GOTO RollBackTran
         END

         -- To ID
         SET @fWeight = 0
         SET @nUCCCount = 0
         SET @fBoxWeight = 0
         SET @cUCC = ''
         SET @cPallet = ''
         SET @fHeight = 0
         SET @fLength = 0
         SET @fWidth = 0

         SET @curPD = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
         SELECT RefNo2
         FROM dbo.PackDetail WITH (NOLOCK)
         WHERE StorerKey = @cStorerKey
         AND   LabelNo = @cToID
         OPEN @curPD
         FETCH NEXT FROM @curPD INTO @cUCC
         WHILE @@FETCH_STATUS = 0
         BEGIN
            SELECT @cUCCSKU = SKU, 
                   @nUCCQty = Qty
            FROM dbo.UCC WITH (NOLOCK) 
            WHERE Storerkey = @cStorerKey
            AND   UCCNo = @cUCC--40
            ORDER BY 1

            SELECT @fStdGrossWGT = STDGROSSWGT
            FROM dbo.SKU WITH (NOLOCK)
            WHERE StorerKey = @cStorerKey
            AND   SKU = @cUCCSKU

            SET @fBoxWeight = @fBoxWeight + ( @fStdGrossWGT * @nUCCQty)

            SET @nUCCCount = @nUCCCount + 1

            FETCH NEXT FROM @curPD INTO @cUCC
         END
         CLOSE @curPD
         DEALLOCATE @curPD

         --Pallet.length = Codelkup. Short
         --Pallet.Weight = Codelkup. Long
         --Pallet.height = Codelkup. Notes
         --BoxWgt = UDF03
         --WoodenCrateWgt = UDF04
         SELECT @fModuleBoxWgt = UDF03,
                @fWoodenCrateWgt = UDF04,
                @fHeight = Notes,
                @fLength = Short,        
                @fWidth = Long
         FROM dbo.CODELKUP WITH (NOLOCK) 
         WHERE ListName = 'FABWeight'
         AND   @nUCCCount BETWEEN UDF01 AND UDF02

         SET @fWeight = @fBoxWeight + ( ( @fModuleBoxWgt * @nUCCCount) + @fWoodenCrateWgt)

         SELECT TOP 1 @cPallet = RefNo
         FROM dbo.PackDetail WITH (NOLOCK)
         WHERE StorerKey = @cStorerKey
         AND   LabelNo = @cToID

         UPDATE dbo.PALLET WITH (ROWLOCK) SET
            GrossWgt = @fWeight,
            Height = @fHeight,
            Length = @fLength,
            Width = @fWidth
         WHERE PalletKey = @cPallet

         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 136704
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --DelPackDtlFail
            GOTO RollBackTran
         END

      END
   END



   GOTO Quit
   
RollBackTran:
   ROLLBACK TRAN rdt_514ExtUpdSP01 -- Only rollback change made here
Quit:
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
      COMMIT TRAN   
END


GO