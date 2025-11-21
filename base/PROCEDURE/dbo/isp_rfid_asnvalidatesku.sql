SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Proc: isp_RFID_ASNValidateSku                                 */
/* Creation Date: 2020-Dec-01                                           */
/* Copyright: LF Logistics                                              */
/* Written by: Wan                                                      */
/*                                                                      */
/* Purpose:  WMS-14739 - CN NIKE O2 WMS RFID Receiving Module           */
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
/* 01-DEC-2020 Wan      1.0   Created                                   */
/* 20-JAN-2021 Wan01    1.1   WMS-16143 - NIKE_O2_RFID_Receiving_CR V1.0*/
/* 05-Jan-2023 Wan02    1.2   WMS-21467-[CN]NIKE_Ecom_NFC RFID Receiving-CR*/
/*                            DevOps Combine Script                     */
/************************************************************************/
CREATE   PROC isp_RFID_ASNValidateSku
           @c_Receiptkey         NVARCHAR(10)  
         , @c_Storerkey          NVARCHAR(15)  
         , @c_SKU                NVARCHAR(20)         OUTPUT
         , @c_Lottable01attrib   NVARCHAR(1)  = '0'   OUTPUT
         , @c_Lottable02attrib   NVARCHAR(1)  = '0'   OUTPUT
         , @c_Lottable03attrib   NVARCHAR(1)  = '0'   OUTPUT
         , @c_Lottable04attrib   NVARCHAR(1)  = '0'   OUTPUT
         , @c_Lottable05attrib   NVARCHAR(1)  = '0'   OUTPUT
         , @c_Lottable06attrib   NVARCHAR(1)  = '0'   OUTPUT
         , @c_Lottable07attrib   NVARCHAR(1)  = '0'   OUTPUT
         , @c_Lottable08attrib   NVARCHAR(1)  = '0'   OUTPUT
         , @c_Lottable09attrib   NVARCHAR(1)  = '0'   OUTPUT
         , @c_Lottable10attrib   NVARCHAR(1)  = '0'   OUTPUT
         , @c_Lottable11attrib   NVARCHAR(1)  = '0'   OUTPUT
         , @c_Lottable12attrib   NVARCHAR(1)  = '0'   OUTPUT
         , @c_Lottable13attrib   NVARCHAR(1)  = '0'   OUTPUT
         , @c_Lottable14attrib   NVARCHAR(1)  = '0'   OUTPUT
         , @c_Lottable15attrib   NVARCHAR(1)  = '0'   OUTPUT
         , @b_ReadRFIDTag        INT          = 0     OUTPUT      --(Wan01) 
         , @b_Success            INT          = 1     OUTPUT
         , @n_Err                INT          = 0     OUTPUT
         , @c_ErrMsg             NVARCHAR(255)= ''    OUTPUT
         , @c_Tag_Reader         NVARCHAR(10) = ''    OUTPUT      --(Wan02) 
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE  
           @n_StartTCnt          INT = @@TRANCOUNT
         , @n_Continue           INT = 1
         , @n_SkuCnt             INT = 0

         , @c_Facility           NVARCHAR(5)  = ''
         , @c_ScanSKU            NVARCHAR(20) = ''
         , @c_RFIDValidateSku_SP NVARCHAR(30) = ''

         , @c_SQL                NVARCHAR(MAX)= ''
         , @c_SQLParms           NVARCHAR(MAX)= ''

   SET @n_err      = 0
   SET @c_errmsg   = ''

   SET @c_ScanSKU = @c_Sku

   IF @c_ScanSKU <> ''
   BEGIN
      SET @c_Sku = ''
      SELECT @c_Sku = S.Sku
      FROM SKU S WITH (NOLOCK)
      WHERE S.Storerkey = @c_Storerkey
      AND S.Sku = @c_ScanSKU

      IF @c_Sku = ''
      BEGIN
         ;WITH SCANSKU AS
         (
            SELECT Sku = S.Sku FROM SKU S WITH (NOLOCK) WHERE S.Storerkey = @c_Storerkey AND S.AltSku = @c_ScanSKU
            UNION ALL
            SELECT Sku = S.Sku FROM SKU S WITH (NOLOCK) WHERE S.Storerkey = @c_Storerkey AND S.RetailSku = @c_ScanSKU
            UNION ALL
            SELECT Sku = S.Sku FROM SKU S WITH (NOLOCK) WHERE S.Storerkey = @c_Storerkey AND S.ManufacturerSku = @c_ScanSKU
            UNION ALL
            SELECT Sku = UPC.Sku FROM UPC  WITH (NOLOCK) WHERE UPC.Storerkey = @c_Storerkey AND UPC.UPC = @c_ScanSKU
         )

         SELECT @n_SkuCnt = COUNT(DISTINCT SS.SKU)
               ,@c_Sku = MIN(SS.Sku)
         FROM SCANSKU SS

         IF @n_SkuCnt = 0 
         BEGIN
            SET @n_Continue = 3
            SET @n_err = 83010
            SET @c_errmsg = 'NSQL' +CONVERT(CHAR(5),@n_err) + ': Invalid Input Sku. (isp_RFID_ASNValidateSku)'
            GOTO QUIT_SP
         END

         IF @n_SkuCnt > 1 
         BEGIN
            SET @n_Continue = 3
            SET @n_err = 83020
            SET @c_errmsg = 'NSQL' +CONVERT(CHAR(5),@n_err) + ': Multi SKU barcode. (isp_RFID_ASNValidateSku)'
            GOTO QUIT_SP
         END
      END
   END

   SELECT  @c_Lottable01attrib = CASE WHEN ISNULL(Lottable01Label,'') <> '' THEN '1' ELSE '0' END
         , @c_Lottable02attrib = CASE WHEN ISNULL(Lottable02Label,'') <> '' THEN '1' ELSE '0' END
         , @c_Lottable03attrib = CASE WHEN ISNULL(Lottable03Label,'') <> '' THEN '1' ELSE '0' END
         , @c_Lottable04attrib = CASE WHEN ISNULL(Lottable04Label,'') <> '' THEN '1' ELSE '0' END
         , @c_Lottable05attrib = '0' 
         , @c_Lottable06attrib = CASE WHEN ISNULL(Lottable06Label,'') <> '' THEN '1' ELSE '0' END
         , @c_Lottable07attrib = CASE WHEN ISNULL(Lottable07Label,'') <> '' THEN '1' ELSE '0' END
         , @c_Lottable08attrib = CASE WHEN ISNULL(Lottable08Label,'') <> '' THEN '1' ELSE '0' END
         , @c_Lottable09attrib = CASE WHEN ISNULL(Lottable09Label,'') <> '' THEN '1' ELSE '0' END
         , @c_Lottable10attrib = CASE WHEN ISNULL(Lottable10Label,'') <> '' THEN '1' ELSE '0' END
         , @c_Lottable11attrib = CASE WHEN ISNULL(Lottable11Label,'') <> '' THEN '1' ELSE '0' END
         , @c_Lottable12attrib = CASE WHEN ISNULL(Lottable12Label,'') <> '' THEN '1' ELSE '0' END
         , @c_Lottable13attrib = CASE WHEN ISNULL(Lottable13Label,'') <> '' THEN '1' ELSE '0' END
         , @c_Lottable14attrib = CASE WHEN ISNULL(Lottable14Label,'') <> '' THEN '1' ELSE '0' END
         , @c_Lottable15attrib = CASE WHEN ISNULL(Lottable15Label,'') <> '' THEN '1' ELSE '0' END
   FROM SKU WITH (NOLOCK)
   WHERE Storerkey = @c_Storerkey
   AND SKu = @c_Sku

   SELECT @c_Facility = RH.Facility
   FROM RECEIPT RH (NOLOCK)
   WHERE RH.Receiptkey = @c_Receiptkey

   SET @c_RFIDValidateSku_SP = ''
   EXEC nspGetRight
         @c_Facility   = @c_Facility  
      ,  @c_StorerKey  = @c_StorerKey 
      ,  @c_sku        = ''       
      ,  @c_ConfigKey  = 'RFIDASNValidateSku_SP' 
      ,  @b_Success    = @b_Success             OUTPUT
      ,  @c_authority  = @c_RFIDValidateSku_SP  OUTPUT 
      ,  @n_err        = @n_err                 OUTPUT
      ,  @c_errmsg     = @c_errmsg              OUTPUT

   IF @b_Success = 0 
   BEGIN
      SET @n_Continue = 3
      SET @n_err = 83030   
      SET @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Error Executing nspGetRight - RFIDASNValidateSku_SP. (isp_RFID_ASNValidateSku)'   
                  + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '   
      GOTO QUIT_SP  
   END

   IF @c_RFIDValidateSku_SP = '0'
   BEGIN
      GOTO QUIT_SP  
   END

   IF NOT EXISTS (SELECT 1 FROM Sys.Objects (NOLOCK) WHERE object_id = object_id(@c_RFIDValidateSku_SP) AND [Type] = 'P')
   BEGIN
      SET @n_Continue = 3
      SET @n_err = 83040   
      SET @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Custom Stored Procedure:' + @c_RFIDValidateSku_SP 
                     +' not found. (isp_RFID_ASNValidateSku)'   
      GOTO QUIT_SP
   END

   SET @b_Success = 1
   SET @c_SQL = N'EXEC ' + @c_RFIDValidateSku_SP
               +'  @c_Receiptkey = @c_Receiptkey' 
               +', @c_Storerkey  = @c_Storerkey' 
               +', @c_Sku        = @c_Sku' 
               +', @b_ReadRFIDTag= @b_ReadRFIDTag  OUTPUT'     --(Wan01)    
               +', @b_Success    = @b_Success      OUTPUT'
               +', @n_Err        = @n_Err          OUTPUT'
               +', @c_ErrMsg     = @c_ErrMsg       OUTPUT'
               +', @c_Tag_Reader = @c_Tag_Reader   OUTPUT'     --(Wan02)

   SET @c_SQLParms= N'@c_Receiptkey    NVARCHAR(10)'
                  +', @c_Storerkey     NVARCHAR(15)'
                  +', @c_Sku           NVARCHAR(20)'
                  +', @b_ReadRFIDTag   INT            OUTPUT'  --(Wan01)    
                  +', @b_Success       INT            OUTPUT'
                  +', @n_Err           INT            OUTPUT'
                  +', @c_ErrMsg        NVARCHAR(255)  OUTPUT'
                  +', @c_Tag_Reader    NVARCHAR(10)   OUTPUT'  --(Wan02)

   EXEC sp_ExecuteSQL  @c_SQL
                     , @c_SQLParms
                     , @c_Receiptkey                     
                     , @c_Storerkey   
                     , @c_Sku  
                     , @b_ReadRFIDTag  OUTPUT                  --(Wan01)  
                     , @b_Success      OUTPUT
                     , @n_Err          OUTPUT
                     , @c_ErrMsg       OUTPUT
                     , @c_Tag_Reader   OUTPUT                  --(Wan02)

   IF @b_Success = 0
   BEGIN
      SET @n_Continue = 3
      GOTO QUIT_SP  
   END
QUIT_SP:

   IF @n_Continue=3  -- Error Occured - Process And Return
   BEGIN
      SET @b_Success = 0
      IF  @@TRANCOUNT = 1 AND @@TRANCOUNT > @n_StartTCnt
      BEGIN
         ROLLBACK TRAN
      END
      ELSE
      BEGIN
         WHILE @@TRANCOUNT > @n_StartTCnt
         BEGIN
            COMMIT TRAN
         END
      END

      EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'isp_RFID_ASNValidateSku'
      --RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
   END
   ELSE
   BEGIN
      IF @b_Success < 2
      BEGIN
         SET @b_Success = 1
      END
      
      WHILE @@TRANCOUNT > @n_StartTCnt
      BEGIN
         COMMIT TRAN
      END
   END
END -- procedure

GO