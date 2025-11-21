SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_1762ExtUpd02                                    */
/* Purpose: To close tote after finish putaway so it can be reused      */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date       Rev  Author     Purposes                                  */
/* 2015-03-19 1.0  James      SOS#336649. Created                       */
/************************************************************************/

CREATE PROC [RDT].[rdt_1762ExtUpd02] (
   @nMobile          INT,
   @nFunc            INT, 
   @cLangCode        NVARCHAR( 3), 
   @nStep            INT, 
   @nInputKey        INT, 
   @cTaskdetailKey   NVARCHAR( 10), 
   @nErrNo           INT           OUTPUT, 
   @cErrMsg          NVARCHAR( 20) OUTPUT
)
AS

SET NOCOUNT ON
SET QUOTED_IDENTIFIER OFF
SET ANSI_NULLS OFF

   DECLARE @cCaseID           NVARCHAR( 20) 

   IF @nStep = 3 AND @nInputKey = 1
   BEGIN
      SELECT @cCaseID = CaseID 
      FROM dbo.TaskDetail WITH (NOLOCK) 
      WHERE TaskDetailKey = @cTaskdetailKey
      AND   [Status] = '9'
      
      IF ISNULL( @cCaseID, '') = ''
         GOTO Quit
      ELSE
      BEGIN
         IF EXISTS ( SELECT 1 FROM dbo.DropID WITH (NOLOCK) 
                     WHERE DropID = @cCaseID 
                     And   [Status] < '9') 
         BEGIN
            UPDATE dbo.DropID WITH (ROWLOCK) SET  
               Status = '9'  
            WHERE DropID = @cCaseID  
            AND   [Status] < '9'           

            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 52901
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')  -- TOTE CLOSE ERR
            END
         END
      END
   END
           
   QUIT:

GO