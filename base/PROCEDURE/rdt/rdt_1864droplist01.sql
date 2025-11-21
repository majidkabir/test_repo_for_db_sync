SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/*********************************************************************************/
/* Store procedure: rdt_1864DropList01                                         */
/* Copyright      : Maersk                                                       */
/*                                                                               */
/* Purpose: DropList Test SP                                                     */
/*                                                                               */
/* Date        Rev  Author      Purposes                                         */
/* 30-10-2024  1.0  Cuize         WMS-23032 Created                                */
/*********************************************************************************/

CREATE   PROCEDURE rdt.rdt_1864DropList01
   @nMobile          INT
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE
      @nFunc         INT,
      @nScn          INT,
      @nStep         INT
      
   DECLARE @tDropDown TABLE
    (
       RowRef INT IDENTITY(1,1),
       ColText   NVARCHAR (125) NULL,
       ColValue  NVARCHAR (125) NULL
    )
   
   --GET SESSION
   SELECT
      @nFunc            = Func,
      @nScn             = Scn,
      @nStep            = Step
   FROM rdt.rdtMobRec WITH (NOLOCK)
      WHERE Mobile = @nMobile

   --Start 
   IF @nFunc = 1864
   BEGIN
      IF @nStep = 1
      BEGIN
         INSERT INTO @tDropDown (coltext, colvalue)
         VALUES
            ('Apple','01'),
            ('Banana','02')
      END
   END
   

Quit:
   
   SELECT coltext, colvalue
   FROM @tDropDown
   
END

GO