SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Trigger: isp_PrePackSN01                                             */
/* Creation Date: 18-MAY-2017                                           */
/* Copyright: LF Logistics                                              */
/* Written by: Wan                                                      */
/*                                                                      */
/* Purpose: WMS-1466 - CN & SG Logitech - Packing                       */
/*        :                                                             */
/* Called By: PACKSerialNo_Wrapper                                      */
/*          :                                                           */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date        Author   Ver   Purposes                                  */
/* 28-May-2021 NJOW01   1.0   WMS-17141 add order type LOGIVMI          */
/************************************************************************/
CREATE PROC [dbo].[isp_PrePackSN01] 
            @c_PickSlipNo  NVARCHAR(10)      
         ,  @c_Storerkey   NVARCHAR(15)   
         ,  @c_Sku         NVARCHAR(20) 
         ,  @c_SerialNo    NVARCHAR(30) 
         ,  @b_Success     INT = 0           OUTPUT 
         ,  @n_err         INT = 0           OUTPUT 
         ,  @c_errmsg      NVARCHAR(255) = ''OUTPUT
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE  
           @n_StartTCnt       INT
         , @n_Continue        INT

         , @c_OrderType       NVARCHAR(10) 
         , @c_InterfaceValue  NVARCHAR(18)   
         , @c_ExternStatus    NVARCHAR(10) 
     
   SET @c_OrderType = ''
   SELECT @c_OrderType = ISNULL(RTRIM(ORDERS.Type),'')
   FROM PACKHEADER WITH (NOLOCK)
   JOIN ORDERS     WITH (NOLOCK) ON (PACKHEADER.Orderkey = ORDERS.Orderkey)
   WHERE PACKHEADER.PickSlipNo = @c_PickSlipNo

   SET @c_ExternStatus = 'E'

   IF RIGHT(RTRIM(@c_SerialNo),1) = 'M'
   BEGIN
      IF EXISTS(  SELECT 1
                  FROM MASTERSERIALNO WITH (NOLOCK) 
                  WHERE Storerkey = @c_Storerkey 
                  AND   Sku = @c_Sku                       
                  AND   ParentSerialNo = @c_SerialNo 
               ) 
      BEGIN
         SET @c_ExternStatus = '9'
      END
   END
   ELSE
   BEGIN
      IF EXISTS(  SELECT 1
                  FROM MASTERSERIALNO WITH (NOLOCK) 
                  WHERE Storerkey = @c_Storerkey 
                  AND   Sku = @c_Sku                       
                  AND   SerialNo = @c_SerialNo 
               ) 
      BEGIN
         SET @c_ExternStatus = '9'
      END
   END

   SET @c_InterfaceValue = CASE WHEN @c_OrderType = 'LOGIRTV' THEN '28'
                                WHEN @c_OrderType = 'LOGIDIS' THEN '92'  
                                WHEN @c_OrderType = 'IR' THEN '14'  
                                WHEN @c_OrderType = 'WR' THEN '26' 
                                WHEN @c_OrderType = 'LOGIVMI' THEN '9' --NJOW01
                                ELSE '20'
                                END
   IF OBJECT_ID('tempdb..#TMP_SNInfo','U') IS NOT NULL
   BEGIN
      INSERT INTO #TMP_SNInfo
         (  SerialNo
         ,  ID
         ,  ExternStatus
         )
      VALUES      
         (  @c_SerialNo
         ,  @c_InterfaceValue
         ,  @c_ExternStatus  
         )      
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

      EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'isp_PrePackSN01'
      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
   END
   ELSE
   BEGIN
      SET @b_Success = 1
      WHILE @@TRANCOUNT > @n_StartTCnt
      BEGIN
         COMMIT TRAN
      END
   END
  
   WHILE @@TRANCOUNT < @n_StartTCnt 
   BEGIN
      BEGIN TRAN; 
   END  
END -- procedure

GO