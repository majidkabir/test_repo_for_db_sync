SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
  
/************************************************************************/  
/* Store procedure: rdt_640ExtUpd02                                     */  
/* Copyright      : MAERSK                                              */
/*                                                                      */
/* Purpose: Display workorder related msg and update workorder.status   */  
/*                                                                      */  
/* Modifications log:                                                   */  
/*                                                                      */  
/* Date         Author    Ver.  Purposes                                */  
/* 2022-10-21   James     1.0   WMS-20989 Created                       */  
/* 2023-08-01   James     1.1   WMS-23232 Update PackDetail.EditDate    */
/*                              same as TaskDetail.EditDate (james01)   */
/************************************************************************/  
  
CREATE   PROCEDURE [RDT].[rdt_640ExtUpd02]  
   @nMobile        INT,
   @nFunc          INT,
   @cLangCode      NVARCHAR( 3),
   @nStep          INT,         
   @nInputKey      INT,         
   @cFacility      NVARCHAR( 5),
   @cStorerKey     NVARCHAR( 15),
   @cGroupKey      NVARCHAR( 10),
   @cTaskDetailKey NVARCHAR( 10),
   @cCartId        NVARCHAR( 10),
   @cFromLoc       NVARCHAR( 10),
   @cCartonId      NVARCHAR( 20),
   @cSKU           NVARCHAR( 20),
   @nQty           INT,         
   @cOption        NVARCHAR( 1),
   @tExtUpdate     VariableTable READONLY, 
   @nErrNo         INT           OUTPUT,
   @cErrMsg        NVARCHAR( 20) OUTPUT  
