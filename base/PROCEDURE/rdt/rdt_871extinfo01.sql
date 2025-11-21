SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/******************************************************************************/
/* Store procedure: rdt_871ExtInfo01                                          */
/* Purpose: Display total count of serial no to delete                        */
/*                                                                            */
/* Modifications log:                                                         */
/*                                                                            */
/* Date        Rev  Author   Purposes                                         */
/* 2017-Nov-22 1.0  James    WMS2954 Created                                  */
/******************************************************************************/

CREATE PROC [RDT].[rdt_871ExtInfo01] (
   @nMobile      INT,
   @nFunc        INT,
   @cLangCode    NVARCHAR(3),
   @nStep        INT,
   @nInputKey    INT, 
   @cStorerKey   NVARCHAR(15),
   @cSerialNo    NVARCHAR(50),
   @cOption      NVARCHAR(1),
   @cExtendedInfo1   NVARCHAR( 20) OUTPUT
)
AS

SET NOCOUNT ON
SET QUOTED_IDENTIFIER OFF
SET ANSI_NULLS OFF

   DECLARE @nBOM              INT
   DECLARE @nCount            INT
   DECLARE @cNewSerialNo      NVARCHAR( 10)

   SET @nBOM = 0

   SET @cNewSerialNo = RIGHT( @cSerialNo, 10)

   IF RIGHT( RTRIM( @cSerialNo), 1) IN ('B', 'C')
      SET @nBOM = 1

   IF @nStep = 1
   BEGIN
      IF @nInputKey = 1 -- ENTER
      BEGIN
         IF @nBOM = 0
            SET @nCount = 1
         ELSE
            SELECT @nCount = COUNT( DISTINCT SerialNo)
            FROM dbo.MasterSerialNo WITH (NOLOCK)
            WHERE StorerKey = @cStorerKey
            AND   ParentSerialNo = @cNewSerialNo
            AND   UnitType='BUNDLEPCS' 

         SET @cExtendedInfo1 = '#Serial To DEL:' + CAST( @nCount AS NVARCHAR( 5))
      END   -- ENTER
   END   

Quit:



GO