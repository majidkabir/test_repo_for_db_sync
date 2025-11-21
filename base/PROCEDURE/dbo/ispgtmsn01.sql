SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Trigger: ispGTMSN01                                                  */
/* Creation Date: 07-SEP-2015                                           */
/* Copyright: LF Logistics                                              */
/* Written by: YTWan                                                    */
/*                                                                      */
/* Purpose: Custom Serial# By Storer Level                              */
/*        : Storerconfig 'GTMSerialRulesSP'                             */
/* Called By: nep_u_kiosk_asrspk_serial.u_dw.itemchanged event          */
/*          :                                                           */
/* PVCS Version: 1.2                                                    */
/*                                                                      */
/* Version: 6.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date        Author   Ver   Purposes                                  */
/* 12-Nov-2018 WAN01    1.1   WMS-6890 - ASRS - Serial# Scanning at GTM */
/*                            Station for REMY                          */
/* 08-JAN-2018 Wan02    1.2   Fixed Get Wrong Qty                       */
/************************************************************************/
CREATE PROC [dbo].[ispGTMSN01] 
            @c_Orderkey          NVARCHAR(10)
         ,  @c_OrderLineNumber   NVARCHAR(5)
         ,  @c_SerialNo          NVARCHAR(30)   OUTPUT
         ,  @n_Qty               INT            OUTPUT
         ,  @b_Success           INT = 0        OUTPUT 
         ,  @n_err               INT = 0        OUTPUT 
         ,  @c_errmsg            NVARCHAR(255) = '' OUTPUT
AS
BEGIN
   DECLARE  
           @n_StartTCnt       INT
         , @n_Continue        INT 

         , @c_Storerkey       NVARCHAR(15)
         , @c_Sku             NVARCHAR(20)

         , @c_RemySNSpecRules    NVARCHAR(30)   --(Wan01)

   SET @n_StartTCnt = @@TRANCOUNT
   SET @n_Continue = 1
   SET @n_err      = 0
   SET @c_errmsg   = ''

   BEGIN TRAN -- Optional if PB Transaction is AUTOCOMMIT = FALSE. No harm to always start BEGIN TRAN in begining of SP

   SELECT @c_Storerkey = Storerkey
         ,@c_Sku       = Sku
   FROM ORDERDETAIL WITH (NOLOCK)
   WHERE ORDERDETAIL.OrderKey = @c_Orderkey
   AND   ORDERDETAIL.OrderLineNumber = @c_OrderLineNumber

   --(Wan01) - START
   SET @c_RemySNSpecRules = ''
   SELECT @c_RemySNSpecRules = ISNULL(RTRIM([Data]),'')
   FROM SKUCONFIG WITH (NOLOCK)
   WHERE Storerkey = @c_Storerkey
   AND   Sku = @c_Sku
   AND   ConfigType = 'RemySNSpecRules'

   IF @c_RemySNSpecRules = '1'
   BEGIN
      IF  LEN(RTRIM(@c_SerialNo)) <> 20 AND LEN(RTRIM(@c_SerialNo)) <> 7
      BEGIN
         SET @n_Continue = 3
         SET @n_err      = 65020
         SET @c_errmsg   = 'NSQL' + CONVERT(CHAR(5),@n_err) + '. Invalid Serial #. Serial # Len is neither 20 nor 7. (ispGTMSN01)'
         GOTO QUIT
      END

      IF  LEN(RTRIM(@c_SerialNo)) = 20  
      BEGIN
         IF LEFT(@c_SerialNo, 2) <> '95'
         BEGIN
            SET @n_Continue = 3
            SET @n_err      = 65030
            SET @c_errmsg   = 'NSQL' + CONVERT(CHAR(5),@n_err) + '. Invalid Serial #. Left 2 digits is not 95.(ispGTMSN01)'
            GOTO QUIT
         END

         IF ISNUMERIC(RIGHT(@c_SerialNo, 18)) = 0
         BEGIN
            SET @n_Continue = 3
            SET @n_err      = 65040
            SET @c_errmsg   = 'NSQL' + CONVERT(CHAR(5),@n_err) + '. Invalid Serial #. Right 18 digits is not numeric.(ispGTMSN01)'
            GOTO QUIT
         END
      END

      IF LEN(RTRIM(@c_SerialNo)) = 7 AND ISNUMERIC(RIGHT(RTRIM(@c_SerialNo),4)) = 0
      BEGIN
         SET @n_Continue = 3
         SET @n_err      = 65050
         SET @c_errmsg   = 'NSQL' + CONVERT(CHAR(5),@n_err) + '. Invalid Serial #. Right 4 digits is not numeric.(ispGTMSN01)'
         GOTO QUIT
      END
   END
   ELSE
   BEGIN
      IF LEN(RTRIM(@c_SerialNo)) > 13 AND LEN(RTRIM(@c_SerialNo)) <= 19
      BEGIN
         SET @n_Continue = 3
         SET @n_err      = 65000
         SET @c_errmsg   = 'NSQL' + CONVERT(CHAR(5),@n_err) + '. Invalid Serial #. (ispGTMSN01)'
         GOTO QUIT
      END
   END
   --(Wan01) - END

   SET @n_Qty = 1
   IF LEN(RTRIM(@c_SerialNo)) >= 20
   BEGIN
      SET @c_SerialNo = RIGHT(@c_SerialNo,18)
      
      SELECT @n_Qty = ISNULL(PACK.CaseCnt,0)
      FROM SKU  WITH (NOLOCK)
      JOIN PACK WITH (NOLOCK) ON (SKU.Packkey = PACK.Packkey)
      WHERE SKU.Storerkey = @c_Storerkey                       --(Wan02)
      AND   SKU.Sku = @c_Sku
   END 

   IF EXISTS ( SELECT 1
               FROM SERIALNO WITH (NOLOCK)
               WHERE Storerkey= @c_Storerkey
               AND   Sku      = @c_Sku
               AND   SerialNo = @c_SerialNo
               )
   BEGIN
      SET @n_Continue = 3
      SET @n_err      = 65005
      SET @c_errmsg   = 'NSQL' + CONVERT(CHAR(5),@n_err) + '. Duplicate Serial#: ' 
                      + RTRIM(@c_SerialNo)+ ' Found. (ispGTMSN01)'
      GOTO QUIT
   END
QUIT:
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

      EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'ispGTMSN01'
      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR
   END
   ELSE
   BEGIN
      SET @b_Success = 1
      WHILE @@TRANCOUNT > @n_StartTCnt
      BEGIN
         COMMIT TRAN
      END
   END
END -- procedure

GO