AS  
BEGIN  
   SET NOCOUNT ON  
   SET QUOTED_IDENTIFIER OFF  
   SET ANSI_NULLS OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  
   
   DECLARE @nTranCount        INT
   DECLARE @cUserName         NVARCHAR( 18)
   DECLARE @cChkTaskDetailKey NVARCHAR( 10)
   DECLARE @cChkSuggFromLOC   NVARCHAR( 10)
   DECLARE @cChkSuggCartonID  NVARCHAR( 20)
   DECLARE @cChkSuggSKU       NVARCHAR( 20)
   DECLARE @nChkSuggQty       INT
   DECLARE @tChkGetTask       VARIABLETABLE
   DECLARE @curWorkOrder      CURSOR
   DECLARE @curUpdWorkOrder   CURSOR
   DECLARE @cWorkOrderKey     NVARCHAR( 10)
   DECLARE @cWKORDUDEF1       NVARCHAR( 18)
   DECLARE @cWKORDUDEF2       NVARCHAR( 18)
   DECLARE @cWKORDUDEF3       NVARCHAR( 18)
   DECLARE @cPalletId         NVARCHAR( 18)
   DECLARE @cWaveKey          NVARCHAR( 10)
   DECLARE @cCartPickMethod   NVARCHAR( 20)
   DECLARE @cCaseId           NVARCHAR( 20)
   DECLARE @cErrMsg1          NVARCHAR( 20)
   DECLARE @cErrMsg2          NVARCHAR( 20)
   DECLARE @cErrMsg3          NVARCHAR( 20)
   DECLARE @cErrMsg4          NVARCHAR( 20)
   DECLARE @cErrMsg5          NVARCHAR( 20)
   DECLARE @cErrMsg6          NVARCHAR( 20)
   DECLARE @cErrMsg7          NVARCHAR( 20)
   DECLARE @cErrMsg8          NVARCHAR( 20)
   DECLARE @cErrMsg9          NVARCHAR( 20)
   DECLARE @n                 INT = 1
   DECLARE @cOrderKey         NVARCHAR( 10)
   DECLARE @cPickSlipNo       NVARCHAR( 10)
   DECLARE @cLabelNo          NVARCHAR( 20)
   DECLARE @cLabelLine        NVARCHAR( 5)
   DECLARE @nCartonNo         INT
   DECLARE @cUpdPackDtl       CURSOR
   DECLARE @cEditWho          NVARCHAR( 18)
   DECLARE @dEditDate         DATETIME
   DECLARE @curUpd            CURSOR
   DECLARE @cTaskKey          NVARCHAR( 10)
   
   SELECT 
      @cUserName = UserName, 
      @cCartPickMethod = V_String21
   FROM RDT.RDTMOBREC WITH (NOLOCK)
   WHERE Mobile = @nMobile
   
   -- Handling transaction            
   SET @nTranCount = @@TRANCOUNT            
   BEGIN TRAN  -- Begin our own transaction            
   SAVE TRAN rdt_640ExtUpd02 -- For rollback or commit only our own transaction            
            
   IF @nStep = 8
   BEGIN
      IF @nInputKey = 1
      BEGIN
      	--INSERT INTO TRACEINFO(TraceName, TimeIn, Col1, Col2, Col3) VALUES ('640', GETDATE(), @cStorerKey, @cGroupKey, SUSER_SNAME())
      	SET @curUpd = CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
      	SELECT TaskDetailKey
      	FROM dbo.TaskDetail WITH (NOLOCK)
      	WHERE StorerKey = @cStorerKey
      	AND   TaskType = 'CPK'
      	AND   Groupkey = @cGroupKey
      	AND   [Status] = '9'
      	OPEN @curUpd
      	FETCH NEXT FROM @curUpd INTO @cTaskKey
      	WHILE @@FETCH_STATUS = 0
      	BEGIN
      	   SELECT @cOrderKey = OrderKey
      	   FROM dbo.PICKDETAIL WITH (NOLOCK)
      	   WHERE TaskDetailKey = @cTaskKey
      	
      	   SELECT @cPickSlipNo = PickSlipNo
      	   FROM dbo.PackHeader WITH (NOLOCK)
      	   WHERE OrderKey = @cOrderKey
      	
      	   SELECT 
      	      @cLabelNo = Caseid,
      	      @cEditWho = EditWho, 
      	      @dEditDate = EditDate
      	   FROM dbo.TaskDetail WITH (NOLOCK)
      	   WHERE TaskDetailKey = @cTaskKey
      	
      	   SET @cUpdPackDtl = CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
      	   SELECT CartonNo, LabelLine
      	   FROM dbo.PackDetail WITH (NOLOCK)
      	   WHERE PickSlipNo = @cPickSlipNo
      	   AND   LabelNo = @cLabelNo
      	   ORDER BY 1, 2
      	   OPEN @cUpdPackDtl
      	   FETCH NEXT FROM @cUpdPackDtl INTO @nCartonNo, @cLabelLine
      	   WHILE @@FETCH_STATUS = 0
      	   BEGIN
      	      UPDATE dbo.PackDetail SET 
      	         EditWho = @cEditWho,
      	         EditDate = @dEditDate
      	      WHERE PickSlipNo = @cPickSlipNo
      	      AND   CartonNo = @nCartonNo
      	      AND   LabelNo = @cLabelNo
      	      AND   LabelLine = @cLabelLine
      	   
      	      IF @@ERROR <> 0
               BEGIN          
                  SET @nErrNo = 193253          
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Upd PackDtl Err          
                  GOTO RollBackTran          
               END
               
      	      FETCH NEXT FROM @cUpdPackDtl INTO @nCartonNo, @cLabelLine	
      	   END
      	   
      	   FETCH NEXT FROM @curUpd INTO @cTaskKey
      	END
      	
         SELECT @cWaveKey = WaveKey
         FROM dbo.TaskDetail WITH (NOLOCK)
         WHERE TaskDetailKey = @cTaskDetailKey

         -- If not exists status = 5, meaning already confirm toloc
         -- Nothing to do for below step
      	IF NOT EXISTS ( SELECT 1 FROM dbo.TaskDetail WITH (NOLOCK)
      	                WHERE Storerkey = @cStorerKey
      	                AND   WaveKey = @cWaveKey
                         AND   Groupkey = @cGroupKey
                         AND   DeviceID = @cCartId
                         AND   [Status] = '5')
            GOTO Commit_Tran
            
         SET @nErrNo = 0  
         SET @cChkSuggFromLOC = ''  

         EXEC [RDT].[rdt_TM_ClusterPick_GetTask]   
            @nMobile          = @nMobile,  
            @nFunc            = @nFunc,  
            @cLangCode        = @cLangCode,  
            @nStep            = @nStep,  
            @nInputKey        = @nInputKey,  
            @cFacility        = @cFacility,  
            @cStorerKey       = @cStorerKey,  
            @cGroupKey        = @cGroupKey,  
            @cCartId          = @cCartId,  
            @cType            = 'NEXTLOC',  
            @cTaskDetailKey   = @cChkTaskDetailKey OUTPUT,  
            @cFromLoc         = @cChkSuggFromLOC   OUTPUT,  
            @cCartonId        = @cChkSuggCartonID  OUTPUT,  
            @cSKU             = @cChkSuggSKU       OUTPUT,  
            @nQty             = @nChkSuggQty       OUTPUT,  
            @tGetTask         = @tChkGetTask,   
            @nErrNo           = @nErrNo         OUTPUT,  
            @cErrMsg          = @cErrMsg        OUTPUT  

         IF @nErrNo <> 0   -- No task anymore, display wordorder related msg
         BEGIN
            IF OBJECT_ID('tempdb..#CaseId') IS NOT NULL  
               DROP TABLE #CaseId
         
            CREATE TABLE #CaseId  (  
               RowRef        BIGINT IDENTITY(1,1)  Primary Key,  
               CaseId        NVARCHAR( 20))  

            IF OBJECT_ID('tempdb..#PalletId') IS NOT NULL  
               DROP TABLE #PalletId
         
            CREATE TABLE #PalletId  (  
               RowRef        BIGINT IDENTITY(1,1)  Primary Key,  
               PalletId      NVARCHAR( 20))  

            INSERT INTO #CaseId(CaseId)
            SELECT DISTINCT CaseId
            FROM dbo.TaskDetail WITH (NOLOCK)
            WHERE Storerkey = @cStorerKey
            AND   Groupkey = @cGroupKey
            AND   DeviceID = @cCartId
            AND   [Status] = '5'
            
         	SET @curWorkOrder = CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
         	SELECT W.WorkOrderKey, W.WKORDUDEF3, C.CaseId  
         	FROM dbo.WorkOrder W WITH (NOLOCK)
         	JOIN #CaseId C ON W.WkOrdUdef2 = C.CaseId
         	WHERE W.WkOrdUdef1 = @cWaveKey
         	AND   W.StorerKey = @cStorerKey
         	AND   W.Facility = @cFacility
         	AND   W.[Type] = 'TASK'
         	AND   [STATUS] < '9'
            OPEN @curWorkOrder
            FETCH NEXT FROM @curWorkOrder INTO @cWorkOrderKey, @cWKORDUDEF3, @cCaseId
            WHILE @@FETCH_STATUS = 0
            BEGIN
            	IF @n = 1
            	   SET @cErrMsg4 = CAST( @n AS NVARCHAR( 1)) + '-' + @cCaseId + '-' + @cWKORDUDEF3
            	IF @n = 2
            	   SET @cErrMsg5 = CAST( @n AS NVARCHAR( 1)) + '-' + @cCaseId + '-' + @cWKORDUDEF3
            	IF @n = 3
            	   SET @cErrMsg6 = CAST( @n AS NVARCHAR( 1)) + '-' + @cCaseId + '-' + @cWKORDUDEF3
            	IF @n = 4
            	   SET @cErrMsg7 = CAST( @n AS NVARCHAR( 1)) + '-' + @cCaseId + '-' + @cWKORDUDEF3
            	IF @n = 5
            	   SET @cErrMsg8 = CAST( @n AS NVARCHAR( 1)) + '-' + @cCaseId + '-' + @cWKORDUDEF3
            	IF @n = 6
            	   SET @cErrMsg9 = CAST( @n AS NVARCHAR( 1)) + '-' + @cCaseId + '-' + @cWKORDUDEF3

               UPDATE dbo.WorkOrder SET
                  [STATUS] = '9',   
                  EditWho = @cUserName,
                  EditDate = GETDATE()
               WHERE WorkOrderKey = @cWorkOrderKey

               IF @@ERROR <> 0               
               BEGIN          
                  SET @nErrNo = 193251          
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Upd WkOrder Err          
                  GOTO RollBackTran          
               END

               IF NOT EXISTS ( SELECT 1 FROM #PalletId WHERE PalletId = @cWKORDUDEF3)
                  INSERT INTO #PalletId (PalletId) VALUES (@cWKORDUDEF3)

            	SET @n = @n + 1
            	
            	FETCH NEXT FROM @curWorkOrder INTO @cWorkOrderKey, @cWKORDUDEF3, @cCaseId
            END
            CLOSE @curWorkOrder
            DEALLOCATE @curWorkOrder
            
            IF @n > 0
            BEGIN
               SET @nErrNo = 0  
               SET @cErrMsg1 = @cCartPickMethod -- Cart Pick Method
               SET @cErrMsg1 = @cCartId   -- Cart Id
               SET @cErrMsg3 = ''   -- Blank line
               EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, 
                     @cErrMsg1, @cErrMsg2, @cErrMsg3, @cErrMsg4, @cErrMsg5, 
                     @cErrMsg6, @cErrMsg7, @cErrMsg8, @cErrMsg9
               IF @nErrNo = 1  
               BEGIN  
                  SET @cErrMsg1 = ''  
                  SET @cErrMsg2 = ''  
                  SET @cErrMsg3 = ''
                  SET @cErrMsg4 = ''
                  SET @cErrMsg5 = ''
                  SET @cErrMsg6 = ''
                  SET @cErrMsg7 = ''
                  SET @cErrMsg8 = ''
                  SET @cErrMsg9 = ''
               END  
               
               SET @nErrNo = 0
            END

            INSERT INTO traceinfo(TraceName, TimeIn, Step1, Step2, Step3, Col1, Col2, Col3, Col4)
            SELECT '640', GETDATE(), [STATUS], WkOrdUdef3, WkOrdUdef4, @cWaveKey, @cStorerKey, @cFacility, @cUserName
            FROM dbo.WorkOrder W WITH (NOLOCK)
         	JOIN #PalletId P ON W.WkOrdUdef3 = P.PalletId
         	WHERE WkOrdUdef1 = @cWaveKey
         	AND   W.StorerKey = @cStorerKey
         	AND   W.Facility = @cFacility
         	AND   W.[Type] = 'TASK'
         	
         	SET @curUpdWorkOrder = CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
         	SELECT PalletID FROM #PalletId
         	OPEN @curUpdWorkOrder
         	FETCH NEXT FROM @curUpdWorkOrder INTO @cPalletId
         	WHILE @@FETCH_STATUS = 0
         	BEGIN
               -- Stamp WKORDUDEF4 = FULL for same wavekey (wkordudef1), same PalletID (wkordudef3) 
               -- already all status = '9'
               IF NOT EXISTS ( SELECT 1  
                               FROM dbo.WorkOrder WITH (NOLOCK)
         	                   WHERE WkOrdUdef1 = @cWaveKey
         	                   AND   WkOrdUdef3 = @cPalletId
         	                   AND   StorerKey = @cStorerKey
         	                   AND   Facility = @cFacility
         	                   AND   [Type] = 'TASK'
         	                   AND   ([STATUS] = '0' OR [STATUS] = ''))
               BEGIN
                  SET @curWorkOrder = CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
         	      SELECT W.WorkOrderKey  
         	      FROM dbo.WorkOrder W WITH (NOLOCK)
         	      WHERE WkOrdUdef1 = @cWaveKey
         	      AND   WkOrdUdef3 = @cPalletId
         	      AND   StorerKey = @cStorerKey
         	      AND   Facility = @cFacility
         	      AND   [Type] = 'TASK'
         	      AND   [STATUS] = '9'
         	      OPEN @curWorkOrder
         	      FETCH NEXT FROM @curWorkOrder INTO @cWorkOrderKey
         	      WHILE @@FETCH_STATUS = 0
         	      BEGIN
         	   	   UPDATE dbo.WorkOrder SET 
         	   	      WkOrdUdef4 = 'FULL', 
         	   	      TrafficCop = NULL,
                        EditWho = @cUserName,
                        EditDate = GETDATE()
         	   	   WHERE WorkOrderKey = @cWorkOrderKey

                     IF @@ERROR <> 0               
                     BEGIN          
                        SET @nErrNo = 193252          
                        SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Upd WkOrder Err          
                        GOTO RollBackTran          
                     END
                  
         	   	   FETCH NEXT FROM @curWorkOrder INTO @cWorkOrderKey
         	      END
         	      CLOSE @curWorkOrder
         	      DEALLOCATE @curWorkOrder
               END
               
               FETCH NEXT FROM @curUpdWorkOrder INTO @cPalletId
            END
         END
      END
   END

   COMMIT TRAN rdt_640ExtUpd02

   GOTO Commit_Tran

   RollBackTran:
      ROLLBACK TRAN rdt_640ExtUpd02 -- Only rollback change made here
   Commit_Tran:
      WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
         COMMIT TRAN
   Quit:               

END  
SET QUOTED_IDENTIFIER OFF 

GO