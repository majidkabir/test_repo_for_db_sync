SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: ispSKUDC14                                         */
/* Creation Date: 24/05/2023                                            */
/* Copyright: Maersk                                                    */
/* Written by:                                                          */
/*                                                                      */
/* Purpose: WMS-22637 CN Converse validate and decode barcode 69        */
/*                                                                      */
/*                                                                      */
/* Called By: isp_SKUDecode_Wrapper                                     */
/*                                                                      */
/* GitLab Version: 1.0                                                  */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date        Author   Ver   Purposes                                  */
/* 24-MAY-2023 NJOW     1.0   DEVOPS combine scirpt                     */
/************************************************************************/

CREATE   PROCEDURE [dbo].[ispSKUDC14]
     @c_Storerkey        NVARCHAR(15)
   , @c_Sku              NVARCHAR(60)
   , @c_NewSku           NVARCHAR(60)      OUTPUT
   , @c_Code01           NVARCHAR(60) = '' OUTPUT
   , @c_Code02           NVARCHAR(60) = '' OUTPUT
   , @c_Code03           NVARCHAR(60) = '' OUTPUT
   , @b_Success          INT          = 1  OUTPUT
   , @n_Err              INT          = 0  OUTPUT
   , @c_ErrMsg           NVARCHAR(250)= '' OUTPUT
   , @c_Pickslipno       NVARCHAR(10) = ''
   , @n_CartonNo         INT = 0
   , @c_UCCNo            NVARCHAR(20) = ''  --Pack by UCC when UCCtoDropID = '1' 
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @n_Continue     INT = 1
         , @n_StartTcnt    INT = @@TRANCOUNT
         , @c_TempSku      NVARCHAR(60) = ''

   SELECT @b_success = 1, @n_err = 0, @c_errmsg = ''   
   
   SET @c_TempSku = LTRIM(@c_Sku)
   
   IF ISNULL(@c_Pickslipno,'') <> ''  --normal packing has pickslipno pass in
   BEGIN
      IF EXISTS(SELECT 1
                FROM PICKHEADER PH (NOLOCK)                
                JOIN ORDERS O (NOLOCK) ON PH.Orderkey = O.Orderkey
                WHERE PH.Pickheaderkey = @c_PickslipNo
                AND O.DocType <> 'E')
      BEGIN
      	 SET @c_NewSku = @c_Sku
         GOTO QUIT_SP   	  
      END
      
      IF EXISTS(SELECT 1
                FROM PICKHEADER PH (NOLOCK)                
                JOIN ORDERS O (NOLOCK) ON PH.ExternOrderkey = O.Loadkey                                          
                WHERE PH.Pickheaderkey = @c_PickslipNo
                AND O.DocType <> 'E'
                AND ISNULL(PH.Orderkey,'') = '')
      BEGIN
      	 SET @c_NewSku = @c_Sku
         GOTO QUIT_SP   	  
      END      
   END
   
   IF LEFT(@c_TempSku,2) <> '69'
   BEGIN 
      SELECT @n_continue = 3  
      SELECT @n_err = 85000  
      SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Please scan 69 code. (ispSKUDC14)'          	  
   END
   ELSE
   BEGIN
      EXEC nspg_GETSKU_PACK   
            @c_PickSlipNo  = @c_Pickslipno  
           ,@c_StorerKey   = @c_Storerkey  OUTPUT   
           ,@c_SKU         = @c_TempSku    OUTPUT  
           ,@b_Success     = @b_Success    OUTPUT  
           ,@n_Err         = @n_Err        OUTPUT  
           ,@c_ErrMsg      = @c_ErrMsg     OUTPUT
      
      IF @b_Success = 0
      BEGIN
         SELECT @n_continue = 3
      END
      ELSE IF @c_TempSku = @c_Sku
      BEGIN
         SELECT @n_continue = 3  
         SELECT @n_err = 85010  
         SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Cannot find Sku by 69 code: ' + RTRIM(@c_Sku) + '. (ispSKUDC14)'          	        	
      END
      ELSE
      BEGIN
         SET @c_NewSku = @c_TempSku
      END
   END
      
QUIT_SP:

   IF @n_Continue=3  -- Error Occured - Process AND Return
   BEGIN
      SET @b_Success = 0
      IF @@TRANCOUNT = 1 AND @@TRANCOUNT > @n_StartTCnt
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
      EXECUTE dbo.nsp_LogError @n_Err, @c_Errmsg, 'ispSKUDC14'
      RAISERROR (@c_Errmsg, 16, 1) WITH SETERROR    -- SQL2012
      RETURN
   END
   ELSE
   BEGIN
      SET @b_Success = 1
      WHILE @@TRANCOUNT > @n_StartTCnt
      BEGIN
         COMMIT TRAN
      END
      RETURN
   END
END -- End Procedure

GO