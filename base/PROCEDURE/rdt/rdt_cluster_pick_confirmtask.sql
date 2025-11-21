SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_Cluster_Pick_ConfirmTask                        */
/* Copyright      : IDS                                                 */
/*                                                                      */
/* Purpose: Comfirm Pick                                                */
/*                                                                      */
/* Called from: rdtfnc_Cluster_Pick                                     */
/*                                                                      */
/* Exceed version: 5.4                                                  */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date        Rev  Author      Purposes                                */
/* 26-Sep-2008 1.0  James       Created                                 */
/* 12-Dec-2008 1.1  Vicky       Add TraceInfo (Vicky02)                 */
/* 03-Feb-2008 1.2  James       Update Pickdetail.Status = '4' for short*/
/*                              picked qty and Status = '5' for fully   */
/*                              picked qty                              */
/* 19-Mar-2009 1.3  James       SOS131967 - Bug fix. When split pd line,*/
/*                              update status '4' if short pick else    */
/*                              update with status = '0'                */
/* 23-Apr-2009 1.4  James       SOS133222 - Insert PackDetail (james01) */
/* 28-Aug-2009 1.50 Vicky       Add in EventLog (Vicky06)               */
/* 03-May-2010 1.14 James       SOS170848 - Picking by Conso (james02)  */
/* 24-Jun-2010 1.15 Leong       SOS# 176144 - Bug Fix                   */
/* 20-May-2010 1.18 James       SOS172041 - L'Oreal enhancement(james03)*/
/* 20-Jul-2010 1.19 James       Bug Fix (james04)                       */
/* 09-Aug-2010 1.20 James       Prevent overpack (james05)              */
/* 17-Aug-2010 1.21 ChewKP      Bug Fix (ChewKP01)                      */   
/* 18-Feb-2013 1.22 ChewKP      Bug Fix (ChewKP03)                      */
/* 30-Apr-2013 1.23 James       SOS276235 - Allow multi storer (james06)*/
/* 05-Jun-2013 1.24 James       Bug Fix (james07)                       */
/* 12-Jul-2013 1.47 James       AEO enhancement (james08)               */
/* 04-Apr-2014 1.48 James       Bug fix for conso pick (james09)        */
/* 19-Jun-2014 1.49 James       SOS313608 - Enable insert Dropid even no*/
/*                              packing (james10)                       */
/*                              Change Dropid to 20 chars               */
/* 01-Sep-2014 1.50 James       Allow reuse DropID if exists (james11)  */
/* 17-Jan-2017 1.51 James       IN00236610 - Bug fix on eventlog qty    */
/*                              insertion (james12)                     */
/* 23-Feb-2017 1.52 James       Performance tuning (james13)            */
/* 24-Feb-2017 1.53 TLTING      Performance Tune - Editdate,editwho     */
/* 07-Mar-2017 1.54 James       IN00284550 - Ins Refkeylookup (james14) */
/* 14-Apr-2017 1.55 James       WMS1626-Stamp pickdetail.caseid(james15)*/
/* 11-Sep-2017 1.56 James       WMS2941 - Add custom generate labelno   */
/*                              stored proc (james16)                   */
/* 14-May-2018 1.57 James       WMS4303 - Bug fix. Update labelno=caseid*/
/*                              only when labelno <> '' (james17)       */
/* 22-Oct-2020 1.58 James       WMS-15456 Add packinfo (james18)        */
/* 13-Aug-2020 1.59 James       INC1237019 - Temporarily fix check 1    */
/*                              order 1 dropid (james19)                */
/* 19-May-2021 1.60 James       WMS16756-Bug fix on short pick couldn't */
/*                              handle multi same sku, loc line(james20)*/
/* 14-Sep-2021 1.61 ian         INC1611727 - picking Error(ian01)       */
/************************************************************************/

