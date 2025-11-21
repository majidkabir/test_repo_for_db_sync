SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
  
/************************************************************************/  
/* Store procedure: rdt_TM_Assist_ClusterPick_Matrix                    */  
/* Copyright      : IDS                                                 */  
/*                                                                      */  
/* Purpose: Show carton matrix                                          */  
/*                                                                      */  
/* Called from: rdtfnc_TM_Assist_ClusterPick                            */  
/*                                                                      */  
/* Date         Rev  Author   Purposes                                  */  
/* 2020-07-26   1.0  James    WMS-17335 Created                         */  
/************************************************************************/  
  
CREATE PROC [RDT].[rdt_TM_Assist_ClusterPick_Matrix] (  
   @nMobile        INT,  
   @nFunc          INT,  
   @cLangCode      NVARCHAR( 3),  
   @nStep          INT,  
   @nInputKey      INT,  
   @cFacility      NVARCHAR( 5),  
   @cStorerKey     NVARCHAR( 15),  
   @cPickZone      NVARCHAR( 10),  
   @cCartID        NVARCHAR( 10),  
   @cMethod        NVARCHAR( 1),  
   @cResult01      NVARCHAR( 20) OUTPUT,  
   @cResult02      NVARCHAR( 20) OUTPUT,  
   @cResult03      NVARCHAR( 20) OUTPUT,  
   @cResult04      NVARCHAR( 20) OUTPUT,  
   @cResult05      NVARCHAR( 20) OUTPUT,  
   @nNextPage      INT           OUTPUT,  
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
   DECLARE @cMatrixSP      NVARCHAR( 20)  
     
   -- Get storer config  
   SET @cMatrixSP = rdt.rdtGetConfig( @nFunc, 'MatrixSP', @cStorerKey)  
   IF @cMatrixSP = '0'  
      SET @cMatrixSP = ''    
  
   /***********************************************************************************************  
                                     Custom Matrix  
   ***********************************************************************************************/  
   IF @cMatrixSP <> ''  
   BEGIN  
      IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cMatrixSP AND type = 'P')  
      BEGIN  
         SET @cSQL = 'EXEC rdt.' + RTRIM( @cMatrixSP) +  
            ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey,  ' +   
            ' @cFacility, @cStorerKey, @cPickZone, @cCartID, @cMethod, ' +   
            ' @cResult01 OUTPUT, @cResult02 OUTPUT, @cResult03 OUTPUT, @cResult04 OUTPUT, @cResult05 OUTPUT, ' +  
            ' @nNextPage,  @nErrNo OUTPUT, @cErrMsg OUTPUT'  
         SET @cSQLParam =  
            '@nMobile         INT,                    ' +  
            '@nFunc           INT,                    ' +  
            '@cLangCode       NVARCHAR( 3),           ' +  
            '@nStep           INT,                    ' +  
            '@nInputKey       INT,                    ' +  
            '@cFacility       NVARCHAR( 5),           ' +  
            '@cStorerKey      NVARCHAR( 15),          ' +  
            '@cPickZone       NVARCHAR( 10),          ' +  
            '@cCartID         NVARCHAR( 10),          ' +  
            '@cMethod         NVARCHAR( 1),           ' +  
            '@cResult01       NVARCHAR( 20) OUTPUT,   ' +  
            '@cResult02       NVARCHAR( 20) OUTPUT,   ' +  
            '@cResult03       NVARCHAR( 20) OUTPUT,   ' +  
            '@cResult04       NVARCHAR( 20) OUTPUT,   ' +  
            '@cResult05       NVARCHAR( 20) OUTPUT,   ' +  
            '@nNextPage       INT           OUTPUT,   ' +  
            '@nErrNo          INT           OUTPUT,   ' +  
            '@cErrMsg         NVARCHAR( 20) OUTPUT    '  
  
         EXEC sp_ExecuteSQL @cSQL, @cSQLParam,  
            @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey,   
            @cFacility, @cStorerKey, @cPickZone, @cCartID, @cMethod,   
            @cResult01 OUTPUT, @cResult02 OUTPUT, @cResult03 OUTPUT, @cResult04 OUTPUT, @cResult05 OUTPUT,    
            @nNextPage, @nErrNo OUTPUT, @cErrMsg OUTPUT  
  
         GOTO Quit  
      END  
   END  
     
   /***********************************************************************************************  
                                     Standard Matrix  
   ***********************************************************************************************/  
     
   DECLARE @curDisplay     CURSOR  
   DECLARE @nCartLimit     INT  
   DECLARE @nCount         INT  
   DECLARE @cCaseID        NVARCHAR( 20)  
   DECLARE @cPickMethod    NVARCHAR( 10)  
   DECLARE @cCartonType    NVARCHAR( 10)  
     
   SELECT @nCartLimit = Short,  
          @cCartonType = UDF01  
   FROM dbo.CODELKUP WITH (NOLOCK)  
   WHERE LISTNAME = 'TMPICKMTD'  
   AND   Code = @cMethod  
   AND   Storerkey = @cStorerKey  
     
   SET @nCount = 1  
   SET @curDisplay = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
   SELECT DISTINCT CaseID, PickMethod  
   FROM dbo.TaskDetail WITH (NOLOCK)  
   WHERE Storerkey = @cStorerKey  
   AND   TaskType = 'ASTCPK'  
   AND   [Status] = '3'  
   AND   DeviceID = @cCartID  
   ORDER BY PickMethod  
   OPEN @curDisplay  
   FETCH NEXT FROM @curDisplay INTO @cCaseID, @cPickMethod  
   WHILE @@FETCH_STATUS = 0  
   BEGIN  
      IF @nCount = 1 SET @cResult01 = '1-' + @cCartonType  
      IF @nCount = 2 SET @cResult02 = '2-' + @cCartonType  
      IF @nCount = 3 SET @cResult03 = '3-' + @cCartonType  
      IF @nCount = 4 SET @cResult04 = '4-' + @cCartonType  
      IF @nCount = 5 SET @cResult05 = '5-' + @cCartonType  
        
      IF @nCount = @nCartLimit  
         BREAK  
      ELSE  
         SET @nCount = @nCount + 1  
  
      FETCH NEXT FROM @curDisplay INTO @cCaseID, @cPickMethod  
   END  
   
  
   Quit:  
END  

GO