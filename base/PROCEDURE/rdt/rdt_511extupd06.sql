SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_511ExtUpd06                                     */
/* Purpose: Trigger iml interface                                       */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date       Rev  Author     Purposes                                  */
/* 2021-12-22 1.0  James      WMS-17576. Created                        */
/************************************************************************/

CREATE PROC [RDT].[rdt_511ExtUpd06] (
   @nMobile        INT,
   @nFunc          INT,
   @cLangCode      NVARCHAR( 3),
   @nStep          INT,
   @nInputKey      INT,
   @cFacility      NVARCHAR( 5),
   @cStorerKey     NVARCHAR( 15),
   @cFromID        NVARCHAR( 18),
   @cFromLOC       NVARCHAR( 10),
   @cToLOC         NVARCHAR( 10),
   @nErrNo         INT           OUTPUT,
   @cErrMsg        NVARCHAR( 20) OUTPUT
)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF

   DECLARE @cTransmitLogKey   NVARCHAR( 10) = ''
   DECLARE @bSuccess          INT = 0
   DECLARE @cLocationType     NVARCHAR( 10)
   DECLARE @cLocationCategory NVARCHAR( 10)

   IF @nFunc = 511 -- Move by ID
   BEGIN
      IF @nStep = 3 -- ToLOC
      BEGIN
         IF EXISTS ( SELECT 1 FROM dbo.CODELKUP WITH (NOLOCK)
                     WHERE LISTNAME = 'AGVDEFLoc'
                     AND   Code = @cFacility
                     AND   Long = @cToLOC
                     AND   Storerkey = @cStorerKey)
         BEGIN
            IF NOT EXISTS ( SELECT 1 FROM dbo.ITRN WITH (NOLOCK)
                              WHERE TranType = 'MV'
                              AND   SourceType = 'rdtfnc_Move_ID'
                              AND   [Status] <> 'OK'
                              AND   ToLoc = @cToLOC)
            BEGIN
               SET @nErrNo = 0
               EXEC [CNDTSITF].[dbo].[isp5926P_WOL_CN_MAST_AGV_REC_ITRN_OUT_Export]
                    @c_DataStream   = '5926'
                  , @c_StorerKey    = @cStorerKey
                  , @b_Debug        = 0
                  , @b_Success      = @bSuccess OUTPUT
                  , @n_Err          = @nErrNo OUTPUT
                  , @c_ErrMsg       = @cErrMsg OUTPUT
                  , @c_TransmitLogKey = @cTransmitLogKey
                  , @c_ToId         = @cFromID

               IF @nErrNo <> 0
                  GOTO Quit
            END
         END
      END
   END

Quit:

END

GO