CREATE   PROC [RDT].[rdt_Cluster_Pick_ConfirmTask] (
   @cStorerKey       NVARCHAR( 15),
   @cUserName        NVARCHAR( 15),
   @cFacility        NVARCHAR( 5),
   @cPutAwayZone     NVARCHAR( 10),
   @cPickZone        NVARCHAR( 10),
   @cOrderKey        NVARCHAR( 10),
   @cSKU             NVARCHAR( 20),
   @cPickSlipNo      NVARCHAR( 10),
   @cLOT             NVARCHAR( 10),
   @cLOC             NVARCHAR( 10),
   @cDropID          NVARCHAR( 20),
   @cStatus          NVARCHAR( 1),   -- 4 = PickInProgress ; 5 = Picked
   @cLangCode        NVARCHAR( 3),
   @nErrNo           INT          OUTPUT,
   @cErrMsg          NVARCHAR( 20) OUTPUT,  -- screen limitation, 20 NVARCHAR max
   @nMobile          INT, -- (Vicky06)
   @nFunc            INT  -- (Vicky06)
)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF

   DECLARE @b_success  INT,
   @n_err              INT,
   @c_errmsg           NVARCHAR( 250),
   @cPickDetailKey     NVARCHAR( 10),
   @nDropIDCnt         INT,
   @nPickQty           INT,
   @nQTY_PD            INT,
   @nRowRef            INT,
   @nTranCount         INT,
   @nRPLCount          INT,
   @nPackQty           INT,
   @nCartonNo          INT,
   @cLabelNo           NVARCHAR( 20),
   @cLabelLine         NVARCHAR( 5),
   @cInterModalVehicle NVARCHAR( 30),
   @cKeyname           NVARCHAR( 30),
   @cURNLabelNo        NVARCHAR( 10),
   @cURNNo             NVARCHAR( 32),
   @cConsigneeKey      NVARCHAR( 15),
   @cBUSR5             NVARCHAR( 30),
   @cItemClass         NVARCHAR( 10),
   @cExternOrderKey    NVARCHAR( 30),
   @cUOM               NVARCHAR( 10), -- (Vicky06)
   @cLoadKey           NVARCHAR( 10),  -- (james02)
   @cLoadDefaultPickMethod NVARCHAR( 1),  -- (james02)
   @nTotalPickedQty    INT,   -- (james05)
   @nTotalPackedQty    INT,   -- (james05)
   @nPickPackQty       INT,   -- (ChewKP02)
   @nMultiStorer       INT, 
   @cRoute             NVARCHAR( 20),  -- (james07)
   @cOrderRefNo        NVARCHAR( 18),  -- (james07)
   @cClusterPickInsPackInfo   NVARCHAR( 1),  -- (james08)
   @cCartonType        NVARCHAR( 10),  -- (james08)
   @cCube              NVARCHAR( 10),  -- (james08)
   @cWeight            NVARCHAR( 10),  -- (james08)
   @fCube              FLOAT,  -- (james08)
   @fWeight            FLOAT,  -- (james08)
   @fCtnWeight         FLOAT   -- (james08)

   DECLARE @cClusterPickOrder1DropID   NVARCHAR( 1)
   DECLARE @cClusterPickBatch1DropID   NVARCHAR( 1)
   DECLARE @cBatchKey                  NVARCHAR( 10)
   DECLARE @cCheckDropID               NVARCHAR( 20)
   DECLARE @nRowCount                  INT
   DECLARE @nBatchRowRef               INT
   DECLARE @cShortPickDetailKey        NVARCHAR( 10)

   -- (james15)
   DECLARE @cClusterPickUpdLabelNoToCaseID   NVARCHAR( 1),
           @cClusterPickGenLabelNo_SP        NVARCHAR( 1),
           @cSQLStatement                    NVARCHAR(2000),
           @cSQLParms                        NVARCHAR(2000),
           @cWaveKey                         NVARCHAR( 10),
           @nStep                            INT,
           @nInputKey                        INT

   -- TraceInfo (Vicky02) - Start
   DECLARE    @d_starttime    datetime,
              @d_endtime      datetime,
              @d_step1        datetime,
              @d_step2        datetime,
              @d_step3        datetime,
              @d_step4        datetime,
              @d_step5        datetime,
              @c_col1         NVARCHAR(20),
              @c_col2         NVARCHAR(20),
              @c_col3         NVARCHAR(20),
              @c_col4         NVARCHAR(20),
              @c_col5         NVARCHAR(20),
              @c_TraceName    NVARCHAR(80)

   SET @d_starttime = getdate()

   SET @c_col1 = @cOrderKey
   SET @c_col2 = @cPickZone
   SET @c_col3 = @cSKU
   SET @c_col4 = @cLOT
   SET @c_col5 = @cLOC

   SET @c_TraceName = 'rdt_Cluster_Pick_ConfirmTask'
   -- TraceInfo (Vicky02) - End
   -- If config turned on (svalue = '1'), check the DropID keyed in must have prefix 'ID'

   -- (james15)
   SET @cClusterPickUpdLabelNoToCaseID = rdt.RDTGetConfig( @nFunc, 'ClusterPickUpdLabelNoToCaseID', @cStorerKey) 

   -- (james16)
   SET @cClusterPickGenLabelNo_SP = rdt.RDTGetConfig( @nFunc, 'ClusterPickGenLabelNo_SP', @cStorerKey) 

   -- (james06)
   SET @nMultiStorer = 0
   IF EXISTS (SELECT 1 FROM dbo.StorerGroup WITH (NOLOCK) WHERE StorerGroup = @cStorerKey)
   BEGIN
      SELECT @cStorerKey = StorerKey FROM dbo.Orders WITH (NOLOCK) WHERE OrderKey = @cOrderKey
   END

   -- (james08)
   SET @cClusterPickInsPackInfo = rdt.RDTGetConfig( @nFunc, 'ClusterPickInsPackInfo', @cStorerKey)

   SET @cClusterPickOrder1DropID = rdt.RDTGetConfig( @nFunc, 'ClusterPickOrder1DropID', @cStorerKey) 
   SET @cClusterPickBatch1DropID = rdt.RDTGetConfig( @nFunc, 'ClusterPickBatch1DropID', @cStorerKey)

   -- (james02)
   SELECT @cLoadKey = LoadKey FROM dbo.OrderDetail WITH (NOLOCK)
   WHERE StorerKey = @cStorerKey
      AND OrderKey = @cOrderKey

   SELECT @cLoadDefaultPickMethod = LoadPickMethod FROM dbo.LoadPlan WITH (NOLOCK)
   WHERE LoadKey = @cLoadKey

   -- (james03)
   IF ISNULL(@cPickSlipNo, '') = ''
   BEGIN
      SELECT @cPickSlipNo = PickHeaderKey FROM dbo.PickHeader WITH (NOLOCK) 
      WHERE OrderKey = @cOrderKey
   END

   -- If still blank picklipno then look for conso pick   
   IF ISNULL(@cPickSlipNo, '') = ''
   BEGIN
      SELECT TOP 1 @cPickSlipNo = PickHeaderKey 
      FROM dbo.PickHeader PIH WITH (NOLOCK)
      JOIN dbo.LoadPlanDetail LPD WITH (NOLOCK) ON (PIH.ExternOrderKey = LPD.LoadKey)
      JOIN dbo.Orders O WITH (NOLOCK) ON (LPD.OrderKey = O.OrderKey)
      WHERE O.OrderKey = @cOrderKey
         AND O.StorerKey = @cStorerKey
   END

   SET @nTranCount = @@TRANCOUNT

   BEGIN TRAN
   SAVE TRAN Cluster_Pick_ConfirmTask

   -- (Vicky06) - Start
   SELECT @cUOM = RTRIM(PACK.PACKUOM3)
   FROM dbo.PACK PACK WITH (NOLOCK)
   JOIN dbo.SKU SKU WITH (NOLOCK) ON (SKU.Packkey = PACK.Packkey)
   WHERE SKU.Storerkey = @cStorerKey
   AND   SKU.SKU = @cSKU
   -- (Vicky06) - End

   -- Get RDT.RDTPickLock candidate to offset
   DECLARE curRPL CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT RowRef, DropID, PickQty, ID, ISNULL( PackKey, '')
   FROM RDT.RDTPickLock WITH (NOLOCK)
   WHERE StorerKey = @cStorerKey
      AND OrderKey = @cOrderKey
      AND SKU = @cSKU
      AND LOT = @cLOT
      AND LOC = @cLOC
      AND Status = '1'
      --AND PickQty > 0
      AND AddWho = @cUserName
      AND (( ISNULL( @cPutAwayZone, '') = 'ALL') OR ( PutAwayZone = @cPutAwayZone))
      AND (( ISNULL( @cPickZone, '') = '') OR ( PickZone = @cPickZone))
   Order By RowRef
   OPEN curRPL
   FETCH NEXT FROM curRPL INTO @nRowRef, @cDropID, @nPickQty, @nCartonNo, @cCartonType
   WHILE @@FETCH_STATUS <> -1
   BEGIN
      SET @d_step1 = GETDATE() -- (Vicky02)
      -- Get PickDetail candidate to offset based on RPL's candidate
      DECLARE curPD CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT PickDetailKey, QTY
      FROM dbo.PickDetail WITH (NOLOCK)
      WHERE OrderKey  = @cOrderKey
         AND StorerKey  = @cStorerKey
         AND SKU = @cSKU
         AND LOT = @cLOT
         AND LOC = @cLOC
         AND Status = '0'
      ORDER BY PickDetailKey
      OPEN curPD
      SET @d_step1 = GETDATE() - @d_step1 -- (Vicky02)
      FETCH NEXT FROM curPD INTO @cPickDetailKey, @nQTY_PD
      WHILE @@FETCH_STATUS <> -1
      BEGIN

         SET @nPickPackQty = @nQTY_PD -- (ChewKP02)        

         IF @cClusterPickOrder1DropID = '1'
         BEGIN
            SELECT DISTINCT @cCheckDropID = DropID
            FROM dbo.PICKDETAIL WITH (NOLOCK)
            WHERE OrderKey = @cOrderKey
            AND   ISNULL( DropID, '') <> ''
            SET @nRowCount = @@ROWCOUNT

            -- Check 1 order 1 dropid            
            IF @nRowCount > 1
            BEGIN
               SET @nErrNo = 66043
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'MultiDropID'
               GOTO RollBackTran
            END
            
            IF @nRowCount = 1
            BEGIN
               IF @cCheckDropID <> @cDropID
               BEGIN
                  IF @nPickQty > 0  -- No need check for short, dropid = <blank>
                  BEGIN
                     SET @nErrNo = 66044
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'DiffDropID'
                     GOTO RollBackTran
                  END
               END
            END
         END
         
         IF @cClusterPickBatch1DropID = '1'
         BEGIN
            SELECT @cBatchKey = BatchKey
            FROM RDT.RDTPickLock WITH (NOLOCK)
            WHERE StorerKey = @cStorerKey
               AND OrderKey = @cOrderKey
               AND SKU = @cSKU
               AND LOT = @cLOT
               AND LOC = @cLOC
               AND Status = '1'
               AND AddWho = @cUserName
               AND (( ISNULL( @cPutAwayZone, '') = 'ALL') OR ( PutAwayZone = @cPutAwayZone))
               AND (( ISNULL( @cPickZone, '') = '') OR ( PickZone = @cPickZone))
            ORDER BY 1 DESC
            
            IF ISNULL( @cBatchKey, '') = ''
            BEGIN
               -- Get new PickDetailkey
               EXECUTE dbo.nspg_GetKey
                  'BatchKey',
                  10 ,
                  @cBatchKey        OUTPUT,
                  @b_Success        OUTPUT,
                  @nErrNo           OUTPUT,
                  @cErrMsg          OUTPUT
               IF @b_Success <> 1
               BEGIN
                  SET @nErrNo = 66045
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- nspg_GetKey
                  GOTO RollBackTran
               END
               
               DECLARE @curBatchKey CURSOR
               SET @curBatchKey = CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
               SELECT RowRef
               FROM RDT.RDTPickLock WITH (NOLOCK)
               WHERE StorerKey = @cStorerKey
                  AND OrderKey = @cOrderKey
                  AND SKU = @cSKU
                  AND LOT = @cLOT
                  AND LOC = @cLOC
                  AND Status = '1'
                  AND AddWho = @cUserName
                  AND (( ISNULL( @cPutAwayZone, '') = 'ALL') OR ( PutAwayZone = @cPutAwayZone))
                  AND (( ISNULL( @cPickZone, '') = '') OR ( PickZone = @cPickZone))
               ORDER BY 1 
               OPEN @curBatchKey
               FETCH NEXT FROM @curBatchKey INTO @nBatchRowRef
               WHILE @@FETCH_STATUS = 0
               BEGIN
                  UPDATE RDT.RDTPickLock SET 
                     BatchKey = @cBatchKey 
                  WHERE RowRef = @nBatchRowRef
                  
                  IF @@ERROR <> 0
                  BEGIN
                     SET @nErrNo = 66046
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- nspg_GetKey
                     GOTO RollBackTran
                  END
               
                  FETCH NEXT FROM @curBatchKey INTO @nBatchRowRef
               END
            END

            SELECT DISTINCT @cCheckDropID = DropID
            FROM RDT.RDTPickLock WITH (NOLOCK)
            WHERE StorerKey = @cStorerKey
               AND OrderKey = @cOrderKey
               AND SKU = @cSKU
               AND LOT = @cLOT
               AND LOC = @cLOC
               AND Status = '1'
               AND AddWho = @cUserName
               AND (( ISNULL( @cPutAwayZone, '') = 'ALL') OR ( PutAwayZone = @cPutAwayZone))
               AND (( ISNULL( @cPickZone, '') = '') OR ( PickZone = @cPickZone))
               AND ISNULL( DropID, '') <> ''
               AND BatchKey = @cBatchKey

            -- Check 1 order 1 dropid            
            IF @nRowCount > 1
            BEGIN
               SET @nErrNo = 66047
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'MultiDropID'
               GOTO RollBackTran
            END
            
            IF @nRowCount = 1
            BEGIN
               IF @cCheckDropID <> @cDropID
               BEGIN
                  SET @nErrNo = 66048
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'DiffDropID'
                  GOTO RollBackTran
               END
            END               
         END
         
         IF @nPickQty = 0
         BEGIN
            -- (james18)
            DECLARE @cCurShortPick  CURSOR
            SET @cCurShortPick = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
            SELECT PickDetailKey 
            FROM dbo.PickDetail WITH (NOLOCK)
            WHERE OrderKey  = @cOrderKey
               AND StorerKey  = @cStorerKey
               AND SKU = @cSKU
               AND LOT = @cLOT
               AND LOC = @cLOC
               AND Status = '0'
            ORDER BY PickDetailKey
            OPEN @cCurShortPick
            FETCH NEXT FROM @cCurShortPick INTO @cShortPickDetailKey
            WHILE @@FETCH_STATUS = 0
            BEGIN
	            SET @d_step2 = GETDATE() -- (Vicky02)

	            -- Confirm PickDetail
	            IF ISNULL(@cLoadDefaultPickMethod, '') = 'C' AND @cStatus = '4'
	            BEGIN
	               UPDATE dbo.PickDetail WITH (ROWLOCK) SET
	                  EditWho = SUSER_SNAME(),
	                  EditDate = GETDATE(),
	                  DropID = '',
	                  Status = @cStatus
	               WHERE PickDetailKey = @cShortPickDetailKey
	            END
	            ELSE
	            BEGIN
	               UPDATE dbo.PickDetail WITH (ROWLOCK) SET
	                  EditWho = SUSER_SNAME(),
	                  EditDate = GETDATE(),
	                  DropID = @cDropID,
	                  Status = @cStatus
	               WHERE PickDetailKey = @cShortPickDetailKey
	            END

	            IF @@ERROR <> 0
	            BEGIN
	               SET @nErrNo = 66026
	               SET @cErrMsg = rdt.rdtgetmessage( 66026, @cLangCode, 'DSP') --'OffSetPDtlFail'
	               GOTO RollBackTran
	            END
	            ELSE
	            BEGIN
	               -- (Vicky06) EventLog - QTY
	               EXEC RDT.rdt_STD_EventLog
	                 @cActionType   = '3', -- Picking
	                 @cUserID       = @cUserName,
	                 @nMobileNo     = @nMobile,
	                 @nFunctionID   = @nFunc,
	                 @cFacility     = @cFacility,
	                 @cStorerKey    = @cStorerkey,
	                 @cLocation     = @cLOC,
	                 @cID           = @cDropID,
	                 @cSKU          = @cSKU,
	                 @cUOM          = @cUOM,
	                 --@nQTY          = @nPickQty,  (james12)
	                 @nQTY          = 0,                 
	                 @cLot          = @cLOT,
	                 @cRefNo1       = @cPutAwayZone,
	                 @cRefNo2       = @cPickZone,
	                 @cRefNo3       = @cOrderKey,
	                 @cRefNo4       = @cPickSlipNo
	            END

	            SET @d_step2 = GETDATE() - @d_step2        -- (Vicky02)
	            SET @c_col5 = RTRIM(@c_col5) + ' - Stp2.1' -- (Vicky02)

	            -- Trace Info (Vicky02) - Start
	            SET @d_endtime = GETDATE()
	            INSERT INTO TraceInfo VALUES
	                  (RTRIM(@c_TraceName), @d_starttime, @d_endtime
	                  ,CONVERT(NVARCHAR(12),@d_endtime - @d_starttime ,114)
	                  ,CONVERT(NVARCHAR(12),@d_step1,114)
	                  ,CONVERT(NVARCHAR(12),@d_step2,114)
	                  ,CONVERT(NVARCHAR(12),@d_step3,114)
	                  ,CONVERT(NVARCHAR(12),@d_step4,114)
	                  ,CONVERT(NVARCHAR(12),@d_step5,114)
	                      ,@c_Col1,@c_Col2,@c_Col3,@c_Col4,@c_Col5)

	            SET @d_step1 = NULL
	            SET @d_step2 = NULL
	            SET @d_step3 = NULL
	            SET @d_step4 = NULL
	            SET @d_step5 = NULL
	             -- Trace Info (Vicky02) - End

	            --BREAK -- Exit -- SOS# 176144
               FETCH NEXT FROM @cCurShortPick INTO @cShortPickDetailKey
            END
         END
         ELSE -- SOS# 176144
         -- Exact match
         IF @nQTY_PD = @nPickQty
         BEGIN
            SET @d_step2 = GETDATE() -- (Vicky02)

            -- Confirm PickDetail
            IF ISNULL(@cLoadDefaultPickMethod, '') = 'C' AND @cStatus = '4'
            BEGIN
               UPDATE dbo.PickDetail WITH (ROWLOCK) SET
                  EditWho = SUSER_SNAME(),
                  EditDate = GETDATE(),
                  DropID = '',
                  Status = @cStatus
               WHERE PickDetailKey = @cPickDetailKey
            END
            ELSE
            BEGIN
               UPDATE dbo.PickDetail WITH (ROWLOCK) SET
                  EditWho = SUSER_SNAME(),
                  EditDate = GETDATE(),
                  DropID = @cDropID,
                  Status = @cStatus  
               WHERE PickDetailKey = @cPickDetailKey
            END

            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 66027
               SET @cErrMsg = rdt.rdtgetmessage( 66027, @cLangCode, 'DSP') --'OffSetPDtlFail'
               GOTO RollBackTran
            END
            ELSE
            BEGIN
               -- (Vicky06) EventLog - QTY
               EXEC RDT.rdt_STD_EventLog
                 @cActionType   = '3', -- Picking
                 @cUserID       = @cUserName,
                 @nMobileNo     = @nMobile,
                 @nFunctionID   = @nFunc,
                 @cFacility     = @cFacility,
                 @cStorerKey    = @cStorerkey,
                 @cLocation     = @cLOC,
                 @cID           = @cDropID,
                 @cSKU          = @cSKU,
                 @cUOM          = @cUOM,
                 @nQTY          = @nPickQty,
                 @cLot          = @cLOT,
                 @cRefNo1       = @cPutAwayZone,
                 @cRefNo2       = @cPickZone,
                 @cRefNo3       = @cOrderKey,
                 @cRefNo4       = @cPickSlipNo
            END
            SET @nPickQty = @nPickQty - @nQTY_PD -- Reduce balance -- SOS# 176144
            SET @d_step2 = GETDATE() - @d_step2        -- (Vicky02)
            SET @c_col5 = RTRIM(@c_col5) + ' - Stp2.2' -- (Vicky02)
            

         END
       -- PickDetail have less
         ELSE IF @nQTY_PD < @nPickQty
         BEGIN
            SET @d_step2 = GETDATE() -- (Vicky02)

            -- Confirm PickDetail
            IF ISNULL(@cLoadDefaultPickMethod, '') = 'C' AND @cStatus = '4'
            BEGIN
               UPDATE dbo.PickDetail WITH (ROWLOCK) SET
                  EditWho = SUSER_SNAME(),
                  EditDate = GETDATE(),
                  DropID = '',
                  Status = @cStatus
               WHERE PickDetailKey = @cPickDetailKey
            END
            ELSE
            BEGIN
               UPDATE dbo.PickDetail WITH (ROWLOCK) SET
                  EditWho = SUSER_SNAME(),
                  EditDate = GETDATE(),
                  DropID = @cDropID,
                  Status = '5'
               WHERE PickDetailKey = @cPickDetailKey
            END

            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 66028
               SET @cErrMsg = rdt.rdtgetmessage( 66028, @cLangCode, 'DSP') --'OffSetPDtlFail'
               GOTO RollBackTran
            END
            ELSE
            BEGIN
           -- (Vicky06) EventLog - QTY
               EXEC RDT.rdt_STD_EventLog
                 @cActionType   = '3', -- Picking
                 @cUserID       = @cUserName,
                 @nMobileNo     = @nMobile,
                 @nFunctionID   = @nFunc,
                 @cFacility     = @cFacility,
                 @cStorerKey    = @cStorerkey,
                 @cLocation     = @cLOC,
                 @cID           = @cDropID,
                 @cSKU          = @cSKU,
                 @cUOM          = @cUOM,
                 --@nQTY          = @nPickQty,  (james12)
                 @nQTY          = @nQTY_PD,                 
                 @cLot          = @cLOT,
                 @cRefNo1       = @cPutAwayZone,
                 @cRefNo2       = @cPickZone,
                 @cRefNo3       = @cOrderKey,
                 @cRefNo4       = @cPickSlipNo
            END

            SET @nPickQty = @nPickQty - @nQTY_PD -- Reduce balance
            SET @d_step2 = GETDATE() - @d_step2        -- (Vicky02)
            SET @c_col5 = RTRIM(@c_col5) + ' - Stp2.3' -- (Vicky02)

         
         END
         -- PickDetail have more, need to split
         ELSE IF @nQTY_PD > @nPickQty
         BEGIN
            IF @nPickQty > 0 -- SOS# 176144
            BEGIN
               SET @d_step2 = GETDATE() -- (Vicky02)
               -- If Status = '5' (full pick), split line if neccessary
               -- If Status = '4' (short pick), no need to split line if already last RPL line to update,
               -- just have to update the pickdetail.qty = short pick qty
                  -- Get new PickDetailkey
               DECLARE @cNewPickDetailKey NVARCHAR( 10)
               EXECUTE dbo.nspg_GetKey
                  'PICKDETAILKEY',
                  10 ,
                  @cNewPickDetailKey OUTPUT,
                  @b_success         OUTPUT,
                  @n_err             OUTPUT,
                  @c_errmsg          OUTPUT

               IF @b_success <> 1
               BEGIN
                  SET @nErrNo = 66029
                  SET @cErrMsg = rdt.rdtgetmessage( 66029, @cLangCode, 'DSP') -- 'GetDetKeyFail'
                  GOTO RollBackTran
               END

               IF ISNULL(@cLoadDefaultPickMethod, '') = 'C'
               BEGIN
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
                     '4', DropID, LOC, ID, PackKey, UpdateSource, CartonGroup, CartonType, ToLoc, DoReplenish, ReplenishZone,
                     DoCartonize, PickMethod, WaveKey, EffectiveDate, ArchiveCop, ShipFlag, PickSlipNo, @cNewPickDetailKey,
                     @nQTY_PD - @nPickQty, -- QTY
                     NULL, --TrafficCop,
                     '1'  --OptimizeCop
                  FROM dbo.PickDetail WITH (NOLOCK)
                  WHERE PickDetailKey = @cPickDetailKey
               END
               ELSE
               BEGIN
                  -- Create a new PickDetail to hold the balance
                  INSERT INTO dbo.PICKDETAIL (
                     CaseID, PickHeaderKey, OrderKey, OrderLineNumber, LOT, StorerKey, SKU, AltSKU, UOM, UOMQTY, QTYMoved,
                     Status, DropID, LOC, ID, PackKey, UpdateSource, CartonGroup, CartonType, ToLoc, DoReplenish, ReplenishZone,
                     DoCartonize, PickMethod, WaveKey, EffectiveDate, ArchiveCop, ShipFlag, PickSlipNo, PickDetailKey,
                     QTY,
                     TrafficCop,
                     OptimizeCop,
					 		channel_id --ian01
					 		)  
                  SELECT  
                     CaseID, PickHeaderKey, OrderKey, OrderLineNumber, Lot, StorerKey, SKU, AltSku, UOM, UOMQTY, QTYMoved,  
                     '0', DropID, LOC, ID, PackKey, UpdateSource, CartonGroup, CartonType, ToLoc, DoReplenish, ReplenishZone,  
                     DoCartonize, PickMethod, WaveKey, EffectiveDate, ArchiveCop, ShipFlag, PickSlipNo, @cNewPickDetailKey,  
                     @nQTY_PD - @nPickQty, -- QTY  
                     NULL, --TrafficCop,  
                     '1',  --OptimizeCop
							channel_id --ian01	
                  FROM dbo.PickDetail WITH (NOLOCK)
                  WHERE PickDetailKey = @cPickDetailKey
               END

               IF @@ERROR <> 0
               BEGIN
                  SET @nErrNo = 66030
                  SET @cErrMsg = rdt.rdtgetmessage( 66030, @cLangCode, 'DSP') --'Ins PDtl Fail'
                  GOTO RollBackTran
               END

               -- Split RefKeyLookup (james14)
               IF EXISTS( SELECT 1 FROM RefKeyLookup WITH (NOLOCK) WHERE PickDetailKey = @cPickDetailKey)
               BEGIN
                  -- Insert into
                  INSERT INTO dbo.RefKeyLookup (PickDetailkey, PickSlipNo, OrderKey, OrderLineNumber, Loadkey)
                  SELECT @cNewPickDetailKey, PickSlipNo, OrderKey, OrderLineNumber, Loadkey
                  FROM RefKeyLookup WITH (NOLOCK) 
                  WHERE PickDetailKey = @cPickDetailKey
                  IF @@ERROR <> 0
                  BEGIN
                     SET @nErrNo = 66041
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- INS RefKeyFail
                     GOTO RollBackTran
                  END
               END

               SET @d_step2 = GETDATE() - @d_step2        -- (Vicky02)
               SET @c_col5 = RTRIM(@c_col5) + ' - Stp2.4' -- (Vicky02)

               -- If short pick & no split line needed. Update pickdetail.qty with no trafficcop
               SET @d_step2 = GETDATE() -- (Vicky02)
               -- Change orginal PickDetail with exact QTY (with TrafficCop)
               UPDATE dbo.PickDetail WITH (ROWLOCK) SET
                  EditWho = SUSER_SNAME(),
                  EditDate = GETDATE(),
                  QTY = @nPickQty,
                  Trafficcop = NULL
               WHERE PickDetailKey = @cPickDetailKey

               IF @@ERROR <> 0
               BEGIN
                  SET @nErrNo = 66031
                  SET @cErrMsg = rdt.rdtgetmessage( 66031, @cLangCode, 'DSP') --'OffSetPDtlFail'
                  GOTO RollBackTran
               END

               UPDATE dbo.PickDetail WITH (ROWLOCK) SET
   --               DropID = @cDropID,            -- Confirm orginal PickDetail with exact QTY

   --             Status = @cStatus
                  EditWho = SUSER_SNAME(),
                  EditDate = GETDATE(),
                  DropID = @cDropID,
                  Status = '5'
               WHERE PickDetailKey = @cPickDetailKey

               IF @@ERROR <> 0
               BEGIN
                  SET @nErrNo = 66032
                  SET @cErrMsg = rdt.rdtgetmessage( 66032, @cLangCode, 'DSP') --'OffSetPDtlFail'
                  GOTO RollBackTran
               END
               ELSE
               BEGIN
               -- (Vicky06) EventLog - QTY
                  EXEC RDT.rdt_STD_EventLog
                    @cActionType   = '3', -- Picking
                    @cUserID       = @cUserName,
                    @nMobileNo     = @nMobile,
                    @nFunctionID   = @nFunc,
                    @cFacility     = @cFacility,
                    @cStorerKey    = @cStorerkey,
                    @cLocation     = @cLOC,
                    @cID           = @cDropID,
                    @cSKU          = @cSKU,
                    @cUOM          = @cUOM,
                    @nQTY          = @nPickQty,
                    @cLot          = @cLOT,
                    @cRefNo1       = @cPutAwayZone,
                    @cRefNo2       = @cPickZone,
                    @cRefNo3       = @cOrderKey,
                    @cRefNo4       = @cPickSlipNo
               END

               SET @d_step2 = GETDATE() - @d_step2        -- (Vicky02)
               SET @c_col5 = RTRIM(@c_col5) + ' - Stp2.6' -- (Vicky02)
               SET @nPickPackQty = @nPickQty -- (ChewKP02) 
               SET @nPickQty = 0 -- Reduce balance  -- (jamesxxx)
               --SET @nPickQty = @nQTY_PD - @nPickQty

         --END -- SOS# 176144

         -- Trace Info (Vicky02) - Start
               SET @d_endtime = GETDATE()
               INSERT INTO TraceInfo VALUES
                       (RTRIM(@c_TraceName), @d_starttime, @d_endtime
                       ,CONVERT(NVARCHAR(12),@d_endtime - @d_starttime ,114)
                       ,CONVERT(NVARCHAR(12),@d_step1,114)
                       ,CONVERT(NVARCHAR(12),@d_step2,114)
                       ,CONVERT(NVARCHAR(12),@d_step3,114)
                       ,CONVERT(NVARCHAR(12),@d_step4,114)
                       ,CONVERT(NVARCHAR(12),@d_step5,114)
                           ,@c_Col1,@c_Col2,@c_Col3,@c_Col4,@c_Col5)

               SET @d_step1 = NULL
               SET @d_step2 = NULL
               SET @d_step3 = NULL
               SET @d_step4 = NULL
               SET @d_step5 = NULL
         -- Trace Info (Vicky02) - End

