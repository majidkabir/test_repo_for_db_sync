SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store procedure: rdt_AutoGenID                                       */
/* Copyright      : Maersk                                              */
/*                                                                      */
/* Purpose: Auto generate ID                                            */
/*                                                                      */
/* Date        Rev  Author      Purposes                                */
/* 2024-09-26  1.0  LJQ006    FCR-872   Created                         */
/************************************************************************/

CREATE   PROCEDURE [rdt].[rdt_1813AutoGenID01]
   @nMobile     INT, 
   @nFunc       INT, 
   @nStep       INT,
   @cLangCode   NVARCHAR( 3),
   @tExtData    VariableTable READONLY,
   @cAutoID     NVARCHAR( 18)  OUTPUT,
   @nErrNo      INT           OUTPUT, 
   @cErrMsg     NVARCHAR( 20) OUTPUT
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF
   
   IF @nFunc IN (1812, 1813)
   BEGIN
      DECLARE 
         @cStorerKey NVARCHAR(15),
         @cPrefix    NVARCHAR(60), -- UDF01
         @cSuffix    NVARCHAR(60), -- UDF02
         @cSeqStart  NVARCHAR(60), -- UDF03
         @cSeqLast   NVARCHAR(60), -- UDF04
         @nSeqLen    INT,           -- code2 to INT
         @nRowCount  INT,
         @cIDType    NVARCHAR(20)

      SET @cAutoID = ''
      -- release this when debugging
      -- SET @cStorerKey = <STORERKEY>
      SELECT @cStorerKey = StorerKey FROM rdt.RDTMOBREC WITH(NOLOCK) WHERE Mobile = @nMobile;
      -- get IDType from variable table
      SELECT @cIDType = Value FROM @tExtData WHERE Variable = '@cIDType';

      -- get auto-gen-id configure in codelkup
      SELECT TOP 1
         @cPrefix = UDF01, 
         @cSuffix = UDF02, 
         @cSeqStart = UDF03, 
         @cSeqLast = UDF04, 
         @nSeqLen = ISNULL(TRY_CAST(code2 AS INT), 0)
      FROM dbo.CODELKUP WITH(NOLOCK)
      WHERE LISTNAME = 'GENERATEID'
         AND StorerKey = @cStorerKey
         AND Code = @cIDType;

      SET @nRowCount = @@ROWCOUNT

      IF @nRowCount = 0
      BEGIN
         -- no codelkup config
         SET @nErrNo = '225005'
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')
         -- PRINT @cErrMsg
         GOTO Fail
      END

      -- validate if the length of sequence valid
      IF (@nSeqLen <= 0) OR (@nSeqLen > LEN(@cSeqLast))
      BEGIN
         -- invalid sequence length
         SET @nErrNo = '225001'
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')
         -- PRINT @cErrMsg
         GOTO Fail
      END

      -- re-construct seq if not set
      IF TRIM(@cSeqStart) IS NULL OR TRIM(@cSeqStart) = ''
      BEGIN
         SET @cSeqStart = REPLICATE('0', @nSeqLen)
      END

      IF TRIM(@cSeqLast) IS NULL OR TRIM(@cSeqLast) = ''
      BEGIN
         SET @cSeqLast = REPLICATE('9', @nSeqLen)
      END

      -- validate if the sequence is valid
      IF (TRY_CAST(@cSeqStart AS INT) IS NULL) OR (TRY_CAST(@cSeqLast AS INT) IS NULL)
      BEGIN
         -- invalid sequence format
         SET @nErrNo = '225002'
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')
         -- PRINT @cErrMsg
         GOTO Fail
      END

      IF (CAST(@cSeqStart AS INT) > CAST(@cSeqLast AS INT))
      BEGIN
         -- minimium sequence grater than maximium sequence
         SET @nErrNo = '225003'
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')
         -- PRINT @cErrMsg
         GOTO Fail
      END

      DECLARE 
         @nSeqStart INT = CAST(@cSeqStart AS INT),
         @nSeqLast  INT = CAST(@cSeqLast AS INT),
         @nRange    INT,
         @nRangeLen INT

      SET @nRange = @nSeqLast - @nSeqStart + 1
      SET @nRangeLen = LEN(@nRange)

      IF @nRangeLen > 0
      BEGIN
         -- get sequence key 
         DECLARE
            @cKeyName NVARCHAR(18) = @cIDType + '_' + @cStorerKey,
            @nFieldLength INT = @nRangeLen,
            @cSeqValue nvarchar(25) = '',
            @b_success INT = 0

         -- preflight of getkey
         SELECT @cSeqValue = ISNULL(TRY_CAST(keycount AS NVARCHAR(18)), '0')
         FROM dbo.NCOUNTER WITH(NOLOCK)
         WHERE keyname = @cKeyName

         -- check if sequence overflow， stop process
         IF CAST(@cSeqValue AS INT) >= @nRange
         BEGIN
            SET @nErrNo = '225004'
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')
            -- PRINT @cErrMsg
            GOTO Fail
         END

         SET @cSeqValue = ''

         EXEC [dbo].[nspg_GetKey]
            @cKeyName,
            @nFieldLength,
            @cSeqValue OUTPUT,
            @b_success OUTPUT,
            @nErrNo OUTPUT,
            @cErrMsg OUTPUT

         -- check success
         IF @b_success <> 1
         BEGIN
            GOTO Fail
         END
      END

      -- check if sequence reached the range limit
      IF CAST(@cSeqValue AS INT) >= @nRange
      BEGIN
         SET @nErrNo = '225004'
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')
         -- PRINT @cErrMsg
         GOTO Fail
      END

      DECLARE
         @cFinalSeq NVARCHAR(18)

      -- get actual sequence value by adding min sequence and offset
      SET @cSeqValue = CAST((@nSeqStart + @cSeqValue - 1) AS NVARCHAR)
      -- add char '0' to the short number
      SET @cFinalSeq = REPLICATE('0', @nSeqLen - LEN(@cSeqValue)) + @cSeqValue

      IF @cSeqValue <> ''
      BEGIN
         -- AutoID format: <prefix><seq><suffix>
         SET @cAutoID = @cPrefix + @cFinalSeq + @cSuffix
      END

      -- PRINT 'AutoID = ' + @cAutoID
   END
Fail:
END


GO