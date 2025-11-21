SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Procedure: ispPKLotChk04                                      */
/* Creation Date: 06-Apr-2022                                           */
/* Copyright: LFL                                                       */
/* Written by:                                                          */
/*                                                                      */
/* Purpose: WMS-19392 TBLTW Pack by lottable validation                 */   
/*                                                                      */
/* Called By: Packing lottable -> isp_PackLottableCheck_Wrapper         */
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */  
/* Date        Author   Ver   Purposes                                  */ 
/* 06-Apr-2022 NJOW     1.0   DEVOPS combine script                     */    
/************************************************************************/

CREATE PROC [dbo].[ispPKLotChk04]   
      @c_PickslipNo    NVARCHAR(10)   
   ,  @c_Storerkey     NVARCHAR(15)
   ,  @c_Sku           NVARCHAR(20)
   ,  @c_LottableValue NVARCHAR(60)
   ,  @n_Cartonno      INT
   ,  @n_PackingQty    INT
   ,  @b_Success       INT           OUTPUT
   ,  @n_Err           INT           OUTPUT
   ,  @c_ErrMsg        NVARCHAR(250) OUTPUT
AS   
BEGIN  
   SET NOCOUNT ON  
   SET QUOTED_IDENTIFIER OFF   
   SET ANSI_NULLS OFF   
   SET CONCAT_NULL_YIELDS_NULL OFF  
     
   DECLARE @n_Continue           INT = 1
         , @n_StartTCnt          INT = @@TRANCOUNT         
         , @c_Orderkey           NVARCHAR(10) = ''
         , @c_C_Country          NVARCHAR(30) = ''
         , @c_Country_ST         NVARCHAR(30) = ''      
   
   SET @n_Err = 0
   SET @c_ErrMsg = ''
   SET @b_Success = 1
   
   SELECT @c_Orderkey = PH.Orderkey
   FROM PICKHEADER PH WITH (NOLOCK)
   WHERE PH.PickHeaderKey = @c_PickslipNo
   
   IF @c_Orderkey <> ''
   BEGIN
      SELECT @c_C_Country = ISNULL(OH.C_Country,'')
      FROM ORDERS OH WITH (NOLOCK) 
      WHERE OH.OrderKey = @c_Orderkey
   END
   
   SELECT @c_Country_ST = ISNULL(s.Country,'')
   FROM STORER AS s WITH (NOLOCK)
   WHERE s.Storerkey = @c_Storerkey

   IF @c_Country_ST <> '' AND @c_Country_ST <> @c_C_Country
   BEGIN
      IF ISNULL(@c_LottableValue,'') = ''
      BEGIN
         SET @n_continue = 3    
         SET @n_err = 61910-- Should Be Set To The SQL Errmessage but I don't know how to do so. 
         SET @c_errmsg='NSQL'+CONVERT(char(5), @n_err)+': Lottable is empty for Sku: ' + RTRIM(ISNULL(@c_Sku,'')) + '. (ispPKLotChk04)'          
         GOTO QUIT_SP
      END
   END 
   
   IF NOT EXISTS(SELECT 1 
                 FROM CODELKUP CL (NOLOCK)
                 WHERE CL.Listname = 'VFCOO'
                 AND CL.Storerkey = @c_Storerkey
                 AND CL.Code = @c_LottableValue)
   BEGIN
      SET @n_continue = 3    
      SET @n_err = 61920-- Should Be Set To The SQL Errmessage but I don't know how to do so. 
      SET @c_errmsg='NSQL'+CONVERT(char(5), @n_err)+': Woring COO Value please check codelkup(VFCOO). (ispPKLotChk04)'          
      GOTO QUIT_SP
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
      EXECUTE dbo.nsp_LogError @n_Err, @c_Errmsg, 'ispPKLotChk04'    
      --RAISERROR (@c_Errmsg, 16, 1) WITH SETERROR    -- SQL2012
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
END  

GO