--         IF @nPickQty = 0 BREAK -- Exit (james04)

            END
         END

         -- Get total qty that need to be packed
         SELECT @nPackQty =  ISNULL(SUM(PickQty), 0)
         FROM RDT.RDTPickLock WITH (NOLOCK)
         WHERE StorerKey = @cStorerKey
            AND OrderKey = @cOrderKey
            AND SKU = @cSKU
            AND LOT = @cLOT
            AND LOC = @cLOC
            AND Status = '1'
            AND AddWho = @cUserName
            AND DropID = @cDropID -- (ChewKP01)
            AND (( ISNULL( @cPutAwayZone, '') = 'ALL') OR ( PutAwayZone = @cPutAwayZone))
            AND (( ISNULL( @cPickZone, '') = '') OR ( PickZone = @cPickZone))
      
         IF rdt.RDTGetConfig( @nFunc, 'ClusterPickInsPackDt', @cStorerKey) = '1' AND @nPackQty > 0
         BEGIN
            SET @nPackQty = @nPickPackQty 

            IF @cLoadDefaultPickMethod = 'C' -- (james09)
            BEGIN
               -- Prevent overpacked (james05)
               SET @nTotalPickedQty = 0 
               SELECT @nTotalPickedQty = ISNULL(SUM(PD.QTY), 0) 
               FROM dbo.PickDetail PD WITH (NOLOCK)
               JOIN dbo.OrderDetail OD WITH (NOLOCK) ON (PD.OrderKey = OD.OrderKey AND PD.OrderLineNumber = OD.OrderLineNumber)
               JOIN dbo.Orders O WITH (NOLOCK) ON OD.OrderKey = O.OrderKey
               WHERE PD.StorerKey = @cStorerKey
                  AND O.LoadKey = @cLoadKey
                  AND PD.SKU = @cSKU
                  AND PD.Status = '5' 

               SET @nTotalPackedQty = 0 
               SELECT @nTotalPackedQty = ISNULL(SUM(QTY), 0) FROM dbo.PackDetail WITH (NOLOCK)
               WHERE StorerKey = @cStorerKey
                  AND PickSlipNo = @cPickSlipNo
                  AND SKU = @cSKU
            END
            ELSE
            BEGIN
               -- Prevent overpacked (james05)
               SET @nTotalPickedQty = 0 
               SELECT @nTotalPickedQty = ISNULL(SUM(QTY), 0) FROM dbo.PickDetail WITH (NOLOCK)
               WHERE StorerKey = @cStorerKey
                  AND OrderKey = @cOrderKey
                  AND SKU = @cSKU
                  AND Status = '5' 

               SET @nTotalPackedQty = 0 
               SELECT @nTotalPackedQty = ISNULL(SUM(QTY), 0) FROM dbo.PackDetail WITH (NOLOCK)
               WHERE StorerKey = @cStorerKey
                  AND PickSlipNo = @cPickSlipNo
                  AND SKU = @cSKU
            END
            
            IF (@nTotalPackedQty + @nPackQty) > @nTotalPickedQty -- (ChewKP02)
            BEGIN
               
               SET @nErrNo = 66039
               SET @cErrMsg = rdt.rdtgetmessage( 66039, @cLangCode, 'DSP') --'SKU Overpacked'
               GOTO RollBackTran
            END
            
            -- SOS133222 insert packdetail (start)
            -- If this carton no not exists in PackDetail then insert new line
            IF rdt.RDTGetConfig( @nFunc, 'ClusterPickPrtURNLbl', @cStorerKey) = '1' 
            BEGIN
               EXEC RDT.rdt_Case_Pick_InsertPack
                  @cStorerKey,
                  @cPickDetailKey,
                  @cSKU,
                  @cPickSlipNo,
                  @nPackQty,
                  @nCartonNo,
                  @cLangCode,
                  @nErrNo          OUTPUT,
                  @cErrMsg         OUTPUT  -- screen limitation, 20 NVARCHAR max

               IF @nErrNo <> 0 
               BEGIN
                  GOTO RollBackTran
               END   
            END
            ELSE  -- Normal Packing
            BEGIN
               -- Same DropID + PickSlipNo will group SKU into a carton. 1 carton could be multi sku
               IF NOT EXISTS (SELECT 1 FROM dbo.PackDetail WITH (NOLOCK) 
                  WHERE StorerKey = @cStorerKey
                     AND PickSlipNo = @cPickSlipNo
                     AND DropID = @cDropID)
               BEGIN
                  IF NOT EXISTS (SELECT 1 FROM dbo.PackHeader WITH (NOLOCK) WHERE Pickslipno = @cPickSlipNo)
                  BEGIN
                     -- (james07)
                     SELECT @cRoute = [Route], 
                            @cOrderRefNo = SUBSTRING(ExternOrderKey, 1, 18), 
                            @cConsigneekey = ConsigneeKey 
                     FROM dbo.Orders WITH (NOLOCK) 
                     WHERE OrderKey = @cOrderKey
                     AND   StorerKey = @cStorerKey
   
                     INSERT INTO dbo.PackHeader
                     (Route, OrderKey, OrderRefNo, Loadkey, Consigneekey, StorerKey, PickSlipNo)
                     VALUES
                     (@cRoute, @cOrderKey, @cOrderRefNo, @cLoadKey, @cConsigneekey, @cStorerKey, @cPickSlipNo)

                     IF @@ERROR <> 0
                     BEGIN
                        SET @nErrNo = 66040
                        SET @cErrMsg = rdt.rdtgetmessage( 66040, @cLangCode, 'DSP') --'InsPHdrFail'
                        GOTO RollBackTran
                     END 
                  END

                  SET @nCartonNo = 0

                  SET @cLabelNo = ''

                  IF @cClusterPickGenLabelNo_SP NOT IN ('', '0') AND 
                     EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cClusterPickGenLabelNo_SP AND type = 'P')
                  BEGIN
                     SET @nErrNo = 0
                     SET @cSQLStatement = 'EXEC rdt.' + RTRIM( @cClusterPickGenLabelNo_SP) +     
                        ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerkey, ' + 
                        ' @cWaveKey, @cLoadKey, @cOrderKey, @cPutAwayZone, @cPickZone, @cPickSlipNo, @cSKU, ' + 
                        ' @nQty, @cDropID, @cLabelNo OUTPUT, @nCartonNo OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT '    

                        SET @cSQLParms =    
                           '@nMobile                   INT,           ' +
                           '@nFunc                     INT,           ' +
                           '@cLangCode                 NVARCHAR( 3),  ' +
                           '@nStep                     INT,           ' +
                           '@nInputKey                 INT,           ' +
                           '@cFacility                 NVARCHAR( 5),  ' +
                           '@cStorerkey                NVARCHAR( 15), ' +
                           '@cWaveKey                  NVARCHAR( 10), ' +
                           '@cLoadKey                  NVARCHAR( 10), ' +
                           '@cOrderKey                 NVARCHAR( 10), ' +
                           '@cPutAwayZone              NVARCHAR( 10), ' +
                           '@cPickZone                 NVARCHAR( 10), ' +
                           '@cPickSlipNo               NVARCHAR( 10), ' +
                           '@cSKU                      NVARCHAR( 20), ' +
                           '@nQty                      INT, ' +
                           '@cDropID                   NVARCHAR( 20), ' +
                           '@cLabelNo                  NVARCHAR( 20) OUTPUT, ' +
                           '@nCartonNo                 INT           OUTPUT, ' +
                           '@nErrNo                    INT           OUTPUT, ' +
                           '@cErrMsg                   NVARCHAR( 20) OUTPUT  ' 
               
                        EXEC sp_ExecuteSQL @cSQLStatement, @cSQLParms,     
                           @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerkey, 
                           @cWaveKey, @cLoadKey, @cOrderKey, @cPutAwayZone, @cPickZone, @cPickSlipNo, @cSKU, 
                           @nPackQty, @cDropID, @cLabelNo OUTPUT, @nCartonNo OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT 
                  END
                  ELSE
                  BEGIN
                     EXECUTE dbo.nsp_GenLabelNo
                        '',
                        @cStorerKey,
                        @c_labelno     = @cLabelNo  OUTPUT,
                        @n_cartonno    = @nCartonNo OUTPUT,
                        @c_button      = '',
                        @b_success     = @b_success OUTPUT,
                        @n_err         = @n_err     OUTPUT,
                        @c_errmsg      = @c_errmsg  OUTPUT
                  END

                  IF @b_success <> 1
                  BEGIN
                     SET @nErrNo = 66038
                     SET @cErrMsg = rdt.rdtgetmessage( 66038, @cLangCode, 'DSP') --'GenLabelFail'
                     GOTO RollBackTran
                  END

                  INSERT INTO dbo.PackDetail
                     (PickSlipNo, CartonNo, LabelNo, LabelLine, StorerKey, SKU, QTY, Refno, AddWho, AddDate, EditWho, EditDate, DropID)
                  VALUES
                     (@cPickSlipNo, 0, @cLabelNo, '00000', @cStorerKey, @cSku, @nPackQty,
                     @cPickDetailKey, 'rdt.' + sUser_sName(), GETDATE(), 'rdt.' + sUser_sName(), GETDATE(), @cDropID)

                  IF @@ERROR <> 0
                  BEGIN
                     SET @nErrNo = 66035
                     SET @cErrMsg = rdt.rdtgetmessage( 66035, @cLangCode, 'DSP') --'InsPackDtlFail'
                     GOTO RollBackTran
                  END 
               END -- DropID not exists
               ELSE
               BEGIN
                  IF NOT EXISTS (SELECT 1 FROM dbo.PackDetail WITH (NOLOCK) 
                     WHERE StorerKey = @cStorerKey
                        AND PickSlipNo = @cPickSlipNo
                        AND DropID = @cDropID
                        AND SKU = @cSKU)
                  BEGIN
                     SET @nCartonNo = 0

                     SET @cLabelNo = ''

                     SELECT @nCartonNo = CartonNo, @cLabelNo = LabelNo 
                     FROM dbo.PackDetail WITH (NOLOCK)
                     WHERE Pickslipno = @cPickSlipNo
                        AND StorerKey = @cStorerKey
                        AND DropID = @cDropID

                     SELECT @cLabelLine = RIGHT( '00000' + CAST( CAST( IsNULL( MAX( LabelLine), 0) AS INT) + 1 AS NVARCHAR( 5)), 5)
                     FROM dbo.PackDetail WITH (NOLOCK)
                     WHERE Pickslipno = @cPickSlipNo
                        AND CartonNo = @nCartonNo
                        AND DropID = @cDropID

                     INSERT INTO dbo.PackDetail
                        (PickSlipNo, CartonNo, LabelNo, LabelLine, StorerKey, SKU, QTY, Refno, AddWho, AddDate, EditWho, EditDate, DropID)
                     VALUES
                        (@cPickSlipNo, @nCartonNo, @cLabelNo, @cLabelLine, @cStorerKey, @cSku, @nPackQty,
                        @cPickDetailKey, 'rdt.' + sUser_sName(), GETDATE(), 'rdt.' + sUser_sName(), GETDATE(), @cDropID)

                     IF @@ERROR <> 0
                     BEGIN
                        SET @nErrNo = 66036
                        SET @cErrMsg = rdt.rdtgetmessage( 66036, @cLangCode, 'DSP') --'InsPackDtlFail'
                        GOTO RollBackTran
                     END 
                  END   -- DropID exists but SKU not exists (insert new line with same cartonno)
                  ELSE
                  BEGIN
                     UPDATE dbo.PackDetail WITH (ROWLOCK) SET
                        QTY = QTY + @nPackQty,
                        EditWho = SUSER_SNAME(),
                        EditDate = GETDATE()
                     WHERE StorerKey = @cStorerKey
                        AND PickSlipNo = @cPickSlipNo
                        AND DropID = @cDropID
                        AND SKU = @cSKU

                     IF @@ERROR <> 0
                     BEGIN
                        SET @nErrNo = 66037
                        SET @cErrMsg = rdt.rdtgetmessage( 66037, @cLangCode, 'DSP') --'UpdPackDtlFail'
                        GOTO RollBackTran
                     END

                     SELECT TOP 1 @cLabelNo = LabelNo 
                     FROM dbo.PackDetail WITH (NOLOCK)
                     WHERE Pickslipno = @cPickSlipNo
                     AND   StorerKey = @cStorerKey
                     AND   DropID = @cDropID
                     AND   SKU = @cSKU
                     ORDER BY 1
                  END   -- DropID exists and SKU exists (update qty only)
               END
               
               IF @cClusterPickInsPackInfo = '1'
               BEGIN
                  
                  SELECT TOP 1 @nCartonNo = CartonNo
                  FROM dbo.PackDetail WITH (NOLOCK)
                  WHERE PickSlipNo = @cPickSlipNo
                  AND   LabelNo = @cLabelNo
                  ORDER BY 1
                  
                  SELECT @fCube = [Cube], 
                         @fCtnWeight = CartonWeight 
                  FROM dbo.Cartonization CZ WITH (NOLOCK)
                  JOIN Storer ST WITH (NOLOCK) ON CZ.CartonizationGroup = ST.CartonGroup
                  WHERE StorerKey = @cStorerKey
                  AND   CartonType = @cCartonType 

                  SELECT @fWeight = STDGrossWGT 
                  FROM dbo.SKU WITH (NOLOCK)
                  WHERE StorerKey = @cStorerKey
                  AND   SKU = @cSKU

                  SET @cCube = rdt.rdtFormatFloat( @fCube)

                  SET @cWeight = @nPackQty * @fWeight

                  IF EXISTS ( SELECT 1 FROM dbo.PackInfo WITH (NOLOCK) 
                              WHERE PickSlipNo = @cPickSlipNo
                              AND   CartonNo = @nCartonNo)                  
                  BEGIN
                     UPDATE dbo.PackInfo WITH (ROWLOCK) SET
                        CartonType = CASE WHEN ISNULL( CartonType, '') = '' THEN @cCartonType ELSE CartonType END,
                        [Cube] = CASE WHEN [Cube] IS NULL THEN @cCube ELSE [Cube] END,
                        Weight = Weight + rdt.rdtFormatFloat( @cWeight),            
                        --Qty = Qty + @nPackQty, no need qty here, trigger will topup qty automatically
                        EditDate = GETDATE(),
                        EditWho = 'rdt.' + sUser_sName()
                     WHERE PickSlipNo = @cPickSliPno
                     AND CartonNo = @nCartonNo
                     
                     IF @@ERROR <> 0
                     BEGIN
                        SET @nErrNo = 66043
                        SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdPackInfoFail'
                        GOTO RollBackTran
                     END                  
                  END
                  ELSE
                  BEGIN
                     SET @cWeight = @cWeight + @fCtnWeight  
                     SET @cWeight = rdt.rdtFormatFloat( @cWeight)  
                     
                     INSERT INTO dbo.PACKINFO
                     (PickSlipNo, CartonNo, CartonType, [Cube], WEIGHT, Qty)
                     VALUES
                     (@cPickSlipNo, @nCartonNo, @cCartonType, @cCube, @cWeight, @nPackQty)

                     IF @@ERROR <> 0
                     BEGIN
                        SET @nErrNo = 66044
                        SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'InsPackInfoFail'
                        GOTO RollBackTran
                     END                  
                  END
               END
            END
         END -- SOS# 176144

         -- (james10)
         IF NOT EXISTS (SELECT 1 FROM dbo.DropID WITH (NOLOCK) 
                        WHERE DropID = @cDropID) OR 
            -- If dropid not exists then need create new dropid.  (james11)
            -- If exists dropid then check if allow reuse dropid. If allow then go on.
            rdt.RDTGetConfig( @nFunc, 'ClusterPickAllowReuseDropID', @cStorerKey) = '1'
         BEGIN
            -- Insert into DropID table   (james08)
            IF rdt.RDTGetConfig( @nFunc, 'ClusterPickPromtOpenDropID', @cStorerKey) = '1' 
            BEGIN
               SET @nErrNo = 0  
               EXECUTE rdt.rdt_Cluster_Pick_DropID  
                  @nMobile, 
                  @nFunc,    
                  @cStorerKey,  
                  @cUserName,  
                  @cFacility,  
                  @cLoadKey,
                  @cPickSlipNo,  
                  @cOrderKey, 
                  @cDropID       OUTPUT,  
                  @cSKU,  
                  'I',      -- I = Insert
                  @cLangCode,  
                  @nErrNo        OUTPUT,  
                  @cErrMsg       OUTPUT  -- screen limitation, 20 NVARCHAR max  
  
               IF @nErrNo <> 0  
                  GOTO RollBackTran
            END
         END

         IF @cClusterPickUpdLabelNoToCaseID = '1' AND ISNULL( @cLabelNo, '') <> '' -- (james17)
         BEGIN
            UPDATE dbo.PickDetail WITH (ROWLOCK) SET 
               CaseID = @cLabelNo,
               EditWho = SUSER_SNAME(),
               EditDate = GETDATE()
            WHERE PickDetailKey = @cPickDetailKey

            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 66042
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdCaseID Fail'
               GOTO RollBackTran
            END
         END

         IF @nPickQty = 0 
         BEGIN
            BREAK -- Exit   (james04)
         END

         FETCH NEXT FROM curPD INTO @cPickDetailKey, @nQTY_PD
      END
      CLOSE curPD
      DEALLOCATE curPD

      -- Stamp RPL's candidate to '5'
      UPDATE RDT.RDTPickLock WITH (ROWLOCK) SET      
         Status = '5'   -- Picked
      WHERE RowRef = @nRowRef

      IF @@ERROR <> 0
      BEGIN
         SET @nErrNo = 66033
         SET @cErrMsg = rdt.rdtgetmessage( 66033, @cLangCode, 'DSP') --'UPDPKLockFail'
         GOTO RollBackTran
      END

      FETCH NEXT FROM curRPL INTO @nRowRef, @cDropID, @nPickQty, @nCartonNo, @cCartonType
   END
   CLOSE curRPL
   DEALLOCATE curRPL

   GOTO Quit

   RollBackTran:
      ROLLBACK TRAN Cluster_Pick_ConfirmTask

   Quit:
      WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
         COMMIT TRAN Cluster_Pick_ConfirmTask
        
END

GO