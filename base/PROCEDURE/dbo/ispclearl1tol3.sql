SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Trigger:  ispClearL1toL3                                             */
/* Copyright: LF Logistics                                              */
/*                                                                      */
/* Purpose:  Clear L01, L02, L03 in RDT for user to scan new value and  */
/*           prevent user press ENTER to accept default value           */
/*                                                                      */
/* Date         Author    Ver.  Purposes                                */
/* 13-11-2013   ChewKP    1.1   SOS#294699 Use Codelkup to control      */
/*                              Storer that use this features (ChewKP01)*/
/* 04-08-2-14   Ung       1.2   SOS317591                               */
/* 19-12-2014   CSCHONG   1.3   Add new lottable 06 to 15 (CS01)        */
/* 14-01-2015   CSCHONG   1.4   Add new input parameter (CS02)          */
/************************************************************************/

CREATE PROCEDURE [dbo].[ispClearL1toL3]
   @c_Storerkey        NVARCHAR(15),
   @c_Sku              NVARCHAR(20),
   @c_Lottable01Value  NVARCHAR(18),
   @c_Lottable02Value  NVARCHAR(18),
   @c_Lottable03Value  NVARCHAR(18),
   @dt_Lottable04Value DATETIME,
   @dt_Lottable05Value DATETIME,
   @c_Lottable06Value  NVARCHAR(30) = '',   --(CS01)
   @c_Lottable07Value  NVARCHAR(30) = '',   --(CS01)
   @c_Lottable08Value  NVARCHAR(30) = '',   --(CS01)
   @c_Lottable09Value  NVARCHAR(30) = '',   --(CS01)
   @c_Lottable10Value  NVARCHAR(30) = '',   --(CS01)
   @c_Lottable11Value  NVARCHAR(30) = '',   --(CS01)
   @c_Lottable12Value  NVARCHAR(30) = '',   --(CS01)
   @dt_Lottable13Value DATETIME = NULL,        --(CS01)
   @dt_Lottable14Value DATETIME = NULL,        --(CS01)
   @dt_Lottable15Value DATETIME = NULL,        --(CS01)
   @c_Lottable01       NVARCHAR(18) OUTPUT,
   @c_Lottable02       NVARCHAR(18) OUTPUT,
   @c_Lottable03       NVARCHAR(18) OUTPUT,
   @dt_Lottable04      DATETIME     OUTPUT,
   @dt_Lottable05      DATETIME     OUTPUT,
   @c_Lottable06       NVARCHAR(30) OUTPUT,   --(CS01)
   @c_Lottable07       NVARCHAR(30) OUTPUT,   --(CS01)
   @c_Lottable08       NVARCHAR(30) OUTPUT,   --(CS01)
   @c_Lottable09       NVARCHAR(30) OUTPUT,   --(CS01)
   @c_Lottable10       NVARCHAR(30) OUTPUT,   --(CS01)
   @c_Lottable11       NVARCHAR(30) OUTPUT,   --(CS01)
   @c_Lottable12       NVARCHAR(30) OUTPUT,   --(CS01)
   @dt_Lottable13      DATETIME OUTPUT,      --(CS01)
   @dt_Lottable14      DATETIME OUTPUT,      --(CS01)
   @dt_Lottable15      DATETIME OUTPUT,      --(CS01) 
   @b_Success          INT = 1      OUTPUT,
   @n_Err              INT = 0      OUTPUT,
   @c_Errmsg           NVARCHAR(250) = '' OUTPUT,
   @c_Sourcekey        NVARCHAR(10) = '',
   @c_Sourcetype       NVARCHAR(20) = '',
   @c_LottableLabel    NVARCHAR(20) = '',
   @c_type             NVARCHAR(10) = ''     --(CS02)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   IF @c_Sourcetype = 'RDTRECEIPT'
   BEGIN
      SET @c_Lottable01 = ''
      SET @c_Lottable02 = ''
      SET @c_Lottable03 = ''
   END

END

GO