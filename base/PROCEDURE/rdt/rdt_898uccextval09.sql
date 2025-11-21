SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


/***************************************************************************/
/* Store procedure: rdt_898UCCExtVal09                                     */
/* Copyright      : LF Logistics                                           */
/*                                                                         */
/* Purpose: UCC extended validation for USLevis                            */
/*                                                                         */
/* Date        Rev   Author   Purposes                                     */
/* 2024-5-24   1.0   JackC    FCR-236. Created                             */
/* 2024-6-21   1.1   JackC    FCR-236.Upd retrieve UCC logic               */
/* 2024-12-04  1.2   ShaoAn   FCR-1103.Upd Changes in UCC Receive          */
/*                            to process for returns                       */
/***************************************************************************/

CREATE   PROCEDURE [RDT].[rdt_898UCCExtVal09]
    @nMobile     INT
   ,@nFunc       INT
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
   ,@nErrNo      INT           OUTPUT
   ,@cErrMsg     NVARCHAR( 20) OUTPUT
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   IF @nFunc = 898 -- UCC receiving
   BEGIN
      
      DECLARE  @cUSUCCValidation       NVARCHAR (30)
               , @cListName            NVARCHAR (28)
               , @cPrefixLength        VARCHAR (1)
               , @nDelimeterPosition   INT
               , @cStorerKey           NVARCHAR(15)
               , @cSKU                 NVARCHAR(20)
               , @cSKUSUSR1            NVARCHAR(18)
               , @cUCCUDF08            NVARCHAR(30)
               , @cUCCUDF09            NVARCHAR(30)
               , @cDocType             NVARCHAR(1)
               , @nRowCount            INT


      -- Get StorerKey
      SELECT @cStorerKey = StorerKey,@cDocType = DocType FROM Receipt WITH (NOLOCK) WHERE ReceiptKey = @cReceiptKey 


      SET @cUSUCCValidation = rdt.RDTGetConfig( @nFunc, 'USUCCValidation', @cStorerKey)
      IF @cUSUCCValidation = '0'
         SET @cUSUCCValidation = ''

      IF @cUSUCCValidation = ''
         GOTO Quit

      -- Get listname and length of prefix
      SET @nDelimeterPosition = CHARINDEX(',',@cUSUCCValidation)

      IF @nDelimeterPosition <= 1
      BEGIN
         SET @nErrNo = 215301
         SET @cErrMsg = rdt.rdtGetMessage(@nErrNo, @cLangCode, 'DSP') -- Invalid Svalue
         GOTO Quit
      END

      SET @cListName = LEFT(@cUSUCCValidation, @nDelimeterPosition-1)
      SET @cPrefixLength = SUBSTRING(@cUSUCCValidation, @nDelimeterPosition + 1, LEN(@cUSUCCValidation))

      --Validate length of prefix
      IF RDT.rdtIsValidQTY( @cPrefixLength, 0) = 0
      BEGIN
         SET @nErrNo = 215302
         SET @cErrMsg = rdt.rdtGetMessage(@nErrNo, @cLangCode, 'DSP') -- Invalid Prefix Length
         GOTO Quit
      END

      --Verify lentgh of prefix > lentgh of ID
      IF CONVERT(INT, @cPrefixLength) >= LEN(@cToID) OR CONVERT(INT, @cPrefixLength) < 1
      BEGIN
         SET @nErrNo = 215302
         SET @cErrMsg = rdt.rdtGetMessage(@nErrNo, @cLangCode, 'DSP') -- Invalid Prefix Length
         GOTO Quit
      END
      

      -- Verify listname exits in codelkup
      IF NOT EXISTS (SELECT 1 FROM CodeLKUP WITH (NOLOCK) WHERE LISTNAME = @cListName AND Storerkey = @cStorerKey )
      BEGIN
         SET @nErrNo = 215303
         SET @cErrMsg = rdt.rdtGetMessage(@nErrNo, @cLangCode, 'DSP') -- Setup CodeLkup
         GOTO Quit
      END

      --GET SKU
      SELECT @cSKU = SKU
            ,@cUCCUDF08 = ISNULL(Userdefined08,'')
            ,@cUCCUDF09 = ISNULL(Userdefined09,'')
      FROM UCC WITH (NOLOCK) 
      WHERE UCCNo = @cUCC
      --AND ReceiptKey = @cReceiptKey -- remove since no receipt key before receiving

      SET @nRowCount = @@ROWCOUNT

      IF @cDocType = 'R' 
      BEGIN 
         IF EXISTS(SELECT 1 FROM dbo.UCC WITH (NOLOCK) WHERE UCCNo = @cUCC AND Status <>6)
         BEGIN
            SET @nErrNo = 229151
            SET @cErrMsg = rdt.rdtgetmessage( 229151, @cLangCode, 'DSP') --UCC Already Exists
            GOTO Quit
         END
      END
      ELSE
      BEGIN
         IF @nRowCount < 1
         BEGIN
            SET @nErrNo = 215312
            SET @cErrMsg = rdt.rdtGetMessage(@nErrNo, @cLangCode, 'DSP') -- UCC Not Exist
            GOTO Quit
         END
      END

      --GET SKU
      SELECT @cSKUSUSR1 = SUSR1 
      FROM SKU WITH (NOLOCK)
      WHERE StorerKey = @cStorerKey
         AND SKU = @cSKU

      IF @@ROWCOUNT < 1 AND @cDocType <> 'R' 
      BEGIN
         SET @nErrNo = 215304
         SET @cErrMsg = rdt.rdtGetMessage(@nErrNo, @cLangCode, 'DSP') -- SKU NOT EXISTS
         GOTO Quit
      END

      IF @cDocType = 'R' 
         GOTO Quit

      ------------------------------------------------------------------------------------------------------------------------------
      -- Main validation logic
      ------------------------------------------------------------------------------------------------------------------------------
      -- It is a new SKU
      IF ISNULL(@cSKUSUSR1,'')=''
      BEGIN
         UPDATE UCC WITH (ROWLOCK) SET Userdefined09 = 'FAI'
         WHERE UCCNo = @cUCC

         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 215310
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') -- UpdUCCFail
            GOTO Quit
         END

         UPDATE SKU WITH (ROWLOCK) SET SUSR1 = 'PEND'
         WHERE StorerKey = @cStorerKey
         AND SKU = @cSKU 

         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 215311
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') -- UpdSKUFail
            GOTO Quit
         END

         -- FAI required if UDF08=''
         IF @cUCCUDF08 = ''
         BEGIN
            SET @nErrNo = 215305
            SET @cErrMsg = rdt.rdtGetMessage(@nErrNo, @cLangCode, 'DSP') -- FAI Required
            GOTO Quit
         END
         --FAI, QC required if udf08=QC
         IF @cUCCUDF08 = 'QC'
         BEGIN
            SET @nErrNo = 215306
            SET @cErrMsg = rdt.rdtGetMessage(@nErrNo, @cLangCode, 'DSP') -- QC&FAI Required
            GOTO Quit
         END

      END -- END SKUSUSR1 = ''
      ELSE -- Existing SKU
      BEGIN
         IF @cUCCUDF08 = 'QC' AND @cUCCUDF09 = 'FAI' AND NOT EXISTS (SELECT 1 FROM CODELKUP WITH (NOLOCK) 
                                                                     WHERE LISTNAME = @cListName 
                                                                     AND LONG = 'MIX'
                                                                     AND Storerkey = @cStorerKey
                                                                     AND short = SUBSTRING(@cToID, 1, CONVERT(INT, @cPrefixLength))
                                                                     )
         BEGIN
            SET @nErrNo = 215307
            SET @cErrMsg = rdt.rdtGetMessage(@nErrNo, @cLangCode, 'DSP') -- CannotRecvID(QC,FAI)
            GOTO Quit
         END
         ELSE IF @cUCCUDF08 = 'QC' AND @cUCCUDF09 = '' AND NOT EXISTS (SELECT 1 FROM CODELKUP WITH (NOLOCK) 
                                                                        WHERE LISTNAME = @cListName 
                                                                        AND LONG = 'QC'
                                                                        AND Storerkey = @cStorerKey
                                                                        AND short = SUBSTRING(@cToID, 1, CONVERT(INT, @cPrefixLength))
                                                                      )
         BEGIN
            SET @nErrNo = 215308
            SET @cErrMsg = rdt.rdtGetMessage(@nErrNo, @cLangCode, 'DSP') -- CannotRecvID(QC)
            GOTO Quit
         END
         ELSE IF @cUCCUDF08 = '' AND @cUCCUDF09 = 'FAI' AND NOT EXISTS (SELECT 1 FROM CODELKUP WITH (NOLOCK) 
                                                                        WHERE LISTNAME = @cListName 
                                                                        AND LONG = 'FAI'
                                                                        AND Storerkey = @cStorerKey
                                                                        AND short = SUBSTRING(@cToID, 1, CONVERT(INT, @cPrefixLength))
                                                                        )
         BEGIN
            SET @nErrNo = 215309
            SET @cErrMsg = rdt.rdtGetMessage(@nErrNo, @cLangCode, 'DSP') -- CannotRecvID(FAI)
            GOTO Quit
         END
      END -- END existing SKU

   END -- END FUNC=898

   GOTO Quit

Quit:

END

GO