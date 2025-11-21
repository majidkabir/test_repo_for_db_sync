SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_838ConfirmSP20                                  */
/* Copyright      : Maersk                                              */
/*                                                                      */
/* Purpose: split pickdetail for Granite                                */
/*                                                                      */
/* Date       Rev  Author      Purposes                                 */
/* 07-01-2023 1.0  JACKC       FCR-392 Created                          */
/* 08-22-2023 1.1  JACKC       FCR-392 Support cutomized repack         */
/************************************************************************/

CREATE   PROC [RDT].[rdt_838ConfirmSP20] (
    @nMobile         INT
   ,@nFunc           INT
   ,@cLangCode       NVARCHAR( 3)
   ,@nStep           INT
   ,@nInputKey       INT
   ,@cFacility       NVARCHAR( 5)
   ,@cStorerKey      NVARCHAR( 15)
   ,@cPickSlipNo     NVARCHAR( 10)
   ,@cFromDropID     NVARCHAR( 20)
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
   
   DECLARE @cSQL        NVARCHAR(MAX)
   DECLARE @cSQLParam   NVARCHAR(MAX)

   DECLARE @bSuccess    INT
   DECLARE @cLabelLine  NVARCHAR( 5)
   DECLARE @cNewLine    NVARCHAR( 1)
   DECLARE @cNewCarton  NVARCHAR( 1)
   DECLARE @cDropID     NVARCHAR( 20) = ''
   DECLARE @cRefNo      NVARCHAR( 20) = ''
   DECLARE @cRefNo2     NVARCHAR( 30) = ''
   DECLARE @cUPC        NVARCHAR( 30) = ''    
   DECLARE @cLoadKey    NVARCHAR( 10) = ''
   DECLARE @cOrderKey   NVARCHAR( 10) = ''
   
   DECLARE @cGenLabelNo_SP       NVARCHAR( 20)
   DECLARE @cPackDetailCartonID  NVARCHAR( 20)
   DECLARE @cPackByFromDropID    NVARCHAR( 1)

   --FCR 392
   DECLARE  @nCartonPackQty      INT = 0,
            @nBalQty             INT = 0,
            @cOption             NVARCHAR( 1) ='0',
            @cZone               NVARCHAR( 18),
            @nTotalNoPackQty     INT = 0,
            @bDebugFlag          BINARY = 0

   --FCR-392 Get original packed qty on Carton Level
   IF @nCartonNo <> 0
      SELECT @nCartonPackQty = ISNULL(SUM(PD.Qty), 0)
      FROM PackDetail PD WITH (NOLOCK)
      WHERE PD.PickSlipNo = @cPickSlipNo
         AND PD.StorerKey = @cStorerKey
         AND PD.SKU = @cSKU
         AND PD.labelNo = @cLabelNo

   SET @nBalQty = @nQTY - @nCartonPackQty

   IF @bDebugFlag = 1
      SELECT 'Start Tran', @nQTY AS InputQty, @nCartonPackQty AS OldQty, @nBalQty AS BalQty, @nCartonNo AS CartonNo

   -- Handling transaction
   DECLARE @nTranCount  INT
   SET @nTranCount = @@TRANCOUNT
   BEGIN TRAN  -- Begin our own transaction
   SAVE TRAN rdt_Pack_Confirm20 -- For rollback or commit only our own transaction
   
   IF @nBalQty = 0 -- No change applied
   BEGIN
      IF @bDebugFlag = 1
         SELECT 'No Change in Carton', @nQTY, @nCartonPackQty

      GOTO EVENTLOG
   END

   -- Storer configure
   SET @cPackByFromDropID = rdt.rdtGetConfig( @nFunc, 'PackByFromDropID', @cStorerKey)
   SET @cPackDetailCartonID = rdt.RDTGetConfig( @nFunc, 'PackDetailCartonID', @cStorerKey)
   IF @cPackDetailCartonID = '0' -- DropID/LabelNo/RefNo/RefNo2/UPC/NONE
      SET @cPackDetailCartonID = 'DropID'

   -- Save decoded data to which column (initially it was carton ID only, hence the misleading PackDetailCartonID ConfigKey name)
   IF @cPackDetailCartonID = 'DropID'  SET @cDropID  = ISNULL(@cPackDtlDropID,'') ELSE
   IF @cPackDetailCartonID = 'RefNo'   SET @cRefNo   = ISNULL(@cPackDtlRefNo, '')  ELSE
   IF @cPackDetailCartonID = 'RefNo2'  SET @cRefNo2  = ISNULL(@cPackDtlRefNo2,'') ELSE
   IF @cPackDetailCartonID = 'UPC'     SET @cUPC     = ISNULL(@cPackDtlUPC, '')

   -- Pack by drop ID, the drop ID must present in both PickDetail and PackDetail, otherwise it can't do over pack checking.
   IF @cPackByFromDropID = '1'
      SET @cDropID = @cFromDropID   
   
   SET @cNewLine = 'N'
   SET @cNewCarton = 'N'
   
   -- New carton, generate labelNo
   IF @nCartonNo = 0 -- 
   BEGIN
      IF @bDebugFlag = 1
         SELECT 'Generate CartonNo'


      SET @cLabelNo = ''
      
      IF @cUCCNo <> ''
      BEGIN
         IF rdt.RDTGetConfig( @nFunc, 'DefaultUCCtoLabelNo', @cStorerkey) = '1'
            SET @cLabelNo = @cUCCNo
      END
      
      IF @cLabelNo = ''
      BEGIN
         SET @cGenLabelNo_SP = rdt.RDTGetConfig( @nFunc, 'GenLabelNo_SP', @cStorerkey)
         IF @cGenLabelNo_SP = '0'
            SET @cGenLabelNo_SP = ''
         
         IF @cGenLabelNo_SP <> ''
         BEGIN
            IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cGenLabelNo_SP AND type = 'P')  
            BEGIN
               SET @cSQL = 'EXEC dbo.' + RTRIM( @cGenLabelNo_SP) +
                  ' @cPickslipNo, ' +  
                  ' @nCartonNo,   ' +  
                  ' @cLabelNo     OUTPUT '  
               SET @cSQLParam =
                  ' @cPickslipNo  NVARCHAR(10),       ' +  
                  ' @nCartonNo    INT,                ' +  
                  ' @cLabelNo     NVARCHAR(20) OUTPUT '  
               EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
                  @cPickslipNo, 
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
      END

      IF @cLabelNo = ''
      BEGIN
         SET @nErrNo = 100403
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --GenLabelNoFail
         GOTO RollBackTran
      END

      IF @bDebugFlag = 1
         SELECT 'Label No Generated', @cLabelNo AS NewLabelNo

      SET @cLabelLine = ''   
      SET @cNewLine = 'Y'
      SET @cNewCarton = 'Y'
   END -- Generate Label No
   ELSE
   BEGIN
      IF @bDebugFlag = 1
         SELECT 'Get Label Line'

      -- Get LabelLine
      SET @cLabelLine = ''
      SELECT @cLabelLine = LabelLine
      FROM dbo.PackDetail WITH (NOLOCK) 
      WHERE PickSlipNo = @cPickSlipNo 
         AND CartonNo = @nCartonNo
         AND LabelNo = @cLabelNo 
         AND SKU = @cSKU
      
      IF @cLabelLine = ''
         SELECT @cLabelLine = LabelLine
         FROM dbo.PackDetail WITH (NOLOCK) 
         WHERE PickSlipNo = @cPickSlipNo 
            AND CartonNo = @nCartonNo
            AND LabelNo = @cLabelNo 
            AND SKU = ''
      
      IF @cLabelLine = ''
      BEGIN
         SELECT @cLabelLine = RIGHT( '00000' + CAST( CAST( IsNULL( MAX( LabelLine), 0) AS INT) + 1 AS NVARCHAR( 5)), 5) 
         FROM dbo.PackDetail (NOLOCK)
         WHERE Pickslipno = @cPickSlipNo
            AND CartonNo = @nCartonNo
            AND LabelNo = @cLabelNo

         SET @cNewLine = 'Y'
      END

      IF @bDebugFlag = 1
         SELECT 'Lable Line', @cLabelLine AS LabelLine

   END--Get label line
   
   IF @cNewLine = 'Y'
   BEGIN
      -- Insert PackDetail
      INSERT INTO dbo.PackDetail
         (PickSlipNo, CartonNo, LabelNo, LabelLine, StorerKey, SKU, QTY, 
         DropID, RefNo, RefNo2, UPC,
         AddWho, AddDate, EditWho, EditDate)
      VALUES
         (@cPickSlipNo, @nCartonNo, @cLabelNo, @cLabelLine, @cStorerKey, @cSKU, @nQTY, 
         @cDropID, @cRefNo, @cRefNo2, @cUPC,
         'rdt.' + SUSER_SNAME(), GETDATE(), 'rdt.' + SUSER_SNAME(), GETDATE())
      IF @@ERROR <> 0
      BEGIN
         SET @nErrNo = 100404
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InsPackDtlFail
         GOTO RollBackTran
      END
   END
   ELSE
   BEGIN
      --FCR-392 Update Packdetail to the qty input by Jackc
      UPDATE dbo.PackDetail WITH (ROWLOCK) SET   
         SKU = @cSKU, 
         QTY = @nQTY, 
         EditWho = 'rdt.' + SUSER_SNAME(), 
         EditDate = GETDATE() 
         --ArchiveCop = NULL
      WHERE PickSlipNo = @cPickSlipNo
         AND CartonNo = @nCartonNo
         AND LabelNo = @cLabelNo
         AND LabelLine = @cLabelLine
         --AND SKU = @cSKU -- V1.1 remove SKU to support repack scenario by jackc
      IF @@ERROR <> 0
      BEGIN
         SET @nErrNo = 100405
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UpdPackDtlFail
         GOTO RollBackTran
      END
   END

   -- Get system assigned CartonoNo and LabelNo
   IF @nCartonNo = 0
   BEGIN
      SET @cOption = '1'  -- FCR-392 Save new carton flag for PKD processing 
      -- If insert cartonno = 0, system will auto assign max cartonno
      SELECT TOP 1 
         @nCartonNo  = CartonNo, 
         @cLabelNo      = LabelNo, 
         @cLabelLine    = LabelLine
      FROM PackDetail WITH (NOLOCK)
      WHERE PickSlipNo = @cPickSlipNo
         AND SKU = @cSKU
         AND AddWho = 'rdt.' + SUSER_SNAME()
      ORDER BY CartonNo DESC -- max cartonno
   END

   -- FCR-392 update pack info

   IF @cOption = 1
   BEGIN
      IF @bDebugFlag = 1
         SELECT 'Insert new pack info', @cPickSlipNo AS PSNo, @nCartonNo AS CartonNo, @nQTY AS Qty

      IF NOT EXISTS (SELECT 1 FROM dbo.PackInfo WITH (NOLOCK) WHERE PickSlipNo = @cPickSlipNo AND CartonNo = @nCartonNo)
      BEGIN
         IF NOT EXISTS (SELECT 1 FROM PackInfo WITH (NOLOCK) WHERE PickSlipNo = @cPickSlipNo AND ISNULL(CartonType,'') <> '' )
         BEGIN
            SET @nErrNo = '218415'
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --NoCartonTypeInPackInfo
            GOTO RollBackTran
         END
         ELSE
         BEGIN
            INSERT INTO dbo.PackInfo (PickslipNo, CartonNo, Cube, QTY, CartonType, RefNo, Length, Width, Height, UCCNo, TrackingNo)
               SELECT TOP 1 
                  @cPickSlipNo,
                  @nCartonNo,
                  Cube,
                  @nQTY,
                  CartonType,
                  @cLabelNo,
                  Length,
                  Width,
                  Height,
                  '', --UCC
                  '' --TrackingNo
               FROM PackInfo  WITH (NOLOCK)
               WHERE PickSlipNo = @cPickSlipNo
                  AND ISNULL(CartonType,'') <> ''
            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 100406
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --INSPackInfFail
               GOTO RollBackTran
            END
         END 
      END -- Gen new pack info
      ELSE
      BEGIN
         SET @nErrNo = '218405'
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --DuplicatePackInfo
         GOTO RollBackTran
      END
   END -- Insert new pack info
   -- Remove UPDATE logic. The packdetail trigger help maintan pack info
   /*
   ELSE
   BEGIN
      IF @bDebugFlag = 1
         SELECT 'Upd pack info', @cPickSlipNo AS PSNo, @nCartonNo AS CartonNo, @nQTY AS Qty

      UPDATE dbo.PackInfo SET
            Qty = QTY + @nBalQTY, 
            EditDate = GETDATE(), 
            EditWho = SUSER_SNAME(), 
            TrafficCop = NULL
      WHERE PickSlipNo = @cPickSlipNo
         AND CartonNo = @nCartonNo
      IF @@ERROR <> 0
      BEGIN
         SET @nErrNo = 100407
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPDPackInfFail
         GOTO RollBackTran
      END
   END */


   --  Skip Original UCC packinfo logic 347-395
   --  Skip SN logic 397-528
   
   -- Pack data
   IF ISNULL(@cPackData1,'') <> '' OR
      ISNULL(@cPackData2,'') <> '' OR
      ISNULL(@cPackData3,'') <> ''
   BEGIN
      DECLARE @nPackDetailInfoKey BIGINT
      
      -- Get PackDetailInfo
      SET @nPackDetailInfoKey = 0
      SELECT @nPackDetailInfoKey = PackDetailInfoKey
      FROM dbo.PackDetailInfo WITH (NOLOCK) 
      WHERE PickSlipNo = @cPickSlipNo 
         AND CartonNo = @nCartonNo
         AND LabelNo = @cLabelNo 
         AND SKU = @cSKU
         AND UserDefine01 = @cPackData1
         AND UserDefine02 = @cPackData2
         AND UserDefine03 = @cPackData3
      
      IF @nPackDetailInfoKey = ''
      BEGIN
         -- Insert PackDetailInfo
         INSERT INTO dbo.PackDetailInfo (
            PickSlipNo, CartonNo, LabelNo, LabelLine, StorerKey, SKU, QTY, UserDefine01, UserDefine02, UserDefine03, 
            AddWho, AddDate, EditWho, EditDate)
         VALUES (
            @cPickSlipNo, @nCartonNo, @cLabelNo, @cLabelLine, @cStorerKey, @cSKU, @nQTY, @cPackData1, @cPackData2, @cPackData3, 
            'rdt.' + SUSER_SNAME(), GETDATE(), 'rdt.' + SUSER_SNAME(), GETDATE())
         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 100417
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --INS PDInfoFail
            GOTO RollBackTran
         END
      END
      ELSE
      BEGIN
         -- Update PackDetailInfo
         UPDATE dbo.PackDetailInfo SET   
            QTY = @nQTY, -- fcr-392 update qty to the input qty 
            EditWho = 'rdt.' + SUSER_SNAME(), 
            EditDate = GETDATE(), 
            ArchiveCop = NULL
         WHERE PackDetailInfoKey = @nPackDetailInfoKey
         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 100418
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD PDInfoFail
            GOTO RollBackTran
         END
      END
   END 

   -----------------------------------------------------------------------------------------------------------------
   -- FCR-392 Handle the pick detail data based on the pack detail
   -----------------------------------------------------------------------------------------------------------------
   DECLARE @tPKD TABLE
   (
      PickDetailKey     NVARCHAR( 10) NOT NULL,
      CaseID            NVARCHAR( 20) NOT NULL,
      PickHeaderKey     NVARCHAR( 18) NOT NULL,
      OrderKey          NVARCHAR( 10) NOT NULL,
      OrderLineNumber   NVARCHAR( 5)  NOT NULL,
      SKU               NVARCHAR( 20) NOT NULL, 
      QTY               INT           NOT NULL,
      AdjustQty         INT           NOT NULL,
      Lot               NVARCHAR( 10) NOT NULL,
      StorerKey         NVARCHAR( 15) NOT NULL,
      UOM               NVARCHAR( 10) NOT NULL,
      UOMQty            INT           NOT NULL,
      DropID            NVARCHAR( 20) NULL,
      Loc               NVARCHAR( 10) NOT NULL,
      ID                NVARCHAR( 18) NULL,
      PackKey           NVARCHAR( 10) NOT NULL,
      CartonGroup       NVARCHAR( 10) NULL,
      PickMethod        NVARCHAR( 1)  NOT NULL,
      WaveKey           NVARCHAR( 10) NULL,
      New               NVARCHAR( 1)  NULL DEFAULT 'N',
      PRIMARY KEY CLUSTERED (PickDetailKey)
   )

   DECLARE  
      @cPickDetailKey         NVARCHAR( 10),
      @cNewPickDetailKey      NVARCHAR( 10),
      @cPKDCaseID             NVARCHAR( 20),
      @cPKDPickHeaderKey      NVARCHAR( 18),
      @cPKDOrderKey           NVARCHAR( 10),
      @cPKDOrderLineNumber    NVARCHAR( 5),
      @cPKDLot                NVARCHAR( 10),
      @cPKDDropID             NVARCHAR( 20),
      @cPKDLoc                NVARCHAR( 10),
      @cPKDID                 NVARCHAR( 18),
      @cPKDWeaveKey           NVARCHAR( 10),
      @nPkdQty                INT = 0,
      @nNewAdjustQty          INT = 0,
      @cNewFlag               NVARCHAR( 1) = 'N'

   IF @bDebugFlag = 1
   BEGIN
         SELECT 'Start handling PKD', @nQTY AS InputQty, @nCartonPackQty AS CartonPackedQty, @nBalQty AS BalQty, 
                  @nCartonNo AS CartonNo, @cLabelNo AS LabelNo    
   END

   IF @nBalQty < 0 -- Move out SKU from carton
   BEGIN

      IF @bDebugFlag = 1
         SELECT 'Move out SKU from Carton', @nQTY AS NewQtyInCarton, @nCartonPackQty AS OldQtyInCarton

      INSERT INTO @tPKD (PickDetailKey, CaseID, PickHeaderKey, OrderKey, OrderLineNumber, SKU, Qty, AdjustQty,Lot, UOM,
						 UOMQty, DropID, Loc, ID, PackKey, CartonGroup, PickMethod, WaveKey, StorerKey)
      SELECT	PickDetailKey, CaseID, PickHeaderKey, OrderKey, OrderLineNumber, SKU, Qty, 0, Lot, UOM,
	   		UOMQty, DropID, Loc, ID, PackKey, CartonGroup, PickMethod, WaveKey, @cStorerKey
      FROM PICKDETAIL with(nolock)
      WHERE Storerkey = @cStorerKey
	      AND CaseID = @cLabelNo
         AND Status = '5'
         AND SKU = @cSKU

      IF @@ERROR <> 0
      BEGIN
         SET @nErrNo = 218401
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Gen tPKD Fail'
         GOTO RollBackTran
      END

      IF @bDebugFlag = 1
      BEGIN
         SELECT 'Fill in @tPKD'
         SELECT * FROM @tPKD ORDER BY Qty DESC
      END
      
      WHILE @nBalQty < 0
      BEGIN
         SET @cPickDetailKey        = ''
         SET @cNewPickDetailKey     = ''
         SET @cPKDPickHeaderKey     = ''
         SET @cPKDOrderKey          = ''          
         SET @cPKDOrderLineNumber   = ''    
         SET @cPKDLot               = ''                
         SET @cPKDDropID            = ''       
         SET @cPKDLoc               = ''
         SET @cPKDID                = ''
         SET @nPkdQty               = 0
         SET @cNewFlag              = 'N'

         SELECT TOP 1 
            @cPickDetailKey      = PickDetailKey,
            @cPKDOrderKey        = OrderKey,          
            @cPKDOrderLineNumber = OrderLineNumber,    
            @cPKDLot             = Lot,                
            @cPKDDropID          = DropID,       
            @cPKDLoc             = Loc,
            @cPKDID              = ID,
            @cPKDWeaveKey        = Wavekey,
            @nPkdQTY             = Qty
         FROM @tPKD
         WHERE (Qty - AdjustQty) >0
            AND New = 'N'
            AND CaseID <> ''
         ORDER BY QTY DESC, OrderKey, OrderLineNumber, LOT, LOC, ID, DropID

         IF @cPickDetailKey = ''
         BEGIN
            SET @nErrNo = 218402
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --GetPKDFail
            GOTO RollBackTran
         END

         IF @bDebugFlag = 1
            SELECT 'PKD Found', @cPickDetailKey AS PKDKey, @nBalQty AS BalQty, @nPkdQty AS PKDQty

         IF ABS(@nBalQty) < @nPkdQty -- Split original pkd
         BEGIN
            IF @bDebugFlag = 1
               SELECT 'Splist old PKD'

            --Adjust PKD qty
            UPDATE @tPKD SET AdjustQty = AdjustQty + @nBalQty
            WHERE PickDetailKey = @cPickDetailKey

            --IF exists a pkd with same case id and all same attributes, then add qty to that one
            SELECT @cNewPickDetailKey = PickDetailKey FROM PICKDETAIL WITH (NOLOCK) 
            WHERE Storerkey = @cStorerKey AND CaseID = '' AND OrderKey = @cPKDOrderKey AND OrderLineNumber = @cPKDOrderLineNumber
               AND Lot = @cPKDLot AND SKU = @cSKU AND Status = '5' AND DropID = @cPKDDropID AND Loc = @cPKDLoc
               AND ID = @cPKDID AND WaveKey = @cPKDWeaveKey

            IF @cNewPickDetailKey <> ''
            BEGIN
               IF @bDebugFlag = 1
                  SELECT 'Found PKD with all same attributes, increas qty', @cNewPickDetailKey AS PKDKey

               -- insert PKD to @tPKD to increas qty same as the qty take out from the carton
               INSERT INTO @tPKD (PickDetailKey, CaseID, PickHeaderKey, OrderKey, OrderLineNumber, SKU, Qty, AdjustQty,Lot, UOM,
                     UOMQty, DropID, Loc, ID, PackKey, CartonGroup, PickMethod, WaveKey, StorerKey)
                  SELECT	PickDetailKey, CaseID, PickHeaderKey, OrderKey, OrderLineNumber, SKU, QTY, ABS(@nBalQty), Lot, UOM,
                        UOMQty, DropID, Loc, ID, PackKey, CartonGroup, PickMethod, WaveKey, Storerkey
                  FROM PickDetail WITH (NOLOCK)
                  WHERE PickDetailKey = @cNewPickDetailKey
               
               IF @@ERROR <> 0
               BEGIN
                  SET @nErrNo = 218406
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'InsExtPkdFail'
                  GOTO RollBackTran
               END

            END -- newPKDKey <> ''
            ELSE 
            BEGIN

               -- Generate new pkd
               EXECUTE dbo.nspg_GetKey
                  'PICKDETAILKEY',
                  10 ,
                  @cNewPickDetailKey OUTPUT,
                  @bSuccess          OUTPUT,
                  @nErrNo            OUTPUT,
                  @cErrMsg           OUTPUT

               IF @bSuccess <> 1
               BEGIN
                  SET @nErrNo = 218403
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --GetKey Fail
                  GOTO RollBackTran
               END

               IF ISNULL(@cNewPickDetailKey, '') = ''
               BEGIN
                  SET @nErrNo = 218408
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --GenPKDKeyFail
                  GOTO RollBackTran
               END

               IF @bDebugFlag = 1
                  SELECT 'Gen new tPKD record', @cNewPickDetailKey AS NewPKDKey

               INSERT INTO @tPKD (PickDetailKey, CaseID, PickHeaderKey, OrderKey, OrderLineNumber, SKU, Qty, AdjustQty,Lot, UOM,
                     UOMQty, DropID, Loc, ID, PackKey, CartonGroup, PickMethod, WaveKey, StorerKey, New)
                  SELECT	@cNewPickDetailKey, '', PickHeaderKey, OrderKey, OrderLineNumber, SKU, ABS(@nBalQty), 0, Lot, '6',
                        1, DropID, Loc, ID, PackKey, CartonGroup, PickMethod, WaveKey,StorerKey,'Y'
                  FROM @tPKD
                  WHERE PickDetailKey = @cPickDetailKey

               IF @@ERROR <> 0
               BEGIN
                  SET @nErrNo = 218404
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'InsNewPkdFail'
                  GOTO RollBackTran
               END
            END -- Generate new pkd
         END -- Split original pkd
         ELSE -- ABS(@nBalQty) >= @nPkdQty
         BEGIN

            IF @bDebugFlag = 1
               SELECT 'Update existing PKD'

            --IF exists a pkd without case id but has all same attributes, then add qty to that one
            SELECT @cNewPickDetailKey = PickDetailKey FROM PICKDETAIL WITH (NOLOCK) 
            WHERE Storerkey = @cStorerKey AND CaseID = '' AND OrderKey = @cPKDOrderKey AND OrderLineNumber = @cPKDOrderLineNumber
               AND Lot = @cPKDLot AND SKU = @cSKU AND Status = '5' AND DropID = @cPKDDropID AND Loc = @cPKDLoc
               AND ID = @cPKDID AND WaveKey = @cPKDWeaveKey

            IF @cNewPickDetailKey <> ''
            BEGIN
               IF @bDebugFlag = 1
                  SELECT 'Found PKD with all same attributes, increas qty, delete original one', @cNewPickDetailKey AS PKDKey

               IF NOT EXISTS (SELECT 1 FROM @tPKD WHERE PickDetailKey = @cNewPickDetailKey)
               BEGIN
                  IF @bDebugFlag = 1
                     SELECT 'Found PKD not exist in @tPKD, insert it'

                  -- insert PKD to @tPKD to increas qty same as the qty take out from the carton
                  INSERT INTO @tPKD (PickDetailKey, CaseID, PickHeaderKey, OrderKey, OrderLineNumber, SKU, Qty, AdjustQty,Lot, UOM,
                        UOMQty, DropID, Loc, ID, PackKey, CartonGroup, PickMethod, WaveKey, StorerKey)
                     SELECT	PickDetailKey, CaseID, PickHeaderKey, OrderKey, OrderLineNumber, SKU, QTY, @nPkdQty, Lot, UOM,
                           UOMQty, DropID, Loc, ID, PackKey, CartonGroup, PickMethod, WaveKey, Storerkey
                     FROM PickDetail WITH (NOLOCK)
                     WHERE PickDetailKey = @cNewPickDetailKey
                  
                  IF @@ERROR <> 0
                  BEGIN
                     SET @nErrNo = 218406
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'InsExtPkdFail'
                     GOTO RollBackTran
                  END
               END -- Not Exists
               ELSE
               BEGIN -- exists in @tPKD
                  IF @bDebugFlag = 1
                     SELECT 'Found pkd exists in @tPKD, update it'

                  UPDATE @tPKD SET AdjustQty = AdjustQty + @nPkdQty WHERE PickDetailKey = @cNewPickDetailKey

                  IF @@ERROR <> 0
                  BEGIN
                     SET @nErrNo = 218411
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdtPKDFail'
                     GOTO RollBackTran
                  END
               END


               IF @bDebugFlag = 1
                  SELECT 'Mark the original PKD as delete', @cPickDetailKey

               --Mark to delete the original pkd
               UPDATE @tPKD SET New = 'D' WHERE PickDetailKey = @cPickDetailKey

               IF @@ERROR <> 0
               BEGIN
                  SET @nErrNo = 218411
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdtPKDFail'
                  GOTO RollBackTran
               END


            END -- newPKDKey <> ''
            ELSE
            BEGIN
               IF @bDebugFlag = 1
                  SELECT 'Remove case id from pkd'

               -- Set case id to empty
               UPDATE @tPKD SET  CaseID = ''  WHERE PickDetailKey = @cPickDetailKey
            END
         END

         SET @nBalQty = @nBalQty + @nPkdQTY

      END --  @nBalQty < 0 While
   END -- @nBalQty < 0
   ELSE IF @nBalQty > 0 -- Add item to existing carton
   BEGIN

      IF @bDebugFlag = 1
         SELECT 'Add SKU to Carton', @nQTY AS NewQtyInCarton, @nCartonPackQty AS OldQtyInCarton

      --Get all unpacked pick detail with same sku under this pickslip no 
      SELECT TOP 1
         @cOrderKey = OrderKey,
         @cLoadKey = ExternOrderKey,
         @cZone = Zone
      FROM dbo.PickHeader WITH (NOLOCK)
      WHERE PickHeaderKey = @cPickSlipNo

      IF @cZone IN ('XD', 'LB', 'LP')
      BEGIN
         INSERT INTO @tPKD (PickDetailKey, CaseID, PickHeaderKey, OrderKey, OrderLineNumber, SKU, Qty, AdjustQty,Lot, UOM,
						 UOMQty, DropID, Loc, ID, PackKey, CartonGroup, PickMethod, WaveKey, StorerKey)
            SELECT	PD.PickDetailKey, CaseID, PickHeaderKey, PD.OrderKey, PD.OrderLineNumber, SKU, Qty, 0, Lot, UOM,
	   		         UOMQty, DropID, Loc, ID, PackKey, CartonGroup, PickMethod, WaveKey, Storerkey
            FROM dbo.RefKeyLookup RKL WITH (NOLOCK)
               JOIN dbo.PickDetail PD WITH (NOLOCK) ON (PD.PickDetailKey = RKL.PickDetailKey)
            WHERE RKL.PickSlipNo = @cPickSlipNo 
               AND PD.Status = '5'
               AND PD.CaseID = ''
               AND PD.SKU = @cSKU
      END
      ELSE IF @cOrderKey <> ''
      BEGIN
         INSERT INTO @tPKD (PickDetailKey, CaseID, PickHeaderKey, OrderKey, OrderLineNumber, SKU, Qty, AdjustQty,Lot, UOM,
						 UOMQty, DropID, Loc, ID, PackKey, CartonGroup, PickMethod, WaveKey, StorerKey)
            SELECT	PD.PickDetailKey, CaseID, PickHeaderKey, PD.OrderKey, PD.OrderLineNumber, SKU, Qty, 0, Lot, UOM,
	   		         UOMQty, DropID, Loc, ID, PackKey, CartonGroup, PickMethod, WaveKey, Storerkey
            FROM dbo.PickDetail PD WITH (NOLOCK)
            WHERE PD.OrderKey = @cOrderKey
               AND PD.Status = '5' 
               AND PD.CaseID = ''
               AND PD.SKU = @cSKU
      END
      ELSE IF @cLoadKey <> ''
      BEGIN
         INSERT INTO @tPKD (PickDetailKey, CaseID, PickHeaderKey, OrderKey, OrderLineNumber, SKU, Qty, AdjustQty,Lot, UOM,
						 UOMQty, DropID, Loc, ID, PackKey, CartonGroup, PickMethod, WaveKey, StorerKey)
            SELECT	PD.PickDetailKey, CaseID, PickHeaderKey, PD.OrderKey, PD.OrderLineNumber, SKU, Qty, 0, Lot, UOM,
	   		         UOMQty, DropID, Loc, ID, PackKey, CartonGroup, PickMethod, WaveKey, Storerkey
            FROM dbo.LoadPlanDetail LPD WITH (NOLOCK) 
               JOIN dbo.PickDetail PD (NOLOCK) ON (PD.OrderKey = LPD.OrderKey) 
            WHERE LPD.LoadKey = @cLoadKey
               AND PD.Status = '5'
               AND PD.CaseID = ''
               AND PD.SKU = @cSKU
      END
            
      IF @@ERROR <> 0
      BEGIN
         SET @nErrNo = 218401
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Gen tPKD Fail'
         GOTO RollBackTran
      END

      SELECT @nTotalNoPackQty = ISNULL( SUM(QTY), 0)
      FROM @tPKD
      WHERE CaseID = ''

      IF @bDebugFlag = 1
      BEGIN
         SELECT 'Total Unpacked Qty', @nTotalNoPackQty
         SELECT 'Fill In @tPKD'
         SELECT * FROM @tPKD
      END

      IF @nTotalNoPackQty = 0
      BEGIN
         SET @nErrNo = 218413
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'NothingToPack'
         GOTO RollBackTran
      END

      IF @nBalQty > @nTotalNoPackQty
      BEGIN
         SET @nErrNo = 218414
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'ExceedUnPackQty'
         GOTO RollBackTran
      END

      WHILE @nBalQty > 0
      BEGIN
         SET @cPickDetailKey        = ''
         SET @cNewPickDetailKey     = ''
         SET @cPKDPickHeaderKey     = ''
         SET @cPKDOrderKey          = ''          
         SET @cPKDOrderLineNumber   = ''    
         SET @cPKDLot               = ''                
         SET @cPKDDropID            = ''       
         SET @cPKDLoc               = ''
         SET @cPKDID                = ''
         SET @nPkdQty               = 0
         SET @cNewFlag              = 'N'

         SELECT TOP 1 
            @cPickDetailKey      = PickDetailKey,
            @cPKDOrderKey        = OrderKey,          
            @cPKDOrderLineNumber = OrderLineNumber,    
            @cPKDLot             = Lot,                
            @cPKDDropID          = DropID,       
            @cPKDLoc             = Loc,
            @cPKDID              = ID,
            @cPKDWeaveKey        = WaveKey,
            @nPkdQTY             = Qty
         FROM @tPKD
         WHERE (Qty - AdjustQty) >0
            AND New = 'N'
            AND CaseID = ''
         ORDER BY QTY DESC, OrderKey, OrderLineNumber, LOT, LOC, ID, DropID

         IF @cPickDetailKey = ''
         BEGIN
            SET @nErrNo = 218402
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --GetPKDFail
            GOTO RollBackTran
         END

         IF @bDebugFlag = 1
            SELECT 'PKD Found', @cPickDetailKey AS PKDKey, @nBalQty AS BalQty, @nPkdQty AS PKDQty

         IF @nBalQty < @nPkdQty
         BEGIN
            IF @bDebugFlag = 1
               SELECT 'Split old PKD'

            --Adjust PKD qty
            UPDATE @tPKD SET AdjustQty = AdjustQty - @nBalQty
            WHERE PickDetailKey = @cPickDetailKey

            --IF exists a pkd without case id but has all same attributes, then add qty to that one
            SELECT @cNewPickDetailKey = PickDetailKey FROM PICKDETAIL WITH (NOLOCK) 
            WHERE Storerkey = @cStorerKey AND CaseID = @cLabelNo AND OrderKey = @cPKDOrderKey AND OrderLineNumber = @cPKDOrderLineNumber
               AND Lot = @cPKDLot AND SKU = @cSKU AND Status = '5' AND DropID = @cPKDDropID AND Loc = @cPKDLoc
               AND ID = @cPKDID AND WaveKey = @cPKDWeaveKey

            IF @cNewPickDetailKey <> ''
            BEGIN
               IF @bDebugFlag = 1
                  SELECT 'Found PKD with all same attributes, increas qty', @cNewPickDetailKey AS PKDKey

               -- insert PKD to @tPKD to increas qty same as the qty add to the carton
               INSERT INTO @tPKD (PickDetailKey, CaseID, PickHeaderKey, OrderKey, OrderLineNumber, SKU, Qty, AdjustQty,Lot, UOM,
                     UOMQty, DropID, Loc, ID, PackKey, CartonGroup, PickMethod, WaveKey, StorerKey)
                  SELECT	PickDetailKey, CaseID, PickHeaderKey, OrderKey, OrderLineNumber, SKU, QTY, ABS(@nBalQty), Lot, UOM,
                        UOMQty, DropID, Loc, ID, PackKey, CartonGroup, PickMethod, WaveKey, Storerkey
                  FROM PickDetail WITH (NOLOCK)
                  WHERE PickDetailKey = @cNewPickDetailKey
               
               IF @@ERROR <> 0
               BEGIN
                  SET @nErrNo = 218406
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'InsExtPkdFail'
                  GOTO RollBackTran
               END
            END -- newPKDKey <> ''
            ELSE 
            BEGIN
               -- Generate new pkd
               EXECUTE dbo.nspg_GetKey
                  'PICKDETAILKEY',
                  10 ,
                  @cNewPickDetailKey OUTPUT,
                  @bSuccess          OUTPUT,
                  @nErrNo            OUTPUT,
                  @cErrMsg           OUTPUT

               IF @bSuccess <> 1
               BEGIN
                  SET @nErrNo = 218403
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --GetKey Fail
                  GOTO RollBackTran
               END

               IF ISNULL(@cNewPickDetailKey, '') = ''
               BEGIN
                  SET @nErrNo = 218408
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --GenPKDKeyFail
                  GOTO RollBackTran
               END

               IF @bDebugFlag = 1
                  SELECT 'Gen new tPKD record', @cNewPickDetailKey AS NewPKDKey

               INSERT INTO @tPKD (PickDetailKey, CaseID, PickHeaderKey, OrderKey, OrderLineNumber, SKU, Qty, AdjustQty,Lot, UOM,
                     UOMQty, DropID, Loc, ID, PackKey, CartonGroup, PickMethod, WaveKey, StorerKey, New)
                  SELECT	@cNewPickDetailKey, @cLabelNo, PickHeaderKey, OrderKey, OrderLineNumber, SKU, ABS(@nBalQty), 0, Lot, '6',
                        1, DropID, Loc, ID, PackKey, CartonGroup, PickMethod, WaveKey,StorerKey,'Y'
                  FROM @tPKD
                  WHERE PickDetailKey = @cPickDetailKey

               IF @@ERROR <> 0
               BEGIN
                  SET @nErrNo = 218404
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'InsNewPkdFail'
                  GOTO RollBackTran
               END
            END -- Generate new pkd

         END -- @nBalQty < @nPkdQty
         ELSE -- @nBalQty >= @nPkdQty
         BEGIN
            IF @bDebugFlag = 1
               SELECT 'Update existing PKD'

            --IF exists a pkd with same case id and has all same attributes, then add qty to that one
            SELECT @cNewPickDetailKey = PickDetailKey FROM PICKDETAIL WITH (NOLOCK) 
            WHERE Storerkey = @cStorerKey AND CaseID = @cLabelNo AND OrderKey = @cPKDOrderKey AND OrderLineNumber = @cPKDOrderLineNumber
               AND Lot = @cPKDLot AND SKU = @cSKU AND Status = '5' AND DropID = @cPKDDropID AND Loc = @cPKDLoc
               AND ID = @cPKDID AND WaveKey = @cPKDWeaveKey

            IF @cNewPickDetailKey <> ''
            BEGIN
               IF @bDebugFlag = 1
                  SELECT 'Found PKD with all same attributes, increas qty, delete original one', @cNewPickDetailKey AS PKDKey

               -- insert PKD to @tPKD to increas qty same as the qty take out from the carton
               IF NOT EXISTS (SELECT 1 FROM @tPKD WHERE PickDetailKey = @cNewPickDetailKey)
               BEGIN
                  IF @bDebugFlag = 1
                     SELECT 'Found PKD not Exist in @tPKD, Insert it'

                  INSERT INTO @tPKD (PickDetailKey, CaseID, PickHeaderKey, OrderKey, OrderLineNumber, SKU, Qty, AdjustQty,Lot, UOM,
                        UOMQty, DropID, Loc, ID, PackKey, CartonGroup, PickMethod, WaveKey, StorerKey)
                     SELECT	PickDetailKey, CaseID, PickHeaderKey, OrderKey, OrderLineNumber, SKU, QTY, @nPkdQty, Lot, UOM,
                           UOMQty, DropID, Loc, ID, PackKey, CartonGroup, PickMethod, WaveKey, Storerkey
                     FROM PickDetail WITH (NOLOCK)
                     WHERE PickDetailKey = @cNewPickDetailKey
                  
                  IF @@ERROR <> 0
                  BEGIN
                     SET @nErrNo = 218406
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'InstPkdFail'
                     GOTO RollBackTran
                  END
               END -- Not exists
               ELSE
               BEGIN -- Exists in @tPkd
                  IF @bDebugFlag = 1
                     SELECT 'Found PKD already Exists in @tPKD, update it'

                  UPDATE @tPKD SET AdjustQty = AdjustQty + @nPkdQty WHERE PickDetailKey = @cNewPickDetailKey

                  IF @@ERROR <> 0
                  BEGIN
                     SET @nErrNo = 218411
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdtPKDFail'
                     GOTO RollBackTran
                  END
               END

               IF @bDebugFlag = 1
                  SELECT 'Mark the original PKD as delete', @cPickDetailKey

               --Mark to delete the original pkd
               UPDATE @tPKD SET New = 'D' WHERE PickDetailKey = @cPickDetailKey

               IF @@ERROR <> 0
               BEGIN
                  SET @nErrNo = 218411
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdtPKDFail'
                  GOTO RollBackTran
               END

            END -- newPKDKey <> ''
            ELSE
            BEGIN
               IF @bDebugFlag = 1
                  SELECT 'Upd pkd caseid to the scanned label no'

               -- Set case id to empty
               UPDATE @tPKD SET  CaseID = @cLabelNo  WHERE PickDetailKey = @cPickDetailKey
            END

         END -- @nBalQty >= @nPkdQty

         SET @nBalQty = @nBalQty - @nPkdQTY

      END -- while @nBalQty > 0


   END -- @nBalQty >0

   IF @bDebugFlag = 1
   BEGIN
      SELECT 'Applied to real PKD'
      SELECT * FROM @tPKD
   END

   --------------------------------------------------------------------------------------------------------------
   --Update back to PickDetail
   --------------------------------------------------------------------------------------------------------------

   -- Delete the pickdetail record which is marked as deleted in tPKD
   IF @bDebugFlag = 1
      SELECT 'Delete PickDetail'

   DELETE pkd
   FROM pickdetail pkd INNER JOIN @tPKD t
      ON pkd.PickDetailKey = t.PickDetailKey
   WHERE t.New = 'D'

   IF @@ERROR <> 0
   BEGIN
      SET @nErrNo = 218412
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'DelPKDFail'
      GOTO RollBackTran
   END

   IF @bDebugFlag = 1
      SELECT 'Update PickDetail'

   UPDATE pkd SET 
      pkd.CaseID  = t.CaseID,
      pkd.Qty     = t.Qty + t.AdjustQty,
      pkd.UOM     = '6',
      pkd.UOMQty  = 1
   FROM pickdetail pkd INNER JOIN @tPKD t
      ON pkd.pickdetailkey = t.pickdetailkey AND t.New <> 'D'
   
   IF @@ERROR <> 0
   BEGIN
      SET @nErrNo = 218407
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdPKDFail'
      GOTO RollBackTran
   END

   --Split the update and insert code to avoid lotxlocxid check constraints
   IF @bDebugFlag = 1
      SELECT 'Insert PickDetail'

   INSERT INTO pickdetail (PickDetailKey, CaseID, PickHeaderKey, OrderKey, OrderLineNumber, SKU, Qty, Lot, StorerKey, UOM,
               UOMQty, DropID, Loc, ID, PackKey, CartonGroup, PickMethod, WaveKey)
   SELECT  PickdetailKey,  CaseID,  PickHeaderKey,  OrderKey,  OrderLineNumber,  SKU,  Qty,  lot, @cStorerKey,  UOM,
            UOMQty,  DropID,  Loc,  ID,  PackKey,  CartonGroup,  PickMethod, WaveKey
   FROM @tPKD WHERE NEW = 'Y'

   IF @@ERROR <> 0
   BEGIN
      SET @nErrNo = 218409
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'InsPKDFail'
      GOTO RollBackTran
   END

   UPDATE pkd SET status = '5'
   FROM pickdetail pkd JOIN @tPKD t
      ON pkd.PickDetailKey = t.PickDetailKey
   WHERE t.New = 'Y'

   IF @@ERROR <> 0
   BEGIN
      SET @nErrNo = 218410
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdPKDFail'
      GOTO RollBackTran
   END


   EVENTLOG:
      --YeeKung      
      EXEC RDT.rdt_STD_EventLog           
      @cActionType         = '3',              
      @nMobileNo           = @nMobile,        
      @nFunctionID         = @nFunc,        
      @cFacility           = @cFacility,        
      @cStorerKey          = @cStorerkey,       
      @nQTY                = @nQTY,          
      @cUCC                = @cUCCNo,    
      @cOrderKey           = @cOrderKey,    
      @cSKU                = @cSKU,  
      @cRefNo1             = @nCartonNo,
      @cPickSlipNo         = @cPickSlipNo,   -- ZG01
      @cLabelNo            = @cLabelNo       -- ZG01

   COMMIT TRAN rdt_Pack_Confirm20
   GOTO Quit

   RollBackTran:
   BEGIN
      ROLLBACK TRAN rdt_Pack_Confirm20 -- Only rollback change made here
      IF @cNewCarton = 'Y'
      BEGIN
         SET @nCartonNo = 0
         SET @cLabelNo = ''
      END

      IF @bDebugFlag = 1
         SELECT 'Rollback Tran', @nErrNo AS ErrNo, @cErrMsg AS ErrMsg
         SELECT * FROM @tPKD

   END --rollback

   Quit:
      WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
      COMMIT TRAN
END -- End SP

GO