SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO



/******************************************************************************/
/* Store procedure: isp_ExtInfoVas01                                          */
/* Copyright      : LFLogistics                                               */
/*                                                                            */
/* Date         Rev  Author     Purposes                                      */
/* 2020-06-26   1.0  Chermaine  Created                                       */
/******************************************************************************/

CREATE   PROC [API].[isp_ExtInfoVas01] (
   @cStorerKey    NVARCHAR( 15),
   @cOrderKey     NVARCHAR( 10),
   @b_Success     INT = 1  OUTPUT,
   @n_Err         INT = 0  OUTPUT,
   @c_ErrMsg      NVARCHAR( 255) = ''  OUTPUT,
   @cNotes        NVARCHAR( 4000) = ''  OUTPUT,
   @cLong         NVARCHAR( 250) = ''  OUTPUT
)
AS

SET NOCOUNT ON
SET QUOTED_IDENTIFIER OFF
SET ANSI_NULLS OFF
SET CONCAT_NULL_YIELDS_NULL OFF


SELECT @cLong = ISNULL(C.long,''), @cNotes = ISNULL(C.NOTES,'')
FROM ORDERS O WITH (NOLOCK)
JOIN CODELKUP C WITH (NOLOCK) ON (O.C_ISOCntryCode = C.CODE)
WHERE C.ListName ='ISOCOUNTRY'
AND O.OrderKey = @cOrderKey
AND o.StorerKey = @cStorerKey


SET QUOTED_IDENTIFIER OFF

GO