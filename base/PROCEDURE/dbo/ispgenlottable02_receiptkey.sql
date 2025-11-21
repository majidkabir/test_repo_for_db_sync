SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* SP:  ispGenLottable02_ReceiptKey                                     */
/* Copyright: IDS                                                       */
/*                                                                      */
/* Purpose:  Default ReceiptKey to Lottable02                           */
/*                                                                      */
/* Version: 1.2                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Who      Purpose                                        */
/* 08-Apr-2009  Shong    SOS133226                                      */
/* 20-May-2010  Vanessa  SOS171763 TradeReturn diff way gen Lot02.      */
/*                                 (Vanessa01)                          */
/* 25-Jun-2010  Leong    Bug fix for SOS171763 (Leong01)                */
/* 05-May-2014  NJOW01   310313-Able to run from Finalize ASN           */
/* 21-May-2014  TKLIM    Added Lottables 06-15                          */
/************************************************************************/

CREATE PROCEDURE [dbo].[ispGenLottable02_ReceiptKey]
     @c_Storerkey          NVARCHAR(15)
   , @c_Sku                NVARCHAR(20)
   , @c_Lottable01Value    NVARCHAR(18)
   , @c_Lottable02Value    NVARCHAR(18)
   , @c_Lottable03Value    NVARCHAR(18)
   , @dt_Lottable04Value   DATETIME
   , @dt_Lottable05Value   DATETIME
   , @c_Lottable06Value    NVARCHAR(30)   = ''
   , @c_Lottable07Value    NVARCHAR(30)   = ''
   , @c_Lottable08Value    NVARCHAR(30)   = ''
   , @c_Lottable09Value    NVARCHAR(30)   = ''
   , @c_Lottable10Value    NVARCHAR(30)   = ''
   , @c_Lottable11Value    NVARCHAR(30)   = ''
   , @c_Lottable12Value    NVARCHAR(30)   = ''
   , @dt_Lottable13Value   DATETIME       = NULL
   , @dt_Lottable14Value   DATETIME       = NULL
   , @dt_Lottable15Value   DATETIME       = NULL
   , @c_Lottable01         NVARCHAR(18)            OUTPUT
   , @c_Lottable02         NVARCHAR(18)            OUTPUT
   , @c_Lottable03         NVARCHAR(18)            OUTPUT
   , @dt_Lottable04        DATETIME                OUTPUT
   , @dt_Lottable05        DATETIME                OUTPUT
   , @c_Lottable06         NVARCHAR(30)   = ''     OUTPUT
   , @c_Lottable07         NVARCHAR(30)   = ''     OUTPUT
   , @c_Lottable08         NVARCHAR(30)   = ''     OUTPUT
   , @c_Lottable09         NVARCHAR(30)   = ''     OUTPUT
   , @c_Lottable10         NVARCHAR(30)   = ''     OUTPUT
   , @c_Lottable11         NVARCHAR(30)   = ''     OUTPUT
   , @c_Lottable12         NVARCHAR(30)   = ''     OUTPUT
   , @dt_Lottable13        DATETIME       = NULL   OUTPUT
   , @dt_Lottable14        DATETIME       = NULL   OUTPUT
   , @dt_Lottable15        DATETIME       = NULL   OUTPUT
   , @b_Success            int            = 1      OUTPUT
   , @n_ErrNo              int            = 0      OUTPUT
   , @c_Errmsg             NVARCHAR(250)  = ''     OUTPUT
   , @c_Sourcekey          NVARCHAR(15)   = ''  
   , @c_Sourcetype         NVARCHAR(20)   = ''   
   , @c_LottableLabel      NVARCHAR(20)   = '' 

AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @n_IsRDT INT
   EXECUTE RDT.rdtIsRDT @n_IsRDT OUTPUT

   DECLARE @n_continue     INT,
           @b_debug        INT

   SELECT @n_continue = 1, @b_success = 1, @n_ErrNo = 0, @b_debug = 0

   -- Start (Vanessa01)
   DECLARE @c_ReceiptKey        NVARCHAR(10),
           @c_ReceiptLnNo       NVARCHAR(5),
           @c_ExecStatements    NVARCHAR(4000),
           @c_ExecArguments     NVARCHAR(4000)

   DECLARE @c_ArcDBName      NVARCHAR(30),
           @c_GetReceiptKey  NVARCHAR(10),
           @c_GetReceiptLnNo NVARCHAR(5),
           @c_Recipients     NVARCHAR(MAX),
           @c_Subject        NVARCHAR(MAX),
           @tableHTML        NVARCHAR(MAX),
           @Mailitem_id      INT

   SELECT @c_GetReceiptKey = ''
   SELECT @tableHTML       = ''
   SELECT @c_ReceiptKey    = SUBSTRING(@c_Sourcekey, 1 , 10)
   SELECT @c_ReceiptLnNo   = SUBSTRING(@c_Sourcekey, 11 , 5)

   IF @c_Sourcetype = 'RECEIPT' OR @c_Sourcetype = 'RDTRECEIPT' -- Leong01
      OR @c_Sourcetype = 'RECEIPTFINALIZE' --NJOW01
   BEGIN
   -- End (Vanessa01)

   --   IF @n_IsRDT = '1'
   --      SELECT @c_Lottable02  = SUBSTRING(@c_Sourcekey, 1 , 10)
   --   ELSE
         SELECT @c_Lottable02  = SUBSTRING(@c_Sourcekey, 1 , 10) + '_' + SUBSTRING(@c_Sourcekey, 11 , 5)

   -- Start (Vanessa01)
   END

   IF @c_Sourcetype = 'TRADERETURN'
   BEGIN
      SELECT @c_ArcDBName = ISNULL(NSQLValue,'')
      FROM NSQLCONFIG (NOLOCK)
      WHERE ConfigKey='ArchiveDBName'

      SELECT @c_Subject     = Long,
             @c_Recipients  = Notes
      FROM Codelkup (nolock)
      WHERE Listname ='Recipients'
         AND Code = 'ispGenLottable02_ReceiptKey'

      Select @c_GetReceiptKey = MAX(R.ReceiptKey),
             @c_GetReceiptLnNo = MAX(RD.ReceiptLineNumber)
      From Receipt R WITH (NOLOCK)
      JOIN ReceiptDetail RD WITH (NOLOCK) ON (RD.ReceiptKey = R.ReceiptKey)
      Where R.DOCTYPE = 'A'
      AND R.StorerKey = @c_Storerkey
      AND RD.Sku = @c_Sku

      IF @b_debug = 1
      BEGIN
         SELECT '@c_Storerkey', @c_Storerkey
         SELECT '@c_Sku', @c_Sku
         SELECT '@c_GetReceiptKey', @c_GetReceiptKey
      END

      IF ISNULL(@c_GetReceiptKey, '') = ''
      BEGIN
         IF ISNULL(@c_ArcDBName, '') <> ''
         BEGIN
            SET @c_ExecStatements = ''
            SET @c_ExecArguments  = ''
            SET @c_ExecStatements = N'SELECT @c_GetReceiptKey = MAX(R.ReceiptKey), ' +
                                     '       @c_GetReceiptLnNo = MAX(RD.ReceiptLineNumber) ' +
                                     'FROM ' + ISNULL(RTRIM(@c_ArcDBName),'') +
                                     '.dbo.Receipt R WITH (NOLOCK) ' +
                                     'JOIN ' + ISNULL(RTRIM(@c_ArcDBName),'') +
                                     '.dbo.ReceiptDetail RD WITH (NOLOCK) ON (RD.ReceiptKey = R.ReceiptKey)' +
                                     'Where R.DOCTYPE = ''A'' ' +
                                     'AND R.StorerKey = @c_Storerkey ' +
                                     '   AND RD.Sku = @c_Sku '

            SET @c_ExecArguments = N'@c_Storerkey        NVARCHAR(15), ' +
                                    '@c_Sku              NVARCHAR(20), ' +
                                    '@c_GetReceiptKey    NVARCHAR(10) OUTPUT, ' +
                                    '@c_GetReceiptLnNo   NVARCHAR(5) OUTPUT '

            EXEC sp_ExecuteSql @c_ExecStatements
                              ,@c_ExecArguments
                              ,@c_Storerkey
                              ,@c_Sku
                              ,@c_GetReceiptKey    OUTPUT
                              ,@c_GetReceiptLnNo   OUTPUT

            IF ISNULL(@c_GetReceiptKey, '') = ''
            BEGIN
               SET @tableHTML =
                   N'<H4>No Receipt Found. Refer Below for Detail Info: </H4>' +
                   N'<table border="1">' +
                   N'<tr><th>StorerKey</th>' +
                   N'<th>ReceiptKey</th><th>ReceiptLineNumber</th>' +
                   N'<th>Sku</th></tr>' +
                   N'<tr><td>' + @c_Storerkey + '</td>' +
                   N'<td>' + @c_ReceiptKey + '</td><td>' + @c_ReceiptLnNo + '</td>' +
                   N'<td>' + @c_Sku + '</td></tr>' +
                   N'</table>' +
                   N'<H4>From Trade Return. (ispGenLottable02_ReceiptKey)</H4>'

               IF ISNULL(@c_Recipients, '') <> ''
               BEGIN
                  EXEC msdb.dbo.sp_send_dbmail
                      @recipients   = @c_Recipients,
                      @subject      = @c_Subject,
                      @body         = @tableHTML,
                      @body_format  = 'HTML',
                      @mailitem_id  = '',
                      @exclude_query_output = 1
               END
               ELSE
               BEGIN
                  SET @n_ErrNo = 31001
                  SET @c_Errmsg = CONVERT ( NVARCHAR(5), @n_ErrNo) + ' Recipients no Setup at Codelkup.Notes. (ispGenLottable02_ReceiptKey)'

                  GOTO QUIT
               END

               SELECT @c_Lottable02  = ''

               GOTO QUIT
            END
            ELSE
            BEGIN
               SELECT @c_Lottable02  = @c_GetReceiptKey + '_' + @c_GetReceiptLnNo
            END
         END
         ELSE
         BEGIN
            SET @n_ErrNo = 31002
            SET @c_Errmsg = CONVERT ( NVARCHAR(5), @n_ErrNo) + ' Invalid ArchiveDB Setup at NSQLCONFIG.ConfigKey=''ArchiveDBName''. (ispGenLottable02_ReceiptKey)'

            GOTO QUIT
         END
      END
      ELSE
      BEGIN
         SELECT @c_Lottable02  = @c_GetReceiptKey + '_' + @c_GetReceiptLnNo
      END
      
      IF @c_Lottable02Value = @c_Lottable02 --NJOW01
         SELECT @c_Lottable02 = ''

      IF @b_debug = 1
      BEGIN
         SELECT '@Mailitem_id', @Mailitem_id
         SELECT '@c_Lottable02', @c_Lottable02
      END
   END
   -- End (Vanessa01)
QUIT:
END -- End Procedure

GO