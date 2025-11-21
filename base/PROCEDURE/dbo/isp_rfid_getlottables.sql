SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Proc: isp_RFID_GetLottables                                   */
/* Creation Date: 2020-12-02                                            */
/* Copyright: LF Logistics                                              */
/* Written by: Wan                                                      */
/*                                                                      */
/* Purpose: WMS-14739 - CN NIKE O2 WMS RFID Receiving Module            */
/*        :                                                             */
/* Called By:                                                           */
/*          :                                                           */
/* PVCS Version: 1.3                                                    */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date        Author   Ver   Purposes                                  */
/* 02-DEC-2020 Wan      1.0   Created                                   */
/* 2021-03-19  Wan01    1.1   WMS-16505 - [CN]NIKE_Phoenix_RFID_Receiving*/
/*                           _Overall_CR                                */
/* 06-JUL-2021 WLChooi  1.2   WMS-17404 - Add Output Parameters (WL01)  */
/* 27-JUL-2021 WLChooi  1.3   WMS-17404 - Do not reset b_success (WL02) */
/************************************************************************/
CREATE PROC [dbo].[isp_RFID_GetLottables]
      @c_ReceiptKey              NVARCHAR(10)   
   ,  @c_ToID                    NVARCHAR(18) = ''  
   ,  @c_StorerKey               NVARCHAR(15)   
   ,  @c_SKU                     NVARCHAR(20) = ''        
   ,  @c_Listname                NVARCHAR(10) = ''
   ,  @c_Lottable01Value         NVARCHAR(60) = '' 
   ,  @c_Lottable02Value         NVARCHAR(60) = '' 
   ,  @c_Lottable03Value         NVARCHAR(60) = '' 
   ,  @dt_Lottable04Value        DATETIME     = NULL
   ,  @dt_Lottable05Value        DATETIME     = NULL
   ,  @c_Lottable06Value         NVARCHAR(60) = ''  
   ,  @c_Lottable07Value         NVARCHAR(60) = ''  
   ,  @c_Lottable08Value         NVARCHAR(60) = ''  
   ,  @c_Lottable09Value         NVARCHAR(60) = ''  
   ,  @c_Lottable10Value         NVARCHAR(60) = ''  
   ,  @c_Lottable11Value         NVARCHAR(60) = ''  
   ,  @c_Lottable12Value         NVARCHAR(60) = ''  
   ,  @dt_Lottable13Value        DATETIME     = NULL  
   ,  @dt_Lottable14Value        DATETIME     = NULL  
   ,  @dt_Lottable15Value        DATETIME     = NULL  
   ,  @c_Lottable01              NVARCHAR(18) = ''    OUTPUT  
   ,  @c_Lottable02              NVARCHAR(18) = ''    OUTPUT  
   ,  @c_Lottable03              NVARCHAR(18) = ''    OUTPUT  
   ,  @dt_Lottable04             DATETIME             OUTPUT  
   ,  @dt_Lottable05             DATETIME             OUTPUT  
   ,  @c_Lottable06              NVARCHAR(30) = ''    OUTPUT  
   ,  @c_Lottable07              NVARCHAR(30) = ''    OUTPUT  
   ,  @c_Lottable08              NVARCHAR(30) = ''    OUTPUT  
   ,  @c_Lottable09              NVARCHAR(30) = ''    OUTPUT  
   ,  @c_Lottable10              NVARCHAR(30) = ''    OUTPUT  
   ,  @c_Lottable11              NVARCHAR(30) = ''    OUTPUT  
   ,  @c_Lottable12              NVARCHAR(30) = ''    OUTPUT  
   ,  @dt_Lottable13             DATETIME     = NULL  OUTPUT  
   ,  @dt_Lottable14             DATETIME     = NULL  OUTPUT  
   ,  @dt_Lottable15             DATETIME     = NULL  OUTPUT 
   ,  @b_ResetLottablesattrib    INT          = 0     OUTPUT   --(wan01)   
   ,  @c_Lottable01attrib        NVARCHAR(1)  = '0'   OUTPUT   --(wan01)
   ,  @c_Lottable02attrib        NVARCHAR(1)  = '0'   OUTPUT   --(wan01)
   ,  @c_Lottable03attrib        NVARCHAR(1)  = '0'   OUTPUT   --(wan01)
   ,  @c_Lottable04attrib        NVARCHAR(1)  = '0'   OUTPUT   --(wan01)
   ,  @c_Lottable05attrib        NVARCHAR(1)  = '0'   OUTPUT   --(wan01)
   ,  @c_Lottable06attrib        NVARCHAR(1)  = '0'   OUTPUT   --(wan01)
   ,  @c_Lottable07attrib        NVARCHAR(1)  = '0'   OUTPUT   --(wan01)
   ,  @c_Lottable08attrib        NVARCHAR(1)  = '0'   OUTPUT   --(wan01)
   ,  @c_Lottable09attrib        NVARCHAR(1)  = '0'   OUTPUT   --(wan01)
   ,  @c_Lottable10attrib        NVARCHAR(1)  = '0'   OUTPUT   --(wan01)
   ,  @c_Lottable11attrib        NVARCHAR(1)  = '0'   OUTPUT   --(wan01)
   ,  @c_Lottable12attrib        NVARCHAR(1)  = '0'   OUTPUT   --(wan01)
   ,  @c_Lottable13attrib        NVARCHAR(1)  = '0'   OUTPUT   --(wan01)
   ,  @c_Lottable14attrib        NVARCHAR(1)  = '0'   OUTPUT   --(wan01)
   ,  @c_Lottable15attrib        NVARCHAR(1)  = '0'   OUTPUT   --(wan01)
   ,  @c_OtherFieldName          NVARCHAR(2000) = '0' OUTPUT   --WL01
   ,  @c_OtherFieldValue         NVARCHAR(2000) = '0' OUTPUT   --WL01
   ,  @b_Success                 INT = 1              OUTPUT  
   ,  @n_Err                     INT = 1              OUTPUT  
   ,  @c_ErrMsg                  NVARCHAR(215) = ''   OUTPUT  
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @n_Cnt                      INT           = 0
   
         , @c_SQL                      NVARCHAR(4000)= ''      --(Wan01)
         , @c_SQLParms                 NVARCHAR(4000)= ''
         
         , @c_Facility                 NVARCHAR(10)  = ''

         , @c_Short                    NVARCHAR(10)  = ''
         , @c_StoredProd               NVARCHAR(250) = '' 
         , @c_LottableLabel            NVARCHAR(60)  = ''

         , @c_doctype                  NVARCHAR(10)  = ''
         , @c_Sourcetype               NVARCHAR(20)  = ''

         , @c_RFIDASNGetLAAttrib_SP    NVARCHAR(30)   = ''

   SET @b_ResetLottablesattrib = 0

   SELECT @c_Facility = Facility  
         , @c_doctype  = Doctype
   FROM RECEIPT WITH (NOLOCK)  
   WHERE ReceiptKey = @c_ReceiptKey 
      
   SET @c_Sourcetype = CASE WHEN @c_doctype = 'X' THEN 'XDOCK'
                              WHEN @c_doctype = 'R' THEN 'TRADERETURN'
                              ELSE 'RECEIPT'
                              END
                 
   -- Retrieve Lottables on ToID  
   SET @c_Lottable01 = ''  
   SET @c_Lottable02 = ''  
   SET @c_Lottable03 = ''  
   SET @dt_Lottable04 = NULL
   SET @dt_Lottable05 = NULL
   SET @c_Lottable06 = ''  
   SET @c_Lottable07 = ''  
   SET @c_Lottable08 = ''
   SET @c_Lottable09 = ''  
   SET @c_Lottable10 = ''  
   SET @c_Lottable11 = ''  
   SET @c_Lottable12 = '' 
   SET @dt_Lottable13 = NULL 
   SET @dt_Lottable14 = NULL  
   SET @dt_Lottable15 = NULL          
  
   IF ISNULL(@c_Listname,'') = ''
   BEGIN
      -- Retrieve pre Lottable values  
      SET @n_Cnt = 1  
      WHILE @n_Cnt <= 15  
      BEGIN  
         IF @n_Cnt =  1 SET @c_ListName = 'Lottable01'  
         IF @n_Cnt =  2 SET @c_ListName = 'Lottable02'  
         IF @n_Cnt =  3 SET @c_ListName = 'Lottable03'  
         IF @n_Cnt =  4 SET @c_ListName = 'Lottable04'  
         IF @n_Cnt =  6 SET @c_ListName = 'Lottable06'  
         IF @n_Cnt =  7 SET @c_ListName = 'Lottable07'  
         IF @n_Cnt =  8 SET @c_ListName = 'Lottable08'  
         IF @n_Cnt =  9 SET @c_ListName = 'Lottable09'  
         IF @n_Cnt = 10 SET @c_ListName = 'Lottable10'  
         IF @n_Cnt = 11 SET @c_ListName = 'Lottable11'  
         IF @n_Cnt = 12 SET @c_ListName = 'Lottable12'  
         IF @n_Cnt = 13 SET @c_ListName = 'Lottable13'  
         IF @n_Cnt = 14 SET @c_ListName = 'Lottable14'  
         IF @n_Cnt = 15 SET @c_ListName = 'Lottable15'  
  
         SET @c_Short = ''  
         SET @c_StoredProd = ''  
         SET @c_LottableLabel = ''  
  
         -- Get PRE store procedure 
         SELECT  
            @c_Short = C.Short,  
            @c_StoredProd = IsNULL( C.Long, ''),  
            @c_LottableLabel = S.SValue  
         FROM dbo.CodeLkUp C WITH (NOLOCK)  
         JOIN RDT.StorerConfig S WITH (NOLOCK)ON C.ListName = S.ConfigKey  
         WHERE C.ListName = @c_ListName  
         AND C.Code = S.SValue  
         AND S.Storerkey = @c_StorerKey -- NOTE: storer level  
  
         -- Execute PRE store procedure  
         IF @c_Short = 'PRE' AND @c_StoredProd <> ''  
         BEGIN  
            EXEC dbo.ispLottableRule_Wrapper  
                 @c_SPName            = @c_StoredProd 
               , @c_ListName          = @c_ListName 
               , @c_Storerkey         = @c_StorerKey  
               , @c_Sku               = @c_SKU 
               , @c_LottableLabel     = @c_LottableLabel  
               , @c_Lottable01Value   = ''  
               , @c_Lottable02Value   = ''  
               , @c_Lottable03Value   = ''  
               , @dt_Lottable04Value  = NULL  
               , @dt_Lottable05Value  = NULL  
               , @c_Lottable06Value   = ''  
               , @c_Lottable07Value   = ''  
               , @c_Lottable08Value   = ''  
               , @c_Lottable09Value   = ''  
               , @c_Lottable10Value   = ''  
               , @c_Lottable11Value   = ''  
               , @c_Lottable12Value   = ''  
               , @dt_Lottable13Value  = NULL 
               , @dt_Lottable14Value  = NULL   
               , @dt_Lottable15Value  = NULL  
               , @c_Lottable01        = @c_Lottable01    OUTPUT  
               , @c_Lottable02        = @c_Lottable02    OUTPUT  
               , @c_Lottable03        = @c_Lottable03    OUTPUT  
               , @dt_Lottable04       = @dt_Lottable04   OUTPUT  
               , @dt_Lottable05       = @dt_Lottable05   OUTPUT  
               , @c_Lottable06        = @c_Lottable06    OUTPUT  
               , @c_Lottable07        = @c_Lottable07    OUTPUT  
               , @c_Lottable08        = @c_Lottable08    OUTPUT  
               , @c_Lottable09        = @c_Lottable09    OUTPUT  
               , @c_Lottable10        = @c_Lottable10    OUTPUT  
               , @c_Lottable11        = @c_Lottable11    OUTPUT  
               , @c_Lottable12        = @c_Lottable12    OUTPUT  
               , @dt_Lottable13       = @dt_Lottable13   OUTPUT  
               , @dt_Lottable14       = @dt_Lottable14   OUTPUT  
               , @dt_Lottable15       = @dt_Lottable15   OUTPUT  
               , @b_Success           = @b_Success       OUTPUT  
               , @n_Err               = @n_Err           OUTPUT  
               , @c_Errmsg            = @c_ErrMsg        OUTPUT  
               , @c_Sourcekey         = @c_Receiptkey  
               , @c_Sourcetype        = @c_Sourcetype
  
               IF ISNULL(@c_ErrMsg, '') <> ''  
               BEGIN  
                  SET @c_ErrMsg = @c_ErrMsg   
                  SET @b_Success = 0   
                  BREAK  
               END           END  
         SET @n_Cnt = @n_Cnt + 1  
      END -- WHILE @n_Cnt <= 15 
   END
   ELSE
   BEGIN
      EXEC dbo.ispLottableRule_Wrapper  
            @c_SPName            = '' 
         , @c_ListName          = @c_ListName 
         , @c_Storerkey         = @c_StorerKey  
         , @c_Sku               = @c_SKU 
         , @c_LottableLabel     = @c_LottableLabel  
         , @c_Lottable01Value   = @c_Lottable01Value  
         , @c_Lottable02Value   = @c_Lottable02Value  
         , @c_Lottable03Value   = @c_Lottable03Value  
         , @dt_Lottable04Value  = @dt_Lottable04Value 
         , @dt_Lottable05Value  = @dt_Lottable05Value 
         , @c_Lottable06Value   = @c_Lottable06Value  
         , @c_Lottable07Value   = @c_Lottable07Value  
         , @c_Lottable08Value   = @c_Lottable08Value  
         , @c_Lottable09Value   = @c_Lottable09Value  
         , @c_Lottable10Value   = @c_Lottable10Value  
         , @c_Lottable11Value   = @c_Lottable11Value  
         , @c_Lottable12Value   = @c_Lottable12Value  
         , @dt_Lottable13Value  = @dt_Lottable13Value 
         , @dt_Lottable14Value  = @dt_Lottable14Value 
         , @dt_Lottable15Value  = @dt_Lottable15Value 
         , @c_Lottable01        = @c_Lottable01    OUTPUT  
         , @c_Lottable02        = @c_Lottable02    OUTPUT  
         , @c_Lottable03        = @c_Lottable03    OUTPUT  
         , @dt_Lottable04       = @dt_Lottable04   OUTPUT  
         , @dt_Lottable05       = @dt_Lottable05   OUTPUT  
         , @c_Lottable06        = @c_Lottable06    OUTPUT  
         , @c_Lottable07        = @c_Lottable07    OUTPUT  
         , @c_Lottable08        = @c_Lottable08    OUTPUT  
         , @c_Lottable09        = @c_Lottable09    OUTPUT  
         , @c_Lottable10        = @c_Lottable10    OUTPUT  
         , @c_Lottable11        = @c_Lottable11    OUTPUT  
         , @c_Lottable12        = @c_Lottable12    OUTPUT  
         , @dt_Lottable13       = @dt_Lottable13   OUTPUT  
         , @dt_Lottable14       = @dt_Lottable14   OUTPUT  
         , @dt_Lottable15       = @dt_Lottable15   OUTPUT  
         , @b_Success           = @b_Success       OUTPUT  
         , @n_Err               = @n_Err           OUTPUT  
         , @c_Errmsg            = @c_ErrMsg        OUTPUT  
         , @c_Sourcekey         = @c_Receiptkey  
         , @c_Sourcetype        = @c_Sourcetype
         , @c_PrePost           = '' 
   END
  
   SET @c_Lottable01 = IsNULL( @c_Lottable01, '')  
   SET @c_Lottable02 = IsNULL( @c_Lottable02, '')  
   SET @c_Lottable03 = IsNULL( @c_Lottable03, '')  
   SET @c_Lottable06 = IsNULL( @c_Lottable06, '')  
   SET @c_Lottable07 = IsNULL( @c_Lottable07, '')  
   SET @c_Lottable08 = IsNULL( @c_Lottable08, '')  
   SET @c_Lottable09 = IsNULL( @c_Lottable09, '')  
   SET @c_Lottable10 = IsNULL( @c_Lottable10, '')  
   SET @c_Lottable11 = IsNULL( @c_Lottable11, '')  
   SET @c_Lottable12 = IsNULL( @c_Lottable12, '')  
   
   -------------------------------------------------
   --(Wan01) - START : GET Sku Lottables Attribute 
   -------------------------------------------------
   
   SELECT @c_RFIDASNGetLAAttrib_SP = dbo.fnc_GetRight(@c_Facility, @c_Storerkey, '', 'RFIDASNGetLAAttrib_SP')

   IF NOT EXISTS (SELECT 1 FROM Sys.Objects (NOLOCK) WHERE object_id = object_id(@c_RFIDASNGetLAAttrib_SP) AND [Type] = 'P')
   BEGIN
      GOTO QUIT_SP
   END

   --SET @b_Success = 1   --WL02
   SET @c_SQL = N'EXEC ' + @c_RFIDASNGetLAAttrib_SP
              + ' @c_StorerKey            = @c_StorerKey'             
              + ',@c_SKU                  = @c_SKU' 
              + ',@c_Lottable01Value      = @c_Lottable01Value'
              + ',@c_Lottable02Value      = @c_Lottable02Value'
              + ',@c_Lottable03Value      = @c_Lottable03Value'
              + ',@dt_Lottable04Value     = @dt_Lottable04Value'
              + ',@dt_Lottable05Value     = @dt_Lottable05Value'
              + ',@c_Lottable06Value      = @c_Lottable06Value'
              + ',@c_Lottable07Value      = @c_Lottable07Value'
              + ',@c_Lottable08Value      = @c_Lottable08Value'
              + ',@c_Lottable09Value      = @c_Lottable09Value'
              + ',@c_Lottable10Value      = @c_Lottable10Value'
              + ',@c_Lottable11Value      = @c_Lottable11Value'
              + ',@c_Lottable12Value      = @c_Lottable12Value'
              + ',@dt_Lottable13Value     = @dt_Lottable13Value'
              + ',@dt_Lottable14Value     = @dt_Lottable14Value'
              + ',@dt_Lottable15Value     = @dt_Lottable15Value'
              + ',@c_Lottable01           = @c_Lottable01'          
              + ',@c_Lottable02           = @c_Lottable02'          
              + ',@c_Lottable03           = @c_Lottable03'          
              + ',@dt_Lottable04          = @dt_Lottable04'         
              + ',@dt_Lottable05          = @dt_Lottable05'         
              + ',@c_Lottable06           = @c_Lottable06'          
              + ',@c_Lottable07           = @c_Lottable07'          
              + ',@c_Lottable08           = @c_Lottable08'          
              + ',@c_Lottable09           = @c_Lottable09'          
              + ',@c_Lottable10           = @c_Lottable10'          
              + ',@c_Lottable11           = @c_Lottable11'          
              + ',@c_Lottable12           = @c_Lottable12'          
              + ',@dt_Lottable13          = @dt_Lottable13'         
              + ',@dt_Lottable14          = @dt_Lottable14'         
              + ',@dt_Lottable15          = @dt_Lottable15'         
              + ',@b_ResetLottablesattrib = @b_ResetLottablesattrib  OUTPUT'
              + ',@c_Lottable01attrib     = @c_Lottable01attrib      OUTPUT'    
              + ',@c_Lottable02attrib     = @c_Lottable02attrib      OUTPUT'    
              + ',@c_Lottable03attrib     = @c_Lottable03attrib      OUTPUT'    
              + ',@c_Lottable04attrib     = @c_Lottable04attrib      OUTPUT'    
              + ',@c_Lottable05attrib     = @c_Lottable05attrib      OUTPUT'    
              + ',@c_Lottable06attrib     = @c_Lottable06attrib      OUTPUT'    
              + ',@c_Lottable07attrib     = @c_Lottable07attrib      OUTPUT'    
              + ',@c_Lottable08attrib     = @c_Lottable08attrib      OUTPUT'    
              + ',@c_Lottable09attrib     = @c_Lottable09attrib      OUTPUT'    
              + ',@c_Lottable10attrib     = @c_Lottable10attrib      OUTPUT'    
              + ',@c_Lottable11attrib     = @c_Lottable11attrib      OUTPUT'    
              + ',@c_Lottable12attrib     = @c_Lottable12attrib      OUTPUT'    
              + ',@c_Lottable13attrib     = @c_Lottable13attrib      OUTPUT'    
              + ',@c_Lottable14attrib     = @c_Lottable14attrib      OUTPUT'    
              + ',@c_Lottable15attrib     = @c_Lottable15attrib      OUTPUT'    
              + ',@c_OtherFieldName       = @c_OtherFieldName        OUTPUT'   --WL01
              + ',@c_OtherFieldValue      = @c_OtherFieldValue       OUTPUT'   --WL01
              + ',@c_Receiptkey           = @c_Receiptkey                  '   --WL01

   SET @c_SQLParms= N'@c_StorerKey               NVARCHAR(15)'   
                  + ',@c_SKU                     NVARCHAR(20)'
                  + ',@c_Lottable01Value         NVARCHAR(60)'
                  + ',@c_Lottable02Value         NVARCHAR(60)'
                  + ',@c_Lottable03Value         NVARCHAR(60)'
                  + ',@dt_Lottable04Value        DATETIME'
                  + ',@dt_Lottable05Value        DATETIME'
                  + ',@c_Lottable06Value         NVARCHAR(60)'
                  + ',@c_Lottable07Value         NVARCHAR(60)'
                  + ',@c_Lottable08Value         NVARCHAR(60)'
                  + ',@c_Lottable09Value         NVARCHAR(60)'
                  + ',@c_Lottable10Value         NVARCHAR(60)'
                  + ',@c_Lottable11Value         NVARCHAR(60)'
                  + ',@c_Lottable12Value         NVARCHAR(60)'
                  + ',@dt_Lottable13Value        DATETIME'  
                  + ',@dt_Lottable14Value        DATETIME'  
                  + ',@dt_Lottable15Value        DATETIME'  
                  + ',@c_Lottable01              NVARCHAR(18)'  
                  + ',@c_Lottable02              NVARCHAR(18)'  
                  + ',@c_Lottable03              NVARCHAR(18)'  
                  + ',@dt_Lottable04             DATETIME    '  
                  + ',@dt_Lottable05             DATETIME    '  
                  + ',@c_Lottable06              NVARCHAR(30)'  
                  + ',@c_Lottable07              NVARCHAR(30)'  
                  + ',@c_Lottable08              NVARCHAR(30)'  
                  + ',@c_Lottable09              NVARCHAR(30)'  
                  + ',@c_Lottable10              NVARCHAR(30)'  
                  + ',@c_Lottable11              NVARCHAR(30)'  
                  + ',@c_Lottable12              NVARCHAR(30)'  
                  + ',@dt_Lottable13             DATETIME    '  
                  + ',@dt_Lottable14             DATETIME    '  
                  + ',@dt_Lottable15             DATETIME    '   
                  + ',@b_ResetLottablesattrib    INT           OUTPUT'
                  + ',@c_Lottable01attrib        NVARCHAR(1)   OUTPUT'
                  + ',@c_Lottable02attrib        NVARCHAR(1)   OUTPUT'
                  + ',@c_Lottable03attrib        NVARCHAR(1)   OUTPUT'
                  + ',@c_Lottable04attrib        NVARCHAR(1)   OUTPUT'
                  + ',@c_Lottable05attrib        NVARCHAR(1)   OUTPUT'
                  + ',@c_Lottable06attrib        NVARCHAR(1)   OUTPUT'
                  + ',@c_Lottable07attrib        NVARCHAR(1)   OUTPUT'
                  + ',@c_Lottable08attrib        NVARCHAR(1)   OUTPUT'
                  + ',@c_Lottable09attrib        NVARCHAR(1)   OUTPUT'
                  + ',@c_Lottable10attrib        NVARCHAR(1)   OUTPUT'
                  + ',@c_Lottable11attrib        NVARCHAR(1)   OUTPUT'
                  + ',@c_Lottable12attrib        NVARCHAR(1)   OUTPUT'
                  + ',@c_Lottable13attrib        NVARCHAR(1)   OUTPUT'
                  + ',@c_Lottable14attrib        NVARCHAR(1)   OUTPUT'
                  + ',@c_Lottable15attrib        NVARCHAR(1)   OUTPUT'
                  + ',@c_OtherFieldName          NVARCHAR(2000) OUTPUT'   --WL01
                  + ',@c_OtherFieldValue         NVARCHAR(2000) OUTPUT'   --WL01
                  + ',@c_Receiptkey              NVARCHAR(2000) OUTPUT'   --WL01

   EXEC sp_ExecuteSQL  @c_SQL
                     , @c_SQLParms
                     , @c_StorerKey               
                     , @c_SKU  
                     , @c_Lottable01Value 
                     , @c_Lottable02Value 
                     , @c_Lottable03Value 
                     , @dt_Lottable04Value
                     , @dt_Lottable05Value
                     , @c_Lottable06Value 
                     , @c_Lottable07Value 
                     , @c_Lottable08Value 
                     , @c_Lottable09Value 
                     , @c_Lottable10Value 
                     , @c_Lottable11Value 
                     , @c_Lottable12Value 
                     , @dt_Lottable13Value
                     , @dt_Lottable14Value
                     , @dt_Lottable15Value                   
                     , @c_Lottable01              
                     , @c_Lottable02              
                     , @c_Lottable03              
                     , @dt_Lottable04             
                     , @dt_Lottable05             
                     , @c_Lottable06              
                     , @c_Lottable07              
                     , @c_Lottable08              
                     , @c_Lottable09              
                     , @c_Lottable10              
                     , @c_Lottable11              
                     , @c_Lottable12              
                     , @dt_Lottable13             
                     , @dt_Lottable14             
                     , @dt_Lottable15             
                     , @b_ResetLottablesattrib    OUTPUT
                     , @c_Lottable01attrib        OUTPUT
                     , @c_Lottable02attrib        OUTPUT
                     , @c_Lottable03attrib        OUTPUT
                     , @c_Lottable04attrib        OUTPUT
                     , @c_Lottable05attrib        OUTPUT
                     , @c_Lottable06attrib        OUTPUT
                     , @c_Lottable07attrib        OUTPUT
                     , @c_Lottable08attrib        OUTPUT
                     , @c_Lottable09attrib        OUTPUT
                     , @c_Lottable10attrib        OUTPUT
                     , @c_Lottable11attrib        OUTPUT
                     , @c_Lottable12attrib        OUTPUT
                     , @c_Lottable13attrib        OUTPUT
                     , @c_Lottable14attrib        OUTPUT
                     , @c_Lottable15attrib        OUTPUT
                     , @c_OtherFieldName          OUTPUT   --WL01
                     , @c_OtherFieldValue         OUTPUT   --WL01
                     , @c_Receiptkey              OUTPUT   --WL01

   -------------------------------------------------
   --(Wan01) - END : GET Sku Lottables Attribute  
   -------------------------------------------------
   QUIT_SP: --(Wan01)
END -- procedure

GO