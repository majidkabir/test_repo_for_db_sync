SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/  
/* Store procedure: rdt_1855MatrixSP01                                  */  
/* Copyright      : IDS                                                 */  
/*                                                                      */  
/* Purpose: Show carton matrix                                          */  
/*                                                                      */  
/* Called from: rdtfnc_TM_Assist_ClusterPick                            */  
/*                                                                      */  
/* Date         Rev  Author   Purposes                                  */  
/* 2020-07-26   1.0  James    WMS-17335 Created                         */  
/************************************************************************/  
  
CREATE PROC [RDT].[rdt_1855MatrixSP01] (  
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
  
   DECLARE @curDisplay     CURSOR  
   DECLARE @nCartLimit     INT  
   DECLARE @nCount         INT  
   DECLARE @cCaseID        NVARCHAR( 20)  
   DECLARE @cPickMethod    NVARCHAR( 10)  
   DECLARE @cCartonType    NVARCHAR( 10)  
   DECLARE @cUDF01         NVARCHAR( 10)  
   DECLARE @cCode          NVARCHAR( 10)  
     
   SELECT @nCartLimit = Short,  
          @cUDF01 = UDF01  
   FROM dbo.CODELKUP WITH (NOLOCK)  
   WHERE LISTNAME = 'TMPICKMTD'  
   AND   Code = @cMethod  
   AND   Storerkey = @cStorerKey  
     
   SET @nCount = 1  
   SET @curDisplay = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
   SELECT DISTINCT TD.CaseID, TD.PickMethod, CL.Code  
   FROM dbo.TaskDetail TD WITH (NOLOCK)  
   JOIN dbo.CODELKUP CL WITH (NOLOCK) ON ( TD.PickMethod = CL.Long)  
   WHERE TD.Storerkey = @cStorerKey  
   AND   TD.TaskType = 'ASTCPK'  
   AND   TD.Status = '3'  
   AND   TD.DeviceID = @cCartID  
   ORDER BY CL.Code  
   OPEN @curDisplay  
   FETCH NEXT FROM @curDisplay INTO @cCaseID, @cPickMethod, @cCode  
   WHILE @@FETCH_STATUS = 0  
   BEGIN  
      IF @cMethod = '4'  
         SELECT @cCartonType = UDF01   
         FROM dbo.CODELKUP WITH (NOLOCK)   
         WHERE LISTNAME = 'TMPICKMTD'   
         AND   Long = @cPickMethod   
         AND   Storerkey = @cStorerKey  
      ELSE  
         SET @cCartonType = @cUDF01  
           
      IF @nCount IN ( 1, 2, 3)  
         SET @cResult01 = @cResult01 + ' ,' + CAST( @nCount AS NVARCHAR( 1)) + '-' + @cCartonType  
  
      IF @nCount IN ( 4, 5, 6)  
         SET @cResult02 = @cResult02 + ' ,' + CAST( @nCount AS NVARCHAR( 1)) + '-' + @cCartonType  
  
      IF @nCount = @nCartLimit  
         BREAK  
      ELSE  
         SET @nCount = @nCount + 1  
  
      FETCH NEXT FROM @curDisplay INTO @cCaseID, @cPickMethod, @cCode  
   END  
  
   SET @cResult01 = CASE WHEN @cResult01 <> '' THEN RIGHT( @cResult01, LEN( @cResult01) - 2) ELSE '' END  
   SET @cResult02 = CASE WHEN @cResult02 <> '' THEN RIGHT( @cResult02, LEN( @cResult02) - 2) ELSE '' END  
  
   --INSERT INTO traceinfo (TraceName, TimeIn, Col1, Col2) VALUES ('123', GETDATE(), @cResult01, @cResult02)  
  
   Quit:  
END  

GO