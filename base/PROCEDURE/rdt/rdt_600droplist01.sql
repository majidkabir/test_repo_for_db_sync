SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/*********************************************************************************/
/* Store procedure: rdt_600DropList01                                            */
/* Copyright      : Maersk                                                       */
/*                                                                               */
/* Purpose: DropList Test SP                                                     */
/*                                                                               */
/* Date        Rev  Author      Purposes                                         */
/* 2025-01-09  1.0  CYU027    UWP-26488 Add Type List                           */
/*********************************************************************************/

CREATE   PROCEDURE rdt.rdt_600DropList01
@nMobile          INT
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE
      @nFunc         INT,
      @nStep         INT,
      @cStorerKey   NVARCHAR( 15)

   DECLARE   @tDropDown TABLE
      (
         RowRef INT IDENTITY(1,1),
         ColText   NVARCHAR (125) NULL,
         ColValue  NVARCHAR (125) NULL,
         Selected  BIT
      )

   --GET SESSION
   SELECT
      @nFunc            = Func,
      @cStorerKey       = V_StorerKey,
      @nStep            = Step
   FROM rdt.rdtMobRec WITH (NOLOCK)
   WHERE Mobile = @nMobile

   --Start
   IF @nFunc = 600
   BEGIN
      IF @nStep = 6
      BEGIN

         INSERT INTO @tDropDown (coltext, colvalue, Selected)
         SELECT Description,
                Code,
                CASE WHEN ISNULL(Notes,'') = 'TRUE'
                   THEN 1
                   ELSE 0 END
         FROM dbo.CODELKUP WITH (NOLOCK)
         WHERE Storerkey     = @cStorerKey
           AND LISTNAME     = 'ASNREASON'
         ORDER BY Short

      END
      GOTO Quit
   END


   Quit:

   SELECT coltext, colvalue, Selected
   FROM @tDropDown

END

GO