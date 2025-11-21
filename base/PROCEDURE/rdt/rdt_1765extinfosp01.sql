SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
  
/************************************************************************/  
/* Store procedure: rdt_1765ExtInfoSP01                                 */  
/* Purpose: Extended info                                               */  
/*                                                                      */  
/* Modifications log:                                                   */  
/*                                                                      */  
/* Date         Author    Ver.  Purposes                                */  
/* 2014-06-26   ChewKP    1.0   Created                                 */  
/************************************************************************/  
  
CREATE PROCEDURE [RDT].[rdt_1765ExtInfoSP01]  
    @nMobile         INT   
   ,@nFunc           INT   
   ,@cLangCode       NVARCHAR( 3)   
   ,@nStep           INT   
   ,@cTaskdetailKey  NVARCHAR( 10)   
   ,@cExtendedLabel  NVARCHAR( 20) = '' OUTPUT  
   ,@cExtendedInfo1  NVARCHAR( 20) = '' OUTPUT  
   ,@cExtendedInfo2  NVARCHAR( 20) = '' OUTPUT 
   ,@nErrNo          INT           OUTPUT   
   ,@cErrMsg         NVARCHAR( 20) OUTPUT  
   ,@nAfterStep      INT = 0  
AS  
BEGIN  
   SET NOCOUNT ON  
   SET QUOTED_IDENTIFIER OFF  
   SET ANSI_NULLS OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  
  
   DECLARE @nQTY   INT  
   DECLARE @cUCCNo NVARCHAR(20)  
   DECLARE @cCaseID        NVARCHAR( 20)  
          ,@cListKey       NVARCHAR( 10)
          ,@cSourceKey     NVARCHAR( 30)
          ,@cTransferKey   NVARCHAR( 10)
          ,@cTrasferLineNumber NVARCHAR(5)
          ,@cToLoc         NVARCHAR( 10)
          ,@nCaseCount     INT
          ,@cUserName      NVARCHAR( 18) 
          ,@cFromID        NVARCHAR( 18) 
  
   -- TM Replen From  
   IF @nFunc = 1765  
   BEGIN  
      
      IF @nStep = 2 
      BEGIN
         
         SET @cExtendedLabel = 'Suggested SKU:'
         SET @cExtendedInfo1 = ''
         SET @nCaseCount     = 0 
         SET @cToLoc         = ''
         SET @cFromID        = ''
         
         SELECT @cExtendedInfo1 = SKU 
               ,@cToLoc         = ToLoc
               ,@cFromID        = FromID
               ,@cUserName      = UserKey
         FROM dbo.TaskDetail WITH (NOLOCK) 
         WHERE TaskDetailKey = @cTaskDetailKey
         
         SELECT @nCaseCount = Count(Distinct TaskDetailKey) 
         FROM dbo.TaskDetail WITH (NOLOCK) 
         WHERE FromID = @cFromID
         AND ToLoc = @cToLoc
         AND UserKey = @cUserName
         AND Status = '3'
         
         SET @cExtendedInfo2 = 'CASE Count: ' + CAST ( @nCaseCount AS NVARCHAR(5) ) 
         
         
         
      END
--      
--      -- Get TransferKey
--      SELECT @cListKey = ListKey
--      FROM dbo.TaskDetail WITH (NOLOCK)
--      WHERE TaskDetailKey = @cTaskDetailKey
--   
--      SELECT @cSourceKey = SourceKey
--      FROM dbo.TaskDetail WITH (NOLOCK)
--      WHERE ListKey = @cListKey
--      AND TaskType = 'RPF'
--      --AND CaseID   = @c_LabelNo
--   
--      SET @cTransferKey       = Substring(@cSourceKey , 1 , 10) 
--      SET @cTrasferLineNumber = Substring(@cSourceKey , 11 , 15 ) 
--      
--      IF @nAfterStep = 4 -- SKU, QTY screen  
--      BEGIN  
--         -- Get UCC on task not yet pick  
--         SELECT TOP 1   
--            --@nQTY = UCC.QTY,   
--            @cUCCNo = TDD.UserDefine01   
--         FROM dbo.TransferDetail TDD WITH (NOLOCK)  
--            JOIN dbo.UCC UCC WITH (NOLOCK) ON (TDD.UserDefine01 = UCC.UCCNo)  
--         WHERE TDD.TransferKey = @cTransferKey
--            --AND TDD.TransferLineNumber = @cTranferLineNumber
--            AND TDD.Status = '0'  
--         ORDER BY TDD.TransferKey ,TDD.TransferLineNumber
--  
--         IF @@ROWCOUNT = 1   
--            --SET @cExtendedInfo1 = RIGHT( RTRIM( @cUCCNo) + '--' + RTRIM(CAST( @nQTY AS NVARCHAR(5))), 20)  
--            SET @cExtendedInfo1 = @cUCCNo
--            
--      END  
      
      
   END  
END  

GO