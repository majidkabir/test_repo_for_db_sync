SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_606ExtUpd02                                           */
/* Copyright      : LF Logistics                                              */
/*                                                                            */
/* Purpose: Based on custom defined field, update receipt table               */
/*                                                                            */
/* Date        Author   Ver.  Purposes                                        */
/* 17-Mar-2022 yeekung  1.0   WMS-19161 Created                               */
/******************************************************************************/

CREATE PROCEDURE [RDT].[rdt_606ExtUpd02]
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
      @bSuccess             INT,
      @nCtnQty              INT

   -- Variable mapping
   SELECT @cReceiptKey = ISNULL( Value, '') FROM @tExtUpdVar WHERE Variable = '@cReceiptKey'
   SELECT @nQty = ISNULL( Value, 0) FROM @tExtUpdVar WHERE Variable = '@nQty'
   SELECT @cID = ISNULL( Value, '') FROM @tExtUpdVar WHERE Variable = '@cID'
   SELECT @cReturnRegisterField = ISNULL( Value, '') FROM @tExtUpdVar WHERE Variable = '@cReturnRegisterField'
   

   IF @nStep = 1
   BEGIN
      IF @nInputKey = 1
      BEGIN


         IF EXISTS ( SELECT 1 FROM Receipt (NOLOCK)
                     WHERE ReceiptKey = @cReceiptKey
                     AND storerkey=@cStorerKey
                     AND RecType  IN  ('ERTN','ECOM'))
         BEGIN

            SET @cStartSQL = N' UPDATE Receipt WITH (ROWLOCK) SET
                               ASNStatus=''RCVD'', '

            SET @cCustomSQL = @cReturnRegisterField + ' = GETDATE() '

            SET @cEndSQL = N' WHERE ReceiptKey = @cReceiptKey'

            SET @cExecStatements = @cStartSQL + @cCustomSQL + @cEndSQL

            SET @cExecArguments =  N'@cReceiptKey  NVARCHAR( 10)'

            EXEC sp_ExecuteSql @cExecStatements
                              ,@cExecArguments
                              ,@cReceiptKey

            IF @nErrNo <> 0
            BEGIN
               SET @nErrNo = 185051   
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdReceiptFail'  
               GOTO QUIT  
            END

            EXEC dbo.ispGenTransmitLog3   
               @c_TableName      = 'RCVDRDTLOG',   
               @c_Key1           = @cReceiptKey,   
               @c_Key2           = '' ,   
               @c_Key3           = @cStorerKey,   
               @c_TransmitBatch  = '',   
               @b_success        = @bSuccess    OUTPUT,   
               @n_err            = @nErrNo      OUTPUT,   
               @c_errmsg         = @cErrMsg     OUTPUT 
  
            IF @bSuccess <> 1  
            BEGIN  
               SET @nErrNo = 185052  
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'nspGetRightErr'  
               GOTO QUIT  
            End  
         END
         ELSE
         BEGIN
            UPDATE RECEIPT WITH (ROWLOCK)
            SET UserDefine06=GETDATE(),
                 ContainerQty=@nQty
            WHERE ReceiptKey = @cReceiptKey

           IF @nErrNo <> 0
            BEGIN
               SET @nErrNo = 185053   
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdReceiptFail'  
               GOTO QUIT  
            END

         END
      END
   END

Quit:  


END

SET QUOTED_IDENTIFIER OFF

GO