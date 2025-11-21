SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store procedure: rdt_TM_ClusterPick_ShowCartonPos                    */
/* Copyright      : IDS                                                 */
/*                                                                      */
/* Purpose: Show carton position                                        */
/*                                                                      */
/* Called from: rdtfnc_TM_ClusterPick                                   */
/*                                                                      */
/* Date         Rev  Author   Purposes                                  */
/* 2021-07-15   1.0  James    WMS-17429 Created                         */
/* 2022-04-08   1.1  James    Perf tuning                               */
/************************************************************************/

CREATE PROC [RDT].[rdt_TM_ClusterPick_ShowCartonPos] (
   @nMobile        INT,
   @nFunc          INT,
   @cLangCode      NVARCHAR( 3),
   @nStep          INT,
   @nInputKey      INT,
   @cFacility      NVARCHAR( 5),
   @cStorerKey     NVARCHAR( 15),
   @cGroupKey      NVARCHAR( 10),
   @cTaskDetailKey NVARCHAR( 10),
   @cCartonID      NVARCHAR( 20),
   @cPosition      NVARCHAR( 20) OUTPUT,
   @nErrNo         INT           OUTPUT,
   @cErrMsg        NVARCHAR( 20) OUTPUT
)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @cSQL           NVARCHAR( MAX)  
   DECLARE @cSQLParam      NVARCHAR( MAX)  
   DECLARE @cShowCartonPos NVARCHAR( 20)  
   
   -- Get storer config  
   SET @cShowCartonPos = rdt.RDTGetConfig( @nFunc, 'ShowCartonPosSP', @cStorerKey)  
   IF @cShowCartonPos = '0'  
      SET @cShowCartonPos = ''  
  
   /***********************************************************************************************  
                                    Custom Show Carton Pos  
   ***********************************************************************************************/  
   -- Check confirm SP blank  
   IF @cShowCartonPos <> ''  
   BEGIN  
      -- Confirm SP  
      SET @cSQL = 'EXEC rdt.' + RTRIM( @cShowCartonPos) +  
         ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, ' + 
         ' @cFacility, @cStorerKey, @cGroupKey, @cTaskDetailKey, @cCartonID, ' +  
         ' @cPosition OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT '  
      SET @cSQLParam =  
         ' @nMobile        INT,           ' +  
         ' @nFunc          INT,           ' +  
         ' @cLangCode      NVARCHAR( 3),  ' +  
         ' @nStep          INT,           ' +  
         ' @nInputKey      INT,           ' +  
         ' @cFacility      NVARCHAR( 5) , ' +  
         ' @cStorerKey     NVARCHAR( 15), ' +  
         ' @cGroupKey      NVARCHAR( 10), ' +
         ' @cTaskDetailKey NVARCHAR( 10), ' +
         ' @cCartonID      NVARCHAR( 20), ' +
         ' @cPosition      NVARCHAR( 20) OUTPUT, ' +
         ' @nErrNo         INT           OUTPUT, ' +  
         ' @cErrMsg        NVARCHAR(250) OUTPUT  '  
  
      EXEC sp_ExecuteSQL @cSQL, @cSQLParam,  
         @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, 
         @cFacility, @cStorerKey, @cGroupKey, @cTaskDetailKey, @cCartonID, 
         @cPosition OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT 
  
      GOTO Quit  
   END  
  
   /***********************************************************************************************  
                                    Standard Show Carton Pos  
   ***********************************************************************************************/  
   DECLARE @curPD CURSOR
   DECLARE @cPickSlipNo    NVARCHAR( 10) = ''
   DECLARE @cCartonType    NVARCHAR( 10) = ''
   DECLARE @nCount         INT = 0
   DECLARE @nCartonNo      INT
   DECLARE @cLabelNo       NVARCHAR( 20)
   
   CREATE TABLE #CaseInfo  (  
      RowRef         BIGINT IDENTITY(1,1)  Primary Key,  
      PickSlipNo     NVARCHAR( 10),
      LabelNo        NVARCHAR( 20))  

   -- Get PickslipNo, LabelNo
   INSERT INTO #CaseInfo (PickSlipNo, LabelNo)
   SELECT DISTINCT PH.PickSlipNo, TD.Caseid
   FROM dbo.TASKDETAIL TD (NOLOCK) 
   JOIN dbo.PICKDETAIL PD (NOLOCK) ON ( TD.Caseid = PD.CaseID) 
   JOIN dbo.PackHeader PH (NOLOCK) ON ( PD.OrderKey = PH.orderkey AND PH.StorerKey = PD.Storerkey)
   WHERE TD.Groupkey = @cGroupKey
   AND   TD.[Status] < '9'
   AND   TD.TaskType = 'CPK'
   AND   TD.Caseid <> ''
   AND   PD.[Status] < '9'
   
   SET @nCount = 1

   SET @curPD = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT PD.PickSlipNo, PD.CartonNo, PIF.CartonType, C.LabelNo
   FROM #CaseInfo C 
   JOIN dbo.PackDetail PD WITH (NOLOCK) ON ( C.PickSlipNo = PD.PickSlipNo AND C.LabelNo = PD.LabelNo)
   JOIN dbo.PackInfo PIF WITH (NOLOCK) ON ( PD.PickSlipNo = PIF.PickSlipNo AND PD.CartonNo = PIF.CartonNo)
   JOIN dbo.CARTONIZATION CZ WITH (NOLOCK) ON ( PIF.CartonType = CZ.CartonType)
   JOIN STORER ST WITH (NOLOCK) ON ( CZ.CartonizationGroup = ST.CartonGroup)
   WHERE ST.StorerKey = @cStorerKey
   GROUP BY PD.PickSlipNo, PD.CartonNo, PIF.CartonType, CZ.[CUBE], CZ.UseSequence, C.LabelNo
   ORDER BY CZ.CUBE, CZ.UseSequence
   OPEN @curPD
   FETCH NEXT FROM @curPD INTO @cPickSlipNo, @nCartonNo, @cCartonType, @cLabelNo
   WHILE @@FETCH_STATUS = 0
   BEGIN
      IF @nCount = 1 SET @cPosition = 'POS: 1'
      IF @nCount = 2 SET @cPosition = 'POS: 2'
      IF @nCount = 3 SET @cPosition = 'POS: 3'
      IF @nCount = 4 SET @cPosition = 'POS: 4'
      IF @nCount = 5 SET @cPosition = 'POS: 5'
      IF @nCount = 6 SET @cPosition = 'POS: 6'
      IF @nCount = 7 SET @cPosition = 'POS: 7'
      IF @nCount = 8 SET @cPosition = 'POS: 8'
      
      SET @nCount = @nCount + 1
      
      IF @cLabelNo = @cCartonID OR  @nCount >= 8
         BREAK

      FETCH NEXT FROM @curPD INTO @cPickSlipNo, @nCartonNo, @cCartonType, @cLabelNo
   END
 

   Quit:
END

GO