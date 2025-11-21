SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store procedure: rdt_GENERATEIDGen                                   */
/* Copyright      : Maersk                                              */
/*                                                                      */
/* Purpose: Auto generate ID for codelist GENERATEID                    */
/*                                                                      */
/* Date        Rev    Author          Purposes                          */
/* 2024-09-26  1.0.0  PXL009/LJQ006   FCR-872/FCR-877 Created           */
/************************************************************************/

CREATE   PROCEDURE [rdt].[rdt_GENERATEIDGen]
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

   DECLARE   @cStorerKey            NVARCHAR( 15)
            ,@cCounterKey           NVARCHAR( 18)
            ,@bSuccess              INT
            ,@nSequenceLen          INT
            ,@dMinSequence          INT
            ,@dMaxSequence          INT
            ,@cPrefix               NVARCHAR( 20)
            ,@cSuffix               NVARCHAR( 20)
            ,@cSequenceNo           NVARCHAR( 25)
            ,@cIDType               NVARCHAR( 30)

      SELECT @cStorerKey=storerkey
      FROM rdt.rdtmobrec (NOLOCK)
      WHEre mobile=@nMobile

   IF @nFunc IS NOT NULL
   BEGIN
   
      SET @cIDType = [rdt].[rdtGetConfig](@nFunc, N'GenIDType', @cStorerKey)
      IF @cIDType = N'0'
         SET @cIDType = N''

      IF ISNULL(@cIDType, N'') = N''
      BEGIN
         SET @nErrNo = 224956
         SET @cErrMsg = [rdt].[rdtGetMessage](@nErrNo, @cLangCode, N'DSP') -- No GenIDType Configuration
         GOTO Quit
      END

      SELECT TOP 1
         @cPrefix       = ISNULL([UDF01], N''),
         @cSuffix       = ISNULL([UDF02], N''),
         @nSequenceLen  = CONVERT(INT, [Code2]),
         @dMinSequence  = ISNULL(CONVERT(INT,[UDF03]), 0),
         @dMaxSequence  = ISNULL(CONVERT(INT,[UDF04]), 0)
      FROM [dbo].[CODELKUP] WITH (NOLOCK)
      WHERE [ListName]     = N'GENERATEID'
         AND [Code]        = @cIDType
         AND [Storerkey]   = @cStorerKey
      IF @@ROWCOUNT <> 1
      BEGIN
         SET @nErrNo = 224951
         SET @cErrMsg = [rdt].[rdtGetMessage](@nErrNo, @cLangCode, N'DSP') -- No Codelist Configuration
         GOTO Quit
      END

      IF (@nSequenceLen IS NULL OR @nSequenceLen < 1 )
      BEGIN
         SET @nErrNo = 224952
         SET @cErrMsg = [rdt].[rdtGetMessage](@nErrNo, @cLangCode, N'DSP') -- Code2 (Length of Sequence) Error
         GOTO Quit
      END

      IF @dMaxSequence = 0
         SET @dMaxSequence = CONVERT(INT, REPLICATE('9',@nSequenceLen))

      IF ( @dMaxSequence <= @dMinSequence)
      BEGIN
         SET @nErrNo = 224953
         SET @cErrMsg = [rdt].[rdtGetMessage](@nErrNo, @cLangCode, N'DSP') -- -- UDF03 (Min Sequence)/UDF04(Max Sequence) Error
         GOTO Quit
      END

      SET @cCounterKey = RTRIM(@cIDType) + N'_' + @cStorerKey

      IF EXISTS (
         SELECT 1 FROM [nCounter] (NOLOCK)
         WHERE [KeyName] = @cCounterKey 
            AND ([KeyCount] < @dMinSequence OR [KeyCount] >= @dMaxSequence)
      )
      BEGIN
         DELETE [nCounter]
         WHERE [KeyName] = @cCounterKey
         IF @@ROWCOUNT = 0
         BEGIN
            SET @nErrNo = 224954
            SET @cErrMsg = [rdt].[rdtGetMessage](@nErrNo, @cLangCode, N'DSP') -- Reset NCounter Failed
            GOTO Quit
         END
      END

      IF NOT EXISTS( SELECT 1 FROM [nCounter] (NOLOCK) WHERE [KeyName] = @cCounterKey) AND @dMinSequence > 0
      BEGIN
         INSERT [nCounter]([KeyName], [KeyCount]) VALUES (@cCounterKey, @dMinSequence - 1)
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
         SET @cErrMsg = [rdt].[rdtGetMessage](@nErrNo, @cLangCode, N'DSP') -- Getkey Error
         GOTO Quit
      END

      SET @cAutoID = LTRIM(RTRIM(@cPrefix)) + @cSequenceNo + LTRIM(RTRIM(@cSuffix))
   END

   Quit:
END
GO