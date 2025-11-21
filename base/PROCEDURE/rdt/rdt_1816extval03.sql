SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_1816ExtVal03                                    */
/* Copyright      : Maersk                                              */
/*                                                                      */
/* Purpose: For Levis                                                   */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date         Author    Ver.   Purposes                               */
/* 2025-01-20   Dennis    1.0.0  FCR-1344 Created                       */
/************************************************************************/

CREATE   PROCEDURE rdt.rdt_1816ExtVal03
    @nMobile         INT 
   ,@nFunc           INT 
   ,@cLangCode       NVARCHAR( 3) 
   ,@nStep           INT 
   ,@nInputKey       INT
   ,@cTaskdetailKey  NVARCHAR( 10)
   ,@cFinalLOC       NVARCHAR( 10)
   ,@nErrNo          INT           OUTPUT 
   ,@cErrMsg         NVARCHAR( 20) OUTPUT
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   -- TM assist NMV
   IF @nFunc = 1816
   BEGIN
      IF @nStep = 0 -- init
      BEGIN
         SET @nErrNo = 99
         SET @cErrMsg = 'DennisTests'
      END
   END

Quit:

END

GO