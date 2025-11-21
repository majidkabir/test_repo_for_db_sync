SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_701ExtUpdSP01                                   */
/* Purpose: Extended Update for time attendance module                  */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date       Rev  Author     Purposes                                  */
/* 2014-08-14 1.0  James      SOS#317982 Created                        */  
/************************************************************************/

CREATE PROC [RDT].[rdt_701ExtUpdSP01] (
   @nMobile     INT,
   @nFunc       INT, 
   @cLangCode   NVARCHAR( 3), 
   @nStep       INT, 
   @nInputKey   INT, 
   @cStorerKey  NVARCHAR( 15),   
   @cLocation   NVARCHAR( 10),
   @cUserID     NVARCHAR( 18), 
   @cClickCnt   NVARCHAR( 1), 
   @nNextScn    INT           OUTPUT, 
   @nNextStep   INT           OUTPUT,  
   @nErrNo      INT           OUTPUT, 
   @cErrMsg     NVARCHAR( 20) OUTPUT
)
AS

SET NOCOUNT ON
SET QUOTED_IDENTIFIER OFF
SET ANSI_NULLS OFF

   DECLARE @nTranCount     INT 
      
   SET @nTranCount = @@TRANCOUNT

   -- Scan Out Start
   BEGIN TRAN
   SAVE TRAN rdt_701ExtUpdSP01

   IF @nFunc <> 701
      GOTO Quit

   IF @nStep <> 2 OR @nInputKey <> 1
      GOTO Quit

   -- Check if this user+loc clock in b4
   -- Insert WAT record (clock in) if not prev clock in
   IF NOT EXISTS ( SELECT 1 FROM rdt.rdtWatLog WITH (NOLOCK) 
                   WHERE UserName = @cUserID	
                   AND   Location = @cLocation
                   AND   [Status] = '0')
   BEGIN
      INSERT INTO RDT.rdtWATLog (Module, UserName, Location, EndDate, [Status])  
      VALUES ('CLK', @cUserID, @cLocation, '', '0')  
      
      IF @@ERROR <> 0
      BEGIN
         SET @nErrNo = 50451
         GOTO RollBackTran
      END

      -- Check if prev clock in
      IF EXISTS ( SELECT 1 FROM rdt.rdtWatLog WITH (NOLOCK)
                  WHERE UserName = @cUserID	
                  AND   Location <> @cLocation
                  AND   [Status] = '0')
      BEGIN
         UPDATE RDT.rdtWATLog WITH (ROWLOCK)  
         SET STATUS = '9',  
             EndDate = GETDATE()  
         WHERE UserName = @cUserID  
         AND   Location <> @cLocation  
         AND   Status = '0'  

         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 50452
            GOTO RollBackTran
         END
      END
   END
   ELSE
   BEGIN
      -- If prev clock in then now clock out
      UPDATE RDT.rdtWATLog WITH (ROWLOCK)  
      SET STATUS = '9',  
          EndDate = GETDATE()  
      WHERE UserName = @cUserID  
      AND   Location = @cLocation  
      AND   Status = '0'  

      IF @@ERROR <> 0
      BEGIN
         SET @nErrNo = 50453
         GOTO RollBackTran
      END
   END

   IF rdt.RDTGetConfig( @nFunc, 'AutoGoBackScn1', @cStorerKey) = 1
   BEGIN
      -- Go to screen 1
      SET @nNextScn = 704  
      SET @nNextStep = 1  
   END
      
   GOTO Quit
   

   RollBackTran:
   ROLLBACK TRAN rdt_701ExtUpdSP01
   
QUIT:
   WHILE @@TRANCOUNT>@nTranCount -- Commit until the level we started
         COMMIT TRAN rdt_701ExtUpdSP01

GO