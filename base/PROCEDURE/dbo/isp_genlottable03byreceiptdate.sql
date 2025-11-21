SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: isp_GenLottable03ByReceiptDate                     */
/* Creation Date:                                                       */
/* Copyright: IDS                                                       */
/* Written by:                                                          */
/*                                                                      */
/* Purpose:  Default Lottable03 based on day elapsed between            */  
/*           19000101 and receipt date                                  */
/*                                                                      */
/* Called By:                                                           */
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Who      Purpose                                        */  
/* 06-Jun-2012  James    SOS246197                                      */  
/* 07-May-2014  TKLIM    Added Lottables 06-15                          */
/************************************************************************/  
  
CREATE PROCEDURE [dbo].[isp_GenLottable03ByReceiptDate]  
   @c_Storerkey         NVARCHAR(15),  
   @c_Sku               NVARCHAR(20),  
   @c_Lottable01Value   NVARCHAR(18),  
   @c_Lottable02Value   NVARCHAR(18),  
   @c_Lottable03Value   NVARCHAR(18),  
   @dt_Lottable04Value  DATETIME,  
   @dt_Lottable05Value  DATETIME,  
   @c_Lottable06Value   NVARCHAR(30)   = '',
   @c_Lottable07Value   NVARCHAR(30)   = '',
   @c_Lottable08Value   NVARCHAR(30)   = '',
   @c_Lottable09Value   NVARCHAR(30)   = '',
   @c_Lottable10Value   NVARCHAR(30)   = '',
   @c_Lottable11Value   NVARCHAR(30)   = '',
   @c_Lottable12Value   NVARCHAR(30)   = '',
   @dt_Lottable13Value  DATETIME       = NULL,
   @dt_Lottable14Value  DATETIME       = NULL,
   @dt_Lottable15Value  DATETIME       = NULL,
   @c_Lottable01        NVARCHAR(18)            OUTPUT,  
   @c_Lottable02        NVARCHAR(18)            OUTPUT,  
   @c_Lottable03        NVARCHAR(18)            OUTPUT,  
   @dt_Lottable04       DATETIME                OUTPUT,  
   @dt_Lottable05       DATETIME                OUTPUT,  
   @c_Lottable06        NVARCHAR(30)   = ''     OUTPUT,
   @c_Lottable07        NVARCHAR(30)   = ''     OUTPUT,
   @c_Lottable08        NVARCHAR(30)   = ''     OUTPUT,
   @c_Lottable09        NVARCHAR(30)   = ''     OUTPUT,
   @c_Lottable10        NVARCHAR(30)   = ''     OUTPUT,
   @c_Lottable11        NVARCHAR(30)   = ''     OUTPUT,
   @c_Lottable12        NVARCHAR(30)   = ''     OUTPUT,
   @dt_Lottable13       DATETIME       = NULL   OUTPUT,
   @dt_Lottable14       DATETIME       = NULL   OUTPUT,
   @dt_Lottable15       DATETIME       = NULL   OUTPUT,
   @b_Success           INT = 1                 OUTPUT,  
   @n_ErrNo             INT = 0                 OUTPUT,  
   @c_Errmsg            NVARCHAR(250)  = ''     OUTPUT,  
   @c_Sourcekey         NVARCHAR(15)   = '',  
   @c_Sourcetype        NVARCHAR(20)   = '',  
   @c_LottableLabel     NVARCHAR(20)   = ''  
  
AS  
BEGIN  
   SET NOCOUNT ON  
   SET QUOTED_IDENTIFIER OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  
  
   DECLARE @b_debug        INT,
           @n_DayElapsed   INT, 
           @c_ReceiptKey   NVARCHAR(10),  
           @c_ReceiptLnNo  NVARCHAR(5)    
  
   SELECT @b_success = 1, @n_ErrNo = 0, @b_debug = 0  

   SET @b_debug = 0

   SELECT @c_ReceiptKey    = SUBSTRING(@c_Sourcekey, 1 , 10)  
   SELECT @c_ReceiptLnNo   = SUBSTRING(@c_Sourcekey, 11 , 5)  
   
   SELECT @c_Lottable03Value = LOTTABLE03
   FROM dbo.ReceiptDetail WITH (NOLOCK) 
   WHERE StorerKey = @c_Storerkey
   AND ReceiptKey = @c_ReceiptKey
   AND ReceiptLineNumber = @c_ReceiptLnNo
   
   -- If Lottable03 is not blank then no need auto generate the batch no
   IF ISNULL(@c_Lottable03Value, '') <> ''
   BEGIN
      SET @c_Lottable03 = @c_Lottable03Value
      GOTO QUIT
   END
   
   SET @c_Lottable03 = DATEDIFF(Day, '19000101', GETDATE()) 
  
   IF @b_debug = 1  
   BEGIN  
      SELECT '@c_Lottable03', @c_Lottable03  
   END  

QUIT:  
END -- End Procedure

GO