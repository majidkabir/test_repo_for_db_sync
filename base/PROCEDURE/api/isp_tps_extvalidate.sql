SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: isp_TPS_ExtValidate                                       */
/* Copyright      : LFLogistics                                               */
/*                                                                            */
/* Date         Rev  Author     Purposes                                      */
/* 2021-09-22   1.0  YeeKung  Created                                         */
/******************************************************************************/

CREATE    PROC [API].[isp_TPS_ExtValidate] (
	@json       NVARCHAR( MAX),
   @jResult    NVARCHAR( MAX) OUTPUT,
   @b_Success  INT = 1        OUTPUT,
   @n_Err      INT = 0        OUTPUT,
   @c_ErrMsg   NVARCHAR( 255) = ''  OUTPUT
)
AS

SET NOCOUNT ON
SET QUOTED_IDENTIFIER OFF
SET ANSI_NULLS OFF
SET CONCAT_NULL_YIELDS_NULL OFF
DECLARE @cStorerKey  NVARCHAR( 15)
DECLARE @cExtValidSP  NVARCHAR( 20)
DECLARE @cSQL        NVARCHAR (MAX)
DECLARE @cSQLParam   NVARCHAR (MAX)

--Decode Json Format
SELECT @cStorerKey = StorerKey
FROM OPENJSON(@json)
WITH (
   StorerKey   NVARCHAR ( 15)
)

   SELECT @cExtValidSP = sValue FROM dbo.StorerConfig WITH (NOLOCK) WHERE StorerKey =@cStorerkey AND configKey = 'TPS-ExtValidSP'

   IF ISNULL(@cExtValidSP,'') <> ''
   BEGIN
      IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtValidSP AND type = 'P')
      BEGIN
         SET @cSQL = 'EXEC API.' + RTRIM( @cExtValidSP) +
            ' @json, @jResult OUTPUT, @b_Success OUTPUT, @n_Err OUTPUT, @c_ErrMsg OUTPUT '
         SET @cSQLParam =
            ' @json          NVARCHAR( MAX),  ' +
            ' @jResult       NVARCHAR( MAX) OUTPUT, ' +
            ' @b_Success     INT = 1        OUTPUT, ' +
            ' @n_Err         INT = 0        OUTPUT, ' +
            ' @c_ErrMsg      NVARCHAR( 255) OUTPUT '

         EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
            @json, @jResult OUTPUT, @b_Success OUTPUT, @n_Err OUTPUT, @c_ErrMsg OUTPUT
      END
   END
   ELSE
   BEGIN
      SET @jResult = @json
      SET @b_Success = 1
   END

GO