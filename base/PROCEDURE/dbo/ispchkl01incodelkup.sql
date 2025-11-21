SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: ispChkL01InCodelkup                                 */
/* Copyright: LF Logistics                                              */
/* Purpose: Check lottable01 in CodeLKKUP                               */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date         Author    Ver.  Purposes                                */
/* 2013-06-17   Ung       1.0   SOS279908 Created                       */
/************************************************************************/

CREATE PROCEDURE [dbo].[ispChkL01InCodelkup]
   @c_Storerkey        NVARCHAR(15),
   @c_Sku              NVARCHAR(20),
	@c_Lottable01Value  NVARCHAR(18),
	@c_Lottable02Value  NVARCHAR(18),
	@c_Lottable03Value  NVARCHAR(18),
	@dt_Lottable04Value datetime,
	@dt_Lottable05Value datetime,
	@c_Lottable01       NVARCHAR(18) OUTPUT,
	@c_Lottable02       NVARCHAR(18) OUTPUT,
	@c_Lottable03       NVARCHAR(18) OUTPUT,
	@dt_Lottable04      datetime OUTPUT,
   @dt_Lottable05      datetime OUTPUT,
   @b_Success          int = 1  OUTPUT,
   @n_ErrNo            int = 0  OUTPUT,
   @c_Errmsg           NVARCHAR(250) = '' OUTPUT,
   @c_Sourcekey        NVARCHAR(15) = '',  
   @c_Sourcetype       NVARCHAR(20) = '',  
   @c_LottableLabel    NVARCHAR(20) = ''   
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   -- Get lottable01 info
   DECLARE @cUDF02 NVARCHAR(10)
   SET @cUDF02 = ''
   SELECT @cUDF02 = UDF02
   FROM dbo.CodeLkUp WITH (NOLOCK) 
   WHERE ListName = 'LOTTABLE01'  
      AND Code = @c_LottableLabel   
   
   -- UDF02 defined
   IF @cUDF02 <> ''
   BEGIN
      -- UDF02 is listname
      IF EXISTS( SELECT 1 FROM dbo.CodeList WITH (NOLOCK) WHERE ListName = @cUDF02)
      BEGIN
         -- Check L02 value setup in listname
         IF NOT EXISTS( SELECT 1 
            FROM dbo.CodeLkUp WITH (NOLOCK) 
            WHERE ListName = @cUDF02
               AND Code = @c_Lottable01Value
               AND StorerKey = @c_StorerKey)
         BEGIN
            SET @n_ErrNo = 50001
            SET @c_Errmsg = 'Bad Lottable01'
         END
      END
   END
END

GO