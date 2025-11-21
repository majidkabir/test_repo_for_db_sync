SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Proc: isp_RFID_GetLAAttrib01                                  */
/* Creation Date: 2021-03-19                                            */
/* Copyright: LF Logistics                                              */
/* Written by: Wan                                                      */
/*                                                                      */
/* Purpose:  WMS-16505 - [CN]NIKE_Phoenix_RFID_Receiving_Overall_CR     */
/*        :                                                             */
/* Called By:                                                           */
/*          :                                                           */
/* PVCS Version: 1.2                                                    */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date        Author   Ver   Purposes                                  */
/* 2021-03-19  Wan      1.0   Created                                   */
/* 2021-07-06  WLChooi  1.1   WMS-17404 - Add Output Parameters and get */
/*                            suggested LOC (WL01)                      */
/* 17-Aug-2023 WLChooi  1.2   Performance Tuning (WL02)                 */
/* 17-Aug-2023 WLChooi  1.2   DevOps Combine Script                     */
/************************************************************************/
CREATE   PROC [dbo].[isp_RFID_GetLAAttrib01]
      @c_Receiptkey              NVARCHAR(10) = ''   --WL01
   ,  @c_StorerKey               NVARCHAR(15)   
   ,  @c_SKU                     NVARCHAR(20) = ''  
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
   ,  @b_ResetLottablesattrib    INT          = 0     OUTPUT     
   ,  @c_Lottable01attrib        NVARCHAR(1)  = '0'   OUTPUT   
   ,  @c_Lottable02attrib        NVARCHAR(1)  = '0'   OUTPUT   
   ,  @c_Lottable03attrib        NVARCHAR(1)  = '0'   OUTPUT   
   ,  @c_Lottable04attrib        NVARCHAR(1)  = '0'   OUTPUT   
   ,  @c_Lottable05attrib        NVARCHAR(1)  = '0'   OUTPUT   
   ,  @c_Lottable06attrib        NVARCHAR(1)  = '0'   OUTPUT   
   ,  @c_Lottable07attrib        NVARCHAR(1)  = '0'   OUTPUT   
   ,  @c_Lottable08attrib        NVARCHAR(1)  = '0'   OUTPUT   
   ,  @c_Lottable09attrib        NVARCHAR(1)  = '0'   OUTPUT   
   ,  @c_Lottable10attrib        NVARCHAR(1)  = '0'   OUTPUT   
   ,  @c_Lottable11attrib        NVARCHAR(1)  = '0'   OUTPUT   
   ,  @c_Lottable12attrib        NVARCHAR(1)  = '0'   OUTPUT   
   ,  @c_Lottable13attrib        NVARCHAR(1)  = '0'   OUTPUT   
   ,  @c_Lottable14attrib        NVARCHAR(1)  = '0'   OUTPUT   
   ,  @c_Lottable15attrib        NVARCHAR(1)  = '0'   OUTPUT  
   ,  @c_OtherFieldName          NVARCHAR(2000) = '0' OUTPUT   --WL01
   ,  @c_OtherFieldValue         NVARCHAR(2000) = '0' OUTPUT   --WL01 
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   SET @b_ResetLottablesattrib = 0

   DECLARE @n_StartTCnt INT = @@TRANCOUNT
         , @c_SuggestedToLoc   NVARCHAR(50)   --WL01
  
   IF (@c_Lottable01Value = 'A' AND @c_Lottable01 = '') OR @c_Lottable01 = 'A'
   BEGIN
      SET @b_ResetLottablesattrib = 1
      SET @c_Lottable02attrib = '0'
   END
   ELSE
   BEGIN
      SET @b_ResetLottablesattrib = 1
      SET @c_Lottable02attrib = '1'
   END 

   --WL01 S
   IF ISNULL(@c_Lottable02Value,'') = ''
   BEGIN
      SET @c_Lottable02Value = 'NON'
   END

   --WL02 S
   IF ISNULL(@c_Storerkey,'') = ''
   BEGIN
      SELECT TOP 1 @c_Storerkey = R.Storerkey
      FROM RECEIPT R (NOLOCK)
      WHERE R.ReceiptKey = @c_Receiptkey
   END
   --WL02 E

   SELECT @c_SuggestedToLoc = ISNULL(NIKESugLoc.Short,'')
   FROM RECEIPT R (NOLOCK)
   JOIN RECEIPTDETAIL RD (NOLOCK) ON R.ReceiptKey = RD.ReceiptKey
   JOIN SKUINFO SI (NOLOCK) ON SI.Storerkey = RD.StorerKey AND SI.SKU = RD.Sku
   JOIN CODELKUP NIKESugLoc (NOLOCK) ON NIKESugLoc.LISTNAME = 'NIKESugLoc' AND NIKESugLoc.Storerkey = R.StorerKey
                                    AND ISNULL(NIKESugLoc.UDF03,'') = ISNULL(SI.ExtendedField02,'')
                                    AND ISNULL(NIKESugLoc.UDF04,'') = ISNULL(SI.ExtendedField03,'')
                                    AND ISNULL(NIKESugLoc.UDF05,'') = ISNULL(SI.ExtendedField06,'')
   JOIN CODELKUP O2Reason (NOLOCK) ON O2Reason.LISTNAME = 'O2Reason' AND O2Reason.Storerkey = R.StorerKey
                                  AND O2Reason.Long = NIKESugLoc.UDF02
   JOIN CODELKUP NIKESoldTo (NOLOCK) ON NIKESoldTo.LISTNAME = 'NIKESoldTo' AND NIKESoldTo.Storerkey = R.StorerKey
                                    AND NIKESoldTo.Notes = R.UserDefine03
                                    AND NIKESoldTo.Long  = NIKESugLoc.Long
   WHERE R.ReceiptKey = @c_ReceiptKey
   AND RD.SKU = @c_SKU
   AND RD.Storerkey = @c_Storerkey   --WL02
   AND NIKESugLoc.UDF01 = @c_Lottable01Value
   AND O2Reason.Code = @c_Lottable02Value

   IF ISNULL(@c_SuggestedToLoc,'') = ''
   BEGIN
      SET @c_OtherFieldName  = ''
      SET @c_OtherFieldValue = ''
   END
   ELSE
   BEGIN
      SET @c_OtherFieldName  = 'ToLoc'
      SET @c_OtherFieldValue = TRIM(@c_SuggestedToLoc)
   END
   --WL01 E
   
QUIT_SP:

END -- procedure

GO