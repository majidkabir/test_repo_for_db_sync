SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_Pack_LVSUSA_Confirm                             */
/* Copyright      : Maersk                                              */
/*                                                                      */
/* Purpose: Confirm logic for LVSUSA Packing                            */
/*                                                                      */
/* Date       Rev  Author      Purposes                                 */
/* 2024-10-23 1.0  JCH507      FCR-946 Created                          */
/************************************************************************/

CREATE   PROC [RDT].[rdt_Pack_LVSUSA_Confirm] (
    @nMobile         INT
   ,@nFunc           INT
   ,@cLangCode       NVARCHAR( 3)
   ,@nStep           INT
   ,@nInputKey       INT
   ,@cFacility       NVARCHAR( 5)
   ,@cStorerKey      NVARCHAR( 15)
   ,@cType           NVARCHAR( 10) -- fcr-946 NEW, MERGE
   ,@cMasterLabelNo  NVARCHAR( 20) --fcr-946
   ,@cSKU            NVARCHAR( 20) 
   ,@nQTY            INT
   ,@cUCCNo          NVARCHAR( 20) 
   ,@cSerialNo       NVARCHAR( 30) 
   ,@nSerialQTY      INT
   ,@cPackDtlRefNo   NVARCHAR( 20)
   ,@cPackDtlRefNo2  NVARCHAR( 20)
   ,@cPackDtlUPC     NVARCHAR( 30)
   ,@cPackDtlDropID  NVARCHAR( 20)
   ,@nCartonNo       INT           OUTPUT
   ,@cLabelNo        NVARCHAR( 20) OUTPUT
   ,@nErrNo          INT           OUTPUT
   ,@cErrMsg         NVARCHAR(250) OUTPUT
   ,@nBulkSNO        INT
   ,@nBulkSNOQTY     INT
   ,@cPackData1      NVARCHAR( 30)
   ,@cPackData2      NVARCHAR( 30)
   ,@cPackData3      NVARCHAR( 30)
   ,@nUseStandard    INT = 0
)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF
   
   DECLARE @cSQL           NVARCHAR(MAX)
   DECLARE @cSQLParam      NVARCHAR(MAX)
   DECLARE @cConfirmSP     NVARCHAR(20) = ''

   -- Get storer configure
   IF @nUseStandard = 0
   BEGIN
      SET @cConfirmSP = rdt.RDTGetConfig( @nFunc, 'ConfirmSP', @cStorerKey)
      IF @cConfirmSP = '0'
         SET @cConfirmSP = ''
   END
   
   /***********************************************************************************************
                                              Custom confirm
   ***********************************************************************************************/
   -- Custom logic
   IF @cConfirmSP <> '' 
   BEGIN
      IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cConfirmSP AND type = 'P')
      BEGIN
         SET @cSQL = 'EXEC rdt.' + RTRIM( @cConfirmSP) +
            ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cType, @cMasterLabelNo, ' +
            ' @cSKU, @nQTY, @cUCCNo, @cSerialNo, @nSerialQTY, @cPackDtlRefNo, @cPackDtlRefNo2, @cPackDtlUPC, @cPackDtlDropID, ' + 
            ' @nCartonNo OUTPUT, @cLabelNo OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT, ' + 
            ' @nBulkSNO, @nBulkSNOQTY, @cPackData1, @cPackData2, @cPackData3 '

         SET @cSQLParam =
            ' @nMobile        INT,           ' + 
            ' @nFunc          INT,           ' + 
            ' @cLangCode      NVARCHAR( 3),  ' + 
            ' @nStep          INT,           ' + 
            ' @nInputKey      INT,           ' + 
            ' @cFacility      NVARCHAR( 5),  ' + 
            ' @cStorerKey     NVARCHAR( 15), ' +   
            ' @cType          NVARCHAR( 10), ' +   
            ' @cMasterLabelNo NVARCHAR( 20), ' +   
            ' @cSKU           NVARCHAR( 20), ' +   
            ' @nQTY           INT,           ' + 
            ' @cUCCNo         NVARCHAR( 20), ' + 
            ' @cSerialNo      NVARCHAR( 30), ' +   
            ' @nSerialQTY     INT,           ' + 
            ' @cPackDtlRefNo  NVARCHAR( 20), ' + 
            ' @cPackDtlRefNo2 NVARCHAR( 20), ' + 
            ' @cPackDtlUPC    NVARCHAR( 30), ' + 
            ' @cPackDtlDropID NVARCHAR( 20), ' + 
            ' @nCartonNo      INT           OUTPUT, ' + 
            ' @cLabelNo       NVARCHAR( 20) OUTPUT, ' + 
            ' @nErrNo         INT           OUTPUT, ' + 
            ' @cErrMsg        NVARCHAR(250) OUTPUT, ' + 
            ' @nBulkSNO       INT           , ' + 
            ' @nBulkSNOQTY    INT           , ' + 
            ' @cPackData1     NVARCHAR( 30) , ' + 
            ' @cPackData2     NVARCHAR( 30) , ' + 
            ' @cPackData3     NVARCHAR( 30)   '
            
         EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
            @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cType, @cMasterLabelNo, 
            @cSKU, @nQTY, @cUCCNo, @cSerialNo, @nSerialQTY, @cPackDtlRefNo, @cPackDtlRefNo2, @cPackDtlUPC, @cPackDtlDropID, 
            @nCartonNo OUTPUT, @cLabelNo OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT, 
            @nBulkSNO, @nBulkSNOQTY, @cPackData1, @cPackData2, @cPackData3

         GOTO Quit
      END
   END

   /***********************************************************************************************
                                             Standard confirm
   ***********************************************************************************************/
   DECLARE @bSuccess    INT
   DECLARE @cLabelLine  NVARCHAR( 5)
   DECLARE @cNewLine    NVARCHAR( 1)
   DECLARE @cNewCarton  NVARCHAR( 1)
   DECLARE @cDropID     NVARCHAR( 20) = ''
   DECLARE @cRefNo      NVARCHAR( 20) = ''
   DECLARE @cRefNo2     NVARCHAR( 30) = ''
   DECLARE @cUPC        NVARCHAR( 30) = ''  


   
   DECLARE @cGenLabelNo_SP       NVARCHAR( 20)
   DECLARE @cPackDetailCartonID  NVARCHAR( 20)
   DECLARE @cPackByFromDropID    NVARCHAR( 1)

   DECLARE @cPSNO             NVARCHAR( 10)
   DECLARE @nFromCartonNo     INT
   DECLARE @cFromLabeLLine    NVARCHAR( 5)
   DECLARE @nFromQty          INT
   DECLARE @nNewCartonNo      INT
   DECLARE @nMasterPackQty    INT
   DECLARE @nBalQty           INT
   DECLARE @nAdjustQty        INT
   DECLARE @nMaxCount         INT
   DECLARE @nRowNo            INT

   DECLARE @cPickDetailPSNO     NVARCHAR( 10)
   DECLARE @cPickDetailLabelNo  NVARCHAR( 20)
   DECLARE @cPickDetailSKU      NVARCHAR( 20)
   DECLARE @nPickDetailQty      INT

   DECLARE @cMasterCartonType    NVARCHAR( 10)
   DECLARE @fMasterCartonLength  FLOAT
   DECLARE @fMasterCartonWidth   FLOAT
   DECLARE @fMasterCartonHeight  FLOAT
   DECLARE @fMasterCartonCube    FLOAT

   DECLARE @cTempPSNO      NVARCHAR( 10)
   DECLARE @cTempLabelNo   NVARCHAR( 20)
   DECLARE @cTempSKU       NVARCHAR( 20)
   DECLARE @nTempQty       INT
   DECLARE @nTempCartonNo  INT

   DECLARE @nTranCount INT
   DECLARE @bDebugFlag BINARY = 0

   DECLARE @tMoveLog TABLE
   (
      RowNumber   INT IDENTITY,
      PickSlipNo  NVARCHAR( 10) NOT NULL,
      LabelNo     NVARCHAR( 20) NOT NULL,
      SKU         NVARCHAR( 20) NOT NULL,
      MoveQty     INT
   )

   DECLARE @tPSNO TABLE
   (
      RowNumber   INT IDENTITY NOT NULL,
      PickSlipNo  NVARCHAR(20) NOT NULL
   )

   SET @nErrNo = 0

   -- Generic Validation
   IF @cType NOT IN ('NEW','MERGE')
   BEGIN
      SET @nErrNo = 227601
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Inv type
      GOTO Quit
   END

   SELECT @nMasterPackQty = ISNULL( SUM(Qty),0)
   FROM PackDetail WITH (NOLOCK)
   WHERE Storerkey = @cStorerKey
      AND SKU = @cSKU
      AND LabelNo = @cMasterLabelNo
      
   --Log the PSNO under source and dest cartons
   INSERT INTO @tPSNO (PickSlipNO)
   SELECT DISTINCT PickSlipNO
   FROM PackDetail  WITH (NOLOCK)
   WHERE StorerKey = @cStorerKey
      AND LabelNo IN (@cLabelNo, @cMasterLabelNo)
   ORDER BY PickSlipNo

   IF @cType = 'NEW'
   BEGIN
      IF @bDebugFlag = 1
         SELECT 'Type = NEW'

      --The input qty cannot be greater than the qty left in the original label no
      IF @nQty > @nMasterPackQty
      BEGIN
         SET @nErrNo = 227611
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Qty too great
         GOTO Quit
      END

      IF NOT EXISTS (SELECT 1 FROM PackDetail WITH (NOLOCK)
                  WHERE LabelNo = @cMasterLabelNo
                     AND SKU = @cSKU)
      BEGIN
         SET @nErrNo = 227602
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --SKU not in master label no
         GOTO Quit
      END

      --Generate LabelNo if it is new carton
      IF @cLabelNo = ''
      BEGIN
         IF @bDebugFlag = 1
            SELECT 'Generate CartonNo'

         SET @cGenLabelNo_SP = rdt.RDTGetConfig( @nFunc, 'GenLabelNo_SP', @cStorerkey)
         IF @cGenLabelNo_SP = '0'
            SET @cGenLabelNo_SP = ''

         IF @cGenLabelNo_SP <> ''
         BEGIN
            IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cGenLabelNo_SP AND type = 'P')  
            BEGIN
               SELECT TOP 1 @cPSNO = PickSlipNo
               FROM dbo.PackDetail WITH(NOLOCK)
               WHERE StorerKey = @cStorerKey
                  AND LabelNo = @cMasterLabelNo
               ORDER BY PickSlipNo
               SET @cSQL = 'EXEC dbo.' + RTRIM( @cGenLabelNo_SP) +
                  ' @cPSNO, ' +  --fcr-946
                  ' @nCartonNo,   ' +  
                  ' @cLabelNo     OUTPUT '  
               SET @cSQLParam =
                  ' @cPSNO  NVARCHAR(10),       ' +  --fcr-946
                  ' @nCartonNo    INT,                ' +  
                  ' @cLabelNo     NVARCHAR(20) OUTPUT '  
               EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
                  @cPSNO, --fcr-946
                  @nCartonNo, 
                  @cLabelNo OUTPUT
            END
         END
         ELSE
         BEGIN   
            EXEC isp_GenUCCLabelNo
               @cStorerKey,
               @cLabelNo      OUTPUT, 
               @bSuccess      OUTPUT,
               @nErrNo        OUTPUT,
               @cErrMsg       OUTPUT
            IF @nErrNo <> 0
            BEGIN
               SET @nErrNo = 100402
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --GenLabelNoFail
               GOTO RollBackTran
            END
         END

         IF @cLabelNo = ''
         BEGIN
            SET @nErrNo = 227603
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --GenLabelNoFail
            GOTO RollBackTran
         END

         IF @bDebugFlag = 1
            SELECT 'Label No Generated', @cLabelNo AS NewLabelNo

         SET @cLabelLine = ''   
         SET @cNewLine = 'Y'
         SET @cNewCarton = 'Y'
         --SET @nCartonNo = 0
      END -- Generate new lableno

      SET @nBalQty = @nQty

      SET @nTranCount = @@TRANCOUNT
      BEGIN TRAN  -- Begin our own transaction
      SAVE TRAN rdt_Pack_LVSUSA_Confirm -- For rollback or commit only our own transaction

      WHILE @nBalQTY > 0
      BEGIN
         SELECT TOP 1
            @cPSNO            = PickSlipNo,
            @nFromCartonNo    = CartonNo,
            @cFromLabelLine   = LabelLine,
            @nFromQTY         = Qty
         FROM PackDetail WITH (NOLOCK)
         WHERE StorerKey = @cStorerKey
            AND LabelNo = @cMasterLabelNo
            AND SKU = @cSKU
         ORDER BY Qty DESC, PickSlipNo

         IF @bDebugFlag = 1
         BEGIN
            SELECT 'Handling PackDetail'
            SELECT @cPSNO AS PSNO, @cMasterLabelNo AS MasterLableNo, @nFromCartonNo AS MasterCartonNo, @cSKU AS SKU, 
                     @cFromLabelLine AS FromLabelLine, @nFromQty AS FromQty, @cLabelNo AS ToLabelNo
         END
         
         -- Handle master carton start
         IF @bDebugFlag = 1
            SELECT 'Start to handle MasterLabel'

         IF @nBalQty < @nFromQTY
         BEGIN
            IF @bDebugFlag= 1
               SELECT 'Update Master Carton PackDetail'

            UPDATE PackDetail WITH (ROWLOCK)
            SET Qty = @nFromQty - @nBalQty
            WHERE PickSlipNo = @cPSNO
               AND CartonNo = @nFromCartonNo
               AND LabelNo = @cMasterLabelNo
               AND LabelLine = @cFromLabelLine

            IF @@Error <> 0
            BEGIN
               SET @nErrNo = 227604
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Upd PackDetail Fail
               GOTO RollBackTran
            END

            SET @nAdjustQty = @nBalQTY

            IF @bDebugFLag = 1
               SELECT '@BalQty < @FromQty', @nAdjustQty AS AdjustQty
         END -- BalQty < FromQty
         ELSE
         BEGIN
            IF @bDebugFlag= 1
               SELECT 'Delete Master Carton Pack Detail'

            SET @nAdjustQty = @nFromQty

            DELETE PackDetail WITH (ROWLOCK)
            WHERE PickSlipNo = @cPSNO
               AND CartonNo = @nFromCartonNo
               AND LabelNo = @cMasterLabelNo
               AND LabelLine = @cFromLabelLine
            IF @@Error <> 0
            BEGIN
               SET @nErrNo = 227604
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Del PackDetail Fail
               GOTO RollBackTran
            END

            IF @bDebugFlag = 1
               SELECT '@BalQty >= @FromQty', @nAdjustQty AS AdjustQty, @nBalQty AS LeftBalQty
         END--BalQty >= FromQty

         -- Handle Master Carton END
         IF @bDebugFlag = 1
            SELECT 'Start to handle ToLabel'

         --Handle To Carton Start
         -- If new carton, or carton not exists under the current PickSlipNo
         IF @cNewCarton = 'Y' OR NOT EXISTS (SELECT 1 FROM PackDetail WITH (NOLOCK)
                                             WHERE PickSlipNO = @cPSNO
                                                AND LabelNo = @cLabelNo)
         BEGIN
            IF @bDebugFlag = 1
               SELECT 'Insert new carton packdetail and packinfo'

            --PackdetailAdd trigger will handle cartonNo and LabelLine            
            SELECT @nNewCartonNo = COALESCE(MAX(CartonNo),0) + 1
            FROM PackDetail WITH (NOLOCK)
            WHERE PickSlipNo = @cPSNO

            IF @bDebugFLag = 1
               SELECT 'Get New CartonNo', @nNewCartonNo AS NewCartonNo

            INSERT INTO PackDetail (PickSlipNo, CartonNo, LabelNo, LabelLine, StorerKey, SKU, Qty, DropID)
            VALUES (@cPSNO, @nNewCartonNo, @cLabelNo,'00001', @cStorerKey, @cSKU, @nAdjustQty, @cLabelNo)
            
            IF @@Error <> 0
            BEGIN
               SET @nErrNo = 227606
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Ins PackDetail Fail
               GOTO RollBackTran
            END

            INSERT INTO PackInfo (PickSlipNO, CartonNo, Qty, RefNo)
            VALUES (@cPSNO, @nNewCartonNo, @nAdjustQty, @cLabelNo)

            IF @@Error <> 0
            BEGIN
               SET @nErrNo = 227607
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Ins PackInfo Fail
               GOTO RollBackTran
            END
         END -- New Carton
         ELSE
         BEGIN-- Existing carton existing label line
            IF EXISTS (SELECT 1 FROM PackDetail WITH (NOLOCK)
                        WHERE PickSlipNO = @cPSNO
                           AND LabelNo = @cLabelNo
                           AND SKU = @cSKU)
            BEGIN
               IF @bDebugFlag = 1
                  SELECT 'Add Qty to existing PackDetail'

               UPDATE PackDetail WITH (ROWLOCK)
               SET Qty = Qty + @nAdjustQty
               WHERE PickSlipNo = @cPSNO
                  AND LabelNo = @cLabelNo
                  AND SKU = @cSKU

               IF @@Error <> 0
               BEGIN
                  SET @nErrNo = 227608
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Upd Packdetail Fail
                  GOTO RollBackTran
               END
            END -- Update existing toCarton record
            ELSE--Add new label line
            BEGIN
               IF @bDebugFlag = 1
                  SELECT 'Add new label line to the existing carton'

               INSERT INTO PackDetail (PickSlipNo, CartonNo, LabelNo, LabelLine, StorerKey, SKU, Qty, DropID)
               SELECT @cPSNO,
                     MAX(CartonNo),
                     @cLabelNo,
                     RIGHT( '00000' + CAST( CAST( ISNULL( MAX( LabelLine), 0) AS INT) + 1 AS NVARCHAR( 5)), 5),
                     @cStorerKey,
                     @cSKU,
                     @nQty,
                     @cLabelNo
               FROM PackDetail WITH (NOLOCK)
               WHERE PickSlipNo = @cPSNO
                  AND LabelNo = @cLabelNo

               IF @@Error <> 0
               BEGIN
                  SET @nErrNo = 227609
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Ins PackDetail Fail
                  GOTO RollBackTran
               END
            END-- Add new label line
         END -- Existing Carton

         -- Log the label adjustment for pickdetail handling
         BEGIN TRY
            MERGE INTO @tMoveLog AS a
            USING (SELECT @cPSNO AS PickSlipNo, @cMasterLabelNo AS LabelNo, @cSKU AS SKU, -@nAdjustQty AS MoveQty) AS b
            ON (a.PickSlipNo = b.PickSlipNo AND a.LabelNo = b.LabelNo AND a.SKU = b.SKU)
            WHEN MATCHED THEN
               UPDATE SET a.MoveQty = a.MoveQty + b.MoveQty
            WHEN NOT MATCHED THEN
               INSERT (PickSlipNo, LabelNo, SKU, MoveQty)
               VALUES (b.PickSlipNo, b.LabelNo, b.SKU, b.MoveQty);

            MERGE INTO @tMoveLog AS a
            USING (SELECT @cPSNO AS PickSlipNo, @cLabelNo AS LabelNo, @cSKU AS SKU, @nAdjustQty AS MoveQty) AS b
            ON (a.PickSlipNo = b.PickSlipNo AND a.LabelNo = b.LabelNo AND a.SKU = b.SKU)
            WHEN MATCHED THEN
               UPDATE SET a.MoveQty = a.MoveQty + b.MoveQty
            WHEN NOT MATCHED THEN
               INSERT (PickSlipNo, LabelNo, SKU, MoveQty)
               VALUES (b.PickSlipNo, b.LabelNo, b.SKU, b.MoveQty);
         END TRY
         BEGIN CATCH
            SET @nErrNo = 227610
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Ins PackDetail Fail
            GOTO RollBackTran
         END CATCH  

         IF @bDebugFlag = 1
         BEGIN
            SELECT 'Get @tMoveLog'
            SELECT * FROM @tMoveLog
         END
         --Handle toCarton End

         SET @nBalQTY = @nBalQty - @nFromQty

      END -- PackDetail while end

      --PickDetail handling Start
      IF @bDebugFlag = 1
         SELECT 'Handling PickDetail (NEW)'

      WHILE 1 = 1
      BEGIN
         SELECT TOP 1 @nRowNo = RowNumber, 
               @cPickDetailPSNO = PickSlipNo,
               @cPickDetailLabelNo = LabelNo,
               @nPickDetailQty = MoveQty
         FROM @tMoveLog
         ORDER BY MoveQty

         IF @@ROWCOUNT = 0
         BEGIN
            IF @bDebugFlag = 1
               SELECT 'No records in @tMoveLog, Exit'
            BREAK -- All records were handled
         END

         IF @bDebugFlag = 1
            SELECT 'Current Handling PickDetail', @nRowNo AS RowNo, @cPickDetailPSNO AS PSNO, @cPickDetailLabelNo AS LabelNo, @cSKU AS SKU, @nPickDetailQty AS Qty

         EXEC rdt.rdt_Pack_LVSUSA_PickDetailConfirm @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey
         ,@cPickDetailPSNO
         ,'' --FromDropID
         ,@cSKU
         ,@nPickDetailQty
         ,@nCartonNo             OUTPUT
         ,@cPickDetailLabelNo    OUTPUT 
         ,@nErrNo                OUTPUT
         ,@cErrMsg               OUTPUT
         
         IF @nErrNo <> 0
         BEGIN
            SET @nErrNo = 227612
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Handle PickDetail Fail
            GOTO RollBackTran
         END

         DELETE @tMoveLog WHERE RowNumber = @nRowNo

         IF @bDebugFlag = 1
            SELECT 'Delete RowNumber: ' + CAST(@nRowNo AS NVARCHAR(3)) + ' In @tMoveLog'
      END -- PickDetail while

      --PickDetail handling End

      --Reorganize the label no in the cases start
      ;WITH LabelRenumbered AS (
      SELECT PickSlipNo, 
             CartonNo, 
             LabelNo, 
             LabelLine, 
             ROW_NUMBER() OVER (PARTITION BY PickSlipNo, CartonNo, LabelNo ORDER BY LabelLine) AS NewLabelLine
      FROM PackDetail WITH (NOLOCK)
         WHERE LabelNo IN (@cMasterLabelNo, @cLabelNo)
            AND StorerKey = @cStorerKey
      )

      UPDATE PackDetail
         SET LabelLine = RIGHT(REPLICATE('0',5)+CAST(LabelRenumbered.NewLabelLine AS VARCHAR), 5)
      FROM LabelRenumbered
      WHERE PackDetail.PickSlipNo = LabelRenumbered.PickSlipNo
         AND PackDetail.CartonNo = LabelRenumbered.CartonNo
         AND PackDetail.LabelNo = LabelRenumbered.LabelNo
         AND PackDetail.LabelLine = LabelRenumbered.LabelLine;
      --Reorganize the label no in the cases end   
   END -- NEW

   IF @cType = 'MERGE'
   BEGIN
      IF @bDebugFlag = 1
         SELECT 'Type = MERGE'
      -- Valid if from carton is equal to master carton  
      IF @cMasterLabelNo = @cLabelNo
      BEGIN
         SET @nErrNo = 227623
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Invalid From Carton No
         GOTO RollBackTran
      END

      -- Log the label adjustment for from carton
      BEGIN TRY
         MERGE INTO @tMoveLog AS a
         USING (SELECT PickSlipNO, LabelNo, SKU, -Qty AS MoveQty 
                FROM PackDetail WITH (NOLOCK)
                WHERE StorerKey = @cStorerKey
                  AND LabelNo = @cLabelNo) AS b
         ON (a.PickSlipNo = b.PickSlipNo AND a.LabelNo = b.LabelNo AND a.SKU = b.SKU)
         WHEN MATCHED THEN
            UPDATE SET a.MoveQty = a.MoveQty + b.MoveQty
         WHEN NOT MATCHED THEN
            INSERT (PickSlipNo, LabelNo, SKU, MoveQty)
            VALUES (b.PickSlipNo, b.LabelNo, b.SKU, b.MoveQty);

         MERGE INTO @tMoveLog AS a
         USING (SELECT PickSlipNO, @cMasterLabelNo AS LabelNo, SKU, Qty AS MoveQty 
                FROM PackDetail WITH (NOLOCK)
                WHERE StorerKey = @cStorerKey
                  AND LabelNo = @cLabelNo) AS b
         ON (a.PickSlipNo = b.PickSlipNo AND a.LabelNo = b.LabelNo AND a.SKU = b.SKU)
         WHEN MATCHED THEN
            UPDATE SET a.MoveQty = a.MoveQty + b.MoveQty
         WHEN NOT MATCHED THEN
            INSERT (PickSlipNo, LabelNo, SKU, MoveQty)
            VALUES (b.PickSlipNo, b.LabelNo, b.SKU, b.MoveQty);
      END TRY
      BEGIN CATCH
         SET @nErrNo = 227613
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Ins @tMoveLog Fail
         GOTO RollBackTran
      END CATCH

      IF @bDebugFlag = 1
      BEGIN
         SELECT 'Get @tMoveLog'
         SELECT * FROM @tMoveLog
      END

      SET @nTranCount = @@TRANCOUNT
      BEGIN TRAN  -- Begin our own transaction
      SAVE TRAN rdt_Pack_LVSUSA_Confirm -- For rollback or commit only our own transaction

      --PackDetail Handling (Merge)

      IF @bDebugFlag = 1
         SELECT 'Handling Source PackDetail'

      -- Delete From Carton's PackDetail
      IF @bDebugFlag = 1
         SELECT 'Delete source carton packdetail (Merge)'
      BEGIN TRY
         DELETE FROM dbo.PackDetail WHERE LabelNo = @cLabelNo
      END TRY
      BEGIN CATCH
         SET @nErrNo = 227616
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Delete PackDetail Fail
         GOTO RollBackTran
      END CATCH

      IF @bDebugFlag = 1
         SELECT 'Handling Source Carton PickDetail (Merge)'

      --Similar to repack, update fromcarton pickdetail caseid to empty
      IF @bDebugFlag = 1
         SELECT 'Empty CaseID in PickDetail'
      BEGIN TRY
         UPDATE dbo.PickDetail WITH (ROWLOCK)
         SET 
            CaseID = '', 
            EditDate = GETDATE(), 
            EditWho  = SUSER_SNAME(), 
            TrafficCop = NULL
         WHERE StorerKey = @cStorerKey
            AND CaseID = @cLabelNo
      END TRY
      BEGIN CATCH
         SET @nErrNo = 227618
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Empty PickDetail CaseID Fail
         GOTO RollBackTran
      END CATCH

      IF @bDebugFlag = 1
         SELECT 'Merge Master Carton Pack/Pick data'

      --Get Master carton info 

      SELECT TOP 1
         @cMasterCartonType = CartonType,
         @fMasterCartonLength = Length,
         @fMasterCartonWidth = Width,
         @fMasterCartonHeight = Height,
         @fMasterCartonCube = Length * Width * Height
      FROM PackInfo PI WITH (NOLOCK)
      JOIN PackDetail PD WITH (NOLOCK)
         ON PI.PickSlipNo = PD.PickSlipNo
         AND PI.CartonNo = PD.CartonNo
      WHERE PD.StorerKey = @cStorerKey
         AND PD.LabelNo = @cMasterLabelNo
      
      IF @bDebugFlag = 1
      BEGIN
         SELECT 'Get Master Carton PackInfo'
         SELECT 'Delete Master carton packinfo'
      END

      -- Delete Master Carton PackInfo (Will insert back after packdetail ready)
      BEGIN TRY
         DELETE PI
         FROM PackInfo PI
         JOIN PackDetail PD
            ON PI.PickSlipNo = PD.PickSlipNo
            AND PI.CartonNo = PD.CartonNo
         WHERE PD.StorerKey = @cStorerKey
            AND PD.LabelNo = @cMasterLabelNo
      END TRY
      BEGIN CATCH
         SET @nErrNo = 227620
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Delete PackInfo Fail
         GOTO RollBackTran
      END CATCH

      IF @bDebugFlag = 1
         SELECT 'Handl Master Carton Pack Detail'

      --Only handle the master carton record
      WHILE 1 = 1 
      BEGIN
         SELECT TOP 1 
            @nRowNo = RowNumber, 
            @cTempPSNO = PickSlipNo,
            @cTempLabelNo = LabelNo,
            @cTempSKU = SKU,
            @nTempQty = MoveQty
         FROM @tMoveLog
         WHERE MoveQty > 0
         ORDER BY MoveQty

         IF @@ROWCOUNT = 0
         BEGIN
            IF @bDebugFlag = 1
               SELECT 'No records in @tMoveLog, Exit'
            BREAK -- All records were handled
         END

         IF @bDebugFlag = 1
         BEGIN
            SELECT 'Current Handling @tMoveLog', @nRowNo AS RowNo, @cTempPSNO AS PSNO, @cTempLabelNo AS LabelNo, @cTempSKU AS SKU, @nTempQty AS Qty
         END

         IF EXISTS (SELECT 1 FROM dbo.PackDetail WITH (NOLOCK)
                     WHERE PickSlipNo = @cTempPSNO
                        AND LabelNo = @cTempLabelNo
                        AND SKU = @cTempSKU
                     )
         BEGIN
            IF @bDebugFlag = 1
               SELECT 'Dest Carton has same pickslipno, and same sku records'

            -- Add the qty to the existing record
            UPDATE dbo.PackDetail WITH (ROWLOCK)
            SET   Qty = Qty + @nTempQty
            WHERE PickSlipNo = @cTempPSNO
               AND LabelNo = @cTempLabelNo
               AND SKU = @cTempSKU
            -- No needs to handle Packinfo, trigger will handle it.
         END
         ELSE
         BEGIN
            IF EXISTS (SELECT 1 FROM PackDetail WITH (NOLOCK)
                        WHERE PickSlipNo = @cTempPSNO
                           AND LabelNo = @cTempLabelNo
                        )
            BEGIN
               IF @bDebugFlag = 1
                  SELECT 'Dest Carton has same psno, but no same sku'
               
               INSERT INTO dbo.PackDetail (PickSlipNo, CartonNo, LabelNo, LabelLine, StorerKey, SKU, Qty, DropID)
                  SELECT 
                     @cTempPSNO,
                     MAX(CartonNo),
                     @cTempLabelNo,
                     RIGHT('00000' + CAST((ISNULL(MAX(LabelLine), 0) + 1) AS VARCHAR(5)), 5),
                     @cStorerKey,
                     @cTempSKU,
                     @nTempQty,
                     @cTempLabelNo
                  FROM dbo.PackDetail WITH (NOLOCK)
                  WHERE PickSlipNo = @cTempPSNO
                     AND LabelNo = @cTempLabelNo
               -- No needs to handle Packinfo, trigger will handle it.
            END -- same psno, no same sku
            ELSE -- no same psno, no samp sku
            BEGIN
               IF @bDebugFlag = 1
                  SELECT 'Dest Carton has no same psno, no same sku'

               INSERT INTO dbo.PackDetail (PickSlipNo, CartonNo, LabelNo, LabelLine, StorerKey, SKU, Qty, DropID)
                  SELECT 
                     @cTempPSNO,
                     MAX(CartonNo)+1,
                     @cTempLabelNo,
                     '00001',
                     @cStorerKey,
                     @cTempSKU,
                     @nTempQty,
                     @cTempLabelNo
                  FROM dbo.PackDetail WITH (NOLOCK)
                  WHERE PickSlipNo = @cTempPSNO
            END -- -- no same psno, no samp sku

         END -- PackDeail/PackInfo Hanlding

         IF @bDebugFlag = 1
         BEGIN
            SELECT 'Finish PackDetail Handling'
            SELECT * FROM PackDetail WITH (NOLOCK) WHERE LabelNo = @cMasterLabelNo
            SELECT 'Handling PickDetail'
         END


         EXEC rdt.rdt_Pack_LVSUSA_PickDetailConfirm @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey
         ,@cTempPSNO --PickSlipNo
         ,'' --FromDropID
         ,@cTempSKU --SKU
         ,@nTempQty
         ,@nCartonNo             OUTPUT
         ,@cTempLabelNo          OUTPUT 
         ,@nErrNo                OUTPUT
         ,@cErrMsg               OUTPUT
         
         IF @nErrNo <> 0
         BEGIN
            SET @nErrNo = 227617
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Handle PickDetail Fail
            GOTO RollBackTran
         END

         DELETE @tMoveLog WHERE RowNumber = @nRowNo

         IF @bDebugFlag = 1
            SELECT 'Delete RowNumber: ' + CAST(@nRowNo AS NVARCHAR(3)) + ' In @tMoveLog'
      END -- PickDetail while
      IF @bDebugFlag = 1
         SELECT 'Handling PickDetail (Merge) END'
      --PickDetail Handling (Merge) End
   END -- MERGE
   
   -- Reorganize the master carton packdetail
   BEGIN TRY
      ;WITH TempPackDetail AS (
         SELECT 
            DENSE_RANK() OVER (PARTITION BY PickSlipNo ORDER BY LabelNo) AS NewCartonNo,
            RIGHT('00000' + CAST(ROW_NUMBER() OVER (PARTITION BY PickSlipNo, CartonNo ORDER BY SKU) AS VARCHAR(5)), 5) AS NewLabelLine,
            PickSlipNo, 
            CartonNo, 
            LabelNo, 
            LabelLine, 
            StorerKey, 
            SKU, 
            Qty
         FROM dbo.PackDetail WITH (NOLOCK)
         WHERE PickSlipNo IN (SELECT PickSlipNo FROM @tPSNO )
      )
      UPDATE pd
      SET pd.CartonNo = tpd.NewCartonNo,
         pd.LabelLine = tpd.NewLabelLine
      FROM dbo.PackDetail pd
      JOIN TempPackDetail tpd
      ON pd.PickSlipNo = tpd.PickSlipNo
      AND pd.LabelNo = tpd.LabelNo
      AND pd.LabelLine = tpd.LabelLine;
   END TRY
   BEGIN CATCH
      SET @nErrNo = 227621
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Handle PickDetail Fail
      GOTO RollBackTran
   END CATCH

   --Insert back master carton packinfo

   IF @bDebugFlag = 1
   BEGIN
      SELECT 'renewed packdetail'
      SELECT * FROM PackDetail WHERE LabelNo = @cMasterLabelNo
   END

   --Re-generate the new packinfo for MasterLabel
   BEGIN TRY
      MERGE INTO PackInfo AS PI
      USING (SELECT PickSlipNo, CartonNo, LabelNo, SUM(Qty) AS Qty
               FROM PackDetail WITH (NOLOCK)
               WHERE StorerKey = @cStorerkey
                  AND PickSlipNo IN (SELECT PickSlipNo FROM @tPSNO )
               GROUP BY StorerKey, PickSlipNo, CartonNo, LabelNo) AS PD
      ON (PI.PickSlipNo = PD.PickSlipNo AND PI.RefNo = PD.LabelNo)
      WHEN MATCHED THEN
         UPDATE SET PI.CartonNo = PD.CartonNo, PI.Qty = PD.Qty
      WHEN NOT MATCHED THEN
         INSERT (PickSlipNo, CartonNo, Cube, Qty, 
                  CartonType, RefNo, Length, 
                  Width, Height, CartonStatus)
         VALUES (PD.PickSlipNo, PD.CartonNo, ISNULL(@fMasterCartonCube,0), PD.Qty,
            ISNULL(@cMasterCartonType, ''), PD.LabelNo, ISNULL(@fMasterCartonLength, 0), 
               ISNULL(@fMasterCartonWidth, 0), ISNULL(@fMasterCartonHeight, 0), 'PACKED');
   END TRY
   BEGIN CATCH
      SET @nErrNo = 227622
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Handle PickDetail Fail
      GOTO RollBackTran
   END CATCH

   IF @bDebugFlag = 1
   BEGIN
      SELECT 'New Master Label No PackInfo'
      SELECT * FROM PackInfo PI WITH (NOLOCK)
      JOIN PackDetail PD WITH (NOLOCK)
         ON PI.PickSlipNo = PD.PickSlipNo
         AND PI.CartonNo = PD.CartonNo
      WHERE PD.StorerKey = @cStorerKey
         AND PD.LabelNo = @cMasterLabelNo
   END
   
   EXEC RDT.rdt_STD_EventLog           
   @cActionType         = '3',              
   @nMobileNo           = @nMobile,        
   @nFunctionID         = @nFunc,        
   @cFacility           = @cFacility,        
   @cStorerKey          = @cStorerkey,       
   @nQTY                = @nQTY,          
   @cUCC                = @cUCCNo,    
   @cOrderKey           = '',    
   @cSKU                = @cSKU,  
   @cRefNo1             = @cLabelNo,
   @cPickSlipNo         = '',
   @cLabelNo            = @cMasterLabelNo

   COMMIT TRAN rdt_Pack_LVSUSA_Confirm
   GOTO Quit

RollBackTran:
BEGIN
   SELECT 'Rollback Tran'
   IF @@ROWCOUNT > 0
      ROLLBACK TRAN rdt_Pack_LVSUSA_Confirm -- Only rollback change made here
   IF @cNewCarton = 'Y'
   BEGIN
      SET @nCartonNo = 0
      SET @cLabelNo = ''
   END
END

Quit:
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
      COMMIT TRAN
   
   IF @bDebugFlag = 1
   BEGIN
      SELECT 'Quit'
      SELECT @nErrNo AS ErrNo, @cErrMsg AS ErrMsg
   END
END

GO