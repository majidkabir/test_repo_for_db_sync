SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store procedure: rdt_898ExtUpd06                                     */
/* Copyright      : Maersk                                              */
/*                                                                      */
/* Purpose: Extended Upd for USLevis                                    */
/*                                                                      */
/* Date        Rev  Author      Purposes                                */
/* 27-05-2024  1.0  JACKC       FCR-236 Created                         */
/* 14-06-2024  1.1  JACKC       FCR-236 transmitlog2 requirement change */
/* 27-11-2024  1.2  TLE109      FCR-1128 Finalize close pallet          */
/************************************************************************/

CREATE   PROCEDURE rdt.rdt_898ExtUpd06
    @nMobile     INT
   ,@nFunc       INT
   ,@nStep       INT
   ,@cLangCode   NVARCHAR(  3)
   ,@cReceiptKey NVARCHAR( 10)
   ,@cPOKey      NVARCHAR( 10)
   ,@cLOC        NVARCHAR( 10)
   ,@cToID       NVARCHAR( 18)
   ,@cLottable01 NVARCHAR( 18)
   ,@cLottable02 NVARCHAR( 18)
   ,@cLottable03 NVARCHAR( 18)
   ,@dLottable04 DATETIME
   ,@cUCC        NVARCHAR( 20)
   ,@cSKU        NVARCHAR( 20)
   ,@nQTY        INT
   ,@cParam1     NVARCHAR( 20) OUTPUT
   ,@cParam2     NVARCHAR( 20) OUTPUT
   ,@cParam3     NVARCHAR( 20) OUTPUT
   ,@cParam4     NVARCHAR( 20) OUTPUT
   ,@cParam5     NVARCHAR( 20) OUTPUT
   ,@cOption     NVARCHAR( 1)
   ,@nErrNo      INT       OUTPUT
   ,@cErrMsg     NVARCHAR( 20) OUTPUT
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF
   
   DECLARE  @cStorerKey NVARCHAR( 15)
            

   -- Get Receipt info
   SELECT @cStorerKey = StorerKey
   FROM Receipt WITH (NOLOCK) 
   WHERE ReceiptKey = @cReceiptKey
   
   IF @nFunc = 898
   BEGIN
      IF @nStep = 12 -- Close pallet
      BEGIN
         IF @cToID <> ''
         BEGIN
            IF @cOption IN ('2','3')
            BEGIN
               DECLARE  @b_Success           INT,
                        @cUCCFinalizeClosePallet NVARCHAR( 30)

               SET @cUCCFinalizeClosePallet = rdt.RDTGetConfig( @nFunc, 'UCCFinalizeClosePallet', @cStorerKey) 
               IF @cUCCFinalizeClosePallet = '1'
               BEGIN
                  --Finalize Close Pallet
                  DECLARE @cDOCTYPE NVARCHAR( 2)
                  
                  SELECT
                     @cDOCTYPE = DOCTYPE
                  FROM dbo.RECEIPT WITH(NOLOCK)
                  WHERE ReceiptKey = @cReceiptKey AND StorerKey = @cStorerKey

                  IF @cDOCTYPE = 'A'
                  BEGIN
                     UPDATE dbo.ReceiptDetail WITH (ROWLOCK) SET  
                        QTYReceived = BeforeReceivedQTY,  
                        FinalizeFlag = 'Y',
                        UserDefine02 = '',
                        EditDate = GETDATE(),  
                        EditWho = SUSER_SNAME()    
                     FROM dbo.ReceiptDetail
                     INNER JOIN dbo.UCC WITH(NOLOCK) ON UCC.UCCNo = ReceiptDetail.UserDefine02 AND UCC.StorerKey = ReceiptDetail.StorerKey
                     WHERE ReceiptDetail.StorerKey = @cStorerKey AND ReceiptDetail.ReceiptKey = @cReceiptKey 
                        AND ReceiptDetail.FinalizeFlag = 'N'
                     IF @@ERROR <> 0
                     BEGIN  
                        SET @nErrNo = 215352  
                        SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --215352^Finalize Fail
                        GOTO Quit
                     END

                     -- Send new transmitlog2 per FCR-236 v1.4
                     EXEC ispGenTransmitLog2 
                           @c_TableName      = 'WSRCTPDETLOG', 
                           @c_Key1           = @cReceiptkey,
                           @c_Key2           = @cToID, 
                           @c_Key3           = @cStorerkey, 
                           @c_TransmitBatch  = '', 
                           @b_Success        = @b_Success   OUTPUT,
                           @n_err            = @nErrNo      OUTPUT,
                           @c_errmsg         = @cErrMsg     OUTPUT               

                     IF @b_Success <> 1
                     BEGIN
                        SET @nErrNo = 215351
                        SET @cErrMsg = rdt.rdtGetMessage(@nErrNo, @cLangCode, 'DSP') -- Add TransmitLog2 Fail
                        GOTO Quit
                     END
                  END
               END
               ELSE
               BEGIN
                  -- Send new transmitlog2 per FCR-236 v1.4
                  EXEC ispGenTransmitLog2 
                        @c_TableName      = 'WSRCTPDETLOG', 
                        @c_Key1           = @cReceiptkey,
                        @c_Key2           = @cToID, 
                        @c_Key3           = @cStorerkey, 
                        @c_TransmitBatch  = '', 
                        @b_Success        = @b_Success   OUTPUT,
                        @n_err            = @nErrNo      OUTPUT,
                        @c_errmsg         = @cErrMsg     OUTPUT               

                  IF @b_Success <> 1
                  BEGIN
                     SET @nErrNo = 215351
                     SET @cErrMsg = rdt.rdtGetMessage(@nErrNo, @cLangCode, 'DSP') -- Add TransmitLog2 Fail
                     GOTO Quit
                  END
               END
                        --,@cReceiptLineNumber NVARCHAR(5)
                        --,@cExternPOKey       NVARCHAR(20)
                        --,@cKey2              NVARCHAR(30)
                        --,@cErrFlag           NVARCHAR(1)

               -- Send receiptdetail info to interface
               /*SET @cErrFlag = 0
               DECLARE @curReceiptDetail CURSOR
               SET @curReceiptDetail = CURSOR FAST_FORWARD FOR
                  SELECT ExternPoKey, ReceiptLineNumber FROM RECEIPTDETAIL WITH (NOLOCK) WHERE ReceiptKey = @cReceiptKey AND ToId = @cToID
                  GROUP BY ReceiptKey, ToId, ExternPoKey, ReceiptLineNumber
                  ORDER BY ExternPoKey, ReceiptLineNumber
               OPEN @curReceiptDetail
               FETCH NEXT FROM @curReceiptDetail INTO @cExternPOKey, @cReceiptLineNumber
               WHILE @@FETCH_STATUS = 0
               BEGIN
                  SET @cKey2 = @cExternPOKey + @cReceiptLineNumber
                  -- Insert transmitlog2 here
                  EXEC ispGenTransmitLog2 
                     @c_TableName      = 'WSRCTPDETLOG', 
                     @c_Key1           = @cReceiptkey,
                     @c_Key2           = @cKey2, 
                     @c_Key3           = @cStorerkey, 
                     @c_TransmitBatch  = '', 
                     @b_Success        = @b_Success   OUTPUT,
                     @n_err            = @nErrNo      OUTPUT,
                     @c_errmsg         = @cErrMsg     OUTPUT    
            
                  IF @b_Success <> 1 
                     SET @cErrFlag = 1

                  FETCH NEXT FROM @curReceiptDetail INTO @cExternPOKey, @cReceiptLineNumber
               END -- End cursor */ -- Removed per FCR-236 FBR v1.4 change

            END -- END option
         END -- END ToID not empty
      END -- End step 12
   END -- END 898

QUIT:
END -- End Procedure


GO