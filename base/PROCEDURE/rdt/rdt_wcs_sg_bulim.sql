SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_WCS_SG_BULIM                                     */
/* Copyright      : LF Logistics                                        */
/*                                                                      */
/* Purpose: Send command to WCS                                         */
/*                                                                      */
/* Date         Author    Ver.  Purposes                                */
/* 2015-03-04   Ung       1.0   SOS256104 Created                       */
/************************************************************************/

CREATE PROCEDURE [RDT].[rdt_WCS_SG_BULIM]
    @nMobile         INT
   ,@nFunc           INT
   ,@cLangCode       NVARCHAR( 3)
   ,@nStep           INT
   ,@cTaskdetailKey  NVARCHAR( 10)
   ,@nErrNo          INT           OUTPUT
   ,@cErrMsg         NVARCHAR( 20) OUTPUT
   ,@cParam01        NVARCHAR( 30) = ''
   ,@cParam02        NVARCHAR( 30) = ''
   ,@cParam03        NVARCHAR( 30) = ''
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @bSuccess     INT
   DECLARE @cStorerKey   NVARCHAR( 15)
   DECLARE @cFromLOC     NVARCHAR( 10)
   DECLARE @cFromID      NVARCHAR( 18)

   -- TM Assist Putaway 
   IF @nFunc = 1815
   BEGIN
      IF @nStep = 1 -- From LOC
      BEGIN
         -- Param mapping
         SET @cFromID = @cParam01
         SET @cFromLOC = @cParam02
         
         -- Build WCS command
         IF @cFromID <> '' AND @cFromLOC <> ''
         BEGIN
            EXEC isp_TCP_WCS_MsgProcess
               @c_MessageName    = 'PUTAWAY'
             , @c_MessageType    = 'SEND'
             , @c_OrigMessageID  = ''
             , @c_PalletID       = @cFromID
             , @c_FromLoc        = @cFromLoc
             , @c_ToLoc          = ''
             , @c_Priority       = ''
             , @c_UD1            = ''
             , @c_UD2            = ''
             , @c_UD3            = ''
             , @c_TaskDetailKey  = @cTaskDetailKey
             , @n_SerialNo       = ''
             , @b_debug          = 0
             , @b_Success        = @bSuccess    OUTPUT
             , @n_Err            = @nErrNo      OUTPUT
             , @c_ErrMsg         = @cErrMsg     OUTPUT

            IF @nErrNo <> 0
               GOTO Fail
         END
      END
   END

   -- Putaway by ID 
   IF @nFunc = 1819
   BEGIN
      IF @nStep = 2 -- To LOC
      BEGIN
         -- Param mapping
         SET @cFromID = @cParam01
         SET @cFromLOC = @cParam02
         
         -- Build WCS command
         IF @cFromID <> '' AND @cFromLOC <> ''
         BEGIN
            EXEC isp_TCP_WCS_MsgProcess
               @c_MessageName    = 'PUTAWAY'
             , @c_MessageType    = 'SEND'
             , @c_OrigMessageID  = ''
             , @c_PalletID       = @cFromID
             , @c_FromLoc        = @cFromLOC
             , @c_ToLoc          = ''
             , @c_Priority       = ''
             , @c_UD1            = ''
             , @c_UD2            = ''
             , @c_UD3            = ''
             , @c_TaskDetailKey  = ''
             , @n_SerialNo       = ''
             , @b_debug          = 0
             , @b_Success        = @bSuccess    OUTPUT
             , @n_Err            = @nErrNo      OUTPUT
             , @c_ErrMsg         = @cErrMsg     OUTPUT

            IF @nErrNo <> 0
               GOTO Fail
         END
      END
   END
Fail:

END

GO