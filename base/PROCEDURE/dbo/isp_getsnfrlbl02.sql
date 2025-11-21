SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Proc: isp_GetSNFRLBL02                                        */
/* Creation Date: 29-MAR-2023                                           */
/* Copyright: Maersk                                                    */
/* Written by:                                                          */
/*                                                                      */
/* Purpose: WMS-22024 - CN ANTA SCAN EPC to SKU                         */
/*        :                                                             */
/*                                                                      */
/* Called By:  ECOM PACK Sku. isp_GetSNFromScanLabel_Wrapper            */
/*          :  Storerconfig - GetSNFromScanLabel                        */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date        Author   Ver   Purposes                                  */
/* 01-May-2023 NJOW01   1.0   DEVOPS Combine Script                     */
/* 01-May-2023 NJOW01   1.0   Add serialno Validation                   */
/************************************************************************/
CREATE   PROC [dbo].[isp_GetSNFRLBL02]
           @c_Storerkey       NVARCHAR(15)
         , @c_Sku             NVARCHAR(20)
         , @c_ScanLabel       NVARCHAR(60)
         , @c_SerialNo        NVARCHAR(30)   OUTPUT
         , @b_Success         INT            OUTPUT
         , @n_Err             INT            OUTPUT
         , @c_ErrMsg          NVARCHAR(255)  OUTPUT
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @n_StartTCnt       INT
          ,@n_Continue        INT
          ,@c_SerialNoCapture NVARCHAR(1)

   SET @n_StartTCnt = @@TRANCOUNT
   SET @n_Continue = 1
   SET @n_err      = 0
   SET @c_errmsg   = ''

   SET @c_SerialNo = ''

 	 SELECT @c_SerialNoCapture = SerialNoCapture
   FROM SKU (NOLOCK)
   WHERE Storerkey = @c_Storerkey
   AND Sku = @c_Sku     	  
   
   IF LEN(RTRIM(@c_ScanLabel)) <> 24 AND @c_SerialNoCapture IN('1','3')
   BEGIN
      SET @n_Continue = 3
      SET @n_Err = 69010
      SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(6), @n_Err) + ': Need To Scan EPC (isp_GetSNFRLBL02)'   	   	
   END
   ELSE IF LEN(RTRIM(@c_ScanLabel)) = 24 AND @c_SerialNoCapture IN('1','3')
   BEGIN
   	  IF EXISTS(SELECT 1
   	            FROM SERIALNO (NOLOCK)
   	            WHERE SerialNo = @c_ScanLabel
   	            AND Storerkey = @c_Storerkey
   	            AND Sku = @c_Sku
   	            AND Status >= 6) OR  
   	     EXISTS(SELECT 1 
   	            FROM PACKSERIALNO PS (NOLOCK)
   	            JOIN PACKHEADER PH (NOLOCK) ON PS.PickslipNo = PH.Pickslipno
   	            WHERE PS.SerialNo = @c_ScanLabel
   	            AND PS.Storerkey = @c_storerkey
   	            AND PS.Sku = @c_Sku
   	            AND PH.Status = '0') --NJOW01            
   	  BEGIN
         SET @n_Continue = 3
         SET @n_Err = 69020
         SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(6), @n_Err) + ': EPC is Packed (isp_GetSNFRLBL02)'   	   	
   	  END      
   	  ELSE       	            
   	     SET @c_SerialNo = @c_ScanLabel
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

      EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'isp_GetSNFRLBL02'
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