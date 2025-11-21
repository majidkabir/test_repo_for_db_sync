SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/    
/* Store procedure: rdt_CartPicking_PrintLabel                          */    
/* Copyright      : LF                                                  */    
/*                                                                      */    
/* Purpose: Look for pick task and print label                          */    
/*                                                                      */    
/* Modifications log:                                                   */    
/* Date        Rev  Author   Purposes                                   */    
/* 2020-04-03  1.0  James    WMS-12367 Created                          */    
/* 2021-08-11  1.1  Chermain WMS-17365 Modify ExtPrintParam (cc01)      */ 
/************************************************************************/    
  
CREATE PROC [RDT].[rdt_CartPicking_PrintLabel] (    
   @nMobile          INT,    
   @nFunc            INT,    
   @cLangCode        NVARCHAR( 3),
   @nStep            INT,
   @nInputKey        INT,
   @cStorerKey       NVARCHAR( 15),
   @cFacility        NVARCHAR( 5),    
   @cAreaKey         NVARCHAR( 10),
   @cCartID          NVARCHAR( 10),    
   @cUserID          NVARCHAR( 20),    
   @cTaskType        NVARCHAR( 10),
   @cNoOfTask        NVARCHAR( 2),    
   @tPrintLabelVar   VARIABLETABLE READONLY,
   @nNoOfLabel       INT           OUTPUT,
   @nErrNo           INT           OUTPUT,    
   @cErrMsg          NVARCHAR( 20) OUTPUT  -- screen limitation, 20 char max    
) AS    
BEGIN    
   SET NOCOUNT ON    
   SET ANSI_NULLS OFF    
   SET QUOTED_IDENTIFIER OFF    
   SET CONCAT_NULL_YIELDS_NULL OFF    
   
   
   DECLARE @nTranCount        INT    
   DECLARE @cGroupKey         NVARCHAR( 10)
   DECLARE @cTaskDetailKey    NVARCHAR( 10)
   DECLARE @cPickSlipNo       NVARCHAR( 10)
   DECLARE @cOrderKey         NVARCHAR( 10)
   DECLARE @cCurOrderKey      NVARCHAR( 10)
   DECLARE @cLoadKey          NVARCHAR( 10)
   DECLARE @cLabelNo          NVARCHAR( 20)
   DECLARE @cDropID           NVARCHAR( 20)
   DECLARE @cShipLabel        NVARCHAR( 10)
   DECLARE @cCartonLbl        NVARCHAR( 10)
   DECLARE @cExtendedPrintSP  NVARCHAR( 20)
   DECLARE @cLabelPrinter     NVARCHAR( 10)
   DECLARE @nCartonNo         INT
   DECLARE @curGetTask        CURSOR
   DECLARE @curPrintLabel     CURSOR
   DECLARE @curUpdTask        CURSOR
   DECLARE @cSQL              NVARCHAR( MAX)
   DECLARE @cSQLParam         NVARCHAR( MAX)
   DECLARE @nNoOfTask         INT
   DECLARE @cCaseID           NVARCHAR( 20)
   DECLARE @cPriority         NVARCHAR( 10)
   
   SET @nNoOfLabel = 0
   SET @cCurOrderKey = ''
   SET @nNoOfTask = CAST( @cNoOfTask AS INT)
   
   SELECT @cLabelPrinter = Printer
   FROM RDT.RDTMOBREC WITH (NOLOCK)
   WHERE Mobile = @nMobile

   -- Get extended ExtendedPltBuildCfmSP
   SET @cExtendedPrintSP = rdt.rdtGetConfig( @nFunc, 'ExtendedPrintSP', @cStorerKey)
   IF @cExtendedPrintSP = '0'
      SET @cExtendedPrintSP = ''  

   -- Extended putaway
   IF @cExtendedPrintSP <> ''
   BEGIN
      IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedPrintSP AND type = 'P')
      BEGIN
         SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedPrintSP) +
            ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cFacility, ' +
            ' @cAreaKey, @cCartID, @cUserID, @cTaskType, @cNoOfTask, ' +
            ' @tPrintLabelVar, @nNoOfLabel OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT ' 
         SET @cSQLParam =
            ' @nMobile          INT,   ' +
            ' @nFunc            INT,   ' + 
            ' @cLangCode        NVARCHAR( 3),   ' +
            ' @nStep            INT,   ' +
            ' @nInputKey        INT,   ' +
            ' @cStorerKey       NVARCHAR( 15),  ' +
            ' @cFacility        NVARCHAR( 5),   ' +
            ' @cAreaKey         NVARCHAR( 10),  ' +
            ' @cCartID          NVARCHAR( 10),  ' +
            ' @cUserID          NVARCHAR( 20),  ' +
            ' @cTaskType        NVARCHAR( 10),  ' +
            ' @cNoOfTask        NVARCHAR( 2),   ' +
            ' @tPrintLabelVar   VARIABLETABLE READONLY,  ' +
            ' @nNoOfLabel       INT           OUTPUT,  ' +
            ' @nErrNo           INT           OUTPUT,    ' +    
            ' @cErrMsg          NVARCHAR( 20) OUTPUT     ' 

         EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
            @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cFacility, 
            @cAreaKey, @cCartID, @cUserID, @cTaskType, @cNoOfTask, 
            @tPrintLabelVar, @nNoOfLabel OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT

         IF @nErrNo <> 0
            GOTO Fail
      END
   END
   ELSE
   BEGIN
      SET @cShipLabel = rdt.RDTGetConfig( @nFunc, 'ShipLabel', @cStorerKey)
      IF @cShipLabel = '0'
         SET @cShipLabel = ''

      SET @cCartonLbl = rdt.RDTGetConfig( @nFunc, 'CartonLabel', @cStorerKey)
      IF @cCartonLbl = '0'
         SET @cCartonLbl = ''
                  
      SET @nTranCount = @@TRANCOUNT    
    
      BEGIN TRAN    
      SAVE TRAN rdt_CartPicking_PrintLabel    
    
      SET @cGroupKey = ''
      WHILE @nNoOfTask > 0
      BEGIN
         IF @cGroupKey <> ''  -- 1 Cart 1 groupkey
            GOTO Quit

         SELECT TOP 1 @cGroupKey = Groupkey
         FROM dbo.TaskDetail T1 WITH (NOLOCK)
         JOIN dbo.LOC LOC WITH (NOLOCK) ON  T1.FromLoc = Loc.Loc
         JOIN dbo.AreaDetail AD WITH (NOLOCK) ON  AD.Putawayzone = Loc.PutAwayZone     
         WHERE T1.Storerkey = @cStorerKey
         AND   T1.TaskType = @cTaskType
         AND   T1.UserKey = ''
         AND   T1.[Status] = '0'
         AND   T1.UserKeyOverRide = ''
         AND   T1.DeviceID = ''
         AND   AD.AreaKey = @cAreaKey
         AND   EXISTS( SELECT 1 FROM TaskManagerUserDetail TMU WITH (NOLOCK)
                     WHERE TMU.PermissionType = T1.TASKTYPE
                        AND TMU.UserKey = @cUserID  
                        AND TMU.AreaKey = @cAreaKey 
                        AND TMU.Permission = '1')
         -- Exclude partial picked task
         AND   NOT EXISTS( SELECT 1 FROM dbo.TaskDetail T2 WITH (NOLOCK)
                           WHERE T1.Groupkey = T2.Groupkey
                           AND   T2.[Status] > '0'
                           AND   T1.TaskType = T2.TaskType)
         ORDER BY T1.Priority

         IF @@ROWCOUNT = 0
         BEGIN
            -- Something print, exit
            IF @nNoOfTask < CAST( @cNoOfTask AS INT)
               GOTO Quit
            ELSE
            -- Nothing printed, prompt error
            BEGIN
               SET @nErrNo = 150651
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --No Task Found
               GOTO RollBackTran
            END
         END                      
         ELSE
         BEGIN
            IF OBJECT_ID('tempdb..#LabelPrinted') IS NOT NULL  
               DROP TABLE #LabelPrinted
         
            CREATE TABLE #LabelPrinted  (  
               RowRef        BIGINT IDENTITY(1,1)  Primary Key,  
               LabelNo       NVARCHAR( 20))  
                     
            SET @curGetTask = CURSOR FOR 
            SELECT DISTINCT Caseid, Priority
            FROM dbo.TaskDetail WITH (NOLOCK)
            WHERE Groupkey = @cGroupKey
            AND   [Status] = '0'
            ORDER BY Priority, Caseid
            OPEN @curGetTask
            FETCH NEXT FROM @curGetTask INTO @cCaseID, @cPriority
            WHILE @@FETCH_STATUS = 0
            BEGIN
               SET @curPrintLabel = CURSOR FOR
               SELECT DISTINCT OrderKey, CaseID, DropID
               FROM dbo.PICKDETAIL WITH (NOLOCK)
               WHERE CaseID = @cCaseID
               ORDER BY OrderKey, CaseID
               OPEN @curPrintLabel
               FETCH NEXT FROM @curPrintLabel INTO @cOrderKey, @cLabelNo, @cDropID
               WHILE @@FETCH_STATUS = 0
               BEGIN
                  -- If orders not same only need retrieve again pickslipno
                  IF @cCurOrderKey <> @cOrderKey
                  BEGIN
                     -- Get PickSlipNo (discrete)  
                     SELECT @cPickSlipNo = PickSlipNo FROM PackHeader WITH (NOLOCK) WHERE OrderKey = @cOrderKey    
                     IF @cPickSlipNo = ''    
                        SELECT @cPickSlipNo = PickHeaderKey FROM PickHeader WITH (NOLOCK) WHERE OrderKey = @cOrderKey  

                     -- Get PickSlipNo (conso)  
                     IF @cPickSlipNo = ''   
                     BEGIN  
                        SELECT @cLoadKey = LoadKey FROM LoadPlanDetail WITH (NOLOCK) WHERE OrderKey = @cOrderKey           
                        IF @cLoadKey = ''   
                        BEGIN  
                           SET @nErrNo = 146951  
                           SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --No LoadKey  
                           GOTO RollBackTran  
                        END  
  
                        SELECT @cPickSlipNo = PickSlipNo FROM PackHeader WITH (NOLOCK) WHERE LoadKey = @cLoadKey AND OrderKey = ''  
                        IF @cPickSlipNo = ''    
                           SELECT @cPickSlipNo = PickHeaderKey FROM PickHeader WITH (NOLOCK) WHERE ExternOrderKey = @cLoadkey AND OrderKey = ''  
                     END  

                     -- Check PickSlip  
                     IF @cPickSlipNo = ''   
                     BEGIN  
                        SET @nErrNo = 146952  
                        SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --No PickSlipNo  
                        GOTO RollBackTran  
                     END 
                  END

                  SET @cCurOrderKey = @cOrderKey
                  
                  IF NOT EXISTS ( SELECT 1 FROM #LabelPrinted WHERE LabelNo = @cLabelNo)
                     INSERT INTO #LabelPrinted (LabelNo) VALUES (@cLabelNo)
                  
                  FETCH NEXT FROM @curPrintLabel INTO @cOrderKey, @cLabelNo, @cDropID
               END

               SET @curUpdTask = CURSOR FOR 
               SELECT TaskDetailKey 
               FROM dbo.TaskDetail WITH (NOLOCK) 
               WHERE Storerkey = @cStorerKey 
               AND   TaskType = @cTaskType 
               AND   Groupkey = @cGroupKey
               AND   Caseid = @cCaseID 
               AND   [Status] = '0'
               OPEN @curUpdTask
               FETCH NEXT FROM @curUpdTask INTO @cTaskDetailKey
               WHILE @@FETCH_STATUS = 0
               BEGIN
                  UPDATE dbo.TaskDetail SET 
                     DeviceID = @cCartID,
                     UserKeyOverRide = @cUserID,
                     EditDate = GETDATE(),
                     EditWho = @cUserID
                  WHERE TaskDetailKey = @cTaskDetailKey
         
                  IF @@ERROR <> 0
                  BEGIN
                     SET @nErrNo = 150652
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Task No Allow
                     GOTO RollBackTran
                  END
                  
                  FETCH NEXT FROM @curUpdTask INTO @cTaskDetailKey
               END

               IF @cCartonLbl <> ''
               BEGIN
                                       --SELECT @cLabelNo '@cLabelNo'
                  DECLARE @tCARTONLBL AS VariableTable
                  DELETE FROM @tCARTONLBL
                  INSERT INTO @tCARTONLBL (Variable, Value) VALUES ( '@cPickSlipNo',   @cPickSlipNo)
                  INSERT INTO @tCARTONLBL (Variable, Value) VALUES ( '@nFromCartonNo', @nCartonNo)
                  INSERT INTO @tCARTONLBL (Variable, Value) VALUES ( '@nToCartonNo',   @nCartonNo)
                  INSERT INTO @tCARTONLBL (Variable, Value) VALUES ( '@cFromLabelNo', @cLabelNo)
                  INSERT INTO @tCARTONLBL (Variable, Value) VALUES ( '@cToLabelNo',   @cLabelNo)
                  INSERT INTO @tCARTONLBL (Variable, Value) VALUES ( '@cDropID',   @cDropID)

                  -- Print label
                  EXEC RDT.rdt_Print @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerkey, @cLabelPrinter, '', 
                     @cCartonLbl,  -- Report type
                     @tCARTONLBL, -- Report params
                     'rdt_CartPicking_PrintLabel', 
                     @nErrNo  OUTPUT,
                     @cErrMsg OUTPUT 

                  IF @nErrNo <> 0
                     GOTO RollBackTran

                  SET @nNoOfLabel = @nNoOfLabel + 1
               END


               IF @cShipLabel <> ''
               BEGIN
                                       --SELECT @cLabelNo '@cLabelNo'
                  DECLARE @tSHIPPLABEL AS VariableTable
                  DELETE FROM @tSHIPPLABEL
                  INSERT INTO @tSHIPPLABEL (Variable, Value) VALUES ( '@cPickSlipNo',   @cPickSlipNo)
                  INSERT INTO @tSHIPPLABEL (Variable, Value) VALUES ( '@nFromCartonNo', @nCartonNo)
                  INSERT INTO @tSHIPPLABEL (Variable, Value) VALUES ( '@nToCartonNo',   @nCartonNo)
                  INSERT INTO @tSHIPPLABEL (Variable, Value) VALUES ( '@cFromLabelNo',  @cLabelNo)
                  INSERT INTO @tSHIPPLABEL (Variable, Value) VALUES ( '@cToLabelNo',    @cLabelNo)
                  INSERT INTO @tSHIPPLABEL (Variable, Value) VALUES ( '@cDropID',    @cDropID)

                  -- Print label
                  EXEC RDT.rdt_Print @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerkey, @cLabelPrinter, '', 
                     @cShipLabel,  -- Report type
                     @tSHIPPLABEL, -- Report params
                     'rdt_CartPicking_PrintLabel', 
                     @nErrNo  OUTPUT,
                     @cErrMsg OUTPUT 

                  IF @nErrNo <> 0
                     GOTO RollBackTran

                  SET @nNoOfLabel = @nNoOfLabel + 1
               END

               FETCH NEXT FROM @curGetTask INTO @cCaseID, @cPriority

               SET @nNoOfTask = @nNoOfTask - 1      

               IF @nNoOfTask = 0
                  GOTO Quit
            END
         END
      END
      GOTO QUIT           
             
      RollBackTran:          
         ROLLBACK TRAN rdt_CartPicking_PrintLabel -- Only rollback change made here          
          
      Quit:          
         WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started          
            COMMIT TRAN rdt_CartPicking_PrintLabel          
   END
   
   Fail:
END  

GO