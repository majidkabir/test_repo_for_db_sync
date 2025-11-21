SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/*****************************************************************************/
/* Store procedure: rdt_514ExtUpdSP03                                        */
/* Copyright: LFLogistics                                                    */
/*                                                                           */
/* Purpose: Update ID.UDF01 From input TOID first 7 char                     */
/*                                                                           */
/* Called from: rdtfnc_Move_UCC                                              */
/*                                                                           */
/* Date        Rev     Author   Purposes                                     */
/* 2024-10-25  1.0     ShaoAn   FCR-759-1001 saved first 7 char to ID.UDF01  */
/* 2024-10-25  1.0.1   ShaoAn   Add check before update udf01                */
/*****************************************************************************/

CREATE   PROC [rdt].[rdt_514ExtUpdSP03] (
   @nMobile        INT, 
   @nFunc          INT, 
   @cLangCode      NVARCHAR( 3),  
   @nStep          INT, 
   @nInputKey      INT, 
   @cStorerKey     NVARCHAR( 15), 
   @cToID          NVARCHAR( 18), 
   @cToLoc         NVARCHAR( 10), 
   @cFromLoc       NVARCHAR( 10), 
   @cFromID        NVARCHAR( 18), 
   @cUCC1          NVARCHAR( 20), 
   @cUCC2          NVARCHAR( 20), 
   @cUCC3          NVARCHAR( 20), 
   @cUCC4          NVARCHAR( 20), 
   @cUCC5          NVARCHAR( 20), 
   @cUCC6          NVARCHAR( 20), 
   @cUCC7          NVARCHAR( 20), 
   @cUCC8          NVARCHAR( 20), 
   @cUCC9          NVARCHAR( 20), 
   @cUDF01         NVARCHAR( 30), 
   @nErrNo         INT           OUTPUT,  
   @cErrMsg        NVARCHAR( 20) OUTPUT
) AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @nTranCount INT

   SET @nTranCount = @@TRANCOUNT
   BEGIN TRAN
   IF @nStep = 2
   BEGIN
      IF @nInputKey = 1 -- ENTER
      BEGIN
         IF EXISTS(SELECT 1 FROM dbo.loc where LoseId = '1' AND LOC = @cToLoc)
         BEGIN
            GOTO Quit
         END

         SET @cUDF01 = ISNULL(@cUDF01, '')
         IF @cUDF01 <> ''  
            UPDATE dbo.ID WITH (ROWLOCK) SET
                  UserDefine01 = @cUDF01
            WHERE Id = @cToID
      END
   END
   Quit:
      WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
         COMMIT TRAN   
END


GO