SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_606ExtValid01                                         */
/* Copyright      : LF Logistics                                              */
/*                                                                            */
/* Purpose: Based on custom defined field, check whether it is valid          */
/*                                                                            */
/* Date        Author   Ver.  Purposes                                        */
/* 11-Apr-2019 James    1.0   WMS-8630 Created                                */
/******************************************************************************/

CREATE PROCEDURE [RDT].[rdt_606ExtValid01]
   @nMobile       INT,
   @nFunc         INT,
   @cLangCode     NVARCHAR( 3),
   @nStep         INT,
   @nAfterStep    INT,
   @nInputKey     INT,
   @cFacility     NVARCHAR( 5),
   @cStorerKey    NVARCHAR( 15),
   @tExtValidVar  VariableTable READONLY,
   @nErrNo        INT           OUTPUT,
   @cErrMsg       NVARCHAR( 20) OUTPUT
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @cReturnRegisterField NVARCHAR( 20)

   -- Variable mapping
   SELECT @cReturnRegisterField = ISNULL( Value, '') FROM @tExtValidVar WHERE Variable = '@cReturnRegisterField'

   IF @nStep = 1
   BEGIN
      IF @nInputKey = 1
      BEGIN
        -- Get lookup field data type
         DECLARE @cDataType NVARCHAR(128)
         SET @cDataType = ''
         SELECT @cDataType = DATA_TYPE FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME = 'Receipt' AND COLUMN_NAME = @cReturnRegisterField
         
         IF @cDataType = ''
         BEGIN
            SET @nErrNo = 137601
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Field
            GOTO Quit
         END
         
         -- Check data type
         IF @cDataType <> 'datetime'
         BEGIN
            SET @nErrNo = 137602
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Inv Data Type
            GOTO Quit
         END
      END
   END
   
Quit:  


END

SET QUOTED_IDENTIFIER OFF

GO