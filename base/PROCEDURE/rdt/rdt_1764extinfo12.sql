SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_1764ExtInfo12                                   */
/* Copyright      : Maersk                                              */
/* Customer: Levis                                                      */
/*                                                                      */
/* Date         Author     Ver.  Purposes                               */
/* 2024-12-05   JCH507     1.0   FCR-1157 Show UCC St4 for Levis        */
/************************************************************************/

CREATE   PROCEDURE rdt.rdt_1764ExtInfo12
    @nMobile         INT 
   ,@nFunc           INT 
   ,@cLangCode       NVARCHAR( 3) 
   ,@nStep           INT 
   ,@cTaskdetailKey  NVARCHAR( 10) 
   ,@cExtendedInfo1  NVARCHAR( 20) OUTPUT
   ,@nErrNo          INT           OUTPUT 
   ,@cErrMsg         NVARCHAR( 20) OUTPUT
   ,@nAfterStep      INT = 0
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   -- TM Replen From
   IF @nFunc = 1764
   BEGIN
      IF @nAfterStep = 4
      BEGIN
         -- Get TaskDetail info
         SELECT 
            @cExtendedInfo1 = ISNULL(caseid,'')
         FROM dbo.TaskDetail WITH (NOLOCK) 
         WHERE TaskdetailKey = @cTaskdetailKey
      END
   END

Quit:

END

GO