SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Trigger: ispGenLot1_TH01                                             */
/* Creation Date: 31-Jan-2012                                           */
/* Copyright: IDS                                                       */
/* Written by: NJOW                                                     */
/*                                                                      */
/* Purpose:  Generate Receiptdetail Lottable01                          */
/*           By Lottable02 refer to Lotattribute (SOS#233957)           */
/*                                                                      */
/* Called By: Receipt Populate From PO (ispLottableRul_Wrapper)         */
/*                                                                      */
/* PVCS Version: 2.0                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author   Ver  Purposes                                  */
/* 07-Mar-2012  NJOW01   1.0  Get the lot from lottattribe.flag='Y'     */
/*                            first                                     */
/* 13-Apr-2012  NJOW02   1.1  241071-Batchno Automatic ExpiryDate       */
/* 24-Jul-2012  NJOW03   1.2  Fix first day of the week to monday       */
/* 11-Jan-2013  YTWan    1.3  SOS#265945: Auto Populate data.(wan01)    */
/* 27-feb-2013  NJOW04   1.4  270366-Skip generate lottable01 if        */
/*                            loc.hostwhcode <> '0001'                  */
/* 01-Apr-2013  Ung      1.5  SOS273757 Support RDT                     */
/*                            change RD.PutawayLOC to RD.ToLOC          */
/* 21-Jun-2013  SPChin   1.6  SOS278355 - Bug Fixed                     */
/* 28-Oct-2013  NJOW05   1.7  293398-TH-Mars-Add condition auto update  */
/*                            lottable01 after finalize receipt         */
/* 29-May-2014  NJOW06   1.8  312264-New lot01 logic for MARS Export    */
/* 24-Jul-2014  NJOW07   1.9  Return lottable01 original value if no    */
/*                            conversion                                */
/* 29-Aug-2014  Leong    2.0  SOS# 319429 - Retrieve Lottable01 from    */
/*                            ReceiptDetail when using RDT.             */
/* 02-Jan-2015  YTWan    2.1  SOS#328865 - TH-MARS EXPORT ASN Finalize  */
/*                            revise to apply Status "X".(Wan02)        */
/* 19-Dec-2014  CSCHONG  2.1   Add new lottable 06 to 15 (CS01)         */
/* 14-Jan-2015  CSCHONG  2.2   Add new input parameter (CS02)           */
/* 26-Feb-2016  NJOW08   2.3   364615-Fix to skip the non-working week  */
/*                             if 1st day is on fri/sat/sun             */
/* 06-Apr-2016  Leong    2.4   SOS367356 - Fix backward year.           */
/************************************************************************/
CREATE PROCEDURE [dbo].[ispGenLot1_TH01]
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
   @dt_Lottable04      DATETIME OUTPUT,
   @dt_Lottable05      DATETIME OUTPUT,
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
   @b_Success          INT = 1  OUTPUT,
   @n_ErrNo            INT = 0  OUTPUT,
   @c_Errmsg           NVARCHAR(250) = '' OUTPUT,
   @c_Sourcekey        NVARCHAR(15) = '',
   @c_Sourcetype       NVARCHAR(20) = '',
   @c_LottableLabel    NVARCHAR(20) = '',
   @c_type             NVARCHAR(10) = ''     --(CS02)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @c_Lottable01Label   NVARCHAR(20),
           @c_Lottable02Label   NVARCHAR(20),
           @c_Lottable03Label   NVARCHAR(20),  --NJOW02
           @c_Lottable04Label   NVARCHAR(20),  --NJOW02
           @c_Doctype           NVARCHAR(1),
           @c_Lottable01_Attr   NVARCHAR(18)

   DECLARE @n_continue     INT,
           @b_debug        INT

   --NJOW02
    DECLARE @c_year         NVARCHAR(4),
           @c_yearlastdigit NVARCHAR(1),
           @dt_tempdate     DATETIME,
           @n_targetweek    INT,
           @c_targetday     NVARCHAR(1),
           @n_skushelflife  INT,
           @c_facility      NVARCHAR(5), --NJOW06
           @n_targetday     INT,
           @c_targetweek    NVARCHAR(2)

   SELECT @n_continue = 1, @b_success = 1, @n_ErrNo = 0, @b_debug = 0

