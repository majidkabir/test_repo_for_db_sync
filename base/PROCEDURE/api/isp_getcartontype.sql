SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO



/******************************************************************************/
/* Store procedure: isp_GetCartonType                                         */
/* Copyright      : LFLogistics                                               */
/*                                                                            */
/* Date         Rev  Author     Purposes                                      */
/* 2020-04-07   1.0  Chermaine  Created                                       */
/* 2021-01-25   1.1  Chermaine  TPS-527 return UseSequence (cc01)             */
/* 2021-09-05   1.2  Chermaine  TPS-11 ErrMsg add to rdtmsg (cc02)            */
/******************************************************************************/

CREATE   PROC [API].[isp_GetCartonType] (
   @json       NVARCHAR( MAX),
   @jResult    NVARCHAR( MAX) OUTPUT,
   @b_Success  INT = 1  OUTPUT,
   @n_Err      INT = 0  OUTPUT,
   @c_ErrMsg   NVARCHAR( 250) = ''  OUTPUT
)
AS

SET NOCOUNT ON
SET QUOTED_IDENTIFIER OFF
SET ANSI_NULLS OFF
SET CONCAT_NULL_YIELDS_NULL OFF

DECLARE
   @cLangCode     NVARCHAR( 3),
   @cUserName      NVARCHAR( 128),
   @cStorerKey    NVARCHAR( 15),
   @cFacility     NVARCHAR( 5),
   @nFunc         INT,
   @cStorerJson   NVARCHAR( 1048)

DECLARE @errMsg TABLE (
   nErrNo    INT,
   cErrMsg   NVARCHAR( 1024)
)

DECLARE @storer TABLE (
   StorerKey     NVARCHAR( 15),
   catchWeight   NVARCHAR( 1),
   catchCube     NVARCHAR( 1)
)


--Decode Json Format
--DECLARE curMsg CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
select @nFunc = Func,@cUserName = UserName,@cLangCode = LangCode, @cStorerJson=Storer
FROM OPENJSON(@json)
WITH (
   Func       nvarchar( 5),
   UserName   nvarchar( 15),
   LangCode   NVARCHAR( 1),
   Storer     nvarchar( max) as json
)

insert INTO @storer
SELECT vs.storerKey, CASE WHEN SC.sValue LIKE '%W%' THEN '1' ELSE 0 END,CASE WHEN SC.sValue LIKE '%C%' THEN '1' ELSE 0 END
FROM OPENJSON(@cStorerJson)
WITH (
   StorerKey   NVARCHAR( 20)    '$.StorerKey'
)vs
LEFT JOIN (SELECT storerKey, svalue FROM dbo.StorerConfig  WITH (NOLOCK) WHERE ConfigKey = 'TPS-captureWeight') SC
ON (vs.StorerKey = SC.storerkey )


--Json Format Output
SET @b_Success = 1
SET @jResult = (
SELECT vs.StorerKey,vs.catchWeight,vs.catchCube ,cartonType,CartonDescription,Barcode,ISNULL(CartonLength,0) AS CartonLength,ISNULL(CartonWidth,0) AS CartonWidth
,ISNULL(CartonHeight,0) AS CartonHeight,ISNULL(MaxWeight,0) AS MaxWeight,CUBE, carton.UseSequence AS UseSequence
FROM @storer vs
JOIN STORER S WITH (NOLOCK)  ON vs.StorerKey = s.StorerKey
JOIN CARTONIZATION Carton WITH (NOLOCK) ON (S.cartonGroup=Carton.CartonizationGroup)
FOR JSON AUTO, INCLUDE_NULL_VALUES)

EXIT_SP:
   REVERT

SET QUOTED_IDENTIFIER OFF

GO