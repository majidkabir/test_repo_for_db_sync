SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_606ExtUpd01                                           */
/* Copyright      : LF Logistics                                              */
/*                                                                            */
/* Purpose: Based on custom defined field, update receipt table               */
/*                                                                            */
/* Date        Author      Ver.  Purposes                                     */
/* 11-Apr-2019 James       1.0   WMS-8630 Created                             */
/* 16-Dec-2020 Chermaine   1.1   WMS-15858 Add Config to update status (cc01) */
/******************************************************************************/

CREATE   PROCEDURE [RDT].[rdt_606ExtUpd01]
   @nMobile       INT,
   @nFunc         INT,
   @cLangCode     NVARCHAR( 3),
   @nStep         INT,
   @nAfterStep    INT,
   @nInputKey     INT,
   @cFacility     NVARCHAR( 5),
   @cStorerKey    NVARCHAR( 15),
   @tExtUpdVar    VariableTable READONLY,
   @nErrNo        INT           OUTPUT,
   @cErrMsg       NVARCHAR( 20) OUTPUT
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE
      @cStartSQL            NVARCHAR( 1000),
      @cCustomSQL           NVARCHAR( 1000),
      @cEndSQL              NVARCHAR( 1000),
      @cExecStatements      NVARCHAR( MAX),
      @cExecArguments       NVARCHAR( MAX),
      @cReceiptKey          NVARCHAR( 10),
      @cID                  NVARCHAR( 18),
      @cReturnRegisterField NVARCHAR( 20),
      @nQty                 INT,        
      @cCaptureStatus       NVARCHAR( 1)

   -- Variable mapping
   SELECT @cReceiptKey = ISNULL( Value, '') FROM @tExtUpdVar WHERE Variable = '@cReceiptKey'
   SELECT @nQty = ISNULL( Value, 0) FROM @tExtUpdVar WHERE Variable = '@nQty'
   SELECT @cID = ISNULL( Value, '') FROM @tExtUpdVar WHERE Variable = '@cID'
   SELECT @cReturnRegisterField = ISNULL( Value, '') FROM @tExtUpdVar WHERE Variable = '@cReturnRegisterField'
   
   SET @cCaptureStatus = rdt.RDTGetConfig( @nFunc, 'CaptureStatus', @cStorerKey) --(cc01)
   

   IF @nStep = 1
   BEGIN
      IF @nInputKey = 1
      BEGIN
         SET @cStartSQL = N' UPDATE Receipt SET
                               ContainerQTY = @nQTY, '
         
         --(cc01)
         IF @cCaptureStatus = 1
         BEGIN
            SET @cCustomSQL = @cReturnRegisterField + ' = GETDATE() ' +
                              ', ASNStatus = ''RCVD'' ' 
         END
         ELSE
         BEGIN
         	SET @cCustomSQL = @cReturnRegisterField + ' = GETDATE() '
         END
         

         SET @cEndSQL = N' WHERE ReceiptKey = @cReceiptKey'

         SET @cExecStatements = @cStartSQL + @cCustomSQL + @cEndSQL

         SET @cExecArguments =  N'@cReceiptKey  NVARCHAR( 10), ' +
                                 '@nQTY         INT ' 

         EXEC sp_ExecuteSql @cExecStatements
                           ,@cExecArguments
                           ,@cReceiptKey
                           ,@nQTY

         SET @nErrNo = @@ERROR

         IF @nErrNo <> 0
            GOTO Quit
      END
   END

   IF @nStep = 2
   BEGIN
      IF @nInputKey = 1
      BEGIN
         SET @cStartSQL = N' UPDATE Receipt SET
                               ContainerQTY = @nQTY, 
                               UserDefine02 = @cID, '

         --(cc01)
         IF @cCaptureStatus = 1
         BEGIN
            SET @cCustomSQL = @cReturnRegisterField + ' = GETDATE() ' +
                              ', ASNStatus = ''RCVD'' ' 
         END
         ELSE
         BEGIN
         	SET @cCustomSQL = @cReturnRegisterField + ' = GETDATE() '
         END

         --SET @cCustomSQL = @cReturnRegisterField + ' = GETDATE() '

         SET @cEndSQL = N' WHERE ReceiptKey = @cReceiptKey'

         SET @cExecStatements = @cStartSQL + @cCustomSQL + @cEndSQL

         SET @cExecArguments =  N'@cReceiptKey  NVARCHAR( 10), ' +
                                 '@nQTY         INT, ' +
                                 '@cID          NVARCHAR( 18)'

         EXEC sp_ExecuteSql @cExecStatements
                           ,@cExecArguments
                           ,@cReceiptKey
                           ,@nQTY
                           ,@cID

         SET @nErrNo = @@ERROR

         IF @nErrNo <> 0
            GOTO Quit
      END
   END
   
Quit:  


END

SET QUOTED_IDENTIFIER OFF

GO