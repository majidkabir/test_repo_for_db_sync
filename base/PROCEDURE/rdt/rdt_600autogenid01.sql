SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store procedure: rdt_600AutoGenID01                                  */
/* Copyright      : Maersk                                              */
/*                                                                      */
/* Purpose: Auto generate SSCC                                           */
/*                                                                      */
/* Date        Rev  Author    Purposes                                  */
/* 2024-06-28  1.0  CYU027    UWP-20470 Created                         */
/************************************************************************/

CREATE PROCEDURE rdt.rdt_600AutoGenID01
  @nMobile     INT,           
  @nFunc       INT,           
  @nStep       INT,           
  @cLangCode   NVARCHAR( 3),
  @tExtData    VariableTable READONLY,
  @cAutoID     NVARCHAR( 18) OUTPUT,
  @nErrNo      INT           OUTPUT, 
  @cErrMsg     NVARCHAR( 20) OUTPUT

AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   IF @nFunc = 600
   BEGIN
      DECLARE   @cStorerKey        NVARCHAR(15)
               ,@nCounterKey       NVARCHAR(18)
               ,@cNCounter         NVARCHAR(9)
               ,@bSuccess          INT
               ,@nSequenceLen      INT
               ,@dMinSequence      INT
               ,@dMaxSequence      INT

               /******************** SSCC generation patterns ********************/
               /**   E PPPPPPP RRRRRRRRR C       */
               /** Fixed 00 */
               ,@nCompanyPrefix        NVARCHAR (10)
               /** 1 Extension digit (0-9) +  7 or 9 digit GS1 company Prefix */
               ,@nSerialRef            NVARCHAR (9)
               ,@nCheckDigit           NVARCHAR (1)
               /******************************************************************/

      SELECT @cStorerKey=storerkey
      FROM rdt.rdtmobrec (NOLOCK)
      WHEre mobile=@nMobile

      SELECT TOP 1
         @nCompanyPrefix = ISNULL(code,''),
         @nSequenceLen = convert(INT,code2),
         @dMinSequence = convert(INT,UDF01),
         @dMaxSequence = convert(INT,UDF02)
      FROM CODELKUP WITH (NOLOCK)
      WHERE ListName = 'GENSSCC'
        AND Storerkey = @cStorerKey

      IF @@ROWCOUNT <> 1
      BEGIN
         SET @nErrNo = 218501
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Setup CodeLKUP
         GOTO Quit
      END

      IF ( @nSequenceLen IS NULL OR @nSequenceLen NOT IN (7,9))
         BEGIN
            SET @nErrNo = 218502
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InvalidCode2Value
            GOTO Quit
         END

      IF ( @nCompanyPrefix = '' OR ( LEN(@nCompanyPrefix) <> (17 - @nSequenceLen) ))
      BEGIN
         SET @nErrNo = 218503
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InvalidCodeValue
         GOTO Quit
      END

      IF @dMaxSequence = 0
         SET @dMaxSequence = REPLICATE('9',@nSequenceLen)

      IF (  @dMaxSequence <= @dMinSequence)
      BEGIN
         SET @nErrNo = 218504
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UDF01/UDF02 Error
         GOTO Quit
      END

      SET @nCounterKey = 'SSCC_' + @cStorerKey

--    First init, set counter start from dMinSequence
      IF NOT EXISTS(
         SELECT 1 FROM nCounter (NOLOCK)
         WHERE KeyName = @nCounterKey
      )
      BEGIN
         INSERT nCounter (KeyName, KeyCount) VALUES (@nCounterKey, @dMinSequence)
      END

--    IF keycount is smaller than dMinSequence, Reset key
      ELSE IF EXISTS ( SELECT 1 FROM nCounter (NOLOCK)
                  WHERE KeyName = @nCounterKey
                    AND (KeyCount < @dMinSequence OR KeyCount > @dMaxSequence)
      )
      BEGIN

         UPDATE nCounter WITH (ROWLOCK)
         SET KeyCount = @dMinSequence,
             EditDate = GETDATE()
         WHERE KeyName = @nCounterKey

         IF @@ROWCOUNT = 0
         BEGIN
            SET @nErrNo = 218505
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Reset nCounter failed
            GOTO Quit
         END
      END


      SET @cNCounter = ''
      SET @bSuccess = 1
      EXECUTE dbo.nspg_getkey
              @nCounterKey
            , @nSequenceLen
            , @nSerialRef         OUTPUT
            , @bSuccess          OUTPUT
            , @nErrNo            OUTPUT
            , @cErrMsg           OUTPUT
      IF @bSuccess <> 1
      BEGIN
         SET @nErrNo = 218506
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Getkey Error
         GOTO Quit
      END


      DECLARE @dCurrentDgit numeric(38,0)
      SET @dCurrentDgit = convert( numeric(38,0), @nCompanyPrefix + @nSerialRef)

      EXEC dbo.isp_CheckDigits
           @dCurrentDgit,
           @nCheckDigit OUTPUT


      SET @cAutoID = @nCompanyPrefix + @nSerialRef + @nCheckDigit
   END
   


   Quit:


END


GO