/*
   SELECT @c_Lottable01  = '',
          @c_Lottable02  = '',
          @c_Lottable03  = '',
          @dt_Lottable04 = NULL,
          @dt_Lottable05 = NULL
*/
   IF @c_Sourcetype IN('RECEIPT','RECEIPTFINALIZE','RDTRECEIPT')
   BEGIN
      SELECT @c_Doctype = Doctype,
             @c_Facility = Facility --NJOW05
      FROM RECEIPT (NOLOCK)
      WHERE Receiptkey = LEFT(@c_Sourcekey,10)

      IF @c_Doctype IN('R','X')
         GOTO QUIT
   END
   ELSE
   --(Wan01) - START
   BEGIN
      IF @c_Sourcetype NOT IN ('CCOUNT','RDTCCOUNT')
      BEGIN
         GOTO QUIT
      END
   END
   --(Wan01) - END

   IF @n_continue = 1 OR @n_continue = 2
   BEGIN
      SELECT @c_Lottable01Label = ISNULL(RTRIM(Lottable01Label),''),
             @c_Lottable02Label = ISNULL(RTRIM(Lottable02Label),''),
             @c_Lottable03Label = ISNULL(RTRIM(Lottable03Label),''),  --NJOW02
             @c_Lottable04Label = ISNULL(RTRIM(Lottable04Label),'')   --NJOW02
      FROM SKU (NOLOCK)
        WHERE Storerkey = @c_Storerkey
      AND   SKU = @c_Sku

      IF @c_Lottable01Label = 'PROD_STS' AND @c_Lottable02Label = 'BATCHNO'
         AND @c_Lottable03Label = 'PROD_DATE' AND @c_Lottable04Label = 'EXP_DATE'  --NJOW02
      BEGIN
         SELECT @n_continue = 1
      END
      ELSE
      BEGIN
         SET @n_continue = 3
