SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store procedure: rdt_1812AutoGenDropID01                             */
/* Copyright      : LF Logistics                                        */
/*                                                                      */
/* Purpose: Auto generate DropID                                        */
/*                                                                      */
/* Date        Rev  Author    Purposes                                  */
/* 2024-09-26  1.0  PXL009    FCR-872 Created                           */
/************************************************************************/

CREATE   PROCEDURE [rdt].[rdt_1812AutoGenDropID01]
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

   DECLARE   @cStorerKey            NVARCHAR(15)
            ,@cCounterKey           NVARCHAR(18)
            ,@bSuccess              INT
            ,@nSequenceLen          INT
            ,@dMinSequence          INT
            ,@dMaxSequence          INT
            ,@cPrefix               NVARCHAR (20)
            ,@cSuffix               NVARCHAR (20)
            ,@cSequenceNo           NVARCHAR (25)
            ,@nCheckDigit           NVARCHAR (1)

      SELECT @cStorerKey=storerkey
      FROM rdt.rdtmobrec (NOLOCK)
      WHEre mobile=@nMobile

   IF @nFunc = 1812
   BEGIN
   
      SELECT TOP 1
         @cPrefix       = ISNULL([UDF01], N''),
         @cSuffix       = ISNULL([UDF02], N''),
         @nSequenceLen  = CONVERT(INT, [Code2]),
         @dMinSequence  = ISNULL(CONVERT(INT,[UDF03]), 0),
         @dMaxSequence  = ISNULL(CONVERT(INT,[UDF04]), 0)
      FROM [CODELKUP] WITH (NOLOCK)
      WHERE [ListName]     = N'GENERATEID'
         AND [Code]        = N'DROPID'
         AND [Storerkey]   = @cStorerKey
      IF @@ROWCOUNT <> 1
      BEGIN
         SET @nErrNo = 224951
         SET @cErrMsg = [rdt].[rdtGetMessage](@nErrNo, @cLangCode, N'DSP')
         GOTO Quit
      END

      IF (@nSequenceLen IS NULL OR @nSequenceLen < 1 )
      BEGIN
         SET @nErrNo = 224952
         SET @cErrMsg = [rdt].[rdtGetMessage](@nErrNo, @cLangCode, N'DSP')
         GOTO Quit
      END

      IF @dMaxSequence = 0
         SET @dMaxSequence = CONVERT(INT, REPLICATE('9',@nSequenceLen))

      IF ( @dMaxSequence <= @dMinSequence)
      BEGIN
         SET @nErrNo = 224953
         SET @cErrMsg = [rdt].[rdtGetMessage](@nErrNo, @cLangCode, N'DSP')
         GOTO Quit
      END

      SET @cCounterKey = N'DROPID_' + @cStorerKey

      IF NOT EXISTS( SELECT 1 FROM [nCounter] (NOLOCK) WHERE [KeyName] = @cCounterKey )
      BEGIN
         INSERT [nCounter]([KeyName], [KeyCount]) VALUES (@cCounterKey, @dMinSequence)
      END
      ELSE IF EXISTS (
         SELECT 1 FROM [nCounter] (NOLOCK)
         WHERE [KeyName] = @cCounterKey 
            AND ([KeyCount] < @dMinSequence OR [KeyCount] >= @dMaxSequence)
      )
      BEGIN
         UPDATE [nCounter] WITH (ROWLOCK)
         SET [KeyCount] = @dMinSequence,
             [EditDate] = GETDATE()
         WHERE [KeyName] = @cCounterKey
         IF @@ROWCOUNT = 0
         BEGIN
            SET @nErrNo = 224954
            SET @cErrMsg = [rdt].[rdtGetMessage](@nErrNo, @cLangCode, N'DSP')
            GOTO Quit
         END
      END

      SET @bSuccess = 1
      EXECUTE [dbo].[nspg_getkey]
              @cCounterKey
            , @nSequenceLen
            , @cSequenceNo       OUTPUT
            , @bSuccess          OUTPUT
            , @nErrNo            OUTPUT
            , @cErrMsg           OUTPUT
      IF @bSuccess <> 1
      BEGIN
         SET @nErrNo = 224955
         SET @cErrMsg = [rdt].[rdtGetMessage](@nErrNo, @cLangCode, N'DSP')
         GOTO Quit
      END

      SET @cAutoID = LTRIM(RTRIM(@cPrefix)) + @cSequenceNo + LTRIM(RTRIM(@cSuffix))

   END

   Quit:
END


GO