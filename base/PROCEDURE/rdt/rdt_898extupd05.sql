SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store procedure: rdt_898ExtUpd05                                     */
/* Copyright      : IDS                                                 */
/*                                                                      */
/* Purpose: Check UCC scan to ID have same SKU, QTY, L02                */
/*                                                                      */
/* Called from:                                                         */
/*                                                                      */
/* Exceed version: 5.4                                                  */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date        Rev  Author      Purposes                                */
/* 20-05-2022  1.0  yeekung     WMS-19671 Created                       */
/************************************************************************/

CREATE PROCEDURE [RDT].[rdt_898ExtUpd05]
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

   DECLARE @b_Success INT

   -- Get Receipt info
   DECLARE @cStorerKey NVARCHAR( 15)
   SELECT @cStorerKey = StorerKey
   FROM Receipt WITH (NOLOCK) 
   WHERE ReceiptKey = @cReceiptKey
   
   IF @nStep = 9 -- Add UCC. QTY screen
   BEGIN
      -- Default Param1 = UDF03, if RD only have 1 UDF03 value
      IF (SELECT COUNT( DISTINCT UserDefine03) 
         FROM dbo.ReceiptDetail WITH (NOLOCK) 
         WHERE ReceiptKey = @cReceiptKey
            AND SKU = @cSKU
            AND UserDefine03 <> '') = 1
      BEGIN
         SELECT TOP 1 @cParam1 = LEFT( UserDefine03, 20)
         FROM dbo.ReceiptDetail WITH (NOLOCK) 
         WHERE ReceiptKey = @cReceiptKey
            AND SKU = @cSKU
            AND UserDefine03 <> ''
      END
   END

   IF @nStep = 10 -- Param1..5
   BEGIN
      IF @cParam1 = '' -- UCC.UserDefined03      
      BEGIN
         SET @nErrNo = 186851
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need CustPO
         GOTO Quit
      END

      -- Get ReceiptDetail info
      IF NOT EXISTS( SELECT TOP 1 1 
         FROM dbo.ReceiptDetail WITH (NOLOCK) 
         WHERE ReceiptKey = @cReceiptKey
            AND RTRIM( UserDefine03) = @cParam1)
      BEGIN
         SET @nErrNo = 186852
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --CustPONotFound
         GOTO Quit
      END

      -- Insert new UCC
      IF NOT EXISTS( SELECT 1 FROM dbo.UCC WITH (NOLOCK) WHERE UCCNo = @cUCC AND StorerKey = @cStorerKey)
      BEGIN
         INSERT INTO dbo.UCC (StorerKey, UCCNo, Status, SKU, QTY, LOC, ID, ExternKey, UserDefined03)
         VALUES (@cStorerKey, @cUCC, '0', @cSKU, @nQTY, @cLOC, @cToID, '', @cParam1)
         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 186853
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --INS UCC fail
            GOTO Quit
         END
      END
   END

   IF @nStep = 12 -- Close pallet
   BEGIN
      IF @cToID <> ''
      BEGIN

         IF EXISTS (SELECT 1 FROM DROPID (NOLOCK)
                     WHERE STATUS in (0,9)
                     and dropid=@ctoID)
         BEGIN
            UPDATE DROPID WITH (ROWLOCK)
            SET status=9
            WHERE STATUS = 0
               and dropid=@ctoID

            IF @@ERROR <> 0
            BEGIN
               SET @nErrno=186855 
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')
               GOTO QUIT
            END   
         END
         ELSE 
         BEGIN 
            INSERT INTO DROPID( dropid,droploc,status)
            VALUES(@cToID,@cLOC,'9')

            IF @@ERROR <> 0
            BEGIN
               SET @nErrno=186854 
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')
               GOTO QUIT
            END
         END

         DECLARE @cReceiptLineNumber NVARCHAR(5)
         -- Loop ReceiptDetail of pallet
         DECLARE @curRD CURSOR
         SET @curRD = CURSOR FOR 
                 
            SELECT RD.ReceiptLineNumber--, RD.ToLOC, RD.SKU
            FROM dbo.ReceiptDetail RD WITH (NOLOCK) 
            INNER JOIN dbo.Receipt R WITH (NOLOCK) ON R.ReceiptKey = RD.ReceiptKey AND R.StorerKey = RD.StorerKey 
            WHERE RD.ToID = @cToID 
               AND RD.FinalizeFlag <> 'Y'
               AND RD.BeforeReceivedQty > 0 
               AND R.StorerKey = @cStorerKey
               AND R.ReceiptKey = @cReceiptKey 
            ORDER BY RD.ReceiptKey, RD.ReceiptLineNumber
         OPEN @curRD
         FETCH NEXT FROM @curRD INTO @cReceiptLineNumber
         WHILE @@FETCH_STATUS = 0
         BEGIN
                 
            EXEC dbo.ispFinalizeReceipt    
            @c_ReceiptKey        = @cReceiptKey    
            ,@b_Success           = @b_Success  OUTPUT    
            ,@n_err               = @nErrNo     OUTPUT    
            ,@c_ErrMsg            = @cErrMsg    OUTPUT    
            ,@c_ReceiptLineNumber = @cReceiptLineNumber    
            
            IF @nErrNo <> 0
            BEGIN
               -- SET @nErrNo = 109401
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- FinalizeRDFail
               GOTO QUIT
            END


            FETCH NEXT FROM @curRD INTO  @cReceiptLineNumber
         END

         IF @cLOC='RBSTG'
         BEGIN
            -- Insert transmitlog2 here
            EXEC ispGenTransmitLog2 
               @c_TableName      = 'WOLRCPCFMGK', 
               @c_Key1           = @cReceiptkey,
               @c_Key2           = @cToID, 
               @c_Key3           = @cStorerkey, 
               @c_TransmitBatch  = '', 
               @b_Success        = @b_Success   OUTPUT,
               @n_err            = @nErrNo      OUTPUT,
               @c_errmsg         = @cErrMsg     OUTPUT    
      
            IF @b_Success <> 1 
               GOTO QUIT
         END


      END
   END

QUIT:
END -- End Procedure


GO