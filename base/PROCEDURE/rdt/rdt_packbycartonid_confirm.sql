SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store procedure: rdt_PackByCartonID_Confirm                          */
/* Copyright      : IDS                                                 */
/*                                                                      */
/* Purpose: Pick and pack confirm                                       */
/*                                                                      */
/* Called from: rdtfnc_PackByCartonID                                   */
/*                                                                      */
/* Date        Rev  Author      Purposes                                */
/* 14-Jan-2019 1.0  James       WMS8119.Created                         */
/************************************************************************/

CREATE PROC [RDT].[rdt_PackByCartonID_Confirm] (
   @nMobile       INT,
   @nFunc         INT,
   @cLangCode     NVARCHAR( 3),
   @cStorerKey    NVARCHAR( 15),
   @cFacility     NVARCHAR( 5), 
   @cWaveKey      NVARCHAR( 10), 
   @cDropID       NVARCHAR( 20),
   @cSKU          NVARCHAR( 20), 
   @cCaseID       NVARCHAR( 20), 
   @cSerialNo     NVARCHAR( MAX), 
   @nErrNo        INT            OUTPUT,
   @cErrMsg       NVARCHAR( 20)  OUTPUT
)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF

   DECLARE @nTranCount     INT
   DECLARE @fCaseCount     FLOAT
   DECLARE @cUOM           NVARCHAR( 10)
   DECLARE @cZone          NVARCHAR( 10)
   DECLARE @cPH_LoadKey    NVARCHAR( 10)
   DECLARE @cPH_OrderKey   NVARCHAR( 10)
   DECLARE @cPickDetailKey NVARCHAR( 10)
   DECLARE @cLoadKey       NVARCHAR( 10)
   DECLARE @nCaseCount     INT
   DECLARE @nQTY_PD        INT
   DECLARE @bSuccess       INT
   DECLARE @n_err          INT
   DECLARE @c_errmsg       NVARCHAR( 20)
   DECLARE @cUserName      NVARCHAR( 18)
   DECLARE @cShipperKey    NVARCHAR( 15)
   DECLARE @cPickConfirmStatus NVARCHAR( 1)
   DECLARE @cDataCapture       NVARCHAR(1)
   DECLARE @cSerialNoCapture   NVARCHAR(1)
   DECLARE @cSQL           NVARCHAR( MAX)
   DECLARE @cSQLParam      NVARCHAR( MAX)
   DECLARE @cRoute         NVARCHAR( 20)
   DECLARE @cOrderRefNo    NVARCHAR( 18)
   DECLARE @cConsigneekey  NVARCHAR( 15)
   DECLARE @cLot           NVARCHAR( 10)
   DECLARE @cLabelNo       NVARCHAR( 20)
   DECLARE @nCartonNo      INT
   DECLARE @cLabelLine     NVARCHAR( 5)
   DECLARE @nSrCartonNo    INT
   DECLARE @cSrLabelLine   NVARCHAR( 5)
   DECLARE @nRowCount      INT
   DECLARE @nPackSerialNoKey  INT
   DECLARE @cChkSerialSKU  NVARCHAR( 20)
   DECLARE @nChkSerialQTY  INT
   DECLARE @cTempSerialNo  NVARCHAR( 60)
   DECLARE @cShipLabel     NVARCHAR( 10)
   DECLARE @cDelNotes      NVARCHAR( 10)
   DECLARE @cPaperPrinter  NVARCHAR( 10)
   DECLARE @cLabelPrinter  NVARCHAR( 10)
   DECLARE @nStart         INT 
   DECLARE @nLen           INT 
   DECLARE @nSerialNo_Cnt  INT
   DECLARE @ni             INT
   DECLARE @nStep          INT
   DECLARE @nInputKey      INT
   DECLARE @nQty           INT
   DECLARE @nSum_Picked    INT
   DECLARE @nSum_Packed    INT
   DECLARE @nPackDetailInfoKey BIGINT  
   DECLARE @cGenLabelNo_SP NVARCHAR( 20)
   DECLARE @tSerialNo TABLE
   ( SerialNo  NVARCHAR( 30) NOT NULL PRIMARY KEY CLUSTERED, i INT)

   DECLARE @cErrMsg1       NVARCHAR( 20)

   SET @nErrNo = 0

   SELECT @cLabelPrinter = Printer,
          @cPaperPrinter = Printer_Paper,
          @cUserName = UserName
   FROM RDT.RDTMOBREC WITH (NOLOCK)
   WHERE Mobile = @nMobile

   -- Get extended ExtendedPltBuildCfmSP
   DECLARE @cExtendedPackCfmSP NVARCHAR(20)
   SET @cExtendedPackCfmSP = rdt.rdtGetConfig( @nFunc, 'ExtendedPackCfmSP', @cStorerKey)
   IF @cExtendedPackCfmSP = '0'
      SET @cExtendedPackCfmSP = ''  

   SET @cGenLabelNo_SP = rdt.RDTGetConfig( @nFunc, 'GenLabelNo_SP', @cStorerKey) 
   IF @cGenLabelNo_SP = '0'
      SET @cGenLabelNo_SP = ''  

   -- Extended putaway
   IF @cExtendedPackCfmSP <> ''
   BEGIN
      IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedPackCfmSP AND type = 'P')
      BEGIN
         SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedPackCfmSP) +
            ' @nMobile, @nFunc, @cLangCode, @cStorerKey, @cFacility, @cWaveKey, @cDropID, ' + 
            ' @cSKU, @cCaseID, @cSerialNo, @nErrNo OUTPUT, @cErrMsg OUTPUT'
         SET @cSQLParam =
            '@nMobile         INT,                  ' +
            '@nFunc           INT,                  ' +
            '@cLangCode       NVARCHAR( 3),         ' +
            '@cStorerKey      NVARCHAR( 15),        ' +
            '@cFacility       NVARCHAR( 5),         ' + 
            '@cWaveKey        NVARCHAR( 10),        ' +
            '@cDropID         NVARCHAR( 20),        ' +
            '@cSKU            NVARCHAR( 20),        ' +
            '@cCaseID         NVARCHAR( 20),        ' +
            '@cSerialNo       NVARCHAR( MAX),       ' +
            '@nErrNo          INT           OUTPUT, ' +
            '@cErrMsg         NVARCHAR( 20) OUTPUT  '

         EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
            @nMobile, @nFunc, @cLangCode, @cStorerKey, @cFacility, @cWaveKey, @cDropID, 
            @cSKU, @cCaseID, @cSerialNo, @nErrNo OUTPUT, @cErrMsg OUTPUT

         IF @nErrNo <> 0
            GOTO Fail
      END
   END
   ELSE
   BEGIN
      SET @nTranCount = @@TRANCOUNT
      BEGIN TRAN
      SAVE TRAN rdt_PackByCartonID_Confirm

      SET @cPickConfirmStatus = rdt.RDTGetConfig( @nFunc, 'PickConfirmStatus', @cStorerKey)
      IF @cPickConfirmStatus = '0'
         SET @cPickConfirmStatus = '5'

      IF NOT EXISTS ( SELECT 1
         FROM dbo.PickDetail PD (NOLOCK)     
         JOIN dbo.WaveDetail WD (NOLOCK) ON (PD.OrderKey = WD.OrderKey)    
         WHERE WD.WaveKey = @cWaveKey
         AND   PD.Status < @cPickConfirmStatus
         AND   PD.Status <> '4'
         AND   PD.QTY > 0
         AND   PD.SKU = @cSKU
         AND   PD.UOM = '2'
         AND   PD.StorerKey  = @cStorerKey)
      BEGIN
         SET @nErrNo = 137151
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Fully Picked'
         GOTO RollBackTran
      END  

      SELECT @cUOM = RTRIM(PACK.PACKUOM3), 
             @fCaseCount = PACK.CaseCnt
      FROM dbo.PACK PACK WITH (NOLOCK)
      JOIN dbo.SKU SKU WITH (NOLOCK) ON (SKU.Packkey = PACK.Packkey)
      WHERE SKU.Storerkey = @cStorerKey
      AND   SKU.SKU = @cSKU

      SET @nCaseCount = rdt.rdtFormatFloat( @fCaseCount)

      IF ISNULL( @nCaseCount, 0) <= 0
      BEGIN
         SET @nErrNo = 137152
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Casecnt = 0'
         GOTO RollBackTran
      END
      SET @nQty = @nCaseCount

      DECLARE curPD CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT PD.PickDetailKey, Qty
      FROM dbo.PickDetail PD WITH (NOLOCK) 
      WHERE PD.WaveKey = @cWaveKey
      AND   PD.StorerKey = @cStorerKey
      AND   PD.UOM = '2'
      AND   PD.Status < @cPickConfirmStatus
      AND   PD.Status <> '4'
      AND   PD.SKU = @cSKU
      AND   ISNULL( PD.CaseID, '') = ''
      AND   PD.QTY > 0
      GROUP BY PickDetailKey, Qty
      HAVING ( Qty % @nCaseCount = 0) -- filter pickdetail line that only contain full case qty
      ORDER BY PD.PickDetailKey
      OPEN curPD
      FETCH NEXT FROM curPD INTO @cPickDetailKey, @nQTY_PD
      WHILE @@FETCH_STATUS <> -1
      BEGIN
         -- Get PickDetail info  
         DECLARE @cPD_LoadKey      NVARCHAR( 10)  
         DECLARE @cPD_OrderKey     NVARCHAR( 10)  
         DECLARE @cOrderLineNumber NVARCHAR( 5)  
         SELECT 
            @cPD_Loadkey = O.LoadKey, 
            @cPD_OrderKey = OD.OrderKey, 
            @cOrderLineNumber = OD.OrderLineNumber,
            @cLot = PD.LOT
         FROM dbo.PickDetail PD WITH (NOLOCK) 
         INNER JOIN dbo.OrderDetail OD WITH (NOLOCK) ON (OD.OrderKey = PD.OrderKey AND OD.OrderLineNumber = PD.OrderLineNumber)
         INNER JOIN dbo.Orders O WITH (NOLOCK) ON (OD.OrderKey = O.OrderKey)
         WHERE PD.PickDetailkey = @cPickDetailKey  

         -- Get PickSlipNo  
         DECLARE @cPickSlipNo NVARCHAR(10)  
         SET @cPickSlipNo = ''  
         SELECT @cPickSlipNo = PickHeaderKey FROM PickHeader WITH (NOLOCK) WHERE OrderKey = @cPD_OrderKey  
         IF @cPickSlipNo = ''  
            SELECT TOP 1 @cPickSlipNo = PickHeaderKey FROM PickHeader WITH (NOLOCK) WHERE ExternOrderKey = @cPD_Loadkey  

         -- Exact match
         IF @nQTY_PD = @nQty
         BEGIN
            -- Confirm PickDetail
            UPDATE dbo.PickDetail WITH (ROWLOCK) SET
               DropID = @cDropID,
               CaseID = @cCaseID,
               Status = @cPickConfirmStatus
            WHERE PickDetailKey = @cPickDetailKey

            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 137153
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'OffSetPDtlFail'
               GOTO RollBackTran
            END

            SET @nQty = 0 -- Reduce balance
         END
         -- PickDetail have less
         ELSE IF @nQTY_PD < @nQty
         BEGIN
            -- Confirm PickDetail
            UPDATE dbo.PickDetail WITH (ROWLOCK) SET
               DropID = @cDropID,
               CaseID = @cCaseID,
               Status = @cPickConfirmStatus
            WHERE PickDetailKey = @cPickDetailKey

            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 137154
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'OffSetPDtlFail'
               GOTO RollBackTran
            END
            ELSE

            SET @nQty = 0 -- Reduce balance
         END
         -- PickDetail have more, need to split
         ELSE IF @nQTY_PD > @nQty
         BEGIN
            DECLARE @cNewPickDetailKey NVARCHAR( 10)
            EXECUTE dbo.nspg_GetKey
               'PICKDETAILKEY',
               10 ,
               @cNewPickDetailKey OUTPUT,
               @bSuccess          OUTPUT,
               @n_err             OUTPUT,
               @c_errmsg          OUTPUT

            IF @bSuccess <> 1
            BEGIN
               SET @nErrNo = 137155
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- 'GetDetKeyFail'
               GOTO RollBackTran
            END

            -- Create a new PickDetail to hold the balance
            INSERT INTO dbo.PICKDETAIL (
               CaseID, PickHeaderKey, OrderKey, OrderLineNumber, LOT, StorerKey, SKU, AltSKU, UOM, UOMQTY, QTYMoved,
               Status, DropID, LOC, ID, PackKey, UpdateSource, CartonGroup, CartonType, ToLoc, DoReplenish, ReplenishZone,
               DoCartonize, PickMethod, WaveKey, EffectiveDate, ArchiveCop, ShipFlag, PickSlipNo, PickDetailKey,
               QTY,
               TrafficCop,
               OptimizeCop)
            SELECT
               CaseID, PickHeaderKey, OrderKey, OrderLineNumber, Lot, StorerKey, SKU, AltSku, UOM, UOMQTY, QTYMoved,
               Status, DropID, LOC, ID, PackKey, UpdateSource, CartonGroup, CartonType, ToLoc, DoReplenish, ReplenishZone,
               DoCartonize, PickMethod, WaveKey, EffectiveDate, ArchiveCop, ShipFlag, PickSlipNo, @cNewPickDetailKey,
               @nQTY_PD - @nQty, -- QTY
               NULL, --TrafficCop,
               '1'  --OptimizeCop
            FROM dbo.PickDetail WITH (NOLOCK)
            WHERE PickDetailKey = @cPickDetailKey

            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 137156
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Ins PDtl Fail'
               GOTO RollBackTran
            END

            IF EXISTS( SELECT 1 FROM RefKeyLookup WITH (NOLOCK) WHERE PickDetailKey = @cPickDetailKey)
            BEGIN
               INSERT INTO dbo.RefKeyLookup (PickDetailkey, Pickslipno, OrderKey, OrderLineNumber, Loadkey)  
               VALUES (@cNewPickDetailKey, @cPickSlipNo, @cPD_OrderKey, @cOrderLineNumber, @cPD_Loadkey)  

               IF @@ERROR <> 0  
               BEGIN  
                  SET @nErrNo = 137157  
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- INS RefKeyFail  
                  GOTO RollBackTran  
               END  
            END

            -- Change orginal PickDetail with exact QTY (with TrafficCop)
            UPDATE dbo.PickDetail WITH (ROWLOCK) SET
               QTY = @nQty,
               EditDate = GETDATE(),
               EditWho  = SUSER_SNAME(),
               Trafficcop = NULL
            WHERE PickDetailKey = @cPickDetailKey

            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 137158
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'OffSetPDtlFail'
               GOTO RollBackTran
            END

            -- If short pick & no split line needed. Update pickdetail.qty with no trafficcop
            -- Change orginal PickDetail with exact QTY (with TrafficCop)
            UPDATE dbo.PickDetail WITH (ROWLOCK) SET
               DropID = @cDropID,
               CaseID = @cCaseID,
               Status = @cPickConfirmStatus
            WHERE PickDetailKey = @cPickDetailKey

            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 137168
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'OffSetPDtlFail'
               GOTO RollBackTran
            END

            SET @nQty = 0 -- Reduce balance
         END

         IF @nQty = 0 
         BEGIN
            BREAK 
         END

         FETCH NEXT FROM curPD INTO @cPickDetailKey, @nQTY_PD
      END
      CLOSE curPD
      DEALLOCATE curPD

      IF NOT EXISTS (SELECT 1 FROM dbo.PackDetail WITH (NOLOCK) 
         WHERE StorerKey = @cStorerKey
            AND PickSlipNo = @cPickSlipNo
            AND RefNo2 = @cCaseID)
      BEGIN
         IF NOT EXISTS (SELECT 1 FROM dbo.PackHeader WITH (NOLOCK) WHERE Pickslipno = @cPickSlipNo)
         BEGIN
            SELECT @cRoute = [Route], 
                   @cOrderRefNo = SUBSTRING(ExternOrderKey, 1, 18), 
                   @cConsigneekey = ConsigneeKey 
            FROM dbo.Orders WITH (NOLOCK) 
            WHERE OrderKey = @cPD_OrderKey
            AND   StorerKey = @cStorerKey
   
            INSERT INTO dbo.PackHeader
            (Route, OrderKey, OrderRefNo, Loadkey, Consigneekey, StorerKey, PickSlipNo)
            VALUES
            (@cRoute, @cPD_OrderKey, @cOrderRefNo, @cLoadKey, @cConsigneekey, @cStorerKey, @cPickSlipNo)

            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 137159
               SET @cErrMsg = rdt.rdtgetmessage( 66040, @cLangCode, 'DSP') --'InsPHdrFail'
               GOTO RollBackTran
            END 
         END

         SET @nCartonNo = 0

         SET @cLabelNo = ''

         IF @cGenLabelNo_SP <> '' AND 
            EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cGenLabelNo_SP AND type = 'P')
         BEGIN
            SET @nErrNo = 0
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cGenLabelNo_SP) +     
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerkey, ' + 
               ' @cWaveKey, @cPickSlipNo, @cDropID, @cSKU, @cCaseID, @cSerialNo, @nQty, ' +
               ' @cLabelNo OUTPUT, @nCartonNo OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT '    

               SET @cSQLParam =    
                  '@nMobile                   INT,           ' +
                  '@nFunc                     INT,           ' +
                  '@cLangCode                 NVARCHAR( 3),  ' +
                  '@nStep                     INT,           ' +
                  '@nInputKey                 INT,           ' +
                  '@cFacility                 NVARCHAR( 5),  ' +
                  '@cStorerkey                NVARCHAR( 15), ' +
                  '@cWaveKey                  NVARCHAR( 10), ' +
                  '@cPickSlipNo               NVARCHAR( 10), ' +
                  '@cDropID                   NVARCHAR( 20), ' +
                  '@cSKU                      NVARCHAR( 20), ' +
                  '@cCaseID                   NVARCHAR( 20), ' +
                  '@cSerialNo                 NVARCHAR( MAX), ' +
                  '@nQty                      INT, ' +
                  '@cLabelNo                  NVARCHAR( 20) OUTPUT, ' +
                  '@nCartonNo                 INT           OUTPUT, ' +
                  '@nErrNo                    INT           OUTPUT, ' +
                  '@cErrMsg                   NVARCHAR( 20) OUTPUT  ' 
               
               EXEC sp_ExecuteSQL @cSQL, @cSQLParam,     
                  @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerkey, 
                  @cWaveKey, @cPickSlipNo, @cDropID, @cSKU, @cCaseID, @cSerialNo, @nCaseCount,
                  @cLabelNo OUTPUT, @nCartonNo OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT 

               IF @nErrNo <> 0
                  GOTO RollBackTran
         END
         ELSE
         BEGIN
            EXECUTE dbo.nsp_GenLabelNo
               '',
               @cStorerKey,
               @c_labelno     = @cLabelNo  OUTPUT,
               @n_cartonno    = @nCartonNo OUTPUT,
               @c_button      = '',
               @b_success     = @bSuccess  OUTPUT,
               @n_err         = @n_err     OUTPUT,
               @c_errmsg      = @c_errmsg  OUTPUT

            IF @bSuccess <> 1
            BEGIN
               SET @nErrNo = 137160
               SET @cErrMsg = rdt.rdtgetmessage( 66038, @cLangCode, 'DSP') --'GenLabelFail'
               GOTO RollBackTran
            END
         END

         INSERT INTO dbo.PackDetail
            (PickSlipNo, CartonNo, LabelNo, LabelLine, StorerKey, SKU, QTY, Refno, AddWho, AddDate, EditWho, EditDate, DropID, RefNo2)
         VALUES
            (@cPickSlipNo, 0, @cLabelNo, '00000', @cStorerKey, @cSku, @nCaseCount,
            @cPickDetailKey, 'rdt.' + sUser_sName(), GETDATE(), 'rdt.' + sUser_sName(), GETDATE(), @cDropID, @cCaseID)

         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 137161
            SET @cErrMsg = rdt.rdtgetmessage( 66035, @cLangCode, 'DSP') --'InsPackDtlFail'
            GOTO RollBackTran
         END 

         SELECT TOP 1 @nSrCartonNo = CartonNo, @cSrLabelLine = LabelLine
         FROM dbo.PackDetail WITH (NOLOCK)
         WHERE PickSlipNo = @cPickSlipNo
         AND   LabelNo = @cLabelNo
      END -- CaseID not exists
      ELSE
      BEGIN
         IF NOT EXISTS (SELECT 1 FROM dbo.PackDetail WITH (NOLOCK) 
            WHERE StorerKey = @cStorerKey
               AND PickSlipNo = @cPickSlipNo
               AND RefNo2 = @cCaseID
               AND SKU = @cSKU)
         BEGIN
            SET @nCartonNo = 0

            SET @cLabelNo = ''

            SELECT @nCartonNo = CartonNo, @cLabelNo = LabelNo 
            FROM dbo.PackDetail WITH (NOLOCK)
            WHERE Pickslipno = @cPickSlipNo
               AND StorerKey = @cStorerKey
               AND RefNo2 = @cCaseID

            SELECT @cLabelLine = RIGHT( '00000' + CAST( CAST( IsNULL( MAX( LabelLine), 0) AS INT) + 1 AS NVARCHAR( 5)), 5)
            FROM dbo.PackDetail WITH (NOLOCK)
            WHERE Pickslipno = @cPickSlipNo
               AND CartonNo = @nCartonNo
               AND RefNo2 = @cCaseID

            INSERT INTO dbo.PackDetail
               (PickSlipNo, CartonNo, LabelNo, LabelLine, StorerKey, SKU, QTY, Refno, AddWho, AddDate, EditWho, EditDate, DropID, RefNo2)
            VALUES
               (@cPickSlipNo, @nCartonNo, @cLabelNo, @cLabelLine, @cStorerKey, @cSku, @nCaseCount,
               @cPickDetailKey, 'rdt.' + sUser_sName(), GETDATE(), 'rdt.' + sUser_sName(), GETDATE(), @cDropID, @cCaseID)

            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 137162
               SET @cErrMsg = rdt.rdtgetmessage( 66036, @cLangCode, 'DSP') --'InsPackDtlFail'
               GOTO RollBackTran
            END 

            SET @nSrCartonNo = @nCartonNo
            SET @cSrLabelLine = @cLabelLine
         END   -- DropID exists but SKU not exists (insert new line with same cartonno)
         ELSE
         BEGIN
            UPDATE dbo.PackDetail WITH (ROWLOCK) SET
               QTY = QTY + @nCaseCount,
               EditWho = SUSER_SNAME(),
               EditDate = GETDATE()
            WHERE StorerKey = @cStorerKey
            AND   PickSlipNo = @cPickSlipNo
            AND   RefNo2 = @cCaseID
            AND   SKU = @cSKU

            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 137163
               SET @cErrMsg = rdt.rdtgetmessage( 66037, @cLangCode, 'DSP') --'UpdPackDtlFail'
               GOTO RollBackTran
            END

            SELECT TOP 1 @nSrCartonNo = CartonNo, @cLabelNo = LabelNo, @cSrLabelLine = LabelLine
            FROM dbo.PackDetail WITH (NOLOCK)
            WHERE StorerKey = @cStorerKey
            AND   PickSlipNo = @cPickSlipNo
            AND   RefNo2 = @cCaseID
            AND   SKU = @cSKU
         END   -- DropID exists and SKU exists (update qty only)
      END

      -- Get SKU info  
      SELECT @cDataCapture = DataCapture, 
             @cSerialNoCapture = SerialNoCapture
      FROM SKU WITH (NOLOCK)   
      WHERE StorerKey = @cStorerKey   
      AND   SKU = @cSKU  

      -- Serial no
      IF @cSerialNoCapture IN ('1', '3') -- 1=Inbound and outbound, 3=outbound only 
      BEGIN
         SET @nSerialNo_Cnt = 0
         SET @nStart = 1
         SET @ni = 1
         SET @cTempSerialNo = ''
         --Get # of serial no within the string
         SET @nSerialNo_Cnt = SUM( LEN( RTRIM( @cSerialNo)) - LEN( REPLACE( RTRIM( @cSerialNo), ',', '')) + 1) 

         WHILE @nSerialNo_Cnt > 0
         BEGIN
            select @nLen = charindex( ',', @cSerialNo, @nStart)
            IF @nLen = 0
               SET @cTempSerialNo = @cSerialNo
            ELSE
               SET @cTempSerialNo = SUBSTRING( @cSerialNo, @nStart, @nLen-1)

            INSERT INTO @tSerialNo ( SerialNo, i) VALUES ( @cTempSerialNo, @ni)

            SET @cSerialNo = RIGHT( @cSerialNo, LEN( @cSerialNo) - @nLen)
            SET @nSerialNo_Cnt = @nSerialNo_Cnt - 1 
            SET @ni = @ni + 1
         END

         DECLARE @cur_SerialNo CURSOR
         SET @cur_SerialNo = CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
         SELECT SerialNo, i FROM @tSerialNo ORDER BY i
         OPEN @cur_SerialNo
         FETCH NEXT FROM @cur_SerialNo INTO @cTempSerialNo, @ni
         WHILE @@FETCH_STATUS = 0
         BEGIN
            -- Get serial no info
            SELECT 
               @nPackSerialNoKey = PackSerialNoKey, 
               @cChkSerialSKU = SKU, 
               @nChkSerialQTY = QTY
            FROM PackSerialNo WITH (NOLOCK)
            WHERE PickSlipNo = @cPickSlipNo
               AND StorerKey = @cStorerKey
               AND SKU = @cSKU
               AND SerialNo = @cTempSerialNo
            SET @nRowCount = @@ROWCOUNT
      
            -- New serial no
            IF @nRowCount = 0
            BEGIN

               -- Insert PackSerialNo 
               INSERT INTO PackSerialNo (PickSlipNo, CartonNo, LabelNo, LabelLine, StorerKey, SKU, SerialNo, QTY)
               VALUES (@cPickSlipNo, @nSrCartonNo, @cLabelNo, @cSrLabelLine, @cStorerKey, @cSKU, @cTempSerialNo, 1)
               IF @@ERROR <> 0
               BEGIN
                  SET @nErrNo = 137164
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --INS RDSNo Fail
                  GOTO RollBackTran
               END
            END
      
            -- Check serial no scanned
            ELSE
            BEGIN
               SET @nErrNo = 137165
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --SNO ady scan
               GOTO RollBackTran
            END

            FETCH NEXT FROM @cur_SerialNo INTO @cTempSerialNo, @ni
         END
         CLOSE @cur_SerialNo
         DEALLOCATE @cur_SerialNo
      END

      -- Capture Pack data  
      IF @cDataCapture IN ('1', '3') -- 1=Inbound and outbound, 3=outbound only 
      BEGIN  
         -- Get PackDetailInfo  
         SET @nPackDetailInfoKey = 0  
         SELECT @nPackDetailInfoKey = PackDetailInfoKey  
         FROM dbo.PackDetailInfo WITH (NOLOCK)   
         WHERE PickSlipNo = @cPickSlipNo   
            AND CartonNo = @nSrCartonNo  
            AND LabelNo = @cLabelNo   
            AND SKU = @cSKU  
            AND UserDefine01 = @cTempSerialNo  
            AND UserDefine02 = UserDefine02
            AND UserDefine03 = UserDefine03
        
         IF ISNULL( @nPackDetailInfoKey, 0) = 0  
         BEGIN  
            -- Insert PackDetailInfo  
            INSERT INTO dbo.PackDetailInfo (  
               PickSlipNo, CartonNo, LabelNo, LabelLine, StorerKey, SKU, QTY, UserDefine01, UserDefine02, UserDefine03,   
               AddWho, AddDate, EditWho, EditDate)  
            VALUES (  
               @cPickSlipNo, @nSrCartonNo, @cLabelNo, @cSrLabelLine, @cStorerKey, @cSKU, @nCaseCount, @cSerialNo, '', '',   
               'rdt.' + SUSER_SNAME(), GETDATE(), 'rdt.' + SUSER_SNAME(), GETDATE())  
            IF @@ERROR <> 0  
            BEGIN  
               SET @nErrNo = 137166  
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --INS PDInfoFail  
               GOTO RollBackTran  
            END  
         END  
         ELSE  
         BEGIN  
            -- Update PackDetailInfo  
            UPDATE dbo.PackDetailInfo SET     
               QTY = QTY + @nCaseCount,   
               EditWho = 'rdt.' + SUSER_SNAME(),   
               EditDate = GETDATE(),   
               ArchiveCop = NULL  
            WHERE PackDetailInfoKey = @nPackDetailInfoKey  
            IF @@ERROR <> 0  
            BEGIN  
               SET @nErrNo = 137167  
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD PDInfoFail  
               GOTO RollBackTran  
            END  
         END  
      END 

      SET @nSum_Picked = 0
      SELECT @nSum_Picked = ISNULL( SUM ( Qty), 0)
      FROM dbo.PickDetail PD WITH (NOLOCK)
      WHERE StorerKey = @cStorerKey
      AND   Status < '9'
      AND   EXISTS ( SELECT 1 FROM dbo.PackHeader PH WITH (NOLOCK)
                     WHERE PH.PickSlipNo = @cPickSlipNo
                     AND   PH.OrderKey = PD.OrderKey)
      
      SET @nSum_Packed = 0
      SELECT @nSum_Packed = ISNULL( SUM ( Qty), 0)
      FROM dbo.PackDetail WITH (NOLOCK)
      WHERE PickSlipNo = @cPickSlipNo

      IF @nSum_Picked = @nSum_Packed
      BEGIN
         UPDATE dbo.PackHeader WITH (ROWLOCK) SET 
            Status = '9'
         WHERE PickSlipNo = @cPickSlipNo
         AND   Status < '9'

         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 137169
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --PackCfm Fail
            GOTO RollBackTran
         END
      END

      GOTO Quit

      RollBackTran:
         ROLLBACK TRAN rdt_PackByCartonID_Confirm

      Quit:
         WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
            COMMIT TRAN rdt_PackByCartonID_Confirm

      IF @nErrNo <> 0
         GOTO Fail

      SET @cShipLabel = rdt.RDTGetConfig( @nFunc, 'ShipLabel', @cStorerKey)
      IF @cShipLabel = '0'
         SET @cShipLabel = ''

      IF @cShipLabel <> ''
      BEGIN
         SET @nErrNo = 0
         DECLARE @tSHIPPLABEL AS VariableTable
         INSERT INTO @tSHIPPLABEL (Variable, Value) VALUES ( '@cWaveKey',     @cWaveKey)
         INSERT INTO @tSHIPPLABEL (Variable, Value) VALUES ( '@cLoadKey',     @cLoadKey)
         INSERT INTO @tSHIPPLABEL (Variable, Value) VALUES ( '@cPickSlipNo',  @cPickSlipNo)
         INSERT INTO @tSHIPPLABEL (Variable, Value) VALUES ( '@cDropID',      @cDropID)
         INSERT INTO @tSHIPPLABEL (Variable, Value) VALUES ( '@cShipperKey',  @cShipperKey)
         INSERT INTO @tSHIPPLABEL (Variable, Value) VALUES ( '@nFromCartonNo',  @nSrCartonNo)
         INSERT INTO @tSHIPPLABEL (Variable, Value) VALUES ( '@nToCartonNo',    @nSrCartonNo)

         -- Print label
         EXEC RDT.rdt_Print @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerkey, @cLabelPrinter, '', 
            @cShipLabel, -- Report type
            @tSHIPPLABEL, -- Report params
            'rdt_PackByCartonID_Confirm', 
            @nErrNo  OUTPUT,
            @cErrMsg OUTPUT 
      END

      IF @nSum_Picked = @nSum_Packed
      BEGIN
         SET @cDelNotes = rdt.RDTGetConfig( @nFunc, 'DelNotes', @cStorerKey)
         IF @cDelNotes = '0'
            SET @cDelNotes = ''

         IF @cDelNotes <> ''
         BEGIN
            SET @nErrNo = 0
            DECLARE @tDelNotes AS VariableTable
            INSERT INTO @tDelNotes (Variable, Value) VALUES ( '@cPickSlipNo',  @cPickSlipNo)
            INSERT INTO @tDelNotes (Variable, Value) VALUES ( '@cOrderKey',  @cPD_OrderKey)

            -- Print label
            EXEC RDT.rdt_Print @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerkey, '', @cPaperPrinter, 
               @cDelNotes, -- Report type
               @tDelNotes, -- Report params
               'rdt_PackByCartonID_Confirm', 
               @nErrNo  OUTPUT,
               @cErrMsg OUTPUT 

            IF @nErrNo = 0
            BEGIN
               SET @cErrMsg1 = rdt.rdtGetMessage( 137170, @cLangCode, 'DSP') --Packing List Printed
               SET @nErrNo = 0
               EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, @cErrMsg1

               IF @nErrNo = 1
                  SET @cErrMsg1 = ''

               SET @nErrNo = 0
            END
         END
      END
   END

   Fail:
END

GO