--         SET @b_Success = 0

         IF @c_Lottable01Label <> 'PROD_STS'
         BEGIN
            SET @n_ErrNo = 31326
            SET @c_Errmsg = CONVERT ( NVARCHAR(5), @n_ErrNo) + ' Invalid Lottable01Label Setup.  (ispGenLot1_TH01)'
         END
         ELSE IF @c_Lottable02Label <> 'BATCHNO'
         BEGIN
            SET @n_ErrNo = 31327
            SET @c_Errmsg = CONVERT ( NVARCHAR(5), @n_ErrNo) + ' Invalid Lottable02Label Setup.  (ispGenLot1_TH01)'
         END
         ELSE IF @c_Lottable03Label <> 'PROD_DATE' --NJOW02
         BEGIN
            SET @n_ErrNo = 31328
            SET @c_Errmsg = CONVERT ( NVARCHAR(5), @n_ErrNo) + ' Invalid Lottable03Label Setup.  (ispGenLot1_TH01)'
         END
         ELSE IF @c_Lottable04Label <> 'EXP_DATE'  --NJOW02
         BEGIN
            SET @n_ErrNo = 31329
            SET @c_Errmsg = CONVERT ( NVARCHAR(5), @n_ErrNo) + ' Invalid Lottable04Label Setup.  (ispGenLot1_TH01)'
         END
         GOTO QUIT
      END
   END

   IF (@n_continue = 1 OR @n_continue = 2) AND @c_SourceType IN ('RDTRECEIPT')
   BEGIN
      IF ISNULL(RTRIM(@c_Lottable01Value),'') = ''-- SOS# 319429
      BEGIN
         SELECT @c_Lottable01Value = Lottable01
         FROM ReceiptDetail WITH (NOLOCK)
         WHERE Receiptkey = SUBSTRING(@c_Sourcekey,1,10)
         AND ReceiptLineNumber = SUBSTRING(@c_Sourcekey,11,5)
         AND Storerkey = @c_Storerkey
         AND Sku = @c_Sku
      END
   END

   IF (@n_continue = 1 OR @n_continue = 2) AND @c_SourceType IN ('RECEIPTFINALIZE','CCOUNT','RDTRECEIPT','RDTCCOUNT')
   BEGIN
       /*
       When Lotattribute.Lottable02 = Receiptdetail.Lottable02
       Scenario   SKU.SUSR5       Lotattribute.Lottable01   POdetail.Lottable01  ASN Populate from PO         Remark
                                                                                                            receiptdetail.lottable01
     1         "EXP-Copack"   S                        X                   S                           Normal
     2         "EXP-Copack"   U                        X                   X                           Special
     3         -              U                        X                   U                           Normal
     4         -              U                        U                   U                           Normal
     5         -              S                        X                   S                           Normal
     6         -              S                        U                   S                           Normal
     7         -              X                        U                   X                           Normal
     8         -              X                        X                   X                           Normal

     EXPORT
                            U                       U                    U
                            X                       U                    U
                            S                       U                    S <--
                            U                       X                    X
                            X                       X                    X
                            S                       X                    S <--
                            U                       S                    S
                            X                       S                    S
                            S                       S                    S
     */

      IF EXISTS (SELECT 1
                 FROM RECEIPTDETAIL RD (NOLOCK)
                 JOIN LOC WITH (NOLOCK) ON RD.ToLoc = LOC.Loc
                 JOIN SKU WITH (NOLOCK) ON RD.Storerkey = SKU.Storerkey AND RD.Sku = SKU.Sku
                 WHERE RD.Receiptkey = LEFT(@c_Sourcekey,10)
                 AND RD.ReceiptLineNumber = SUBSTRING(@c_Sourcekey,11,5)
                 AND LOC.HOSTWHCODE = '0001'
                 AND SKU.SUSR5='POSM')
                 AND @c_Facility <> 'MTH05' --NJOW06 Export
      BEGIN
          --NJOW05
          SET @c_Lottable01 = 'U'
      END
      ELSE
      BEGIN
         IF EXISTS(SELECT 1
                   FROM RECEIPTDETAIL RD (NOLOCK)
                   JOIN LOC WITH (NOLOCK) ON RD.ToLoc = LOC.Loc
                   WHERE RD.Receiptkey = LEFT(@c_Sourcekey,10)
                   AND RD.ReceiptLineNumber = SUBSTRING(@c_Sourcekey,11,5)
                   AND LOC.HOSTWHCODE = '0001')  --NJOW04
         BEGIN
              SELECT TOP 1 LA.Storerkey, LA.Sku, LA.Lottable01, SKU.Susr5, SKU.BUSR5         --(Wan02)
              INTO #TMP_LASTSTATUS
              FROM LOTATTRIBUTE LA (NOLOCK)
              JOIN SKU (NOLOCK) ON (LA.Storerkey = SKU.Storerkey AND LA.Sku = SKU.Sku)
              WHERE LA.Storerkey = @c_Storerkey
              AND LA.Sku = @c_Sku
              AND LA.Lottable02 = @c_Lottable02Value
              AND LA.Flag = 'Y' --SOS278355
              ORDER BY CASE WHEN LA.Flag='Y' THEN 0 ELSE 1 END, LA.Lot DESC   --NJOW01

            IF @c_Facility = 'MTH05' --NJOW06 Export
            BEGIN
                 SELECT @c_Lottable01_Attr = CASE WHEN (Lottable01 = 'S' AND @c_Lottable01Value IN('U','X')) THEN
                                                    Lottable01
                                            --(Wan02) - START
                                                  WHEN (Lottable01 = 'X' AND @c_Lottable01Value = 'U' AND Busr5 = 'QI') THEN
                                                        Lottable01
                                                  WHEN (Lottable01 = 'X' AND @c_Lottable01Value = 'U' AND (Busr5 <> 'QI' OR Busr5 IS NULL )) THEN
                                                        @c_Lottable01Value
                                            --(Wan02) - END
                                                  ELSE
                                                    ''
                                             END
                 FROM #TMP_LASTSTATUS
            END
            ELSE
            BEGIN
                 SELECT @c_Lottable01_Attr = CASE WHEN Susr5 <> 'EXP-COPACK' OR (Susr5 = 'EXP-COPACK' AND Lottable01 <> 'U') THEN
                                                    Lottable01
                                                  ELSE
                                                    ''
                                             END
                 FROM #TMP_LASTSTATUS
              END

            IF ISNULL(@c_Lottable01_Attr,'') <> ''
                 SET @c_Lottable01 = @c_Lottable01_Attr
              ELSE
                 SET @c_Lottable01 = @c_Lottable01Value  --NJOW07
           END
        END

        /*
        SELECT TOP 1 @c_Lottable01_Attr = LA.Lottable01
        FROM LOTATTRIBUTE LA (NOLOCK)
        JOIN SKU (NOLOCK) ON (LA.Storerkey = SKU.Storerkey AND LA.Sku = SKU.Sku)
        WHERE LA.Storerkey = @c_Storerkey
        AND LA.Sku = @c_Sku
        AND LA.Lottable02 = @c_Lottable02Value
        AND SKU.Susr5 <> 'EXP-COPACK'
        ORDER BY LA.Lot DESC

        IF ISNULL(@c_Lottable01_Attr,'') <> ''
           SET @c_Lottable01 = @c_Lottable01_Attr
        ELSE
        BEGIN
          SELECT @c_Lottable01_Attr = LA.Lottable01
           FROM #TMP_LASTSTATUS
           WHERE Susr5 = 'EXP-COPACK'
           AND Lottable01 <> 'U'

          SELECT TOP 1 @c_Lottable01_Attr = LA.Lottable01
          FROM LOTATTRIBUTE LA (NOLOCK)
           JOIN SKU (NOLOCK) ON (LA.Storerkey = SKU.Storerkey AND LA.Sku = SKU.Sku)
           WHERE LA.Storerkey = @c_Storerkey
           AND LA.Sku = @c_Sku
           AND LA.Lottable02 = @c_Lottable02Value
           AND SKU.Susr5 = 'EXP-COPACK'
           AND LA.Lottable01 <> 'U'
           ORDER BY LA.Lot DESC

           IF ISNULL(@c_Lottable01_Attr,'') <> ''
              SET @c_Lottable01 = @c_Lottable01_Attr
         END
         */
   END

   --NJOW01
   IF @n_continue = 1 OR @n_continue = 2 AND @c_SourceType IN('RECEIPT','CCOUNT','RDTRECEIPT','RDTCCOUNT')
   BEGIN
      IF @c_LottableLabel = 'BATCHNO' AND ISNULL(@c_Lottable02Value,'') <> ''
      BEGIN
         SELECT @c_yearlastdigit = LEFT(@c_Lottable02Value,1)
         SELECT @c_targetweek = SUBSTRING(@c_Lottable02Value, 2, 2)
         SELECT @c_targetday = SUBSTRING(@c_Lottable02Value, 4, 1)
         IF ISNUMERIC(@c_yearlastdigit) = 0
         BEGIN
            SET @n_ErrNo = 31330
            SET @c_Errmsg = CONVERT ( NVARCHAR(5), @n_ErrNo) + ' Invalid Lottable02 Value For Year.  (ispGenLot1_TH01)'
            GOTO QUIT
         END

         IF ISNUMERIC(@c_targetweek) = 1
            SELECT @n_targetweek = CONVERT(INT, @c_targetweek )
         ELSE
         BEGIN
            SET @n_ErrNo = 31331
            SET @c_Errmsg = CONVERT ( NVARCHAR(5), @n_ErrNo) + ' Invalid Lottable02 Value For Week.  (ispGenLot1_TH01)'
            GOTO QUIT
         END

         SELECT @n_targetday = CASE
                                 WHEN @c_targetday = 'A'  THEN 1--2  --Mon
                                 WHEN @c_targetday = 'B'  THEN 2--3  --Tue
                                 WHEN @c_targetday = 'C'  THEN 3--4  --Wed
                                 WHEN @c_targetday = 'D'  THEN 4--5  --Thu
                                 WHEN @c_targetday = 'E'  THEN 5--6  --Fri
                                 WHEN @c_targetday = 'F'  THEN 6--7  --Sat
                                 WHEN @c_targetday = 'G'  THEN 7--1  --Sun
                                 ELSE 0
                               END
         IF @n_targetday = 0
         BEGIN
            SET @n_ErrNo = 31332
            SET @c_Errmsg = CONVERT ( NVARCHAR(5), @n_ErrNo) + ' Invalid Lottable02 Value For Day.  (ispGenLot1_TH01)'
            GOTO QUIT
         END


         IF @c_yearlastdigit < RIGHT(DATEPART(year,getdate()),1)  --NJOW08
            -- SELECT @c_year = LTRIM(RTRIM(CAST(CAST(LEFT(DATEPART(year,getdate()),3) AS INT) + 1 AS NVARCHAR))) + @c_yearlastdigit
            SELECT @c_year = LTRIM(RTRIM(CAST(CAST(LEFT(DATEPART(year,getdate()),3) AS INT) AS NVARCHAR))) + @c_yearlastdigit -- SOS367356
         ELSE
            SELECT @c_year = LEFT(DATEPART(year,getdate()),3) + @c_yearlastdigit

         -- Get first date of the year
         SELECT @dt_tempdate = CONVERT(DATETIME, @c_year+'-01-01')

         -- Get first week first day of the year
         --SELECT @dt_tempdate = DATEADD(day, (DATEPART(dw, @dt_tempdate) - 1) * -1, @dt_tempdate)
         IF DATEPART(dw, @dt_tempdate) = 6  --Fri NJOW08
         BEGIN
              SELECT @dt_tempdate = DATEADD(Day, 3 ,@dt_tempdate)
         END
         ELSE IF DATEPART(dw, @dt_tempdate) = 7  --Sat NJOW08
         BEGIN
              SELECT @dt_tempdate = DATEADD(Day, 2 ,@dt_tempdate)
         END
         ELSE IF DATEPART(dw, @dt_tempdate) = 8  --Sun NJOW08
         BEGIN
              SELECT @dt_tempdate = DATEADD(Day, 1 ,@dt_tempdate)
         END
         ELSE
         BEGIN
            SELECT @dt_tempdate = DATEADD(day, (DATEPART(dw, @dt_tempdate) - 2) * -1, @dt_tempdate) --set monday as first day of the week (system is sunday=1)
         END

         -- Get first day of the targeted week
         SELECT @dt_tempdate = DATEADD(week, @n_targetweek - 1, @dt_tempdate)

         -- Get target day of the targed week
         --SELECT @dt_tempdate = DATEADD(day, @n_targetday - DATEPART(dw, @dt_tempdate), @dt_tempdate)
         SELECT @dt_tempdate = DATEADD(day, @n_targetday - 1, @dt_tempdate)

         SELECT @c_Lottable03 = CONVERT(CHAR(10), @dt_tempdate, 103)

         SELECT @n_SKUShelfLife = Shelflife
         FROM SKU(NOLOCK)
         WHERE Storerkey = @c_Storerkey
         AND Sku = @c_Sku

         SELECT @dt_Lottable04 = DATEADD(day, @n_SKUShelflife, @dt_tempdate)

      END
   END

QUIT:
END -- End Procedure


GO