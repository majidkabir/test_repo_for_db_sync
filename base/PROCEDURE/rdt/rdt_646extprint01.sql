SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
  
/************************************************************************/      
/* Store procedure: rdt_646ExtPrint01                                   */      
/* Copyright      : LF                                                  */      
/*                                                                      */      
/* Purpose: Look for pick task and print label                          */      
/*                                                                      */      
/* Modifications log:                                                   */      
/* Date        Rev  Author    Purposes                                  */      
/* 2021-07-07  1.0  Chermaine WMS-17365 Created                         */      
/* 2022-02-21  1.1  James     WMS-18699 Add sorting priority (james01)  */
/* 2022-04-26  1.2  James     Add missing Print Export Label (james02)  */
/* 2023-08-04  1.3  JihHaur   JSM-168373 Avoid 1 case ID with different */
/*                            groupkey assigned (JH01)                  */   
/************************************************************************/      
    
CREATE   PROC [RDT].[rdt_646ExtPrint01] (      
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
   DECLARE @cPickSlipNo       NVARCHAR( 10)  
   DECLARE @cOrderKey         NVARCHAR( 10)  
   DECLARE @cCurOrderKey      NVARCHAR( 10)  
   DECLARE @cLoadKey          NVARCHAR( 10)  
   DECLARE @cLabelNo          NVARCHAR( 20)  
   DECLARE @cDropID           NVARCHAR( 20)  
   DECLARE @cShipLabel        NVARCHAR( 10)  
   DECLARE @cCartonLbl        NVARCHAR( 10)  
   DECLARE @cExportLabel      NVARCHAR( 10)
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
   DECLARE @cCountry          NVARCHAR( 5)
   
   DECLARE @cNumTote       NVARCHAR(10)  
   DECLARE @cPickMethod    NVARCHAR(20)  
   DECLARE @ctaskDetailKey NVARCHAR(10)  
   DECLARE @cWaveKey       NVARCHAR(10)  
   DECLARE @cFromLoc       NVARCHAR(10)  
   DECLARE @cPickZone      NVARCHAR(10)  
   DECLARE @cChkLoadPlan   NVARCHAR(1)  
   DECLARE @nNumTote       INT  
   DECLARE @b_success      INT  
     
   SET @nNoOfLabel = 0  
   SET @cCurOrderKey = ''  
   SET @nNoOfTask = CAST( @cNoOfTask AS INT)  
     
   SELECT @cLabelPrinter = Printer  
   FROM RDT.RDTMOBREC WITH (NOLOCK)  
   WHERE Mobile = @nMobile  
  
   SELECT 
      @cCountry = Country
   FROM storer WITH (NOLOCK)
   WHERE StorerKey = @cStorerKey
   
   SET @cShipLabel = rdt.RDTGetConfig( @nFunc, 'ShipLabel', @cStorerKey)  
   IF @cShipLabel = '0'  
      SET @cShipLabel = ''  
  
   SET @cCartonLbl = rdt.RDTGetConfig( @nFunc, 'CartonLabel', @cStorerKey)  
   IF @cCartonLbl = '0'  
      SET @cCartonLbl = ''  
        
   SET @cChkLoadPlan = rdt.RDTGetConfig( @nFunc, 'ChkLoadPlan', @cStorerKey)  
   IF @cChkLoadPlan = '0'  
      SET @cChkLoadPlan = ''        
        
   SET @cExportLabel = rdt.RDTGetConfig( @nFunc, 'ExportLabel', @cStorerKey)
   IF @cExportLabel = '0'
      SET @cExportLabel = ''            

   SET @nTranCount = @@TRANCOUNT      
      
   BEGIN TRAN      
   SAVE TRAN rdt_646ExtPrint01      
      
   SET @cGroupKey = ''  
   WHILE @nNoOfTask > 0  
   BEGIN  
      
      SELECT   
         @cNumTote = Short,   
         @cPickMethod = LONG   
      FROM codelkup (NOLOCK)   
      WHERE storerKey = @cStorerKey   
      AND listName = 'TMPickMtd'    
      AND code = '1'--B2b  
        
      SET @nNumTote = convert (INT,@cNumTote)  
   
      SELECT TOP (@nNumTote) taskDetailKey  
      FROM TaskDetail TD WITH (NOLOCK)  
      WHERE TD.storerKey = 'ADIDAS'  
      AND pickMethod = @cPickMethod  
      AND taskType = 'CPK'  
      AND groupKey = ''  
      ORDER BY Message01  
  
      IF @cGroupKey <> ''  -- 1 Cart 1 groupkeyphw  
         GOTO Quit  
           
      SELECT TOP 1   
         @cWaveKey = T1.WaveKey,  
         @cFromLoc = T1.FromLoc,  
         @cPickZone = Loc.PickZone  
      FROM dbo.TaskDetail T1 WITH (NOLOCK)  
      JOIN dbo.LOC LOC WITH (NOLOCK) ON  T1.FromLoc = Loc.Loc  
      JOIN dbo.AreaDetail AD WITH (NOLOCK) ON  AD.Putawayzone = Loc.PutAwayZone       
      JOIN dbo.Orders O WITH (NOLOCK) ON O.UserDefine09 = T1.wavekey  
      WHERE T1.Storerkey = @cStorerKey  
      AND   T1.TaskType = @cTaskType  
      AND   T1.UserKey = ''  
      AND   T1.[Status] = '0'  
      AND   T1.UserKeyOverRide = ''  
      AND   T1.DeviceID = ''  
      AND   T1.PickMethod = @cPickMethod  
      AND   T1.groupKey = ''  
      AND   AD.AreaKey = @cAreaKey  
      AND   EXISTS( SELECT 1 FROM TaskManagerUserDetail TMU WITH (NOLOCK)  
                  WHERE TMU.PermissionType = T1.TASKTYPE  
                     AND TMU.UserKey = @cUserID    
                     AND TMU.AreaKey = @cAreaKey   
                     AND TMU.Permission = '1')  
      ---- Exclude partial picked task  
      --AND   NOT EXISTS( SELECT 1 FROM dbo.TaskDetail T2 WITH (NOLOCK)  
      --                  WHERE T1.Groupkey = T2.Groupkey  
      --                  AND   T2.[Status] > '0'  
      --                  AND   T1.TaskType = T2.TaskType)  
      ORDER BY T1.WaveKey, T1.Message01   
                          
      IF @@ROWCOUNT = 0    
      BEGIN  
         -- Something print, exit  
         IF @nNoOfTask < CAST( @cNoOfTask AS INT)  
            GOTO Quit  
         ELSE  
         -- Nothing printed, prompt error  
         BEGIN  
            SET @nErrNo = 170601  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --No Task Found  
            GOTO RollBackTran  
         END  
      END                        
      ELSE   
      BEGIN  
       IF @cChkLoadPlan <> '' AND @cTaskType = 'CPK'  
         BEGIN  
          IF EXISTS (SELECT 1 FROM Orders WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND UserDefine09 = @cWaveKey AND LoadKey = '')  
          BEGIN  
           SET @nErrNo = 170606  
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --TaskNoLoadKey  
               GOTO RollBackTran  
          END  
       END  
         
       SET @b_success = 1    
         -- Get new GroupKey    
         EXECUTE dbo.nspg_GetKey    
            'GroupKey',    
            10 ,    
            @cGroupKey   OUTPUT,    
            @b_Success   OUTPUT,    
            @nErrNo      OUTPUT,    
            @cErrMsg     OUTPUT    
         IF @b_Success <> 1    
         BEGIN    
            SET @nErrNo = 170602    
            SET @cErrMsg = rdt.rdtgetmessage( @cErrMsg, @cLangCode, 'DSP') -- GetKey Fail    
            GOTO Quit    
         END    
  
         IF OBJECT_ID('tempdb..#LabelPrinted') IS NOT NULL    
            DROP TABLE #LabelPrinted  
           
         CREATE TABLE #LabelPrinted  (    
            RowRef        BIGINT IDENTITY(1,1)  Primary Key,    
            LabelNo       NVARCHAR( 20))    
                       
            SET @curGetTask = CURSOR FOR   
              
            SELECT TOP (@nNumTote) T1.Caseid  
            FROM dbo.TaskDetail T1 WITH (NOLOCK)  
            JOIN dbo.LOC LOC WITH (NOLOCK) ON  T1.FromLoc = Loc.Loc  
            JOIN dbo.AreaDetail AD WITH (NOLOCK) ON  AD.Putawayzone = Loc.PutAwayZone       
            WHERE T1.Storerkey = @cStorerKey  
            AND   T1.TaskType = @cTaskType  
            AND   T1.UserKey = ''  
            AND   T1.[Status] = '0'  
            AND   T1.UserKeyOverRide = ''  
            AND   T1.DeviceID = ''  
            AND   T1.PickMethod = @cPickMethod  
            AND   T1.groupKey = ''  
            AND   T1.WaveKey = @cWaveKey  
            AND   Loc.PickZone = @cPickZone  
            AND   AD.AreaKey = @cAreaKey  
            AND   EXISTS( SELECT 1 FROM TaskManagerUserDetail TMU WITH (NOLOCK)  
                        WHERE TMU.PermissionType = T1.TASKTYPE  
                           AND TMU.UserKey = @cUserID    
                           AND TMU.AreaKey = @cAreaKey   
                           AND TMU.Permission = '1')  
            GROUP BY T1.caseID, T1.Message01, T1.Priority   
            ORDER BY T1.Priority, T1.Message01   
              
            OPEN @curGetTask  
            FETCH NEXT FROM @curGetTask INTO @cCaseID  
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
                           SET @nErrNo = 170603    
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
                        SET @nErrNo = 170604    
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
               SELECT T1.TaskDetailKey   
               FROM dbo.TaskDetail T1 WITH (NOLOCK)  
               JOIN dbo.LOC LOC WITH (NOLOCK) ON  T1.FromLoc = Loc.Loc  
               JOIN dbo.AreaDetail AD WITH (NOLOCK) ON  AD.Putawayzone = Loc.PutAwayZone       
               WHERE T1.Storerkey = @cStorerKey  
               AND   T1.TaskType = @cTaskType  
               AND   T1.UserKey = ''  
               AND   T1.[Status] = '0'  
               AND   T1.UserKeyOverRide = ''  
               AND   T1.DeviceID = ''  
               AND   T1.PickMethod = @cPickMethod  
               AND   T1.groupKey = ''  
               AND   T1.WaveKey = @cWaveKey  
               AND   Loc.PickZone = @cPickZone  
               AND   T1.CaseID = @cCaseID  
               AND   AD.AreaKey = @cAreaKey  
               AND   EXISTS( SELECT 1 FROM TaskManagerUserDetail TMU WITH (NOLOCK)  
                           WHERE TMU.PermissionType = T1.TASKTYPE  
                              AND TMU.UserKey = @cUserID    
                              AND TMU.AreaKey = @cAreaKey   
                              AND TMU.Permission = '1')  
               OPEN @curUpdTask  
               FETCH NEXT FROM @curUpdTask INTO @cTaskDetailKey  
               WHILE @@FETCH_STATUS = 0  
               BEGIN  
                 
                  UPDATE dbo.TaskDetail SET   
                     DeviceID = @cCartID,  
                     UserKeyOverRide = @cUserID,  
                     EditDate = GETDATE(),  
                     EditWho = @cUserID,  
                     GroupKey = @cGroupKey  
                  WHERE TaskDetailKey = @cTaskDetailKey
                  AND   GroupKey = '' /*JH01*/
           
                  IF @@ERROR <> 0 OR @@ROWCOUNT <> 1  /*JH01 add OR @@ROWCOUNT <> 1*/
                  BEGIN  
                     SET @nErrNo = 170605  
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD Task Fail  
                     GOTO RollBackTran  
                  END  
                    
                  FETCH NEXT FROM @curUpdTask INTO @cTaskDetailKey    
               END   
  
               --export order label
               IF EXISTS (SELECT TOP 1 1 
                          FROM Orders O WITH (NOLOCK) 
                          JOIN PICKDETAIL PD WITH (NOLOCK) ON (O.orderKey = PD.OrderKey)
                          WHERE PD.CaseID = @cCaseID 
                          AND O.C_Country <> @cCountry) --export order
               BEGIN
               	IF @cExportLabel <> ''
                  BEGIN
                     --SELECT @cLabelNo '@cLabelNo'
                     DECLARE @tExportLBL AS VariableTable
                     DELETE FROM @tExportLBL
                     INSERT INTO @tExportLBL (Variable, Value) VALUES ( '@cPickSlipNo',   @cPickSlipNo)
                     INSERT INTO @tExportLBL (Variable, Value) VALUES ( '@nFromCartonNo', @nCartonNo)
                     INSERT INTO @tExportLBL (Variable, Value) VALUES ( '@nToCartonNo',   @nCartonNo)
                     INSERT INTO @tExportLBL (Variable, Value) VALUES ( '@cFromLabelNo', @cLabelNo)
                     INSERT INTO @tExportLBL (Variable, Value) VALUES ( '@cToLabelNo',   @cLabelNo)
                     INSERT INTO @tExportLBL (Variable, Value) VALUES ( '@cDropID',   @cDropID)

                     -- Print label
                     EXEC RDT.rdt_Print @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerkey, @cLabelPrinter, '', 
                        @cExportLabel,  -- Report type
                        @tExportLBL, -- Report params
                        'rdt_646ExtPrint01', 
                        @nErrNo  OUTPUT,
                        @cErrMsg OUTPUT 

                     IF @nErrNo <> 0
                        GOTO RollBackTran

                     SET @nNoOfLabel = @nNoOfLabel + 1
                  END
               END
               ELSE
               BEGIN
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
                        'rdt_646ExtPrint01', 
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
                        'rdt_646ExtPrint01', 
                        @nErrNo  OUTPUT,
                        @cErrMsg OUTPUT 

                     IF @nErrNo <> 0
                        GOTO RollBackTran

                     SET @nNoOfLabel = @nNoOfLabel + 1
                  END
               END
  
               FETCH NEXT FROM @curGetTask INTO @cCaseID  
  
               SET @nNoOfTask = @nNoOfTask - 1        
  
               IF @nNoOfTask = 0  
                  GOTO Quit  
            END  
         END  
      END  
      GOTO QUIT             
               
      RollBackTran:            
         ROLLBACK TRAN rdt_646ExtPrint01 -- Only rollback change made here            
            
      Quit:            
         WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started            
            COMMIT TRAN rdt_646ExtPrint01            
     
     
   Fail:  
END    

GO